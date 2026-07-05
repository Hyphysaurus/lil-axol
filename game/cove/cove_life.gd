extends Node2D
## Restoration payoff: as the oil is cleaned (OilSpill's `cleanliness` 0 -> 1), kelp fades
## in and sways, fish start darting, and bubbles rise — the cove visibly comes back to life.
## Life returns LOCALLY: each kelp/fish samples the oil film on the surface above its own
## spot, so plants bloom exactly where you scrubbed and trail your path across the cove.
## A global envelope keeps the cove reading dead at 0% and staggers the stages (kelp first,
## fish once the water is partway healed). Geometry + counts come from the injected CoveConfig.

const WHITE := preload("res://assets/white.png")
const BUBBLE_TEX := preload("res://assets/fx/bubble.png")   # Mario's hand-drawn bubble (Pixquare)
const KELP_SHADER := preload("res://shaders/wind_grass.gdshader")   # reused, tinted as kelp
# the fish school is real sprite art now (Smolque Pixel Fish Pack — 32x32, single pose each).
# cove_life just darts + flips them and fades them in as the water heals; the old procedural
# fish.gdshader is retired for the cove (kept in the repo for reuse).
const FISH_TEX := [
	# warm cuties (Smolque)
	preload("res://assets/critters/clownfish.png"),
	preload("res://assets/critters/goldfish.png"),
	preload("res://assets/critters/butterflyfish.png"),
	preload("res://assets/critters/milkfish.png"),
	# cool-toned variety (PIXEL_1992 Sea Creatures) — same 32x32 dark-outline style, same facing
	preload("res://assets/critters/fish_teal.png"),
	preload("res://assets/critters/fish_tang.png"),
	preload("res://assets/critters/fish_blue.png"),
	preload("res://assets/critters/fish_violet.png"),
]
# ambient reef life — gentle drifters (jellyfish pulse, seahorses hover) + a crab that scuttles
# the seabed floor (4-frame walk sliced from the top row of a 4x4 32px sheet). All from the same
# cozy pixel packs as the school, all fade in with the heal like the fish do.
const SEAHORSE_TEX := preload("res://assets/critters/seahorse.png")
const JELLYFISH_TEX := preload("res://assets/critters/jellyfish.png")
const CRAB_SHEET := preload("res://assets/critters/crab_sheet.png")
const LIGHT_SHAFTS := preload("res://shaders/light_shafts.gdshader")   # god-rays over the column
# a few seabed reef props (owned decor + PIXEL_1992 starfish) rest on the floor among the kelp
const CORAL_TEX := [
	preload("res://assets/props/decor/coral_pink.png"),
	preload("res://assets/props/decor/coral_cluster.png"),
	preload("res://assets/props/decor/seaweed_plant.png"),
	preload("res://assets/props/decor/coral_blue.png"),
	preload("res://assets/critters/star_red.png"),
	preload("res://assets/critters/star_blue.png"),
	preload("res://assets/critters/star_orange.png"),
]

const SAMPLE_DEPTH := 20.0        # px below the waterline where the oil film is sampled

var _cfg: CoveConfig
var _oil: Node                    # oil manager (oil_at), for the local reveal
var _clean := 0.0
var _life := 0.0
var _fish: Array = []
var _kelp: Array = []             # { mat, x } — per-blade material + cove-local sample column
var _bubbles: CPUParticles2D
var _ambient: Array = []          # gentle drifters: { node, base, bob, sway, pulse, phase, ... }
var _crab: AnimatedSprite2D       # scuttles left/right along the seabed floor
var _crab_vel := 34.0             # crab scuttle speed (px/s), flips sign at the cove edges
var _shafts: ColorRect            # god-rays overlay (full-viewport CanvasLayer), fade with the heal
var _motes: CPUParticles2D        # faint marine snow drifting in the water column
var _coral: Array = []            # { node, x } — seabed reef props, revealed with the kelp

## Called by the Cove composition root after _ready; config-dependent spawn lives here.
func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_spawn_kelp()
	_spawn_fish()
	_spawn_bubbles()
	_spawn_ambient()
	_spawn_crab()
	_spawn_shafts()
	_spawn_coral()
	_spawn_motes()
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
	var species_n := maxi(FISH_TEX.size() - 1, 1)
	for k in _kelp:
		_reveal(k["mat"], (1.0 - _oil_above(k["x"])) * kelp_env, delta * 0.5)
	for c in _coral:
		var cs: Sprite2D = c["node"]
		cs.modulate.a = move_toward(cs.modulate.a, (1.0 - _oil_above(c["x"])) * kelp_env, delta * 0.5)
	for f in _fish:
		_update_fish(f, delta)
		var s: Sprite2D = f["node"]
		# GRADUAL SPECIES RELEASE: each species debuts at a higher heal level (spread 0.10..0.70),
		# so the cleaner the cove gets the more KINDS of fish return — variety as a reward. Gated
		# further by the local (per-column) oil clearance so fish still appear where you've scrubbed.
		var debut: float = lerpf(0.10, 0.70, float(f["species"]) / float(species_n))
		var gate: float = smoothstep(debut, debut + 0.18, _life)
		var target: float = (1.0 - _oil_above(s.position.x)) * gate
		s.modulate.a = move_toward(s.modulate.a, target, delta * 0.4)
	_update_ambient(delta)

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
	mat.set_shader_parameter("base_col", Palette.TEAL.darkened(0.35))   # deep kelp root
	mat.set_shader_parameter("tip_col", Palette.GREEN)                  # bright frond tips
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
	for i in _cfg.fish_count:
		var s := Sprite2D.new()
		s.texture = FISH_TEX[i % FISH_TEX.size()]           # cycle through the school's species
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art, like the axolotl
		s.centered = true
		# the pack fish are 32x32; scale down so they read as small darting fish (~14–22px tall)
		var disp := 14.0 + float((i * 5) % 9)
		s.scale = Vector2.ONE * (disp / 32.0)
		s.modulate.a = 0.0                    # hidden until the water overhead heals (local reveal)
		s.z_index = 4
		s.position = Vector2(lerpf(_cfg.water_left, _cfg.water_right, float(i) / float(_cfg.fish_count)),
			lerpf(_cfg.surface_y + 24.0, _cfg.seabed_y - 24.0, fmod(float(i) * 0.37, 1.0)))
		add_child(s)
		var vel := Vector2(28.0 + float(i % 3) * 10.0, 0.0)
		if i % 2 == 0:
			vel.x = -vel.x
		# each fish belongs to a species (its texture); species debut at staggered heal levels
		_fish.append({ "node": s, "vel": vel, "phase": float(i) * 1.3, "species": i % FISH_TEX.size() })

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
	p.texture = BUBBLE_TEX               # Mario's hand-drawn bubble sprite
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixels
	p.scale_amount_min = 0.28            # 32px sprite -> ~9..24px rising bubbles
	p.scale_amount_max = 0.72
	p.color = Color(1.0, 1.0, 1.0, 0.85) # white so the bubble's own teal/highlight colours show
	p.z_index = 4
	p.modulate.a = 0.0            # vents wake with the global heal, not per-spot
	add_child(p)
	_bubbles = p

func _spawn_ambient() -> void:
	# jellyfish drift + pulse mid-water; a seahorse hovers near the kelp. fx/fy place them across
	# the cove (0..1); bob/sway are drift amplitudes (px); pulse breathes the jellyfish scale.
	var specs := [
		{ "tex": JELLYFISH_TEX, "fx": 0.30, "fy": 0.38, "px": 22.0, "bob": 11.0, "bob_sp": 0.7, "sway": 7.0, "sway_sp": 0.5, "pulse": 0.12 },
		{ "tex": JELLYFISH_TEX, "fx": 0.68, "fy": 0.52, "px": 19.0, "bob": 9.0, "bob_sp": 0.9, "sway": 6.0, "sway_sp": 0.6, "pulse": 0.12 },
		{ "tex": SEAHORSE_TEX, "fx": 0.50, "fy": 0.80, "px": 18.0, "bob": 5.0, "bob_sp": 1.1, "sway": 3.0, "sway_sp": 0.8, "pulse": 0.0 },
	]
	for i in specs.size():
		var sp: Dictionary = specs[i]
		var s := Sprite2D.new()
		s.texture = sp["tex"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		var base_scale := Vector2.ONE * (float(sp["px"]) / 32.0)
		s.scale = base_scale
		s.modulate.a = 0.0
		s.z_index = 4
		var base := Vector2(lerpf(_cfg.water_left, _cfg.water_right, float(sp["fx"])),
			lerpf(_cfg.surface_y + 20.0, _cfg.seabed_y - 12.0, float(sp["fy"])))
		s.position = base
		add_child(s)
		_ambient.append({ "node": s, "base": base, "bob": sp["bob"], "bob_sp": sp["bob_sp"],
			"sway": sp["sway"], "sway_sp": sp["sway_sp"], "pulse": sp["pulse"],
			"base_scale": base_scale, "phase": float(i) * 1.7 })

func _spawn_crab() -> void:
	# a 4-frame walk cut from the TOP ROW of the 4x4 crab sheet (skips the sheet's odd extra frames)
	var sf := SpriteFrames.new()
	sf.add_animation(&"walk")
	sf.set_animation_speed(&"walk", 7.0)
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = CRAB_SHEET
		at.region = Rect2(float(i) * 32.0, 0.0, 32.0, 32.0)
		sf.add_frame(&"walk", at)
	_crab = AnimatedSprite2D.new()
	_crab.sprite_frames = sf
	_crab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crab.scale = Vector2.ONE * (20.0 / 32.0)     # ~20px crab on the seabed floor
	_crab.z_index = 4
	_crab.modulate.a = 0.0                         # reveals with the heal like the fish
	_crab.position = Vector2((_cfg.water_left + _cfg.water_right) * 0.5, _cfg.seabed_y - 6.0)
	add_child(_crab)
	_crab.play(&"walk")

func _spawn_shafts() -> void:
	# God-rays are a SCENE-WIDE atmospheric overlay, not just the water box: a full-viewport
	# ColorRect on its own CanvasLayer, so the sunbeams rake down through the sky/background AND the
	# water in one continuous sweep. The sky is itself a full-screen CanvasLayer, so a screen-space
	# overlay is the only way to cover it. Additive (the shader's blend_add), over the world but
	# under the HUD + PostFX. Brightness is driven from the heal (see _update_ambient) — the light
	# returns to the whole scene as the cove is restored.
	var mat := ShaderMaterial.new()
	mat.shader = LIGHT_SHAFTS
	mat.set_shader_parameter("intensity", 0.0)   # starts dark; _update_ambient fades it up
	var layer := CanvasLayer.new()
	layer.layer = 50                  # over the world (0), under the HUD/menus (90+) and PostFX (100)
	add_child(layer)
	_shafts = ColorRect.new()
	_shafts.material = mat
	_shafts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_shafts)

## Drift the jellyfish/seahorse, scuttle the crab, and fade the god-rays in with the heal.
func _update_ambient(delta: float) -> void:
	for a in _ambient:
		a["phase"] = float(a["phase"]) + delta
		var ph: float = a["phase"]
		var s: Sprite2D = a["node"]
		var base: Vector2 = a["base"]
		s.position = base + Vector2(sin(ph * float(a["sway_sp"])) * float(a["sway"]),
			sin(ph * float(a["bob_sp"])) * float(a["bob"]))
		if float(a["pulse"]) > 0.0:
			s.scale = (a["base_scale"] as Vector2) * (1.0 + float(a["pulse"]) * sin(ph * 2.2))
		var at: float = (1.0 - _oil_above(base.x)) * smoothstep(0.15, 0.5, _life)
		s.modulate.a = move_toward(s.modulate.a, at, delta * 0.4)
	if _crab:
		var cx: float = _crab.position.x + _crab_vel * delta
		if cx < _cfg.water_left + 24.0 and _crab_vel < 0.0:
			_crab_vel = -_crab_vel
		elif cx > _cfg.water_right - 24.0 and _crab_vel > 0.0:
			_crab_vel = -_crab_vel
		_crab.position.x = clampf(cx, _cfg.water_left + 24.0, _cfg.water_right - 24.0)
		_crab.flip_h = _crab_vel < 0.0
		var ct: float = (1.0 - _oil_above(_crab.position.x)) * smoothstep(0.1, 0.45, _life)
		_crab.modulate.a = move_toward(_crab.modulate.a, ct, delta * 0.4)
	if _shafts:
		# drive brightness from the heal via the shader uniform (a ColorRect+shader that writes
		# COLOR ignores modulate, so we set intensity directly). _life is already smoothed; cap a
		# touch below full so the rays stay a soft glow over the whole scene, not a wash.
		(_shafts.material as ShaderMaterial).set_shader_parameter("intensity", _life * 0.5)
	if _motes:
		_motes.modulate.a = _life * 0.9        # marine snow only shows in cleared, sunlit water

func _spawn_coral() -> void:
	# a few coral/seaweed props rising from the seabed floor — reef life the cleanup restores. They
	# sit among the kelp (same z + heal reveal), each sampling the oil directly above its own spot.
	var n := 8
	for i in n:
		var tex: Texture2D = CORAL_TEX[i % CORAL_TEX.size()]
		var sc := 0.5 + 0.12 * float(i % 3)          # small reef props, a little size variety
		var w := float(tex.get_width()) * sc
		var h := float(tex.get_height()) * sc
		var x := lerpf(_cfg.water_left + 40.0, _cfg.water_right - 40.0, (float(i) + 0.5) / float(n))
		x += sin(float(i) * 5.7) * 28.0
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.scale = Vector2(sc, sc)
		s.position = Vector2(x - w * 0.5, _cfg.seabed_y - h)   # base rests on the seabed line
		s.modulate.a = 0.0
		s.z_index = 3                                # among the kelp, behind the fish
		add_child(s)
		_coral.append({ "node": s, "x": x })

func _spawn_motes() -> void:
	# faint marine snow drifting in the water column — tiny motes that catch the god-ray light and
	# give the water body real depth. Slow, sparse, on-palette; fades in with the heal.
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 8.0
	p.preprocess = 8.0               # pre-populate the column so it isn't empty at spawn
	p.position = Vector2((_cfg.water_left + _cfg.water_right) * 0.5, (_cfg.surface_y + _cfg.seabed_y) * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2((_cfg.water_right - _cfg.water_left) * 0.5, (_cfg.seabed_y - _cfg.surface_y) * 0.5)
	p.direction = Vector2(0.3, -1.0)   # drift gently up and to the side
	p.spread = 30.0
	p.gravity = Vector2(3.0, -3.0)     # near-neutral: a lazy float, not a fall
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	p.color = Color(Palette.FOAM, 0.28)   # very faint bright fleck
	p.z_index = 4
	p.modulate.a = 0.0                 # revealed by the heal (clear water sparkles)
	add_child(p)
	_motes = p

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
	s.flip_h = vel.x > 0.0        # pack fish face -x by default; flip when swimming right
	f["vel"] = vel
