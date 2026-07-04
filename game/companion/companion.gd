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
const DEMOLISH_RADIUS := 34.0  # its demolition reach once it arrives at the marked rubble
const COMMAND_SPEED := 5.0     # swims to a click-marked spot faster than it follows (on a mission)
const COMMAND_ARRIVE := 26.0   # within this of the mark counts as "there" — then it rams
const CHARGE_DIST := 60.0      # tucks into its shell and charges the last stretch — a shell-ram
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
var _ramming := false              # shelled + smashing (vs swimming) during a command
var _ram_fx_t := 0.0
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
	# follow point: near the player, but a water creature won't beach itself — if the
	# tidekeeper walks ashore, wait at the water's edge (it reads as loyalty)
	var target := (get_parent() as Node2D).to_local(axo.global_position) + Vector2(0.0, -6.0)
	target.x = clampf(target.x, _cfg.water_left + 14.0, _cfg.water_right - 14.0)
	target.y = maxf(target.y, _cfg.surface_y + 10.0)
	var gap := target - position
	if gap.length() > FOLLOW_GAP:
		position += gap * clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
		if absf(gap.x) > 4.0:
			_face = signf(gap.x)
		_anims.play(anims.swim, _face)
	else:
		_anims.play(anims.swim_idle, _face)
	position.y += sin(_t * 2.4) * BOB_AMP * delta
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
	_ping(_command_local)

## Swim to the marked spot (kept inside the water), then ram any rubble there until it's clear.
func _run_command(delta: float) -> void:
	var tgt := _command_local
	tgt.x = clampf(tgt.x, _cfg.water_left + 14.0, _cfg.water_right - 14.0)
	tgt.y = clampf(tgt.y, _cfg.surface_y + 10.0, _cfg.seabed_y)
	var gap := tgt - position
	var dist := gap.length()
	if dist > COMMAND_ARRIVE:
		# tuck into the shell and CHARGE the last stretch — the classic turtle shell-ram
		if dist < CHARGE_DIST:
			if not _ramming:
				_anims.play(anims.shell_tuck, _face)   # tuck (plays once, holds on the shell frame)
				_ramming = true
		else:
			_ramming = false
			_anims.play(anims.swim, _face)
		if absf(gap.x) > 4.0:
			_face = signf(gap.x)
		position += gap * clampf(COMMAND_SPEED * delta, 0.0, 1.0)
		position.y += sin(_t * 2.4) * BOB_AMP * delta
		return
	# arrived — smash the rubble (already shelled from the charge)
	if not _ramming:
		_anims.play(anims.shell_tuck, _face)
		_ramming = true
	var hit := 0
	for b in get_tree().get_nodes_in_group("blastable"):
		if b.has_method("blast"):
			hit += b.blast(global_position, DEMOLISH_RADIUS)
	if hit > 0:
		_ram_fx_t -= delta
		if _ram_fx_t <= 0.0:              # throttle the spray burst so it doesn't machine-gun
			_ram_fx_t = 0.14
			_ram_fx()
	else:                                 # nothing left to break -> emerge and rejoin you
		_anims.play(anims.shell_emerge, _face)
		_ramming = false
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
