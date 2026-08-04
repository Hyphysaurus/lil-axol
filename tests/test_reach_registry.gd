extends SceneTree
## Lint for the world identity table (game/world/reach_registry.gd) — same shape as
## test_companion_library.gd guards the character records.
##
## The registry is deliberately thin: it owns NAMES and identity, while the graph is derived from the
## .tres configs so the wiring has one home. That leaves exactly one thing that can silently drift —
## which config belongs to which id — so the load-bearing check here is that every record's config
## actually carries that `id`. Mislabel a row and signage would name the wrong place with no error.
##
## The other check worth its weight is REACHABILITY: every reach must be connected to the hub through
## real doors. Adding a reach and forgetting to wire a door is a quiet failure — the place exists,
## boots, tests clean, and no player can ever see it. That is precisely how the dragonfly's Survey
## verb sat unreachable for two slices (D-0023).
##
## Harness note: runs from a one-shot _process(), never _init(), per the trap at
## tests/test_reach_map.gd:3-17 — loading a .tres config instantiates cove_config.gd, and anything in
## that dependency chain touching an autoload would not be compile-visible under `--headless
## --script`. The _process() idiom is always safe, so it is the default here rather than a reaction.
##
## Run: & $godot --headless --path . --script res://tests/test_reach_registry.gd

const MAX_NAME_LEN := 24   # door signage + the map overlay render these at HUD scale

var _fails := 0
var _checks := 0
var _done := false

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var Registry = load("res://game/world/reach_registry.gd")
	_test_records(Registry)
	_test_configs_match(Registry)
	_test_doors_resolve(Registry)
	_test_all_reachable_from_hub(Registry)
	print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
	quit(1 if _fails > 0 else 0)
	return true

func _test_records(Registry) -> void:
	_check("registry is not empty", Registry.ids().size() > 0)
	var names := {}
	for id in Registry.ids():
		var n: String = Registry.name_of(id)
		_check("%s has a display name" % id, not n.is_empty())
		_check("%s name fits signage (%d <= %d chars)" % [id, n.length(), MAX_NAME_LEN], n.length() <= MAX_NAME_LEN)
		_check("%s name is unique" % id, not names.has(n))
		names[n] = true
		var scene: String = Registry.scene_of(id)
		_check("%s scene exists (%s)" % [id, scene], ResourceLoader.exists(scene))
		# the lookup portals depend on: a door knows only its res:// path
		_check("%s round-trips scene -> id" % id, Registry.id_for_scene(scene) == id)
		_check("%s round-trips scene -> name" % id, Registry.name_for_scene(scene) == n)

## THE drift guard: a record pointing at the wrong .tres would name the wrong place, silently.
func _test_configs_match(Registry) -> void:
	for id in Registry.ids():
		var path: String = Registry.config_of(id)
		_check("%s config exists (%s)" % [id, path], ResourceLoader.exists(path))
		if not ResourceLoader.exists(path):
			continue
		var cfg = load(path)
		_check("%s config is loadable" % id, cfg != null)
		if cfg != null:
			_check("%s config carries id '%s' (got '%s')" % [id, id, cfg.id], String(cfg.id) == id)

## A door pointing at a scene the registry does not know would render on the map as a nameless node.
func _test_doors_resolve(Registry) -> void:
	var total := 0
	for id in Registry.ids():
		for d in Registry.doors_of(id):
			total += 1
			_check("%s door via %s -> known reach (%s)" % [id, d["via"], d["to_scene"]], not String(d["to"]).is_empty())
	_check("the world has doors at all (%d)" % total, total > 0)

## Every reach must be walkable from the hub. A reach nobody can open a door to is content that
## exists and cannot be played — the D-0023 failure mode, made mechanical.
func _test_all_reachable_from_hub(Registry) -> void:
	var seen := {"hub": true}
	var queue: Array = ["hub"]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		for d in Registry.doors_of(cur):
			var to: String = d["to"]
			if to.is_empty() or seen.has(to):
				continue
			seen[to] = true
			queue.append(to)
	for id in Registry.ids():
		_check("%s is reachable from the hub through real doors" % id, seen.has(id))
