extends SceneTree
## ReachField: rect backing == mask backing on an equivalent rectangular world (parity proof),
## plus mask-only behaviors (holes, carve, floor scan).
const ReachFieldScript := preload("res://game/cove/reach_field.gd")
const CoveConfigScript := preload("res://game/cove/cove_config.gd")
var fails := 0
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok: fails += 1
func _init() -> void:
	var cfg := CoveConfigScript.new()
	cfg.water_left = -80.0; cfg.water_right = 80.0
	cfg.surface_y = -16.0; cfg.seabed_y = 64.0
	var rectf = ReachFieldScript.new(); rectf.setup_rect(cfg)
	# mask equivalent: 30x14 cells at origin (-120,-40): water spans cells x 5..24, y 3..12
	var w := 30; var h := 14
	var cells := PackedByteArray(); cells.resize(w * h); cells.fill(1)
	for cy in range(3, 13):
		for cx in range(5, 25): cells[cy * w + cx] = 3
	var maskf = ReachFieldScript.new(); maskf.set_mask(Vector2(-120, -40), cells, w, h, 3)
	for p in [Vector2(0, 0), Vector2(0, -20), Vector2(-100, 20), Vector2(79, 63), Vector2(-79, -15)]:
		_check("parity is_water %s" % p, rectf.is_water(p) == maskf.is_water(p))
	_check("parity surface", absf(rectf.surface_y() - maskf.surface_y()) < 0.01)
	_check("rect oil_allowed above surface", rectf.oil_allowed(Vector2(0, -18)))
	_check("mask oil gate", not maskf.oil_allowed(Vector2(-100, 20)) and maskf.oil_allowed(Vector2(0, 0)))
	_check("rect floor", absf(rectf.floor_y_at(0.0) - 64.0) < 0.01)
	_check("mask floor", absf(maskf.floor_y_at(0.0) - 64.0) < 0.01)   # water ends cell y12 -> floor top y13 = -40+13*8 = 64
	cells[7 * w + 15] = 2                        # a rubble pocket cell mid-water (carvable; EARTH is not — spec C5)
	maskf.set_mask(Vector2(-120, -40), cells, w, h, 3)
	var pocket := Vector2(-120 + 15 * 8 + 4, -40 + 7 * 8 + 4)
	_check("mask hole solid", not maskf.is_water(pocket))
	maskf.carve(pocket, 4.0)
	_check("carve flips to water", maskf.is_water(pocket))
	rectf.carve(Vector2(0, 0), 10.0)            # rect: no-op, no crash
	_check("rect carve noop", rectf.is_water(Vector2(0, 0)))
	rectf.free(); maskf.free()
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()
