extends CanvasLayer
## The Waking (spec A, 2026-07-24): a rescue deserves a MOMENT. Non-blocking bottom-center
## card — "<Name> the <Species> joins you!" + the verb teach — that fades in on a friend's
## wake and melts away. Fired via group "rescue_card" from companion._wake(); reads everything
## from CompanionLibrary.info() (one-record character sheet). Travellers arriving already
## rescued never fire it. Styled with UiTheme; never locks input.

const Library := preload("res://game/companion/companion_library.gd")
const HOLD := 4.0
const FADE := 0.4

var _root: Control
var _title: Label
var _teach: Label
var _timer := 0.0
var _fade := 0.0

func _ready() -> void:
	layer = 94                 # over hints (93), under the restoration banner (95)
	process_mode = PROCESS_MODE_ALWAYS   # keep fading under the paused rest menu (review minor)
	add_to_group("rescue_card")
	_build()

func setup(_cfg) -> void:
	pass                       # injection no-op: the card is stateless, config-free

## The ceremony entry point (group-called from companion._wake()).
func show_rescue(kind: int) -> void:
	var info := Library.info(kind)
	if info.is_empty():
		return
	_title.text = "%s the %s joins you!" % [info["name"], info["species"]]
	var teach: String = info.get("verb_teach", "")
	_teach.text = teach
	_teach.visible = teach != ""
	_timer = HOLD
	Sfx.play("chime", -6.0, 1.2)

func _process(delta: float) -> void:
	var target := 0.0
	if _timer > 0.0:
		_timer -= delta
		target = 0.0 if Settings.ui_locked() else 1.0
	_fade = move_toward(_fade, target, delta / FADE)
	_root.modulate.a = _fade
	_root.visible = _fade > 0.01 and not Settings.ui_locked()   # hard-hide under menus (hints idiom)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -128.0            # a row above the hints toast (-74) so both can show
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.panel())
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color(Palette.GOLD))
	_title.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.9))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_title)
	_teach = Label.new()
	_teach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_teach.add_theme_font_size_override("font_size", 21)
	_teach.add_theme_color_override("font_color", Color(Palette.FOAM))
	_teach.add_theme_color_override("font_shadow_color", Color(Palette.INK, 0.9))
	_teach.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_teach)
