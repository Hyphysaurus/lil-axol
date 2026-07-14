extends SceneTree
## Headless tests for WorldState (run BEFORE the autoload exists -> first run must FAIL to load).
## Run: & $godot --headless --path $proj --script res://tests/test_world_state.gd
## Prints one line per case; exits 1 on any failure (CI-friendly).

const WS := preload("res://game/world/world_state.gd")

var _fails := 0

func _init() -> void:
	_test_fresh_defaults()
	_test_round_trip()
	_test_corrupt_quarantine()
	_test_new_tide()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _fresh(path: String) -> Node:
	# instantiate directly (no tree, no _ready) and load explicitly — same code path the game uses
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs)
	if FileAccess.file_exists(path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")
	var ws: Node = WS.new()
	ws.save_path = path
	ws.load_file()
	return ws

func _test_fresh_defaults() -> void:
	var ws := _fresh("user://test_ws_fresh.save")
	_check("fresh: not restored", ws.is_restored("hub") == false)
	_check("fresh: default returned", float(ws.get_cove("hub", "cleanliness", 0.25)) == 0.25)
	ws.free()

func _test_round_trip() -> void:
	var path := "user://test_ws_round.save"
	var a := _fresh(path)
	a.mark("hub", "restored", true)
	a.mark("hub", "cleanliness", 0.42)
	a.mark("estuary", "friend_awake", true)
	a.free()
	var b: Node = WS.new()
	b.save_path = path
	b.load_file()
	_check("round: restored persists", b.is_restored("hub"))
	_check("round: float persists", absf(float(b.get_cove("hub", "cleanliness", 0.0)) - 0.42) < 0.001)
	_check("round: other cove isolated", b.is_restored("estuary") == false)
	_check("round: other cove key persists", bool(b.get_cove("estuary", "friend_awake", false)))
	b.free()

## NEW TIDE (title screen): has_progress drives the continue/new-tide split; wipe() washes the
## save away and leaves a fresh, versioned store.
func _test_new_tide() -> void:
	var path := "user://test_ws_tide.save"
	var ws := _fresh(path)
	_check("tide: fresh world has no progress", ws.has_progress() == false)
	ws.mark("canals", "seal_2", true)
	_check("tide: a mark counts as progress", ws.has_progress())
	ws.wipe()
	_check("tide: wipe clears progress", ws.has_progress() == false)
	_check("tide: wipe removes the file", FileAccess.file_exists(path) == false)
	_check("tide: wiped store still answers defaults", ws.is_restored("canals") == false)
	ws.mark("canals", "seal_2", true)
	_check("tide: world records again after the wipe", ws.has_progress())
	ws.free()

func _test_corrupt_quarantine() -> void:
	var path := "user://test_ws_bad.save"
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path + ".bad"):
		DirAccess.remove_absolute(abs + ".bad")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[unclosed section\nkey=\"")   # genuinely unparseable INI (an open bracket + dangling quote)
	f.close()
	var ws: Node = WS.new()
	ws.save_path = path
	ws.load_file()                       # must not crash
	_check("corrupt: defaults after quarantine", ws.is_restored("hub") == false)
	_check("corrupt: .bad backup exists", FileAccess.file_exists(path + ".bad"))
	ws.mark("hub", "restored", true)     # store still writable after quarantine
	_check("corrupt: writable after quarantine", ws.is_restored("hub"))
	ws.free()
	# a SECOND corruption must quarantine again (Windows rename won't overwrite an existing .bad —
	# the code must clear the old backup first)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[unclosed section\nkey=\"")
	f.close()
	var ws2: Node = WS.new()
	ws2.save_path = path
	ws2.load_file()
	_check("corrupt: repeat quarantine still defaults", ws2.is_restored("hub") == false)
	_check("corrupt: repeat quarantine keeps .bad", FileAccess.file_exists(path + ".bad"))
	ws2.free()
