extends Node
## Shore health — the beach starts spill-washed and heals with the water. Drives the
## `sludge` uniform on the sand + grass materials from the oil manager's cleanliness
## signal (banner idiom: self-wired, purely visual, touches no gameplay). The shore
## eases a beat behind the water (0.3/s), so the land visibly answers the cleanup.

const SHORE_PATHS := ["../Beach/Sand", "../Grass", "../GrassFront"]

var _mats: Array[ShaderMaterial] = []
var _clean := 0.0
var _sludge := 1.0

func _ready() -> void:
	for path in SHORE_PATHS:
		var n := get_node_or_null(path) as CanvasItem
		if n and n.material is ShaderMaterial:
			_mats.append(n.material)
	var mgr = get_tree().get_first_node_in_group("oil_manager")
	if mgr and mgr.has_signal("cleanliness"):
		mgr.cleanliness.connect(_on_clean)
	if mgr and "current_clean" in mgr:
		_clean = mgr.current_clean
	_apply(_sludge)

func _on_clean(v: float) -> void:
	_clean = v

func _process(delta: float) -> void:
	var target := 1.0 - _clean
	if is_equal_approx(_sludge, target):
		return
	_sludge = move_toward(_sludge, target, delta * 0.3)
	_apply(_sludge)

func _apply(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("sludge", v)
