--!nonstrict
-- INKWING :: REALMS (v0.9)
--   * REALM MAP: a sketchbook page with the 3 realms. Every zone you have visited = one-tap fast travel
--     (same realm: instant blink, other realm: teleport to that place).
--   * GATES: a shimmering veil at each realm border (the Sky Tear above the storm, the Deep Rift below
--     the Deepsea). Fly through it and you are carried to the next realm.
--   * LOADING SCREEN: an ink-and-paper travel screen (also shown on arrival via SetTeleportGui).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local me = Players.LocalPlayer
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Fx = Remotes:WaitForChild("Fx")
local Travel = Remotes:WaitForChild("Travel")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local PAPER = Color3.fromRGB(250, 246, 232)
local REALM_COL = {
	Overworld = Color3.fromRGB(90, 180, 255),
	Celestial = Color3.fromRGB(255, 196, 70),
	Underworld = Color3.fromRGB(235, 70, 70),
}
local rgb = Color3.fromRGB

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", { CornerRadius = r or UDim.new(0, 14) }, o)
end
local function stroke(o, t, c)
	new("UIStroke", { Thickness = t or 3, Color = c or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local gui = new("ScreenGui", { Name = "RealmUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6 }, me:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- LOADING SCREEN (also handed to TeleportService so it stays up during the teleport)
---------------------------------------------------------------------------
local function makeLoading(title, sub, col)
	local lg = new("ScreenGui", { Name = "InkwingTravel", IgnoreGuiInset = true, DisplayOrder = 100, ResetOnSpawn = false }, nil)
	local bg = new("Frame", { Name = "BG", Size = UDim2.fromScale(1, 1), BackgroundColor3 = PAPER, BorderSizePixel = 0 }, lg)
	new("UIGradient", { Color = ColorSequence.new(PAPER, col:Lerp(PAPER, 0.55)), Rotation = 90 }, bg)
	-- ink blots in the corners
	for k = 1, 6 do
		local s = 120 + k * 40
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(s, s), BackgroundColor3 = INK, BackgroundTransparency = 0.88, Position = UDim2.fromScale(({ 0.05, 0.95, 0.1, 0.9, 0.5, 0.02 })[k], ({ 0.08, 0.1, 0.92, 0.9, 1.02, 0.5 })[k]) }, bg)
		corner(b, UDim.new(1, 0))
	end
	local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1 }, bg)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 50, 0.5, math.sin(a) * 50), Size = UDim2.fromOffset(14 - k * 0.6, 14 - k * 0.6), BackgroundColor3 = k % 3 == 0 and col or INK, BorderSizePixel = 0 }, ring)
		corner(d, UDim.new(1, 0))
	end
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.new(0.8, 0, 0, 64), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = title, TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, bg)
	new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.new(0.6, 0, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = sub, TextColor3 = INK }, bg)
	return lg
end
local loading
local spinConn
local function showLoading(title, sub, col)
	if loading then
		loading:Destroy()
	end
	loading = makeLoading(title, sub, col)
	local bg = loading.BG
	bg.BackgroundTransparency = 1
	loading.Parent = me.PlayerGui
	TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	if spinConn then
		spinConn:Disconnect()
	end
	spinConn = RunService.RenderStepped:Connect(function(dt)
		if loading and loading.Parent then
			loading.BG.Ring.Rotation += dt * 120
		end
	end)
	pcall(function()
		TeleportService:SetTeleportGui(makeLoading(title, sub, col))
	end)
end
local function hideLoading()
	if loading then
		local l = loading
		loading = nil
		TweenService:Create(l.BG, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(l:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif d:IsA("Frame") and d.Name ~= "BG" and d.Name ~= "Ring" then
				TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.5, function()
			l:Destroy()
		end)
	end
end

-- quick white blink for same-realm travel
local blink = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50 }, gui)

Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "TravelStart" then
		local up = info.realm == "Celestial" or (info.realm == "Overworld" and G.REALM == "Underworld")
		showLoading(info.title or "TRAVELLING", up and "ASCENDING..." or "DESCENDING...", REALM_COL[info.realm] or PAPER)
	elseif kind == "TravelFailed" then
		hideLoading()
	elseif kind == "Blink" then
		blink.BackgroundTransparency = 1
		TweenService:Create(blink, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		task.delay(0.5, function()
			TweenService:Create(blink, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		end)
	end
end)

---------------------------------------------------------------------------
-- REALM MAP
---------------------------------------------------------------------------
local mapB = new("TextButton", { Name = "MapButton", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, isMobile and -8 or -6), Size = UDim2.fromOffset(isMobile and 84 or 74, isMobile and 52 or 74), BackgroundColor3 = rgb(120, 200, 140), Font = FONT, TextScaled = true, Text = isMobile and "MAP" or "MAP (M)", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)
corner(mapB, UDim.new(1, 0))
stroke(mapB, 3)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, mapB)

local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(940, 520), BackgroundColor3 = PAPER, Visible = false, ZIndex = 10 }, gui)
corner(panel, UDim.new(0, 22))
stroke(panel, 4)
local uiScale = new("UIScale", {}, panel)
local function fit()
	local vs = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.min(1, (vs.X - 30) / 940, (vs.Y - 30) / 520)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
new("TextLabel", { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "REALM MAP", TextColor3 = INK, ZIndex = 11 }, panel)
new("TextLabel", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "VISIT A PLACE ONCE TO UNLOCK FAST TRAVEL", TextColor3 = rgb(120, 110, 130), ZIndex = 11 }, panel)
local closeB = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = rgb(255, 100, 100), Font = FONT, TextScaled = true, Text = "X", TextColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, panel)
corner(closeB, UDim.new(1, 0))
stroke(closeB, 3)

local rows = {} -- zone name -> { btn, lbl }
local order = { "Overworld", "Celestial", "Underworld" }
for i, realm in ipairs(order) do
	local col = REALM_COL[realm]
	local card = new("Frame", { Position = UDim2.fromOffset(20 + (i - 1) * 303, 92), Size = UDim2.fromOffset(290, 410), BackgroundColor3 = col:Lerp(PAPER, 0.8), ZIndex = 11 }, panel)
	corner(card, UDim.new(0, 18))
	stroke(card, 3)
	new("TextLabel", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = G.REALM_NAMES[realm], TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK, ZIndex = 12 }, card)
	local hereL = new("TextLabel", { Name = "Here", Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 18), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = realm == G.REALM and "- YOU ARE IN THIS REALM -" or "", TextColor3 = INK, ZIndex = 12 }, card)
	local _ = hereL
	local n = 0
	for _, z in ipairs(G.ZONES) do
		if z.realm == realm then
			local y0 = 72 + n * 82
			n += 1
			local row = new("Frame", { Position = UDim2.fromOffset(12, y0), Size = UDim2.new(1, -24, 0, 72), BackgroundColor3 = PAPER, ZIndex = 12 }, card)
			corner(row, UDim.new(0, 12))
			stroke(row, 2)
			local _, need = G.ZoneNeed(z.point.Y)
			local nm = new("TextLabel", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = z.name, TextColor3 = INK, ZIndex = 13 }, row)
			local _2 = nm
			new("TextLabel", { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(0.5, -10, 0, 18), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "SAFE WITH: " .. string.upper(G.WING_ORDER[need] or "Paper") .. " WINGS", TextColor3 = rgb(130, 120, 140), ZIndex = 13 }, row)
			local b = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -8), Size = UDim2.fromOffset(120, 34), BackgroundColor3 = col, Font = FONT, TextScaled = true, Text = "TRAVEL", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK, ZIndex = 13 }, row)
			corner(b, UDim.new(1, 0))
			stroke(b, 2)
			new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, b)
			b.Activated:Connect(function()
				local found = string.find("," .. (me:GetAttribute("Found") or "") .. ",", "," .. z.name .. ",", 1, true)
				if found then
					Travel:FireServer(z.name)
					panel.Visible = false
				end
			end)
			rows[z.name] = { btn = b, row = row, col = col }
		end
	end
end
local function refresh()
	local f = "," .. (me:GetAttribute("Found") or "") .. ","
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local cur = hrp and G.ZoneOf(hrp.Position.Y)
	for name, r in pairs(rows) do
		local found = string.find(f, "," .. name .. ",", 1, true) ~= nil
		if name == cur and G.ZONE_BY_NAME[name].realm == G.REALM then
			r.btn.Text = "YOU ARE HERE"
			r.btn.BackgroundColor3 = rgb(170, 170, 180)
			r.btn.AutoButtonColor = false
		elseif found then
			r.btn.Text = "TRAVEL"
			r.btn.BackgroundColor3 = r.col
			r.btn.AutoButtonColor = true
		else
			r.btn.Text = "???"
			r.btn.BackgroundColor3 = rgb(120, 115, 130)
			r.btn.AutoButtonColor = false
		end
		r.row.BackgroundColor3 = found and PAPER or rgb(225, 220, 210)
	end
end
local function toggleMap()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
		uiScale.Scale *= 0.9
		fit()
	end
end
mapB.Activated:Connect(toggleMap)
mapB.Visible = false -- v1.9: the menu orb opens the map
_G.InkwingToggleMap = toggleMap
closeB.Activated:Connect(function()
	panel.Visible = false
end)
UserInputService.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.M then
		toggleMap()
	end
end)
me:GetAttributeChangedSignal("Found"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)

---------------------------------------------------------------------------
-- GATES: a shimmering veil across the whole sky at each realm border + a landmark tear
---------------------------------------------------------------------------
local gates = {}
local function gate(y, col, title, up)
	local fold = Instance.new("Folder")
	fold.Name = "Gate_" .. title
	local veil = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 1400, 1400), Material = Enum.Material.Neon, Color = col, Transparency = 0.86 }, fold)
	local veil2 = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 700, 700), Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1), Transparency = 0.8 }, fold)
	local sparkle = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(col, Color3.new(1, 1, 1)), Rate = isMobile and 60 or 140, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(4, 14), SpreadAngle = Vector2.new(25, 25), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 3), NumberSequenceKeypoint.new(1, 0) }), EmissionDirection = up and Enum.NormalId.Top or Enum.NormalId.Bottom }, nil)
	local box = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(600, 1, 600) }, fold)
	sparkle.Shape = Enum.ParticleEmitterShape.Box
	sparkle.Parent = box
	-- the landmark: a spinning ring of light at the centre of the world
	local ring = {}
	for k = 0, 31 do
		ring[k + 1] = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = Vector3.new(6, 6, 26), Material = Enum.Material.Neon, Color = k % 2 == 0 and col or Color3.new(1, 1, 1) }, fold)
	end
	local beam = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(900, 60, 60), Material = Enum.Material.Neon, Color = col, Transparency = 0.7, CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2) }, fold)
	local _ = beam
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(520, 80), AlwaysOnTop = false, LightInfluence = 0, MaxDistance = 1200 }, box)
	new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = title, TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, bb)
	table.insert(gates, { y = y, fold = fold, veil = veil, veil2 = veil2, box = box, ring = ring, title = title, col = col, up = up })
end
-- v1.10 THE DEEP RIFT: a burning hell sigil carved across the dark - molten jagged lines, a pentagram,
-- and a black pit in the centre that breathes embers up at you. No text.
local function hellSigil(g)
	local y = g.y
	local rnd = Random.new(666)
	local sig = {}
	local HOT, DEEP = rgb(255, 130, 40), rgb(200, 40, 10)
	local function seg(a, b, w)
		local mid = (a + b) / 2
		local L = (b - a).Magnitude
		local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = HOT:Lerp(DEEP, rnd:NextNumber() * 0.5), Size = Vector3.new(w, 2, L + w * 0.6), CFrame = CFrame.lookAt(mid, b) }, g.fold)
		table.insert(sig, p)
	end
	local function line(a, b, w, n)
		n = n or math.max(3, math.floor((b - a).Magnitude / 40))
		local dir = (b - a)
		local perp = Vector3.new(-dir.Z, 0, dir.X).Unit
		local prev = a
		for i = 1, n do
			local q = a + dir * (i / n)
			if i < n then
				q += perp * rnd:NextNumber(-1, 1) * 9
			end
			seg(prev, q, w * rnd:NextNumber(0.6, 1.3))
			-- little cracks branching off
			if rnd:NextNumber() < 0.35 then
				local ang = rnd:NextNumber() * math.pi * 2
				seg(q, q + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rnd:NextNumber(18, 45), w * 0.4)
			end
			prev = q
		end
	end
	local function circle(rad, w, n)
		local pts = {}
		for i = 0, n do
			local a = i / n * math.pi * 2
			local rr = rad + rnd:NextNumber(-1, 1) * rad * 0.04
			pts[i] = Vector3.new(math.cos(a) * rr, y, math.sin(a) * rr)
		end
		for i = 1, n do
			line(pts[i - 1], pts[i], w, 1)
		end
	end
	circle(330, 10, 48)
	circle(300, 5, 44)
	circle(150, 9, 26)
	local star = {}
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 - math.pi / 2
		star[i] = Vector3.new(math.cos(a) * 315, y, math.sin(a) * 315)
	end
	for i = 0, 4 do
		line(star[i], star[(i + 2) % 5], 9)
	end
	-- the pit
	local pit = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic, Color = Color3.new(0, 0, 0), Size = Vector3.new(3, 270, 270), CFrame = CFrame.new(0, y - 1, 0) * CFrame.Angles(0, 0, math.pi / 2) }, g.fold)
	local rim = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = rgb(255, 90, 20), Transparency = 0.35, Size = Vector3.new(2, 290, 290), CFrame = CFrame.new(0, y - 2, 0) * CFrame.Angles(0, 0, math.pi / 2) }, g.fold)
	local emit = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(240, 1, 240), CFrame = CFrame.new(0, y, 0) }, g.fold)
	new("ParticleEmitter", { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(rgb(255, 200, 90), rgb(200, 30, 0)), LightEmission = 1, Rate = isMobile and 25 or 60, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(30, 70), SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 0) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), EmissionDirection = Enum.NormalId.Top }, emit)
	new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(rgb(255, 170, 60)), LightEmission = 1, Rate = isMobile and 40 or 100, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(20, 60), SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 0) }), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 8, 0) }, emit)
	new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(rgb(20, 4, 2)), LightEmission = 0, Rate = isMobile and 6 or 14, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(10, 25),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 40), NumberSequenceKeypoint.new(1, 90) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }), EmissionDirection = Enum.NormalId.Top }, emit)
	new("PointLight", { Color = rgb(255, 80, 20), Range = 60, Brightness = 6 }, emit)
	new("Sound", { SoundId = "rbxassetid://9120018695", Looped = true, Playing = true, Volume = 1.2, RollOffMaxDistance = 1400, RollOffMinDistance = 120, PlaybackSpeed = 0.6 }, emit)
	g.sig, g.rim, g.hell = sig, rim, true
	g.veil.Transparency, g.veil2.Transparency = 1, 1
	for _, p in ipairs(g.ring) do
		p:Destroy()
	end
	g.ring = {}
	local bb = g.box:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb:Destroy()
	end
	for _, c in ipairs(g.fold:GetChildren()) do
		if c:IsA("BasePart") and c.Shape == Enum.PartType.Cylinder and c.Size.X == 900 then
			c.Color, c.Transparency = rgb(60, 0, 0), 0.85 -- the column beneath glows a dim blood red
		end
	end
end
if G.REALM == "Overworld" then
	gate(G.GATE_UP, rgb(255, 214, 120), "THE SKY TEAR  -  TO THE CELESTIAL REALM", true)
	gate(G.GATE_DOWN, rgb(230, 50, 50), "THE DEEP RIFT  -  TO THE UNDERWORLD", false)
	hellSigil(gates[#gates])
elseif G.REALM == "Celestial" then
	gate(G.CEL_FLOOR, rgb(120, 200, 255), "BACK DOWN TO THE OVERWORLD", false)
elseif G.REALM == "Underworld" then
	gate(G.UND_ROOF, rgb(120, 200, 255), "BACK UP TO THE OVERWORLD", true)
end

local warnL = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(isMobile and 460 or 700, isMobile and 44 or 56), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local t = os.clock()
	local near
	for _, g in ipairs(gates) do
		local dy = math.abs(cp.Y - g.y)
		local show = dy < 1500
		if (g.fold.Parent ~= nil) ~= show then
			g.fold.Parent = show and workspace or nil
		end
		if show then
			local c = CFrame.new(cp.X, g.y, cp.Z) * CFrame.Angles(0, 0, math.pi / 2)
			g.veil.CFrame = c
			g.veil.Transparency = g.hell and 1 or (0.84 + math.sin(t * 2) * 0.04)
			if g.hell then -- the sigil breathes
				local k = 0.5 + 0.5 * math.sin(t * 1.3)
				g.rim.Transparency = 0.2 + 0.4 * k
				if not g.pulseT or t - g.pulseT > 0.1 then
					g.pulseT = t
					for i, p in ipairs(g.sig) do
						p.Transparency = 0.05 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 + i * 0.15))
					end
				end
			end
			g.veil2.CFrame = c * CFrame.new(math.sin(t) * 3, 0, 0)
			g.box.CFrame = CFrame.new(cp.X, g.y, cp.Z)
			for k, p in ipairs(g.ring) do
				local a = (k - 1) / #g.ring * math.pi * 2 + t * 0.15
				p.CFrame = CFrame.new(math.cos(a) * 140, g.y + math.sin(t + k) * 4, math.sin(a) * 140) * CFrame.Angles(0, -a, 0)
			end
			if dy < 220 and not g.hell then
				near = g
			end
		end
	end
	if near then
		warnL.Text = near.title
		warnL.TextColor3 = near.col
		warnL.TextTransparency = 0.15 + math.sin(t * 5) * 0.15
	else
		warnL.Text = ""
	end
end)
