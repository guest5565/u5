# Inkwing: Cultivation System (design draft)

## 1. The Mana Core
- Every player has a **core**. Its rank (D, C, B, A, S) is shown as a coloured core in the chest and as the aura colour band:
  - D = dull red, C = orange, B = yellow, A = silver, S = white-gold.
- **Max mana grows by meditating while full** (already built).
- Each core rank has a **cap**. When you reach it: "YOUR CORE IS AT ITS LIMIT", and max mana stops growing.
- **Caps are personal.** The base cap per rank is raised by:
  - **Core refinement:** affinity purity (see 2) adds up to +15%.
  - **Skill evolutions:** e.g. Zen Flight +10%, Gluttony +5% per 1000 essence devoured (capped).
  - **Breakthrough quality:** a perfect breakthrough adds +5% to every later cap. It stacks.
  - Example: two D-rank players, one capped at 1000 and the other at 1200.
- **Display:** `MANA 840 / 1000  (CORE D - LIMIT 1200)`.

## 2. Affinity (all elements, blended)
- **Elements:** Fire, Frost, Storm, Nature, Void/Abyss, Holy, Cosmic (reusing the existing essences).
- **Each element has its own affinity %.** Sources:
  - Absorbing essence of that element.
  - Meditating in a zone of that element: storm = Storm, sea = Abyss, Heaven = Holy, Cosmos = Cosmic, World Tree = Nature, Hell = Fire.
- **Top element = primary.** If the 2nd element is at least 60% of the 1st, you have a **dual affinity** (e.g. Storm-Abyss).
- **Purity** = how dominant the primary is. High purity gives stronger single-element effects and raises the core cap. A blend gives hybrid effects.
- **What affinity changes:**
  - The element of your 3 wing abilities (Storm Gust chains lightning, Abyss Gust pulls, Fire Gust leaves burning trails...).
  - Your aura colour.
  - The look of your evolved wings.
- **Not permanent:** affinities slowly drift toward whatever you feed them.
- **Essence folds in:** absorbing essence = affinity progress, so there is no separate essence currency for the player to think about.

## 3. Breakthroughs
- **Trigger:** at your cap, meditate in a zone that matches one of your affinities and choose "Attempt Breakthrough".
- **The trial (60 s):** stay inside the circle and keep meditating. A meter fills.
  - Safe zones: no monsters. The challenge is "mana surges", short rhythm prompts (tap at the right moment) that affect quality.
  - Hostile zones (storm, deep sea, Hell...): monsters are drawn to the surge. Higher risk gives a higher quality bonus.
- **Friends:** they can stand in the outer ring to guard you and feed mana, which steadies the surges. Guards get a small affinity reward.
- **Result:**
  - Rank up, core colour change, wing evolution, server announcement.
  - Quality grades: Rough / Clean / Perfect, which change future caps.
- **Failure:** you lose some mana and retry after a short cooldown. No permanent loss.

## 4. Presence, Sense, Conceal (players AND monsters)
- **Presence** = a strength value: core rank, max mana and level, minus Conceal.
- **Sense (V):**
  - Weak or equal beings are sensed consistently, including passively nearby once trained.
  - Stronger beings need **direct observation**: look at them and press V. Even then, the true number only shows if your sense skill rank is high enough. Otherwise you see "MANA TOO VAST".
  - Shows the aura: green = your level, red, bigger and spikier = stronger. It dims with HP (already built).
- **Conceal (skill):** lowers your presence. If your Conceal is above an observer's Sense, they read you as weaker, or can't sense you at all.
  - **Monsters can have Conceal too:** "hidden" monsters show as weak until observed closely, then reveal themselves. Ambush predators, elite disguises.
- **Flare (skill):** release your presence. Monsters far below you **freeze** for a few seconds or flee. Equal monsters become enraged and target you.
  - Some bosses Flare at you; low-rank players get slowed or frozen briefly. No stun in a way that feels unfair: short, telegraphed.

## 5. Resonances (hidden skill combos)
- **Discovered by doing**, not shown in a menu. A tile appears on the skill board when you discover one.
- **"???" tiles give vague hints.**
- Starter set:

| Combo | Result |
|---|---|
| Sense + Gluttony on the same target | **Soul Harvest:** double affinity gain |
| Meditate during a storm (Storm affinity) | **Stormcall:** the next ability calls lightning |
| Flare + Unleash | **Domain:** a zone where weaker enemies are slowed |
| Conceal + Dive Strike from unsensed | **Ambush:** a guaranteed crit |
| Breakthrough with a friend guarding | **Bonded Core:** a small permanent bond buff when near that friend |

## 6. Pacing

| When | Unlock |
|---|---|
| 0–10 min | Wings, combat, Meditate, mana bar |
| ~30 min | Sense, absorbing, first cap and first breakthrough (D→C) |
| 1–2 h | Affinity becomes visible (tinted mana, elemental abilities) |
| Rank B | Conceal and Flare training from mentors, first Resonance hints |
| Rank A–S | Dual affinities, Domains, presence games in PvP |

## Open questions
- Rhythm prompts in breakthroughs: yes or no? They're fun on mobile, but they're an extra mechanic.
- Should guards in someone's breakthrough be able to fail it, e.g. trolls leaving?
- Max players per breakthrough circle?
