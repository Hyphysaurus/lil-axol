extends Node2D
## Bubble Bomb — the Hydro Pack's Bubble tool, v1. A big wobbling bubble the axolotl blows
## along its aim; it drifts with gentle lift and POPS after a moment (or on reaching the
## film band at the surface): one strong AOE carve through the oil, a droplet burst, and a
## bright pop-chime. Spawned cove-local by the axolotl; entirely self-contained.

const DRIFT := 90.0
const LIFT := -26.0            # gentle buoyancy pull while drifting underwater
const LIFE := 1.1              # underwater: seconds before it pops on its own
const LIFE_AIR := 1.8          # in air it floats longer, looking for water
const AIR_SINK := 30.0         # soap-bubble settle toward the water when blown on land
const POP_RADIUS := 64.0
const POP_STRENGTH := 0.6      # spray_at delta-equivalent (sim-tuned: ~10-15% of the cove)
const R := 13.0

var _vel := Vector2.ZERO
var _cfg: CoveConfig
var _t := 0.0
var _popped := false
var _in_air := false

func setup(aim: Vector2, cfg: CoveConfig) -> void:
	_vel = aim * DRIFT
	_cfg = cfg

func _ready() -> void:
	z_index = 7
	_in_air = _cfg != null and position.y < _cfg.surface_y - 2.0

func _physics_process(delta: float) -> void:
	_t += delta
	if _in_air:
		# blown on land: drifts along the aim, settles toward the water, pops the moment
		# it kisses the surface — right on the film, exactly where a bubble should burst
		_vel.y += AIR_SINK * delta
		position += _vel * delta
		if (_cfg != null and position.y >= _cfg.surface_y - 4.0) or _t >= LIFE_AIR:
			_pop()
	else:
		_vel.y += LIFT * delta
		position += _vel * delta
		if _t >= LIFE or (_cfg != null and position.y < _cfg.surface_y + 10.0):
			_pop()
	scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 9.0))   # soap-film wobble
	queue_redraw()

func _pop() -> void:
	if _popped:
		return
	_popped = true
	set_physics_process(false)
	get_tree().call_group("oil_manager", "spray_at", global_position, POP_RADIUS, POP_STRENGTH)
	Sfx.play("chime", -2.0, 1.4)
	Sfx.play("splash", -4.0, 0.9)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 22
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.position = position
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 160.0
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.gravity = Vector2(0, -24)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	p.color = Color(0.8, 0.95, 1.0, 0.85)
	p.z_index = 7
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, R, Color(0.8, 0.95, 1.0, 0.10))
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 32, Color(0.9, 0.98, 1.0, 0.8), 1.5, true)
	draw_arc(Vector2.ZERO, R - 4.0, -2.2, -1.1, 10, Color(1.0, 1.0, 1.0, 0.7), 1.5, true)
