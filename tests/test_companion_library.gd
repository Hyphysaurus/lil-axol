extends SceneTree
## Headless lint for the character record (companion_library INFO + art) and the D-0019
## no-steal roster ruling. Settings is an AUTOLOAD — under --script it is not compile-visible,
## so the roster checks instantiate settings_store.gd fresh via load() (pure state math).
## Run: & $godot --headless --path . --script res://tests/test_companion_library.gd

const Library := preload("res://game/companion/companion_library.gd")

var _fails := 0

func _init() -> void:
	_test_art()
	_test_info()
	_test_no_steal()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_art() -> void:
	for kind in Library.ART:
		var row: Dictionary = Library.ART[kind]
		var frames := row["frames"] as SpriteFrames
		_check("kind %d frames load" % kind, frames != null and frames.get_animation_names().size() > 0)
		_check("kind %d anims load" % kind, row["anims"] != null)
		_check("kind %d integer scale" % kind, is_equal_approx(float(row["scale"]), 1.0))

func _test_info() -> void:
	const VERBLESS := [2]   # otter: verb lands with slice 6
	for kind in Library.ART:
		var info := Library.info(kind)
		_check("kind %d has info" % kind, not info.is_empty())
		_check("kind %d name" % kind, info.get("name", "") != "")
		_check("kind %d species" % kind, info.get("species", "") != "")
		if not kind in VERBLESS:
			_check("kind %d verb_name" % kind, info.get("verb_name", "") != "")
			_check("kind %d verb_teach" % kind, info.get("verb_teach", "") != "")
	_check("unknown kind -> empty", Library.info(99).is_empty())

func _test_no_steal() -> void:
	var s: Node = (load("res://game/hud/settings_store.gd") as GDScript).new()
	s.roster_add(0)
	_check("first rescue claims the empty slot", s.run_active == 0)
	s.roster_add(1)
	_check("second rescue joins the roster", s.run_roster.size() == 2 and s.run_roster[0] == 0 and s.run_roster[1] == 1)
	_check("D-0019: second rescue does NOT steal active", s.run_active == 0)
	s.roster_add(1)
	_check("re-rescue is idempotent", s.run_roster.size() == 2 and s.run_active == 0)
	s.free()
