extends CanvasLayer
## Win-state payoff (first pass). When the cove is fully cleaned (OilSpill's cleanliness
## reaches 1.0) a soft "Cove Restored" banner fades in, holds, then fades away. Purely
## additive: self-wires to the oil_manager group and never touches gameplay, so it can't
## affect swim or cleanup. Built in code to match the rest of the cove's code-first style.

const HOLD_SECONDS := 2.5
const FADE_SPEED := 1.2

var _root: Control
var _fade := 0.0
var _target := 0.0
var _hold := 0.0
var _fired := false

func _ready() -> void:
	layer = 95                     # above the world, below PostFX (100) so grain/vignette still apply
	_build()
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(_on_clean)

func _on_clean(v: float) -> void:
	if not _fired and v >= 0.999:
		_fired = true              # one-shot: only celebrate the first full restoration
		_target = 1.0
		_hold = HOLD_SECONDS

func _process(delta: float) -> void:
	if _target <= 0.0 and _fade <= 0.0:
		return
	_fade = move_toward(_fade, _target, delta * FADE_SPEED)
	if _fade >= 1.0 and _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_target = 0.0          # hold elapsed -> begin fade-out
	_root.modulate.a = _fade

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
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.93, 0.98, 1.0))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "the water runs clear again"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.70, 0.85, 0.90))
	vb.add_child(sub)
