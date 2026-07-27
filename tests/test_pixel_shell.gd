extends SceneTree
## Headless tests for the slice-3 pixel-shell layout math (pure — no scene needed).
## BASE is the 640x360 EFFECT grid (2026-07-24 retune): the camera runs x2 on top, so the
## world framing matches the original 320x180 shell while effects render twice as fine.
## Run: & $godot --headless --path . --script res://tests/test_pixel_shell.gd
##
## AUTOLOAD TRAP (fixed 2026-07-26): this suite used a top-level
## `const Shell := preload("res://game/fx/pixel_shell.gd")`, which stopped compiling the moment
## pixel_shell.gd:39 started reading the `Settings` autoload (commit 0e08050, the touch-grid perf
## pass). Under `--headless --script` autoload identifiers are not compile-visible that early, so
## the preload yielded a broken script, EVERY _test_* aborted on its first call, `_fails` stayed 0
## — and the suite printed "ALL PASS" while running zero checks for three commits. Same trap
## documented at tests/test_reach_map.gd:3-17. Cure: run the body from the first _process()
## callback (autoloads are live by then) and load() the script lazily. The RESULT line now carries
## the executed-check count so a silently-empty suite can never read as green again.

var _fails := 0
var _checks := 0
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var Shell = load("res://game/fx/pixel_shell.gd")
	_test_exact_fit(Shell)
	_test_expand(Shell)
	_test_degenerate(Shell)
	print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
	quit(1 if _fails > 0 else 0)
	return true

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _test_exact_fit(Shell) -> void:
	var l = Shell.compute_layout(Vector2i(1280, 720))
	_check("720p: scale 2", l["scale"] == 2)
	_check("720p: view 640x360", l["view"] == Vector2i(640, 360))
	l = Shell.compute_layout(Vector2i(1920, 1080))
	_check("1080p: scale 3", l["scale"] == 3)
	_check("1080p: view 640x360", l["view"] == Vector2i(640, 360))

func _test_expand(Shell) -> void:
	# phone landscape: 844x390 -> k = min(1.32, 1.08) floored = 1, view = window
	var l = Shell.compute_layout(Vector2i(844, 390))
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

func _test_degenerate(Shell) -> void:
	# headless server / zero window: neutral shell, never crash, never scale 0
	var l = Shell.compute_layout(Vector2i(0, 0))
	_check("zero: scale 1", l["scale"] == 1)
	_check("zero: view = BASE", l["view"] == Shell.BASE)
	# window smaller than base: k=1, view = window (shows less world, never upscale-blurs)
	l = Shell.compute_layout(Vector2i(600, 340))
	_check("tiny: scale 1", l["scale"] == 1)
	_check("tiny: view 600x340", l["view"] == Vector2i(600, 340))
	# the touch grid takes an explicit base (perf pass 0e08050) - 320x180 fits 1280x720 at k=4
	l = Shell.compute_layout(Vector2i(1280, 720), Shell.BASE_TOUCH)
	_check("touch base: scale 4", l["scale"] == 4)
	_check("touch base: view 320x180", l["view"] == Vector2i(320, 180))
