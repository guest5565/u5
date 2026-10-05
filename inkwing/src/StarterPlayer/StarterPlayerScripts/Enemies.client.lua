--!nonstrict
-- INKWING :: ENEMIES (local): models, name/HP tags, tap-to-lock + auto-target, combat FX, telegraphs
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local me = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("Game"))
local EnemyModel = require(Shared:WaitForChild("EnemyModel"))
local InkFX = require(Shared:WaitForChild("InkFX"))
local Audio = require(Shared:WaitForChild("Audio"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Combat = Remotes:WaitForChild("Combat")
local Fx = Remotes:WaitForChild("Fx")
local folder = workspace:WaitForChild("Enemies")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local RED = Color3.fromRGB(255, 60, 70)
local function sfx(n, o)
	pcall(Audio.play, n, o)
end
local function fx(f, ...)
	pcall(f, ...)
end

local vis = Instance.new("Folder")
vis.Name = "EnemyVisuals"
vis.Parent = workspace
local Lock = Instance.new("ObjectValue")
Lock.Name = "Lock"
Lock.Parent = me

local list = {} -- part -> { e, cf, tag, fill, lunge }
local byModel = {}

-- v1.8 MANA SENSE: a monster's strength is hidden until you sense its mana.
-- Beings far stronger than you can't be read at all ("MANA TOO VAST").
local sensed = {} -- part -> "ok" | "vast"
local function senseLimit()
	return 6 + (me:GetAttribute("WingRank") or 1) * 3 + ((me:GetAttribute("Skills") or ""):find("truesight") and 8 or 0)
end
_G.InkwingSenseLimit = senseLimit
_G.InkwingSensed = sensed
local revealed = {} -- v1.9 concealed monsters seen through with Mana Vision
local vision = { on = false, r = 40, eff = 0 }
_G.InkwingVision = vision
function _G.InkwingEnemyLabel(part, def)
	local lv = part:GetAttribute("Level") or def.level
	local diff = lv - (me:GetAttribute("Level") or 1)
	local s = sensed[part]
	if part:GetAttribute("Conceal") and not revealed[part] then
		lv, diff = def.level, -3 -- it LOOKS weak
		if s then
			s = "ok"
		end
	end
	if def.peaceful or def.neutral then
		return "", Color3.fromRGB(255, 220, 120)
	end
	if s == "vast" then
		return "???", Color3.fromRGB(200, 60, 120), true
	elseif s ~= "ok" then
		return "", Color3.fromRGB(215, 215, 222)
	end
	local col = diff >= 8 and Color3.fromRGB(255, 70, 70) or diff >= 3 and Color3.fromRGB(255, 160, 70) or diff >= -4 and Color3.fromRGB(245, 240, 225) or Color3.fromRGB(150, 150, 160)
	return G.Grade(lv), col
end
function _G.InkwingApplyLabel(t, part, def)
	local txt, col = _G.InkwingEnemyLabel(part, def)
	t.Text, t.TextColor3 = txt, col
end
local function tag(e, part, def)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 38)
	bb.StudsOffsetWorldSpace = Vector3.new(0, e.size * 0.9 + 2.5, 0)
	bb.MaxDistance = 140 + e.size * 3
	bb.LightInfluence = 0
	bb.Adornee = e.root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, 0, 0, 20)
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextScaled = true
	t.Name = "Label"
	if def.giant and not def.neutral or def.neutral then
		bb.Size = UDim2.fromOffset(320, 60)
	end
	_G.InkwingApplyLabel(t, part, def)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = INK
	t.Parent = bb
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(15, 24)
	bar.Size = UDim2.new(1, -30, 0, 10)
	bar.BackgroundColor3 = INK
	bar.BorderSizePixel = 0
	bar.Parent = bb
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	bb.Parent = e.model
	return bb, fill
end

-- v1.1 monster VFX: built with the shared Auras tool (geometry + tuned emitters) instead of stock smoke/sparks
local Auras = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Auras"))
local MSTYLE = {
	InkBlob = { "drip", Color3.fromRGB(30, 28, 45) }, BlobMother = { "drip", Color3.fromRGB(40, 20, 60) }, InkShade = { "drip", Color3.fromRGB(20, 18, 30) }, BlotKing = { "drip", Color3.fromRGB(15, 12, 25) },
	ScribbleBat = { "doodle", Color3.fromRGB(40, 40, 60) }, PaperWasp = { "doodle", Color3.fromRGB(240, 200, 80) },
	InkEel = { "bubbles", Color3.fromRGB(60, 140, 200) }, Inkvern = { "bubbles", Color3.fromRGB(40, 120, 190) },
	StarWisp = { "stardust", Color3.fromRGB(180, 200, 255) }, CometHound = { "galaxy", Color3.fromRGB(150, 90, 255) }, CometEater = { "galaxy", Color3.fromRGB(120, 80, 255) },
	StarLeviathan = { "galaxy", Color3.fromRGB(110, 140, 255) }, Dreamer = { "stardust", Color3.fromRGB(255, 200, 255) }, Weaver = { "galaxy", Color3.fromRGB(200, 120, 255) },
	HaloSentinel = { "halo", Color3.fromRGB(255, 230, 150) }, GildedMoth = { "gold", Color3.fromRGB(255, 210, 110) }, Seraphim = { "phoenix", Color3.fromRGB(255, 230, 160) },
	Throne = { "halo", Color3.fromRGB(255, 220, 130) }, HaloWarden = { "gold", Color3.fromRGB(255, 220, 120) },
	CinderImp = { "ember", Color3.fromRGB(255, 110, 40) }, AshWraith = { "ember", Color3.fromRGB(200, 70, 40) }, CinderKing = { "phoenix", Color3.fromRGB(255, 80, 20) },
	Hollow = { "void", Color3.fromRGB(70, 20, 90) }, Forgotten = { "void", Color3.fromRGB(60, 20, 80) }, Hunched = { "void", Color3.fromRGB(50, 10, 60) },
	MawBelow = { "void", Color3.fromRGB(90, 10, 30) }, EclipseEye = { "void", Color3.fromRGB(140, 30, 40) }, Nameless = { "void", Color3.fromRGB(20, 10, 30) }, TheUnknown = { "void", Color3.fromRGB(10, 5, 20) },
}
local STYLE_EL = { ember = "Fire", phoenix = "Fire", halo = "Holy", gold = "Holy", void = "Void", galaxy = "Void", stardust = "Storm", bubbles = "Frost" }
-- v1.1 "godlike" enemy attacks: windup at the attacker, a themed travel effect, a zone-flavoured impact
local function godAtk(k, from, to, melee)
	local def = G.Enemies[k or ""]
	local ms = MSTYLE[k or ""]
	if not def or not ms or not from or not to then
		return false
	end
	local style, col = ms[1], ms[2]
	local hi = col:Lerp(Color3.new(1, 1, 1), 0.5)
	local s = math.clamp((def.size or 6) / 6, 1, 8)
	local el = STYLE_EL[style]
	local big = s >= 3
	if el then
		fx(InkFX.windup, from, el, s, 0.18)
	end
	local function land()
		fx(InkFX.impact, to, hi, el, s * 0.8)
		if style == "drip" then
			fx(InkFX.splat, to, col, 3 * s, 2.5)
		elseif style == "void" then
			fx(InkFX.spikes, to, Color3.fromRGB(10, 0, 15), 9, 4 * s, 0.35)
			fx(InkFX.ring, to, col, 1, 6 * s, 0.5, 1)
		elseif style == "halo" or style == "gold" or style == "phoenix" then
			fx(InkFX.flash, to, hi, 6 * s, 0.2)
			fx(InkFX.ring, to, hi, 1, 7 * s, 0.5, 1, true)
		elseif style == "ember" then
			fx(InkFX.explosion, to, col, 3 * s, true)
		elseif style == "galaxy" or style == "stardust" then
			fx(InkFX.shards, to, hi, big and 10 or 6, 14 * s)
			fx(InkFX.ring, to, col, 1, 6 * s, 0.6, 1)
		else
			fx(InkFX.puffs, to, hi, 5, 1.5 * s, 0.5)
		end
	end
	if melee then
		local dir = (to - from)
		local yaw = math.atan2(-dir.X, -dir.Z)
		fx(InkFX.slash, to, hi, 3 * s, yaw, 1, 0.4)
		land()
	elseif style == "halo" or style == "gold" or style == "galaxy" or style == "void" then
		fx(InkFX.bolt, from, to, hi, 0.6 * s, 0.35) -- beams strike instantly
		task.delay(0.05, land)
	else
		fx(InkFX.projectile, from, to, hi, 70, 0.8 * s, land)
	end
	return true
end
local function highQ()
	return me:GetAttribute("HighQ") ~= false
end
local rescale -- set below: rebuild a monster's model when it grows (merged blobs, elites)
local function add(part)
	if list[part] then
		return
	end
	local kind = part:GetAttribute("Type")
	local def = kind and G.Enemies[kind]
	if not def then
		return
	end
	local e = EnemyModel.build(kind, vis, part:GetAttribute("Scale"))
	if part:GetAttribute("Scale") then
		e.size *= part:GetAttribute("Scale")
	end
	local entry = { e = e, cf = part.CFrame, seed = math.random() * 10 }
	if not def.boss then
		entry.tag, entry.fill = tag(e, part, def)
		if entry.fill then
			entry.fill.Parent.Visible = vision.on -- v1.9 health only through Mana Vision
		end
	end
	list[part] = entry
	byModel[e.model] = part
	local ms = MSTYLE[kind]
	if part:GetAttribute("Rare") then
		-- GOLDEN variant: gilded body + gold aura + name
		ms = { "gold", Color3.fromRGB(255, 205, 70) }
		for _, d in ipairs(e.model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				d.Color = d.Color:Lerp(Color3.fromRGB(255, 200, 60), 0.6)
				d.Material = Enum.Material.Foil
			end
		end
		if entry.tag then
			local t = entry.tag:FindFirstChildOfClass("TextLabel")
			if t then
				t.Text = "GOLDEN " .. t.Text
				t.TextColor3 = Color3.fromRGB(255, 215, 80)
			end
		end
	end
	if ms and (highQ() or def.boss or (def.size or 0) >= 20) then
		local ok, au = pcall(Auras.new, ms[1], { color = ms[2], c2 = ms[2]:Lerp(Color3.new(1, 1, 1), 0.4) }, { folder = e.model, scale = math.max(1, (def.size or 6) / 6), lod = highQ() and 1 or 0.5 })
		if ok then
			entry.aura = au
			for _, d in ipairs(e.root:GetChildren()) do -- retire the stock emitters
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
		end
	end
	local function hp()
		local f = (part:GetAttribute("HP") or 0) / math.max(1, part:GetAttribute("MaxHP") or 1)
		if entry.fill then
			entry.fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
		end
	end
	part:GetAttributeChangedSignal("HP"):Connect(hp)
	hp()
	EnemyModel.pose(e, part.CFrame, 0)
	part:GetAttributeChangedSignal("Scale"):Connect(function()
		if rescale and list[part] and list[part].e == e then
			rescale(part)
		end
	end)
end
local function remove(part)
	local entry = list[part]
	if entry then
		byModel[entry.e.model] = nil
		if entry.aura then
			pcall(function()
				entry.aura:destroy()
			end)
		end
		entry.e.model:Destroy()
		list[part] = nil
	end
	if Lock.Value == part then
		Lock.Value = nil
	end
end
folder.ChildAdded:Connect(function(c)
	task.wait()
	add(c)
end)
folder.ChildRemoved:Connect(remove)
rescale = function(part)
	local lk = Lock.Value == part
	remove(part)
	add(part)
	if lk then
		Lock.Value = part
	end
end
for _, c in ipairs(folder:GetChildren()) do
	add(c)
end

---------------------------------------------------------------------------
-- LOCK-ON: tap / click an enemy (generous screen radius), or auto-target the nearest close one
---------------------------------------------------------------------------
local ring = Instance.new("BillboardGui")
ring.Size = UDim2.fromOffset(44, 44)
ring.AlwaysOnTop = true
ring.LightInfluence = 0
ring.Enabled = false
local rf = Instance.new("Frame")
rf.AnchorPoint = Vector2.new(0.5, 0.5)
rf.Position = UDim2.fromScale(0.5, 0.5)
rf.Size = UDim2.fromScale(1, 1)
rf.BackgroundTransparency = 1
rf.Parent = ring
Instance.new("UICorner", rf).CornerRadius = UDim.new(1, 0)
local rs = Instance.new("UIStroke")
rs.Thickness = 4
rs.Color = RED
rs.Parent = rf
for k = 0, 3 do -- crosshair ticks
	local t = Instance.new("Frame")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.BackgroundColor3 = RED
	t.BorderSizePixel = 0
	t.Size = (k % 2 == 0) and UDim2.fromOffset(4, 16) or UDim2.fromOffset(16, 4)
	t.Position = ({ UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 0.5), UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0.5) })[k + 1]
	t.Parent = rf
end
ring.Parent = vis

-- v1.2: PC uses FREE AIM (no lock-on, no ring, no camera snap). Mobile keeps tap-lock.
local PC = not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
local function setLock(part)
	if PC and part then
		return
	end
	if Lock.Value == part then
		return
	end
	Lock.Value = part
	Combat:FireServer("lock", part)
	if part then
		sfx("ui_click", { vol = 0.4, pitch = 1.3 })
	end
end

-- v0.9b: auto-target only things that are (or would be) fighting you
local function canAuto(part)
	if part:GetAttribute("Neutral") then
		return false
	end
	if (part:GetAttribute("HostileToMe") or 0) > os.clock() then
		return true
	end
	if part:GetAttribute("Peaceful") then
		return false
	end
	local sl = part:GetAttribute("StrongLv")
	if sl and (me:GetAttribute("Level") or 1) < sl then
		return false
	end
	return true
end
_G.InkwingCanAuto = canAuto
-- free aim pick: the monster under a screen ray (direct hit, or the closest one hugging the ray)
_G.InkwingAimPick = function(ray, maxD)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { vis }
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * (maxD + 60), rp)
	if hit and hit.Instance then
		local m = hit.Instance:FindFirstAncestorOfClass("Model")
		while m and not byModel[m] and m.Parent ~= vis do
			m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model")
		end
		if m and byModel[m] then
			return byModel[m]
		end
	end
	local best, bs
	local dir = ray.Direction.Unit
	for part, entry in pairs(list) do
		local rel = entry.cf.Position - ray.Origin
		local along = rel:Dot(dir)
		if along > 0 and along < maxD + 60 then
			local off = (rel - dir * along).Magnitude
			local tol = 2.5 + (entry.e.size or 4) * 0.45 + along * 0.012
			if off < tol and (not bs or off / tol < bs) then
				best, bs = part, off / tol
			end
		end
	end
	return best
end

local downAt, downPos
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then
		return
	end
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		downAt, downPos = os.clock(), Vector2.new(i.Position.X, i.Position.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i, gp)
	if gp or not downAt then
		return
	end
	if not (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
		return
	end
	if PC then
		downAt = nil
		return -- PC clicks shoot (Attack.client), they never lock
	end
	local pos = Vector2.new(i.Position.X, i.Position.Y)
	if os.clock() - downAt > 0.35 or (pos - downPos).Magnitude > 18 then
		return -- that was a camera drag
	end
	downAt = nil
	local cam = workspace.CurrentCamera
	-- direct hit on a model piece
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { vis }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
	if hit and hit.Instance then
		local m = hit.Instance:FindFirstAncestorOfClass("Model")
		if m and byModel[m] then
			setLock(byModel[m])
			return
		end
	end
	-- forgiving: nearest enemy on screen within 80px
	local best, bd
	for part, entry in pairs(list) do
		local sp, on = cam:WorldToViewportPoint(entry.e.root.Position)
		if on then
			local d = (Vector2.new(sp.X, sp.Y) - pos).Magnitude
			if d < 80 and (not bd or d < bd) then
				best, bd = part, d
			end
		end
	end
	if best then
		setLock(best)
	end
end)

---------------------------------------------------------------------------
-- RENDER
---------------------------------------------------------------------------
local autoT = 0
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	for part, entry in pairs(list) do
		local goal = part.CFrame
		entry.cf = entry.cf:Lerp(goal, math.clamp(dt * 8, 0, 1))
		local cf = entry.cf
		if entry.hitT then
			local k = (t - entry.hitT) / 0.18
			if k < 1 then
				local hp_ = hrp and hrp.Position or cf.Position
				local away = (cf.Position - hp_)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.zero
				cf = cf + away * math.sin(k * math.pi) * (0.6 + entry.e.size * 0.05)
			else
				entry.hitT = nil
			end
		end
		if entry.lunge then
			local k = (t - entry.lunge) / 0.3
			if k < 1 then
				cf = cf * CFrame.new(0, 0, -math.sin(k * math.pi) * 3)
			else
				entry.lunge = nil
			end
		end
		-- v1.0b LOD: out of range = not rendered at all; mid range = animated at a lower rate
		local dist = hrp and (hrp.Position - cf.Position).Magnitude or 0
		-- v1.1: render far beyond the fog so monsters never visibly pop in (PC quality renders the farthest)
		local R = highQ() and (900 + entry.e.size * 8) or (480 + entry.e.size * 5)
		local m = entry.e.model
		if dist < R then
			if m.Parent ~= vis then
				m.Parent = vis
			end
			entry.fr = (entry.fr or 0) + 1
			local every = dist < R * 0.35 and 1 or (dist < R * 0.7 and 2 or 4)
			if entry.fr % every == 0 then
				EnemyModel.pose(entry.e, cf, t + entry.seed)
			end
			if entry.aura and dist < R * 0.6 then
				entry.aura:setHidden(false)
				if not pcall(entry.aura.update, entry.aura, cf, t, dt) then
					pcall(entry.aura.destroy, entry.aura)
					entry.aura = nil
				end
			elseif entry.aura then
				entry.aura:setHidden(true)
			end
		elseif m.Parent then
			m.Parent = nil
		end
	end
	-- lock ring + auto-target
	local lk = Lock.Value
	if lk and (not lk.Parent or not list[lk] or (hrp and (hrp.Position - lk.Position).Magnitude > 140 + (list[lk] and list[lk].e.size * 0.6 or 0))) then
		setLock(nil)
		lk = nil
	end
	if not PC and not lk and hrp and t - autoT > 0.3 and t > (me:GetAttribute("AutoLockOff") or 0) then
		autoT = t
		local best, bd
		for part, _ in pairs(list) do
			local d = (part.Position - hrp.Position).Magnitude
			if d < 30 and canAuto(part) and (not bd or d < bd) then
				best, bd = part, d
			end
		end
		if best then
			setLock(best)
		end
	end
	if lk and list[lk] then
		ring.Adornee = list[lk].e.root
		ring.Enabled = not PC -- v1.7: free aim on PC needs no lock reticle
		local s = math.clamp(list[lk].e.size * 6, 30, 90)
		ring.Size = UDim2.fromOffset(s, s)
		rf.Rotation = (t * 90) % 360
	else
		ring.Enabled = false
	end
end)

---------------------------------------------------------------------------
-- FX
---------------------------------------------------------------------------
local function number(pos, text, color, big)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = pos + Vector3.new(math.random(-15, 15) / 10, 2, math.random(-15, 15) / 10)
	p.Parent = vis
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 140 or 90, big and 50 or 34)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = p
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = INK
	l.Parent = bb
	TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = p.Position + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(p, 1)
end
local function shield(player, dur)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 8
	b.Material = Enum.Material.ForceField
	b.Color = Color3.fromRGB(255, 250, 220)
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
	b.Parent = vis
	local t0 = os.clock()
	local con
	con = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > dur or not hrp.Parent then
			con:Disconnect()
			b:Destroy()
			return
		end
		b.CFrame = hrp.CFrame
	end)
end
local function warnZone(pos, r, t)
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 0.5
	b.Material = Enum.Material.Neon
	b.Color = Color3.fromRGB(255, 40, 60)
	b.Transparency = 0.75
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
	b.Position = pos
	b.Parent = vis
	local shell = b:Clone()
	shell.Size = Vector3.one * r * 2
	shell.Transparency = 0.88
	shell.Parent = vis
	TweenService:Create(b, TweenInfo.new(t, Enum.EasingStyle.Linear), { Size = Vector3.one * r * 2, Transparency = 0.55 }):Play()
	Debris:AddItem(b, t)
	Debris:AddItem(shell, t)
end

Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Shot" then
		fx(InkFX.projectile, info.from, info.to, info.color, 140, 0.8)
		if info.player == me then
			sfx("hit1", { vol = 0.25, pitch = 1.4 })
		end
	elseif kind == "Hit" then
		local entry = list[info.part]
		if entry then
			local pos = entry.e.root.Position + Vector3.new(0, entry.e.size * 0.6, 0)
			if info.by == me then
				number(pos, tostring(info.dmg) .. (info.crit and "!" or ""), info.crit and Color3.fromRGB(255, 220, 60) or Color3.new(1, 1, 1), info.crit)
			end
			fx(InkFX.flash, pos, Color3.new(1, 1, 1), entry.e.size * 0.6, 0.08)
			entry.hitT = os.clock()
			if info.by == me and info.crit then
				fx(InkFX.shards, pos, Color3.fromRGB(255, 220, 60), 8)
			end
		end
	elseif kind == "Die" then
		local s = info.boss and 30 or 7
		fx(InkFX.explosion, info.pos, Color3.fromRGB(70, 50, 120), s, not info.boss)
		sfx(info.boss and "boss_death" or "punch", { vol = 0.6 })
	elseif kind == "Hostile" then
		for _, pt in ipairs(info.parts or {}) do
			if typeof(pt) == "Instance" then
				pt:SetAttribute("HostileToMe", os.clock() + (info.t or 45))
			end
		end
	elseif kind == "Smite" then
		-- a giant angel's holy beam (gold = against you, white = on your side)
		local col = info.ally and Color3.fromRGB(255, 250, 220) or Color3.fromRGB(255, 200, 70)
		fx(InkFX.bolt, info.from, info.to, col, info.big and 6 or 4, 0.5)
		fx(InkFX.flash, info.to, col, info.big and 18 or 12, 0.25)
		fx(InkFX.ring, info.to, col, 2, info.big and 20 or 14, 0.6, 1)
		sfx("boom", { vol = 0.35, pitch = 1.4 })
	elseif kind == "Warn" then
		warnZone(info.pos, info.r, info.t)
		sfx("boss_warn", { vol = 0.35 })
	elseif kind == "Blast" then
		fx(InkFX.explosion, info.pos, Color3.fromRGB(200, 30, 60), info.r, true)
		sfx("boom", { vol = 0.5 })
	elseif kind == "EShot" then
		if not godAtk(info.k, info.from, info.to, false) then
			fx(InkFX.projectile, info.from, info.to, Color3.fromRGB(255, 130, 40), 60, 1)
		end
	elseif kind == "Bite" then
		local entry = list[info.part]
		if entry then
			entry.lunge = os.clock()
			if info.to then
				godAtk(info.k, entry.cf.Position, info.to, true)
			end
		end
	elseif kind == "Hurt" then
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			number(hrp.Position + Vector3.new(0, 2, 0), "-" .. info.dmg, RED, false)
		end
		sfx("hit3", { vol = 0.5 })
	elseif kind == "Ability" then
		local id = info.id
		if id == "fold" then
			shield(info.player, 4)
			sfx("magic", { vol = 0.5 })
		elseif id == "gust" then
			fx(InkFX.ring, info.pos, Color3.new(1, 1, 1), 2, info.r, 0.5, 1.5)
			fx(InkFX.puffs, info.pos, Color3.new(1, 1, 1), 8, 4, 0.7)
			sfx("wind", { vol = 0.6 })
		elseif id == "splash" then
			fx(InkFX.explosion, info.pos, Color3.fromRGB(60, 90, 255), info.r, true)
			sfx("boom", { vol = 0.5 })
		elseif id == "burn" then
			fx(InkFX.puffs, info.pos, Color3.fromRGB(80, 60, 200), 10, 3, 1.5)
			sfx("el_void", { vol = 0.5 })
		elseif id == "blot" then
			fx(InkFX.splat, info.pos, Color3.fromRGB(30, 30, 90), 8, 4)
			fx(InkFX.ring, info.pos, Color3.fromRGB(60, 80, 220), 1, 8, 0.4, 1)
			sfx("void_place", { vol = 0.5 })
		elseif id == "dive" then
			sfx("slash", { vol = 0.6 })
			task.delay(0.25, function()
				fx(InkFX.explosion, info.pos, Color3.new(1, 1, 1), 10, true)
			end)
		end
	elseif kind == "LevelUp" then
		local c = info.player and info.player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- v1.8f: levels are hidden now (body tempering) - just a faint glow
			fx(InkFX.ring, hrp.Position, Color3.fromRGB(255, 230, 160), 1, 6, 0.5, 0.4)
		end
	elseif kind == "Loot" then
		number(info.pos + Vector3.new(0, 3, 0), "+" .. info.xp .. " XP", Color3.fromRGB(140, 220, 255), false)
	elseif kind == "WingUp" then
		local c = info.player and info.player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hrp then
			fx(InkFX.explosion, hrp.Position, Color3.fromRGB(255, 255, 255), 10, true)
		end
	end
end)

-- name tags only on the locked enemy and close ones (less clutter, no overlapping labels)
task.spawn(function()
	while true do
		task.wait(0.2)
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		for part, entry in pairs(list) do
			if entry.tag then
				local near = hrp and (part.Position - hrp.Position).Magnitude < 45 + entry.e.size * 1.5
				entry.tag.Enabled = vision.on and part == _G.InkwingSenseTarget and hrp ~= nil -- v1.10: no names; vision shows the grade of what you look at
			end
		end
	end
end)


-- v1.8 MANA SENSE pulse (server validates skill + mana, then tells us the radius)
local function refreshLabels()
	for part, en in pairs(list) do
		local def = G.Enemies[part:GetAttribute("Type") or ""]
		local lbl = en.tag and en.tag:FindFirstChild("Label")
		if def and lbl then
			_G.InkwingApplyLabel(lbl, part, def)
		end
	end
end
local function sense(r, quiet)
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local myLv = me:GetAttribute("Level") or 1
	local lim = senseLimit()
	local n, vast = 0, 0
	for part in pairs(list) do
		if part.Parent and (part.Position - hrp.Position).Magnitude < r and not sensed[part] then
			local def = G.Enemies[part:GetAttribute("Type") or ""]
			local lv = part:GetAttribute("Level") or (def and def.level) or 1
			if lv - myLv > 2 then
				-- v1.8e: stronger beings hide from a passive sweep - look straight at them while holding V
			elseif lv - myLv > lim then
				sensed[part] = "vast"
				vast += 1
			else
				sensed[part] = "ok"
				n += 1
			end
			if not quiet then
				local col = sensed[part] == "vast" and Color3.fromRGB(200, 60, 120) or Color3.fromRGB(120, 200, 255)
				task.delay((part.Position - hrp.Position).Magnitude / 220, function()
					if part.Parent then
						InkFX.ring(part.Position, col, 1, 10, 0.5, 0.5)
					end
				end)
			end
		end
	end
	refreshLabels()
	if not quiet then
		InkFX.ring(hrp.Position, Color3.fromRGB(120, 200, 255), 2, r, 0.9, 1.2)
		if vast > 0 then
			InkFX.word(hrp.Position + Vector3.new(0, 6, 0), "SOMETHING HERE IS FAR BEYOND YOU", Color3.fromRGB(220, 80, 140), 1)
		end
	end
end
-- v1.8b SENSE AURA: look at a monster and press V - its mana flares up as an aura around it.
-- green = about your strength, yellow/orange = stronger, red + bigger + spiky = dangerous,
-- crimson-black and huge = far beyond you. The aura weakens as the monster loses HP.
local auraF = Instance.new("Folder")
auraF.Name = "SenseAuras"
auraF.Parent = workspace
local auras = {} -- part -> state
local function auraColor(diff, vast)
	if vast then
		return Color3.fromRGB(120, 0, 30), 1
	end
	local t = math.clamp((diff + 2) / 12, 0, 1) -- <= -2 lv: green, +10 lv: red
	local c
	if t < 0.5 then
		c = Color3.fromRGB(80, 230, 110):Lerp(Color3.fromRGB(255, 220, 60), t * 2)
	else
		c = Color3.fromRGB(255, 220, 60):Lerp(Color3.fromRGB(255, 40, 40), (t - 0.5) * 2)
	end
	return c, t
end
-- v1.8e: the aura is FLAME-LIKE mana pouring off the monster's body (particles hugging its shape),
-- not shells/rings. Stronger = taller, faster, denser, redder. Wounded = it thins out.
local senseHeld = false
local function showAura(part)
	local def = G.Enemies[part:GetAttribute("Type") or ""]
	if not def then
		return
	end
	local old = auras[part]
	if old and old.key ~= tostring(sensed[part]) .. tostring(revealed[part]) then
		old.holder:Destroy()
		auras[part] = nil
		old = nil
	end
	if old then
		old.t0 = os.clock()
		old.dying = nil
		return
	end
	local lv = part:GetAttribute("Level") or def.level or 1
	local diff = lv - (me:GetAttribute("Level") or 1)
	if part:GetAttribute("Conceal") and not revealed[part] then
		lv, diff = def.level, -3
	end
	local vast = sensed[part] == "vast"
	local unread = not sensed[part] -- too strong to read from afar: dark static
	local col, threat = auraColor(diff, vast)
	if unread then
		col, threat = Color3.fromRGB(70, 70, 80), 0.5
	end
	local S_ = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	local holder = Instance.new("Part")
	holder.Name = "SenseAura"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
	holder.Transparency = 1
	holder.Size = part.Size * 0.9
	holder.CFrame = part.CFrame
	holder.Parent = auraF
	local function em(props)
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.EmissionDirection = Enum.NormalId.Top
		e.LightEmission = 1
		e.LockedToPart = false
		for k, v in pairs(props) do
			e[k] = v
		end
		e.Parent = holder
		return e
	end
	local tall = 0.35 + threat * 1.6 + (threat > 0.7 and 1.2 or 0) + (vast and 1.5 or 0) -- weak = a faint wisp, dangerous = a towering red blaze
	local flame = em({ Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.35), col),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S_ * 0.12 * tall), NumberSequenceKeypoint.new(0.4, S_ * 0.2 * tall), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(S_ * 0.25 * tall, S_ * 0.5 * tall), SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, S_ * 0.6 * tall, 0), RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360), Rate = 0 })
	local motes = em({ Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(col),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S_ * 0.05), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(S_ * 0.3, S_ * 0.7 * tall), SpreadAngle = Vector2.new(40, 40), Rate = 0 })
	local smoke
	if vast then
		smoke = em({ Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(Color3.fromRGB(20, 0, 8)), LightEmission = 0,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S_ * 0.3), NumberSequenceKeypoint.new(1, S_ * 0.9) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(S_ * 0.3, S_ * 0.6), Rate = 0 })
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = col, math.min(40, S_ * 1.6), 0
	light.Parent = holder
	-- v1.9 SOUL RINGS: thin glowing rings around a strong being's body - more + darker = stronger
	local rings = {}
	local nR = vast and 5 or diff >= 8 and 4 or diff >= 3 and 3 or diff >= -1 and 2 or (lv >= 10 and 1 or 0)
	local rc = vast and Color3.fromRGB(150, 0, 30) or diff >= 8 and Color3.fromRGB(40, 10, 60) or diff >= 3 and Color3.fromRGB(170, 90, 255) or Color3.fromRGB(255, 220, 90)
	for k = 1, nR do -- each ring = a hoop of short glowing segments (flat, thin, hollow)
		local d = S_ * (1.3 + k * 0.25)
		local segs = {}
		local N = 16
		local L = math.pi * d / N * 1.05
		for n = 1, N do
			local sg = Instance.new("Part")
			sg.Anchored, sg.CanCollide, sg.CanQuery, sg.CanTouch, sg.CastShadow = true, false, false, false, false
			sg.Material = Enum.Material.Neon
			sg.Color = rc
			sg.Transparency = 1
			sg.Size = Vector3.new(L, math.max(0.08, S_ * 0.02), math.max(0.08, S_ * 0.02))
			sg.Parent = holder
			segs[n] = sg
		end
		rings[k] = { segs = segs, r = d / 2 }
	end
	auras[part] = { holder = holder, flame = flame, motes = motes, smoke = smoke, light = light, part = part, threat = threat, vast = vast, t0 = os.clock(), rings = rings, key = tostring(sensed[part]) .. tostring(revealed[part]), conceal = part:GetAttribute("Conceal") and not revealed[part] }
	pcall(Audio.play, vast and "boom" or "magic", { volume = 0.3 })
end
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for part, st in pairs(auras) do
		-- the aura lives while you HOLD sense; on release it fades out over ~0.5 s
		if vision.on and st.part == (_G.InkwingSenseTarget) then
			st.t0 = now
		end
		local idle = now - st.t0
		local fade = math.clamp(1 - (idle - 0.05) / 0.5, 0, 1)
		if not part.Parent or fade <= 0 then
			st.holder:Destroy()
			auras[part] = nil
		else
			local hpF = math.clamp((part:GetAttribute("HP") or 1) / math.max(1, part:GetAttribute("MaxHP") or 1), 0, 1)
			local pow = (0.25 + 0.75 * hpF) * fade
			st.holder.CFrame = part.CFrame
			st.flame.Rate = (25 + st.threat * 70 + (st.vast and 50 or 0)) * pow
			st.motes.Rate = (4 + st.threat * 16) * pow
			if st.smoke then
				st.smoke.Rate = 12 * pow
			end
			local flick = 1
			if st.conceal then -- concealed beings flicker in Mana Vision: something is off
				flick = (math.noise(now * 6, part.Position.X * 0.01) > 0.15) and 0.15 or 1
			end
			st.light.Brightness = (0.6 + st.threat * 1.6) * pow * flick * (0.85 + 0.15 * math.sin(now * 8))
			st.flame.Rate *= flick
			for k, ring in ipairs(st.rings) do
				local base = CFrame.new(part.Position) * CFrame.Angles(math.sin(now * 0.6 + k) * 0.25, now * (0.35 + k * 0.12) * (k % 2 == 0 and -1 or 1), math.cos(now * 0.5 + k * 2) * 0.25)
				local N = #ring.segs
				for n, sg in ipairs(ring.segs) do
					local a = (n - 0.5) / N * math.pi * 2
					sg.Transparency = 1 - 0.8 * pow * flick
					sg.CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(0, (k - (#st.rings + 1) / 2) * part.Size.Y * 0.18, -ring.r)
				end
			end
		end
	end
end)
local function lookTarget(maxR)
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not hrp or not cam then
		return nil
	end
	local o, dir = cam.CFrame.Position, cam.CFrame.LookVector
	local mp = UserInputService:GetMouseLocation()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter and not UserInputService.TouchEnabled then
		local ray = cam:ViewportPointToRay(mp.X, mp.Y - 36) -- free mouse: aim where the cursor is
		dir = ray.Direction.Unit
	end
	local best, bs = nil, math.huge
	for part in pairs(list) do
		if part.Parent then
			local v = part.Position - o
			local dist = v.Magnitude
			if dist < maxR and (part.Position - hrp.Position).Magnitude < maxR then
				local ang = math.acos(math.clamp(v.Unit:Dot(dir), -1, 1))
				local size = math.max(part.Size.X, part.Size.Y, part.Size.Z)
				local tol = math.max(0.16, math.atan(size / math.max(1, dist)))
				if ang < tol then
					local score = ang / tol + dist / maxR
					if score < bs then
						best, bs = part, score
					end
				end
			end
		end
	end
	return best
end
local senseOK = false
function _G.InkwingSenseHold(on)
	senseHeld = on
	if not on then
		_G.InkwingSenseTarget = nil
	end
end
-- v1.9 MANA VISION: screen tint + glows. The server keeps it on while mana lasts.
local Lighting = game:GetService("Lighting")
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ManaVision"
cc.Enabled = false
cc.Parent = Lighting
local TweenService = game:GetService("TweenService")
local glowF = Instance.new("Folder")
glowF.Name = "VisionGlows"
glowF.Parent = workspace
local glows = {} -- inst -> part
local function setVision(on)
	vision.on = on
	senseOK = on
	if on then
		cc.Enabled = true
		cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness = Color3.new(1, 1, 1), 0, 0, 0
		TweenService:Create(cc, TweenInfo.new(0.3), { TintColor = Color3.fromRGB(165, 195, 255), Saturation = -0.75, Contrast = 0.18, Brightness = -0.06 }):Play()
		pcall(Audio.play, "magic", { volume = 0.35 })
	else
		local tw = TweenService:Create(cc, TweenInfo.new(0.35), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0 })
		tw:Play()
		tw.Completed:Connect(function()
			if not vision.on then
				cc.Enabled = false
			end
		end)
		for _, g in pairs(glows) do
			g:Destroy()
		end
		glows = {}
	end
	refreshLabels()
	for part, en in pairs(list) do
		if en.fill then
			en.fill.Parent.Visible = on
		end
	end
end
local function glow(key, pos, col, size)
	local g = glows[key]
	if not g then
		g = Instance.new("Part")
		g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
		g.Transparency = 1
		g.Size = Vector3.one
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(col)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.25), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 14
		e.Parent = g
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = col, size * 3, 2
		l.Parent = g
		g.Parent = glowF
		glows[key] = g
	end
	g.Position = pos
	return g
end
local senseR = 160
Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Vision" then
		if info.on then
			vision.r, vision.eff = info.r or 40, info.eff or 0
			senseR = vision.r
		end
		setVision(info.on and senseHeld)
		if info.empty then
			InkFX.word(((me.Character and me.Character:GetPivot().Position) or Vector3.zero) + Vector3.new(0, 5, 0), "OUT OF MANA", Color3.fromRGB(120, 170, 255), 0.8)
		end
	end
end)
-- while seeing: read the weak around you, the looked-at being directly, light up the world
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	if not vision.on then
		return
	end
	acc += dt
	local tgt = lookTarget(senseR * 1.6)
	_G.InkwingSenseTarget = tgt
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if tgt then
		local changed = false
		if not sensed[tgt] then
			sensed[tgt] = ((tgt:GetAttribute("Level") or 1) - (me:GetAttribute("Level") or 1) > senseLimit()) and "vast" or "ok"
			changed = true
		end
		if tgt:GetAttribute("Conceal") and not revealed[tgt] then
			revealed[tgt] = true
			changed = true
			InkFX.word(tgt.Position + Vector3.new(0, 6, 0), "HIDDEN STRENGTH", Color3.fromRGB(220, 80, 140), 1)
			pcall(Audio.play, "boom", { volume = 0.4 })
		end
		if changed then
			refreshLabels()
		end
	end
	if acc < 0.15 or not hrp then
		return
	end
	acc = 0
	-- the 10 nearest beings in range glow; weak ones are read automatically
	local near = {}
	local myLv = me:GetAttribute("Level") or 1
	for part in pairs(list) do
		if part.Parent then
			local d = (part.Position - hrp.Position).Magnitude
			if d < senseR then
				table.insert(near, { part, d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a[2] < b[2]
	end)
	local fresh = false
	for i2 = 1, math.min(10, #near) do
		local part = near[i2][1]
		if not sensed[part] and ((part:GetAttribute("Level") or 1) - myLv <= 2 or part:GetAttribute("Conceal")) then
			sensed[part] = "ok"
			fresh = true
		end
		showAura(part)
	end
	if fresh then
		refreshLabels()
	end
	-- people glow gold, remains glow with their essence
	local alive = {}
	local npcF = workspace:FindFirstChild("NPCFigures")
	if npcF then
		for _, m in ipairs(npcF:GetChildren()) do
			if m:IsA("Model") then
				local pos = m:GetPivot().Position
				if (pos - hrp.Position).Magnitude < senseR then
					glow(m, pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 205, 90), 4)
					alive[m] = true
				end
			end
		end
	end
	local rf = workspace:FindFirstChild("Remains")
	if rf then
		local n = 0
		for _, rr in ipairs(rf:GetChildren()) do
			if rr:IsA("BasePart") and n < 12 and (rr.Position - hrp.Position).Magnitude < senseR then
				n += 1
				local ess = rr:GetAttribute("Essence")
				glow(rr, rr.Position, (ess and G.ESSENCES[ess] and G.ESSENCES[ess].color) or Color3.fromRGB(150, 200, 255), rr.Size.X)
				alive[rr] = true
			end
		end
	end
	for k, g in pairs(glows) do
		if not alive[k] then
			g:Destroy()
			glows[k] = nil
		end
	end
end)
-- ALL-SEEING EYE / evolved sense: passive reading of everything close
task.spawn(function()
	while true do
		task.wait(2)
		local sk = me:GetAttribute("Skills") or ""
		if sk:find("allsee") or sk:find("truesight") then
			sense(90, true)
		end
	end
end)
me:GetAttributeChangedSignal("Level"):Connect(function()
	for part, v in pairs(sensed) do
		if v == "vast" then
			sensed[part] = nil -- try again after levelling
		end
	end
	refreshLabels()
end)
folder.ChildRemoved:Connect(function(part)
	sensed[part] = nil
	revealed[part] = nil
end)
