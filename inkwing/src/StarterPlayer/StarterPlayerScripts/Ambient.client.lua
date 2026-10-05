-- Ambient.client (v1.4): the islands come alive.
--   wind sway on leaves / pines / fronds / grass near you, butterflies over flowers, bird flocks circling the isles,
--   fireflies at night, leaves drifting off the giant ancient tree, chests you already opened stay open (per player)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
if (RS:FindFirstChild("Realm") and RS.Realm.Value or "Overworld") ~= "Overworld" then
	return
end
local Shared = RS:WaitForChild("Shared")
local InkFX = require(Shared:WaitForChild("InkFX"))
local Audio = require(Shared:WaitForChild("Audio"))
local Fx = RS:WaitForChild("Remotes"):WaitForChild("Fx")
local World = workspace:WaitForChild("World")

local function hq()
	return me:GetAttribute("HighQ") ~= false
end
local function camPos()
	return workspace.CurrentCamera.CFrame.Position
end

---------------------------------------------------------------------------
-- collect swaying parts + flowers + chests
---------------------------------------------------------------------------
local SWAY = { Leaves = 0.35, Needles = 0.22, PineTip = 0.3, Frond = 0.5, Tuft = 0.25, Bush = 0.12, RuinIvy = 0.08 }
local sway, flowers, chests, giantLeaves, flowerParts = {}, {}, {}, {}, {}
for _, d in ipairs(World:GetDescendants()) do
	if d:IsA("BasePart") then
		local amp = SWAY[d.Name]
		if amp then
			-- taller/bigger canopies move more; a phase per tree position so the forest ripples
			table.insert(sway, { p = d, cf = d.CFrame, amp = amp * math.clamp(d.Size.Y / 6, 0.6, 2.2), ph = (d.Position.X * 0.05 + d.Position.Z * 0.04) })
			if d.Name == "Leaves" and d.Size.X > 24 then
				table.insert(giantLeaves, d)
			end
		elseif d.Name == "Flower" then
			table.insert(flowers, d.Position)
			table.insert(flowerParts, d)
		elseif d.Name == "ChestBase" then
			chests[tostring(d:GetAttribute("ChestId"))] = d.Parent
		end
	end
end

-- the near set is rebuilt every second (only parts within reach of the camera get animated)
local near, rebuildT = {}, 0
local function rebuild()
	near = {}
	local cp = camPos()
	local R = hq() and 260 or 140
	local cap = hq() and 2200 or 700
	for _, s in ipairs(sway) do
		if (s.cf.Position - cp).Magnitude < R then
			table.insert(near, s)
			if #near >= cap then
				break
			end
		end
	end
end

---------------------------------------------------------------------------
-- falling leaves from the ancient tree
---------------------------------------------------------------------------
for i, lp in ipairs(giantLeaves) do
	if i % 2 == 1 then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(120, 190, 70), Color3.fromRGB(220, 200, 80))
		e.Size = NumberSequence.new(0.6)
		e.Lifetime = NumberRange.new(6, 10)
		e.Rate = 2
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(1.5, -2, 0.8)
		e.Drag = 0.6
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Rotation = NumberRange.new(0, 360)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.LightInfluence = 0.6
		e.Parent = lp
	end
end

---------------------------------------------------------------------------
-- creatures (client-only, pooled)
---------------------------------------------------------------------------
local fol = Instance.new("Folder")
fol.Name = "AmbientLife"
fol.Parent = workspace
local function mk(size, color, mat, shape, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Transparency = tr or 0
	p.Parent = fol
	return p
end

-- butterflies: two wing plates that flap, wandering above flower patches
local BUTTER_COLS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 130, 190), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 60) }
local butterflies = {}
for i = 1, 14 do
	local c = BUTTER_COLS[(i - 1) % #BUTTER_COLS + 1]
	table.insert(butterflies, { l = mk(Vector3.new(0.7, 0.05, 0.6), c), r = mk(Vector3.new(0.7, 0.05, 0.6), c), pos = Vector3.zero, goal = Vector3.zero, home = nil, ph = math.random() * 6 })
end
local function nearFlower(cp)
	local best = nil
	for _ = 1, 12 do
		local f = flowers[math.random(1, math.max(1, #flowers))]
		if f and (f - cp).Magnitude < 140 then
			best = f
			break
		end
	end
	return best
end

-- birds: flocks gliding in wide circles around the islands
local flocks = {}
local FLOCK_CENTERS = { Vector3.new(0, 110, 300), Vector3.new(-420, 130, 140), Vector3.new(420, 160, 600), Vector3.new(0, 170, -60) }
for fi, c in ipairs(FLOCK_CENTERS) do
	local f = { c = c, r = 120 + fi * 25, sp = 0.08 + fi * 0.01, birds = {} }
	for b = 1, 7 do
		local col = Color3.fromRGB(40, 40, 48)
		table.insert(f.birds, { body = mk(Vector3.new(0.6, 0.5, 1.6), col), l = mk(Vector3.new(2.2, 0.1, 0.9), col), r = mk(Vector3.new(2.2, 0.1, 0.9), col), off = Vector3.new((b % 3 - 1) * 5, (b % 2) * 2, -math.floor(b / 2) * 4), ph = b * 0.7 })
	end
	table.insert(flocks, f)
end

-- fireflies: soft glowing dots near the ground at night
local flies = {}
for i = 1, 30 do
	table.insert(flies, { p = mk(Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(230, 255, 120), Enum.Material.Neon, Enum.PartType.Ball, 1), base = Vector3.zero, ph = math.random() * 10 })
end
local function isNight()
	local t = Lighting.ClockTime
	return t > 18.3 or t < 5.7
end

---------------------------------------------------------------------------
-- chests: opened ones stay open for you
---------------------------------------------------------------------------
local function chestState()
	local open = {}
	for id in string.gmatch(me:GetAttribute("Chests") or "", "[^,]+") do
		open[id] = true
	end
	for id, m in pairs(chests) do
		local lid, glow, base = m:FindFirstChild("ChestLid"), m:FindFirstChild("ChestGlow"), m:FindFirstChild("ChestBase")
		if open[id] and lid and not lid:GetAttribute("Open") then
			lid:SetAttribute("Open", true)
			-- v1.8: every ChestLid* part swings open around the back hinge
			if base then
				local hinge = base.CFrame * CFrame.new(0, 1.2, 1.4)
				local parts = {}
				for _, c in ipairs(m:GetDescendants()) do
					if c:IsA("BasePart") and string.sub(c.Name, 1, 8) == "ChestLid" then
						table.insert(parts, { c, hinge:ToObjectSpace(c.CFrame) })
					end
				end
				task.spawn(function()
					local t0 = os.clock()
					while true do
						local a = math.min(1, (os.clock() - t0) / 0.6)
						local e = 1 - (1 - a) ^ 3
						local h = hinge * CFrame.Angles(1.9 * e, 0, 0)
						for _, pr in ipairs(parts) do
							pr[1].CFrame = h * pr[2]
						end
						if a >= 1 then break end
						task.wait()
					end
				end)
			end
			if glow then
				glow.Transparency = 1
				local l = glow:FindFirstChildOfClass("PointLight")
				if l then
					l.Enabled = false
				end
			end
			local pr = base and base:FindFirstChildOfClass("ProximityPrompt")
			if pr then
				pr.Enabled = false
			end
		end
	end
end
me:GetAttributeChangedSignal("Chests"):Connect(chestState)
task.delay(3, chestState) -- prompts are added by the server shortly after load

Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Slam" and typeof(info) == "table" and typeof(info.pos) == "Vector3" then
		-- v1.8 ground slam: shockwave rings, cracked crater, dust and flying debris
		local pos, R = info.pos, info.r or 18
		local stone = Color3.fromRGB(120, 112, 100)
		pcall(InkFX.ring, pos + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 240, 210), 2, R, 0.45, 1.4, true)
		pcall(InkFX.ring, pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(200, 190, 170), 1, R * 0.6, 0.7, 2.2, true)
		pcall(InkFX.puffs, pos, Color3.fromRGB(215, 205, 190), 14)
		pcall(InkFX.spikes, pos, stone, 10, R * 0.35, 0.8)
		pcall(InkFX.flash, pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 240, 210))
		local crater = Instance.new("Part")
		crater.Name = "SlamCrater"
		crater.Anchored, crater.CanCollide, crater.CanQuery, crater.CanTouch = true, false, false, false
		crater.Shape = Enum.PartType.Cylinder
		crater.Size = Vector3.new(0.12, R * 0.9, R * 0.9)
		crater.CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		crater.Color, crater.Material = Color3.fromRGB(40, 36, 34), Enum.Material.Slate
		crater.Transparency = 0.25
		crater.Parent = workspace
		for k = 1, 10 do
			local d = Instance.new("Part")
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = false, false, false, false
			local s = 0.6 + math.random() * 1.2
			d.Size = Vector3.new(s, s * 0.7, s)
			d.Color, d.Material = stone, Enum.Material.Slate
			local a = k / 10 * math.pi * 2
			d.CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 2, 1, math.sin(a) * 2))
			d.Parent = workspace
			d.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 30, 35 + math.random() * 25, math.sin(a) * 30)
			d.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
			game:GetService("Debris"):AddItem(d, 2.5)
		end
		task.delay(2, function()
			for i = 1, 20 do
				crater.Transparency = 0.25 + i / 20 * 0.75
				task.wait(0.05)
			end
			crater:Destroy()
		end)
		pcall(Audio.play, "boom", { volume = 1 })
		return
	end
	if kind == "ChestOpen" then
		local gold = info.tier >= 2 and Color3.fromRGB(200, 160, 255) or Color3.fromRGB(255, 215, 90)
		pcall(InkFX.explosion, info.pos + Vector3.new(0, 2, 0), gold, 8, true)
		pcall(InkFX.shards, info.pos + Vector3.new(0, 3, 0), gold, 14, 18)
		pcall(InkFX.word, info.pos + Vector3.new(0, 7, 0), info.tier >= 2 and "ANCIENT TREASURE!" or "TREASURE!", gold, 1.4)
		if info.player == me then
			pcall(Audio.play, "reveal_rare", { vol = 0.8 })
		end
	elseif kind == "AppleEat" then
		pcall(InkFX.flash, info.pos, Color3.fromRGB(255, 120, 100), 3, 0.2)
		pcall(InkFX.shards, info.pos, Color3.fromRGB(120, 255, 140), 8, 8)
		pcall(Audio.play, "ui_click", { vol = 0.5, pitch = 1.5 })
	end
end)

---------------------------------------------------------------------------
-- the loop
---------------------------------------------------------------------------
local frame = 0
RunService.RenderStepped:Connect(function(dt)
	frame += 1
	local t = os.clock()
	local cp = camPos()
	if t - rebuildT > 1 then
		rebuildT = t
		rebuild()
	end
	-- wind: a slow gust envelope over a fast flutter
	local gust = 0.6 + 0.4 * math.sin(t * 0.35)
	if hq() or frame % 2 == 0 then
		for _, s in ipairs(near) do
			local a = s.amp * gust
			local w = math.sin(t * 1.4 + s.ph) * a
			local w2 = math.cos(t * 1.1 + s.ph * 1.3) * a * 0.5
			s.p.CFrame = s.cf * CFrame.new(w, 0, w2) * CFrame.Angles(w2 * 0.02, 0, w * 0.02)
		end
	end
	-- butterflies
	for _, b in ipairs(butterflies) do
		if not b.home or (b.home - cp).Magnitude > 160 then
			b.home = nearFlower(cp)
			if b.home then
				b.pos = b.home + Vector3.new(math.random(-4, 4), 2, math.random(-4, 4))
				b.goal = b.pos
			end
		end
		if b.home then
			if (b.goal - b.pos).Magnitude < 0.5 then
				b.goal = b.home + Vector3.new(math.random(-8, 8), 1.5 + math.random() * 3, math.random(-8, 8))
			end
			local dir = b.goal - b.pos
			b.pos += dir.Unit * math.min(dir.Magnitude, dt * 4) + Vector3.new(0, math.sin(t * 6 + b.ph) * dt * 1.5, 0)
			local cf = CFrame.lookAt(b.pos, b.pos + Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0.001, 0, 0))
			local f = math.sin(t * 22 + b.ph) * 1.1
			b.l.CFrame = cf * CFrame.Angles(0, 0, f) * CFrame.new(-0.35, 0, 0)
			b.r.CFrame = cf * CFrame.Angles(0, 0, -f) * CFrame.new(0.35, 0, 0)
			b.l.Transparency, b.r.Transparency = 0, 0
		else
			b.l.Transparency, b.r.Transparency = 1, 1
		end
	end
	-- bird flocks
	for _, f in ipairs(flocks) do
		local vis = (f.c - cp).Magnitude < 900
		local a = t * f.sp
		local lead = f.c + Vector3.new(math.cos(a) * f.r, math.sin(a * 2.3) * 12, math.sin(a) * f.r)
		local fwd = Vector3.new(-math.sin(a), 0, math.cos(a))
		local base = CFrame.lookAt(lead, lead + fwd)
		for _, bd in ipairs(f.birds) do
			if vis then
				local cf = base * CFrame.new(bd.off) * CFrame.Angles(0, 0, math.sin(a * 3) * 0.25)
				local fl = math.sin(t * 9 + bd.ph) * 0.7
				bd.body.CFrame = cf
				bd.l.CFrame = cf * CFrame.new(-0.3, 0, 0) * CFrame.Angles(0, 0, fl) * CFrame.new(-1.1, 0, 0)
				bd.r.CFrame = cf * CFrame.new(0.3, 0, 0) * CFrame.Angles(0, 0, -fl) * CFrame.new(1.1, 0, 0)
				bd.body.Transparency, bd.l.Transparency, bd.r.Transparency = 0, 0, 0
			elseif bd.body.Transparency < 1 then
				bd.body.Transparency, bd.l.Transparency, bd.r.Transparency = 1, 1, 1
			end
		end
	end
	-- fireflies
	local night = isNight()
	for i, fl in ipairs(flies) do
		if night and (i <= (hq() and 30 or 12)) then
			if (fl.base - cp).Magnitude > 90 then
				local f = nearFlower(cp)
				fl.base = f and (f + Vector3.new(math.random(-14, 14), 1, math.random(-14, 14))) or Vector3.new(0, -1e4, 0)
			end
			fl.p.CFrame = CFrame.new(fl.base + Vector3.new(math.sin(t * 0.7 + fl.ph) * 3, 1.5 + math.sin(t * 1.3 + fl.ph) * 1.2, math.cos(t * 0.6 + fl.ph) * 3))
			fl.p.Transparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + fl.ph))
		elseif fl.p.Transparency < 1 then
			fl.p.Transparency = 1
		end
	end
end)


---------------------------------------------------------------------------
-- v1.5 SKY SHOWERS: rain around you, cooler light, glowing flowers, then a rainbow
---------------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local rainP = mk(Vector3.new(120, 1, 120), Color3.new(1, 1, 1), nil, nil, 1)
local rain = Instance.new("ParticleEmitter")
rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
rain.Color = ColorSequence.new(Color3.fromRGB(200, 225, 255))
rain.LightEmission = 0.3
rain.Size = NumberSequence.new(0.18)
rain.Squash = NumberSequence.new(-3)
rain.Transparency = NumberSequence.new(0.35)
rain.Lifetime = NumberRange.new(1.1, 1.4)
rain.Speed = NumberRange.new(70, 85)
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Orientation = Enum.ParticleOrientation.VelocityParallel
rain.Shape = Enum.ParticleEmitterShape.Box
rain.Rate = 0
rain.Parent = rainP
local rainS = Instance.new("Sound")
rainS.SoundId = "rbxassetid://9112853287"
rainS.Looped = true
rainS.Volume = 0
rainS.Parent = workspace.CurrentCamera
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ShowerCC"
cc.Parent = Lighting
local bow -- built on demand
local function buildRainbow()
	bow = Instance.new("Model")
	bow.Name = "Rainbow"
	local COLS = { { 255, 60, 60 }, { 255, 150, 50 }, { 255, 235, 80 }, { 90, 220, 90 }, { 80, 170, 255 }, { 90, 90, 230 }, { 170, 90, 230 } }
	local C = Vector3.new(0, -60, 1150)
	for i, c in ipairs(COLS) do
		local R = 620 - i * 14
		for k = 0, 35 do
			local a0, a1 = k / 36 * math.pi, (k + 1) / 36 * math.pi
			local p0 = C + Vector3.new(math.cos(a0) * R, math.sin(a0) * R, 0)
			local p1 = C + Vector3.new(math.cos(a1) * R, math.sin(a1) * R, 0)
			local seg = Instance.new("Part")
			seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.CastShadow = true, false, false, false, false
			seg.Material = Enum.Material.Neon
			seg.Color = Color3.fromRGB(c[1], c[2], c[3])
			seg.Size = Vector3.new(14, 1, (p1 - p0).Magnitude + 1)
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, math.pi / 2)
			seg.Transparency = 1
			seg.Parent = bow
		end
	end
	bow.Parent = fol
end
local showerK, bowK, glowOn = 0, 0, false
RunService.Heartbeat:Connect(function(dt)
	local cp = camPos()
	local inIsles = cp.Y > -60 and cp.Y < 700 and (Vector2.new(cp.X, cp.Z - 300)).Magnitude < 1500
	local want = (workspace:GetAttribute("IslandShower") == true and inIsles) and 1 or 0
	showerK += (want - showerK) * math.clamp(dt * 0.5, 0, 1)
	rainP.CFrame = CFrame.new(cp + Vector3.new(0, 45, 0))
	rain.Rate = showerK * (hq() and 900 or 350)
	rainS.Volume = showerK * 0.45
	if showerK > 0.01 and not rainS.IsPlaying then
		rainS:Play()
	elseif showerK <= 0.01 and rainS.IsPlaying then
		rainS:Stop()
	end
	cc.Brightness = -0.06 * showerK
	cc.Saturation = -0.15 * showerK
	cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 220, 255), showerK)
	-- flowers glow while it rains (and a little after)
	local g = showerK > 0.3
	if g ~= glowOn then
		glowOn = g
		for _, f in ipairs(flowerParts) do
			f.Material = g and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	-- rainbow after the shower
	local bw = ((workspace:GetAttribute("Rainbow") or 0) > workspace:GetServerTimeNow() and inIsles) and 1 or 0
	bowK += (bw - bowK) * math.clamp(dt * 0.4, 0, 1)
	if bowK > 0.01 then
		if not bow then
			buildRainbow()
		end
		local tr = 1 - bowK * 0.55
		if math.abs((bow:GetAttribute("Tr") or 1) - tr) > 0.01 then
			bow:SetAttribute("Tr", tr)
			for _, sgm in ipairs(bow:GetChildren()) do
				sgm.Transparency = tr
			end
		end
	elseif bow and (bow:GetAttribute("Tr") or 1) < 1 then
		bow:SetAttribute("Tr", 1)
		for _, sgm in ipairs(bow:GetChildren()) do
			sgm.Transparency = 1
		end
	end
end)

---------------------------------------------------------------------------
-- v1.8b FAIRIES around the World Tree: tiny glowing sprites with fluttering wings and a light trail
---------------------------------------------------------------------------
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	if not world then
		return
	end
	task.wait(4)
	local zones = {}
	for _, d in ipairs(world:GetDescendants()) do
		if d.Name == "FairyZone" and d:IsA("BasePart") then
			table.insert(zones, d)
		end
	end
	if #zones == 0 then
		return
	end
	local RS = game:GetService("RunService")
	local folder = Instance.new("Folder")
	folder.Name = "Fairies"
	local COLS = { Color3.fromRGB(255, 200, 240), Color3.fromRGB(190, 255, 220), Color3.fromRGB(255, 240, 170), Color3.fromRGB(190, 220, 255) }
	local function bp(sz, col, mat, tr)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size, p.Color, p.Material, p.Transparency = sz, col, mat, tr or 0
		p.Parent = folder
		return p
	end
	local fairies = {}
	for zi, z in ipairs(zones) do
		local R, N = z:GetAttribute("R") or 150, z:GetAttribute("N") or 6
		for i = 1, N do
			local col = COLS[(zi + i) % #COLS + 1]
			local body = bp(Vector3.new(1.1, 1.1, 1.1), col, Enum.Material.Neon)
			body.Shape = Enum.PartType.Ball
			local halo = bp(Vector3.new(3, 3, 3), col, Enum.Material.Neon, 0.8)
			halo.Shape = Enum.PartType.Ball
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = col, 14, 1.5
			l.Parent = body
			local wings = {}
			for w = 1, 4 do
				wings[w] = bp(Vector3.new(0.08, w <= 2 and 1.8 or 1.2, w <= 2 and 1.1 or 0.8), Color3.fromRGB(240, 250, 255), Enum.Material.Glass, 0.45)
			end
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, 0.35, 0), Vector3.new(0, -0.35, 0)
			a0.Parent, a1.Parent = body, body
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Color = ColorSequence.new(col)
			tr.Transparency = NumberSequence.new(0.2, 1)
			tr.Lifetime = 0.9
			tr.LightEmission = 1
			tr.FaceCamera = true
			tr.Parent = body
			table.insert(fairies, { z = z.Position, R = R * (0.4 + math.random() * 0.6), body = body, halo = halo, wings = wings,
				ph = math.random() * 100, sp = 0.15 + math.random() * 0.25, h = R * 0.35 * (math.random() - 0.5) })
		end
	end
	local center = zones[1].Position
	RS.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		local near = cam and (cam.CFrame.Position - center).Magnitude < 1600
		if not near then
			if folder.Parent then
				folder.Parent = nil
			end
			return
		end
		folder.Parent = workspace
		local t = os.clock()
		for _, f in ipairs(fairies) do
			local u = t * f.sp + f.ph
			local pos = f.z + Vector3.new(math.cos(u) * f.R + math.sin(u * 2.3) * 12, f.h + math.sin(u * 1.7) * 20 + math.sin(t * 3 + f.ph) * 1.5, math.sin(u) * f.R + math.cos(u * 1.9) * 12)
			local vel = Vector3.new(-math.sin(u), 0, math.cos(u))
			local cf = CFrame.lookAt(pos, pos + vel)
			f.body.CFrame = cf
			f.halo.CFrame = cf
			f.halo.Transparency = 0.75 + math.sin(t * 4 + f.ph) * 0.1
			local flap = math.sin(t * 40 + f.ph) * 0.9
			for w = 1, 4 do
				local sd = (w % 2 == 1) and 1 or -1
				local big = w <= 2
				f.wings[w].CFrame = cf * CFrame.new(0, big and 0.3 or -0.35, 0.3) * CFrame.Angles(0, sd * (0.9 + flap), big and 0.3 * sd or -0.4 * sd) * CFrame.new(sd * 0.0, 0, 0) * CFrame.new(0, 0, 0) * CFrame.new(0, big and 0.6 or -0.3, big and 0.55 or 0.4)
			end
		end
	end)
end)
