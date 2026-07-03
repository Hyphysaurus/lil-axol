extends Node2D
## Cap the Leak — the spill's SOURCE, and the first real use of the industrial prop art.
## A leaking valve on the right ledge drips fresh oil back into the slick near the source
## (OilSpill.stain_at, hard-capped so oil never exceeds the level's start — D-0005). Aim a
## sustained spray at the valve to seal it: the drip stops, the valve swaps to its capped
## sprite, a clunk lands. No fail state — ignore it and the source stays lively, cap it and
## the cleaning finally counts. Config-driven (leak_enabled / leak_pos / leak_rate), injected
## by the Cove composition root; joins the "sprayable" group so the axolotl's spray reaches it.

const LEAKING := preload("res://assets/props/industrial/barrel_valve_leaking.png")
const CAPPED := preload("res://assets/props/industrial/barrel_oil_valve.png")

const CAP_SECONDS := 2.0        # sustained spray on the valve to seal it
const CAP_REACH := 30.0         # spray point must land this close to the valve
const STAIN_RADIUS := 26.0      # how wide the trickle re-oils near the source

var _cfg: CoveConfig
var _oil: Node
var _spr: Sprite2D
var _drip: CPUParticles2D
var _ring: Node2D
var _capped := false
var _cap_t := 0.0
var _spray_cd := 0.0            # was the valve sprayed very recently? (drives the cap meter)

func _ready() -> void:
	add_to_group("sprayable")
	z_index = 4                  # over the water/oil, under FX
	_spr = Sprite2D.new()
	_spr.texture = LEAKING
	add_child(_spr)
	_drip = _make_drip()
	add_child(_drip)
	_ring = CapRing.new()
	add_child(_ring)

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
## valve fills the cap meter; anywhere else on the water does nothing here.
func spray_at(world_pos: Vector2, _radius: float, delta: float) -> void:
	if _capped:
		return
	if world_pos.distance_to(global_position) > CAP_REACH:
		return
	_cap_t = minf(CAP_SECONDS, _cap_t + delta)
	_spray_cd = 0.15
	if _cap_t >= CAP_SECONDS:
		_cap()

func _process(delta: float) -> void:
	if _capped:
		return
	# trickle fresh oil back near the source, just under the waterline
	if _oil:
		var drip := Vector2(global_position.x, global_position.y + 18.0)
		_oil.stain_at(drip, STAIN_RADIUS, _cfg.leak_rate * delta)
	# the cap meter drains when you stop spraying the valve (no penalty, just not-yet-sealed)
	_spray_cd -= delta
	if _spray_cd <= 0.0:
		_cap_t = move_toward(_cap_t, 0.0, delta * 1.5)
	(_ring as CapRing).progress = _cap_t / CAP_SECONDS

func _cap() -> void:
	_capped = true
	_spr.texture = CAPPED
	_drip.emitting = false
	(_ring as CapRing).progress = 0.0
	Sfx.play("land", -2.0, 0.7)      # a solid "clunk" (reuses the land thud, pitched down)
	Sfx.play("chime", -6.0, 1.0)     # a soft "sealed" sparkle
	_burst()

func _make_drip() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.9
	p.position = Vector2(2.0, 20.0)   # from the valve mouth down into the water
	p.direction = Vector2(0.1, 1.0)
	p.spread = 8.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(0.06, 0.05, 0.08, 0.9)   # dark oil droplets
	return p

func _burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 12
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 120)
	p.color = Color(0.85, 0.92, 0.8, 0.8)
	add_child(p)
	p.finished.connect(p.queue_free)

## Small fill-ring over the valve while you spray it, so capping reads as a deliberate action.
class CapRing extends Node2D:
	var progress := 0.0:
		set(v):
			if not is_equal_approx(progress, v):
				progress = v
				queue_redraw()

	func _draw() -> void:
		if progress <= 0.01:
			return
		var c := Vector2(0.0, -26.0)
		draw_arc(c, 12.0, 0.0, TAU, 28, Color(0.9, 0.97, 1.0, 0.25), 2.0, true)
		draw_arc(c, 12.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 28,
			Color(0.95, 0.99, 1.0, 0.9), 2.5, true)
