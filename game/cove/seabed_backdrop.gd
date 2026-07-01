extends Node2D
class_name SeabedBackdrop
## Reactive pixel-art seabed. Tiles water_clean_seabed across the water floor, BEHIND the
## procedural water + oil film, as the payoff layer for paint-to-clean: dim and murky while
## the cove is oily, brightening into a vivid living reef as the player scrubs it clean
## (driven by the oil_manager `cleanliness` signal). Day/night tint is automatic — the cove's
## CanvasModulate already multiplies this like everything else. Per-tile flip breaks up tiling.

const SEABED_TEX := preload("res://assets/props/water/water_clean_seabed.png")
const SEABED_SHADER := preload("res://shaders/seabed.gdshader")

@export var murky := Color(0.34, 0.44, 0.52)   # under the oil: dim, desaturated
@export var vivid := Color(1.0, 1.0, 1.0)       # restored: full colour

var _cfg: CoveConfig
var _clean := 0.0
var _life := 0.0

func _ready() -> void:
	modulate = murky      # dim until cleaned (also correct before setup runs)

## Called by the Cove composition root after _ready; config-dependent tiling lives here.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_tile()
	var mgr = get_tree().get_first_node_in_group("oil_manager")   # untyped: dynamic access
	if mgr:
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(_on_clean)
		if "current_clean" in mgr:
			_clean = mgr.current_clean

func _on_clean(v: float) -> void:
	_clean = v

func _process(delta: float) -> void:
	_life = move_toward(_life, _clean, delta * 0.5)   # smooth reveal, in step with CoveLife
	modulate = murky.lerp(vivid, _life)

const EDGE_OVERLAP := 0.16    # must match seabed.gdshader `edge_fade` so faded edges crossfade

func _tile() -> void:
	var tw := float(SEABED_TEX.get_width())
	var th := float(SEABED_TEX.get_height())
	var y := _cfg.seabed_y - th        # reef floor rests on the seabed line
	# one shared material: top-fade + edge-crossfade + depth blend so the band melts together
	var mat := ShaderMaterial.new()
	mat.shader = SEABED_SHADER
	var step := tw * (1.0 - EDGE_OVERLAP)   # overlap neighbours by the shader's edge-fade width
	var x := _cfg.water_left
	var i := 0
	while x < _cfg.water_right:
		var s := Sprite2D.new()
		s.texture = SEABED_TEX
		s.material = mat
		s.centered = false
		s.position = Vector2(x, y)
		s.flip_h = (i % 2 == 0)        # alternate flip so the tiling reads as reef, not wallpaper
		s.z_index = 1                  # behind the axolotl (z 2), kelp (3), fish (4), water (5)
		add_child(s)
		x += step
		i += 1
