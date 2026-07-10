extends Node2D
## Cattail reeds rooted in the shallows near each bank — tall two-tone blades breaking the
## surface, brown seed heads on some, all swaying in a field-wide wind wave (the GrassLayer
## idiom: throttled redraw, a few dozen polygons). Zero reeds = retire.

const REDRAW_HZ := 15.0

var _cfg: CoveConfig
var _reeds: Array = []   # [x, height, phase, has_head] per reed
var _t := 0.0
var _acc := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.reed_count <= 0:
		queue_free()
		return
	z_index = 4                       # behind the water surface tint (5): reeds read IN the water
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in cfg.reed_count:
		# root alternately near the left and right water edges (the marsh margins)
		var left := i % 2 == 0
		var x := rng.randf_range(cfg.water_left + 6.0, cfg.water_left + 76.0) if left \
			else rng.randf_range(cfg.water_right - 76.0, cfg.water_right - 6.0)
		_reeds.append([x, rng.randf_range(95.0, 145.0), rng.randf_range(0.0, TAU), rng.randf() < 0.55])

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if _cfg == null:
		return
	for r in _reeds:
		var base := Vector2(r[0], _cfg.seabed_y)
		var sway: float = sin(_t * 1.4 + r[2] + r[0] * 0.08) * 3.5
		var tip := base + Vector2(sway, -r[1])
		# tapered two-tone blade (rooted wide in the mud, bright at the tip)
		draw_polygon(
			PackedVector2Array([base + Vector2(-2.2, 0.0), base + Vector2(2.2, 0.0), tip]),
			PackedColorArray([Palette.MOSS, Palette.MOSS, Palette.LEAF]))
		if r[3]:
			# the cattail seed head: a fat brown capsule just below the tip
			draw_line(tip + Vector2(0.0, 10.0), tip + Vector2(0.0, 22.0), Palette.LOAM, 4.5)
