# Heavensunder: Rojo and .rbxl notes, place-file analysis, and AssetBuilder review

## 1. Rojo and Roblox place files in brief

| Format | What it is | Who writes it |
|---|---|---|
| `.rbxl` / `.rbxm` | Binary place / model. Chunked, LZ4-compressed, one chunk per class and property | Studio (default), `rojo build -o x.rbxl`, Lune |
| `.rbxlx` / `.rbxmx` | XML place / model (format "version 4") | Studio "Save as XML", Rojo, hand-written generators like `AssetBuilder` |

**XML structure:** `<roblox version="4">` contains `<Item class="…" referent="…">`. Each Item holds one `<Properties>` element and then its child Items. Every property is a typed element such as `<float name="Transparency">`, `<CoordinateFrame name="CFrame">` (X,Y,Z,R00…R22, row-major), `<token>` for enums, and `<Ref>` for instance links (`null` means empty). Three details matter here:
* **The type tag has to match the reflection type.** `Transparency` is Float32, so it must be `<float>`, not `<int>`.
* **Some properties are saved under a different name.** `Part.Size` is saved as `size`, `Part.Color` as `Color3uint8`, and `Humanoid.Health` as `Health_XML`. `Attachment` saves `CFrame`. Its `Position` property is never written to the file.
* **Referents only have to be unique within one file.**

**Rojo** turns a filesystem tree into instances according to `*.project.json`:
* `rojo build -o place.rbxl` (or `.rbxlx`) writes a standalone file.
* `rojo serve` with the Studio plugin live-syncs into an open Studio session.
* `"$path": "x.rbxmx"` puts a model file into the tree. `*.lua`/`*.luau` files become scripts, and `*.model.json` holds small hand-written instance trees.
* Project nodes that have no `$path` leave unknown children alone, so `rojo serve` won't delete the rest of your hand-built world.
* Rojo converts known aliases (`Color` → `Color3uint8`, `Health` → `Health_XML`). **Its binary writer rejects wrong property types.** Its XML writer passes them through unchanged.

## 2. What the HTML file is

`Heavensunder-v0.4 (1).html` is a read-only offline explorer. It embeds a gzip+base64 JSON dump of **`Heavensunder-v0.4 (1).rbxl`** (a binary place saved by Studio) with every instance and every saved property:
* 36,386 instances across 94 classes: 22,993 Part, 8,467 WedgePart, 398 Motor6D, 2,882 WeldConstraint.
* 21 scripts totalling 3,172 lines, including `GameServer`, `EnemyService`, `NPCService`, `GameClient`, `SpiderAnimator` and `VFXManager`.
* Layout: `Workspace/World/{Islands, Architecture, Paths, Foliage(50 trees), Details, Waterfalls, Interactables, Zones, DistantIsles, Training, Ground/{Buildings,Landscape}}` and `Workspace/Actors/{Enemies(14), NPCs(5)}`.

This makes it the ground truth I checked the builder against.

## 3. AssetBuilder review

### How exact the geometry is (checked by rebuilding at each asset's shipped position and scale)
| Asset | Result |
|---|---|
| Spider `JadeSilkweaver_00` | **161/161 parts exact** (position, size, rotation, colour, material, transparency) |
| `The_Silk_Matriarch` | **166/166 exact** |
| Enemy rigs (Warden, Storm, Lotus): body, armour and halo | **70/70 exact** each |
| `TeaAndSilkMarket`, `RiverReeds` | exact structure |
| `LanternwakeHome` | 224/254 exact. The other 30 are just a different accent: shipped homes use `redwood` *and* `slate`. |
| Trees / island / mountain: the parts that don't use random numbers | exact |
| Trees / island / mountain / reeds: the random-number-driven parts | **differ** (see issue B) |

### Problems found
**A. Serialization bugs (fixed in `asset_builder_fixed.py`)**
1. **`rojo build -o x.rbxl` fails.** `_num()` writes whole numbers as `<int>`, e.g. Transparency 0, WalkSpeed 12, CurveSize0 3. Rojo aborts with `Property type mismatch: Expected Beam.CurveSize0 to be of type Float32, but it was of type Int32`. The XML build only works because it copies the wrong types through unchanged.
2. **`Humanoid.Health` is written under the wrong name.** It needs to be `Health_XML`. The shipped place has `Health_XML = 100` on all 20 humanoids, so the original "Health" writes were lost. It's harmless for enemies because EnemyService resets health from `Config`.
3. **Waterfall attachments use `Position`, which is never saved.** Both beam ends therefore load at (0,0,0) and the beams are zero-length. They need `CFrame`.
4. **The nameplate is missing `Bar.Fill`**, so `EnemyService.updateHealthBillboard` never has a bar to resize. Bar styling, TextStroke and LightInfluence were also missing.
5. **NPCs have no `ProximityPrompt`.** `NPCService` connects dialogue to it, so builder-made NPCs can't be talked to. The role subtitle line was also missing.
6. **Rigs are missing their 30 `…RigAttachment`s and `DisplayDistanceType = None`.** Every shipped rig has them. Without them you also get Roblox's default overhead name on top of the custom nameplate.
7. **Referent collisions when merging.** With an existing `root`, numbering restarts at `RBX0000001` and can collide with Items already in the tree.

**B. Claims in the docstring that aren't accurate (not fixable in the builder itself)**
* **"100% verbatim / exactly recreate": only partly true.** These pieces are missing:
  * Rig costume: RobePanel, HairLock, horns, talismans, wings, face (eyes, nose, mouth), sash. That's about 230 of the 409 instances in a Warden.
  * Island `ExposedMineral` (22 per island).
  * House `Frame`, `SilkTassel` and `LanternLight`.
  * NPC custom cloth colours for Mei_Lan and Tao.
* **`waterfall` and `bridge` aren't the shipped designs.** The game uses CascadeSheet/Catchpool/ParticleEmitters, and its skywalks have ropes, rails and lanterns (327 instances against 19 from the builder).
* **"Same rng phasing as shipped game": only if you replay the entire original build script in its original order.** Every random-number-using call shifts the stream. A fresh builder can't reproduce `LowlandBough_00`, for example.
* **Minor:** the shipped colours are about 1/255 lower on some channels (the old pipeline truncated, Rojo rounds). You won't see the difference.

## 4. What's in `heavensunder_tools/`
* `asset_builder_fixed.py`: the same recipes with fixes A1–A7, plus `export_rbxmx()`. Geometry is re-verified identical. `asset_builder.diff` shows every change.
* `rojo_example/`: `build_assets.py`, `default.project.json` and a built `Heavensunder_assets.rbxl` (every catalogue asset). **The binary build now works.**
* `verify_place.luau`: Lune check of a built place. It shows Health 160/120, `Bar.Fill` present, 30 RigAttachments, the beam end at -80, and the NPC prompt bound to E.
* `merge_into_place.luau`: Lune script that adds generated `.rbxmx` models into an existing place (e.g. the v0.4 .rbxl) and leaves everything else untouched.

Workflow:
```
python rojo_example/build_assets.py            # → assets/*.rbxmx
rojo build rojo_example -o test.rbxl           # standalone test place, or `rojo serve` to live-sync
lune run merge_into_place.luau Heavensunder-v0.4.rbxl v0.5.rbxl Workspace/Actors/Enemies=assets/JadeSilkweaver_99.rbxmx
```

**To get true 100% fidelity for complex assets** (costumed rigs, shipped waterfalls and bridges, exact trees), extract them directly from the place data rather than regenerating them. The HTML/rbxl holds every property, so a small exporter can turn any existing model into a `.rbxmx` template for cloning or re-positioning.

---

## v0.4.1 visual bug fixes
The meditation pose, the house holes and door beams, and the floating heads are fixed in `v041/`. See `v041/README.md` for details. `asset_builder_fixed.py` and `asset_builder.diff` now include the house and neck changes.
