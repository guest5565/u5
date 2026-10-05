--!nonstrict
-- INKWING :: THE UNKNOWN (local). Colossal cosmic beings drift in the dark around you - each one bigger
-- than any island: a spiral core, a crown of slow tentacles, glowing eyes that turn to follow you,
-- violet veins. They never attack. They just watch. Plus violet motes and a deep drone.
local RunService = game:GetService("RunService")
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game"))
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local rng = Random.new(66)

local root = Instance.new("Folder")
root.Name = "UnknownFX"
local function part(size, color, mat, tr, ball)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material, p.Transparency = size, color, mat or Enum.Material.SmoothPlastic, tr or 0
	if ball then
		p.Shape = Enum.PartType.Ball
	end
	p.CFrame = CF(0, -20000, 0)
	p.Parent = root
	return p
end

local DARK, DARK2, VEIN = rgb(10, 6, 20), rgb(26, 16, 44), rgb(150, 110, 255)
local beings = {}
local function being(center, S, ph)
	local B = { c = center, S = S, ph = ph, parts = {}, cfs = {}, items = {} }
	local function add(p, fn)
		table.insert(B.parts, p)
		table.insert(B.items, fn)
	end
	local core = part(V(1, 1, 1) * 60 * S, DARK, nil, 0, true)
	add(core, function(base)
		return base
	end)
	-- spiral veins on the core (facing you)
	for arm = 0, 2 do
		for j = 0, 9 do
			local a = arm * 2.09 + j * 0.42
			local r = (6 + j * 2.6) * S
			local p = part(V(4 * S, 1.4 * S, 2 * S), j % 2 == 0 and VEIN or rgb(110, 70, 220), Enum.Material.Neon, 0.1 + j * 0.06)
			add(p, function(base, t, look)
				return look * A(0, 0, t * 0.08) * CF(math.cos(a) * r, math.sin(a) * r, -29 * S) * A(0, 0, a)
			end)
		end
	end
	-- eyes that follow you
	for k = 1, 6 do
		local yaw, pitch = rng:NextNumber(-1.1, 1.1), rng:NextNumber(-0.7, 0.7)
		local d = rng:NextNumber(6, 12) * S
		local sclera = part(V(d, d, d), rgb(235, 225, 205), nil, 0, true)
		local iris = part(V(d, d, d) * 0.55, k % 2 == 0 and rgb(255, 60, 90) or rgb(190, 120, 255), Enum.Material.Neon, 0, true)
		local off = (A(pitch, yaw, 0) * CF(0, 0, -27 * S)).Position
		add(sclera, function(base, t, look)
			return look * CF(off)
		end)
		add(iris, function(base, t, look)
			return look * CF(off) * CF(0, 0, -d * 0.25)
		end)
	end
	-- tentacles
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local dir = V(math.cos(a), math.sin(a), 0.3).Unit
		for j = 1, 9 do
			local r = (14 - j * 1.2) * S
			local p = part(V(r, r, r), j % 2 == 0 and DARK2 or DARK, nil, 0, true)
			add(p, function(base, t)
				local w = t * 0.25 + ph + k
				return base * CF(dir * (24 + j * 11) * S + V(math.sin(w + j * 0.5) * j * 2.2 * S, math.cos(w * 0.8 + j * 0.4) * j * 2 * S, math.sin(w * 0.6 - j * 0.3) * j * 1.6 * S))
			end)
			if j % 3 == 0 then
				local g = part(V(r, r, r) * 0.3, VEIN, Enum.Material.Neon, 0, true)
				add(g, function(base, t)
					local w = t * 0.25 + ph + k
					return base * CF(dir * (24 + j * 11) * S + V(math.sin(w + j * 0.5) * j * 2.2 * S, math.cos(w * 0.8 + j * 0.4) * j * 2 * S + r * 0.4, math.sin(w * 0.6 - j * 0.3) * j * 1.6 * S))
				end)
			end
		end
	end
	for i = 1, #B.parts do
		B.cfs[i] = CF()
	end
	table.insert(beings, B)
end
being(V(-520, -6050, -700), 2.2, 0)
being(V(650, -6300, -200), 1.7, 2)
being(V(-100, -6450, 650), 2.6, 4)

-- motes
local motesBox = part(V(160, 90, 160), Color3.new(), nil, 1)
local motes = Instance.new("ParticleEmitter")
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Rate = 30
motes.Lifetime = NumberRange.new(4, 7)
motes.Speed = NumberRange.new(0.2, 1)
motes.SpreadAngle = Vector2.new(180, 180)
motes.LightEmission = 1
motes.Color = ColorSequence.new(rgb(190, 120, 255), rgb(120, 200, 255))
motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) })
motes.Shape = Enum.ParticleEmitterShape.Box
motes.Parent = motesBox
local drone = Instance.new("Sound")
drone.SoundId = "rbxassetid://9120018695" -- distant rumble (Pro Sound Effects), played slow = a deep drone
drone.Looped = true
drone.PlaybackSpeed = 0.45
drone.Volume = 0

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local on = G.InAbyss(cp.Y) -- v0.9: the colossal beings drift in the Abyss
	if (root.Parent ~= nil) ~= on then
		root.Parent = on and workspace or nil
		drone.Parent = on and cam or nil
		if on then
			drone:Play()
		end
	end
	drone.Volume += ((on and 0.5 or 0) - drone.Volume) * math.min(1, dt)
	if not on then
		return
	end
	local t = os.clock()
	motesBox.CFrame = CF(cp)
	for _, B in ipairs(beings) do
		local c = B.c + V(math.sin(t * 0.05 + B.ph) * 40, math.sin(t * 0.07 + B.ph) * 20, math.cos(t * 0.04 + B.ph) * 40)
		local base = CF(c) * A(0, t * 0.02 + B.ph, 0)
		local look = CF(c, c + (cp - c).Unit * 10) -- the face always turns toward you
		for i, fn in ipairs(B.items) do
			B.cfs[i] = fn(base, t, look)
		end
		workspace:BulkMoveTo(B.parts, B.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
