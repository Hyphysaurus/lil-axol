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
const CHIP_EVERY := 0.10          # sustained close spray chips the rock every this many seconds
const CHIP_RADIUS := 7.0          # the jet carves a small spot; demolition blasts are far bigger

@export var cols := 12
@export var rows := 9
@export var edge := 0.92          # <1 rounds/erodes the outline into an irregular lump

var _present: Array = []          # rows×cols of bool — is this cell still solid?
var _shapes: Array = []           # rows×cols of CollisionShape2D (null where eroded at spawn)
var _body: StaticBody2D           # one body owns every cell's collision shape
var _chip_acc := 0.0              # accumulates close-spray time toward the next chip
var _remaining := 0              # solid cells still standing; when it hits 0, `cleared` fires
var _emptied := false

func _ready() -> void:
	add_to_group("blastable")
	add_to_group("sprayable")      # sustained spray also chips it (slow hand-mining)
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
			# on-palette rock with per-cell tonal variation, plus a dark grid edge for a chunky read
			var tone := Palette.SLATE.lerp(Palette.STEEL, 0.25 + 0.55 * _hash(c, r))
			draw_rect(Rect2(p, Vector2(CELL, CELL)), tone)
			draw_rect(Rect2(p, Vector2(CELL, CELL)), Color(Palette.INK, 0.5), false, 1.0)

## Carve every solid cell within `radius` of a world point. Called via the "blastable" group by
## blast sources (bubble bomb pop today; turtle demolition tomorrow). `_power` reserved for later
## (multi-hit rubble that cracks before it clears).
func blast(world_pos: Vector2, radius: float, _power := 1.0) -> int:
	return _carve(to_local(world_pos), radius, true)

## Sustained close spray slowly CHIPS the rock (hand-mining) — a friction-free way to break it,
## far slower than a demolition blast. Reaches us via the "sprayable" group like the oil does.
func spray_at(world_pos: Vector2, _radius: float, delta: float) -> void:
	var local := to_local(world_pos)
	if _nearest_solid_dist(local) > CHIP_RADIUS + CELL:   # the jet isn't on the rock
		_chip_acc = 0.0
		return
	_chip_acc += delta
	if _chip_acc >= CHIP_EVERY:
		_chip_acc = 0.0
		_carve(local, CHIP_RADIUS, false)

## Remove every solid cell within `radius` of a rock-local point. Returns the count removed (0 =
## nothing there) so a blast source (the turtle) knows whether it connected. `is_blast` picks the
## demolition boom vs the softer chip scrape.
func _carve(local: Vector2, radius: float, is_blast: bool) -> int:
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
	if is_blast:
		Sfx.play("break", -7.0)            # heavy stone smash (turtle ram / bubble bomb)
	else:
		Sfx.play("scrub", -12.0, 0.7)      # a rocky scrape as the jet chips
	return removed

func _nearest_solid_dist(local: Vector2) -> float:
	var best := INF
	for r in rows:
		for c in cols:
			if _present[r][c]:
				best = minf(best, _center(c, r).distance_to(local))
	return best

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
