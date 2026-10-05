--!nonstrict
-- INKWING :: FOG SHELL (local). Atmosphere alone can't hide the sky, so in the foggy zones a wall of soft
-- particles surrounds the camera (emitted on the SURFACE of a box, locked to it so it never falls behind
-- even at full boost). Thickness / colour / distance blend by height:
--   windy climb: white, closing in as you rise | storm: dark grey wall | cosmos: purple-blue nebula
--   hell: ash | abyss: black | unknown: violet
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game"))
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local rgb = Color3.fromRGB
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local box = Instance.new("Part")
box.Name = "FogShell"
box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
box.Transparency = 1
box.Size = Vector3.new(200, 120, 200)
local e = Instance.new("ParticleEmitter")
e.Texture = SMOKE
e.Shape = Enum.ParticleEmitterShape.Box
e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
e.LockedToPart = true
e.Lifetime = NumberRange.new(4, 6)
e.Speed = NumberRange.new(0, 0)
e.Rotation = NumberRange.new(0, 360)
e.RotSpeed = NumberRange.new(-8, 8)
e.LightInfluence = 0.6
e.Rate = 0
e.Parent = box

-- band: { lo, hi, color1, color2, alpha (0..1 thickness), radius, size }
local function band(y)
	if y > G.STORM_GATE + 40 and y < G.STORM_BASE then
		local k = math.clamp((y - G.STORM_GATE) / (G.STORM_BASE - G.STORM_GATE), 0, 1)
		return rgb(250, 250, 255), rgb(205, 208, 222):Lerp(rgb(140, 145, 165), k), 0.35 + 0.55 * k, 140 - 60 * k, 55
	elseif y >= G.STORM_BASE and y < G.STORM_TOP + 150 then
		return rgb(90, 96, 118), rgb(50, 54, 72), 1, 75, 60
	elseif y > G.COSMOS_BASE - 400 and y < G.COSMOS_TOP + 300 then
		return rgb(120, 70, 220), rgb(60, 120, 230), 0.55, 150, 80
	elseif y < -4902 and y > G.HELL_BOTTOM - 320 then
		return rgb(255, 90, 20), rgb(90, 10, 0), 1, 40, 45 -- v0.9c inside the lava
	elseif y < G.HELL_TOP + 150 and y > G.HELL_BOTTOM - 300 then
		return rgb(110, 60, 50), rgb(70, 40, 36), 0.45, 150, 70
	elseif y < G.ABYSS_TOP + 100 and y > G.ABYSS_BOTTOM - 300 then
		return rgb(6, 6, 10), rgb(0, 0, 0), 0.9, 90, 60
	elseif y < G.UNKNOWN_TOP + 200 then
		return rgb(0, 0, 0), rgb(0, 0, 0), 1, 45, 60 -- v0.9: the Unknown is pure darkness
	end
	return nil
end

local cur = 0
local lastR
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local c1, c2, alpha, R, size = band(cp.Y)
	local goal = alpha or 0
	cur += (goal - cur) * math.min(1, dt * 1.5)
	if cur < 0.02 and not alpha then
		if box.Parent then
			box.Parent = nil
		end
		return
	end
	if not box.Parent then
		box.Parent = workspace
	end
	box.CFrame = CFrame.new(cp)
	if c1 then
		if not lastR or math.abs(R - lastR) > 4 then
			lastR = R
			box.Size = Vector3.new(R * 2, R * 1.1, R * 2)
		end
		e.Color = ColorSequence.new(c1, c2)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.8), NumberSequenceKeypoint.new(1, size * 1.2) })
	end
	local a = 1 - 0.75 * math.clamp(cur, 0, 1)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, a), NumberSequenceKeypoint.new(0.7, a), NumberSequenceKeypoint.new(1, 1) })
	e.Rate = cur * (isMobile and 70 or 140)
end)
