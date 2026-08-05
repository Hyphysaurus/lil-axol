extends SceneTree
## Edge-aware legacy arrivals (Batch B): does crossing INTO a legacy rect reach put you at the
## door you actually came through? Before this, every legacy arrival teleported to the hardcoded
## west waterline mouth — walk east into a reach, come back, and you materialized across the map.
## Drives the real path: sets the crossing flags exactly as cove_portal._cross() stamps them, boots
## the creek (a legacy reach with TWO doors to two different places), and reads where the axolotl
## actually stands. The fallback ("" = direct boot / one-way / old session) must stay the classic
## west mouth, byte-identical.
##
## Harness note: one-shot _process() per the trap at tests/test_reach_map.gd:3-17; autoloads only
## via runtime lookup.
##
## Run: & $godot --headless --path . --script res://tests/test_edge_arrivals.gd

const SETTLE_FRAMES := 3   # few: water damps drift, but physics runs — distance checks, not exact

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

func _boot_creek(from_scene: String) -> void:
	var s = get_root().get_node("Settings")
	s.arrive_via_portal = true
	s.arrive_from = from_scene
	_scene = (load("res://creek.tscn") as PackedScene).instantiate()
	get_root().add_child(_scene)
	_frame = 0

func _axo_pos() -> Vector2:
	var axo := get_first_node_in_group("player") as Node2D
	return axo.position if axo != null else Vector2(1e9, 1e9)

func _cfg() -> Resource:
	var root = get_first_node_in_group("cove_root")
	return root.get("config") if root != null else null

func _process(_delta: float) -> bool:
	match _stage:
		0:
			var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
			WSHelper.reset_scratch("user://test_edge_arrivals.save")
			_boot_creek("res://main.tscn")   # came from the hub -> creek's exit door (east side)
			_stage = 1
		1:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				var cfg := _cfg()
				var at_door: Vector2 = cfg.exit_pos + Vector2.LEFT * 26.0
				var west_mouth := Vector2(cfg.water_left + 34.0, cfg.surface_y + 46.0)
				var p := _axo_pos()
				_check("arriving from the hub lands at the hub door (%.0fpx off)" % p.distance_to(at_door), p.distance_to(at_door) < 60.0)
				_check("and nowhere near the old west mouth", p.distance_to(west_mouth) > 200.0)
				var s = get_root().get_node("Settings")
				_check("arrive_from consumed one-shot", String(s.arrive_from) == "")
				_scene.queue_free()
				_scene = null
				_stage = 2
				_frame = 0
		2:
			_frame += 1
			if _frame >= 2:
				_boot_creek("")              # unknown origin -> the classic west mouth, unchanged
				_stage = 3
		3:
			_frame += 1
			if _frame >= SETTLE_FRAMES:
				var cfg := _cfg()
				var west_mouth := Vector2(cfg.water_left + 34.0, cfg.surface_y + 46.0)
				var p := _axo_pos()
				_check("unknown origin keeps the classic west mouth (%.0fpx off)" % p.distance_to(west_mouth), p.distance_to(west_mouth) < 60.0)
				_check("and not the hub door", p.distance_to(cfg.exit_pos) > 200.0)
				print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
				quit(1 if _fails > 0 else 0)
				return true
	return false
