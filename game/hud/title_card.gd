extends CanvasLayer
## Title veil — the living cove IS the title screen. A soft dim + wordmark over the running
## world; the axolotl idles (and eventually naps) behind it. Begin with the begin button,
## jump/spray/ui_accept, or a tap. Fades out and frees itself; New Day reloads skip it via
## the session flag on the Settings autoload. Holds a UI lock so gameplay input stays neutral.

const FADE_SPEED := 1.6
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne.ttf")   # chunky rounded wordmark font

var _root: Control
var _fade := 1.0
var _leaving := false
var _new_tide: Button = null   # the wash-away button (returning worlds only); two-tap confirm
var _tide_armed := false

func _ready() -> void:
	layer = 97                     # over banner (95) + NewDay (96), under settings (99) + PostFX (100)
	if Settings.title_shown:
		queue_free()
		return
	add_to_group("title_veil")     # CoveAudio plays the cove's theme while this exists
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

## NEW TIDE, two-tap: the first press arms the button ("wash it all away?"), the second commits.
## Any other choice (continue / settings / credits) leaves the world untouched — no modal, no
## fail-state energy, just a deliberate second tap (the cozy confirm).
func _confirm_new_tide() -> void:
	if _leaving:
		return
	if not _tide_armed:
		_tide_armed = true
		_new_tide.text = "wash it all away?"
		_new_tide.add_theme_color_override("font_color", Palette.GOLD)
		Sfx.play("scrub", -12.0, 0.8)
		return
	WorldState.wipe()
	Settings.roster_reset()
	Settings.run_score = 0.0
	Settings.arrive_via_portal = false
	Settings.arrive_entry = ""
	Settings.title_shown = false        # the reloaded world greets like a first launch
	Sfx.play("splash", -4.0, 0.9)       # the tide takes it
	get_tree().reload_current_scene()

func _open_settings() -> void:
	var menu := get_node_or_null("../SettingsMenu")
	if menu:
		menu.open()

func _open_credits() -> void:
	var c := get_node_or_null("../CreditsCard")
	if c:
		c.open()

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
	title.add_theme_font_override("font", DISPLAY_FONT)   # chunky rounded wordmark, burned by the shader
	title.add_theme_font_size_override("font_size", 76)
	# the burning shader multiplies by this, so FOAM (near-white) lets the Sweetie 16 fire read true
	title.add_theme_color_override("font_color", Palette.FOAM)
	title.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 3)
	# the wordmark burns against the sky — a fire shader recolours the glyphs (see burning_text)
	var fire := ShaderMaterial.new()
	fire.shader = preload("res://shaders/burning_text.gdshader")
	title.material = fire
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "~ tidekeeper ~"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", DISPLAY_FONT)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(Palette.GOLD, 0.95))
	vb.add_child(sub)

	vb.add_child(_spacer(26.0))
	# returning tidekeeper: the world remembers, so offer the choice — continue it, or wash it
	# all away and start a new tide. A brand-new world just gets "begin".
	var returning := WorldState.has_progress()
	var first := _button("continue" if returning else "begin", _begin)
	vb.add_child(first)
	first.grab_focus.call_deferred()   # pad/keyboard can navigate from here
	if returning:
		vb.add_child(_spacer(4.0))
		_new_tide = _button("new tide", _confirm_new_tide)
		vb.add_child(_new_tide)
	vb.add_child(_spacer(4.0))
	vb.add_child(_button("settings", _open_settings))
	vb.add_child(_spacer(4.0))
	vb.add_child(_button("credits", _open_credits))
	vb.add_child(_spacer(22.0))

	var hint := Label.new()
	# show the controls that actually apply: touch wording on phones, keys on desktop/pad
	hint.text = "drag left to swim  ·  buttons to act  ·  tap open water to send your turtle" \
		if Settings.touch_active() \
		else "move WASD/stick · jump Space/A · spray C/X · run Shift/B"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(Palette.MIST, 0.85))
	vb.add_child(hint)

func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180.0, 40.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	UiTheme.style_button(b)       # shared watery/cozy button look
	b.pressed.connect(on_pressed)
	return b

func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
