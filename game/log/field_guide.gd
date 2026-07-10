extends RefCounted
## The FIELD GUIDE — the Restoration Log's data (Living Watershed spec §8: the conservation hook,
## opt-in and diegetic, never preachy). Each hidden CURIO unlocks one card: a real thing from the
## real Xochimilco, with one true line of ecology. Facts live HERE and on cards only — never in
## mid-play dialogue (the cozy tone rule). Keyed "<cove_id>_<index>" to match WorldState curio marks.
## Preloaded (not class_name) by its users, like game/fx/spring.gd.

## icon: which little code-drawn pictogram the curio wears (see curio.gd) — 0 eggs, 1 shard, 2 sprig.
const CARDS := {
	"hub_0": {
		"name": "Axolotl Egg Cluster",
		"species": "Ambystoma mexicanum",
		"fact": "Wild axolotls live in exactly one place on Earth — these canals. Fewer than a few dozen remain per square kilometre; every egg matters.",
		"icon": 0,
	},
	"hub_1": {
		"name": "Mud-Turtle Scute",
		"species": "Kinosternon integrum",
		"fact": "The Mexican mud turtle is the valley's true native. The green, red-eared sliders sold as pets are invaders here — set loose, they crowd it out.",
		"icon": 1,
	},
	"hub_2": {
		"name": "Chinampa Potsherd",
		"species": "a thousand years of farming",
		"fact": "These canals are not wild — they are a garden. Chinampa farmers have grown food on raised wetland beds here for over a thousand years.",
		"icon": 1,
	},
	"estuary_0": {
		"name": "Leopard-Frog Egg Mass",
		"species": "Lithobates montezumae",
		"fact": "The Montezuma leopard frog breeds in the same high-altitude pools as the axolotl. Where its eggs appear, the water is coming back to life.",
		"icon": 0,
	},
	"estuary_1": {
		"name": "Dragonfly Larva Husk",
		"species": "Odonata",
		"fact": "Dragonfly larvae only survive in clean, oxygen-rich water. Scientists read their return like a signature on the water's recovery.",
		"icon": 2,
	},
	"estuary_2": {
		"name": "Eelgrass Strand",
		"species": "submerged meadow",
		"fact": "Underwater plants anchor eggs, shelter hatchlings, and settle the silt. A reach with rooted greens is a reach that can raise young.",
		"icon": 2,
	},
	"enc_estuary_school": {
		"name": "Shadow in the Water",
		"species": "Oreochromis / Cyprinus — introduced",
		"fact": "Tilapia and carp were released here in the 1970s as a food program. They eat eggs and stir the silt — most of what swims these canals now was never meant to.",
		"icon": 1,
		"type": "encounter",
	},
}

static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})

## How many curios exist for a cove (drives the "X/N found in this reach" line).
static func count_for(cove_id: String) -> int:
	var n := 0
	for k in CARDS:
		if (k as String).begins_with(cove_id + "_") and CARDS[k].get("type", "curio") == "curio":
			n += 1
	return n
