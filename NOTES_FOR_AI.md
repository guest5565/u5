# Notes for AI assistants working on Heavensunder

The owner is **new to programming**. Give copy-and-paste instructions or complete finished files, and keep answers simple.
Don't assume they use git or a terminal; they upload files on the GitHub website.
When you fix geometry, also fix `python/asset_builder.py`, so newly generated assets don't bring the bug back.

## What is in this repository
| Path | What it is |
|---|---|
| `Heavensunder.rbxl` | **The game** (binary Roblox place, v0.4.1, ~36k instances). Source of truth for everything that is not a script. |
| `scripts/` | Copies of all 21 scripts. `X.luau` = ModuleScript, `X.server.luau` = Script, `X.client.luau` = LocalScript. Folders = Explorer path. |
| `place_overview.txt` | **Text outline of the whole place** (~1,950 lines, ~45k tokens), made from the .rbxl. Read this first. |
| `Heavensunder_explorer.html` | The same place as an interactive explorer page for a browser (13 MB, too big to read as text; meant for humans). |
| `default.project.json`, `rokit.toml` | Rojo setup: maps `scripts/` into the place (only scripts; all models stay in the .rbxl). |
| `lune/` | Lune scripts that read/write the .rbxl (see below). |
| `python/asset_builder.py` | Procedural asset generator (writes `.rbxmx`/`.rbxlx`). |
| `python/dump_to_rbxlx.py` | Rebuilds a place from an old Heavensunder "report" HTML (only for recovery). |
| `python/checks/` | Offline checks: rig forward-kinematics renders, pose solver, house hole ray-casts. |
| `patches/v041/` | The v0.4.1 patch (meditation legs, house holes/doors, necks) and its verifier. |
| `docs/` | Review of the asset builder and before/after pictures. |

## How to read the place file (Heavensunder.rbxl)
`.rbxl` is a **binary** format; don't try to read it as text. Options, best first:
1. **No code execution:** read `place_overview.txt` (hierarchy, positions, sizes, colours, important values,
   Motor6D joints). Repeated parts are merged ("x176") and identical models are listed once
   ("same structure as JadeWarden_00"). Script sources are in `scripts/`.
2. **You can run code:** install Lune 0.10.x and use the tools from the repository root:
   ```
   lune run lune/inspect.luau tree Workspace.Actors 2          # hierarchy
   lune run lune/inspect.luau props Workspace.Actors.NPCs.Liora.Head
   lune run lune/inspect.luau find Lantern Model               # search by name (+ class)
   lune run lune/inspect.luau export Workspace.Actors.NPCs.Liora liora.rbxmx   # XML text of a subtree
   lune run lune/rbxl_to_text.luau                             # regenerate place_overview.txt
   lune run lune/rbxl_to_html.luau                             # regenerate Heavensunder_explorer.html
   ```
   Or directly: `roblox.deserializePlace(fs.readFile("Heavensunder.rbxl"))` with `@lune/roblox`.
   Exported `.rbxmx` / `.rbxlx` files are XML and can be read as text.
3. `lune run lune/xml_to_binary.luau Heavensunder.rbxl full.rbxlx` converts the whole place to XML (~120 MB, big).

**Keep the text files in sync:** if you change the .rbxl, rerun `rbxl_to_text.luau` (and `rbxl_to_html.luau`).

## How to change things
- **Scripts:** edit `scripts/...`, then `lune run lune/build.luau` writes `build/Heavensunder.rbxl` with the new
  sources put into the place (models untouched). Or the owner copies the script text into Studio by hand.
  `lune run lune/pull_scripts.luau` does the reverse (place → `scripts/`) after editing in Studio.
- **Models/geometry:** change the place with a Lune script (like `patches/v041/patch_v041.luau`), or generate
  models with `asset_builder.py` and insert them with `lune/merge_into_place.luau`. Always also fix `asset_builder.py`.
- **Rojo live sync (optional):** `rojo serve` + the Rojo Studio plugin syncs `scripts/` into an open place.
  Every node has `$ignoreUnknownInstances: true`, so models in the place are left alone.
- Lune tools that read properties must skip classes Lune doesn't know (e.g. `Packages`): reading them crashes Lune
  in a way `pcall` can't catch. Check `roblox.getReflectionDatabase():GetClass(inst.ClassName)` first.

## Place layout (v0.4.1, 36k instances)
- `Workspace.World`: `Islands`, `Foliage` (50 trees), 5 waterfalls, `Ground` (`Buildings`: 6× `LanternwakeHome`,
  2× `TeaAndSilkMarket`, square, lanterns, well; `RiverReeds`; `CloudrootPeak_0..4`)
- `Workspace.Actors.NPCs`: Elder_Yun, Liora, Shen, Mei_Lan, Tao_Reedwalker · `Workspace.Actors.Enemies`: 14 (JadeWarden ×4,
  StormDisciple ×3, The_Hollow_Lotus, JadeSilkweaver spiders ×5, The_Silk_Matriarch)
- `StarterPlayer.StarterCharacter`: the player rig (+ `Animate` LocalScript)
- Scripts: `ReplicatedStorage.Shared.*` (AnimationManager, PoseLibrary, Config, VFXManager, Spider*…),
  `ServerScriptService.*` (GameServer Script + services), `StarterPlayerScripts.GameClient`
- Script contracts: EnemyService needs `Archetype` StringValue, `HumanoidRootPart`, `Humanoid`, `Bar.Fill`;
  NPCService needs a `Role` StringValue and a `ProximityPrompt` in the model; Elder toggles Meditate/Idle (NPCService ~l.190);
  player meditation in GameServer (~l.199).

## Animation system
- `AnimationManager` per rig: each Motor6D's pose lerps to `toFrame(p[name])` with alpha `1 - exp(-dt*13)`, then
  `Motor.C0 = Base * Pose`, `toFrame(v) = CFrame.new(v[4],v[5],v[6]) * CFrame.Angles(v[1],v[2],v[3])`.
- `PoseLibrary`: `neutral()` runs first every frame, then the state pose overrides keys.
  `put(p, joint, x,y,z, px,py,pz)` **negates x for Shoulder/Elbow/Hip/Knee/Ankle** (rigs face **−Z**; positive x in `put`
  raises a limb toward −Z/forward). Translations are in studs → scale them with `rig.Root.Size.Y / 2`.
- `meditation(p, t, scale)` (v0.4.1) was solved numerically against the rig; see `python/checks/pose_design.py`.

## Humanoid rig geometry (rig units × scale, scale = HumanoidRootPart.Size.Y/2 = Head.Size.X/1.12)
Ground = HRP.y − 3. LowerTorso centre 2.65 (1.6×.75×.86) · UpperTorso 3.65 (1.85×1.35×.92, top 4.325) ·
Head Ball 5.03 (1.12×1.15×1.05, bottom 4.455) · NeckColumn cylinder 4.22–4.70 Ø.52 welded to Head (v0.4.1) ·
pivots: Root 3.0, Waist 3.02, Neck 4.41, Shoulder (±1.06, 4.13), Elbow 3.08, Wrist 2.21, Hip (±.46, 2.34), Knee 1.34, Ankle .46.
Motor6Ds are parented under Part0 in the place; details are attached with WeldConstraints named `DetailWeld`.

## LanternwakeHome geometry (house-local: origin = RaisedStoneFoundation.CFrame * (0, −0.35, 0))
Floor top 1.0 · walls to 8.5 · SideWall x=±9 · RearWall z=+8 · door wall z=−8 (door opening x ±2.19, lintel bottom 7.35) ·
FacadePosts x=±2.4, ±9 at z=−8.5 · roof underside ≈ 11.89 − 0.34|z| · v0.4.1 added GableInfill (strip + 2 wedges per side),
EaveInfill (front/rear), split the door CrossBeams, moved SweptEave to (0, 8.88, ±10.98). Houses exist at yaw 0° and 180°.

## Place-file pitfalls (learned the hard way)
- Serialized names differ from API names: BasePart `size`, `Color3uint8`, `shape`; Humanoid `Health_XML`;
  WeldConstraint `Part0Internal`/`Part1Internal` + `CFrame0`. Types matter: a float property written as an int
  (`Beam.CurveSize0`) makes `rojo build` to `.rbxl` fail.
- Lune: derived properties (`Position`, `Orientation`) aren't stored → use `part.CFrame.Position`.
  `Instance.new` leaves properties *absent* (Studio then uses class defaults, e.g. `Anchored=false`) → set everything explicitly.
  Instances from `deserializePlace` are fresh userdata each access → don't use them as table keys; use `GetFullName()`.
- Non-uniform `Ball` parts render as ellipsoids in-game.
