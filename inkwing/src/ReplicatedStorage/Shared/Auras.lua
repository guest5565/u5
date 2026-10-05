--!nonstrict
-- Inkbound v13.1 :: AURAS
-- Geometry-only auras (no uploaded assets). Every style is built differently - ground pieces,
-- orbiting pieces, things above the head, things behind the back - and they get fancier the
-- harder they are to get (level road -> shop -> passes).
--
--   local a = Auras.new(style, item, { folder = f, scale = 1, lod = 1 })
--   a:update(rootCFrame, now, dt)   -- every frame while visible
--   a:setHidden(true/false)
--   a:destroy()
--
-- Units are "character units": root = HumanoidRootPart centre, feet at y = -3, head top ~ +2.
-- `scale` multiplies everything (gallery showcases use 2-4). +Z is BEHIND the root (look = -Z).
local Auras = {}

local rng = Random.new()
local function rnd(a, b)
	return a + rng:NextNumber() * (b - a)
end
local NEON, SMOOTH, GLASS, FOIL = Enum.Material.Neon, Enum.Material.SmoothPlastic, Enum.Material.Glass, Enum.Material.Foil
local BALL, BLOCK, CYL, WEDGE = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Wedge
local WHITE = Color3.new(1, 1, 1)
local camera = workspace.CurrentCamera

local A = {}
-- Ordered list (cheap -> premium) for previews / docs
Auras.Order = { "drip", "sparkle", "doodle", "ember", "leaves", "frost", "storm", "void", "halo", "bubbles", "hearts", "music", "rainbow", "lightning", "stardust", "galaxy", "gold", "phoenix" }

---------------------------------------------------------------------------
-- object
---------------------------------------------------------------------------
local stepGeo -- (v14.3, geometry particles below)
local stepSol -- (v13.2, defined with the SOL layer below)
local Obj = {}
Obj.__index = Obj

function Obj:part(shape, color, mat, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape or BALL
	p.Material = mat or NEON
	p.Color = color or WHITE
	p.Transparency = tr or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.one * 0.2
	p.Parent = self.holder
	return p
end
-- local position helpers (scaled)
function Obj:P(x, y, z)
	return self.base * CFrame.new(x * self.k, y * self.k, z * self.k)
end
function Obj:V(x, y, z)
	return Vector3.new(x, y, z) * self.k
end
function Obj:n(count) -- level of detail
	return math.max(2, math.floor(count * self.lod + 0.5))
end
function Obj:update(cf, now, dt)
	if self.hidden or self.dead then
		return
	end
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	self.base = CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0)
	for _, e in ipairs(self.emit) do
		e.p.CFrame = self:P(0, e.y, 0)
	end
	stepSol(self, now)
	stepGeo(self, dt or 0.016)
	self.def.step(self, now, dt)
end
function Obj:setHidden(h)
	if self.hidden == h then
		return
	end
	self.hidden = h
	self.holder.Parent = (not h) and self.folder or nil
end
function Obj:destroy()
	self.dead = true
	self.holder:Destroy()
end

-- v13.2: particle + light layers on top of the geometry (built-in textures only)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local EMIT = {
	drip = { { tex = SPARK, rate = 4, col = "c2", size = 0.35, speed = { 0.2, 0.6 }, life = { 0.5, 0.9 }, box = { 2.5, 4, 2.5 } } },
	sparkle = { { tex = SPARK, rate = 12, col = "c1", size = 0.55, speed = { 0.3, 1.2 }, life = { 0.6, 1 }, box = { 3.5, 5, 3.5 } } },
	doodle = { { tex = SPARK, rate = 5, col = "c2", size = 0.35, speed = { 0.5, 1.5 }, life = { 0.4, 0.8 }, box = { 4.4, 0.2, 4.4 }, y = -2.9 } },
	ember = { { tex = FIRE, rate = 16, col = "c1", col2 = "c2", size = 0.9, speed = { 1.5, 3 }, life = { 0.4, 0.8 }, box = { 2.6, 0.3, 2.6 }, y = -2.8, up = true, light = 0.5 }, { tex = SPARK, rate = 8, col = "c1", size = 0.3, speed = { 2, 4 }, life = { 0.6, 1.1 }, box = { 2.4, 0.3, 2.4 }, y = -2.6, up = true } },
	leaves = { { tex = SPARK, rate = 5, col = "c2", size = 0.35, speed = { 0.5, 1.2 }, life = { 0.6, 1 }, box = { 3, 5, 3 } } },
	frost = { { tex = SPARK, rate = 12, col = "white", size = 0.35, speed = { 0.4, 1 }, life = { 1, 1.6 }, box = { 4, 5, 4 }, down = true }, { tex = SMOKE, rate = 3, col = "c1", size = 2.4, speed = { 0.2, 0.5 }, life = { 1.5, 2.2 }, box = { 3, 0.2, 3 }, y = -2.8, tr = 0.8 } },
	storm = { { tex = SPARK, rate = 14, col = "c2", size = 0.4, speed = { 3, 6 }, life = { 0.2, 0.4 }, box = { 4, 6, 4 } } },
	void = { { tex = SMOKE, rate = 9, col = "dark", size = 2.6, speed = { 0.3, 0.8 }, life = { 1.2, 1.8 }, box = { 3, 4, 3 }, tr = 0.55, noLight = true }, { tex = SPARK, rate = 8, col = "c2", size = 0.4, speed = { 0.5, 1.5 }, life = { 0.6, 1 }, box = { 3, 4, 3 } } },
	halo = { { tex = SPARK, rate = 16, col = "c1", size = 0.5, speed = { 1, 2.5 }, life = { 0.9, 1.5 }, box = { 3, 0.3, 3 }, y = -2.8, up = true }, { tex = SPARK, rate = 6, col = "white", size = 0.8, speed = { 0, 0.3 }, life = { 0.5, 0.8 }, box = { 2, 0.3, 2 }, y = 3.1 } },
	bubbles = { { tex = SPARK, rate = 4, col = "c2", size = 0.3, speed = { 0.4, 1 }, life = { 0.5, 0.9 }, box = { 3, 5, 3 } } },
	hearts = { { tex = SPARK, rate = 8, col = "c1", col2 = "c2", size = 0.45, speed = { 0.6, 1.5 }, life = { 0.7, 1.1 }, box = { 3, 4, 3 }, up = true } },
	music = { { tex = SPARK, rate = 12, col = "c1", col2 = "c2", size = 0.4, speed = { 1, 2.5 }, life = { 0.4, 0.8 }, box = { 4, 0.3, 4 }, y = -2.6, up = true } },
	rainbow = { { tex = SPARK, rate = 18, col = "rainbow", size = 0.5, speed = { 0.6, 1.8 }, life = { 0.7, 1.2 }, box = { 4, 5, 4 } } },
	galaxy = { { tex = SPARK, rate = 20, col = "c2", col2 = "white", size = 0.35, speed = { 0.2, 0.8 }, life = { 1, 1.8 }, box = { 6, 5, 6 } }, { tex = SMOKE, rate = 4, col = "c1", size = 3, speed = { 0.2, 0.4 }, life = { 1.5, 2.5 }, box = { 3.5, 0.2, 3.5 }, y = -2.8, tr = 0.7 } },
	gold = { { tex = SPARK, rate = 14, col = "c1", col2 = "white", size = 0.45, speed = { 0.5, 1.5 }, life = { 0.7, 1.2 }, box = { 3.5, 5, 3.5 } }, { tex = SPARK, rate = 6, col = "c1", size = 0.6, speed = { 0, 0.4 }, life = { 0.4, 0.7 }, box = { 1.4, 0.3, 1.4 }, y = 3.3 } },
}
EMIT.phoenix = { { tex = FIRE, rate = 22, col = "c1", col2 = "c2", size = 1.3, speed = { 1.5, 3.5 }, life = { 0.4, 0.8 }, box = { 2.4, 0.3, 2.4 }, y = -2.8, up = true }, { tex = SPARK, rate = 14, col = "c1", col2 = "white", size = 0.35, speed = { 1, 3 }, life = { 0.8, 1.4 }, box = { 5, 4, 3 }, up = true } }
EMIT.lightning = { { tex = SPARK, rate = 22, col = "c1", col2 = "white", size = 0.35, speed = { 4, 9 }, life = { 0.12, 0.3 }, box = { 3, 5, 3 } }, { tex = SMOKE, rate = 3, col = "c2", size = 2.2, speed = { 0.2, 0.5 }, life = { 1, 1.6 }, box = { 3, 0.2, 3 }, y = -2.8, tr = 0.75 } }
EMIT.stardust = { { tex = SPARK, rate = 18, col = "c1", col2 = "c2", size = 0.4, speed = { 0.4, 1.2 }, life = { 1.2, 2 }, box = { 4, 0.3, 4 }, y = -2.8, up = true }, { tex = SPARK, rate = 8, col = "white", size = 0.7, speed = { 0, 0.2 }, life = { 0.3, 0.6 }, box = { 4, 6, 4 } } }
local LIGHT = { phoenix = 2, lightning = 1.3, stardust = 0.9, ember = 1, frost = 0.6, storm = 0.8, halo = 1.4, rainbow = 0.7, galaxy = 1, gold = 1.1, void = 0.5 }
local function colOf(o, key)
	if key == "c1" then
		return o.c1
	elseif key == "c2" then
		return o.c2
	elseif key == "dark" then
		return Color3.fromRGB(20, 8, 40)
	end
	return WHITE
end
-- v13.2 "SOL" LAYER for the premium auras: a soft light pillar + comet motes orbiting the body
local PILLAR = { halo = 1, rainbow = 1, galaxy = 1, gold = 1, stardust = 1, lightning = 1, void = 1 }
local MOTES = { storm = 2, void = 3, halo = 3, music = 3, rainbow = 4, lightning = 3, stardust = 5, galaxy = 5, gold = 4 }
local function buildSol(o, style)
	o.sol = {}
	if PILLAR[style] then
		local a = o:part(BLOCK, WHITE, SMOOTH, 1)
		a.Size = Vector3.one * 0.2
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, -3 * o.k, 0), Vector3.new(0, 11 * o.k, 0)
		a0.Parent, a1.Parent = a, a
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Color = style == "void" and ColorSequence.new(Color3.fromRGB(40, 10, 70), o.c2) or ColorSequence.new(o.c1, o.c2)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) })
		b.Width0, b.Width1 = 3.2 * o.k, 1.2 * o.k
		b.LightEmission, b.LightInfluence = 1, 0
		b.FaceCamera = true
		b.Segments = 4
		b.Parent = a
		o.sol.pillar = { p = a, b = b }
	end
	o.sol.motes = {}
	for i = 1, math.max(0, math.floor((MOTES[style] or 0) * math.max(0.5, o.lod) + 0.5)) do
		local m = o:part(BALL, i % 2 == 0 and o.c2 or o.c1, NEON, 0)
		m.Size = Vector3.one * 0.28 * o.k
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.12 * o.k, 0), Vector3.new(0, -0.12 * o.k, 0)
		a0.Parent, a1.Parent = m, m
		local t = Instance.new("Trail")
		t.Attachment0, t.Attachment1 = a0, a1
		t.Color = ColorSequence.new(m.Color, WHITE)
		t.Transparency = NumberSequence.new(0.2, 1)
		t.Lifetime, t.LightEmission, t.FaceCamera = 0.35, 1, true
		t.Parent = m
		o.sol.motes[i] = { p = m, ph = i / math.max(1, MOTES[style]) * math.pi * 2, r = rnd(1.5, 2.2), sp = rnd(1.4, 2.2), tilt = rnd(-0.5, 0.5) }
	end
end
stepSol = function(o, now)
	local sol = o.sol
	if not sol then
		return
	end
	if sol.pillar then
		sol.pillar.p.CFrame = o:P(0, 0, 0)
		local pulse = 0.5 + 0.5 * math.sin(now * 2.2)
		sol.pillar.b.Width0 = (2.8 + pulse * 0.8) * o.k
	end
	for _, m in ipairs(sol.motes) do
		local a = now * m.sp + m.ph
		m.p.CFrame = o:P(math.cos(a) * m.r, math.sin(a * 0.5 + m.ph) * 1.6 + m.tilt, math.sin(a) * m.r)
	end
end
-- v14.3 GEOMETRY PARTICLES: the sparkle-texture dots are replaced by real little shapes
-- (no uploads possible), one shape family per aura. Each slot lives, drifts, spins and shrinks, then respawns.
local SHAPE_OF = {
	drip = "drop", sparkle = "cross", doodle = "tri", ember = "diamond", leaves = "leaf", frost = "flake",
	storm = "shard", void = "diamond", halo = "cross", bubbles = "bubble", hearts = "heart", music = "note",
	rainbow = "diamond", lightning = "shard", stardust = "star", galaxy = "star", gold = "coin", phoenix = "diamond",
}
-- each shape = list of { shape, size(Vector3 at scale 1), offset CFrame, material?, colour-key? }
local R45 = CFrame.Angles(0, 0, math.pi / 4)
local SHAPES = {
	diamond = { { BLOCK, Vector3.new(0.7, 0.7, 0.08), R45 } },
	cross = { { BLOCK, Vector3.new(1.3, 0.12, 0.06), CFrame.new() }, { BLOCK, Vector3.new(0.12, 1.3, 0.06), CFrame.new() }, { BLOCK, Vector3.new(0.3, 0.3, 0.07), R45 } },
	star = { { BLOCK, Vector3.new(1.2, 0.1, 0.06), CFrame.new() }, { BLOCK, Vector3.new(0.1, 1.2, 0.06), CFrame.new() }, { BLOCK, Vector3.new(0.75, 0.08, 0.05), R45 }, { BLOCK, Vector3.new(0.08, 0.75, 0.05), R45 } },
	flake = { { BLOCK, Vector3.new(1.1, 0.09, 0.05), CFrame.new() }, { BLOCK, Vector3.new(1.1, 0.09, 0.05), CFrame.Angles(0, 0, math.pi / 3) }, { BLOCK, Vector3.new(1.1, 0.09, 0.05), CFrame.Angles(0, 0, -math.pi / 3) } },
	tri = { { WEDGE, Vector3.new(0.06, 0.7, 0.7), CFrame.Angles(0, math.pi / 2, 0) } },
	shard = { { BLOCK, Vector3.new(0.12, 1.1, 0.06), CFrame.Angles(0, 0, 0.3) }, { BLOCK, Vector3.new(0.1, 0.7, 0.05), CFrame.new(0.18, -0.6, 0) * CFrame.Angles(0, 0, -0.5) } },
	leaf = { { BALL, Vector3.new(0.9, 0.45, 0.08), CFrame.new(), SMOOTH }, { BLOCK, Vector3.new(0.85, 0.04, 0.09), CFrame.new(), SMOOTH, "dark" } },
	drop = { { BALL, Vector3.new(0.45, 0.6, 0.45), CFrame.new(), GLASS } },
	bubble = { { BALL, Vector3.new(0.7, 0.7, 0.7), CFrame.new(), GLASS }, { BALL, Vector3.new(0.18, 0.18, 0.18), CFrame.new(-0.15, 0.15, -0.3), NEON, "white" } },
	heart = { { BALL, Vector3.new(0.5, 0.5, 0.2), CFrame.new(-0.17, 0.1, 0) }, { BALL, Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.17, 0.1, 0) }, { BLOCK, Vector3.new(0.46, 0.46, 0.19), CFrame.new(0, -0.1, 0) * R45 } },
	note = { { BALL, Vector3.new(0.4, 0.3, 0.15), CFrame.new(0, -0.35, 0) }, { BLOCK, Vector3.new(0.07, 0.8, 0.07), CFrame.new(0.17, 0.05, 0) }, { BLOCK, Vector3.new(0.3, 0.08, 0.07), CFrame.new(0.3, 0.42, 0) * CFrame.Angles(0, 0, -0.5) } },
	coin = { { CYL, Vector3.new(0.08, 0.7, 0.7), CFrame.Angles(0, math.pi / 2, 0), FOIL }, { CYL, Vector3.new(0.09, 0.4, 0.4), CFrame.Angles(0, math.pi / 2, 0), NEON, "white" } },
}
local function buildGeo(o, e, style)
	local shape = SHAPES[e.shape or SHAPE_OF[style] or "diamond"] or SHAPES.diamond
	local count = math.clamp(math.floor(e.rate * (e.life[1] + e.life[2]) * 0.5 * o.lod + 0.5), 2, math.max(3, math.floor(28 / #shape)))
	local g = { e = e, slots = {}, shape = shape }
	for i = 1, count do
		local slot = { parts = {} }
		for j, sp in ipairs(shape) do
			local col
			if e.col == "rainbow" then
				col = Color3.fromHSV((i / count + j * 0.1) % 1, 0.75, 1)
			else
				col = colOf(o, sp[5] or ((j % 2 == 0 and e.col2) or e.col))
			end
			local p = o:part(sp[1], col, sp[4] or NEON, 1)
			slot.parts[j] = p
		end
		slot.t = -rnd(0, e.life[2]) -- staggered start
		g.slots[i] = slot
	end
	o.geo = o.geo or {}
	table.insert(o.geo, g)
end
local function spawnGeo(o, g, slot)
	local e = g.e
	slot.t = 0
	slot.life = rnd(e.life[1], e.life[2])
	slot.pos = Vector3.new(rnd(-0.5, 0.5) * e.box[1], (e.y or 0) + rnd(-0.5, 0.5) * e.box[2], rnd(-0.5, 0.5) * e.box[3])
	local sp = rnd(e.speed[1], e.speed[2])
	local dir
	if e.up then
		dir = Vector3.new(rnd(-0.25, 0.25), 1, rnd(-0.25, 0.25)).Unit
	elseif e.down then
		dir = Vector3.new(rnd(-0.2, 0.2), -1, rnd(-0.2, 0.2)).Unit
	else
		dir = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1))
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.yAxis
	end
	slot.vel = dir * sp
	slot.spin = rnd(-3, 3)
	slot.roll = rnd(0, math.pi * 2)
end
stepGeo = function(o, dt)
	if not o.geo then
		return
	end
	local camPos = camera.CFrame.Position
	for _, g in ipairs(o.geo) do
		local e = g.e
		local sz0 = e.size * 1.25
		for _, slot in ipairs(g.slots) do
			slot.t += dt
			if slot.t >= 0 and (not slot.life or slot.t >= slot.life) then
				spawnGeo(o, g, slot)
			end
			if slot.life and slot.t >= 0 then
				local f = slot.t / slot.life
				slot.pos += slot.vel * dt
				slot.roll += slot.spin * dt
				local world = o:P(slot.pos.X, slot.pos.Y, slot.pos.Z).Position
				local cf = CFrame.lookAt(world, camPos) * CFrame.Angles(0, 0, slot.roll)
				local sc = sz0 * o.k * (f < 0.15 and f / 0.15 or (1 - (f - 0.15) / 0.85 * 0.85))
				local tr = (e.tr or 0.05) + f * f * 0.8
				for j, p in ipairs(slot.parts) do
					local sp = g.shape[j]
					p.Size = sp[2] * math.max(sc, 0.01)
					p.CFrame = cf * CFrame.new(sp[3].Position * sc) * sp[3].Rotation
					p.Transparency = (sp[4] == GLASS) and math.max(tr, 0.45) or tr
				end
			else
				for _, p in ipairs(slot.parts) do
					p.Transparency = 1
				end
			end
		end
	end
end

local function buildEmitters(o, style)
	o.emit = {}
	for _, e in ipairs(EMIT[style] or {}) do
		if e.tex == SPARK then
			buildGeo(o, e, style)
			continue
		end
		local p = o:part(BLOCK, WHITE, SMOOTH, 1)
		p.Size = o:V(e.box[1], e.box[2], e.box[3])
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = e.tex
		if e.col == "rainbow" then
			local ks = {}
			for i = 0, 6 do
				ks[#ks + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 0.75, 1))
			end
			pe.Color = ColorSequence.new(ks)
		else
			pe.Color = ColorSequence.new(colOf(o, e.col), colOf(o, e.col2 or e.col))
		end
		pe.LightEmission = e.noLight and 0 or 0.9
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, e.size * o.k), NumberSequenceKeypoint.new(0.4, e.size * o.k), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, e.tr or 0.1), NumberSequenceKeypoint.new(1, 1) })
		pe.Speed = NumberRange.new(e.speed[1] * o.k, e.speed[2] * o.k)
		pe.Lifetime = NumberRange.new(e.life[1], e.life[2])
		pe.Rate = e.rate * o.lod
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-90, 90)
		if e.up then
			pe.EmissionDirection = Enum.NormalId.Top
			pe.SpreadAngle = Vector2.new(25, 25)
		elseif e.down then
			pe.EmissionDirection = Enum.NormalId.Bottom
			pe.SpreadAngle = Vector2.new(20, 20)
		else
			pe.SpreadAngle = Vector2.new(180, 180)
		end
		pe.LockedToPart = false
		pe.Parent = p
		table.insert(o.emit, { p = p, y = e.y or 0 })
	end
	if LIGHT[style] then
		local lp = o:part(BLOCK, WHITE, SMOOTH, 1)
		local pl = Instance.new("PointLight")
		pl.Color = o.c1
		pl.Brightness = LIGHT[style]
		pl.Range = 10 * o.k
		pl.Shadows = false
		pl.Parent = lp
		table.insert(o.emit, { p = lp, y = 0 })
	end
end

function Auras.new(style, it, opts)
	opts = opts or {}
	local def = A[style] or A.sparkle
	local self = setmetatable({}, Obj)
	self.def, self.it = def, it or {}
	self.c1 = (it and it.color) or WHITE
	self.c2 = (it and (it.c2 or it.color)) or WHITE
	self.k = opts.scale or 1
	self.lod = opts.lod or 1
	self.folder = opts.folder or workspace
	self.holder = Instance.new("Folder")
	self.holder.Name = "Aura_" .. tostring(style)
	self.holder.Parent = self.folder
	self.base = CFrame.new()
	def.build(self)
	buildEmitters(self, style)
	buildSol(self, style)
	return self
end
function Auras.has(style)
	return A[style] ~= nil
end

local function flat(o, p, x, y, z, d, tr) -- a flat disc lying on the ground
	p.Size = o:V(0.06, d, d)
	p.CFrame = o:P(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
	if tr then
		p.Transparency = tr
	end
end
local function faceCam(o, pos)
	return CFrame.lookAt(pos, camera.CFrame.Position)
end

---------------------------------------------------------------------------
-- 1. INK DRIPS (Lv 4) - ink runs down and splats at your feet
---------------------------------------------------------------------------
A.drip = {
	build = function(o)
		o.d = {}
		for i = 1, o:n(3) do
			o.d[i] = { drop = o:part(BALL, o.c1, SMOOTH), pud = o:part(CYL, o.c1, SMOOTH), t = i / 3, a = rnd(0, 6.28) }
		end
	end,
	step = function(o, now, dt)
		for _, d in ipairs(o.d) do
			d.t += dt / 1.6
			if d.t >= 1 then
				d.t, d.a = 0, rnd(0, 6.28)
			end
			local x, z = math.cos(d.a) * 0.9, math.sin(d.a) * 0.9
			if d.t < 0.5 then
				local f = d.t / 0.5
				d.drop.Transparency = 0
				d.drop.Size = o:V(0.22, 0.34, 0.22)
				d.drop.CFrame = o:P(x, 0.6 - f * f * 3.5, z)
				d.pud.Transparency = 1
			else
				local f = (d.t - 0.5) / 0.5
				d.drop.Transparency = 1
				flat(o, d.pud, x, -2.95, z, 0.3 + math.min(f * 3, 1) * 0.9, f * f)
			end
		end
	end,
}

---------------------------------------------------------------------------
-- 2. SPARKLE DUST (Lv 8) - four-point twinkles pop around you
---------------------------------------------------------------------------
A.sparkle = {
	build = function(o)
		o.s = {}
		for i = 1, o:n(6) do
			o.s[i] = { a = o:part(BLOCK, o.c1), b = o:part(BLOCK, o.c2), t = rng:NextNumber(), life = rnd(0.6, 1) }
		end
	end,
	step = function(o, now, dt)
		for _, s in ipairs(o.s) do
			s.t += dt / s.life
			if s.t >= 1 or not s.pos then
				s.t = 0
				local a = rnd(0, 6.28)
				local r = rnd(1.1, 2)
				s.pos = Vector3.new(math.cos(a) * r, rnd(-2.6, 2.2), math.sin(a) * r)
			end
			local sz = math.sin(s.t * math.pi) * 0.7
			local cf = faceCam(o, o:P(s.pos.X, s.pos.Y, s.pos.Z).Position) * CFrame.Angles(0, 0, s.t * 1.5)
			s.a.Size = o:V(0.07, sz, 0.02)
			s.b.Size = o:V(sz, 0.07, 0.02)
			s.a.CFrame, s.b.CFrame = cf, cf
		end
	end,
}

---------------------------------------------------------------------------
-- 3. SCRIBBLE RING (Lv 11) - a pencil keeps drawing and erasing a wobbly circle
---------------------------------------------------------------------------
A.doodle = {
	build = function(o)
		o.N = o:n(18)
		o.seg, o.wob = {}, {}
		for i = 1, o.N do
			o.seg[i] = o:part(BLOCK, o.c1, SMOOTH)
			o.wob[i] = rnd(-0.18, 0.18)
		end
		o.pen = o:part(BLOCK, o.c2, SMOOTH)
		o.tip = o:part(BLOCK, Color3.fromRGB(245, 220, 180), SMOOTH)
	end,
	step = function(o, now)
		local cyc = (now * 0.45) % 2
		local N = o.N
		local function pt(i)
			local a = (i - 1) / N * math.pi * 2
			local r = 2.1 + o.wob[((i - 1) % N) + 1]
			return Vector3.new(math.cos(a) * r, -2.94, math.sin(a) * r)
		end
		local head
		for i = 1, N do
			local s = o.seg[i]
			local f = (i - 1) / N
			local vis = (cyc < 1 and f <= cyc) or (cyc >= 1 and f > cyc - 1)
			if vis then
				local a, b = pt(i), pt(i + 1)
				local mid = (a + b) / 2
				s.Transparency = 0
				s.Size = o:V(0.16, 0.05, (b - a).Magnitude + 0.08)
				s.CFrame = CFrame.lookAt(o:P(mid.X, mid.Y, mid.Z).Position, o:P(b.X, b.Y, b.Z).Position)
			else
				s.Transparency = 1
			end
		end
		local hf = cyc < 1 and cyc or (cyc - 1)
		local hi = hf * N + 1
		head = pt(math.floor(hi)):Lerp(pt(math.floor(hi) + 1), hi % 1)
		local up = o:P(head.X, head.Y + 0.8, head.Z)
		o.pen.Size = o:V(0.22, 1.2, 0.22)
		o.pen.CFrame = up * CFrame.Angles(0.35, 0, 0.35)
		o.tip.Size = o:V(0.16, 0.25, 0.16)
		o.tip.CFrame = up * CFrame.Angles(0.35, 0, 0.35) * CFrame.new(0, -0.7 * o.k, 0)
		local tr = cyc < 1 and 0 or 0.6
		o.pen.Transparency, o.tip.Transparency = tr, tr
	end,
}

---------------------------------------------------------------------------
-- 4. EMBERS (Lv 16) - flames lick around your feet, sparks rise
---------------------------------------------------------------------------
A.ember = {
	build = function(o)
		o.fl, o.sp = {}, {}
		for i = 1, o:n(7) do
			o.fl[i] = { p = o:part(BLOCK, o.c1), a = i / 7 * math.pi * 2, ph = rnd(0, 6) }
		end
		for i = 1, o:n(7) do
			o.sp[i] = { p = o:part(BLOCK, o.c2), t = rng:NextNumber(), a = rnd(0, 6.28), life = rnd(0.9, 1.5) }
		end
	end,
	step = function(o, now, dt)
		for _, f in ipairs(o.fl) do
			local h = 0.5 + (math.sin(now * 9 + f.ph) * 0.5 + 0.5) * 0.8
			f.p.Size = o:V(0.32, h, 0.32)
			f.p.CFrame = o:P(math.cos(f.a + now * 0.6) * 1.25, -3 + h / 2, math.sin(f.a + now * 0.6) * 1.25) * CFrame.Angles(0, f.a, math.pi / 4) * CFrame.Angles(math.pi / 4, 0, 0)
			f.p.Color = o.c1:Lerp(o.c2, math.sin(now * 6 + f.ph) * 0.5 + 0.5)
			f.p.Transparency = 0.15
		end
		for _, s in ipairs(o.sp) do
			s.t += dt / s.life
			if s.t >= 1 then
				s.t, s.a = 0, rnd(0, 6.28)
			end
			local a = s.a + s.t * 2.5
			local r = 1.3 - s.t * 0.7
			local w = 0.16 * (1 - s.t) + 0.04
			s.p.Size = o:V(w, w, w)
			s.p.CFrame = o:P(math.cos(a) * r, -2.6 + s.t * 5.5, math.sin(a) * r) * CFrame.Angles(now * 3, now * 2, 0)
			s.p.Transparency = s.t * 0.9
		end
	end,
}

---------------------------------------------------------------------------
-- 5. LEAF TORNADO (Lv 19) - leaves spiral up around you and tumble away
---------------------------------------------------------------------------
A.leaves = {
	build = function(o)
		o.l = {}
		for i = 1, o:n(10) do
			o.l[i] = { p = o:part(BALL, i % 3 == 0 and o.c2 or o.c1, SMOOTH), t = i / 10, a = rnd(0, 6.28), spin = rnd(2, 5) }
		end
	end,
	step = function(o, now, dt)
		for _, l in ipairs(o.l) do
			l.t += dt / 2.6
			if l.t >= 1 then
				l.t, l.a = 0, rnd(0, 6.28)
			end
			local a = l.a + l.t * 9
			local r = 0.7 + l.t * 1.8
			l.p.Size = o:V(0.55, 0.07, 0.32)
			l.p.CFrame = o:P(math.cos(a) * r, -3 + l.t * 6.2, math.sin(a) * r) * CFrame.Angles(now * l.spin, a, math.sin(now * 3) * 0.8)
			l.p.Transparency = l.t > 0.8 and (l.t - 0.8) * 5 or 0
		end
	end,
}

---------------------------------------------------------------------------
-- 6. FROST SHARDS (Lv 24) - an ice crown grows from the ground, snowflakes fall
---------------------------------------------------------------------------
A.frost = {
	build = function(o)
		o.sh, o.fl = {}, {}
		for i = 1, o:n(8) do
			o.sh[i] = { p = o:part(BLOCK, i % 2 == 0 and o.c1 or o.c2, GLASS, 0.2), a = i / 8 * math.pi * 2, len = rnd(0.9, 1.6) }
		end
		for i = 1, o:n(5) do
			o.fl[i] = { a = o:part(BLOCK, WHITE), b = o:part(BLOCK, WHITE), c = o:part(BLOCK, WHITE), t = rng:NextNumber(), x = rnd(-2, 2), z = rnd(-2, 2) }
		end
		o.ice = o:part(CYL, o.c1, GLASS, 0.55)
	end,
	step = function(o, now, dt)
		flat(o, o.ice, 0, -2.97, 0, 3.6 + math.sin(now) * 0.1)
		for _, s in ipairs(o.sh) do
			local L = s.len * (0.9 + math.sin(now * 1.5 + s.a * 2) * 0.1)
			s.p.Size = o:V(0.3, L, 0.3)
			s.p.CFrame = o:P(math.cos(s.a) * 1.7, -3, math.sin(s.a) * 1.7) * CFrame.Angles(0, -s.a, 0) * CFrame.Angles(0, 0, -0.45) * CFrame.new(0, L * o.k / 2, 0) * CFrame.Angles(0, math.pi / 4, 0)
		end
		for _, f in ipairs(o.fl) do
			f.t += dt / 3
			if f.t >= 1 then
				f.t, f.x, f.z = 0, rnd(-2, 2), rnd(-2, 2)
			end
			local pos = o:P(f.x + math.sin(now * 2 + f.x) * 0.3, 3 - f.t * 6, f.z).Position
			local cf = faceCam(o, pos) * CFrame.Angles(0, 0, now)
			local L = 0.45
			f.a.Size, f.b.Size, f.c.Size = o:V(0.05, L, 0.02), o:V(0.05, L, 0.02), o:V(0.05, L, 0.02)
			f.a.CFrame, f.b.CFrame, f.c.CFrame = cf, cf * CFrame.Angles(0, 0, math.pi / 3), cf * CFrame.Angles(0, 0, -math.pi / 3)
			local tr = f.t > 0.85 and (f.t - 0.85) / 0.15 or 0
			f.a.Transparency, f.b.Transparency, f.c.Transparency = tr, tr, tr
		end
	end,
}

---------------------------------------------------------------------------
-- 7. STORM CLOUD (Lv 32) - a personal thundercloud strikes the ground around you
---------------------------------------------------------------------------
A.storm = {
	build = function(o)
		o.cl = {}
		for i = 1, 6 do
			o.cl[i] = { p = o:part(BALL, Color3.fromRGB(70, 76, 96), SMOOTH), x = rnd(-0.9, 0.9), z = rnd(-0.6, 0.6), s = rnd(0.8, 1.3) }
		end
		o.bolt = {}
		for i = 1, 4 do
			o.bolt[i] = o:part(BLOCK, o.c2)
		end
		o.flash = o:part(CYL, o.c1, NEON, 1)
		o.next, o.on = 0, 0
		o.drops = {}
		for i = 1, o:n(6) do
			o.drops[i] = { p = o:part(BLOCK, o.c1, NEON, 0.4), t = rng:NextNumber(), x = rnd(-1, 1), z = rnd(-0.7, 0.7) }
		end
	end,
	step = function(o, now, dt)
		for i, c in ipairs(o.cl) do
			c.p.Size = o:V(c.s, c.s * 0.8, c.s)
			c.p.CFrame = o:P(c.x + math.sin(now + i) * 0.08, 3.4 + math.sin(now * 1.3 + i) * 0.06, c.z)
		end
		for _, d in ipairs(o.drops) do
			d.t += dt / 0.6
			if d.t >= 1 then
				d.t, d.x, d.z = 0, rnd(-1, 1), rnd(-0.7, 0.7)
			end
			d.p.Size = o:V(0.04, 0.35, 0.04)
			d.p.CFrame = o:P(d.x, 3 - d.t * 6, d.z)
		end
		if now >= o.next then
			o.next = now + rnd(0.7, 1.5)
			o.on = now + 0.14
			local a = rnd(0, 6.28)
			o.hit = Vector3.new(math.cos(a) * 2, -3, math.sin(a) * 2)
			o.flashT = now
			local top = Vector3.new(rnd(-0.5, 0.5), 3, 0)
			local pts = { top }
			for s = 1, 3 do
				pts[#pts + 1] = top:Lerp(o.hit, s / 4) + Vector3.new(rnd(-0.5, 0.5), 0, rnd(-0.5, 0.5))
			end
			pts[#pts + 1] = o.hit
			o.pts = pts
		end
		local lit = now < o.on
		for i, b in ipairs(o.bolt) do
			if lit and o.pts then
				local a, c = o:P(o.pts[i].X, o.pts[i].Y, o.pts[i].Z).Position, o:P(o.pts[i + 1].X, o.pts[i + 1].Y, o.pts[i + 1].Z).Position
				b.Size = Vector3.new(0.12 * o.k, 0.12 * o.k, (c - a).Magnitude)
				b.CFrame = CFrame.lookAt((a + c) / 2, c)
				b.Transparency = 0
			else
				b.Transparency = 1
			end
		end
		if o.hit and o.flashT then
			local f = (now - o.flashT) / 0.45
			if f < 1 then
				flat(o, o.flash, o.hit.X, -2.95, o.hit.Z, 0.4 + f * 2.2, f)
			else
				o.flash.Transparency = 1
			end
		end
	end,
}

---------------------------------------------------------------------------
-- 8. VOID RIFT (Lv 42) - a black portal opens behind you and swallows light
---------------------------------------------------------------------------
A.void = {
	build = function(o)
		o.disc = o:part(CYL, Color3.fromRGB(8, 4, 18), SMOOTH)
		o.glow = o:part(CYL, o.c1, NEON, 0.5)
		o.rim = {}
		for i = 1, o:n(12) do
			o.rim[i] = o:part(BALL, o.c2)
		end
		o.inn = {}
		for i = 1, o:n(8) do
			o.inn[i] = { p = o:part(BLOCK, i % 2 == 0 and o.c2 or WHITE), t = rng:NextNumber(), a = rnd(0, 6.28) }
		end
	end,
	step = function(o, now, dt)
		local c = o:P(0, 0.4, 1.4)
		local r = 1.7 + math.sin(now * 2) * 0.08
		o.disc.Size = o:V(0.08, r * 2, r * 2)
		o.disc.CFrame = c * CFrame.Angles(0, math.pi / 2, 0)
		o.glow.Size = o:V(0.04, r * 2 + 0.35, r * 2 + 0.35)
		o.glow.CFrame = c * CFrame.new(0, 0, 0.06 * o.k) * CFrame.Angles(0, math.pi / 2, 0)
		local n = #o.rim
		for i, p in ipairs(o.rim) do
			local a = i / n * math.pi * 2 + now * 1.6
			p.Size = o:V(0.2, 0.2, 0.2)
			p.CFrame = c * CFrame.new(math.cos(a) * r * o.k, math.sin(a) * r * o.k, -0.05 * o.k)
		end
		for _, q in ipairs(o.inn) do
			q.t += dt / 1.3
			if q.t >= 1 then
				q.t, q.a = 0, rnd(0, 6.28)
			end
			local a = q.a + q.t * 5
			local rr = (1 - q.t) * 3
			q.p.Size = o:V(0.14, 0.14, 0.14) * (1 - q.t * 0.6)
			q.p.CFrame = c * CFrame.new(math.cos(a) * rr * o.k, math.sin(a) * rr * o.k, -(1 - q.t) * 1.2 * o.k) * CFrame.Angles(now, now, 0)
			q.p.Transparency = q.t * 0.6
		end
	end,
}

---------------------------------------------------------------------------
-- 9. DIVINE HALO (Lv 50) - halo, feathered wings that flap, a pillar of light
---------------------------------------------------------------------------
A.halo = {
	build = function(o)
		o.ring = {}
		for i = 1, o:n(12) do
			o.ring[i] = o:part(BALL, o.c1)
		end
		o.wing = {}
		for side = -1, 1, 2 do
			for f = 1, 7 do
				local p = o:part(BLOCK, f > 5 and o.c1 or WHITE, f > 5 and NEON or SMOOTH)
				table.insert(o.wing, { p = p, side = side, f = f })
			end
		end
		o.pillar = o:part(CYL, o.c1, NEON, 0.88)
		o.mote = {}
		for i = 1, o:n(6) do
			o.mote[i] = { p = o:part(BALL, o.c2), t = rng:NextNumber(), a = rnd(0, 6.28) }
		end
	end,
	step = function(o, now, dt)
		local n = #o.ring
		for i, p in ipairs(o.ring) do
			local a = i / n * math.pi * 2 + now * 0.8
			p.Size = o:V(0.22, 0.22, 0.22)
			p.CFrame = o:P(math.cos(a) * 0.9, 3.1 + math.sin(now * 2) * 0.07, math.sin(a) * 0.9)
		end
		local flap = math.sin(now * 2.2) * 0.18
		for _, w in ipairs(o.wing) do
			local f = w.f
			local L = 1 + f * 0.28
			local ang = math.rad(15 + f * 13) + flap
			local sh = o:P(w.side * 0.35, 1, 0.75)
			w.p.Size = o:V(0.28, L, 0.08)
			w.p.CFrame = sh * CFrame.Angles(0, -w.side * 0.35, 0) * CFrame.Angles(0, 0, -w.side * ang) * CFrame.new(0, L * o.k / 2, 0)
		end
		o.pillar.Size = o:V(7, 2.6, 2.6)
		o.pillar.CFrame = o:P(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
		o.pillar.Transparency = 0.86 + math.sin(now * 2) * 0.05
		for _, m in ipairs(o.mote) do
			m.t += dt / 1.8
			if m.t >= 1 then
				m.t, m.a = 0, rnd(0, 6.28)
			end
			m.p.Size = o:V(0.14, 0.14, 0.14)
			m.p.CFrame = o:P(math.cos(m.a) * 1.1, -3 + m.t * 6, math.sin(m.a) * 1.1)
			m.p.Transparency = m.t
		end
	end,
}

---------------------------------------------------------------------------
-- 10. BUBBLE POP (400) - soap bubbles rise, wobble and pop
---------------------------------------------------------------------------
A.bubbles = {
	build = function(o)
		o.b = {}
		for i = 1, o:n(7) do
			local col = Color3.fromHSV(rnd(0.45, 0.9), 0.35, 1)
			o.b[i] = { p = o:part(BALL, col, GLASS, 0.45), shine = o:part(BALL, WHITE, NEON, 0.3), t = rng:NextNumber(), a = rnd(0, 6.28), s = rnd(0.35, 0.7), life = rnd(2, 3) }
		end
	end,
	step = function(o, now, dt)
		for _, b in ipairs(o.b) do
			b.t += dt / b.life
			if b.t >= 1 then
				b.t, b.a = 0, rnd(0, 6.28)
			end
			local pop = b.t > 0.92
			local s = b.s * (0.5 + b.t * 0.6) * (pop and 1.4 or 1)
			local pos = o:P(math.cos(b.a) * 1.4 + math.sin(now * 2 + b.a) * 0.25, -2.5 + b.t * 5.5, math.sin(b.a) * 1.4)
			b.p.Size = o:V(s, s * (1 + math.sin(now * 6 + b.a) * 0.06), s)
			b.p.CFrame = pos
			b.p.Transparency = pop and 0.9 or 0.45
			b.shine.Size = o:V(s * 0.22, s * 0.22, s * 0.22)
			b.shine.CFrame = pos * CFrame.new(-s * 0.22 * o.k, s * 0.25 * o.k, -s * 0.3 * o.k)
			b.shine.Transparency = pop and 1 or 0.3
		end
	end,
}

---------------------------------------------------------------------------
-- 11. DOODLE HEARTS (900) - hearts float up, a heartbeat ring pulses
---------------------------------------------------------------------------
A.hearts = {
	build = function(o)
		o.h = {}
		for i = 1, o:n(6) do
			o.h[i] = { l = o:part(BALL, o.c1), r = o:part(BALL, o.c1), w = o:part(BLOCK, o.c1), t = rng:NextNumber(), a = rnd(0, 6.28), life = rnd(1.6, 2.4) }
		end
		o.beat = o:part(CYL, o.c2, NEON, 0.5)
	end,
	step = function(o, now, dt)
		for _, h in ipairs(o.h) do
			h.t += dt / h.life
			if h.t >= 1 then
				h.t, h.a = 0, rnd(0, 6.28)
			end
			local pos = o:P(math.cos(h.a) * 1.7, -1.6 + h.t * 4.2, math.sin(h.a) * 1.7).Position
			local s = 0.38 * (h.t < 0.15 and h.t / 0.15 or 1) * o.k
			local cf = faceCam(o, pos) * CFrame.Angles(0, 0, math.sin(now * 3 + h.a) * 0.3)
			h.l.Size, h.r.Size = Vector3.one * s, Vector3.one * s
			h.l.CFrame = cf * CFrame.new(-s * 0.32, s * 0.15, 0)
			h.r.CFrame = cf * CFrame.new(s * 0.32, s * 0.15, 0)
			h.w.Size = Vector3.new(s * 0.72, s * 0.72, s * 0.3)
			h.w.CFrame = cf * CFrame.new(0, -s * 0.18, 0) * CFrame.Angles(0, 0, math.pi / 4)
			local tr = h.t > 0.75 and (h.t - 0.75) / 0.25 or 0
			h.l.Transparency, h.r.Transparency, h.w.Transparency = tr, tr, tr
		end
		local ph = now % 1.1
		local f = ph < 0.25 and ph / 0.25 or ((ph > 0.3 and ph < 0.55) and (ph - 0.3) / 0.25 or 1)
		flat(o, o.beat, 0, -2.96, 0, 1.2 + f * 2.6, 0.35 + f * 0.65)
	end,
}

---------------------------------------------------------------------------
-- 12. BEAT DROP (1500) - an equalizer ring bounces to a 120 bpm beat, notes fly
---------------------------------------------------------------------------
A.music = {
	build = function(o)
		o.bars = {}
		local n = o:n(12)
		for i = 1, n do
			o.bars[i] = { p = o:part(BLOCK, o.c1:Lerp(o.c2, i / n)), a = i / n * math.pi * 2, ph = rnd(0, 6) }
		end
		o.notes = {}
		for i = 1, o:n(3) do
			o.notes[i] = { head = o:part(BALL, o.c2), stem = o:part(BLOCK, o.c2), flag = o:part(BLOCK, o.c2), t = i / 3, a = rnd(0, 6.28) }
		end
	end,
	step = function(o, now, dt)
		local env = math.exp(-((now * 2) % 1) * 5)
		for i, b in ipairs(o.bars) do
			local h = 0.25 + (math.abs(math.sin(now * 7 + b.ph + i)) * 0.6 + 0.4) * env * 1.7
			b.p.Size = o:V(0.32, h, 0.2)
			b.p.CFrame = o:P(math.cos(b.a + now * 0.4) * 1.9, -3 + h / 2, math.sin(b.a + now * 0.4) * 1.9) * CFrame.Angles(0, -(b.a + now * 0.4) + math.pi / 2, 0)
		end
		for _, nt in ipairs(o.notes) do
			nt.t += dt / 2.2
			if nt.t >= 1 then
				nt.t, nt.a = 0, rnd(0, 6.28)
			end
			local pos = o:P(math.cos(nt.a) * 1.5, -0.5 + nt.t * 3.5, math.sin(nt.a) * 1.5).Position
			local cf = faceCam(o, pos) * CFrame.Angles(0, 0, math.sin(now * 4 + nt.a) * 0.3)
			local k = o.k
			nt.head.Size = Vector3.new(0.32, 0.26, 0.2) * k
			nt.head.CFrame = cf
			nt.stem.Size = Vector3.new(0.06, 0.6, 0.06) * k
			nt.stem.CFrame = cf * CFrame.new(0.14 * k, 0.3 * k, 0)
			nt.flag.Size = Vector3.new(0.22, 0.07, 0.06) * k
			nt.flag.CFrame = cf * CFrame.new(0.24 * k, 0.56 * k, 0) * CFrame.Angles(0, 0, -0.5)
			local tr = nt.t > 0.8 and (nt.t - 0.8) * 5 or 0
			nt.head.Transparency, nt.stem.Transparency, nt.flag.Transparency = tr, tr, tr
		end
	end,
}

---------------------------------------------------------------------------
-- 13. RAINBOW SWIRL (2000) - three colour ribbons braid around you over a rainbow ring
---------------------------------------------------------------------------
A.rainbow = {
	build = function(o)
		o.rib = {}
		for r = 1, 3 do
			for i = 1, o:n(6) do
				table.insert(o.rib, { p = o:part(BALL, WHITE), r = r, i = i })
			end
		end
		o.ring = {}
		for i = 1, o:n(12) do
			o.ring[i] = o:part(BLOCK, WHITE)
		end
	end,
	step = function(o, now)
		for _, q in ipairs(o.rib) do
			local u = q.i / 6
			local a = now * 2 + q.r * 2.09 + u * 2.4
			local y = -2.6 + ((u + now * 0.25 + q.r * 0.33) % 1) * 5.4
			local s = 0.26 * (1 - u * 0.5)
			q.p.Size = o:V(s, s, s)
			q.p.Color = Color3.fromHSV((u * 0.3 + q.r / 3 + now * 0.15) % 1, 0.75, 1)
			q.p.CFrame = o:P(math.cos(a) * 1.6, y, math.sin(a) * 1.6)
		end
		local n = #o.ring
		for i, p in ipairs(o.ring) do
			local a = i / n * math.pi * 2 - now * 0.5
			p.Size = o:V(0.25, 0.06, 2 * math.pi * 2 / n * 0.9)
			p.CFrame = o:P(math.cos(a) * 2, -2.95, math.sin(a) * 2) * CFrame.Angles(0, -a, 0)
			p.Color = Color3.fromHSV((i / n + now * 0.1) % 1, 0.7, 1)
		end
	end,
}

---------------------------------------------------------------------------
-- 14. GALAXY CORE (3500) - a tiny solar system: nebula disc, planets, rings, a moon, stars
---------------------------------------------------------------------------
A.galaxy = {
	build = function(o)
		o.neb = o:part(CYL, o.c1, NEON, 0.65)
		o.neb2 = o:part(CYL, o.c2, NEON, 0.75)
		o.pl = {
			{ p = o:part(BALL, Color3.fromRGB(255, 160, 80), SMOOTH), r = 1.6, s = 0.45, sp = 1.3, tilt = 0.3 },
			{ p = o:part(BALL, Color3.fromRGB(90, 200, 255), SMOOTH), r = 2.3, s = 0.55, sp = 0.8, tilt = -0.25 },
			{ p = o:part(BALL, Color3.fromRGB(230, 200, 140), SMOOTH), r = 3, s = 0.7, sp = 0.5, tilt = 0.15, ring = o:part(CYL, Color3.fromRGB(240, 220, 180), SMOOTH, 0.2) },
		}
		o.moon = o:part(BALL, Color3.fromRGB(220, 220, 230), SMOOTH)
		o.st = {}
		for i = 1, o:n(8) do
			o.st[i] = { p = o:part(BALL, WHITE), pos = Vector3.new(rnd(-3, 3), rnd(-2, 3), rnd(-3, 3)), ph = rnd(0, 6) }
		end
	end,
	step = function(o, now)
		o.neb.Size = o:V(0.05, 4.4, 4.4)
		o.neb.CFrame = o:P(0, -2.96, 0) * CFrame.Angles(0, now * 0.3, math.pi / 2)
		o.neb2.Size = o:V(0.05, 2.4 + math.sin(now) * 0.2, 2.4 + math.sin(now) * 0.2)
		o.neb2.CFrame = o:P(0, -2.94, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for i, pl in ipairs(o.pl) do
			local a = now * pl.sp + i * 2
			local pos = o:P(math.cos(a) * pl.r, -0.2 + math.sin(a) * pl.r * pl.tilt, math.sin(a) * pl.r)
			pl.p.Size = o:V(pl.s, pl.s, pl.s)
			pl.p.CFrame = pos
			if pl.ring then
				pl.ring.Size = o:V(0.04, pl.s * 2, pl.s * 2)
				pl.ring.CFrame = pos * CFrame.Angles(0.4, 0, math.pi / 2)
			end
			if i == 2 then
				local m = now * 3
				o.moon.Size = o:V(0.16, 0.16, 0.16)
				o.moon.CFrame = pos * CFrame.new(math.cos(m) * 0.55 * o.k, 0, math.sin(m) * 0.55 * o.k)
			end
		end
		for _, s in ipairs(o.st) do
			local tw = math.sin(now * 4 + s.ph) * 0.5 + 0.5
			local z = 0.05 + tw * 0.12
			s.p.Size = o:V(z, z, z)
			s.p.CFrame = o:P(s.pos.X, s.pos.Y, s.pos.Z)
		end
	end,
}

---------------------------------------------------------------------------
-- 15. GOLDEN CROWN (VIP) - a jewelled crown floats over your head, coins orbit
---------------------------------------------------------------------------
-- v13.2 LIGHTNING (ported from the retired "Lightning Sketch" summon FX):
-- 4 charged nodes float around you; bolts leap node->node and sometimes strike the ground
A.lightning = {
	build = function(o)
		o.nodes = {}
		for i = 1, 4 do
			o.nodes[i] = { p = o:part(BALL, o.c1, NEON, 0.1), a = i / 4 * math.pi * 2, y = rnd(-1, 1.8) }
		end
		o.bolt = {}
		for i = 1, 10 do
			o.bolt[i] = o:part(BLOCK, WHITE, NEON, 1)
		end
		o.flash = o:part(CYL, o.c1, NEON, 1)
		o.next, o.on = 0, 0
	end,
	step = function(o, now, dt)
		for i, n in ipairs(o.nodes) do
			local a = n.a + now * 0.9
			local s = 0.3 + 0.1 * math.sin(now * 9 + i)
			n.p.Size = o:V(s, s, s)
			n.p.CFrame = o:P(math.cos(a) * 1.9, n.y + math.sin(now * 1.7 + i) * 0.3, math.sin(a) * 1.9)
		end
		if now >= o.next then
			o.next = now + rnd(0.12, 0.35)
			o.on = now + 0.09
			local i = rng:NextInteger(1, 4)
			local from = o.nodes[i].p.Position
			local to
			if rng:NextNumber() < 0.3 then
				to = o:P(rnd(-2, 2), -3, rnd(-2, 2)).Position
				o.flashAt, o.flashT = to, now
			else
				to = o.nodes[(i % 4) + 1].p.Position
			end
			local pts = { from }
			for k = 1, 4 do
				pts[#pts + 1] = from:Lerp(to, k / 5) + Vector3.new(rnd(-0.4, 0.4), rnd(-0.4, 0.4), rnd(-0.4, 0.4)) * o.k
			end
			pts[#pts + 1] = to
			o.pts = pts
		end
		local lit = now < o.on and o.pts
		for k, b in ipairs(o.bolt) do
			if lit and k < #o.pts then
				local a, c = o.pts[k], o.pts[k + 1]
				b.Size = Vector3.new(0.09 * o.k, 0.09 * o.k, (c - a).Magnitude)
				b.CFrame = CFrame.lookAt((a + c) / 2, c)
				b.Color = k % 2 == 0 and o.c1 or WHITE
				b.Transparency = 0
			else
				b.Transparency = 1
			end
		end
		if o.flashT then
			local f = (now - o.flashT) / 0.35
			if f < 1 then
				local rel = o.base:PointToObjectSpace(o.flashAt) / o.k
				flat(o, o.flash, rel.X, -2.95, rel.Z, 0.5 + f * 2, f)
			else
				o.flash.Transparency = 1
			end
		end
	end,
}

-- v13.2 STARDUST (ported from the retired "Stardust" summon FX):
-- a galaxy of tiny stars spirals up around you and bursts into a twinkling crown overhead
A.stardust = {
	build = function(o)
		o.st = {}
		for i = 1, o:n(16) do
			o.st[i] = { p = o:part(BLOCK, i % 3 == 0 and WHITE or (i % 2 == 0 and o.c2 or o.c1), NEON, 0), t = i / 16, sp = rnd(0.25, 0.4), ph = rnd(0, 6.28) }
		end
		o.crown = {}
		for i = 1, 6 do
			o.crown[i] = o:part(BLOCK, o.c2, NEON, 0)
		end
	end,
	step = function(o, now, dt)
		for _, s in ipairs(o.st) do
			s.t = (s.t + dt * s.sp) % 1
			local a = s.ph + s.t * math.pi * 6
			local r = 2.1 - s.t * 1.2
			local tw = 0.12 + 0.12 * math.abs(math.sin(now * 6 + s.ph))
			s.p.Size = o:V(tw, tw, tw)
			s.p.Transparency = s.t > 0.85 and (s.t - 0.85) / 0.15 or 0
			s.p.CFrame = o:P(math.cos(a) * r, -2.9 + s.t * 6, math.sin(a) * r) * CFrame.Angles(now, now * 1.3, 0.785)
		end
		for i, c in ipairs(o.crown) do
			local a = i / 6 * math.pi * 2 + now * 0.6
			local tw = 0.22 + 0.1 * math.sin(now * 5 + i)
			c.Size = o:V(tw, tw, 0.05)
			c.CFrame = o:P(math.cos(a) * 0.75, 3.2 + math.sin(now * 2 + i) * 0.08, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0.785)
		end
	end,
}

A.gold = {
	build = function(o)
		o.band = o:part(CYL, o.c1, FOIL)
		o.spikes, o.gems = {}, {}
		local gemC = { Color3.fromRGB(255, 60, 80), Color3.fromRGB(60, 160, 255), Color3.fromRGB(70, 230, 120) }
		for i = 1, 5 do
			o.spikes[i] = o:part(BLOCK, o.c1, FOIL)
			o.gems[i] = o:part(BALL, gemC[(i % 3) + 1])
		end
		o.coins = {}
		for i = 1, o:n(6) do
			o.coins[i] = o:part(CYL, Color3.fromRGB(255, 205, 60), FOIL)
		end
		o.sheen = o:part(CYL, o.c2, NEON, 0.6)
	end,
	step = function(o, now)
		local top = o:P(0, 3.2 + math.sin(now * 2) * 0.12, 0) * CFrame.Angles(0, now * 0.7, 0)
		o.band.Size = o:V(0.35, 1.25, 1.25)
		o.band.CFrame = top * CFrame.Angles(0, 0, math.pi / 2)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local p = top * CFrame.new(math.cos(a) * 0.55 * o.k, 0.3 * o.k, math.sin(a) * 0.55 * o.k)
			o.spikes[i].Size = o:V(0.22, 0.22, 0.22)
			o.spikes[i].CFrame = p * CFrame.Angles(0, -a, math.pi / 4)
			o.gems[i].Size = o:V(0.13, 0.13, 0.13)
			o.gems[i].CFrame = p * CFrame.new(0, 0.18 * o.k, 0)
		end
		local n = #o.coins
		for i, c in ipairs(o.coins) do
			local a = i / n * math.pi * 2 + now * 1.2
			c.Size = o:V(0.08, 0.5, 0.5)
			c.CFrame = o:P(math.cos(a) * 1.8, -0.6 + math.sin(now * 2 + i) * 0.3, math.sin(a) * 1.8) * CFrame.Angles(0, now * 4 + i, 0)
		end
		flat(o, o.sheen, 0, -2.96, 0, 3 + math.sin(now * 3) * 0.2, 0.55 + math.sin(now * 3) * 0.1)
	end,
}

---------------------------------------------------------------------------
-- 18. PHOENIX (top tier) - a blazing sun behind your head ringed with flame-rays, burning
--     beam-feather wings arching up around it, a rotating fire sigil under your feet
---------------------------------------------------------------------------
local Wings = require(script.Parent:WaitForChild("Wings"))
A.phoenix = {
	build = function(o)
		local hot, mid, deep = Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 160, 40), Color3.fromRGB(200, 60, 20)
		o.hot, o.mid, o.deep = hot, mid, deep
		-- sun: dark molten core, bright gold rim, glow halo
		o.sunCore = o:part(CYL, Color3.fromRGB(215, 110, 30), SMOOTH)
		o.sunRim = o:part(CYL, Color3.fromRGB(255, 205, 70), NEON)
		o.sunGlow = o:part(CYL, mid, NEON, 0.7)
		o.sunInner = o:part(CYL, Color3.fromRGB(255, 225, 120), NEON, 0.55)
		o.rays = {}
		for i = 1, o:n(18) do
			o.rays[i] = o:part(WEDGE, i % 2 == 0 and hot or mid, NEON, 0.05)
		end
		-- flame crown around the sun
		local fl = o:part(BLOCK, WHITE, SMOOTH, 1)
		local fe = Instance.new("ParticleEmitter")
		fe.Texture = FIRE
		fe.Color = ColorSequence.new(hot, deep)
		fe.LightEmission = 1
		fe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
		fe.Transparency = NumberSequence.new(0.3, 1)
		fe.Lifetime = NumberRange.new(0.4, 0.7)
		fe.Speed = NumberRange.new(1, 2)
		fe.Rate = 30 * o.lod
		fe.Shape = Enum.ParticleEmitterShape.Cylinder
		fe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		fe.EmissionDirection = Enum.NormalId.Top
		fe.Parent = fl
		o.sunFlame = fl
		-- wings
		o.wings = Wings.new({ theme = "Phoenix", feathers = 11, lod = o.lod, make = function(shape, color, mat, tr)
			return o:part(shape, color, mat, tr)
		end })
		-- fire sigil
		o.sigil = o:part(CYL, Color3.fromRGB(255, 200, 90), NEON, 0.35)
		o.sigilRing = {}
		for i = 1, o:n(16) do
			o.sigilRing[i] = o:part(BLOCK, hot, NEON)
		end
		o.swirl = {}
		for i = 1, o:n(10) do
			o.swirl[i] = { p = o:part(BLOCK, i % 2 == 0 and mid or deep, NEON, 0.2), a = i / 10 * math.pi * 2 }
		end
	end,
	step = function(o, now, dt)
		local k = o.k
		-- the sun sits behind and above the head, facing forward
		local sunC = o:P(0, 4.7 + math.sin(now * 1.4) * 0.08, 1.4)
		local face = sunC * CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis along Z
		local pulse = 1 + math.sin(now * 3) * 0.03
		o.sunCore.Size = o:V(0.12, 2.2 * pulse, 2.2 * pulse)
		o.sunCore.CFrame = face
		o.sunInner.Size = o:V(0.13, 1.5, 1.5)
		o.sunInner.CFrame = face * CFrame.new(0.02 * k, 0, 0)
		o.sunInner.Transparency = 0.5 + math.sin(now * 5) * 0.1
		o.sunRim.Size = o:V(0.1, 2.55, 2.55)
		o.sunRim.CFrame = face * CFrame.new(-0.04 * k, 0, 0)
		o.sunGlow.Size = o:V(0.08, 3.3 + math.sin(now * 2) * 0.15, 3.3 + math.sin(now * 2) * 0.15)
		o.sunGlow.CFrame = face * CFrame.new(-0.08 * k, 0, 0)
		local n = #o.rays
		for i, r in ipairs(o.rays) do
			local a = i / n * math.pi * 2 + now * 0.25
			local L = (i % 2 == 0 and 1.15 or 0.7) * (1 + math.sin(now * 4 + i) * 0.12)
			local R = 1.35
			-- wedge: tip points outward from the sun's centre, in the sun's plane
			r.Size = o:V(0.05, L, 0.32)
			r.CFrame = sunC * CFrame.Angles(0, 0, a) * CFrame.new(0, (R + L / 2) * k, 0.06 * k) * CFrame.Angles(0, math.pi / 2, 0)
		end
		o.sunFlame.Size = o:V(2.6, 0.2, 2.6)
		o.sunFlame.CFrame = sunC * CFrame.Angles(math.pi / 2, 0, 0)
		-- wings between the shoulders
		o.wings:update(o:P(0, 0.9, 0.35), k, now, 1)
		-- sigil under the feet
		flat(o, o.sigil, 0, -2.95, 0, 4.2 + math.sin(now * 2) * 0.15, 0.4 + math.sin(now * 3) * 0.08)
		local m = #o.sigilRing
		for i, p in ipairs(o.sigilRing) do
			local a = i / m * math.pi * 2 - now * 0.6
			p.Size = o:V(0.5, 0.06, 0.12)
			p.CFrame = o:P(math.cos(a) * 2.5, -2.92, math.sin(a) * 2.5) * CFrame.Angles(0, -a, 0)
		end
		for i, sw in ipairs(o.swirl) do
			local a = sw.a + now * 1.6
			local r = 1.6 + math.sin(now * 2 + i) * 0.4
			sw.p.Size = o:V(0.12, 0.08, 1.1)
			sw.p.CFrame = o:P(math.cos(a) * r, -2.85 + math.sin(now * 3 + i) * 0.15, math.sin(a) * r) * CFrame.Angles(0, -a, 0)
		end
	end,
}

return Auras
