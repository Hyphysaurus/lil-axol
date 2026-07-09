extends Node2D
## Floating pollution debris — a muck clump bobbing on the estuary surface, OUT of the axolotl's spray
## reach, so clearing it needs the FROG's tongue. Joins "grabbable"; the frog's tongue calls grab(to) to
## reel it in and cleanse it (Shine + a foam pop). Bobbing + a faint sheen so it reads as floating gunk,
## not a static prop. Drop as many as you like via the config-driven DebrisField.

const GRAB_SHINE := 450.0      # Shine for reeling in one clump (small, like a shore splat)

var _phase := 0.0
var _base := Vector2.ZERO
var _grabbed := false

func _ready() -> void:
	add_to_group("grabbable")
	z_index = 5                 # on the water, above the surface tint
	_base = position
	_phase = position.x * 0.05  # desync the bob per-instance
	queue_redraw()

func _process(delta: float) -> void:
	if _grabbed:
		return
	_phase += delta
	position.y = _base.y + sin(_phase * 1.6) * 3.0   # bob on the surface
	rotation = sin(_phase * 1.1) * 0.12               # gentle wallow

## The frog's tongue snagged us — reel toward `to` (the frog's mouth), shrink + fade, then cleanse.
func grab(to: Vector2) -> void:
	if _grabbed:
		return
	_grabbed = true
	remove_from_group("grabbable")   # can't be double-grabbed mid-reel
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("bonus"):
		keeper.bonus(GRAB_SHINE, global_position)
	Sfx.play("chime", -7.0, 1.45)    # a little cleanse chime
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", to, 0.22).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.22)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(_cleanse)

func _cleanse() -> void:
	_foam_pop()
	queue_free()

## A small clean-water foam burst where the muck dissolves.
func _foam_pop() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.position = position
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0.0, 40.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	p.color = Color(Palette.AQUA, 0.9)
	p.z_index = 7
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)

func _draw() -> void:
	# a dark muck clump with a faint cool sheen — floating gunk, on-palette
	draw_circle(Vector2(-3.0, 1.0), 6.0, Color(Palette.INK, 0.85))
	draw_circle(Vector2(4.0, 2.0), 5.0, Color(Palette.SLATE, 0.9))
	draw_circle(Vector2(0.0, -2.0), 5.5, Color(Palette.INK, 0.8))
	draw_circle(Vector2(-2.0, -3.0), 2.0, Color(Palette.CYAN, 0.45))   # sheen glint
