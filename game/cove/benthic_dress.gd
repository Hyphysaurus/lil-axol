extends Node2D
## Benthic dressing (2026-07-24 looks pass — Maram: "the tank levels need help, especially the
## bottom areas"): eelgrass tufts, pebble clusters, pale accents, and a depth-darkening wash
## seeded along the reach's REAL floor. Reads ReachField.floor_y_at, so one component dresses
## the rect "tanks" (hub/estuary, flat seabed) and the painted canals (varying floors) alike.
## Static one-shot _draw, seeded per reach id — the dressing never pops or reshuffles. Sits at
## z 2: over the reef band (1), under fish/water (4/5); the land quad (7) covers it on earth.

const MURKY := Color(0.42, 0.5, 0.55)   # oil-dimmed until cleaned (same idiom as SeabedBackdrop)

var _cfg: CoveConfig
var _field: ReachField
var _clean := 0.0
var _life := 0.0

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_field = get_tree().get_first_node_in_group("reach_field")
	z_index = 2
	modulate = MURKY
	var mgr = get_tree().get_first_node_in_group("oil_manager")   # untyped: dynamic access
	if mgr:
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(func(v: float) -> void: _clean = v)
		if "current_clean" in mgr:
			_clean = mgr.current_clean
	queue_redraw()

func _process(delta: float) -> void:
	# the bottom BLOOMS as the water heals — eases in step with the reef band's reveal
	if is_equal_approx(_life, _clean):
		return
	_life = move_toward(_life, _clean, delta * 0.5)
	modulate = MURKY.lerp(Color.WHITE, _life)

func _draw() -> void:
	if _cfg == null or _field == null:
		return
	var wb := _field.water_bounds()
	if wb.size.x <= 0.0:
		return
	var surf := _field.surface_y()
	# DEPTH WASH: three widening DEEP/ABYSS bands — the bottom reads deeper than the shallows
	var top := surf + 30.0
	var bottom := wb.end.y
	if bottom > top:
		var span := bottom - top
		draw_rect(Rect2(wb.position.x, top, wb.size.x, span), Color(Palette.DEEP, 0.07))
		draw_rect(Rect2(wb.position.x, top + span * 0.45, wb.size.x, span * 0.55), Color(Palette.DEEP, 0.10))
		draw_rect(Rect2(wb.position.x, top + span * 0.75, wb.size.x, span * 0.25), Color(Palette.ABYSS, 0.12))
	# FLOOR SCATTER, seeded stable per reach id
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_cfg.id)
	var x := wb.position.x + 10.0
	while x < wb.end.x - 10.0:
		x += 10.0 + rng.randf() * 10.0
		var fy := _field.floor_y_at(x)
		if fy <= surf + 8.0 or fy > wb.end.y + 4.0:
			continue          # no submerged floor in this column (bank, mouth, out of water)
		if not _field.is_water(Vector2(x, fy - 5.0)):
			continue
		var roll := rng.randf()
		if roll < 0.38:
			_tuft(rng, Vector2(x, fy))
		elif roll < 0.62:
			_pebbles(rng, Vector2(x, fy))
		elif roll < 0.72:
			_sprout(rng, Vector2(x, fy))

## 2-4 bending eelgrass blades — MOSS/GREEN stems, a FERN tip catching the light.
func _tuft(rng: RandomNumberGenerator, at: Vector2) -> void:
	var blades := 2 + rng.randi_range(0, 2)
	for b in blades:
		var h := 9.0 + rng.randf() * 16.0
		var bx := at.x + float(b) * 3.0 - float(blades)
		var bend := (rng.randf() - 0.5) * 5.0
		var stem := Color(Palette.GREEN if rng.randf() < 0.6 else Palette.FERN)
		draw_polyline(PackedVector2Array([
			Vector2(bx, at.y),
			Vector2(bx + bend * 0.4, at.y - h * 0.55),
			Vector2(bx + bend, at.y - h),
		]), stem, 2.0)
		draw_rect(Rect2(bx + bend - 1.0, at.y - h - 2.0, 2.0, 2.0), Color(Palette.LEAF))

## 1-3 low stones snugged into the floor line.
func _pebbles(rng: RandomNumberGenerator, at: Vector2) -> void:
	var n := 1 + rng.randi_range(0, 2)
	var px := at.x
	for i in n:
		var w := 3.0 + rng.randf() * 4.0
		var h := 2.0 + rng.randf() * 2.5
		var tones := [Palette.STEEL, Palette.MIST, Palette.SLATE, Palette.CLAY]
		draw_rect(Rect2(px, at.y - h, w, h), Color(tones[rng.randi_range(0, 3)], 0.95))
		px += w + 1.0

## A tiny pale accent — a shell or a new sprout catching what light reaches the bottom.
func _sprout(rng: RandomNumberGenerator, at: Vector2) -> void:
	var tone = Palette.SPROUT if rng.randf() < 0.6 else Palette.BLOSSOM
	draw_rect(Rect2(at.x, at.y - 2.0, 2.0, 2.0), Color(tone, 0.9))
	draw_rect(Rect2(at.x + 1.0, at.y - 3.0, 1.0, 1.0), Color(tone, 0.7))
