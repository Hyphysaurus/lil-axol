extends CharacterBody2D
## Lil Axolotl — land movement + swim. Reads InputMap actions (touch/gamepad-ready).
## Water geometry (has_water, surface_y, left/right span) comes from the cove's
## injected CoveConfig — the parent Cove calls setup(cfg) before the first physics frame.

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
const REST_DEPTH := 5.0      # feet settle this far below the surface (head floats out)
const BUOY_SPRING := 5.5
const BUOY_MAX := 42.0
const BOB_AMP := 5.0
const BOB_FREQ := 2.2
const SURFACE_HOP := -300.0   # strong enough to clear the beach ledge out of the water
const OIL_DRAG := 0.5         # max swim slow-down when in thick oil (0 = none .. 1 = stuck)

# --- spray (oil cleanup) ---
const SPRAY_REACH := 40.0     # px in front of the axo the spray reaches
const SPRAY_RADIUS := 36.0    # clean radius around the spray point

## Logical-state -> clip-name map (assigned in the scene). Clip names live here as data, not
## as literals in the movement code below.
@export var anim_set: CharacterAnimSet

@onready var _spr: AnimatedSprite2D = $Sprite

var _cfg: CoveConfig            # water geometry, injected by the cove (see setup)
var _oil_mgr: Node             # oil manager, for the in-oil movement debuff (fetched in setup)
var _anims: AnimationController  # drives _spr from the states the movement code picks
var _face := 1.0
var _t := 0.0
var _hop_grace := 0.0
var _in_water := false
var _spray_p: CPUParticles2D

## Called by the Cove composition root once, before the first physics frame.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	# grabbed here (not _ready) because the oil manager joins its group in its own _ready first
	_oil_mgr = get_tree().get_first_node_in_group("oil_manager")

## Axo position in the cove's (parent) frame — the water bounds are authored there.
func _cove_local() -> Vector2:
	return (get_parent() as Node2D).to_local(global_position)

func _ready() -> void:
	# data-driven animation: movement picks a logical state, the controller plays the mapped clip
	if anim_set == null:
		anim_set = CharacterAnimSet.new()   # defaults match the SpriteFrames clip names
	_anims = AnimationController.new(_spr)

	# persistent water-spray emitter, toggled on while the spray button is held
	_spray_p = CPUParticles2D.new()
	_spray_p.emitting = false
	_spray_p.local_coords = false
	_spray_p.amount = 22
	_spray_p.lifetime = 0.4
	_spray_p.spread = 16.0
	_spray_p.initial_velocity_min = 130.0
	_spray_p.initial_velocity_max = 190.0
	_spray_p.gravity = Vector2(0, 260)
	_spray_p.scale_amount_min = 0.6
	_spray_p.scale_amount_max = 1.5
	_spray_p.color = Color(0.72, 0.9, 1.0, 0.9)
	_spray_p.z_index = 7
	add_child(_spray_p)

func _physics_process(delta: float) -> void:
	_t += delta
	_hop_grace = maxf(0.0, _hop_grace - delta)

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_face = signf(dir)
	var running := Input.is_action_pressed("run")

	# --- spray: clean oil blobs in front of the axo (works on land or in the water) ---
	var spraying := Input.is_action_pressed("spray")
	_spray_p.emitting = spraying
	if spraying:
		_spray_p.position = Vector2(_face * 10.0, 1.0)   # at the snout/mouth tip
		_spray_p.direction = Vector2(_face, -0.25)
		var reach := global_position + Vector2(_face * SPRAY_REACH, 0.0)
		get_tree().call_group("oil_manager", "spray_at", reach, SPRAY_RADIUS, delta)

	# --- water: enter / exit / swim, polled vs the waterline (hysteresis stops surface flicker) ---
	# The config's surface_y / water_left / water_right are authored in the cove's (parent) frame, so test the
	# axo in that frame too. Using global_position added the cove's world offset and made every poll read
	# "over water / submerged" — the axo spawned swimming on the sand and floated in the beach/water gap.
	var local := _cove_local()
	var feet := local.y + HALF_H
	var has_water := _cfg != null and _cfg.has_water
	var submerged := false
	if has_water:
		var over_water := local.x > _cfg.water_left and local.x < _cfg.water_right
		if over_water:
			if _in_water:
				submerged = feet > _cfg.surface_y - 2.0   # stay in until fully out
			else:
				submerged = feet > _cfg.surface_y + 4.0   # dip in to start
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
	var feet := _cove_local().y + HALF_H
	var depth := feet - _cfg.surface_y                   # >0 = below the surface
	# oil debuff: thick oil sludges both top speed and how fast you accelerate (0 oil => no change)
	var oil: float = _oil_mgr.oil_at(global_position) if _oil_mgr else 0.0
	var slow := 1.0 - OIL_DRAG * oil
	var tv := Vector2(dir * SWIM_H * slow, vin * SWIM_V * slow)

	# no vertical input -> buoyancy spring toward REST_DEPTH + a gentle surface bob
	# (suspended during a hop's grace window so it can't drag the leap back down)
	if vin == 0.0 and _hop_grace <= 0.0:
		var spring := clampf((REST_DEPTH - depth) * BUOY_SPRING, -BUOY_MAX, BUOY_MAX)
		var near_surface := clampf(1.0 - absf(depth - REST_DEPTH) / 24.0, 0.0, 1.0)
		tv.y = spring + sin(_t * BOB_FREQ) * BOB_AMP * near_surface

	velocity = velocity.lerp(tv, clampf(SWIM_LERP * slow * delta, 0.0, 1.0))

	# buoyancy alone never flings the axo out...
	if depth <= 0.0 and velocity.y < 0.0 and _hop_grace <= 0.0:
		velocity.y = 0.0
	# ...but a deliberate hop near the surface gets a grace window to clear it
	if Input.is_action_just_pressed("jump") and depth < REST_DEPTH + 6.0:
		velocity.y = SURFACE_HOP
		velocity.x = dir * RUN_SPEED
		_hop_grace = 0.3

	var moving := absf(velocity.x) > MOVE_EPS or vin != 0.0
	_anims.play(anim_set.swim if moving else anim_set.swim_idle, _face)
	move_and_slide()

func _animate_land(_dir: float, running: bool) -> void:
	if not is_on_floor():
		_anims.play(anim_set.jump if velocity.y < 0.0 else anim_set.fall, _face)
	elif absf(velocity.x) > MOVE_EPS:
		_anims.play(anim_set.run if running else anim_set.walk, _face)
	else:
		_anims.play(anim_set.idle, _face)

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
	p.position = Vector2(_cove_local().x, _cfg.surface_y)   # entry point on the waterline (cove frame)
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
