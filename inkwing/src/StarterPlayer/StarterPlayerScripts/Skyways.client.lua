--!nonstrict
-- INKWING v1.6 :: SKYWAYS (local)
--   wind currents + updrafts, camera shake, wing trails, per-zone weather, feather plume UI,
--   elite / behaviour visuals, sky shrine flames, perch glow, Leviathan + falling star events.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("Game"))
local FX = require(Shared:WaitForChild("InkFX"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Fx = Remotes:WaitForChild("Fx")
local Combat = Remotes:WaitForChild("Combat")
local me = Players.LocalPlayer
local cam = workspace.CurrentCamera
local V, CF = Vector3.new, CFrame.new
local rgb = Color3.fromRGB
local rng = Random.new()
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local OVER = G.REALM == "Overworld"

local root = Instance.new("Folder")
root.Name = "SkywaysFX"
root.Parent = workspace

local function bare(size, color, mat, tr, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material, p.Transparency = size, color, mat or Enum.Material.SmoothPlastic, tr or 0
	if shape then
		p.Shape = shape
	end
	p.Parent = root
	return p
end
local function seq(a, b)
	return NumberSequence.new(a, b)
end

---------------------------------------------------------------------------
-- CAMERA SHAKE: _G.InkwingShake(strength 0..1, duration)
---------------------------------------------------------------------------
local trauma, traumaDecay = 0, 1.5
_G.InkwingShake = function(s, dur)
	if me:GetAttribute("NoShake") then
		return
	end
	trauma = math.min(1, math.max(trauma, s or 0.4))
	traumaDecay = 1 / math.max(0.15, dur or 0.6)
end
RunService:BindToRenderStep("InkwingShake", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if trauma <= 0 then
		return
	end
	local t = os.clock() * 28
	local k = trauma * trauma
	local rx = (math.noise(t, 1.3) * 0.05) * k
	local ry = (math.noise(t, 7.1) * 0.05) * k
	local rz = (math.noise(t, 4.7) * 0.06) * k
	cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz) * CF(math.noise(t, 9.9) * k * 0.8, math.noise(t, 2.2) * k * 0.8, 0)
	trauma = math.max(0, trauma - dt * traumaDecay)
end)

local function myPos()
	local c = me.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position, hrp
end
local function near(pos, r)
	local mp = myPos()
	return mp and (mp - pos).Magnitude < r
end

---------------------------------------------------------------------------
-- WIND CURRENTS + UPDRAFTS (Overworld)
---------------------------------------------------------------------------
if OVER then
	local SPD, R = G.CURRENT_SPEED, G.CURRENT_R
	local segs = {}
	for ci, c in ipairs(G.Currents) do
		for i = 1, #c.pts - 1 do
			local a, b = c.pts[i], c.pts[i + 1]
			table.insert(segs, { a = a, b = b, dir = (b - a).Unit, len = (b - a).Magnitude, name = c.name, ci = ci })
		end
	end
	-- v1.7 visuals: thin curling WIND LINES (short white trails) that stream along the current near you.
	-- No beams / big particle volumes - the sky stays clean, the lines only appear around the player.
	local MAXL = isMobile and 18 or 34
	local lines, nearSegs = {}, {}
	for k = 1, MAXL do
		local p = bare(V(0.2, 0.2, 0.2), rgb(255, 255, 255), nil, 1)
		local a0 = Instance.new("Attachment")
		a0.Position = V(0, 0.18, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = V(0, -0.18, 0)
		a1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.55
		tr.MinLength = 0.1
		tr.FaceCamera = true
		tr.LightEmission = 0.4
		tr.Color = ColorSequence.new(rgb(255, 255, 255))
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		tr.Enabled = false
		tr.Parent = p
		lines[k] = { p = p, tr = tr, alive = false }
	end
	local segAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		local cp = cam.CFrame.Position
		segAcc += dt
		if segAcc > 0.5 then
			segAcc = 0
			table.clear(nearSegs)
			for _, s in ipairs(segs) do
				local t = math.clamp((cp - s.a):Dot(s.dir), 0, s.len)
				if (cp - (s.a + s.dir * t)).Magnitude < 320 then
					table.insert(nearSegs, { s = s, t = t })
				end
			end
		end
		for _, L in ipairs(lines) do
			if L.alive then
				L.age += dt
				local k = L.age / L.life
				if k >= 1 or L.d > L.s.len then
					L.alive = false
					L.tr.Enabled = false
				else
					L.d += SPD * 0.75 * dt
					-- curl: a slow corkscrew around the flow line, with one loop near the middle
					local s = L.s
					local up = math.abs(s.dir.Y) > 0.9 and V(1, 0, 0) or V(0, 1, 0)
					local side = s.dir:Cross(up).Unit
					local up2 = side:Cross(s.dir).Unit
					local ang = L.phase + L.age * L.spin
					local rr = L.r * (1 + math.sin(k * math.pi) * 0.4)
					local pos = s.a + s.dir * L.d + side * (L.ox + math.cos(ang) * rr) + up2 * (L.oy + math.sin(ang) * rr)
					L.p.CFrame = CFrame.new(pos)
				end
			elseif #nearSegs > 0 and math.random() < dt * 6 then
				local ns = nearSegs[math.random(1, #nearSegs)]
				local s = ns.s
				L.s = s
				L.d = math.clamp(ns.t + math.random(-120, 120), 0, s.len)
				L.age, L.life = 0, 1 + math.random() * 0.8
				L.ox, L.oy = (math.random() - 0.5) * R * 1.4, (math.random() - 0.5) * R * 1.0
				L.r, L.phase, L.spin = 0.8 + math.random() * 1.6, math.random() * 6.28, (math.random() < 0.5 and -1 or 1) * (2 + math.random() * 3)
				L.alive = true
				local up = math.abs(s.dir.Y) > 0.9 and V(1, 0, 0) or V(0, 1, 0)
				local side = s.dir:Cross(up).Unit
				L.p.CFrame = CFrame.new(s.a + s.dir * L.d + side * L.ox + side:Cross(s.dir).Unit * L.oy)
				task.defer(function()
					L.tr:Clear()
					L.tr.Enabled = true
				end)
			end
		end
	end)
	-- updraft columns
	for _, u in ipairs(G.Updrafts) do
		local host = bare(V(u.r * 1.6, 1, u.r * 1.6), rgb(255, 255, 255), nil, 1)
		host.CFrame = CF(u.pos)
		local em = Instance.new("ParticleEmitter")
		em.EmissionDirection = Enum.NormalId.Top
		em.Shape = Enum.ParticleEmitterShape.Box
		em.Speed = NumberRange.new(70, 95)
		em.Lifetime = NumberRange.new(u.h / 85, u.h / 70)
		em.Rate = isMobile and 4 or 8
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) })
		em.Color = ColorSequence.new(rgb(240, 250, 255))
		em.LightEmission = 0.5
		em.Parent = host
		-- swirling leaves in the column
		local lf = em:Clone()
		lf.Rate = isMobile and 2 or 5
		lf.Size = seq(0.8, 0.6)
		lf.Transparency = seq(0.1, 0.6)
		lf.LightEmission = 0
		lf.Color = ColorSequence.new(rgb(120, 190, 90), rgb(230, 200, 90))
		lf.RotSpeed = NumberRange.new(-200, 200)
		lf.Rotation = NumberRange.new(0, 360)
		lf.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		lf.Parent = host
	end
	-- physics: push the flyer along (Flight.client adds _G.InkwingExtVel)
	local inside, lastName = false, nil
	local windSound = Instance.new("Sound")
	windSound.SoundId = "rbxassetid://9114057128"
	windSound.Looped = true
	windSound.Volume = 0
	windSound.Parent = root
	windSound:Play()
	RunService.Heartbeat:Connect(function(dt)
		local pos = myPos()
		local ext = Vector3.zero
		local nm
		if pos and me:GetAttribute("Flying") then
			local best, bd
			for _, s in ipairs(segs) do
				local t = math.clamp((pos - s.a):Dot(s.dir), 0, s.len)
				local q = s.a + s.dir * t
				local d = (pos - q).Magnitude
				if d < R and (not bd or d < bd) then
					best, bd = { s = s, q = q }, d
				end
			end
			if best then
				-- along the flow + a gentle pull to the centre line
				ext = best.s.dir * SPD + (best.q - pos) * 2.5
				nm = best.s.name
			end
			for _, u in ipairs(G.Updrafts) do
				local flat = V(pos.X - u.pos.X, 0, pos.Z - u.pos.Z).Magnitude
				if flat < u.r and pos.Y > u.pos.Y - 10 and pos.Y < u.pos.Y + u.h then
					ext += V(0, 85, 0)
					nm = nm or "UPDRAFT"
				end
			end
		end
		_G.InkwingExtVel = ext
		local want = ext.Magnitude > 1 and 0.45 or 0
		windSound.Volume += (want - windSound.Volume) * math.min(1, dt * 3)
		if nm and not inside then
			inside = true
			if nm ~= lastName then
				lastName = nm
				FX.word(pos + V(0, 6, 0), nm, rgb(220, 245, 255), 1.1)
			end
			_G.InkwingShake(0.12, 0.3)
		elseif not nm then
			inside = false
		end
	end)
end

---------------------------------------------------------------------------
-- WING TRAILS (coloured by your wing's aspect) while flying fast
---------------------------------------------------------------------------
do
	local trails = {}
	local function trailColor()
		local asp = me:GetAttribute("Aspect")
		local e = asp and G.ESSENCES[asp]
		return e and e.color or rgb(235, 240, 255)
	end
	local function setup(c)
		for _, t in ipairs(trails) do
			t:Destroy()
		end
		trails = {}
		local torso = c:WaitForChild("UpperTorso", 10) or c:WaitForChild("Torso", 5)
		if not torso then
			return
		end
		for side = -1, 1, 2 do
			local a0 = Instance.new("Attachment")
			a0.Position = V(side * 4.5, 1.2, 0.8)
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Position = V(side * 3.8, 0.4, 0.8)
			a1.Parent = torso
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = 0.45
			tr.MinLength = 0.2
			tr.FaceCamera = true
			tr.LightEmission = 0.7
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			tr.Enabled = false
			tr.Parent = torso
			table.insert(trails, tr)
			table.insert(trails, a0)
			table.insert(trails, a1)
		end
	end
	me.CharacterAdded:Connect(setup)
	if me.Character then
		task.spawn(setup, me.Character)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.15 then
			return
		end
		acc = 0
		local _, hrp = myPos()
		local on = hrp and me:GetAttribute("Flying") and hrp.AssemblyLinearVelocity.Magnitude > 55
		local col = ColorSequence.new(trailColor(), rgb(255, 255, 255))
		for _, t in ipairs(trails) do
			if t:IsA("Trail") then
				t.Enabled = on and true or false
				t.Color = col
			end
		end
	end)
end

---------------------------------------------------------------------------
-- PER-ZONE WEATHER around the camera (all realms)
---------------------------------------------------------------------------
do
	local host = bare(V(160, 2, 160), rgb(255, 255, 255), nil, 1)
	local em = Instance.new("ParticleEmitter")
	em.Shape = Enum.ParticleEmitterShape.Box
	em.EmissionDirection = Enum.NormalId.Bottom
	em.Enabled = false
	em.Parent = host
	local mode
	local MODES = {
		snow = { rate = 90, speed = { 8, 14 }, life = { 6, 8 }, size = { 0.35, 0.2 }, col = { rgb(255, 255, 255), rgb(220, 235, 255) }, tr = 0.1, light = 0.2, accel = V(10, 0, 4), dir = Enum.NormalId.Bottom, h = 50 },
		ash = { rate = 70, speed = { 2, 6 }, life = { 7, 9 }, size = { 0.3, 0.12 }, col = { rgb(90, 80, 80), rgb(255, 120, 40) }, tr = 0.15, light = 0.3, accel = V(0, 1.5, 0), dir = Enum.NormalId.Bottom, h = 40 },
		embers = { rate = 35, speed = { 6, 12 }, life = { 4, 6 }, size = { 0.25, 0 }, col = { rgb(255, 170, 60), rgb(255, 60, 20) }, tr = 0, light = 1, accel = V(0, 5, 0), dir = Enum.NormalId.Top, h = -40 },
		motes = { rate = 30, speed = { 1, 3 }, life = { 6, 9 }, size = { 0.45, 0 }, col = { rgb(255, 245, 200), rgb(255, 220, 140) }, tr = 0.1, light = 1, accel = V(0, 1, 0), dir = Enum.NormalId.Top, h = -30 },
		stardust = { rate = 40, speed = { 0.5, 2 }, life = { 6, 10 }, size = { 0.3, 0 }, col = { rgb(200, 180, 255), rgb(140, 220, 255) }, tr = 0, light = 1, accel = V(0, 0, 0), dir = Enum.NormalId.Top, h = 0 },
		marine = { rate = 60, speed = { 0.5, 1.5 }, life = { 8, 12 }, size = { 0.18, 0.1 }, col = { rgb(200, 230, 230), rgb(120, 170, 190) }, tr = 0.3, light = 0.2, accel = V(0, -0.6, 0), dir = Enum.NormalId.Bottom, h = 0 },
	}
	local function zoneMode(y)
		if G.REALM == "Overworld" then
			if y > G.STORM_BASE + 350 then
				return "snow"
			elseif y < -1500 then
				return "marine"
			end
		elseif G.REALM == "Underworld" then
			if y < -4000 and y > -5200 then
				return y < -4600 and "embers" or "ash"
			end
		elseif G.REALM == "Celestial" then
			if y > 6000 then
				return "motes"
			elseif y > 4100 then
				return "stardust"
			end
		end
		return nil
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local cp = cam.CFrame.Position
		local m = MODES[mode]
		host.CFrame = CF(cp + V(0, m and m.h or 40, 0))
		if acc < 0.5 then
			return
		end
		acc = 0
		local nm = zoneMode(cp.Y)
		if nm ~= mode then
			mode = nm
			m = MODES[nm]
			em.Enabled = m ~= nil
			if m then
				em.Rate = isMobile and m.rate * 0.45 or m.rate
				em.Speed = NumberRange.new(m.speed[1], m.speed[2])
				em.Lifetime = NumberRange.new(m.life[1], m.life[2])
				em.Size = seq(m.size[1], m.size[2])
				em.Color = ColorSequence.new(m.col[1], m.col[2])
				em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, m.tr), NumberSequenceKeypoint.new(0.85, m.tr), NumberSequenceKeypoint.new(1, 1) })
				em.LightEmission = m.light
				em.Acceleration = m.accel
				em.EmissionDirection = m.dir
				em.SpreadAngle = Vector2.new(25, 25)
				em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			end
		end
	end)
end

---------------------------------------------------------------------------
-- FEATHER PLUMES UI
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PlumesUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = me:WaitForChild("PlayerGui")
local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end
local function stroke(o, t, c)
	new("UIStroke", { Thickness = t or 2, Color = c or rgb(30, 30, 40), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local INK, PAPER = rgb(30, 30, 40), rgb(250, 246, 236)
local btnSize = isMobile and 64 or 52
local open = new("TextButton", {
	Size = UDim2.fromOffset(btnSize, btnSize),
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, isMobile and 104 or 124, 0.5, isMobile and 50 or 76), -- right of the SKILLS button
	BackgroundColor3 = PAPER,
	Text = "",
	AutoButtonColor = true,
}, gui)
round(open, 14)
stroke(open, 3)
do
	-- a little drawn feather icon
	local f = new("Frame", { Size = UDim2.new(0.18, 0, 0.62, 0), Position = UDim2.new(0.5, 0, 0.42, 0), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 30, BackgroundColor3 = rgb(255, 160, 230), BorderSizePixel = 0 }, open)
	round(f, 99)
	stroke(f, 2)
	new("TextLabel", { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.new(0, 0, 0.7, 0), BackgroundTransparency = 1, Text = "PLUMES", Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = INK }, open)
end
local panel = new("Frame", {
	Size = UDim2.fromScale(0.92, 0.82),
	Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = PAPER,
	Visible = false,
}, gui)
round(panel, 16)
stroke(panel, 4)
new("UISizeConstraint", { MaxSize = Vector2.new(620, 460), MinSize = Vector2.new(300, 240) }, panel)
new("TextLabel", { Size = UDim2.new(1, -80, 0, 40), Position = UDim2.fromOffset(16, 8), BackgroundTransparency = 1, Text = "FEATHER PLUMES", TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne, TextSize = 28, TextColor3 = INK }, panel)
local slotsLbl = new("TextLabel", { Size = UDim2.new(1, -32, 0, 30), Position = UDim2.fromOffset(16, 44), BackgroundTransparency = 1, Text = "", TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = rgb(110, 105, 100) }, panel)
local close = new("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -54, 0, 10), BackgroundColor3 = rgb(255, 120, 110), Text = "X", Font = Enum.Font.FredokaOne, TextSize = 24, TextColor3 = rgb(255, 255, 255) }, panel)
round(close, 12)
stroke(close, 3)
local list = new("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -92), Position = UDim2.fromOffset(12, 82), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, panel)
new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, isMobile and 96 or 104), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local function refresh()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local owned = {}
	pcall(function()
		owned = HttpService:JSONDecode(me:GetAttribute("Plumes") or "{}")
	end)
	local eq = string.split(me:GetAttribute("Equip") or "", ",")
	local slots = G.PlumeSlots(me:GetAttribute("WingRank") or 1)
	local n = 0
	for _, id in ipairs(eq) do
		if id ~= "" then
			n += 1
		end
	end
	slotsLbl.Text = ("Plumes are feathers you socket into your wings. Each one changes how your shots work.  EQUIPPED %d / %d - tap one to equip. Found from bosses, golden + elite monsters, shrines, ancient chests and world events."):format(n, slots)
	slotsLbl.TextScaled = true
	for i, id in ipairs(G.PLUME_ORDER) do
		local pl = G.Plumes[id]
		local have = (owned[id] or 0) > 0
		local on = table.find(eq, id) ~= nil
		local card = new("TextButton", { LayoutOrder = i, BackgroundColor3 = on and pl.color:Lerp(PAPER, 0.55) or (have and rgb(255, 255, 255) or rgb(225, 222, 215)), Text = "", AutoButtonColor = have }, list)
		round(card, 12)
		stroke(card, on and 4 or 2, on and pl.color:Lerp(INK, 0.3) or INK)
		local feather = new("Frame", { Size = UDim2.fromOffset(12, 46), Position = UDim2.fromOffset(18, 24), Rotation = 25, BackgroundColor3 = have and pl.color or rgb(170, 168, 160), BorderSizePixel = 0 }, card)
		round(feather, 99)
		stroke(feather, 2)
		new("TextLabel", { Size = UDim2.new(1, -52, 0, 22), Position = UDim2.fromOffset(46, 6), BackgroundTransparency = 1, Text = have and pl.name or "???", TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = INK }, card)
		new("TextLabel", { Size = UDim2.new(1, -52, 1, -34), Position = UDim2.fromOffset(46, 28), BackgroundTransparency = 1, Text = have and pl.desc or "Not found yet.", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamMedium, TextSize = isMobile and 12 or 13, TextColor3 = rgb(70, 66, 60) }, card)
		if on then
			local tag = new("TextLabel", { Size = UDim2.fromOffset(70, 18), Position = UDim2.new(1, -76, 1, -22), BackgroundColor3 = INK, Text = "EQUIPPED", Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = rgb(255, 255, 255) }, card)
			round(tag, 6)
		end
		if have then
			card.MouseButton1Click:Connect(function()
				Combat:FireServer(on and "unequip" or "equip", id)
			end)
		end
	end
end
local function togglePlumes()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
	end
end
open.MouseButton1Click:Connect(togglePlumes)
open.Visible = false -- v1.9: opened from the menu orb (Inventory)
_G.InkwingTogglePlumes = togglePlumes
close.MouseButton1Click:Connect(function()
	panel.Visible = false
end)
me:GetAttributeChangedSignal("Equip"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)
me:GetAttributeChangedSignal("Plumes"):Connect(function()
	if panel.Visible then
		refresh()
	end
end)

-- big "new plume" reveal
local function plumeReveal(id, why)
	local pl = G.Plumes[id]
	if not pl then
		return
	end
	local f = new("Frame", { Size = UDim2.fromOffset(360, 170), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PAPER }, gui)
	round(f, 18)
	stroke(f, 4, pl.color:Lerp(INK, 0.3))
	local sc = new("UIScale", { Scale = 0.2 }, f)
	local feather = new("Frame", { Size = UDim2.fromOffset(18, 80), Position = UDim2.fromOffset(40, 45), Rotation = 25, BackgroundColor3 = pl.color, BorderSizePixel = 0 }, f)
	round(feather, 99)
	stroke(feather, 3)
	new("TextLabel", { Size = UDim2.new(1, -100, 0, 22), Position = UDim2.fromOffset(86, 14), BackgroundTransparency = 1, Text = "NEW FEATHER PLUME", TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = rgb(120, 115, 110) }, f)
	new("TextLabel", { Size = UDim2.new(1, -100, 0, 36), Position = UDim2.fromOffset(86, 34), BackgroundTransparency = 1, Text = pl.name, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = pl.color:Lerp(INK, 0.35) }, f)
	new("TextLabel", { Size = UDim2.new(1, -100, 0, 60), Position = UDim2.fromOffset(86, 72), BackgroundTransparency = 1, Text = pl.desc, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = INK }, f)
	new("TextLabel", { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 1, -26), BackgroundTransparency = 1, Text = why and ("from " .. why) or "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = rgb(140, 135, 128) }, f)
	TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local mp = myPos()
	if mp then
		FX.ring(mp, pl.color, 2, 18, 0.6, 1.2)
		FX.shards(mp + V(0, 2, 0), pl.color, 14, 30)
	end
	_G.InkwingShake(0.25, 0.4)
	task.delay(4.5, function()
		TweenService:Create(sc, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.3)
		f:Destroy()
	end)
end

---------------------------------------------------------------------------
-- ELITES / PARASITES / MERGED: tag + aura on the monster
---------------------------------------------------------------------------
do
	local folder = workspace:WaitForChild("Enemies")
	local function tagIt(part)
		local aff = part:GetAttribute("Affix")
		local para = part:GetAttribute("Parasite")
		if not aff and not para then
			return
		end
		if part:FindFirstChild("EliteTag") then
			return
		end
		local A = aff and G.Affixes[aff]
		local col = A and A.color or rgb(140, 220, 255)
		local bb = new("BillboardGui", { Name = "EliteTag", Size = UDim2.fromOffset(170, 40), StudsOffsetWorldSpace = V(0, 9, 0), AlwaysOnTop = true, MaxDistance = 220, LightInfluence = 0 }, part)
		local l = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = A and ("ELITE  -  " .. A.name) or "PARASITE", Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, bb)
		if A then
			new("TextLabel", { Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 1), BackgroundTransparency = 1, Text = A.desc, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0.2 }, l)
			local em = new("ParticleEmitter", {
				Rate = isMobile and 8 or 18,
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(2, 6),
				SpreadAngle = Vector2.new(180, 180),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
				Transparency = seq(0.2, 1),
				LightEmission = 1,
				Color = ColorSequence.new(col),
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
			}, part)
			em.Name = "EliteAura"
			new("PointLight", { Color = col, Range = 18, Brightness = 1.5 }, part)
		end
	end
	for _, p in ipairs(folder:GetChildren()) do
		task.spawn(tagIt, p)
	end
	folder.ChildAdded:Connect(function(p)
		task.wait(0.1)
		tagIt(p)
		p:GetAttributeChangedSignal("Affix"):Connect(function()
			tagIt(p)
		end)
	end)
end

---------------------------------------------------------------------------
-- SKY SHRINES: braziers burn when lit
---------------------------------------------------------------------------
if OVER then
	task.spawn(function()
		local life = workspace:WaitForChild("World"):WaitForChild("Gate"):WaitForChild("Life", 30)
		if not life then
			return
		end
		for _, b in ipairs(life:GetDescendants()) do
			if b:IsA("BasePart") and b:GetAttribute("ShrineId") then
				local fire = new("ParticleEmitter", {
					Rate = 0,
					Lifetime = NumberRange.new(0.6, 1),
					Speed = NumberRange.new(5, 9),
					SpreadAngle = Vector2.new(15, 15),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) }),
					Transparency = seq(0, 1),
					LightEmission = 1,
					Color = ColorSequence.new(rgb(255, 220, 120), rgb(255, 80, 30)),
					Texture = "rbxasset://textures/particles/fire_main.dds",
					EmissionDirection = Enum.NormalId.Top,
				}, b)
				local light = new("PointLight", { Color = rgb(255, 170, 80), Range = 0, Brightness = 2.5 }, b)
				local function upd()
					local lit = b:GetAttribute("Lit") == true
					fire.Rate = lit and 40 or 0
					light.Range = lit and 26 or 0
					if lit then
						FX.flash(b.Position + V(0, 2, 0), rgb(255, 180, 80), 8, 0.25)
					end
				end
				b:GetAttributeChangedSignal("Lit"):Connect(upd)
				upd()
			end
		end
	end)
end

---------------------------------------------------------------------------
-- PERCHED glow
---------------------------------------------------------------------------
me:GetAttributeChangedSignal("Perched"):Connect(function()
	local mp = myPos()
	if me:GetAttribute("Perched") and mp then
		FX.word(mp + V(0, 5, 0), "PERCHED - MANA FLOWS", rgb(170, 220, 255), 0.9)
		FX.ring(mp - V(0, 2.5, 0), rgb(170, 220, 255), 1, 7, 0.6, 0.4)
	end
end)

---------------------------------------------------------------------------
-- LEVIATHAN visual: a huge paper-and-ink sky whale riding the server root
---------------------------------------------------------------------------
local function buildLeviathan(rootPart)
	local m = Instance.new("Model")
	m.Name = "Leviathan"
	m.Parent = root
	local body = {}
	local PALE, BELLY, LINE = rgb(70, 110, 170), rgb(225, 235, 245), rgb(25, 30, 45)
	local function seg(z, w, h, col)
		local p = bare(V(w, h, 26), col, Enum.Material.SmoothPlastic)
		p.Shape = Enum.PartType.Ball
		p.Size = V(w, w, w)
		p.Parent = m
		table.insert(body, { p = p, z = z, w = w })
		return p
	end
	for i = 0, 8 do
		local w = 46 * math.sin((i + 1) / 10 * math.pi) + 10
		seg(-60 + i * 15, w, w, PALE)
	end
	local belly = {}
	for i = 1, 7 do
		local w = (46 * math.sin((i + 1) / 10 * math.pi) + 10) * 0.86
		local p = bare(V(w, w, w), BELLY, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
		p.Parent = m
		table.insert(belly, { p = p, z = -60 + i * 15 })
	end
	local fins = {}
	for side = -1, 1, 2 do
		local f = bare(V(4, 34, 60), PALE, Enum.Material.SmoothPlastic)
		f.Parent = m
		table.insert(fins, { p = f, side = side })
	end
	local tail = bare(V(70, 3, 26), PALE, Enum.Material.SmoothPlastic)
	tail.Parent = m
	local eyes = {}
	for side = -1, 1, 2 do
		local e = bare(V(4, 4, 4), rgb(255, 250, 220), Enum.Material.Neon, 0, Enum.PartType.Ball)
		e.Parent = m
		table.insert(eyes, { p = e, side = side })
	end
	-- glowing ink spots along the back
	local spots = {}
	for i = 1, 10 do
		local s = bare(V(3, 3, 3), rgb(140, 230, 255), Enum.Material.Neon, 0, Enum.PartType.Ball)
		s.Parent = m
		table.insert(spots, { p = s, z = -55 + i * 11, x = (i % 2 == 0 and 1 or -1) * 8 })
	end
	local song = Instance.new("Sound")
	song.SoundId = "rbxassetid://9120018695"
	song.Volume = 1.2
	song.PlaybackSpeed = 0.45
	song.RollOffMaxDistance = 1500
	song.RollOffMinDistance = 120
	local att = Instance.new("Attachment")
	att.Parent = rootPart
	song.Parent = rootPart
	song.Looped = true
	song:Play()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not rootPart.Parent then
			conn:Disconnect()
			m:Destroy()
			return
		end
		local t = os.clock()
		local base = rootPart.CFrame
		for i, b in ipairs(body) do
			local wave = math.sin(t * 1.2 - i * 0.5) * 4
			b.p.CFrame = base * CF(0, wave, b.z)
		end
		for i, b in ipairs(belly) do
			local wave = math.sin(t * 1.2 - (i + 0.5) * 0.5) * 4
			b.p.CFrame = base * CF(0, wave - 6, b.z)
		end
		for _, f in ipairs(fins) do
			f.p.CFrame = base * CF(f.side * 30, -6, -10) * CFrame.Angles(0, 0, f.side * (0.9 + math.sin(t * 1.4) * 0.45)) * CF(0, -14, 0)
		end
		tail.CFrame = base * CF(0, math.sin(t * 1.2 - 5) * 7, 78) * CFrame.Angles(math.sin(t * 1.2 - 5.5) * 0.35, 0, 0)
		for _, e in ipairs(eyes) do
			e.p.CFrame = base * CF(e.side * 14, 2, -70)
		end
		for i, s in ipairs(spots) do
			local wave = math.sin(t * 1.2 - (s.z + 60) / 15 * 0.5) * 4
			s.p.CFrame = base * CF(s.x, 20 + wave, s.z)
			s.p.Transparency = 0.2 + math.sin(t * 2 + i) * 0.2
		end
	end)
	FX.word(rootPart.Position + V(0, 60, 0), "THE SKY LEVIATHAN", rgb(160, 220, 255), 2)
end
workspace.ChildAdded:Connect(function(c)
	if c.Name == "LeviathanRoot" then
		buildLeviathan(c)
	end
end)
if workspace:FindFirstChild("LeviathanRoot") then
	buildLeviathan(workspace.LeviathanRoot)
end

---------------------------------------------------------------------------
-- FX EVENTS
---------------------------------------------------------------------------
Fx.OnClientEvent:Connect(function(kind, info)
	info = info or {}
	if kind == "Knock" then
		_G.InkwingImpulse = (_G.InkwingImpulse or Vector3.zero) + info.v
		_G.InkwingShake(0.35, 0.4)
	elseif kind == "PlumeGet" then
		plumeReveal(info.id, info.why)
	elseif kind == "Chain" then
		local pts = info.pts or {}
		for i = 1, #pts - 1 do
			FX.bolt(pts[i], pts[i + 1], rgb(255, 240, 120), 0.6, 0.25)
			FX.impact(pts[i + 1], rgb(255, 240, 120), "Storm", 0.6)
		end
	elseif kind == "Burn" then
		FX.emit(info.pos, "spark1", rgb(255, 140, 50), 6, { size = 1.2, life = 0.5, speed = 12 })
		FX.flash(info.pos, rgb(255, 120, 40), 3, 0.15)
	elseif kind == "GaleBlast" then
		FX.ring(info.pos, rgb(220, 255, 240), 3, 30, 0.45, 1.5)
		FX.puffs(info.pos, rgb(240, 255, 250), 8, 4, 0.7)
		if near(info.pos, 8) then
			_G.InkwingShake(0.2, 0.3)
		end
	elseif kind == "GalePulse" then
		local r = info.big and 90 or 32
		FX.ring(info.pos, rgb(200, 255, 230), 2, r, 0.5, info.big and 4 or 1.2)
		FX.puffs(info.pos, rgb(230, 255, 245), info.big and 14 or 6, info.big and 9 or 4, 0.8)
	elseif kind == "AnchorPull" then
		if info.big then
			FX.ring(info.from, rgb(150, 110, 255), 120, 4, 1.1, 3)
			_G.InkwingShake(0.5, 0.9)
		else
			FX.bolt(info.from, info.to, rgb(150, 110, 255), 0.8, 0.4)
			FX.ring(info.from, rgb(150, 110, 255), 30, 2, 0.5, 1)
		end
	elseif kind == "Merge" then
		FX.projectile(info.from, info.to, rgb(60, 60, 110), 60, 1.6)
		FX.splat(info.to, rgb(40, 40, 80), 6, 2)
		FX.word(info.to + V(0, 8, 0), "BLOBS MERGE!", rgb(120, 120, 220), 1)
	elseif kind == "Swarm" then
		FX.word(info.pos + V(0, 6, 0), "THE SWARM RETURNS!", rgb(200, 80, 80), 1.2)
	elseif kind == "WaspCall" then
		FX.word(info.pos + V(0, 6, 0), "BZZZT!", rgb(255, 210, 70), 1)
		FX.ring(info.pos, rgb(255, 210, 70), 2, 40, 0.6, 0.8)
	elseif kind == "Blink" then
		FX.puffs(info.from, rgb(50, 40, 50), 8, 3, 0.6)
		FX.puffs(info.to, rgb(50, 40, 50), 8, 3, 0.6)
		FX.flash(info.to, rgb(255, 90, 40), 6, 0.2)
	elseif kind == "EShield" then
		local p = info.part
		if p and p.Parent then
			local s = bare(V(1, 1, 1), rgb(255, 230, 140), Enum.Material.ForceField, 0.2, Enum.PartType.Ball)
			local sz = math.max(14, (p:GetAttribute("Scale") or 1) * 18)
			s.Size = V(sz, sz, sz)
			local c
			c = RunService.RenderStepped:Connect(function()
				if not p.Parent or not s.Parent then
					c:Disconnect()
					return
				end
				s.CFrame = p.CFrame
			end)
			task.delay(info.t or 2.5, function()
				s:Destroy()
			end)
		end
	elseif kind == "Mirror" then
		FX.flash(info.pos, rgb(180, 220, 255), 10, 0.3)
		FX.word(info.pos + V(0, 6, 0), "IT SPLITS!", rgb(180, 220, 255), 1.1)
	elseif kind == "InkPool" then
		local pool = bare(V(0.6, 32, 32), rgb(25, 25, 60), Enum.Material.SmoothPlastic, 0.25, Enum.PartType.Cylinder)
		local ray = workspace:Raycast(info.pos, V(0, -60, 0))
		local at = ray and ray.Position or info.pos
		pool.CFrame = CF(at + V(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		FX.splat(at, rgb(40, 40, 110), 12, info.t or 5)
		task.delay(info.t or 5, function()
			TweenService:Create(pool, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			task.wait(0.5)
			pool:Destroy()
		end)
	elseif kind == "BossPhase" then
		_G.InkwingShake(0.8, 1.2)
		FX.ring(info.pos, rgb(255, 80, 60), 5, 140, 0.9, 4)
		FX.flash(info.pos, rgb(255, 120, 90), 40, 0.4)
	elseif kind == "Blast" then
		if info.pos and near(info.pos, 50) then
			_G.InkwingShake(0.3, 0.35)
		end
	elseif kind == "Evolve" then
		_G.InkwingShake(0.6, 1)
	elseif kind == "ShrineStart" then
		FX.word((myPos() or V()) + V(0, 7, 0), (info.name or "SHRINE") .. ": LIGHT ALL 4 IN " .. tostring(info.t) .. "s!", rgb(255, 200, 110), 1.1)
	elseif kind == "ShrineDone" then
		FX.ring(info.pos, rgb(255, 210, 120), 4, 60, 0.8, 2)
		FX.shards(info.pos + V(0, 4, 0), rgb(255, 210, 120), 20, 40)
		if near(info.pos, 120) then
			_G.InkwingShake(0.4, 0.6)
		end
	elseif kind == "LeviathanGift" then
		for i = 1, 24 do
			task.delay(i * 0.08, function()
				local p0 = info.pos + V(rng:NextNumber(-60, 60), 20, rng:NextNumber(-60, 60))
				FX.projectile(p0, p0 + V(rng:NextNumber(-40, 40), -120, rng:NextNumber(-40, 40)), rgb(140, 230, 255), 70, 1.2)
			end)
		end
	elseif kind == "StarFall" then
		local target = info.pos
		local from = target + V(-400, 700, 250)
		local star = bare(V(8, 8, 8), rgb(230, 220, 255), Enum.Material.Neon, 0, Enum.PartType.Ball)
		local a0 = Instance.new("Attachment")
		a0.Position = V(0, 3, 0)
		a0.Parent = star
		local a1 = Instance.new("Attachment")
		a1.Position = V(0, -3, 0)
		a1.Parent = star
		new("Trail", { Attachment0 = a0, Attachment1 = a1, Lifetime = 1.2, LightEmission = 1, Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 120, 255)), Transparency = seq(0, 1), WidthScale = seq(1, 0) }, star)
		new("PointLight", { Color = rgb(200, 180, 255), Range = 60, Brightness = 4 }, star)
		local t0 = os.clock()
		local c
		c = RunService.RenderStepped:Connect(function()
			local k = math.min(1, (os.clock() - t0) / 2.6)
			star.CFrame = CF(from:Lerp(target, k * k))
			if k >= 1 then
				c:Disconnect()
				star:Destroy()
				FX.explosion(target, rgb(190, 160, 255), 22, false)
				FX.ring(target, rgb(220, 200, 255), 4, 70, 0.8, 2.5)
				if near(target, 400) then
					_G.InkwingShake(near(target, 120) and 0.9 or 0.4, 1)
				end
			end
		end)
	end
end)

---------------------------------------------------------------------------
-- v1.7 MEDITATION AURA: flowing ribbons that wrap the seated body (like the sketch).
-- Denser, wider, brighter the further along your evolution (mana toward the next rank) you are.
---------------------------------------------------------------------------
do
	local auras = {}
	local function progress(pl)
		-- v1.8d: the aura stays tiny until your mana pool is HUGE (log scale, cubed)
		local mx = math.max(1, pl:GetAttribute("ManaMax") or 1)
		return math.clamp((math.log10(mx) / 4.6) ^ 3, 0, 1)
	end
	local function colorOf(pl)
		local e = G.ESSENCES[pl:GetAttribute("Aspect") or ""]
		return e and e.color or rgb(70, 170, 255)
	end
	local MAXR = isMobile and 7 or 10
	local function make(pl)
		local a = { ribbons = {}, t0 = os.clock() }
		for k = 1, MAXR do
			local p = bare(V(0.2, 0.2, 0.2), rgb(255, 255, 255), nil, 1)
			local a0 = Instance.new("Attachment")
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Parent = p
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.FaceCamera = true
			tr.LightEmission = 1
			tr.MinLength = 0.05
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
			tr.Parent = p
			a.ribbons[k] = { p = p, tr = tr, a0 = a0, a1 = a1, ph = k / MAXR * math.pi * 2, sp = 1.4 + (k % 3) * 0.35, dir = (k % 2 == 0) and 1 or -1 }
		end
		local glow = bare(V(1, 1, 1), rgb(255, 255, 255), nil, 1)
		a.light = Instance.new("PointLight")
		a.light.Parent = glow
		a.glow = glow
		-- dense rising motes (more with progress)
		a.em = Instance.new("ParticleEmitter")
		a.em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		a.em.Lifetime = NumberRange.new(1.2, 2)
		a.em.Speed = NumberRange.new(1.5, 4)
		a.em.SpreadAngle = Vector2.new(25, 25)
		a.em.EmissionDirection = Enum.NormalId.Top
		a.em.LightEmission = 1
		a.em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		a.em.Transparency = NumberSequence.new(0.2, 1)
		a.em.Shape = Enum.ParticleEmitterShape.Cylinder
		a.em.Parent = glow
		glow.Size = V(5, 1, 5)
		return a
	end
	local function kill(pl)
		local a = auras[pl]
		if a then
			for _, r in ipairs(a.ribbons) do
				r.p:Destroy()
			end
			a.glow:Destroy()
			auras[pl] = nil
		end
	end
	Players.PlayerRemoving:Connect(kill)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			if pl:GetAttribute("Meditating") == true and hrp then
				local a = auras[pl] or make(pl)
				auras[pl] = a
				local pr = progress(pl)
				local col = colorOf(pl)
				local n = math.max(1, math.floor(1 + pr * (MAXR - 1) + 0.5))
				local fade = math.min(1, (t - a.t0) / 1.2) -- grows in as you settle
				local base = hrp.CFrame * CFrame.new(0, -1.6, 0) -- seated: the hips
				for k, r in ipairs(a.ribbons) do
					local on = k <= n
					r.tr.Enabled = on
					if on then
						-- each ribbon traces a wrapping loop: wide around the legs, hugging up the body,
						-- arching over the head, then swinging back down the other side (the sketch's outline)
						local u = (t * r.sp * 0.35 + r.ph / (math.pi * 2)) % 1
						local ang = r.ph + r.dir * u * math.pi * 2
						local h = math.sin(u * math.pi) -- 0 at the bottom, 1 over the head
						local rad = (2.9 - h * 1.4) * (0.4 + pr * 0.95) + math.sin(t * 3 + k) * 0.08
						local y = -0.6 + h * (2.4 + pr * 3.4)
						local pos = base * V(math.cos(ang) * rad, y, math.sin(ang) * rad * 0.85)
						r.p.CFrame = CFrame.new(pos)
						local w = (0.05 + pr * 0.63) * fade
						r.a0.Position = V(0, w, 0)
						r.a1.Position = V(0, -w, 0)
						r.tr.Lifetime = 0.25 + pr * 0.95
						r.tr.Color = ColorSequence.new(col:Lerp(rgb(255, 255, 255), 0.45), col)
					end
				end
				a.glow.CFrame = base * CFrame.new(0, -0.2, 0)
				a.light.Color = col
				a.light.Range = 3 + pr * 19
				a.light.Brightness = (0.12 + pr * 2.7 + math.sin(t * 1.8) * 0.1) * fade
				a.em.Rate = (0.8 + pr * 44) * fade * (isMobile and 0.5 or 1)
				a.em.Color = ColorSequence.new(col:Lerp(rgb(255, 255, 255), 0.5), col)
			elseif auras[pl] then
				kill(pl)
			end
		end
	end)
end
