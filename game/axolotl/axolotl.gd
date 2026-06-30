extends CharacterBody2D
## Lil Axolotl — land movement + swim. Reads InputMap actions (touch/gamepad-ready).
## The cove sets has_water + water_surface_y on this instance (Inspector exports).

# --- land ---
const WALK_SPEED := 90.0
const RUN_SPEED := 150.0
const JUMP_VELOCITY := -300.0
const GRAVITY := 760.0
const MOVE_EPS := 6.0

# --- swim ---
const HALF_H := 9.0            # half the 16x18 collision box (feet are this far below center)
const SWIM_H := 60.0
const SWIM_V := 54.0
const SWIM_LERP := 7.0
const REST_DEPTH := 5.0        # feet settle this far below the surface (head floats out)
const BUOY_SPRING := 5.5
const BUOY_MAX := 42.0
const BOB_AMP := 5.0
const BOB_FREQ := 2.2
const SURFACE_HOP := -210.0

@export var has_water := false
@export var water_surface_y := 0.0

@onready var _spr: AnimatedSprite2D = $Sprite

var _face := 1.0
var _t := 0.0
var _hop_grace := 0.0
var _in_water := false

func _physics_process(delta: float) -> void:
	_t += delta
	_hop_grace = maxf(0.0, _hop_grace - delta)

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_face = signf(dir)
	var running := Input.is_action_pressed("run")

	# --- water: enter / exit / swim, polled vs the waterline (hysteresis stops surface flicker) ---
	var feet := global_position.y + HALF_H
	var submerged := false
	if has_water:
		if _in_water:
			submerged = feet > water_surface_y - 2.0   # stay in until fully out
		else:
			submerged = feet > water_surface_y + 4.0   # dip in to start
	if submerged and not _in_water:
		_enter_water()
	elif not submerged and _in_water:
		_exit_water()
	_in_water = submerged
	if submerged:
		_swim(delta, dir)
		return

	# --- land movement ---
	velocity.x = dir * (RUN_SPEED if running else WALK_SPEED)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	_animate_land(dir, running)

func _swim(delta: float, dir: float) -> void:
	var vin := Input.get_axis("move_up", "move_down")    # +1 = down (dive)
	var feet := global_position.y + HALF_H
	var depth := feet - water_surface_y                  # >0 = below the surface
	var tv := Vector2(dir * SWIM_H, vin * SWIM_V)

	# no vertical input -> buoyancy spring toward REST_DEPTH + a gentle surface bob
	# (suspended during a hop's grace window so it can't drag the leap back down)
	if vin == 0.0 and _hop_grace <= 0.0:
		var spring := clampf((REST_DEPTH - depth) * BUOY_SPRING, -BUOY_MAX, BUOY_MAX)
		var near_surface := clampf(1.0 - absf(depth - REST_DEPTH) / 24.0, 0.0, 1.0)
		tv.y = spring + sin(_t * BOB_FREQ) * BOB_AMP * near_surface

	velocity = velocity.lerp(tv, clampf(SWIM_LERP * delta, 0.0, 1.0))

	# buoyancy alone never flings the axo out...
	if depth <= 0.0 and velocity.y < 0.0 and _hop_grace <= 0.0:
		velocity.y = 0.0
	# ...but a deliberate hop near the surface gets a grace window to clear it
	if Input.is_action_just_pressed("jump") and depth < REST_DEPTH + 6.0:
		velocity.y = SURFACE_HOP
		velocity.x = dir * RUN_SPEED
		_hop_grace = 0.3

	if dir != 0.0:
		_spr.flip_h = _face < 0.0
	var moving := absf(velocity.x) > MOVE_EPS or vin != 0.0
	_anim("swim" if moving else "swim_idle")
	move_and_slide()

func _animate_land(dir: float, running: bool) -> void:
	if dir != 0.0:
		_spr.flip_h = _face < 0.0
	if not is_on_floor():
		_anim("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > MOVE_EPS:
		_anim("run" if running else "walk")
	else:
		_anim("idle")

func _enter_water() -> void:
	_splash(1.0)
	velocity.y *= 0.35   # soften the plunge

func _exit_water() -> void:
	_splash(0.7)

func _splash(amt: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = int(10.0 * amt) + 6
	p.lifetime = 0.5
	p.explosiveness = 0.85
	p.position = Vector2(global_position.x, water_surface_y)   # at the entry point on the waterline
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.initial_velocity_min = 40.0 * amt
	p.initial_velocity_max = 90.0 * amt
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.85, 0.95, 1.0, 0.9)
	p.z_index = 8
	get_parent().add_child(p)   # add to the cove (world coords) so the splash stays at the surface
	p.finished.connect(p.queue_free)

func _anim(a: String) -> void:
	if _spr.animation != a:
		_spr.play(a)
