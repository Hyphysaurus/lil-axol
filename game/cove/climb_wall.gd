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

var _t := 0.0
var _acc := 0.0
var _phases: Array = []

func _ready() -> void:
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
		draw_polyline(pts, Palette.LOAM.darkened(0.2), 2.0)
		# rootlet nubs so the curtain reads grabbable, not just lines
		for s in range(1, segs, 2):
			var yy := float(s) / float(segs) * extent.y
			var px := x + sin(_t * 1.2 + phase + yy * 0.05) * 2.5 * (yy / extent.y)
			draw_line(Vector2(px, yy), Vector2(px + (3.0 if i % 2 == 0 else -3.0), yy + 2.0),
				Palette.MOSS, 1.5)
