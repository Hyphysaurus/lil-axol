extends CharacterBody2D
## Lil Axolotl — land movement + swim. Reads InputMap actions (touch/gamepad-ready).
## Water geometry (has_water, surface_y, left/right span) comes from the cove's
## injected CoveConfig — the parent Cove calls setup(cfg) before the first physics frame.
## Movement/spray numbers come from the AxolotlTuning resource (defaults = D-0003 contract).

const MOVE_EPS := 6.0
const BubbleBomb := preload("res://game/axolotl/bubble.gd")
const Spring := preload("res://game/fx/spring.gd")   # offset-transform juice helper (see _juice)

# --- juice (visual only — never touches movement; D-0002: art stays out of config) ---
const TILT_MAX := 0.35          # swim nose-down/up lean, radians at full vertical speed
const TILT_LERP := 6.0
const SKEW_MAX := 0.16          # how far the body leans (skews) into horizontal motion, radians
const BREATHE := 0.02           # idle breathing depth — a subtle scale swell when calm
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
var _field: ReachField = null   # the water/footing oracle (slice 5); null in standalone-scene runs
var _anims: AnimationController  # drives _spr from the states the movement code picks
var _half_h := 9.0             # feet are this far below center (read off the collision shape)
var _face := 1.0
var _t := 0.0
var _lean := Spring.new(0.0, 70.0)   # springy body-lean (skew) into horizontal motion — offset juice
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
var _reticle: Reticle          # aim indicator: shows where spray/bubble/dash point
var _shake := 0.0              # camera impact shake, kicked by shake() and decayed in _juice
var _climbing := false         # latched onto a climbable root curtain (designated surfaces only)
var _climb_wall: Node2D = null # the curtain we're latched to (its ledge_side steers the crest hop)
var _climb_fx_cd := 0.0        # cadence for the climb rustle + falling leaf motes while moving

const CLIMB_SPEED := 70.0      # px/s up/down a root curtain (a new state — D-0003 numbers untouched)
const CLIMB_HOP := 0.8         # hop-off jump strength as a fraction of the full jump
const COYOTE_TIME := 0.1       # jump grace after stepping off a ledge — forgiving, not floaty
const AIR_JUMP_SCALE := 0.9    # the mid-air gill-kick is a touch softer than the takeoff
const DIVE_MIN_SPEED := 320.0  # entry fall speed where a dive starts scrubbing (a bank slip doesn't)
const DIVE_MAX_SPEED := 620.0  # full-power cannonball
const BOUNCE_SCALE := 1.15     # bubble-trampoline launch vs the ground jump

var _air_jump_spent := false   # double jump: one per airtime, refreshed by floor/water/curtain
var _coyote := 0.0

@onready var _cam: Camera2D = $Camera

## Kick the camera with an impact shake (the shell-spin's rubble bites, big pops...). Public and
## reached via the "player" group so any system can thump the screen without knowing this node.
func shake(amount: float) -> void:
	_shake = minf(_shake + amount, 5.0)

## Called by the Cove composition root once, before the first physics frame.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	# grabbed here (not _ready) because the oil manager joins its group in its own _ready first
	_oil_mgr = get_tree().get_first_node_in_group("oil_manager")
	_field = get_tree().get_first_node_in_group("reach_field")
	# map reaches (slice 5) set camera_bounds; classic reaches leave it Rect2() (size.x == 0) and
	# the Camera2D keeps its scene-authored (unlimited) limits. camera_bounds is authored cove-local
	# (ReachMap builds it from map_origin, which never accounts for the Cove node's own transform),
	# but Camera2D.limit_* are WORLD pixels — the cove sits at a non-zero offset in every wrapper
	# scene (main.tscn: (402, 28)), so convert corner-by-corner through the parent Cove's transform
	# rather than trusting cove-local == global. Safe to read _cam here even though it's @onready:
	# setup() is called from the Cove root's _ready(), which runs AFTER every child's own _ready()
	# (bottom-up tree order) — Axolotl's @onready vars are already populated by then.
	if _cfg.camera_bounds.size.x > 0.0:
		var b := _cfg.camera_bounds
		var tl := (get_parent() as Node2D).to_global(b.position)
		var br := (get_parent() as Node2D).to_global(b.end)
		_cam.limit_left = int(tl.x);   _cam.limit_top = int(tl.y)
		_cam.limit_right = int(br.x);  _cam.limit_bottom = int(br.y)

## Axo position in the cove's (parent) frame — the water bounds are authored there.
## Run standalone (Play Current Scene), the parent is the Window, not a cove: fall back
## to our own frame so the scene stays testable instead of erroring every physics frame.
func _cove_local() -> Vector2:
	var cove := get_parent() as Node2D
	return cove.to_local(global_position) if cove else position

## True while ANY companion is being piloted by joystick (touch shell-spin) — the stick then
## steers the shell, so the axolotl yields its controls. Desktop mouse-piloting leaves this false.
## Iterates the group: with the travelling party there can be several companions in the scene.
func _companion_locks_input() -> bool:
	for c in get_tree().get_nodes_in_group("companion"):
		if c.has_method("wants_input_lock") and c.wants_input_lock():
			return true
	return false

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

	# aim reticle — a small code-drawn indicator of where the current verb points
	_reticle = Reticle.new()
	_reticle.z_index = 4
	add_child(_reticle)

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

	# menus (title / settings / rest card) own the input; the cove keeps living behind them. also
	# yield the controls while the turtle is joystick-piloted (touch shell-spin — the stick steers
	# the shell, so the axolotl holds still; desktop pilots with the mouse and stays free to swim).
	var ui := Settings.ui_locked() or _companion_locks_input()
	var dir := 0.0 if ui else Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		_face = signf(dir)
	var running := not ui and Input.is_action_pressed("run")

	# --- spray: clean oil blobs in front of the axo (works on land or in the water) ---
	var spraying := not ui and Input.is_action_pressed("spray")
	_spray_p.emitting = spraying
	Sfx.loop("spray", spraying, -6.0)
	# shared aim vector for every verb (mouse on desktop, stick/keys on touch)
	var aim := _aim(dir)
	var mouse_aim := Settings.aim_with_mouse()
	var aiming := not ui and (spraying or Input.is_action_pressed("bubble") or Input.is_action_pressed("dash"))
	# desktop: a live crosshair sitting ON the mouse cursor (subtle when idle, bright when a verb
	# fires); touch/keys: a target out along the aim at the verb's reach, shown only while armed
	var ret_local := get_local_mouse_position() if mouse_aim else aim * tuning.spray_reach
	_reticle.set_target(ret_local, 1.0 if aiming else (0.42 if mouse_aim else 0.0))
	if spraying:
		# aim follows the input direction (stick = analog, keys = 8-way); neutral = facing
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
		if _field != null:
			# lateral span comes from the field (rect: exactly water_left/water_right — the
			# hysteresis numbers below stay verbatim, only the boundary QUERY moves to the field).
			var wb := _field.water_bounds()
			var over_water := local.x > wb.position.x and local.x < wb.position.x + wb.size.x
			if over_water:
				if _in_water:
					submerged = feet > _field.surface_y() - 2.0   # stay in until fully out
				else:
					submerged = feet > _field.surface_y() + 4.0   # dip in to start
		else:
			# standalone-scene testability idiom (see _cove_local): no injected field, fall back
			# to the raw config so the axolotl scene stays runnable/testable on its own.
			var over_water := local.x > _cfg.water_left and local.x < _cfg.water_right
			if over_water:
				if _in_water:
					submerged = feet > _cfg.surface_y - 2.0   # stay in until fully out
				else:
					submerged = feet > _cfg.surface_y + 4.0   # dip in to start
	if submerged and not _in_water:
		_climbing = false         # water always takes over — a curtain dipping below the line hands off to swim
		_enter_water()
	elif not submerged and _in_water:
		_exit_water()
	_in_water = submerged
	_update_bubble(dir, ui)   # launch / steer / release the aimed Bubble Bomb (works anywhere)
	if submerged:
		_swim(delta, dir)
		_juice(delta)
		return

	# --- climbing (designated surfaces): UP on a root curtain latches; UP/DOWN scales it;
	# JUMP hops off; sliding off either end lets go (see game/cove/climb_wall.gd) ---
	if _climbing:
		_climb(delta, dir, ui)
		_juice(delta)
		return
	if not ui and Input.get_axis("move_up", "move_down") < -0.4 and _on_climbable():
		_climbing = true
		velocity = Vector2.ZERO
		_spr.scale = Vector2(1.25, 0.78)   # a grab squash — the latch lands in the body
		Sfx.play("scrub", -14.0, 1.3)      # a soft root-rustle grab
		_climb(delta, dir, ui)
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
	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_jump_spent = false
	else:
		_coyote = maxf(0.0, _coyote - delta)
		velocity.y += tuning.gravity * delta
	if not ui and Input.is_action_just_pressed("jump"):
		if is_on_floor() or _coyote > 0.0:
			velocity.y = tuning.jump_velocity
			_coyote = 0.0
			_spr.scale = Vector2(0.72, 1.28)   # takeoff stretch
			Sfx.play("jump")
		elif not _air_jump_spent:
			# the mid-air GILL-KICK (double jump): one per airtime, a touch softer than the
			# takeoff, refreshed by floor / water / a climb curtain
			_air_jump_spent = true
			velocity.y = tuning.jump_velocity * AIR_JUMP_SCALE
			_spr.scale = Vector2(0.68, 1.32)
			_gill_kick_fx()
			Sfx.play("jump", -2.0, 1.25)       # a brighter chirp for the second hop
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_land()
	_was_on_floor = is_on_floor()
	_animate_land(running, spraying, delta)
	_juice(delta)

## The climbable strip under the axolotl right now, or null. (Designated surfaces only — a couple
## per scene, so polling the group is cheap.)
func _on_climbable() -> Node2D:
	for w in get_tree().get_nodes_in_group("climbable"):
		if w.has_method("has_point") and w.has_point(global_position):
			return w
	return null

## Latched on a root curtain: gravity is off, UP/DOWN inches along it, JUMP hops away. Cresting
## the top hops the axolotl ONTO the ledge (the wall knows which side it's on) so holding UP can
## never re-latch into a jitter; sliding off the bottom just lets go into a normal fall.
func _climb(delta: float, dir: float, ui: bool) -> void:
	_sitting = false
	_idle_t = 0.0
	_air_jump_spent = false          # a curtain refreshes the gill-kick: hop off, kick, chain
	var v := 0.0 if ui else Input.get_axis("move_up", "move_down")
	velocity = Vector2(0.0, v * CLIMB_SPEED)
	move_and_slide()
	if not ui and Input.is_action_just_pressed("jump"):
		_climbing = false               # a deliberate hop off the curtain
		velocity = Vector2(dir * tuning.walk_speed, tuning.jump_velocity * CLIMB_HOP)
		_spr.scale = Vector2(0.72, 1.28)
		Sfx.play("jump")
		return
	var wall := _on_climbable()
	if wall == null:
		_climbing = false
		if v < -0.1:                    # crested the top while climbing UP -> hop onto the ledge
			var side := 1.0
			if is_instance_valid(_climb_wall) and "ledge_side" in _climb_wall:
				side = _climb_wall.ledge_side
			velocity = Vector2(side * 55.0, tuning.jump_velocity * 0.55)
			_face = signf(side)
			_spr.scale = Vector2(0.72, 1.28)
			Sfx.play("jump", -6.0)
		_climb_wall = null
		return
	_climb_wall = wall                  # remembered for the crest hop above
	if absf(v) > 0.1:
		_anims.play(anim_set.wall_climb, _face)
		# climbing juice: a soft rustle + a couple of shaken-loose leaf motes on a cadence
		_climb_fx_cd -= delta
		if _climb_fx_cd <= 0.0:
			_climb_fx_cd = 0.32
			Sfx.play("scrub", -18.0, randf_range(1.25, 1.5))
			_leaf_motes()
	else:
		_anims.play(anim_set.wall_grab, _face)

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
	# BREATHING: when calm, the pose the scale eases back to gently swells instead of sitting at 1:1 —
	# so an idle/hovering axo is alive, not frozen. Active states kick the scale and this rest is ~1:1.
	var calm := clampf(1.0 - absf(velocity.x) / 60.0, 0.0, 1.0)
	var breath := sin(_t * 1.6) * BREATHE * calm
	var rest := Vector2(1.0 - breath * 0.5, 1.0 + breath)
	_spr.scale = _spr.scale.lerp(rest, clampf(SCALE_RECOVER * delta, 0.0, 1.0))
	# LEAN: a springy skew leans the body into horizontal motion (leads the turn, then settles back) —
	# the marquee "offset transform" juice. Skew is on the SPRITE only; movement is untouched.
	_spr.skew = _lean.update(clampf(velocity.x / tuning.run_speed, -1.0, 1.0) * SKEW_MAX, delta)
	var target_tilt := 0.0
	if _in_water:
		target_tilt = clampf(velocity.y / tuning.swim_v, -1.0, 1.0) * TILT_MAX * _face
	_spr.rotation = lerpf(_spr.rotation, target_tilt, clampf(TILT_LERP * delta, 0.0, 1.0))
	# sit & watch (or a full AFK nap): the camera breathes out and the cove becomes the show
	var z := 2.55 if (_sitting or _idle_t >= AFK_AT) else 3.0
	_cam.zoom = _cam.zoom.lerp(Vector2(z, z), clampf(1.5 * delta, 0.0, 1.0))
	# impact shake: a fast-decaying jitter on the camera offset (kicked via shake())
	if _shake > 0.05:
		_shake = move_toward(_shake, 0.0, 11.0 * delta)
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif _cam.offset != Vector2.ZERO:
		_shake = 0.0
		_cam.offset = Vector2.ZERO

func _land() -> void:
	_spr.scale = Vector2(1.3, 0.72)   # landing squash
	_land_t = LAND_CLIP_T
	_dust()
	Sfx.play("land")

signal submerged_changed(on: bool)   # audio keys the underwater muffle off this

func _enter_water() -> void:
	submerged_changed.emit(true)
	_air_jump_spent = false           # water refreshes the gill-kick, like ground
	# DIVE-SPLASH: a real cannonball scrubs the slick around the entry point — the verticality
	# (gill-kick, curtains, floating cliffs) becomes a restoration verb. Gentle slips off a bank
	# stay a plain splash; the burst scales with entry speed up to a full high-dive.
	var impact := clampf(inverse_lerp(DIVE_MIN_SPEED, DIVE_MAX_SPEED, velocity.y), 0.0, 1.0)
	if impact > 0.0:
		get_tree().call_group("oil_manager", "spray_at",
			global_position, 26.0 + 22.0 * impact, 0.30 + 0.45 * impact)
		shake(1.0 + 1.5 * impact)
		_splash(1.2 + 0.8 * impact)
		Sfx.play("splash", -2.0, 0.85)    # deeper whump for a dive
	else:
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

## Current aim: toward the MOUSE cursor on desktop; the input direction (analog stick / 8-way keys,
## facing when neutral) on touch/gamepad. One source of truth for spray, bubble, and the reticle.
func _aim(dir: float) -> Vector2:
	if Settings.aim_with_mouse():
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 2.0:
			return to_mouse.normalized()
		return Vector2(_face, 0.0)
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

## A couple of leaf bits shaken loose from the root curtain as the axolotl climbs — they flutter
## down and fade. Added to the parent (cove frame) so they fall where they were shaken free.
func _leaf_motes() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 3
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.position = _cove_local() + Vector2(_face * 6.0, -2.0)
	p.direction = Vector2(0.0, 1.0)
	p.spread = 40.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(0.0, 60.0)
	p.damping_min = 10.0
	p.damping_max = 30.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(Palette.MOSS.lerp(Palette.LEAF, 0.5), 0.85)
	p.z_index = 6
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)

## True while swimming — public for the bubble's bounce-pad check (`_in_water` stays private).
func swimming() -> bool:
	return _in_water

## Landed on our own live Bubble Bomb: trampoline launch (the bubble pops itself and still
## scrubs/carves). Refreshes the gill-kick — bubble -> bounce -> gill-kick chains are the toy.
func bubble_bounce() -> void:
	velocity.y = tuning.jump_velocity * BOUNCE_SCALE
	_air_jump_spent = false
	_coyote = 0.0
	_spr.scale = Vector2(0.65, 1.35)
	Sfx.play("jump", -1.0, 1.4)

## The mid-air GILL-KICK burst: a tiny ring of aqua droplets flicked off the gills — the double
## jump's own signature, so the second hop reads as a move, not a glitch.
func _gill_kick_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2(0.0, 1.0)         # flicked downward as the kick pushes up
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0.0, 240.0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(Palette.AQUA, 0.85)
	p.position = position + Vector2(0.0, 6.0)
	p.z_index = 8
	get_parent().add_child(p)               # left behind in the world, not carried with us
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

## A small code-drawn aim indicator. On desktop it's a live crosshair sitting ON the mouse cursor
## (subtle when idle, bright while a verb fires); on touch/keys it's a target out along the aim at the
## verb's reach, shown only while a verb is armed. It redraws every frame while visible, so it tracks
## the cursor in realtime. Child of the axolotl body (unaffected by the sprite's skew/tilt juice);
## the target is in body-local space.
class Reticle extends Node2D:
	var _target := Vector2.RIGHT * 40.0   # where to draw, in body-local space
	var _lit := 0.0                       # eased brightness, 0 hidden .. 1 bright
	var _goal := 0.0

	func set_target(local_pos: Vector2, intensity: float) -> void:
		_target = local_pos
		_goal = intensity

	func _process(delta: float) -> void:
		_lit = move_toward(_lit, _goal, delta * 6.0)
		if _lit > 0.02:
			queue_redraw()   # redraw while visible so the crosshair follows the cursor live

	func _draw() -> void:
		if _lit <= 0.02:
			return
		var p := _target
		var a := 0.9 * _lit
		draw_line(Vector2.ZERO, p, Color(Palette.CYAN, 0.10 * _lit), 1.0)   # faint lead line
		draw_arc(p, 6.0, 0.0, TAU, 20, Color(Palette.CYAN, a), 1.5, true)   # crosshair ring
		for k in 4:                                                          # four tick marks
			var d := Vector2.from_angle(float(k) * PI * 0.5)
			draw_line(p + d * 4.0, p + d * 8.0, Color(Palette.FOAM, a), 1.5)
