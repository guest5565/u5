# python/: asset generator + helpers (all offline, no Studio needed)

Install once from the repo root:

```
pip install -r python/requirements.txt   # numpy, scipy, Pillow
```

| File | What it does |
|---|---|
| `asset_builder.py` | Procedural asset generator. Writes `.rbxmx` / `.rbxlx` (XML). Geometry recipes verified part-for-part against the shipped place for spiders, rig bodies, houses, stalls and reeds. Run `python asset_builder.py list` for kinds, `python asset_builder.py export house MyHouse out.rbxmx --set yaw=3.14159`, `python asset_builder.py demo` for a test place. |
| `build_assets.py` | Builds the whole catalog into `assets/*.rbxmx` with fixed seeds. Merge results into a place copy with `lune/run lune/merge_into_place.luau`. |
| `compare_places.py` | Compares two `.rbxmx` / `.rbxlx` files part-for-part (position, size, rotation, colour, material, transparency). `python compare_places.py a.rbxmx b.rbxmx`. Exit 0 = identical. Use `--tolerance 0.005` to ignore 1/255 colour rounding noise. |
| `dump_to_rbxlx.py` | Emergency recovery: rebuilds a place from an old Heavensunder report `.html`. You should never need this unless the `.rbxl` is lost. |
| `checks/` | Offline visual checks, see `checks/README.md`. |

Workflow for new geometry: generate with `asset_builder.py` → check offline with
`checks/` (`rigsim`, `holes`) → `compare_places.py` against the expectation →
merge into a place copy with Lune → verify → playtest in Studio.

Limits (see `docs/REVIEW_v0.4_assetbuilder.md`): the builder does not reproduce
costume layers on rigs, the shipped waterfall/bridge designs, or the exact
random parts of shipped trees/islands. For 1:1 copies of those, extract them
from the place with `lune run lune/inspect.luau export <Path> file.rbxmx`.
