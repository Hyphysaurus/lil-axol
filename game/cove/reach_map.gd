extends Node2D
## THE INGESTER (slice 5 spec §4.1): turns a painted reach map into config + world. This task:
## classify both PNGs, expand the runtime config, upgrade the ReachField to the mask, retire the
## hand-built cove nodes, and lint loudly. Geometry builders arrive in later tasks and hang off
## build() below. No map on the config -> retire (the classic reaches never feel this node).

const CELL := 8.0
const TERRAIN_COLORS := {                       # exact legend RGB (alpha-gated first)
	Color8(122, 74, 35): ReachField.EARTH,   Color8(140, 140, 140): ReachField.RUBBLE,
	Color8(46, 111, 242): ReachField.WATER,  Color8(46, 158, 63): ReachField.CLIMB,
	Color8(210, 180, 140): ReachField.SILT,  Color8(86, 112, 126): ReachField.BOULDER,
}
const MARKER_COLORS := {
	Color8(255, 0, 255): &"spawn",  Color8(255, 215, 0): &"friend", Color8(0, 255, 255): &"portal",
	Color8(255, 34, 34): &"leak",   Color8(255, 136, 0): &"barrel", Color8(255, 255, 0): &"curio",
	Color8(183, 240, 74): &"lilypad", Color8(160, 32, 240): &"vent",
}
## queue_free'd on map reaches (spec C3 — normative). Hidden-but-alive hub vents make a map
## reach UNWINNABLE (the banner's all-vents gate polls the group), so retirement is by free.
const RETIRE := ["Beach", "Seabed", "Banks", "BeachRight", "BankTowerBody", "BlockLand",
	"BlockLandRight", "BankTower", "Grass", "GrassFront", "TowerWall", "TowerDrape",
	"LandNook1", "LandNook2", "LandNook3", "Vent1", "Vent2", "Vent3",
	"GroundFill", "SeabedBackdrop"]

var grid := PackedByteArray()
var gw := 0
var gh := 0
var table_row := 0
var _cfg: CoveConfig

func setup(cfg: CoveConfig) -> void:
	if cfg.map_terrain == null:
		queue_free()                            # classic reach — the rect ReachField stands
		return
	classify(cfg)
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	field.set_mask(cfg.map_origin, grid, gw, gh, table_row)
	_retire_handbuilt()
	build()
	print("[reach_map] %s: %dx%d cells, table row %d, %d portals" %
		[cfg.id, gw, gh, table_row, cfg.portal_markers.size()])

## Pure data stage (headless-testable without a scene): grids + config expansion.
func classify(cfg: CoveConfig) -> void:
	_cfg = cfg
	var timg := cfg.map_terrain.get_image()
	var mimg := cfg.map_markers.get_image()
	assert(not timg.is_compressed(), "map textures must import lossless (compress mode 0)")
	gw = timg.get_width(); gh = timg.get_height()
	grid.resize(gw * gh)
	table_row = gh
	for cy in gh:
		for cx in gw:
			var code := ReachField.AIR
			var px := timg.get_pixel(cx, cy)
			if px.a8 >= 128:                    # alpha gate FIRST (import bleeds RGB — spec M3)
				var key := Color8(px.r8, px.g8, px.b8)
				if TERRAIN_COLORS.has(key):
					code = TERRAIN_COLORS[key]
				else:
					push_warning("reach_map: off-legend terrain %s at (%d,%d)" % [key, cx, cy])
			grid[cy * gw + cx] = code
			if code == ReachField.WATER and cy < table_row:
				table_row = cy
	cfg.has_map = true
	cfg.surface_y = cfg.map_origin.y + float(table_row) * CELL
	var wb := _water_cell_bounds()
	cfg.water_left = cfg.map_origin.x + float(wb.position.x) * CELL
	cfg.water_right = cfg.map_origin.x + float(wb.end.x) * CELL
	cfg.seabed_y = cfg.map_origin.y + float(wb.end.y) * CELL
	cfg.camera_bounds = Rect2(cfg.map_origin, Vector2(gw, gh) * CELL).grow(24.0)
	cfg.ground_hold_y = _derive_ground_hold()
	_harvest(mimg)

func cell_world(cx: int, cy: int) -> Vector2:   # cell CENTER, cove-local
	return _cfg.map_origin + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL

func _water_cell_bounds() -> Rect2i:
	var minx := gw; var maxx := -1; var miny := gh; var maxy := -1
	for cy in gh:
		for cx in gw:
			if grid[cy * gw + cx] == ReachField.WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

## Highest DRY standable earth top (air above earth, above the table), minus a 4-cell margin:
## the follower ceiling (spec 4.6). Fallback: the legacy hub const.
func _derive_ground_hold() -> float:
	for cy in range(0, table_row):
		for cx in gw:
			if cy + 1 < gh and grid[cy * gw + cx] == ReachField.AIR \
					and grid[(cy + 1) * gw + cx] == ReachField.EARTH:
				return _cfg.map_origin.y + float(cy - 4) * CELL
	return -62.0

func _harvest(mimg: Image) -> void:
	_cfg.curios = []
	_cfg.pad_xs = PackedFloat32Array()
	_cfg.barrel_positions = []; _cfg.vent_positions = []; _cfg.portal_markers = []
	for cy in gh:
		for cx in gw:
			var px := mimg.get_pixel(cx, cy)
			if px.a8 < 128:
				continue
			var key := Color8(px.r8, px.g8, px.b8)
			if not MARKER_COLORS.has(key):
				push_warning("reach_map: off-legend marker %s at (%d,%d)" % [key, cx, cy])
				continue
			var pos := cell_world(cx, cy)
			var solid := grid[cy * gw + cx] != ReachField.AIR and grid[cy * gw + cx] != ReachField.WATER
			if solid:
				push_warning("reach_map: %s marker buried at (%d,%d)" % [MARKER_COLORS[key], cx, cy])
			match MARKER_COLORS[key]:
				&"spawn":  _cfg.spawn_pos = pos
				&"friend": _cfg.friend_pos = pos
				&"leak":   _cfg.leak_pos = pos
				&"curio":  _cfg.curios.append(pos)
				&"lilypad": _cfg.pad_xs.append(pos.x)
				&"barrel": _cfg.barrel_positions.append(pos)
				&"vent":   _cfg.vent_positions.append(pos)
				&"portal": _cfg.portal_markers.append({"pos": pos, "edge": _edge_of(cx, cy)})

func _edge_of(cx: int, cy: int) -> String:
	if cx <= 2: return "west"
	if cx >= gw - 3: return "east"
	if cy <= 2: return "top"
	if cy >= gh - 3: return "bottom"
	return ""

func _retire_handbuilt() -> void:
	var root := get_parent()
	for n in RETIRE:
		var node := root.get_node_or_null(n)
		if node:
			node.queue_free()

## Geometry builders (Tasks 3-6) chain here.
func build() -> void:
	pass

## 4-connected components of one cell code, as cell-space rects. Non-rect components warn and
## return their bounding box (authoring lint enforces rectangles for seals/gates).
func component_rects(code: int) -> Array[Rect2i]:
	var seen := PackedByteArray(); seen.resize(gw * gh)
	var out: Array[Rect2i] = []
	for cy in gh:
		for cx in gw:
			if grid[cy * gw + cx] != code or seen[cy * gw + cx] == 1:
				continue
			var stack := [Vector2i(cx, cy)]
			seen[cy * gw + cx] = 1
			var minx := cx; var maxx := cx; var miny := cy; var maxy := cy
			var count := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				count += 1
				minx = mini(minx, c.x); maxx = maxi(maxx, c.x)
				miny = mini(miny, c.y); maxy = maxi(maxy, c.y)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.x >= gw or n.y < 0 or n.y >= gh:
						continue
					if grid[n.y * gw + n.x] == code and seen[n.y * gw + n.x] == 0:
						seen[n.y * gw + n.x] = 1
						stack.push_back(n)
			var rect := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
			if count != rect.size.x * rect.size.y:
				push_warning("reach_map: non-rectangular component (code %d) near (%d,%d)" % [code, cx, cy])
			out.append(rect)
	return out
