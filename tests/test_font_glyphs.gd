extends SceneTree
## Every character the game writes, against every face that has to draw it.
##
## This suite exists because the game shipped tofu boxes to players for weeks and no test, no
## validator and no code review saw them. The default face (Axolotl.ttf) carried 356 codepoints
## and lacked the em-dash — the house punctuation of this codebase — so twenty-one user-facing
## strings rendered a hollow rectangle where a dash belonged:
##
##     "Oreochromis / Cyprinus ▯ introduced"
##     "gold ring ▯ you are here · pearl ▯ restored"
##
## Nothing about that is visible in code review: the SOURCE is correct, the string is correct,
## and the failure happens in the rasteriser. The only place it can be caught mechanically is
## here, by asking each font whether it owns the glyph.
##
## ⚠ IT SCANS THE REAL SOURCE, not a hand-kept list of characters. A list would be another thing
## to forget to update the day someone types a new symbol into a hint; the point is to make the
## check impossible to drift from the copy it is checking.
##
## Run: & $godot --headless --path . --script res://tests/test_font_glyphs.gd

const FACES := {
	"LilitaOne (display)": "res://assets/fonts/LilitaOne.ttf",
	"Maven Pro (heading)": "res://assets/fonts/MavenPro-Medium.ttf",
	"Rubik (text)": "res://assets/fonts/Rubik-Regular.ttf",
	"Rubik Medium": "res://assets/fonts/Rubik-Medium.ttf",
}

## Where the player-facing words live. Comments in these files are scanned too — that is
## deliberate and cheap: a comment's arrow costing us one extra glyph in a font is a far better
## trade than a missed string.
const SOURCE_DIRS := ["res://game"]

## ASCII is assumed present in any real font; it is the symbols that get people.
func _interesting(c: String) -> bool:
	return c.unicode_at(0) > 0x7E

func _collect_strings(path: String, out: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var line_no := 0
	while not f.eof_reached():
		var line := f.get_line()
		line_no += 1
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue                       # a comment's symbols are not drawn
		# Every double-quoted run on the line.
		var parts := line.split("\"")
		for i in range(1, parts.size(), 2):
			for c in parts[i]:
				if _interesting(c) and not out.has(c):
					out[c] = "%s:%d" % [path.get_file(), line_no]
		f = f            # keep the handle alive for the loop
	f.close()

func _walk(dir_path: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				_walk(full, out)
		elif name.ends_with(".gd"):
			_collect_strings(full, out)
		name = d.get_next()
	d.list_dir_end()

func _init() -> void:
	var fails := 0
	var checks := 0

	var used := {}                       # character -> where it was first seen
	for dir_path in SOURCE_DIRS:
		_walk(dir_path, used)

	var chars := used.keys()
	chars.sort()
	print("Scanned the game's strings: %d non-ASCII character(s) in player-facing copy" % chars.size())
	if chars.is_empty():
		push_warning("no non-ASCII characters found at all — the scanner has probably broken")
		fails += 1

	for face_name in FACES:
		var path: String = FACES[face_name]
		if not ResourceLoader.exists(path):
			printerr("  ✗ %s: missing at %s" % [face_name, path])
			fails += 1
			continue
		var font: FontFile = load(path)
		var missing: Array[String] = []
		for c in chars:
			checks += 1
			# get_supported_chars() is the font's own cmap, which is the thing that decides
			# whether a glyph or a hollow box gets rasterised.
			if not font.get_supported_chars().contains(c):
				missing.append("%s (first used %s)" % [c, used[c]])
		if missing.is_empty():
			print("  ✓ %s draws all %d" % [face_name, chars.size()])
		else:
			printerr("  ✗ %s cannot draw: %s" % [face_name, ", ".join(missing)])
			fails += missing.size()

	print("test_font_glyphs: %d check(s), %d failure(s)" % [checks, fails])
	if fails > 0:
		printerr("FAILED: a shipping face cannot draw a character the game writes")
	quit(1 if fails > 0 else 0)
