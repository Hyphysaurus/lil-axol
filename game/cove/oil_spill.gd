extends Node2D
## Oil spill manager. Spawns floating oil blobs on the cove water, lets the axolotl
## spray them clean, and drives the Water shader's `clean` uniform (0 oily -> 1 restored)
## so the whole cove — colour + sky reflection — heals as you clean up the spill.

signal cleanliness(v: float)   # 0 oily -> 1 restored; emitted whenever the spill state changes

const OIL_SHADER := preload("res://shaders/oil.gdshader")
const WHITE := preload("res://assets/white.png")

@export var blob_count := 9
@export var clean_rate := 1.4          # how fast a sprayed blob clears (amount/sec)

# spill sits on the right (oil-source) side, floating on the surface (cove-local coords)
const SPILL_LEFT := 120.0
const SPILL_RIGHT := 445.0
const SURFACE_Y := -27.0

var _blobs: Array = []
var _water_mat: ShaderMaterial
var _total := 0.0
var current_clean := 0.0

func _ready() -> void:
	add_to_group("oil_manager")
	var wt := get_node_or_null("../Water")
	if wt:
		_water_mat = (wt as Sprite2D).material as ShaderMaterial
	_spawn()
	_update_water()

func _spawn() -> void:
	for i in blob_count:
		var fx := float(i) / float(maxi(blob_count - 1, 1))
		var x := lerpf(SPILL_LEFT, SPILL_RIGHT, fx) + sin(float(i) * 12.9) * 16.0
		var y := SURFACE_Y - 2.0 + cos(float(i) * 7.3) * 9.0
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
	for b in _blobs:
		if float(b["amount"]) <= 0.0:
			continue
		if (b["pos"] as Vector2).distance_to(p) <= radius:
			b["amount"] = maxf(0.0, float(b["amount"]) - clean_rate * delta)
			(b["mat"] as ShaderMaterial).set_shader_parameter("amount", b["amount"])
			if float(b["amount"]) <= 0.0:
				(b["node"] as Sprite2D).visible = false
			changed = true
	if changed:
		_update_water()

func _update_water() -> void:
	var remaining := 0.0
	for b in _blobs:
		remaining += float(b["amount"])
	var clean := 1.0 - remaining / maxf(_total, 1.0)
	current_clean = clean
	if _water_mat:
		_water_mat.set_shader_parameter("clean", clean)
	cleanliness.emit(clean)   # let CoveLife heal in step with the water
