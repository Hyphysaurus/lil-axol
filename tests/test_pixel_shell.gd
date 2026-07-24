extends SceneTree
## Headless tests for the slice-3 pixel-shell layout math (pure — no scene needed).
## BASE is the 640x360 EFFECT grid (2026-07-24 retune): the camera runs x2 on top, so the
## world framing matches the original 320x180 shell while effects render twice as fine.
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
	_check("720p: scale 2", l["scale"] == 2)
	_check("720p: view 640x360", l["view"] == Vector2i(640, 360))
	l = Shell.compute_layout(Vector2i(1920, 1080))
	_check("1080p: scale 3", l["scale"] == 3)
	_check("1080p: view 640x360", l["view"] == Vector2i(640, 360))

func _test_expand() -> void:
	# phone landscape: 844x390 -> k = min(1.32, 1.08) floored = 1, view = window
	var l := Shell.compute_layout(Vector2i(844, 390))
	_check("phone: scale 1", l["scale"] == 1)
	_check("phone: view 844x390", l["view"] == Vector2i(844, 390))
	# just above a scale step: k=2, view expands to fill the remainder
	l = Shell.compute_layout(Vector2i(1400, 800))
	_check("above-step: scale 2", l["scale"] == 2)
	_check("above-step: view 700x400", l["view"] == Vector2i(700, 400))
	# non-divisible: 2000x1200 -> k=3, view = ceil(2000/3)=667 x 400
	l = Shell.compute_layout(Vector2i(2000, 1200))
	_check("nondiv: scale 3", l["scale"] == 3)
	_check("nondiv: view 667x400", l["view"] == Vector2i(667, 400))

func _test_degenerate() -> void:
	# headless server / zero window: neutral shell, never crash, never scale 0
	var l := Shell.compute_layout(Vector2i(0, 0))
	_check("zero: scale 1", l["scale"] == 1)
	_check("zero: view = BASE", l["view"] == Shell.BASE)
	# window smaller than base: k=1, view = window (shows less world, never upscale-blurs)
	l = Shell.compute_layout(Vector2i(600, 340))
	_check("tiny: scale 1", l["scale"] == 1)
	_check("tiny: view 600x340", l["view"] == Vector2i(600, 340))
