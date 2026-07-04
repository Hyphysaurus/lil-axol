extends CanvasLayer
## Touch controls for iPad/phones. A floating joystick on the LEFT half drives the move_*
## actions (analog strength, full deflection = run); a fan of hold buttons on the RIGHT drives
## spray / jump / dash / bubble, plus two small corner taps for the pause menu and a new day.
## Everything goes through Input.action_press, so the axolotl and NewDay read touch exactly like
## the keyboard — zero gameplay code knows touch exists. Hidden automatically on machines without
## a touchscreen. Code-built overlay in the new_day idiom: no scene nodes, no textures, drawn on
## the Sweetie 16 palette so it matches the whole game's procedural look — and drawn HIGH-CONTRAST
## (frosted bodies + dark backing discs + labels) so it actually reads on a bright cove.

const STICK_RADIUS := 74.0      # max knob travel from the joystick origin
const STICK_DEAD := 0.22        # deflection below this releases the movement actions
const RUN_AT := 0.9             # deflection above this also holds "run"
const HIT_SLOP := 1.15          # forgiving hit radius multiplier (kept < button spacing so taps don't cross)
const DRAG_START := 12.0        # a left-half finger must travel this far to become the joystick; a
                                # shorter press-and-release is read as a tap = a turtle command

## Short caps drawn under each button so the control reads at a glance (the font has plain Latin).
const LABELS := {
	"spray": "SPRAY", "jump": "JUMP", "dash": "DASH",
	"bubble": "BOMB", "menu": "MENU", "restart": "DAY",
}

## Force the overlay on for desktop testing (pair with emulate_touch_from_mouse).
@export var force_visible := false

var _canvas: TouchCanvas
var _stick_id := -1             # finger owning the joystick (-1 = none)
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO  # deflection, unit-clamped
var _pending_id := -1           # a left-half finger that hasn't dragged yet — a tap or a nascent stick
var _pending_origin := Vector2.ZERO
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
	_pending_id = -1                # a forced release must NOT fire a turtle command
	for action in _held.keys():
		Input.action_release(action)
	_held.clear()
	_sync()

## We consume every touch WE act on (button hit, joystick spawn/drag, owned release) so it can't
## fall through to the turtle's point-and-click command. Touches on open water are left alone —
## those reach the companion as a "go demolish there" command (see companion._unhandled_input).
func _input(event: InputEvent) -> void:
	var used := false
	if event is InputEventScreenTouch:
		if event.pressed:
			used = _touch_down(event.index, event.position)
		else:
			used = _touch_up(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_stick_move(event.position)
			used = true
		elif event.index == _pending_id:
			if _pending_origin.distance_to(event.position) > DRAG_START:
				_promote_pending(event.position)   # travelled far enough — it's really the joystick
			used = true
	if used:
		get_viewport().set_input_as_handled()

## Returns true if we claimed this touch (a button, or a left-half movement/tap finger). The LEFT
## half is movement territory; the first finger there is PENDING — it neither moves the axolotl nor
## shows a ring, so a quick release reads as a tap = a turtle command, while a real drag promotes it
## to the joystick. Any left-half touch is consumed so it can't leak a stray command; the RIGHT half
## is left alone → open-water taps there reach the turtle command in companion._unhandled_input.
func _touch_down(id: int, pos: Vector2) -> bool:
	var btns := _buttons()
	for action in btns:
		if pos.distance_to(btns[action][0]) <= btns[action][1] * HIT_SLOP:
			if action == "menu":
				_fire_menu()          # the pause card listens for the "menu" event, not a held state
			else:
				_held[action] = id
				Input.action_press(action)
			_sync()
			return true
	if pos.x < _canvas.size.x * 0.5:
		if _stick_id == -1 and _pending_id == -1:
			_pending_id = id
			_pending_origin = pos
		return true                   # consume even a 2nd left finger — never a command
	return false

## Returns true if the lifted finger was one we owned (stick, a pending tap, or a held button).
func _touch_up(id: int) -> bool:
	var used := false
	if id == _stick_id:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		_apply_stick()
		used = true
	elif id == _pending_id:
		_command_at(_pending_origin)  # a left-half finger that never dragged = a tap = send the turtle
		_pending_id = -1
		used = true
	for action in _held.keys():
		if _held[action] == id:
			_held.erase(action)
			Input.action_release(action)
			used = true
	_sync()
	return used

## A pending left-half finger travelled far enough — it's the joystick, not a tap.
func _promote_pending(pos: Vector2) -> void:
	_stick_id = _pending_id
	_stick_origin = _pending_origin
	_pending_id = -1
	_stick_move(pos)

## Route a left-half tap to the turtle: convert the screen point to world and hand it to the
## companion via its group, so this layer stays decoupled from the turtle node.
func _command_at(screen_pos: Vector2) -> void:
	var world := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	get_tree().call_group("companion", "command_to", world)

## The pause/settings card opens on the "menu" action arriving as an EVENT (its _unhandled_input),
## so a plain Input.action_press won't reach it — synthesize the action. Press AND release so the
## action can't latch pressed in the Input singleton (the card only reacts to the press edge).
func _fire_menu() -> void:
	_menu_event(true)
	_menu_event(false)

func _menu_event(pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = &"menu"
	ev.pressed = pressed
	Input.parse_input_event(ev)

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

## Button layout, computed from the live canvas size: action -> [center, radius]. A thumb-fan in
## the bottom-right (spray is the primary verb, so it's biggest + closest to the corner), plus two
## small taps in the top-right for the pause menu and a fresh day. Spacing keeps the forgiving hit
## areas from crossing.
func _buttons() -> Dictionary:
	var s := _canvas.size
	return {
		"spray":   [Vector2(s.x - 88.0, s.y - 96.0), 52.0],
		"jump":    [Vector2(s.x - 202.0, s.y - 80.0), 44.0],
		"dash":    [Vector2(s.x - 214.0, s.y - 188.0), 40.0],
		"bubble":  [Vector2(s.x - 100.0, s.y - 206.0), 42.0],
		"menu":    [Vector2(s.x - 48.0, 48.0), 26.0],
		"restart": [Vector2(s.x - 112.0, 48.0), 26.0],
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
	var stick_on := false
	var stick_origin := Vector2.ZERO
	var stick_knob := Vector2.ZERO
	var stick_r := 74.0
	var btns := []   # [center, radius, held, action-name glyph key]

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		# --- floating joystick ---
		if stick_on:
			draw_circle(stick_origin, stick_r, Color(Palette.INK, 0.30))            # dark backing reads over any water
			draw_arc(stick_origin, stick_r, 0.0, TAU, 48, Color(Palette.FOAM, 0.6), 3.0, true)
			draw_circle(stick_knob, 30.0, Color(Palette.CYAN, 0.6))                 # the thumb knob
			draw_arc(stick_knob, 30.0, 0.0, TAU, 32, Color(Palette.FOAM, 0.95), 2.5, true)
		# --- action buttons ---
		for b in btns:
			var c: Vector2 = b[0]
			var r: float = b[1]
			var held: bool = b[2]
			var action: String = b[3]
			draw_circle(c, r + 3.0, Color(Palette.INK, 0.36))                       # backing disc = contrast anchor
			var fill: Color = Palette.CYAN if action == "spray" else Palette.FOAM   # spray (primary) pops cyan
			draw_circle(c, r, Color(fill, 0.44 if held else 0.24))                  # frosted body, brighter when held
			draw_arc(c, r, 0.0, TAU, 40, Color(Palette.FOAM, 0.95 if held else 0.72), 3.0, true)
			var ink := Color(0.98, 0.99, 1.0, 0.95 if held else 0.82)
			_glyph(action, c, ink)
			if font:                                                                # a plain-language cap under the icon
				var txt: String = LABELS.get(action, "")
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
				draw_string(font, c + Vector2(-w * 0.5, r + 16.0), txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(Palette.FOAM, 0.9))

	## Each button's pictogram, drawn bright over the frosted body.
	func _glyph(action: String, c: Vector2, ink: Color) -> void:
		match action:
			"jump":     # chevron up
				draw_polyline([c + Vector2(-12, 6), c + Vector2(0, -8), c + Vector2(12, 6)], ink, 3.0, true)
			"spray":    # three spray streaks fanning right
				for i in 3:
					var d := Vector2.from_angle(-0.45 + 0.45 * i)
					draw_line(c + d * 4.0 + Vector2(-8, 0), c + d * 16.0 + Vector2(-4, 0), ink, 3.0, true)
			"dash":     # a double chevron (»), speed lines to the right
				for k in 2:
					var ox := -6.0 + k * 10.0
					draw_polyline([c + Vector2(ox - 5, -9), c + Vector2(ox + 5, 0), c + Vector2(ox - 5, 9)], ink, 3.0, true)
			"bubble":   # a bubble with its highlight
				draw_arc(c, 12.0, 0.0, TAU, 24, ink, 3.0, true)
				draw_arc(c, 7.0, -2.2, -1.2, 8, ink, 2.0, true)
			"menu":     # three stacked bars (a pause/menu glyph)
				for k in 3:
					var y := -7.0 + k * 7.0
					draw_line(c + Vector2(-10, y), c + Vector2(10, y), ink, 3.0, true)
			"restart":  # circular arrow (hold for a new day)
				draw_arc(c, 10.0, -PI * 0.35, PI * 1.15, 24, ink, 3.0, true)
				var tip := c + Vector2.from_angle(-PI * 0.35) * 10.0
				draw_polyline([tip + Vector2(-5, -3), tip, tip + Vector2(2, -6)], ink, 3.0, true)
