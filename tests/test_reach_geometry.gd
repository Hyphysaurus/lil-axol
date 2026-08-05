extends SceneTree
## BATCH A — the "nothing is buried, nothing is unreachable" gate, across ALL FIVE reaches.
##
## WHY THIS EXISTS: on 2026-07-27 Maram's playtest surfaced two bugs of exactly one shape — a thing
## the player must reach, sitting inside solid geometry. (1) The estuary's three thermal vents were
## pinned at cove.tscn's hardcoded y=164 (the HUB's seabed) while the estuary raises seabed_y to 96,
## so all three caps sat 68px BELOW its mud floor; since restoration_banner requires every vent open,
## THE REACH COULD NOT BE COMPLETED AT ALL. (2) The estuary's hub door and the hub's own plugged exit
## were both drawn inside the BeachRight bank — the way out you must break open was invisible. Both
## were found by a human playing, both are mechanically detectable, and both are silent: nothing
## errors, nothing warns, the reach just quietly can't be finished. This suite makes that class of
## defect fail a gate instead of a playtest.
##
## SOLIDITY IS "PERMANENT TERRAIN", NOT "ANY COLLIDER" — deliberately. A vent cap buried under its
## own rubble, or a portal behind its plug, is the DESIGN (that is what the turtle's ram is for);
## a vent buried in the mud floor is the BUG. So the probe walks each hit's ancestor chain and
## ignores anything under `blastable`/`turtle_blastable`, exactly as companion.gd's `_shell_solid_at`
## does — same rule, same reason, so the shell and this audit can never disagree about what a wall is.
##
## QUERIED AGAINST PHYSICS, NOT THE ReachField MASK — also deliberately, and this is the whole reason
## the audit can cover all five reaches: a painted reach keeps its terrain in both a mask and rect
## bodies, but the legacy hub/estuary/creek/refugio keep theirs ONLY in hand-placed StaticBody2Ds
## that the field knows nothing about. Physics is the one source every reach shares. (Both of the
## 07-27 bugs were in LEGACY reaches — a mask-based audit would have missed them entirely.)
##
## PART 2 is the D-0022 linter: on the 8px grid an intended passage is THREE cells minimum, because a
## 14px body in a 16px hole has one pixel of clearance per side — traversable in theory, never in
## practice. That rule cost two round trips to discover (narrow the collider; still stuck; erode the
## map) and until now was enforced by nothing: test_reach_map guards a golden EARTH tally, which a
## two-cell shaft passes happily. Note the vertical case is stricter still — the axolotl is 18px
## TALL, so a 2-cell (16px) horizontal corridor cannot admit it at any width.
##
## Harness note (the trap documented at tests/test_reach_map.gd:3-17): under `--headless --script`
## autoload globals are NOT compile-visible in this file's own source, and add_child()'d nodes report
## a null tree, until SceneTree.initialize() finishes. So the entire body runs from a one-shot
## _process() state machine, every dependency is load()'d lazily, no bare `WorldState`/`Settings`
## identifier appears in this source, and WorldState is routed through the helper onto a SCRATCH save
## so the audit reads a fresh world (worst case: everything still sealed) and never the dev save.
##
## Run: & $godot --headless --path . --script res://tests/test_reach_geometry.gd

const REACHES: Array[String] = [
	"res://main.tscn", "res://estuary.tscn", "res://canals.tscn",
	"res://creek.tscn", "res://refugio.tscn",
]

## Painted reaches to lint for D-0022: [id, terrain png, markers png].
const PAINTED: Array = [
	["canals", "res://assets/maps/marsh_draft_terrain.png", "res://assets/maps/marsh_draft_markers.png"],
]

## D-0022 exemptions — constrictions that ARE two cells across and are deliberately not passages.
## Intent is the one thing the geometry cannot tell you, so it is written down here instead of
## guessed at, and every entry has to earn its line. Anything not listed fails the gate.
##
## canals col 42, rows 13-14: the open air beneath a ONE-CELL pillar hanging off the upper platform,
## with clear space at col 41 and col 43 — you walk around it, and no route needs it. Independently
## reached the same verdict on 07-27 from the other axis ("the 1-cell decorative notch at x=42 rows
## 13-14 … was never a passage"). Verified by dumping the classified grid, not by assuming.
const ACCEPTED_TIGHT := {
	# (emptied 2026-08-04: the canals' col-42 under-leg corridor — accepted on 07-28 as "decorative,
	# walk around it" — was exactly the gap Maram kept reporting. The walk-around was a climb curtain
	# that reads as scenery, so in play there was no way around; the leg is gone, the entry with it.
	# An allowlist line must survive a PLAYER, not just an audit.)
}

const SETTLE_FRAMES := 8        # let the physics server register the freshly added bodies
const APPROACH_RADIUS := 20.0   # a body-and-a-bit out from centre: "can I get next to this thing?"
const APPROACH_SAMPLES := 16

var _fails := 0
var _checks := 0
var _reach := 0
var _frame := 0
var _scene: Node = null
var _space: PhysicsDirectSpaceState2D = null

# painted-grid scratch for the D-0022 scan
var _g: PackedByteArray
var _gw := 0
var _gh := 0
var _earth := 1

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	if _reach >= REACHES.size():
		_lint_painted()
		print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
		quit(1 if _fails > 0 else 0)
		return true
	if _scene == null:
		var WSHelper = load("res://tests/reach_map_worldstate_helper.gd")
		WSHelper.reset_scratch("user://test_reach_geometry.save")
		_scene = (load(REACHES[_reach]) as PackedScene).instantiate()
		get_root().add_child(_scene)
		_frame = 0
		return false
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return false
	_audit(REACHES[_reach].get_file().get_basename())
	_scene.free()                 # free(), not queue_free(): the next reach must not share a frame
	_scene = null                 # with this one's "player"/"thermal_vent" group members
	_reach += 1
	return false

# --- Part 1: nothing the player must reach is inside permanent terrain -------------------------

func _audit(id: String) -> void:
	var axo := get_first_node_in_group("player") as Node2D
	_check("%s: player exists" % id, axo != null)
	if axo == null:
		return
	# the space state comes from the PLAYER's world, not the root's — the pixel shell reparents the
	# world subtree into a runtime SubViewport, so a root-side lookup can be the wrong World2D
	_space = axo.get_world_2d().direct_space_state
	_probe("%s spawn" % id, axo.global_position)

	var vents := get_nodes_in_group("thermal_vent")
	for i in vents.size():
		var v := vents[i] as Node2D
		if v != null:
			_probe_vent("%s vent %d" % [id, i], v.global_position)

	# the reach's own sleeper (group "companion"): a fresh world has no travellers, so anything here
	# is the rescuable friend — the thing the whole reach is about
	var friends := get_nodes_in_group("companion")
	for i in friends.size():
		var f := friends[i] as Node2D
		if f != null:
			_probe("%s friend %d" % [id, i], f.global_position)

	var leaks := get_nodes_in_group("leak")
	for i in leaks.size():
		var l := leaks[i] as Node2D
		if l != null:
			_probe_fixture("%s leak %d" % [id, i], l.global_position)

	# portals and curios join no group, so find them by script — covers both the scene-authored
	# $Portal/$Portal2 (setup()) and ReachMap's painted portal instances (configure())
	var portals: Array[Node] = []
	_collect(_scene, "cove_portal.gd", portals)
	for i in portals.size():
		var p := portals[i] as Node2D
		if p != null:
			_probe("%s portal %d" % [id, i], p.global_position)
	var curios: Array[Node] = []
	_collect(_scene, "curio.gd", curios)
	for i in curios.size():
		var c := curios[i] as Node2D
		if c != null:
			_probe("%s curio %d" % [id, i], c.global_position)

func _collect(node: Node, script_file: String, out: Array[Node]) -> void:
	var s := node.get_script() as Resource
	if s != null and s.resource_path.get_file() == script_file:
		out.append(node)
	for c in node.get_children():
		_collect(c, script_file, out)

## THREE probe kinds, because "buried" means different things to different fixtures. Getting this
## wrong in the first draft of this suite was instructive: probing every target's centre reported all
## twelve legacy vents as buried, including the hub's — which have shipped for months and are fine.
## A vent's origin sits EXACTLY on the seabed plane by construction (`thermal_vent.setup` assigns
## `position.y = cfg.seabed_y`), so a point query at its centre always hits the mud. The centre test
## is meaningless there; what matters is which way the fixture has to be open.

## Things the axolotl must OCCUPY or swim into — spawn, portals, the friend, curios. Centre must be
## clear, and at least one bearing out of it must be clear (the mechanical form of the hand audit run
## on 07-27, "96/96 free approach points": one free bearing is enough to approach, zero means sealed).
func _probe(label: String, p: Vector2) -> void:
	_check("%s not inside solid" % label, not _solid_at(p))
	_ring(label, p)

## Things EMBEDDED in terrain by design — the leak barrel is half-sunk in the bank on purpose. Only
## approachability is meaningful: you must be able to get a spray on it from somewhere.
func _probe_fixture(label: String, p: Vector2) -> void:
	_ring(label, p)

## A vent is a mouth in the floor: its centre is in the mud by design, but it must open UPWARD into
## water, or its plume has nowhere to rise and the axolotl can never ride the updraft. This is the
## check that catches the 07-27 estuary bug — vents pinned at y=164 under a seabed at y=96 have solid
## ground for 68px above them, and the reach's win gate needs every vent open. RED-proven by reverting
## thermal_vent.gd to 4cbbd69^ (see the suite's commit message).
func _probe_vent(label: String, p: Vector2) -> void:
	var clear := true
	for dy in [10.0, 20.0, 30.0]:
		if _solid_at(p - Vector2(0.0, dy)):
			clear = false
	_check("%s mouth opens upward" % label, clear)
	_ring(label, p)

func _ring(label: String, p: Vector2) -> void:
	var free_dirs := 0
	for i in APPROACH_SAMPLES:
		var a := TAU * float(i) / float(APPROACH_SAMPLES)
		if not _solid_at(p + Vector2(cos(a), sin(a)) * APPROACH_RADIUS):
			free_dirs += 1
	_check("%s approachable (%d/%d bearings free)" % [label, free_dirs, APPROACH_SAMPLES], free_dirs > 0)

## Mirrors companion.gd's `_shell_solid_at` exactly — breakables are NOT terrain, because clearing
## them is the game. Divergence here would mean the shell and the audit disagree about walls.
func _solid_at(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collide_with_areas = false
	q.collide_with_bodies = true
	for hit in _space.intersect_point(q, 8):
		var col: Object = hit.get("collider")
		if col == null or col is CharacterBody2D:
			continue                          # the tidekeeper herself is not terrain
		var n: Node = col as Node
		var breakable := false
		while n != null:
			if n.is_in_group("blastable") or n.is_in_group("turtle_blastable"):
				breakable = true
				break
			n = n.get_parent()
		if not breakable:
			return true
	return false

# --- Part 2: D-0022 — no two-cell through-passages in a painted map ---------------------------

func _lint_painted() -> void:
	var ReachMapScript = load("res://game/cove/reach_map.gd")
	var ReachFieldScript = load("res://game/cove/reach_field.gd")
	var CoveConfigScript = load("res://game/cove/cove_config.gd")
	_earth = ReachFieldScript.EARTH
	for entry in PAINTED:
		var cfg = CoveConfigScript.new()
		cfg.id = entry[0]
		cfg.map_terrain = load(entry[1])
		cfg.map_markers = load(entry[2])
		var rm = ReachMapScript.new()
		var root := Node2D.new()
		get_root().add_child(root)
		root.add_child(rm)
		rm.classify(cfg)
		_g = rm.grid
		_gw = rm.gw
		_gh = rm.gh
		# D-0022: every constriction the body cannot pass, named. Known-and-accepted ones are
		# allowlisted above; anything else is new and fails.
		var tight := _find_pinches()
		var unexpected: Array[String] = []
		for p in tight:
			var accepted: Array = ACCEPTED_TIGHT.get(entry[0], [])
			var known: bool = accepted.has(p.substr(0, p.find(" (")))
			print("      %s  %s: %s" % ["known" if known else "TIGHT", entry[0], p])
			if not known:
				unexpected.append(p)
		_check("%s: no unlisted 2-cell constriction (D-0022; %d new)" % [entry[0], unexpected.size()], unexpected.is_empty())
		var stranded := _stranded_markers(cfg, rm)
		for s in stranded:
			print("      STRANDED  %s: %s" % [entry[0], s])
		_check("%s: every painted marker is body-reachable from spawn (%d stranded)" % [entry[0], stranded.size()], stranded.is_empty())
		var orphans := _orphan_regions(cfg)
		for o in orphans:
			print("      ORPHAN  %s: %s" % [entry[0], o])
		_check("%s: no region is visible-but-unenterable (%d orphaned)" % [entry[0], orphans.size()], orphans.is_empty())
		root.free()

## Out of bounds counts as solid: the map edge is a wall, and a run touching it is bounded by it.
func _solid_cell(cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= _gw or cy >= _gh:
		return true
	return _g[cy * _gw + cx] == _earth

## THE GATE: is every painted marker somewhere a 14×18 body can actually GET?
##
## This replaced a purely local "flag every 2-cell opening" rule, which could not tell a blocking
## shaft from scenery. Its first run flagged col 42, rows 13-14 of the canals — which turns out to be
## the open air under a ONE-CELL pillar, with clear space on both sides; you walk around it. (The
## 07-27 hand audit reached the same verdict from the other axis: "the 1-cell decorative notch at
## x=42 rows 13-14 … was never a passage.") Whether a constriction matters is a ROUTING question, and
## routing needs connectivity, not a pattern match.
##
## So: flood-fill twice from the spawn. Once with a point agent (any free cell), once with a body that
## honours D-0022 — a 3×3 cell window, 24×24px, the smallest opening the 14×18 axolotl can pass with
## real margin. Anything the point agent reaches that the body cannot is content the map places and
## the player cannot have. That is the failure worth stopping a build for, and it is exactly what
## yesterday's two-cell shaft did: the region past it was point-reachable and body-unreachable.
##
## Breakables (RUBBLE/SILT/BOULDER) count as FREE — clearing them is the game, and a gate the turtle
## opens is design, not a defect. Today that distinction is theoretical: neither painted map contains
## a single SILT or BOULDER pixel.
func _stranded_markers(cfg: Object, rm: Object) -> Array[String]:
	var origin: Vector2 = cfg.map_origin
	var reach := _body_reachable_from(cfg.spawn_pos, origin)
	var out: Array[String] = []
	var targets: Array = [["spawn", cfg.spawn_pos], ["friend", cfg.friend_pos]]
	for i in cfg.curios.size():
		targets.append(["curio %d" % i, cfg.curios[i]])
	for i in cfg.vent_positions.size():
		targets.append(["vent %d" % i, cfg.vent_positions[i]])
	for i in cfg.barrel_positions.size():
		targets.append(["barrel %d" % i, cfg.barrel_positions[i]])
	for i in cfg.portal_markers.size():
		var m: Dictionary = cfg.portal_markers[i]
		targets.append(["portal %s" % m.get("edge", "?"), m.get("pos", Vector2.ZERO)])
	for t in targets:
		var pos: Vector2 = t[1]
		var cx := int(floor((pos.x - origin.x) / 8.0))
		var cy := int(floor((pos.y - origin.y) / 8.0))
		# a marker is satisfied if the body can stand anywhere in its own cell's 3×3 neighbourhood —
		# markers are painted at a cell centre, not at a body's resting position
		var ok := false
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if reach.has("%d,%d" % [cx + ox, cy + oy]):
					ok = true
		if not ok:
			out.append("%s at cell (%d,%d) is not body-reachable from spawn" % [t[0], cx, cy])
	return out

## THE GATE THAT ACTUALLY CATCHES THE 07-27 SHAFT. Marker-reachability alone does not: RED-proving
## it against the pre-widening map (73ec50d^) came back GREEN, because nothing painted sat behind
## that shaft — the player simply could not get through a part of the level. So compare reachable
## SPACE, not just markers: flood-fill once with a point agent and once with the D-0022 body, and
## report any sizeable region a point can enter and the body cannot. That is "you can see it, you can
## never swim into it" — the shaft's real symptom, and the thing Maram reported twice.
##
## MIN_ORPHAN keeps it honest rather than noisy: single-cell crevices and one-cell decorative nooks
## are point-reachable and body-unreachable everywhere in a hand-painted map, and none of them are
## bugs. A region of 12+ cells is a piece of level.
const MIN_ORPHAN := 12

func _orphan_regions(cfg: Object) -> Array[String]:
	var origin: Vector2 = cfg.map_origin
	var body := _body_reachable_from(cfg.spawn_pos, origin)
	# every cell the body can actually occupy = the 3×3 footprint around each standable centre
	var covered := {}
	for key in body:
		var parts := (key as String).split(",")
		var bx := int(parts[0])
		var by := int(parts[1])
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				covered["%d,%d" % [bx + ox, by + oy]] = true
	var point := _point_reachable_from(cfg.spawn_pos, origin)
	var orphan_cells := {}
	for key in point:
		if not covered.has(key):
			orphan_cells[key] = true
	# group the leftovers so one report is one place, not one per cell
	var out: Array[String] = []
	var seen := {}
	for key in orphan_cells:
		if seen.has(key):
			continue
		var parts := (key as String).split(",")
		var comp := _component(orphan_cells, seen, Vector2i(int(parts[0]), int(parts[1])))
		if comp.size() >= MIN_ORPHAN:
			var minx := 9999
			var miny := 9999
			var maxx := -1
			var maxy := -1
			for c in comp:
				minx = mini(minx, c.x); miny = mini(miny, c.y)
				maxx = maxi(maxx, c.x); maxy = maxi(maxy, c.y)
			out.append("%d cells the body cannot enter, spanning x=%d..%d, y=%d..%d" % [comp.size(), minx, maxx, miny, maxy])
	return out

func _component(cells: Dictionary, seen: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var out: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	seen["%d,%d" % [start.x, start.y]] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		out.append(c)
		for d in dirs:
			var n: Vector2i = c + d
			var key := "%d,%d" % [n.x, n.y]
			if seen.has(key) or not cells.has(key):
				continue
			seen[key] = true
			queue.append(n)
	return out

## Point agent: any free cell at all. The optimistic view of the map — what the painting implies.
func _point_reachable_from(spawn: Vector2, origin: Vector2) -> Dictionary:
	var sx := int(floor((spawn.x - origin.x) / 8.0))
	var sy := int(floor((spawn.y - origin.y) / 8.0))
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var seen := {}
	var queue: Array[Vector2i] = [Vector2i(sx, sy)]
	seen["%d,%d" % [sx, sy]] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			var key := "%d,%d" % [n.x, n.y]
			if seen.has(key) or _solid_cell(n.x, n.y):
				continue
			seen[key] = true
			queue.append(n)
	return seen

## BFS over cells where the body fits (3×3 free window), seeded from the spawn's neighbourhood so a
## marker painted one cell off a wall doesn't strand the whole fill.
func _body_reachable_from(spawn: Vector2, origin: Vector2) -> Dictionary:
	var sx := int(floor((spawn.x - origin.x) / 8.0))
	var sy := int(floor((spawn.y - origin.y) / 8.0))
	var seeds: Array[Vector2i] = []
	for ox in range(-2, 3):
		for oy in range(-2, 3):
			if _body_fits(sx + ox, sy + oy):
				seeds.append(Vector2i(sx + ox, sy + oy))
	var seen := {}
	var queue: Array[Vector2i] = seeds.duplicate()
	for s in seeds:
		seen["%d,%d" % [s.x, s.y]] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			var key := "%d,%d" % [n.x, n.y]
			if seen.has(key) or not _body_fits(n.x, n.y):
				continue
			seen[key] = true
			queue.append(n)
	return seen

## D-0022 in code: the body needs a 3-cell (24px) window, not the 2 cells (16px) that look walkable.
func _body_fits(cx: int, cy: int) -> bool:
	for ox in [-1, 0, 1]:
		for oy in [-1, 0, 1]:
			if _solid_cell(cx + ox, cy + oy):
				return false
	return true

## Informational only (see the gate above): every constriction exactly two cells across that you
## could plausibly try to travel through. Named coordinates so a fix is an edit, not a hunt.
## Vertically-adjacent repeats of the same shaft are reported once, at their first row.
func _find_pinches() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	# vertical shafts: 2 cells wide horizontally, open above AND below
	for cy in _gh:
		var cx := 0
		while cx < _gw:
			if _solid_cell(cx, cy):
				cx += 1
				continue
			var start := cx
			while cx < _gw and not _solid_cell(cx, cy):
				cx += 1
			if cx - start != 2:
				continue
			var above := not _solid_cell(start, cy - 1) or not _solid_cell(start + 1, cy - 1)
			var below := not _solid_cell(start, cy + 1) or not _solid_cell(start + 1, cy + 1)
			if above and below and not seen.has("v%d,%d" % [start, cy - 1]):
				seen["v%d,%d" % [start, cy]] = true
				out.append("vertical shaft 2 cells wide at x=%d..%d, row %d (16px — needs 3)" % [start, start + 1, cy])
			elif above and below:
				seen["v%d,%d" % [start, cy]] = true
	# horizontal corridors: 2 cells tall, open left AND right. Stricter case — the axolotl is 18px
	# tall, so 16px of headroom cannot admit it at any width.
	for cx in _gw:
		var cy := 0
		while cy < _gh:
			if _solid_cell(cx, cy):
				cy += 1
				continue
			var start := cy
			while cy < _gh and not _solid_cell(cx, cy):
				cy += 1
			if cy - start != 2:
				continue
			var left := not _solid_cell(cx - 1, start) or not _solid_cell(cx - 1, start + 1)
			var right := not _solid_cell(cx + 1, start) or not _solid_cell(cx + 1, start + 1)
			if left and right and not seen.has("h%d,%d" % [cx - 1, start]):
				seen["h%d,%d" % [cx, start]] = true
				out.append("horizontal corridor 2 cells tall at col %d, rows %d..%d (16px of headroom — body is 18px)" % [cx, start, start + 1])
			elif left and right:
				seen["h%d,%d" % [cx, start]] = true
	return out
