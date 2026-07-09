extends CanvasLayer
## Partner swap HUD — small chips (top-left, under the restoration meter) showing every RESCUED
## partner; the active traveller wears the gold ring. Tap/click a chip to swap who journeys with you
## (Settings.roster_swap -> roster_changed -> the follower re-skins). Pure view over the Settings
## roster: it renders state and requests swaps, never owns either. Hidden while menus are up or the
## roster is empty (pre-first-rescue players never see UI they can't use yet).

const Library := preload("res://game/companion/companion_library.gd")
const CHIP := 34.0             # chip diameter
const PAD := 8.0

var _root: Control
var _chips: HBoxContainer

func _ready() -> void:
	layer = 92
	_build()
	Settings.roster_changed.connect(_refresh)
	Settings.ui_lock_changed.connect(func(_l: bool) -> void: _refresh())
	_refresh()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_chips = HBoxContainer.new()
	_chips.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_chips.offset_left = 16.0
	_chips.offset_top = 56.0            # under the restoration meter's row
	_chips.add_theme_constant_override("separation", 6)
	_root.add_child(_chips)

## Rebuild the chip row from the roster (tiny N — a full rebuild is simpler than diffing).
func _refresh() -> void:
	visible = not Settings.ui_locked() and not Settings.run_roster.is_empty()
	for c in _chips.get_children():
		c.visible = false      # hide NOW — queue_free lands at frame-end, and a same-frame rebuild
		c.queue_free()         # must not show stale chips beside the fresh row
	for kind in Settings.run_roster:
		if Library.has_kind(kind):
			_chips.add_child(Chip.new(kind, kind == Settings.run_active))

## One tappable partner chip: backing disc + the partner's idle frame + a gold ring when active.
class Chip extends Control:
	var _kind: int
	var _active: bool
	var _tex: Texture2D

	func _init(kind: int, active: bool) -> void:
		_kind = kind
		_active = active
		custom_minimum_size = Vector2(CHIP, CHIP)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var frames: SpriteFrames = Library.ART[kind]["frames"]
		if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
			_tex = frames.get_frame_texture("idle", 0)
		tooltip_text = str(Library.NAMES.get(kind, "?")).capitalize()

	func _gui_input(event: InputEvent) -> void:
		var tap: bool = (event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			accept_event()              # this tap is OURS — it must not leak a turtle command
			Settings.roster_swap(_kind)
			Sfx.play("ui_tap", -8.0)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, CHIP * 0.5, Color(Palette.INK, 0.4))                    # backing disc
		draw_circle(c, CHIP * 0.5 - 2.0, Color(Palette.DEEP, 0.6 if _active else 0.35))
		if _tex:
			var s := (CHIP - 12.0) / maxf(float(_tex.get_width()), float(_tex.get_height()))
			var sz := Vector2(_tex.get_width(), _tex.get_height()) * s
			draw_texture_rect(_tex, Rect2(c - sz * 0.5, sz), false,
				Color(1, 1, 1, 1.0 if _active else 0.55))
		draw_arc(c, CHIP * 0.5 - 1.0, 0.0, TAU, 32,
			Color(Palette.GOLD, 0.95) if _active else Color(Palette.MIST, 0.4),
			2.0 if _active else 1.0, true)
