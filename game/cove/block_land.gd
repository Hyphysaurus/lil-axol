extends Node2D
class_name BlockLand
## Chunky block-tile land (Apollo loam) that replaces the smooth Sand/Grass sprites and GROWS grass
## as the cove heals — barren oil-stained soil at 0% restoration, lush at 100%. Self-wires to the
## oil_manager cleanliness signal (banner idiom — purely visual, touches no gameplay), so the Beach
## collision + the ShorePollution oil splats keep working on top of it.
##
## PERF: the soil is ONE shader quad (block_land.gdshader), not thousands of draw_rects — only the
## `oil` uniform changes at runtime, so re-tinting as you clean costs a single cheap draw call. The
## grass is a light procedural layer (a few dozen tapered blades) drawn on top.

const CELL := 8.0
const EASE := 0.3               # restoration eases in a beat behind the water (matches ShoreHealth)
const SOIL_SHADER := preload("res://shaders/block_land.gdshader")
const WHITE := preload("res://assets/white.png")

@export var cols := 32          # 32*8 = 256 ≈ the 252-wide beach
@export var rows := 35          # 35*8 = 280 = the beach height
@export var surface_row := 3    # rows above this are dry warm loam; at/below reads submerged & darker

var _clean := 0.0               # 0 oil-stained .. 1 restored (eased a beat behind cleanliness)
var _target := 0.0
var _soil_mat: ShaderMaterial
var _grass: GrassLayer
var _pollen: CPUParticles2D

func _ready() -> void:
	z_index = 1                 # above the water backdrop, below the axolotl + oil splats (z 2)
	# soil — a single shader quad (white 1x1 texture scaled to the land size, UV 0..1)
	_soil_mat = ShaderMaterial.new()
	_soil_mat.shader = SOIL_SHADER
	_soil_mat.set_shader_parameter("grid", Vector2(cols, rows))
	_soil_mat.set_shader_parameter("surface_row", float(surface_row))
	_soil_mat.set_shader_parameter("oil", 1.0)
	var soil := Sprite2D.new()
	soil.texture = WHITE
	soil.material = _soil_mat
	soil.centered = false
	soil.scale = Vector2(float(cols) * CELL, float(rows) * CELL)
	add_child(soil)
	# grass + drifting pollen on top
	_grass = GrassLayer.new()
	_grass.cols = cols
	add_child(_grass)
	_pollen = _make_pollen()
	add_child(_pollen)
	_hook.call_deferred()       # deferred so the oil manager is in its group by the time we look

func _hook() -> void:
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(func(v: float) -> void: _target = v)
	if mgr and "current_clean" in mgr:
		_target = mgr.current_clean
		_clean = _target
	_apply()

func _process(delta: float) -> void:
	if not is_equal_approx(_clean, _target):
		_clean = move_toward(_clean, _target, delta * EASE)
		_apply()
	_grass.tick(delta)          # grass always sways (cheap — a few dozen blades)
	_pollen.emitting = _clean > 0.75   # drifting spores only over lush grass

func _apply() -> void:
	_soil_mat.set_shader_parameter("oil", 1.0 - _clean)
	_grass.clean = _clean

## Drifting pollen/spores over the grass once the shore is lush — a soft ambient life cue.
func _make_pollen() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = 14
	p.lifetime = 4.0
	p.position = Vector2(float(cols) * CELL * 0.5, -6.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(float(cols) * CELL * 0.5, 6.0)
	p.direction = Vector2(0.25, -1.0)
	p.gravity = Vector2(4.0, -5.0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.7
	p.color = Color(Palette.SPROUT, 0.5)
	p.z_index = 3
	return p

## Polished procedural grass along the land's top edge. Each top cell greens at its own restoration
## threshold (the shore fills in gradually), then blades grow taller/greener and flower. Drawn as
## tapered two-tone tufts in a back+front layer (for depth), bending together in a field-wide wind
## wave. Only a few dozen blades, so a per-frame redraw for the sway is cheap.
class GrassLayer extends Node2D:
	var cols := 32
	var clean := 0.0
	var _t := 0.0

	func tick(delta: float) -> void:
		_t += delta
		if clean > 0.10:
			queue_redraw()

	func _hash(a: int, b: int) -> float:
		return fmod(absf(sin(float(a) * 12.9898 + float(b) * 47.11) * 43758.5453), 1.0)

	func _draw() -> void:
		if clean <= 0.10:
			return
		_layer(Palette.MOSS, Palette.GREEN, 0.8, false)     # back — shorter, darker, for depth
		_layer(Palette.GREEN, Palette.LEAF, 1.0, true)      # front — full, lighter, flowers

	func _layer(base_c: Color, tip_c: Color, hscale: float, front: bool) -> void:
		for c in cols:
			var seed := _hash(c, 1)
			var thresh := 0.10 + seed * 0.5                 # cells green progressively as it heals
			if clean < thresh:
				continue
			var grow := clampf((clean - thresh) / (1.0 - thresh), 0.0, 1.0)
			var cx := (float(c) + 0.5) * 8.0
			var tufts := 2 + int(seed * 2.0)                # 2-3 blades per cell
			for b in tufts:
				var bx := cx + (float(b) - float(tufts - 1) * 0.5) * 2.4
				var h := (5.0 + 9.0 * grow) * hscale * (0.7 + 0.5 * _hash(c, b + 3))
				var wind := sin(_t * 1.8 + bx * 0.14) * (1.5 + 3.5 * grow)   # field-wide wave
				var w := 1.5 * (0.65 + 0.5 * grow)
				var tip := Vector2(bx + wind, -h)
				draw_polygon(
					PackedVector2Array([Vector2(bx - w, 0.0), Vector2(bx + w, 0.0), tip]),
					PackedColorArray([base_c, base_c, tip_c]))
			if front and grow > 0.8 and seed > 0.45:
				var fx := cx + sin(_t * 1.8 + cx * 0.14) * 3.0
				_flower(Vector2(fx, -(5.0 + 9.0 * grow) - 1.0), c)

	## A tiny five-petal bloom on the lushest tufts.
	func _flower(pos: Vector2, c: int) -> void:
		var petal: Color = Palette.BLOSSOM if _hash(c, 9) > 0.5 else Palette.GOLD
		for i in 5:
			draw_circle(pos + Vector2.from_angle(TAU * float(i) / 5.0) * 1.6, 1.0, petal)
		draw_circle(pos, 1.0, Palette.AMBER)
