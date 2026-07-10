extends Node2D
## Cap the Leak — the spill's SOURCE. A red oil barrel sits on the sand at the shoreline and
## trickles fresh oil back into the slick near it (OilSpill.stain_at, hard-capped at the
## level's start — D-0005). Aim a sustained spray at the barrel to neutralize it: when the
## meter fills the barrel BURSTS (12-frame explosion) and the blast clears the oil around the
## source, sealing the leak. No fail state — ignore it and the source just stays lively.
## Config-driven (leak_enabled / leak_pos / leak_rate), injected by the Cove composition root;
## joins the "sprayable" group so the axolotl's spray reaches it.

const BARREL := preload("res://assets/props/industrial/red_oil_barrel.png")
const OIL_SHADER := preload("res://shaders/oil.gdshader")
const WHITE := preload("res://assets/white.png")

const PROP_SCALE := 1.2         # 32px pixel-art barrel, scaled to a sensible size on the beach
const CAP_SECONDS := 2.0        # sustained spray on the barrel to neutralize it
# Shine for cleaning the leak source lives in the "spring_clean" feat (shine.FEATS).
const CAP_REACH := 34.0         # spray point must land this close to the barrel
const STAIN_RADIUS := 24.0      # how wide the trickle re-oils near the source
const DRIP := Vector2(26.0, 22.0)   # from the barrel down-right into the water at the shoreline
const BLAST_CLEAR := 60.0       # the explosion clears this radius of oil at the source

var _cfg: CoveConfig
var _oil: Node
var _spr: Sprite2D
var _drip: CPUParticles2D
var _pool: Sprite2D               # oil-shader pool stained on the ground at the barrel's base
var _ring: Node2D
var _body: StaticBody2D          # the barrel's physical collider — freed when it bursts
var _capped := false
var _cap_t := 0.0
var _spray_cd := 0.0            # was the barrel sprayed very recently? (drives the cap meter)

func _ready() -> void:
	add_to_group("sprayable")
	add_to_group("leak")         # so the hint system can nudge the player toward capping it
	z_index = 4                  # over the water/oil, under FX
	_spr = Sprite2D.new()
	_spr.texture = BARREL
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	_spr.scale = Vector2(PROP_SCALE, PROP_SCALE)
	_spr.offset = Vector2(0.0, -float(BARREL.get_height()) * 0.5)   # bottom sits on leak_pos
	add_child(_spr)
	_add_solid()                 # the barrel is solid — the axolotl bumps it, doesn't pass through
	_drip = _make_drip()
	add_child(_drip)
	_ring = CapRing.new()
	add_child(_ring)
	_pool = _make_pool()         # an oil-shader pool at the barrel's base (real oil, not a flat blob)
	add_child(_pool)

## Give the barrel a physical body so the axolotl collides with it. A StaticBody2D on the
## DEFAULT collision layer is exactly what the beach and seabed already use, so the axolotl
## (a CharacterBody2D driven by move_and_slide) bumps into it for free — no code on the axo,
## no signals, just physics. The box is derived from the texture (no magic numbers) and covers
## the visible barrel body; the sprite is bottom-anchored, so the box sits above the origin.
func _add_solid() -> void:
	var box := RectangleShape2D.new()
	box.size = Vector2(BARREL.get_width(), BARREL.get_height()) * PROP_SCALE * 0.8
	var col := CollisionShape2D.new()
	col.shape = box
	col.position = Vector2(0.0, -box.size.y * 0.5)
	_body = StaticBody2D.new()
	_body.add_child(col)
	add_child(_body)

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if not cfg.leak_enabled:
		queue_free()
		return
	position = cfg.leak_pos
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_method("stain_at"):
		_oil = mgr

## The axolotl's spray reaching us (via the "sprayable" group). Sustained close spray on the
## barrel fills the meter; anywhere else on the water does nothing here.
func spray_at(world_pos: Vector2, _radius: float, delta: float) -> void:
	if _capped:
		return
	if world_pos.distance_to(global_position) > CAP_REACH:
		return
	_cap_t = minf(CAP_SECONDS, _cap_t + delta)
	_spray_cd = 0.15
	if _cap_t >= CAP_SECONDS:
		_purify()

func _process(delta: float) -> void:
	if _capped:
		return
	# trickle fresh oil back into the water at the shoreline, down-right from the barrel
	if _oil:
		_oil.stain_at(global_position + DRIP, STAIN_RADIUS, _cfg.leak_rate * delta)
	# the cap meter drains when you stop spraying the barrel (no penalty, just not-yet-sealed)
	_spray_cd -= delta
	if _spray_cd <= 0.0:
		_cap_t = move_toward(_cap_t, 0.0, delta * 1.5)
	(_ring as CapRing).progress = _cap_t / CAP_SECONDS

## The source is PURIFIED, not blown up: the Tidekeeper's restorative spray dissolves the oil and the
## rusted barrel crumbles into clean water + light, sealing the leak for good — cozy, not a violent
## explosion (which is why plain water can neutralize it: it's restoration, not detonation).
func _purify() -> void:
	_capped = true
	_drip.emitting = false
	if is_instance_valid(_body):
		_body.queue_free()           # the barrel's gone — drop its collider so the axo doesn't
		_body = null                 # stand on an invisible box where the barrel used to be
	(_ring as CapRing).progress = 0.0
	get_tree().call_group("oil_manager", "spray_at", global_position + DRIP, BLAST_CLEAR, 0.9)   # oil lifts away
	Sfx.play("vent_open", -6.0)      # a warm ascending sparkle (GameBurp) — a cleanse, not a boom
	Sfx.play("chime", -5.0, 1.3)
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"spring_clean", global_position + Vector2(0.0, -18.0))   # "Spring Clean" feat
	_purify_fx(self, Vector2(0.0, -16.0))
	var tok := preload("res://game/cove/reclaim_token.gd").new()
	tok.position = (get_parent() as Node2D).to_local(global_position)
	get_parent().add_child(tok)   # survives this node's later retirement
	# the barrel + its oil pool dissolve away instead of vanishing
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_spr, "modulate:a", 0.0, 0.45)
	if is_instance_valid(_pool):
		tw.tween_property(_pool, "modulate:a", 0.0, 0.5)

## The cozy replacement for an explosion: a burst of clean-water foam + rising golden sparkles where a
## barrel purifies. Static so the drifting sea barrels (shore_pollution) reuse the exact same look.
static func _purify_fx(parent: Node, at: Vector2) -> void:
	var foam := CPUParticles2D.new()
	foam.one_shot = true; foam.emitting = true
	foam.amount = 20; foam.lifetime = 0.7; foam.explosiveness = 0.9
	foam.position = at; foam.spread = 180.0
	foam.gravity = Vector2(0.0, 40.0)
	foam.initial_velocity_min = 40.0; foam.initial_velocity_max = 110.0
	foam.damping_min = 30.0; foam.damping_max = 70.0
	foam.scale_amount_min = 1.0; foam.scale_amount_max = 2.8
	foam.color = Color(Palette.AQUA, 0.9); foam.z_index = 7
	parent.add_child(foam)
	foam.finished.connect(foam.queue_free)
	var spark := CPUParticles2D.new()
	spark.one_shot = true; spark.emitting = true
	spark.amount = 14; spark.lifetime = 1.0; spark.explosiveness = 0.85
	spark.position = at; spark.direction = Vector2(0.0, -1.0); spark.spread = 70.0
	spark.gravity = Vector2(0.0, -30.0)
	spark.initial_velocity_min = 20.0; spark.initial_velocity_max = 60.0
	spark.scale_amount_min = 0.8; spark.scale_amount_max = 1.8
	spark.color = Color(Palette.GOLD, 0.95); spark.z_index = 8
	parent.add_child(spark)
	spark.finished.connect(spark.queue_free)

## An oil pool at the barrel's base, drawn with the game's OIL shader (petrol sheen, organic lobed
## blob) so it reads as real oil integrated on the ground, not a flat drawn circle.
func _make_pool() -> Sprite2D:
	var mat := ShaderMaterial.new()
	mat.shader = OIL_SHADER
	mat.set_shader_parameter("amount", 0.9)
	mat.set_shader_parameter("sheen", 0.5)
	var s := Sprite2D.new()
	s.texture = WHITE
	s.material = mat
	s.scale = Vector2(56.0, 30.0)     # a flat oily pool spreading at the base
	s.position = Vector2(4.0, 2.0)
	s.z_index = 3                      # on the ground, under the barrel (z 4)
	return s

func _make_drip() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.9
	p.position = Vector2(10.0, -6.0)   # from the barrel's lower-right, down into the water
	p.direction = Vector2(0.6, 1.0)
	p.spread = 8.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(Palette.INK, 0.9)   # dark oil droplets (on-palette darkest navy)
	return p

## Small fill-ring over the barrel while you spray it, so neutralizing reads as deliberate.
class CapRing extends Node2D:
	var progress := 0.0:
		set(v):
			if not is_equal_approx(progress, v):
				progress = v
				queue_redraw()

	func _draw() -> void:
		if progress <= 0.01:
			return
		var c := Vector2(0.0, -44.0)
		draw_arc(c, 12.0, 0.0, TAU, 28, Color(0.9, 0.97, 1.0, 0.25), 2.0, true)
		draw_arc(c, 12.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 28,
			Color(0.95, 0.99, 1.0, 0.9), 2.5, true)
