class_name ReachField
extends Node
## The reach's water/footing ORACLE (slice 5 spec §4.1/4.5). One API, two backings:
## RECT (legacy hand-built reaches — answers derived from config numbers, so behavior is
## preserved by construction) and MASK (painted map reaches — per-cell truth). Everything that
## used to test the water rectangle (axolotl, companions, oil, spawners) asks this instead.
## All coordinates are cove-local (the config frame). Group: "reach_field".

const CELL := 8.0
# cell codes (mask backing)
const AIR := 0; const EARTH := 1; const RUBBLE := 2; const WATER := 3
const CLIMB := 4; const SILT := 5; const BOULDER := 6

var _rect_cfg: CoveConfig = null      # rect backing when set
var _origin := Vector2.ZERO           # mask backing
var _cells := PackedByteArray()
var _w := 0
var _h := 0
var _table_row := 0
# computed ONCE per backing swap — water_bounds() is a per-physics-frame caller (axolotl); an
# O(w*h) mask scan on every call is too hot (T1 review carry-over).
var _bounds_cache := Rect2()

func _ready() -> void:
	add_to_group("reach_field")

func setup_rect(cfg: CoveConfig) -> void:
	_rect_cfg = cfg
	_bounds_cache = Rect2(cfg.water_left, cfg.surface_y,
		cfg.water_right - cfg.water_left, cfg.seabed_y - cfg.surface_y)

func set_mask(origin: Vector2, cells: PackedByteArray, w: int, h: int, table_row: int) -> void:
	_rect_cfg = null
	_origin = origin; _cells = cells; _w = w; _h = h; _table_row = table_row
	_bounds_cache = _scan_water_bounds()

func _scan_water_bounds() -> Rect2:
	var minx := _w; var maxx := -1; var miny := _h; var maxy := -1
	for cy in _h:
		for cx in _w:
			if _cells[cy * _w + cx] == WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	if maxx < 0:
		return Rect2()
	return Rect2(_origin + Vector2(minx, miny) * CELL, Vector2(maxx - minx + 1, maxy - miny + 1) * CELL)

func _cell_at(p: Vector2) -> int:
	var cx := int(floorf((p.x - _origin.x) / CELL))
	var cy := int(floorf((p.y - _origin.y) / CELL))
	if cx < 0 or cx >= _w or cy < 0 or cy >= _h:
		return EARTH                   # off-map reads solid: nothing swims off the edge
	return _cells[cy * _w + cx]

func is_water(p: Vector2) -> bool:
	if _rect_cfg:
		return _rect_cfg.has_water and p.x > _rect_cfg.water_left and p.x < _rect_cfg.water_right \
			and p.y > _rect_cfg.surface_y and p.y < _rect_cfg.seabed_y
	return _cell_at(p) == WATER

## Oil coverage may exist here. Rect: ALWAYS true — the legacy mask build had no terrain
## knowledge, and gating it would shift _total/cleanliness on saved worlds. Mask: water only
## (oil born inside painted earth is invisible and would block the win — spec C2).
func oil_allowed(p: Vector2) -> bool:
	if _rect_cfg:
		return true
	return _cell_at(p) == WATER

func surface_y() -> float:
	if _rect_cfg:
		return _rect_cfg.surface_y
	return _origin.y + float(_table_row) * CELL

func water_bounds() -> Rect2:
	return _bounds_cache

## y of the first solid top below the waterline at x — where floor-rooted life plants.
func floor_y_at(x: float) -> float:
	if _rect_cfg:
		return _rect_cfg.seabed_y
	var cx := int(floorf((x - _origin.x) / CELL))
	if cx < 0 or cx >= _w:
		return surface_y()
	for cy in range(_table_row, _h):
		var c := _cells[cy * _w + cx]
		if c != WATER and c != AIR:
			return _origin.y + float(cy) * CELL
	return _origin.y + float(_h) * CELL

func random_water_cell(rng: RandomNumberGenerator) -> Vector2:
	if _rect_cfg:
		return Vector2(rng.randf_range(_rect_cfg.water_left + 8.0, _rect_cfg.water_right - 8.0),
			rng.randf_range(_rect_cfg.surface_y + 8.0, _rect_cfg.seabed_y - 8.0))
	for _i in 200:                     # rejection sample; painted maps are ~1/3 water
		var cx := rng.randi_range(0, _w - 1)
		var cy := rng.randi_range(0, _h - 1)
		if _cells[cy * _w + cx] == WATER:
			return _origin + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL
	return water_bounds().get_center()

## An x whose SURFACE cell (just below the table) is open water — lilypad/debris band.
func random_surface_x(rng: RandomNumberGenerator) -> float:
	if _rect_cfg:
		return rng.randf_range(_rect_cfg.water_left + 20.0, _rect_cfg.water_right - 20.0)
	for _i in 200:
		var cx := rng.randi_range(0, _w - 1)
		if _table_row < _h and _cells[_table_row * _w + cx] == WATER:
			return _origin.x + (float(cx) + 0.5) * CELL
	return water_bounds().get_center().x

## Broken rock becomes swimmable at/below the table (spec C5 — the legacy rect made carved
## tunnels swimmable by construction; the mask must do it explicitly). Rect: no-op.
## T5 DECISION (was a NOTE-only carry-over from T2 review): every flipped cell also grows
## _bounds_cache in-place, O(1) per cell — cheap because we're already iterating them to flip the
## code, and correct even for a seal that sits OUTSIDE the already-classified water span (the T2
## note's "always inside" assumption held for the pilot map but isn't a mask invariant in general).
## Rejected alternative: re-running _scan_water_bounds() per carve — O(w*h) per bite, too hot for
## something a blast can call every frame during a shell-spin grind.
func carve(p: Vector2, radius: float) -> void:
	if _rect_cfg:
		return
	var r := int(ceilf(radius / CELL))
	var cx := int(floorf((p.x - _origin.x) / CELL))
	var cy := int(floorf((p.y - _origin.y) / CELL))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var nx := cx + dx; var ny := cy + dy
			if nx < 0 or nx >= _w or ny < 0 or ny >= _h or ny < _table_row:
				continue
			var c := _cells[ny * _w + nx]
			if c == RUBBLE or c == SILT or c == BOULDER:
				_cells[ny * _w + nx] = WATER
				var cell_rect := Rect2(_origin + Vector2(nx, ny) * CELL, Vector2(CELL, CELL))
				_bounds_cache = cell_rect if _bounds_cache.size == Vector2.ZERO \
					else _bounds_cache.merge(cell_rect)
