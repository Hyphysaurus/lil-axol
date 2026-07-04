extends CanvasLayer
## Credits — a scrollable overlay reached from the title veil and the rest card. Code-built in
## the same idiom as the other overlays (settings/rest card) so the coming UI restyle can
## theme them all together. Opens via open(), holds a UI lock while up, closes on esc/button.
## The credit text lives in one CREDITS block below (content, not logic) so it's easy to edit.

## bbcode credits — [center]/[b]/[color] format a RichTextLabel. Edit freely; it's just text.
const CREDITS := "[center][color=#ffdd8c]~ Lil Axolotl: Tidekeeper ~[/color]

a game by [b]Mario Alberto Ramirez[/b]
(Hyphysaurus)


[color=#9fd8e0]ENGINE[/color]
Godot 4.7


[color=#9fd8e0]ART[/color]
Axolotl — SeethingSwarm
Fish — Smolque (Pixel Fish Pack)
World, water & sky — procedural shaders
Red oil barrel — pixel practice


[color=#9fd8e0]AUDIO[/color]
Theme — synthesized for LilAxol
SFX — Helton Yan · TomMusic · SwishSwoosh
Typeface — “Axolotl”


[color=#9fd8e0]BUILT WITH[/color]
Claude Code


for my friends  🌊[/center]"

var _root: Control

func _ready() -> void:
	layer = 98                 # over the rest card (97), under the settings menu (99)
	process_mode = Node.PROCESS_MODE_ALWAYS   # works over the rest card's pause
	_build()
	visible = false

func open() -> void:
	if visible:
		return
	visible = true
	Settings.push_ui_lock()
	Sfx.play("ui_open", -6.0)

func close() -> void:
	if not visible:
		return
	visible = false
	Settings.pop_ui_lock()

func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		close()
		get_viewport().set_input_as_handled()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.6)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360.0, 440.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UiTheme.panel())   # shared watery/cozy theme
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	# scrollable body so longer credit lists still fit any screen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_color_override("default_color", Color(0.9, 0.95, 1.0))
	text.text = CREDITS
	scroll.add_child(text)

	var close_btn := Button.new()
	close_btn.text = "back"
	close_btn.custom_minimum_size = Vector2(160.0, 36.0)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 18)
	UiTheme.style_button(close_btn)
	close_btn.pressed.connect(close)
	vb.add_child(close_btn)
