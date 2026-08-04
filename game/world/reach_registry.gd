extends RefCounted
## THE WORLD'S IDENTITY TABLE: reach id -> display name, scene, config. One row per place.
##
## Why this exists: until now the topology had NO single source of truth. It lived scattered across
## `exit_target`/`exit2_target` in four .tres configs plus `map_exits` in a fifth, every destination
## written as a SCENE PATH rather than a reach id, and no reach had a display name at all — configs
## carry `id` ("hub", "canals") and nothing else. Nothing could answer "what is behind this door?"
## in words, which is why every portal in the game draws the same unlabelled tunnel and why there is
## no map. Both the door signage and the map overlay need exactly this table.
##
## DELIBERATELY THIN. This holds identity — name, scene, config — and NOT the graph. `doors_of()`
## derives edges by reading the configs themselves, so the wiring has exactly one home (the .tres
## files, where Maram edits it) and this table can never disagree with it about who connects to whom.
## The one thing that CAN drift is which config belongs to which id, so the lint suite asserts every
## record's config actually carries that `id` — see tests/test_reach_registry.gd.
##
## NAMES (Maram, 2026-07-28): Californio Spanish. Alta California was Mexican territory until 1848,
## so old-California water vocabulary IS the Xochimilco vocabulary — the register she wanted costs
## the setting nothing. `tular` even carries the seam: Nahuatl *tōllin* -> Spanish *tule* -> the
## California marsh word. `refugio` keeps its design meaning (master §7's real chinampa-refugio).
##
## Preloaded by its users, like companion_library.gd — no class_name, no autoload.

const REACHES := {
	"hub": {
		"name": "El Embarcadero",     # the landing you launch from; Xochimilco's real trajinera docks
		"scene": "res://main.tscn",
		"config": "res://game/cove/cove_a.tres",
		"door_color": Color(0.95, 0.84, 0.55),   # lantern gold — the lit dock you set out from
	},
	"estuary": {
		"name": "El Tular",           # the tule marsh — the shallow reed reach (seabed_y 96)
		"scene": "res://estuary.tscn",
		"config": "res://game/cove/estuary_a.tres",
	},
	"canals": {
		"name": "Las Acequias",       # the worked irrigation canals — a garden, not a wilderness
		"scene": "res://canals.tscn",
		"config": "res://game/cove/canals_a.tres",
		"door_color": Color(0.82, 0.74, 0.92),   # flower-market lilac — Xochimilco is a field of flowers
	},
	"creek": {
		"name": "El Arroyo",          # the seasonal creek
		"scene": "res://creek.tscn",
		"config": "res://game/cove/creek_a.tres",
	},
	"refugio": {
		"name": "El Refugio",         # the shelter the player builds (slice 6)
		"scene": "res://refugio.tscn",
		"config": "res://game/cove/refugio_a.tres",
	},
}

static func ids() -> Array:
	return REACHES.keys()

static func has_id(id: String) -> bool:
	return REACHES.has(id)

static func name_of(id: String) -> String:
	return REACHES.get(id, {}).get("name", "")

static func scene_of(id: String) -> String:
	return REACHES.get(id, {}).get("scene", "")

static func config_of(id: String) -> String:
	return REACHES.get(id, {}).get("config", "")

## Scene path -> id. Portals only ever know where they lead as a `res://` path (cove_portal's
## `_exit_to`), so this is the lookup that turns a door into a place.
static func id_for_scene(path: String) -> String:
	for id in REACHES:
		if REACHES[id]["scene"] == path:
			return id
	return ""

## The signage call: what do I write on this door? Empty string for an unknown destination, so a
## caller can simply skip the label rather than print a path at the player.
static func name_for_scene(path: String) -> String:
	return name_of(id_for_scene(path))

## What does that place LOOK like? Reads the destination's own `env_water_tint` so a door can carry
## the colour of the reach beyond it — the at-a-distance half of the signage (the name toast is the
## up-close half). Falls back to a transparent colour when a reach sets no tint, which callers read
## as "no opinion, use your default". Kept here with doors_of() so config `load()`s have one home.
static func water_tint_of(id: String) -> Color:
	var path := config_of(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return Color(0.0, 0.0, 0.0, 0.0)
	var cfg = load(path)
	return cfg.env_water_tint if cfg != null else Color(0.0, 0.0, 0.0, 0.0)

static func water_tint_for_scene(path: String) -> Color:
	return water_tint_of(id_for_scene(path))

## What colour is the DOOR to this place? An explicit `door_color` wins; otherwise the reach's own
## `env_water_tint`. The split exists because hub + canals author NO water tint (their water is the
## default aqua), so their doors stayed unmarked — Maram ruled (2026-08-04) the registry carries a
## signage-only colour for them rather than authoring tints that would repaint shipped water.
## Transparent still means "no opinion, use your default", same contract as water_tint_of.
static func door_tint_of(id: String) -> Color:
	var explicit: Variant = REACHES.get(id, {}).get("door_color")
	if explicit is Color:
		return explicit
	return water_tint_of(id)

static func door_tint_for_scene(path: String) -> Color:
	return door_tint_of(id_for_scene(path))

## The graph, derived from the configs rather than duplicated here. Returns
## [{to, to_scene, via}] — `via` is "exit"/"exit2" on a legacy rect reach, or the painted edge
## ("west"/"east"/...) on a map reach. `to` is "" when a door points somewhere not in the registry,
## which the lint treats as an error: the map would have nothing to draw there.
static func doors_of(id: String) -> Array:
	var out: Array = []
	var path := config_of(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return out
	var cfg = load(path)
	if cfg == null:
		return out
	# painted reaches carry their doors as edge -> scene
	var map_exits: Dictionary = cfg.map_exits
	for edge in map_exits:
		var target: String = map_exits[edge]
		out.append({"to": id_for_scene(target), "to_scene": target, "via": String(edge)})
	# legacy rect reaches carry up to two scene-authored pathways
	if cfg.exit_enabled and not String(cfg.exit_target).is_empty():
		out.append({"to": id_for_scene(cfg.exit_target), "to_scene": String(cfg.exit_target), "via": "exit"})
	if cfg.exit2_enabled and not String(cfg.exit2_target).is_empty():
		out.append({"to": id_for_scene(cfg.exit2_target), "to_scene": String(cfg.exit2_target), "via": "exit2"})
	return out
