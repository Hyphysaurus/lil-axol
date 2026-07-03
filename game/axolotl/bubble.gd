extends Node2D
## Bubble Bomb — the Hydro Pack's Bubble tool. Aim-and-release, Din's-Fire style: blow the
## bubble and it glides along your aim; HOLD to send it further (and steer it with the stick),
## RELEASE to detonate it right there — one strong AOE carve through the oil, a droplet burst,
## a bright pop. The farther it flies, the bigger the blast. Auto-detonates at max reach so it
## never wanders off. Spawned cove-local by the axolotl, which owns it while the button is held.

const SPEED := 150.0           # travel speed while held
const STEER := 4.0             # how fast it turns toward the current aim
const MAX_TIME := 1.7          # auto-detonate after this even if still held
const POP_RADIUS := 46.0       # blast radius at launch...
const POP_GROW := 34.0         # ...plus this much per second of flight (reward for holding)
const POP_STRENGTH := 0.6
const R := 13.0

var _aim := Vector2.RIGHT
var _cfg: CoveConfig
var _t := 0.0
var _popped := false

func setup(aim: Vector2, cfg: CoveConfig) -> void:
	_aim = aim if aim != Vector2.ZERO else Vector2.RIGHT
	_cfg = cfg

func _ready() -> void:
	z_index = 7

## Called by the axolotl each frame the bubble button stays down: steer gently toward the
## current aim (Din's-Fire control) and keep gliding further.
func steer(aim: Vector2) -> void:
	if aim != Vector2.ZERO:
		_aim = _aim.lerp(aim, clampf(STEER * get_physics_process_delta_time(), 0.0, 1.0)).normalized()

## Button released — detonate where it is.
func release() -> void:
	_pop()

func _physics_process(delta: float) -> void:
	if _popped:
		return
	_t += delta
	position += _aim * SPEED * delta
	# keep it in the cove: detonate if it overstays or leaves the water column
	var out := _cfg != null and (position.y < _cfg.surface_y - 44.0 \
		or position.x < _cfg.water_left - 24.0 or position.x > _cfg.water_right + 24.0)
	if _t >= MAX_TIME or out:
		_pop()
		return
	scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 9.0) + 0.12 * _t)   # swells as it charges
	queue_redraw()

func _pop() -> void:
	if _popped:
		return
	_popped = true
	set_physics_process(false)
	var radius := POP_RADIUS + POP_GROW * _t
	get_tree().call_group("oil_manager", "spray_at", global_position, radius, POP_STRENGTH)
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
	p.initial_velocity_max = 60.0 + radius * 1.4
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
