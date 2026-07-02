# Title Veil & Settings — Design (Approach A, approved)

**Date:** 2026-07-01
**Status:** BUILT (2026-07-02, committed 2026-07-02) — verified by headless + real-renderer boot.
Adversarially reviewed (partial fleet — 4/8 agents hit session limits); 3 confirmed findings
fixed: touch-held actions released on scene exit (was: infinite-reload risk), settings flush
on close for keyboard-nudged sliders, rebind capture cancelled on tab switch. Focus handling
added for full gamepad/keyboard menu navigation.
**Context:** Mario wants a title screen and a settings menu (controls / audio / visual), and
declared the game will grow beyond one scene ("this will be a working game"). This supersedes
the game-loop spec's "main.tscn stays the only scene forever" premise: main.tscn becomes the
**app shell** — UI layers live there and survive future level swaps under it.

## Shape

- **The living cove IS the title screen.** `TitleCard` (CanvasLayer 97, in main.tscn) is a
  soft veil over the running cove: title + *begin* + *settings*. Any of jump/spray/ui_accept
  or a tap begins. Skipped on New Day reloads via a session flag on the Settings autoload.
  Nothing pauses — the axolotl idles (and can fall asleep) behind the veil.
- **`Settings` autoload** (`game/hud/settings_store.gd`) — ConfigFile at `user://settings.cfg`.
  Owns: audio bus volumes, visual flags (fullscreen/vsync/grain/vignette), touch mode
  (auto/on/off), custom InputMap bindings (InputEvents serialize into the cfg directly).
  Also owns the session **UI lock** (counter + `ui_lock_changed` signal): while any menu is
  up, gameplay input reads as neutral. Emits `changed`; readers pull.
- **`SettingsMenu`** (CanvasLayer 99, main.tscn, PROCESS_MODE_ALWAYS, code-built) — three
  tabs: **Audio** (Master/SFX/Ambience/Music sliders, live, saved on drag-end), **Controls**
  (per-action keyboard + gamepad rebind via press-capture, reset-to-defaults, touch mode),
  **Visual** (fullscreen, vsync, film grain, vignette). Opened from title or rest card.
- **`RestCard`** (CanvasLayer 97, main.tscn) — Esc / pad Start (`menu` action) pauses the
  tree: *resume / settings / new day / quit* (quit hidden on web). Stops the spray loop on
  pause (physics can't release it once frozen). "New day" triggers NewDay via a `new_day`
  group call — shared restart routine, per the game-loop spec.
- **`postfx.gd`** on the cove's Post rect — remembers authored grain/vignette strengths,
  applies the Settings toggles, re-applies on `changed` and on scene reload (pull-based, so
  reload/level-swap safe).

## Touched files (all additive to gameplay)

New: `settings_store.gd`, `title_card.gd`, `settings_menu.gd`, `rest_card.gd`, `postfx.gd`.
Edited: `main.tscn` (three UI layers), `cove.tscn` (Post gets the script), `project.godot`
(Settings autoload + `menu` action), `axolotl.gd` (input reads neutral under UI lock — no
D-0003 numbers change), `new_day.gd` (`start()` API, group, lock gate), `touch_controls.gd`
(mode from Settings, hides + releases holds under lock), `sfx.gd` (PROCESS_MODE_ALWAYS so
menu ticks survive pause).

## Explicitly not now
Rebind conflict detection (last-write wins v1), audio settings beyond bus volumes,
resolution pickers (stretch mode handles it), persisting title-seen across sessions.
