extends SceneTree
## The standing "all five reaches boot clean" gate, made mechanical — it was a manual eyeball of
## five headless boots until Batch C pt 2, when the cove root began stamping `visited` on arrival
## and a naive boot started WRITING to the real user save. This suite redirects the save to a
## scratch first, then boots every reach the registry knows, in one process, and asserts two
## things per reach: the cove root actually came up carrying the RIGHT config (a scene wired to
## the wrong .tres would boot "clean" and be the wrong place), and the arrival stamped `visited`
## (proving the map's memory across all five, not just the estuary of test_visited_wiring.gd).
## Script errors don't fail Godot's exit code headless — the runner greps stderr; this gate covers
## what a grep cannot: the scene came up, as itself, and remembered you were there.
##
## Harness note: one-shot _process() state machine per the trap at tests/test_reach_map.gd:3-17.
##
## Run: & $godot --headless --path . --script res://tests/test_boot_gate.gd

const SETTLE_FRAMES := 10
const DRAIN_FRAMES := 2

var _fails := 0
var _checks := 0
var _stage := 0        # 0 = setup, 1 = settling, 2 = draining the freed scene
var _frame := 0
var _ids: Array = []
var _idx := 0
var _scene: Node = null
var _registry = null

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	match _stage:
		0:
			var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
			WSHelper.reset_scratch("user://test_boot_gate.save")
			_registry = load("res://game/world/reach_registry.gd")
			_ids = _registry.ids()
			_boot_next()
		1:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				var id: String = _ids[_idx]
				var root = get_first_node_in_group("cove_root")
				_check("%s boots a live cove root" % id, root != null)
				if root != null:
					_check("%s root carries its own config" % id, String(root.get("config").id) == id)
				var ws = get_root().get_node("WorldState")
				_check("%s arrival stamped visited" % id, bool(ws.get_cove(id, "visited", false)))
				_scene.queue_free()
				_scene = null
				_idx += 1
				_stage = 2
				_frame = 0
		2:
			_frame += 1
			if _frame >= DRAIN_FRAMES:
				_boot_next()
	return false

func _boot_next() -> void:
	if _idx >= _ids.size():
		_check("gate walked every registered reach (%d)" % _idx, _idx == _ids.size() and _idx > 0)
		print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
		quit(1 if _fails > 0 else 0)
		return
	var scene_path: String = _registry.scene_of(_ids[_idx])
	_scene = (load(scene_path) as PackedScene).instantiate()
	get_root().add_child(_scene)
	_stage = 1
	_frame = 0
