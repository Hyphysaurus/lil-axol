extends Node2D
## A CLIMBABLE root curtain — the designated-surface climbing rule (Maram, 2026-07-09): verticality
## reads as ECOLOGY. Hanging roots and rough growth on a bank face are climbable; smooth block faces
## never are. The axolotl grabs it with UP, scales it with UP/DOWN, and hops off with JUMP
## (see axolotl._climb). Purely a zone + a drawn visual: no collision of its own — group
## "climbable" + has_point() is the whole contract. Drop one on any vertical face.

const REDRAW_HZ := 12.0

## The climbable strip, in local space: from this node's origin extending down-right by extent.
@export var extent := Vector2(14.0, 92.0)
## How many root strands to draw across the strip's width.
@export var strands := 4
## Which side the ledge at the TOP is on (+1 right, -1 left): cresting the curtain hops the
## climber onto it instead of letting them jitter against the strip's upper edge.
@export var ledge_side := 1.0
## false = a purely DECORATIVE drape (same art, no grab): dresses ledges and faces so climbable
## curtains aren't the only roots in the world — the real ones stay special but not arbitrary.
@export var climbable := true

var _t := 0.0
var _acc := 0.0
var _phases: Array = []

func _ready() -> void:
	if climbable:
		add_to_group("climbable")
	z_index = 3                      # over the land blocks, under the axolotl (z 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5                     # stable strand shapes per scene
	for i in strands:
		_phases.append(rng.randf_range(0.0, TAU))
	queue_redraw()

## Is a WORLD point inside the climbable strip? The axolotl polls this to grab/stay latched.
func has_point(world: Vector2) -> bool:
	var p := to_local(world)
	return p.x >= -6.0 and p.x <= extent.x + 6.0 and p.y >= 0.0 and p.y <= extent.y

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()               # the roots sway gently, GrassLayer-idiom throttled

func _draw() -> void:
	# a recessed groove behind the curtain: the roots hang in a carved seam, not painted on the face
	draw_rect(Rect2(Vector2(-2.0, 0.0), Vector2(extent.x + 4.0, extent.y)), Color(Palette.INK, 0.16))
	for i in strands:
		var x := (float(i) + 0.5) / float(strands) * extent.x
		var phase: float = _phases[i]
		# each strand is a chain of short segments swaying more toward its loose lower end
		var pts := PackedVector2Array()
		var segs := int(extent.y / 12.0)
		for s in segs + 1:
			var yy := float(s) / float(segs) * extent.y
			var loose := yy / extent.y
			pts.append(Vector2(x + sin(_t * 1.2 + phase + yy * 0.05) * 2.5 * loose, yy))
		# two-tone strand: a dark under-line with a lit face reads as a thick rope of root
		draw_polyline(pts, Palette.LOAM.darkened(0.35), 4.0)
		draw_polyline(pts, Palette.LOAM, 2.0)
		# leaf clusters + rootlet nubs — the mass of green is what makes the curtain read lush
		# and grabbable instead of wiry bare wire
		for s in range(1, segs, 2):
			var yy := float(s) / float(segs) * extent.y
			var px := x + sin(_t * 1.2 + phase + yy * 0.05) * 2.5 * (yy / extent.y)
			var side := 3.5 if (i + s) % 2 == 0 else -3.5
			draw_line(Vector2(px, yy), Vector2(px + side, yy + 2.0), Palette.MOSS, 1.5)
			var tip := Vector2(px + side, yy + 2.0)
			draw_circle(tip, 2.2, Palette.MOSS)                       # cluster base
			draw_circle(tip + Vector2(side * 0.35, -1.6), 1.9, Palette.LEAF)
			draw_circle(tip + Vector2(-side * 0.25, 1.6), 1.6, Palette.MOSS)
			if (i + s) % 3 == 0:   # the odd bright new-growth leaf catches the light
				draw_circle(tip + Vector2(side * 0.6, 0.4), 1.3, Palette.SPROUT)
	# the ANCHOR: a mound of root-woven soil hugging the top lip — where the curtain grows from,
	# and the visual promise that the top is a place you can stand. Knots only, weighted toward
	# the ledge side: a full-width bar floats in air wherever the strip sits proud of the face.
	for i in strands:
		var x := (float(i) + 0.5) / float(strands) * extent.x
		draw_circle(Vector2(x, 1.5), 3.2, Palette.LOAM.darkened(0.3))
		draw_circle(Vector2(x + ledge_side * 1.2, 0.0), 2.4, Palette.SOIL)
	var lip_x := extent.x * (0.7 if ledge_side > 0.0 else 0.3)
	draw_circle(Vector2(lip_x, -1.0), 3.4, Palette.SOIL.darkened(0.15))
	draw_circle(Vector2(lip_x + ledge_side * 4.0, -1.5), 2.6, Palette.SOIL)
	draw_circle(Vector2(lip_x + ledge_side * 7.5, -0.5), 2.0, Palette.MOSS)
