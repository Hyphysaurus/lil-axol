extends SceneTree
## Is `visited` actually WIRED? tests/test_world_state.gd proves the store semantics; this proves
## the cove root stamps a real arrival — and that an ECHO run (score replay of a restored reach)
## does NOT, since echo's whole contract is that the world stays untouched (spec §7). Both failure
## modes are silent: a missed stamp is just a map that never fills in, an echo stamp is just a
## dirty save. Nothing errors either way, so boot the estuary for real, twice.
##
## Harness note: one-shot _process() state machine per the trap at tests/test_reach_map.gd:3-17;
## the WorldState autoload is reached only at runtime (lazy helper / dynamic node lookup), never
## as a bare identifier in this file's source.
##
## Run: & $godot --headless --path . --script res://tests/test_visited_wiring.gd

const SETTLE_FRAMES := 8

var _fails := 0
var _checks := 0
var _stage := 0
var _frame := 0
var _scene: Node = null

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	match _stage:
		0:
			var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
			WSHelper.reset_scratch("user://test_visited_a.save")
			_scene = (load("res://estuary.tscn") as PackedScene).instantiate()
			get_root().add_child(_scene)
			_stage = 1
			_frame = 0
		1:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				var ws = get_root().get_node("WorldState")
				_check("arrival stamps visited", bool(ws.get_cove("estuary", "visited", false)))
				_check("has_visited answers live", bool(ws.has_visited("estuary")))
				_check("a reach not walked stays unvisited", not bool(ws.has_visited("creek")))
				_scene.queue_free()
				_scene = null
				_stage = 2
				_frame = 0
		2:
			_frame += 1
			if _frame >= 2:   # let the freed estuary leave the tree before the echo boot
				var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
				WSHelper.reset_scratch("user://test_visited_b.save")
				var ws = get_root().get_node("WorldState")
				ws.echo = true
				_scene = (load("res://estuary.tscn") as PackedScene).instantiate()
				get_root().add_child(_scene)
				_stage = 3
				_frame = 0
		3:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				var ws = get_root().get_node("WorldState")
				_check("echo arrival does NOT stamp", not bool(ws.get_cove("estuary", "visited", false)))
				_check("echo flag consumed by the boot", bool(ws.echo) == false)
				print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
				quit(1 if _fails > 0 else 0)
				return true
	return false
