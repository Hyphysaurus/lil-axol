# Lil Axolotl: Tidekeeper — The Living Watershed (Master Design v2)

**Date:** 2026-07-07
**Status:** Approved direction (Maram), master spec for review
**Supersedes:** `2026-07-06-hub-pond-living-world-design.md` (hub/persistence/frog/marsh
survive; this re-frames the whole world around real ecology + Terra Nil systems)
**Decides:** world framing, restoration model, roster + unlock order, art pipeline,
metroidvania topology, persistence + win, conservation hook

---

## 0. What changed since v1 (why this exists)

v1 gave us a persistent hub-and-spoke world with a companion roadmap. Three inputs since
then reshaped it into something with a real spine:

1. **Ecological accuracy as a pillar** (Maram). A verified-ecology review of the full
   SeethingSwarm catalog found the axolotl *pins the whole game to one real place*.
2. **Terra Nil** (Maram): "emulate those variables and conditions." Restoration becomes a
   **system of chained ecological conditions with habitat recipes**, not a single meter.
3. **Nested-metroidvania traversal + full-pixel art unification** (Maram): Terraria/Noita/
   Hollow Knight density; every spoke a mini-hub with secrets; one pixel grid.

Together these turn a cozy cove-cleaner into **the true story of the axolotl's only home**,
told as a systemic restoration game.

## 1. Pillars

1. **Cozy, no-fail, no-death.** Every system below obeys this. "Dark," "invasive," and
   "antagonist" mean *mystery* and *mess to tidy*, never danger or violence.
2. **Ecological truth.** Wild *Ambystoma mexicanum* lives in exactly one place on Earth —
   the **Xochimilco** canal wetlands of Mexico City (~2240m, temperate freshwater),
   critically endangered (≈6,000/km² in 1998 → ≈35 in 2020) from pollution, urban runoff,
   and **invasive carp + tilapia** that eat its eggs and young. The game IS this story.
3. **Restoration as a system** (Terra Nil): multiple tracked variables, chained thresholds,
   per-species habitat recipes, a multi-condition win. One defining mechanic — Restoration —
   held, but given real depth. (Satisfies the bible's "one mechanic per game.")
4. **Nested metroidvania.** Persistent world of mini-hubs and secret passages; every new
   partner triggers a backtracking wave; puzzles are keyed to the available roster
   (Kirby Star Allies — swap choreography).
5. **One pixel grid.** Full-pixel rendering unifies characters, terrain, water, and light.

## 2. The world — one honest watershed

Not a teleport tour of biomes; **one spring-fed high-altitude Valley-of-Mexico watershed**,
every reach ecologically true and laddering back to axolotl habitat:

| Reach (spoke) | Real basis | Partner anchored | Distinct look |
|---|---|---|---|
| **Canal Hub** (Xochimilco chinampa canals) | the axolotl's true & only home | Turtle (shipped) | open still canals, chinampa banks |
| **Reed Marsh** | canal reed margins | Frog (shipped) | shallow marsh, lilypads, cattails |
| **Open Canals / airspace** | the wide bioindicator water | Dragonfly | broad water, dragonfly swarms |
| **Creek / River connector** | the canal's upstream watershed (Sierra runoff) | Otter | flowing water, weirs, log jams |
| **Spring-Grotto** | Xochimilco's real *manantiales* (spring sources) | Bat | dark cave, glow, the water source |
| **Chinampa Farm-edge / Headland** | the 1000-yr cultural wetland | *(citizens only)* | willows, farm plots, coastal bluff |

The **Canal Hub** is the persistent home; each spoke is itself a mini-hub with secret
chambers. Restoring an upstream reach visibly improves the water flowing into the hub.

## 3. Restoration as a system (the Terra Nil core)

### 3.1 Reach state — the tracked variables

Each reach owns an ecological state (all 0..1), replacing the single cleanliness float:

- **Toxicity** — oil/urban runoff on the surface & substrate.
- **Oxygen** — dissolved O₂; smothered by algae mats & stagnation.
- **Clarity** — water transparency; wrecked by carp stirring silt (turbidity).
- **Invasive ratio** — share of biomass that is tilapia/carp.
- **Vegetation** — native aquatic plants (reeds on mud, **eelgrass** in clear shallows).

These are authored per-reach in `CoveConfig` (starting values + which are "in play") and
persisted in `WorldState`. The old `cleanliness` becomes a *derived read* (weighted blend)
for legacy consumers (banner, grass-growth) during migration, then those consumers move to
reading specific variables.

### 3.2 Verbs move variables (this is what makes each partner non-redundant)

| Actor | Verb | Moves | Ecology |
|---|---|---|---|
| Axolotl (player) | **Spray** | Toxicity ↓ | restoration "magic" scrubs runoff |
| Axolotl (player) | **Bubble bomb** | Toxicity ↓ (area) + breaks rubble | traversal + big clears |
| Turtle | **Break** | removes hard debris blocking flow → enables Oxygen ↑ | mud turtle clears the bed |
| Frog | **Consume** | algae mats & mosquito larvae ↓ → Oxygen ↑ | leopard frog eats pests |
| Dragonfly | **Survey** | *reveals hidden sources*; its presence *reads* Oxygen | odonate bioindicator |
| Otter | **Herd** | Invasive ↓ → Clarity ↑ (herds carp/tilapia to the refugio) | the real fisher-sweep fix |
| Otter | **Haul** | relocates heavy sunken debris to sockets → restores Flow | river otter |
| Bat | **Echosong** | reveals hidden things in the dark grotto; wakes glow-moss | echolocation |

**Vegetation is not a verb** — it's a *recipe outcome*: eelgrass grows where
`Clarity ≥ 0.7 AND Toxicity ≤ 0.2`; reeds where the mud bank is clean. (This retires the
old "dragonfly pollination/Bloomdust" verb — dragonflies don't pollinate; regrowth is
systemic, matching Terra Nil's "green appears when conditions are met.")

### 3.3 Chains & thresholds (conditions gate conditions)

Restoration is a cascade, authored as simple threshold rules a designer can read:

```
break/bomb clears hard debris        ─┐
frog eats algae mats                  ├─▶  Oxygen ↑
                                      ─┘
otter herds invasives out  ─▶ Invasive ↓ ─▶ Clarity ↑
(Clarity ≥ .7 & Toxicity ≤ .2)        ─▶ Eelgrass grows
(Oxygen ≥ .6)                          ─▶ Dragonfly larvae hatch → dragonflies return
(Clarity ≥ .6 & fish present)          ─▶ Egret wades in
```

Threshold rules live in a small data table per reach (not scattered `if`s), evaluated on
variable-change — the same event-driven pattern the win banner already uses
(`call_group("restoration", ...)`).

### 3.4 Habitat recipes — wildlife returns by condition, not by %

Each citizen has a recipe (a set of variable thresholds + required vegetation/prey). It
fades in (reusing the existing cleanliness-fade tech) only when ITS recipe holds — so the
returning fauna *reads the state of the water*. Flagship recipes:

- **Dragonflies** ← Oxygen ≥ .6 (larvae need oxygenated water).
- **Egret / heron** ← Clarity ≥ .6 AND native fish present (sight-feeder).
- **Native fish & waterfowl** ← Invasive ≤ .3 AND Oxygen ≥ .5.
- **Axolotl young (THE win)** ← Toxicity ≤ .15 AND Clarity ≥ .75 AND Invasive ≤ .2 AND
  Eelgrass present. See §7.

### 3.5 The invasive fish — central antagonist, cozily handled

Tilapia + carp are the pollution's living face and the reason the axolotl is dying.
- **Art (verified 2026-07-07 sweep):** the best *confirmed* owned stand-in is the **Smolque
  goldfish** (`2D/ocean assets/Pixel_FishPack_smolque.zip`) — a goldfish is a domesticated
  carp, clean black outline closest to the axolotl; recolor murky brown/olive for the carp,
  and the Gnome-Fishing freshwater **bass** silhouette for the tilapia. **Caveat:** all owned
  fish are **static single-frame** → animate schools with a shader wiggle (cheap) or a small
  swim-cycle commission. **PIXEL_1992 Sea Creatures** (577 outlined creatures) is a strong
  *potential* source but is RAR5-locked and could not be verified this session (no extractor
  resolved) — install 7-Zip and eyeball `See Creatures/Black Outline/…` before committing to
  it. Zero-budget path holds; see Appendix A. (Softens, not fully resolves, the ecology
  review's #1 production risk — a proper swim cycle may still want a commission.)
- **Mechanic:** the **otter herds** dense schools into a **refugio** (a mesh-filter channel
  the player restores) — mirroring the real UNAM chinampa-refugio conservation fix. Fish are
  **relocated, never killed** (cozy contract). Carp presence keeps a reach turbid (Clarity
  capped) until herded; tilapia caps Invasive ratio, gating the axolotl-egg recipe.

## 4. The roster

**The axolotl is the protagonist and keystone lens, NOT a swappable partner** — its innate
sense reads reach health (the HUD's baseline). Partners are one-active-at-a-time, swappable
via the shipped `partner_hud` chips.

### 4.1 Partners (ecologically justified; restyles noted)

| # | Partner | Real species | Verb | Restyle needed |
|---|---|---|---|---|
| 1 | Turtle ✅ | **Mexican mud turtle** (*Kinosternon integrum*) | Break | **Yes — critical.** Current green/red slider art *is an invasive species in Mexico*; restyle to a dark, domed mud turtle or the ally is literally an invader. |
| 2 | Frog ✅ | **Montezuma leopard frog** (*Lithobates montezumae*) | Consume | Minor — olive/dark-spotted high-altitude coloration. |
| 3 | Dragonfly | native Odonata | Survey (reveal + bioindicator) | none (owned Dragonflypack) |
| 4 | Otter | **Neotropical river otter** (*Lontra longicaudis*) | Herd + Haul (keystone) | none (Lil Otter) |
| 5 | Bat | native insectivorous bat | Echosong (grotto reveal) | sell as insect-hunter, not fisher |

### 4.2 Unlock order: Turtle → Frog → **Dragonfly → Otter → Bat**

From a 5-order × 3-lens panel, reconciled with the ecology reframing:
- **Dragonfly (3):** teaches "read the ecosystem / find hidden sources" (the loop's missing
  *discover* beat); recruited — not rescued — from the dragonflies that already return to
  healed water in shipped code (`pest_fly.Mode.DRAGONFLY`); marsh-adjacent hot hook; pays for
  the flying-follow plane (reused by bat).
- **Otter (4):** the keystone mid-game beat — introduces the **invasive fish** and the Clarity/
  Invasive variables ("*this* is what's really killing the axolotls"). Anchors the creek
  connector (in-watershed, not a detached river level).
- **Bat (5):** the earned mid-late **dark grotto** (mood curve), revealing the spring *source*
  of the whole watershed. Reuses the flight plane + reveal-registry from dragonfly.
- The panels' one worry — a "D-O rhyme" of two water-raising verbs — **dissolves**: with
  ecological verbs, dragonfly = survey and otter = herd-invasives; different variables, no rhyme.
- **Crow is cut as a partner** (the panels' "Seedwing/replant" verb is now the systemic
  vegetation recipe) and returns as a **citizen** — it's native to the valley.

### 4.3 Citizens (return by recipe, no verb)

Egret/heron (flagship, restyle the "crane" sprite — a sandhill crane at Xochimilco is a
geography error), native duck & waterfowl*, Mexican garter snake*, Mexican Plateau raccoon
(native — a harmless rummager, never an antagonist), crow/raven, white-tailed deer (forest
reach), gray fox (gray, not red), volcano rabbit (highland flavor), owl (dusk, forest/willow),
wild marsh mouse. The **Xoloitzcuintli** dog is a fixed canal-edge NPC cameo — the richest in
the catalog (*a-xolotl* "water-dog" and Xolo both trace to the god **Xolotl**).
*(\* = no catalog pack; commission/backlog — flagship payoff leans on the restyled egret until then.)*

### 4.4 Antagonists (relocated, never harmed)

Invasive **tilapia** (primary) & **carp** (turbidity) — see §3.5. Optional land-edge
opportunists used sparingly and kept visually distinct from their friendly cameos: **feral
hog** (roots banks muddy, flees when restored — distinct from the penned chinampa pig),
**stray cat / feral dog** (urban-encroachment on shore; shoo/coax away — kept mangy/distinct
from the Xolo & any house-cat cameo).

### 4.5 Rejects (ecological tourists — do not use)

Panda (China/bamboo), parrot (tropical lowland — only a caged trajinera pet prop), falcon
(cliffs; the wetland raptor is an osprey/kingfisher), wolf (extirpated, wrong scale, eats the
cast), **hedgehog** (Old World — no American species ever; reskin to a native shrew if a spiky
mascot is wanted), chicken (livestock — farm set-dressing only, never a citizen-with-verb).

## 5. Art unification — full pixel @ 640×360

- **World** renders into a **640×360 SubViewport**, integer-scaled ×2 → 720p / ×3 → 1080p,
  `NEAREST`. One pixel grid for characters, block terrain, water, sky, particles, and light.
- **Shaders quantize to the grid** and to **Apollo** swatches: water, clouds, god-rays,
  oil sheen become chunky-glowing (Animal Well is the proof — Hollow Knight atmosphere on a
  pure low-res grid). Retires the painterly-vs-pixel tension the asset map flagged.
- **HUD/text** stays on native-res CanvasLayers (crisp UI over the pixel world).
- Characters keep their authored sizes; **no runtime fractional scaling of pixel art**
  (see §9 frog rule).

## 6. Nested-metroidvania topology

- **Mini-hubs & secret passages.** Terrain is the 8px block-land system upgraded to a
  **carvable cell mask** (solid/carved drives both the shader *and* generated collision),
  so Terraria-style hidden block pockets become the secret-passage medium. Today `BlockLand`
  is visual-only (one shader quad; collision on a separate Beach body) and per-cell breaking
  lives in `DestructibleRock` — this pass **merges those**: a cell mask that the turtle/bomb
  carve, revealing chambers.
- **Teased locks + backtracking waves.** Early reaches ship **visible-but-unanswerable
  locks** (a chime node high on dry rock; a silt-buried socket; a reed-choked channel) that a
  *later* partner or a *restored variable* finally answers. Every new partner triggers a wave
  across all earlier reaches. **Bat at slot 5 is a tease-generator** — its reveal both answers
  old teases and mints new ones for otter/backtracking to resolve.
- **Roster-swap puzzles (Kirby).** Combos sequence a **persistent-state verb** into an
  **instant verb**: e.g. *turtle breaks a debris plug (persistent) → swap otter, herd the carp
  now reachable (Clarity ↑) → eelgrass recipe fires → egret returns*. Combos only sing because
  verbs move different variables (§3.2).
- **Waterline gates stay pre-authored** scene-state swaps (flood-fill into block basins),
  persisted like `cove_portal`'s `cleared` flag — never a fluid sim; frozen swim tuning
  untouched. Ecologically re-attributed: the otter clearing a flow blockage *raises a
  downstream pool*.

## 7. Persistence & the self-sustaining refugio (leave-no-trace)

- **WorldState** autoload (from v1): `user://world.save` via `ConfigFile` (survives on web via
  IndexedDB). Now stores **per-reach the full variable state** + vegetation + revealed-secrets
  + roster + portals + best scores. Milestone-triggered saves; corrupt/version-mismatch →
  back up to `.bad`, start fresh, never crash. Fresh profile → today's behavior.
- **The win is a recipe, not a %** (§3.4): when the axolotl-young recipe holds AND stays
  stable, **eggs appear**, natives breed, and the reach is **self-sustaining** — you *leave*
  and the persistent world keeps it alive. That is our cozy **leave-no-trace**: nothing to
  dismantle (your tools are living creatures), you remove yourself by moving on. Emotionally
  Terra Nil's "it thrives without me"; ecologically the real chinampa **refugio**.
- **Echo runs** (from v1): a restored reach can be replayed as a scored, transient run
  (re-oiled from config; feats/flow/leaderboard live; world state untouched) — the arcade
  layer's home in a persistent world. Tide Board re-enables on Echo-run completion.

## 8. Conservation hook (opt-in, diegetic, never preachy)

- **Restoration Log / field guide:** each returning citizen unlocks a card — real species
  name, one-line ecology, and for the axolotl its IUCN Critically-Endangered status + the
  collapse figures. The player assembles the real Xochimilco food web through play.
- **Title card:** one quiet line — wild axolotls live in exactly one place on Earth.
- **Credits:** one honest paragraph on *Ambystoma mexicanum*'s plight + a link to a real
  program (e.g. UNAM's axolotl chinampa-refugio work — the refugio the player builds).
- **Steam page:** lead with "the only wild home on Earth" + the invasive-fish story.
- **Tone rule:** facts live in the log/title/credits — **never mid-play dialogue**.

## 9. Frog pivot + marsh (carried from v1, still slice-1)

- **Frog: surface + land only** — never dives. For `Kind.FROG` the follow target's y clamps to
  `surface_y` over water (kicks the surface via `swimforward`, rests `swimidle`, hops land &
  lilypads; tongue works from the surface). No perch AI — the marsh is shallow.
- **Integer scale:** `friend_scale` → **1.0** (estuary 0.7 & library 0.85 retired). Rule for
  all partners: **no runtime fractional scaling of pixel art**; if the frog reads too big, fix
  in art with a one-time integer resize.
- **Marsh = a real biome, not a tint:** keeps instancing `cove.tscn` but gains shallow geometry
  (raise `seabed_y`), a mud-bank islet, and new self-contained set-dressing (lilypads = hop
  perches; reeds/cattails on the `wind_grass` shader; half-sunken log), plus a CoveConfig
  `environment` sub-resource (Apollo-named water/sand/mood overrides) replacing the
  `CanvasModulate` wash.

## 10. Slicing

Ordered to fix-what's-live, then build the system, then expand. Each slice is its own build
(and, where it adds a new spoke/partner, its own detailed spec).

1. **Slice 1 — Foundations** *(no purchases, no new partner)*
   WorldState persistence + Echo runs; frog surface pivot + integer scale; **marsh estuary**
   (geometry, lilypads, reeds, environment overrides); **mud-turtle restyle** (critical
   ecology fix). Establishes the save + biome-identity groundwork.
2. **Slice 2 — The restoration system** *(the Terra Nil core)*
   Convert cleanliness → the **variable/recipe engine** (§3): reach-state variables, threshold
   chains, habitat recipes, verbs re-mapped to variables. Retune the hub + marsh onto it.
   Wire the **invasive fish** (PIXEL_1992 art) as a Clarity/Invasive antagonist even before the
   otter (start as ambient turbidity schools). This is the pillar; it deserves its own spec.
3. **Slice 3 — Art unification** *(640×360 pixel pipeline + Apollo-quantized shaders)*. Can
   run parallel to 2; do before adding new biomes so they're authored native-pixel.
4. **Slice 4 — Dragonfly + open-canal survey** (recruit flow, Survey verb, flying-follow
   plane, reveal-registry). Buy Dragonflypack (owned).
5. **Slice 5 — Metroidvania terrain** (carvable block-land cell mask + secret pockets +
   teased-lock authoring pass across existing reaches).
6. **Slice 6 — Otter + creek + the refugio** (Herd/Haul, invasive relocation to the mesh
   refugio, flow-gate waterline, Clarity system payoff). Buy Lil Otter.
7. **Slice 7 — Bat + spring-grotto** (Echosong reveal, dark-biome lighting, the watershed
   source). Buy Batpack.
8. **Ongoing — Citizens & conservation log** sprinkled as reaches restore (egret/heron
   restyle, Xolo cameo, field-guide cards).

## 11. Testing

- **Save round-trip (headless):** write full reach-variable WorldState → reload tree → assert
  the composition root spawns restored state (variables, vegetation, revealed secrets, roster,
  portals). Version-migration + corrupt-file → `.bad` backup path. Fresh-profile guard =
  today's behavior.
- **Recipe engine (headless):** drive variables across thresholds → assert the right chain
  fires and the right citizens' recipes flip; assert the axolotl-egg win needs ALL four
  conditions (no single-variable shortcut).
- **Verb→variable:** each verb moves only its variable(s); invasive herding lifts Clarity;
  carp presence caps Clarity until herded.
- **Frog:** surface clamp over water; hop on lilypads; tongue still snags; renders 1:1 pixels.
- **Visual review on the live web build** (Mario reviews at lilaxol.vercel.app — editor bridges
  are unreachable from the CLI shell, so visual iteration ships via deploys): pixel pipeline,
  mud-turtle restyle, marsh identity, murky-fish read.

## 12. Open items & honest tension flags

- **Turtle restyle is a pillar-blocker**, not polish — the shipped slider is an invasive
  species; slice 1 fixes it.
- **Two "perceive" partners** (dragonfly survey + bat echosong) are justified only by hard
  biome/traversal separation (daylight open water vs dark grotto). If they still feel same-y in
  play, demote bat to a citizen + keep the grotto reveal as an environmental mechanic.
- **Core citizens lack art** (native duck/waterfowl, garter snake) — flagship "wildlife
  returns" leans on the restyled egret until commissioned.
- **Xolo cameo vs feral-dog antagonist** — keep the friendly dark Xolo fixed and any feral
  pack-dog visually distinct, or drop the dog-antagonist and let cat + hog carry it.
- **Volcano rabbit / owl / bat** are honest only in their reaches (highland meadow / forest
  dusk / grotto), never the open canal.
- **Frog at 1.0 scale** pending Mario's visual check (fallback = art resize).
- **Scope discipline:** this is now a much bigger game than v1. The slices are ordered so each
  is independently shippable to the live build; do not start a spoke slice before its system
  slice (2) lands, or biomes get authored against a meter we're replacing.
- **Bible caveat carried forward:** series doc says "KayKit environments" (3D); the 2D tileset
  reality remains the accepted deviation.

---

## Appendix A — Asset sourcing (owned-first, verified 2026-07-07)

Five parallel library sweeps (props, backdrops, roster, audio, VFX) against the Living
Watershed. Path-verified. **Headline: nearly the whole game is buildable from owned assets;
the only real spend is ~5 SeethingSwarm creature packs, and the only true gaps are the
signature Xochimilco props (trajinera, refugio net) that want bespoke art.**

### A.1 Corrections to earlier memory/spec

- **MossyCavern is NOT crisp pixel** — it's 4096² HD painterly/vector; it clashes with the
  Apollo outlined-pixel look. **Drop the "MossyCavern = grotto" reservation** (two independent
  sweeps confirmed). Use the unTied Games grotto tileset instead (below).
- **Audio lives under `Asset Library/SFX/`** (subfolders `Music/ SFX/ Vocals/`), not `Audio/`.
- **Invasive-fish art** reality corrected in §3.5 (Smolque goldfish, static → shader wiggle).

### A.2 Biggest wins (owned, purpose-fit)

1. **`Asset Library/oilset.png` (+`oilsetalpha.png`, 1536×1024) — a BESPOKE "LIL AXOLOTL
   TILESET"** already in the library, exact target style + Apollo bar baked in: oil slicks,
   barrels, DANGER-OIL signage, a full **derelict oil rig** (crates, ladders, chains, lantern),
   underwater coral/rock ledges, bubbles, land/sand/waterfall. **Covers the entire pollution
   pillar.** Action: audit what's already sliced into the project — the oil-rig / oil-slick
   sections look untapped.
2. **unTied Games "Pixel Art Tileset Collection"** (`2D/Tilesets/Pixel & Dungeon/
   pixelarttilesetcollection/…GDM/`, crisp 8/16px side-view, day/night variants) — one source
   covers most reaches: **`dagogum_cavern`** (spring-grotto: dark cave + glowing blue water =
   the grotto, replaces MossyCavern), **`forest_of_whispers`** (forest-creek: mist + waterline
   + underwater-slope tiles), **`mayclover_meadow`** (canal hub / reed marsh, full day→night),
   **`seaside_cave`**, and **`hydro_plant` + `_toxic`** (a polluted canal-lock "before" state).
   Recolor saturated blues/purples → Apollo. License: unTied royalty-free commercial, credit.
3. **Water/underwater fully covered by owned crisp packs:** Tiny Ocean Complete (37 seaweeds +
   coral parallax + bubbles), Nature Pixel Pack – Ocean (seagrass/shells/stones), and **The
   Myth of Pixel – Water Temple** (Aztec stone waterworks + an animated **pouring-jar statue
   fountain** — a Xochimilco-flavored grotto centerpiece AND a ready leak-source prop).
4. **VFX — Super Pixel Effects Gigapack** (`2D/Super Pixel Effects Gigapack v2.5.0/…`, crisp
   pixel strips): `round_sparkle_burst` (drop-in upgrade to `cleanup_fx.gd`), `round_light_burst`
   (grotto glow / dark-room reveal), bubble bursts, `directional_particle_burst` (pollen/motes
   as water heals), splatters, `symbol_success` (feat-banner pops). Binbun **TransitionKit** is
   the only 2D-safe scene-wipe shader. (Binbun GODOT VFX + loose `.gdshader` = 3D/GPU, skip.)
5. **Restoration-feedback + water SFX — `SFX/SFX/2000_Game_SFX_Collection.zip`** (WATER-BUBBLES-
   SPLASHES, SUCCESS-CHIMES, POPS-BURSTS, VOCAL-CUTE) + **TomMusic Free Fantasy SFX** (River/
   Stream/Waterfall loops, water footsteps, BGS Forest/Cave beds — OGG-ready) + SwishSwoosh
   (pitched UI-fillup for the restoration meter, bubble pops).

### A.3 Per-reach ambient music beds (owned)

- **Canal hub:** Cozy Tunes *Gentle Breeze* / *Evening Harmony* over Abstraction CC0 pad.
- **Reed marsh:** Cozy Tunes *Wildflowers By The River* + TomMusic *Forest Day* BGS (birds/insects).
- **Forest creek:** Cozy Tunes *Sunlight Through Leaves* + TomMusic *River Stream* loop.
- **Spring-grotto:** JDSherbert *Underwater City* + TomMusic *Cave* BGS (drips) — strongest pairing.
- **Xochimilco music nod:** none owned fit (owned Latin = Brazilian bossa/Spanish flamenco/Cuban,
  wrong region + clichéd). Right answer = *son jarocho* (nylon guitar/jarana) or soft marimba —
  source a CC0 loop or commission; don't force the owned tracks.

### A.4 Roster — owned vs buy (SeethingSwarm, ~$12 each, guaranteed style match)

- **Owned:** turtle ✅, frog ✅. Dragonfly = owned loose sheet (`2D/Dragonfly Sprite Sheet.png`,
  ~24px thinner outline — MVP-ok) or buy Dragonflypack for cohesion. Gray fox & bee also owned
  as loose sheets.
- **Must-buy partners (~$24):** **Lil Otter**, **Batpack** — no owned option, core to the roster.
- **Citizen packs (buy as their reach lands, ~$84):** Raccoon, Deer, Owl, Bunny, Mouse, Crow, Dog
  (Xolo recolor); **Crane → repurpose as the egret** (recolor white/shorten). Duck pack existence
  unconfirmed.
- **Recommended spend:** ~$120 core (partners + citizens), ~$156 fully polished (Dragonfly/Fox).
  Zero-budget MVP ships on owned art + the two must-buy partners staggered by slice.

### A.5 True gaps → bespoke / commission (the signature Xochimilco items)

- **Trajinera** (the iconic painted canal boat) — nothing owned; a hand-drawn trajinera would be
  a signature hero prop worth authoring.
- **Refugio netting/mesh** (the conservation-fix centerpiece) & **tires** — not in library.
- **True egret/heron** (only a crane to repurpose), **duck**, **garter snake**, **butterflies**,
  **tadpoles**, and **animated carp/tilapia swim cycles** — commission or trivial hand-sprite.
- **grotto living-glow:** MossyCavern `BlueFlower1/2` glow-plants exist but are hi-res (downscale);
  or author simple glow-moss on the Gigapack `round_light_burst`.

### A.6 Rejected (for the record)

Themed-Packs Swamp/Forest (vector `.ai/.eps`, not pixel), Free_Pond_Kit (3D FBX), Underwater
World platform tileset (HD painterly), all Top-Down/Isometric tilesets (wrong projection),
Binbun GODOT VFX + loose Synty `.gdshader` (3D/GPU), Helton-Yan combat SFX + Human Vocals
(wrong tone).
