extends Node2D
## Dark bedrock filling the world BELOW and BESIDE the play area, so the cove reads as a pool carved
## into the earth instead of a tank floating in sky. Three static quads (one draw, no per-frame cost):
## - BELOW: starts exactly where the seabed polygon + block-land columns end (y = 241) and CONTINUES
##   the seabed's own dark-navy tone, deepening to ink — no seam, no warm "dry loam" band underwater.
## - SIDES: beyond the beach (left) and bank (right), dark earth from ground level down, so the camera
##   never shows sky under the horizon past the level's edges.
## Sits far back (behind seabed/water/banks); the sky layer stays visible only above ground level.

const BOTTOM_Y := 241.0     # bottom edge of the seabed Polygon2D AND the 35-row block-land columns
const GROUND_Y := -39.0     # top of the block-land ground (beach + right bank) — sides start here
const LEFT_EDGE := -394.0   # where the beach's block-land ends on the left
const RIGHT_EDGE := 457.0   # where the right bank's block-land ends
const SPAN := 1400.0        # how far past the play area the fill extends each way
const DEPTH := 900.0        # how far down — deeper than the camera ever pans

const SEABED_NAVY := Color(0.11, 0.16, 0.23)   # the Seabed Polygon2D's exact tone (seamless handoff)

func _ready() -> void:
	z_index = -50           # behind the seabed backdrop, water, and land banks; above the sky layer

func _draw() -> void:
	var deep := Palette.INK.lerp(SEABED_NAVY, 0.25)    # near-black navy at depth
	# BELOW the whole world: seabed navy at the seam, fading down to ink-dark rock
	_grad(Rect2(LEFT_EDGE - SPAN, BOTTOM_Y, RIGHT_EDGE - LEFT_EDGE + SPAN * 2.0, DEPTH),
		SEABED_NAVY, deep)
	# faint strata lines so the depths aren't a dead flat gradient
	for i in 5:
		var y := BOTTOM_Y + 60.0 + float(i) * 110.0
		draw_rect(Rect2(LEFT_EDGE - SPAN, y, RIGHT_EDGE - LEFT_EDGE + SPAN * 2.0, 3.0),
			Color(Palette.INK, 0.10 + 0.02 * float(i)))
	# SIDES: earth beyond the beach / bank so the horizon continues past the level's edges. WARM
	# near the surface — this is the same dry loam as the block-land in cross-section, just in
	# shadow; the old cool mix read as a jarring black slab against the warm bank blocks.
	var side_top := Palette.LOAM.darkened(0.45)
	_grad(Rect2(LEFT_EDGE - SPAN, GROUND_Y, SPAN, BOTTOM_Y - GROUND_Y), side_top, SEABED_NAVY)
	_grad(Rect2(RIGHT_EDGE, GROUND_Y, SPAN, BOTTOM_Y - GROUND_Y), side_top, SEABED_NAVY)
	# a soft AO seam where the lit blocks end and the shadowed earth begins, so the handoff
	# reads as depth rather than a texture change (darkest at the block edge, fading outward)
	_hgrad(Rect2(LEFT_EDGE - 7.0, GROUND_Y, 7.0, BOTTOM_Y - GROUND_Y),
		Color(Palette.INK, 0.0), Color(Palette.INK, 0.22))
	_hgrad(Rect2(RIGHT_EDGE, GROUND_Y, 7.0, BOTTOM_Y - GROUND_Y),
		Color(Palette.INK, 0.22), Color(Palette.INK, 0.0))

## A vertical-gradient rectangle (per-vertex colours top -> bottom).
func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0),
			r.position + r.size, r.position + Vector2(0.0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))

## A horizontal-gradient rectangle (per-vertex colours left -> right).
func _hgrad(r: Rect2, left: Color, right: Color) -> void:
	draw_polygon(
		PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0),
			r.position + r.size, r.position + Vector2(0.0, r.size.y)]),
		PackedColorArray([left, right, right, left]))
