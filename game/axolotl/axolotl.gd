extends CharacterBody2D
## Lil Axolotl — land movement + swim. Reads InputMap actions (touch/gamepad-ready).
## Water geometry (has_water, surface_y, left/right span) comes from the cove's
## injected CoveConfig — the parent Cove calls setup(cfg) before the first physics frame.
## Movement/spray numbers come from the AxolotlTuning resource (defaults = D-0003 contract).

const MOVE_EPS := 6.0
const BubbleBomb := preload("res://game/axolotl/bubble.gd")

# --- juice (visual only — never touches movement; D-0002: art stays out of config) ---
const TILT_MAX := 0.35          # swim nose-down/up lean, radians at full vertical speed
const TILT_LERP := 6.0
const SCALE_RECOVER := 9.0      # how fast squash/stretch settles back to 1:1
const LAND_CLIP_T := 0.22       # how long the landing clip owns the sprite (3 frames @ 14fps)
const AFK_AT := 18.0            # quiet seconds before the axo lies down and drifts off
const BLINK_MIN := 3.0          # seconds between idle blinks (randomised in this range)
const BLINK_MAX := 7.0

## Movement + spray tuning (single source of truth; falls back to D-0003 defaults).
@export var tuning: AxolotlTuning
## Logical-state -> clip-name map (assigned in the scene). Clip names live here as data, not
## as literals in the movement code below.
@export var anim_set: CharacterAnimSet

@onready var _spr: AnimatedSprite2D = $Sprite

var _cfg: CoveConfig            # water geometry, injected by the cove (see setup)
var _oil_mgr: Node             # oil manager, for the in-oil movement debuff (fetched in setup)
var _anims: AnimationController  # drives _spr from the states the movement code picks
var _half_h := 9.0             # feet are this far below center (read off the collision shape)
var _face := 1.0
var _t := 0.0
var _hop_grace := 0.0
var _in_water := false
var _was_on_floor := false
var _idle_t := 0.0             # quiet time on land, drives blink + the AFK sleep chain
var _land_t := 0.0             # remaining time the landing clip owns the sprite
var _next_blink := 0.0
var _sitting := false          # deliberate sit (press ↓ while idle); any input stands up
var _dash_t := 0.0             # remaining clean-wake dash time (swim only)
var _dash_cd := 0.0
var _spray_p: CPUParticles2D
var _bubbles: CPUParticles2D
var _bubble: Node = null       # the live Bubble Bomb while its button is held (aim/steer/release)

@onready var _cam: Camera2D = $Camera

## Called by the Cove composition root once, before the first physics frame.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	# grabbed here (not _ready) because the oil manager joins its group in its own _ready first
	_oil_mgr = get_tree().get_first_node_in_group("oil_manager")

## Axo position in the cove's (parent) frame — the water bounds are authored there.
## Run standalone (Play Current Scene), the parent is the Window, not a cove: fall back
## to our own frame so the scene stays testable instead of erroring every physics frame.
func _cove_local() -> Vector2:
	var cove := get_parent() as Node2D
	return cove.to_local(global_position) if cove else position

func _ready() -> void:
	add_to_group("player")   # companions and future systems find the tidekeeper here
	if tuning == null:
		tuning = AxolotlTuning.new()   # defaults are the frozen D-0003 numbers
	# data-driven animation: movement picks a logical state, the controller plays the mapped clip
	if anim_set == null:
		anim_set = CharacterAnimSet.new()   # defaults match the SpriteFrames clip names
	_anims = AnimationController.new(_spr)
	_next_blink = randf_range(BLINK_MIN, BLINK_MAX)

	# feet offset comes from the authored collision box, not a hand-copied constant
	var rect := ($Col as CollisionShape2D).shape as RectangleShape2D
	if rect:
		_half_h = rect.size.y / 2.0

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
	_spray_p.color = Color(Palette.CYAN, 0.9)   # spray mist, on-palette
	_spray_p.z_index = 7
	add_child(_spray_p)

	# gentle bubble trail while swimming (emitting toggled in _swim)
	_bubbles = CPUParticles2D.new()
	_bubbles.emitting = false
	_bubbles.local_coords = false
	_bubbles.amount = 8
	_bubbles.lifetime = 1.1
	_bubbles.spread = 25.0
	_bubbles.direction = Vector2(0, -1)
	_bubbles.initial_velocity_min = 8.0
	_bubbles.initial_velocity_max = 18.0
	_bubbles.gravity = Vector2(0, -26)   # bubbles drift up
	_bubbles.texture = preload("res://assets/fx/bubble.png")   # Mario's hand-drawn bubble sprite
	_bubbles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubbles.scale_amount_min = 0.12     # small swim-trail bubbles (~4..11px)
	_bubbles.scale_amount_max = 0.34
	_bubbles.color = Color(1.0, 1.0, 1.0, 0.7)   # white so the bubble's own colours show
	_bubbles.z_index = 6
	add_child(_bubbles)

func _physics_process(delta: float) -> void:
	_t += delta
	_hop_grace = maxf(0.0, _hop_grace - delta)
	_land_t = maxf(0.0, _land_t - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_t = maxf(0.0, _dash_t - delta)

	# menus (title / settings / rest card) own the input; the cove keeps living behind them
	var ui := Settings.ui_locked()
	var dir := 0.0 if ui else Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_face = signf(dir)
	var running := not ui and Input.is_action_pressed("run")

	# --- spray: clean oil blobs in front of the axo (works on land or in the water) ---
	var spraying := not ui and Input.is_action_pressed("spray")
	_spray_p.emitting = spraying
	Sfx.loop("spray", spraying, -6.0)
	if spraying:
		# aim follows the input direction (stick = analog, keys = 8-way); neutral = facing
		var aim := _aim(dir)
		_spray_p.position = aim * 10.0 + Vector2(0.0, 1.0)   # off the snout, along the aim
		_spray_p.direction = aim + Vector2(0.0, -0.15)        # slight cosmetic lift on the jet
		var reach := global_position + aim * tuning.spray_reach
		get_tree().call_group("oil_manager", "spray_at", reach, tuning.spray_radius, delta)
		# generic spray-the-world hook: anything in "sprayable" reacts (rescues, props later)
		get_tree().call_group("sprayable", "spray_at", reach, tuning.spray_radius, delta)

	# --- water: enter / exit / swim, polled vs the waterline (hysteresis stops surface flicker) ---
	# The config's surface_y / water_left / water_right are authored in the cove's (parent) frame, so test the
	# axo in that frame too. Using global_position added the cove's world offset and made every poll read
	# "over water / submerged" — the axo spawned swimming on the sand and floated in the beach/water gap.
	var local := _cove_local()
	var feet := local.y + _half_h
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
	_update_bubble(dir, ui)   # launch / steer / release the aimed Bubble Bomb (works anywhere)
	if submerged:
		_swim(delta, dir)
		_juice(delta)
		return

	# --- land movement ---
	_bubbles.emitting = false
	# same dash verb on land/air — a traversal scoot for shore puzzles (no cleaning up here)
	if not ui and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		if dir != 0.0:
			_face = signf(dir)
		_dash_t = tuning.dash_time
		_dash_cd = tuning.dash_cooldown
		_spr.scale = Vector2(1.3, 0.75)
		if is_on_floor():
			_dust()
		Sfx.play("swish", -4.0)   # the dash whoosh (cohesive with the water wake dash)
	if _dash_t > 0.0:
		velocity.x = _face * tuning.dash_speed   # the dash owns X; gravity still applies
	else:
		velocity.x = dir * (tuning.run_speed if running else tuning.walk_speed)
	if not is_on_floor():
		velocity.y += tuning.gravity * delta
	if not ui and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = tuning.jump_velocity
		_spr.scale = Vector2(0.72, 1.28)   # takeoff stretch
		Sfx.play("jump")
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land()
	_was_on_floor = is_on_floor()
	_animate_land(running, spraying, delta)
	_juice(delta)

func _swim(delta: float, dir: float) -> void:
	var ui := Settings.ui_locked()
	var vin := 0.0 if ui else Input.get_axis("move_up", "move_down")    # +1 = down (dive)
	var feet := _cove_local().y + _half_h
	var depth := feet - _cfg.surface_y                   # >0 = below the surface
	_sitting = false

	# --- clean wake dash: a joyful burst that scrubs a stripe of the film behind you ---
	if _dash_t > 0.0:
		# the film lives in a band just under the waterline — aim the wake there (when in
		# reach) and erode several times harder than the spray: a passing brush only touches
		# each cell for ~0.13s, so at 1x it removes ~0.19 coverage and nothing visibly changes
		var cl := _cove_local()
		if _cfg != null and cl.y < _cfg.surface_y + tuning.dash_clean_depth:
			var wake := Vector2(cl.x, clampf(cl.y, _cfg.surface_y + 8.0, _cfg.surface_y + 52.0))
			var cove := get_parent() as Node2D
			var wake_world := cove.to_global(wake) if cove else wake
			get_tree().call_group("oil_manager", "spray_at",
				wake_world, tuning.dash_clean_radius, delta * tuning.dash_clean_power)
		_idle_t = 0.0
		_bubbles.emitting = true
		_bubbles.position = Vector2(-_face * 8.0, 2.0)
		_anims.play(anim_set.dash, _face)
		_was_on_floor = false
		move_and_slide()
		return
	if not ui and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		var dd := Vector2(dir, vin)
		if dd == Vector2.ZERO:
			dd = Vector2(_face, 0.0)
		if dir != 0.0:
			_face = signf(dir)
		velocity = dd.normalized() * tuning.dash_speed
		_dash_t = tuning.dash_time
		_dash_cd = tuning.dash_cooldown
		_hop_grace = 0.25                # a surface-ward dash may crest the waterline
		_spr.scale = Vector2(1.3, 0.75)  # long and lean into the burst
		_dash_burst(dd.normalized())
		Sfx.play("swish", -5.0)          # the wake-dash whoosh (same as the land dash)
		Sfx.play("splash", -12.0, 1.3)   # a faint water burst under it
	# oil debuff: thick oil sludges both top speed and how fast you accelerate (0 oil => no change)
	var oil: float = _oil_mgr.oil_at(global_position) if _oil_mgr else 0.0
	var slow := 1.0 - tuning.oil_drag * oil
	var tv := Vector2(dir * tuning.swim_h * slow, vin * tuning.swim_v * slow)

	# no vertical input -> buoyancy holds you near the surface, but FADES to neutral hover with
	# depth (Subnautica mobility): idle underwater you keep your depth and aim instead of always
	# floating up. (Suspended during a hop's grace window so it can't drag the leap back down.)
	if vin == 0.0 and _hop_grace <= 0.0:
		var spring := clampf((tuning.rest_depth - depth) * tuning.buoy_spring, -tuning.buoy_max, tuning.buoy_max)
		var near_surface := clampf(1.0 - absf(depth - tuning.rest_depth) / 24.0, 0.0, 1.0)
		var surf_pull := clampf(1.0 - (depth - tuning.rest_depth) / tuning.surface_band, 0.0, 1.0)
		tv.y = (spring + sin(_t * tuning.bob_freq) * tuning.bob_amp * near_surface) * surf_pull

	velocity = velocity.lerp(tv, clampf(tuning.swim_lerp * slow * delta, 0.0, 1.0))

	# buoyancy alone never flings the axo out...
	if depth <= 0.0 and velocity.y < 0.0 and _hop_grace <= 0.0:
		velocity.y = 0.0
	# ...but a deliberate hop near the surface gets a grace window to clear it
	if not ui and Input.is_action_just_pressed("jump") and depth < tuning.rest_depth + 6.0:
		velocity.y = tuning.surface_hop
		velocity.x = dir * tuning.run_speed
		_hop_grace = 0.3
		Sfx.play("splash", -8.0, 1.2)   # tiny bright hop splash

	_idle_t = 0.0   # swimming is its own animation family; the AFK chain is land-only
	var moving := absf(velocity.x) > MOVE_EPS or vin != 0.0
	_bubbles.emitting = moving and depth > 4.0
	_bubbles.position = Vector2(-_face * 8.0, 2.0)   # trail off the tail
	_anims.play(anim_set.swim if moving else anim_set.swim_idle, _face)
	_was_on_floor = false
	move_and_slide()

func _animate_land(running: bool, spraying: bool, delta: float) -> void:
	if _dash_t > 0.0:
		_sitting = false
		_idle_t = 0.0
		_anims.play(anim_set.dash, _face)
	elif not is_on_floor():
		_sitting = false
		_idle_t = 0.0
		_anims.play(anim_set.jump if velocity.y < 0.0 else anim_set.fall, _face)
	elif absf(velocity.x) > MOVE_EPS:
		_sitting = false
		_idle_t = 0.0
		_anims.play(anim_set.run if running else anim_set.walk, _face)
	elif _land_t > 0.0:
		_idle_t = 0.0
		_anims.play(anim_set.land, _face)
	elif spraying:
		# arm-pump into the spray pose; the non-looping clip freezes on its last frame while held
		_sitting = false
		_idle_t = 0.0
		_anims.play(anim_set.spray, _face)
	else:
		# sit & watch: press ↓ while idle to settle in; any other input stands back up
		if not _sitting and not Settings.ui_locked() and Input.is_action_just_pressed("move_down"):
			_sitting = true
		if _sitting:
			_idle_t = 0.0
			_anims.play(anim_set.sit, _face)
			return
		_animate_idle(delta)

## Idle life: blink now and then; after a long quiet stretch, lie down and drift off.
## Purely reactive to _idle_t — any movement/spray/jump resets it and normal states resume.
func _animate_idle(delta: float) -> void:
	_idle_t += delta
	var cur := _spr.animation
	if _idle_t >= AFK_AT:
		if cur == anim_set.sleep:
			return
		if cur == anim_set.liedown:
			if not _spr.is_playing():   # settled down -> start the sleep loop
				_anims.play(anim_set.sleep, _face)
			return
		_anims.play(anim_set.liedown, _face)
		return
	if cur == anim_set.idle_blink:
		if _spr.is_playing():
			return                       # let the blink finish
		_next_blink = _t + randf_range(BLINK_MIN, BLINK_MAX)
	elif _t >= _next_blink:
		_anims.play(anim_set.idle_blink, _face)
		return
	_anims.play(anim_set.idle, _face)

## Visual-only follow-through: squash/stretch settles back and the sprite leans into
## vertical swim motion. Never writes velocity/position — D-0003 stays intact.
func _juice(delta: float) -> void:
	_spr.scale = _spr.scale.lerp(Vector2.ONE, clampf(SCALE_RECOVER * delta, 0.0, 1.0))
	var target_tilt := 0.0
	if _in_water:
		target_tilt = clampf(velocity.y / tuning.swim_v, -1.0, 1.0) * TILT_MAX * _face
	_spr.rotation = lerpf(_spr.rotation, target_tilt, clampf(TILT_LERP * delta, 0.0, 1.0))
	# sit & watch (or a full AFK nap): the camera breathes out and the cove becomes the show
	var z := 2.55 if (_sitting or _idle_t >= AFK_AT) else 3.0
	_cam.zoom = _cam.zoom.lerp(Vector2(z, z), clampf(1.5 * delta, 0.0, 1.0))

func _land() -> void:
	_spr.scale = Vector2(1.3, 0.72)   # landing squash
	_land_t = LAND_CLIP_T
	_dust()
	Sfx.play("land")

signal submerged_changed(on: bool)   # audio keys the underwater muffle off this

func _enter_water() -> void:
	submerged_changed.emit(true)
	_splash(1.0)
	Sfx.play("splash")
	_spr.scale = Vector2(0.8, 1.2)    # slip in long and lean
	velocity.y *= 0.35   # soften the plunge

func _exit_water() -> void:
	submerged_changed.emit(false)
	_splash(0.7)
	Sfx.play("splash", -6.0)   # lighter, like the 0.7 particle burst

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
	p.color = Color(Palette.FOAM, 0.9)   # bright water-entry splash
	p.z_index = 8
	get_parent().add_child(p)   # add to the cove (world coords) so the splash stays at the surface
	p.finished.connect(p.queue_free)

## Current aim: input direction (analog on stick, 8-way on keys), facing when neutral.
func _aim(dir: float) -> Vector2:
	var v := Vector2(dir, 0.0 if Settings.ui_locked() else Input.get_axis("move_up", "move_down"))
	return v.normalized() if v != Vector2.ZERO else Vector2(_face, 0.0)

## Bubble Bomb control: launch on press (spends a Shine charge), HOLD to send it further and
## steer it, RELEASE to detonate. The axolotl owns the live bubble while the button is held.
func _update_bubble(dir: float, ui: bool) -> void:
	if is_instance_valid(_bubble):
		if ui or not Input.is_action_pressed("bubble"):
			_bubble.release()          # released -> detonate where it is
			_bubble = null
		else:
			_bubble.steer(_aim(dir))   # held -> steer + keep gliding further
		return
	_bubble = null                     # cleared if it auto-detonated at max reach
	if not ui and Input.is_action_just_pressed("bubble"):
		_fire_bubble(dir)

## Spend a full Shine charge and launch a steerable AOE bubble (see bubble.gd).
func _fire_bubble(dir: float) -> void:
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper == null:
		return
	if not keeper.spend_bubble():
		Sfx.play("scrub", -16.0, 0.65)   # soft "not charged yet" blip
		return
	var aim := _aim(dir)
	var b := BubbleBomb.new()
	b.position = _cove_local() + aim * 12.0
	b.setup(aim, _cfg)
	get_parent().add_child(b)
	_bubble = b
	Sfx.play("splash", -10.0, 1.5)
	_spr.scale = Vector2(0.8, 1.2)   # a little puff of effort

## Underwater burst kicked off behind a dash: droplets that brake in the water and
## bubble upward. One-shot, added to the cove so the trail stays where the dash began.
func _dash_burst(dd: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 16
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.position = _cove_local()
	p.direction = -dd
	p.spread = 40.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.damping_min = 60.0
	p.damping_max = 130.0
	p.gravity = Vector2(0, -30)      # spent droplets drift up as bubbles
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.color = Color(Palette.CYAN, 0.8)   # dash droplet burst
	p.z_index = 7
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)

func _dust() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 7
	p.lifetime = 0.35
	p.explosiveness = 0.9
	p.position = Vector2(_cove_local().x, _cove_local().y + _half_h)
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(Palette.GOLD.lerp(Palette.MIST, 0.35), 0.7)   # dusty dry-sand puff
	p.z_index = 5
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
