extends Node2D
class_name LandNook
## A cracked loam mound on the beach edge — breakable by the turtle's shell-ram (or a bubble bomb).
## Smash it open to uncover a HIDDEN SHINE CACHE: a reason to send the turtle ashore, and a reward for
## exploring the land. Self-contained: it spawns its own loam-tinted DestructibleRock and listens for
## `cleared`, exactly like the thermal vents do for their caps. Drop as many along the beach as you like.

const RockScript := preload("res://game/cove/destructible_rock.gd")
# The cache's Shine payout lives in the "trove" feat (shine.FEATS) — opening one is a celebrated feat.

@export var cols := 5
@export var rows := 4

var _opened := false
var _glow := 0.0               # 0 sealed .. 1 opened (the revealed cache glows warm)
var _pulse := 0.0

func _ready() -> void:
	z_index = 2                 # on the beach, in front of the block-land (z 1), beside the axolotl
	var rock = RockScript.new()
	rock.cols = cols
	rock.rows = rows
	rock.turtle_only = true         # only the turtle's ram opens a nook — not a stray bubble bomb
	# warm brown in the block-land's OWN earth family (SOIL read too red/pink); a touch darker than the
	# surrounding topsoil so the mound reads as distinct denser earth, not a foreign block
	rock.tone_a = Palette.LOAM
	rock.tone_b = Palette.CLAY
	rock.position = Vector2(-float(cols) * DestructibleRock.CELL * 0.5, -float(rows) * DestructibleRock.CELL * 0.5)
	add_child(rock)
	rock.cleared.connect(_open)
	queue_redraw()

func _open() -> void:
	if _opened:
		return
	_opened = true
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"trove", global_position)   # "Trove" feat: callout + Flow + Shine
	_sparkle()
	create_tween().tween_property(self, "_glow", 1.0, 0.6)

func _process(delta: float) -> void:
	if _opened:
		_pulse += delta
		queue_redraw()             # the revealed glow breathes

func _draw() -> void:
	if _glow > 0.01:
		var g := _glow * (0.7 + 0.3 * sin(_pulse * 2.6))
		for i in 3:                # a warm hidden-treasure glow where the mound was
			draw_circle(Vector2.ZERO, 7.0 + float(i) * 7.0, Color(Palette.GOLD, 0.16 * g / float(i + 1)))

## A burst of golden sparkles as the cache cracks open.
func _sparkle() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 16
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0.0, 60.0)
	p.damping_min = 20.0
	p.damping_max = 50.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	p.color = Color(Palette.GOLD, 0.9)
	p.z_index = 8
	add_child(p)
	p.finished.connect(p.queue_free)
