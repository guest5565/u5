--!nonstrict
-- INKWING :: HUD (level/XP/HP, ink + feathers, abilities, target + boss bars, quest tracker + guide arrow,
-- wings panel, toasts, banners, zone titles)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local me = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("Game"))
local Audio = require(Shared:WaitForChild("Audio"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Combat = Remotes:WaitForChild("Combat")
local Fx = Remotes:WaitForChild("Fx")
local Fn = Remotes:WaitForChild("Fn")
local Lock = me:WaitForChild("Lock")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local PAPER = Color3.fromRGB(253, 250, 240)
local BLUE = Color3.fromRGB(70, 150, 255)
local GOLD = Color3.fromRGB(255, 196, 50)
local RED = Color3.fromRGB(240, 70, 80)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function sfx(n, o)
	pcall(Audio.play, n, o)
end

local function new(c, props, parent)
	local o = Instance.new(c)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function deco(o, r, th, col)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
	if th then
		new("UIStroke", { Thickness = th, Color = col or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	return o
end
local function label(parent, props)
	local t = new("TextLabel", { BackgroundTransparency = 1, Font = FONT, TextColor3 = INK, TextScaled = true }, parent)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end
local function button(parent, text, color, props)
	local b = new("TextButton", { BackgroundColor3 = color, Font = FONT, Text = text, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, AutoButtonColor = true }, parent)
	deco(b, 14, 3)
	new("UIStroke", { Thickness = 1.5, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, b)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	return b
end
local function pop(o)
	local s = o:FindFirstChild("Pop") or new("UIScale", { Name = "Pop" }, o)
	s.Scale = 0.7
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end
local function bar(parent, pos, size, color)
	local b = new("Frame", { Position = pos, Size = size, BackgroundColor3 = INK, BorderSizePixel = 0 }, parent)
	deco(b, 8, 2)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, b)
	deco(f, 8)
	return b, f
end

local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, me:WaitForChild("PlayerGui"))
new("UIScale", { Scale = isMobile and 0.8 or 1 }, gui)
local UI = {}

---------------------------------------------------------------------------
-- STATS (top-left): level badge, HP + XP bars
---------------------------------------------------------------------------
do
	local f = new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(280, 70), BackgroundColor3 = PAPER, Visible = false }, gui) -- v1.9: replaced by the bottom-left vitals
	deco(f, 18, 4)
	local badge = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = BLUE }, f)
	deco(badge, 27, 3)
	local lv = label(badge, { Size = UDim2.fromScale(1, 1), Text = "1", TextColor3 = Color3.new(1, 1, 1) })
	new("UIStroke", { Thickness = 2, Color = INK }, lv)
	local _, hpF = bar(f, UDim2.fromOffset(72, 10), UDim2.fromOffset(196, 22), RED)
	local hpT = label(hpF.Parent, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	new("UIStroke", { Thickness = 1.5, Color = INK }, hpT)
	local _, xpF = bar(f, UDim2.fromOffset(72, 40), UDim2.fromOffset(196, 16), Color3.fromRGB(120, 210, 255))
	local xpT = label(xpF.Parent, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	new("UIStroke", { Thickness = 1.5, Color = INK }, xpT)
	local function upd()
		lv.Text = tostring(me:GetAttribute("Level") or 1)
		local xp, need = me:GetAttribute("XP") or 0, me:GetAttribute("XPNeed") or 1
		xpF.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
		xpT.Text = "XP " .. xp .. " / " .. need
	end
	for _, a in ipairs({ "Level", "XP", "XPNeed" }) do
		me:GetAttributeChangedSignal(a):Connect(upd)
	end
	upd()
	me:GetAttributeChangedSignal("Level"):Connect(function()
		pop(badge)
	end)
	RunService.Heartbeat:Connect(function()
		local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hpF.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 1)
			hpT.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
		end
	end)
end

---------------------------------------------------------------------------
-- CURRENCY (top-centre)
---------------------------------------------------------------------------
do
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 48), BackgroundColor3 = PAPER, Visible = false }, gui) -- v1.10: only pops up when it changes
	deco(f, 16, 4)
	local drop = new("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = BLUE }, f)
	deco(drop, 15, 3)
	local ink = label(f, { Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(110, 36), Text = "0", TextXAlignment = Enum.TextXAlignment.Left })
	local fe = new("Frame", { Position = UDim2.fromOffset(166, 9), Size = UDim2.fromOffset(16, 30), BackgroundColor3 = Color3.new(1, 1, 1), Rotation = 25 }, f)
	deco(fe, 8, 3)
	local feT = label(f, { Position = UDim2.fromOffset(192, 6), Size = UDim2.fromOffset(100, 36), Text = "0", TextXAlignment = Enum.TextXAlignment.Left })
	local function upd()
		ink.Text = tostring(me:GetAttribute("Ink") or 0)
		feT.Text = tostring(me:GetAttribute("Feathers") or 0)
	end
	local showTok = 0
	local function flash()
		showTok += 1
		local my = showTok
		f.Visible = true
		task.delay(3, function()
			if showTok == my then
				f.Visible = false
			end
		end)
	end
	local first = true
	me:GetAttributeChangedSignal("Ink"):Connect(function()
		upd()
		if not first then
			flash()
		end
	end)
	me:GetAttributeChangedSignal("Feathers"):Connect(function()
		upd()
		if not first then
			flash()
		end
	end)
	task.delay(5, function()
		first = false
	end)
	_G.InkwingShowWallet = flash
	upd()
end

---------------------------------------------------------------------------
-- TOASTS + BANNERS
---------------------------------------------------------------------------
do
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(620, 200), BackgroundTransparency = 1 }, gui)
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, holder)
	function UI.toast(text, color)
		local t = label(holder, { Size = UDim2.fromOffset(600, 30), Text = text, TextColor3 = color or Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK })
		pop(t)
		task.delay(3.2, function()
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.45)
			t:Destroy()
		end)
	end
	-- big centred banner (quest complete, new wing, zone title)
	local bf = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(640, 110), BackgroundTransparency = 1, Visible = false }, gui)
	local top = label(bf, { Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, TextStrokeColor3 = INK })
	local lineA = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 31), Size = UDim2.new(0.8, 0, 0, 3), BackgroundColor3 = INK, BorderSizePixel = 0 }, bf)
	local mid = label(bf, { Position = UDim2.fromOffset(0, 37), Size = UDim2.new(1, 0, 0, 48), Text = "", TextStrokeTransparency = 0, TextStrokeColor3 = INK })
	local lineB = lineA:Clone()
	lineB.Position = UDim2.new(0.5, 0, 0, 89)
	lineB.Parent = bf
	local sub = label(bf, { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, TextStrokeColor3 = INK })
	local token = 0
	function UI.banner(t1, t2, col, t3)
		token += 1
		local my = token
		top.Text, mid.Text, mid.TextColor3, sub.Text = t1, t2, col or Color3.fromRGB(255, 236, 190), t3 or ""
		bf.Visible = true
		for _, l in ipairs({ top, mid, sub }) do
			l.TextTransparency = 1
			TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
		end
		lineA.Size, lineB.Size = UDim2.new(0, 0, 0, 3), UDim2.new(0, 0, 0, 3)
		TweenService:Create(lineA, TweenInfo.new(0.6), { Size = UDim2.new(0.8, 0, 0, 3) }):Play()
		TweenService:Create(lineB, TweenInfo.new(0.6), { Size = UDim2.new(0.8, 0, 0, 3) }):Play()
		task.delay(3.6, function()
			if my == token then
				for _, l in ipairs({ top, mid, sub }) do
					TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
				end
				task.wait(0.8)
				if my == token then
					bf.Visible = false
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- ABILITIES (3 + PC keys 1/2/3)
---------------------------------------------------------------------------
do
	local btns = {}
	local cdEnd = {}
	local row = new("Frame", { BackgroundTransparency = 1 }, gui)
	if isMobile then
		row.AnchorPoint = Vector2.new(1, 1)
		row.Position = UDim2.new(1, -190, 1, -18)
		row.Size = UDim2.fromOffset(250, 78)
	else
		row.AnchorPoint = Vector2.new(0.5, 1)
		row.Position = UDim2.new(0.5, 0, 1, -16)
		row.Size = UDim2.fromOffset(300, 86)
		row.Visible = false -- v1.10 PC: abilities live on keys 1-3, no buttons on screen
	end
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local COLS = { Color3.fromRGB(110, 170, 255), Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 100, 120) }
	for i = 1, 3 do
		local b = button(row, "", COLS[i], { Size = UDim2.fromOffset(isMobile and 76 or 90, isMobile and 76 or 86), LayoutOrder = i })
		b.UICorner.CornerRadius = UDim.new(1, 0)
		local name = label(b, { Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.15), Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
		new("UIStroke", { Thickness = 1.5, Color = INK }, name)
		if not isMobile then
			label(b, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -18), Text = tostring(i), TextColor3 = Color3.new(1, 1, 1), ZIndex = 2 })
		end
		local shade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = INK, BackgroundTransparency = 0.4, ZIndex = 3 }, b)
		deco(shade, 40)
		local cdT = label(b, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 4 })
		btns[i] = { b = b, name = name, shade = shade, cd = cdT }
	end
	local function wingDef()
		return G.Wings[me:GetAttribute("Wing") or "Paper"] or G.Wings.Paper
	end
	local function refresh()
		local w = wingDef()
		for i, x in ipairs(btns) do
			x.name.Text = w.abilities[i].name
		end
	end
	me:GetAttributeChangedSignal("Wing"):Connect(refresh)
	refresh()
	local function use(i)
		local w = wingDef()
		local ab = w.abilities[i]
		local key = (me:GetAttribute("Wing") or "Paper") .. i
		if cdEnd[key] and os.clock() < cdEnd[key] then
			return
		end
		local cost = G.AbilityMana(ab)
		if (me:GetAttribute("Mana") or 0) < cost then
			UI.toast(("NOT ENOUGH MANA (%d)"):format(cost), Color3.fromRGB(120, 180, 255))
			return
		end
		if ab.kind ~= "shield" then
			local tgt = Lock.Value
			if not tgt and _G.InkwingPickTarget then
				tgt = _G.InkwingPickTarget(ab.kind == "dive" and 75 or (w.range or 55))
			end
			if not tgt then
				UI.toast("NO MONSTER IN RANGE - AIM AT ONE", Color3.fromRGB(255, 130, 130))
				return
			end
			Combat:FireServer("lock", tgt)
		end
		cdEnd[key] = os.clock() + ab.cd
		Combat:FireServer("ability", i)
		pop(btns[i].b)
	end
	for i, x in ipairs(btns) do
		x.b.Activated:Connect(function()
			use(i)
		end)
	end
	UserInputService.InputBegan:Connect(function(inp, gp)
		if gp then
			return
		end
		local k = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 })[inp.KeyCode]
		if k then
			use(k)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local w = wingDef()
		local wing = me:GetAttribute("Wing") or "Paper"
		for i, x in ipairs(btns) do
			local e = cdEnd[wing .. i]
			local left = e and (e - os.clock()) or 0
			if left > 0 then
				x.shade.Size = UDim2.fromScale(1, left / w.abilities[i].cd)
				x.cd.Text = tostring(math.ceil(left))
			else
				x.shade.Size = UDim2.fromScale(1, 0)
				x.cd.Text = ""
			end
		end
	end)
end

---------------------------------------------------------------------------
-- TARGET FRAME + BOSS BAR
---------------------------------------------------------------------------
do
	local tf = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(300, 46), BackgroundColor3 = PAPER, Visible = false }, gui)
	deco(tf, 14, 3, RED)
	local tn = label(tf, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 20), Text = "", TextColor3 = RED })
	local _, tfill = bar(tf, UDim2.fromOffset(10, 26), UDim2.new(1, -20, 0, 13), RED)
	local bossF = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(520, 56), BackgroundTransparency = 1, Visible = false }, gui)
	local bn = label(bossF, { Size = UDim2.new(1, 0, 0, 24), Text = "THE BLOT KING", TextColor3 = Color3.fromRGB(255, 90, 110), TextStrokeTransparency = 0, TextStrokeColor3 = INK })
	local _, bfill = bar(bossF, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 22), Color3.fromRGB(200, 30, 70))
	local bt = label(bfill.Parent, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.new(1, 1, 1), ZIndex = 3 })
	new("UIStroke", { Thickness = 1.5, Color = INK }, bt)
	local enemies = workspace:WaitForChild("Enemies")
	RunService.Heartbeat:Connect(function()
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		local boss
		if hrp then
			for _, e in ipairs(enemies:GetChildren()) do
				local bdef = G.Enemies[e:GetAttribute("Type") or ""]
				if bdef and bdef.boss and (e.Position - hrp.Position).Magnitude < 220 then
					boss = e
					bn.Text = bdef.name
				end
			end
		end
		local V = _G.InkwingVision
		local seeing = V and V.on
		bossF.Visible = boss ~= nil and seeing
		if boss then
			local hp, mx = boss:GetAttribute("HP") or 0, boss:GetAttribute("MaxHP") or 1
			bfill.Parent.Visible = seeing -- v1.9 health is only readable through Mana Vision
			bfill.Size = UDim2.fromScale(math.clamp(hp / mx, 0, 1), 1)
			bt.Text = (V and V.eff >= 0.45) and (math.floor(hp) .. " / " .. mx) or ""
		end
		local lk = Lock.Value
		tf.Visible = seeing and lk ~= nil and lk.Parent ~= nil and boss == nil -- v1.10: no names unless you look with Mana Vision
		if tf.Visible then
			local def = G.Enemies[lk:GetAttribute("Type") or ""]
			tn.Text = def and (_G.InkwingEnemyLabel and (_G.InkwingEnemyLabel(lk, def)) or def.name) or ""
			tfill.Parent.Visible = seeing
			tf.Size = UDim2.fromOffset(300, seeing and 46 or 26)
			tfill.Size = UDim2.fromScale(math.clamp((lk:GetAttribute("HP") or 0) / math.max(1, lk:GetAttribute("MaxHP") or 1), 0, 1), 1)
		end
	end)
end

---------------------------------------------------------------------------
-- QUEST TRACKER + GUIDE ARROW
---------------------------------------------------------------------------
do
	-- v1.10 quest: plain white text with a grey outline, top-left under the training line
	local qf = new("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 14, 0, isMobile and 128 or 40), Size = UDim2.fromOffset(isMobile and 260 or 340, 66), BackgroundTransparency = 1 }, gui)
	local qt = label(qf, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Text = "QUEST", TextColor3 = Color3.fromRGB(220, 150, 20), TextXAlignment = Enum.TextXAlignment.Left })
	local qd = label(qf, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 26), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
	local qp = label(qf, { Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 16), Text = "", TextColor3 = Color3.fromRGB(110, 110, 130), TextXAlignment = Enum.TextXAlignment.Left })
	local function upd()
		local qi = me:GetAttribute("Quest") or 1
		local q = G.Quests[qi]
		if not q then
			qt.Text = "ALL QUESTS DONE"
			qd.Text = "THE STORM LAYER OPENS NEXT UPDATE"
			qp.Text = ""
			return
		end
		qt.Text = ("QUEST %d / %d"):format(qi, #G.Quests)
		qd.Text = q.text
		for _, l in ipairs({ qt, qd, qp }) do
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeColor3 = Color3.fromRGB(70, 70, 78)
			l.TextStrokeTransparency = 0
			local us = l:FindFirstChildOfClass("UIStroke")
			if us then
				us:Destroy()
			end
		end
		qt.TextColor3 = Color3.fromRGB(255, 225, 140)
		qp.Text = ("%d / %d   REWARD %d INK%s"):format(me:GetAttribute("QuestProg") or 0, q.n, q.ink, q.feathers > 0 and (" + " .. q.feathers .. " FEATHERS") or "")
	end
	me:GetAttributeChangedSignal("Quest"):Connect(upd)
	me:GetAttributeChangedSignal("QuestProg"):Connect(upd)
	upd()
	-- arrow beam to the quest area (or to the jump sign before your first flight)
	local tp = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one }, workspace)
	local a1 = new("Attachment", {}, tp)
	local beam = new("Beam", { Attachment1 = a1, Width0 = 1, Width1 = 1, FaceCamera = true, Color = ColorSequence.new(GOLD), LightEmission = 0.7, Transparency = NumberSequence.new(0.25), Texture = "rbxasset://textures/particles/sparkles_main.dds", TextureSpeed = 2, Segments = 10, Enabled = false }, tp)
	local flown = false
	RunService.Heartbeat:Connect(function()
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			beam.Enabled = false
			return
		end
		if me:GetAttribute("Flying") then
			flown = true
		end
		local q = G.Quests[me:GetAttribute("Quest") or 1]
		local goal = (not flown and me:GetAttribute("NewPlayer")) and Vector3.new(0, 44, 300) or (q and q.where)
		if goal and G.RealmOfY and G.RealmOfY(goal.Y) ~= G.REALM then
			-- v0.9: the quest is in another realm -> guide to the right gate
			local gy = (G.REALM == "Overworld" and (goal.Y > 0 and G.GATE_UP + 20 or G.GATE_DOWN - 20)) or (G.REALM == "Celestial" and G.CEL_FLOOR - 20) or (G.UND_ROOF + 20)
			goal = Vector3.new(0, gy, 0)
		end
		if goal and (hrp.Position - goal).Magnitude > 45 then
			tp.Position = goal
			local a0 = hrp:FindFirstChild("QuestA0") or new("Attachment", { Name = "QuestA0", Position = Vector3.new(0, -1, 0) }, hrp)
			beam.Attachment0 = a0
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end)
end

---------------------------------------------------------------------------
-- WINGS PANEL
---------------------------------------------------------------------------
do
	local wb = button(gui, "WINGS", Color3.fromRGB(150, 110, 240), { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, isMobile and -66 or -84), Size = UDim2.fromOffset(isMobile and 84 or 104, isMobile and 52 or 66) })
	local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(600, 380), BackgroundColor3 = PAPER, Visible = false, ZIndex = 5 }, gui)
	deco(panel, 22, 5)
	label(panel, { Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(300, 38), Text = "MY WINGS", TextXAlignment = Enum.TextXAlignment.Left })
	local close = button(panel, "X", RED, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(46, 42) })
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local listF = new("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(190, 304), BackgroundTransparency = 1 }, panel)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, listF)
	local det = new("Frame", { Position = UDim2.fromOffset(218, 60), Size = UDim2.new(1, -234, 1, -76), BackgroundColor3 = Color3.fromRGB(242, 238, 224) }, panel)
	deco(det, 16, 3)
	local dName = label(det, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), Text = "" })
	local dInfo = label(det, { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 20), Text = "", TextColor3 = Color3.fromRGB(90, 90, 110) })
	local abl = {}
	for i = 1, 3 do
		abl[i] = label(det, { Position = UDim2.fromOffset(12, 64 + (i - 1) * 40), Size = UDim2.new(1, -24, 0, 36), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(60, 60, 80) })
	end
	local upB = button(det, "UPGRADE", GOLD, { Position = UDim2.new(0, 12, 1, -100), Size = UDim2.new(1, -24, 0, 42) })
	local eqB = button(det, "EQUIP", BLUE, { Position = UDim2.new(0, 12, 1, -52), Size = UDim2.new(1, -24, 0, 40) })
	local sel = "Paper"
	local function render()
		local owned = HttpService:JSONDecode(me:GetAttribute("WingsOwned") or "{}")
		local cur = me:GetAttribute("Wing") or "Paper"
		for _, c in ipairs(listF:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, id in ipairs(G.WingOrder) do
			local w = G.Wings[id]
			local has = owned[id] ~= nil
			local b = button(listF, has and (w.name .. "  T" .. owned[id]) or "???  (LOCKED)", has and (id == sel and BLUE or Color3.fromRGB(150, 150, 170)) or Color3.fromRGB(190, 185, 175), { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = i })
			if id == cur then
				b.Text ..= "  [ON]"
			end
			b.Activated:Connect(function()
				sel = id
				render()
			end)
		end
		local w = G.Wings[sel]
		local tier = owned[sel]
		dName.Text = tier and w.name or "LOCKED WING"
		dName.TextColor3 = G.Rarity[w.rarity] or INK
		dInfo.Text = tier and (w.rarity:upper() .. "  |  TIER " .. tier .. " / " .. G.MAX_TIER .. "  |  " .. w.trait:upper()) or (w.unlock or "???")
		for i, a in ipairs(w.abilities) do
			abl[i].Text = tier and (a.name .. ": " .. a.desc:upper()) or "???"
		end
		upB.Visible = tier ~= nil
		eqB.Visible = tier ~= nil
		if tier then
			if tier >= G.MAX_TIER then
				upB.Text = "MAX TIER"
			else
				local c = G.WingCost(tier)
				upB.Text = ("UPGRADE > T%d  (%d FEATHERS + %d INK)"):format(tier + 1, c.feathers, c.ink)
				local ok = (me:GetAttribute("Feathers") or 0) >= c.feathers and (me:GetAttribute("Ink") or 0) >= c.ink
				upB.BackgroundColor3 = ok and GOLD or Color3.fromRGB(200, 190, 170)
			end
			eqB.Text = sel == cur and "EQUIPPED" or "EQUIP"
		end
	end
	upB.Activated:Connect(function()
		local res = Fn:InvokeServer("upgrade", sel)
		if res and res.ok then
			sfx("upgrade")
			UI.banner("WINGS UPGRADED", G.Wings[sel].name:upper() .. "  TIER " .. res.tier, GOLD, nil)
		elseif res and res.err then
			UI.toast(res.err, Color3.fromRGB(255, 120, 120))
		end
	end)
	eqB.Activated:Connect(function()
		Fn:InvokeServer("equip", sel)
	end)
	for _, a in ipairs({ "WingsOwned", "Wing", "Ink", "Feathers" }) do
		me:GetAttributeChangedSignal(a):Connect(function()
			if panel.Visible then
				render()
			end
		end)
	end
	wb.Visible = false -- v1.9: the menu orb opens wings
	_G.InkwingToggleWings = function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			sel = me:GetAttribute("Wing") or "Paper"
			render()
			pop(panel)
			sfx("ui_open", { vol = 0.5 })
		end
	end
	wb.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			sel = me:GetAttribute("Wing") or "Paper"
			render()
			pop(panel)
			sfx("ui_open", { vol = 0.5 })
		end
	end)
	local fit = new("UIScale", {}, panel)
	local function doFit()
		local vs = workspace.CurrentCamera.ViewportSize
		fit.Scale = math.max(0.5, math.min(1, (vs.X - 40) / 600, (vs.Y - 100) / 380) / (isMobile and 0.8 or 1))
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(doFit)
	doFit()
	-- a hint dot when an upgrade is affordable
	local dot = label(wb, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 3 })
	deco(dot, 12)
	local function hint()
		local wing = me:GetAttribute("Wing") or "Paper"
		local tier = me:GetAttribute("WingTier") or 1
		local c = G.WingCost(tier)
		dot.Visible = tier < G.MAX_TIER and (me:GetAttribute("Feathers") or 0) >= c.feathers and (me:GetAttribute("Ink") or 0) >= c.ink
		local _ = wing
	end
	for _, a in ipairs({ "Ink", "Feathers", "WingTier" }) do
		me:GetAttributeChangedSignal(a):Connect(hint)
	end
	hint()
end

---------------------------------------------------------------------------
-- ZONES + REMOTE MESSAGES + WELCOME
---------------------------------------------------------------------------
do
	local cur
	task.spawn(function()
		while true do
			task.wait(0.5)
			local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local zone
				for _, z in ipairs(G.Zones) do
					if z.test(hrp.Position) then
						zone = z.name
						break
					end
				end
				if zone and zone ~= cur then
					if cur ~= nil then
						local zc
						for _, z in ipairs(G.Zones) do
							if z.name == zone then
								zc = z.color
							end
						end
						UI.banner("ENTERING", zone, zc or Color3.fromRGB(255, 236, 190))
					end
					cur = zone
				end
			end
		end
	end)
	Fx.OnClientEvent:Connect(function(kind, info)
		if kind == "Toast" then
			UI.toast(info.text, info.color)
		elseif kind == "Announce" then
			UI.toast(info.text, info.color)
			sfx("boss_warn", { vol = 0.4 })
		elseif kind == "QuestDone" then
			UI.banner("QUEST COMPLETE", info.text, GOLD, ("+%d INK%s"):format(info.ink, info.feathers > 0 and ("  +" .. info.feathers .. " FEATHERS") or ""))
			sfx("wave_clear")
		elseif kind == "NewWing" then
			local w = G.Wings[info.wing]
			UI.banner("NEW WINGS!", w.name:upper(), G.Rarity[w.rarity], "OPEN WINGS TO EQUIP THEM")
			sfx("reveal_legendary")
		elseif kind == "Loot" then
			if info.feathers > 0 then
				UI.toast("+" .. info.feathers .. " FEATHER" .. (info.feathers > 1 and "S" or ""), Color3.new(1, 1, 1))
			end
		end
	end)
	if me:GetAttribute("NewPlayer") then
		task.delay(2, function()
			UI.toast("QUILL: THE INK IS SPREADING ACROSS THE SKY...", Color3.fromRGB(255, 220, 120))
			task.wait(2.5)
			UI.toast("QUILL: JUMP OFF THE EDGE - YOUR WINGS WILL CATCH YOU!", Color3.fromRGB(255, 220, 120))
		end)
	end
end
