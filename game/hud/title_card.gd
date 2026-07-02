extends CanvasLayer
## Title veil — the living cove IS the title screen. A soft dim + wordmark over the running
## world; the axolotl idles (and eventually naps) behind it. Begin with the begin button,
## jump/spray/ui_accept, or a tap. Fades out and frees itself; New Day reloads skip it via
## the session flag on the Settings autoload. Holds a UI lock so gameplay input stays neutral.

const FADE_SPEED := 1.6

var _root: Control
var _fade := 1.0
var _leaving := false

func _ready() -> void:
	layer = 97                     # over banner (95) + NewDay (96), under settings (99) + PostFX (100)
	if Settings.title_shown:
		queue_free()
		return
	Settings.push_ui_lock()
	_build()

func _process(delta: float) -> void:
	if not _leaving:
		return
	_fade = move_toward(_fade, 0.0, delta * FADE_SPEED)
	_root.modulate.a = _fade
	if _fade <= 0.0:
		set_process(false)
		Settings.title_shown = true
		Settings.pop_ui_lock()
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var menu := get_node_or_null("../SettingsMenu")
	if menu and menu.visible:
		return                      # settings is open above us; it owns input
	if event.is_action_pressed("jump") or event.is_action_pressed("spray") \
			or event.is_action_pressed("ui_accept") \
			or (event is InputEventScreenTouch and event.pressed):
		_begin()

func _begin() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("chime", -6.0, 1.25)

func _open_settings() -> void:
	var menu := get_node_or_null("../SettingsMenu")
	if menu:
		menu.open()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# soft veil: darker at the edges so the cove still glows through the middle
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.05, 0.08, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -220.0
	vb.offset_right = 220.0
	vb.offset_top = -150.0
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	_root.add_child(vb)

	var title := Label.new()
	title.text = "Lil Axolotl"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.03, 0.10, 0.16, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 3)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "~ tidekeeper ~"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55, 0.95))
	vb.add_child(sub)

	vb.add_child(_spacer(26.0))
	var begin := _button("begin", _begin)
	vb.add_child(begin)
	begin.grab_focus.call_deferred()   # pad/keyboard can navigate from here
	vb.add_child(_spacer(4.0))
	vb.add_child(_button("settings", _open_settings))
	vb.add_child(_spacer(22.0))

	var hint := Label.new()
	hint.text = "move WASD/stick · jump Space/A · spray C/X · run Shift/B"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.70, 0.85, 0.90, 0.85))
	vb.add_child(hint)

func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(on_pressed)
	return b

func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
