--!nonstrict
-- INKWING :: shared game data (wings, enemies, spawns, zones, quests, curves)
local G = {}

G.HUB = Vector3.new(0, 101, 8)
-- VERTICAL LAYOUT (y). Zones are far apart and hidden from each other (client streaming + fog).
--   6600..7300 HEAVEN | 5100..6600 the light climb | 4300..5100 THE COSMOS | 2750..4300 thin air
--   2150..2750 THE STORM | 330..2150 the windy climb | 60..260 SKY ISLES (start)
--   -700 INK SEA surface + sea isles | -700..-2700 underwater | -2700..-3400 THE INK DEEPSEA (Blot King)
--   -4200..-5000 HELL (walkable lava isles) | -5800..-6600 THE ABYSS | -7400..-8400 THE UNKNOWN
-- No hard gates: anyone can fly anywhere - the monsters up/down there are just much stronger.
G.STORM_GATE = 330 -- the cloud deck above the isles
G.STORM_BASE = 2150 -- rain / lightning / tornados start here
G.STORM_SHOW = 1400 -- storm content streams in above this height
G.STORM_TOP = 2750 -- the storm clouds end here, the air thins out
G.COSMOS_SHOW = 3600
G.COSMOS_BASE = 4300 -- THE COSMOS (paper planets, moon isles, constellations)
G.COSMOS_TOP = 5100
G.HEAVEN_SHOW = 5800
G.HEAVEN_BASE = 6600 -- HEAVEN (gold and white cloud isles, the Halo Warden)
G.CEILING = 7400 -- top of the world (v0.3)
G.SEA = -700 -- the ink ocean surface
G.SEA_SHOW = -250 -- the ocean streams in below this height
G.DEPTH_LINE = -2700 -- the Ink Deepsea begin
G.DEPTH_SHOW = -1700 -- depths content streams in below this height
G.DEPTH_TIER = 3 -- recommended wing tier for the depths (quest)
G.STORM_TIER = 5 -- recommended wing tier for the storm
G.HELL_SHOW = -3700
G.HELL_TOP = -4200 -- HELL: lava sea, volcano isles you can WALK on, the Cinder King
G.HELL_BOTTOM = -5000
G.ABYSS_SHOW = -5300
G.ABYSS_TOP = -5800 -- THE ABYSS: black, silent, things watching
G.ABYSS_BOTTOM = -6600
G.UNKNOWN_SHOW = -6900
G.UNKNOWN_TOP = -7400 -- THE UNKNOWN: cosmic beings bigger than islands
G.FLOOR = -8600

---------------------------------------------------------------------------
-- WINGS = your class. auto-attack + 3 abilities + a flight trait
---------------------------------------------------------------------------
G.Wings = {
	Paper = {
		name = "Paper Wings", rarity = "Common", theme = "Paper", color = Color3.fromRGB(250, 246, 230), shot = Color3.fromRGB(255, 255, 255),
		dmg = 10, range = 55, rate = 0.7, speed = 46, trait = "Glide + flight",
		abilities = {
			{ id = "gust", name = "GUST", cd = 6, kind = "aoe", radius = 18, mult = 2.4, desc = "Blast everything around your target" },
			{ id = "fold", name = "FOLD SHIELD", cd = 14, kind = "shield", dur = 4, reduce = 0.6, desc = "Take 60% less damage for 4s" },
			{ id = "dive", name = "DIVE STRIKE", cd = 8, kind = "dive", mult = 4.2, desc = "Dash into your target for a huge hit" },
		},
	},
	Ink = {
		name = "Ink Wings", rarity = "Rare", theme = "Ink", color = Color3.fromRGB(60, 80, 200), shot = Color3.fromRGB(80, 110, 255),
		dmg = 17, range = 60, rate = 0.75, speed = 54, trait = "Faster boost, dives deeper",
		abilities = {
			{ id = "splash", name = "INK SPLASH", cd = 7, kind = "aoe", radius = 20, mult = 3, desc = "A big splash around your target" },
			{ id = "burn", name = "INK BURN", cd = 9, kind = "dot", ticks = 6, mult = 0.7, desc = "Soak your target: damage over time" },
			{ id = "blot", name = "BLOT TRAP", cd = 12, kind = "root", dur = 4, mult = 1.6, desc = "Pin your target in place for 4s" },
		},
	},
}
G.Wings.Coral = {
	name = "Coral Wings", rarity = "Rare", theme = "Coral", color = Color3.fromRGB(255, 120, 130), shot = Color3.fromRGB(255, 170, 160),
	dmg = 26, range = 62, rate = 0.7, speed = 58, trait = "Swims fast underwater", unlock = "DEFEAT THE INKVERN IN THE INK DEEPSEA",
	abilities = {
		{ id = "tide", name = "TIDAL BURST", cd = 7, kind = "aoe", radius = 24, mult = 3.2, desc = "A wave crashes around your target" },
		{ id = "shell", name = "SHELL GUARD", cd = 14, kind = "shield", dur = 5, reduce = 0.6, desc = "Take 60% less damage for 5s" },
		{ id = "eel", name = "EEL LUNGE", cd = 8, kind = "dive", mult = 4.6, desc = "Lunge into your target" },
	},
}
G.Wings.Star = {
	name = "Star Wings", rarity = "Epic", theme = "Star", color = Color3.fromRGB(120, 90, 255), shot = Color3.fromRGB(255, 240, 150),
	dmg = 38, range = 70, rate = 0.65, speed = 64, trait = "Long range, fast boost", unlock = "DEFEAT THE COMET EATER IN THE COSMOS",
	abilities = {
		{ id = "nova", name = "NOVA", cd = 8, kind = "aoe", radius = 26, mult = 3.6, desc = "A star bursts on your target" },
		{ id = "orbit", name = "GRAVITY WELL", cd = 12, kind = "root", dur = 4, mult = 2, desc = "Hold your target in orbit for 4s" },
		{ id = "comet", name = "COMET DIVE", cd = 8, kind = "dive", mult = 5, desc = "Crash into your target like a comet" },
	},
}
G.Wings.Halo = {
	name = "Halo Wings", rarity = "Legendary", theme = "Halo", color = Color3.fromRGB(255, 220, 120), shot = Color3.fromRGB(255, 250, 210),
	dmg = 52, range = 72, rate = 0.6, speed = 70, trait = "The fastest wings in the sky", unlock = "DEFEAT THE HALO WARDEN IN HEAVEN",
	abilities = {
		{ id = "judg", name = "JUDGEMENT", cd = 8, kind = "aoe", radius = 28, mult = 4, desc = "Light falls on your target" },
		{ id = "grace", name = "GRACE", cd = 14, kind = "shield", dur = 5, reduce = 0.7, desc = "Take 70% less damage for 5s" },
		{ id = "brand", name = "HOLY BRAND", cd = 9, kind = "dot", ticks = 8, mult = 0.8, desc = "Burn your target with light" },
	},
}
G.Wings.Ember = {
	name = "Ember Wings", rarity = "Epic", theme = "Ember", color = Color3.fromRGB(255, 110, 40), shot = Color3.fromRGB(255, 170, 60),
	dmg = 62, range = 64, rate = 0.6, speed = 66, trait = "Burns everything it touches", unlock = "DEFEAT THE CINDER KING IN HELL",
	abilities = {
		{ id = "erupt", name = "ERUPTION", cd = 8, kind = "aoe", radius = 26, mult = 4, desc = "Lava bursts from your target" },
		{ id = "scorch", name = "SCORCH", cd = 9, kind = "dot", ticks = 8, mult = 0.9, desc = "Set your target on fire" },
		{ id = "meteor", name = "METEOR DIVE", cd = 8, kind = "dive", mult = 5.4, desc = "Fall on your target like a meteor" },
	},
}
G.Wings.Void = {
	name = "Void Wings", rarity = "Mythic", theme = "Void", color = Color3.fromRGB(30, 10, 50), shot = Color3.fromRGB(190, 120, 255),
	dmg = 80, range = 76, rate = 0.55, speed = 74, trait = "Made of the Unknown itself", unlock = "DEFEAT THE UNKNOWN",
	abilities = {
		{ id = "gaze", name = "THE GAZE", cd = 8, kind = "aoe", radius = 30, mult = 4.5, desc = "Everything near your target is seen" },
		{ id = "unmake", name = "UNMAKE", cd = 12, kind = "root", dur = 4, mult = 2.6, desc = "Erase your target from moving for 4s" },
		{ id = "between", name = "IN BETWEEN", cd = 14, kind = "shield", dur = 5, reduce = 0.75, desc = "Slip half out of the world: 75% less damage" },
	},
}
G.Wings.Ink.unlock = "DEFEAT THE BLOT KING IN THE INK SEA"
G.WingOrder = { "Paper", "Ink", "Coral", "Star", "Halo", "Ember", "Void" }
G.MAX_TIER = 10
function G.WingCost(tier) -- cost to go tier -> tier+1
	return { feathers = tier * 3, ink = 60 * tier * tier }
end
function G.WingPower(tier)
	return 1 + 0.2 * (tier - 1)
end
function G.LevelPower(level)
	return 1 + 0.04 * (level - 1)
end
function G.MaxHP(level)
	return 100 + (level - 1) * 12
end
function G.XPNeed(level)
	return math.floor(40 * level ^ 1.5)
end
G.MAX_LEVEL = 100

---------------------------------------------------------------------------
-- ENEMIES (built on the client by EnemyModel)
---------------------------------------------------------------------------
G.Enemies = {
	BlobMother = { name = "Blob Mother", level = 4, hp = 380, dmg = 10, speed = 8, aggro = 60, reach = 14, atk = 1.8, xp = 220, ink = 120, feather = 3, fly = true, size = 16 },
	InkBlob = { name = "Ink Blob", level = 1, hp = 55, dmg = 6, speed = 11, aggro = 30, reach = 7, atk = 1.4, xp = 14, ink = 8, feather = 0.3, fly = true },
	ScribbleBat = { name = "Scribble Bat", level = 4, hp = 95, dmg = 8, speed = 26, aggro = 45, reach = 7, atk = 1.2, xp = 24, ink = 12, feather = 0.35, fly = true },
	PaperWasp = { name = "Paper Wasp", level = 8, hp = 150, dmg = 11, speed = 22, aggro = 55, reach = 42, atk = 2.4, ranged = true, xp = 38, ink = 18, feather = 0.45, fly = true },
	InkShade = { name = "Ink Shade", level = 12, hp = 280, dmg = 16, speed = 24, aggro = 60, reach = 9, atk = 1.3, xp = 65, ink = 32, feather = 0.6, fly = true },
	BlotKing = { name = "THE BLOT KING", level = 15, hp = 5000, dmg = 28, speed = 14, aggro = 120, reach = 30, atk = 3, xp = 700, ink = 600, feather = 1, fly = true, boss = true, featherN = 12, size = 20 },
	-- the Ink Sea
	InkEel = { name = "Ink Eel", level = 10, hp = 220, dmg = 14, speed = 30, aggro = 55, reach = 8, atk = 1.1, xp = 50, ink = 24, feather = 0.5, fly = true },
	Inkvern = { name = "THE INKVERN", level = 20, hp = 9000, dmg = 34, speed = 18, aggro = 170, reach = 40, atk = 3, xp = 1200, ink = 900, feather = 1, fly = true, boss = true, featherN = 15, size = 30 },
	-- the Cosmos
	StarWisp = { name = "Star Spawn", level = 30, hp = 900, dmg = 28, speed = 22, aggro = 140, reach = 90, atk = 2.2, ranged = true, xp = 150, ink = 64, feather = 0.6, fly = true, size = 36, strongLv = 35 },
	CometHound = { name = "Void Gazer", level = 33, hp = 1200, dmg = 34, speed = 30, aggro = 140, reach = 34, atk = 1.3, xp = 180, ink = 72, feather = 0.6, fly = true, size = 30, strongLv = 35 },
	CometEater = { name = "THE COMET EATER", level = 36, hp = 22000, dmg = 48, speed = 14, aggro = 170, reach = 40, atk = 2.8, xp = 3000, ink = 2000, feather = 1, fly = true, boss = true, featherN = 20, size = 30 },
	-- Heaven
	HaloSentinel = { name = "Ophan", level = 42, hp = 2600, dmg = 42, speed = 22, aggro = 130, reach = 90, atk = 2, ranged = true, xp = 270, ink = 115, feather = 0.7, fly = true, size = 32, peaceful = true },
	GildedMoth = { name = "Cherub", level = 45, hp = 3200, dmg = 48, speed = 34, aggro = 130, reach = 30, atk = 1.1, xp = 310, ink = 125, feather = 0.7, fly = true, size = 30, peaceful = true },
	-- Hell (walking monsters on the volcano isles)
	CinderImp = { name = "Cinder Imp", level = 55, hp = 3000, dmg = 55, speed = 22, aggro = 80, reach = 9, atk = 1.1, xp = 380, ink = 150, feather = 0.7, size = 5 },
	AshWraith = { name = "Ash Wraith", level = 58, hp = 3400, dmg = 58, speed = 28, aggro = 100, reach = 60, atk = 2, ranged = true, xp = 420, ink = 165, feather = 0.7, fly = true, size = 9 },
	CinderKing = { name = "THE CINDER KING", level = 62, hp = 80000, dmg = 80, speed = 10, aggro = 180, reach = 46, atk = 2.6, xp = 9000, ink = 6000, feather = 1, boss = true, featherN = 40, size = 34 },
	-- the Abyss
	AbyssLurker = { name = "Abyss Lurker", level = 66, hp = 9000, dmg = 66, speed = 46, aggro = 240, reach = 40, atk = 1.2, xp = 520, ink = 200, feather = 0.8, fly = true, size = 42 },
	-- the Unknown
	Hollow = { name = "The Hollow", level = 75, hp = 6000, dmg = 80, speed = 26, aggro = 130, reach = 70, atk = 2, ranged = true, xp = 700, ink = 260, feather = 0.8, fly = true, size = 18 },
	-- v0.8 GIANT ANGELS: ~100x a player. NEUTRAL until you hit them; allies to the Blessed (Halo Warden slayers)
	Seraphim = { name = "SERAPHIM", level = 70, hp = 600000, dmg = 140, speed = 4, aggro = 0, reach = 700, atk = 3.5, xp = 40000, ink = 25000, feather = 1, featherN = 60, fly = true, giant = true, neutral = true, size = 300 },
	Throne = { name = "THE THRONE", level = 72, hp = 700000, dmg = 150, speed = 3, aggro = 0, reach = 700, atk = 3.2, xp = 45000, ink = 28000, feather = 1, featherN = 70, fly = true, giant = true, neutral = true, size = 280 },
	-- v0.9c colossi: hunched titans of rock and fibre (Abyss: aggressive | Cosmos: only notice the strong)
	Forgotten = { name = "THE FORGOTTEN", level = 72, hp = 250000, dmg = 150, speed = 2, aggro = 0, reach = 650, atk = 3.4, xp = 25000, ink = 16000, feather = 1, featherN = 50, fly = true, giant = true, aggressive = 480, size = 520 },
	Hunched = { name = "THE HUNCHED ONE", level = 55, hp = 160000, dmg = 95, speed = 2, aggro = 0, reach = 650, atk = 3.6, xp = 14000, ink = 9000, feather = 1, featherN = 35, fly = true, giant = true, aggressive = 500, strongLv = 35, size = 520 },
	-- v1.0 COSMIC GIANTS
	MawBelow = { name = "THE MAW BELOW", level = 66, hp = 320000, dmg = 150, speed = 1, aggro = 0, reach = 650, atk = 3.2, xp = 26000, ink = 17000, feather = 1, featherN = 50, fly = true, giant = true, aggressive = 520, size = 620 },
	Dreamer = { name = "THE DREAMER", level = 82, hp = 450000, dmg = 190, speed = 1, aggro = 0, reach = 700, atk = 3, xp = 40000, ink = 26000, feather = 1, featherN = 70, fly = true, giant = true, size = 600 },
	StarLeviathan = { name = "STAR LEVIATHAN", level = 50, hp = 200000, dmg = 90, speed = 3, aggro = 0, reach = 650, atk = 3.6, xp = 15000, ink = 9000, feather = 1, featherN = 35, fly = true, giant = true, aggressive = 600, strongLv = 35, size = 700 },
	Weaver = { name = "THE WEAVER", level = 52, hp = 220000, dmg = 95, speed = 2, aggro = 0, reach = 600, atk = 3.4, xp = 16000, ink = 10000, feather = 1, featherN = 38, fly = true, giant = true, aggressive = 500, strongLv = 35, size = 520 },
	EclipseEye = { name = "THE ECLIPSE EYE", level = 58, hp = 260000, dmg = 110, speed = 1, aggro = 0, reach = 800, atk = 4, xp = 19000, ink = 12000, feather = 1, featherN = 42, fly = true, giant = true, aggressive = 800, strongLv = 40, size = 640 },
	Nameless = { name = "THE NAMELESS", level = 95, hp = 2000000, dmg = 220, speed = 2, aggro = 0, reach = 1400, atk = 4, xp = 90000, ink = 60000, feather = 1, featherN = 120, fly = true, giant = true, aggressive = 650, size = 900 },
	TheUnknown = { name = "THE UNKNOWN", level = 90, hp = 250000, dmg = 120, speed = 8, aggro = 300, reach = 80, atk = 2.4, xp = 30000, ink = 20000, feather = 1, fly = true, boss = true, featherN = 80, size = 90 },
	HaloWarden = { name = "THE HALO WARDEN", level = 50, hp = 60000, dmg = 62, speed = 14, aggro = 260, reach = 90, atk = 2.6, xp = 6000, ink = 4000, feather = 1, fly = true, boss = true, featherN = 30, size = 120 },
}

-- TORNADOS (client visuals + wind; deterministic paths so every player sees the same storm)
G.Tornados = {
	{ center = Vector3.new(-60, 2200, -150), orbit = 70, speed = 0.05, height = 240, r = 26, phase = 0 },
	{ center = Vector3.new(150, 2200, -40), orbit = 55, speed = -0.06, height = 230, r = 22, phase = 2 },
	{ center = Vector3.new(-170, 2200, 20), orbit = 60, speed = 0.045, height = 220, r = 20, phase = 4 },
	{ center = Vector3.new(60, 2200, -260), orbit = 80, speed = -0.04, height = 250, r = 28, phase = 1 },
}
function G.TornadoPos(t, now)
	local a = t.phase + now * t.speed
	return t.center + Vector3.new(math.cos(a) * t.orbit, 0, math.sin(a) * t.orbit)
end

-- spawn areas: centre, radius, height band (fly) / island top (ground)
G.Spawns = {
	{ type = "InkBlob", center = Vector3.new(-10, 96, -90), r = 30, max = 6 },
	{ type = "InkBlob", center = Vector3.new(70, 104, -40), r = 24, max = 4 },
	{ type = "ScribbleBat", center = Vector3.new(-110, 158, -60), r = 40, max = 6 },
	{ type = "PaperWasp", center = Vector3.new(120, 182, -150), r = 40, max = 6 },
	{ type = "ScribbleBat", center = Vector3.new(-90, 2300, -120), r = 70, max = 7, level = 22 },
	{ type = "PaperWasp", center = Vector3.new(130, 2380, -220), r = 70, max = 7, level = 26 },
	{ type = "InkShade", center = Vector3.new(-60, -1100, -40), r = 110, max = 8, level = 12 },
	{ type = "InkShade", center = Vector3.new(160, -1350, -220), r = 110, max = 7, level = 14 },
	{ type = "InkEel", center = Vector3.new(0, -3000, -60), r = 120, max = 8, level = 17 },
	{ type = "InkEel", center = Vector3.new(150, -3200, -200), r = 120, max = 7, level = 19 },
	{ type = "StarWisp", center = Vector3.new(-90, 4560, -120), r = 160, max = 9 },
	{ type = "CometHound", center = Vector3.new(130, 4700, -40), r = 160, max = 9 },
	{ type = "HaloSentinel", center = Vector3.new(-190, 6800, -10), r = 100, max = 3 },
	{ type = "GildedMoth", center = Vector3.new(190, 6820, -20), r = 100, max = 3 },
	{ type = "CinderImp", center = Vector3.new(-140, -4500 + 3.5, -80), r = 30, max = 6, ground = true },
	{ type = "CinderImp", center = Vector3.new(150, -4560 + 3.5, 60), r = 26, max = 5, ground = true },
	{ type = "AshWraith", center = Vector3.new(0, -4420, -60), r = 120, max = 6 },
}

-- v0.7 SOFT GATES: you CAN fly anywhere, but zones above/below your wings hurt (thin air, cold, pressure, heat).
G.WING_ORDER = { "Paper", "Ink", "Coral", "Star", "Halo", "Ember", "Void" }
G.WING_RANK = {}
for i, n in ipairs(G.WING_ORDER) do
	G.WING_RANK[n] = i
end
-- returns zone label, required wing rank, hazard word
function G.ZoneNeed(y)
	if y > G.HEAVEN_BASE - 150 then
		return "HEAVEN", 4, "HOLY LIGHT BURNS YOU"
	elseif y > G.COSMOS_BASE - 200 then
		return "THE COSMOS", 3, "THE VOID OF SPACE FREEZES YOU"
	elseif y > G.STORM_BASE then
		return "THE STORM", 2, "THE STORM TEARS AT YOUR WINGS"
	elseif y < G.UNKNOWN_TOP + 300 then
		return "THE UNKNOWN", 6, "YOUR MIND IS UNRAVELLING"
	elseif y < G.ABYSS_TOP + 250 then
		return "THE ABYSS", 6, "THE DARK CRUSHES YOU"
	elseif y < G.HELL_TOP + 250 then
		return "HELL", 5, "THE HEAT MELTS YOUR WINGS"
	elseif y < G.DEPTH_LINE then
		return "THE INK DEEPSEA", 2, "THE PRESSURE CRUSHES YOU"
	end
	return nil, 1, nil
end
function G.BestRank(wings)
	local r = 1
	for n, _ in pairs(wings or {}) do
		r = math.max(r, G.WING_RANK[n] or 1)
	end
	return r
end
G.EXPOSURE_DPS = 0.035 -- fraction of max HP per second, per missing wing rank
G.FLY_CAP = { 150, 190, 230, 270, 310, 350, 400 } -- top speed (studs/s) by best wing rank, with momentum

for k = 0, 5 do -- v0.8 outer Heaven: cherub flocks and ophan wheels between the far districts
	local a = k / 6 * math.pi * 2 + 0.3
	table.insert(G.Spawns, { type = k % 2 == 0 and "GildedMoth" or "HaloSentinel", center = Vector3.new(math.cos(a) * 2000, 6800, math.sin(a) * 2000), r = 200, max = 2, level = 50, outer = true }) -- v0.9c: Heaven is calmer
end
for k = 0, 11 do -- v0.9 the Underworld has its own place: camps all the way out
	local a = k / 12 * math.pi * 2 + 0.2
	local kind = "AshWraith" -- v0.9c: the Abyss belongs to the Forgotten alone
	local y = ({ AshWraith = -4420, AbyssLurker = -6200, Hollow = -7800 })[kind]
	table.insert(G.Spawns, { type = kind, center = Vector3.new(math.cos(a) * 2000, y, math.sin(a) * 2000), r = 250, max = (kind == "AbyssLurker" and 1 or 5), level = ({ AshWraith = 62, AbyssLurker = 70, Hollow = 80 })[kind], outer = true })
end
table.insert(G.Spawns, 1, { type = "InkBlob", center = Vector3.new(70, 46, 175), r = 50, max = 6 }) -- v1.8e: the hunting grounds, far side of the isle (spawn + Orren stay calm) -- v1.1 GENESIS ISLE: the first hunt, on foot
G.Giants = {
	{ kind = "Forgotten", pos = Vector3.new(700, -6250, -500), respawn = 600 },
	{ kind = "Forgotten", pos = Vector3.new(-1600, -6200, 1300), respawn = 600 },
	{ kind = "Forgotten", pos = Vector3.new(1200, -6300, 2000), respawn = 600 },
	{ kind = "Hunched", pos = Vector3.new(1500, 4700, -700), respawn = 600 },
	{ kind = "Hunched", pos = Vector3.new(-1300, 4750, 1100), respawn = 600 },
	{ kind = "Hunched", pos = Vector3.new(-600, 4650, -2000), respawn = 600 },
	{ kind = "MawBelow", pos = Vector3.new(-1700, -4750, -600), respawn = 600 },
	{ kind = "MawBelow", pos = Vector3.new(1900, -4750, 1200), respawn = 600 },
	{ kind = "Dreamer", pos = Vector3.new(-300, -6300, -2300), respawn = 900 },
	{ kind = "StarLeviathan", pos = Vector3.new(2400, 4800, 400), respawn = 600 },
	{ kind = "StarLeviathan", pos = Vector3.new(-2600, 4900, -900), respawn = 600 },
	{ kind = "Weaver", pos = Vector3.new(500, 4600, 2600), respawn = 600 },
	{ kind = "Weaver", pos = Vector3.new(-1800, 4700, 2400), respawn = 600 },
	{ kind = "EclipseEye", pos = Vector3.new(0, 5050, -3000), respawn = 900 },
	{ kind = "Nameless", pos = Vector3.new(900, -8000, -1400), respawn = 900 }, -- the Unknown: one thing you cannot understand -- they drift slowly around their home, high above Heaven's districts
	{ kind = "Seraphim", pos = Vector3.new(-1500, 7150, -600), respawn = 600 },
	{ kind = "Seraphim", pos = Vector3.new(1400, 7200, 900), respawn = 600 },
	{ kind = "Throne", pos = Vector3.new(300, 7350, -1700), respawn = 600 },
}
G.ZONE_RADIUS = 1300 -- v0.6: zones are much wider
do -- outer rings: every flying spawn also appears out in the wider zone (a bit stronger)
	local base = #G.Spawns
	for i = 1, base do
		local sp = G.Spawns[i]
		if not sp.ground and sp.type ~= "InkBlob" and sp.type ~= "AbyssLurker" then
			for k = 0, 2 do
				local a = k * math.pi * 2 / 3 + i * 0.7
				local d = 650 + (i % 3) * 150
				table.insert(G.Spawns, { type = sp.type, center = Vector3.new(math.cos(a) * d, sp.center.Y, math.sin(a) * d), r = sp.r + 40, max = math.max(4, sp.max - 2), level = sp.level and sp.level + 2 or nil, outer = true })
			end
		end
	end
	for _, c in ipairs({ { 798, -4570, -93 }, { 232, -4482, 706 }, { -976, -4544, 69 }, { 231, -4563, -1241 } }) do
		table.insert(G.Spawns, { type = "CinderImp", center = Vector3.new(c[1], c[2] + 3.5, c[3]), r = 24, max = 4, ground = true, outer = true })
	end
end
G.BOSS_POS = Vector3.new(0, -1478, -100) -- the Blot King now rules the Ink Sea
G.BOSS_RESPAWN = 120
-- BOSSES: one per zone. roam = circles around pos (radius). wing = dropped on first kill.
G.Bosses = {
	{ kind = "BlotKing", pos = G.BOSS_POS, respawn = 120, wing = "Ink", adds = "InkBlob", zone = "THE INK SEA" },
	{ kind = "Inkvern", pos = Vector3.new(0, -3150, -80), respawn = 150, wing = "Coral", adds = "InkEel", roam = 110, zone = "THE INK DEEPSEA" },
	{ kind = "CometEater", pos = Vector3.new(0, 4900, -260), respawn = 180, wing = "Star", adds = "StarWisp", roam = 50, zone = "THE COSMOS" },
	{ kind = "HaloWarden", pos = Vector3.new(0, 7020, -280), respawn = 240, wing = "Halo", adds = "HaloSentinel", zone = "HEAVEN" },
	{ kind = "CinderKing", pos = Vector3.new(0, -4640 + 16.5, -320), respawn = 300, wing = "Ember", adds = "CinderImp", zone = "HELL" },
	{ kind = "TheUnknown", pos = Vector3.new(0, -8000, -500), respawn = 420, wing = "Void", adds = "Hollow", roam = 120, zone = "THE UNKNOWN" },
}
---------------------------------------------------------------------------
-- ZONES (banner + lighting)
---------------------------------------------------------------------------
G.Zones = {
	{ name = "QUILL'S REST", test = function(p)
		return (p - Vector3.new(0, 100, 0)).Magnitude < 40
	end },
	{ name = "THE HALO WARDEN'S GATE", test = function(p)
		return (p - G.Bosses[4].pos).Magnitude < 90
	end, color = Color3.fromRGB(255, 220, 120) },
	{ name = "HEAVEN", test = function(p)
		return p.Y > G.HEAVEN_BASE - 150
	end, color = Color3.fromRGB(255, 236, 160) },
	{ name = "THE COMET EATER'S ORBIT", test = function(p)
		return (p - G.Bosses[3].pos).Magnitude < 100
	end, color = Color3.fromRGB(255, 120, 90) },
	{ name = "THE COSMOS", test = function(p)
		return p.Y > G.COSMOS_BASE - 200 and p.Y < G.COSMOS_TOP + 300
	end, color = Color3.fromRGB(170, 150, 255) },
	{ name = "THE STORM", test = function(p)
		return p.Y > G.STORM_BASE and p.Y < G.STORM_TOP + 100
	end, color = Color3.fromRGB(190, 200, 230) },
	{ name = "THE SKY ISLES", test = function(p)
		return p.Y > -200 and p.Y < G.STORM_GATE + 100
	end },
	{ name = "THE BLOT KING'S THRONE", test = function(p)
		return (p - G.BOSS_POS).Magnitude < 70
	end, first = true, color = Color3.fromRGB(255, 90, 120) },
	{ name = "THE INKVERN'S LAIR", test = function(p)
		return (p - G.Bosses[2].pos).Magnitude < 160
	end, color = Color3.fromRGB(120, 220, 255) },
	{ name = "THE DRIFTWOOD ISLES", test = function(p)
		return p.Y >= G.SEA and p.Y < G.SEA + 160
	end, color = Color3.fromRGB(140, 210, 255) },
	{ name = "THE INK SEA", test = function(p)
		return p.Y < G.SEA and p.Y > G.DEPTH_LINE + 100
	end, color = Color3.fromRGB(90, 170, 255) },
	{ name = "THE UNKNOWN", test = function(p)
		return p.Y < G.UNKNOWN_TOP + 300
	end, color = Color3.fromRGB(200, 120, 255) },
	{ name = "THE ABYSS", test = function(p)
		return p.Y < G.ABYSS_TOP + 250 and p.Y > G.ABYSS_BOTTOM - 300
	end, color = Color3.fromRGB(150, 150, 180) },
	{ name = "THE CINDER KING'S CALDERA", test = function(p)
		return (p - G.Bosses[5].pos).Magnitude < 110
	end, color = Color3.fromRGB(255, 90, 40) },
	{ name = "HELL", test = function(p)
		return p.Y < G.HELL_TOP + 250 and p.Y > G.HELL_BOTTOM - 300
	end, color = Color3.fromRGB(255, 120, 50) },
	{ name = "THE INK DEEPSEA", test = function(p)
		return p.Y <= G.DEPTH_LINE + 100 and p.Y > G.HELL_SHOW
	end, color = Color3.fromRGB(110, 140, 255) },
}

---------------------------------------------------------------------------
-- QUESTS (auto-progress, no NPC trips needed)
---------------------------------------------------------------------------
-- v1.2 TRAINING: skills are taught by Master Orren (Genesis Isles), one training at a time, in this order
G.N_CHESTS = 11 -- keep in sync with gen_world (prints "chests:")
-- v1.5 WANDERING MERCHANT: an airship that tours the isles and sells potions & curios for ink
G.MerchantDocks = {
	{ name = "THE GENESIS ISLES", pos = Vector3.new(-70, 62, 420) },
	{ name = "QUILL'S REST", pos = Vector3.new(30, 122, -30) },
	{ name = "THE WESTERN ISLE", pos = Vector3.new(-420, 122, 140) },
	{ name = "THE SOUTHERN ISLE", pos = Vector3.new(-400, 62, 630) },
	{ name = "THE FORGOTTEN TEMPLE", pos = Vector3.new(420, 152, 600) },
}
G.MERCHANT_DOCK_TIME = 150
G.MERCHANT_TRAVEL_TIME = 45
G.ShopItems = {
	{ id = "wind", name = "TAILWIND TONIC", price = 300, desc = "+30% flight speed for 5 minutes", buff = "BuffWind", dur = 300 },
	{ id = "hunt", name = "HUNTER'S BREW", price = 400, desc = "+25% damage for 5 minutes", buff = "BuffDmg", dur = 300 },
	{ id = "lantern", name = "ESSENCE LANTERN", price = 500, desc = "Double essence from absorbing for 5 minutes", buff = "BuffEss", dur = 300 },
	{ id = "map", name = "TREASURE MAP", price = 250, desc = "Shows the way to the nearest chest you haven't opened" },
	{ id = "feathers", name = "BUNDLE OF FEATHERS", price = 600, desc = "+4 feathers" },
	{ id = "crystal", name = "ESSENCE CRYSTAL", price = 700, desc = "+6 essence of a random kind" },
	{ id = "basket", name = "APPLE BASKET", price = 120, desc = "Heals you completely" },
}
-- v1.5 SKY SHOWERS: warm rain sweeps the isles every few minutes. Flowers glow, GOLDEN monsters appear, then a rainbow.
G.SHOWER_EVERY = { 360, 600 }
G.SHOWER_LEN = 150
G.GOLDEN_KINDS = { "InkBlob", "ScribbleBat", "PaperWasp" }
G.GOLDEN_SPOTS = { Vector3.new(-120, 50, 260), Vector3.new(130, 50, 360), Vector3.new(-420, 70, 140), Vector3.new(430, 30, 180), Vector3.new(-400, 10, 630), Vector3.new(0, 80, 860), Vector3.new(20, 110, -40) }
-- v1.6 FEATHER PLUMES: socket into your wings; each one changes how you fight (not % boosts)
G.Plumes = {
	split = { name = "SPLIT PLUME", color = Color3.fromRGB(120, 200, 255), desc = "Every shot forks: 2 more monsters near your target take half damage.", w = 10 },
	storm = { name = "STORM PLUME", color = Color3.fromRGB(255, 240, 120), desc = "Every 5th hit calls lightning that chains to 3 monsters.", w = 8 },
	ember = { name = "EMBER PLUME", color = Color3.fromRGB(255, 120, 50), desc = "Hits set monsters ablaze: they burn for 3 seconds.", w = 9 },
	blood = { name = "BLOOD PLUME", color = Color3.fromRGB(220, 40, 70), desc = "You heal 5% of all damage you deal.", w = 7 },
	ink = { name = "INK PLUME", color = Color3.fromRGB(60, 60, 140), desc = "Kills leave an ink pool that roots monsters inside it.", w = 8 },
	gale = { name = "GALE PLUME", color = Color3.fromRGB(220, 255, 240), desc = "Boosting blasts nearby monsters away and hurts them.", w = 8 },
	moth = { name = "MOTH PLUME", color = Color3.fromRGB(200, 180, 255), desc = "Monsters lose sight of you while you fly without shooting (3 s).", w = 5 },
	echo = { name = "ECHO PLUME", color = Color3.fromRGB(255, 160, 230), desc = "Critical hits fire a free second shot.", w = 6 },
}
G.PLUME_ORDER = { "split", "storm", "ember", "blood", "ink", "gale", "moth", "echo" }
function G.PlumeSlots(rank)
	return (rank or 1) >= 4 and 3 or 2
end
-- v1.6 ELITE AFFIXES: rare tougher monsters with a twist
G.ELITE_CHANCE = 0.07
G.Affixes = {
	mirrored = { name = "MIRRORED", color = Color3.fromRGB(180, 220, 255), desc = "splits in two when it dies" },
	gale = { name = "GALE", color = Color3.fromRGB(200, 255, 230), desc = "blasts you away" },
	anchored = { name = "ANCHORED", color = Color3.fromRGB(150, 110, 255), desc = "drags you in" },
	vampiric = { name = "VAMPIRIC", color = Color3.fromRGB(220, 30, 60), desc = "regenerates" },
	shielded = { name = "SHIELDED", color = Color3.fromRGB(255, 220, 120), desc = "takes little damage until its shield breaks" },
	swift = { name = "SWIFT", color = Color3.fromRGB(120, 255, 140), desc = "very fast" },
	volatile = { name = "VOLATILE", color = Color3.fromRGB(255, 120, 40), desc = "explodes when it dies" },
}
G.AFFIX_ORDER = { "mirrored", "gale", "anchored", "vampiric", "shielded", "swift", "volatile" }
-- v1.6 WIND CURRENTS (fly inside = fast travel) and UPDRAFTS (free climb)
G.CURRENT_SPEED = 150
G.CURRENT_R = 18
G.Currents = {
	{ name = "GENESIS RING", pts = { Vector3.new(-420, 135, 140), Vector3.new(-220, 75, 30), Vector3.new(0, 120, -60), Vector3.new(230, 95, 20), Vector3.new(430, 75, 180), Vector3.new(420, 165, 600), Vector3.new(0, 145, 860), Vector3.new(-400, 60, 630), Vector3.new(-420, 135, 140) } },
	{ name = "SKY LIFT", pts = { Vector3.new(60, 130, -40), Vector3.new(80, 700, -100), Vector3.new(40, 1500, -80), Vector3.new(0, 2120, -60) } },
	{ name = "SEA DIVE", pts = { Vector3.new(300, 40, -220), Vector3.new(320, -300, -260), Vector3.new(300, -680, -200) } },
	{ name = "SEA RISE", pts = { Vector3.new(-300, -680, -300), Vector3.new(-320, -300, -240), Vector3.new(-300, 60, -120) } },
}
G.Updrafts = {
	{ pos = Vector3.new(-212, -40, 331), r = 14, h = 110 }, -- the Genesis waterfall
	{ pos = Vector3.new(420, 80, 600), r = 16, h = 120 }, -- the temple
	{ pos = Vector3.new(0, 30, 860), r = 14, h = 100 },
	{ pos = Vector3.new(-30, 60, 0), r = 12, h = 90 }, -- Quill's Rest edge
}
-- v1.6 SKY SHRINES: light all 4 braziers within the time limit
G.SHRINE_TIME = 25
G.Shrines = {
	{ id = "s1", name = "SHRINE OF EMBERS", center = Vector3.new(-420, 100, 140), plume = "ember" },
	{ id = "s2", name = "SHRINE OF ECHOES", center = Vector3.new(0, 110, 860), plume = "echo" },
	{ id = "s3", name = "SHRINE OF GALES", center = Vector3.new(430, 60, 180), plume = "gale" },
}
-- v1.6 WORLD EVENTS
G.LEVIATHAN_EVERY = { 1500, 2100 }
G.LEVIATHAN_TIME = 200
G.STAR_EVERY = { 900, 1200 }
G.MENTOR_POS = Vector3.new(14, 43, 350)
G.Training = {
	{ skill = "meditate", kind = "still", n = 20, text = "STAND COMPLETELY STILL FOR 20 SECONDS", say = "Strength starts with stillness. Stand still - do not move at all - for twenty breaths." },
	{ skill = "absorb", kind = "kill", n = 8, text = "DEFEAT 8 MONSTERS", say = "Now hunt. Defeat eight monsters, and feel what is left behind when they fall." },
	{ skill = "sense", kind = "meditate", n = 30, text = "MEDITATE FOR 30 SECONDS AND FEEL THE MANA AROUND YOU", say = "Every being carries mana. Sit, breathe, and feel it - thirty breaths. Then you will know what you face before you fight it." },
	{ skill = "unleash", kind = "meditate", n = 90, text = "MEDITATE FOR 90 SECONDS", say = "You hold power, but cannot release it. Meditate for ninety seconds until it overflows." },
	{ skill = "abysseye", kind = "depth", n = 1, text = "DIVE 1500 STUDS DEEP INTO THE INK SEA", say = "Last lesson. Dive deep into the Ink Sea, deeper than 1500. Learn to see in the dark." },
}
G.Quests = {
	{ text = "DEFEAT 5 INK BLOBS ON GENESIS ISLE", kind = "kill", target = "InkBlob", n = 5, ink = 80, feathers = 3, where = Vector3.new(0, 44, 300) },
	{ text = "TALK TO MASTER ORREN AND FINISH HIS FIRST TRAINING", kind = "train", n = 1, ink = 120, feathers = 3, where = Vector3.new(14, 44, 350) },
	{ text = "FLY UP: DEFEAT 4 SCRIBBLE BATS", kind = "kill", target = "ScribbleBat", n = 4, ink = 150, feathers = 4, where = Vector3.new(-110, 158, -60) },
	{ text = "TRAIN WITH MASTER ORREN: LEARN ABSORB", kind = "train", n = 2, ink = 150, feathers = 3, where = Vector3.new(14, 44, 350) },
	{ text = "MEDITATE UNTIL YOUR WINGS EVOLVE TO RANK C", kind = "rank", n = 2, ink = 250, feathers = 4 },
	{ text = "UPGRADE YOUR WINGS TO TIER 3", kind = "tier", n = 3, ink = 200, feathers = 0 },
	{ text = "DEFEAT 3 PAPER WASPS", kind = "kill", target = "PaperWasp", n = 3, ink = 300, feathers = 6, where = Vector3.new(120, 182, -150) },
	{ text = "DIVE INTO THE INK SEA: DEFEAT 3 INK SHADES", kind = "kill", target = "InkShade", n = 3, ink = 400, feathers = 6, where = Vector3.new(-60, -1100, -40) },
	{ text = "DEFEAT THE BLOT KING", kind = "kill", target = "BlotKing", n = 1, ink = 1500, feathers = 10, where = G.BOSS_POS },
	{ text = "SINK TO THE INK DEEPSEA: DEFEAT 4 INK EELS", kind = "kill", target = "InkEel", n = 4, ink = 1200, feathers = 8, where = Vector3.new(0, -3000, -60) },
	{ text = "HUNT THE INKVERN IN THE INK DEEPSEA", kind = "kill", target = "Inkvern", n = 1, ink = 2500, feathers = 12, where = G.Bosses[2].pos },
	{ text = "RISE THROUGH THE STORM: DEFEAT 5 PAPER WASPS UP THERE", kind = "kill", target = "PaperWasp", n = 5, ink = 2000, feathers = 10, where = Vector3.new(130, 2380, -220) },
	{ text = "REACH THE COSMOS: DEFEAT 5 STAR WISPS", kind = "kill", target = "StarWisp", n = 5, ink = 3000, feathers = 12, where = Vector3.new(-90, 4560, -120) },
	{ text = "DEFEAT 5 COMET HOUNDS", kind = "kill", target = "CometHound", n = 5, ink = 3500, feathers = 14, where = Vector3.new(130, 4700, -40) },
	{ text = "DEFEAT THE COMET EATER", kind = "kill", target = "CometEater", n = 1, ink = 6000, feathers = 20, where = G.Bosses[3].pos },
	{ text = "ENTER HEAVEN: DEFEAT 5 HALO SENTINELS", kind = "kill", target = "HaloSentinel", n = 5, ink = 6000, feathers = 18, where = Vector3.new(-190, 6800, -10) },
	{ text = "DEFEAT 5 GILDED MOTHS", kind = "kill", target = "GildedMoth", n = 5, ink = 7000, feathers = 20, where = Vector3.new(190, 6820, -20) },
	{ text = "DEFEAT THE HALO WARDEN", kind = "kill", target = "HaloWarden", n = 1, ink = 15000, feathers = 40, where = G.Bosses[4].pos },
	{ text = "DESCEND INTO HELL: DEFEAT 6 CINDER IMPS", kind = "kill", target = "CinderImp", n = 6, ink = 16000, feathers = 30, where = Vector3.new(-140, -4500, -80) },
	{ text = "DEFEAT 4 ASH WRAITHS", kind = "kill", target = "AshWraith", n = 4, ink = 18000, feathers = 30, where = Vector3.new(0, -4420, -60) },
	{ text = "DEFEAT THE CINDER KING", kind = "kill", target = "CinderKing", n = 1, ink = 30000, feathers = 60, where = G.Bosses[5].pos },
	{ text = "FALL INTO THE ABYSS: DEFEAT THE FORGOTTEN", kind = "kill", target = "Forgotten", n = 1, ink = 32000, feathers = 40, where = Vector3.new(700, -6250, -500) },
	{ text = "FACE THE UNKNOWN: DEFEAT 3 HOLLOWS (THEY RISE WHEN THE UNKNOWN WAKES)", kind = "kill", target = "Hollow", n = 3, ink = 40000, feathers = 50, where = Vector3.new(0, -7800, -60) },
	{ text = "DEFEAT THE UNKNOWN", kind = "kill", target = "TheUnknown", n = 1, ink = 100000, feathers = 120, where = G.Bosses[6].pos },
}

G.Rarity = {
	Common = Color3.fromRGB(200, 200, 210),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 70, 160),
}

-- ======================= v0.9 REALMS (separate places in one experience) =======================
-- Overworld = Sky Isles, Storm, Ink Sea, Deepsea | Celestial = Cosmos + Heaven | Underworld = Hell, Abyss, Unknown
-- Same coordinates in every place (so all zone logic still works); each place only contains its own zones.
do
	local ok, rs = pcall(function()
		return game:GetService("ReplicatedStorage")
	end)
	local rv = ok and rs and rs:FindFirstChild("Realm")
	G.REALM = rv and rv.Value or "Overworld"
end
-- PUT YOUR PLACE IDS HERE (Creator Dashboard > your experience > Places). 0 = not published yet.
G.PLACES = { Overworld = 0, Celestial = 0, Underworld = 0 }
G.REALM_NAMES = { Overworld = "THE OVERWORLD", Celestial = "THE CELESTIAL REALM", Underworld = "THE UNDERWORLD" }
G.GATE_UP = 3300 -- Overworld: fly above this -> Celestial
G.GATE_DOWN = -3700 -- Overworld: dive below this -> Underworld
G.CEL_FLOOR = 3500 -- Celestial: fall below this -> back to the Overworld
G.UND_ROOF = -3850 -- Underworld: climb above this -> back to the Overworld
function G.RealmOfY(y)
	if y >= G.GATE_UP then
		return "Celestial"
	elseif y <= G.GATE_DOWN then
		return "Underworld"
	end
	return "Overworld"
end
-- crossing a gate: returns destination realm + arrival key (or nil)
function G.GateCheck(y)
	if G.REALM == "Overworld" then
		if y > G.GATE_UP then
			return "Celestial", "CEL_GATE"
		elseif y < G.GATE_DOWN then
			return "Underworld", "UND_GATE"
		end
	elseif G.REALM == "Celestial" and y < G.CEL_FLOOR then
		return "Overworld", "OW_TOP"
	elseif G.REALM == "Underworld" and y > G.UND_ROOF then
		return "Overworld", "OW_BOTTOM"
	end
	return nil
end
G.ARRIVE = {
	CEL_GATE = Vector3.new(0, 3960, 0), -- the Celestial gate isle
	UND_GATE = Vector3.new(0, -4040, 0), -- the Underworld gate isle
	OW_TOP = Vector3.new(0, 3050, 0), -- just below the sky tear
	OW_BOTTOM = Vector3.new(0, -3450, 0), -- just above the deep rift
}
-- fast travel destinations (discovered by visiting)
G.ZONES = {
	{ name = "SKY ISLES", realm = "Overworld", point = Vector3.new(0, 104, 8) },
	{ name = "THE STORM", realm = "Overworld", point = Vector3.new(0, 2300, 0) },
	{ name = "THE INK SEA", realm = "Overworld", point = Vector3.new(0, -660, 0) },
	{ name = "THE INK DEEPSEA", realm = "Overworld", point = Vector3.new(0, -2900, 0) },
	{ name = "THE COSMOS", realm = "Celestial", point = Vector3.new(0, 4400, 0) },
	{ name = "HEAVEN", realm = "Celestial", point = Vector3.new(0, 6745, 230) },
	{ name = "HELL", realm = "Underworld", point = Vector3.new(-140, -4492, -80) },
	{ name = "THE ABYSS", realm = "Underworld", point = Vector3.new(0, -5900, 0) },
	{ name = "THE UNKNOWN", realm = "Underworld", point = Vector3.new(0, -7450, 0) },
}
G.ZONE_BY_NAME = {}
for _, z in ipairs(G.ZONES) do
	G.ZONE_BY_NAME[z.name] = z
end
function G.ZoneOf(y)
	if y > G.HEAVEN_BASE - 150 then
		return "HEAVEN"
	elseif y > G.COSMOS_BASE - 200 then
		return "THE COSMOS"
	elseif y > G.STORM_BASE then
		return "THE STORM"
	elseif y > -300 then
		return "SKY ISLES"
	elseif y > G.DEPTH_LINE then
		return "THE INK SEA"
	elseif y > G.HELL_TOP + 250 then
		return "THE INK DEEPSEA"
	elseif y > G.ABYSS_TOP + 250 then
		return "HELL"
	elseif y > G.UNKNOWN_TOP + 300 then
		return "THE ABYSS"
	end
	return "THE UNKNOWN"
end
-- v0.9: the eyes, beings and events now live in THE ABYSS; THE UNKNOWN is pure darkness
function G.InAbyss(y)
	return y < G.ABYSS_TOP + 300 and y > G.ABYSS_BOTTOM - 300
end

-- v1.0 the Cosmos widens: 10 far camps of Star Spawn / Void Gazers (they only hunt the strong)
for k = 0, 9 do
	local a = k / 10 * math.pi * 2 + 0.2
	local d = (k % 2 == 0) and 1600 or 2600
	table.insert(G.Spawns, { type = k % 2 == 0 and "StarWisp" or "CometHound", center = Vector3.new(math.cos(a) * d, 4500 + (k % 3) * 220, math.sin(a) * d), r = 260, max = 6, level = 40 + (k % 3) * 4, outer = true })
end
-- ======================= v1.0 ASCENSION: absorb, meditate, evolve, ranked skills =======================
G.RANKS = { "D", "C", "B", "A", "S" }
G.RANK_COLORS = { Color3.fromRGB(170, 170, 180), Color3.fromRGB(110, 220, 120), Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 200, 60) }
-- essence types (each zone's beings carry their own) + what that aspect gives an evolved wing
G.ESSENCES = {
	Ink = { color = Color3.fromRGB(80, 100, 230), aspect = "INKBOUND", bonus = "+10% max HP" },
	Storm = { color = Color3.fromRGB(150, 220, 255), aspect = "TEMPEST", bonus = "+10% flight speed" },
	Cosmic = { color = Color3.fromRGB(170, 110, 255), aspect = "ASTRAL", bonus = "+25% mana from meditation" },
	Holy = { color = Color3.fromRGB(255, 220, 120), aspect = "SERAPHIC", bonus = "Heal 3% of damage dealt" },
	Infernal = { color = Color3.fromRGB(255, 90, 30), aspect = "INFERNAL", bonus = "+10% damage" },
	Abyssal = { color = Color3.fromRGB(80, 230, 210), aspect = "ABYSSAL", bonus = "+10% crit chance" },
	Void = { color = Color3.fromRGB(120, 60, 200), aspect = "VOIDBORN", bonus = "+20% damage to giants and bosses" },
}
G.EssenceOf = {
	InkBlob = "Ink", BlobMother = "Ink", ScribbleBat = "Storm", PaperWasp = "Storm", InkShade = "Ink", BlotKing = "Ink", InkEel = "Ink", Inkvern = "Ink",
	StarWisp = "Cosmic", CometHound = "Cosmic", CometEater = "Cosmic", Hunched = "Cosmic", StarLeviathan = "Cosmic", Weaver = "Cosmic", EclipseEye = "Cosmic", MawBelow = "Infernal", Dreamer = "Abyssal",
	HaloSentinel = "Holy", GildedMoth = "Holy", HaloWarden = "Holy", Seraphim = "Holy", Throne = "Holy",
	CinderImp = "Infernal", AshWraith = "Infernal", CinderKing = "Infernal",
	AbyssLurker = "Abyssal", Forgotten = "Abyssal", Hollow = "Void", TheUnknown = "Void", Nameless = "Void",
}
function G.EssenceAmount(def)
	if def.giant then
		return 120
	elseif def.boss then
		return 60
	end
	return math.max(1, math.floor(1 + def.level / 12))
end
-- wing evolution: essence to fuse + mana to reach, per rank step (D->C, C->B, B->A, A->S)
G.EVO_ESSENCE = { 12, 120, 400, 1200 }
-- v1.8: wing abilities cost mana (scaled by cooldown)
function G.AbilityMana(ab)
	return ab.mana or math.max(1, math.floor((ab.cd or 6) * 0.3)) -- v1.8c: you start with a 1-mana pool
end
G.EVO_MANA = { 45, 250, 800, 2400 }
G.RANK_POWER = { 1, 1.15, 1.35, 1.6, 2 }
G.MANA_PER_SEC = 1
-- v1.8d MANA CORE: every core rank has a LIMIT on max mana. Limits are personal: breakthrough quality
-- (and some skills) raise them, so two D-rank cores can hold 1000 vs 1200. At the limit you need a
-- BREAKTHROUGH: meditate for 60 s without being knocked out of it (friends nearby speed it up).
G.CORE_CAP = { 60, 300, 1000, 3000, 12000 }
G.BREAK_TIME = 60
G.BREAK_BONUS = { Rough = 0, Clean = 0.03, Perfect = 0.07 }
function G.CoreCap(rank, bonus)
	return math.floor(G.CORE_CAP[math.clamp(rank, 1, 5)] * (1 + (bonus or 0)))
end
-- core purity 0 (black) .. 1 (white): rank steps + how full your core is within the rank
function G.CorePurity(rank, manaMax, cap)
	return math.clamp(((rank - 1) + math.clamp(manaMax / math.max(1, cap), 0, 1)) / 5, 0, 1)
end
-- SKILLS (v1.0b): four skills that change how you play. Learned with skill points; each one EVOLVES
-- through use into a stronger form (shown in the SKILLS panel with its progress).
G.Skills = {
	{ id = "absorb", name = "ABSORB", rank = 2, sp = 1, level = 2, key = "E", how = "Defeat your first monster.",
		desc = "Draw the remains of the fallen into you and keep their essence.",
		evo = { id = "gluttony", name = "GLUTTONY", rank = 4, need = 60, unit = "REMAINS ABSORBED",
			desc = "A devouring vortex: swallow EVERY remains around you at once. Each one heals you and feeds a FEAST (+6% damage per corpse for 30s, up to 10)." } },
	{ id = "meditate", name = "MEDITATE", rank = 2, sp = 1, level = 2, key = "R", how = "Absorb the remains of 3 fallen.",
		desc = "Gather strength and evolve your mana. Stored essence fuses into your wings.",
		evo = { id = "zen", name = "ZEN FLIGHT", rank = 4, need = 1200, unit = "SECONDS MEDITATED",
			desc = "Meditate while hovering in mid-air. Hits no longer break your focus. Mana flows twice as fast." } },
	{ id = "sense", name = "MANA SENSE", rank = 2, sp = 1, level = 3, key = "V", how = "Train with Master Orren.",
		desc = "Send out a pulse and read the mana of every monster around you: their true level. Beings far stronger than you can't be read at all. Costs 3 mana.",
		evo = { id = "truesight", name = "SOUL READING", rank = 4, need = 150, unit = "PULSES",
			desc = "You read mana constantly: every monster close to you is sensed automatically, the pulse reaches much farther, and you can read beings far stronger than you." } },
	{ id = "unleash", name = "UNLEASH", rank = 3, sp = 3, level = 15, key = "Q", how = "Defeat the Blot King in the Ink Sea.",
		desc = "Burn 10 essence to unleash its power. Each essence acts differently: Infernal nova, Holy healing, Storm chain lightning, Cosmic star rain, Abyssal drain, Void singularity, Ink blot.",
		evo = { id = "catastrophe", name = "CATASTROPHE", rank = 5, need = 120, unit = "UNLEASHES",
			desc = "Your unleashed powers become disasters: far bigger, far stronger, and cost only 6 essence." } },
	{ id = "abysseye", name = "EYES OF THE ABYSS", rank = 3, sp = 3, level = 30, how = "Descend into the Abyss and look into the dark.",
		desc = "See through the darkness of the depths and the void.",
		evo = { id = "allsee", name = "ALL-SEEING EYE", rank = 5, need = 900, unit = "SECONDS IN THE DARK",
			desc = "Sense every remains, giant and boss around you, through any darkness, and read the true strength of every being." } },
}
-- what each essence does when UNLEASHED (mult = x your hit damage)
G.UNLEASH = {
	Infernal = { name = "INFERNAL NOVA", radius = 34, mult = 5 },
	Holy = { name = "HOLY LIGHT", radius = 30, mult = 2.5, heal = 0.35 },
	Storm = { name = "CHAIN LIGHTNING", radius = 90, mult = 3.2, chain = 6 },
	Cosmic = { name = "STAR RAIN", radius = 40, mult = 1.6, strikes = 7 },
	Abyssal = { name = "ABYSSAL DRAIN", radius = 0, mult = 5.5, drain = 0.5 },
	Void = { name = "SINGULARITY", radius = 60, mult = 3.5, pull = true },
	Ink = { name = "BLOT PRISON", radius = 36, mult = 2.6, root = 4 },
}
-- v1.9 MANA ROTATION: no evolution, mastered through proficiency only
table.insert(G.Skills, 3, { id = "rotation", name = "MANA ROTATION", rank = 3, sp = 0, level = 0, how = "Reach proficiency C in Meditate.", profNeed = 1800, unit = "SECONDS OF ROTATION",
	desc = "Your mana circulates on its own: regeneration x3, even while moving, flying and fighting." })
G.SkillById = {}
for _, sk in ipairs(G.Skills) do
	G.SkillById[sk.id] = sk
	if sk.evo then
		G.SkillById[sk.evo.id] = { id = sk.evo.id, name = sk.evo.name, rank = sk.evo.rank, base = sk.id, sp = 0, level = 0 }
	end
end
G.Skills[4].desc = "Hold to open MANA VISION: the world dims and every living mana source glows. Read monster threat, health and soul rings. Drains mana every second; proficiency makes it cheaper, wider and clearer."

-- v1.9 SKILL PROFICIENCY: F..S from use. S = evolution. Efficiency 0..1 drives each skill's numbers.
G.PROF_RANKS = { "F", "E", "D", "C", "B", "A", "S" }
G.PROF_TH = { 0, 0.05, 0.12, 0.25, 0.45, 0.7, 1.0 }
G.PROF_COLORS = { Color3.fromRGB(150, 150, 150), Color3.fromRGB(200, 200, 200), Color3.fromRGB(170, 200, 140), Color3.fromRGB(110, 220, 120), Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 200, 60) }
function G.ProfNeed(sk)
	return (sk.evo and sk.evo.need) or sk.profNeed or 200
end
-- returns rank index (1..7), efficiency 0..1, progress to next rank 0..1
function G.Proficiency(id, sxp, evolved)
	local sk = G.SkillById[id]
	if not sk then
		return 1, 0, 0
	end
	if evolved then
		return 7, 1, 1
	end
	local f = math.clamp((sxp or 0) / G.ProfNeed(sk), 0, 1)
	local r = 1
	for i = 1, 7 do
		if f >= G.PROF_TH[i] then
			r = i
		end
	end
	if r == 7 and sk.evo then
		r = 6 -- S needs the evolution itself
	end
	local nx = G.PROF_TH[math.min(7, r + 1)]
	local prog = r >= 7 and 1 or math.clamp((f - G.PROF_TH[r]) / math.max(0.001, nx - G.PROF_TH[r]), 0, 1)
	return r, f, prog
end
-- what each skill's efficiency does (numbers shown on the skill board and used by the server)
function G.SenseStats(eff)
	return 2 - 1.5 * eff, math.floor(40 + 260 * eff) -- mana per second, range
end
function G.EffLines(id, eff)
	if id == "sense" or id == "truesight" then
		local cost, r = G.SenseStats(eff)
		return ("Drain %.1f mana/s   Range %d   %s"):format(cost, r, eff >= 0.45 and "Reads exact health" or "Exact health at rank B")
	elseif id == "meditate" or id == "zen" then
		return ("Mana flow +%d%%"):format(math.floor(eff * 100))
	elseif id == "absorb" or id == "gluttony" then
		return ("Essence gained +%d%%"):format(math.floor(eff * 50))
	elseif id == "rotation" then
		return ("Regeneration x%.1f"):format(3 + eff * 2)
	elseif id == "unleash" or id == "catastrophe" then
		return ("Unleash power +%d%%"):format(math.floor(eff * 40))
	end
	return ""
end
-- v1.9 THREAT GRADES (no levels on screen): a monster's level as a letter grade
G.GRADES = { "F", "E-", "E", "E+", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+", "S-", "S", "S+" }
function G.Grade(lv)
	return G.GRADES[math.clamp(math.floor((lv or 1) / 5) + 1, 1, #G.GRADES)]
end

return G
