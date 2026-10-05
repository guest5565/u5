--!nonstrict
-- INKWING :: SEA LIFE + "YOU ARE IN THE OCEAN" feedback (local)
--   * crossing the surface: big splash (ring + spray + flash) and a muffled underwater screen tint + blur
--   * HUGE ambient monsters: 3 ink leviathans (≈170 studs) cruising slow circles under the sea,
--     one of them just below the surface so you see its giant shadow from the air
--   * kraken arms: giant ink tentacles rising out of the sea and swaying near the Driftwood Isles
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("Game"))
local Audio = require(Shared:WaitForChild("Audio"))
local me = Players.LocalPlayer
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local SEA = G.SEA

local root = Instance.new("Folder")
root.Name = "SeaLifeFX"
local function part(size, color, mat, tr, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material, p.Transparency = size, color, mat or Enum.Material.SmoothPlastic, tr or 0
	if shape then
		p.Shape = shape
	end
	p.CFrame = CF(0, -9000, 0)
	p.Parent = root
	return p
end

---------------------------------------------------------------------------
-- underwater screen: tint, wobbling surface line, blur
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Underwater"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -5
gui.Parent = me:WaitForChild("PlayerGui")
local tint = Instance.new("Frame")
tint.Size = UDim2.fromScale(1, 1)
tint.BackgroundColor3 = rgb(20, 80, 170)
tint.BackgroundTransparency = 1
tint.BorderSizePixel = 0
tint.Parent = gui
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
grad.Parent = tint
local blur = Instance.new("BlurEffect")
blur.Name = "UnderwaterBlur"
blur.Size = 0
blur.Parent = Lighting

---------------------------------------------------------------------------
-- splash
---------------------------------------------------------------------------
local function splash(pos, down)
	local c = V(pos.X, SEA + 0.8, pos.Z)
	for k = 1, 14 do
		local a = k / 14 * math.pi * 2
		local p = part(V(1.4, 1.4, 1.4), Color3.new(1, 1, 1), Enum.Material.Neon, 0.1, Enum.PartType.Ball)
		p.Parent = workspace
		p.CFrame = CF(c)
		local goal = c + V(math.cos(a) * 14, math.random(6, 16), math.sin(a) * 14)
		TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CF(goal), Transparency = 1, Size = V(0.4, 0.4, 0.4) }):Play()
		task.delay(0.6, function()
			p:Destroy()
		end)
	end
	local ring = part(V(0.4, 4, 4), Color3.new(1, 1, 1), Enum.Material.Neon, 0.2, Enum.PartType.Cylinder)
	ring.Parent = workspace
	ring.CFrame = CF(c) * A(0, 0, math.pi / 2)
	TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = V(0.2, 46, 46), Transparency = 1 }):Play()
	task.delay(1, function()
		ring:Destroy()
	end)
	pcall(Audio.play, "boom", { vol = 0.35, pitch = down and 0.6 or 0.8 })
	-- a short white flash on the screen
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = rgb(220, 240, 255)
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	f.Parent = gui
	TweenService:Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.6, function()
		f:Destroy()
	end)
end

---------------------------------------------------------------------------
-- LEVIATHANS: huge ink whales with glowing eyes and a mouth full of teeth
---------------------------------------------------------------------------
local INK, INK2 = rgb(14, 20, 44), rgb(24, 34, 70)
local function leviathan(center, radius, depth, speed, scale)
	local L = { center = center, r = radius, y = depth, sp = speed, s = scale, pieces = {}, ph = math.random() * 6 }
	local function add(size, color, off, mat, tr, shape, seg)
		local p = part(size * scale, color, mat, tr, shape)
		table.insert(L.pieces, { p = p, off = off, seg = seg or 0 })
	end
	-- body: 10 segments tapering toward the tail (+Z)
	for i = 0, 9 do
		local d = (26 - i * 2) * (i == 0 and 1.1 or 1)
		add(V(d, d * 0.8, 14), i % 2 == 0 and INK or INK2, V(0, 0, i * 11), nil, 0, nil, i)
	end
	add(V(4, 22, 18), INK2, V(0, 0, 112), nil, 0, nil, 10) -- tail fluke (vertical)
	add(V(40, 3, 16), INK2, V(0, 0, 112), nil, 0, nil, 10) -- tail fluke (wide)
	for _, sd in ipairs({ -1, 1 }) do
		add(V(26, 2, 12), INK2, V(sd * 22, -6, 14), nil, 0, nil, 1) -- flippers
		add(V(3, 3, 3), rgb(255, 60, 70), V(sd * 9, 4, -7.4), Enum.Material.Neon, 0, Enum.PartType.Ball, 0) -- eyes
		add(V(5, 1.2, 2), rgb(8, 8, 18), V(sd * 8.6, 6.4, -7.6), nil, 0, nil, 0) -- angry brows
	end
	add(V(20, 2.5, 1), rgb(120, 10, 40), V(0, -5, -7.3), Enum.Material.Neon, 0, nil, 0) -- maw glow
	for k = 0, 9 do
		add(V(1.4, 2.6, 1), rgb(245, 240, 225), V(-9 + k * 2, -3.6, -7.7), nil, 0, nil, 0) -- teeth
	end
	for i = 1, 8 do
		add(V(1.2, 1.2, 1.2), rgb(80, 230, 255), V(0, 10 - i * 0.4, i * 11), Enum.Material.Neon, 0, Enum.PartType.Ball, i) -- spine lights
	end
	return L
end
local whales = {
	leviathan(V(0, 0, -60), 340, SEA - 45, 0.025, 1.6), -- just under the surface: a giant shadow from above
	leviathan(V(-80, 0, -120), 260, -1250, -0.03, 1.2),
	leviathan(V(60, 0, 0), 300, -2150, 0.02, 1.5),
}

---------------------------------------------------------------------------
-- KRAKEN ARMS rising out of the sea (visible from the air)
---------------------------------------------------------------------------
local arms = {}
for k, base in ipairs({ V(300, SEA, -380), V(330, SEA, -330), V(270, SEA, -320), V(-380, SEA, 180), V(-340, SEA, 230) }) do
	local segs = {}
	for i = 1, 12 do
		local r = 9 - i * 0.6
		segs[i] = part(V(r, r, r), i % 2 == 0 and INK or INK2, nil, 0, Enum.PartType.Ball)
	end
	local suckers = {}
	for i = 1, 6 do
		suckers[i] = part(V(1.6, 1.6, 1.6), rgb(150, 90, 200), Enum.Material.Neon, 0, Enum.PartType.Ball)
	end
	arms[k] = { base = base, segs = segs, suckers = suckers, ph = k * 1.7 }
end

---------------------------------------------------------------------------
local wasUnder
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local t = os.clock()
	local under = cp.Y < SEA
	-- screen feedback
	local depth = SEA - cp.Y
	local goalT = under and math.clamp(0.72 - depth / 6000, 0.45, 0.72) or 1
	tint.BackgroundTransparency += (goalT - tint.BackgroundTransparency) * math.min(1, dt * 6)
	tint.BackgroundColor3 = depth > 1400 and rgb(10, 30, 90) or rgb(20, 80, 170)
	grad.Offset = Vector2.new(0, math.sin(t * 1.3) * 0.05)
	blur.Size += ((under and 4 or 0) - blur.Size) * math.min(1, dt * 6)
	if wasUnder ~= nil and under ~= wasUnder then
		splash(cp, under)
	end
	wasUnder = under

	local near = cp.Y < G.SEA_SHOW and cp.Y > G.DEPTH_LINE - 200
	if (root.Parent ~= nil) ~= near then
		root.Parent = near and workspace or nil
	end
	if not near then
		return
	end
	-- leviathans
	for _, L in ipairs(whales) do
		local close = math.abs(cp.Y - L.y) < 700
		local a = L.ph + t * L.sp
		local head = V(L.center.X + math.cos(a) * L.r, L.y + math.sin(t * 0.3 + L.ph) * 6, L.center.Z + math.sin(a) * L.r)
		local dir = V(-math.sin(a), 0, math.cos(a)) * math.sign(L.sp)
		local base = CF(head, head + dir)
		for _, pc in ipairs(L.pieces) do
			if close then
				local sway = math.sin(t * 0.8 - pc.seg * 0.45) * pc.seg * 0.9 * L.s
				local lift = math.sin(t * 0.6 - pc.seg * 0.4) * pc.seg * 0.5 * L.s
				-- the body follows the head along the circle (segments trail behind)
				pc.p.CFrame = base * CF(pc.off.X * L.s + sway, pc.off.Y * L.s + lift, pc.off.Z * L.s) * A(0, -pc.seg * 0.04 * math.sign(L.sp), 0)
			else
				pc.p.CFrame = CF(0, -9000, 0)
			end
		end
	end
	-- kraken arms
	local showArms = cp.Y > SEA - 300 and cp.Y < SEA + 600
	for _, arm in ipairs(arms) do
		local pos = arm.base + V(0, -6, 0)
		local yaw = math.sin(t * 0.3 + arm.ph) * 0.6
		for i, seg in ipairs(arm.segs) do
			if showArms then
				local u = i / #arm.segs
				local bend = math.sin(t * 0.9 + arm.ph - u * 2.4) * 0.5 * u + u * 0.9
				pos += V(math.sin(bend) * math.cos(yaw), math.cos(bend), math.sin(bend) * math.sin(yaw)) * 6.2
				seg.CFrame = CF(pos)
				local s = arm.suckers[math.floor(i / 2)]
				if s and i % 2 == 0 then
					s.CFrame = CF(pos + V(-math.cos(yaw), 0, -math.sin(yaw)) * (4.6 - i * 0.3))
				end
			else
				seg.CFrame = CF(0, -9000, 0)
			end
		end
		if not showArms then
			for _, s in ipairs(arm.suckers) do
				s.CFrame = CF(0, -9000, 0)
			end
		end
	end
end)
