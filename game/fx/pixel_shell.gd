extends Node
## Slice-3 pixel shell (spec 2026-07-23): wraps the cove's world subtree in a 320x180
## SubViewport at runtime so the whole world renders on one integer-scaled pixel grid while
## HUD layers stay native-res at the cove root. Layout math is pure + static for headless
## testing. Preloaded (not class_name) by cove.gd — same portable pattern as game/fx/spring.gd.

const BASE := Vector2i(320, 180)

## Biggest integer scale that fits the physical window, view expanded to fill the remainder
## (ratified fill policy: integer + expand, never letterbox, never fractional world pixels).
static func compute_layout(phys: Vector2i) -> Dictionary:
	if phys.x <= 0 or phys.y <= 0:
		return {"scale": 1, "view": BASE}   # headless / degenerate window: neutral shell
	var k := maxi(1, mini(phys.x / BASE.x, phys.y / BASE.y))   # int division = floor
	return {"scale": k, "view": Vector2i(ceili(phys.x / float(k)), ceili(phys.y / float(k)))}
