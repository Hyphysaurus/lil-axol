extends Node2D
## The Rescued Friend — an oil-matted wild-type axolotl asleep in the cove's far corner.
## Spray them close and sustained (D-0006's skill verb) and the oil washes off: they wake,
## chirp, award Shine, and follow the tidekeeper for the rest of the day, helping scrub.
## The rig is data-driven: swap `frames`/`anims`/tints to make this a Lil Otter or Frog
## companion with zero code changes. New Day resets the rescue — that's part of the loop.

@export var frames: SpriteFrames = preload("res://game/axolotl/axolotl_frames.tres")
@export var anims: CharacterAnimSet = preload("res://game/axolotl/axolotl_anims.tres")
@export var clean_tint := Color(0.62, 0.72, 0.55)   # wild-type olive, distinct from the player
@export var oiled_tint := Color(0.30, 0.28, 0.24)   # matted in oil, waiting

const RESCUE_SECONDS := 2.5    # cumulative close-spray time to wash them awake
const RESCUE_REACH := 30.0     # how close the spray point must land
const FOLLOW_GAP := 30.0       # stops this far from the player
const FOLLOW_SPEED := 3.2      # lerp rate toward the follow point
const HELP_EVERY := 3.5        # seconds between helper scrubs
const HELP_RADIUS := 14.0
const BOB_AMP := 2.5
const BONUS := 500.0

enum State { SLEEPING, WAKING, FOLLOWING }

var _cfg: CoveConfig
var _state := State.SLEEPING
var _spr: AnimatedSprite2D
var _anims: AnimationController
var _progress := 0.0
var _help_t := 0.0
var _t := 0.0
var _face := -1.0

func _ready() -> void:
	add_to_group("sprayable")          # receives the player's spray hits
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = frames
	_spr.modulate = oiled_tint
	add_child(_spr)
	_anims = AnimationController.new(_spr)
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
	# oil visibly washing off as you work
	_spr.modulate = oiled_tint.lerp(clean_tint, clampf(_progress / RESCUE_SECONDS, 0.0, 1.0))
	if _progress >= RESCUE_SECONDS:
		_wake()

func _wake() -> void:
	_state = State.WAKING
	_spr.modulate = clean_tint
	_anims.play(anims.idle_blink, _face)
	Sfx.play("chime", -6.0, 1.8)       # placeholder chirp until the authored axo_chirp lands
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("bonus"):
		keeper.bonus(BONUS, global_position)
	await get_tree().create_timer(0.9).timeout
	_state = State.FOLLOWING

func _process(delta: float) -> void:
	_t += delta
	if _state != State.FOLLOWING:
		return
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	if axo == null or _cfg == null:
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
