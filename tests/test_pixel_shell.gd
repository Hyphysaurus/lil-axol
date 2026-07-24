extends SceneTree
## Headless tests for the slice-3 pixel-shell layout math (pure — no scene needed).
## Run: & $godot --headless --path . --script res://tests/test_pixel_shell.gd

const Shell := preload("res://game/fx/pixel_shell.gd")

var _fails := 0

func _init() -> void:
	_test_exact_fit()
	_test_expand()
	_test_degenerate()
	print("RESULT: %s" % ("FAIL x%d" % _fails if _fails > 0 else "ALL PASS"))
	quit(1 if _fails > 0 else 0)

func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_exact_fit() -> void:
	var l := Shell.compute_layout(Vector2i(1280, 720))
	_check("720p: scale 4", l["scale"] == 4)
	_check("720p: view 320x180", l["view"] == Vector2i(320, 180))
	l = Shell.compute_layout(Vector2i(1920, 1080))
	_check("1080p: scale 6", l["scale"] == 6)
	_check("1080p: view 320x180", l["view"] == Vector2i(320, 180))

func _test_expand() -> void:
	# phone landscape: 844x390 -> k = min(2.6, 2.16) floored = 2, view expands to fill
	var l := Shell.compute_layout(Vector2i(844, 390))
	_check("phone: scale 2", l["scale"] == 2)
	_check("phone: view 422x195", l["view"] == Vector2i(422, 195))
	# just under a scale step: k=1, view = window (bigger than base on x, y)
	l = Shell.compute_layout(Vector2i(639, 359))
	_check("under-step: scale 1", l["scale"] == 1)
	_check("under-step: view 639x359", l["view"] == Vector2i(639, 359))
	# non-divisible: 1000x600 -> k=3, view = ceil(1000/3)=334 x 200
	l = Shell.compute_layout(Vector2i(1000, 600))
	_check("nondiv: scale 3", l["scale"] == 3)
	_check("nondiv: view 334x200", l["view"] == Vector2i(334, 200))

func _test_degenerate() -> void:
	# headless server / zero window: neutral shell, never crash, never scale 0
	var l := Shell.compute_layout(Vector2i(0, 0))
	_check("zero: scale 1", l["scale"] == 1)
	_check("zero: view = BASE", l["view"] == Shell.BASE)
	# window smaller than base: k=1, view = window (shows less world, never upscale-blurs)
	l = Shell.compute_layout(Vector2i(300, 200))
	_check("tiny: scale 1", l["scale"] == 1)
	_check("tiny: view 300x200", l["view"] == Vector2i(300, 200))
