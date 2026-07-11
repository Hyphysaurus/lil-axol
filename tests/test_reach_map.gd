extends SceneTree
## ReachMap loader vs marsh_draft ground truth (commit 541dc74 tallies).
const ReachMapScript := preload("res://game/cove/reach_map.gd")
const ReachFieldScript := preload("res://game/cove/reach_field.gd")
const CoveConfigScript := preload("res://game/cove/cove_config.gd")
var fails := 0
func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name); if not ok: fails += 1
func _init() -> void:
	var cfg := CoveConfigScript.new()
	cfg.id = "canals"
	cfg.map_terrain = load("res://assets/maps/marsh_draft_terrain.png")
	cfg.map_markers = load("res://assets/maps/marsh_draft_markers.png")
	var rm = ReachMapScript.new()
	var root := Node2D.new(); get_root().add_child(root); root.add_child(rm)
	rm.classify(cfg)                      # pure data stage — no scene building needed for this suite
	_check("dims", rm.gw == 120 and rm.gh == 60)
	var t := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0}
	for c in rm.grid: t[c] += 1
	_check("tally earth", t[1] == 2556);  _check("tally rubble", t[2] == 102)
	_check("tally water", t[3] == 2348);  _check("tally climb", t[4] == 125)
	_check("table row", rm.table_row == 22)
	_check("surface_y", absf(cfg.surface_y - (cfg.map_origin.y + 22.0 * 8.0)) < 0.01)
	_check("spawn", cfg.spawn_pos == cfg.map_origin + Vector2(6.5, 16.5) * 8.0)
	_check("friend", cfg.friend_pos == cfg.map_origin + Vector2(70.5, 26.5) * 8.0)
	_check("curios", cfg.curios.size() == 3)
	_check("pads", cfg.pad_xs.size() == 15)
	_check("barrels", cfg.barrel_positions.size() == 6)
	_check("vents", cfg.vent_positions.size() == 1)
	_check("portals", cfg.portal_markers.size() == 2)
	var edges := [cfg.portal_markers[0]["edge"], cfg.portal_markers[1]["edge"]]
	_check("portal edges", edges.has("west") and edges.has("east"))
	var seals = rm.component_rects(2)
	# west plug (0,36)-(1,45), two mesa plugs (72,30)-(73,42)/(88,30)-(89,42), and TWO bottom
	# plugs (58,50)-(59,55)/(107,49)-(108,57) — re-derived via tools/audit_reach_map.ps1-style
	# flood fill against the real marsh_draft_terrain.png; the brief's "bottom plug" (singular,
	# 4 total) was stale — the map genuinely gates two separate bottom pockets, all 5 exact
	# rectangles (no non-rect lint warning).
	_check("seal components", seals.size() == 5)
	_check("camera bounds", cfg.camera_bounds.size.x >= 960.0)

	# MANDATORY carry-over from T1 review: water_bounds() must be a cached member set ONCE in
	# set_mask() (O(w*h) scan is too hot for a per-physics-frame caller like the axolotl) — prove
	# the cache equals an independent scan of the SAME marsh grid classify() just produced.
	var field := ReachFieldScript.new()
	field.set_mask(cfg.map_origin, rm.grid, rm.gw, rm.gh, rm.table_row)
	var minx: int = rm.gw; var maxx := -1; var miny: int = rm.gh; var maxy := -1
	for cy in rm.gh:
		for cx in rm.gw:
			if rm.grid[cy * rm.gw + cx] == ReachFieldScript.WATER:
				minx = mini(minx, cx); maxx = maxi(maxx, cx)
				miny = mini(miny, cy); maxy = maxi(maxy, cy)
	var scanned := Rect2(cfg.map_origin + Vector2(minx, miny) * 8.0,
		Vector2(maxx - minx + 1, maxy - miny + 1) * 8.0)
	_check("water_bounds cache == scan (marsh mask)", field.water_bounds() == scanned)
	field.free()

	# --- collision merge property: union == solid set, no overlaps ---
	var rects = ReachMapScript.merge_rects(rm.grid, rm.gw, rm.gh,
		func(c): return c == 1 or c == 4)       # earth + climb
	var covered: Dictionary = {}
	var overlap := false
	for r in rects:
		for cy2 in range(r.position.y, r.end.y):
			for cx2 in range(r.position.x, r.end.x):
				var k: int = cy2 * rm.gw + cx2
				if covered.has(k): overlap = true
				covered[k] = true
	var solid_n := 0
	for i in rm.grid.size():
		if rm.grid[i] == 1 or rm.grid[i] == 4: solid_n += 1
	_check("merge covers exactly", covered.size() == solid_n and not overlap)
	_check("merge is compact", rects.size() <= 96)

	print("RESULT: " + ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	root.free()
	quit()
