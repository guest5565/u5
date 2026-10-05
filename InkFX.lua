-- InkFX (v9.1): layered, pooled, quality-tiered VFX for Inkbound.
--
-- Every effect is built from LAYERS: flash -> core -> impact spikes -> shockwave ring -> shards/embers ->
-- cartoon smoke -> inked particles (uploaded textures) -> ground splat -> light -> camera shake / words.
-- Works with ZERO uploaded textures (geometry layers); textures from VfxIds.lua add the hand-inked particles.
--
-- Quality: player attribute "Device" = "Mobile" -> fewer pieces, no dynamic lights, hard part budget.
-- Usage (client):  InkFX.install(fxHandlers, { shake = fn(amount) })   -- replaces the attack handlers
--                  InkFX.impact(pos, color, element, scale)            -- any custom use
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local okIds, VfxIds = pcall(function()
	return require(script.Parent:WaitForChild("VfxIds", 2))
end)
if not okIds or type(VfxIds) ~= "table" then
	VfxIds = {}
end

local FX = {}
local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(28, 30, 48)
local HEAD_COLOR = {
	Fire = Color3.fromRGB(255, 200, 90),
	Frost = Color3.fromRGB(225, 245, 255),
	Storm = Color3.fromRGB(255, 250, 190),
	Nature = Color3.fromRGB(170, 240, 120),
	Void = Color3.fromRGB(20, 10, 35),
	Holy = Color3.fromRGB(255, 240, 190),
}
local ELEMENT_COLOR = {
	Fire = Color3.fromRGB(255, 90, 40),
	Frost = Color3.fromRGB(110, 200, 255),
	Storm = Color3.fromRGB(255, 225, 60),
	Nature = Color3.fromRGB(80, 210, 90),
	Void = Color3.fromRGB(150, 70, 230),
	Holy = Color3.fromRGB(255, 150, 210),
}
local RARITY_SCALE = { Common = 0.8, Uncommon = 0.9, Rare = 1, Epic = 1.15, Legendary = 1.3, Mythic = 1.45, GODLIKE = 1.75 }

---------------------------------------------------------------------------
-- quality + budget
---------------------------------------------------------------------------
local function mobile()
	return player and player:GetAttribute("Device") == "Mobile"
end
local function Q(n) -- scale a piece count by quality
	return math.max(1, math.floor(n * (mobile() and 0.45 or 1) + 0.5))
end
local active = 0
local function budget()
	return mobile() and 170 or 520
end
local function canSpend(n)
	return active + n <= budget()
end

---------------------------------------------------------------------------
-- pooling
---------------------------------------------------------------------------
local folder = Instance.new("Folder")
folder.Name = "InkFX"
folder.Parent = workspace
local pools = {} -- shape -> { parts }
local function newPart(shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	return p
end
local function get(shape, props)
	local pool = pools[shape]
	local p = pool and table.remove(pool)
	if not p then
		p = newPart(shape)
	end
	active += 1
	p.Transparency = 0
	p.Material = Enum.Material.Neon
	p.Color = WHITE
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end
local function release(p, shape, delay)
	task.delay(delay or 0, function()
		active -= 1
		p.Parent = nil
		local pool = pools[shape]
		if not pool then
			pool = {}
			pools[shape] = pool
		end
		if #pool < 250 then
			for _, c in ipairs(p:GetChildren()) do
				c:Destroy()
			end
			pool[#pool + 1] = p
		else
			p:Destroy()
		end
	end)
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

---------------------------------------------------------------------------
-- per-frame updaters (projectiles, ballistic shards)
---------------------------------------------------------------------------
local updaters = {}
RunService.RenderStepped:Connect(function(dt)
	for i = #updaters, 1, -1 do
		local ok, alive = pcall(updaters[i], dt)
		if not ok or not alive then
			table.remove(updaters, i)
		end
	end
end)
local function onFrame(fn)
	updaters[#updaters + 1] = fn
end

local function tex(name)
	local id = VfxIds[name]
	return (type(id) == "number" and id > 0) and ("rbxassetid://" .. id) or nil
end
FX.tex = tex

---------------------------------------------------------------------------
-- LAYERS
---------------------------------------------------------------------------
-- bright expanding flash (white core + coloured shell)
function FX.flash(pos, color, size, t)
	t = t or 0.18
	if not canSpend(2) then
		return
	end
	local shell = get("Ball", { Color = color, Size = Vector3.one * size * 0.4, CFrame = CFrame.new(pos), Transparency = 0.1 })
	local core = get("Ball", { Color = WHITE, Size = Vector3.one * size * 0.25, CFrame = CFrame.new(pos) })
	tween(shell, t, { Size = Vector3.one * size, Transparency = 1 })
	tween(core, t * 0.7, { Size = Vector3.one * size * 0.6, Transparency = 1 })
	release(shell, "Ball", t + 0.02)
	release(core, "Ball", t + 0.02)
end

-- anime impact spikes: thin neon needles shooting out, then thinning away
function FX.spikes(pos, color, n, len, t, flat, pure)
	n = Q(n)
	t = t or 0.22
	if not canSpend(n) then
		return
	end
	for i = 1, n do
		local yaw = (i / n) * math.pi * 2 + math.random() * 0.4
		local pitch = flat and (math.random() - 0.5) * 0.35 or (math.random() - 0.3) * 1.4
		local dir = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		local L = len * (0.6 + math.random() * 0.6)
		local w = math.max(0.12, len * 0.05)
		local p = get("Block", { Color = (not pure and i % 3 == 0) and WHITE or color, Size = Vector3.new(w, w, 0.2), CFrame = CFrame.lookAt(pos, pos + dir) })
		local endCf = CFrame.lookAt(pos + dir * L * 0.55, pos + dir * L * 2)
		tween(p, t * 0.45, { Size = Vector3.new(w, w, L), CFrame = endCf }, Enum.EasingStyle.Quart)
		task.delay(t * 0.45, function()
			tween(p, t * 0.55, { Size = Vector3.new(0.02, 0.02, L * 1.2), CFrame = endCf * CFrame.new(0, 0, -L * 0.25), Transparency = 1 })
		end)
		release(p, "Block", t + 0.05)
	end
end

-- flat shockwave ring built from segments (works without textures)
function FX.ring(pos, color, r0, r1, t, thick, up)
	t = t or 0.35
	thick = thick or 0.5
	local n = Q(18)
	if not canSpend(n) then
		return
	end
	up = up or Vector3.yAxis
	local base = CFrame.lookAt(pos, pos + up) * CFrame.Angles(math.pi / 2, 0, 0) -- Y axis = ring normal
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local seg = (2 * math.pi * r0 / n) * 1.15
		local cf0 = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r0)
		local cf1 = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r1)
		local p = get("Block", { Color = i % 2 == 0 and color or color:Lerp(WHITE, 0.35), Size = Vector3.new(seg, thick * 0.5, thick), CFrame = cf0, Transparency = 0.05 })
		tween(p, t, { CFrame = cf1, Size = Vector3.new((2 * math.pi * r1 / n) * 1.15, 0.05, thick * 0.3), Transparency = 1 })
		release(p, "Block", t + 0.02)
	end
end

-- textured ground ring (uses the inked ring texture when uploaded, else segments)
function FX.groundRing(pos, color, r0, r1, t)
	local id = tex("ringhatch") or tex("ring")
	if not id or not canSpend(1) then
		return FX.ring(pos, color, r0, r1, t, 0.6)
	end
	local p = get("Block", { Transparency = 1, Size = Vector3.new(r0 * 2, 0.05, r0 * 2), CFrame = CFrame.new(pos) })
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = id
	d.Color3 = color
	d.Parent = p
	tween(p, t, { Size = Vector3.new(r1 * 2, 0.05, r1 * 2) })
	tween(d, t, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	release(p, "Block", t + 0.05)
end

-- ballistic chunks (paper scraps / ice / embers / leaves) with gravity + spin
function FX.shards(pos, color, n, speed, opts)
	opts = opts or {}
	n = Q(n)
	if not canSpend(n) then
		return
	end
	local life = opts.life or 0.8
	for _ = 1, n do
		local s = (opts.size or 0.6) * (0.6 + math.random() * 0.8)
		local p = get("Block", { Color = (math.random() < 0.3) and WHITE or color, Material = opts.material or Enum.Material.Neon, Size = opts.flat and Vector3.new(s, 0.08, s * 0.7) or Vector3.one * s, CFrame = CFrame.new(pos) })
		local a = math.random() * math.pi * 2
		local up = opts.up or 0.9
		local v = Vector3.new(math.cos(a), up * (0.4 + math.random() * 0.8), math.sin(a)) * speed * (0.5 + math.random() * 0.7)
		local rot = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 16
		local t0, x, ang = 0, pos, Vector3.zero
		local g = opts.gravity or 60
		onFrame(function(dt)
			t0 += dt
			v += Vector3.new(0, -g * dt, 0)
			if opts.drag then
				v *= (1 - math.min(1, opts.drag * dt))
			end
			x += v * dt
			ang += rot * dt
			p.CFrame = CFrame.new(x) * CFrame.Angles(ang.X, ang.Y, ang.Z)
			local k = t0 / life
			p.Transparency = k > 0.6 and (k - 0.6) / 0.4 or 0
			if k >= 1 then
				release(p, "Block")
				return false
			end
			return true
		end)
	end
end

-- cartoon smoke: soft puffs that swell, drift and fade
function FX.puffs(pos, color, n, size, t)
	n = Q(n)
	t = t or 0.7
	if not canSpend(n) then
		return
	end
	for _ = 1, n do
		local off = Vector3.new(math.random() - 0.5, math.random() * 0.4, math.random() - 0.5) * size * 1.4
		local p = get("Ball", { Color = color, Material = Enum.Material.SmoothPlastic, Size = Vector3.one * size * 0.4, CFrame = CFrame.new(pos + off * 0.3), Transparency = 0.15 })
		tween(p, t, { Size = Vector3.one * size * (0.9 + math.random() * 0.5), CFrame = CFrame.new(pos + off + Vector3.new(0, size * 0.6, 0)), Transparency = 1 }, Enum.EasingStyle.Quad)
		release(p, "Ball", t + 0.02)
	end
end

-- inked particle burst (needs uploaded textures; silently skipped otherwise)
local emitterPool = {}
function FX.emit(pos, texName, color, count, opts)
	local id = tex(texName)
	if not id then
		return false
	end
	opts = opts or {}
	count = Q(count)
	local p = get("Block", { Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos) })
	local e = table.remove(emitterPool) or Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = id
	e.Color = ColorSequence.new(color)
	e.LightEmission = opts.glow or 0.15
	e.LightInfluence = 0
	e.Size = opts.sizeSeq or NumberSequence.new({ NumberSequenceKeypoint.new(0, (opts.size or 1.5) * 0.6), NumberSequenceKeypoint.new(0.2, opts.size or 1.5), NumberSequenceKeypoint.new(1, (opts.size or 1.5) * (opts.endScale or 0.2)) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(opts.life or 0.45, (opts.life or 0.45) * 1.5)
	e.Speed = NumberRange.new((opts.speed or 20) * 0.5, opts.speed or 20)
	e.SpreadAngle = Vector2.new(opts.spread or 180, opts.spread or 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(opts.spin or 180), opts.spin or 180)
	e.Drag = opts.drag or 4
	e.Acceleration = opts.accel or Vector3.new(0, -10, 0)
	e.Orientation = opts.velocityAligned and Enum.ParticleOrientation.VelocityParallel or Enum.ParticleOrientation.FacingCamera
	e.EmissionDirection = opts.dir or Enum.NormalId.Top
	e.ZOffset = opts.z or 0.5
	if opts.flipbook then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	else
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	end
	e.Parent = p
	e:Emit(count)
	local life = (opts.life or 0.45) * 1.5 + 0.1
	task.delay(life, function()
		e.Parent = nil
		if #emitterPool < 60 then
			emitterPool[#emitterPool + 1] = e
		else
			e:Destroy()
		end
	end)
	release(p, "Block", life + 0.05)
	return true
end

-- ground splat decal (inked texture) or a blob cluster fallback
function FX.splat(pos, color, size, life)
	do
		return -- v1.8f: no more flat ground squares anywhere
	end
	life = life or 4
	if not canSpend(1) then
		return
	end
	local id = tex("splat" .. math.random(1, 4))
	local p = get("Block", { Transparency = 1, Size = Vector3.new(size * 2, 0.05, size * 2), CFrame = CFrame.new(pos) * CFrame.Angles(0, math.random() * 6.28, 0) })
	if id then
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = id
		d.Color3 = color
		d.Parent = p
		p.Size = Vector3.new(size * 0.5, 0.05, size * 0.5)
		tween(p, 0.12, { Size = Vector3.new(size * 2, 0.05, size * 2) }, Enum.EasingStyle.Back)
		task.delay(life, function()
			tween(d, 1, { Transparency = 1 })
		end)
	else
		p.Transparency = 0.2
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color:Lerp(INK, 0.4)
		p.Shape = Enum.PartType.Block
		p.Size = Vector3.new(size * 1.4, 0.05, size * 1.1)
		task.delay(life, function()
			tween(p, 1, { Transparency = 1 })
		end)
	end
	release(p, "Block", life + 1.05)
end

function FX.light(pos, color, range, t)
	if mobile() or not canSpend(1) then
		return
	end
	local p = get("Block", { Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos) })
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 4
	l.Shadows = false
	l.Parent = p
	tween(l, t or 0.3, { Brightness = 0 })
	release(p, "Block", (t or 0.3) + 0.05)
end

-- comic word ("POW!", "SLASH!") on a spiky burst
local lastWord = 0
function FX.word(pos, text, color, size)
	if os.clock() - lastWord < 0.25 then
		return
	end
	lastWord = os.clock()
	local p = get("Block", { Transparency = 1, Size = Vector3.one * 0.2, CFrame = CFrame.new(pos) })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 150, (size or 150) * 0.6)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = p
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = math.random(-14, 14)
	holder.Parent = bb
	local burstId = tex("burst")
	if burstId then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = burstId
		img.ImageColor3 = color
		img.Size = UDim2.fromScale(1.1, 1.5)
		img.Position = UDim2.fromScale(-0.05, -0.25)
		img.Parent = holder
	end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = burstId and WHITE or color
	l.Parent = holder
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = INK
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = holder
	tween(sc, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		tween(sc, 0.2, { Scale = 0.6 })
		tween(l, 0.2, { TextTransparency = 1 })
		tween(st, 0.2, { Transparency = 1 })
		for _, c in ipairs(holder:GetChildren()) do
			if c:IsA("ImageLabel") then
				tween(c, 0.2, { ImageTransparency = 1 })
			end
		end
	end)
	release(p, "Block", 0.7)
end

-- jagged lightning between two points (+ branches)
function FX.bolt(a, b, color, width, t)
	t = t or 0.22
	width = width or 0.5
	local segs = Q(9) + 2
	if not canSpend(segs * 2 + 4) then
		return
	end
	local pts = { a }
	local dir = b - a
	local side = dir:Cross(Vector3.yAxis)
	side = side.Magnitude > 0.01 and side.Unit or Vector3.xAxis
	local up = dir:Cross(side)
	up = up.Magnitude > 0.01 and up.Unit or Vector3.yAxis
	for i = 1, segs - 1 do
		local k = i / segs
		local amp = dir.Magnitude * 0.08 * math.sin(k * math.pi)
		pts[#pts + 1] = a + dir * k + side * (math.random() - 0.5) * 2 * amp + up * (math.random() - 0.5) * 2 * amp
	end
	pts[#pts + 1] = b
	local function line(p0, p1, w, col)
		local L = (p1 - p0).Magnitude
		local p = get("Block", { Color = col, Size = Vector3.new(w, w, L), CFrame = CFrame.lookAt((p0 + p1) / 2, p1) })
		task.delay(t * 0.5, function()
			tween(p, t * 0.5, { Transparency = 1, Size = Vector3.new(w * 0.2, w * 0.2, L) })
		end)
		release(p, "Block", t + 0.02)
	end
	for i = 1, #pts - 1 do
		line(pts[i], pts[i + 1], width * 2.2, color)
		line(pts[i], pts[i + 1], width, WHITE)
		if i > 1 and math.random() < 0.3 then -- branch
			local e = pts[i] + (side * (math.random() - 0.5) + up * (math.random() - 0.5) + dir.Unit * 0.5).Unit * dir.Magnitude * 0.18
			line(pts[i], e, width * 1.2, color)
		end
	end
end

-- moving projectile with a shrinking trail of blobs
function FX.projectile(from, to, color, speed, size, onArrive, arc, el)
	if not canSpend(6) then
		if onArrive then
			onArrive()
		end
		return
	end
	local dist = (to - from).Magnitude
	local dur = math.clamp(dist / speed, 0.08, 1.2)
	local headCol = el and HEAD_COLOR[el] or WHITE
	local head = get("Ball", { Color = headCol, Size = Vector3.one * size, CFrame = CFrame.new(from) })
	if el then
		FX.trail(from, to, dur, el, size, arc)
	end
	local shell = get("Ball", { Color = color, Size = Vector3.one * size * 1.7, CFrame = CFrame.new(from), Transparency = 0.35 })
	local trailN = mobile() and 3 or 6
	local trail = {}
	for i = 1, trailN do
		trail[i] = get("Ball", { Color = color, Size = Vector3.one * size * (1.4 - i * 0.18), CFrame = CFrame.new(from), Transparency = 0.2 + i * 0.12 })
	end
	local hist = {}
	local t0 = 0
	onFrame(function(dt)
		t0 += dt
		local k = math.min(1, t0 / dur)
		local p = from:Lerp(to, k)
		if arc then
			p += Vector3.new(0, math.sin(k * math.pi) * arc, 0)
		end
		head.CFrame = CFrame.new(p)
		shell.CFrame = CFrame.new(p)
		table.insert(hist, 1, p)
		for i, tp in ipairs(trail) do
			tp.CFrame = CFrame.new(hist[math.min(#hist, i * 2)] or p)
		end
		if k >= 1 then
			release(head, "Ball")
			release(shell, "Ball")
			for _, tp in ipairs(trail) do
				release(tp, "Ball")
			end
			if onArrive then
				onArrive()
			end
			return false
		end
		return true
	end)
end

---------------------------------------------------------------------------
-- v9.8 ELEMENT IDENTITY: every element owns its wind-up, trail and impact shape
---------------------------------------------------------------------------
-- (HEAD_COLOR is declared near the top so FX.projectile can see it)
local TRAIL = {
	Fire = function(p, s) -- embers that fall and fade + a little smoke
		FX.shards(p, Color3.fromRGB(255, 150 + math.random(0, 60), 40), 1, 4 * s, { size = 0.3 * s, gravity = -10, life = 0.45 })
		if math.random() < 0.35 then
			FX.puffs(p, Color3.fromRGB(80, 60, 60), 1, 1.2 * s, 0.5)
		end
	end,
	Frost = function(p, s) -- cold mist + tiny glinting ice flecks
		FX.puffs(p, Color3.fromRGB(215, 240, 255), 1, 1.4 * s, 0.45)
		if math.random() < 0.5 then
			FX.shards(p, Color3.fromRGB(190, 235, 255), 1, 2 * s, { size = 0.35 * s, material = Enum.Material.Glass, gravity = 6, life = 0.5 })
		end
	end,
	Storm = function(p, s, prev) -- crackling arcs between trail points
		if prev and math.random() < 0.7 then
			local jig = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * s
			FX.bolt(prev, p + jig, Color3.fromRGB(255, 240, 120), 0.12 * s, 0.12)
		end
	end,
	Void = function(p, s) -- dark smoke that lingers
		FX.puffs(p, Color3.fromRGB(35, 18, 60), 1, 1.8 * s, 0.7)
	end,
	Nature = function(p, s) -- leaves shed in flight
		if not FX.emit(p, "leaf", Color3.fromRGB(110, 220, 90), 1, { size = 0.9 * s, life = 0.8, speed = 3, accel = Vector3.new(0, -5, 0), drag = 2, spin = 240 }) then
			FX.shards(p, Color3.fromRGB(90, 200, 80), 1, 3 * s, { size = 0.35 * s, flat = true, gravity = 8, life = 0.6 })
		end
	end,
	Holy = function(p, s) -- golden sparkles
		if not FX.emit(p, "star4", Color3.fromRGB(255, 230, 150), 1, { size = 0.9 * s, life = 0.5, speed = 1, spin = 90, glow = 0.8 }) then
			FX.shards(p, Color3.fromRGB(255, 225, 140), 1, 2 * s, { size = 0.3 * s, gravity = -4, life = 0.4 })
		end
	end,
}
function FX.trail(from, to, dur, el, size, arc)
	local f = TRAIL[el]
	if not f then
		return
	end
	local step = mobile() and 0.07 or 0.035
	local t0, acc, prev = 0, 0, nil
	local s = math.clamp((size or 0.6) * 1.4, 0.6, 2)
	onFrame(function(dt)
		t0 += dt
		acc += dt
		local k = math.min(1, t0 / dur)
		if acc >= step then
			acc = 0
			local p = from:Lerp(to, k)
			if arc then
				p += Vector3.new(0, math.sin(k * math.pi) * arc, 0)
			end
			f(p, s, prev)
			prev = p
		end
		return k < 1
	end)
end
-- wind-up: element energy gathers at the muzzle for a beat before the shot leaves
local WINDUP = {
	Fire = { Color3.fromRGB(255, 140, 40), "flame_fb" },
	Frost = { Color3.fromRGB(190, 235, 255), "snow" },
	Storm = { Color3.fromRGB(255, 240, 120), "spark1" },
	Void = { Color3.fromRGB(120, 60, 200), "swirl" },
	Nature = { Color3.fromRGB(110, 220, 90), "leaf" },
	Holy = { Color3.fromRGB(255, 230, 160), "star4" },
}
function FX.windup(pos, el, s, t)
	local w = WINDUP[el]
	if not w or not canSpend(4) then
		return
	end
	t = t or 0.12
	s = s or 1
	local n = mobile() and 3 or 6
	for i = 1, n do
		local a = i / n * math.pi * 2
		local off = Vector3.new(math.cos(a), (math.random() - 0.5) * 0.8, math.sin(a)) * 2.4 * s
		local b = get("Ball", { Color = w[1], Size = Vector3.one * 0.35 * s, CFrame = CFrame.new(pos + off), Transparency = 0.1 })
		tween(b, t, { CFrame = CFrame.new(pos), Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		release(b, "Ball", t + 0.02)
	end
	local core = get("Ball", { Color = w[1], Size = Vector3.one * 0.2, CFrame = CFrame.new(pos), Transparency = 0.2 })
	tween(core, t, { Size = Vector3.one * 1.3 * s }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	release(core, "Ball", t + 0.02)
end
-- element impact SHAPE (replaces the generic neon needles when an element is present)
local IMPACT = {
	Fire = function(pos, s) -- a flat ring of flame licking outward + scorch
		FX.ring(pos - Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 120, 40), 0.4, 3.6 * s, 0.3, 0.5)
		FX.flash(pos, Color3.fromRGB(255, 170, 60), 2.8 * s, 0.14)
	end,
	Frost = function(pos, s) -- chunky ice crystals jut out + a cold mist bloom
		FX.spikes(pos, Color3.fromRGB(170, 225, 255), 5, 2.4 * s, 0.4, true, true)
		FX.puffs(pos, Color3.fromRGB(225, 245, 255), 3, 2 * s, 0.6)
	end,
	Storm = function(pos, s) -- a sharp yellow-white crack
		FX.flash(pos, Color3.fromRGB(255, 245, 160), 3.2 * s, 0.08)
	end,
	Void = function(pos, s) -- smoke curls sucked inward (the implosion is in the flourish)
		FX.puffs(pos, Color3.fromRGB(30, 15, 55), 3, 2.2 * s, 0.8)
	end,
	Nature = function(pos, s) -- thorns burst from the ground
		FX.spikes(pos - Vector3.new(0, 0.5, 0), Color3.fromRGB(60, 150, 50), 5, 2.8 * s, 0.35, true, true)
	end,
	Holy = function(pos, s) -- a clean golden halo ring
		FX.ring(pos, Color3.fromRGB(255, 225, 150), 0.3, 3 * s, 0.3, 0.35)
	end,
}

---------------------------------------------------------------------------
-- ELEMENT FLOURISHES (added on top of any impact)
---------------------------------------------------------------------------
local ELEMENT_FX = {
	Fire = function(pos, s)
		FX.emit(pos, "flame_fb", Color3.fromRGB(255, 140, 50), 6, { size = 2.2 * s, life = 0.5, speed = 8, accel = Vector3.new(0, 18, 0), flipbook = true, glow = 0.5, spin = 30 })
		FX.shards(pos, Color3.fromRGB(255, 170, 60), 8, 22 * s, { size = 0.35, gravity = -8, drag = 2, life = 0.7 })
		FX.puffs(pos + Vector3.new(0, 1, 0), Color3.fromRGB(70, 60, 70), 3, 2.6 * s, 0.9)
	end,
	Frost = function(pos, s)
		FX.shards(pos, Color3.fromRGB(200, 240, 255), 10, 26 * s, { size = 0.7, material = Enum.Material.Glass, life = 0.8 })
		FX.emit(pos, "snow", Color3.fromRGB(220, 245, 255), 8, { size = 1.2 * s, life = 0.9, speed = 10, accel = Vector3.new(0, -4, 0), spin = 60 })
		FX.emit(pos, "shard", Color3.fromRGB(150, 220, 255), 6, { size = 1.6 * s, life = 0.4, speed = 22, velocityAligned = true })
	end,
	Storm = function(pos, s)
		for _ = 1, (mobile() and 1 or 3) do
			local a = math.random() * math.pi * 2
			FX.bolt(pos, pos + Vector3.new(math.cos(a) * 7 * s, math.random() * 4, math.sin(a) * 7 * s), Color3.fromRGB(255, 230, 80), 0.25, 0.18)
		end
		FX.emit(pos, "spark1", Color3.fromRGB(255, 240, 120), 10, { size = 1.6 * s, life = 0.3, speed = 40, velocityAligned = true })
	end,
	Nature = function(pos, s)
		FX.emit(pos, "leaf", Color3.fromRGB(110, 220, 90), 8, { size = 1.2 * s, life = 1.0, speed = 14, accel = Vector3.new(0, -6, 0), drag = 3, spin = 240 })
		FX.shards(pos, Color3.fromRGB(80, 200, 80), 6, 18 * s, { size = 0.5, flat = true, gravity = 20, drag = 3, life = 1 })
	end,
	Void = function(pos, s)
		local core = get("Ball", { Color = Color3.fromRGB(20, 10, 40), Material = Enum.Material.SmoothPlastic, Size = Vector3.one * 5 * s, CFrame = CFrame.new(pos) })
		tween(core, 0.28, { Size = Vector3.one * 0.3, Transparency = 0.4 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		release(core, "Ball", 0.3)
		FX.emit(pos, "swirl", Color3.fromRGB(170, 90, 255), 3, { size = 5 * s, life = 0.4, speed = 0.1, spin = 720, glow = 0.4, endScale = 0.05 })
		task.delay(0.28, function()
			FX.flash(pos, Color3.fromRGB(170, 90, 255), 5 * s, 0.15)
		end)
	end,
	Holy = function(pos, s)
		FX.emit(pos, "rays", Color3.fromRGB(255, 240, 200), 1, { size = 9 * s, life = 0.35, speed = 0.1, spin = 60, glow = 1 })
		FX.emit(pos, "star4", Color3.fromRGB(255, 220, 240), 7, { size = 1.3 * s, life = 0.7, speed = 12, accel = Vector3.new(0, 8, 0), spin = 90, glow = 0.6 })
		local pillar = get("Cyl", { Color = Color3.fromRGB(255, 245, 210), Size = Vector3.new(14 * s, 0.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.3 })
		tween(pillar, 0.3, { Size = Vector3.new(14 * s, 0.05, 0.05), Transparency = 1 })
		release(pillar, "Cyl", 0.32)
	end,
}

---------------------------------------------------------------------------
-- COMPOSITE IMPACTS
---------------------------------------------------------------------------
-- standard hit: flash + spikes + inked sparks + element flourish
function FX.impact(pos, color, el, scale)
	scale = scale or 1
	color = color or (el and ELEMENT_COLOR[el]) or WHITE
	local shape = el and IMPACT[el]
	if shape then
		shape(pos, scale)
	else
		FX.flash(pos, color, 3.2 * scale, 0.14)
		FX.spikes(pos, color, 7, 3.2 * scale, 0.2)
	end
	if not FX.emit(pos, "spark2", color, 2, { size = 3 * scale, life = 0.18, speed = 0.1, spin = 0, glow = 0.3, endScale = 1.4 }) then
		FX.shards(pos, color, 4, 18 * scale, { size = 0.3, life = 0.35 })
	end
	FX.emit(pos, "spark1", color, 6, { size = 1.4 * scale, life = 0.25, speed = 34, velocityAligned = true })
	local f = el and ELEMENT_FX[el]
	if f then
		f(pos, scale)
	end
end

-- big explosion
function FX.explosion(pos, color, r, small, shake)
	local s = math.clamp(r / 8, 0.6, 3)
	FX.flash(pos, color, r * 1.2, 0.22)
	FX.flash(pos, WHITE, r * 0.6, 0.12)
	FX.spikes(pos, color, small and 8 or 14, r * 0.9, 0.3)
	FX.ring(pos - Vector3.new(0, 1, 0), color, r * 0.3, r * 1.3, 0.4, 0.8 * s)
	FX.groundRing(pos - Vector3.new(0, 1.2, 0), color, r * 0.4, r * 1.6, 0.5)
	FX.puffs(pos, color:Lerp(Color3.fromRGB(60, 55, 70), 0.55), small and 4 or 8, 3.5 * s, 0.9)
	FX.shards(pos, color, small and 6 or 12, 30 * s, { size = 0.5 * s, life = 0.9 })
	FX.emit(pos, "smoke_fb", color:Lerp(WHITE, 0.4), small and 3 or 6, { size = 5 * s, life = 0.7, speed = 10, flipbook = true, accel = Vector3.new(0, 6, 0), spin = 40 })
	FX.emit(pos, "spark1", color, small and 10 or 20, { size = 2 * s, life = 0.35, speed = 55, velocityAligned = true })
	FX.splat(pos - Vector3.new(0, 1.3, 0), color, r * 0.8, 3)
	FX.light(pos, color, r * 3, 0.35)
	if shake then
		shake(small and 0.25 or 0.6)
	end
end

-- brush crescent: segments appear along the arc in sequence (a real swing), white edge + coloured body
function FX.slash(pos, color, r, yaw, scale, tilt)
	scale = scale or 1
	local n = Q(14) + 4
	if not canSpend(n * 2) then
		return
	end
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, tilt or (math.random() - 0.5) * 0.9)
	local R = r * 0.85
	for i = 0, n - 1 do
		local k = i / (n - 1)
		local a = -1.35 + k * 2.7
		local thick = math.sin(k * math.pi) ^ 0.7
		local p0 = (base * CFrame.new(math.sin(a) * R, 0, math.cos(a) * R)).Position
		local p1 = (base * CFrame.new(math.sin(a + 2.7 / n) * R, 0, math.cos(a + 2.7 / n) * R)).Position
		local L = (p1 - p0).Magnitude * 1.25
		local w = (0.25 + 1.4 * thick) * scale
		task.delay(k * 0.07, function()
			local body = get("Block", { Color = color, Size = Vector3.new(w, 0.25, L), CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(-w * 0.3, 0, 0) })
			local edge = get("Block", { Color = WHITE, Size = Vector3.new(w * 0.35, 0.3, L), CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.new(w * 0.2, 0, 0) })
			tween(body, 0.28, { Transparency = 1, Size = Vector3.new(0.05, 0.1, L) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(edge, 0.2, { Transparency = 1, Size = Vector3.new(0.02, 0.05, L) })
			release(body, "Block", 0.3)
			release(edge, "Block", 0.22)
		end)
	end
	-- textured slash on top (if uploaded)
	FX.emit(pos, "slash", color, 1, { size = r * 2.2 * scale, life = 0.22, speed = 0.1, spin = 0, glow = 0.4, endScale = 1.2 })
end

---------------------------------------------------------------------------
-- HANDLER INSTALL: replaces the basic attack handlers in the main client
---------------------------------------------------------------------------
local function rs(d)
	return RARITY_SCALE[d.rar or ""] or 1
end
local function godlike(d)
	return d.rar == "GODLIKE" or d.rar == "Mythic"
end

function FX.install(handlers, hooks)
	hooks = hooks or {}
	local shake = hooks.shake or function() end
	FX.shake = shake -- v9.4: other scripts (UltClient) reuse the camera shake
	local play = hooks.play or function() end
	local orig = {}
	for k, v in pairs(handlers) do
		orig[k] = v
	end

	handlers.Shot = function(d)
		local s = rs(d)
		local col = d.color or WHITE
		local big = d.big
		local function fire()
			FX.flash(d.from, col, (big and 3 or 1.8) * s, 0.12) -- muzzle
			FX.projectile(d.from, d.to, col, big and 120 or 170, (big and 0.9 or 0.55) * s, function()
				FX.impact(d.to, col, d.el, (big and 1.1 or 0.75) * s)
				if godlike(d) then
					FX.spikes(d.to, d.el and col or WHITE, 10, 6 * s, 0.25, false, d.el ~= nil)
					FX.light(d.to, col, 18, 0.25)
				end
			end, nil, d.el)
		end
		if d.el and WINDUP[d.el] then
			FX.windup(d.from, d.el, (big and 1.2 or 0.8) * s, 0.09)
			task.delay(0.09, fire)
		else
			fire()
		end
	end

	handlers.Arrow = function(d)
		play("Draw", 2, 0.3)
		local s = rs(d)
		local col = d.color or WHITE
		local dir = (d.to - d.from)
		if dir.Magnitude < 0.1 then
			return
		end
		local arrow = get("Block", { Color = d.el and HEAD_COLOR[d.el] or WHITE, Size = Vector3.new(0.25, 0.25, 3.2 * s), CFrame = CFrame.lookAt(d.from, d.to) })
		local glow = get("Block", { Color = col, Size = Vector3.new(0.6, 0.6, 5 * s), CFrame = CFrame.lookAt(d.from, d.to), Transparency = 0.45 })
		local dur = math.clamp(dir.Magnitude / 220, 0.06, 0.4)
		if d.el then
			FX.trail(d.from, d.to, dur, d.el, 0.6 * s)
		end
		tween(arrow, dur, { CFrame = CFrame.lookAt(d.to, d.to + dir) }, Enum.EasingStyle.Linear)
		tween(glow, dur, { CFrame = CFrame.lookAt(d.to - dir.Unit * 1.5, d.to + dir) }, Enum.EasingStyle.Linear)
		release(arrow, "Block", dur)
		release(glow, "Block", dur)
		task.delay(dur, function()
			FX.impact(d.to, col, d.el, 0.8 * s)
			FX.spikes(d.to, col, 4, 5 * s, 0.18, true, d.el ~= nil) -- pierce streaks
		end)
	end

	handlers.Lob = function(d)
		local s = rs(d)
		local col = d.color or WHITE
		FX.projectile(d.from, d.to, col, (d.to - d.from).Magnitude / (d.t or 0.6), 1.1 * s, nil, 10, d.el)
	end

	handlers.Blast = function(d)
		FX.explosion(d.pos, d.color or Color3.fromRGB(255, 120, 50), d.r or 8, d.small, shake)
	end

	handlers.Meteor = function(d)
		local col = d.color or Color3.fromRGB(255, 120, 40)
		local from = d.to + Vector3.new(18, 70, 12)
		local rock = get("Ball", { Color = Color3.fromRGB(60, 45, 60), Material = Enum.Material.SmoothPlastic, Size = Vector3.one * 5, CFrame = CFrame.new(from) })
		local fire = get("Ball", { Color = col, Size = Vector3.one * 7.5, CFrame = CFrame.new(from), Transparency = 0.3 })
		local t0, dur = 0, 0.55
		onFrame(function(dt)
			t0 += dt
			local k = math.min(1, t0 / dur)
			local p = from:Lerp(d.to, k * k)
			rock.CFrame = CFrame.new(p)
			fire.CFrame = CFrame.new(p)
			if math.random() < 0.6 then
				FX.puffs(p, col, 1, 3, 0.35)
			end
			if k >= 1 then
				release(rock, "Ball")
				release(fire, "Ball")
				FX.explosion(d.to, col, 14, false, shake)
				FX.splat(d.to - Vector3.new(0, 1.3, 0), Color3.fromRGB(40, 30, 40), 10, 5)
				return false
			end
			return true
		end)
	end

	handlers.Slash = function(d)
		play("Hit", 0.8, 0.5)
		shake(0.2)
		local s = rs(d)
		local col = d.color or WHITE
		FX.slash(d.pos, col, math.max(d.r or 5, 4), d.yaw or 0, s)
		task.delay(0.08, function()
			FX.impact(d.pos, col, d.el, 0.8 * s)
			if godlike(d) then
				FX.slash(d.pos + Vector3.new(0, 0.6, 0), WHITE, math.max(d.r or 5, 4) * 1.2, (d.yaw or 0) + 0.3, s * 0.7, 0.5)
				FX.light(d.pos, col, 16, 0.25)
			end
		end)
	end

	handlers.Punch = function(d)
		play("Hit", 1.1 + math.random() * 0.3, 0.4)
		local s = rs(d)
		local col = d.color or Color3.fromRGB(255, 230, 120)
		local up = d.from and (d.pos - (d.from + Vector3.new(0, 1, 0))) or Vector3.zAxis
		up = up.Magnitude > 0.1 and up.Unit or Vector3.zAxis
		FX.flash(d.pos, col, 3.5 * s, 0.12)
		FX.ring(d.pos, col, 0.6, 4.5 * s, 0.22, 0.45, up) -- impact ring facing the punch
		if d.el and IMPACT[d.el] then
			IMPACT[d.el](d.pos, 0.9 * s)
		else
			FX.spikes(d.pos, WHITE, 6, 3.5 * s, 0.18)
		end
		FX.puffs(d.pos - Vector3.new(0, 1, 0), Color3.fromRGB(235, 225, 210), 3, 1.8 * s, 0.5)
		if d.el and ELEMENT_FX[d.el] then
			ELEMENT_FX[d.el](d.pos, 0.8 * s)
		end
		if godlike(d) or math.random() < 0.12 then
			local words = { "POW!", "BAM!", "WHAM!", "BONK!" }
			FX.word(d.pos + Vector3.new(0, 3, 0), words[math.random(#words)], col, 130)
		end
	end

	handlers.Lightning = function(d)
		local chain = d.chain or {}
		local col = d.color or ELEMENT_COLOR.Storm
		for i = 1, #chain - 1 do
			task.delay((i - 1) * 0.05, function()
				FX.bolt(chain[i], chain[i + 1], col, 0.45, 0.25)
				FX.bolt(chain[i], chain[i + 1], col, 0.2, 0.18)
				FX.impact(chain[i + 1], col, "Storm", 0.8)
			end)
		end
		FX.light(chain[1] or Vector3.zero, col, 24, 0.2)
	end

	handlers.Beam = function(d)
		play("Collect", 1.8, 0.3)
		local col = d.color or Color3.fromRGB(255, 245, 190)
		local pos = d.pos
		local pillar = get("Cyl", { Color = col, Size = Vector3.new(80, 5, 5), CFrame = CFrame.new(pos + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.2 })
		local core = get("Cyl", { Color = WHITE, Size = Vector3.new(80, 2, 2), CFrame = pillar.CFrame })
		tween(pillar, 0.5, { Size = Vector3.new(80, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(core, 0.35, { Size = Vector3.new(80, 0.05, 0.05), Transparency = 1 })
		release(pillar, "Cyl", 0.52)
		release(core, "Cyl", 0.37)
		FX.ring(pos - Vector3.new(0, 0.8, 0), col, 1, 9, 0.45, 0.6)
		FX.impact(pos, col, "Holy", 1.1)
	end

	handlers.Breath = function(d)
		play("Splat", 1.6, 0.4)
		local col = d.color or Color3.fromRGB(255, 120, 40)
		local dir = d.dir or Vector3.zAxis
		local n = Q(12)
		for i = 1, n do
			task.delay(i * 0.025, function()
				local k = i / n
				local p = d.from + dir * k * (d.len or 20) + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * k * 3
				FX.puffs(p, i % 3 == 0 and WHITE or col, 1, 1.2 + k * 3.4, 0.4)
			end)
		end
		FX.emit(d.from, "flame_fb", col, 10, { size = 3, life = 0.5, speed = 40, spread = 14, dir = Enum.NormalId.Front, flipbook = true, glow = 0.6, spin = 60 })
		task.delay(0.3, function()
			FX.impact(d.from + dir * (d.len or 20), col, "Fire", 1)
		end)
	end

	handlers.Freeze = function(d)
		local s = (d.size or 3) * 0.5
		local n = Q(7)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local base = d.pos + Vector3.new(math.cos(a) * s, -1, math.sin(a) * s)
			local tip = base + Vector3.new(math.cos(a) * s * 0.6, s * 2.2, math.sin(a) * s * 0.6)
			local L = (tip - base).Magnitude
			local p = get("Block", { Color = Color3.fromRGB(190, 235, 255), Material = Enum.Material.Glass, Transparency = 0.2, Size = Vector3.new(0.9, 0.9, 0.1), CFrame = CFrame.lookAt(base, tip) })
			tween(p, 0.15, { Size = Vector3.new(0.9, 0.9, L), CFrame = CFrame.lookAt((base + tip) / 2, tip) }, Enum.EasingStyle.Back)
			task.delay(0.9, function()
				tween(p, 0.15, { Transparency = 1 })
				FX.shards((base + tip) / 2, Color3.fromRGB(200, 240, 255), 2, 16, { size = 0.5, material = Enum.Material.Glass, life = 0.6 })
			end)
			release(p, "Block", 1.1)
		end
		FX.ring(d.pos - Vector3.new(0, 1, 0), Color3.fromRGB(170, 225, 255), 0.5, s * 3, 0.35, 0.5)
		ELEMENT_FX.Frost(d.pos, 1)
	end

	local function vortex(d, dark)
		local col = d.color or ELEMENT_COLOR.Void
		local r, life = d.r or 8, d.life or 2
		local core = get("Ball", { Color = dark and Color3.fromRGB(12, 6, 24) or col, Material = dark and Enum.Material.SmoothPlastic or Enum.Material.Neon, Size = Vector3.one * 0.5, CFrame = CFrame.new(d.pos) })
		tween(core, 0.3, { Size = Vector3.one * r * 0.45 }, Enum.EasingStyle.Back)
		local n = Q(16)
		local bits = {}
		for i = 1, n do
			bits[i] = { p = get("Block", { Color = i % 3 == 0 and WHITE or col, Size = Vector3.new(0.3, 0.3, 1.6) }), a = i / n * math.pi * 2, rr = r * (0.5 + math.random() * 0.6), y = (math.random() - 0.5) * 2 }
		end
		local t0 = 0
		onFrame(function(dt)
			t0 += dt
			for _, b in ipairs(bits) do
				b.a += dt * (5 + 12 / math.max(b.rr, 0.5))
				b.rr = math.max(0.3, b.rr - dt * r * 0.35)
				if b.rr <= 0.4 then
					b.rr = r * (0.8 + math.random() * 0.3)
				end
				local p = d.pos + Vector3.new(math.cos(b.a) * b.rr, b.y, math.sin(b.a) * b.rr)
				b.p.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(b.a), 0, math.cos(b.a)))
			end
			if t0 >= life then
				for _, b in ipairs(bits) do
					release(b.p, "Block")
				end
				tween(core, 0.18, { Size = Vector3.one * 0.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				release(core, "Ball", 0.2)
				task.delay(0.18, function()
					FX.flash(d.pos, col, r * 0.9, 0.2)
					FX.spikes(d.pos, col, 10, r * 0.8, 0.25)
					shake(0.3)
				end)
				return false
			end
			return true
		end)
		FX.emit(d.pos, "swirl", col, 2, { size = r * 1.6, life = life, speed = 0.1, spin = 400, glow = 0.5, endScale = 0.1 })
	end
	handlers.Vortex = function(d)
		vortex(d, false)
	end
	handlers.BlackHole = function(d)
		vortex(d, true)
	end

	handlers.Heal = function(d)
		local col = Color3.fromRGB(120, 255, 140)
		FX.ring(d.pos - Vector3.new(0, 0.8, 0), col, 1, d.r or 8, 0.5, 0.5)
		local n = Q(8)
		for i = 1, n do
			local p0 = d.pos + Vector3.new((math.random() - 0.5) * 6, 0, (math.random() - 0.5) * 6)
			local plusA = get("Block", { Color = col, Size = Vector3.new(0.9, 0.25, 0.25), CFrame = CFrame.new(p0) })
			local plusB = get("Block", { Color = col, Size = Vector3.new(0.25, 0.9, 0.25), CFrame = CFrame.new(p0) })
			for _, pp in ipairs({ plusA, plusB }) do
				tween(pp, 0.8, { CFrame = CFrame.new(p0 + Vector3.new(0, 5 + i * 0.3, 0)), Transparency = 1 })
				release(pp, "Block", 0.82)
			end
		end
		FX.emit(d.pos, "star4", col, 6, { size = 1.2, life = 0.8, speed = 8, accel = Vector3.new(0, 10, 0), glow = 0.6 })
	end

	handlers.AuraPulse = function(d)
		FX.ring(d.pos - Vector3.new(0, 0.5, 0), d.color or WHITE, 1, d.r or 8, 0.45, 0.4)
		FX.groundRing(d.pos - Vector3.new(0, 0.9, 0), d.color or WHITE, 1, d.r or 8, 0.5)
	end

	-------------------------------------------------------------------
	-- v9.2 PEN POWERS
	-------------------------------------------------------------------
	-- Colored Pencil: thorny bramble patch that grows out of the ground, then withers
	handlers.Thorns = function(d)
		local n = Q(9)
		local green = Color3.fromRGB(70, 170, 70)
		for i = 1, n do
			local a = i / n * math.pi * 2 + math.random() * 0.5
			local rr = (d.r or 6) * (0.3 + math.random() * 0.65)
			local base = d.pos + Vector3.new(math.cos(a) * rr, -1.2, math.sin(a) * rr)
			local tip = base + Vector3.new((math.random() - 0.5) * 1.2, 1.6 + math.random() * 1.4, (math.random() - 0.5) * 1.2)
			local L = (tip - base).Magnitude
			local p = get("Block", { Color = i % 3 == 0 and Color3.fromRGB(150, 90, 50) or green, Material = Enum.Material.Fabric, Size = Vector3.new(0.35, 0.35, 0.1), CFrame = CFrame.lookAt(base, tip) })
			tween(p, 0.22, { Size = Vector3.new(0.35, 0.35, L), CFrame = CFrame.lookAt((base + tip) / 2, tip) }, Enum.EasingStyle.Back)
			task.delay((d.life or 3) - 0.3, function()
				tween(p, 0.3, { Size = Vector3.new(0.05, 0.05, L * 0.3), Transparency = 1 })
			end)
			release(p, "Block", (d.life or 3) + 0.05)
		end
		FX.emit(d.pos, "leaf", Color3.fromRGB(110, 210, 90), 5, { size = 1, life = 0.8, speed = 8, spin = 200 })
	end

	-- Airbrush: a drifting spray cloud that lingers
	handlers.Mist = function(d)
		local col = d.color or Color3.fromRGB(150, 230, 150)
		local r, life = d.r or 7, d.life or 3
		local n = Q(7)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local off = Vector3.new(math.cos(a) * r * 0.5 * math.random(), 0.5 + math.random(), math.sin(a) * r * 0.5 * math.random())
			local p = get("Ball", { Color = col:Lerp(WHITE, 0.35), Material = Enum.Material.SmoothPlastic, Size = Vector3.one * 1.5, CFrame = CFrame.new(d.pos + off), Transparency = 0.5 })
			tween(p, 0.5, { Size = Vector3.one * r * (0.55 + math.random() * 0.3) })
			tween(p, life, { CFrame = CFrame.new(d.pos + off + Vector3.new(0, 1.2, 0)) }, Enum.EasingStyle.Sine)
			task.delay(life - 0.6, function()
				tween(p, 0.6, { Transparency = 1 })
			end)
			release(p, "Ball", life + 0.05)
		end
		FX.emit(d.pos, "smoke_fb", col, 4, { size = r * 0.9, life = life * 0.6, speed = 1.5, flipbook = true, accel = Vector3.new(0, 1, 0), spin = 20 })
		FX.emit(d.pos, "drop", col, 6, { size = 0.6, life = 0.5, speed = 12, velocityAligned = true })
	end

	-- Calligraphy Brush: a glowing rune circle writes itself on the ground, then detonates
	handlers.Glyph = function(d)
		local col = d.color or Color3.fromRGB(255, 210, 110)
		local gold = Color3.fromRGB(255, 220, 120)
		local r = d.r or 9
		local base = d.pos - Vector3.new(0, 1.1, 0)
		local n = Q(10) + 4
		local strokes = {}
		for i = 1, n do -- outer circle written stroke by stroke
			local a0, a1 = (i - 1) / n * math.pi * 2, i / n * math.pi * 2
			local p0 = base + Vector3.new(math.cos(a0) * r * 0.8, 0, math.sin(a0) * r * 0.8)
			local p1 = base + Vector3.new(math.cos(a1) * r * 0.8, 0, math.sin(a1) * r * 0.8)
			strokes[#strokes + 1] = { p0, p1 }
		end
		for k = 0, 2 do -- inner triangle rune
			local a0, a1 = k / 3 * math.pi * 2, (k + 1) / 3 * math.pi * 2
			strokes[#strokes + 1] = { base + Vector3.new(math.cos(a0) * r * 0.62, 0, math.sin(a0) * r * 0.62), base + Vector3.new(math.cos(a1) * r * 0.62, 0, math.sin(a1) * r * 0.62) }
		end
		for i, sg in ipairs(strokes) do
			task.delay(i * 0.012, function()
				local L = (sg[2] - sg[1]).Magnitude
				local p = get("Block", { Color = i % 2 == 0 and gold or col, Size = Vector3.new(0.35, 0.12, L + 0.3), CFrame = CFrame.lookAt((sg[1] + sg[2]) / 2, sg[2]) })
				task.delay(0.35, function()
					tween(p, 0.25, { Transparency = 1, Size = Vector3.new(0.05, 0.05, L) })
				end)
				release(p, "Block", 0.62)
			end)
		end
		task.delay(0.3, function()
			FX.flash(d.pos, gold, r * 0.9, 0.18)
			FX.spikes(d.pos, gold, 10, r * 0.7, 0.25, true)
			FX.ring(base + Vector3.new(0, 0.2, 0), col, r * 0.3, r * 1.2, 0.35, 0.5)
			FX.emit(d.pos, "star4", gold, 8, { size = 1.4, life = 0.6, speed = 18, glow = 0.7 })
			FX.word(d.pos + Vector3.new(0, 3, 0), "STUN!", gold, 110)
			shake(0.12)
		end)
	end

	-- Watercolor: liquid ribbons arc from the target to its neighbours
	handlers.Flow = function(d)
		local col = d.color or Color3.fromRGB(120, 180, 255)
		for i, to in ipairs(d.to or {}) do
			task.delay((i - 1) * 0.06, function()
				FX.projectile(d.from, to, col:Lerp(WHITE, 0.2), 90, 0.5, function()
					FX.puffs(to, col:Lerp(WHITE, 0.3), 2, 1.4, 0.4)
					FX.emit(to, "drop", col, 5, { size = 0.6, life = 0.45, speed = 14, velocityAligned = true })
					FX.splat(to - Vector3.new(0, 1.3, 0), col, 1.6, 1.5)
				end, 3)
			end)
		end
	end

	-- Chalk: dusty puff that hangs in the air
	handlers.Dust = function(d)
		FX.puffs(d.pos, Color3.fromRGB(240, 238, 230), 3, 2, 0.8)
		FX.shards(d.pos, Color3.fromRGB(250, 250, 245), 4, 8, { size = 0.2, gravity = 4, drag = 3, life = 0.8, material = Enum.Material.SmoothPlastic })
	end

	-- keep the original hit (damage numbers / sounds) and add a small element spark
	local origHit = orig.Hit
	local hitN = 0
	handlers.Hit = function(d)
		if origHit then
			origHit(d)
		end
		hitN += 1
		if d.pos and (d.by == player or not mobile() or hitN % 3 == 0) then
			local col = (d.el and ELEMENT_COLOR[d.el]) or WHITE
			if d.armor then
				FX.shards(d.pos, Color3.fromRGB(200, 205, 220), 4, 16, { size = 0.3, life = 0.35 })
				FX.spikes(d.pos, Color3.fromRGB(230, 235, 255), 4, 2, 0.12)
			else
				FX.flash(d.pos, col, 1.8, 0.1)
			end
		end
	end

	-- deaths: paper crumple burst + ink splat (+ huge version for bosses)
	local origDeath = orig.Death
	handlers.Death = function(d)
		if origDeath then
			origDeath(d)
		end
		local s = math.clamp((d.size or 3) / 3, 0.6, 3)
		local col = Color3.fromRGB(90, 60, 160)
		FX.flash(d.pos, WHITE, 4 * s, 0.14)
		FX.shards(d.pos, Color3.fromRGB(245, 242, 230), d.boss and 30 or 9, 26 * s, { size = 0.7 * s, flat = true, material = Enum.Material.SmoothPlastic, drag = 1.5, gravity = 35, life = 1.1 })
		FX.emit(d.pos, "splat" .. math.random(1, 4), col, d.boss and 6 or 2, { size = 3 * s, life = 0.35, speed = 12, spin = 90 })
		FX.emit(d.pos, "drop", col, d.boss and 14 or 5, { size = 0.9 * s, life = 0.6, speed = 26, accel = Vector3.new(0, -40, 0), velocityAligned = true })
		FX.puffs(d.pos, Color3.fromRGB(235, 232, 225), d.boss and 10 or 3, 2.4 * s, 0.6)
		if d.boss then
			FX.explosion(d.pos, Color3.fromRGB(170, 90, 255), 22, false, shake)
			FX.word(d.pos + Vector3.new(0, 8, 0), "ERASED!", Color3.fromRGB(255, 220, 90), 260)
		end
	end

	local origCrit = orig.Crit
	handlers.Crit = function(d)
		if origCrit then
			origCrit(d)
		end
		FX.spikes(d.pos, WHITE, 12, 6, 0.25)
		FX.flash(d.pos, Color3.fromRGB(255, 230, 90), 5, 0.15)
		shake(0.15)
	end

	local origCombo = orig.Combo
	handlers.Combo = function(d)
		if origCombo then
			origCombo(d)
		end
		FX.ring(d.pos - Vector3.new(0, 2, 0), d.color or WHITE, 1, 8, 0.5, 0.6)
		FX.emit(d.pos, "star4", d.color or WHITE, 10, { size = 1.5, life = 0.8, speed = 16, glow = 0.6 })
	end
end

return FX
