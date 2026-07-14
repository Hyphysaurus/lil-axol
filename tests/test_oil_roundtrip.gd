extends SceneTree
## OilSpill save/reload round trip (D-oil-roundtrip): cove.gd saves oil.current_clean on exit
## (_exit_tree -> WorldState) and restores it on the next spawn via a fresh _build_mask() +
## set_clean_fraction(saved) (_apply_saved). current_clean is measured in VISIBILITY-weighted
## units (_vis() remaps raw coverage through the VIS_FLOOR/VIS_FULL ramp — see oil_spill.gd), so
## the restore must land within a small tolerance of the value that was saved. Same bootstrap
## constraint as test_reach_map.gd: OilSpill.setup() needs get_tree() (reach_field group lookup)
## and touches the Sfx/WorldState autoloads via spray_at/CleanupFX, neither of which is available
## during _init()/_initialize() under `--headless --script` — so this suite's entire body runs
## from the first real _process() callback (one-shot, returns true to quit after frame 1).
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
	var CoveConfigScript = load("res://game/cove/cove_config.gd")

	for target in [0.1, 0.5, 0.9]:
		var saved := _scrub_and_read(OilSpillScript, CoveConfigScript, target)
		_check("scrub reached ~%.2f (got %.4f)" % [target, saved], saved >= target and saved <= target + 0.05)

		# --- simulate the reload path: a brand-new cove, a fresh _build_mask(), then the exact
		# call cove.gd._apply_saved() makes with the value _exit_tree() wrote to WorldState. ---
		var restored := _reload_with(OilSpillScript, CoveConfigScript, saved)
		var err := absf(restored - saved)
		_check("round trip saved=%.4f -> restored=%.4f (|err| %.4f <= 0.02)" % [saved, restored, err], err <= 0.02)

	# --- Edge cases (reviewer's Minor: missing permanent assertions for set_clean_fraction's own
	# documented short-circuits + the win-threshold boundary the whole round trip exists to protect) ---

	# f=0.0 is a documented no-op (`if _mask == null or f <= 0.0: return`): a freshly built mask
	# (current_clean == 0.0 from setup()'s own _set_clean()) must stay untouched.
	var oil_zero = _spawn_oil(OilSpillScript, CoveConfigScript)
	oil_zero.set_clean_fraction(0.0)
	_check("f=0.0 is a no-op: current_clean stays 0.0", is_equal_approx(oil_zero.current_clean, 0.0))

	# f=1.0 short-circuits _solve_keep's target<=0.0 branch straight to keep=0.0 (no bisection) —
	# this is the WorldState.is_restored() spawn path (cove.gd._apply_saved), so it must land on
	# EXACTLY 1.0, not an approximation close to it, or a "fully restored" cove could still show
	# lingering oil.
	var oil_one = _spawn_oil(OilSpillScript, CoveConfigScript)
	oil_one.set_clean_fraction(1.0)
	_check("f=1.0 restores to EXACTLY 1.0 (is_restored spawn path)", oil_one.current_clean == 1.0)

	# Win-boundary membership: _solve_keep's bisection only ever UNDER-restores by a tiny epsilon
	# (hi starts at 1.0 and only shrinks — see _solve_keep), never over-restores past the saved
	# fraction, so a value comfortably on one side of win_threshold (CoveConfig default 0.98) must
	# restore to the SAME side, never crossing it.
	var restored_975 := _reload_with(OilSpillScript, CoveConfigScript, 0.975)
	_check("win boundary: saved 0.975 (below win_threshold 0.98) restores still below it",
		restored_975 < 0.98)
	var restored_985 := _reload_with(OilSpillScript, CoveConfigScript, 0.985)
	_check("win boundary: saved 0.985 (above win_threshold 0.98) restores still at/above it",
		restored_985 >= 0.98)

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
	return true

## Builds a fresh OilSpill on hub-shaped geometry (mirrors cove.tscn's Water sibling exactly:
## same position/scale) and sprays it — via the real spray_at() erosion path, not
## set_clean_fraction — until current_clean crosses `target`, returning the value actually
## reached. This is the "ground truth" half of the round trip: the number a real player's spray
## session would leave behind for cove.gd._exit_tree() to save.
func _scrub_and_read(OilSpillScript, CoveConfigScript, target: float) -> float:
	var oil = _spawn_oil(OilSpillScript, CoveConfigScript)
	var center := Vector2(282.5, 3.0)   # mid-spill, mid-band (spill_left/right ~120/445, surf -27)
	var iterations := 0
	# radius >> the mask diagonal makes the brush falloff (1 - d/rpx) nearly flat across the whole
	# 192x88 grid, so one call/iteration erodes every cell a small, controlled amount instead of
	# needing dozens of hand-placed brush positions to cover the spill evenly.
	while oil.current_clean < target and iterations < 3000:
		oil.spray_at(center, 5000.0, 0.02)
		iterations += 1
	return oil.current_clean

## Fresh cove, fresh OilSpill, fresh _build_mask() (setup() calls it) — exactly the state cove.gd
## hands to set_clean_fraction() in _apply_saved(). Returns current_clean right after that call.
func _reload_with(OilSpillScript, CoveConfigScript, saved: float) -> float:
	var oil = _spawn_oil(OilSpillScript, CoveConfigScript)
	oil.set_clean_fraction(saved)
	return oil.current_clean

func _spawn_oil(OilSpillScript, CoveConfigScript):
	var cfg = CoveConfigScript.new()   # hub numbers (the class defaults) are fine for this suite
	var root := Node2D.new()
	get_root().add_child(root)
	var water := Sprite2D.new()
	water.name = "Water"
	water.position = Vector2(-142, -35)   # == cove.tscn's Water node, byte-for-byte
	water.scale = Vector2(519, 276)
	root.add_child(water)
	var oil = OilSpillScript.new()
	oil.name = "OilSpill"
	root.add_child(oil)
	oil.setup(cfg)
	return oil
