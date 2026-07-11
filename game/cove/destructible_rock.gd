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
signal carved(world_pos: Vector2, radius: float)   # a bite landed (ReachField flips cells to water)

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
## A subtle diegetic "this is breakable" aura — a slow pulse in the rock's own colour. Off for
## anything you'd rather not advertise.
@export var breakable_glow := true
## A TEASED gate (silt/boulder seal — slice 5): blast() bounces off with a dull thunk + a
## tone-coloured shimmer instead of carving. The world says "not yet", never "no" (cozy) — slice 6
## unlocks specific gates by kind. Default false so every existing rock (rubble, vent caps, land
## nooks) keeps blasting exactly as before.
@export var locked := false

var _present: Array = []          # rows×cols of bool — is this cell still solid?
var _shapes: Array = []           # rows×cols of CollisionShape2D (null where eroded at spawn)
var _body: StaticBody2D           # one body owns every cell's collision shape
var _remaining := 0              # solid cells still standing; when it hits 0, `cleared` fires
var _emptied := false
var _glow_t := 0.0               # drives the breakable aura's slow pulse
var _redraw_acc := 0.0           # throttles the pulse redraw to ~10 Hz
var _scars: Array = []           # [local cell centre, age] — fresh-break craters, fading ~1.2s
var _lock_tween: Tween           # guards against stacking tweens on rapid blasts
const SCAR_LIFE := 1.2

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

func _process(delta: float) -> void:
	var shimmer := breakable_glow and _remaining > 0
	if not shimmer and _scars.is_empty():
		return
	_glow_t += delta
	for s in _scars:
		s[1] += delta
	while not _scars.is_empty() and _scars[0][1] > SCAR_LIFE:   # appended in order — oldest first
		_scars.pop_front()
	# WEB PERF: canvas-item rebuilds are the expensive part on WebGL, and every intact rock runs
	# this loop. The slow mineral shimmer only needs ~8Hz; the brief scar fades get 20Hz while
	# any are alive, then the rock settles back to the cheap cadence.
	_redraw_acc += delta
	var period := 0.05 if not _scars.is_empty() else 0.125
	if _redraw_acc >= period:
		_redraw_acc = 0.0
		queue_redraw()

func _draw() -> void:
	# fresh-break craters: each carved cell leaves a dark bitten-out recess that fades over a second —
	# a bite visibly TAKEN out of the world, instead of rubble evaporating against a clean background
	for s in _scars:
		var sa: float = 0.38 * (1.0 - s[1] / SCAR_LIFE)
		draw_rect(Rect2(s[0] - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), Color(Palette.INK, sa))
	# breakable shimmer: a scatter of cells gently "catch the light" on a slow pulse — each shimmer
	# cell brightens at its own phase, so loose rock glints like mineral seams (diegetic, no blob)
	var pz := sin(_glow_t * 2.0)
	for r in rows:
		for c in cols:
			if not _present[r][c]:
				continue
			var p := _center(c, r) - Vector2(CELL, CELL) * 0.5
			var j := _hash(c, r)
			# per-cell tone + value mottling so no cell is a flat fill (grain like the block-land)
			var tone := tone_a.lerp(tone_b, 0.2 + 0.6 * j)
			var m := _hash(r * 3 + 7, c * 5 + 2)
			if m > 0.62:
				tone = tone.darkened(0.16)
			elif m < 0.3:
				tone = tone.lightened(0.12)
			if breakable_glow and j > 0.68:   # ~1/3 of cells shimmer, each at its own phase
				var tw := 0.5 + 0.5 * sin(_glow_t * 2.0 + j * TAU + pz)
				tone = tone.lightened(0.10 * tw)
			draw_rect(Rect2(p, Vector2(CELL, CELL)), tone)
			# a SOFT seam tinted to the material (warm loam / cool stone), not a harsh near-black grid
			draw_rect(Rect2(p, Vector2(CELL, CELL)), Color(tone_a.darkened(0.35), 0.28), false, 1.0)
			# scattered grit specks for texture
			var s := _hash(r * 11 + 3, c * 2 + 9)
			if s > 0.72:
				var speck: Color = tone.darkened(0.28) if s > 0.86 else tone.lightened(0.3)
				draw_rect(Rect2(p + Vector2(1.5 + s * 3.5, 1.5 + j * 3.5), Vector2(2.0, 2.0)), Color(speck, 0.7))

## Carve every solid cell within `radius` of a world point, returning the count removed (0 = nothing
## there, so a blast source knows whether it connected). Called via the "blastable" group by the two
## things that break rubble — the turtle's shell-ram and the bubble bomb. `_power` reserved for later
## (multi-hit rubble that cracks before it clears).
func blast(world_pos: Vector2, radius: float, _power := 1.0, quiet := false) -> int:
	if locked:
		# reuse "land" (a soft footfall thud) pitched down for a dull bounce — there's no dedicated
		# "blocked" SFX bank yet, and "break"/"explode" both read as destruction, which a locked
		# gate must never imply.
		Sfx.play("land", -12.0, 0.8)
		_flash_locked()
		return 0
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
				if _scars.size() < 140:
					_scars.append([_center(c, r), 0.0])   # a fading crater where the cell was
	if removed == 0:
		return 0
	_remaining -= removed
	carved.emit(world_pos, radius)   # once per landed bite — a seal listens to carve its water cells
	if _remaining <= 0 and not _emptied:
		_emptied = true
		cleared.emit()             # the cap is fully gone -> the vent beneath can open
	queue_redraw()
	_shatter(position + center / float(removed), removed)
	if not quiet:                  # the shell-spin carves continuously and plays its own grind loop
		Sfx.play("break", -7.0)    # heavy stone smash (bubble bomb / a single ram)
	return removed

## A brief tone-coloured shimmer for a locked gate's "not yet" bounce: modulate flashes toward the
## rock's own tone_a and eases back over 0.2s — the same "catch the light" language as the
## breakable shimmer in _draw(), just a one-shot pulse instead of the idle mineral glint.
func _flash_locked() -> void:
	if _lock_tween and _lock_tween.is_running():
		_lock_tween.kill()
	_lock_tween = create_tween()
	_lock_tween.tween_property(self, "modulate", tone_a, 0.1)
	_lock_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

## Is any still-solid cell within `radius` of a world point? A cheap, NON-destructive contact test
## the turtle uses to start bashing on FIRST CONTACT instead of dashing to a mark aimed deep inside.
func has_solid_within(world: Vector2, radius: float) -> bool:
	var local := to_local(world)
	for r in rows:
		for c in cols:
			if _present[r][c] and _center(c, r).distance_to(local) <= radius:
				return true
	return false

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
