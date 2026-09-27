# Heavensunder v0.4.1: fixes for meditation, houses and floating heads

> **Layout note (toolkit v2):** this patch is already applied to
> `Heavensunder.rbxl`. Run it from the repo root as
> `lune run patches/v041/patch_v041.luau Heavensunder.rbxl out.rbxl`
> and `lune run patches/v041/verify_v041.luau out.rbxl`.
> Older paths mentioned below (`heavensunder_tools/`, `place/`, `src/`,
> `tools/`) refer to previous layouts; the equivalent files now live in
> `patches/v041/`, `python/`, `lune/`, `scripts/` and `docs/images/`.
> Kept as a record, and to patch an original v0.4 file.

> **In this repo:** the patch has already been applied to `place/Heavensunder.rbxl` (6 houses, 14 rigs, 2 scripts) and the scripts are in `src/`. The builder is `tools/asset_builder.py`, and the images are in `docs/images/`. Paths further down refer to the older `heavensunder_tools/` layout. Keep this folder as a record, or to patch an original v0.4 file.

There are two ways to apply the fixes. Both give the same geometry.

| Where | How |
|---|---|
| **Existing place file** (`Heavensunder-v0.4.rbxl`) | `lune run patch_v041.luau Heavensunder-v0.4.rbxl Heavensunder-v0.4.1.rbxl`, then `lune run verify_v041.luau Heavensunder-v0.4.1.rbxl` |
| **Builder** (new assets from now on) | `../asset_builder_fixed.py` now includes the house and neck fixes (`asset_builder_v041.diff`) |
| **Scripts** (if you keep them in Rojo/Git) | `scripts/PoseLibrary.luau` and `scripts/AnimationManager.luau` (`scripts.diff`) |

- The patch works with `.rbxl` and `.rbxlx`: the output format follows the file extension.
- You can run it more than once safely; a second run changes nothing.
- `--dry` prints what the patch would do without writing a file.
- It only ever adds new instances; it never uses `:Clone()`, so no UniqueIds are duplicated.
- If a script doesn't look the way the patch expects, the patch warns and skips that script instead of guessing.

---

## 1. Meditation: the legs bent the wrong way

**Cause.** In `PoseLibrary.meditation`:
- The hip values (`-1.2` in `put()`, which negates X for legs) swing the thighs **backwards** and twist them outward.
- The knees then fold 1.85 rad on top of that.
- The body is lowered by only 0.65 studs.

Together these left the character hovering in a twisted half-squat, with the shins sticking out sideways and upward (image-1 and image-7; the shipped pose rendered offline looks the same).

**Fix.** A new cross-legged pose with the hands resting in the lap:
- The pelvis drops by `1.70 × scale`, so the hips sit 0.64 above the floor.
- The thighs splay outward and forward, and the shins fold inward so the feet meet under the hands.
- The Root drop is a distance in studs, so it has to grow with the rig's size. `meditation(p, t, scale)` therefore takes a scale argument. AnimationManager now passes `rig.Root.Size.Y / 2`, and the value defaults to 1 if left out.
- Breathing is now a small movement of the waist, neck and shoulders. Previously the whole body bobbed up and down by 0.12 studs.

**How the numbers were found.** I solved the pose offline against the real rig: joint pivots taken from the place, forward kinematics that match `AnimationManager` (`C0 = Base * CFrame.new(pos) * Angles(x, y, z)`), and IK to place the hands in the lap.
- All leg parts stay above the floor. The lowest point is 0.06 studs below it, at a shin edge.
- To check the final result, I ran the **patched Luau file itself** through Lune and rendered its output (`renders/meditation_luau_check.png`: player, Elder Yun and Liora).

## 2. Houses: holes and the door blocked by two parts

**Door.** Two `CrossBeam`s, at heights 1.5 and 4.5, ran the full 19.3-stud width of the front, straight across the doorway. Each is now split into two 7.25-stud pieces that end inside the door posts (x = ±2.4).
- The top beam at height 8.4 sits above the door lintel and is unchanged.

**Holes.** The walls stop at height 8.5, but the underside of the roof is about 9.2 at the eaves and about 11.9 at the ridge. That left:
- an open triangle above each side wall;
- a narrow slot above the front and rear walls.

The patch adds these pieces:
- `GableInfill` on each side: one strip plus two WedgeParts that follow the roof slope. Colour and material are copied from `SideWall`.
- `EaveInfill`: a strip at the front and at the rear, copied from `RearWall`.

**Floating trim.** `SweptEave` hung in the air 1.3 studs above the eave. It now sits on the edge of the lowest roof course.

**Test.** I fired rays outward from 27 points inside the house:
- v0.4: rays escaped through both gables and the front and rear slots.
- v0.4.1: every escaping ray leaves **only through the door**, for houses facing both directions (yaw 0° and 180°).

Renders: `renders/house_compare.png`, `renders/door_compare.png`.

## 3. Floating heads

**Cause.** The Head is a Ball whose bottom sits at 4.455 × scale. The top of the UpperTorso is at 4.325 × scale, so there was a real 0.13-stud gap with nothing in it, and no neck part.

**Fix.** The patch adds a `NeckColumn` to every humanoid R15 rig:
- It is a cylinder spanning heights 4.22–4.70 with a diameter of 0.52 (× scale), coloured the same as the Head.
- It is attached to the Head with a `WeldConstraint`.
- It is Massless, non-colliding and non-queryable, so it has no effect on physics or hit detection.
- Its centre is on the Neck joint, so it stays attached when the head turns or nods. Its lower end sits inside the torso.
- It is applied to the StarterCharacter, the 5 NPCs and the humanoid enemies (skin 76/90/100 is taken from their heads).
- Spiders are skipped. They have no `Neck` motor driving a Head.

Render: `renders/neck_compare.png` shows neutral, head-turn and nod poses for v0.4 and v0.4.1.

---

## How this was tested (without your real .rbxl)
`test/make_test_place.py` builds a stand-in for v0.4. It contains:
- the 6 LanternwakeHomes at their shipped positions and rotations (3 at 0°, 3 at 180°);
- the StarterCharacter, all 5 NPCs, JadeWarden, StormDisciple, the Hollow Lotus and a spider, all built from v0.4 geometry;
- the shipped PoseLibrary and AnimationManager source.

The following were checked:
- **Patch result:** 6 houses (12 beams split, 48 infill parts, 12 eaves moved), 9 necks, 2 scripts.
- **Second run:** no changes.
- **Matches the builder:** `test/compare_places.py` shows the patched place and the fixed builder produce the same geometry, part for part (0 models differ).
- **Verify script:** `verify_v041.luau` passes, which includes compiling and running the patched PoseLibrary.
- **Output formats:** both binary and XML output were checked.

**Before running it on the real place, back up the file.** The patch finds things by name and position (`RaisedStoneFoundation`, `SideWall`, `CrossBeam` at local heights 1.5/4.5, and so on) and prints a warning for anything it doesn't recognise.

Known cosmetic leftover: Elder Yun's staff moves with his arm, so when he sits its lower end goes into the floor. It stays hidden by the ground.
