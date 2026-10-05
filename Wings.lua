--!nonstrict
-- Inkbound v14.9 :: BEAM WINGS (no uploads: built-in fire texture + neon parts)
-- Phoenix-style wings: a glowing golden "bone" arching up and curling in, a fan of feathers along it,
-- each feather wrapped in a scrolling flame Beam, fire puffs along the outer edge, gentle flapping.
--
--   local w = Wings.new({ make = function(shape, color, mat, tr) -> Part end, theme = "Fire", feathers = 10, puffs = true, lod = 1 })
--   w:update(backCF, k, t, flapAmt)   -- backCF: between the shoulders, look = forward, +Z = behind; k = scale
--   w:setVisible(bool)
-- Parts come from opts.make so the caller owns cleanup (Auras holder / SketchLife life.extra).
local Wings = {}
Wings.__index = Wings

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

Wings.Palettes = {
	Fire = { Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 165, 40), Color3.fromRGB(230, 60, 20) },
	Phoenix = { Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 165, 40), Color3.fromRGB(230, 60, 20) },
	Frost = { Color3.fromRGB(235, 252, 255), Color3.fromRGB(120, 205, 255), Color3.fromRGB(60, 110, 230) },
	Void = { Color3.fromRGB(235, 190, 255), Color3.fromRGB(150, 60, 235), Color3.fromRGB(45, 10, 90) },
	Holy = { Color3.fromRGB(255, 255, 235), Color3.fromRGB(255, 222, 120), Color3.fromRGB(255, 165, 60) },
	Nature = { Color3.fromRGB(235, 255, 205), Color3.fromRGB(120, 225, 90), Color3.fromRGB(35, 140, 60) },
	Storm = { Color3.fromRGB(240, 250, 255), Color3.fromRGB(120, 205, 255), Color3.fromRGB(90, 90, 255) },
}

local BONE_N = 6
-- the wing arch (local space of one wing, side = +1 right / -1 left); u = 0 shoulder -> 1 crest
local function bonePoint(side, u)
	local x = side * (0.35 + 2.5 * math.sin(u * math.pi * 0.8))
	local y = -0.25 + 3.5 * u
	local z = 0.35 + 0.5 * u
	return Vector3.new(x, y, z)
end

function Wings.new(opts)
	local self = setmetatable({}, Wings)
	local pal = Wings.Palettes[opts.theme or "Fire"] or Wings.Palettes.Fire
	self.pal = pal
	self.lod = opts.lod or 1
	local make = opts.make
	local nF = math.max(5, math.floor((opts.feathers or 10) * self.lod + 0.5))
	self.rig = make(Enum.PartType.Block, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	self.rig.Size = Vector3.one * 0.2
	self.sides = {}
	for _, side in ipairs({ -1, 1 }) do
		local S = { side = side, bone = {}, feathers = {}, puffs = {} }
		for i = 1, BONE_N do
			S.bone[i] = make(Enum.PartType.Block, pal[1]:Lerp(pal[2], i / BONE_N * 0.5), Enum.Material.Neon, 0)
		end
		for i = 1, nF do
			local u = (i - 0.5) / nF
			local p = make(Enum.PartType.Block, pal[1]:Lerp(pal[2], 0.3 + u * 0.4), Enum.Material.Neon, 0.05)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = self.rig, self.rig
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Texture = FIRE
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureSpeed = 1.2 + (i % 3) * 0.3
			b.TextureLength = 1
			b.FaceCamera = true
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Segments = 1
			b.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, pal[1]), ColorSequenceKeypoint.new(0.45, pal[2]), ColorSequenceKeypoint.new(1, pal[3]) })
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = self.rig
			S.feathers[i] = { p = p, u = u, a0 = a0, a1 = a1, beam = b }
		end
		if opts.puffs ~= false then
			for i = 1, (self.lod < 0.7 and 2 or 4) do
				local a = make(Enum.PartType.Block, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
				local e = Instance.new("ParticleEmitter")
				e.Texture = FIRE
				e.Color = ColorSequence.new(pal[2], pal[3])
				e.LightEmission = 1
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0.2) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
				e.Lifetime = NumberRange.new(0.5, 0.9)
				e.Speed = NumberRange.new(0.4, 1.2)
				e.SpreadAngle = Vector2.new(60, 60)
				e.Acceleration = Vector3.new(0, 2.5, 0)
				e.Rotation = NumberRange.new(0, 360)
				e.RotSpeed = NumberRange.new(-60, 60)
				e.Rate = 9 * self.lod
				e.Parent = a
				S.puffs[i] = { p = a, e = e, u = i / ((self.lod < 0.7 and 2 or 4) + 0.5) }
			end
			local em = make(Enum.PartType.Block, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
			local s = Instance.new("ParticleEmitter")
			s.Texture = SPARK
			s.Color = ColorSequence.new(pal[1], pal[2])
			s.LightEmission = 1
			s.Size = NumberSequence.new(0.18, 0)
			s.Lifetime = NumberRange.new(0.6, 1.2)
			s.Speed = NumberRange.new(0.5, 1.5)
			s.Acceleration = Vector3.new(0, 1.5, 0)
			s.SpreadAngle = Vector2.new(180, 180)
			s.Rate = 10 * self.lod
			s.Parent = em
			S.embers = em
		end
		self.sides[#self.sides + 1] = S
	end
	return self
end

function Wings:setVisible(v)
	for _, S in ipairs(self.sides) do
		for _, b in ipairs(S.bone) do
			b.LocalTransparencyModifier = v and 0 or 1
		end
		for _, f in ipairs(S.feathers) do
			f.p.LocalTransparencyModifier = v and 0 or 1
			f.beam.Enabled = v
		end
		for _, p in ipairs(S.puffs) do
			p.e.Enabled = v
		end
	end
end

-- backCF: centre between the shoulders (look = forward). k = scale. flap = 0..1 amplitude
function Wings:update(backCF, k, t, flap)
	flap = flap or 1
	local beat = math.sin(t * 2.1) * 0.22 * flap
	for _, S in ipairs(self.sides) do
		local side = S.side
		-- the whole wing pivots at the shoulder (flap = swing backwards/forwards)
		local root = backCF * CFrame.new(side * 0.3 * k, 0, 0.3 * k) * CFrame.Angles(0, side * (beat - 0.15), side * beat * 0.25)
		local pts = {}
		for i = 0, BONE_N do
			local u = i / BONE_N
			local lp = bonePoint(side, u)
			-- the crest flutters a bit more than the base
			lp += Vector3.new(0, math.sin(t * 3 + u * 4) * 0.06 * u, math.sin(t * 2.1 + u * 2) * 0.15 * u * flap)
			pts[i] = root * (lp * k)
		end
		for i = 1, BONE_N do
			local a, b = pts[i - 1], pts[i]
			local len = (b - a).Magnitude
			local th = (0.2 - i * 0.02) * k
			S.bone[i].Size = Vector3.new(th, th, len + th)
			S.bone[i].CFrame = CFrame.lookAt((a + b) / 2, b)
		end
		local backLook = (backCF.LookVector)
		for _, f in ipairs(S.feathers) do
			local u = f.u
			local fi = u * BONE_N
			local i0 = math.clamp(math.floor(fi), 0, BONE_N - 1)
			local base = pts[i0]:Lerp(pts[i0 + 1], fi - i0)
			local tangent = (pts[i0 + 1] - pts[i0])
			tangent = tangent.Magnitude > 1e-3 and tangent.Unit or Vector3.yAxis
			-- feathers point OUTWARD from the arch (away from the body) and droop a little
			local outward = (base - (root.Position + root.UpVector * (1.4 * k))) * Vector3.new(1, 0.4, 1)
			outward = outward.Magnitude > 1e-3 and outward.Unit or root.RightVector * side
			local dir = (outward - tangent * 0.35 + Vector3.new(0, -0.25, 0)).Unit
			local L = (0.7 + 1.5 * math.sin(u * math.pi * 0.95) + math.sin(t * 4 + u * 9) * 0.05) * k
			local tip = base + dir * L
			f.p.Size = Vector3.new(0.12 * k, 0.05 * k, L)
			f.p.CFrame = CFrame.lookAt((base + tip) / 2, tip, backLook)
			f.a0.WorldPosition = base
			f.a1.WorldPosition = tip + dir * 0.25 * k
			f.beam.Width0 = 0.55 * k
			f.beam.Width1 = 0.15 * k
		end
		for _, pf in ipairs(S.puffs) do
			local fi = pf.u * BONE_N
			local i0 = math.clamp(math.floor(fi), 0, BONE_N - 1)
			local p = pts[i0]:Lerp(pts[i0 + 1], fi - i0)
			local out = (p - root.Position) * Vector3.new(1, 0, 1)
			out = out.Magnitude > 1e-3 and out.Unit or root.RightVector * side
			pf.p.CFrame = CFrame.new(p + out * 1.3 * k)
			pf.p.Size = Vector3.one * 0.8 * k
		end
		if S.embers then
			S.embers.CFrame = CFrame.new(pts[3])
			S.embers.Size = Vector3.new(2, 2.5, 0.5) * k
		end
	end
end

return Wings
