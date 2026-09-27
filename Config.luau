-- Heavensunder / shared tuning. No paid assets, plugins, or animation IDs required.
local Config = {}
Config.Version = "0.4.0 — The World Below"
Config.Realms = {
	{Name = "Mortal Seed", Need = 80, Health = 120, Damage = 14, Color = Color3.fromRGB(149, 215, 192)},
	{Name = "Qi Awakening", Need = 180, Health = 155, Damage = 19, Color = Color3.fromRGB(127, 238, 212)},
	{Name = "Jade Foundation", Need = 360, Health = 200, Damage = 26, Color = Color3.fromRGB(71, 227, 179)},
	{Name = "Golden Core", Need = 640, Health = 255, Damage = 35, Color = Color3.fromRGB(255, 207, 109)},
	{Name = "Nascent Soul", Need = 1000, Health = 320, Damage = 46, Color = Color3.fromRGB(161, 193, 255)},
	{Name = "Void Walker", Need = 1500, Health = 395, Damage = 59, Color = Color3.fromRGB(194, 158, 255)},
	{Name = "Heaven Severing", Need = 2200, Health = 480, Damage = 75, Color = Color3.fromRGB(255, 167, 211)},
	{Name = "Celestial Lotus", Need = 3200, Health = 575, Damage = 94, Color = Color3.fromRGB(255, 224, 151)},
	{Name = "Ninefold Immortal", Need = 5000, Health = 700, Damage = 120, Color = Color3.fromRGB(240, 250, 255)},
}
Config.Abilities = {
	Strike = {Cooldown = 0.46, Cost = 0, Range = 14, Multiplier = 1, Unlock = 1},
	Palm = {Cooldown = 4.5, Cost = 22, Range = 44, Multiplier = 2.3, Unlock = 1},
	Dash = {Cooldown = 2.8, Cost = 14, Range = 0, Multiplier = 0, Unlock = 1},
	Lotus = {Cooldown = 12, Cost = 48, Range = 29, Multiplier = 3.5, Unlock = 3},
}
Config.Enemies = {
	SilkSpider = {Name = "Jade Silkweaver", Health = 115, Damage = 11, Speed = 12, Aggro = 35,
		Reach = 9, Leash = 52, Cooldown = 2.8, Windup = 1.05, Reward = 24, Spirit = 8,
		Respawn = 30, Color = Color3.fromRGB(132, 220, 177)},
	SilkMatriarch = {Name = "The Silk Matriarch", Health = 900, Damage = 23, Speed = 10, Aggro = 45,
		Reach = 13, Leash = 62, Cooldown = 3.1, Windup = 1.25, Reward = 180, Spirit = 70,
		Respawn = 70, Color = Color3.fromRGB(227, 159, 214), Boss = true},
	JadeWarden = {Name = "Jade Warden", Health = 150, Damage = 13, Speed = 10, Aggro = 48,
		Reach = 9, Leash = 72, Cooldown = 2.3, Windup = 0.85, Reward = 32, Spirit = 10,
		Respawn = 24, Color = Color3.fromRGB(108, 247, 197)},
	StormDisciple = {Name = "Exiled Storm Disciple", Health = 240, Damage = 20, Speed = 13, Aggro = 55,
		Reach = 11, Leash = 65, Cooldown = 2.0, Windup = 0.72, Reward = 55, Spirit = 18,
		Respawn = 30, Color = Color3.fromRGB(159, 193, 255)},
	LotusSovereign = {Name = "The Hollow Lotus", Health = 2100, Damage = 30, Speed = 10, Aggro = 70,
		Reach = 14, Leash = 65, Cooldown = 2.8, Windup = 1.0, Reward = 420, Spirit = 150,
		Respawn = 65, Color = Color3.fromRGB(255, 149, 199), Boss = true},
}
Config.Quests = {
	{Title = "A still heart", Text = "Gather 3 spirit lotuses, then speak to Elder Yun.", Gather = 3, Kills = 0, Reward = 60, Spirit = 25},
	{Title = "The jade trial", Text = "Defeat 4 enemies, then return to Elder Yun.", Gather = 0, Kills = 4, Reward = 140, Spirit = 50},
	{Title = "Beyond the veil", Text = "Defeat 8 enemies, including the Hollow Lotus.", Gather = 0, Kills = 8, Boss = true, Reward = 400, Spirit = 160},
}
Config.Dialogue = {
	Elder = {"The heavens broke. We did not.", "Sit beneath the great tree. Let your breath find the current.", "Press F to cultivate; press B when your Qi is ready."},
	Alchemist = {"A little starlight. A little bad judgment. Perfect medicine.", "Bring me 3 petals and 20 spirit for a restorative draught."},
	Ferryman = {"No boat survives this sea. Fortunately, I have no boat.", "The jade arches carry you between islands. Approach and interact."},
}
Config.ZoneNames = {Sanctuary = "DAWNREACH SANCTUARY", Verdant = "VERDANT FANG", Frost = "FROSTVEIL MONASTERY", Boss = "THE HOLLOW CROWN", Garden = "STARFALL GARDEN"}
Config.ZoneNames.Lanternwake = "LANTERNWAKE VILLAGE"
Config.ZoneNames.Silkwood = "THE SILKWOOD"
Config.ZoneNames.Cloudroot = "CLOUDROOT PEAK"
Config.ZoneNames.Lowlands = "THE WORLD BELOW"
Config.Guard = {Cooldown = 1.4, Cost = 10, Duration = 0.65, PerfectWindow = 0.23}
Config.Shrines = {
    {Name = "Root Meridian", Zone = "Verdant", Lore = "Roots remember the earth even when the earth has fallen away."},
    {Name = "Stillwater Meridian", Zone = "Frost", Lore = "The first master did not defeat the storm. She waited until it listened."},
    {Name = "Starlight Meridian", Zone = "Garden", Lore = "Every lost star is a promise the sky has not yet kept."},
    {Name = "Hollow Meridian", Zone = "Boss", Lore = "A crown without a heart is only a circle. You may choose to break it."},
}
Config.MaxFocus = 100
Config.QiPerSecond = 5
Config.SaveInterval = 90
Config.AllowStudioPersistence = false -- opt-in only after publishing and enabling API access
return Config
