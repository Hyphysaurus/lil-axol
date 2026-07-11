extends Node2D
## Oil spill — paint-to-clean. The spill is a coverage mask (Image) over the water surface,
## rendered as an iridescent oil FILM (oil_surface.gdshader) that sits IN the water rather than
## on top of it. Spraying erodes the mask exactly where the axo aims; clean water + the sky
## reflection bloom through wherever you've scrubbed. Overall cleanliness (1 - remaining
## coverage) still drives the global water tint, CoveLife, and the restoration banner via the
## `cleanliness` signal. Visual juice (sparkle trail, milestone bursts) is delegated to CleanupFX.

signal cleanliness(v: float)   # 0 oily -> 1 restored
signal scrubbed(frac: float, world_pos: Vector2)   # oil actually removed (frac of the whole spill)

const OIL_SURFACE_SHADER := preload("res://shaders/oil_surface.gdshader")
const WHITE := preload("res://assets/white.png")

const MASK_W := 192
const MASK_H := 88
const MILESTONES := [0.25, 0.5, 0.75, 1.0]   # escalating burst reward as the cove recovers
# The film shader renders nothing below ~0.28 coverage (minus up to 0.15 of edge noise), so
# progress is counted in VISIBLE oil: what the player can't possibly see can't block 100%.
const VIS_FLOOR := 0.13      # provably invisible below this, even at max noise
const VIS_FULL := 0.42       # solidly-visible film on average
const CHIME_STEPS := [1.0, 1.125, 1.25]      # major-pentatonic rise; the 1.0 milestone is the
                                             # win stinger's moment, so it gets no chime

var _cfg: CoveConfig
var _fx: CleanupFX
var _water_mat: ShaderMaterial
var _mask: Image                      # 8-bit view for the shader ONLY — never do math on it
var _cov: PackedFloat32Array          # source of truth: float coverage per cell (no
                                      # quantization drift — 8-bit truncation was silently
                                      # leaking ~4% of progress and capping cleanliness)
var _cov0: PackedFloat32Array         # the level's starting coverage — a hard cap the leak
                                      # can re-oil toward but never exceed (D-0005)
var _mask_tex: ImageTexture
var _surface: Sprite2D
var _origin := Vector2.ZERO   # water rect top-left (cove-local)
var _size := Vector2.ONE      # water rect size (px)
var _total := 0.001           # initial summed coverage (denominator for cleanliness)
var _remaining := 0.0
var _milestone := 0
var current_clean := 0.0
var _spark_cd := 0.0
var _scrub_snd_cd := 0.0       # slower than _spark_cd so the pops tick, not machine-gun
# The mask Image is edited every frame you spray (or while the leak trickles), but re-uploading the
# whole 192x88 texture to the GPU every frame is a heavy web/GL cost. We mark it dirty and flush ONE
# upload at ~30Hz — visually identical (≤33ms latency on the film), and it coalesces to zero uploads
# whenever the mask isn't changing (e.g. an uncapped leak that isn't currently re-oiling a cell).
var _mask_dirty := false
var _upload_cd := 0.0
const MASK_UPLOAD_HZ := 30.0

func _ready() -> void:
	add_to_group("oil_manager")
	_fx = CleanupFX.new()
	add_child(_fx)

## Called by the Cove composition root after _ready; the config-dependent build lives here.
## The Water-rect read moves here from _ready (spec C1) — _ready runs before a mapped reach's
## ReachMap can resize the water sprite, which would capture a stale origin/size.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	var wt := get_node_or_null("../Water") as Sprite2D
	if wt:
		_water_mat = wt.material as ShaderMaterial
		_origin = wt.position
		_size = wt.scale          # 1px texture scaled to px size -> scale == size
	_build_mask()
	_build_surface()
	_set_clean()

func _build_mask() -> void:
	_mask = Image.create_empty(MASK_W, MASK_H, false, Image.FORMAT_RGBA8)
	_cov.resize(MASK_W * MASK_H)
	var surf := _cfg.surface_y
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")   # one lookup, not 16,896
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
			# thickness ramps toward the source (the leaking barrel on the shore, at spill_left):
			# thick sludge by the source, thinning to sheen at the far edge — clear the easy
			# edges, work inward toward the stubborn core
			var ramp := 1.0 - smoothstep(_cfg.spill_left, _cfg.spill_right, lx)
			var cov := clampf(in_x * in_y * (0.30 + 0.30 * blot + 0.55 * ramp), 0.0, 1.0)
			if cov < VIS_FLOOR:
				cov = 0.0                   # don't birth oil nobody can ever see
			elif field != null and not field.oil_allowed(Vector2(lx, ly)):
				cov = 0.0                   # no oil born inside painted terrain (spec C2)
			_cov[my * MASK_W + mx] = cov
			_mask.set_pixel(mx, my, Color(cov, 0.0, 0.0, 1.0))
			_total += _vis(cov)
	_total = maxf(_total, 0.001)
	_remaining = _total
	_cov0 = _cov.duplicate()             # remember the start as the leak's re-oil ceiling
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
			var old := _cov[my * MASK_W + mx]
			if old <= 0.0:
				continue
			# thick sludge sheds slower than thin sheen — the dark core needs sustained,
			# close-range spray to break, not just repeat passes (D-0006: sludge = skill)
			var resist := 1.0 - 0.55 * smoothstep(0.55, 0.95, old)
			var nr := maxf(0.0, old - strength * (1.0 - d / rpx) * resist)   # soft brush falloff
			if nr < VIS_FLOOR:
				nr = 0.0                    # sub-visible residue snaps clean (renders as nothing)
			removed += _vis(old) - _vis(nr)
			_cov[my * MASK_W + mx] = nr
			_mask.set_pixel(mx, my, Color(nr, 0.0, 0.0, 1.0))
	if removed > 0.0:
		_mask_dirty = true                       # batch the GPU upload (flushed in _process)
		_remaining = maxf(0.0, _remaining - removed)
		_set_clean()
		scrubbed.emit(removed / _total, to_global(p))   # Shine and friends key off real progress
		_spark_cd -= delta
		if _spark_cd <= 0.0:                    # local sparkle trail while actively scrubbing
			_spark_cd = 0.05
			_fx.spark(p)
		_scrub_snd_cd -= delta
		if _scrub_snd_cd <= 0.0:                # audible bite only while oil actually comes off:
			_scrub_snd_cd = 0.12                # spraying clean water stays silent by construction
			Sfx.play("scrub", 0.0, 0.9 + current_clean * 0.4)
		if _milestone < MILESTONES.size() and current_clean >= float(MILESTONES[_milestone]):
			_milestone += 1                     # escalating burst as the cove recovers
			_fx.pop(p)
			if _milestone <= CHIME_STEPS.size():
				# whimsy chimes rising one pentatonic step per milestone (cohesive reward palette)
				Sfx.play("whimsy", -2.0, CHIME_STEPS[_milestone - 1])

## Fresh oil trickling back from an uncapped leak. Adds coverage toward each cell's ORIGINAL
## value — a hard cap, so oil resists but never grows past the level's start (D-0005). Gentle
## by design: ignore the leak and the spill just stays lively near the source a bit longer.
func stain_at(world_pos: Vector2, radius: float, amount: float) -> void:
	if _mask == null:
		return
	var p := to_local(world_pos)
	var cx := (p.x - _origin.x) / _size.x * float(MASK_W)
	var cy := (p.y - _origin.y) / _size.y * float(MASK_H)
	var rpx := maxf(3.0, radius / _size.x * float(MASK_W))
	var added := 0.0
	var x0 := int(maxf(0.0, floor(cx - rpx)))
	var x1 := int(minf(float(MASK_W - 1), ceil(cx + rpx)))
	var y0 := int(maxf(0.0, floor(cy - rpx)))
	var y1 := int(minf(float(MASK_H - 1), ceil(cy + rpx)))
	for my in range(y0, y1 + 1):
		for mx in range(x0, x1 + 1):
			var i := my * MASK_W + mx
			var cap := _cov0[i]
			if cap <= 0.0:
				continue                    # never oil where the level had none
			var d := Vector2(float(mx) - cx, float(my) - cy).length()
			if d > rpx:
				continue
			var old := _cov[i]
			if old >= cap:
				continue
			var nr := minf(cap, old + amount * (1.0 - d / rpx))
			added += _vis(nr) - _vis(old)
			_cov[i] = nr
			_mask.set_pixel(mx, my, Color(nr, 0.0, 0.0, 1.0))
	if added > 0.0:
		_mask_dirty = true                       # batch the GPU upload (flushed in _process)
		_remaining = minf(_total, _remaining + added)
		_set_clean()

## Flush the batched mask changes to the GPU at most MASK_UPLOAD_HZ times/sec. The Image itself is
## already current (spray_at/stain_at edited it this frame); this only paces the texture upload.
func _process(delta: float) -> void:
	if not _mask_dirty:
		return
	_upload_cd -= delta
	if _upload_cd > 0.0:
		return
	_upload_cd = 1.0 / MASK_UPLOAD_HZ
	_mask_dirty = false
	_mask_tex.update(_mask)

## Oil coverage (0..1) at a world position — used by the axolotl to sludge its movement in oil.
func oil_at(world_pos: Vector2) -> float:
	if _mask == null:
		return 0.0
	var p := to_local(world_pos)
	var mx := int((p.x - _origin.x) / _size.x * float(MASK_W))
	var my := int((p.y - _origin.y) / _size.y * float(MASK_H))
	if mx < 0 or mx >= MASK_W or my < 0 or my >= MASK_H:
		return 0.0
	return _cov[my * MASK_W + mx]

## Jump the whole spill to a cleanliness fraction (0 = untouched, 1 = fully clean) — the
## persistence spawn path (WorldState). Scales every cell uniformly; the visibility floor
## applies, so thin residue snaps clean exactly as scrubbing would. Recomputes the milestone
## cursor so re-seeded progress doesn't replay milestone bursts/chimes.
func set_clean_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if _mask == null or f <= 0.0:
		return
	var keep := 1.0 - f
	_remaining = 0.0
	for my in MASK_H:
		for mx in MASK_W:
			var i := my * MASK_W + mx
			var nr := _cov[i] * keep
			if nr < VIS_FLOOR:
				nr = 0.0
			_cov[i] = nr
			_mask.set_pixel(mx, my, Color(nr, 0.0, 0.0, 1.0))
			_remaining += _vis(nr)
	_mask_tex.update(_mask)
	_set_clean()
	_milestone = 0
	for m in MILESTONES:
		if current_clean >= float(m):
			_milestone += 1

## Progress weight of a coverage value — matches the film shader's visibility ramp, so the
## meter and the win can never demand oil the player cannot find. Raw coverage (oil_at)
## stays untouched for the debuff and the ecosystem reveal.
func _vis(c: float) -> float:
	return clampf((c - VIS_FLOOR) / (VIS_FULL - VIS_FLOOR), 0.0, 1.0)

func _set_clean() -> void:
	current_clean = clampf(1.0 - _remaining / _total, 0.0, 1.0)
	if _water_mat:
		_water_mat.set_shader_parameter("clean", current_clean)
	cleanliness.emit(current_clean)   # water tint + CoveLife + banner heal in step
