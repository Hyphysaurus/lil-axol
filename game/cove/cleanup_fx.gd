extends Node2D
class_name CleanupFX
## Presentation-only juice for the oil cleanup. OilSpill owns the simulation and decides
## WHEN things happen; this decides only HOW they look — the sparkle burst + expanding
## clear-water ring when a blob is fully cleared, and the light sparkle trail while spraying.
## Added as a child of OilSpill at its origin, so positions share the same cove-local frame.

const WHITE := preload("res://assets/white.png")
const RING_SHADER := preload("res://shaders/ring.gdshader")

## Satisfying clear: sparkle burst outward from the cleared blob + expanding clear-water ring.
func pop(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 16
	burst.lifetime = 0.5
	burst.explosiveness = 0.9
	burst.position = pos
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 120.0
	burst.gravity = Vector2(0, 130.0)
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.9
	burst.color = Color(0.85, 0.97, 1.0, 0.95)
	burst.z_index = 7
	add_child(burst)
	burst.finished.connect(burst.queue_free)
	# expanding clear-water ring
	var ring := Sprite2D.new()
	ring.texture = WHITE
	ring.centered = true
	ring.scale = Vector2(80, 52)
	ring.position = pos
	ring.z_index = 7
	var rmat := ShaderMaterial.new()
	rmat.shader = RING_SHADER
	ring.material = rmat
	add_child(ring)
	var tw := create_tween()
	tw.tween_method(func(v: float): rmat.set_shader_parameter("t", v), 0.0, 1.0, 0.45)
	tw.tween_callback(ring.queue_free)

## A few tiny sparkles at the spray point while actively cleaning.
func spark(pos: Vector2) -> void:
	var s := CPUParticles2D.new()
	s.one_shot = true
	s.emitting = true
	s.amount = 5
	s.lifetime = 0.35
	s.explosiveness = 0.8
	s.position = pos
	s.direction = Vector2(0, -1)
	s.spread = 90.0
	s.initial_velocity_min = 25.0
	s.initial_velocity_max = 60.0
	s.gravity = Vector2(0, 90.0)
	s.scale_amount_min = 0.5
	s.scale_amount_max = 1.2
	s.color = Color(0.9, 0.98, 1.0, 0.85)
	s.z_index = 7
	add_child(s)
	s.finished.connect(s.queue_free)
