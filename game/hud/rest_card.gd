extends CanvasLayer
## Rest card — Esc / pad Start ("menu" action) pauses the tree over the living cove:
## resume / settings / new day / quit. PROCESS_MODE_ALWAYS so it runs while paused; the
## Sfx autoload is ALWAYS too, so menu sounds survive the pause. "New day" reuses NewDay's
## fade-to-black restart via the new_day group — one restart routine for the whole game.

var _open := false
var _root: Control
var _first_btn: Button

func _ready() -> void:
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		return
	var menu := get_node_or_null("../SettingsMenu")
	if menu and menu.visible:
		return                          # settings owns esc; it closes itself
	if not _open and Settings.ui_locked():
		return                          # title veil (or another menu) is up
	_toggle(not _open)
	get_viewport().set_input_as_handled()

func _toggle(on: bool) -> void:
	if on == _open:
		return
	_open = on
	_root.visible = on
	get_tree().paused = on
	if on:
		Settings.push_ui_lock()
		Sfx.loop("spray", false)        # physics can't release a held loop once frozen
		Sfx.play("scrub", -12.0, 1.3)
		_first_btn.grab_focus()         # pad/keyboard can navigate from here
	else:
		Settings.pop_ui_lock()

func _resume() -> void:
	_toggle(false)

func _open_settings() -> void:
	var menu := get_node_or_null("../SettingsMenu")
	if menu:
		menu.open()

func _open_credits() -> void:
	var c := get_node_or_null("../CreditsCard")
	if c:
		c.open()

func _new_day() -> void:
	_toggle(false)                      # unpause first so the fade can run
	var nd := get_tree().get_first_node_in_group("new_day")
	if nd and nd.has_method("start"):
		nd.start()

func _quit() -> void:
	get_tree().quit()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.55)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(240.0, 0.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.14, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18.0)
	style.border_color = Color(0.70, 0.85, 0.90, 0.25)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var head := Label.new()
	head.text = "resting…"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(0.95, 0.99, 1.0))
	vb.add_child(head)

	_first_btn = _button("resume", _resume)
	vb.add_child(_first_btn)
	vb.add_child(_button("settings", _open_settings))
	vb.add_child(_button("credits", _open_credits))
	vb.add_child(_button("new day", _new_day))
	if not OS.has_feature("web"):
		vb.add_child(_button("quit", _quit))

func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200.0, 36.0)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(on_pressed)
	return b
