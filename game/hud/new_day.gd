extends CanvasLayer
## "New Day" — the game's whole reset/progression system. Hold the restart action (R) to
## fill a small ring; releasing cancels (the ring drains fast, no penalty). A full ring
## fades the screen to black and reloads the scene: fresh spill, fresh morning. Available
## at any time, not just after restoration — the post-win subline merely teaches it.
## Code-built overlay in the restoration_banner idiom; reads action state in _process and
## never consumes input events, so it can't interfere with movement or spray.

const HOLD_SECONDS := 0.8
const DRAIN_SPEED := 3.0        # released ring drains ~3x faster than it fills
const FADE_TO_BLACK := 2.2      # blackout alpha/sec once triggered (~0.45s to dark)

var _ring: Ring
var _blackout: ColorRect
var _hold_t := 0.0
var _restarting := false
var _black := 0.0

func _ready() -> void:
	layer = 96                  # above the banner (95), below PostFX (100)
	add_to_group("new_day")     # the rest card's "new day" button finds us here
	_build()

## Kick the fade-to-black reload from UI (shared restart routine — rest card uses this).
func start() -> void:
	_restarting = true

func _process(delta: float) -> void:
	if _restarting:
		_black = move_toward(_black, 1.0, delta * FADE_TO_BLACK)
		_blackout.color.a = _black
		if _black >= 1.0:
			set_process(false)  # one reload only; this node dies with the old scene
			get_tree().reload_current_scene()
		return
	if not InputMap.has_action("restart"):
		return                  # keeps the scene runnable if the action isn't migrated yet
	if Input.is_action_pressed("restart") and not Settings.ui_locked():
		_hold_t = minf(HOLD_SECONDS, _hold_t + delta)
		if _hold_t >= HOLD_SECONDS:
			_restarting = true
	else:
		_hold_t = move_toward(_hold_t, 0.0, delta * HOLD_SECONDS * DRAIN_SPEED)
	_ring.progress = _hold_t / HOLD_SECONDS

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat input
	add_child(root)

	_ring = Ring.new()
	_ring.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ring.offset_left = -24.0
	_ring.offset_right = 24.0
	_ring.offset_top = -120.0
	_ring.offset_bottom = -72.0
	root.add_child(_ring)

	_blackout = ColorRect.new()
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.color = Color(0.02, 0.03, 0.05, 0.0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_blackout)

## Hold-progress ring, drawn in code: faint full track + bright fill arc from 12 o'clock.
## Pops in quickly at the start of a hold and vanishes when drained.
class Ring extends Control:
	var progress := 0.0:
		set(v):
			if not is_equal_approx(progress, v):
				progress = v
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if progress <= 0.0:
			return
		var c := size / 2.0
		var r := minf(c.x, c.y) - 3.0
		var vis := clampf(progress * 3.0, 0.0, 1.0)   # quick pop-in, fades out with the drain
		draw_arc(c, r, 0.0, TAU, 40, Color(0.9, 0.97, 1.0, 0.18 * vis), 3.0, true)
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * progress, 40,
			Color(0.95, 0.99, 1.0, 0.85 * vis), 3.0, true)
