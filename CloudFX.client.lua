--!nonstrict
-- INKWING :: SOFT CLOUDS (local). Every cloud in the map is an invisible anchor part with a "Cloud" scale
-- attribute; this fills it with slow, overlapping soft particles (no more ball clouds).
-- "Dark" = 1 for storm clouds. Works with zone streaming: clouds re-warm instantly when a zone streams in.
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local World = workspace:WaitForChild("World")
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local done = {}

local function setup(p)
	if not p:IsA("BasePart") then
		return
	end
	local sc = p:GetAttribute("Cloud")
	if typeof(sc) ~= "number" then
		return
	end
	local e = done[p]
	if not e then
		local dv = p:GetAttribute("Dark") or 0
		local pink = dv > 1.5
		local dark = dv > 0.5 and not pink
		e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Rate = sc * (isMobile and 1.6 or 2.6)
		e.Lifetime = NumberRange.new(10, 14)
		e.Speed = NumberRange.new(0, 0.6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-4, 4)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sc * 7), NumberSequenceKeypoint.new(1, sc * 10) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, dark and 0.25 or 0.35), NumberSequenceKeypoint.new(0.8, dark and 0.25 or 0.35), NumberSequenceKeypoint.new(1, 1) })
		e.Color = (pink and ColorSequence.new(Color3.fromRGB(255, 196, 214), Color3.fromRGB(255, 226, 190))) or ColorSequence.new(dark and Color3.fromRGB(80, 84, 104) or Color3.fromRGB(255, 255, 255))
		e.LightInfluence = dark and 0.4 or 0.7
		e.LightEmission = dark and 0 or 0.15
		e.Parent = p
		done[p] = e
	end
	task.defer(function()
		if e.Parent then
			e:Emit(math.floor(e.Rate * 10))
		end
	end)
end
for _, d in ipairs(World:GetDescendants()) do
	setup(d)
end
World.DescendantAdded:Connect(setup)
