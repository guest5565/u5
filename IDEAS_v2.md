# Inkwing — Gameplay Deep Dive (v1.5)

## Where the game stands
**Strengths**
- Flight feels like the core fantasy.
- The vertical world is distinctive: islands, then storm, then cosmos and heaven above; sea, then deepsea, hell, abyss and the void below.
- Wings act as your class, and ranks D–S are earned through meditation.
- Skills come from training with Master Orren.
- Essence, giants, realms, chests and weather give the world texture.

**Weak spots, honestly**
1. **Combat is mostly "hold click".** You shoot, with 3 small abilities and Unleash on top. There's no reason to *fly well* while fighting.
2. **After the quest chain, the loop thins out.** Quests are linear, and once they're done the only goal left is "go deeper or higher".
3. **Flying has no skill ceiling.** Boost and momentum exist, but nothing rewards mastering movement (no races, currents or perfect dodges).
4. **No reason to play together.** Players share a server but never *need* each other.
5. **Monsters are stat blocks.** They differ in looks and numbers, rarely in how you have to fight them.

---

## TOP 5: what I'd build next (biggest impact per effort)

### 1. Aerial combat that rewards flying
- **Perfect Dodge:** boost through an enemy attack at the last moment. Time slows for 0.6 s and your next shot is a guaranteed crit with a feather burst. One move teaches players to read attacks and makes the attack effects we just built *matter*.
- **Sky Combo:** chain hits without touching the ground. A x1 → x5 multiplier grows bonus XP and essence; landing or taking a hit breaks it. This pushes players to stay airborne, which is the game's identity.
- **Dive Finisher:** dive onto a low-HP enemy from high above for an execution with an ink explosion. Altitude becomes a weapon.
- **Charged Shot:** hold for 1 s and release a piercing feather lance. This adds a choice besides spam.

### 2. Feather Plumes (wing mods that change how you play, not % boosts)
Socket 2–3 plumes into your wings. Plumes drop from bosses, golden monsters and Ancient Chests. Examples:
- **Split Plume:** shots fork into 3.
- **Homing Plume:** shots curve toward the target, at lower damage.
- **Storm Plume:** every 5th hit chains lightning to 3 enemies.
- **Gale Plume:** boosting leaves a wind trail that knocks enemies back.
- **Ink Plume:** kills leave an ink puddle that slows enemies.
- **Moth Plume:** you're invisible to enemies while gliding without shooting.

This gives loot a reason to exist, makes builds personal, and gives every boss a "chase drop".

### 3. Wind Currents and Sky Trials (movement mastery)
- **Wind Currents:** visible streams of drifting particles between islands and zones. Ride one to travel at 3x speed. They work as a natural fast-travel network that makes the huge distances fun instead of a chore.
- **Updrafts:** above waterfalls and cliffs. They give a free climb and recharge your boost.
- **Sky Trials:** ring courses (Genesis → Temple, Storm Gauntlet, Abyss Descent) with ghost replays and per-server best times. Each one gives a big reward the first time.

### 4. Masters of the Sky (more trainers, more skills)
Orren works well, so repeat the pattern once per zone. Each new master teaches one *gameplay-changing* skill:
- **Storm Hermit (storm isles), Thunder Step:** a short teleport dash that leaves lightning.
- **Old Diver (Ink Sea), Tide Breath:** fly underwater at full speed, and enemies there can't see you.
- **Fallen Seraph (Heaven), Halo Guard:** reflect projectiles for 2 s.
- **The Chained One (Hell), Hellfire Wings:** boosting sets your trail on fire.
- **(Abyss, no master.)** A whisper teaches **Void Glide:** pass through solid objects for a moment.

The trainings stay activity-based, like Orren's: stand still, dive deep, survive a lightning strike, and so on. Every zone gets a "who will I meet next?" pull.

### 5. Living world events (reasons to look up, and to group up)
- **The Leviathan Migration:** every ~30 min a colossal sky whale crosses the Genesis Isles. You can land on its back, where parasites guard essence crystals. Server-wide; you need others to clear its back before it leaves.
- **Ink Tide:** the Ink Sea rises for 3 minutes. Sea monsters attack the low islands, and players defend Quill's Rest.
- **Falling Star:** at night a star crashes onto a random isle. The first player to reach it gets cosmic essence, and a Star Wisp boss guards it.
- **Thunderhead:** a lightning storm drifts down from the storm layer. Lightning strikes empower anyone hit by them, rather than hurting them.

---

## More ideas (good, but smaller or later)

### Combat and monsters
- **Weak points:** glowing spots on big beings (the angels' eyes, the Comet Eater's core) take 3x damage. Aiming matters now that PC uses free aim.
- **Monster behaviours instead of stats:**
  - Bats flee and return in swarms.
  - Wasps call reinforcements unless killed fast.
  - Blobs merge into one bigger blob if left alone.
  - Angels shield each other.
- **Elite affixes:** random elites with modifiers like "Mirrored" (splits on death), "Gale" (pushes you away) or "Anchored" (pulls you toward it).
- **Boss phases with arena changes:** the Blot King drowns half his arena in ink; the Cinder King collapses floating platforms.

### Progression and RPG
- **Bestiary with research tasks:** for each monster, defeat 10, dodge 20 of its attacks, defeat 3 while diving. Completing an entry reveals its weak point and gives a feather. It gives every monster a reason to matter at any level.
- **Wing Molting (prestige):** at Rank S, molt your wings back to D but keep one essence aspect permanently. You can then stack two aspects, for hybrid wings like Storm-Abyss.
- **Titles from deeds:** "Leviathan Rider", "Never Landed" (a x5 Sky Combo), "Abyss Walker". Show them above your name.
- **Fledglings:** rescue lost baby birds stuck in dangerous places and bring them home to an aviary on the Genesis Isles. They become tiny companions that sit on your shoulder (cosmetic). The fun is in rescuing them.

### Exploration
- **Undercaves:** secret caves inside the rocky undersides of big islands, reached through waterfalls.
- **Perches:** land on any tree top or cliff tip to rest. Perched players regenerate mana faster, which is a soft alternative to meditating anywhere.
- **Sky Shrines:** small puzzle shrines (light the 4 braziers before the wind blows them out; follow the golden bird). They reward plumes.
- **Echo Stones:** touch one to see a ghost replay of a famous flight path. It hints at hidden places without any lore text.

### Co-op and social
- **Slipstream:** flying behind another player gives +20% speed, so flying as a group is naturally better.
- **Fusion Unleash:** two players who Unleash within 1 s of each other trigger a combined effect based on both aspects (Fire + Storm = firestorm).
- **Rescue:** a downed player falls slowly for 8 s, and a friend who catches them revives them.
- **Sky Duels (optional PvP):** challenge someone to a duel in a ring arena high above the storm. No forced PvP anywhere else.

### Feel and polish
- **Wind audio that follows your speed and altitude** (already partly there).
- **Wing trails** that change with your aspect (fire, ink, starlight).
- **Camera shake and slow-mo** on big moments: perfect dodges, boss kills, evolving.
- **Weather that differs per zone:** snow in the storm's upper layer, ash rain in Hell, light-pillars in Heaven.

---

## Suggested order
1. Perfect Dodge, Sky Combo and Dive Finisher (combat feel, about one session).
2. Wind Currents and Updrafts (fixes the long distances; also one session).
3. Feather Plumes plus plume drops (the loot loop).
4. The Storm Hermit as the second master (proves the pattern scales).
5. The Leviathan Migration (the signature event and trailer moment).
6. Bestiary, Sky Trials, then the co-op mechanics.
