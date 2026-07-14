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
	_test_carve_cell_contract()
	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit()

## carve_cell(cx,cy) must flip EXACTLY one cell — the fixed 3x3-bleed regression guard. carve()'s
## radius math always sweeps a minimum 3x3 (ceilf(radius/CELL) >= 1 even for a tiny radius), which
## is why carve_cell exists as the exact-cell path _carve_rect needs. A 3x3 rubble block on an
## otherwise-air field, carved at its center cell only: the center must read water and all 8
## neighbors (still part of the same block) must stay solid.
func _test_carve_cell_contract() -> void:
	var w := 5; var h := 5
	var cells := PackedByteArray(); cells.resize(w * h)   # AIR(0) background
	for cy in range(1, 4):
		for cx in range(1, 4):
			cells[cy * w + cx] = ReachFieldScript.RUBBLE  # solid 3x3 rubble block, center cell (2,2)
	var origin := Vector2.ZERO
	var f = ReachFieldScript.new()
	f.set_mask(origin, cells, w, h, 0)     # table_row 0: nothing blocks the carve
	f.carve_cell(2, 2)
	_check("carve_cell: center flips to water",
		f.is_water(origin + Vector2(2.5, 2.5) * ReachFieldScript.CELL))
	var neighbors_solid := true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if f.is_water(origin + Vector2(2.5 + dx, 2.5 + dy) * ReachFieldScript.CELL):
				neighbors_solid = false
	_check("carve_cell: all 8 neighbors still rubble-solid (no 3x3 bleed)", neighbors_solid)
	f.free()
