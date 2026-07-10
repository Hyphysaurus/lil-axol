extends Node2D
## The Rescued Friend — an oil-matted little TURTLE asleep in the cove's far corner (SeethingSwarm,
## same artist as the axolotl). Spray them close and sustained (D-0006's skill verb) and the oil
## washes off: they wake, chirp, award Shine, and follow the tidekeeper for the rest of the day,
## helping scrub. The rig is data-driven: swap `frames`/`anims`/tints to make this a Frog or Otter
## companion with zero code changes. New Day resets the rescue — that's part of the loop.

## Once awake it FOLLOWS you and helps scrub. Its demolition verb is the SHELL-SPIN: HOLD the Shell
## action (Z / hold Right-Mouse on desktop; the on-screen Shell button on touch) and the turtle tucks
## and becomes a steerable spinning shell that homes to your cursor (or the joystick on touch),
## grinding a continuous tunnel through any "blastable" rubble it crosses. A stamina ring drains while
## it spins and recharges between spins; empty = it pops out dizzy for a beat. Steering the shell to
## carve tunnels doubles as traversal. (The FROG companion isn't piloted — it auto-tongues debris.)

const Spring := preload("res://game/fx/spring.gd")   # offset-transform juice helper (lean/skew)

@export var frames: SpriteFrames = preload("res://game/companion/turtle_frames.tres")
@export var anims: CharacterAnimSet = preload("res://game/companion/turtle_anims.tres")
@export var clean_tint := Color(1.0, 1.0, 1.0)      # the turtle's own colours once washed (no tint)
@export var oiled_tint := Color(0.52, 0.47, 0.40)   # matted & grimy but VISIBLE — you must spot it

const RESCUE_SECONDS := 1.8    # cumulative close-spray time to wash them awake
const RESCUE_REACH := 48.0     # how close the spray must land (forgiving — it's a small target)
const FOLLOW_GAP := 30.0       # stops this far from the player
const FOLLOW_SPEED := 3.2      # lerp rate toward the follow point
const FOLLOW_LIFT_WATER := -6.0   # swims a touch below the surface
const FOLLOW_LIFT_LAND := 3.0     # rests ON the land blocks — the 40px turtle frame sits high on land
                                  # otherwise (it hovered a few px); raise this to drop it further
const HELP_EVERY := 3.5        # seconds between helper scrubs
const HELP_RADIUS := 14.0
const BOB_AMP := 2.5
const TURTLE_SKEW := 0.14      # how far the turtle leans (skews) into its follow direction, radians
# Shine for the rescue lives in the "wake_up" feat (shine.FEATS).

# --- SHELL-SPIN (turtle demolition): HOLD Shell to pilot a spinning shell that homes to the cursor
# and grinds a continuous tunnel through rubble, on a stamina meter that recharges between spins ---
const SHELL_SPEED := 250.0        # px/s the spinning shell travels
const SHELL_STEER := 7.0          # how fast the heading curves toward the aim (lower = wider PK arcs)
const SHELL_MIN_FRAC := 0.6       # never drops below this fraction of top speed (always gliding)
const SHELL_CARVE_RADIUS := 13.0  # carve reach along the shell's path (~1.6 rock cells)
const SHELL_CARVE_EVERY := 0.05   # carve this often so the tunnel reads continuous
const SPIN_SPEED := 20.0          # shell rotation, rad/s (the tucked frame spun in code)
const STAMINA_SECONDS := 3.0      # full-spin duration
const REFILL_SECONDS := 2.4       # empty -> full recharge time while resting
const START_MIN := 0.25           # need at least this much stamina to LAUNCH a new spin
const DIZZY_TIME := 0.55          # brief stun after fully exhausting the shell

# --- frog tongue-grab: the frog AUTO-tongues floating debris that drifts within reach WHILE it follows
# (no point-and-click darting — you bring the frog near the muck and it cleans it) ---
const TONGUE_REACH := 56.0     # floating debris within this of the frog gets auto-snagged
const TONGUE_COOLDOWN := 0.7   # min seconds between tongue strikes (so it isn't a machine gun)

enum State { SLEEPING, WAKING, FOLLOWING }
enum Kind { TURTLE, FROG }      # TURTLE = shell-spin demolition; FROG = tongue-grab (config-selected)

signal woke   # emitted once when the rescue ceremony completes (WorldState files friend_awake off this)

var _cfg: CoveConfig
var _kind := Kind.TURTLE
var _state := State.SLEEPING
var _spr: AnimatedSprite2D
var _anims: AnimationController
var _progress := 0.0
var _help_t := 0.0
var _was_air := false              # airborne last frame? (drives the land-clip touchdown beat)
var _land_t := 0.0                 # remaining time the landing clip + squash own the sprite
var _zzz: CPUParticles2D           # sleepy oil bubbles that draw the eye to the matted friend
var _oil_a := 1.0                  # alpha of the dark oil stain drawn under the friend (washed to 0)
var _t := 0.0
var _face := -1.0
var _lean := Spring.new(0.0, 55.0)   # springy body-lean (skew) into the follow direction — offset juice
var _tongue_cd := 0.0                # cooldown between auto-tongue strikes
var _strike_t := 0.0                 # remaining time the tongue clip owns the sprite (over follow anims)

# shell-spin state
var _piloting := false
var _stamina := 1.0                # 0..1 shell energy
var _dizzy_t := 0.0                # post-exhaust stun lock
var _shell_vel := Vector2.ZERO
var _spin := 0.0                   # accumulated shell rotation while piloting
var _carve_t := 0.0                # counts down to the next carve along the path
var _grinding := false             # carving rubble right now? (drives the continuous grind loop)
var _steer_axis := false           # steering source: true = joystick (touch), false = mouse (desktop)
var _shell_p: CPUParticles2D       # electric energy trail behind the spinning shell
var _crunch_cd := 0.0              # throttles the per-bite crunch SFX (no machine-gun)
var _meaty_cd := 0.0               # throttles hitstop so only spaced-out hits freeze the frame
var _flash := 0.0                  # white impact flash on the shell sprite, decays fast

func _ready() -> void:
	add_to_group("sprayable")          # receives the player's spray hits
	add_to_group("companion")          # so the hint system can find + read our state
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = frames
	_spr.modulate = oiled_tint
	add_child(_spr)
	_anims = AnimationController.new(_spr)
	_zzz = _make_zzz()
	add_child(_zzz)
	_shell_p = _make_shell_trail()
	add_child(_shell_p)
	z_index = 9

## Injected by the Cove composition root.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if not cfg.friend_enabled:
		queue_free()
		return
	# data-driven companion: config can swap the art + verb so ONE rig is the turtle OR the frog
	_kind = cfg.friend_kind
	if cfg.friend_frames:
		frames = cfg.friend_frames
		_spr.sprite_frames = frames
	if cfg.friend_anims:
		anims = cfg.friend_anims
	scale = Vector2.ONE * cfg.friend_scale   # on the node (not _spr) so the squash juice stays 1:1-based
	position = cfg.friend_pos
	_anims.play(anims.sleep, _face)

## The player's spray reaching us — same signature as the oil manager's brush, via the
## generic "sprayable" group. Sustained close spray is what washes a friend awake.
func spray_at(world_pos: Vector2, _radius: float, delta: float) -> void:
	if _state != State.SLEEPING:
		return
	if world_pos.distance_to(global_position) > RESCUE_REACH:
		return
	_progress += delta
	# oil visibly washing off the friend AND the slick around them as you work
	var washed := clampf(_progress / RESCUE_SECONDS, 0.0, 1.0)
	_spr.modulate = oiled_tint.lerp(clean_tint, washed)
	_oil_a = 1.0 - washed              # the oil stain under them thins as you scrub
	queue_redraw()
	if _progress >= RESCUE_SECONDS:
		_wake()

func _wake() -> void:
	_state = State.WAKING
	_zzz.emitting = false              # no longer matted — the sleepy oil bubbles stop
	_oil_a = 0.0                       # the oil stain is gone
	queue_redraw()
	_spr.modulate = clean_tint
	_anims.play(anims.fright, _face)   # startles awake first — a little jolt before it settles
	Sfx.play("chirp", -4.0)            # a cute vocal chirp as the friend wakes (GameBurp)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"wake_up", global_position)   # "Wake-Up Call" feat: callout + Flow + Shine
	Settings.roster_add(_kind)   # the rescued friend joins the roster (chips HUD); was never wired
	woke.emit()
	await get_tree().create_timer(0.5).timeout
	if _state != State.WAKING:          # (a New Day reset could have freed/retired us mid-wait)
		return
	_anims.play(anims.idle_blink, _face)   # ...then blinks and looks around before it follows
	await get_tree().create_timer(0.4).timeout
	_state = State.FOLLOWING
	get_tree().call_group("restoration", "notify_progress")   # rescuing me may complete the win

## Public read for the win gate — has this friend been rescued (no longer asleep in its corner)?
func is_awake() -> bool:
	return _state != State.SLEEPING

## Persistence spawn path: start this friend already rescued — no ceremony, no feat, no Shine,
## straight to FOLLOWING. Mirrors _wake()'s end state (tint, stain, zzz) and registers roster
## membership WITHOUT stealing the active-partner slot.
func wake_instant() -> void:
	if _state != State.SLEEPING:
		return
	_state = State.FOLLOWING
	_progress = RESCUE_SECONDS
	_zzz.emitting = false
	_oil_a = 0.0
	_spr.modulate = clean_tint
	Settings.roster_include(_kind)   # register WITHOUT stealing the player's active-partner choice
	queue_redraw()

## True while the turtle is being actively piloted with the JOYSTICK (touch) — the axolotl reads this
## to hand the stick to the shell and hold still. On desktop the shell is mouse-steered, so this stays
## false and the axolotl keeps swimming freely while you pilot.
func wants_input_lock() -> bool:
	return _piloting and _steer_axis

func _process(delta: float) -> void:
	_t += delta
	if _state == State.SLEEPING:
		_spr.position.y = sin(_t * 1.6) * 2.0   # a gentle sleeping bob so the matted friend is spottable
		return
	if _state != State.FOLLOWING or _cfg == null:
		return
	if _piloting:
		_run_pilot(delta)                 # shell-spin demolition (the frog isn't piloted)
		return
	# recharge the shell between spins; tick down any dizzy lock
	_dizzy_t = maxf(0.0, _dizzy_t - delta)
	if _stamina < 1.0:
		_stamina = minf(1.0, _stamina + delta / REFILL_SECONDS)
		queue_redraw()
	# start a spin: HOLD Shell (turtle only) with enough charge, when no menu is up
	if _kind == Kind.TURTLE and _dizzy_t <= 0.0 and _stamina >= START_MIN \
			and not Settings.ui_locked() and _shell_held():
		_begin_pilot()
		return
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo == null:
		return
	# follow the tidekeeper anywhere — this little turtle has legs, so it climbs up OUT of the water
	# onto land to keep up (swims below the surface, hops/walks above it)
	var in_water := position.y > _cfg.surface_y + 4.0
	var lift := FOLLOW_LIFT_WATER if in_water else FOLLOW_LIFT_LAND   # sit ON the blocks on land, lift in water
	var target := (get_parent() as Node2D).to_local(axo.global_position) + Vector2(0.0, lift)
	if _kind == Kind.FROG:
		# the frog is a SURFACE-AND-LAND creature (spec §9): it rides the waterline and hops the
		# banks/lilypads — never dives. Clamping the follow target here retires the deep-water
		# swim jank at the source; the axolotl remains free to dip under alone.
		target.y = minf(target.y, _cfg.surface_y - 2.0)
	target.x = clampf(target.x, _cfg.water_left - 260.0, _cfg.water_right - 8.0)   # onto the BEACH too, not just the water's edge
	target.y = minf(target.y, _cfg.seabed_y)          # never sink through the floor; free to rise ashore
	var gap := target - position
	_land_t = maxf(0.0, _land_t - delta)
	# out of water and climbing/dropping toward the target sharply = mid-hop (jump on the way up,
	# fall on the way down); the follow model has no physics arc, so we read it off the gap
	var airborne := not in_water and gap.length() > FOLLOW_GAP and absf(gap.y) > 18.0
	if _was_air and not airborne and not in_water:
		_land_t = 0.18                               # just touched down -> a brief landing beat
		_spr.scale = Vector2(1.18, 0.82)             # a little squash on impact
	_was_air = airborne
	_strike_t = maxf(0.0, _strike_t - delta)
	var moving := gap.length() > FOLLOW_GAP
	if moving:
		position += gap * clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
		if absf(gap.x) > 4.0:
			_face = signf(gap.x)
	if _strike_t <= 0.0:                               # while a tongue-strike plays, don't override it
		if moving:
			if in_water:
				_anims.play(anims.swim, _face)            # paddling through the water
			elif _land_t > 0.0:
				_anims.play(anims.land, _face)            # the touchdown squash owns the sprite briefly
			elif gap.y < -18.0:
				_anims.play(anims.jump, _face)            # hopping up out of the water / onto a ledge
			elif gap.y > 18.0:
				_anims.play(anims.fall, _face)            # dropping back down toward the water / a lower ledge
			else:
				_anims.play(anims.run if gap.length() > 70.0 else anims.walk, _face)   # trotting on land
		elif _land_t > 0.0:
			_anims.play(anims.land, _face)                # landed right at the follow point
		else:
			_anims.play(anims.swim_idle if in_water else anims.idle, _face)
	_spr.scale = _spr.scale.lerp(Vector2.ONE, clampf(9.0 * delta, 0.0, 1.0))   # settle the landing/chomp squash
	_spr.skew = _lean.update(clampf(gap.x / 70.0, -1.0, 1.0) * TURTLE_SKEW, delta)   # lean into the follow
	if in_water:
		position.y += sin(_t * 2.4) * BOB_AMP * delta   # a gentle float, only while submerged
	if _kind == Kind.FROG:
		_auto_tongue(delta)   # snag any floating debris that drifted within reach as we followed
	# a little helper, not a replacement: scrub a small patch when there's film above us
	_help_t -= delta
	if _help_t <= 0.0:
		_help_t = HELP_EVERY
		var mgr = get_tree().get_first_node_in_group("oil_manager")
		if mgr and mgr.has_method("oil_at") and mgr.oil_at(global_position) > 0.1:
			mgr.spray_at(global_position, HELP_RADIUS, 0.35)

# --- SHELL-SPIN ---------------------------------------------------------------------------------

## Is the Shell action held? Z / a gamepad button feed the "shell" action; on desktop, holding Right
## Mouse also pilots (so you steer with the cursor one-handed). Touch presses "shell" via its button.
func _shell_held() -> bool:
	if Input.is_action_pressed("shell"):
		return true
	return not Settings.touch_active() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

## Where the shell is homing, in our parent (cove) frame: the mouse on desktop, the joystick heading
## on touch/gamepad (a point projected ahead of the shell so it always has somewhere to go).
func _steer_target() -> Vector2:
	if _steer_axis:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v.length() < 0.2:
			var head := _shell_vel.normalized() if _shell_vel.length() > 1.0 else Vector2(_face, 0.0)
			return position + head * 60.0
		return position + v * 120.0
	return (get_parent() as Node2D).to_local(get_global_mouse_position())

## Tuck into the shell (foam-masked) and launch it toward the cursor.
func _begin_pilot() -> void:
	_piloting = true
	_steer_axis = Settings.touch_active()
	_carve_t = 0.0
	_grinding = false
	_lean.value = 0.0
	_lean.vel = 0.0
	_spr.skew = 0.0
	_spr.position = Vector2.ZERO
	_anims.play(anims.shell_tuck, _face)
	_shell_puff(18, 120.0, 3.2, Color(Palette.FOAM, 0.92))
	Sfx.play("splash", -8.0, 1.2)
	Sfx.play("swish", -3.0, 0.85)             # a deeper launch whoosh — the wind-up THUMP
	Input.start_joy_vibration(0, 0.4, 0.0, 0.12)
	var axo := get_tree().get_first_node_in_group("player")
	if axo and axo.has_method("shake"):
		axo.shake(1.0)                        # a small kick as the shell fires off
	var d := _steer_target() - position
	_shell_vel = (d.normalized() if d.length() > 4.0 else Vector2(_face, 0.0)) * SHELL_SPEED
	_shell_p.emitting = true

## Pilot the spinning shell: curve toward the aim, keep gliding, carve any rubble along the path,
## drain stamina. Ends on release, on a menu opening, or when the shell exhausts (pops out dizzy).
func _run_pilot(delta: float) -> void:
	if Settings.ui_locked() or not _shell_held():
		_end_pilot(false)
		return
	_stamina -= delta / STAMINA_SECONDS
	if _stamina <= 0.0:
		_stamina = 0.0
		_end_pilot(true)
		return
	# steer: curve the heading toward the aim, never dropping below a gliding minimum speed
	var to := _steer_target() - position
	var desired := (to.normalized() if to.length() > 6.0 else _shell_vel.normalized()) * SHELL_SPEED
	_shell_vel = _shell_vel.lerp(desired, clampf(SHELL_STEER * delta, 0.0, 1.0))
	if _shell_vel.length() < SHELL_SPEED * SHELL_MIN_FRAC:
		var head := _shell_vel.normalized() if _shell_vel.length() > 1.0 else Vector2(_face, 0.0)
		_shell_vel = head * SHELL_SPEED * SHELL_MIN_FRAC
	position += _shell_vel * delta
	# stay inside the reach: the water, a beach-width of land on the left, and INTO the right bank's
	# face — the portal plug is carved into that bank, so the shell must be able to chew all the way
	# through it (a tighter bound left an unreachable last column: the un-breakable sliver bug)
	position.x = clampf(position.x, _cfg.water_left - 260.0, _cfg.water_right + 64.0)
	position.y = clampf(position.y, _cfg.surface_y - 70.0, _cfg.seabed_y)
	if absf(_shell_vel.x) > 4.0:
		_face = signf(_shell_vel.x)
	# spin the tucked shell (the sprite holds the shelled frame; we rotate it)
	_spin += SPIN_SPEED * delta
	_spr.rotation = _spin
	_spr.scale = _spr.scale.lerp(Vector2.ONE, clampf(10.0 * delta, 0.0, 1.0))
	# impact juice bookkeeping: SFX/hitstop throttles tick down, the hit-flash decays off the sprite
	_crunch_cd = maxf(0.0, _crunch_cd - delta)
	_meaty_cd = maxf(0.0, _meaty_cd - delta)
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, 7.0 * delta)
		_spr.modulate = clean_tint.lerp(Color(1.9, 1.85, 1.5), _flash)   # a hot white-gold blink
	# aim the energy trail out the BACK of the shell
	_shell_p.direction = (-_shell_vel).normalized() if _shell_vel.length() > 1.0 else Vector2(-_face, 0.0)
	# carve a continuous tunnel through any rubble along the path — evaluated on a 20Hz beat, and the
	# grind loop only toggles on an actual enter/exit-rubble transition (so it's one sustained sound,
	# not a break-boom per cell and not a stutter between beats)
	_carve_t -= delta
	if _carve_t <= 0.0:
		_carve_t = SHELL_CARVE_EVERY
		var hit := 0
		for b in get_tree().get_nodes_in_group("blastable") + get_tree().get_nodes_in_group("turtle_blastable"):
			if b.has_method("blast"):
				hit += b.blast(global_position, SHELL_CARVE_RADIUS, 1.0, true)   # quiet: our grind loop carries the sound
		var now_grinding := hit > 0
		if now_grinding:
			_spr.scale = Vector2(1.16, 0.86)   # a squash pulse as it bites
			_grind_fx()
			_impact(hit, not _grinding)        # crunch / shake / rumble / hitstop, scaled to the bite
		if now_grinding != _grinding:
			_grinding = now_grinding
			Sfx.loop("scrub", _grinding, -7.0)
	queue_redraw()   # the stamina ring drains live

## The DK-style impact stack for a shell bite: a pitch-varied stone CRUNCH (throttled so the 20Hz
## carve never machine-guns), a camera kick, controller rumble / handheld buzz, a hot flash on the
## shell — and on the FIRST contact of a grind (or an extra-meaty bite) a single brief HITSTOP so
## the collision lands in the hands, not just the ears.
func _impact(hit: int, first_contact: bool) -> void:
	_flash = 1.0
	var axo := get_tree().get_first_node_in_group("player")
	if axo and axo.has_method("shake"):
		axo.shake(clampf(0.8 + float(hit) * 0.3, 0.8, 3.5))
	if _crunch_cd <= 0.0:
		_crunch_cd = 0.11
		Sfx.play("break", -12.0 + minf(float(hit), 6.0), randf_range(0.85, 1.25))
		Input.start_joy_vibration(0, 0.5, 0.2, 0.09)
		if Settings.touch_active():
			Input.vibrate_handheld(20)
	if (first_contact or hit >= 6) and _meaty_cd <= 0.0:
		_meaty_cd = 0.35
		Sfx.play("break", -4.0, 0.72)          # one deep bassy THUD under the crunch
		Input.start_joy_vibration(0, 0.7, 0.9, 0.16)
		_hitstop(0.12, 0.05)

## A single brief global freeze-frame. The restore rides a real-time SceneTreeTimer whose lambda the
## timer itself keeps alive — so time_scale ALWAYS recovers, even if this node is freed mid-stop.
func _hitstop(scale_to: float, dur: float) -> void:
	if Engine.time_scale < 1.0:
		return                                  # already inside a stop — never stack
	Engine.time_scale = scale_to
	var t := get_tree().create_timer(dur, true, false, true)   # ignore_time_scale = true
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)

## Pop out of the shell and hand back to following. `exhausted` = the stamina ran dry (a dizzy beat).
func _end_pilot(exhausted: bool) -> void:
	_piloting = false
	_spr.rotation = 0.0
	_spr.position = Vector2.ZERO
	_spr.modulate = clean_tint       # drop any leftover impact flash
	_flash = 0.0
	_shell_vel = Vector2.ZERO
	_shell_p.emitting = false
	if _grinding:
		_grinding = false
		Sfx.loop("scrub", false)
	_shell_puff(11, 85.0, 2.3, Color(Palette.FOAM, 0.85))
	_anims.play(anims.shell_emerge, _face)
	if exhausted:
		_dizzy_t = DIZZY_TIME
		Sfx.play("chirp", -12.0, 0.8)   # a little dizzy peep
	queue_redraw()

## The frog auto-snags any floating debris that drifts within tongue reach WHILE it follows you — bring
## it near the muck and it cleans it (no command, no darting). A cooldown paces the strikes; the tongue
## clip owns the sprite for a beat (_strike_t) so it reads, then the follow anims resume.
func _auto_tongue(delta: float) -> void:
	_tongue_cd = maxf(0.0, _tongue_cd - delta)
	if _tongue_cd > 0.0:
		return
	var prey := _nearest_grabbable(TONGUE_REACH)
	if prey == null:
		return
	_tongue_cd = TONGUE_COOLDOWN
	_strike_t = 0.4                       # let the tongue clip own the sprite briefly
	var dir := (get_parent() as Node2D).to_local(prey.global_position) - position
	if absf(dir.x) > 2.0:
		_face = signf(dir.x)              # turn toward the prey
	_play_tongue_anim(dir)
	prey.grab(global_position)            # reel it in + cleanse (floating_debris.grab)
	_spr.scale = Vector2(1.15, 0.85)      # a little chomp squash

## Nearest node in group "grabbable" within `reach` of the frog, or null.
func _nearest_grabbable(reach: float) -> Node2D:
	var best: Node2D = null
	var best_d := reach
	for g in get_tree().get_nodes_in_group("grabbable"):
		var d: float = (g as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = g
	return best

## Pick the directional tongue clip from the aim + whether the frog is submerged (it has both sets).
func _play_tongue_anim(dir: Vector2) -> void:
	var in_water := position.y > _cfg.surface_y + 4.0
	var clip: StringName
	if dir.y < -absf(dir.x) * 0.6:          # mostly upward
		clip = anims.swim_tongue_up if in_water else anims.tongue_up
	elif absf(dir.y) > absf(dir.x) * 0.4:   # angled
		clip = anims.swim_tongue_diag if in_water else anims.tongue_diag
	else:                                    # straight forward
		clip = anims.swim_tongue_fwd if in_water else anims.tongue_fwd
	_anims.play(clip, _face)

## Sleepy dark oil bubbles rising off the matted friend — thematic, and they draw the eye so you
## can spot it in its corner (the camera only reveals the corner when you swim over).
func _make_zzz() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 6
	p.lifetime = 1.8
	p.position = Vector2(0.0, -6.0)
	p.direction = Vector2(0.15, -1.0)
	p.spread = 12.0
	p.gravity = Vector2(0.0, -12.0)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 14.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color = Color(Palette.INK, 0.5)
	p.z_index = 10
	return p

## The electric energy trail behind the spinning shell (PK-Thunder feel, code-only for now — the
## owned Gigapack Lightning strip is the drop-in polish upgrade). Emits in world space so it streaks.
func _make_shell_trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = false
	p.amount = 26
	p.lifetime = 0.45
	p.spread = 26.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2.ZERO
	p.texture = preload("res://assets/fx/bubble.png")   # soft round motes so the trail actually READS
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.color = Color(Palette.CYAN, 0.9)   # electric cyan crackle
	p.z_index = 8
	return p

## A dark oil stain pooled UNDER the matted friend (drawn behind the sprite), plus the shell-spin
## stamina ring while it's relevant. The stain thins to nothing as you wash them awake.
func _draw() -> void:
	# the matted oil stain, only while still oily
	if _oil_a > 0.01:
		var a := 0.5 * _oil_a
		draw_circle(Vector2(-8.0, 6.0), 15.0, Color(Palette.INK, a))
		draw_circle(Vector2(11.0, 7.0), 12.0, Color(Palette.INK, a))
		draw_circle(Vector2(1.0, 9.0), 19.0, Color(Palette.INK, a * 0.9))
	# shell-spin energy aura: a pulsing electric halo behind the whirling shell so the spin reads as a
	# charged, spinning ball (behind the sprite; the trail + stamina ring complete the look)
	if _piloting:
		var pz := 0.5 + 0.5 * sin(_spin * 3.0)
		for i in 3:
			draw_circle(Vector2.ZERO, 15.0 + float(i) * 6.0 + pz * 4.0,
				Color(Palette.CYAN, (0.16 - float(i) * 0.045) * (0.6 + 0.4 * pz)))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(Palette.FOAM, 0.4 + 0.35 * pz), 2.0, true)
	# shell-spin energy ring: shows while piloting, recharging, or dizzy so the stamina always reads
	if _kind == Kind.TURTLE and _state == State.FOLLOWING and (_piloting or _stamina < 1.0 or _dizzy_t > 0.0):
		var c := Vector2(0.0, -2.0)
		var r := 20.0
		draw_arc(c, r, 0.0, TAU, 28, Color(Palette.INK, 0.30), 2.0, true)                        # track
		var col: Color = Palette.CYAN if _stamina > 0.3 and _dizzy_t <= 0.0 else Palette.GOLD    # low/dizzy = warm
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * _stamina, 28, Color(col, 0.9), 2.5, true)    # charge fill

## A quick foam burst that MASKS a shell transition — the turtle vanishes into the splash and comes
## out in its new stance, so the transition frames never read as awkward. `amount`/`vmax`/`scale`
## scale the puff.
func _shell_puff(amount: int, vmax: float, scale_max: float, tint: Color) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = vmax * 0.4
	p.initial_velocity_max = vmax
	p.gravity = Vector2(0.0, 70.0)
	p.damping_min = 30.0
	p.damping_max = 80.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = scale_max
	p.color = tint
	p.z_index = 12                        # over the turtle sprite (z 9), masking the transition
	add_child(p)
	p.finished.connect(p.queue_free)

## A burst of grit + spray thrown out as the shell grinds into rock — added to the parent (cove
## frame) so the bits stay where the shell bit, not glued to the moving shell.
func _grind_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.45
	p.explosiveness = 0.9
	p.position = global_position + Vector2(_face * 12.0, 0.0)   # off the front of the shell
	p.direction = Vector2(-_face, -0.4)
	p.spread = 60.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0.0, 180.0)
	p.damping_min = 30.0
	p.damping_max = 80.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	p.color = Palette.STEEL               # rock grit
	p.z_index = 10
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
