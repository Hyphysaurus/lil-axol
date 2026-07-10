extends Node2D
## A hidden CURIO — a real little piece of Xochimilco buried in the silt (Living Watershed §8).
## Diegetic seek-and-find: a low silt mound that GLINTS faintly every few seconds (findable, never a
## pixel hunt), unearthed by sustained spray (the same skill verb as every rescue), then it floats
## free and is collected by swimming close: feat callout + Shine + its Field Guide card. Found curios
## are WorldState-marked per cove (echo runs re-spawn them for score but never re-mark).
## Spawned by curio_field.gd; self-contained otherwise.

signal collected(id: String)

const UNEARTH_SECONDS := 1.1   # sustained close-spray to shake it free of the silt
const SPRAY_REACH := 30.0
const COLLECT_REACH := 16.0
const REDRAW_HZ := 8.0

var id := ""                   # "<cove_id>_<index>" — the WorldState mark + Field Guide key
var icon := 0                  # 0 eggs, 1 shard, 2 sprig (see field_guide.gd)

var _progress := 0.0
var _revealed := false
var _done := false
var _t := 0.0
var _acc := 0.0

func _ready() -> void:
	add_to_group("sprayable")
	z_index = 4                 # in the silt, under creatures (frog 9 / axolotl 10)

## The player's spray — same group contract as rescues and the leak cap.
func spray_at(world_pos: Vector2, _radius: float, delta: float) -> void:
	if _revealed or _done:
		return
	if world_pos.distance_to(global_position) > SPRAY_REACH:
		return
	_progress += delta
	queue_redraw()              # the mound visibly loosens as you work
	if _progress >= UNEARTH_SECONDS:
		_revealed = true
		Sfx.play("chime", -10.0, 1.4)
		_puff()

func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if _revealed:
		# unearthed: the curio floats free, bobbing — collect by coming close
		position.y += sin(_t * 2.2) * 2.4 * delta
		var axo := get_tree().get_first_node_in_group("player") as Node2D
		if axo and axo.global_position.distance_to(global_position) <= COLLECT_REACH:
			_collect()
			return
	_acc += delta
	if _acc >= 1.0 / REDRAW_HZ:
		_acc = 0.0
		queue_redraw()          # the buried glint + the revealed bob (throttled — WebGL churn rule)

func _collect() -> void:
	_done = true
	var keeper = get_tree().get_first_node_in_group("shine")
	if keeper and keeper.has_method("feat"):
		keeper.feat(&"curio", global_position)
	Sfx.play("whimsy", -4.0, 1.3)
	collected.emit(id)          # curio_field marks WorldState + shows the Field Guide card
	_puff()
	queue_free()

func _draw() -> void:
	if _done:
		return
	if not _revealed:
		# the silt mound, sinking away as spray loosens it — plus a soft periodic glint
		var a := 1.0 - _progress / UNEARTH_SECONDS
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 9.0, Color(Palette.SAND.lerp(Palette.LOAM, 0.4), 0.85 * a))
		draw_circle(Vector2(-2.0, -1.0), 6.0, Color(Palette.SAND, 0.9 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var glint := maxf(0.0, sin(_t * 1.4))
		glint = maxf(0.0, glint * glint * glint - 0.15)   # a brief sparkle every ~4.5s, dark between
		if glint > 0.0:
			draw_line(Vector2(-3.0, -4.0), Vector2(3.0, -4.0), Color(Palette.FOAM, glint), 1.5)
			draw_line(Vector2(0.0, -7.0), Vector2(0.0, -1.0), Color(Palette.FOAM, glint), 1.5)
		return
	# unearthed: the little find itself, held in a soft glow until collected
	var bob := sin(_t * 2.2) * 1.5
	draw_circle(Vector2(0.0, bob), 8.5, Color(Palette.GOLD, 0.14))
	match icon:
		0:   # egg cluster — three pale rounds
			draw_circle(Vector2(-3.0, bob), 3.2, Palette.FOAM)
			draw_circle(Vector2(2.5, bob - 2.0), 2.8, Palette.FOAM.darkened(0.08))
			draw_circle(Vector2(2.0, bob + 2.5), 2.4, Palette.MIST)
		1:   # shard — an angular sherd/scute plate
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4.0, bob + 3.0), Vector2(-1.0, bob - 4.0),
				Vector2(4.0, bob - 2.0), Vector2(2.0, bob + 4.0)]), Palette.CLAY)
			draw_line(Vector2(-2.0, bob), Vector2(2.0, bob - 1.0), Palette.LOAM, 1.0)
		_:   # sprig — a green blade with a husk curl
			draw_line(Vector2(0.0, bob + 4.0), Vector2(-1.0, bob - 4.0), Palette.LEAF, 2.0)
			draw_line(Vector2(-1.0, bob - 4.0), Vector2(2.0, bob - 6.0), Palette.MOSS, 1.5)

## A golden puff at the curio's spot — added to the PARENT (cove frame) so it plays out fully
## even when the curio frees itself on collect.
func _puff() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.position = position
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0.0, 30.0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	p.color = Color(Palette.GOLD, 0.8)
	p.z_index = 8
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
