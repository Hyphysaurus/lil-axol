extends RefCounted
## THE WATERSHED CHART (Batch D): pure layout + visibility for the map overlay. No autoloads, no
## nodes — a registry goes in, drawable data comes out, so the rules live where a headless suite
## can hold them (tests/test_map_chart.gd) and the overlay stays a dumb renderer.
##
## Rules (Maram, 2026-08-04):
## - The map is MEMORY: it shows where you have been, plus a nameless, tintless "?" one door
##   beyond any visited reach — a tease, not a spoiler. Anything further simply is not there.
## - A tease keeps its secrets: no name, no door colour, and none of ITS doors are drawn (edges
##   come only from visited reaches, so two adjacent unknowns never reveal they connect).
## - Sealed doors draw like any other door — the rubble stays a surprise at the door itself.
## - Layout is computed over the FULL graph (BFS depth from the hub, alphabetical rows), so a
##   reach's position never shifts as its neighbours become visible: the map grows, it does not
##   rearrange. New registry reaches appear with no edit here.

## visited/restored are Arrays of reach ids; current_id may be "" (no marker).
## Returns {"nodes": [{id, name, tint, depth, row, tease, current, restored}], "edges": [[a, b]]}.
static func build(registry, visited: Array, current_id: String, restored: Array, root: String = "hub") -> Dictionary:
	# depth: BFS over the full graph from the root
	var depth := {root: 0}
	var queue: Array = [root]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for d in registry.doors_of(cur):
			var to: String = d["to"]
			if to.is_empty() or depth.has(to):
				continue
			depth[to] = int(depth[cur]) + 1
			queue.append(to)
	# row: stable alphabetical order within each depth column, from the full graph
	var by_col := {}
	for id in depth:
		var c: int = depth[id]
		if not by_col.has(c):
			by_col[c] = []
		by_col[c].append(id)
	var row := {}
	for c in by_col:
		by_col[c].sort()
		for i in by_col[c].size():
			row[by_col[c][i]] = i
	# visibility: visited reaches, then a tease one door beyond each of them
	var tease := {}   # id -> true = tease, false = visited
	for id in visited:
		if depth.has(id):
			tease[id] = false
	for id in visited:
		if not depth.has(id):
			continue
		for d in registry.doors_of(id):
			var to: String = d["to"]
			if not to.is_empty() and depth.has(to) and not tease.has(to):
				tease[to] = true
	var shown: Array = tease.keys()
	shown.sort()
	var nodes: Array = []
	for id in shown:
		var is_tease: bool = tease[id]
		nodes.append({
			"id": id,
			"name": "" if is_tease else String(registry.name_of(id)),
			"tint": Color(0.0, 0.0, 0.0, 0.0) if is_tease else Color(registry.door_tint_of(id)),
			"depth": int(depth[id]),
			"row": int(row[id]),
			"tease": is_tease,
			"current": (not is_tease) and id == current_id,
			"restored": (not is_tease) and restored.has(id),
		})
	# edges: only from VISITED reaches' doors, both endpoints shown, deduped either direction
	var edges: Array = []
	var seen := {}
	for id in shown:
		if tease[id]:
			continue
		for d in registry.doors_of(id):
			var to: String = d["to"]
			if to.is_empty() or not tease.has(to):
				continue
			var pair: Array = [id, to] if id < to else [to, id]
			var key: String = pair[0] + "|" + pair[1]
			if seen.has(key):
				continue
			seen[key] = true
			edges.append(pair)
	return {"nodes": nodes, "edges": edges}
