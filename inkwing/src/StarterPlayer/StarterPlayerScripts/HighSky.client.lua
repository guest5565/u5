--!nonstrict
-- INKWING :: THE COSMOS + HEAVEN atmosphere (local)
--   Cosmos: twinkling star dust around you, shooting stars streaking past, slow drifting paper comets
--   Heaven: golden light shafts falling through the clouds, drifting white feathers, soft sparkle
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game"))
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local rng = Random.new(21)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local root = Instance.new("Folder")
root.Name = "HighSkyFX"
local function part(size, color, mat, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material, p.Transparency = size, color, mat or Enum.Material.Neon, tr or 0
	p.CFrame = CF(0, -9000, 0)
	p.Parent = root
	return p
end
local function emitter(box, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or SPARK
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = o.rate * (isMobile and 0.5 or 1)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = o.size
	e.Transparency = o.tr
	e.Acceleration = o.accel or Vector3.zero
	e.LightEmission = o.glow or 0.6
	e.Color = ColorSequence.new(o.color)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Enabled = false
	e.Parent = box
	return e
end
local box = part(V(140, 80, 140), Color3.new(), nil, 1)
local dust = emitter(box, { rate = 50, life = { 3, 6 }, speed = { 0, 0.5 }, size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }),
	tr = NumberSequence.new(0.1), color = rgb(255, 245, 210), glow = 1 })
local feathers = emitter(box, { tex = "rbxasset://textures/particles/explosion01_implosion_main.dds", rate = 12, life = { 6, 9 }, speed = { 0.5, 1.5 }, accel = V(0.6, -1.4, 0),
	size = NumberSequence.new(0.7), tr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(1, 1) }), color = rgb(255, 255, 250), glow = 0.3 })
local goldDust = emitter(box, { rate = 30, life = { 3, 5 }, speed = { 0.2, 1 }, accel = V(0, 0.8, 0), size = NumberSequence.new(0.35, 0), tr = NumberSequence.new(0.2, 1), color = rgb(255, 215, 110), glow = 1 })

local embers = emitter(box, { rate = 60, life = { 3, 6 }, speed = { 2, 6 }, accel = V(0, 5, 0), size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), tr = NumberSequence.new(0, 1), color = rgb(255, 140, 50), glow = 1 })
local ash = emitter(box, { tex = "rbxasset://textures/particles/smoke_main.dds", rate = 14, life = { 6, 9 }, speed = { 0.5, 1.5 }, accel = V(1, -0.6, 0), size = NumberSequence.new(0.4), tr = NumberSequence.new(0.3, 1), color = rgb(60, 50, 50), glow = 0 })
-- heaven light shafts
local shafts = {}
for i = 1, (isMobile and 6 or 10) do
	shafts[i] = { p = part(V(rng:NextNumber(40, 70), 420, rng:NextNumber(40, 70)), rgb(255, 236, 200), Enum.Material.Neon, 1), dx = rng:NextNumber(-220, 220), dz = rng:NextNumber(-220, 220), a = rng:NextNumber(0, 6) }
end
-- shooting stars
local function shootingStar(cp)
	local from = cp + V(rng:NextNumber(-300, 300), rng:NextNumber(60, 220), rng:NextNumber(-300, 300))
	local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, -0.15), rng:NextNumber(-1, 1)).Unit
	local p = part(V(1.2, 1.2, 40), rgb(255, 250, 220), Enum.Material.Neon, 0)
	p.CFrame = CF(from, from + dir)
	local t = rng:NextNumber(0.6, 1.1)
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CF(from + dir * 420, from + dir * 421), Transparency = 1, Size = V(0.4, 0.4, 70) }):Play()
	task.delay(t + 0.1, function()
		p:Destroy()
	end)
end
local nextStar = 0

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local cosmos = cp.Y > G.COSMOS_BASE - 600 and cp.Y < G.COSMOS_TOP + 500
	local heaven = cp.Y > G.HEAVEN_BASE - 500
	local hell = cp.Y < G.HELL_TOP + 200 and cp.Y > G.HELL_BOTTOM - 300
	embers.Enabled, ash.Enabled = hell, hell
	local on = cosmos or heaven or hell
	if (root.Parent ~= nil) ~= on then
		root.Parent = on and workspace or nil
	end
	dust.Enabled = cosmos
	feathers.Enabled, goldDust.Enabled = heaven, heaven
	if not on then
		return
	end
	local t = os.clock()
	box.CFrame = CF(cp)
	if cosmos and t > nextStar then
		nextStar = t + rng:NextNumber(0.6, 2.2)
		shootingStar(cp)
	end
	for _, s in ipairs(shafts) do
		if heaven then
			s.p.Transparency = 0.95 + math.sin(t * 0.5 + s.a) * 0.02
			s.p.CFrame = CF(cp.X + s.dx, cp.Y + 60, cp.Z + s.dz) * A(0.25, s.a, 0.15)
		else
			s.p.Transparency = 1
		end
	end
end)
