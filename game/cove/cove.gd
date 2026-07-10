extends Node2D
## Cove composition root. Owns the CoveConfig and injects it into each component in
## _ready() so children depend on the config's interface — never on each other or on
## walking the scene tree. One-way dependency: the parent hands data down.
##
## Child _ready() runs before this (bottom-up), so setup() lands after each child has
## initialised but before the first physics frame — config is always present in time.
##
## PERSISTENCE (Living Watershed slice 1): after injection the root consults WorldState —
## a restored cove spawns clean (oil gone, friend awake, portal open, leak retired); a
## partially-cleaned one re-seeds its saved cleanliness. Milestone saves are wired via
## signals (restored / opened / woke) + a cleanliness save on scene exit. An ECHO run
## (WorldState.echo, set by New Day on a restored cove) skips BOTH: fresh spill, no saves —
## the score replay leaves the world untouched (spec §7).

@export var config: CoveConfig

const IrisWipe := preload("res://game/fx/iris_wipe.gd")

var _echo := false

## Is this visit an Echo run? (High-scores board keys off this.)
func is_echo() -> bool:
	return _echo

func _ready() -> void:
	add_to_group("cove_root")
	_echo = WorldState.echo
	WorldState.echo = false          # one reload only; consuming it here makes crossings normal
	WorldState.current_id = config.id
	_inject($Axolotl)
	_inject($OilSpill)
	_inject($CoveLife)
	_inject($SeabedBackdrop)
	_inject($RestorationBanner)
	_inject($NewDay)
	_inject($CoveAudio)
	_inject($Friend)
	_inject($LeakSource)
	_inject($ShorePollution)
	_inject($Portal)
	_inject($DebrisField)
	_inject($PestField)
	_inject($LilyPads)
	_inject($Reeds)
	_apply_environment()
	if Settings.arrive_via_portal:
		Settings.arrive_via_portal = false
		_arrive()
	if not _echo:
		_wire_saves()      # wires FIRST: if a re-seed ever crosses the win gate, it must save/score
		_apply_saved()

## A live (not queued-for-deletion) child by name, or null. Components retire themselves in
## setup() (friend_enabled false, no exit configured...) — never poke a retiring node.
func _live(n: String) -> Node:
	var node := get_node_or_null(n)
	return node if node != null and not node.is_queued_for_deletion() else null

## Spawn-time restore from WorldState (spec §7): the world as you left it.
func _apply_saved() -> void:
	var id := config.id
	var friend := _live("Friend")
	var portal := _live("Portal")
	var oil := _live("OilSpill")
	if WorldState.is_restored(id):
		var banner := _live("RestorationBanner")
		if banner:
			banner.is_restored = true          # latch: no duplicate celebration on re-entry
		if friend and friend.has_method("wake_instant"):
			friend.wake_instant()
		if oil and oil.has_method("set_clean_fraction"):
			oil.set_clean_fraction(1.0)
		if portal and portal.has_method("force_open"):
			portal.force_open()
		var leak := _live("LeakSource")
		if leak:
			leak.queue_free()                  # a healed cove's leak stays capped
		return
	# partial progress: re-seed cleanliness + the flags that were individually earned
	if friend and friend.has_method("wake_instant") and bool(WorldState.get_cove(id, "friend_awake", false)):
		friend.wake_instant()
	if oil and oil.has_method("set_clean_fraction"):
		var f := float(WorldState.get_cove(id, "cleanliness", 0.0))
		if f > 0.02:
			oil.set_clean_fraction(f)
	if portal and portal.has_method("force_open") and bool(WorldState.get_cove(id, "portal_cleared", false)):
		portal.force_open()

## Milestone saves: each signal writes one flag the moment it's earned.
func _wire_saves() -> void:
	var id := config.id
	var banner := _live("RestorationBanner")
	if banner and banner.has_signal("restored"):
		banner.restored.connect(func() -> void: WorldState.mark(id, "restored", true))
	var portal := _live("Portal")
	if portal and portal.has_signal("opened"):
		portal.opened.connect(func() -> void: WorldState.mark(id, "portal_cleared", true))
	var friend := _live("Friend")
	if friend and friend.has_signal("woke"):
		friend.woke.connect(func() -> void: WorldState.mark(id, "friend_awake", true))

## Scene exit (portal cross, New Day, quit): file the scrub progress of an unfinished cove.
func _exit_tree() -> void:
	if _echo:
		return
	if WorldState.is_restored(config.id):
		return
	var oil := get_node_or_null("OilSpill")
	if oil and "current_clean" in oil:
		WorldState.mark(config.id, "cleanliness", oil.current_clean)

## A tunnel crossing brought us here: the axolotl emerges at THIS cove's passage mouth (the left
## edge of the water — you exited the last cove travelling right), already swimming, behind an
## opening iris — the two coves read as one continuous passage.
func _arrive() -> void:
	var axo := $Axolotl as CharacterBody2D
	axo.position = Vector2(config.water_left + 34.0, config.surface_y + 46.0)
	var speed: float = axo.tuning.run_speed if axo.tuning else 150.0
	axo.velocity = Vector2(speed, 0.0)      # still swimming out of the tunnel
	var wipe := IrisWipe.new()
	add_child(wipe)
	wipe.set_closed()
	wipe.open(0.7)

func _inject(n: Node) -> void:
	# has_method guard keeps the scene runnable while components are migrated one at a time
	if n and n.has_method("setup"):
		n.setup(config)

## Per-cove environment overrides (spec §9): the marsh reads green-tea and muddy without forking
## the scene. Water + soil tints ride shader UNIFORMS (the modulate chain also carries the
## day/night CanvasModulate these shaders ignore). ALWAYS written — white when unset — because
## the water ShaderMaterial is a shared sub-resource cached across cove instances, so an estuary
## visit would otherwise leak its green onto the hub's water for the rest of the session.
func _apply_environment() -> void:
	var wt := config.env_water_tint if config.env_water_tint.a > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
	var water := get_node_or_null("Water") as Sprite2D
	if water and water.material is ShaderMaterial:
		(water.material as ShaderMaterial).set_shader_parameter("env_tint", wt)
	var lt := config.env_land_tint if config.env_land_tint.a > 0.0 else Color(1.0, 1.0, 1.0, 1.0)
	for n in ["BlockLand", "BlockLandRight"]:
		var land := get_node_or_null(n)
		if land:
			(land as Node2D).modulate = lt
			if land.has_method("set_env_tint"):
				land.set_env_tint(lt)
