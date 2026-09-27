# How to make a v0.4.2 patch (template)

This folder is a starting point. To make a real patch:

1. Copy this folder to `patches/v042/` and rename the files to
   `patch_v042.luau` / `verify_v042.luau`.
2. Edit `patch_v042.luau`: find things **by name and position** (like
   `patches/v041/patch_v041.luau` does), create only **fresh** instances
   (never `:Clone()`, so no duplicate UniqueIds), and make the patch
   **idempotent** (running it twice changes nothing the second time).
   If anything doesn't look as expected, `warn` and skip it — never guess.
3. Dry-run on a **copy** of the place:
   `lune run patches/v042/patch_v042.luau Heavensunder.rbxl out.rbxl --dry`
4. Run it for real, then check:
   `lune run patches/v042/patch_v042.luau Heavensunder.rbxl Heavensunder_v042.rbxl`
   `lune run patches/v042/verify_v042.luau Heavensunder_v042.rbxl`
5. If you changed geometry by hand-designed numbers, also fix
   `python/asset_builder.py` so newly generated assets don't bring the bug back.
6. If scripts changed, copy them into `scripts/` (or run
   `lune run lune/pull_scripts.luau Heavensunder_v042.rbxl`), bump
   `Config.Version`, and regenerate `place_overview.txt` +
   `Heavensunder_explorer.html`.
7. Open the result in Studio and playtest before replacing `Heavensunder.rbxl`.

The template patch below does nothing by itself — it only shows the structure.
