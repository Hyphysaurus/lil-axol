extends Node2D
## Restoration payoff: as the oil is cleaned (OilSpill's `cleanliness` 0 -> 1), kelp fades
## in and sways, fish start darting, and bubbles rise — the cove visibly comes back to life.
## Everything is a child of this node, so fading its modulate fades the whole ecosystem in.

const WHITE := preload("res://assets/white.png")
const KELP_SHADER := preload("res://shaders/wind_grass.gdshader")   # reused, tinted as kelp
const FISH_SHADER := preload("res://shaders/fish.gdshader")

# water column (cove-local): water x[-142,457], surface ~ -27, seabed top ~166
const SEABED_Y := 165.0
const SURFACE_Y := -22.0
const WATER_L := -130.0
const WATER_R := 445.0

@export var kelp_count := 6
@export var fish_count := 5

var _clean := 0.0
var _life := 0.0
var _fish: Array = []

func _ready() -> void:
	modulate.a = 0.0                      # dead cove until it's cleaned
	_spawn_kelp()
	_spawn_fish()
	_spawn_bubbles()
	var mgr = get_tree().get_first_node_in_group("oil_manager")   # untyped: dynamic access
	if mgr:
		if mgr.has_signal("cleanliness"):
			mgr.cleanliness.connect(_on_clean)
		if "current_clean" in mgr:
			_clean = mgr.current_clean

func _on_clean(v: float) -> void:
	_clean = v

func _process(delta: float) -> void:
	_life = move_toward(_life, _clean, delta * 0.5)   # smooth heal / fade
	modulate.a = _life
	for f in _fish:
		_update_fish(f, delta)

func _spawn_kelp() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = KELP_SHADER
	mat.set_shader_parameter("base_col", Color(0.08, 0.32, 0.28))
	mat.set_shader_parameter("tip_col", Color(0.24, 0.70, 0.55))
	mat.set_shader_parameter("blades", 9.0)
	mat.set_shader_parameter("wind", 0.09)
	mat.set_shader_parameter("wind_speed", 0.8)
	mat.set_shader_parameter("height", 0.96)
	for i in kelp_count:
		var w := 34.0 + float((i * 17) % 20)
		var h := 70.0 + float((i * 29) % 45)
		var x := lerpf(WATER_L + 20.0, WATER_R - 30.0, float(i) / float(maxi(kelp_count - 1, 1)))
		x += sin(float(i) * 9.3) * 22.0
		var s := Sprite2D.new()
		s.texture = WHITE
		s.material = mat
		s.centered = false
		s.scale = Vector2(w, h)
		s.position = Vector2(x - w * 0.5, SEABED_Y - h)   # base sits on the seabed
		s.z_index = 3                                      # over seabed, under the water tint
		add_child(s)

func _spawn_fish() -> void:
	var hues := [Color(0.95, 0.55, 0.35), Color(0.9, 0.45, 0.55), Color(0.6, 0.75, 0.85), Color(0.95, 0.8, 0.4)]
	for i in fish_count:
		var mat := ShaderMaterial.new()
		mat.shader = FISH_SHADER
		var hue: Color = hues[i % hues.size()]
		mat.set_shader_parameter("body_col", hue)
		mat.set_shader_parameter("fin_col", hue.darkened(0.25))
		var s := Sprite2D.new()
		s.texture = WHITE
		s.material = mat
		s.centered = true
		var sz := 12.0 + float((i * 13) % 8)
		s.scale = Vector2(sz * 1.6, sz)
		s.z_index = 4
		s.position = Vector2(lerpf(WATER_L, WATER_R, float(i) / float(fish_count)),
			lerpf(SURFACE_Y + 24.0, SEABED_Y - 24.0, fmod(float(i) * 0.37, 1.0)))
		add_child(s)
		var vel := Vector2(28.0 + float(i % 3) * 10.0, 0.0)
		if i % 2 == 0:
			vel.x = -vel.x
		_fish.append({ "node": s, "vel": vel, "phase": float(i) * 1.3 })

func _spawn_bubbles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 4.5
	p.position = Vector2((WATER_L + WATER_R) * 0.5, SEABED_Y)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((WATER_R - WATER_L) * 0.5, 4.0)
	p.direction = Vector2(0, -1)
	p.spread = 8.0
	p.gravity = Vector2(0, -14.0)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.color = Color(0.8, 0.95, 1.0, 0.5)
	p.z_index = 4
	add_child(p)

func _update_fish(f: Dictionary, delta: float) -> void:
	var s: Sprite2D = f["node"]
	var vel: Vector2 = f["vel"]
	f["phase"] = float(f["phase"]) + delta
	var pos := s.position + vel * delta
	pos.y += sin(float(f["phase"]) * 1.4) * 6.0 * delta   # gentle bob/weave
	if pos.x < WATER_L and vel.x < 0.0:
		vel.x = -vel.x
	elif pos.x > WATER_R and vel.x > 0.0:
		vel.x = -vel.x
	pos.y = clampf(pos.y, SURFACE_Y + 14.0, SEABED_Y - 14.0)
	s.position = pos
	s.flip_h = vel.x < 0.0
	f["vel"] = vel
