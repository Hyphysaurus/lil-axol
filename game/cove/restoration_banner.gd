extends CanvasLayer
## Win-state payoff + post-win handoff. When the cove is fully cleaned (cleanliness reaches
## the config's win_threshold) a soft "Cove Restored" banner fades in, holds, then hands off:
## the panel recedes while a small corner sun glyph fades in and stays for the session, with
## a one-time subline teaching the New Day restart. Emits `restored` (and sits in the
## "restoration" group) so future afterglow content — fireflies, visitors — can key off the
## moment. Purely additive: self-wires to the oil_manager group and never touches gameplay,
## so it can't affect swim or cleanup. Built in code to match the cove's code-first style.

signal restored

const HOLD_SECONDS := 2.5
const FADE_SPEED := 1.2
const SUBLINE_SECONDS := 6.0

var is_restored := false           # one-shot latch; afterglow content may read this

var _cfg: CoveConfig
var _root: Control
var _corner: Control
var _subline: Label
var _tally: Label              # final Shine, set the moment the cove is restored
var _fade := 0.0
var _target := 0.0
var _hold := 0.0
var _corner_on := false
var _corner_fade := 0.0
var _subline_left := SUBLINE_SECONDS
var _subline_fade := 1.0

func _ready() -> void:
	layer = 95                     # above the world, below PostFX (100) so grain/vignette still apply
	add_to_group("restoration")    # discoverable by future afterglow content
	_build()
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(_on_clean)

## Injected by the Cove composition root; only win_threshold is read (null-safe while
## components migrate — without config the old 0.999 behavior stands).
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg

func _win_threshold() -> float:
	return _cfg.win_threshold if _cfg else 0.999

func _on_clean(v: float) -> void:
	if not is_restored and v >= _win_threshold():
		is_restored = true         # one-shot: only celebrate the first full restoration
		_target = 1.0
		_hold = HOLD_SECONDS
		Sfx.play("win")
		var keeper = get_tree().get_first_node_in_group("shine")
		if keeper and "score" in keeper:
			_tally.text = "shine  %d" % int(keeper.score)
			_tally.visible = true
		restored.emit()

func _process(delta: float) -> void:
	if _target <= 0.0 and _fade <= 0.0 and not _corner_on:
		return
	# center banner: rise, hold, then recede (slight shrink) as it hands off to the corner
	_fade = move_toward(_fade, _target, delta * FADE_SPEED)
	if _fade >= 1.0 and _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_target = 0.0          # hold elapsed -> begin fade-out + corner handoff
			_corner_on = true
	_root.modulate.a = _fade
	_root.pivot_offset = _root.size / 2.0
	_root.scale = Vector2.ONE * (0.94 + 0.06 * _fade)
	# corner glyph fades in once and stays; the teaching subline melts away after a while
	if _corner_on:
		_corner_fade = move_toward(_corner_fade, 1.0, delta * FADE_SPEED)
		_corner.modulate.a = _corner_fade
		if _corner_fade >= 1.0 and _subline_left > 0.0:
			_subline_left -= delta
		if _subline_left <= 0.0:
			_subline_fade = move_toward(_subline_fade, 0.0, delta * FADE_SPEED)
			_subline.modulate.a = _subline_fade

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat input
	_root.modulate.a = 0.0
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.14, 0.72)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	sb.border_color = Color(0.6, 0.85, 0.95, 0.35)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Cove Restored"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(0.93, 0.98, 1.0))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "the water runs clear again"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.70, 0.85, 0.90))
	vb.add_child(sub)

	_tally = Label.new()
	_tally.visible = false
	_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tally.add_theme_font_size_override("font_size", 22)
	_tally.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
	vb.add_child(_tally)

	# corner handoff (top-right): a little sun glyph + the one-time teaching subline
	_corner = Control.new()
	_corner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.modulate.a = 0.0
	add_child(_corner)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stack.offset_left = -300.0
	stack.offset_top = 16.0
	stack.offset_right = -16.0
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	_corner.add_child(stack)

	var glyph := SunGlyph.new()
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(glyph)

	_subline = Label.new()
	_subline.text = "stay awhile — hold R for a new day"
	_subline.size_flags_horizontal = Control.SIZE_SHRINK_END
	_subline.add_theme_font_size_override("font_size", 22)
	_subline.add_theme_color_override("font_color", Color(0.85, 0.93, 0.96, 0.9))
	stack.add_child(_subline)

## Tiny code-drawn sun: warm disc + rays. Persists in the corner as the "restored" mark.
class SunGlyph extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(30.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var warm := Color(1.0, 0.87, 0.55, 0.95)
		draw_circle(c, 6.0, warm)
		for i in 8:
			var dir := Vector2.from_angle(TAU * float(i) / 8.0)
			draw_line(c + dir * 9.0, c + dir * 13.0, warm, 1.6, true)
