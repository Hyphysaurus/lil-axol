extends CanvasLayer
## Settings overlay — audio / controls / visual tabs, code-built in the project's idiom.
## Opened from the title card or the rest card (works over the rest card's pause via
## PROCESS_MODE_ALWAYS). All state lives in the Settings autoload; this is pure view.
## Rebinding: click a binding button, press the new key (or pad input for the pad column);
## esc cancels the capture, last-write-wins, no conflict detection in v1.

const INK := Color(0.95, 0.99, 1.0)
const DIM_INK := Color(0.70, 0.85, 0.90)
const ACTION_LABELS := {
	"move_left": "move left", "move_right": "move right", "move_up": "up / float",
	"move_down": "down / dive", "jump": "jump", "run": "run", "spray": "spray",
	"dash": "dash", "bubble": "bubble bomb", "restart": "new day (hold)",
}

var _root: Control
var _sliders := {}            # bus name -> HSlider
var _checks := {}             # visual key -> CheckButton
var _touch_mode: OptionButton
var _rows := {}               # action -> {key: Button, pad: Button}
var _capture_btn: Button      # non-null while waiting for a rebind press
var _capture_action := ""
var _capture_pad := false

func _ready() -> void:
	layer = 99                 # over title (97) / rest card (97), under PostFX (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func open() -> void:
	if visible:
		return
	visible = true
	Settings.push_ui_lock()
	Sfx.play("ui_open", -6.0)
	_refresh_all()
	if _sliders.has("Master"):
		_sliders["Master"].grab_focus.call_deferred()   # pad/keyboard entry point

func close() -> void:
	if not visible:
		return
	_cancel_capture()
	Settings.flush()   # keyboard-nudged sliders never fire drag_ended; persist on the way out
	visible = false
	Settings.pop_ui_lock()

## _input (not _unhandled) so an in-progress rebind capture wins over every other consumer.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _capture_btn:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
			_cancel_capture()
			get_viewport().set_input_as_handled()
		elif _try_capture(event):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()

# --- rebinding ---

func _start_capture(action: String, pad: bool, btn: Button) -> void:
	_cancel_capture()
	_capture_btn = btn
	_capture_action = action
	_capture_pad = pad
	btn.text = "press…"

func _cancel_capture() -> void:
	if _capture_btn:
		_capture_btn = null
		_refresh_bindings()

func _try_capture(event: InputEvent) -> bool:
	var ev: InputEvent = null
	if _capture_pad:
		if event is InputEventJoypadButton and event.pressed:
			ev = InputEventJoypadButton.new()
			ev.button_index = event.button_index
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
			ev = InputEventJoypadMotion.new()
			ev.axis = event.axis
			ev.axis_value = signf(event.axis_value)
	elif event is InputEventKey and event.pressed and not event.echo:
		ev = InputEventKey.new()
		ev.physical_keycode = event.physical_keycode
	if ev == null:
		return false
	ev.device = -1                     # match any device, like the authored bindings
	# swap out this device-type's old events; the other column's bindings survive
	for old in InputMap.action_get_events(_capture_action):
		var old_pad := old is InputEventJoypadButton or old is InputEventJoypadMotion
		if old_pad == _capture_pad:
			InputMap.action_erase_event(_capture_action, old)
	InputMap.action_add_event(_capture_action, ev)
	Settings.save_bindings()
	_capture_btn = null
	_refresh_bindings()
	Sfx.play("scrub", -12.0, 1.5)
	return true

func _binding_text(action: String, pad: bool) -> String:
	for e in InputMap.action_get_events(action):
		if pad:
			if e is InputEventJoypadButton:
				return "pad %d" % e.button_index
			if e is InputEventJoypadMotion:
				return "axis %d %s" % [e.axis, "+" if e.axis_value > 0.0 else "−"]
		elif e is InputEventKey:
			return e.as_text().trim_suffix(" (Physical)")
	return "—"

func _reset_bindings() -> void:
	_cancel_capture()
	Settings.reset_bindings()
	_refresh_bindings()

# --- refresh (view <- Settings), signals blocked so refresh never re-saves ---

func _refresh_all() -> void:
	for bus in _sliders:
		_sliders[bus].set_value_no_signal(Settings.bus_volume(bus))
	for key in _checks:
		_checks[key].set_pressed_no_signal(Settings.get_setting("visual", key, key != "fullscreen"))
	_touch_mode.select(Settings.get_setting("controls", "touch_mode", 0))
	_refresh_bindings()

func _refresh_bindings() -> void:
	for action in _rows:
		_rows[action]["key"].text = _binding_text(action, false)
		_rows[action]["pad"].text = _binding_text(action, true)

# --- construction ---

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
	panel.custom_minimum_size = Vector2(560.0, 430.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UiTheme.panel())   # shared watery/cozy theme
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var head := Label.new()
	head.text = "settings"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", INK)
	vb.add_child(head)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# switching tabs mid-rebind would leave the capture armed on a now-hidden row
	tabs.tab_changed.connect(func(_tab: int) -> void: _cancel_capture())
	vb.add_child(tabs)
	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_controls_tab())
	tabs.add_child(_build_visual_tab())

	var foot := Label.new()
	foot.text = "esc closes"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 18)
	foot.add_theme_color_override("font_color", Color(DIM_INK, 0.7))
	vb.add_child(foot)

func _build_audio_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "audio"
	box.add_theme_constant_override("separation", 12)
	box.add_child(_spacer(4.0))
	for bus in Settings.BUSES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		row.add_child(_row_label(bus.to_lower(), 110.0))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# live-apply while dragging, hit the disk only on release
		slider.value_changed.connect(func(v: float) -> void: Settings.set_bus_volume(bus, v, false))
		slider.drag_ended.connect(func(_changed: bool) -> void: Settings.flush())
		row.add_child(slider)
		_sliders[bus] = slider
	return box

func _build_controls_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "controls"
	box.add_theme_constant_override("separation", 6)

	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 12)
	box.add_child(touch_row)
	touch_row.add_child(_row_label("touch controls", 150.0))
	_touch_mode = OptionButton.new()
	for opt in ["auto", "always on", "off"]:
		_touch_mode.add_item(opt)
	_touch_mode.item_selected.connect(func(i: int) -> void:
		Settings.set_setting("controls", "touch_mode", i)
		Sfx.play("ui_toggle", -8.0))
	touch_row.add_child(_touch_mode)

	box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for action in Settings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		row.add_child(_row_label(ACTION_LABELS.get(action, action), 170.0))
		var key_btn := _bind_button()
		key_btn.pressed.connect(func() -> void: _start_capture(action, false, key_btn))
		row.add_child(key_btn)
		var pad_btn := _bind_button()
		pad_btn.pressed.connect(func() -> void: _start_capture(action, true, pad_btn))
		row.add_child(pad_btn)
		_rows[action] = {"key": key_btn, "pad": pad_btn}

	var reset := Button.new()
	reset.text = "reset to defaults"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_reset_bindings)
	box.add_child(reset)
	return box

func _build_visual_tab() -> Control:
	var box := VBoxContainer.new()
	box.name = "visual"
	box.add_theme_constant_override("separation", 10)
	box.add_child(_spacer(4.0))
	for entry in [["fullscreen", "fullscreen"], ["vsync", "v-sync"],
			["grain", "film grain"], ["vignette", "vignette"]]:
		var key: String = entry[0]
		var check := CheckButton.new()
		check.text = entry[1]
		check.toggled.connect(func(on: bool) -> void:
			Settings.set_setting("visual", key, on)
			Sfx.play("ui_toggle", -8.0))
		box.add_child(check)
		_checks[key] = check
	return box

func _bind_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(130.0, 30.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _row_label(text: String, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0.0)
	l.add_theme_color_override("font_color", DIM_INK)
	return l

func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	return s
