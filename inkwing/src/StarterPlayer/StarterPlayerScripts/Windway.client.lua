--!nonstrict
-- INKWING :: THE WINDY CLIMB (local) between the cloud deck (330) and the storm (2150).
-- The closer you get to the storm, the stronger it all gets:
--   wind streaks rushing past, cloud wisps drifting by, paper scraps blown sideways, tall cloud pillars,
--   the clouds above start to flicker with hidden lightning + distant rumble, rising wind sound.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local me = Players.LocalPlayer
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local rng = Random.new(11)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LOW, HIGH = G.STORM_GATE, G.STORM_BASE

local root = Instance.new("Folder")
root.Name = "WindwayFX"
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
local WIND = V(1, 0.12, 0.35).Unit

-- wind streaks (thin white lines) recycled around the camera
local STREAKS = isMobile and 26 or 46
local streaks, sParts, sCFs = {}, {}, {}
for i = 1, STREAKS do
	local p = part(V(0.12, 0.12, rng:NextNumber(8, 18)), Color3.new(1, 1, 1), Enum.Material.Neon, 1)
	sParts[i] = p
	sCFs[i] = p.CFrame
	streaks[i] = { pos = V(0, -9000, 0), sp = rng:NextNumber(90, 150) }
end
-- cloud wisps drifting past: one soft particle emitter upwind of the camera, blowing along the wind
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local wispBox = part(V(260, 140, 40), Color3.new(), nil, 1)
local wisp = Instance.new("ParticleEmitter")
wisp.Texture = SMOKE
wisp.Shape = Enum.ParticleEmitterShape.Box
wisp.EmissionDirection = Enum.NormalId.Front
wisp.SpreadAngle = Vector2.new(6, 6)
wisp.Lifetime = NumberRange.new(6, 9)
wisp.Rotation = NumberRange.new(0, 360)
wisp.RotSpeed = NumberRange.new(-6, 6)
wisp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 26) })
wisp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(0.75, 0.55), NumberSequenceKeypoint.new(1, 1) })
wisp.LightInfluence = 0.7
wisp.Parent = wispBox
-- paper scraps tumbling in the wind
local scraps = {}
for i = 1, (isMobile and 8 or 14) do
	scraps[i] = { p = part(V(rng:NextNumber(1, 2.4), 0.08, rng:NextNumber(1.4, 3)), rgb(250, 248, 238)), pos = V(0, -9000, 0), sp = rng:NextNumber(40, 70), spin = V(rng:NextNumber(-5, 5), rng:NextNumber(-5, 5), rng:NextNumber(-5, 5)) }
end
local pillarE = {}
-- tall cloud pillars (landmarks of the climb): soft particle columns, darker near the storm
for i = 1, 9 do
	local a = i / 9 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	local dist = rng:NextNumber(220, 420)
	local h = rng:NextNumber(900, 1500)
	local base = V(math.cos(a) * dist, LOW + rng:NextNumber(50, 300), -60 + math.sin(a) * dist)
	local col = part(V(70, h, 70), Color3.new(), nil, 1)
	col.CFrame = CF(base + V(0, h / 2, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = isMobile and 5 or 9
	e.Lifetime = NumberRange.new(14, 18)
	e.Speed = NumberRange.new(0, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-3, 3)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 60), NumberSequenceKeypoint.new(1, 85) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(Color3.fromRGB(245, 246, 252), Color3.fromRGB(170, 175, 195))
	e.LightInfluence = 0.8
	e.Parent = col
	table.insert(pillarE, e)
end
-- hidden lightning: flashes inside the clouds above
local glow = part(V(200, 200, 200), rgb(210, 220, 255), Enum.Material.Neon, 1, Enum.PartType.Ball)
local glowT, nextGlow = 0, os.clock() + 4
local function sound(id, vol, looped)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = vol
	s.Looped = looped or false
	s.Parent = workspace.CurrentCamera or workspace
	return s
end
local windS = sound(9113732197, 0, true) -- Cavernous Winds Empty Eerie Gusts (Pro Sound Effects)
windS:Play()
local RUMBLE = 9120018695

RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local inZone = cp.Y > LOW - 60 and cp.Y < HIGH + 150
	if (root.Parent ~= nil) ~= inZone then
		root.Parent = inZone and workspace or nil
		if inZone then
			task.defer(function()
				for _, e in ipairs(pillarE) do
					e:Emit(120)
				end
			end)
		end
	end
	windS.Volume += (((inZone and math.clamp((cp.Y - LOW) / (HIGH - LOW), 0, 1) * 0.55) or 0) - windS.Volume) * math.min(1, dt * 2)
	if not inZone then
		return
	end
	local t = os.clock()
	local k = math.clamp((cp.Y - LOW) / (HIGH - LOW), 0, 1) -- 0 at the deck, 1 at the storm
	-- streaks
	local nS = math.floor(STREAKS * (0.25 + 0.75 * k))
	for i, s in ipairs(streaks) do
		if i <= nS then
			local p = s.pos + WIND * s.sp * (0.6 + k) * dt
			local rel = p - cp
			if rel.Magnitude > 75 or rel:Dot(WIND) > 60 then
				p = cp - WIND * rng:NextNumber(40, 60) + V(rng:NextNumber(-50, 50), rng:NextNumber(-30, 30), rng:NextNumber(-50, 50))
			end
			s.pos = p
			sCFs[i] = CF(p, p + WIND)
			sParts[i].Transparency = 0.82 - 0.4 * k
		else
			sCFs[i] = CF(0, -9000, 0)
		end
	end
	workspace:BulkMoveTo(sParts, sCFs, Enum.BulkMoveMode.FireCFrameChanged)
	-- wisps: more, faster and greyer near the storm
	local shade = 1 - k * 0.45
	wispBox.CFrame = CF(cp - WIND * 110, cp - WIND * 110 + WIND)
	wisp.Rate = (isMobile and 2 or 4) + k * (isMobile and 6 or 12)
	wisp.Speed = NumberRange.new(25 * (0.6 + k), 45 * (0.6 + k))
	wisp.Color = ColorSequence.new(Color3.new(shade, shade, shade * 1.06))
	-- scraps
	for _, s in ipairs(scraps) do
		local p = s.pos + (WIND * s.sp * (0.5 + k) + V(0, math.sin(t * 3 + s.sp) * 6, 0)) * dt
		local rel = p - cp
		if rel.Magnitude > 90 or rel:Dot(WIND) > 70 then
			p = cp - WIND * rng:NextNumber(50, 70) + V(rng:NextNumber(-40, 40), rng:NextNumber(-20, 20), rng:NextNumber(-40, 40))
		end
		s.pos = p
		s.p.CFrame = CF(p) * A(s.spin.X * t, s.spin.Y * t, s.spin.Z * t)
	end
	-- hidden lightning in the clouds above, more often near the storm
	if k > 0.35 and t > nextGlow then
		nextGlow = t + rng:NextNumber(6, 14) * (1.6 - k)
		glowT = 1
		glow.CFrame = CF(cp + V(rng:NextNumber(-300, 300), math.min(HIGH - cp.Y, 500) + 100, rng:NextNumber(-300, 300)))
		local d = (glow.Position - cp).Magnitude
		task.delay(d / 700, function()
			local r = sound(RUMBLE, 0.25 + 0.3 * k)
			r.TimePosition = rng:NextNumber(0, 60)
			r:Play()
			task.delay(4, function()
				r:Destroy()
			end)
		end)
	end
	if glowT > 0 then
		glowT = math.max(0, glowT - dt * 4)
		glow.Transparency = 1 - glowT * 0.55 * (math.sin(t * 60) > -0.3 and 1 or 0.3)
	end
end)
