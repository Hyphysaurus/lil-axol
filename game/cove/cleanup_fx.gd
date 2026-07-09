extends Node2D
class_name CleanupFX
## Presentation-only juice for the oil cleanup. OilSpill owns the simulation and decides
## WHEN things happen; this decides only HOW they look — the sparkle burst + expanding
## clear-water ring when a blob is fully cleared, and the light sparkle trail while spraying.
## Added as a child of OilSpill at its origin, so positions share the same cove-local frame.

const WHITE := preload("res://assets/white.png")
const RING_SHADER := preload("res://shaders/ring.gdshader")

var _spark_pool: CPUParticles2D   # one persistent sparkle emitter, reused for the whole spray trail
var _spark_off := 0.0             # emitting auto-stops when this countdown (refreshed per spark) runs out

func _ready() -> void:
	# Spray fires spark() ~20x/sec; allocating+freeing a CPUParticles2D each call is real churn on the
	# single-threaded web build. Instead we keep ONE continuous emitter and just move it to the spray
	# point — local_coords=false leaves the emitted sparkles in world space so the emitter trails them.
	_spark_pool = CPUParticles2D.new()
	_spark_pool.emitting = false
	_spark_pool.local_coords = false
	_spark_pool.amount = 10
	_spark_pool.lifetime = 0.35
	_spark_pool.spread = 90.0
	_spark_pool.direction = Vector2(0, -1)
	_spark_pool.initial_velocity_min = 25.0
	_spark_pool.initial_velocity_max = 60.0
	_spark_pool.gravity = Vector2(0, 90.0)
	_spark_pool.scale_amount_min = 0.5
	_spark_pool.scale_amount_max = 1.2
	_spark_pool.color = Color(Palette.CYAN, 0.85)   # spray-point sparkle trail
	_spark_pool.z_index = 7
	add_child(_spark_pool)

func _process(delta: float) -> void:
	if _spark_pool.emitting:
		_spark_off -= delta
		if _spark_off <= 0.0:
			_spark_pool.emitting = false   # spray stopped -> let the trail finish and go idle

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
	burst.color = Color(Palette.FOAM, 0.95)   # bright clear-water sparkle
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

## A light sparkle trail at the spray point while actively cleaning — just repositions the pooled
## emitter and keeps it streaming; _process stops it a beat after the last spray frame.
func spark(pos: Vector2) -> void:
	_spark_pool.position = pos
	_spark_pool.emitting = true
	_spark_off = 0.12
