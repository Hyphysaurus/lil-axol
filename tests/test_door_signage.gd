extends SceneTree
## Does a door actually NAME the place beyond it, in game, at the right range?
##
## test_reach_registry proves the table is correct; this proves it is WIRED. Signage is a silent
## feature: if `_read_destination` never ran, or the nudge never fired, or a portal's destination
## resolved to "", nothing errors and nothing appears — the game just goes on being the thing Maram
## reported ("cant seem to return to my bespoke scene, the original hub"). So drive it for real:
## instantiate a reach, walk the axolotl into signage range of each door, and read back what the
## hints layer was told.
##
## The estuary is the reach under test because it is the only one with TWO live doors going to two
## DIFFERENT places (hub via `exit`, canals via `exit2`) — so it proves the per-door lookup, not just
## that some string appeared once.
##
## Approach geometry matters: the axolotl is parked 70px to the LEFT of each door — inside
## SIGN_RADIUS (90) and well outside TRIGGER_RADIUS (28), horizontally offset so the few frames of
## gravity that follow cannot close the gap and cross the portal mid-test.
##
## Harness note: one-shot _process() state machine per the trap at tests/test_reach_map.gd:3-17.
##
## Run: & $godot --headless --path . --script res://tests/test_door_signage.gd

const SETTLE_FRAMES := 8
const NUDGE_FRAMES := 3
const STANDOFF := Vector2(-70.0, 0.0)

var _fails := 0
var _checks := 0
var _stage := 0
var _frame := 0
var _scene: Node = null
var _portals: Array[Node] = []
var _expect: Array = []

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	match _stage:
		0:
			var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
			WSHelper.reset_scratch("user://test_door_signage.save")
			_scene = (load("res://estuary.tscn") as PackedScene).instantiate()
			get_root().add_child(_scene)
			_stage = 1
			_frame = 0
		1:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				_collect()
				_stage = 2
				_frame = 0
		2:
			# park the axolotl beside the first door and let the portal poll
			_stand_beside(0)
			_stage = 3
			_frame = 0
		3:
			_frame += 1
			if _frame >= NUDGE_FRAMES:
				_verify(0)
				_stand_beside(1)
				_stage = 4
				_frame = 0
		4:
			_frame += 1
			if _frame >= NUDGE_FRAMES:
				_verify(1)
				print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
				quit(1 if _fails > 0 else 0)
				return true
	return false

func _collect() -> void:
	var Registry = load("res://game/world/reach_registry.gd")
	_find(_scene, "cove_portal.gd", _portals)
	_check("estuary has two live doors (found %d)" % _portals.size(), _portals.size() == 2)
	# resolve what each door SHOULD say straight from the portal's own destination
	for p in _portals:
		var target := String(p.get("_exit_to"))
		_expect.append({
			"scene": target,
			"id": Registry.id_for_scene(target),
			"name": Registry.name_for_scene(target),
		})
	var ids: Array = []
	for e in _expect:
		ids.append(e["id"])
	# the two doors must lead to two DIFFERENT places, or this suite proves nothing
	_check("the two doors lead to different reaches (%s)" % str(ids), ids.size() == 2 and ids[0] != ids[1])
	for e in _expect:
		_check("door destination %s resolves to a named reach ('%s')" % [e["scene"], e["name"]], not String(e["name"]).is_empty())

func _stand_beside(idx: int) -> void:
	if idx >= _portals.size():
		return
	var axo := get_first_node_in_group("player") as Node2D
	var p := _portals[idx] as Node2D
	if axo != null and p != null:
		axo.global_position = p.global_position + STANDOFF

func _verify(idx: int) -> void:
	if idx >= _portals.size() or idx >= _expect.size():
		return
	var hints := get_first_node_in_group("hints")
	_check("hints layer is live", hints != null)
	if hints == null:
		return
	var seen: Dictionary = hints.get("_seen")
	var key: String = "door_" + String(_expect[idx]["id"])
	_check("door %d signed '%s' on approach (%s)" % [idx, _expect[idx]["name"], key], seen.has(key))

func _find(node: Node, script_file: String, out: Array[Node]) -> void:
	var s := node.get_script() as Resource
	if s != null and s.resource_path.get_file() == script_file:
		out.append(node)
	for c in node.get_children():
		_find(c, script_file, out)
