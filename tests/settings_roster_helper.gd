extends RefCounted
## Tiny indirection so tests/test_companion_survey.gd — the direct `--script` target, which under
## `--headless --script` is parsed by Godot BEFORE SceneTree.initialize() registers autoloads as
## GDScript globals — never carries a literal `Settings` identifier in its own source. Mirrors
## tests/reach_map_worldstate_helper.gd's rationale exactly, aimed at the Settings autoload
## instead of WorldState. Loaded lazily via load() from inside the test's first _process().

static func reset() -> void:
	Settings.roster_reset()

static func add(kind: int) -> void:
	Settings.roster_add(kind)

static func active() -> int:
	return Settings.run_active
