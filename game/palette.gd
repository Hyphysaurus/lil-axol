class_name Palette
extends RefCounted
## Apollo (AdigunPolack, lospec.com/palette-list/apollo) — the game's master colour set, for
## GDScript-driven visuals: particles, sprite tints, the UI theme. It MIRRORS shaders/apollo.gdshaderinc
## so code and shaders draw from the exact same palette. Values are the hex codes normalised to 0..1
## (the Compatibility renderer is sRGB end-to-end, so no linear conversion is needed).
##
## Migrated from Sweetie 16: the ORIGINAL 16 names are kept (INK..PLUM) and re-pointed to their
## closest Apollo role, so every existing reference stays valid. Apollo's extra range then adds the
## things Sweetie lacked — a real EARTH ramp (SOIL..SAND), deeper FOLIAGE, warm EMBER/AMBER, sea-life
## PINK, and more water depth (AQUA/ABYSS).
##
## Usage: Palette.CORAL, Palette.CYAN, Palette.LOAM, ... — never hand-type a Color() literal for game
## visuals; reach for a named swatch here so everything stays on-palette from one place.
##
## The numeric form (not Color("hex")) is used so each entry is a compile-time constant; the hex
## code is kept in the comment for reference. Keep this file in step with the shader include.

# --- Neutrals (darkest ink -> near-white foam) ---
const INK   := Color(0.035, 0.039, 0.078)  # #090a14  darkest ink-navy
const SLATE := Color(0.125, 0.180, 0.216)  # #202e37  dark slate
const STEEL := Color(0.341, 0.447, 0.467)  # #577277  steel grey-teal
const MIST  := Color(0.659, 0.710, 0.698)  # #a8b5b2  pale mist
const FOAM  := Color(0.922, 0.929, 0.914)  # #ebede9  near-white

# --- Water (bright surface -> deep) ---
const AQUA  := Color(0.643, 0.867, 0.859)  # #a4dddb  pale surface aqua
const CYAN  := Color(0.451, 0.745, 0.827)  # #73bed3  bright water
const SKY   := Color(0.310, 0.561, 0.729)  # #4f8fba  sky blue
const BLUE  := Color(0.235, 0.369, 0.545)  # #3c5e8b  mid blue
const DEEP  := Color(0.145, 0.227, 0.369)  # #253a5e  deep blue
const ABYSS := Color(0.090, 0.125, 0.220)  # #172038  deepest navy
const TEAL  := Color(0.224, 0.290, 0.314)  # #394a50  muted dark teal

# --- Foliage (deep forest -> pale sprout) ---
const MOSS   := Color(0.145, 0.337, 0.180) # #25562e  deep forest
const GREEN  := Color(0.275, 0.510, 0.196) # #468232  green
const FERN   := Color(0.459, 0.655, 0.263) # #75a743  fern
const LEAF   := Color(0.659, 0.792, 0.345) # #a8ca58  light leaf-green
const SPROUT := Color(0.816, 0.855, 0.569) # #d0da91  pale sprout

# --- Earth (dark loam -> pale sand) — Sweetie 16 had no real browns ---
const SOIL := Color(0.302, 0.169, 0.196)   # #4d2b32  dark loam
const LOAM := Color(0.478, 0.282, 0.255)   # #7a4841  loam
const CLAY := Color(0.678, 0.467, 0.341)   # #ad7757  warm clay
const SAND := Color(0.843, 0.710, 0.580)   # #d7b594  pale sand

# --- Warm (ember -> gold) ---
const EMBER := Color(0.745, 0.467, 0.169)  # #be772b  deep ember-orange
const AMBER := Color(0.871, 0.620, 0.255)  # #de9e41  amber
const GOLD  := Color(0.910, 0.757, 0.439)  # #e8c170  warm gold

# --- Reds & pinks (sea life, the burning title) ---
const ROSE    := Color(0.647, 0.188, 0.188) # #a53030  rose-red / ember base
const CORAL   := Color(0.812, 0.341, 0.235) # #cf573c  coral/orange
const PLUM    := Color(0.251, 0.153, 0.318) # #402751  dark plum
const PINK    := Color(0.776, 0.318, 0.592) # #c65197  bright pink
const BLOSSOM := Color(0.875, 0.518, 0.647) # #df84a5  pale blossom
