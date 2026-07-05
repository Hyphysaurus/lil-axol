extends Node2D
class_name DestructibleRock
## PROTOTYPE — "voxel-like" destructible terrain. The rock is a grid of small CELL-sized cells,
## each with its own collision, shaped into an irregular lump. A blast() carves every cell within
## a radius: its collision is disabled and it stops drawing, so a hole opens that the axolotl can
## swim/walk through. Chunky rock bits shatter out for feel.
##
## Why a chunk grid (not a per-pixel sim): destruction here is a DISCRETE, localised blast (the
## bubble bomb now; the turtle's shell-ram later) — never a continuous per-frame simulation — so
## collision only changes on the blast. That keeps it cheap on the web / no-threads / GL-Compat
## target (a falling-sand sim would not survive there). Joins the "blastable" group; any blast
## source calls `get_tree().call_group("blastable", "blast", world_pos, radius)`.

signal cleared     # fires ONCE when the last cell is demolished (a thermal vent cap listens for this)

const CELL := 8.0                 # px per rock cell — smaller = smoother carve, more cells

@export var cols := 12
@export var rows := 9
@export var edge := 0.92          # <1 rounds/erodes the outline into an irregular lump
## Per-cell fill lerps tone_a -> tone_b. Default = cool stone (vent caps); set to LOAM/CLAY for the
## warm earthen rubble of the block-land's breakable nooks.
@export var tone_a: Color = Palette.SLATE
@export var tone_b: Color = Palette.STEEL
## true = ONLY the turtle's shell-ram can break it (the bubble bomb can't) — the land nooks use this
## so smashing them stays the turtle's job, not a stray bomb.
@export var turtle_only := false

var _present: Array = []          # rows×cols of bool — is this cell still solid?
var _shapes: Array = []           # rows×cols of CollisionShape2D (null where eroded at spawn)
var _body: StaticBody2D           # one body owns every cell's collision shape
var _remaining := 0              # solid cells still standing; when it hits 0, `cleared` fires
var _emptied := false

func _ready() -> void:
	# turtle-only nooks join a private group the bubble bomb doesn't call; everything else is "blastable"
	add_to_group("turtle_blastable" if turtle_only else "blastable")   # not "sprayable" — spray never breaks rubble
	z_index = 2
	_body = StaticBody2D.new()     # default collision layer = the axolotl bumps it for free
	add_child(_body)
	var mid := Vector2(cols, rows) * 0.5
	for r in rows:
		var prow: Array = []
		var srow: Array = []
		for c in cols:
			# irregular lump: keep a cell only inside a slightly noisy ellipse, so it reads as a
			# rock, not a perfect brick. `_hash` gives a stable per-cell jitter.
			var nx := (float(c) + 0.5 - mid.x) / mid.x
			var ny := (float(r) + 0.5 - mid.y) / mid.y
			var solid := sqrt(nx * nx + ny * ny) <= edge + 0.18 * _hash(c, r)
			prow.append(solid)
			if solid:
				_remaining += 1
				var shape := RectangleShape2D.new()
				shape.size = Vector2(CELL, CELL)
				var col := CollisionShape2D.new()
				col.shape = shape
				col.position = _center(c, r)
				_body.add_child(col)
				srow.append(col)
			else:
				srow.append(null)
		_present.append(prow)
		_shapes.append(srow)
	queue_redraw()

func _center(c: int, r: int) -> Vector2:
	return Vector2((float(c) + 0.5) * CELL, (float(r) + 0.5) * CELL)

func _hash(c: int, r: int) -> float:
	return fmod(absf(sin(float(c) * 12.9898 + float(r) * 78.233) * 43758.5453), 1.0)

func _draw() -> void:
	for r in rows:
		for c in cols:
			if not _present[r][c]:
				continue
			var p := _center(c, r) - Vector2(CELL, CELL) * 0.5
			# per-cell tonal variation (tone_a->tone_b), plus a dark grid edge for a chunky read
			var tone := tone_a.lerp(tone_b, 0.25 + 0.55 * _hash(c, r))
			draw_rect(Rect2(p, Vector2(CELL, CELL)), tone)
			draw_rect(Rect2(p, Vector2(CELL, CELL)), Color(Palette.INK, 0.5), false, 1.0)

## Carve every solid cell within `radius` of a world point, returning the count removed (0 = nothing
## there, so a blast source knows whether it connected). Called via the "blastable" group by the two
## things that break rubble — the turtle's shell-ram and the bubble bomb. `_power` reserved for later
## (multi-hit rubble that cracks before it clears).
func blast(world_pos: Vector2, radius: float, _power := 1.0) -> int:
	var local := to_local(world_pos)
	var removed := 0
	var center := Vector2.ZERO
	for r in rows:
		for c in cols:
			if not _present[r][c]:
				continue
			if _center(c, r).distance_to(local) <= radius:
				_present[r][c] = false
				(_shapes[r][c] as CollisionShape2D).set_deferred("disabled", true)  # open the path
				center += _center(c, r)
				removed += 1
	if removed == 0:
		return 0
	_remaining -= removed
	if _remaining <= 0 and not _emptied:
		_emptied = true
		cleared.emit()             # the cap is fully gone -> the vent beneath can open
	queue_redraw()
	_shatter(position + center / float(removed), removed)
	Sfx.play("break", -7.0)        # heavy stone smash (turtle ram / bubble bomb)
	return removed

## Chunky rock bits fly out of the carve, scaled to how much was removed.
func _shatter(cove_pos: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = clampi(amount, 5, 24)
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.position = cove_pos                 # added to our parent (cove frame)
	p.spread = 180.0
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0.0, 240.0)       # bits fall like debris
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Palette.STEEL               # on-palette rock grit
	p.z_index = 7
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
