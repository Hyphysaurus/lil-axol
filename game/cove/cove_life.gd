extends Node2D
## Restoration payoff: as the oil is cleaned (OilSpill's `cleanliness` 0 -> 1), kelp fades
## in and sways, fish start darting, and bubbles rise — the cove visibly comes back to life.
## Life returns LOCALLY: each kelp/fish samples the oil film on the surface above its own
## spot, so plants bloom exactly where you scrubbed and trail your path across the cove.
## A global envelope keeps the cove reading dead at 0% and staggers the stages (kelp first,
## fish once the water is partway healed). Geometry + counts come from the injected CoveConfig.

const WHITE := preload("res://assets/white.png")
const KELP_SHADER := preload("res://shaders/wind_grass.gdshader")   # reused, tinted as kelp
const FISH_SHADER := preload("res://shaders/fish.gdshader")

const SAMPLE_DEPTH := 20.0        # px below the waterline where the oil film is sampled

var _cfg: CoveConfig
var _oil: Node                    # oil manager (oil_at), for the local reveal
var _clean := 0.0
var _life := 0.0
var _fish: Array = []
var _kelp: Array = []             # { mat, x } — per-blade material + cove-local sample column
var _bubbles: CPUParticles2D

## Called by the Cove composition root after _ready; config-dependent spawn lives here.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_spawn_kelp()
	_spawn_fish()
	_spawn_bubbles()
	var mgr = get_tree().get_first_node_in_group("oil_manager")   # untyped: dynamic access
	if mgr:
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(_on_clean)
		if "current_clean" in mgr:
			_clean = mgr.current_clean
		if mgr.has_method("oil_at"):
			_oil = mgr

func _on_clean(v: float) -> void:
	_clean = v

func _process(delta: float) -> void:
	_life = move_toward(_life, _clean, delta * 0.5)   # smooth global heal
	if _bubbles:
		_bubbles.modulate.a = _life
	var kelp_env := smoothstep(0.0, 0.35, _life)      # kelp leads the recovery
	var fish_env := smoothstep(0.15, 0.55, _life)     # fish come back once it's safer
	for k in _kelp:
		_reveal(k["mat"], (1.0 - _oil_above(k["x"])) * kelp_env, delta * 0.5)
	for f in _fish:
		_update_fish(f, delta)
		var s: Sprite2D = f["node"]
		_reveal(f["mat"], (1.0 - _oil_above(s.position.x)) * fish_env, delta * 0.4)

## Oil coverage of the surface film directly above a cove-local x (0 = scrubbed clean).
func _oil_above(x: float) -> float:
	if _oil == null:
		return 0.0
	return _oil.oil_at(to_global(Vector2(x, _cfg.surface_y + SAMPLE_DEPTH)))

func _reveal(m: ShaderMaterial, target: float, step: float) -> void:
	var cur: float = m.get_shader_parameter("reveal")
	if not is_equal_approx(cur, target):
		m.set_shader_parameter("reveal", move_toward(cur, target, step))

func _spawn_kelp() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = KELP_SHADER
	mat.set_shader_parameter("base_col", Color(0.08, 0.32, 0.28))
	mat.set_shader_parameter("tip_col", Color(0.24, 0.70, 0.55))
	mat.set_shader_parameter("blades", 9.0)
	mat.set_shader_parameter("wind", 0.09)
	mat.set_shader_parameter("wind_speed", 0.8)
	mat.set_shader_parameter("height", 0.96)
	for i in _cfg.kelp_count:
		var w := 34.0 + float((i * 17) % 20)
		var h := 70.0 + float((i * 29) % 45)
		var x := lerpf(_cfg.water_left + 20.0, _cfg.water_right - 30.0, float(i) / float(maxi(_cfg.kelp_count - 1, 1)))
		x += sin(float(i) * 9.3) * 22.0
		var s := Sprite2D.new()
		s.texture = WHITE
		var m: ShaderMaterial = mat.duplicate()   # per-blade material: each reveals on its own
		m.set_shader_parameter("reveal", 0.0)
		s.material = m
		s.centered = false
		s.scale = Vector2(w, h)
		s.position = Vector2(x - w * 0.5, _cfg.seabed_y - h)   # base sits on the seabed
		s.z_index = 3                                          # over seabed, under the water tint
		add_child(s)
		_kelp.append({ "mat": m, "x": x })

func _spawn_fish() -> void:
	var hues := [Color(0.95, 0.55, 0.35), Color(0.9, 0.45, 0.55), Color(0.6, 0.75, 0.85), Color(0.95, 0.8, 0.4)]
	for i in _cfg.fish_count:
		var mat := ShaderMaterial.new()
		mat.shader = FISH_SHADER
		var hue: Color = hues[i % hues.size()]
		mat.set_shader_parameter("body_col", hue)
		mat.set_shader_parameter("fin_col", hue.darkened(0.25))
		mat.set_shader_parameter("reveal", 0.0)
		var s := Sprite2D.new()
		s.texture = WHITE
		s.material = mat
		s.centered = true
		var sz := 12.0 + float((i * 13) % 8)
		s.scale = Vector2(sz * 1.6, sz)
		s.z_index = 4
		s.position = Vector2(lerpf(_cfg.water_left, _cfg.water_right, float(i) / float(_cfg.fish_count)),
			lerpf(_cfg.surface_y + 24.0, _cfg.seabed_y - 24.0, fmod(float(i) * 0.37, 1.0)))
		add_child(s)
		var vel := Vector2(28.0 + float(i % 3) * 10.0, 0.0)
		if i % 2 == 0:
			vel.x = -vel.x
		_fish.append({ "node": s, "vel": vel, "phase": float(i) * 1.3, "mat": mat })

func _spawn_bubbles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 4.5
	p.position = Vector2((_cfg.water_left + _cfg.water_right) * 0.5, _cfg.seabed_y)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((_cfg.water_right - _cfg.water_left) * 0.5, 4.0)
	p.direction = Vector2(0, -1)
	p.spread = 8.0
	p.gravity = Vector2(0, -14.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color = Color(0.8, 0.95, 1.0, 0.5)
	p.z_index = 4
	p.modulate.a = 0.0            # vents wake with the global heal, not per-spot
	add_child(p)
	_bubbles = p

func _update_fish(f: Dictionary, delta: float) -> void:
	var s: Sprite2D = f["node"]
	var vel: Vector2 = f["vel"]
	f["phase"] = float(f["phase"]) + delta
	var pos := s.position + vel * delta
	pos.y += sin(float(f["phase"]) * 1.4) * 6.0 * delta   # gentle bob/weave
	if pos.x < _cfg.water_left and vel.x < 0.0:
		vel.x = -vel.x
	elif pos.x > _cfg.water_right and vel.x > 0.0:
		vel.x = -vel.x
	pos.y = clampf(pos.y, _cfg.surface_y + 14.0, _cfg.seabed_y - 14.0)
	s.position = pos
	s.flip_h = vel.x < 0.0
	f["vel"] = vel
