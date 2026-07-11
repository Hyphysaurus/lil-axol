extends SceneTree
## ReachMap loader vs marsh_draft ground truth (commit 541dc74 tallies).
## NOTE (Task 5): reach_map.gd now preloads destructible_rock.gd, which references the Sfx
## autoload; destructible_rock.gd/reach_map.gd also touch the WorldState autoload directly, and
## _build_breakables()/_build_climbs() need a working get_tree().get_first_node_in_group(). Under
## `--headless --script`, NEITHER is available during _init() OR _initialize(): autoload
## singletons aren't registered as GDScript globals until SceneTree.initialize() finishes (a bare
## `const X := preload(destructible_rock.gd)` — or even a lazy load() from _init()/_initialize() —
## fails "Identifier not found: Sfx"/"WorldState"), AND freshly add_child()'d nodes report
## is_inside_tree() == false / get_tree() == null during that same window (verified empirically:
## both _init() and _initialize() give a null tree pointer for a node added moments earlier).
## Both problems resolve together at the first real _process() callback, i.e. once the engine's
## actual per-frame loop has started — by then autoloads are live AND the tree is real. So this
## suite runs its ENTIRE body from _process() (one-shot, returns true to quit after frame 1), and
## keeps any literal `WorldState.*` text out of this file's own source (compiled too early
## regardless of which function it's nested in) by routing through reach_map_worldstate_helper.gd,
## itself only load()'d — never top-level preload()'d — from inside that first _process().
var fails := 0
var _done := false
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name); if not ok: fails += 1
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var ReachMapScript = load("res://game/cove/reach_map.gd")
	var ReachFieldScript = load("res://game/cove/reach_field.gd")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")
	var RockScript = load("res://game/cove/destructible_rock.gd")
	var cfg = CoveConfigScript.new()
	cfg.id = "canals"
	cfg.map_terrain = load("res://assets/maps/marsh_draft_terrain.png")
	cfg.map_markers = load("res://assets/maps/marsh_draft_markers.png")
	var rm = ReachMapScript.new()
	var root := Node2D.new(); get_root().add_child(root); root.add_child(rm)
	rm.classify(cfg)                      # pure data stage — no scene building needed for this suite
	_check("dims", rm.gw == 120 and rm.gh == 60)
	var t := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	for c in rm.grid: t[c] += 1
	_check("tally earth", t[1] == 2556);  _check("tally rubble", t[2] == 102)
	_check("tally water", t[3] == 2348);  _check("tally climb", t[4] == 125)
	_check("table row", rm.table_row == 22)
	_check("surface_y", absf(cfg.surface_y - (cfg.map_origin.y + 22.0 * 8.0)) < 0.01)
	_check("spawn", cfg.spawn_pos == cfg.map_origin + Vector2(6.5, 16.5) * 8.0)
	_check("friend", cfg.friend_pos == cfg.map_origin + Vector2(70.5, 26.5) * 8.0)
	_check("curios", cfg.curios.size() == 3)
	_check("pads", cfg.pad_xs.size() == 15)
	_check("barrels", cfg.barrel_positions.size() == 6)
	_check("vents", cfg.vent_positions.size() == 1)
	_check("portals", cfg.portal_markers.size() == 2)
	var edges := [cfg.portal_markers[0]["edge"], cfg.portal_markers[1]["edge"]]
	_check("portal edges", edges.has("west") and edges.has("east"))
	var seals = rm.component_rects(2)
	# west plug (0,36)-(1,45), two mesa plugs (72,30)-(73,42)/(88,30)-(89,42), and TWO bottom
	# plugs (58,50)-(59,55)/(107,49)-(108,57) — re-derived via tools/audit_reach_map.ps1-style
	# flood fill against the real marsh_draft_terrain.png; the brief's "bottom plug" (singular,
	# 4 total) was stale — the map genuinely gates two separate bottom pockets, all 5 exact
	# rectangles (no non-rect lint warning).
	_check("seal components", seals.size() == 5)
	_check("camera bounds", cfg.camera_bounds.size.x >= 960.0)

	# MANDATORY carry-over from T1 review: water_bounds() must be a cached member set ONCE in
	# set_mask() (O(w*h) scan is too hot for a per-physics-frame caller like the axolotl) — prove
	# the cache equals an independent scan of the SAME marsh grid classify() just produced.
	var field = ReachFieldScript.new()
	field.set_mask(cfg.map_origin, rm.grid, rm.gw, rm.gh, rm.table_row)
	var minx: int = rm.gw; var maxx := -1; var miny: int = rm.gh; var maxy := -1
	for cy in rm.gh:
		for cx in rm.gw:
			if rm.grid[cy * rm.gw + cx] == ReachFieldScript.WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	var scanned := Rect2(cfg.map_origin + Vector2(minx, miny) * 8.0,
		Vector2(maxx - minx + 1, maxy - miny + 1) * 8.0)
	_check("water_bounds cache == scan (marsh mask)", field.water_bounds() == scanned)
	field.free()

	# --- collision merge property: union == solid set, no overlaps ---
	var rects = ReachMapScript.merge_rects(rm.grid, rm.gw, rm.gh,
		func(c): return c == 1 or c == 4)       # earth + climb
	var covered: Dictionary = {}
	var overlap := false
	for r in rects:
		for cy2 in range(r.position.y, r.end.y):
			for cx2 in range(r.position.x, r.end.x):
				var k: int = cy2 * rm.gw + cx2
				if covered.has(k): overlap = true
				covered[k] = true
	var solid_n := 0
	for i in rm.grid.size():
		if rm.grid[i] == 1 or rm.grid[i] == 4: solid_n += 1
	_check("merge covers exactly", covered.size() == solid_n and not overlap)
	_check("merge is compact", rects.size() <= 96)

	# --- Task 5: locked gate is a no-op bounce (never carves, never counts down) ---
	var locked_rock = RockScript.new()
	locked_rock.cols = 4
	locked_rock.rows = 4
	locked_rock.locked = true
	root.add_child(locked_rock)
	var before_remaining: int = locked_rock._remaining
	_check("locked gate: has solid cells before blast", before_remaining > 0)
	var hit: int = locked_rock.blast(locked_rock.global_position, 20.0)
	_check("locked gate: blast() returns 0", hit == 0)
	_check("locked gate: _remaining unchanged", locked_rock._remaining == before_remaining)
	locked_rock.free()

	# --- Task 5: seal persistence round-trip (broken seals STAY broken; echo-exempt) ---
	# WorldState idiom from tests/test_world_state.gd's _fresh(): redirect the AUTOLOAD singleton
	# itself to a scratch save file so the real user save is NEVER touched — reach_map.gd's
	# _build_breakables() calls the global `WorldState`, not an injected instance, so the only way
	# to isolate this test is to repoint the singleton for the duration of the run. Routed through
	# WSHelper (see its header) because a bare `WorldState` identifier written directly in THIS
	# file fails to compile under --headless --script (autoloads aren't registered as GDScript
	# globals until after this --script target is itself statically compiled).
	var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
	WSHelper.reset_scratch("user://test_reach_map_seal.save")
	# seal_2 is the REAL ordinal id of the west plug (0,36)-(1,45) in component_rects' actual
	# scan order (code ascending RUBBLE/SILT/BOULDER, then row-major within a code) — verified via
	# a throwaway probe against this exact PNG: seal_0/seal_1 land on the two mesa plugs (row 30,
	# scanned before row 36), seal_2 is the west plug, seal_3/seal_4 the two bottom plugs. The
	# brief's Step 3 said "seal_0" for the west plug; that was a stale guess (same class of error
	# T2's "4 bottom plugs" was), corrected here against the ground truth like that fix was.
	WSHelper.mark(cfg.id, "seal_2", true)

	var cfg2 = CoveConfigScript.new()
	cfg2.id = "canals"
	cfg2.map_terrain = load("res://assets/maps/marsh_draft_terrain.png")
	cfg2.map_markers = load("res://assets/maps/marsh_draft_markers.png")
	var rm2 = ReachMapScript.new()
	var root2 := Node2D.new(); get_root().add_child(root2)
	var field2 = ReachFieldScript.new()
	root2.add_child(field2)               # group "reach_field" membership needs it IN the tree
	root2.add_child(rm2)
	rm2.classify(cfg2)
	field2.set_mask(cfg2.map_origin, rm2.grid, rm2.gw, rm2.gh, rm2.table_row)
	rm2.build()                           # exercises _build_breakables() end to end

	_check("seal persistence: west-plug cell reads water",
		field2.is_water(rm2.cell_world(0, 40)))
	var live_rock_at_plug := false
	for child in rm2.get_children():
		if is_instance_of(child, RockScript) and not child.locked \
				and child.position == cfg2.map_origin + Vector2(0, 36) * 8.0:
			if not child.is_queued_for_deletion():
				live_rock_at_plug = true
	_check("seal persistence: no live rock at the west plug", not live_rock_at_plug)
	# a seal NOT marked broken (seal_0, the north mesa plug) must still be a live, unlocked rock
	var live_rock_at_mesa := false
	for child in rm2.get_children():
		if is_instance_of(child, RockScript) and not child.locked \
				and child.position == cfg2.map_origin + Vector2(72, 30) * 8.0 \
				and not child.is_queued_for_deletion():
			live_rock_at_mesa = true
	_check("seal persistence: untouched seal still has a live rock", live_rock_at_mesa)
	root2.free()

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	root.free()
	quit(1 if fails > 0 else 0)
	return true
