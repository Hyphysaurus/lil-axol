extends SceneTree
## D-0020 — cleared chokes and purified barrels STAY cleared across reach crossings.
##
## The bug this locks down: debris_field.setup() and shore_pollution._spawn_barrels() respawned
## their full config count on every non-restored visit, so a 5-second portal hop undid the frog's
## work (estuary oxygen is 30% of the blend, and the win recipe needs oxygen >= 0.9) and let
## material + the "spring_clean" feat be farmed by re-entering a reach. Both now file an indexed
## WorldState mark ("debris_<i>" / "barrel_<i>") in the shipped curio_<i> / seal_<n> idiom.
##
## Runs its whole body from the first _process() callback and keeps literal autoload identifiers
## out of this file's source — see tests/test_reach_map.gd:3-17 for why (autoloads are not
## compile-visible under `--headless --script`; this suite routes through the same helper).
## Run: & $godot --headless --path . --script res://tests/test_choke_persistence.gd

const SCRATCH := "user://test_choke.save"

var fails := 0
var _checks := 0
var _done := false

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var WS = load("res://tests/reach_map_worldstate_helper.gd")
	var DebrisField = load("res://game/cove/debris_field.gd")
	var Debris = load("res://game/cove/floating_debris.gd")
	var ShorePollution = load("res://game/cove/shore_pollution.gd")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")
	WS.reset_scratch(SCRATCH)

	var cfg = CoveConfigScript.new()
	cfg.id = "testreach"
	cfg.debris_count = 5
	cfg.water_left = 0.0
	cfg.water_right = 600.0
	cfg.surface_y = 0.0

	# --- first visit: nothing cleared yet, the full count spawns -------------------------------
	var f1 = DebrisField.new()
	get_root().add_child(f1)
	f1.setup(cfg)
	var first_xs: Array = []
	for c in f1.get_children():
		first_xs.append(c.position.x)
	_check("visit 1: spawns the full debris_count", f1.get_child_count() == 5)
	_check("visit 1: each clump is index-stamped", f1.get_child_count() == 5
		and f1.get_child(0).idx == 0 and f1.get_child(4).idx == 4)

	# --- the frog eats clumps 1 and 3 -----------------------------------------------------------
	# _cleanse() is the real dissolve path (grab() ends in it via a tween); call it directly so the
	# test needs no frog, no tween, and no frame budget.
	f1.get_child(3)._cleanse()
	f1.get_child(1)._cleanse()
	_check("eaten clumps filed a WorldState mark",
		bool(WS.get_cove("testreach", "debris_1", false))
		and bool(WS.get_cove("testreach", "debris_3", false)))
	_check("uneaten clumps filed nothing", not bool(WS.get_cove("testreach", "debris_0", false))
		and not bool(WS.get_cove("testreach", "debris_2", false))
		and not bool(WS.get_cove("testreach", "debris_4", false)))
	f1.free()

	# --- leave and come back: the mark must survive a real disk round-trip ----------------------
	WS.reload_scratch(SCRATCH)
	var f2 = DebrisField.new()
	get_root().add_child(f2)
	f2.setup(cfg)
	_check("visit 2: eaten chokes stay eaten (THE BUG)", f2.get_child_count() == 3)
	var kept: Array = []
	for c in f2.get_children():
		kept.append(c.idx)
	kept.sort()
	_check("visit 2: exactly the uneaten indices return", kept == [0, 2, 4])
	# the rng/lerp draw happens BEFORE the skip, so survivors keep their original columns
	var moved := false
	for c in f2.get_children():
		if not is_equal_approx(c.position.x, first_xs[c.idx]):
			moved = true
	_check("visit 2: survivors keep their original x column", not moved)
	f2.free()

	# --- a restored reach still short-circuits (spec review C2, unchanged) ----------------------
	WS.mark("testreach", "restored", true)
	var f3 = DebrisField.new()
	get_root().add_child(f3)
	f3.setup(cfg)
	_check("restored reach spawns no chokes at all", f3.get_child_count() == 0)
	f3.free()

	# --- barrels: a purified barrel does not come back to be re-cashed --------------------------
	var bcfg = CoveConfigScript.new()
	bcfg.id = "barrelreach"
	bcfg.has_map = true          # skips the legacy shore splats; barrel_positions drives the spawn
	bcfg.water_left = 0.0
	bcfg.water_right = 600.0
	bcfg.surface_y = 0.0
	# barrel_positions is a typed Array[Vector2] — build it typed, a plain [] literal is rejected
	var bpos: Array[Vector2] = [Vector2(100.0, 0.0), Vector2(200.0, 0.0), Vector2(300.0, 0.0)]
	bcfg.barrel_positions = bpos

	var sp1 = ShorePollution.new()
	get_root().add_child(sp1)
	sp1.setup(bcfg)
	var live1: int = sp1._barrels.size()
	_check("barrels: all three spawn on the first visit", live1 == 3)
	sp1._purify_barrel(sp1._barrels[1])
	_check("purified barrel filed its mark", bool(WS.get_cove("barrelreach", "barrel_1", false)))
	_check("untouched barrels filed nothing",
		not bool(WS.get_cove("barrelreach", "barrel_0", false))
		and not bool(WS.get_cove("barrelreach", "barrel_2", false)))
	sp1.free()

	WS.reload_scratch(SCRATCH)
	var sp2 = ShorePollution.new()
	get_root().add_child(sp2)
	sp2.setup(bcfg)
	_check("barrels: the purified one does not respawn (material farm closed)",
		sp2._barrels.size() == 2)
	var bidx: Array = []
	for b in sp2._barrels:
		bidx.append(int(b["idx"]))
	bidx.sort()
	_check("barrels: exactly the unpurified indices return", bidx == [0, 2])
	sp2.free()

	print("RESULT: %s (%d checks)" % ["FAIL x%d" % fails if fails > 0 else "ALL PASS", _checks])
	quit(1 if fails > 0 else 0)
	return true
