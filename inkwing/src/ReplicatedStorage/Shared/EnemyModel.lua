--!nonstrict
-- INKWING :: ENEMY MODELS (client). Everything here must read as "enemy" at a glance:
-- dark ink bodies, slanted angry brows over glowing red pupils, jagged teeth, spikes, drips, a red glow.
--   local e = EnemyModel.build(type, parent) -> { model, root, parts, offs, anims, size }
--   EnemyModel.pose(e, cf, t)  -- moves every piece in one BulkMoveTo (cheap)
local EnemyModel = {}

local INK = Color3.fromRGB(32, 28, 52)
local INK2 = Color3.fromRGB(48, 38, 78)
local RED = Color3.fromRGB(255, 40, 60)
local TOOTH = Color3.fromRGB(250, 246, 230)
local MOUTH = Color3.fromRGB(110, 10, 30)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local I = CFrame.identity

local function newE(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = parent
	return { model = m, root = root, parts = {}, offs = {}, anims = {} }
end
-- add a piece: off = CFrame relative to the root; anim(t) -> extra CFrame applied after off (optional)
local function add(e, shape, size, color, off, o)
	o = o or {}
	local p = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
		local s = math.min(size.X, size.Y, size.Z)
		size = Vector3.new(s, s, s)
	elseif shape == "Cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.Color = color
	p.Material = o.mat or Enum.Material.SmoothPlastic
	p.Transparency = o.tr or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, true, false, false
	p.Parent = e.model
	table.insert(e.parts, p)
	table.insert(e.offs, off)
	table.insert(e.anims, o.anim or false)
	return p
end
-- an angry eye: sclera + glowing pupil + slanted brow (side = -1 left / 1 right)
local function eye(e, pos, s, side, o)
	o = o or {}
	add(e, "Ball", Vector3.one * s, o.sclera or Color3.fromRGB(255, 236, 160), CFrame.new(pos), { anim = o.anim })
	local pupil = add(e, "Ball", Vector3.one * s * 0.5, o.pupil or RED, CFrame.new(pos + Vector3.new(-side * s * 0.06, -s * 0.08, -s * 0.33)), { mat = Enum.Material.Neon, anim = o.anim })
	-- the brow cuts down toward the nose: that's what makes it angry
	add(e, "Block", Vector3.new(s * 1.35, s * 0.32, s * 0.5), o.brow or INK, CFrame.new(pos + Vector3.new(side * s * 0.05, s * 0.42, -s * 0.22)) * CFrame.Angles(0, 0, side * 0.5), { anim = o.anim })
	return pupil
end
-- a row of jagged teeth along X (pointing down for top row, up for bottom row)
local function teeth(e, center, width, n, h, up, o)
	o = o or {}
	for i = 1, n do
		local x = -width / 2 + (i - 0.5) * width / n
		local cf = CFrame.new(center + Vector3.new(x, 0, 0)) * (up and CFrame.Angles(0, 0, 0) or CFrame.Angles(math.pi, 0, 0))
		add(e, "Wedge", Vector3.new(width / n * 0.8, h, h * 0.6), TOOTH, cf, { anim = o.anim })
	end
end
local function glow(e, color, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.4
	l.Parent = e.root
end
local function smoke(e, color, rate, size)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SMOKE
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 1.8) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 0
	pe.Parent = e.root
	return pe
end
local function sparks(e, color, rate)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARK
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(1, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = e.root
end

local B = {}

-- INK BLOB: a lumpy flying ink monster with a wide toothy grin, spikes, torn little wings and falling drips
function B.InkBlob(e)
	local bob = function(t)
		return CFrame.new(0, math.abs(math.sin(t * 3)) * 0.6, 0)
	end
	add(e, "Ball", Vector3.one * 5, INK, CFrame.new(0, 2.4, 0), { anim = bob })
	add(e, "Ball", Vector3.one * 3.4, INK2, CFrame.new(0.9, 4.1, 0.6), { anim = bob })
	add(e, "Ball", Vector3.one * 2.6, INK, CFrame.new(-1.6, 1.4, 1.2), { anim = bob })
	add(e, "Ball", Vector3.one * 0.8, Color3.fromRGB(150, 140, 200), CFrame.new(-1.1, 3.8, -1.6), { tr = 0.35, anim = bob }) -- gloss
	eye(e, Vector3.new(-0.95, 3.1, -2.05), 1.35, -1, { anim = bob })
	eye(e, Vector3.new(0.95, 3.1, -2.05), 1.35, 1, { anim = bob })
	add(e, "Block", Vector3.new(2.8, 1.1, 0.4), MOUTH, CFrame.new(0, 1.75, -2.25) * CFrame.Angles(0.2, 0, 0), { anim = bob })
	teeth(e, Vector3.new(0, 2.15, -2.42), 2.8, 6, 0.55, false, { anim = bob })
	teeth(e, Vector3.new(0, 1.3, -2.32), 2.4, 5, 0.45, true, { anim = bob })
	for k = 0, 3 do -- back spikes
		add(e, "Wedge", Vector3.new(0.4, 1.4 - k * 0.15, 1.2), INK2, CFrame.new(0, 4.6 - k * 0.5, 0.2 + k * 0.8) * CFrame.Angles(-0.5 - k * 0.25, 0, 0), { anim = bob })
	end
	-- little torn ink wings (blobs fly now) + dripping tail drops
	for _, s in ipairs({ -1, 1 }) do
		for k = 1, 3 do
			local len = 3.6 - k * 0.6
			add(e, "Wedge", Vector3.new(0.25, 1.5, len), INK2, I, {
				anim = function(t)
					local flap = math.sin(t * 11) * 0.7
					return CFrame.new(s * 2.2, 3.3 + math.abs(math.sin(t * 3)) * 0.6, 0.6) * CFrame.Angles(0, 0, s * (flap + 0.35)) * CFrame.new(s * (0.4 + k * 0.8), -0.2 - k * 0.2, 0.2) * CFrame.Angles(math.pi / 2, s * 0.35, s * math.pi / 2)
				end,
			})
		end
	end
	for k = 1, 3 do
		add(e, "Ball", Vector3.one * (1.1 - k * 0.25), INK, I, {
			anim = function(t)
				local f = (t * 0.8 + k / 3) % 1
				return CFrame.new((k - 2) * 0.9, 0.4 - f * 3, 0.2)
			end,
		})
	end
	glow(e, RED, 8)
	e.size = 5
end

-- SCRIBBLE BAT: jagged scribble wings, big ears, fangs, red eyes
function B.ScribbleBat(e)
	local body = Color3.fromRGB(46, 30, 70)
	local hover = function(t)
		return CFrame.new(0, math.sin(t * 5) * 0.5, 0)
	end
	add(e, "Ball", Vector3.one * 2.6, body, I, { anim = hover })
	add(e, "Ball", Vector3.one * 1.8, body, CFrame.new(0, -1.2, 0.6), { anim = hover })
	for _, s in ipairs({ -1, 1 }) do
		add(e, "Wedge", Vector3.new(0.3, 1.8, 1), body, CFrame.new(s * 0.75, 1.6, 0) * CFrame.Angles(0, 0, -s * 0.25), { anim = hover })
		eye(e, Vector3.new(s * 0.5, 0.25, -1.05), 0.8, s, { anim = hover })
		add(e, "Wedge", Vector3.new(0.25, 0.7, 0.3), TOOTH, CFrame.new(s * 0.35, -0.65, -1.15) * CFrame.Angles(math.pi, 0, 0), { anim = hover })
		-- wing: three jagged membrane blades, flapping about the shoulder
		for k = 1, 3 do
			local len = 3.4 - k * 0.5
			add(e, "Wedge", Vector3.new(0.2, 1.6, len), Color3.fromRGB(34, 20, 56),
				I, {
					anim = function(t)
						local flap = math.sin(t * 16) * 0.8
						return CFrame.new(s * 1.2, 0.3 + math.sin(t * 5) * 0.5, 0) * CFrame.Angles(0, 0, s * (flap + 0.2)) * CFrame.new(s * (0.6 + k * 0.85), -0.3 - k * 0.15, 0.3) * CFrame.Angles(math.pi / 2, s * 0.4, s * math.pi / 2)
					end,
				})
		end
		add(e, "Block", Vector3.new(3.6, 0.22, 0.22), Color3.fromRGB(150, 40, 80), I, {
			mat = Enum.Material.Neon,
			anim = function(t)
				return CFrame.new(s * 1.2, 0.3 + math.sin(t * 5) * 0.5, 0) * CFrame.Angles(0, 0, s * (math.sin(t * 16) * 0.8 + 0.2)) * CFrame.new(s * 1.8, 0, 0)
			end,
		})
	end
	glow(e, RED, 7)
	e.size = 3
end

-- PAPER WASP: striped paper abdomen, glowing compound eyes, mandibles, a long black stinger
function B.PaperWasp(e)
	local YEL = Color3.fromRGB(232, 188, 70)
	local fly = function(t)
		return CFrame.new(0, math.sin(t * 4) * 0.4, 0)
	end
	add(e, "Ball", Vector3.one * 3, YEL, CFrame.new(0, -0.3, 2.2), { anim = fly })
	for k = -1, 1 do
		add(e, "Cyl", Vector3.new(0.5, 3.05 - math.abs(k) * 0.5, 3.05 - math.abs(k) * 0.5), INK, CFrame.new(0, -0.3, 2.2 + k * 0.8) * CFrame.Angles(0, math.pi / 2, 0), { anim = fly })
	end
	add(e, "Wedge", Vector3.new(0.6, 0.6, 2.2), INK, CFrame.new(0, -0.6, 4.3) * CFrame.Angles(0, math.pi, 0), { anim = fly })
	add(e, "Ball", Vector3.one * 1.9, Color3.fromRGB(70, 55, 40), CFrame.new(0, 0, 0.3), { anim = fly })
	add(e, "Ball", Vector3.one * 1.7, YEL, CFrame.new(0, 0.2, -1.2), { anim = fly })
	for _, s in ipairs({ -1, 1 }) do
		add(e, "Ball", Vector3.one * 0.95, RED, CFrame.new(s * 0.62, 0.45, -1.55), { mat = Enum.Material.Neon, anim = fly })
		add(e, "Block", Vector3.new(1, 0.25, 0.4), INK, CFrame.new(s * 0.55, 1.0, -1.6) * CFrame.Angles(0, 0, s * 0.55), { anim = fly })
		add(e, "Wedge", Vector3.new(0.25, 0.4, 0.9), INK, CFrame.new(s * 0.35, -0.45, -2.05) * CFrame.Angles(0, -s * 0.5, 0), { anim = fly })
		add(e, "Block", Vector3.new(0.12, 0.12, 1.6), INK, CFrame.new(s * 0.5, 1.4, -1.6) * CFrame.Angles(0.6, s * 0.3, 0), { anim = fly }) -- antenna
		add(e, "Block", Vector3.new(3.4, 0.08, 1.3), Color3.fromRGB(235, 240, 255), I, {
			tr = 0.45,
			anim = function(t)
				return CFrame.new(s * 0.6, 0.9 + math.sin(t * 4) * 0.4, 0.4) * CFrame.Angles(0, 0, s * math.sin(t * 40) * 0.5) * CFrame.new(s * 1.7, 0, 0)
			end,
		})
		for k = -1, 1 do
			add(e, "Block", Vector3.new(0.12, 1.4, 0.12), INK, CFrame.new(s * 0.7, -1.0, 0.3 + k * 0.5) * CFrame.Angles(0, 0, s * 0.5), { anim = fly })
		end
	end
	glow(e, Color3.fromRGB(255, 120, 40), 7)
	e.size = 4
end

-- INK SHADE: a shadow serpent from the depths - horned head, open jaw, glowing eyes, spined body
function B.InkShade(e)
	local C = Color3.fromRGB(22, 20, 38)
	local swim = function(i)
		return function(t)
			return CFrame.new(math.sin(t * 4 - i * 0.7) * i * 0.28, math.cos(t * 3 - i * 0.6) * i * 0.12, 0)
		end
	end
	local head = swim(0)
	add(e, "Ball", Vector3.one * 3.2, C, I, { anim = head })
	add(e, "Wedge", Vector3.new(2.6, 0.8, 2.6), C, CFrame.new(0, -1.5, -1.0) * CFrame.Angles(0.35, math.pi, 0), { anim = head }) -- lower jaw
	add(e, "Block", Vector3.new(2.2, 0.6, 1.4), MOUTH, CFrame.new(0, -0.95, -1.3), { mat = Enum.Material.Neon, anim = head })
	teeth(e, Vector3.new(0, -0.75, -1.85), 2.2, 6, 0.5, false, { anim = head })
	for _, s in ipairs({ -1, 1 }) do
		eye(e, Vector3.new(s * 0.75, 0.45, -1.3), 0.9, s, { anim = head, sclera = Color3.fromRGB(120, 255, 240), pupil = RED })
		add(e, "Wedge", Vector3.new(0.5, 2.4, 1), Color3.fromRGB(70, 60, 100), CFrame.new(s * 1.0, 1.9, 0.6) * CFrame.Angles(-0.6, 0, -s * 0.35), { anim = head })
	end
	for i = 1, 8 do
		local r = 2.8 - i * 0.22
		add(e, "Ball", Vector3.one * r, i % 2 == 0 and C or Color3.fromRGB(32, 28, 52), CFrame.new(0, 0, 1.6 + i * 1.9), { anim = swim(i) })
		add(e, "Wedge", Vector3.new(0.3, r * 0.6, r * 0.5), Color3.fromRGB(110, 40, 140), CFrame.new(0, r * 0.55, 1.6 + i * 1.9), { mat = Enum.Material.Neon, anim = swim(i) })
	end
	smoke(e, Color3.fromRGB(30, 20, 50), 8, 2)
	glow(e, Color3.fromRGB(120, 255, 240), 10)
	e.size = 4
end

-- THE BLOT KING: a giant ink blob with a torn paper crown, five glowing eyes, a huge toothy maw, tentacles
function B.BlotKing(e)
	local breathe = function(t)
		return CFrame.new(0, math.sin(t * 1.6) * 0.8, 0)
	end
	add(e, "Ball", Vector3.one * 18, INK, I, { anim = breathe })
	add(e, "Ball", Vector3.one * 10, INK2, CFrame.new(-6, 5, 3), { anim = breathe })
	add(e, "Ball", Vector3.one * 9, INK2, CFrame.new(6.5, 4, 2), { anim = breathe })
	add(e, "Ball", Vector3.one * 2.5, Color3.fromRGB(150, 140, 200), CFrame.new(-4, 6, -6.5), { tr = 0.35, anim = breathe })
	-- crown
	for k = 0, 6 do
		local a = (k / 7) * math.pi * 2
		add(e, "Wedge", Vector3.new(1.4, 4 + (k % 2) * 1.6, 2.2), Color3.fromRGB(255, 200, 60), CFrame.new(math.cos(a) * 4, 9.6, math.sin(a) * 4) * CFrame.Angles(0, -a + math.pi / 2, 0), { mat = Enum.Material.Neon, anim = breathe })
	end
	add(e, "Cyl", Vector3.new(1.2, 9.5, 9.5), Color3.fromRGB(230, 170, 40), CFrame.new(0, 8.2, 0) * CFrame.Angles(0, 0, math.pi / 2), { anim = breathe })
	-- eyes: one huge, four small
	eye(e, Vector3.new(0, 3.2, -7.6), 4.2, 1, { anim = breathe })
	for _, p in ipairs({ { -4.5, 4.6, -6.2 }, { 4.5, 4.6, -6.2 }, { -6.6, 1.4, -5.4 }, { 6.6, 1.4, -5.4 } }) do
		eye(e, Vector3.new(p[1], p[2], p[3]), 1.9, p[1] < 0 and -1 or 1, { anim = breathe })
	end
	-- maw
	add(e, "Block", Vector3.new(11, 3.6, 1.5), MOUTH, CFrame.new(0, -2.6, -7.9) * CFrame.Angles(0.15, 0, 0), { mat = Enum.Material.Neon, anim = breathe })
	teeth(e, Vector3.new(0, -1.1, -8.5), 11, 9, 1.6, false, { anim = breathe })
	teeth(e, Vector3.new(0, -4.2, -8.2), 10, 8, 1.3, true, { anim = breathe })
	-- tentacles
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.3
		for j = 1, 5 do
			local r = 3 - j * 0.4
			add(e, "Ball", Vector3.one * r, j % 2 == 0 and INK2 or INK, CFrame.new(math.cos(a) * 6, -7 - j * 2.2, math.sin(a) * 6), {
				anim = function(t)
					return CFrame.new(math.sin(t * 2 + k + j * 0.5) * j * 0.5, math.sin(t * 1.6) * 0.8, math.cos(t * 1.7 + k) * j * 0.4)
				end,
			})
		end
	end
	smoke(e, Color3.fromRGB(40, 20, 60), 18, 6)
	sparks(e, Color3.fromRGB(255, 60, 90), 10)
	glow(e, RED, 40)
	e.size = 20
end

-- helpers for the v0.3 monsters
local function hinge(pivot, f)
	-- rotate a piece around a pivot point (relative to the root)
	return function(t)
		return CFrame.new(pivot) * f(t) * CFrame.new(-pivot)
	end
end
local function ring(e, center, radius, n, col, thick, anim)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		add(e, "Block", Vector3.new(thick, thick, radius * 2 * math.pi / n * 1.05), col, CFrame.new(center) * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0), { mat = Enum.Material.Neon, anim = anim })
	end
end
local function serpent(e, n, r0, r1, step, col1, col2, finCol, amp, freq)
	local swim = function(i)
		return function(t)
			return CFrame.new(math.sin(t * freq - i * 0.55) * i * amp, math.cos(t * freq * 0.7 - i * 0.5) * i * amp * 0.4, 0)
		end
	end
	for i = 1, n do
		local r = r0 + (r1 - r0) * (i / n)
		add(e, "Ball", Vector3.one * r, i % 2 == 0 and col1 or col2, CFrame.new(0, 0, r0 * 0.4 + i * step), { anim = swim(i) })
		if finCol and i % 2 == 1 then
			add(e, "Wedge", Vector3.new(r * 0.12, r * 0.55, r * 0.6), finCol, CFrame.new(0, r * 0.6, r0 * 0.4 + i * step), { mat = Enum.Material.Neon, anim = swim(i) })
		end
	end
	return swim(0)
end

-- INK EEL: a long ink eel with a fanged snapping head and glowing cyan fins
function B.InkEel(e)
	local C, C2 = Color3.fromRGB(24, 30, 56), Color3.fromRGB(38, 48, 90)
	local head = serpent(e, 9, 2.2, 0.8, 1.5, C, C2, Color3.fromRGB(60, 230, 255), 0.35, 6)
	add(e, "Ball", Vector3.one * 2.8, C, I, { anim = head })
	add(e, "Block", Vector3.new(1.8, 0.5, 1.6), MOUTH, CFrame.new(0, -0.6, -1.3), { mat = Enum.Material.Neon, anim = head })
	add(e, "Wedge", Vector3.new(2, 0.6, 2), C, CFrame.new(0, -1.2, -1.1) * CFrame.Angles(0.3, math.pi, 0), {
		anim = function(t)
			return head(t) * CFrame.new(0, -0.6, -0.4) * CFrame.Angles(math.max(0, math.sin(t * 5)) * 0.4, 0, 0) * CFrame.new(0, 0.6, 0.4)
		end,
	})
	teeth(e, Vector3.new(0, -0.4, -1.7), 1.8, 5, 0.45, false, { anim = head })
	for _, sd in ipairs({ -1, 1 }) do
		eye(e, Vector3.new(sd * 0.7, 0.45, -1.05), 0.8, sd, { anim = head, sclera = Color3.fromRGB(150, 255, 245) })
	end
	glow(e, Color3.fromRGB(60, 230, 255), 12)
	e.size = 4
end

-- THE INKVERN: a gigantic sea serpent. Horned skull-like head, huge jaws full of teeth, 2 burning eyes,
-- a body of 18 rolling coils with glowing fins. It circles its lair.
function B.Inkvern(e)
	local C, C2, FIN = Color3.fromRGB(16, 24, 50), Color3.fromRGB(28, 44, 86), Color3.fromRGB(70, 220, 255)
	local head = serpent(e, 18, 11, 3, 6.5, C, C2, FIN, 0.6, 1.6)
	add(e, "Ball", Vector3.one * 14, C, I, { anim = head })
	add(e, "Block", Vector3.new(10, 9, 12), C2, CFrame.new(0, 1, -7), { anim = head }) -- snout
	add(e, "Block", Vector3.new(9, 2.4, 1.2), MOUTH, CFrame.new(0, -2.8, -13.1), { mat = Enum.Material.Neon, anim = head })
	teeth(e, Vector3.new(0, -2, -13.4), 9, 8, 2.2, false, { anim = head })
	local jaw = function(t)
		return head(t) * CFrame.new(0, -3, -1) * CFrame.Angles(0.25 + math.max(0, math.sin(t * 1.3)) * 0.35, 0, 0) * CFrame.new(0, 3, 1)
	end
	add(e, "Block", Vector3.new(9, 2.4, 12), C, CFrame.new(0, -5, -7), { anim = jaw })
	teeth(e, Vector3.new(0, -3.6, -12.4), 8, 7, 2, true, { anim = jaw })
	for _, sd in ipairs({ -1, 1 }) do
		eye(e, Vector3.new(sd * 4.2, 4, -10.5), 3.4, sd, { anim = head, sclera = Color3.fromRGB(160, 255, 245) })
		add(e, "Wedge", Vector3.new(1.6, 9, 3), Color3.fromRGB(200, 210, 230), CFrame.new(sd * 4.5, 9, -2) * CFrame.Angles(-0.7, 0, -sd * 0.4), { anim = head }) -- horns
		add(e, "Wedge", Vector3.new(0.6, 6, 7), FIN, CFrame.new(sd * 7.4, 0, 0) * CFrame.Angles(0, 0, sd * 1.2), { mat = Enum.Material.Neon, anim = head }) -- gill frills
	end
	smoke(e, Color3.fromRGB(20, 30, 60), 14, 7)
	glow(e, FIN, 50)
	e.size = 30
end



-- THE COMET EATER: a hungry dark moon. A maw that splits the planet, three eyes, a ring of orbiting rocks
function B.CometEater(e)
	local C, C2, ROCK, FIRE = Color3.fromRGB(46, 32, 80), Color3.fromRGB(70, 50, 110), Color3.fromRGB(120, 105, 150), Color3.fromRGB(255, 120, 60)
	local spin = function(t)
		return CFrame.new(0, math.sin(t * 1.2) * 1.2, 0)
	end
	add(e, "Ball", Vector3.one * 24, C, I, { anim = spin })
	for k = 1, 6 do -- craters
		local a, b = k * 1.3, k * 0.9
		local dx, dy, dz = math.cos(a) * math.cos(b), math.sin(b) * 0.6, math.sin(a) * math.cos(b)
		local m = math.sqrt(dx * dx + dy * dy + dz * dz)
		dx, dy, dz = dx / m, dy / m, dz / m
		if dz > -0.3 then
			add(e, "Cyl", Vector3.new(0.6, 4 + k % 3, 4 + k % 3), C2, CFrame.new(dx * 11.8, dy * 11.8, dz * 11.8) * CFrame.Angles(0, math.atan2(-dz, dx), math.asin(dy)), { anim = spin })
		end
	end
	add(e, "Block", Vector3.new(18, 5, 2), MOUTH, CFrame.new(0, -3, -11), { mat = Enum.Material.Neon, anim = spin })
	teeth(e, Vector3.new(0, -0.8, -11.4), 18, 11, 2.6, false, { anim = spin })
	teeth(e, Vector3.new(0, -5.3, -11.2), 16, 10, 2.2, true, { anim = spin })
	eye(e, Vector3.new(0, 6, -9.6), 5, 1, { anim = spin, sclera = Color3.fromRGB(255, 220, 140) })
	eye(e, Vector3.new(-6.6, 3.6, -8.6), 2.6, -1, { anim = spin, sclera = Color3.fromRGB(255, 220, 140) })
	eye(e, Vector3.new(6.6, 3.6, -8.6), 2.6, 1, { anim = spin, sclera = Color3.fromRGB(255, 220, 140) })
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local sz = 2 + (k % 3)
		add(e, "Block", Vector3.new(sz, sz * 0.8, sz), ROCK, CFrame.new(math.cos(a) * 20, (k % 2) * 2 - 1, math.sin(a) * 20) * CFrame.Angles(k, k * 2, 0), {
			anim = function(t)
				return CFrame.Angles(0.35, t * 0.5, 0)
			end,
		})
	end
	add(e, "Cyl", Vector3.new(0.4, 46, 46), FIRE, CFrame.Angles(0.35, 0, math.pi / 2), { mat = Enum.Material.Neon, tr = 0.75 })
	sparks(e, FIRE, 16)
	smoke(e, Color3.fromRGB(40, 20, 70), 10, 8)
	glow(e, FIRE, 50)
	e.size = 30
end



-- THE HALO WARDEN: a giant corrupted angel. Cracked ivory mask with burning eyes, a huge gold halo,
-- six fanned wings dripping ink, floating gold blades
function B.HaloWarden(e)
	local IVORY, GOLD, INKC = Color3.fromRGB(245, 238, 220), Color3.fromRGB(255, 205, 80), Color3.fromRGB(28, 22, 44)
	local float = function(t)
		return CFrame.new(0, math.sin(t * 1.1) * 1.5, 0)
	end
	add(e, "Block", Vector3.new(14, 16, 7), IVORY, I, { anim = float })
	add(e, "Wedge", Vector3.new(14, 6, 7), IVORY, CFrame.new(0, -11, 0) * CFrame.Angles(0, 0, math.pi), { anim = float })
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Block", Vector3.new(4.4, 1.6, 0.6), RED, CFrame.new(sd * 3.4, 2.4, -3.7) * CFrame.Angles(0, 0, sd * 0.25), { mat = Enum.Material.Neon, anim = float })
		add(e, "Block", Vector3.new(5.4, 1.4, 0.8), INKC, CFrame.new(sd * 3.2, 4.6, -3.7) * CFrame.Angles(0, 0, -sd * 0.4), { anim = float })
		for k = 1, 3 do
			local piv = Vector3.new(sd * 6, 4 - k * 2.5, 3)
			add(e, "Wedge", Vector3.new(0.8, 9 - k, 18 - k * 2), k == 2 and Color3.fromRGB(250, 246, 232) or IVORY, CFrame.new(sd * 13, 6 - k * 4.5, 6) * CFrame.Angles(0.3 * k, 0, -sd * (0.4 + k * 0.25)), {
				anim = hinge(piv, function(t)
					return float(t) * CFrame.Angles(0, sd * math.sin(t * 1.4 + k) * 0.15, 0)
				end),
			})
			add(e, "Block", Vector3.new(0.6, 6, 0.6), INKC, CFrame.new(sd * (10 + k * 3), 1 - k * 4.5, 8), { anim = float }) -- ink drips
		end
	end
	add(e, "Block", Vector3.new(10, 3, 0.6), MOUTH, CFrame.new(0, -4, -3.7), { mat = Enum.Material.Neon, anim = float })
	teeth(e, Vector3.new(0, -2.7, -4.1), 10, 8, 1.8, false, { anim = float })
	add(e, "Block", Vector3.new(0.4, 10, 0.8), INKC, CFrame.new(-2, 0, -3.7) * CFrame.Angles(0, 0, 0.2), { anim = float }) -- crack
	ring(e, Vector3.new(0, 12, 2), 10, 20, GOLD, 1.1, function(t)
		return float(t) * CFrame.new(0, 12, 2) * CFrame.Angles(0, t * 0.4, 0) * CFrame.new(0, -12, -2)
	end)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		add(e, "Wedge", Vector3.new(0.6, 7, 2), GOLD, CFrame.new(math.cos(a) * 18, 0, math.sin(a) * 18), {
			mat = Enum.Material.Neon,
			anim = function(t)
				return CFrame.Angles(0, t * 0.7, 0)
			end,
		})
	end
	sparks(e, GOLD, 18)
	smoke(e, INKC, 8, 6)
	glow(e, GOLD, 60)
	e.size = 30
end

-- ===== COSMIC HORROR helpers =====
-- an eye that looks along cf's -Z: sclera, glowing iris, black slit pupil
local function orbEye(e, cf, s, iris, anim)
	add(e, "Ball", Vector3.one * s, Color3.fromRGB(240, 232, 210), cf, { anim = anim })
	add(e, "Ball", Vector3.one * s * 0.55, iris or RED, cf * CFrame.new(0, 0, -s * 0.24), { mat = Enum.Material.Neon, anim = anim })
	add(e, "Block", Vector3.new(s * 0.1, s * 0.4, s * 0.1), Color3.fromRGB(5, 0, 10), cf * CFrame.new(0, 0, -s * 0.5), { anim = anim })
end
-- a point on a sphere of radius r looking outward
local function surf(r, yaw, pitch)
	local d = Vector3.new(math.cos(pitch) * math.sin(yaw), math.sin(pitch), -math.cos(pitch) * math.cos(yaw))
	return CFrame.lookAt(d * r, d * (r + 1)) * CFrame.Angles(0, math.pi, 0)
end
-- a writhing tentacle: chain of balls from base along dir
local function tentacle(e, base, dir, n, r0, step, col, col2, speed, ph, glowCol)
	for j = 1, n do
		local r = r0 * (1 - (j - 1) / n * 0.75)
		add(e, "Ball", Vector3.one * r, j % 2 == 0 and col2 or col, CFrame.new(base + dir * (j * step)), {
			anim = function(t)
				return CFrame.new(math.sin(t * speed + ph + j * 0.5) * j * step * 0.09, math.cos(t * speed * 0.8 + ph + j * 0.4) * j * step * 0.08, math.sin(t * speed * 0.6 + ph - j * 0.3) * j * step * 0.06)
			end,
		})
		if glowCol and j % 3 == 0 then
			add(e, "Ball", Vector3.one * r * 0.35, glowCol, CFrame.new(base + dir * (j * step) + Vector3.new(0, r * 0.4, 0)), {
				mat = Enum.Material.Neon,
				anim = function(t)
					return CFrame.new(math.sin(t * speed + ph + j * 0.5) * j * step * 0.09, math.cos(t * speed * 0.8 + ph + j * 0.4) * j * step * 0.08, math.sin(t * speed * 0.6 + ph - j * 0.3) * j * step * 0.06)
				end,
			})
		end
	end
end

-- STAR SPAWN (Cosmos): a drifting mass of dark star-flesh covered in eyes, a fanged maw, 8 writhing tentacles
function B.StarWisp(e)
	local C, C2, GLOW = Color3.fromRGB(30, 18, 60), Color3.fromRGB(56, 30, 96), Color3.fromRGB(150, 110, 255)
	local pulse = function(t)
		return CFrame.new(0, math.sin(t * 1.4) * 0.8, 0)
	end
	add(e, "Ball", Vector3.one * 10, C, I, { anim = pulse })
	add(e, "Ball", Vector3.one * 6, C2, CFrame.new(3, 3, 2), { anim = pulse })
	add(e, "Ball", Vector3.one * 5, C2, CFrame.new(-3.5, 2, 2.5), { anim = pulse })
	for k, d in ipairs({ { 0, 0.25, 3.2 }, { -0.7, 0.55, 1.6 }, { 0.75, 0.6, 1.8 }, { -0.4, -0.1, 1.3 }, { 0.5, -0.05, 1.2 }, { 1.2, 0.2, 1.4 }, { -1.15, 0.15, 1.5 } }) do
		orbEye(e, surf(4.9, d[1], d[2]), d[3], k == 1 and Color3.fromRGB(255, 200, 60) or RED, pulse)
	end
	add(e, "Block", Vector3.new(5, 1.6, 0.6), MOUTH, CFrame.new(0, -2.6, -4.3), { mat = Enum.Material.Neon, anim = pulse })
	teeth(e, Vector3.new(0, -1.9, -4.6), 5, 7, 1, false, { anim = pulse })
	teeth(e, Vector3.new(0, -3.3, -4.5), 4.6, 6, 0.9, true, { anim = pulse })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dir = Vector3.new(math.cos(a) * 0.8, -0.55, math.sin(a) * 0.8 + 0.3)
		tentacle(e, dir * 4, dir, 7, 2, 1.7, C, C2, 2.2, k, GLOW)
	end
	sparks(e, GLOW, 16)
	smoke(e, Color3.fromRGB(70, 40, 140), 10, 5)
	glow(e, GLOW, 30)
	e.size = 12
end

-- VOID GAZER (Cosmos): one enormous eye, its lids lined with fangs, tentacles trailing behind
function B.CometHound(e)
	local C = Color3.fromRGB(24, 14, 44)
	local look = function(t)
		return CFrame.Angles(math.sin(t * 0.9) * 0.15, math.sin(t * 0.7) * 0.2, 0)
	end
	add(e, "Ball", Vector3.one * 10, C, CFrame.new(0, 0, 1.2), { anim = look })
	add(e, "Ball", Vector3.one * 8.2, Color3.fromRGB(240, 230, 205), CFrame.new(0, 0, -0.6), { anim = look })
	add(e, "Ball", Vector3.one * 4.6, Color3.fromRGB(255, 70, 50), CFrame.new(0, 0, -2.6), { mat = Enum.Material.Neon, anim = look })
	add(e, "Block", Vector3.new(0.7, 3.6, 0.6), Color3.fromRGB(5, 0, 10), CFrame.new(0, 0, -4.7), { anim = look })
	for k = 0, 13 do -- fangs around the eye
		local a = k / 14 * math.pi * 2
		add(e, "Wedge", Vector3.new(0.6, 2.2, 1), TOOTH, CFrame.new(math.cos(a) * 4.6, math.sin(a) * 4.6, -2.8) * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.Angles(math.pi, 0, 0), { anim = look })
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local dir = Vector3.new(math.cos(a) * 0.5, math.sin(a) * 0.5, 1)
		tentacle(e, Vector3.new(0, 0, 4) + dir * 1.5, dir, 8, 1.8, 1.6, C, Color3.fromRGB(46, 26, 80), 2.6, k * 1.3, Color3.fromRGB(255, 80, 60))
	end
	smoke(e, Color3.fromRGB(40, 10, 50), 8, 4)
	glow(e, Color3.fromRGB(255, 70, 50), 24)
	e.size = 10
end

-- OPHAN (Heaven): wheels within wheels. Three spinning gold rings studded with eyes around a burning core
function B.HaloSentinel(e)
	local GOLD, CORE = Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 250, 220)
	add(e, "Ball", Vector3.one * 3.4, CORE, I, { mat = Enum.Material.Neon })
	orbEye(e, CFrame.new(0, 0, -1.2), 2.2, Color3.fromRGB(255, 160, 40))
	for k, ax in ipairs({ CFrame.identity, CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(0, 0, math.pi / 2) }) do
		local spin = function(t)
			return ax * CFrame.Angles(0, t * (0.6 + k * 0.25) * (k % 2 == 0 and -1 or 1), 0)
		end
		local R = 4 + k * 1.1
		for j = 0, 17 do
			local a = j / 18 * math.pi * 2
			add(e, "Block", Vector3.new(0.6, 0.6, R * 2 * math.pi / 18 * 1.05), GOLD, CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0), { mat = Enum.Material.Neon, anim = spin })
			if j % 3 == 0 then
				orbEye(e, CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), 1.1, RED, spin)
			end
		end
	end
	sparks(e, GOLD, 18)
	glow(e, GOLD, 30)
	e.size = 12
end

-- SERAPH (Heaven): six great wings wrapped around a burning eye; every feather has an eye
function B.GildedMoth(e)
	local IV, GOLD = Color3.fromRGB(250, 245, 230), Color3.fromRGB(255, 205, 80)
	add(e, "Ball", Vector3.one * 3.6, Color3.fromRGB(255, 240, 200), I, { mat = Enum.Material.Neon })
	orbEye(e, CFrame.new(0, 0, -1.3), 2.6, Color3.fromRGB(255, 120, 30))
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.5
		local piv = Vector3.new(math.cos(a) * 1.5, math.sin(a) * 1.5, 0.5)
		local flap = function(t)
			return CFrame.new(piv) * CFrame.fromAxisAngle(Vector3.new(-math.sin(a), math.cos(a), 0), math.sin(t * 3 + k) * 0.35) * CFrame.new(-piv)
		end
		local base = CFrame.new(math.cos(a) * 5.5, math.sin(a) * 5.5, 1) * CFrame.Angles(0, 0, a - math.pi / 2)
		add(e, "Block", Vector3.new(2.8, 8.5, 0.4), IV, base, { anim = flap })
		add(e, "Block", Vector3.new(3.1, 8.8, 0.3), GOLD, base * CFrame.new(0, 0, 0.2), { mat = Enum.Material.Neon, anim = flap })
		for j = 0, 2 do
			orbEye(e, base * CFrame.new(0, -2.6 + j * 2.6, -0.3), 0.9, RED, flap)
		end
	end
	add(e, "Cyl", Vector3.new(0.4, 16, 16), Color3.fromRGB(255, 160, 60), CFrame.new(0, 0, 1.6) * CFrame.Angles(0, math.pi / 2, 0), { mat = Enum.Material.Neon, tr = 0.75 })
	sparks(e, GOLD, 16)
	glow(e, Color3.fromRGB(255, 180, 80), 28)
	e.size = 11
end

-- CINDER IMP (Hell, WALKS): a cracked lava-rock imp with horns, a burning grin and claws
function B.CinderImp(e)
	local R, LAVA = Color3.fromRGB(40, 20, 20), Color3.fromRGB(255, 110, 30)
	local walk = function(t)
		return CFrame.new(0, math.abs(math.sin(t * 7)) * 0.3, 0)
	end
	add(e, "Block", Vector3.new(3, 3, 2.4), R, CFrame.new(0, 0.5, 0), { anim = walk })
	add(e, "Block", Vector3.new(2.6, 2.2, 2.2), R, CFrame.new(0, 2.8, -0.2), { anim = walk })
	add(e, "Block", Vector3.new(2, 0.5, 0.3), LAVA, CFrame.new(0, 2.2, -1.32), { mat = Enum.Material.Neon, anim = walk })
	teeth(e, Vector3.new(0, 2.45, -1.4), 2, 6, 0.4, false, { anim = walk })
	add(e, "Block", Vector3.new(0.15, 2.2, 0.2), LAVA, CFrame.new(0.6, 0.5, -1.22) * CFrame.Angles(0, 0, 0.4), { mat = Enum.Material.Neon, anim = walk })
	for _, sd in ipairs({ -1, 1 }) do
		eye(e, Vector3.new(sd * 0.6, 3.2, -1.2), 0.75, sd, { anim = walk, sclera = Color3.fromRGB(255, 220, 90) })
		add(e, "Wedge", Vector3.new(0.5, 1.8, 0.8), Color3.fromRGB(20, 10, 10), CFrame.new(sd * 1, 4.4, 0) * CFrame.Angles(0, 0, -sd * 0.4), { anim = walk })
		add(e, "Block", Vector3.new(0.9, 2.6, 0.9), R, CFrame.new(sd * 0.75, -2, 0), {
			anim = function(t)
				return CFrame.new(0, -0.8, 0) * CFrame.Angles(math.sin(t * 7 + (sd > 0 and math.pi or 0)) * 0.6, 0, 0) * CFrame.new(0, 0.8, 0)
			end,
		})
		add(e, "Block", Vector3.new(0.8, 2.6, 0.8), R, CFrame.new(sd * 2, 0.6, -0.3), {
			anim = function(t)
				return walk(t) * CFrame.new(sd * 2, 1.6, -0.3) * CFrame.Angles(-math.sin(t * 7 + (sd > 0 and math.pi or 0)) * 0.7, 0, 0) * CFrame.new(-sd * 2, -1.6, 0.3)
			end,
		})
		add(e, "Wedge", Vector3.new(0.3, 0.8, 0.6), TOOTH, CFrame.new(sd * 2, -0.9, -0.6) * CFrame.Angles(math.pi, 0, 0), { anim = walk })
	end
	sparks(e, LAVA, 10)
	glow(e, LAVA, 14)
	e.size = 5
end

-- ASH WRAITH (Hell): a tattered hood of ash with two ember eyes, clawed floating hands, a smoke tail
function B.AshWraith(e)
	local ASH, EMB = Color3.fromRGB(46, 40, 40), Color3.fromRGB(255, 120, 40)
	local drift = function(t)
		return CFrame.new(0, math.sin(t * 1.5) * 0.8, 0)
	end
	add(e, "Wedge", Vector3.new(6, 7, 5), ASH, CFrame.new(0, 1, 0.5), { anim = drift })
	add(e, "Block", Vector3.new(4.4, 3.4, 0.4), Color3.fromRGB(8, 4, 6), CFrame.new(0, 1.2, -1.5), { anim = drift })
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Ball", Vector3.one * 1, EMB, CFrame.new(sd * 0.9, 1.6, -1.8), { mat = Enum.Material.Neon, anim = drift })
		local hand = function(t)
			return drift(t) * CFrame.new(math.sin(t * 2 + sd) * 0.5, math.cos(t * 2.4 + sd) * 0.6, 0)
		end
		add(e, "Block", Vector3.new(1.2, 1.2, 1.2), ASH, CFrame.new(sd * 4.2, 0, -2), { anim = hand })
		for f = -1, 1 do
			add(e, "Wedge", Vector3.new(0.3, 1.6, 0.5), Color3.fromRGB(20, 16, 16), CFrame.new(sd * 4.2 + f * 0.4, -1.2, -2.2) * CFrame.Angles(math.pi, 0, 0), { anim = hand })
		end
	end
	for i = 1, 6 do
		local r = 4 - i * 0.55
		add(e, "Block", Vector3.new(r, 1.4, r), i % 2 == 0 and ASH or Color3.fromRGB(30, 26, 26), CFrame.new(0, -2.5 - i * 1.2, 1 + i * 0.4) * CFrame.Angles(0, i, 0), {
			anim = function(t)
				return drift(t) * CFrame.new(math.sin(t * 2 - i * 0.6) * i * 0.25, 0, 0)
			end,
		})
	end
	smoke(e, Color3.fromRGB(60, 50, 50), 18, 3)
	sparks(e, EMB, 10)
	glow(e, EMB, 16)
	e.size = 9
end

-- THE CINDER KING (Hell boss, stands in his caldera): a magma giant with a crown of horns
function B.CinderKing(e)
	local R, R2, LAVA = Color3.fromRGB(36, 20, 18), Color3.fromRGB(58, 30, 24), Color3.fromRGB(255, 110, 30)
	local breathe = function(t)
		return CFrame.new(0, math.sin(t * 1.2) * 0.6, 0)
	end
	add(e, "Block", Vector3.new(18, 16, 12), R, CFrame.new(0, 2, 0), { anim = breathe })
	add(e, "Block", Vector3.new(12, 10, 10), R2, CFrame.new(0, 14, -1), { anim = breathe })
	add(e, "Block", Vector3.new(9, 2.6, 0.6), LAVA, CFrame.new(0, 11.5, -6.2), { mat = Enum.Material.Neon, anim = breathe })
	teeth(e, Vector3.new(0, 12.6, -6.5), 9, 8, 1.6, false, { anim = breathe })
	teeth(e, Vector3.new(0, 10.4, -6.4), 8, 7, 1.4, true, { anim = breathe })
	for _, sd in ipairs({ -1, 1 }) do
		eye(e, Vector3.new(sd * 2.8, 16, -5.8), 2.4, sd, { anim = breathe, sclera = Color3.fromRGB(255, 220, 90) })
		for k = 0, 2 do
			add(e, "Wedge", Vector3.new(1.4, 6 - k, 2), Color3.fromRGB(20, 10, 10), CFrame.new(sd * (2 + k * 2), 21 + k * 0.5, 0) * CFrame.Angles(0, 0, -sd * (0.15 + k * 0.25)), { anim = breathe })
		end
		local arm = function(t)
			return breathe(t) * CFrame.new(sd * 11, 8, 0) * CFrame.Angles(math.sin(t * 0.9 + sd) * 0.3, 0, sd * 0.15) * CFrame.new(-sd * 11, -8, 0)
		end
		add(e, "Block", Vector3.new(6, 16, 6), R2, CFrame.new(sd * 12.5, 1, -1), { anim = arm })
		add(e, "Block", Vector3.new(7.5, 6, 7.5), R, CFrame.new(sd * 12.5, -9.5, -1.5), { anim = arm })
		add(e, "Block", Vector3.new(0.4, 12, 0.6), LAVA, CFrame.new(sd * 12.5, 1, -4.1) * CFrame.Angles(0, 0, sd * 0.2), { mat = Enum.Material.Neon, anim = arm })
		add(e, "Block", Vector3.new(6, 10, 6), R2, CFrame.new(sd * 5, -11, 0), { anim = breathe })
	end
	for k = 1, 5 do
		add(e, "Block", Vector3.new(0.5, 6 + k, 0.6), LAVA, CFrame.new(-6 + k * 2.2, 2 - k % 2 * 2, -6.1) * CFrame.Angles(0, 0, (k % 2 == 0 and 0.4 or -0.3)), { mat = Enum.Material.Neon, anim = breathe })
	end
	smoke(e, Color3.fromRGB(40, 30, 30), 20, 10)
	sparks(e, LAVA, 24)
	glow(e, LAVA, 60)
	e.size = 34
end

-- ABYSS LURKER: a blind black angler-horror. Huge jaw of needle teeth, a dangling lure, white pin eyes
function B.AbyssLurker(e)
	local C = Color3.fromRGB(10, 10, 16)
	local swim = function(t)
		return CFrame.new(0, math.sin(t * 1.2) * 0.8, 0) * CFrame.Angles(0, math.sin(t * 0.9) * 0.1, 0)
	end
	add(e, "Ball", Vector3.one * 12, C, CFrame.new(0, 1, 1), { anim = swim })
	add(e, "Block", Vector3.new(11, 2, 3), Color3.fromRGB(70, 10, 30), CFrame.new(0, -1.5, -4.6), { mat = Enum.Material.Neon, anim = swim })
	teeth(e, Vector3.new(0, -0.2, -5.6), 11, 12, 2.6, false, { anim = swim })
	local jaw = function(t)
		return swim(t) * CFrame.new(0, -3, 0) * CFrame.Angles(0.2 + math.max(0, math.sin(t * 1.6)) * 0.3, 0, 0) * CFrame.new(0, 3, 0)
	end
	add(e, "Block", Vector3.new(11, 2.4, 9), C, CFrame.new(0, -4.4, -1.5), { anim = jaw })
	teeth(e, Vector3.new(0, -3, -5.6), 10, 11, 2.4, true, { anim = jaw })
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Ball", Vector3.one * 0.7, Color3.new(1, 1, 1), CFrame.new(sd * 2.4, 4.4, -4.6), { mat = Enum.Material.Neon, anim = swim })
		add(e, "Wedge", Vector3.new(0.4, 5, 6), Color3.fromRGB(20, 20, 30), CFrame.new(sd * 6, 0, 3) * CFrame.Angles(0, 0, sd * 1.1), { anim = swim })
	end
	local lure = function(t)
		return swim(t) * CFrame.new(math.sin(t * 2) * 0.6, math.sin(t * 2.6) * 0.4, 0)
	end
	add(e, "Block", Vector3.new(0.3, 0.3, 7), C, CFrame.new(0, 7.5, -3) * CFrame.Angles(-0.6, 0, 0), { anim = swim })
	add(e, "Ball", Vector3.one * 1.6, Color3.fromRGB(150, 255, 230), CFrame.new(0, 9.5, -6.8), { mat = Enum.Material.Neon, anim = lure })
	tentacle(e, Vector3.new(0, 0, 6), Vector3.new(0, 0, 1), 6, 4, 2, C, Color3.fromRGB(20, 20, 30), 1.6, 0)
	glow(e, Color3.fromRGB(150, 255, 230), 20)
	e.size = 14
end

-- THE HOLLOW (Unknown): a tall thin thing with a smiling white mask, hollow eyes, impossibly long arms
function B.Hollow(e)
	local C, MASK = Color3.fromRGB(8, 4, 14), Color3.fromRGB(235, 230, 220)
	local sway = function(t)
		return CFrame.new(0, math.sin(t * 0.8) * 1, 0) * CFrame.Angles(0, 0, math.sin(t * 0.6) * 0.05)
	end
	add(e, "Block", Vector3.new(3, 16, 2), C, CFrame.new(0, -2, 0), { anim = sway })
	add(e, "Block", Vector3.new(4, 5, 0.8), MASK, CFrame.new(0, 8, -1.2), { anim = sway })
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Ball", Vector3.one * 1.3, Color3.new(0, 0, 0), CFrame.new(sd * 0.9, 8.8, -1.7), { anim = sway })
		add(e, "Ball", Vector3.one * 0.35, RED, CFrame.new(sd * 0.9, 8.8, -2.2), { mat = Enum.Material.Neon, anim = sway })
		local arm = function(t)
			return sway(t) * CFrame.new(sd * 2, 5, 0) * CFrame.Angles(math.sin(t * 0.7 + sd) * 0.25, 0, sd * (0.15 + math.sin(t * 0.5) * 0.08)) * CFrame.new(-sd * 2, -5, 0)
		end
		add(e, "Block", Vector3.new(0.8, 18, 0.8), C, CFrame.new(sd * 2.4, -3, -0.5), { anim = arm })
		for f = -1, 1 do
			add(e, "Wedge", Vector3.new(0.25, 3.4, 0.5), C, CFrame.new(sd * 2.4 + f * 0.45, -13.5, -0.8) * CFrame.Angles(math.pi, 0, f * 0.2), { anim = arm })
		end
	end
	add(e, "Block", Vector3.new(2.4, 0.5, 0.3), Color3.new(0, 0, 0), CFrame.new(0, 6.8, -1.65) * CFrame.Angles(0, 0, 0), { anim = sway })
	teeth(e, Vector3.new(0, 7, -1.75), 2.4, 8, 0.4, false, { anim = sway })
	for k = 0, 7 do -- halo of watching eyes
		local a = k / 8 * math.pi * 2
		orbEye(e, CFrame.new(math.cos(a) * 4.5, 8 + math.sin(a) * 4.5, 0.5), 0.9, Color3.fromRGB(190, 110, 255), function(t)
			return sway(t) * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, t * 0.3) * CFrame.new(0, -8, 0)
		end)
	end
	smoke(e, Color3.fromRGB(20, 0, 30), 20, 4)
	glow(e, Color3.fromRGB(140, 60, 220), 30)
	e.size = 18
end

-- THE UNKNOWN (final boss): a living galaxy. A spiral vortex core, a crown of colossal tentacles,
-- dozens of eyes opening in the dark, violet lightning veins
function B.TheUnknown(e)
	local C, C2, VEIN = Color3.fromRGB(14, 10, 26), Color3.fromRGB(34, 26, 60), Color3.fromRGB(170, 200, 255)
	local slow = function(t)
		return CFrame.new(0, math.sin(t * 0.4) * 3, 0)
	end
	add(e, "Ball", Vector3.one * 40, C, I, { anim = slow })
	for arm = 0, 2 do -- the spiral (galaxy arms) facing you
		for j = 0, 13 do
			local a = arm * (math.pi * 2 / 3) + j * 0.32
			local r = 6 + j * 2.6
			add(e, "Block", Vector3.new(3.4 - j * 0.15, 1.2, 4), j % 3 == 0 and VEIN or Color3.fromRGB(120, 90, 220), CFrame.new(math.cos(a) * r, math.sin(a) * r, -20 - j * 0.3) * CFrame.Angles(0, 0, a), {
				mat = Enum.Material.Neon,
				tr = 0.15 + j * 0.04,
				anim = function(t)
					return slow(t) * CFrame.Angles(0, 0, t * 0.15)
				end,
			})
		end
	end
	orbEye(e, CFrame.new(0, 0, -21), 9, Color3.fromRGB(255, 60, 90), slow) -- the eye at the heart of the spiral
	for k, d in ipairs({ { -0.9, 0.6 }, { 0.8, 0.7 }, { -1.2, -0.3 }, { 1.25, -0.2 }, { 0.3, 1 }, { -0.4, -0.9 }, { 0.6, -0.8 }, { 1.6, 0.4 }, { -1.6, 0.3 } }) do
		orbEye(e, surf(19.5, d[1], d[2]), 3 + (k % 3), k % 2 == 0 and Color3.fromRGB(190, 120, 255) or RED, slow)
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local dir = Vector3.new(math.cos(a), math.sin(a), 0.35)
		tentacle(e, dir * 17, dir, 10, 9, 6.5, C, C2, 0.7, k * 0.9, VEIN)
	end
	smoke(e, Color3.fromRGB(40, 20, 80), 24, 20)
	sparks(e, VEIN, 30)
	glow(e, Color3.fromRGB(150, 90, 255), 120)
	e.size = 90
end

-- ===== v0.8 BIBLICAL ANGELS (refs: mirrored wing stacks lined with eyes, wheels within wheels) =====
-- one feathered wing in the X/Y plane: n feathers fanned around angle a0 (radians from horizontal), side sd
local function angelWing(e, sd, shoulder, a0, spread, n, L, w, pal, eyeEvery, flapAmp, ph, spd, body)
	spd = spd or 1
	local beat = hinge(shoulder, function(t)
		local b = math.sin(t * 2.2 * spd + ph) -- the beat
		return CFrame.Angles(0, sd * (0.18 + b * 0.5) * flapAmp, sd * b * flapAmp)
	end)
	local flap = body and function(t)
		return body(t) * beat(t)
	end or beat
	for j = 1, n do
		local u = (j - 1) / math.max(1, n - 1)
		local a = a0 + (u - 0.5) * spread
		local len = L * (0.55 + 0.45 * math.sin(u * math.pi * 0.9 + 0.2))
		local dir = Vector3.new(sd * math.cos(a), math.sin(a), 0)
		local rot = CFrame.Angles(0, 0, sd > 0 and a or (math.pi - a))
		local z = 0.02 * j
		add(e, "Block", Vector3.new(len, w, w * 0.25), pal.feather, CFrame.new(shoulder + dir * (len / 2)) * rot * CFrame.new(0, 0, z), { anim = flap })
		add(e, "Block", Vector3.new(len * 0.42, w * 0.6, w * 0.12), (j % 2 == 0) and pal.band or pal.band2, CFrame.new(shoulder + dir * (len * 0.68)) * rot * CFrame.new(0, 0, -w * 0.1 - z), { anim = flap })
		add(e, "Block", Vector3.new(len * 0.25, w * 0.5, w * 0.1), pal.tip, CFrame.new(shoulder + dir * (len * 0.9)) * rot * CFrame.new(0, 0, -w * 0.12 - z), { anim = flap })
		if eyeEvery and j % eyeEvery == 0 then
			orbEye(e, CFrame.new(shoulder + dir * (len * 0.45)) * CFrame.new(0, 0, -w * 0.3), w * 0.75, pal.iris, flap)
		end
	end
end
local PALS = {
	holy = { feather = Color3.fromRGB(246, 240, 228), band = Color3.fromRGB(214, 170, 120), band2 = Color3.fromRGB(235, 222, 200), tip = Color3.fromRGB(150, 80, 50), iris = Color3.fromRGB(70, 170, 220), body = Color3.fromRGB(240, 232, 216), gold = Color3.fromRGB(255, 205, 80) },
	warden = { feather = Color3.fromRGB(250, 246, 236), band = Color3.fromRGB(255, 205, 80), band2 = Color3.fromRGB(240, 228, 205), tip = Color3.fromRGB(180, 30, 50), iris = Color3.fromRGB(255, 50, 60), body = Color3.fromRGB(245, 238, 222), gold = Color3.fromRGB(255, 205, 80) },
	cherub = { feather = Color3.fromRGB(70, 46, 50), band = Color3.fromRGB(235, 220, 190), band2 = Color3.fromRGB(95, 64, 66), tip = Color3.fromRGB(40, 26, 34), iris = Color3.fromRGB(255, 190, 70), body = Color3.fromRGB(88, 60, 60), gold = Color3.fromRGB(230, 180, 90) },
}
-- the big central eye with heavy lids and a row of eyes across (ref 1)
local function angelFace(e, pal, s, row, anim)
	orbEye(e, CFrame.new(0, 0, -s * 0.2), s, pal.iris, anim)
	add(e, "Block", Vector3.new(s * 1.7, s * 0.35, s * 0.6), pal.body, CFrame.new(0, s * 0.48, -s * 0.25) * CFrame.Angles(-0.35, 0, 0), { anim = anim })
	add(e, "Block", Vector3.new(s * 1.7, s * 0.3, s * 0.6), pal.body, CFrame.new(0, -s * 0.48, -s * 0.25) * CFrame.Angles(0.35, 0, 0), { anim = anim })
	for i = 1, row do
		for _, sd in ipairs({ -1, 1 }) do
			local es = s * (0.55 - i * 0.06)
			orbEye(e, CFrame.new(sd * (s * 0.55 + i * s * 0.5), math.abs(i - 2) * s * 0.06, -s * 0.05) * CFrame.Angles(0, -sd * 0.2 * i, 0), es, pal.iris, anim)
		end
	end
end
local function angel(e, palName, opts)
	local pal = PALS[palName]
	local spd = opts.speed or 1
	local breathe = function(t)
		-- the body rises on every down-beat and the whole being sways
		return CFrame.new(0, math.sin(t * 2.2 * spd - 0.8) * 0.45, 0) * CFrame.Angles(math.sin(t * 0.5 * spd) * 0.05, 0, math.sin(t * 0.7 * spd) * 0.06)
	end
	-- body: layered paper column + tail stacks that fall like the lower wings in ref 1
	add(e, "Block", Vector3.new(2.2, 3.6, 1.6), pal.body, CFrame.new(0, -0.6, 0.4), { anim = breathe })
	add(e, "Wedge", Vector3.new(2.2, 3, 1.6), pal.body, CFrame.new(0, -3.9, 0.4) * CFrame.Angles(0, 0, math.pi), { anim = breathe })
	add(e, "Block", Vector3.new(0.3, 4, 0.3), pal.tip, CFrame.new(0, -1.5, -0.45), { anim = breathe })
	angelFace(e, pal, 2, opts.row or 3, breathe)
	-- 3 pairs of wings: raised, spread, drooping (6 wings: a seraph)
	for _, sd in ipairs({ -1, 1 }) do
		angelWing(e, sd, Vector3.new(sd * 0.9, 1.2, 0.6), 1.0, 0.55, (opts.n or 7) + 2, 11, 0.8, pal, 2, 0.32, 0, spd, breathe)
		angelWing(e, sd, Vector3.new(sd * 1.1, 0.2, 0.7), 0.2, 0.7, (opts.n or 7) + 3, 13, 0.85, pal, 2, 0.42, 0.6, spd, breathe)
		angelWing(e, sd, Vector3.new(sd * 0.7, -1.4, 0.6), -1.3, 0.35, opts.n or 7, 12, 0.8, pal, 3, 0.22, 1.2, spd, breathe)
	end
	if opts.halo then
		ring(e, Vector3.new(0, 0, 1.6), 5.5, 28, pal.gold, 0.22, function(t)
			return breathe(t) * CFrame.new(0, 0, 1.6) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, t * 0.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0, -1.6)
		end)
	end
	sparks(e, pal.gold, opts.sparks or 20)
	glow(e, pal.gold, 60)
end
-- SERAPHIM (giant, neutral): ~100x a player. Six eyed wings and one great eye.
function B.Seraphim(e)
	angel(e, "holy", { halo = true, row = 4, n = 8, sparks = 30, speed = 0.35 })
	e.size = 300
end
-- THRONE (giant, neutral): wheels within wheels, every rim crowded with eyes, four wings (ref 2)
function B.Throne(e)
	local GOLD, RIM = Color3.fromRGB(255, 205, 80), Color3.fromRGB(236, 226, 205)
	local pal = PALS.holy
	add(e, "Ball", Vector3.one * 2.2, Color3.fromRGB(255, 250, 225), I, { mat = Enum.Material.Neon })
	orbEye(e, CFrame.new(0, 0, -0.9), 1.6, pal.iris)
	for k, ax in ipairs({ CFrame.identity, CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(0, 0, math.pi / 2), CFrame.Angles(math.pi / 4, math.pi / 4, 0) }) do
		local spin = function(t)
			return ax * CFrame.Angles(0, t * (0.12 + k * 0.05) * (k % 2 == 0 and -1 or 1), 0)
		end
		local R = 4.5 + k * 0.9
		for j = 0, 23 do
			local a = j / 24 * math.pi * 2
			add(e, "Block", Vector3.new(0.9, 0.7, R * 2 * math.pi / 24 * 1.08), j % 2 == 0 and RIM or GOLD, CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0), { anim = spin, mat = j % 2 == 0 and Enum.Material.SmoothPlastic or Enum.Material.Neon })
			if j % 2 == 0 then
				orbEye(e, CFrame.Angles(0, a, 0) * CFrame.new(R + 0.35, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), 0.6, pal.iris, spin)
			end
		end
	end
	for _, sd in ipairs({ -1, 1 }) do
		angelWing(e, sd, Vector3.new(sd * 3, 2, 1), 0.9, 0.6, 7, 8, 1, pal, nil, 0.3, 0, 0.3)
		angelWing(e, sd, Vector3.new(sd * 3, -2, 1), -0.9, 0.6, 7, 8, 1, pal, nil, 0.3, 1.5, 0.3)
	end
	sparks(e, GOLD, 30)
	glow(e, GOLD, 60)
	e.size = 280
end
-- THE HALO WARDEN (boss): a crimson-eyed seraph with a crown of halos
function B.HaloWarden(e)
	angel(e, "warden", { halo = true, row = 3, n = 7, sparks = 30, speed = 0.7 })
	for k = 1, 2 do
		ring(e, Vector3.new(0, 4 + k * 0.8, 0.5), 2.4 - k * 0.5, 16, Color3.fromRGB(255, 205, 80), 0.25, function(t)
			return CFrame.new(0, 4 + k * 0.8, 0.5) * CFrame.Angles(0, t * (k == 1 and 0.8 or -1.1), 0) * CFrame.new(0, -4 - k * 0.8, -0.5)
		end)
	end
	smoke(e, Color3.fromRGB(255, 220, 170), 6, 4)
	e.size = 120
end
-- CHERUB (Heaven enemy, ref 3): a four-faced owl-angel of dark banded feathers
function B.GildedMoth(e)
	angel(e, "cherub", { row = 2, n = 6, sparks = 10, speed = 1.5 })
	e.size = 30
end
-- THE NAMELESS (the Unknown, ~1000 studs): a mass you can barely see in the dark. What you DO see:
-- dozens of eyes opening across it, a vertical seam of light, impossible rings turning, endless arms.
function B.Nameless(e)
	local DK, DK2, VI = Color3.fromRGB(8, 6, 14), Color3.fromRGB(16, 10, 26), Color3.fromRGB(140, 90, 255)
	local drift = function(t)
		return CFrame.new(math.sin(t * 0.07) * 0.6, math.sin(t * 0.11) * 0.8, 0) * CFrame.Angles(0, math.sin(t * 0.05) * 0.15, math.sin(t * 0.04) * 0.05)
	end
	local seed = 99
	local rngL = { NextNumber = function(_, a, b)
		seed = (seed * 16807) % 2147483647
		return a + (b - a) * seed / 2147483647
	end }
	for k = 1, 12 do -- the body: overlapping masses of black
		local o = Vector3.new(rngL:NextNumber(-5, 5), rngL:NextNumber(-4, 4), rngL:NextNumber(0, 4))
		add(e, "Ball", Vector3.one * rngL:NextNumber(5, 9), k % 2 == 0 and DK or DK2, CFrame.new(o), { anim = drift })
	end
	for k = 1, 30 do -- eyes everywhere, each looking a slightly different way, each slowly "breathing"
		local yaw, pitch = rngL:NextNumber(-1.2, 1.2), rngL:NextNumber(-0.9, 0.9)
		local sz = k == 1 and 3.2 or rngL:NextNumber(0.5, 1.8)
		local cf = k == 1 and CFrame.new(0, 0.5, -5.6) or surf(5.4 + rngL:NextNumber(-0.3, 0.8), yaw, pitch)
		local iris = ({ Color3.fromRGB(235, 235, 255), Color3.fromRGB(120, 255, 230), Color3.fromRGB(255, 70, 90), VI })[k % 4 + 1]
		local ph = rngL:NextNumber(0, 6)
		orbEye(e, cf, sz, iris, function(t)
			return drift(t) * CFrame.new(0, 0, math.sin(t * 0.3 + ph) * 0.25)
		end)
	end
	for k = -6, 6 do -- a vertical seam of light down the middle
		add(e, "Block", Vector3.new(0.18, 0.95, 0.18), Color3.fromRGB(230, 220, 255), CFrame.new(math.sin(k * 0.7) * 0.15, k * 0.9 - 1, -6.4), { mat = Enum.Material.Neon, anim = drift })
	end
	for k, ax in ipairs({ CFrame.Angles(0.4, 0, 0.2), CFrame.Angles(-0.7, 0.5, 0), CFrame.Angles(1.2, 0, -0.6) }) do -- rings that shouldn't exist
		local R = 9 + k * 2.2
		local spin = function(t)
			return drift(t) * ax * CFrame.Angles(0, t * 0.03 * (k % 2 == 0 and -1 or 1), 0)
		end
		for j = 0, 23 do
			if j % 5 ~= 0 then -- broken
				local a = j / 24 * math.pi * 2
				add(e, "Block", Vector3.new(0.25, 0.25, R * 2 * math.pi / 24 * 0.9), j % 2 == 0 and VI or Color3.fromRGB(60, 40, 110), CFrame.Angles(0, a, 0) * CFrame.new(R, 0, 0), { mat = Enum.Material.Neon, anim = spin, tr = 0.2 })
			end
		end
	end
	for k = 0, 9 do -- endless arms reaching down into the dark
		local a = k / 10 * math.pi * 2
		local dir = Vector3.new(math.cos(a) * 0.6, -0.75, math.sin(a) * 0.6)
		tentacle(e, dir * 5, dir, 12, 2.4, 1.7, DK, DK2, 0.25, k, VI)
	end
	smoke(e, Color3.fromRGB(10, 6, 20), 10, 12)
	sparks(e, VI, 20)
	glow(e, VI, 60)
	e.size = 900
end

-- v0.9c THE FORGOTTEN (Abyss) / THE HUNCHED ONE (Cosmos): a colossal titan curled over itself, skin like rock
-- and wound fibre, head bowed, one vast hand resting on nothing. It breathes. Its head turns to you.
local function colossus(e, skin, skin2, eyeC, shaft, motes)
	local seed = 7
	local function rn(a, b)
		seed = (seed * 16807) % 2147483647
		return a + (b - a) * seed / 2147483647
	end
	local breath = function(t)
		return CFrame.new(0, math.sin(t * 0.25) * 0.25, 0) * CFrame.Angles(math.sin(t * 0.25) * 0.02, 0, 0)
	end
	local headA = function(t)
		return breath(t) * CFrame.new(0, 1, -5) * CFrame.Angles(0.1 + math.sin(t * 0.13) * 0.06, math.sin(t * 0.09) * 0.25, 0) * CFrame.new(0, -1, 5)
	end
	-- the back: one huge hump made of lumps
	add(e, "Ball", Vector3.one * 11, skin, CFrame.new(0, 1, 1), { anim = breath })
	for k = 1, 16 do
		local a, b = rn(0, math.pi * 2), rn(-0.3, 1.2)
		local o = Vector3.new(math.cos(a) * math.cos(b) * 4.5, math.sin(b) * 4.5 + 1, math.sin(a) * math.cos(b) * 4.5 + 1)
		add(e, "Ball", Vector3.one * rn(3, 6), k % 3 == 0 and skin2 or skin, CFrame.new(o), { anim = breath })
	end
	-- wound fibres over the back (image: strands of something old)
	for k = 1, 14 do
		local a = rn(-1.2, 1.2)
		local cf = CFrame.new(0, 1, 1) * CFrame.Angles(0, 0, a) * CFrame.Angles(rn(-1.3, 0.6), 0, 0) * CFrame.new(0, 5.4, 0)
		add(e, "Block", Vector3.new(rn(0.5, 1.1), 0.5, rn(5, 9)), k % 2 == 0 and skin2 or skin, cf, { anim = breath })
	end
	-- shoulders and the bowed head
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Ball", Vector3.one * 6.5, skin, CFrame.new(sd * 4.6, 0.5, -3), { anim = breath })
	end
	add(e, "Ball", Vector3.one * 4.6, skin2, CFrame.new(0, -1.2, -6.2), { anim = headA })
	add(e, "Ball", Vector3.one * 3.2, skin, CFrame.new(0, -2.6, -7.4), { anim = headA }) -- brow / snout mass
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Block", Vector3.new(0.9, 0.22, 0.2), eyeC, CFrame.new(sd * 0.95, -1.2, -8.4) * CFrame.Angles(0, 0, sd * 0.2), { anim = headA, mat = Enum.Material.Neon })
	end
	-- one vast arm reaching forward and down, a hand of thick fingers
	local arm = { Vector3.new(-5, -1, -4), Vector3.new(-6, -4, -7), Vector3.new(-5.5, -7, -9.5), Vector3.new(-4.5, -9, -11) }
	for i, v in ipairs(arm) do
		add(e, "Ball", Vector3.one * (4.2 - i * 0.5), i % 2 == 0 and skin2 or skin, CFrame.new(v), { anim = breath })
	end
	for f = -2, 2 do
		local base = Vector3.new(-4.5 + f * 0.75, -10, -11.6)
		add(e, "Block", Vector3.new(0.6, 0.6, 3.2), skin2, CFrame.new(base) * CFrame.Angles(-0.9, f * 0.15, 0) * CFrame.new(0, 0, -1.2), { anim = function(t)
			return breath(t) * CFrame.new(0, math.sin(t * 0.4 + f) * 0.08, 0)
		end })
	end
	-- the other arm folded under the body
	add(e, "Ball", Vector3.one * 4, skin2, CFrame.new(4.5, -4, -4), { anim = breath })
	add(e, "Ball", Vector3.one * 3, skin, CFrame.new(3.5, -6.5, -6), { anim = breath })
	-- the shaft of light falling on it from somewhere far above + things circling in it
	if shaft then
		add(e, "Cyl", Vector3.new(60, 9, 9), shaft, CFrame.new(0, 32, 0) * CFrame.Angles(0, 0, math.pi / 2), { mat = Enum.Material.Neon, tr = 0.9 })
		add(e, "Cyl", Vector3.new(60, 14, 14), shaft, CFrame.new(0, 32, 0) * CFrame.Angles(0, 0, math.pi / 2), { mat = Enum.Material.Neon, tr = 0.95 })
	end
	for k = 1, 9 do
		local r, h, sp, ph = rn(5, 9), rn(4, 22), rn(0.15, 0.35), rn(0, 6)
		add(e, "Wedge", Vector3.new(0.9, 0.12, 0.5), Color3.fromRGB(10, 10, 12), CFrame.identity, { anim = function(t)
			local a = t * sp + ph
			return CFrame.new(math.cos(a) * r, h + math.sin(t * 0.7 + ph) * 1.5, math.sin(a) * r) * CFrame.Angles(0, -a, math.sin(t * 6 + ph) * 0.5)
		end })
	end
	smoke(e, skin2, 6, 6)
	sparks(e, motes, 18)
	glow(e, motes, 60)
end
function B.Forgotten(e)
	colossus(e, Color3.fromRGB(38, 52, 52), Color3.fromRGB(24, 34, 36), Color3.fromRGB(150, 255, 230), Color3.fromRGB(120, 230, 210), Color3.fromRGB(140, 240, 220))
	e.size = 520
end
function B.Hunched(e)
	colossus(e, Color3.fromRGB(44, 38, 40), Color3.fromRGB(26, 22, 24), Color3.fromRGB(255, 250, 235), nil, Color3.fromRGB(230, 225, 255))
	e.size = 520
end

-- ======================= v1.0 COSMIC GIANTS =======================
local function prng(seed0)
	local seed = seed0
	return function(a, b)
		seed = (seed * 16807) % 2147483647
		return a + (b - a) * seed / 2147483647
	end
end
-- THE MAW BELOW (Hell): a mouth the size of a mountain rising from the lava, rings of teeth turning inward
function B.MawBelow(e)
	local FLESH, FLESH2, LAVA = Color3.fromRGB(70, 22, 18), Color3.fromRGB(40, 12, 10), Color3.fromRGB(255, 110, 30)
	local rise = function(t)
		return CFrame.new(0, math.sin(t * 0.2) * 0.4, 0)
	end
	add(e, "Ball", Vector3.one * 7, Color3.fromRGB(20, 4, 2), CFrame.new(0, -1.5, 0), { anim = rise }) -- the throat
	add(e, "Ball", Vector3.one * 4.5, LAVA, CFrame.new(0, -2.6, 0), { anim = rise, mat = Enum.Material.Neon, tr = 0.2 })
	for ringI = 0, 2 do
		local R = 6.5 - ringI * 1.4
		local dir = ringI % 2 == 0 and 1 or -1
		local spin = function(t)
			return rise(t) * CFrame.new(0, -ringI * 0.6, 0) * CFrame.Angles(0, t * 0.05 * dir, 0)
		end
		local n = 22 - ringI * 4
		for j = 0, n - 1 do
			local a = j / n * math.pi * 2
			if ringI == 0 then -- the lip
				add(e, "Block", Vector3.new(2.4, 1.6, R * 2 * math.pi / n * 1.1), j % 2 == 0 and FLESH or FLESH2, CFrame.Angles(0, a, 0) * CFrame.new(R + 0.8, 0.4, 0), { anim = rise })
			end
			add(e, "Wedge", Vector3.new(0.9, 2.4 - ringI * 0.3, 1.4), TOOTH, CFrame.Angles(0, a, 0) * CFrame.new(R, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(-0.9, 0, 0), { anim = spin })
		end
	end
	local rn = prng(31)
	for k = 1, 12 do -- eyes crowded on the lip
		local a = rn(0, math.pi * 2)
		orbEye(e, CFrame.Angles(0, a, 0) * CFrame.new(8.2, rn(0.6, 2), 0) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(0.6, 0, 0), rn(0.5, 1.1), Color3.fromRGB(255, 200, 40), rise)
	end
	for k = 0, 5 do -- tongues/tendrils lolling over the rim
		local a = k / 6 * math.pi * 2 + 0.3
		local dir = Vector3.new(math.cos(a), 0.15, math.sin(a))
		tentacle(e, dir * 6 + Vector3.new(0, 0.5, 0), dir, 8, 1.4, 1.3, FLESH, FLESH2, 0.4, k, LAVA)
	end
	for k = 0, 9 do -- the body sinking into the lava
		local a = k / 10 * math.pi * 2
		add(e, "Ball", Vector3.one * 6, FLESH2, CFrame.new(math.cos(a) * 6, -5, math.sin(a) * 6), { anim = rise })
	end
	smoke(e, Color3.fromRGB(60, 30, 20), 10, 8)
	sparks(e, LAVA, 30)
	glow(e, LAVA, 60)
	e.size = 620
end
-- THE DREAMER (Abyss): a god curled asleep, eyes shut, hair drifting, dream-bubbles rising. Do not wake it.
function B.Dreamer(e)
	local SK, SK2, DREAM = Color3.fromRGB(46, 58, 66), Color3.fromRGB(30, 38, 46), Color3.fromRGB(150, 255, 230)
	local breath = function(t)
		return CFrame.new(0, math.sin(t * 0.18) * 0.3, 0) * CFrame.Angles(0, 0, math.sin(t * 0.18) * 0.02)
	end
	for k = 0, 13 do -- the curled body: a spiral of masses
		local u = k / 13
		local a = u * math.pi * 1.6
		local r = 6 - u * 2
		add(e, "Ball", Vector3.one * (7 - u * 3.5), k % 3 == 0 and SK2 or SK, CFrame.new(math.cos(a) * r, math.sin(a) * r * 0.8, u * 2), { anim = breath })
	end
	-- the head tucked against its knees
	add(e, "Ball", Vector3.one * 5, SK, CFrame.new(5.4, 2.2, -2.2), { anim = breath })
	for _, sd in ipairs({ -1, 1 }) do
		add(e, "Block", Vector3.new(1, 0.12, 0.15), DREAM, CFrame.new(5.4 + sd * 0.9, 2.3, -4.7) * CFrame.Angles(0, 0, sd * -0.12), { anim = breath, mat = Enum.Material.Neon, tr = 0.3 })
	end
	local rn = prng(17)
	for k = 1, 10 do -- hair drifting in the deep
		local dx, dy, dz = rn(0.2, 1), rn(0.5, 1), rn(-0.6, 0.6)
		local m = math.sqrt(dx * dx + dy * dy + dz * dz)
		local dir = Vector3.new(dx / m, dy / m, dz / m)
		tentacle(e, Vector3.new(5.4, 3.6, -1.6) + dir, dir, 10, 0.4, 1.2, SK2, SK2, 0.15, k)
	end
	for k = 1, 14 do -- dream-bubbles rising and fading
		local x, z, sp, ph = rn(-8, 8), rn(-6, 6), rn(0.1, 0.25), rn(0, 10)
		add(e, "Ball", Vector3.one * rn(0.6, 1.8), DREAM, CFrame.identity, { mat = Enum.Material.Neon, tr = 0.7, anim = function(t)
			local u = (t * sp + ph) % 1
			return CFrame.new(x + math.sin(t + ph) * 0.5, 4 + u * 22, z)
		end })
	end
	smoke(e, SK2, 5, 7)
	sparks(e, DREAM, 22)
	glow(e, DREAM, 60)
	e.size = 600
end
-- STAR LEVIATHAN (Cosmos): a whale drawn in constellations, swimming through space
function B.StarLeviathan(e)
	local BODY, STAR, LINE = Color3.fromRGB(20, 24, 60), Color3.fromRGB(255, 250, 220), Color3.fromRGB(140, 170, 255)
	local N = 12
	local function seg(i)
		return function(t)
			local ph = t * 0.5 - i * 0.45
			return CFrame.new(0, math.sin(ph) * (0.2 + i * 0.08), 0) * CFrame.Angles(math.cos(ph) * 0.03 * i, 0, 0)
		end
	end
	local prev
	for i = 0, N - 1 do
		local u = i / (N - 1)
		local r = (i < 3 and (3 + i) or (6 * (1 - u) + 1)) * 1.1
		local z = -12 + i * 2.4
		local an = seg(i)
		add(e, "Ball", Vector3.one * r, BODY, CFrame.new(0, 0, z), { anim = an, tr = 0.35 })
		local star = Vector3.new(0, r * 0.45, z)
		add(e, "Ball", Vector3.one * 0.5, STAR, CFrame.new(star), { anim = an, mat = Enum.Material.Neon })
		for _, sd in ipairs({ -1, 1 }) do
			add(e, "Ball", Vector3.one * 0.35, STAR, CFrame.new(sd * r * 0.42, 0, z), { anim = an, mat = Enum.Material.Neon })
		end
		if prev then -- constellation lines along the back
			local dy, dz = star.Y - prev.Y, star.Z - prev.Z
			local len = math.sqrt(dy * dy + dz * dz)
			add(e, "Block", Vector3.new(0.12, 0.12, len), LINE, CFrame.new(0, (star.Y + prev.Y) * 0.5, (star.Z + prev.Z) * 0.5) * CFrame.Angles(math.atan2(-dy, dz), 0, 0), { anim = an, mat = Enum.Material.Neon, tr = 0.3 })
		end
		prev = star
	end
	for _, sd in ipairs({ -1, 1 }) do -- pectoral fins + tail flukes
		add(e, "Block", Vector3.new(7, 0.3, 3), BODY, CFrame.new(sd * 5, -1.5, -6) * CFrame.Angles(0, 0, sd * -0.4), { tr = 0.3, anim = function(t)
			return CFrame.Angles(0, 0, math.sin(t * 0.6) * 0.2 * sd)
		end })
		add(e, "Block", Vector3.new(5, 0.3, 2.5), BODY, CFrame.new(sd * 2.6, 0, 16.5) * CFrame.Angles(0, sd * 0.5, 0), { tr = 0.3, anim = seg(N) })
	end
	orbEye(e, CFrame.new(3.2, 0.6, -12) * CFrame.Angles(0, math.pi / 2, 0), 0.9, Color3.fromRGB(140, 200, 255))
	orbEye(e, CFrame.new(-3.2, 0.6, -12) * CFrame.Angles(0, -math.pi / 2, 0), 0.9, Color3.fromRGB(140, 200, 255))
	sparks(e, STAR, 30)
	glow(e, LINE, 60)
	e.size = 700
end
-- THE WEAVER (Cosmos): a spider between planets, nebula webs behind it, a crown of eyes
function B.Weaver(e)
	local CH, CH2, EYE, WEB = Color3.fromRGB(26, 20, 36), Color3.fromRGB(50, 36, 70), Color3.fromRGB(255, 80, 200), Color3.fromRGB(200, 170, 255)
	local bob = function(t)
		return CFrame.new(0, math.sin(t * 0.5) * 0.3, 0)
	end
	add(e, "Ball", Vector3.one * 4, CH, CFrame.new(0, 0, -2), { anim = bob })
	add(e, "Ball", Vector3.one * 6.5, CH2, CFrame.new(0, 0.8, 3.4), { anim = bob })
	local rn = prng(5)
	for k = 1, 10 do -- star pattern on the abdomen
		add(e, "Ball", Vector3.one * 0.4, Color3.fromRGB(255, 240, 255), CFrame.new(rn(-2, 2), 3.6 + rn(-0.4, 0.4), 3.4 + rn(-2.2, 2.2)), { anim = bob, mat = Enum.Material.Neon })
	end
	for k = 0, 7 do -- the eyes
		orbEye(e, CFrame.new((k % 4 - 1.5) * 0.8, 0.6 + math.floor(k / 4) * 0.7, -3.9), k < 4 and 0.55 or 0.4, EYE, bob)
	end
	for sd = -1, 1, 2 do
		for i = 0, 3 do -- 8 legs, two segments each, stepping on nothing
			local ph = i * 1.3 + (sd > 0 and 0 or 0.65)
			local yaw = (-0.9 + i * 0.6)
			local hip = Vector3.new(sd * 1.6, 0, -2 + i * 0.6)
			local upper = function(t)
				return bob(t) * CFrame.new(hip) * CFrame.Angles(0, yaw * sd, 0) * CFrame.Angles(0, 0, sd * (0.7 + math.sin(t * 0.8 + ph) * 0.12)) * CFrame.new(-hip)
			end
			local lower = function(t)
				return upper(t) * CFrame.new(hip + Vector3.new(sd * 6, 0, 0)) * CFrame.Angles(0, 0, sd * (-1.9 + math.sin(t * 0.8 + ph + 0.6) * 0.15)) * CFrame.new(-(hip + Vector3.new(sd * 6, 0, 0)))
			end
			add(e, "Block", Vector3.new(6, 0.6, 0.6), CH2, CFrame.new(hip + Vector3.new(sd * 3, 0, 0)), { anim = upper })
			add(e, "Block", Vector3.new(7, 0.4, 0.4), CH, CFrame.new(hip + Vector3.new(sd * 9.5, 0, 0)), { anim = lower })
		end
	end
	for k = 0, 11 do -- the web behind it: radial strands + a spiral
		local a = k / 12 * math.pi * 2
		add(e, "Block", Vector3.new(0.12, 0.12, 26), WEB, CFrame.new(0, 2, 10) * CFrame.Angles(0, 0, a) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, 0, 13), { mat = Enum.Material.Neon, tr = 0.55 })
	end
	for ring = 1, 4 do
		local R = ring * 5.5
		for k = 0, 11 do
			local a = (k + 0.5) / 12 * math.pi * 2
			add(e, "Block", Vector3.new(0.1, 2 * R * math.sin(math.pi / 12), 0.1), WEB, CFrame.new(0, 2, 10) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0, 0) * CFrame.new(R * math.cos(math.pi / 12), 0, 0), { mat = Enum.Material.Neon, tr = 0.6 })
		end
	end
	sparks(e, WEB, 20)
	glow(e, EYE, 50)
	e.size = 520
end
-- THE ECLIPSE EYE (Cosmos): a planet-sized eye hiding behind its own black moon; the corona burns around it
function B.EclipseEye(e)
	local COR, COR2 = Color3.fromRGB(255, 230, 170), Color3.fromRGB(255, 140, 60)
	add(e, "Ball", Vector3.one * 16, Color3.fromRGB(240, 232, 220), CFrame.identity)
	local look = function(t)
		return CFrame.Angles(math.sin(t * 0.13) * 0.15, math.sin(t * 0.09) * 0.25, 0)
	end
	add(e, "Ball", Vector3.one * 8, Color3.fromRGB(255, 170, 40), CFrame.new(0, 0, -4.6), { anim = look, mat = Enum.Material.Neon })
	add(e, "Ball", Vector3.one * 4.6, Color3.fromRGB(5, 4, 8), CFrame.new(0, 0, -6.4), { anim = look })
	-- the black moon sliding across it, opening and closing the eye
	add(e, "Ball", Vector3.one * 16.6, Color3.fromRGB(4, 4, 8), CFrame.identity, { anim = function(t)
		return CFrame.new(math.sin(t * 0.07) * 14, 0, -3.5)
	end })
	for ringI = 1, 3 do -- corona rings
		local R = 9 + ringI * 1.6
		local spin = function(t)
			return CFrame.Angles(0, 0, t * 0.04 * (ringI % 2 == 0 and -1 or 1))
		end
		for j = 0, 35 do
			local a = j / 36 * math.pi * 2
			local len = (j % 3 == 0) and 3 or 1.2
			add(e, "Block", Vector3.new(0.5, R * 2 * math.pi / 36 * 0.85, 0.5), j % 2 == 0 and COR or COR2, CFrame.Angles(0, 0, a) * CFrame.new(R, 0, 0), { anim = spin, mat = Enum.Material.Neon, tr = 0.15 + ringI * 0.15 })
			if j % 3 == 0 and ringI == 1 then
				add(e, "Block", Vector3.new(len * 2, 0.3, 0.3), COR, CFrame.Angles(0, 0, a) * CFrame.new(R + len + 1, 0, 0), { anim = spin, mat = Enum.Material.Neon, tr = 0.4 })
			end
		end
	end
	sparks(e, COR, 30)
	glow(e, COR2, 60)
	e.size = 640
end

-- v0.9c AURAS for the great ones: a breathing glow body, drifting motes, a wide slow halo of light
local AURA = {
	Seraphim = { Color3.fromRGB(255, 225, 140), Color3.fromRGB(255, 255, 255) },
	Throne = { Color3.fromRGB(255, 210, 110), Color3.fromRGB(255, 250, 220) },
	HaloWarden = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 120) },
	Nameless = { Color3.fromRGB(110, 70, 220), Color3.fromRGB(20, 0, 40) },
	TheUnknown = { Color3.fromRGB(140, 90, 255), Color3.fromRGB(30, 10, 60) },
	Forgotten = { Color3.fromRGB(100, 230, 210), Color3.fromRGB(20, 60, 60) },
	Hunched = { Color3.fromRGB(220, 215, 255), Color3.fromRGB(80, 70, 120) },
	MawBelow = { Color3.fromRGB(255, 100, 30), Color3.fromRGB(120, 20, 0) },
	Dreamer = { Color3.fromRGB(150, 255, 230), Color3.fromRGB(30, 80, 90) },
	StarLeviathan = { Color3.fromRGB(140, 170, 255), Color3.fromRGB(255, 255, 255) },
	Weaver = { Color3.fromRGB(255, 80, 200), Color3.fromRGB(120, 90, 255) },
	EclipseEye = { Color3.fromRGB(255, 220, 150), Color3.fromRGB(255, 120, 40) },
	CinderKing = { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 220, 120) },
	StarWisp = { Color3.fromRGB(160, 120, 255), Color3.fromRGB(80, 200, 255) },
	CometHound = { Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 255, 255) },
}
local function bigAura(e, c1, c2, sz)
	local g = Instance.new("ParticleEmitter")
	g.Texture = SMOKE
	g.Color = ColorSequence.new(c1, c2)
	g.LightEmission = 1
	g.Rate = 3
	g.Lifetime = NumberRange.new(3, 5)
	g.Speed = NumberRange.new(0, 0)
	g.Rotation = NumberRange.new(0, 360)
	g.RotSpeed = NumberRange.new(-10, 10)
	g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sz * 0.5), NumberSequenceKeypoint.new(1, sz * 0.75) })
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.82), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = e.root
	local m = Instance.new("ParticleEmitter")
	m.Texture = SPARK
	m.Color = ColorSequence.new(c1, c2)
	m.LightEmission = 1
	m.Rate = 25
	m.Lifetime = NumberRange.new(4, 7)
	m.Speed = NumberRange.new(sz * 0.05, sz * 0.15)
	m.Drag = 0.6
	m.SpreadAngle = Vector2.new(180, 180)
	m.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, math.max(1.5, sz * 0.012)), NumberSequenceKeypoint.new(1, 0) })
	m.Parent = e.root
end

-- uniform scale for big beings (applied after build: sizes, offsets and animation translations)
B.GuardianOphan = function(e)
	B.HaloSentinel(e)
	e.size = 3
end
local SCALE = { MawBelow = 34, Dreamer = 30, StarLeviathan = 24, Weaver = 22, EclipseEye = 36, Forgotten = 26, Hunched = 26, Nameless = 42, StarWisp = 3, CometHound = 3, AbyssLurker = 3, GuardianOphan = 0.45, Seraphim = 30, Throne = 26, HaloWarden = 9, GildedMoth = 2.6, HaloSentinel = 2.6 }

function EnemyModel.build(kind, parent, extra)
	local e = newE(parent, kind)
	;(B[kind] or B.InkBlob)(e)
	local sc = (SCALE[kind] or 1) * (extra or 1) -- v1.6: extra = merged blobs / elites grow
	if sc ~= 1 then
		for i, p in ipairs(e.parts) do
			if p.ClassName ~= "WedgePart" and p.Shape == Enum.PartType.Ball then
				p.Size = Vector3.one * p.Size.X * sc
			else
				p.Size = p.Size * sc
			end
			local o = e.offs[i]
			e.offs[i] = o + o.Position * (sc - 1)
			local a = e.anims[i]
			if a then
				e.anims[i] = function(t)
					local c = a(t)
					return c + c.Position * (sc - 1)
				end
			end
		end
		for _, d in ipairs(e.root.GetChildren and e.root:GetChildren() or {}) do
			if d:IsA("PointLight") then
				d.Range = math.min(60, d.Range * 2)
				d.Brightness = 2
			elseif d:IsA("ParticleEmitter") then
				local ks = {}
				for _, kp in ipairs(d.Size.Keypoints) do
					table.insert(ks, NumberSequenceKeypoint.new(kp.Time, kp.Value * math.min(sc, 12)))
				end
				d.Size = NumberSequence.new(ks)
				d.Speed = NumberRange.new(d.Speed.Min * sc * 0.5, d.Speed.Max * sc * 0.5)
				d.Rate = d.Rate * math.min(3, 1 + sc / 10)
			end
		end
		if kind == "HaloSentinel" then
			e.size = 32
		elseif kind == "GuardianOphan" then
			e.size = 3
		elseif kind == "StarWisp" then
			e.size = 36
		elseif kind == "CometHound" then
			e.size = 30
		elseif kind == "AbyssLurker" then
			e.size = 42
		end
	end
	local au = AURA[kind]
	if au then
		bigAura(e, au[1], au[2], e.size or 30)
	end
	e.cfs = table.create(#e.parts)
	return e
end
function EnemyModel.pose(e, cf, t)
	e.root.CFrame = cf
	local cfs = e.cfs
	for i, off in ipairs(e.offs) do
		local a = e.anims[i]
		cfs[i] = a and (cf * a(t) * off) or (cf * off)
	end
	workspace:BulkMoveTo(e.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

return EnemyModel
