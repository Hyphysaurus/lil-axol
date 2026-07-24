# Character Setups Polish — Rescue Moments, Partner Flow, Presence, Plumbing

**Date:** 2026-07-24 · **Status:** approved scope (Maram picked all four areas; ruled
"do it all headlessly since I'm in game" — autonomous run, headless gates, design calls
recorded here in lieu of the interactive review gate).

## Why

The companions work mechanically (rescue → roster → Kirby-rule verbs → travelling party) but
read as systems, not characters: waking a friend has no ceremony, a new rescue silently steals
the active slot from the partner you were using (the open slice-4 ruling), followers snap and
sit lifelessly, and adding the otter/bat (slice 6/7) means re-deriving the setup path each time.
Four bounded fixes, one spec.

## A. The Waking — rescue ceremony

When a sleeping friend wakes (spray rescue, `companion._wake`):

- **RescueCard** (`game/hud/rescue_card.gd`, new CanvasLayer at the cove root, hints-style
  bottom-center panel, UiTheme, NON-blocking, auto-fades ~4s): line 1 `“<Name> the <Species>
  joins you!”`, line 2 the verb teach (e.g. shell: `“Hold <prompt> to pilot the spinning
  shell.”`). Data comes from CompanionLibrary (section D) — no hardcoded strings in the card.
  Fired from the `woke` signal via group lookup (banner idiom: self-wired, touches no gameplay).
  **Shell integration**: the card is HUD — its node name must join `cove.gd`'s `KEEP_AT_ROOT`
  list (and the node be added to cove.tscn's HUD block) or the pixel shell will pull it into the
  320-grid world viewport.
- **Wake pop**: on `_wake`, the companion sprite does a small stretch-squash pulse before the
  follow starts (sprite-only; the existing `fright` startle stays).
- The existing `wake_up` feat, Field Guide encounter cards, and WorldState marks are untouched
  (the card is a moment layer, not a replacement).
- Travellers arriving via `setup_traveller` do NOT fire the card (they were already rescued).

## B. Active-partner ruling (record as D-0019)

**A rescue no longer steals the active slot.** `Settings.roster_add(kind)` keeps the current
`run_active` and claims the slot only when none is set (`run_active == -1`) — i.e., it adopts
`roster_include`'s polite semantics; the two collapse into one behavior (keep both names, one
implementation, so persistence call-sites stay untouched). Rationale: the slice-4 final review
flagged the steal (rescuing the estuary frog silences the turtle's shell until a chip swap);
player expectation is "my current partner keeps working." The new friend still joins the roster
and its chip appears.

- **Chip glint**: `partner_hud.gd` pulses the newly added chip (~3s glow) so the join is seen.
- **Swap teach**: first time the roster reaches 2, a one-time hint (hints.gd `nudge`) teaches
  the chip tap / swap.
- Echo runs and persistence paths are unaffected (they already use include/derive semantics).

## C. Follow & presence feel (sprite/feel only — movement tuning untouched, D-0003)

- **Spring-smoothed slots**: follower position easing gains a critically-damped spring
  (`game/fx/spring.gd`, preload pattern) on the slot offset so direction flips glide instead of
  snapping. The >300px re-fan hard snap STAYS (it is deliberate, slice-5 playtest note).
- **Idle presence**: when the player idles (>~2s still), followers settle — face the player and
  play their idle-variant clips (`idle_blink` / croak etc., whatever their CharacterAnimSet
  maps) on staggered per-follower timers so they never sync up.
- **Sleeping readability**: sleeping friends emit a few slow FOAM/MIST "zzz" motes
  (CPUParticles2D, ~3 amount, subtle) so a sleeper reads as rescuable from across the reach.
  Motes stop on wake.

## D. Plumbing — CompanionLibrary as the single character record

- Extend each CompanionLibrary entry to the full character record: frames, anims, scale
  (integer rule), **display_name**, **species line**, **verb name**, **verb teach line**
  (RescueCard line 2 + hint text). One place to author a character; RescueCard, hints, and any
  future UI read it. Otter/bat land by filling one record (art already registered for otter).
- Names (Maram can re-flavor later; ship with): Turtle **“Tola”** (Mexican mud turtle), Frog
  **“Meno”** (Montezuma leopard frog), Dragonfly **“Zuni”** (darner dragonfly), Otter
  **“Nutria”** (placeholder until slice 6). Species lines follow the watershed ecology memory.
- **New headless suite `tests/test_companion_library.gd`**: every registered kind — frames
  resource loads, every anim in its set resolves against the frames' clips, scale == 1.0,
  display_name/species non-empty; verb fields may be empty only for verb-less kinds (otter
  until slice 6). Plus `roster_add` no-steal unit checks (pure Settings math).

## Out of scope

New verbs/otter gameplay (slice 6), stage-look polish and unlock-flow work (their own upcoming
specs), any movement tuning, Field Guide card content changes, reach 2.

## Testing & rollout

Headless only this pass (Maram is in-game): all 12 existing suites + the new library suite
green, boot lint clean on all three wrappers. SDD per-task review; final whole-branch review;
then export + deploy to lilaxol.vercel.app + push (Maram sees it on next full reload).
