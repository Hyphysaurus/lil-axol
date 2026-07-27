extends SceneTree
## Slice-3 coordinate contract: world global coordinates (inside or outside the pixel shell)
## must equal the pre-slice values EXACTLY. If this test breaks, fix the shell, not the numbers.
##
## Harness note (same idiom as tests/test_reach_map.gd, verified empirically against this repo):
## under `--headless --script`, autoload globals (WorldState/Settings/Sfx) are NOT compile-visible
## in this file's own source until SceneTree.initialize() finishes, and add_child()'d nodes report
## a null tree until the real _process() loop starts. Both resolve together at the first real
## _process() callback, so this whole suite runs from a one-shot _process() (never _init()), and
## WorldState access is routed through the lazily-load()'d tests/reach_map_worldstate_helper.gd (no
## bare `WorldState` identifier anywhere in this file's own source) so the run reads a FRESH world,
## never the real dev save on this machine.
##
## EXPECTED_* constants below are real probe-measured values (tests/_probe_contract.gd, now
## deleted), captured against the CURRENT (pre-slice-3) canals.tscn boot — reproduced identically
## across 3 consecutive runs. Positions read synchronously, in the SAME frame add_child() finishes
## (no await, no extra process tick) — no physics tick has run, so nothing has moved.
##
## EXPECTED_VENT_COUNT is 4, not the map's 1 painted vent: reach_map.gd's setup() queue_free()s the
## 3 legacy hand-placed Vent1/Vent2/Vent3 nodes when a map reach loads (spec C3), but queue_free()
## only marks a node for deferred deletion — it stays in the scene tree AND in the "thermal_vent"
## group until the engine processes deferred frees at end-of-frame. Reading in the same frame (as
## this contract requires) observes all 4: the 3 not-yet-freed legacy vents plus the 1 real
## map-painted vent. This is fully deterministic (fixed scene structure, no randomness) and is
## actually the RIGHT thing to lock: if Task 3's restructuring ever caused the read to happen one
## frame later, the legacy vents would already be gone and vent_count would silently drop to 1 —
## exactly the kind of regression this contract exists to catch.
## EXPECTED_VENT_0 is the map-painted vent (parented under ReachMap, the first child of Cove), which
## sorts before the legacy Vent1/2/3 (later Cove children) in get_nodes_in_group()'s scene-tree
## order — not insertion order, but likewise deterministic for a fixed scene tree.
##
## Run: & $godot --headless --path . --script res://tests/test_pixel_contract.gd

const EXPECTED_AXO := Vector2(-26.0, -40.0)
const EXPECTED_LIMITS := [-102, -196, 906, 332]           # [left, top, right, bottom]
const EXPECTED_VENT_COUNT := 4
const EXPECTED_VENT_0 := Vector2(678.0, 280.0)

var _fails := 0
var _done := false

var _checks := 0   # executed-check tally: guards against a silently-empty suite reading as green
func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
	WSHelper.reset_scratch("user://test_pixel_contract.save")

	var scene: Node = (load("res://canals.tscn") as PackedScene).instantiate()
	get_root().add_child(scene)   # runs every _ready synchronously, incl. cove.gd injection

	var axo := get_first_node_in_group("player") as CharacterBody2D
	_check("player exists", axo != null)
	if axo:
		_check("axo spawn position", axo.global_position.is_equal_approx(EXPECTED_AXO))
		var cam := axo.get_node("Camera") as Camera2D
		_check("camera limits", [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom] == EXPECTED_LIMITS)

	var vents := get_nodes_in_group("thermal_vent")
	_check("vent count", vents.size() == EXPECTED_VENT_COUNT)
	if vents.size() > 0:
		_check("vent 0 position", (vents[0] as Node2D).global_position.is_equal_approx(EXPECTED_VENT_0))

	print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
	quit(1 if _fails > 0 else 0)
	return true
