--!nonstrict
-- INKWING :: THE INK SEA (local; iterated from Doodle Pets' OceanFX)
--   above the surface : white comic wave strokes rolling over the ink, spray
--   under the surface : marine snow + bubbles around the camera, light shafts from the surface,
--                       schools of paper fish (glowing ones deeper), drifting ink jellyfish
-- Only runs while you are near / in the sea.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local me = Players.LocalPlayer
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local rng = Random.new(5)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SEA = G.SEA

local root = Instance.new("Folder")
root.Name = "InkSeaFX"
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
local function emitterBox(size, o)
	local b = part(size, Color3.new(), nil, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = o.rate * (isMobile and 0.5 or 1)
	e.Lifetime = NumberRange.new(o.life[1], o.life[2])
	e.Speed = NumberRange.new(o.speed[1], o.speed[2])
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Size = o.size
	e.Transparency = o.tr
	e.Acceleration = o.accel or Vector3.zero
	e.LightEmission = o.glow or 0
	e.Color = ColorSequence.new(o.color)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = b
	return b, e
end

-- marine snow + bubbles follow the camera underwater
local snowBox, snow = emitterBox(V(70, 40, 70), { rate = 60, life = { 5, 8 }, speed = { 0.3, 1 }, size = NumberSequence.new(0.18),
	tr = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(1, 1) }), accel = V(0, -0.4, 0), glow = 0.4, color = rgb(220, 235, 255) })
local bubBox, bubbles = emitterBox(V(40, 4, 40), { rate = 14, life = { 3, 5 }, speed = { 6, 10 }, spread = Vector2.new(10, 10), size = NumberSequence.new(0.35, 0.6),
	tr = NumberSequence.new(0.3, 1), accel = V(0, 3, 0), glow = 0.2, color = rgb(200, 230, 255) })
-- spray above the surface
local sprayBox, spray = emitterBox(V(90, 1, 90), { tex = "rbxasset://textures/particles/smoke_main.dds", rate = 10, life = { 1, 2 }, speed = { 4, 8 }, spread = Vector2.new(30, 30),
	size = NumberSequence.new(2, 5), tr = NumberSequence.new(0.6, 1), accel = V(4, -2, 0), color = rgb(230, 240, 255) })

-- light shafts from the surface
local shafts = {}
for i = 1, (isMobile and 10 or 18) do
	local p = part(V(rng:NextNumber(5, 12), 140, 0.4), rgb(200, 235, 255), Enum.Material.Neon, 0.92)
	shafts[i] = { p = p, dx = rng:NextNumber(-90, 90), dz = rng:NextNumber(-90, 90), a = rng:NextNumber(0, 6) }
end

-- comic wave strokes on the surface (white curved lines made of short segments)
local waves = {}
for i = 1, (isMobile and 14 or 26) do
	local segs = {}
	for k = 1, 5 do
		segs[k] = part(V(0.5, 0.35, 4), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 0.1)
	end
	waves[i] = { segs = segs, dx = rng:NextNumber(-120, 120), dz = rng:NextNumber(-120, 120), ph = rng:NextNumber(0, 6), w = rng:NextNumber(10, 22) }
end

-- fish schools spread through the sea (deterministic), glowing below -1600
local schools = {}
local FISH = { rgb(250, 248, 240), rgb(255, 230, 120), rgb(150, 210, 255), rgb(255, 160, 150) }
local GLOW = { rgb(90, 255, 220), rgb(160, 120, 255), rgb(255, 120, 220) }
local function school(c, r, n, glow)
	local s = { c = c, r = r, a = rng:NextNumber(0, 6), sp = rng:NextNumber(0.12, 0.25) * (rng:NextNumber() < 0.5 and -1 or 1), fish = {} }
	local col = glow and GLOW[rng:NextInteger(1, #GLOW)] or FISH[rng:NextInteger(1, #FISH)]
	for k = 1, n do
		local body = part(V(0.6, 1.1, 2.2), col, glow and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = body
		local tail = part(V(0.15, 1.1, 0.9), col:Lerp(Color3.new(1, 1, 1), 0.3), glow and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		local eye = part(V(0.25, 0.25, 0.25), rgb(20, 20, 30), nil, 0, Enum.PartType.Ball)
		s.fish[k] = { b = body, t = tail, e = eye, off = V(rng:NextNumber(-5, 5), rng:NextNumber(-3, 3), rng:NextNumber(-5, 5)), ph = rng:NextNumber(0, 6) }
	end
	schools[#schools + 1] = s
end
for _ = 1, 16 do
	local y = rng:NextNumber(G.DEPTH_LINE + 200, SEA - 30)
	school(V(rng:NextNumber(-300, 300), y, rng:NextNumber(-400, 250)), rng:NextNumber(12, 28), isMobile and 7 or 11, y < -1600)
end
-- ink jellyfish: dome + trailing tendrils, pulsing upward
local jellies = {}
for i = 1, 10 do
	local col = ({ rgb(120, 90, 255), rgb(80, 200, 255), rgb(255, 120, 220) })[i % 3 + 1]
	local dome = part(V(6, 4, 6), col, Enum.Material.Neon, 0.35)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = dome
	local tend = {}
	for k = 1, 5 do
		tend[k] = part(V(0.25, 7, 0.25), col, Enum.Material.Neon, 0.45)
	end
	jellies[i] = { dome = dome, tend = tend, base = V(rng:NextNumber(-260, 260), rng:NextNumber(-2500, -1200), rng:NextNumber(-350, 200)), ph = rng:NextNumber(0, 6) }
end

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local near = cp.Y < G.SEA_SHOW and cp.Y > G.DEPTH_LINE - 200
	if (root.Parent ~= nil) ~= near then
		root.Parent = near and workspace or nil
	end
	if not near then
		return
	end
	local t = os.clock()
	local under = cp.Y < SEA
	local depth = SEA - cp.Y
	snow.Enabled, bubbles.Enabled = under, under
	spray.Enabled = not under and cp.Y < SEA + 200
	snowBox.CFrame = CF(cp)
	bubBox.CFrame = CF(cp - V(0, 25, 0))
	sprayBox.CFrame = CF(cp.X, SEA + 1, cp.Z)
	snow.Color = ColorSequence.new(depth > 800 and rgb(140, 190, 255) or rgb(230, 245, 255))
	-- shafts: strongest just under the surface, fade out with depth
	local shaftVis = under and math.clamp(1 - depth / 500, 0, 1) or 0
	for _, s in ipairs(shafts) do
		if shaftVis > 0 then
			s.p.Transparency = 1 - (0.08 + math.sin(t * 0.6 + s.a) * 0.03) * shaftVis
			s.p.CFrame = CF(cp.X + s.dx + math.sin(t * 0.2 + s.a) * 3, SEA - 70, cp.Z + s.dz) * A(0, s.a + t * 0.02, 0.22)
		else
			s.p.Transparency = 1
		end
	end
	-- waves roll across the surface around you (visible from above and from below)
	local showWaves = math.abs(cp.Y - SEA) < 400
	for _, w in ipairs(waves) do
		local drift = (t * 4 + w.ph * 20) % 240 - 120
		local cx, cz = cp.X + w.dx + drift, cp.Z + w.dz
		cx = math.floor(cx / 4) * 4 -- snap a bit so they do not swim with the camera
		for k, seg in ipairs(w.segs) do
			if showWaves then
				local u = (k - 3) / 2
				local x = cx + u * w.w * 0.5
				local z = cz + (u * u) * w.w * 0.18 -- a little curved crest
				local lift = math.sin(t * 1.5 + w.ph + k * 0.4) * 0.3
				seg.CFrame = CF(x, SEA + 0.95 + lift, z) * A(0, math.atan2(u * w.w * 0.36, w.w * 0.5) + math.pi / 2, 0)
				seg.Size = V(0.5, 0.35, w.w * 0.27)
			else
				seg.CFrame = CF(0, -9000, 0)
			end
		end
	end
	if not under then
		return
	end
	for _, s in ipairs(schools) do
		if (s.c - cp).Magnitude < 220 then
			s.a += s.sp * dt
			local center = s.c + V(math.cos(s.a) * s.r, math.sin(s.a * 2) * 1.5, math.sin(s.a) * s.r)
			local dir = V(-math.sin(s.a), 0, math.cos(s.a)) * math.sign(s.sp)
			for _, f in ipairs(s.fish) do
				local pos = center + f.off + V(0, math.sin(t * 1.5 + f.ph) * 0.5, 0)
				local cf = CF(pos, pos + dir) * A(0, math.sin(t * 8 + f.ph) * 0.2, 0)
				f.b.CFrame = cf
				f.t.CFrame = cf * CF(0, 0, 1.4) * A(0, math.sin(t * 10 + f.ph) * 0.5, 0)
				f.e.CFrame = cf * CF(0.3, 0.2, -0.7)
			end
		end
	end
	for _, j in ipairs(jellies) do
		if (j.base - cp).Magnitude < 300 then
			local pulse = math.sin(t * 1.6 + j.ph)
			local pos = j.base + V(math.sin(t * 0.2 + j.ph) * 6, (t * 1.2 + j.ph * 10) % 60 - 30 + pulse, 0)
			j.dome.CFrame = CF(pos)
			j.dome.Size = V(6 + pulse * 0.8, 4 - pulse * 0.5, 6 + pulse * 0.8)
			for k, tp in ipairs(j.tend) do
				local a = k / #j.tend * math.pi * 2
				tp.CFrame = CF(pos + V(math.cos(a) * 1.8, -5, math.sin(a) * 1.8)) * A(math.sin(t * 2 + k) * 0.2, 0, math.cos(t * 1.7 + k) * 0.2)
			end
		end
	end
end)
