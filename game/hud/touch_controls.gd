extends CanvasLayer
## Touch controls for iPad/phones. A floating joystick on the left half drives the
## move_* actions (analog strength, full deflection = run); hold buttons on the right
## drive jump / spray / restart. Everything goes through Input.action_press, so the
## axolotl and NewDay read touch exactly like the keyboard — zero gameplay code knows
## touch exists. Hidden automatically on machines without a touchscreen.
## Code-built overlay in the new_day idiom: no scene nodes, no textures, drawn arcs.

const STICK_RADIUS := 68.0      # max knob travel from the joystick origin
const STICK_DEAD := 0.22        # deflection below this releases the movement actions
const RUN_AT := 0.9             # deflection above this also holds "run"
const BTN_R := 44.0             # jump/spray button radius
const RESTART_R := 26.0         # small corner "new day" button radius

## Force the overlay on for desktop testing (pair with emulate_touch_from_mouse).
@export var force_visible := false

var _canvas: TouchCanvas
var _stick_id := -1             # finger owning the joystick (-1 = none)
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO  # deflection, unit-clamped
var _held := {}                 # action name -> finger id, for the hold buttons

func _ready() -> void:
	layer = 90                  # under the banner (95) and NewDay (96)
	_canvas = TouchCanvas.new()
	add_child(_canvas)
	_canvas.resized.connect(_sync)   # buttons anchor to the live viewport size
	Settings.changed.connect(_refresh)
	Settings.ui_lock_changed.connect(func(_locked: bool) -> void: _refresh())
	_refresh()
	_sync.call_deferred()

## Visibility = the Settings touch mode (auto / always on / off), minus any open menu —
## menus own the whole screen, and hiding also releases anything mid-hold.
func _refresh() -> void:
	var mode: int = Settings.get_setting("controls", "touch_mode", 0)
	var on := (DisplayServer.is_touchscreen_available() or force_visible) if mode == 0 else mode == 1
	on = on and not Settings.ui_locked()
	if not on:
		_release_all()
	visible = on
	set_process_input(on)

## The Input singleton outlives scene reloads — anything still pressed when NewDay
## reloads would stay pressed forever (a held restart button = infinite reload loop).
func _exit_tree() -> void:
	_release_all()

func _release_all() -> void:
	if _stick_id != -1:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	for action in _held.keys():
		Input.action_release(action)
	_held.clear()
	_sync()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_id:
		_stick_move(event.position)

func _touch_down(id: int, pos: Vector2) -> void:
	var btns := _buttons()
	for action in btns:
		if pos.distance_to(btns[action][0]) <= btns[action][1] * 1.25:   # forgiving hit area
			_held[action] = id
			Input.action_press(action)
			_sync()
			return
	# not on a button: left side of the screen spawns the joystick under the finger
	if _stick_id == -1 and pos.x < _canvas.size.x * 0.55:
		_stick_id = id
		_stick_origin = pos
		_stick_move(pos)

func _touch_up(id: int) -> void:
	if id == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
	for action in _held.keys():
		if _held[action] == id:
			_held.erase(action)
			Input.action_release(action)
	_sync()

func _stick_move(pos: Vector2) -> void:
	_stick_vec = (pos - _stick_origin) / STICK_RADIUS
	if _stick_vec.length() > 1.0:
		_stick_vec = _stick_vec.normalized()
	_apply_stick()
	_sync()

## Translate the deflection into the same actions the keyboard presses. Strength is
## analog, so Input.get_axis in the axolotl gives gentle paddling on small tilts.
func _apply_stick() -> void:
	_axis("move_left", "move_right", _stick_vec.x)
	_axis("move_up", "move_down", _stick_vec.y)
	if _stick_vec.length() >= RUN_AT:
		Input.action_press("run")
	else:
		Input.action_release("run")

func _axis(neg: String, pos: String, v: float) -> void:
	if v <= -STICK_DEAD:
		Input.action_release(pos)
		Input.action_press(neg, remap(-v, STICK_DEAD, 1.0, 0.0, 1.0))
	elif v >= STICK_DEAD:
		Input.action_release(neg)
		Input.action_press(pos, remap(v, STICK_DEAD, 1.0, 0.0, 1.0))
	else:
		Input.action_release(neg)
		Input.action_release(pos)

## Button layout, computed from the live canvas size: action -> [center, radius].
func _buttons() -> Dictionary:
	var s := _canvas.size
	return {
		"spray": [Vector2(s.x - 76.0, s.y - 96.0), BTN_R],
		"jump": [Vector2(s.x - 186.0, s.y - 66.0), BTN_R],
		"restart": [Vector2(s.x - 44.0, 44.0), RESTART_R],
	}

## Push a draw snapshot into the renderer (it never reads back into this layer).
func _sync() -> void:
	_canvas.stick_on = _stick_id != -1
	_canvas.stick_origin = _stick_origin
	_canvas.stick_knob = _stick_origin + _stick_vec * STICK_RADIUS
	_canvas.stick_r = STICK_RADIUS
	_canvas.btns = []
	var btns := _buttons()
	for action in btns:
		_canvas.btns.append([btns[action][0], btns[action][1], _held.has(action), action])
	_canvas.queue_redraw()

## Full-rect drawing surface. mouse_filter stays IGNORE — touches are read in the
## layer's _input, so this Control can never eat events from anything else.
class TouchCanvas extends Control:
	const INK := Color(0.95, 0.99, 1.0)   # same soft white family as the NewDay ring

	var stick_on := false
	var stick_origin := Vector2.ZERO
	var stick_knob := Vector2.ZERO
	var stick_r := 68.0
	var btns := []   # [center, radius, held, action-name glyph key]

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if stick_on:
			draw_circle(stick_origin, stick_r, Color(INK, 0.06))
			draw_arc(stick_origin, stick_r, 0.0, TAU, 48, Color(INK, 0.25), 2.5, true)
			draw_circle(stick_knob, 26.0, Color(INK, 0.35))
		for b in btns:
			var c: Vector2 = b[0]
			var r: float = b[1]
			var held: bool = b[2]
			draw_circle(c, r, Color(INK, 0.22 if held else 0.09))
			draw_arc(c, r, 0.0, TAU, 40, Color(INK, 0.55 if held else 0.3), 2.5, true)
			var ink := Color(INK, 0.8 if held else 0.5)
			match b[3]:
				"jump":     # chevron up
					draw_polyline([c + Vector2(-12, 6), c + Vector2(0, -8), c + Vector2(12, 6)], ink, 3.0, true)
				"spray":    # three spray streaks fanning right
					for i in 3:
						var d := Vector2.from_angle(-0.45 + 0.45 * i)
						draw_line(c + d * 4.0 + Vector2(-8, 0), c + d * 16.0 + Vector2(-4, 0), ink, 3.0, true)
				"restart":  # circular arrow (hold for a new day)
					draw_arc(c, 10.0, -PI * 0.35, PI * 1.15, 24, ink, 3.0, true)
					var tip := c + Vector2.from_angle(-PI * 0.35) * 10.0
					draw_polyline([tip + Vector2(-5, -3), tip, tip + Vector2(2, -6)], ink, 3.0, true)
