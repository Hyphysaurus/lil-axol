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

## Optional hand-drawn animated bubble (Aseprite → a horizontal strip of SQUARE frames). If this
## file exists it becomes the bomb's look; otherwise the procedural circle in _draw() is the fallback.
## Export from Aseprite as: Export Sprite Sheet → Horizontal Strip → this exact path.
const SHIMMER_STRIP := "res://assets/fx/bubble_shimmer.png"

var _aim := Vector2.RIGHT
var _cfg: CoveConfig
var _t := 0.0
var _popped := false
var _spr: AnimatedSprite2D    # the shimmer sprite when the art exists; null = draw the circle instead

func setup(aim: Vector2, cfg: CoveConfig) -> void:
	_aim = aim if aim != Vector2.ZERO else Vector2.RIGHT
	_cfg = cfg

func _ready() -> void:
	z_index = 7
	# use the hand-drawn animated bubble if it's been exported into the project
	if ResourceLoader.exists(SHIMMER_STRIP):
		var tex := load(SHIMMER_STRIP) as Texture2D
		if tex:
			_spr = AnimatedSprite2D.new()
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels, no smoothing
			_spr.sprite_frames = _slice_strip(tex)
			_spr.play(&"shimmer")
			add_child(_spr)

## Slice a horizontal strip into a looping SpriteFrames, assuming SQUARE frames (frame = height,
## count = width / height). Built at runtime so any frame count from Aseprite just works.
func _slice_strip(tex: Texture2D) -> SpriteFrames:
	var h := tex.get_height()
	var n: int = maxi(1, tex.get_width() / h)
	var sf := SpriteFrames.new()
	sf.add_animation(&"shimmer")
	sf.set_animation_loop(&"shimmer", true)
	sf.set_animation_speed(&"shimmer", 8.0)   # ~8 fps ≈ 120 ms/frame (dreamy); tune to taste
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * h, 0, h, h)
		sf.add_frame(&"shimmer", at)
	return sf

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
	# bubble bombs carve rock too — iterate (not call_group) so we can read the hit count and, if this
	# pop both lifted oil AND cracked rubble, call it a "Bank Shot" feat
	var rubble := 0
	for b in get_tree().get_nodes_in_group("blastable"):
		if b.has_method("blast"):
			rubble += b.blast(global_position, radius)
	if rubble > 0:
		var keeper = get_tree().get_first_node_in_group("shine")
		if keeper and keeper.has_method("feat"):
			keeper.feat(&"bank_shot", global_position)
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
	p.color = Color(Palette.CYAN, 0.85)   # droplet burst, on-palette
	p.z_index = 7
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
	queue_free()

func _draw() -> void:
	if _spr != null:
		return   # the hand-drawn animated bubble is showing; skip the procedural circle
	draw_circle(Vector2.ZERO, R, Color(Palette.CYAN, 0.10))                       # soft fill
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 32, Color(Palette.CYAN, 0.8), 1.5, true)  # bubble rim
	draw_arc(Vector2.ZERO, R - 4.0, -2.2, -1.1, 10, Color(Palette.FOAM, 0.7), 1.5, true)  # glint
