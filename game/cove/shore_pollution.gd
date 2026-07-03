extends Node2D
## Shore pollution — the interactive oil ON the land (Terra Nil-style: you restore each patch
## by hand) plus a few oil barrels adrift in the cove. Oil splats sit on the beach; aim your
## spray at one and it shrinks and fades (reusing oil.gdshader's `amount`). Clearing a splat
## ticks the scrub sound and awards a little Shine. The bobbing barrels are set-dressing —
## pollution washed into the cove. Self-places from the injected cove geometry; joins the
## "sprayable" group so the axolotl's spray reaches the splats like it reaches the water film.

const OIL_SHADER := preload("res://shaders/oil.gdshader")
const WHITE := preload("res://assets/white.png")
const BARREL := preload("res://assets/props/industrial/red_oil_barrel.png")

const SPLATS := 7
const CLEAN_RATE := 1.5         # how fast a splat clears under a direct spray
const SPLAT_SHINE := 700.0      # Shine for fully clearing one land splat

var _cfg: CoveConfig
var _splats: Array = []         # { spr, mat, amount }
var _barrels: Array = []        # { spr, x, phase }
var _t := 0.0
var _scrub_cd := 0.0

func _ready() -> void:
	add_to_group("sprayable")

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	_spawn_splats()
	_spawn_barrels()

func _spawn_splats() -> void:
	# scatter oil splats across the beach near the shoreline (left of the water)
	for i in SPLATS:
		var mat := ShaderMaterial.new()
		mat.shader = OIL_SHADER
		mat.set_shader_parameter("amount", 1.0)
		mat.set_shader_parameter("sheen", 0.55)
		var s := Sprite2D.new()
		s.texture = WHITE
		s.material = mat
		var sz := 24.0 + float((i * 13) % 22)
		s.scale = Vector2(sz, sz)
		var x := lerpf(_cfg.water_left - 226.0, _cfg.water_left - 20.0, fmod(float(i) * 0.37 + 0.12, 1.0))
		var y := lerpf(-40.0, -6.0, fmod(float(i) * 0.61, 1.0))   # the dry beach band by the shore
		s.position = Vector2(x, y)
		s.z_index = 2               # over the sand, under the grass fringe
		add_child(s)
		_splats.append({ "spr": s, "mat": mat, "amount": 1.0 })

func _spawn_barrels() -> void:
	# a couple of oil barrels adrift on the surface — pollution washed in
	for i in 2:
		var s := Sprite2D.new()
		s.texture = BARREL
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(0.85, 0.85)
		var x := lerpf(_cfg.water_left + 90.0, _cfg.water_right - 130.0, 0.3 + 0.45 * float(i))
		s.position = Vector2(x, _cfg.surface_y - 1.0)
		s.z_index = 4
		add_child(s)
		_barrels.append({ "spr": s, "x": x, "phase": float(i) * 2.3 })

## The axolotl's spray reaching us (via the "sprayable" group). Cleans the land splat nearest
## the spray point; the water film is handled separately by OilSpill.
func spray_at(world_pos: Vector2, radius: float, delta: float) -> void:
	var hit := false
	for sp in _splats:
		if sp.amount <= 0.0:
			continue
		var r: float = radius + sp.spr.scale.x * 0.4
		if world_pos.distance_to(sp.spr.global_position) > r:
			continue
		hit = true
		var before: float = sp.amount
		sp.amount = maxf(0.0, sp.amount - CLEAN_RATE * delta)
		sp.mat.set_shader_parameter("amount", sp.amount)
		if before > 0.0 and sp.amount <= 0.0:
			sp.spr.visible = false
			Sfx.play("chime", -8.0, 1.35)
			var keeper = get_tree().get_first_node_in_group("shine")
			if keeper and keeper.has_method("bonus"):
				keeper.bonus(SPLAT_SHINE, sp.spr.global_position)
	if hit:
		_scrub_cd -= delta
		if _scrub_cd <= 0.0:
			_scrub_cd = 0.12
			Sfx.play("scrub", -2.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	for b in _barrels:
		var s: Sprite2D = b["spr"]
		s.position.y = _cfg.surface_y - 1.0 + sin(_t * 1.3 + float(b["phase"])) * 3.0
		s.rotation = sin(_t * 0.9 + float(b["phase"])) * 0.06
