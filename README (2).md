# Heavensunder

My Roblox game. Current version: **v0.4.1** (`Heavensunder.rbxl`).

You only need **Level 1**. Levels 2 and 3 are extras for later. Nothing breaks if you never use them.

---

## Level 1: play and edit in Roblox Studio (no tools needed)

1. Double-click **`Heavensunder.rbxl`**. It opens in Roblox Studio.
2. Edit as usual, then save with **File → Save to File** (keep the name `Heavensunder.rbxl`).
3. Upload the new file to GitHub (see "Updating GitHub" below).

**If you changed a script in Studio:** also copy the script text into the matching file in `scripts/`,
so the AI sees the newest version. (The folders in `scripts/` have the same names as the Explorer in Studio.)

### Asking an AI for help
- Upload or link **`NOTES_FOR_AI.md`** first. It explains the game to the AI.
- For questions about the world, models or positions, also give it **`place_overview.txt`**. That's the whole
  place written as text, because AIs can't read `.rbxl` files directly.
- For script questions, give it the script file from `scripts/`.
- **`Heavensunder_explorer.html`**: open it in your browser to look through the place like Studio's Explorer
  (search, properties, script code). You can use it on a computer without Studio.

---

## Updating GitHub (website, no git needed)

1. Open your repository on github.com.
2. **Add file → Upload files**. Drag in the changed files (for example `Heavensunder.rbxl`).
   Files with the same name are replaced.
3. Click **Commit changes**. GitHub keeps every old version, so you can always go back.

First upload: drag in the **contents** of the `Heavensunder` folder (not the zip).
If GitHub complains about too many files, upload one folder at a time.

---

## Level 2 (optional): Rojo, which puts the `scripts/` files into Studio automatically

Use this if you want to edit scripts in VS Code instead of Studio.

1. Install **Rokit** (it installs Rojo and Lune for you): https://github.com/rojo-rbx/rokit
   - Windows: download the newest `rokit-...-windows-x86_64.zip` from the Releases page, unzip it,
     double-click `rokit.exe` once, then restart your computer (or at least the terminal).
   - Mac/Linux: run the install command from the Rokit page in a terminal.
2. Open a terminal **in this folder** (Windows: open the folder, type `cmd` in the address bar, press Enter).
3. Run these once:
   ```
   rokit install
   rojo plugin install
   ```
4. Every time you work:
   - Open `Heavensunder.rbxl` in Studio.
   - In the terminal run `rojo serve`.
   - In Studio: **Plugins → Rojo → Connect**.

   Now saving a file in `scripts/` updates the script in Studio right away. Models are not touched.
5. Save the place in Studio when you're done (File → Save to File).

---

## Level 3 (optional): Lune tools

After `rokit install` (Level 2, step 1–3) you can run these in a terminal in this folder:

| Command | What it does |
|---|---|
| `lune run lune/rbxl_to_text.luau` | Makes `place_overview.txt` again (do this after changing the place, so the AI's copy is up to date) |
| `lune run lune/rbxl_to_html.luau` | Makes `Heavensunder_explorer.html` again |
| `lune run lune/pull_scripts.luau` | Copies all scripts **from** `Heavensunder.rbxl` **into** `scripts/` |
| `lune run lune/build.luau` | Puts the `scripts/` files into the place, saved as `build/Heavensunder.rbxl` |
| `lune run lune/inspect.luau tree Workspace 2` | Shows the place as a tree in the terminal |
| `lune run lune/inspect.luau find Lantern` | Finds instances by name |

Python tools (need Python 3 + `pip install -r python/requirements.txt`):
- `python/asset_builder.py`: generates the procedural assets (houses, trees, characters, …).
- `python/dump_to_rbxlx.py`: rebuilds a place from an old Heavensunder report `.html` (only for emergencies).
- `python/checks/`: tests for rigs and house holes, used when fixing bugs.

---

## What's in this folder

```
Heavensunder.rbxl            the game (open in Studio)
NOTES_FOR_AI.md              give this to an AI first
place_overview.txt           the place as text (for AIs)
Heavensunder_explorer.html   the place as a browsable web page (for you)
scripts/                     all 21 scripts as files
default.project.json         Rojo settings (Level 2)
rokit.toml                   which Rojo/Lune versions to install (Level 2)
lune/                        Lune tools (Level 3)
python/                      asset builder + helper tools
patches/v041/                how the v0.4.1 bugs were fixed
docs/                        review of the asset builder + before/after pictures
```

## Changelog
- **v0.4.1**: meditation legs fixed; the holes in the houses are closed and the door beams no longer block
  the doors; characters have necks, so heads don't float anymore.
- **v0.4**: starting version.
