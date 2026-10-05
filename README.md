# Inkwing v0.1: flying RPG in a paper/ink sky

Open `Inkwing.rbxl` in Studio. To rebuild it: `python3 tools/gen_world.py && ~/tools/rojo build default.project.json -o Inkwing.rbxl`

## Loop
Spawn at Quill's Rest, then jump off the edge. Your wings open on their own and you fly. Lock onto monsters, earn ink, XP and feathers, and use those to upgrade your wings. At tier 3 you can dive into the Ink Depths, where the Blot King waits. Beating him unlocks Ink Wings.

## Controls
| | PC | Mobile |
|---|---|---|
| Fly | Jump off any edge (auto) | same |
| Steer / climb / dive | Move + camera pitch, Space up, Q/Ctrl down | Stick + UP/DOWN buttons |
| Boost | Shift | BOOST |
| Lock on | Click an enemy (auto-locks within 30 studs) | Tap an enemy |
| Abilities | 1 / 2 / 3 | 3 round buttons |

## Content
- Zones: Quill's Rest (hub), Sky Isles, Ink Depths, Blot King's Throne
- Monsters: Ink Blob, Scribble Bat, Paper Wasp (ranged, with a telegraph), Ink Shade
- Boss: Blot King. Has slam and ink-rain telegraphs, summons blobs at 66% and 33% HP, and respawns 120s after dying.
- Wings: Paper (Common) and Ink (Rare), 10 tiers each. Higher tiers add more and longer feathers, sparkles from tier 5, and a glow at tier 10.
- 6 quests with a gold guide beam, a guided start, and depth lighting set per player
- Saves to DataStore `InkwingV1`. Test commands (Studio only, or your account): `/ink N`, `/feathers N`, `/level N`

## Scripts
Server: `Main.server.lua`. Client: `Flight`, `Enemies`, `HUD`, `WingsRender`, `Atmos`. Shared: `Game` (all tuning values), `EnemyModel`, `InkFX`, `Audio`, `SoundIds`.

## v0.4 (current): Hell, the Abyss, the Unknown + cosmic horror
Layout image: previews/layout_v04.png. Monsters: previews/v04_a.png, previews/v04_b.png
| y | Layer | Monsters / boss | Wing drop |
|---|---|---|---|
| 6600+ | HEAVEN: city of light (domes, towers, pearly gate, angel statues, rainbow, waterfalls, temple), pink clouds | Ophan, Seraph, THE HALO WARDEN | Halo |
| 4300 to 5100 | THE COSMOS (purple nebula fog) | Star Spawn, Void Gazer, THE COMET EATER | Star |
| 2150 to 2750 | THE STORM (dark fog wall; only appears when you get there) | | |
| 330 to 2150 | The windy climb (white fog, thicker as you rise) | | |
| 60 to 260 | SKY ISLES (start) | | |
| -700 to -2700 | THE INK SEA + Driftwood Isles | Ink Eel, THE INKVERN | Coral |
| -2700 to -3400 | THE INK DEEPSEA (renamed) | Ink Shade, THE BLOT KING | Ink |
| -4200 to -5000 | HELL: lava sea, volcanoes, WALKABLE isles + bridges | Cinder Imp (walks), Ash Wraith, THE CINDER KING | Ember (Epic) |
| -5800 to -6600 | THE ABYSS: black, giant bones, monoliths | Abyss Lurker | |
| -7400 to -8400 | THE UNKNOWN: colossal cosmic beings, watching eyes, fallen pieces of the world | The Hollow, THE UNKNOWN | Void (Mythic) |

- FogShell.client: camera-locked fog walls per zone. Unknown.client: colossal beings.
- Altitude readout at the top for admins (testing).
- Wings: quill shafts, coloured tips, a covert feather layer, shoulder joints.

## v0.3: Cosmos + Heaven, a real ocean
| y | Layer | Monsters / boss | Wing drop |
|---|---|---|---|
| 6600 to 7300 | HEAVEN: white and gold cloud isles, Heaven's Gate, giant halos, light shafts, feathers | Halo Sentinel Lv42, Gilded Moth Lv45, THE HALO WARDEN Lv50 | Halo (Legendary) |
| 5100 to 6600 | The light climb: night turns to dawn turns to gold | | |
| 4300 to 5100 | THE COSMOS: moon isles, paper planets, constellations, shooting stars | Star Wisp Lv30, Comet Hound Lv33, THE COMET EATER Lv36 | Star (Epic) |
| 2750 to 4300 | Thin air: the storm fades, the sky goes dark | | |
| 2150 to 2750 | THE STORM | Storm bats and wasps | |
| 330 to 2150 | The windy climb | | |
| 60 to 260 | SKY ISLES (start) | Blob, Bat, Wasp | |
| -700 | THE DRIFTWOOD ISLES on the sea: lighthouse, shipwreck, inkwell, kraken arms | | |
| -700 to -2700 | THE INK SEA: blue tint, splash, slower swimming, giant leviathans | Ink Eel Lv10-13, THE INKVERN Lv20 (roams) | Coral (Rare) |
| below -2700 | THE INK DEPTHS | Ink Shade Lv14, THE BLOT KING Lv15 | Ink (Rare) |

- 15 quests now lead through every zone in order.
- All ball clouds are replaced by soft particle clouds (CloudFX).
- CharAnim supports the new AnimationConstraint joints (the cause of the frozen pose).

## v0.2
| y | Layer |
|---|---|
| 2150 to 2700 | THE STORM: fog, rain, lightning, tornados, storm isles. Bats Lv22, wasps Lv26 |
| 330 to 2150 | The windy climb: wind streaks, cloud wisps, paper scraps, 9 cloud pillars, lightning hidden in the clouds, wind sound |
| 60 to 260 | SKY ISLES (start, calm) |
| -700 | THE INK SEA surface (comic wave strokes, spray) |
| -700 to -2700 | Underwater: light shafts, marine snow, bubbles, fish schools (glowing ones deep), ink jellyfish, sunken boats, pencils and books |
| below -2700 | THE INK DEPTHS (abyss): Shades Lv14, Blot King, "The Unknown" eyes |

- Zones stream in on the client only when you are near (ZoneStream). No hard gates. Climbing or diving for a while builds speed.
- Monsters: spawn-level scaling, bigger aggro range, packs alert each other, flyers circle you, wasps aim ahead.
- CharAnim poses Motor6D.C0. A Studio-only debug line at the bottom-left shows its state.
- Admin panel: ink, feathers, level, tier, unlock all, quest skip, heal, god mode, boss, kill all, teleports, reset player.
- Planned next (from DESIGN_Skybound.md): the Trench, Coral and Storm Wings, Bestiary. Then v0.3: Cosmos, Heaven. Then v0.4: The Unknown and the Void.

## v0.5
- No more death when diving deep (FallenPartsDestroyHeight -20000).
- Monster swap: Blot King + Ink Shades live in the Ink Sea (-700 to -1500, throne isle at -1500); Ink Eels + Inkvern in the Deepsea.
- Heaven v2: Pearly Gate plaza with trumpet angels, Gothic cathedral isle, domed basilica town with clock tower, lake isle (gazebo, roses, waterfalls, rainbow), arched bridges, Warden arena, 3-tier Sky Palace, distant castles, cloud banks. Spawn/teleport moved to gate plaza.
- Heaven light shafts fainter/wider (no more white poles).
- New tool: tools/render_zone.py (env R=radius filter) for map previews.

## v0.6
- All zones ~2.5x wider (radius ~1300): sea, lava and cloud surfaces widened; outer rings filled with rotated/shuffled landmarks (isles, wrecks, crystals, monoliths, moons, fallen ruins).
- Hell: 9 new walkable volcano isles + 7 extra volcanoes, ink hands, ash clouds.
- Heaven: ring of 8 outer districts (temple towns, chapels with angels, gardens, bell keeps) joined by arched bridges, waterfalls, far cloud banks.
- Monsters: every flying spawn also spawns in 3 outer camps (+2 levels); outer Hell isles have Cinder Imps.

## v0.7 (core feel)
- Soft gates (server-side): zones above your best wings drain 3.5% max HP/s per missing wing rank and slow you; red vignette + "NEED X WINGS". Storm/Deepsea: Ink, Cosmos: Coral, Heaven: Star, Hell: Halo, Abyss/Unknown: Ember.
- Speed bug fixed: momentum + boost stacked to ~800 studs/s; now hard cap by best wing rank (150 .. 400).
- Combat camera (CombatCam.client.lua): when locked, over-the-shoulder camera + crosshair; PC mouse locks to centre; soft aim retargets the monster nearest the crosshair; UNLOCK button / F / right mouse.
- Dodge: BOOST while in combat = quick dash with 0.35 s invulnerability (server rate-limited).
- Hit feedback: camera kick on hits/hurt, FOV punch + gold shards on crits, enemies flinch.

## v0.7b
- Combat camera stays on between kills (auto-retargets the nearest monster); AIM / UNLOCK button + F key toggles it.
- Enemy damage now scales with max HP at the enemy's level (Heaven Lv42+ hits ~70-90, bosses ~2x).

## v0.8 (Heaven of giants)
- Giant biblical angels (~100x a player): 2 SERAPHIM (six eyed wings, great central eye) and THE THRONE (wheels within wheels + four wings). PEACEFUL until you hit them (then hostile to you for 60 s: holy beams + JUDGEMENT pillar rings). Respawn 10 min.
- Blessing: slay the Halo Warden -> giant angels smite the monsters you fight, and a Guardian Ophan orbits you and smites your target.
- Halo Warden rebuilt as a crimson-eyed seraph (size 120, crown of halos). Ophan 2.6x bigger, Seraph enemy is now the dark owl-winged CHERUB (ref 3), 2.6x bigger.
- Heaven widened: second ring of 14 districts at 1500-2500, cloud banks to 2900, cherub/ophan camps at r=2000.
- EnemyModel: SCALE table scales any model (sizes, offsets, anim translations, particles).

## v0.9 (Realms)
Three places in ONE experience (shared DataStore, shared code):
| File | Project | Contains |
|---|---|---|
| Inkwing.rbxl | default.project.json | OVERWORLD: Sky Isles, Storm, Ink Sea, Deepsea (start place) |
| Inkwing_Celestial.rbxl | celestial.project.json | CELESTIAL REALM: Cosmos, Heaven, giant angels |
| Inkwing_Underworld.rbxl | underworld.project.json | UNDERWORLD: Hell, Abyss, Unknown |

Setup: Creator Dashboard > experience > Places > add 2 places, publish the Celestial/Underworld files to them, then put the 3 PlaceIds in `G.PLACES` (Shared/Game.lua) and republish all three.
- Gates: fly above 3300 (Sky Tear) -> Celestial; dive below -3700 (Deep Rift) -> Underworld; Celestial below 3500 / Underworld above -3850 -> back to the Overworld. Shimmering veils + ring landmarks + "TO THE ..." warnings.
- Realm Map (MAP button / M): every zone you have visited = fast travel (same realm = blink, other realm = teleport).
- Ink-and-paper travel loading screen (SetTeleportGui + ReplicatedFirst/Arrival).
- Data saved right before every teleport (+ retry x3, failure handling). Blessing and discovered zones are now saved (Blessing was not saved in v0.8).
- Each server only spawns the monsters/bosses/giants of its own realm.
- Studio: teleports don't work in Studio; open each .rbxl separately to test a realm (gates push you back with a message).
- Abyss now has the colossal beings, the giant eyes and the violet lightning; the Unknown is pure darkness.
- Underworld at full size: second ring of 14 Hell isles (to r=2500), 10 more huge volcanoes, lava sea ~6000 wide, Abyss + Unknown filled to r=2800, outer camps.

## v0.9b - Behaviour & animation
- Heaven beings (Halo Sentinel, Gilded Moth) are PEACEFUL until you hit them; their flock nearby joins in for 45 s. Halo Warden stays hostile.
- Cosmos: bigger Star Wisps / Comet Hounds, more of them; they only hunt players Lv.35+ (or whoever attacks them).
- Hell/Abyss aggressive; the Abyss is now sparse: a few huge Abyss Lurkers.
- The Unknown: only the boss and THE NAMELESS (~1000 studs, 30 eyes, broken rings, 10 arms) which attacks anything that gets close.
- Auto-lock / soft-aim skip peaceful & too-strong beings unless they are hostile to you (tap still locks).
- Angel wings beat for real (bigger amplitude, per-kind speed, body rises with the beat).
- UNLOCK button moved under the target panel.

## v0.9c - Void, Pandemonium, Colossi
- The Unknown is a true void: fog to arm's length, exposure crushed, no stars; all fallen isles removed.
- Under the lava sea: molten red murk (no more seeing all of Hell from below).
- Hell: Pandemonium palace (colonnades, lit windows, keep, towers, 32 torches) at (-200,-4700,-1300); 2 Towers of the Eye; 10 eternal flame pillars; braziers on 40 isles.
- Abyss Lurker removed. THE FORGOTTEN x3 (Abyss, aggressive, teal light shaft). THE HUNCHED ONE x3 (Cosmos, only notices Lv35+).
- Heaven population cut (3 per inner camp, 2 per outer).
- Auras (glow body + motes) for Seraphim, Throne, Halo Warden, Cinder King, The Unknown, Nameless, colossi, Cosmos beings.
- Boost lasts 6 s (7 s on better wings), chainable.

## v1.0 - Devour & Ascend + Cosmic Giants
- REMAINS: every fallen being leaves remains (2 min; giants/bosses 5 min) with its zone's essence (Ink, Storm, Cosmic, Holy, Infernal, Abyssal, Void).
- ABSORB (E / button, needs the ABSORB skill): take the nearest remains within 60 studs.
- MEDITATE (R / button, needs MEDITATE): stay still; mana grows, stored essence fuses into your wings. Hit or move = broken.
- WING RANK D -> C -> B -> A -> S (essence fused + mana thresholds). Rank boosts damage, HP, speed; the most-fused essence sets the wing's ASPECT (passive bonus). B+ ranks get a visible aura, A/S glow.
- SKILLS panel (K): 11 learnable ranked skills (D..S), 1 skill point per level + 1 per boss kill. Combat abilities unchanged.
- Cosmic giants: THE MAW BELOW x2 (Hell), THE DREAMER (Abyss, only wakes if attacked), STAR LEVIATHAN x2, THE WEAVER x2, THE ECLIPSE EYE (Cosmos, only notice the strong).
- Cosmos widened to r~3300 with 10 far mob camps; left HUD buttons re-stacked (WINGS / MAP / SKILLS / ADMIN).

## v1.0b - Core skills + 10 polish passes
Skills (4, each EVOLVES through use):
- ABSORB [C] (E) -> GLUTTONY [A] after 60 remains: devour every remains within 150 studs at once; heal 5% each; FEAST +6% dmg per corpse (30s, max 10).
- MEDITATE [C] (R) -> ZEN FLIGHT [A] after 1200 s meditated: meditate mid-air, hits don't break it, 2x mana.
- UNLEASH [B] (Q, Lv15, 3 SP) -> CATASTROPHE [S] after 120 uses: burn 10 essence (aspect first) for its power:
  Infernal nova, Holy heal, Storm chain lightning, Cosmic star rain, Abyssal drain, Void singularity (pull), Ink blot prison (root). Catastrophe: 1.6x size, 1.5x dmg, cost 6, 4s cd.
- EYES OF THE ABYSS [B] (Lv30, 3 SP) -> ALL-SEEING EYE [S] after 900 s in the dark: see in the dark; then on-screen markers for remains, giants, bosses.
Polish: 1 static analysis sweep | 2 mobile button layout | 3 enemy LOD culling + throttled animation, Hell fires halved |
4 onboarding quests (learn skills, absorb 5, evolve to C; D->C cheaper) | 5 rank/mana HUD badge | 6 SFX for absorb/unleash/evolve |
7 danger-coloured name tags + "ignores the weak" | 8 parallel shutdown saves | 9 admin: essence/rank/mana/all skills/reset skills | 10 respawn cleanup.

## v1.1
- **New start:** you spawn on Genesis Isle, a big floating island with no wings. Hunt the Ink Blobs, and your Paper Wings unfold at the Wing Shrine after the first quest. A wingless fall teleports you back.
- **No skill points:** skills awaken through what you do, with a big banner when they do.
  - ABSORB: your first kill.
  - MEDITATE: absorb 3 remains.
  - UNLEASH: defeat the Blot King.
  - EYES OF THE ABYSS: descend into the Abyss.
- **Skill menu:** a grid of symbol tiles plus a detail panel with an evolution bar. Locked tiles show "?" and how to unlock them.
- **Meditate:** cross-legged pose. The aura now rises from the whole body (flames from every limb) instead of floor rings.
- The badge now just says "MANA x / y".
- **Manual attack:**
  - PC: hold left mouse.
  - Mobile: hold the ATTACK button.
  - Small ring reticle. The system cursor is hidden.
- Wings flap hard during boost.
- **Monster VFX:** built with the Auras tool per zone (ink drip, stardust/galaxy, halo/gold, ember/phoenix, void, bubbles). Every enemy attack has a themed windup, beam or projectile, and impact, scaled by monster size.
- **No pop-in:** monsters render out to 900+ studs (PC) or 480+ studs (Mobile).
- **QUALITY toggle** (top right): PC = everything, MOBILE = lighter.

## v1.2
- **Genesis Isles:** the comic paper island is replaced by real floating islands: grass, dirt, rocky undersides, trees, pines, bushes, flowers and a marble Wing Shrine. One big isle and 5 satellites, linked by sagging iron chains.
- **Master Orren (mentor NPC):** teaches skills through training. Talk to him to start a task, then come back when it's done.
  1. MEDITATE: stand completely still for 20 s.
  2. ABSORB: defeat 8 monsters.
  3. UNLEASH: meditate for 90 s.
  4. EYES OF THE ABYSS: dive below -1500 in the Ink Sea.
  - Your current training shows under the mana badge. Quests 2 and 4 point you to him.
- **Skills board, drawn like the sketch:** a white board of 6 hand-drawn tiles (symbol in a circle, name, "Rank C"). Tap a tile to open its skill card: name, symbol, a short line, rank, and an x to close.
- **PC free aim:** no auto-lock, no lock ring, no combat-cam snap. Hold the mouse button and shots hit whatever is under the cursor ring, or fly off and miss. Mobile keeps tap-lock plus the ATTACK button.

## v1.3
- **Mouse:**
  - PC joins LOCKED (mouse centred, shoulder cam). F toggles UNLOCK/LOCK MOUSE.
  - The big crosshair is removed. The same small ring is the only reticle: centred when locked, following the mouse when unlocked.
  - Right-click no longer unlocks.
- **Nature islands** (gen_world `g_island`): lobed irregular outlines, grass/dirt/rock layers, cliffs, stalactites, hanging vines, big branched oaks with roots, tiered pines, palms, bushes, mossy stones, flowers and tufts.
- **Genesis main isle:** radius 210, plus a giant ancient tree and a pond with a waterfall pouring off the edge.
- **Satellites:** radius 80-95 at 400+ studs, chained.
- **Old paper islands:** all overworld sky isles converted (1.6x bigger). The Ink Sea isles are now sand islands with palms.
- The Overworld now has about 17k parts.

## v1.4 - world life
- **Ambient.client:**
  - Wind sway (a gust envelope over flutter) on leaves, pines, fronds, tufts and bushes near the camera. Up to 2200 parts on PC, 700 on Mobile.
  - Butterflies over flower patches, 4 bird flocks circling the isles, fireflies at night, leaves drifting off the ancient tree.
- **Treasure chests (9):** one per satellite isle, 2 on the main isle, an Ancient Chest in the Forgotten Temple, and an Ancient Chest on the Hidden Isle 260 studs above the main isle (wings only). Opened once per player and saved; opened chests stay open for you. Rewards: ink, feathers, XP and Ink essence.
- **Sky Apples:** 16 glowing apples on main-isle oaks. Eating one heals 35% and gives 6 XP; they respawn after 75 s.
- **Landmarks:** the Forgotten Temple (ruined marble columns, arch, ivy), a broken stone bridge that ends mid-air, and a far horizon of 18 low-detail islands 1500-2300 studs out.
- The Overworld is now about 19k parts. Keep G.N_CHESTS in sync with gen_world's "chests:" print.

## v1.5 - merchant + island weather
- **Wandering Merchant:**
  - An airship (client visuals smoothly follow the server's MerchantRoot) tours 5 docks: Genesis, Quill's Rest, the western isle, the southern isle and the Temple. It stays 150 s, travels 45 s, and announces every arrival.
  - **Trade prompt:** 45-stud reach.
  - **Stock:** a Treasure Map plus 4 random items: Tailwind Tonic (+30% flight), Hunter's Brew (+25% damage), Essence Lantern (2x essence), Feathers, Essence Crystal, Apple Basket.
  - The map draws a golden trail and a light pillar to the nearest unopened chest.
  - Active buffs show as countdowns at the top right.
- **Sky Showers:**
  - Every 6-10 min, 150 s of warm rain over the isles: particles, rain sound and cooler light.
  - Flowers glow, and 4 GOLDEN monsters spawn (gold foil and a gold aura; 5x XP, 6x ink, +3 feathers).
  - Afterwards, a giant rainbow for 75 s.
  - Admin: SKY SHOWER button.
- IDEAS_v2.md has the gameplay deep dive.

## v1.6 - Skyways, Plumes and Living Monsters
- **Feather Plumes** (PLUMES button, left side): 8 plumes that change how you fight: Split, Storm, Ember, Blood, Ink, Gale, Moth, Echo. You get 2 slots, or 3 at wing rank A+. Plumes drop from bosses (100%, everyone who did damage), golden monsters (50%), elites (20%), ancient chests, shrines and world events. Duplicates turn into +200 ink.
- **Elite monsters** (7% of spawns, never at the first spawn area): 2.5x HP, 3x XP. Each one is bigger, glows and shows a tag. Affixes: Mirrored (splits when it dies), Gale (blasts you away), Anchored (pulls you in), Vampiric (heals), Shielded (takes 70% less damage above half HP), Swift (fast), Volatile (explodes when it dies).
- **Monster behaviours:** idle ink blobs merge into bigger blobs (up to 3x). Scribble bats flee at 35% HP and come back with the swarm. Paper wasps call every wasp nearby and become enraged. Angels shield each other when one is hit. Cinder imps explode when they die. Ash wraiths teleport behind you.
- **Boss arena mechanics** on top of the old phases. Blot King: Ink Flood, then Whirlpool. Cinder King: Eruption, then Meteor Rain. Inkvern: Tidal Wave, then Maelstrom. Comet Eater: Gravity Well, then Supernova. Every phase change shakes the screen.
- **Wind currents:** Genesis Ring, Sky Lift (Hub to the storm), Sea Dive and Sea Rise. Fly into one to ride it at 150 studs/s. **Updrafts** at the waterfall, the temple and two isle edges lift you for free.
- **Undercaves:** the Waterfall Grotto (a hollow rock beside the Genesis falls) and the Crystal Hollow (below the far west isle). Both have crystals, glowing mushrooms and an ancient chest. Chests: 11.
- **Sky shrines:** on 3 satellites, light all 4 braziers within 25 s. The first clear gives that shrine's plume (Embers → Ember, Echoes → Echo, Gales → Gale). Later clears give ink and XP. Clears are saved.
- **Perches:** stand still on a treetop, ruin column, crag or shrine pillar to gain mana slowly.
- **World events:** the **Sky Leviathan** (every 25–35 min) is a giant sky whale that crosses the isles with 7 parasites riding on it. Clear them all before it leaves and everyone who helped gets a plume, 500 ink and 200 XP. A **Falling Star** (every 15–20 min) crashes onto an isle; the first 4 players to claim it get cosmic essence, and a Star Wisp guards it.
- **Juice:** camera shake (`_G.InkwingShake`), wing trails coloured by your aspect when flying fast, and weather around the camera in every zone (snow high in the storm, marine snow in the deep sea, ash and embers in Hell, stardust in the Cosmos, light motes in Heaven).
- **Admin:** LEVIATHAN, FALLING STAR, GIVE PLUME (N = 1–8 in plume order).
- Hooks for these systems are in the `Hooks` table in Main.server.lua (spawn/taken/hit/death/think/boss/plumeHit/ignore). The client code is in Skyways.client.lua.

## v1.7 - Feel pass (feedback)
- **Wind currents:** the big translucent beams and particle volumes are gone. Currents now show only thin, curling wind lines (short white trails) streaming along the path, and only within about 320 studs of you. Updraft particles are much subtler.
- **Merchant airship is solid:** you can land on the hull, deck, rails and crates, and the ship carries you while it moves.
- **Monsters no longer fly through things:** flying monsters raycast against collidable World parts, then slide along and climb over islands, trees and rocks. They also stay above the ground.
- **Folded wings:** wings tuck along your back on the ground and spread when you fly or boost. G keeps them spread on foot (PC).
- **PC:** the red lock-on reticle is hidden, since PC uses free aim; mobile keeps it.
- **NPCs:** new shared NPCModel.lua builds detailed, code-animated figures. They breathe, their heads follow you, beards sway and wings settle. Master Orren has layered robes, a long white beard, folded feathered wings and a crystal staff, and stands on a rune dais. The merchant captain has goggles, a cap, a scarf, a moustache and a backpack, and waves. Preview: previews/npcs2.png.
- **Meditation aura:** glowing ribbons loop around the seated body and arch over the head (like the sketch), with rising motes and a glow. The number of ribbons, their width, trail length, the light and the mote density all scale with your mana progress toward the next rank. It uses your aspect's colour, and everyone can see it.
- **Soul absorb (Skyrim style):** the remains flare and shrink while streams of light rise, corkscrew and pour into your chest. When they arrive you get ring bursts, a body flash and a screen tint with a shake. Big remains give more and longer streams.

## v1.8
- **Mana Sense (V, 3 mana):** enemy levels stay hidden ("Lv.?") until you sense them. If a monster is far stronger than you, it shows "MANA TOO VAST".
- Abilities now fire without a lock-on and target whatever you aim at. Physical abilities also cost mana now.
- Your wings stay folded on a single jump. Added a ground slam with a crater, shockwave and debris.
- The skill board scrolls, so it has room for more than 6 skills. Fixed the Plumes panel.
- **Day/night:** a 20-minute server-synced cycle (dawn, day, sunset, dusk, night). Admin TIME buttons: DAY / SUNSET / NIGHT / REAL.
- Removed the merchant billboard/toast and the sky pencils. Quill was rebuilt and now stands on the ground.
- **World:**
  - New treasure chests whose lids swing open.
  - A grand terraced Forgotten Temple and detailed sky shrines.
  - Giant stone hands holding up Quill's Rest.
  - Castle isles with waterfalls, a natural stone arch, a moored sky galleon, rock spires, and a colossal World Tree on the horizon.
- About 22.2k parts in Workspace.

## v1.8b
- **Skill board:** tiles now clip properly while scrolling (rotated frames were breaking the clipping), and every tile has an ink border. All-Seeing Eye markers are hidden while the board is open.
- **Sense aura:** look at a monster and press V to make its mana aura flare up for 9 s. Green means about your strength, yellow/orange means stronger, and red, bigger and spiky means dangerous. Crimson means far beyond you. The aura shrinks and dims as the monster loses HP.
- Removed the flat CloudSea/CloudDeck plates. The storm and the sea are still streamed in only when you get close, and a thick fog band now hides the swap.
- **Quill:** a fix for him floating. He was being placed on a floating "Quill" prop; his model is now QuillNPC.
- Removed the "BOSS RETURNS" announcement.
- **World Tree:** now grows on its own island with gripping roots, branching boughs, a clumped canopy, moss curtains, glowing fruit and isles caught in its roots. Animated fairies fly around it.

## v1.8c
- **Mana pool:** mana is now current / max and shown as a bar. You start at 1 / 1.
  - Meditating refills mana fast; meditating while FULL raises your max ("GROWING").
  - Mana also regenerates slowly on its own, and faster while perched.
  - Abilities and Sense spend current mana. Wing evolution and the power bonus use MAX mana.
  - Old saves: the stored mana becomes the max.
- **Islands:**
  - Tops are broken up with grassy mounds, mossy boulders and bush/flower clusters (also on low-detail isles).
  - Undersides come in 4 styles: rock spike with vines, hanging roots, glowing crystals, chunky boulders.
  - Fewer small rocks and isles, spread over much wider heights. The far horizon has fewer but bigger isles.
- **Ships:**
  - 4 rideable SKY SKIFFS: 3 around the starting island, 1 by the temple isle. Use the "Take the helm" prompt.
  - Skiff controls: W/S speed, A/D turn, X/Z up/down (or look up/down while sailing), Space to leave. Mobile uses the stick plus look.
  - 7 small sailboats and 5 balloon ships.
  - THE SKY ARK: a ~520-stud winged galleon that slowly circles the far sky, synced for everyone.

## v1.8d - Mana Core
- **Mana Core:** a small core in every player's chest. It starts black and barely noticeable, then purifies through grey and silver to glowing white as the core ranks up and fills its limit. Everyone can see it.
- **Core limits:** max mana stops at the core limit: D 60, C 300, B 1000, A 3000, S 12000. The limit is personal, raised by breakthrough quality (+3% Clean, +7% Perfect, stacking) and Zen Flight (+10%).
- **Breakthrough:**
  - Starts when you're at the limit with enough essence and keep meditating.
  - Survive-and-meditate for 60 s; moving or getting knocked out fails it (you lose 25% of current mana, 30 s cooldown).
  - Each other player within 35 studs speeds it up by 25% (up to 4). They can't make it fail.
  - Grades: Rough (dropped below 50% HP), Clean, or Perfect (hostile zone without dropping below 50% HP).
  - Success: column of light, flash, server announcement, rank up and wing evolution.
- **Meditation aura** is now tiny and scales on a log curve with max mana. It only becomes large at tens of thousands of mana.

## v1.8e
- **Night:** brighter, moonlit and readable. Dusk is brighter too.
- **Starter area:** the Ink Blob camp moved to hunting grounds on the far side of the start isle (about 70,175), away from spawn and Orren.
- **Remains:** removed the paper-square splat on death. Remains are now a glossy orb with the essence glowing inside, a soft light, twinkling motes and rising wisps.
- **Meditation:** the wing aura is hidden while meditating.
- **Sense is HELD (V / hold the button):**
  - Costs 1 mana per hold.
  - Weak or equal monsters nearby get read automatically. Stronger ones only by looking straight at them while holding.
  - The aura is now flame-like mana pouring off the monster's body: green to red, taller, denser and faster the stronger it is, thinning as it loses HP.
  - Fades 0.5 s after you let go.

## v1.9
- **Mana Vision** (hold V / SENSE): the screen tint shifts blue-grey. Monsters glow by how dangerous they are, NPCs glow gold and remains glow in their essence colour. Mana drains every second the server keeps it open, and vision closes when you run out.
- Weak monsters are read automatically. Stronger ones only show up when you look straight at them, and beings far beyond you show as dark static. Concealed monsters flicker.
- Health bars (and the boss bar) only show during Mana Vision. Exact numbers appear once Sense proficiency reaches B.
- **Soul rings** (1 to 5, coloured by strength) orbit strong beings in vision.
- **Proficiency** ranks F to S for every skill, earned through use. S means the skill has evolved. Efficiency: Sense costs 2 down to 0.5 mana/s and its range grows from 40 to 300; Meditate flow goes up to +100%; Absorb essence up to +50%.
- New skill **Mana Rotation**: unlocks at Meditate proficiency C. Mana regenerates 3x (up to 5x) and keeps working while you move or fly.
- Skill board redesigned: dark grey and gold, a card grid, and a detail panel at the bottom (rank, EXP bar, efficiency).
- New HUD: vitals at the bottom left (top left on mobile) with a core portrait, the core rank letter, and HP and mana bars. A menu orb opens Skills, Map, Inventory (plumes) and Wings.
- Clutter removed: skill-awakened banners, level-up popups, flat ground squares (InkFX.splat is now a no-op), the Wing Shrine label, and the old level panel. Remains labels show within 28 studs only. Enemy labels show a threat grade (F to S+) only after sensing, never a level.
- Leaderstats show **Core** (D-Rank and up). Levels are internal only (body tempering and HP).
- Genesis hunting grounds: hurt blobs flee to a brother and merge into it. A 12% **hidden blob** looks weak until Mana Vision sees through it. A **Blob Mother** appears after 10 blob kills.

## v1.10
- Skill board detail panel is empty for skills you don't have.
- Decluttered: the coin bar only pops up for 3 s when it changes. Quest text is white with a grey outline at the top left, with no box. Removed the altitude/debug readouts, the quality label, the LOCK MOUSE button on PC, and the ability/boost buttons on PC (keys only). ADMIN and QUALITY moved into the menu orb.
- HIDE UI: press H, or use the menu item. An eye button brings the UI back.
- Starter blobs no longer merge or flee. The hidden blob is milder (+3 lv, x1.8 HP). Blob Mother has 380 HP.
- No enemy names anywhere. During Mana Vision the monster you look at shows only its grade. All-Seeing Eye markers only appear in vision.
- Sense aura: weak monsters get a faint wisp, dangerous ones a towering red blaze. Soul rings were rebuilt as thin hoops made of segments.
- Wings melt away while walking. Hold jump for about 1.6 s to unfurl them (charge bar plus a burst). Flight is about 40% slower.
- WING STAMINA: flapping, climbing and boosting drain it. Diving and Mana Rotation give it back. When it's empty you can only glide down. Refills on the ground.
- DIVE AND PULL UP: speed built in a dive turns into height plus a burst (FOV kick, ring, shake).
- Water: much slower to swim and wade in. It gets dark within about 300 studs of depth.
- Thicker distance haze over the isles and the open ocean.
- Custom "hold E" prompt chip for every prompt.
- Dialogue window: camera eases in on the NPC, cinematic bars, typed lines, 2-3 choices (click, tap or 1-3 keys). Master Orren's lessons now run through it, and Quill has a dialogue too.
- The Deep Rift is now a burning hell sigil: molten jagged rings and a pentagram, a black pit breathing embers and smoke, and a low rumble. It has no text.
- The Sky Ark is walkable (deck, hull and castle are solid) and carries you while you stand on it. It sails faster.
