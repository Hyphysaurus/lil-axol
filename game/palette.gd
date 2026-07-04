class_name Palette
extends RefCounted
## Sweetie 16 (GrafxKid) — the game's master colour set, for GDScript-driven visuals: particles,
## sprite tints, the UI theme. It MIRRORS shaders/sweetie16.gdshaderinc so code and shaders draw
## from the exact same 16 colours. Values are the hex codes normalised to 0..1 (the Compatibility
## renderer is sRGB end-to-end, so no linear conversion is needed).
##
## Usage: Palette.CORAL, Palette.CYAN, ... — never hand-type a Color() literal for game visuals;
## reach for a named swatch here so everything stays on-palette from one place.
##
## The numeric form (not Color("hex")) is used so each entry is a compile-time constant; the hex
## code is kept in the comment for reference. Keep this file in step with the shader include.

const INK   := Color(0.102, 0.110, 0.173)  # #1a1c2c  darkest navy
const SLATE := Color(0.200, 0.235, 0.341)  # #333c57  dark slate
const STEEL := Color(0.337, 0.424, 0.525)  # #566c86  steel grey-blue
const MIST  := Color(0.580, 0.690, 0.761)  # #94b0c2  pale mist
const FOAM  := Color(0.957, 0.957, 0.957)  # #f4f4f4  near-white
const CYAN  := Color(0.451, 0.937, 0.969)  # #73eff7  bright cyan
const SKY   := Color(0.255, 0.651, 0.965)  # #41a6f6  sky blue
const BLUE  := Color(0.231, 0.365, 0.788)  # #3b5dc9  royal blue
const DEEP  := Color(0.161, 0.212, 0.435)  # #29366f  deep blue
const TEAL  := Color(0.145, 0.443, 0.475)  # #257179  dark teal
const GREEN := Color(0.220, 0.718, 0.392)  # #38b764  green
const LEAF  := Color(0.655, 0.941, 0.439)  # #a7f070  light leaf-green
const GOLD  := Color(1.000, 0.804, 0.459)  # #ffcd75  warm gold
const CORAL := Color(0.937, 0.490, 0.341)  # #ef7d57  coral/orange
const ROSE  := Color(0.694, 0.243, 0.325)  # #b13e53  rose-red
const PLUM  := Color(0.365, 0.153, 0.365)  # #5d275d  dark plum
