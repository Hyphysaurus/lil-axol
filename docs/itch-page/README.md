# Tidekeeper — itch.io page kit

Everything needed to put this on itch. Same shape as Koma's and Burning Bridges'
kits. Nothing here uploads itself — itch needs a logged-in browser, so the last
mile is yours.

## What's in the box

| File | What it's for |
|---|---|
| `page-plain.txt` | Paste into **Edit game → Details**. itch's editor is WYSIWYG, not markdown, so this is deliberately plain. |
| `page.md` | Markdown mirror of the same copy. |
| `images/cover.png` | 630×500 — itch's cover image. **Required.** |
| `images/banner.png` | 1280×400 page banner. |
| `images/screenshot-*.png` | Four 1280×720 page screenshots. |
| `../../build/tidekeeper-itch.zip` | 23.1 MB, `index.html` at the root. **This is the upload.** |

## Upload steps

1. itch.io → **Dashboard → Create new project**.
2. **Kind of project: HTML.** This matters — anything else hides the embed options.
3. Upload `build/tidekeeper-itch.zip`, then tick **"This file will be played in
   the browser"** on that file. Without it you've published a download.
4. **Embed options → Manually set size: `1280 × 720`.** The effect grid is
   640×360, so 1280×720 is an exact 2× and every pixel lands square. Anything
   that isn't 16:9 letterboxes. Tick **fullscreen button**.
5. Cover image → `images/cover.png`.
6. Paste `page-plain.txt` into the description.
7. Suggested tags: `godot`, `pixel-art`, `platformer`, `cozy`, `nature`,
   `exploration`, `singleplayer`, `2d`.
8. Set it **Public**, then send me the URL — the portfolio's Tidekeeper card
   currently points at `lilaxol.vercel.app` and could point at itch instead, or
   carry both.

## About this build

**This is the existing `build/lilaxol/` export — the one already live at
lilaxol.vercel.app — not a fresh one.** That's deliberate. HEAD only adds a test
suite and a docs true-up on top of what's deployed, but the working tree carries
**uncommitted Batch C work** (`game/world/reach_registry.gd`, the door-signage
changes to `cove_portal.gd`, two test files). Re-exporting now would have shipped
unreviewed work to itch and made the itch build differ from the live link. When
Batch C lands, re-export and replace the upload:

```
"/mnt/d/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" \
  --headless --path "C:/Users/maram/Dev/GODOT PROJECTS/LilAxol" \
  --export-release "Web" build/lilaxol/index.html
```

The zip is assembled from a **staged copy**, not the raw folder — `build/lilaxol/`
also contains `.vercel/` (which holds your project and org IDs), `vercel.json` and
Godot's `.import` sidecars. None of that belongs in a public upload.

Verified headless before packaging: Godot 4.7 boots, zero console errors, the
canals render and take input.

## Two things worth fixing separately

- **The repo's root `README.md` and `LICENSE` are SmartShape2D's**, not this
  project's — the addon's files are sitting at the repo root. Anyone landing on
  `Hyphysaurus/lil-axol` reads a plugin's README, and the LICENSE file states a
  license for someone else's code.
- **The addons aren't credited in-game.** `rmsmartshape` (SmartShape2D),
  `softbody2d` and `lit` all ship in the build; SmartShape2D is MIT, which asks
  that the notice travel with distributions. The credits card lists art and audio
  but no addons. Not urgent, but it's the same honesty the rest of that card has.

## Still worth doing

Screenshots come from scripted headless play, so they're honest but not chosen —
all four are the canals at 0% restored. The game's best argument is a **restored**
reach, where the seabed blooms back, and no script is going to play its way
there. Worth replacing two of these with shots from a real session.
