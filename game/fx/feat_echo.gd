extends Node2D
## FEAT ECHO — the wetland celebrates with you (diegetic pass). Every named feat also lands IN
## the world: a ripple ring spreads on the waterline above the spot and a few glints leap like
## startled fish. The text banner keeps the score; the pond keeps the feeling. Listens to the
## shine keeper's feat_echoed(at) — one signal, drawn dressing only, never touches gameplay.

const RING_SPEED := 55.0       # px/s ring growth
const REDRAW_HZ := 20.0

var _cfg: CoveConfig
var _rings: Array = []         # [x, radius, alpha] per live ring
var _acc := 0.0
var _hooked := false

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	z_index = 6                 # on the water surface plane (pads/film), under land (7)

func _process(delta: float) -> void:
	if not _hooked:             # the keeper joins its group in _ready; hook lazily like hints does
		var keeper := get_tree().get_first_node_in_group("shine")
		if keeper and keeper.has_signal("feat_echoed"):
			keeper.feat_echoed.connect(_on_feat)
			_hooked = true
	if _rings.is_empty():
		return
	for r in _rings:
		r[1] += RING_SPEED * delta
		r[2] = maxf(0.0, r[2] - delta * 0.7)
	_rings = _rings.filter(func(r): return r[2] > 0.02)
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()

func _on_feat(at: Vector2) -> void:
	if _cfg == null or not _cfg.has_water:
		return
	var x := clampf(at.x, _cfg.water_left + 12.0, _cfg.water_right - 12.0)
	_rings.append([x, 5.0, 0.85])
	# a handful of glints leap off the surface like startled fish and rain back in
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.7
	p.explosiveness = 0.85
	p.position = Vector2(x, _cfg.surface_y)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 32.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 190.0
	p.gravity = Vector2(0.0, 460.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.color = Color(Palette.FOAM, 0.9)
	p.z_index = 7
	add_child(p)
	p.finished.connect(p.queue_free)

func _draw() -> void:
	for r in _rings:
		# squashed to an oval so the ring lies ON the surface, not across it
		draw_set_transform(Vector2(r[0], _cfg.surface_y), 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, r[1], 0.0, TAU, 28, Color(Palette.FOAM, r[2]), 1.6, true)
		draw_arc(Vector2.ZERO, maxf(r[1] - 7.0, 2.0), 0.0, TAU, 24, Color(Palette.AQUA, r[2] * 0.5), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
