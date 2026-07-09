extends Node
## WorldState — the persistent world memory (Living Watershed spec §7). One ConfigFile at
## user://world.save (IndexedDB-backed on web, so lilaxol.vercel.app keeps saves): a section per
## cove keyed by CoveConfig.id, plus a meta section for versioning. Writes are milestone-driven
## (the cove root calls mark() on rescue/portal/restore and on scene exit) — never per-frame.
## Corrupt or future-versioned files are quarantined to `<file>.bad` and replaced with a fresh
## store: never crash, never silently clobber the evidence (spec §7).

const SAVE_VERSION := 1

## Injectable for tests; the game always uses the default.
var save_path := "user://world.save"

## SESSION flags (not persisted):
## echo — the next scene load is an ECHO RUN (score replay of a restored cove): the root skips
## applying saved state and suppresses saves, so the world stays untouched (spec §7).
var echo := false
## current_id — the live scene's cove id, set by the cove root (New Day reads it).
var current_id := ""

var _cfg := ConfigFile.new()

func _ready() -> void:
	load_file()

## Load (or re-load) the store. Missing file = fresh defaults; unreadable or future-versioned
## file = quarantine + fresh.
func load_file() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(save_path):
		var err := _cfg.load(save_path)
		var v := int(_cfg.get_value("meta", "version", SAVE_VERSION)) if err == OK else SAVE_VERSION + 1
		if err != OK or v > SAVE_VERSION:
			_quarantine()
	_cfg.set_value("meta", "version", SAVE_VERSION)

func _quarantine() -> void:
	var abs := ProjectSettings.globalize_path(save_path)
	# keep the evidence: copy to .bad then remove the original (rename_absolute proved unreliable
	# for user:// paths on Windows — copy+remove has the same effect and works everywhere)
	DirAccess.copy_absolute(abs, abs + ".bad")
	DirAccess.remove_absolute(abs)
	_cfg = ConfigFile.new()

func get_cove(id: String, key: String, default: Variant) -> Variant:
	return _cfg.get_value("cove_" + id, key, default)

## Set one per-cove value and flush to disk. Milestone-cadence only — never call per frame.
func mark(id: String, key: String, value: Variant) -> void:
	_cfg.set_value("cove_" + id, key, value)
	_cfg.save(save_path)

func is_restored(id: String) -> bool:
	return bool(get_cove(id, "restored", false))
