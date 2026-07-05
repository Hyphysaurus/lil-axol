extends Node2D
## The Rescued Friend — an oil-matted little TURTLE asleep in the cove's far corner (SeethingSwarm,
## same artist as the axolotl). Spray them close and sustained (D-0006's skill verb) and the oil
## washes off: they wake, chirp, award Shine, and follow the tidekeeper for the rest of the day,
## helping scrub. The rig is data-driven: swap `frames`/`anims`/tints to make this a Frog or Otter
## companion with zero code changes. New Day resets the rescue — that's part of the loop.

## Once awake it FOLLOWS you and helps scrub — and you can POINT-AND-CLICK a spot to send it there
## to demolish rubble (its deep-sea-demolition purpose): click (or tap) the water, it swims to the
## mark, rams any "blastable" there until it's clear, then rejoins you.

const RING_SHADER := preload("res://shaders/ring.gdshader")   # the "go here" command ping
const WHITE := preload("res://assets/white.png")

@export var frames: SpriteFrames = preload("res://game/companion/turtle_frames.tres")
@export var anims: CharacterAnimSet = preload("res://game/companion/turtle_anims.tres")
@export var clean_tint := Color(1.0, 1.0, 1.0)      # the turtle's own colours once washed (no tint)
@export var oiled_tint := Color(0.52, 0.47, 0.40)   # matted & grimy but VISIBLE — you must spot it

const RESCUE_SECONDS := 1.8    # cumulative close-spray time to wash them awake
const RESCUE_REACH := 48.0     # how close the spray must land (forgiving — it's a small target)
const FOLLOW_GAP := 30.0       # stops this far from the player
const FOLLOW_SPEED := 3.2      # lerp rate toward the follow point
const HELP_EVERY := 3.5        # seconds between helper scrubs
const HELP_RADIUS := 14.0
const DEMOLISH_RADIUS := 40.0  # its demolition reach once it arrives at the marked rubble
const BASH_INTERVAL := 0.32    # one shell-swing carves this often — paced so the ram READS as
                               # repeated bashing (not an instant vaporise)
const LUNGE_REACH := 8.0       # how far the shell jabs forward on the swing that connects
const MAX_COMMAND_TIME := 8.0  # a demolition run always ends by here (anti-stuck safety net)
const CHARGE_SPEED := 220.0    # px/s shelled dash to the mark — it shells up the INSTANT you command it
const COMMAND_ARRIVE := 10.0   # dashes right onto the tapped spot before it rams (so it clears a
                               # nook-sized cluster in one command, not leaving a sliver)
const BOB_AMP := 2.5
const BONUS := 500.0

enum State { SLEEPING, WAKING, FOLLOWING }

var _cfg: CoveConfig
var _state := State.SLEEPING
var _spr: AnimatedSprite2D
var _anims: AnimationController
var _progress := 0.0
var _help_t := 0.0
var _commanding := false
var _command_local := Vector2.ZERO
var _bash_t := 0.0                 # counts down to the next shell-swing while demolishing
var _lunge := 0.0                  # 1 on a swing, decays -> the shell's forward jab offset
var _tucked := false               # true once it's tucked into its shell for this run
var _bashing := false              # false = swimming to the mark, true = grinding the rubble
var _cmd_t := 0.0                  # elapsed command time (drives the anti-stuck timeout)
var _zzz: CPUParticles2D           # sleepy oil bubbles that draw the eye to the matted friend
var _oil_a := 1.0                  # alpha of the dark oil stain drawn under the friend (washed to 0)
var _t := 0.0
var _face := -1.0

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
	z_index = 9

## Injected by the Cove composition root.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if not cfg.friend_enabled:
		queue_free()
		return
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
	_anims.play(anims.idle_blink, _face)
	Sfx.play("chirp", -4.0)            # a cute vocal chirp as the friend wakes (GameBurp)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("bonus"):
		keeper.bonus(BONUS, global_position)
	await get_tree().create_timer(0.9).timeout
	_state = State.FOLLOWING

func _process(delta: float) -> void:
	_t += delta
	if _state == State.SLEEPING:
		_spr.position.y = sin(_t * 1.6) * 2.0   # a gentle sleeping bob so the matted friend is spottable
		return
	if _state != State.FOLLOWING or _cfg == null:
		return
	if _commanding:
		_run_command(delta)               # on a click-mission to demolish rubble at the mark
		return
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo == null:
		return
	# follow the tidekeeper anywhere — this little turtle has legs, so it climbs up OUT of the water
	# onto land to keep up (swims below the surface, hops/walks above it)
	var target := (get_parent() as Node2D).to_local(axo.global_position) + Vector2(0.0, -6.0)
	target.x = clampf(target.x, _cfg.water_left + 8.0, _cfg.water_right - 8.0)
	target.y = minf(target.y, _cfg.seabed_y)          # never sink through the floor; free to rise ashore
	var gap := target - position
	var in_water := position.y > _cfg.surface_y + 4.0
	if gap.length() > FOLLOW_GAP:
		position += gap * clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
		if absf(gap.x) > 4.0:
			_face = signf(gap.x)
		if in_water:
			_anims.play(anims.swim, _face)            # paddling through the water
		elif gap.y < -18.0:
			_anims.play(anims.jump, _face)            # hopping up out of the water / onto a ledge
		else:
			_anims.play(anims.run if gap.length() > 70.0 else anims.walk, _face)   # trotting on land
	else:
		_anims.play(anims.swim_idle if in_water else anims.idle, _face)
	if in_water:
		position.y += sin(_t * 2.4) * BOB_AMP * delta   # a gentle float, only while submerged
	# a little helper, not a replacement: scrub a small patch when there's film above us
	_help_t -= delta
	if _help_t <= 0.0:
		_help_t = HELP_EVERY
		var mgr = get_tree().get_first_node_in_group("oil_manager")
		if mgr and mgr.has_method("oil_at") and mgr.oil_at(global_position) > 0.1:
			mgr.spray_at(global_position, HELP_RADIUS, 0.35)

## Point-and-click: mark a spot in the water and the (awake) turtle goes there to demolish rubble.
## _unhandled_input, so it only fires when the click/tap wasn't consumed by the on-screen controls.
## Right-half open-water taps + the desktop mouse arrive here; LEFT-half taps are the joystick's, so
## the touch controls consume them and route the tap through command_to() instead.
func _unhandled_input(event: InputEvent) -> void:
	if _state != State.FOLLOWING:
		return
	# Drop mouse<->touch emulation doubles. emulate_touch_from_mouse (desktop) and
	# emulate_mouse_from_touch (mobile, on by default) each deliver a SECOND, synthetic copy
	# (device -1) of every click/tap. Without this, one input fires the command twice (two ping
	# rings on desktop) and on mobile a tap on ANY on-screen button leaks a stray command at the
	# button's location — sending the turtle to the corner every time you spray or move.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		command_to(get_global_mouse_position())
	elif event is InputEventScreenTouch and event.pressed:
		command_to(get_viewport().get_canvas_transform().affine_inverse() * event.position)

## Send the (awake) turtle to demolish rubble at a WORLD point. Public + reached via the "companion"
## group so the touch controls can route a left-side tap here without knowing about this node.
func command_to(world: Vector2) -> void:
	if _state != State.FOLLOWING:
		return
	_command_local = (get_parent() as Node2D).to_local(world)
	_commanding = true
	_bashing = false
	_cmd_t = 0.0
	_bash_t = BASH_INTERVAL          # wind up once before the first swing lands
	_lunge = 0.0
	_spr.position.x = 0.0
	if absf(_command_local.x - position.x) > 4.0:
		_face = signf(_command_local.x - position.x)   # face the target before shelling
	_tucked = false
	_tuck()                          # shell up the INSTANT you command it (foam-masked), then dash
	_ping(_command_local)

## A demolition run: swim to the tapped mark, then GRIND through the whole rubble cluster there —
## drifting to reach every remaining cell — bashing on a beat until nothing's left, then emerge and
## rejoin. Shelled the whole time (tucked exactly once, with a foam mask). A timeout guarantees the
## run can never hang.
func _run_command(delta: float) -> void:
	_cmd_t += delta
	if _cmd_t > MAX_COMMAND_TIME:          # anti-stuck safety net
		_end_command()
		return
	# --- CHARGE: already shelled (tucked on command) — dash to the mark at a constant, punchy speed ---
	if not _bashing:
		# reach the WHOLE cove — the water AND up onto the beach (it has legs) — so you can send it at
		# a land nook, not just a submerged vent. Bounds relax ~a beach-width left + above the waterline.
		var mark := _command_local
		mark.x = clampf(mark.x, _cfg.water_left - 260.0, _cfg.water_right - 14.0)
		mark.y = clampf(mark.y, _cfg.surface_y - 70.0, _cfg.seabed_y)
		var gap := mark - position
		if gap.length() > COMMAND_ARRIVE:
			if absf(gap.x) > 4.0:
				_face = signf(gap.x)
			position += gap.normalized() * minf(CHARGE_SPEED * delta, gap.length())
			return
		_bashing = true                    # reached the mark -> start smashing
	# --- BASH: shelled, bash EXACTLY where you sent it until that spot's rubble is gone (it stays
	# put — no auto-hunting for other rubble; you direct each strike) ---
	_tuck()                                # ensure shelled (covers a very close tap)
	_lunge = move_toward(_lunge, 0.0, delta * 7.0)
	_spr.position.x = _face * _lunge * LUNGE_REACH
	_bash_t -= delta
	if _bash_t > 0.0:
		return                             # winding up / recoiling between swings
	_bash_t = BASH_INTERVAL
	var hit := 0
	for b in get_tree().get_nodes_in_group("blastable"):
		if b.has_method("blast"):
			hit += b.blast(global_position, DEMOLISH_RADIUS)
	if hit > 0:
		_lunge = 1.0                       # snap the shell forward on the swing that connects
		_ram_fx()
	else:                                  # the tapped spot is clear -> emerge and rejoin you
		_end_command()

## Tuck into the shell exactly once per run — a foam burst masks the transform so the tuck frames
## never read as janky.
func _tuck() -> void:
	if _tucked:
		return
	_tucked = true
	_anims.play(anims.shell_tuck, _face)
	_shell_puff(18, 120.0, 3.2, Color(Palette.FOAM, 0.92))
	Sfx.play("splash", -8.0, 1.2)

## Pop out of the shell and hand back to following — a smaller foam pop marks the final impact.
func _end_command() -> void:
	_spr.position.x = 0.0
	_shell_puff(11, 85.0, 2.3, Color(Palette.FOAM, 0.85))
	_anims.play(anims.shell_emerge, _face)
	_commanding = false

## A soft "go here" ring where you clicked, so the command reads.
func _ping(local: Vector2) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	var s := Sprite2D.new()
	s.texture = WHITE
	s.material = mat
	s.scale = Vector2(46.0, 46.0)
	s.position = local
	s.z_index = 8
	get_parent().add_child(s)
	var tw := s.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("t", v), 0.0, 1.0, 0.5)
	tw.tween_callback(s.queue_free)

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

## A dark oil stain pooled UNDER the matted friend, drawn behind the sprite (a node's own _draw
## renders before its children). Thins to nothing as you wash them awake — reads as oil, not a
## pale shader blob (the previous oil-shader sheen washed out under the god-rays).
func _draw() -> void:
	if _oil_a <= 0.01:
		return
	var a := 0.5 * _oil_a
	draw_circle(Vector2(-8.0, 6.0), 15.0, Color(Palette.INK, a))
	draw_circle(Vector2(11.0, 7.0), 12.0, Color(Palette.INK, a))
	draw_circle(Vector2(1.0, 9.0), 19.0, Color(Palette.INK, a * 0.9))

## A quick foam burst that MASKS a shell transition — the turtle vanishes into the splash and comes
## out in its new stance, so the transition frames never read as awkward. Used big for the tuck-in on
## the charge, and as a smaller pop on the emerge so the final impact reads. `amount`/`vmax`/`scale`
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

## A burst of water wake + spray thrown forward as the shell grinds into the rock.
func _ram_fx() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.position = Vector2(_face * 14.0, 0.0)   # off the front of the shell, toward the rock
	p.direction = Vector2(_face, -0.3)
	p.spread = 55.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0.0, 120.0)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color = Color(Palette.CYAN, 0.85)
	p.z_index = 10
	add_child(p)
	p.finished.connect(p.queue_free)
