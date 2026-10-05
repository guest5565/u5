--!nonstrict
-- INKWING v1.7 :: NPCModel - detailed, code-animated NPC figures (no meshes, no assets)
--   local npc = NPCModel.build("mentor" | "merchant", parentFolder)
--   NPCModel.pose(npc, feetCF, t, lookAtWorldPos?)   -- call every frame (idle breathing, head tracking, gestures)
--   npc.parts -> list of BaseParts (for collision / cleanup), npc.model -> Model
local NPCModel = {}

local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local rgb = Color3.fromRGB
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local M = Enum.Material

local function newNPC(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return { model = m, parts = {}, list = {}, cfs = {}, pivots = {} }
end
-- add a part to group g ("body", "head", "armL", "armR", "wingL", "wingR", "beard", "staff", "root")
local function add(n, g, size, off, color, mat, shape, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
	p.Size, p.Color, p.Material = size, color, mat or M.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Transparency = tr or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = n.model
	table.insert(n.parts, p)
	table.insert(n.list, { p = p, g = g, off = off })
	return p
end
local UPCYL = A(0, 0, math.pi / 2) -- cylinders stand upright

-- face shared by both: eyes with highlights, brows, nose, ears
local function face(n, hy, skin, browCol, eyeCol)
	local hz = -0.86
	for s = -1, 1, 2 do
		add(n, "head", V(0.36, 0.42, 0.2), CF(s * 0.34, hy + 0.08, hz + 0.02), rgb(255, 255, 255), M.SmoothPlastic, BALL)
		add(n, "head", V(0.24, 0.24, 0.24), CF(s * 0.34, hy + 0.06, hz - 0.04), eyeCol or rgb(40, 60, 90), M.SmoothPlastic, BALL)
		add(n, "head", V(0.08, 0.08, 0.08), CF(s * 0.31, hy + 0.12, hz - 0.15), rgb(255, 255, 255), M.Neon, BALL)
		add(n, "head", V(0.5, 0.14, 0.16), CF(s * 0.36, hy + 0.42, hz + 0.02) * A(0, 0, s * -0.18), browCol, M.SmoothPlastic)
		add(n, "head", V(0.3, 0.5, 0.3), CF(s * 0.98, hy, -0.05), skin, M.SmoothPlastic, BALL)
	end
	add(n, "head", V(0.36, 0.42, 0.42), CF(0, hy - 0.16, hz - 0.08), skin:Lerp(rgb(220, 120, 110), 0.15), M.SmoothPlastic, BALL)
end

local BUILD = {}
-- MASTER ORREN: an old winged master in layered robes, hood down, long white beard, feathered wings, a crystal staff
function BUILD.mentor(n, o)
	o = o or {}
	local SKIN, ROBE, ROBE2, OVER, TRIM, WHITE, WOOD = rgb(232, 190, 158), o.robe or rgb(236, 230, 214), o.robe2 or rgb(214, 206, 186), o.over or rgb(52, 74, 120), o.trim or rgb(226, 184, 82), rgb(246, 246, 250), rgb(108, 74, 44)
	-- robe skirt: three stacked flaring tiers + hem trim
	add(n, "root", V(1.3, 3.9, 3.9), CF(0, 0.65, 0) * UPCYL, ROBE2, M.Fabric, CYL)
	add(n, "root", V(0.25, 4.0, 4.0), CF(0, 0.15, 0) * UPCYL, TRIM, M.Fabric, CYL)
	add(n, "body", V(1.6, 3.4, 3.4), CF(0, 1.9, 0) * UPCYL, ROBE, M.Fabric, CYL)
	add(n, "body", V(1.4, 3.0, 3.0), CF(0, 3.2, 0) * UPCYL, ROBE, M.Fabric, CYL)
	-- over-robe panels front and back (dark blue, gold-edged)
	for s = -1, 1, 2 do
		add(n, "body", V(0.9, 4.6, 0.25), CF(s * 0.75, 2.6, -1.42) * A(0.06, 0, s * 0.04), OVER, M.Fabric)
		add(n, "body", V(0.12, 4.6, 0.28), CF(s * 0.28, 2.6, -1.44) * A(0.06, 0, 0), TRIM, M.Fabric)
	end
	add(n, "body", V(2.6, 4.4, 0.25), CF(0, 2.7, 1.42) * A(-0.05, 0, 0), OVER, M.Fabric)
	-- chest + shoulders + collar
	add(n, "body", V(2.7, 1.9, 1.9), CF(0, 4.6, 0), ROBE, M.Fabric)
	add(n, "body", V(2.8, 0.4, 2.0), CF(0, 3.8, 0), rgb(150, 50, 40), M.Fabric) -- sash
	add(n, "body", V(0.7, 0.7, 0.3), CF(0, 3.8, -1.05), TRIM, M.Metal) -- buckle
	add(n, "body", V(0.4, 0.3, 0.42), CF(0.7, 3.45, -1.0) * A(0, 0, 0.3), rgb(150, 50, 40), M.Fabric) -- sash tail
	for s = -1, 1, 2 do
		add(n, "body", V(1.35, 1.35, 1.35), CF(s * 1.45, 5.15, 0), OVER, M.Fabric, BALL)
	end
	add(n, "body", V(0.6, 2.7, 2.7), CF(0, 5.6, 0.1) * UPCYL, OVER, M.Fabric, CYL) -- cowl / hood collar
	add(n, "body", V(1.6, 1.4, 0.9), CF(0, 5.9, 1.0) * A(0.3, 0, 0), OVER, M.Fabric) -- hood resting on the back
	-- head
	add(n, "head", V(0.5, 0.8, 0.8), CF(0, 5.85, 0) * UPCYL, SKIN, M.SmoothPlastic, CYL)
	add(n, "head", V(1.9, 1.9, 1.9), CF(0, 6.9, 0), SKIN, M.SmoothPlastic, BALL)
	face(n, 6.9, SKIN, WHITE, rgb(70, 110, 150))
	-- white hair ring (bald crown) + top knot
	add(n, "head", V(1.8, 1.7, 1.2), CF(0, 6.85, 0.45), WHITE, M.Fabric, BALL) -- hair at the back
	for s = -1, 1, 2 do
		add(n, "head", V(0.55, 0.9, 0.8), CF(s * 0.82, 6.75, 0.15), WHITE, M.Fabric, BALL) -- side tufts
	end
	add(n, "head", V(0.6, 0.6, 0.6), CF(0, 7.95, 0.45), WHITE, M.Fabric, BALL)
	-- beard: tapering layers down to the sash + moustache
	add(n, "beard", V(1.6, 0.9, 0.8), CF(0, 6.25, -0.6), WHITE, M.Fabric)
	add(n, "beard", V(1.3, 0.9, 0.7), CF(0, 5.5, -0.82), WHITE, M.Fabric)
	add(n, "beard", V(1.0, 0.9, 0.6), CF(0, 4.7, -1.0), WHITE, M.Fabric)
	add(n, "beard", V(0.6, 0.8, 0.5), CF(0, 3.95, -1.1), WHITE, M.Fabric)
	for s = -1, 1, 2 do
		add(n, "head", V(0.7, 0.22, 0.25), CF(s * 0.35, 6.48, -0.88) * A(0, 0, s * -0.35), WHITE, M.Fabric)
	end
	-- arms: wide sleeves; right hand holds the staff, left hand rests open
	for s = -1, 1, 2 do
		local g = s < 0 and "armL" or "armR"
		add(n, g, V(1.9, 1.0, 1.0), CF(s * 1.65, 4.25, 0) * UPCYL, ROBE, M.Fabric, CYL)
		add(n, g, V(1.0, 1.55, 1.55), CF(s * 1.75, 3.15, -0.1) * UPCYL, ROBE, M.Fabric, CYL)
		add(n, g, V(0.18, 1.6, 1.6), CF(s * 1.75, 2.7, -0.1) * UPCYL, TRIM, M.Fabric, CYL)
		add(n, g, V(0.7, 0.7, 0.7), CF(s * 1.75, 2.35, -0.25), SKIN, M.SmoothPlastic, BALL)
	end
	n.pivots.armL = V(-1.6, 5.1, 0)
	n.pivots.armR = V(1.6, 5.1, 0)
	-- staff (in the right hand): twisted wood, a curled head holding a glowing crystal
	add(n, "staff", V(8.4, 0.38, 0.38), CF(2.0, 3.6, -0.5) * UPCYL, WOOD, M.Wood, CYL)
	for k = 0, 3 do
		add(n, "staff", V(0.5, 0.5, 0.5), CF(2.0, 1.2 + k * 1.6, -0.5), WOOD:Lerp(rgb(60, 40, 25), 0.3), M.Wood, BALL)
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 1.6
		add(n, "staff", V(0.36, 0.36, 0.7), CF(2.0 + math.cos(a) * 0.55, 8.0 + math.sin(a) * 0.55, -0.5) * A(0, 0, a), WOOD, M.Wood)
	end
	local gem = add(n, "staff", V(0.7, 1.1, 0.7), CF(2.0, 8.05, -0.5) * A(0, math.pi / 4, 0), rgb(140, 220, 255), M.Neon, nil, 0.05)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = rgb(140, 220, 255), 16, 1.6
	l.Parent = gem
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Rate, sp.Lifetime, sp.Speed = 6, NumberRange.new(0.8, 1.4), NumberRange.new(0.5, 1.5)
	sp.Size = NumberSequence.new(0.3, 0)
	sp.LightEmission = 1
	sp.Color = ColorSequence.new(rgb(170, 230, 255))
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.Parent = gem
	n.gem = gem
	-- a tall pointed paper hat (Quill)
	if o.hat then
		add(n, "head", V(0.3, 3.6, 3.6), CF(0, 7.65, 0) * UPCYL, o.over or OVER, M.Fabric, CYL)
		for k = 1, 5 do
			local d = 2.2 - k * 0.38
			add(n, "head", V(0.55, d, d), CF(0, 7.7 + k * 0.5, 0.05 * k) * A(0.04 * k, 0, 0) * UPCYL, (o.over or OVER):Lerp(rgb(255, 255, 255), k % 2 == 0 and 0.08 or 0), M.Fabric, CYL)
		end
		add(n, "head", V(0.35, 0.35, 0.35), CF(0, 10.4, 0.4), TRIM, M.Neon, BALL)
	end
	if o.nowings then
		n.pivots.head = V(0, 5.8, 0)
		n.pivots.beard = V(0, 6.3, -0.4)
		return
	end
	-- wings: folded feathered wings, three layers of feathers per side
	for s = -1, 1, 2 do
		local g = s < 0 and "wingL" or "wingR"
		add(n, g, V(0.5, 2.6, 0.9), CF(s * 0.9, 5.5, 1.25) * A(0.15, s * 0.35, s * 0.25), WHITE, M.SmoothPlastic)
		for k = 1, 7 do
			local L = 2.2 + k * 0.55
			local x = s * (0.9 + k * 0.28)
			add(n, g, V(0.14, L, 0.62), CF(x, 5.6 - L / 2 + 0.6, 1.35 + k * 0.05) * A(0.12, s * 0.35, s * (0.12 + k * 0.03)), k % 2 == 0 and WHITE or rgb(232, 234, 242), M.SmoothPlastic)
		end
		for k = 1, 4 do
			add(n, g, V(0.16, 1.4, 0.7), CF(s * (0.9 + k * 0.4), 5.65, 1.3) * A(0.1, s * 0.35, s * 0.25), rgb(250, 250, 255), M.SmoothPlastic)
		end
		add(n, g, V(0.1, 3.6, 0.5), CF(s * 2.9, 3.8, 1.75) * A(0.12, s * 0.35, s * 0.33), TRIM, M.SmoothPlastic) -- gilded tip feather
	end
	n.pivots.wingL = V(-0.6, 5.6, 1.1)
	n.pivots.wingR = V(0.6, 5.6, 1.1)
	n.pivots.head = V(0, 5.8, 0)
	n.pivots.beard = V(0, 6.3, -0.4)
end

-- QUILL: the old paper-folder of Quill's Rest - blue robes, a tall pointed hat, no wings
function BUILD.quill(n)
	BUILD.mentor(n, { hat = true, nowings = true, over = rgb(60, 70, 160), robe = rgb(240, 236, 222), trim = rgb(250, 200, 80) })
end

-- THE WANDERING MERCHANT: goggled aviator captain with a long coat, scarf, big moustache and a pack
function BUILD.merchant(n)
	local SKIN, COAT, COAT2, PANTS, BOOT, SCARF, GOLD, HAT = rgb(236, 196, 160), rgb(60, 100, 150), rgb(45, 76, 118), rgb(110, 84, 60), rgb(60, 40, 28), rgb(210, 60, 50), rgb(236, 186, 70), rgb(70, 48, 32)
	for s = -1, 1, 2 do
		add(n, "root", V(0.85, 0.7, 1.3), CF(s * 0.5, 0.35, -0.2), BOOT, M.Leather)
		add(n, "root", V(0.8, 1.6, 0.8), CF(s * 0.5, 1.4, 0), PANTS, M.Fabric)
		add(n, "root", V(0.86, 0.25, 0.86), CF(s * 0.5, 0.75, 0), rgb(40, 28, 20), M.Leather)
	end
	-- coat (with tails) + belt + buttons
	add(n, "body", V(2.3, 2.1, 1.4), CF(0, 3.2, 0), COAT, M.Fabric)
	add(n, "body", V(2.4, 1.4, 1.5), CF(0, 2.1, 0.05), COAT2, M.Fabric)
	add(n, "body", V(2.45, 0.3, 1.55), CF(0, 2.75, 0), rgb(50, 34, 22), M.Leather)
	add(n, "body", V(0.5, 0.4, 0.2), CF(0, 2.75, -0.8), GOLD, M.Metal)
	for k = 0, 2 do
		add(n, "body", V(0.18, 0.18, 0.18), CF(0.35, 3.6 - k * 0.4, -0.72), GOLD, M.Metal, BALL)
	end
	-- scarf wrapped + a tail blowing back
	add(n, "body", V(0.6, 1.9, 1.9), CF(0, 4.25, 0) * UPCYL, SCARF, M.Fabric, CYL)
	add(n, "body", V(0.5, 1.4, 0.2), CF(0.5, 3.6, 0.8) * A(0.4, 0, 0.2), SCARF, M.Fabric)
	-- backpack with rolled map
	add(n, "body", V(1.6, 1.8, 0.9), CF(0, 3.2, 1.1), rgb(130, 90, 55), M.Leather)
	add(n, "body", V(2.0, 0.5, 0.5), CF(0, 4.25, 1.2) * UPCYL * A(0, 0, math.pi / 2), rgb(240, 225, 190), M.Fabric, CYL)
	-- head
	add(n, "head", V(1.8, 1.8, 1.8), CF(0, 5.2, 0), SKIN, M.SmoothPlastic, BALL)
	face(n, 5.2, SKIN, rgb(90, 60, 40), rgb(70, 50, 30))
	for s = -1, 1, 2 do -- big curled moustache
		add(n, "head", V(0.75, 0.3, 0.3), CF(s * 0.38, 4.85, -0.86) * A(0, 0, s * -0.25), rgb(110, 70, 40), M.Fabric)
		add(n, "head", V(0.25, 0.25, 0.25), CF(s * 0.78, 4.95, -0.82), rgb(110, 70, 40), M.Fabric, BALL)
	end
	-- aviator cap + goggles on the brim
	add(n, "head", V(1.95, 1.0, 1.95), CF(0, 5.75, 0.05), HAT, M.Leather)
	add(n, "head", V(1.0, 1.95, 1.95), CF(0, 6.05, 0.05) * UPCYL, HAT, M.Leather, CYL)
	add(n, "head", V(2.05, 0.25, 0.3), CF(0, 5.8, -0.9), rgb(40, 30, 22), M.Leather)
	for s = -1, 1, 2 do
		add(n, "head", V(0.2, 0.6, 0.6), CF(s * 0.38, 5.85, -0.98) * A(0, math.pi / 2, 0) * UPCYL, GOLD, M.Metal, CYL)
		add(n, "head", V(0.22, 0.45, 0.45), CF(s * 0.38, 5.85, -1.02) * A(0, math.pi / 2, 0) * UPCYL, rgb(150, 220, 255), M.Glass, CYL, 0.2)
		add(n, "head", V(0.4, 0.8, 0.4), CF(s * 0.98, 5.4, 0), HAT, M.Leather) -- ear flaps
	end
	-- arms
	for s = -1, 1, 2 do
		local g = s < 0 and "armL" or "armR"
		add(n, g, V(0.75, 2.1, 0.75), CF(s * 1.5, 3.25, 0), COAT, M.Fabric)
		add(n, g, V(0.85, 0.35, 0.85), CF(s * 1.5, 2.3, 0), GOLD, M.Fabric)
		add(n, g, V(0.6, 0.6, 0.6), CF(s * 1.5, 1.95, 0), rgb(80, 60, 45), M.Leather, BALL) -- gloves
	end
	n.pivots.armL = V(-1.5, 4.2, 0)
	n.pivots.armR = V(1.5, 4.2, 0)
	n.pivots.head = V(0, 4.4, 0)
end

function NPCModel.build(kind, parent)
	local n = newNPC(parent, kind)
	n.kind = kind
	;(BUILD[kind] or BUILD.mentor)(n)
	return n
end

local function about(pivot, rot)
	return CF(pivot) * rot * CF(-pivot)
end
-- idle animation: breathing, the head follows `look`, beard sways, wings settle, staff hand bobs,
-- the merchant waves now and then.
function NPCModel.pose(n, feet, t, look)
	local breathe = math.sin(t * 1.6) * 0.06
	local body = CF(0, breathe, 0)
	local yaw, pitch = math.sin(t * 0.35) * 0.35, 0
	if look then
		local lp = feet:PointToObjectSpace(look)
		local hp = n.pivots.head or V(0, 5, 0)
		local d = lp - hp
		if d.Magnitude > 0.5 and d.Magnitude < 40 then
			yaw = math.clamp(math.atan2(-d.X, -d.Z), -0.9, 0.9)
			pitch = math.clamp(math.atan2(d.Y, V(d.X, 0, d.Z).Magnitude), -0.35, 0.35)
		end
	end
	n.yaw = (n.yaw or 0) + (yaw - (n.yaw or 0)) * 0.08
	n.pitch = (n.pitch or 0) + (pitch - (n.pitch or 0)) * 0.08
	local G = {}
	G.root = CF()
	G.body = body
	G.head = body * about(n.pivots.head or V(0, 5, 0), A(n.pitch, n.yaw, 0))
	G.beard = G.head * about(n.pivots.beard or V(0, 6, 0), A(math.sin(t * 1.1) * 0.04, 0, math.sin(t * 0.9) * 0.05))
	local swing = math.sin(t * 1.3) * 0.05
	G.armL = body * about(n.pivots.armL or V(-1.5, 4, 0), A(swing, 0, -0.05))
	local wave = 0
	if n.kind == "merchant" then
		local cyc = t % 9
		if cyc < 2.2 then
			wave = math.sin(cyc / 2.2 * math.pi)
		end
	end
	local armR = A(-swing - wave * 0.3, 0, wave * 2.6 + math.sin(t * 9) * 0.25 * wave)
	G.armR = body * about(n.pivots.armR or V(1.5, 4, 0), armR)
	G.staff = G.armR
	local wf = math.sin(t * 0.8) * 0.04
	G.wingL = body * about(n.pivots.wingL or V(-0.6, 5.5, 1), A(0, -wf, -wf))
	G.wingR = body * about(n.pivots.wingR or V(0.6, 5.5, 1), A(0, wf, wf))
	for i, e in ipairs(n.list) do
		n.cfs[i] = feet * (G[e.g] or body) * e.off
	end
	workspace:BulkMoveTo(n.parts, n.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	if n.gem then
		n.gem.Transparency = 0.05 + math.sin(t * 2.5) * 0.08
	end
end

return NPCModel
