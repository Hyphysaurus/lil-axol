extends Node2D
## Lilypads riding the waterline — marsh dressing and the frog's hop points (group "perch",
## reserved for future perch logic). Self-contained in the cove idiom: injected config, drawn
## pads (Apollo greens) bobbing gently on the surface. Zero pads = retire.

const REDRAW_HZ := 15.0   # the bob is 1.3 rad/s — 15Hz is visually identical, and WebGL pays
                          # per canvas rebuild, so dressing never redraws at frame rate

var _cfg: CoveConfig
var _pads: Array = []   # [x, radius, phase] per pad
var _t := 0.0
var _acc := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.lilypad_count <= 0:
		queue_free()
		return
	add_to_group("perch")
	z_index = 6                       # on the water surface (water 5), under FX (7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7                      # stable layout per cove — pads don't reshuffle each visit
	for i in cfg.lilypad_count:
		var frac := (float(i) + 0.5) / float(cfg.lilypad_count)
		_pads.append([
			lerpf(cfg.water_left + 30.0, cfg.water_right - 40.0, frac) + rng.randf_range(-14.0, 14.0),
			rng.randf_range(7.0, 12.0),
			rng.randf_range(0.0, TAU),
		])

## The nearest pad's x within `within` of x, or NAN — the frog asks where it can land
## (the perch logic these pads were reserved for; see companion._frog_hop).
func nearest_pad_x(x: float, within: float) -> float:
	var best := NAN
	var best_d := within
	for p in _pads:
		var d: float = absf(float(p[0]) - x)
		if d <= best_d:
			best_d = d
			best = float(p[0])
	return best

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()

func _draw() -> void:
	if _cfg == null:
		return
	for p in _pads:
		var c := Vector2(p[0], _cfg.surface_y - 1.0 + sin(_t * 1.3 + p[2]) * 1.5)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.45))   # circles -> floating oval pads
		draw_circle(Vector2.ZERO, p[1], Palette.MOSS)
		draw_circle(Vector2.ZERO, p[1] - 2.0, Palette.GREEN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the classic notch: a seam from centre to rim
		draw_line(c, c + Vector2(p[1] * 0.9, -p[1] * 0.28), Palette.MOSS, 2.0)
