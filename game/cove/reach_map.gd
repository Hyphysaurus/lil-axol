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

const LAND_SHADER := preload("res://shaders/reach_land.gdshader")
const WHITE := preload("res://assets/white.png")
const RockScript := preload("res://game/cove/destructible_rock.gd")
const ClimbWallScript := preload("res://game/cove/climb_wall.gd")
const PortalScript := preload("res://game/cove/cove_portal.gd")
const VentScene := preload("res://game/cove/thermal_vent.gd")

var grid := PackedByteArray()
var gw := 0
var gh := 0
var table_row := 0
var _cfg: CoveConfig
var _land_mat: ShaderMaterial

func setup(cfg: CoveConfig) -> void:
	if cfg.map_terrain == null or cfg.map_markers == null:
		if cfg.map_terrain != null and cfg.map_markers == null:
			push_warning("reach_map: map_terrain set but map_markers missing - retiring")
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
	assert(not mimg.is_compressed(), "map textures must import lossless (compress mode 0)")
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
	cfg.shore_xs = _harvest_shore_xs()
	_harvest(mimg)

func cell_world(cx: int, cy: int) -> Vector2:   # cell CENTER, cove-local
	return _cfg.map_origin + Vector2(float(cx) + 0.5, float(cy) + 0.5) * CELL

## Greedy horizontal-run + vertical-extend merge: rows of identical runs fuse downward.
static func merge_rects(g: PackedByteArray, w: int, h: int, solid: Callable) -> Array[Rect2i]:
	var used := PackedByteArray(); used.resize(w * h)
	var out: Array[Rect2i] = []
	for cy in h:
		var cx := 0
		while cx < w:
			if used[cy * w + cx] == 1 or not solid.call(g[cy * w + cx]):
				cx += 1
				continue
			var x1 := cx
			while x1 < w and used[cy * w + x1] == 0 and solid.call(g[cy * w + x1]):
				x1 += 1
			var y1 := cy + 1
			while y1 < h:
				var ok := true
				for xx in range(cx, x1):
					if used[y1 * w + xx] == 1 or not solid.call(g[y1 * w + xx]):
						ok = false
						break
				if not ok: break
				y1 += 1
			for yy in range(cy, y1):
				for xx in range(cx, x1):
					used[yy * w + xx] = 1
			out.append(Rect2i(cx, cy, x1 - cx, y1 - cy))
			cx = x1
	return out

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

## Water-at-the-table columns (the still waterline row) with an earth neighbor on either side —
## the marsh's shore/bank edges (spec 4.6). reeds.gd roots here on a painted map instead of the
## legacy rect's fixed left/right bands (companion Task 7).
func _harvest_shore_xs() -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	if table_row >= gh:
		return xs
	for cx in gw:
		if grid[table_row * gw + cx] != ReachField.WATER:
			continue
		var left_earth := cx > 0 and grid[table_row * gw + cx - 1] == ReachField.EARTH
		var right_earth := cx < gw - 1 and grid[table_row * gw + cx + 1] == ReachField.EARTH
		if left_earth or right_earth:
			xs.append(cell_world(cx, table_row).x)
	return xs

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
	_build_land()
	_hook_cleanliness.call_deferred()
	_build_collision()
	_build_surround()
	_resize_water()
	_build_breakables()
	_build_climbs()
	_build_portals()
	_build_vents()
	_place_spawn()

## The land visual: ONE quad the size of the whole map, textured with the terrain PNG itself as
## a mask (spec 4.2). z 7 — over water(5) + oil film(6), under portals/FX(8, later tasks).
func _build_land() -> void:
	_land_mat = ShaderMaterial.new()
	_land_mat.shader = LAND_SHADER
	_land_mat.set_shader_parameter("mask_tex", _cfg.map_terrain)
	_land_mat.set_shader_parameter("grid", Vector2(gw, gh))
	_land_mat.set_shader_parameter("surface_row", float(table_row))
	var quad := Sprite2D.new()
	quad.name = "MapLand"
	quad.texture = WHITE
	quad.centered = false
	quad.position = _cfg.map_origin
	quad.scale = Vector2(gw, gh) * CELL
	quad.material = _land_mat
	quad.z_index = 7                            # the z-map: over water(5)+film(6), under portals(8)
	add_child(quad)

## Restoration -> the land quad's oil stain, mirroring block_land.gd's _hook() idiom (same
## group, same signal, same current_clean seed): reach_land.gdshader defaults `oil` to 1.0 and
## nothing else ever drove it, so a painted map's soil stayed oil-stained forever even after full
## restoration. Deferred off _build_land() so the oil manager is in its group by the time we look.
## No per-frame cost — the uniform is written on signal only.
func _hook_cleanliness() -> void:
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr == null:
		return
	if mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(func(v: float) -> void: _land_mat.set_shader_parameter("oil", 1.0 - v))
	if "current_clean" in mgr:
		_land_mat.set_shader_parameter("oil", 1.0 - mgr.current_clean)

## Static collision from the solid mask (earth + climb) — one StaticBody2D, greedy-merged
## rects (spec §4.3); rubble/gates own their own collision.
func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "MapCollision"
	add_child(body)
	for r in merge_rects(grid, gw, gh, func(c): return c == ReachField.EARTH or c == ReachField.CLIMB):
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(r.size) * CELL
		shape.shape = rect
		shape.position = _cfg.map_origin + (Vector2(r.position) + Vector2(r.size) * 0.5) * CELL
		body.add_child(shape)

## Per-cove environment tint for the land quad. cove.gd's _apply_environment() tint loop matches
## nodes by name and would otherwise miss this quad (it hangs off ReachMap, not a bare
## "BlockLand"/"BlockLandRight" node — spec 4.2 reviewer M1), so that loop now includes
## "ReachMap" itself and calls this.
func set_env_tint(c: Color) -> void:
	if _land_mat:
		_land_mat.set_shader_parameter("env_tint", c)

## Dark earth surround + the backdrop behind translucent water (spec I4): fills the whole map
## rect below the table AND a margin outside it, GroundFill's palette language, one draw.
func _build_surround() -> void:
	var s := Node2D.new()
	s.name = "MapSurround"
	s.z_index = 3
	add_child(s)
	s.draw.connect(_draw_surround.bind(s))
	s.queue_redraw()

func _draw_surround(s: Node2D) -> void:
	var deep := Palette.INK.lerp(Color(0.11, 0.16, 0.23), 0.25)
	var r := Rect2(_cfg.map_origin, Vector2(gw, gh) * CELL).grow(1400.0)
	s.draw_rect(r, deep)                                        # far field
	var below := Rect2(Vector2(_cfg.map_origin.x, _cfg.surface_y),
		Vector2(float(gw) * CELL, float(gh) * CELL - float(table_row) * CELL))
	s.draw_rect(below, Color(0.11, 0.16, 0.23))                 # water backdrop

## Sizes the shared Water sprite/shader to the painted map's water bbox (spec 4.5). Sets
## rect_size here too even though _apply_environment ALWAYS-writes it (Task 3 step 3) — ReachMap
## setup runs before _apply_environment, so this covers anything that reads the shader before then.
func _resize_water() -> void:
	var wt := get_parent().get_node_or_null("Water") as Sprite2D
	if wt == null:
		return
	var b: Rect2 = (get_tree().get_first_node_in_group("reach_field") as ReachField).water_bounds()
	wt.position = b.position
	wt.scale = b.size
	var wm := wt.material as ShaderMaterial
	if wm:
		wm.set_shader_parameter("rect_size", b.size)

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

## Seals: rubble breaks freely (turtle ram / bubble bomb); silt+boulder gates are LOCKED this
## slice (blast() bounces off — cozy "not yet", slice 6 unlocks by kind). edge=1.5 forces a FULL
## rect (the lump-erosion default 0.92 eats through a 2-wide seal — spec I7). Seal ids are ordinal
## over a FIXED iteration order (code ascending, then component_rects' row-major scan order) —
## stable for a given painted PNG; repainting a map invalidates that reach's seal saves only
## (accepted — WorldState keys are per-cove, so it never bleeds into another reach).
func _build_breakables() -> void:
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	var idx := 0
	for entry in [[ReachField.RUBBLE, false, Palette.SLATE, Palette.STEEL],
			[ReachField.SILT, true, Color8(210, 180, 140), Color8(184, 152, 112)],
			[ReachField.BOULDER, true, Color8(86, 112, 126), Color8(64, 86, 98)]]:
		for r in component_rects(entry[0]):
			var key := "seal_%d" % idx
			idx += 1
			var rock = RockScript.new()
			rock.cols = r.size.x
			rock.rows = r.size.y
			rock.edge = 1.5                       # FULL rect: default 0.92 erodes 2-wide seals (spec I7)
			rock.locked = entry[1]
			rock.tone_a = entry[2]
			rock.tone_b = entry[3]
			rock.position = _cfg.map_origin + Vector2(r.position) * CELL
			add_child(rock)
			if not entry[1]:
				# broken seals STAY broken (ruling 5); echo runs replay them sealed, never persist
				var root := get_tree().get_first_node_in_group("cove_root")
				var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
				if not echo and bool(WorldState.get_cove(_cfg.id, key, false)):
					_carve_rect(field, r)
					rock.queue_free()
					continue
				rock.carved.connect(func(p: Vector2, rad: float) -> void: field.carve(p, rad))
				rock.cleared.connect(func() -> void:
					_carve_rect(field, r)         # belt & braces: the whole seal is open water now
					if not echo:
						WorldState.mark(_cfg.id, key, true))

## Every cell of a cleared/pre-cleared seal becomes water — carve_cell flips exactly one cell,
## no 3x3 bleed from the radius-based carve() function.
func _carve_rect(field: ReachField, r: Rect2i) -> void:
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			field.carve_cell(cx, cy)

## Green (CLIMB) runs become climbable root curtains — one ClimbWall per painted component.
func _build_climbs() -> void:
	for r in component_rects(ReachField.CLIMB):
		var wall = ClimbWallScript.new()
		wall.extent = Vector2(r.size) * CELL
		wall.strands = maxi(2, r.size.x)          # thin strips still read as a curtain
		wall.position = _cfg.map_origin + Vector2(r.position) * CELL
		add_child(wall)

## Painted portal markers become live passages (spec 4.7): an edge wired in cfg.map_exits opens
## immediately — the painted rubble seal in front (see _build_breakables) is the real gate, not the
## portal itself — while an unwired edge spawns DORMANT (dark, inert, a promise for a later slice).
## Map portals persist their "opened" flag the same way the legacy $Portal does (cove.gd
## _wire_saves/_apply_saved), skipped on an echo run so a score replay never writes state — same
## idiom as the T5 seal persistence. A REVISIT (WorldState already marked this edge open) reopens
## SILENTLY via configure()'s already_open flag — no SFX, no glow tween, no opened re-emit — because
## the map is rebuilt from scratch on every scene load; without this every reload would replay the
## "opened" cue and re-mark WorldState (mark() itself is idempotent, but the SFX/tween is not).
func _build_portals() -> void:
	var root := get_tree().get_first_node_in_group("cove_root")
	var echo: bool = root != null and root.has_method("is_echo") and root.is_echo()
	for m in _cfg.portal_markers:
		var edge: String = m["edge"]
		var target: String = _cfg.map_exits.get(edge, "")
		var was_open: bool = target != "" and bool(WorldState.get_cove(_cfg.id, "portal_" + edge, false))
		var p = PortalScript.new()
		p.position = m["pos"]
		add_child(p)
		if target != "" and not echo:
			# connect BEFORE configure(): a first-time (not was_open) portal opens synchronously
			# inside configure() and this signal must already be live to catch that emission. On a
			# revisit configure() reopens silently — opened never re-fires — so this mark lands
			# exactly once per world, not once per scene load.
			p.opened.connect(func() -> void: WorldState.mark(_cfg.id, "portal_" + edge, true))
		p.configure(_cfg, target, edge, target == "", was_open)

## Painted vent markers become seabed ThermalVents (spec 4.8) — smaller caps than the hub's hand-
## placed vents (7x5 vs the default 11x7), since a map cell grid reads finer already.
func _build_vents() -> void:
	for p in _cfg.vent_positions:
		var v = VentScene.new()
		v.cap_cols = 7
		v.cap_rows = 5
		v.position = p
		add_child(v)

## The inward unit vector for an edge key — which way "into the map" points from that door.
static func edge_inward(edge: String) -> Vector2:
	match edge:
		"west": return Vector2.RIGHT
		"east": return Vector2.LEFT
		"top": return Vector2.DOWN
		"bottom": return Vector2.UP
	return Vector2.RIGHT

## Where the axolotl appears: the entry portal marker for a tunnel crossing (a 20px nudge off the
## mouth, in whatever direction faces INTO the map for that edge — edge_inward() — so the axo
## doesn't spawn dead-center in the passage geometry, and east/top/bottom doors don't shove it
## outward/sideways), else the painted spawn marker for a fresh/non-portal load. Runs at the end of
## build() — after the axolotl exists as Cove's sibling but before cove.gd's own arrival logic reads
## the (now-consumed) portal flags.
func _place_spawn() -> void:
	var axo := get_parent().get_node_or_null("Axolotl") as Node2D
	if axo == null:
		return
	if Settings.arrive_via_portal and Settings.arrive_entry != "":
		for m in _cfg.portal_markers:
			if m["edge"] == Settings.arrive_entry:
				axo.position = get_parent().to_local(to_global(m["pos"])) + edge_inward(m["edge"]) * 20.0
				return
	axo.position = get_parent().to_local(to_global(_cfg.spawn_pos))
