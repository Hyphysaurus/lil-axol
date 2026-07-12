extends Node2D
## The INVASIVE SCHOOL — murky tilapia/carp stand-ins patrolling the deep (Living Watershed §3.5,
## slice-2 ambient form). The pollution's living face and the pre-otter Clarity cap: shy (eases
## away from the axolotl — cozy, never a threat), scattered briefly by spray but never removed —
## your current verbs visibly don't solve this. Each fish joins group "invasive" (reach_state
## counts them). First close approach shows the "Shadow in the Water" encounter card (echo-safe,
## WorldState-marked once). Art: the Smolque goldfish (a domesticated carp), murk-tinted.

const FISH_TEX := preload("res://assets/critters/goldfish.png")
const FieldGuide := preload("res://game/log/field_guide.gd")

const SHY_DIST := 70.0        # eases away inside this
const SCATTER_TIME := 1.6
const ENCOUNTER_DIST := 90.0

var _cfg: CoveConfig
var _fish: Array = []          # per fish: {node, anchor: Vector2, phase: float, scatter: float}
var _t := 0.0
var _met := false

func setup(cfg: CoveConfig) -> void:
	_cfg = cfg
	if cfg.invasive_count <= 0:
		queue_free()
		return
	add_to_group("sprayable")   # custom spray_at: scatter, never delete
	z_index = 6
	_met = bool(WorldState.get_cove(cfg.id, "enc_school", false))
	# field-true anchors on a painted map only (spec 4.6/T7) — legacy keeps the exact lerp+jitter so
	# a hand-built reach's school layout never shifts.
	var field: ReachField = get_tree().get_first_node_in_group("reach_field")
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in cfg.invasive_count:
		var s := Sprite2D.new()
		s.texture = FISH_TEX
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = Palette.LOAM.lerp(Palette.SLATE, 0.55)   # murk-tinted invader
		s.scale = Vector2(1.15, 1.15)                          # a touch bigger than the natives
		s.add_to_group("invasive")
		add_child(s)
		var anchor: Vector2
		if cfg.has_map and field != null:
			anchor = field.random_water_cell(rng)   # guaranteed an actual water cell
		else:
			var t := (float(i) + 0.5) / float(cfg.invasive_count)
			anchor = Vector2(lerpf(cfg.water_left + 80.0, cfg.water_right - 90.0, t),
				cfg.seabed_y - 14.0 - rng.randf_range(0.0, 10.0))
		s.position = anchor
		_fish.append({"node": s, "anchor": anchor, "phase": rng.randf_range(0.0, TAU), "scatter": 0.0})

func _process(delta: float) -> void:
	_t += delta
	var axo := get_tree().get_first_node_in_group("player") as Node2D
	var axo_local := to_local(axo.global_position) if axo else Vector2(-9999, 0)
	for f in _fish:
		var s: Sprite2D = f["node"]
		f["scatter"] = maxf(0.0, f["scatter"] - delta)
		var target: Vector2 = f["anchor"] + Vector2(sin(_t * 0.7 + f["phase"]) * 26.0, sin(_t * 1.1 + f["phase"]) * 5.0)
		var away := s.position - axo_local
		if away.length() < SHY_DIST:                    # shy: ease away from the tidekeeper
			target += away.normalized() * (SHY_DIST - away.length())
		if f["scatter"] > 0.0:                          # sprayed: dart wide, then re-gather
			target += Vector2(sin(f["phase"] * 7.0) * 60.0, -12.0)
		s.position = s.position.lerp(target, clampf((3.0 if f["scatter"] > 0.0 else 1.2) * delta, 0.0, 1.0))
		s.flip_h = target.x < s.position.x
	# the encounter: first time the tidekeeper comes close, the log meets the antagonist
	if not _met and axo and _fish.size() > 0:
		var s0: Sprite2D = _fish[0]["node"]
		if axo_local.distance_to(s0.position) < ENCOUNTER_DIST:
			_met = true
			var root := get_tree().get_first_node_in_group("cove_root")
			if root == null or not root.has_method("is_echo") or not root.is_echo():
				WorldState.mark(_cfg.id, "enc_school", true)
			var card: Dictionary = FieldGuide.card("enc_estuary_school")
			get_tree().call_group("curio_cards", "show_card", card, "field guide — encounter logged")

## Spray scatters the school for a beat — and that's all it does (the otter herds them, slice 6).
func spray_at(world_pos: Vector2, _radius: float, _delta: float) -> void:
	for f in _fish:
		var s: Sprite2D = f["node"]
		if s.global_position.distance_to(world_pos) < 46.0:
			f["scatter"] = SCATTER_TIME
