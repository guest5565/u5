--!nonstrict
-- INKWING :: TORNADOS. Giant funnels of storm cloud loops wandering between the isles (same path for every
-- player: G.TornadoPos). Paper scraps and pencils orbit inside. Fly close and the wind grabs you:
-- it spins you around the funnel, pulls you in and flings you up (Flight reads the "Wind" attribute).
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
local LOOPS, SEG = isMobile and 10 or 14, isMobile and 12 or 16

local root = Instance.new("Folder")
root.Name = "Tornados"
root.Parent = workspace
local function part(size, color, tr, shape, mat)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Transparency = tr or 0
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CFrame = CF(0, -5000, 0)
	p.Parent = root
	return p
end

-- funnel radius at height fraction u (0 = bottom tip, 1 = top)
local function l0(pf)
	return pf.off * 0.5
end
local function radius(t, u)
	return t.r * (0.18 + 1.25 * u ^ 1.5)
end
local list = {}
for ti, def in ipairs(G.Tornados) do
	local T = { def = def, parts = {}, cfs = {}, puffs = {}, debris = {} }
	-- LOOPS: wobbly white ink rings stacked up the funnel (the sketch), each ring = SEG short strokes
	for l = 1, LOOPS do
		local u = (l - 1) / (LOOPS - 1)
		for k = 1, SEG do
			local p = part(V(0.9 + u * 0.8, 0.9 + u * 0.8, 1), Color3.new(0.97, 0.97, 1), 0.12 + rng:NextNumber(0, 0.15), nil, Enum.Material.SmoothPlastic)
			table.insert(T.parts, p)
			table.insert(T.puffs, { loop = true, u = u, k = k, tilt = rng:NextNumber(-0.35, 0.35), off = rng:NextNumber(0, 6.28) })
		end
	end
	-- soft grey smoke along the axis gives the funnel a body
	for l = 1, (isMobile and 3 or 5) do
		local u = (l - 0.5) / (isMobile and 3 or 5)
		local sp = part(V(1, 1, 1), Color3.new(1, 1, 1), 1)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = isMobile and 6 or 10
		e.Lifetime = NumberRange.new(2, 3)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 30)
		e.RotSpeed = NumberRange.new(-80, 80)
		e.Size = NumberSequence.new(def.r * (0.6 + u * 1.4), def.r * (0.9 + u * 1.8))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(150, 155, 175))
		e.Parent = sp
		table.insert(T.parts, sp)
		table.insert(T.puffs, { smoke = true, u = u })
	end
	-- debris: paper scraps + a pencil or two
	for k = 1, (isMobile and 10 or 18) do
		local pencil = k % 6 == 0
		local p = pencil and part(V(0.8, 0.8, 7), rgb(250, 205, 70)) or part(V(rng:NextNumber(1.5, 3), 0.1, rng:NextNumber(2, 3.5)), Color3.new(1, 1, 1))
		table.insert(T.parts, p)
		table.insert(T.puffs, { debris = true, u = rng:NextNumber(0.05, 0.9), off = rng:NextNumber(0, 6.28), sp = rng:NextNumber(1.2, 2.4), spin = V(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4)) })
	end
	-- spray at the base
	local base = part(V(1, 1, 1), Color3.new(1, 1, 1), 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Rate = isMobile and 8 or 16
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(10, 18)
	pe.SpreadAngle = Vector2.new(80, 80)
	pe.Size = NumberSequence.new(6, 16)
	pe.Transparency = NumberSequence.new(0.5, 1)
	pe.Color = ColorSequence.new(rgb(170, 175, 195))
	pe.Parent = base
	T.base = base
	T.nextStrike = os.clock() + rng:NextNumber(4, 12) + ti
	list[ti] = T
end

local strikeEv
task.spawn(function()
	local s = script.Parent:WaitForChild("Storm", 10)
	strikeEv = s and s:WaitForChild("StormStrike", 10)
end)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local now = workspace:GetServerTimeNow()
	local t = os.clock()
	local camPos = cam.CFrame.Position
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local wind, pull = Vector3.zero, 0
	-- the whole storm only exists while you are up there
	local inZone = camPos.Y > G.STORM_BASE - 300 and camPos.Y < G.STORM_TOP + 700
	if (root.Parent ~= nil) ~= inZone then
		root.Parent = inZone and workspace or nil
	end
	if not inZone then
		if me:GetAttribute("WindPull") ~= 0 then
			me:SetAttribute("Wind", Vector3.zero)
			me:SetAttribute("WindPull", 0)
		end
		return
	end
	for _, T in ipairs(list) do
		local def = T.def
		local c = G.TornadoPos(def, now)
		local H = def.height
		local far = (V(c.X, camPos.Y, c.Z) - camPos).Magnitude > 900
		if not far then
			for i, pf in ipairs(T.puffs) do
				local u = pf.u
				local y = c.Y + u * H
				-- the funnel snakes: the axis sways more toward the top
				local ax = c + V(math.sin(t * 0.6 + u * 3 + def.phase) * 10 * u, u * H, math.cos(t * 0.5 + u * 2.5 + def.phase) * 8 * u)
				local r = radius(def, u)
				if pf.loop then
					-- each ring slowly climbs, spins and wobbles; strokes sit on the ring outline
					local uu = (u + t * 0.05) % 1
					local rr = radius(def, uu)
					local ay = c + V(math.sin(t * 0.6 + uu * 3 + def.phase) * 10 * uu, uu * H, math.cos(t * 0.5 + uu * 2.5 + def.phase) * 8 * uu)
					local spin = t * (2.2 - 1.2 * uu) + pf.off * 0.2
					local a0 = spin + pf.k * (math.pi * 2 / SEG)
					local a1 = a0 + math.pi * 2 / SEG
					local tilt = CFrame.Angles(pf.tilt + math.sin(t * 0.7 + l0(pf)) * 0.12, 0, math.cos(t * 0.6 + pf.off) * 0.12)
					local p0 = ay + tilt * V(math.cos(a0) * rr, 0, math.sin(a0) * rr)
					local p1 = ay + tilt * V(math.cos(a1) * rr, 0, math.sin(a1) * rr)
					local len = (p1 - p0).Magnitude
					local sz = T.parts[i].Size
					if math.abs(sz.Z - len) > 0.5 then
						T.parts[i].Size = V(sz.X, sz.Y, len + sz.X)
					end
					T.cfs[i] = CFrame.lookAt((p0 + p1) / 2, p1)
				elseif pf.smoke then
					T.cfs[i] = CF(ax)
				elseif pf.debris then
					local a = t * pf.sp + pf.off
					local yy = c.Y + ((u + t * 0.03) % 0.9) * H
					local uu = (yy - c.Y) / H
					local rr = radius(def, uu) * 0.85
					T.cfs[i] = CF(ax.X - (ax.Y - yy) * 0 + math.cos(a) * rr, yy, ax.Z + math.sin(a) * rr) * A(pf.spin.X * t, pf.spin.Y * t, pf.spin.Z * t)
				end
			end
			workspace:BulkMoveTo(T.parts, T.cfs, Enum.BulkMoveMode.FireCFrameChanged)
			T.base.CFrame = CF(c)
			-- lightning crawls down the funnel now and then
			if t > T.nextStrike then
				T.nextStrike = t + rng:NextNumber(6, 14)
				if strikeEv then
					strikeEv:Fire(c + V(0, H + 10, 0), c + V(rng:NextNumber(-8, 8), H * 0.25, rng:NextNumber(-8, 8)))
				end
			end
		elseif T.cfs[1] ~= nil and T.parts[1].Position.Y > -4000 then
			for i in ipairs(T.parts) do
				T.cfs[i] = CF(0, -5000, 0)
			end
			workspace:BulkMoveTo(T.parts, T.cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- WIND on the local player
		if hrp then
			local p = hrp.Position
			local u = (p.Y - c.Y) / H
			if u > -0.05 and u < 1.05 then
				local uc = math.clamp(u, 0, 1)
				local ax = c + V(math.sin(t * 0.6 + uc * 3 + def.phase) * 10 * uc, 0, math.cos(t * 0.5 + uc * 2.5 + def.phase) * 8 * uc)
				local rel = V(p.X - ax.X, 0, p.Z - ax.Z)
				local d = rel.Magnitude
				local R = radius(def, uc) + 14
				local reach = R * 2.2
				if d < reach and d > 0.1 then
					local k = 1 - d / reach
					local inward = -rel.Unit
					local tangent = V(-inward.Z, 0, inward.X) * (def.speed > 0 and 1 or -1)
					local w = tangent * 70 * k + inward * 28 * k + V(0, 40 * k, 0)
					if d < R * 0.7 then
						w += V(0, 70, 0) -- the core flings you up
					end
					wind += w
					pull = math.max(pull, k)
				end
			end
		end
	end
	me:SetAttribute("Wind", wind)
	me:SetAttribute("WindPull", pull)
	if pull > 0.3 then -- the camera rattles in the wind
		local s = (pull - 0.3) * 0.35
		cam.CFrame *= CF(rng:NextNumber(-s, s), rng:NextNumber(-s, s), 0)
	end
end)
