class_name UiTheme extends RefCounted
## One source of truth for LilAxol's overlay look — a hybrid organic / watery / cozy theme.
## Every card (settings, rest, credits, the tide board) calls these instead of hand-rolling its
## own StyleBoxes, so the ENTIRE UI restyles by editing this one file. That's the point: minimal
## duplication, one place to tune. Palette: deep seafoam-navy panels, warm gold trim (the
## restored cove's sun), soft seafoam accents — watery and cozy, not a flat grey box.

const INK := Color(0.93, 0.98, 0.96)       # warm-cool cream — body text
const DIM := Color(0.62, 0.82, 0.82)       # muted seafoam — secondary labels
const GOLD := Color(1.0, 0.87, 0.55)       # the cove's sun — headings & panel trim
const SEAFOAM := Color(0.55, 0.92, 0.86)   # accent — button glow, highlights

## A soft, rounded, deep-water panel with a warm gold rim and a drop shadow for depth.
static func panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.13, 0.16, 0.95)
	s.set_corner_radius_all(18)                 # rounded = organic, not a hard rectangle
	s.set_content_margin_all(20.0)
	s.border_color = Color(GOLD, 0.32)
	s.set_border_width_all(2)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size = 14                          # a soft glow-shadow lifts it off the world
	return s

static func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)                 # pill-ish, friendly
	s.set_content_margin_all(9.0)
	s.border_color = border
	s.set_border_width_all(1)
	return s

## Give a Button the whole watery treatment (idle + a brighter seafoam hover/press/focus).
static func style_button(b: Button) -> void:
	var normal := _button_box(Color(0.09, 0.22, 0.24, 0.92), Color(SEAFOAM, 0.22))
	var hot := _button_box(Color(0.15, 0.35, 0.35, 0.96), Color(SEAFOAM, 0.55))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	# every themed button gets a soft cozy click (SwishSwoosh "Cute UI"). Wiring it here — the one
	# place every card routes through — means the ENTIRE UI gets tactile press feedback for free.
	b.pressed.connect(func() -> void: Sfx.play("ui_tap", -7.0))
