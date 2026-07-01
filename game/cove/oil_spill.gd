extends Node2D
## Oil spill — paint-to-clean. The spill is a coverage mask (Image) over the water surface,
## rendered as an iridescent oil FILM (oil_surface.gdshader) that sits IN the water rather than
## on top of it. Spraying erodes the mask exactly where the axo aims; clean water + the sky
## reflection bloom through wherever you've scrubbed. Overall cleanliness (1 - remaining
## coverage) still drives the global water tint, CoveLife, and the restoration banner via the
## `cleanliness` signal. Visual juice (sparkle trail, milestone bursts) is delegated to CleanupFX.

signal cleanliness(v: float)   # 0 oily -> 1 restored

const OIL_SURFACE_SHADER := preload("res://shaders/oil_surface.gdshader")
const WHITE := preload("res://assets/white.png")

const MASK_W := 192
const MASK_H := 88
const MILESTONES := [0.25, 0.5, 0.75, 1.0]   # escalating burst reward as the cove recovers

var _cfg: CoveConfig
var _fx: CleanupFX
var _water_mat: ShaderMaterial
var _mask: Image
var _mask_tex: ImageTexture
var _surface: Sprite2D
var _origin := Vector2.ZERO   # water rect top-left (cove-local)
var _size := Vector2.ONE      # water rect size (px)
var _total := 0.001           # initial summed coverage (denominator for cleanliness)
var _remaining := 0.0
var _milestone := 0
var current_clean := 0.0
var _spark_cd := 0.0

func _ready() -> void:
	add_to_group("oil_manager")
	var wt := get_node_or_null("../Water") as Sprite2D
	if wt:
		_water_mat = wt.material as ShaderMaterial
		_origin = wt.position
		_size = wt.scale          # the water sprite is a 1px texture scaled to px size -> scale == size
	_fx = CleanupFX.new()
	add_child(_fx)

## Called by the Cove composition root after _ready; the config-dependent build lives here.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_build_mask()
	_build_surface()
	_set_clean()

func _build_mask() -> void:
	_mask = Image.create_empty(MASK_W, MASK_H, false, Image.FORMAT_RGBA8)
	var surf := _cfg.surface_y
	_total = 0.0
	for my in MASK_H:
		for mx in MASK_W:
			var uvx := (float(mx) + 0.5) / float(MASK_W)
			var uvy := (float(my) + 0.5) / float(MASK_H)
			var lx := _origin.x + uvx * _size.x       # cove-local px of this mask cell
			var ly := _origin.y + uvy * _size.y
			# inside the spill's horizontal span, with soft shoulders
			var in_x := smoothstep(_cfg.spill_left - 34.0, _cfg.spill_left + 12.0, lx) \
				* (1.0 - smoothstep(_cfg.spill_right - 12.0, _cfg.spill_right + 34.0, lx))
			# hugging the surface: a band from just below the waterline down ~65px
			var in_y := smoothstep(surf - 4.0, surf + 8.0, ly) \
				* (1.0 - smoothstep(surf + 52.0, surf + 82.0, ly))
			# blotchy thickness so the slick isn't a flat slab
			var blot := 0.5 + 0.5 * sin(lx * 0.07 + ly * 0.05) * cos(lx * 0.03 - ly * 0.11)
			var cov := clampf(in_x * in_y * (0.62 + 0.38 * blot), 0.0, 1.0)
			_mask.set_pixel(mx, my, Color(cov, 0.0, 0.0, 1.0))
			_total += cov
	_total = maxf(_total, 0.001)
	_remaining = _total
	_mask_tex = ImageTexture.create_from_image(_mask)

func _build_surface() -> void:
	_surface = Sprite2D.new()
	_surface.texture = WHITE
	_surface.centered = false
	_surface.position = _origin
	_surface.scale = _size
	_surface.z_index = 6                       # in the water surface (water is z 5), under FX (z 7)
	var mat := ShaderMaterial.new()
	mat.shader = OIL_SURFACE_SHADER
	mat.set_shader_parameter("coverage", _mask_tex)
	_surface.material = mat
	add_child(_surface)

# called by the axolotl (via group) each frame the spray is held
func spray_at(world_pos: Vector2, radius: float, delta: float) -> void:
	if _mask == null:
		return
	var p := to_local(world_pos)               # OilSpill sits at the cove origin -> cove-local
	var cx := (p.x - _origin.x) / _size.x * float(MASK_W)
	var cy := (p.y - _origin.y) / _size.y * float(MASK_H)
	var rpx := maxf(3.0, radius / _size.x * float(MASK_W))
	var strength := _cfg.clean_rate * delta
	var removed := 0.0
	var x0 := int(maxf(0.0, floor(cx - rpx)))
	var x1 := int(minf(float(MASK_W - 1), ceil(cx + rpx)))
	var y0 := int(maxf(0.0, floor(cy - rpx)))
	var y1 := int(minf(float(MASK_H - 1), ceil(cy + rpx)))
	for my in range(y0, y1 + 1):
		for mx in range(x0, x1 + 1):
			var d := Vector2(float(mx) - cx, float(my) - cy).length()
			if d > rpx:
				continue
			var col := _mask.get_pixel(mx, my)
			if col.r <= 0.0:
				continue
			var nr := maxf(0.0, col.r - strength * (1.0 - d / rpx))   # soft brush falloff
			removed += col.r - nr
			col.r = nr
			_mask.set_pixel(mx, my, col)
	if removed > 0.0:
		_mask_tex.update(_mask)
		_remaining = maxf(0.0, _remaining - removed)
		_set_clean()
		_spark_cd -= delta
		if _spark_cd <= 0.0:                    # local sparkle trail while actively scrubbing
			_spark_cd = 0.05
			_fx.spark(p)
		if _milestone < MILESTONES.size() and current_clean >= float(MILESTONES[_milestone]):
			_milestone += 1                     # escalating burst as the cove recovers
			_fx.pop(p)

## Oil coverage (0..1) at a world position — used by the axolotl to sludge its movement in oil.
func oil_at(world_pos: Vector2) -> float:
	if _mask == null:
		return 0.0
	var p := to_local(world_pos)
	var mx := int((p.x - _origin.x) / _size.x * float(MASK_W))
	var my := int((p.y - _origin.y) / _size.y * float(MASK_H))
	if mx < 0 or mx >= MASK_W or my < 0 or my >= MASK_H:
		return 0.0
	return _mask.get_pixel(mx, my).r

func _set_clean() -> void:
	current_clean = clampf(1.0 - _remaining / _total, 0.0, 1.0)
	if _water_mat:
		_water_mat.set_shader_parameter("clean", current_clean)
	cleanliness.emit(current_clean)   # water tint + CoveLife + banner heal in step
