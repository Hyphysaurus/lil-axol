extends SceneTree
## The watershed chart's rules, held mechanically (game/hud/map_chart.gd): layout is stable and
## full-graph, visibility is memory + a one-door tease, and a tease keeps ALL its secrets — no
## name, no colour, no edges of its own. The overlay (map_overlay.gd) only draws what this emits,
## so these checks ARE the map's behaviour. Runs against the REAL registry for the shipped world
## and against stub graphs for the rules a five-reach world can't isolate.
##
## Harness note: one-shot _process() per the trap at tests/test_reach_map.gd:3-17 (the registry
## load()s .tres configs whose script chain is not compile-visible under --headless --script).
##
## Run: & $godot --headless --path . --script res://tests/test_map_chart.gd

var _fails := 0
var _checks := 0
var _done := false

func _check(name: String, ok: bool) -> void:
	_checks += 1
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1

## A registry-shaped stub: bidirectional doors declared as id -> [neighbours].
class StubReg:
	var graph := {}
	func _init(g: Dictionary) -> void:
		graph = g
	func ids() -> Array:
		return graph.keys()
	func doors_of(id: String) -> Array:
		var out: Array = []
		for to in graph.get(id, []):
			out.append({"to": to, "to_scene": "", "via": "x"})
		return out
	func name_of(id: String) -> String:
		return id.capitalize()
	func door_tint_of(_id: String) -> Color:
		return Color(0.5, 0.6, 0.7, 1.0)

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var Chart = load("res://game/hud/map_chart.gd")
	var Registry = load("res://game/world/reach_registry.gd")
	_test_full_world(Chart, Registry)
	_test_fresh_world(Chart, Registry)
	_test_stability(Chart, Registry)
	_test_tease_secrecy(Chart)
	print("RESULT: %s (%d checks)" % ["FAIL x%d" % _fails if _fails > 0 else "ALL PASS", _checks])
	quit(1 if _fails > 0 else 0)
	return true

func _node(chart: Dictionary, id: String) -> Dictionary:
	for n in chart["nodes"]:
		if n["id"] == id:
			return n
	return {}

## Everything visited: the whole shipped world on the chart, laid out by hub-distance.
func _test_full_world(Chart, Registry) -> void:
	var all: Array = Registry.ids()
	var chart: Dictionary = Chart.build(Registry, all, "estuary", ["hub"])
	_check("full world shows every reach (%d)" % chart["nodes"].size(), chart["nodes"].size() == all.size())
	for want in [["hub", 0], ["estuary", 1], ["creek", 1], ["canals", 2], ["refugio", 2]]:
		_check("%s at depth %d" % [want[0], want[1]], int(_node(chart, want[0]).get("depth", -1)) == want[1])
	var ok_named := true
	var ok_tinted := true
	var spots := {}
	var ok_spots := true
	var currents := 0
	for n in chart["nodes"]:
		ok_named = ok_named and not n["tease"] and String(n["name"]) != ""
		ok_tinted = ok_tinted and Color(n["tint"]).a > 0.0
		var key := "%d/%d" % [n["depth"], n["row"]]
		ok_spots = ok_spots and not spots.has(key)
		spots[key] = true
		if n["current"]:
			currents += 1
	_check("no teases, every node named", ok_named)
	_check("every node keeps its door colour", ok_tinted)
	_check("no two nodes share a spot", ok_spots)
	_check("exactly one you-are-here, on the estuary", currents == 1 and bool(_node(chart, "estuary")["current"]))
	_check("restored pearl on the hub alone", bool(_node(chart, "hub")["restored"]) and not bool(_node(chart, "estuary")["restored"]))
	_check("the shipped world draws 4 doors", chart["edges"].size() == 4)
	var ok_pairs := true
	for e in chart["edges"]:
		ok_pairs = ok_pairs and String(e[0]) < String(e[1])
	_check("edges deduped (sorted pairs)", ok_pairs)

## A brand-new player who has only seen the hub: two nameless teases, nothing further.
func _test_fresh_world(Chart, Registry) -> void:
	var chart: Dictionary = Chart.build(Registry, ["hub"], "hub", [])
	_check("fresh world shows 3 (hub + 2 teases)", chart["nodes"].size() == 3)
	for id in ["estuary", "creek"]:
		var n := _node(chart, id)
		_check("%s teased" % id, bool(n.get("tease", false)))
		_check("%s tease keeps its name secret" % id, String(n.get("name", "x")) == "")
		_check("%s tease keeps its colour secret" % id, Color(n.get("tint", Color.WHITE)).a == 0.0)
	_check("canals not yet dreamed of", _node(chart, "canals").is_empty())
	_check("refugio not yet dreamed of", _node(chart, "refugio").is_empty())
	_check("2 doors from the hub, none between teases", chart["edges"].size() == 2)
	var far: Dictionary = Chart.build(Registry, ["hub"], "canals", [])
	_check("current marker never lands on the unknown", _node(far, "canals").is_empty())

## A reach's spot never moves as the map fills in — the chart grows, it does not rearrange.
func _test_stability(Chart, Registry) -> void:
	var partial: Dictionary = Chart.build(Registry, ["hub", "estuary"], "hub", [])
	var full: Dictionary = Chart.build(Registry, Registry.ids(), "hub", [])
	var a := _node(partial, "estuary")
	var b := _node(full, "estuary")
	_check("estuary keeps its spot as the world fills in", a["depth"] == b["depth"] and a["row"] == b["row"])

## Two teases adjacent to each other must not reveal they connect (triangle world), and a tease's
## restored state stays hidden; a chain proves depth-2 stays absent.
func _test_tease_secrecy(Chart) -> void:
	var tri := StubReg.new({"hub": ["a", "b"], "a": ["hub", "b"], "b": ["hub", "a"]})
	var chart: Dictionary = Chart.build(tri, ["hub"], "hub", ["a"])
	_check("triangle: both neighbours teased", bool(_node(chart, "a").get("tease", false)) and bool(_node(chart, "b").get("tease", false)))
	_check("triangle: no edge between two unknowns", chart["edges"].size() == 2)
	_check("a teased reach never shows a pearl", not bool(_node(chart, "a")["restored"]))
	var chain := StubReg.new({"hub": ["a"], "a": ["hub", "b"], "b": ["a"]})
	var chart2: Dictionary = Chart.build(chain, ["hub"], "hub", [])
	_check("chain: two doors out stays invisible", _node(chart2, "b").is_empty() and chart2["nodes"].size() == 2)
