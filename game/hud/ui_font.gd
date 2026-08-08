class_name UiFont extends RefCounted
## One source of truth for LilAxol's type — the companion to UiTheme, which already does this
## job for colour. Every card, banner, meter and hint asks for a face and a size HERE instead of
## preloading its own, so the entire game re-types by editing this one file.
##
## ── Why this file exists at all ──
## It didn't, and the cost showed. `LilitaOne.ttf` was preloaded ad hoc in nine separate scripts,
## while the project-wide default was set in project.godot and nowhere else — so "what face is
## this game set in" had ten answers, and the sizes (15, 18, 19, 20, 22, 24, 25, 26, 28, 30…)
## were chosen one card at a time. There was no scale, only a pile of numbers.
##
## ── Why the old default face had to go ──
## The default was `Axolotl.ttf`, and it could not draw the punctuation this game's own writing
## uses. Its cmap carries 356 codepoints and is missing — … → ≈ ↓ ≤. The em-dash is the house
## punctuation of this codebase; TWENTY-ONE user-facing strings contained a glyph it lacked, and
## on the live build they rendered as tofu boxes: "Oreochromis / Cyprinus ▯ introduced",
## "gold ring ▯ you are here". It also shipped with NO licence of any kind — no LICENSE, no
## README, no metadata terms — which made it the last unresolved provenance question on the
## portfolio that features this game first and largest.
##
## ── The three roles ──
## DISPLAY  LilitaOne  — the wordmark, the big banners, the "+N" shine pops. Unchanged: it is the
##                       game's established chunky voice and it has the em-dash.
## HEADING  Maven Pro  — card titles, menu headings, buttons. Flared stems and a humanist
##                       lowercase give the interface a second voice; pairing LilitaOne with
##                       another ROUND face would have read as one blurry family.
## TEXT     Rubik      — everything you actually read: body copy, species lines, tallies, the map
##                       legend. Chosen for the 15px line specifically, which is where the tally
##                       and legend live, over a bright moving sky. It is the sturdiest face at
##                       that size of everything tried.
##
## Both new faces are SIL OFL 1.1 (licences sit beside them in assets/fonts/), both were already
## in Maram's own library, and both cover every glyph the game writes — including the Spanish
## accents the Californio reach names may yet want.

const DISPLAY: FontFile = preload("res://assets/fonts/LilitaOne.ttf")
const HEADING: FontFile = preload("res://assets/fonts/MavenPro-Medium.ttf")
const TEXT: FontFile = preload("res://assets/fonts/Rubik-Regular.ttf")
## Rubik's heavier cut, for the few places body text sits on a bright or busy ground.
const TEXT_STRONG: FontFile = preload("res://assets/fonts/Rubik-Medium.ttf")

## ── The scale ──
## Sizes the cards had already settled on, named and deduplicated rather than re-invented: the
## old set ran 15/16/17/18/19/20/22/24/25/26/28/30 with no rule behind it. These are the ones
## that were doing real work, so nothing on screen has to move for the scale to exist.
const WORDMARK := 76   # the title veil only
const BANNER := 52     # restoration / feat banners
const TITLE := 30      # card and overlay headings
const SUBTITLE := 28   # the field guide's species headline
const BUTTON := 24     # every button label
const BODY := 19       # the sentence you read
const LABEL := 18      # secondary lines beside body
const CAPTION := 15    # tallies, legends, the small print

## Set a Control's face and size in one call, so no card hand-rolls the pair.
static func apply(node: Control, font: FontFile, size: int) -> void:
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)

## The same for a Button, whose theme keys are the plain ones but which UiTheme also styles.
static func apply_button(b: Button, size: int = BUTTON) -> void:
	apply(b, HEADING, size)

## RichTextLabel keeps its own key names — the credits card is the one consumer.
static func apply_rich(r: RichTextLabel, font: FontFile, size: int) -> void:
	r.add_theme_font_override("normal_font", font)
	r.add_theme_font_size_override("normal_font_size", size)
