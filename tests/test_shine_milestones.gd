extends SceneTree
## Shine milestone reload-replay regression (D-0007): a reload/portal-hop that re-seeds
## OilSpill's cleanliness (set_clean_fraction, driven by cove.gd._apply_saved()) must NOT replay
## the 25/50/75% Shine milestone bonuses — Shine is scene-local and its _milestone cursor always
## resets to 0 on load, while cove.gd's children (Shine included) _ready() BEFORE the parent's own
## _ready() calls _apply_saved(), so a saved cleanliness jump reaches an already-connected
## listener. Without a seeding guard, every revisit to a partially-cleaned cove re-awards every
## milestone already crossed (2500+5000+7500 Shine + chimes, farmable by portal-hopping since
## Settings.run_score persists across scenes). Live scrubbing across a milestone must still award
## normally, exactly once. Same guard is checked on game/hud/restoration_meter.gd's cosmetic
## milestone pulse (the reviewer's Minor, same class of bug, no score impact).
##
## Same bootstrap constraint as tests/test_oil_roundtrip.gd: oil_spill.gd/shine.gd/
## restoration_meter.gd touch the Settings/Sfx autoloads directly, unavailable at parse time
## under `--headless --script` (autoloads aren't registered as GDScript globals until
## SceneTree.initialize() finishes) — so this suite's entire body runs from the first real
## _process() callback, and the scripts under test are load()'d there, never top-level preload()'d.
var fails := 0
var _done := false

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var OilSpillScript = load("res://game/cove/oil_spill.gd")
	var ShineScript = load("res://game/cove/shine.gd")
	var MeterScript = load("res://game/hud/restoration_meter.gd")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")

	# --- Setup: OilSpill + Shine + RestorationMeter as siblings under one root, the listeners
	# wired BEFORE OilSpill.setup() runs — the exact ordering cove.gd produces (children _ready
	# bottom-up before the parent's own _ready calls _inject()/_apply_saved()), which is what lets
	# a reload jump reach an already-connected listener. Water geometry mirrors cove.tscn's Water
	# sibling exactly (same idiom as test_oil_roundtrip.gd's _spawn_oil). ---
	var cfg = CoveConfigScript.new()
	var root := Node2D.new()
	get_root().add_child(root)
	var water := Sprite2D.new()
	water.name = "Water"
	water.position = Vector2(-142, -35)
	water.scale = Vector2(519, 276)
	root.add_child(water)

	var oil = OilSpillScript.new()
	oil.name = "OilSpill"
	root.add_child(oil)                     # oil._ready() -> add_to_group("oil_manager")

	var shine = ShineScript.new()
	shine.name = "Shine"
	root.add_child(shine)                   # shine._ready() connects to oil NOW, pre-setup — matches cove.tscn's child order

	var meter = MeterScript.new()
	meter.name = "RestorationMeter"
	root.add_child(meter)                   # same-class cosmetic guard (reviewer's Minor)

	oil.setup(cfg)                          # mirrors cove.gd's _inject($OilSpill): builds the mask, emits cleanliness(0.0)
	_check("setup: starts at 0 cleanliness", is_equal_approx(oil.current_clean, 0.0))
	_check("setup: no milestone score from the 0.0 seed emission", shine._milestone == 0)

	var score_before_seed: float = shine.score
	var pulse_before_seed: float = meter._pulse

	# --- THE BUG: a reload/portal-hop reseed (cove.gd._apply_saved's partial-progress path) ---
	oil.set_clean_fraction(0.6)
	var score_after_seed: float = shine.score
	var gained_seed := score_after_seed - score_before_seed
	_check("seed jump 0 -> ~0.6: Shine score gained == 0 (no replay)", gained_seed == 0.0)

	# independent re-derive of the expected cursor from the ACTUAL post-seed cleanliness (bisection
	# in set_clean_fraction doesn't guarantee current_clean == 0.6 to the ULP) rather than trusting
	# a bare literal — same "don't trust a magic number" idiom test_reach_map.gd uses.
	var expect_cursor := 0
	for m in [0.25, 0.5, 0.75]:
		if oil.current_clean >= m:
			expect_cursor += 1
	_check("seed jump: Shine milestone cursor seeded silently to match current_clean",
		shine._milestone == expect_cursor)
	_check("seed jump: seeded cursor lands at 2 for a 0.6 jump (sanity on VIS thresholds)",
		expect_cursor == 2)
	_check("seed jump: RestorationMeter pulse did not fire (cosmetic sibling guard)",
		is_equal_approx(meter._pulse, pulse_before_seed))
	_check("seed jump: RestorationMeter milestone cursor also seeded",
		meter._milestone == expect_cursor)

	# --- LIVE scrubbing across a milestone must still award, exactly once. Emit the real
	# `cleanliness` signal directly (oil.is_seeding is false here — we're not inside
	# set_clean_fraction) so the assertion isolates the milestone bonus from spray_at's unrelated
	# per-frame scrub reward (_on_scrubbed), instead of conflating the two. ---
	_check("precondition: oil.is_seeding is false outside set_clean_fraction", not oil.is_seeding)
	var score_before_live: float = shine.score
	var cursor_before_live: int = shine._milestone
	oil.cleanliness.emit(0.8)               # a live update crossing the next threshold(s)

	# independently re-derive the expected award from the SAME threshold table Shine uses, rather
	# than hardcoding "milestone 3 / 7500" — robust to whatever tier the seed step actually landed on.
	var expect_gained := 0.0
	var c := cursor_before_live
	while c < 3 and 0.8 >= [0.25, 0.5, 0.75][c]:
		c += 1
		expect_gained += 2500.0 * float(c)
	var gained_live: float = shine.score - score_before_live
	_check("live cleanliness update: newly-crossed milestone(s) award exactly once",
		is_equal_approx(gained_live, expect_gained))
	_check("live cleanliness update: award is non-zero (a milestone really did cross)",
		expect_gained > 0.0)
	_check("live cleanliness update: milestone cursor advanced to match", shine._milestone == c)
	_check("live cleanliness update: RestorationMeter pulse fired", meter._pulse > 0.0)

	# --- no double-award: a further update that doesn't cross a NEW milestone must not re-pay ---
	var score_before_dup: float = shine.score
	var cursor_before_dup: int = shine._milestone
	oil.cleanliness.emit(0.95)
	_check("no double-award: repeat update above the last-crossed milestone gains nothing",
		is_equal_approx(shine.score - score_before_dup, 0.0))
	_check("no double-award: milestone cursor unchanged", shine._milestone == cursor_before_dup)

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	root.free()
	quit(1 if fails > 0 else 0)
	return true
