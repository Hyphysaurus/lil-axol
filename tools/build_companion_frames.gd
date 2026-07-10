extends SceneTree
## Build SpriteFrames .tres for companion packs from their strip PNGs — the frog pipeline, made
## reusable (Living Watershed: every partner arrives this way). Slices <prefix><anim>_stripN.png
## into AtlasTextures (frame = width/N x height), names each animation <anim>, applies the house
## fps/loop conventions, and saves via ResourceSaver so UIDs bake correctly.
##
## Run (import the PNGs first so load() resolves):
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_companion_frames.gd

const JOBS := [
	{ "dir": "res://assets/critters/dragonfly", "prefix": "dragonfly01_", "out": "res://game/companion/dragonfly_frames.tres" },
	{ "dir": "res://assets/critters/otter", "prefix": "lilotter_", "out": "res://game/companion/otter_frames.tres" },
]

## fps by anim token; anything absent runs at the house default 12 (matches the frog/turtle .tres).
const FPS := {
	"idle": 8.0, "idle_blink": 8.0, "sleep": 6.0, "sit": 8.0, "liedown": 8.0, "crouch": 8.0,
	"swim_idle": 6.0, "fly_idle01": 10.0, "fly_idle02": 10.0,
	"attack": 14.0, "swim": 10.0, "dash": 16.0,
}
## One-shots don't loop; locomotion and idles do.
const ONE_SHOT := ["attack", "die", "fright", "hurt", "land", "jump", "crouch"]

func _init() -> void:
	var fails := 0
	for job in JOBS:
		if not _build(job.dir, job.prefix, job.out):
			fails += 1
	quit(1 if fails > 0 else 0)

func _build(dir_path: String, prefix: String, out_path: String) -> bool:
	var d := DirAccess.open(dir_path)
	if d == null:
		push_error("build_companion_frames: missing dir " + dir_path)
		return false
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var rx := RegEx.create_from_string("^" + prefix + "(.+)_strip(\\d+)\\.png$")
	var files := Array(d.get_files())
	files.sort()
	var built := 0
	for f in files:
		var m := rx.search(f)
		if m == null:
			continue
		var anim: String = m.get_string(1)
		var n := int(m.get_string(2))
		var tex: Texture2D = load(dir_path + "/" + f)
		if tex == null:
			push_error("build_companion_frames: unimported texture " + f + " (run --import first)")
			return false
		var fw := int(tex.get_width() / float(n))
		sf.add_animation(anim)
		sf.set_animation_speed(anim, FPS.get(anim, 12.0))
		sf.set_animation_loop(anim, not ONE_SHOT.has(anim))
		for i in n:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, tex.get_height())
			sf.add_frame(anim, at)
		built += 1
	var err := ResourceSaver.save(sf, out_path)
	print(("OK   " if err == OK else "FAIL ") + out_path + "  (" + str(built) + " anims)")
	return err == OK and built > 0
