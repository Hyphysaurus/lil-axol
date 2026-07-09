extends RefCounted
## The partner ART REGISTRY: companion Kind -> {frames, anims, scale}, so the ROSTER can dress the
## active partner in ANY scene (the follower that travels with you through a pathway) without every
## scene's config having to know every partner's art. Per-scene config (friend_frames/anims/scale)
## stays authoritative for that scene's OWN rescuable friend; this registry covers the traveller.
## One row per partner — adding the otter later is one entry here + its .tres files (zero code).
## Preloaded (not class_name) by its users, like game/fx/spring.gd.

const ART := {
	0: {   # Kind.TURTLE — the frames the cove's Friend already uses (40px)
		"frames": preload("res://game/companion/turtle_frames.tres"),
		"anims": preload("res://game/companion/turtle_anims.tres"),
		"scale": 1.0,
	},
	1: {   # Kind.FROG — the frogpack (50px art, scaled to sit beside the 40px turtle)
		"frames": preload("res://game/companion/frog_frames.tres"),
		"anims": preload("res://game/companion/frog_anims.tres"),
		"scale": 0.85,
	},
	# 2: Kind.OTTER — reserved (deep-haul / rock-crack / sluice verbs); add its .tres rows here
}

## The display label each partner wears in the swap HUD.
const NAMES := { 0: "TURTLE", 1: "FROG" }

static func has_kind(kind: int) -> bool:
	return ART.has(kind)
