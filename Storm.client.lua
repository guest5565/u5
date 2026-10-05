--!nonstrict
-- INKWING :: THE STORM (local, per player)
--   * sky by altitude: storm isles -> bright ceiling glow -> pitch-black storm wall -> violet Ink Deepsea
--   * rain in the world (fast streak drops around the camera) AND on the screen (streaks + lens drops)
--   * lightning: jagged bolts in the distance, the whole sky flashes, thunder arrives after the flash
--   * Ink Deepsea (from Doodle Pets' Void / Unknown): drifting black orbs with white rims,
--     floating white ink strokes and two giant eyes that watch you
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local me = Players.LocalPlayer
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local rng = Random.new()
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local root = Instance.new("Folder")
root.Name = "StormFX"
root.Parent = workspace
local function part(o, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.Color = o.color or Color3.new(1, 1, 1)
	p.Transparency = o.tr or 0
	if o.shape then
		p.Shape = o.shape
	end
	p.Size = o.size or V(1, 1, 1)
	p.CFrame = o.cf or CF(0, -5000, 0)
	if o.ellipsoid then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = parent or root
	return p
end

---------------------------------------------------------------------------
-- ATMOSPHERE PRESETS (blended by height)
---------------------------------------------------------------------------
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
local cc = Lighting:FindFirstChild("Color") or Instance.new("ColorCorrectionEffect", Lighting)
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local P = {
	-- the starting sky: warm, bright, soft haze (no rain)
	isles = { clock = 15.2, bright = 2.5, amb = rgb(150, 150, 172), out = rgb(185, 182, 205), atmC = rgb(205, 222, 255), atmD = rgb(176, 192, 245), dens = 0.42, haze = 2.2, tint = rgb(255, 252, 248), sat = 0.14, con = 0.05, rain = 0 },
	-- inside / above the cloud deck: grey, foggy
	deck = { clock = 15.8, bright = 1.6, amb = rgb(130, 132, 148), out = rgb(150, 152, 168), atmC = rgb(200, 204, 216), atmD = rgb(170, 174, 190), dens = 0.82, haze = 3, tint = rgb(235, 238, 250), sat = -0.05, con = 0.04, rain = 0 },
	-- THE STORM: thick dark fog, rain, lightning
	storm = { clock = 16.5, bright = 1.0, amb = rgb(78, 84, 110), out = rgb(92, 98, 128), atmC = rgb(70, 78, 104), atmD = rgb(34, 40, 62), dens = 0.86, haze = 3, tint = rgb(200, 210, 255), sat = -0.2, con = 0.18, rain = 1 },
	-- the long fall below the isles: sky darkens to deep blue
	fall = { clock = 15.2, bright = 0.8, amb = rgb(40, 50, 80), out = rgb(45, 55, 90), atmC = rgb(30, 40, 75), atmD = rgb(10, 14, 35), dens = 0.5, haze = 2.6, tint = rgb(190, 205, 255), sat = 0, con = 0.1, rain = 0 },
	-- under the ink sea: deep blue water, light from above fading with depth
	sea = { clock = 13, bright = 1.2, amb = rgb(50, 110, 170), out = rgb(60, 120, 180), atmC = rgb(20, 90, 170), atmD = rgb(4, 30, 80), dens = 0.86, haze = 3, tint = rgb(140, 200, 255), sat = 0.3, con = 0.1, rain = 0 },
	-- above the sea surface: bright open ocean sky
	coast = { clock = 14.5, bright = 2.2, amb = rgb(140, 160, 190), out = rgb(160, 185, 215), atmC = rgb(170, 210, 255), atmD = rgb(90, 150, 220), dens = 0.58, haze = 2.8, tint = rgb(240, 250, 255), sat = 0.2, con = 0.05, rain = 0 },
	-- above the storm: the air thins, night falls
	thin = { clock = 19.5, bright = 0.9, amb = rgb(60, 60, 100), out = rgb(70, 70, 115), atmC = rgb(60, 60, 120), atmD = rgb(20, 20, 60), dens = 0.3, haze = 1.5, tint = rgb(215, 215, 255), sat = 0, con = 0.08, rain = 0 },
	-- THE COSMOS: black space, stars, purple planets
	cosmos = { clock = 24, bright = 0.6, amb = rgb(90, 80, 140), out = rgb(100, 90, 150), atmC = rgb(60, 30, 110), atmD = rgb(20, 5, 50), dens = 0.6, haze = 2.2, tint = rgb(225, 215, 255), sat = 0.25, con = 0.12, rain = 0 },
	-- the light climb: dawn
	dawn = { clock = 30.4, bright = 1.6, amb = rgb(160, 130, 140), out = rgb(190, 150, 150), atmC = rgb(255, 190, 160), atmD = rgb(150, 110, 170), dens = 0.35, haze = 2, tint = rgb(255, 235, 225), sat = 0.15, con = 0.05, rain = 0 },
	-- HEAVEN: blinding gold and white
	heaven = { clock = 36, bright = 3, amb = rgb(210, 180, 180), out = rgb(240, 205, 195), atmC = rgb(255, 220, 215), atmD = rgb(255, 190, 170), dens = 0.5, haze = 2.4, tint = rgb(255, 238, 232), sat = 0.1, con = 0.04, rain = 0 },
	abyss = { clock = 0, bright = 0.4, amb = rgb(25, 35, 70), out = rgb(20, 30, 65), atmC = rgb(10, 20, 50), atmD = rgb(2, 6, 20), dens = 0.68, haze = 3, tint = rgb(150, 175, 240), sat = 0.05, con = 0.1, rain = 0 },
	-- HELL: red-orange glow from below, ash haze
	hell = { clock = 0, bright = 1.4, amb = rgb(150, 60, 40), out = rgb(170, 70, 40), atmC = rgb(120, 40, 20), atmD = rgb(40, 8, 4), dens = 0.62, haze = 2.6, tint = rgb(255, 205, 175), sat = 0.2, con = 0.12, rain = 0 },
	-- THE ABYSS: nearly black, silent
	void = { clock = 0, bright = 0.05, amb = rgb(14, 14, 22), out = rgb(10, 10, 18), atmC = rgb(4, 4, 8), atmD = rgb(0, 0, 0), dens = 0.72, haze = 3, tint = rgb(170, 170, 200), sat = -0.4, con = 0.2, rain = 0 },
	-- THE UNKNOWN: violet cosmic dark
	unknown = { clock = 0, bright = 0, amb = rgb(4, 4, 8), out = rgb(3, 3, 6), atmC = rgb(0, 0, 0), atmD = rgb(0, 0, 0), dens = 0.85, haze = 3, tint = rgb(130, 130, 150), sat = -0.6, con = 0.25, rain = 0 }, -- v0.9: pure darkness
	depths = { clock = 0, bright = 0.3, amb = rgb(58, 40, 96), out = rgb(44, 30, 84), atmC = rgb(44, 22, 78), atmD = rgb(10, 0, 26), dens = 0.5, haze = 2.4, tint = rgb(215, 195, 255), sat = 0.12, con = 0.12, rain = 0 },
}
local NUM = { "clock", "bright", "dens", "haze", "sat", "con", "rain" }
local COL = { "amb", "out", "atmC", "atmD", "tint" }
local function mix(a, b, t)
	local o = {}
	for _, k in ipairs(NUM) do
		o[k] = a[k] + (b[k] - a[k]) * t
	end
	for _, k in ipairs(COL) do
		o[k] = a[k]:Lerp(b[k], t)
	end
	return o
end
-- v1.8 DAY / NIGHT on the isles: a 20-minute cycle synced to server time (everyone shares the same sky).
-- The isles preset itself changes with the time of day; higher / deeper zones keep their own look.
local DAYP = P.isles
local TOD = {
	dawn = { clock = 6.3, bright = 1.7, amb = rgb(150, 120, 140), out = rgb(185, 150, 160), atmC = rgb(255, 196, 170), atmD = rgb(170, 130, 200), dens = 0.34, haze = 2.2, tint = rgb(255, 232, 220), sat = 0.2, con = 0.06, rain = 0 },
	day = DAYP,
	sunset = { clock = 17.75, bright = 2.0, amb = rgb(170, 120, 110), out = rgb(205, 140, 120), atmC = rgb(255, 165, 120), atmD = rgb(190, 90, 130), dens = 0.36, haze = 2.4, tint = rgb(255, 220, 190), sat = 0.3, con = 0.08, rain = 0 },
	dusk = { clock = 18.6, bright = 1.5, amb = rgb(125, 100, 150), out = rgb(140, 110, 170), atmC = rgb(160, 105, 170), atmD = rgb(80, 60, 130), dens = 0.34, haze = 1.6, tint = rgb(230, 212, 245), sat = 0.12, con = 0.06, rain = 0 },
	night = { clock = 0.3, bright = 1.7, amb = rgb(105, 118, 170), out = rgb(118, 132, 190), atmC = rgb(78, 92, 150), atmD = rgb(40, 50, 100), dens = 0.3, haze = 0.8, tint = rgb(200, 212, 255), sat = 0.0, con = 0.04, rain = 0 }, -- v1.8e: moonlit, readable
}
local KEYS = { { 0, "dawn" }, { 0.05, "day" }, { 0.55, "day" }, { 0.62, "sunset" }, { 0.67, "dusk" }, { 0.72, "night" }, { 0.95, "night" }, { 1.0, "dawn" } }
G.DAY_LEN = G.DAY_LEN or 1200
local todClock = 15.2
local function updateTOD()
	local ph = (workspace:GetServerTimeNow() % G.DAY_LEN) / G.DAY_LEN
	local fp = workspace:GetAttribute("ForcePhase")
	if fp and fp >= 0 then
		ph = fp
	end
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if ph >= a[1] and ph <= b[1] then
			local u = (ph - a[1]) / math.max(1e-4, b[1] - a[1])
			u = u * u * (3 - 2 * u)
			local A_, B_ = TOD[a[2]], TOD[b[2]]
			P.isles = mix(A_, B_, u)
			local ca, cb = A_.clock, B_.clock
			local diff = ((cb - ca + 12) % 24) - 12
			todClock = (ca + diff * u) % 24
			P.isles.clock = 15.2
			break
		end
	end
	_G.InkwingDayPhase = ph
	_G.InkwingIsNight = ph > 0.68 and ph < 0.97
end
local function islesWeight(y)
	if y > 500 or y < -500 then
		return 0
	elseif y > 200 then
		return 1 - (y - 200) / 300
	elseif y < -60 then
		return math.max(0, 1 - (-60 - y) / 440)
	end
	return 1
end
local function presetAt(y)
	if y > G.HEAVEN_BASE then
		return P.heaven
	elseif y > G.COSMOS_TOP then
		local u = math.clamp((y - G.COSMOS_TOP) / (G.HEAVEN_BASE - G.COSMOS_TOP), 0, 1)
		return u < 0.5 and mix(P.cosmos, P.dawn, u * 2) or mix(P.dawn, P.heaven, u * 2 - 1)
	elseif y > G.COSMOS_BASE then
		return P.cosmos
	elseif y > G.STORM_TOP then
		local u = math.clamp((y - G.STORM_TOP) / (G.COSMOS_BASE - G.STORM_TOP), 0, 1)
		return u < 0.4 and mix(P.storm, P.thin, u / 0.4) or mix(P.thin, P.cosmos, (u - 0.4) / 0.6)
	elseif y > G.STORM_BASE then
		return P.storm
	elseif y > G.STORM_SHOW then
		return mix(P.deck, P.storm, math.clamp((y - G.STORM_SHOW) / (G.STORM_BASE - G.STORM_SHOW), 0, 1))
	elseif y > 200 then
		return mix(P.isles, P.deck, math.clamp((y - 200) / 300, 0, 1))
	elseif y > -60 then
		return P.isles
	elseif y > G.SEA then
		-- falling toward the sea: the sky turns to dusk
		-- falling toward the sea: the sky opens up into a bright ocean sky
		return mix(P.isles, P.coast, math.clamp((-60 - y) / (-60 - G.SEA - 200), 0, 1))
	elseif y > G.DEPTH_LINE then
		local u = math.clamp((G.SEA - y) / 320, 0, 1) ^ 0.7 -- v1.10: the light dies fast under water
		return mix(P.sea, P.abyss, u)
	elseif y > G.HELL_SHOW then
		return mix(P.abyss, P.depths, math.clamp((G.DEPTH_LINE - y) / 150, 0, 1))
	elseif y > G.HELL_TOP then
		return mix(P.depths, P.hell, math.clamp((G.HELL_SHOW - y) / (G.HELL_SHOW - G.HELL_TOP), 0, 1))
	elseif y > G.HELL_BOTTOM - 300 then
		return P.hell
	elseif y > G.ABYSS_TOP then
		return mix(P.hell, P.void, math.clamp((G.HELL_BOTTOM - 300 - y) / (G.HELL_BOTTOM - 300 - G.ABYSS_TOP), 0, 1))
	elseif y > G.ABYSS_BOTTOM then
		return P.void
	elseif y > G.UNKNOWN_TOP then
		return mix(P.void, P.unknown, math.clamp((G.ABYSS_BOTTOM - y) / (G.ABYSS_BOTTOM - G.UNKNOWN_TOP), 0, 1))
	else
		return P.unknown
	end
end
local cur = presetAt(100)
local flash = 0 -- lightning flash 0..1

---------------------------------------------------------------------------
-- WORLD RAIN: thin streaks recycled around the camera
---------------------------------------------------------------------------
local DROPS = isMobile and 90 or 170
local drops, dParts, dCFs = {}, {}, {}
for i = 1, DROPS do
	local p = part({ size = V(0.07, 3.6, 0.07), color = rgb(205, 215, 240), tr = 0.45, mat = Enum.Material.Glass })
	dParts[i] = p
	drops[i] = { pos = V(0, -5000, 0) }
	dCFs[i] = p.CFrame
end
local WIND = V(-14, -120, 6)
local windDir = CF(V(), WIND.Unit)

---------------------------------------------------------------------------
-- SCREEN RAIN: streaks across the screen + drops on the lens
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ScreenRain"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -1
gui.Parent = me:WaitForChild("PlayerGui")
local STREAKS = isMobile and 28 or 46
local streaks = {}
for i = 1, STREAKS do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.55
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
	g.Parent = f
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	f.Parent = gui
	streaks[i] = { f = f, x = rng:NextNumber(), y = rng:NextNumber(-0.2, 1.2), sp = rng:NextNumber(0.9, 1.6), len = rng:NextNumber(40, 110), w = rng:NextInteger(2, 4) }
end
local LENS = isMobile and 6 or 10
local lens = {}
for i = 1, LENS do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = rgb(220, 230, 255)
	f.BackgroundTransparency = 1
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Thickness = 2
	s.Transparency = 1
	s.Parent = f
	f.Parent = gui
	lens[i] = { f = f, s = s, life = 0, t = rng:NextNumber(0, 3) }
end
-- flash overlay
local flashF = Instance.new("Frame")
flashF.Size = UDim2.fromScale(1, 1)
flashF.BackgroundColor3 = rgb(230, 235, 255)
flashF.BackgroundTransparency = 1
flashF.BorderSizePixel = 0
flashF.Parent = gui

---------------------------------------------------------------------------
-- SOUND
---------------------------------------------------------------------------
local function sound(id, vol, looped)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = vol
	s.Looped = looped or false
	s.Parent = workspace.CurrentCamera or workspace
	return s
end
local rainS = sound(9112853287, 0, true) -- Rain Heavy 1 (Pro Sound Effects)
local windS = sound(9114057128, 0, true) -- Desert Wind Whistley Light Gusts 2
rainS:Play()
windS:Play()
local CRACKS = { 9116282646, 9116282791, 9116282544, 9116282647 }
local RUMBLE = 9120018695
local function thunder(dist)
	if dist < 260 then
		local s = sound(CRACKS[rng:NextInteger(1, #CRACKS)], math.clamp(1.4 - dist / 260, 0.35, 1.2))
		s.PlaybackSpeed = rng:NextNumber(0.85, 1.05)
		s:Play()
		game:GetService("Debris"):AddItem(s, 12)
	end
	local r = sound(RUMBLE, math.clamp(0.9 - dist / 900, 0.15, 0.7))
	r.TimePosition = rng:NextNumber(0, 60)
	r.PlaybackSpeed = rng:NextNumber(0.8, 1)
	r:Play()
	task.delay(5, function()
		for k = 1, 10 do
			r.Volume *= 0.7
			task.wait(0.1)
		end
		r:Destroy()
	end)
end

---------------------------------------------------------------------------
-- LIGHTNING
---------------------------------------------------------------------------
local function bolt(top, bottom, color, width)
	local pts = { top }
	local n = 12
	for i = 1, n - 1 do
		local u = i / n
		pts[i + 1] = top:Lerp(bottom, u) + V(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 14
	end
	pts[n + 1] = bottom
	local made = {}
	local function seg(a, b, w)
		local p = part({ size = V(w, w, (b - a).Magnitude + w), color = color, mat = Enum.Material.Neon, cf = CF((a + b) / 2, b) })
		made[#made + 1] = p
		return p
	end
	for i = 1, n do
		seg(pts[i], pts[i + 1], width)
	end
	for _ = 1, 3 do -- branches
		local i = rng:NextInteger(2, n - 2)
		local a = pts[i]
		for _ = 1, 3 do
			local b = a + V(rng:NextNumber(-1, 1) * 18, -rng:NextNumber(10, 22), rng:NextNumber(-1, 1) * 18)
			seg(a, b, width * 0.5)
			a = b
		end
	end
	local l = Instance.new("PointLight")
	l.Range = 60
	l.Brightness = 10
	l.Color = color
	l.Parent = made[math.floor(#made / 2)]
	-- flicker: on, off, on, fade
	task.spawn(function()
		task.wait(0.07)
		for _, p in ipairs(made) do
			p.Transparency = 0.9
		end
		task.wait(0.06)
		for _, p in ipairs(made) do
			p.Transparency = 0
		end
		for k = 1, 8 do
			task.wait(0.04)
			for _, p in ipairs(made) do
				p.Transparency = k / 8
			end
		end
		for _, p in ipairs(made) do
			p:Destroy()
		end
	end)
end
local function strike()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local c = cam.CFrame.Position
	local y = c.Y
	local deep = G.InAbyss(y) -- v0.9: the violet lightning lives in the Abyss now
	local a = rng:NextNumber(0, math.pi * 2)
	-- mostly in front of the camera so you actually see it
	local look = cam.CFrame.LookVector
	if rng:NextNumber() < 0.7 then
		a = math.atan2(look.Z, look.X) + rng:NextNumber(-0.9, 0.9)
	end
	local d = rng:NextNumber(110, 480)
	local x, z = c.X + math.cos(a) * d, c.Z + math.sin(a) * d
	local top, bottom
	if deep then
		top, bottom = V(x, y + 160, z), V(x, y - 160, z)
	else
		top, bottom = V(x, G.STORM_TOP + 15, z), V(x, math.max(G.STORM_GATE + 40, y - 260), z)
	end
	bolt(top, bottom, deep and rgb(190, 120, 255) or rgb(225, 232, 255), deep and 1.4 or 1.8)
	flash = math.max(flash, math.clamp(1.2 - d / 500, 0.35, 1))
	task.delay(d / 600, thunder, d)
end
task.spawn(function()
	while true do
		local y = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position.Y or 100
		local wait
		local inStorm = y > G.STORM_BASE - 80 and y < G.STORM_TOP + 150
		local inDepths = G.InAbyss(y)
		if inStorm then
			wait = rng:NextNumber(1.5, 4.5)
		elseif inDepths then
			wait = rng:NextNumber(7, 15)
		else
			wait = 1 -- calm sky: no lightning, check again soon
		end
		task.wait(wait)
		if not (inStorm or inDepths) then
			continue
		end
		strike()
		if rng:NextNumber() < 0.25 then -- double strike
			task.wait(rng:NextNumber(0.15, 0.4))
			strike()
		end
	end
end)
-- the tornado script can ask for a strike near a funnel
local strikeEv = Instance.new("BindableEvent")
strikeEv.Name = "StormStrike"
strikeEv.Parent = script
strikeEv.Event:Connect(function(top, bottom)
	bolt(top, bottom, rgb(225, 232, 255), 1.6)
	local c = workspace.CurrentCamera.CFrame.Position
	local d = (top:Lerp(bottom, 0.5) - c).Magnitude
	flash = math.max(flash, math.clamp(1.1 - d / 500, 0.2, 0.9))
	task.delay(d / 600, thunder, d)
end)

---------------------------------------------------------------------------
-- THE INK DEEPSEA: void orbs, white ink strokes, watching eyes
---------------------------------------------------------------------------
local deepF = Instance.new("Folder")
deepF.Name = "Depths"
local DC = V(0, -6200, -60) -- v0.9: the Abyss
local orbs, strokes, eyes = {}, {}, {}
for i = 1, 22 do
	local d = rng:NextNumber(6, 22)
	local o = part({ size = V(d, d, d), color = rgb(6, 4, 12), shape = Enum.PartType.Ball }, deepF)
	local rim = part({ size = V(d * 1.08, d * 1.08, d * 1.08), color = Color3.new(1, 1, 1), mat = Enum.Material.Neon, tr = 0.82, shape = Enum.PartType.Ball }, deepF)
	orbs[i] = { o = o, rim = rim, a = rng:NextNumber(0, 6.28), r = rng:NextNumber(80, 260), h = rng:NextNumber(-260, 260), sp = rng:NextNumber(0.02, 0.06) }
end
for i = 1, 36 do
	local p = part({ size = V(rng:NextNumber(0.4, 0.9), rng:NextNumber(0.4, 0.9), rng:NextNumber(10, 30)), color = Color3.new(1, 1, 1), mat = Enum.Material.Neon, tr = 0.15 }, deepF)
	strokes[i] = { p = p, pos = DC + V(rng:NextNumber(-260, 260), rng:NextNumber(-280, 260), rng:NextNumber(-260, 220)), rot = V(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), sp = rng:NextNumber(0.1, 0.4) }
end
local function bigEye(pos, d, iris)
	local e = { pos = pos, d = d, nextBlink = os.clock() + rng:NextNumber(1, 5), blink = -1 }
	e.ball = part({ size = V(d, d, d), color = rgb(245, 243, 250), ellipsoid = true }, deepF)
	e.iris = part({ size = V(d * 0.55, d * 0.55, d * 0.12), color = iris, mat = Enum.Material.Neon, ellipsoid = true }, deepF)
	e.pupil = part({ size = V(d * 0.26, d * 0.34, d * 0.12), color = rgb(8, 4, 16), ellipsoid = true }, deepF)
	e.shine = part({ size = V(d * 0.12, d * 0.12, d * 0.12), color = Color3.new(1, 1, 1), mat = Enum.Material.Neon, shape = Enum.PartType.Ball }, deepF)
	e.top = part({ size = V(d * 1.06, d * 0.56, d * 1.06), color = rgb(20, 12, 36), ellipsoid = true }, deepF)
	e.bot = part({ size = V(d * 1.06, d * 0.56, d * 1.06), color = rgb(20, 12, 36), ellipsoid = true }, deepF)
	-- THE UNKNOWN (Inkbound): each eye sits inside a boiling sumi-ink cloud with dripping wisps + violet motes
	local cloud = part({ size = V(d * 1.8, d * 1.5, d * 1.2), tr = 1, cf = CF(pos) }, deepF)
	local function em(o)
		local x = Instance.new("ParticleEmitter")
		x.Texture = "rbxasset://textures/particles/smoke_main.dds"
		x.Color = ColorSequence.new(o.c1, o.c2 or o.c1)
		x.Size = o.size
		x.Transparency = o.tr
		x.Lifetime = NumberRange.new(o.life, o.life * 1.4)
		x.Rate = o.rate * (isMobile and 0.5 or 1)
		x.Speed = NumberRange.new(o.speed, o.speed * 1.6)
		x.SpreadAngle = Vector2.new(180, 180)
		x.Rotation = NumberRange.new(0, 360)
		x.RotSpeed = NumberRange.new(-o.spin, o.spin)
		x.Acceleration = o.accel or Vector3.zero
		x.LightEmission = o.glow or 0
		x.Parent = cloud
	end
	em({ c1 = rgb(20, 14, 34), c2 = rgb(45, 30, 70), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d * 0.35), NumberSequenceKeypoint.new(0.5, d * 0.7), NumberSequenceKeypoint.new(1, d * 0.5) }),
		tr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }), life = 3, rate = 12, speed = 2, spin = 20, accel = V(0, 1, 0) })
	em({ c1 = rgb(10, 6, 20), size = NumberSequence.new(d * 0.12, d * 0.04), tr = NumberSequence.new(0.2, 1), life = 2.5, rate = 8, speed = 5, spin = 60, accel = V(0, -8, 0) })
	em({ c1 = rgb(150, 90, 255), size = NumberSequence.new(1.2, 0), tr = NumberSequence.new(0.2, 1), life = 2, rate = 6, speed = 4, spin = 0, glow = 1 })
	eyes[#eyes + 1] = e
end
bigEye(V(-260, -6230, -220), 70, rgb(170, 90, 255))
bigEye(V(280, -6300, 40), 56, rgb(90, 230, 210))
bigEye(V(30, -6050, 260), 44, rgb(255, 110, 160))
bigEye(V(-60, -6500, -420), 90, rgb(255, 60, 90))
local function updateEye(e, target, t)
	if t > e.nextBlink then
		e.blink = t
		e.nextBlink = t + rng:NextNumber(2.5, 7)
	end
	local o = 1
	if t - e.blink < 0.25 then
		o = math.abs(1 - (t - e.blink) / 0.125)
	end
	local pos = e.pos + V(0, math.sin(t * 0.4 + e.d) * 4, 0)
	local look = CFrame.lookAt(pos, target)
	local d = e.d
	local f = d * 0.47
	e.ball.CFrame = look
	e.iris.CFrame = look * CF(0, 0, -f)
	e.pupil.CFrame = look * CF(0, 0, -f - d * 0.03)
	e.shine.CFrame = look * CF(-d * 0.1, d * 0.12, -f - d * 0.06)
	local a = 0.08 + o * 1.05
	e.top.CFrame = look * A(a, 0, 0) * CF(0, d * 0.24, 0)
	e.bot.CFrame = look * A(-a * 0.8, 0, 0) * CF(0, -d * 0.22, 0)
end
-- slow rising ink motes
local motes = part({ size = V(160, 1, 160), tr = 1 }, deepF)
do
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = isMobile and 25 or 50
	pe.Lifetime = NumberRange.new(6, 10)
	pe.Speed = NumberRange.new(2, 5)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Color = ColorSequence.new(rgb(200, 150, 255), rgb(120, 200, 255))
	pe.LightEmission = 1
	pe.Parent = motes
end

---------------------------------------------------------------------------
-- LOOP
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local t = os.clock()
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local camPos = cam.CFrame.Position
	local y = hrp and hrp.Position.Y or camPos.Y
	-- atmosphere
	if G.REALM == "Overworld" then
		updateTOD()
	end
	local goal = presetAt(y)
	local k = math.clamp(dt * 1.5, 0, 1)
	for _, key in ipairs(NUM) do
		cur[key] += (goal[key] - cur[key]) * k
	end
	for _, key in ipairs(COL) do
		cur[key] = cur[key]:Lerp(goal[key], k)
	end
	flash = math.max(0, flash - dt * 3.2)
	local fl = flash
	do
		local w = G.REALM == "Overworld" and islesWeight(y) or 0
		local c = cur.clock % 24
		local diff = ((todClock - c + 12) % 24) - 12
		Lighting.ClockTime = (c + diff * w) % 24
	end
	Lighting.Brightness = cur.bright + fl * 3
	Lighting.Ambient = cur.amb:Lerp(rgb(220, 225, 255), fl * 0.6)
	Lighting.OutdoorAmbient = cur.out:Lerp(rgb(230, 235, 255), fl * 0.6)
	atm.Density = cur.dens
	atm.Color = cur.atmC:Lerp(rgb(200, 205, 240), fl * 0.7)
	atm.Decay = cur.atmD
	atm.Haze = cur.haze
	atm.Glare = 0
	cc.TintColor = cur.tint
	cc.Saturation = cur.sat
	cc.Contrast = cur.con
	cc.Brightness = fl * 0.12
	-- v0.9c THE UNKNOWN = true void: fog closes to arm's length, exposure crushed, no sky, nothing
	do
		local yy = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position.Y or 0
		local vk = math.clamp((G.ABYSS_BOTTOM - 300 - yy) / (G.ABYSS_BOTTOM - 300 - G.UNKNOWN_TOP), 0, 1)
		if string.find(game:GetService("Players").LocalPlayer:GetAttribute("Skills") or "", "abysseye", 1, true) then
			vk *= 0.45 -- v1.0 EYES OF THE ABYSS
		end
		atm.Offset = vk
		atm.Density = cur.dens + (1 - cur.dens) * vk
		atm.Color = atm.Color:Lerp(rgb(0, 0, 0), vk)
		atm.Decay = atm.Decay:Lerp(rgb(0, 0, 0), vk)
		atm.Haze = cur.haze + 7 * vk
		-- v1.8b CLOUD VEILS: a thick fog band you fly through between the isles and the sea / storm.
		-- ZoneStream swaps the storm / sea in inside these veils, so the pop-in is hidden.
		if G.REALM == "Overworld" then
			local function bump(a, b, c, d)
				if yy <= a or yy >= d then return 0 end
				if yy < b then return (yy - a) / (b - a) end
				if yy > c then return (d - yy) / (d - c) end
				return 1
			end
			local veil = math.max(bump(-420, -300, -220, -120), bump(1650, 1790, 1910, 2060))
			if veil > 0 then
				atm.Density = math.max(atm.Density, cur.dens + (0.72 - cur.dens) * veil)
				atm.Haze = atm.Haze + 4 * veil
				atm.Color = atm.Color:Lerp(rgb(225, 230, 240), veil * 0.7)
			end
		end
		-- v0.9c under the lava sea (-4900): molten murk, you see nothing but glowing red
		local lk = (yy < -4902 and yy > G.HELL_BOTTOM - 320) and math.clamp((-4902 - yy) / 25, 0, 1) or 0
		if lk > 0 then
			atm.Offset = math.max(atm.Offset, lk)
			atm.Density = math.max(atm.Density, 0.6 + 0.4 * lk)
			atm.Color = atm.Color:Lerp(rgb(150, 30, 5), lk)
			atm.Decay = atm.Decay:Lerp(rgb(60, 5, 0), lk)
			atm.Haze = 10
			cc.TintColor = cc.TintColor:Lerp(rgb(255, 120, 80), lk)
		end
		Lighting.ExposureCompensation = -2.5 * vk
		cc.Brightness -= 0.25 * vk
		cc.Saturation = cur.sat - 0.6 * vk
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			sky.StarCount = vk > 0.5 and 0 or 3000
			sky.CelestialBodiesShown = vk < 0.5
		end
	end
	if bloom then
		bloom.Intensity = 0.35 + fl * 0.8
	end
	flashF.BackgroundTransparency = 1 - fl * 0.22

	local vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
	local speed = vel.Magnitude
	local rain = cur.rain

	-- world rain
	local fall = WIND - vel * 0.35 -- moving through rain tilts the streaks toward you
	local fallDir = fall.Magnitude > 1 and fall.Unit or V(0, -1, 0)
	windDir = CF(V(), fallDir) * A(math.pi / 2, 0, 0)
	local active = rain > 0.05
	local n = active and math.floor(DROPS * math.min(1, rain)) or 0
	for i = 1, DROPS do
		local d = drops[i]
		if i <= n then
			local p = d.pos + WIND * dt
			local rel = p - camPos
			if rel.Y < -45 or math.abs(rel.X) > 70 or math.abs(rel.Z) > 70 then
				p = camPos + V(rng:NextNumber(-60, 60), rng:NextNumber(10, 50), rng:NextNumber(-60, 60)) + vel * 0.5
			end
			d.pos = p
			dCFs[i] = CF(p) * windDir
		else
			dCFs[i] = CF(0, -5000, 0)
		end
	end
	workspace:BulkMoveTo(dParts, dCFs, Enum.BulkMoveMode.FireCFrameChanged)

	-- screen rain: streaks get longer + more slanted when you fly fast / boost
	local vs = cam.ViewportSize
	local camVel = cam.CFrame:VectorToObjectSpace(vel)
	local slant = math.clamp(-camVel.X / 80, -0.6, 0.6) + 0.18
	local stretch = 1 + math.clamp(speed / 60, 0, 2.2)
	local scrRain = math.clamp(rain, 0, 1)
	for i, s in ipairs(streaks) do
		local on = i <= math.floor(STREAKS * scrRain)
		s.f.Visible = on
		if on then
			s.y += dt * s.sp * (1.1 + speed / 70)
			s.x += dt * s.sp * slant * 0.6
			if s.y > 1.2 then
				s.y = rng:NextNumber(-0.3, -0.05)
				s.x = rng:NextNumber(-0.1, 1.1)
			end
			s.f.Position = UDim2.fromScale(s.x, s.y)
			s.f.Size = UDim2.fromOffset(s.w, s.len * stretch * (vs.Y / 800))
			s.f.Rotation = -math.deg(slant) * 0.9
		end
	end
	-- lens drops: appear, sit, then slide down and fade
	for _, l in ipairs(lens) do
		l.t -= dt
		if l.life <= 0 and l.t <= 0 and scrRain > 0.3 then
			l.life = rng:NextNumber(1.5, 3)
			l.max = l.life
			local sz = rng:NextInteger(10, 26)
			l.f.Size = UDim2.fromOffset(sz, sz * 1.15)
			l.f.Position = UDim2.fromScale(rng:NextNumber(0.05, 0.95), rng:NextNumber(0.05, 0.8))
			l.t = rng:NextNumber(0.3, 1.5)
		end
		if l.life > 0 then
			l.life -= dt
			local u = l.life / l.max
			l.f.BackgroundTransparency = 1 - 0.18 * u
			l.s.Transparency = 1 - 0.55 * u
			if u < 0.6 then
				l.f.Position += UDim2.fromScale(0, dt * 0.06)
			end
		else
			l.f.BackgroundTransparency, l.s.Transparency = 1, 1
		end
	end
	-- sound
	rainS.Volume += ((rain * 0.45) - rainS.Volume) * k
	local windGoal = math.clamp(speed / 120, 0, 0.6) + ((me:GetAttribute("WindPull") or 0) * 0.8)
	windS.Volume += (windGoal - windS.Volume) * k
	windS.PlaybackSpeed = 0.9 + math.clamp(speed / 200, 0, 0.5)

	-- depths
	local deep = G.InAbyss(y) -- v0.9: the big eyes watch you in the Abyss
	if (deepF.Parent ~= nil) ~= deep then
		deepF.Parent = deep and root or nil
	end
	if deep then
		local target = hrp and hrp.Position or camPos
		motes.CFrame = CF(camPos - V(0, 40, 0))
		for _, o in ipairs(orbs) do
			o.a += o.sp * dt
			local p = DC + V(math.cos(o.a) * o.r, o.h + math.sin(t * 0.3 + o.r) * 6, math.sin(o.a) * o.r)
			o.o.CFrame = CF(p)
			o.rim.CFrame = CF(p)
		end
		for _, s in ipairs(strokes) do
			s.p.CFrame = CF(s.pos + V(0, math.sin(t * s.sp + s.rot.X) * 6, 0)) * A(s.rot.X + t * s.sp * 0.3, s.rot.Y + t * s.sp * 0.2, 0)
		end
		for _, e in ipairs(eyes) do
			updateEye(e, target, t)
		end
	end
end)
