extends Node2D
## Oil spill manager (simulation). Spawns floating oil blobs on the cove water, lets the
## axolotl spray them clean, and drives the Water shader's `clean` uniform (0 oily -> 1
## restored) so the whole cove — colour + sky reflection — heals as the spill clears.
## Geometry + tuning come from the injected CoveConfig; visual juice is delegated to CleanupFX.

signal cleanliness(v: float)   # 0 oily -> 1 restored; emitted whenever the spill state changes

const OIL_SHADER := preload("res://shaders/oil.gdshader")
const WHITE := preload("res://assets/white.png")

var _cfg: CoveConfig
var _fx: CleanupFX
var _blobs: Array = []
var _water_mat: ShaderMaterial
var _total := 0.0
var current_clean := 0.0
var _spark_cd := 0.0

func _ready() -> void:
	add_to_group("oil_manager")
	var wt := get_node_or_null("../Water")
	if wt:
		_water_mat = (wt as Sprite2D).material as ShaderMaterial
	_fx = CleanupFX.new()
	add_child(_fx)   # child at origin -> shares OilSpill's cove-local frame

## Called by the Cove composition root after _ready; the config-dependent spawn lives here.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_spawn()
	_update_water()

func _spawn() -> void:
	for i in _cfg.blob_count:
		var fx := float(i) / float(maxi(_cfg.blob_count - 1, 1))
		var x := lerpf(_cfg.spill_left, _cfg.spill_right, fx) + sin(float(i) * 12.9) * 16.0
		var y := _cfg.surface_y - 2.0 + cos(float(i) * 7.3) * 9.0
		var sz := 32.0 + float((i * 37) % 22)
		var s := Sprite2D.new()
		s.texture = WHITE
		s.centered = true
		s.scale = Vector2(sz * 1.5, sz)
		s.position = Vector2(x, y)
		s.z_index = 6                         # above the water (z 5)
		var mat := ShaderMaterial.new()
		mat.shader = OIL_SHADER
		s.material = mat
		add_child(s)
		_blobs.append({ "node": s, "mat": mat, "amount": 1.0, "pos": Vector2(x, y) })
		_total += 1.0

# called by the axolotl (via group) each frame the spray is held
func spray_at(world_pos: Vector2, radius: float, delta: float) -> void:
	var p := to_local(world_pos)
	var changed := false
	_spark_cd -= delta
	for b in _blobs:
		if float(b["amount"]) <= 0.0:
			continue
		if (b["pos"] as Vector2).distance_to(p) <= radius:
			b["amount"] = maxf(0.0, float(b["amount"]) - _cfg.clean_rate * delta)
			(b["mat"] as ShaderMaterial).set_shader_parameter("amount", b["amount"])
			if float(b["amount"]) <= 0.0:
				(b["node"] as Sprite2D).visible = false
				_fx.pop(b["pos"])                 # satisfying clear: sparkle burst + ring
			changed = true
	if changed:
		_update_water()
		if _spark_cd <= 0.0:                       # light sparkle trail while cleaning
			_spark_cd = 0.06
			_fx.spark(p)

func _update_water() -> void:
	var remaining := 0.0
	for b in _blobs:
		remaining += float(b["amount"])
	var clean := 1.0 - remaining / maxf(_total, 1.0)
	current_clean = clean
	if _water_mat:
		_water_mat.set_shader_parameter("clean", clean)
	cleanliness.emit(clean)   # let CoveLife heal in step with the water
