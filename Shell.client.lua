--!nonstrict
-- INKWING :: SHELL UI (v1.9)
--   * VITALS (bottom-left on PC, top-left on mobile): a portrait circle holding your mana core
--     (black -> white with purity) and the core rank letter, with HP and MANA bars beside it.
--   * MENU ORB (right side): tap to fan out SKILLS / MAP / INVENTORY / WINGS.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local me = Players.LocalPlayer
local rgb = Color3.fromRGB
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local DARK, GOLD, INK = rgb(34, 34, 38), rgb(240, 200, 70), rgb(16, 15, 20)
local FONT = Enum.Font.GothamBlack

local function new(c, props, parent)
	local o = Instance.new(c)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end
local function stroke(o, t, c)
	new("UIStroke", { Thickness = t, Color = c or GOLD, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local gui = new("ScreenGui", { Name = "Shell", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 7 }, me:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- VITALS
---------------------------------------------------------------------------
local P = isMobile and 62 or 78
local vit = new("Frame", { AnchorPoint = isMobile and Vector2.new(0, 0) or Vector2.new(0, 1), Position = isMobile and UDim2.fromOffset(12, 12) or UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(P + (isMobile and 170 or 220), P), BackgroundTransparency = 1 }, gui)
local portrait = new("Frame", { Size = UDim2.fromOffset(P, P), BackgroundColor3 = DARK, ZIndex = 3 }, vit)
corner(portrait, 999)
stroke(portrait, 3)
local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = rgb(10, 10, 12), ZIndex = 4 }, portrait)
corner(core, 999)
local coreGlow = new("UIStroke", { Thickness = 2, Color = rgb(60, 60, 70), Transparency = 0.3 }, core)
local rankL = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(P * 0.62, P * 0.3), BackgroundColor3 = DARK, Font = FONT, TextScaled = true, Text = "D", TextColor3 = GOLD, ZIndex = 5 }, portrait)
corner(rankL, 8)
stroke(rankL, 2)

local function bar(y, h, col1, col2)
	local bg = new("Frame", { Position = UDim2.new(0, P - 10, 0, y), Size = UDim2.new(1, -(P - 10), 0, h), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = 1 }, vit)
	corner(bg, h // 2)
	stroke(bg, 2, INK)
	local fill = new("Frame", { Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -14, 1, -4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, bg)
	corner(fill, (h - 4) // 2)
	new("UIGradient", { Color = ColorSequence.new(col1, col2) }, fill)
	local t = new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -18, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.35, ZIndex = 3 }, bg)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, t)
	return fill, t
end
local BH = isMobile and 20 or 24
local hpFill, hpT = bar(P * 0.5 - BH - 2, BH, rgb(255, 95, 95), rgb(190, 35, 55))
local mpFill, mpT = bar(P * 0.5 + 2, BH - 4, rgb(120, 200, 255), rgb(60, 100, 255))

local function setFill(f, k)
	k = math.clamp(k, 0, 1)
	f.Size = UDim2.new(k, -14 * k, 1, -4)
	f.Visible = k > 0.001
end
local function refreshMana()
	local cur, mx = me:GetAttribute("Mana") or 0, math.max(1, me:GetAttribute("ManaMax") or 1)
	setFill(mpFill, cur / mx)
	local cap = me:GetAttribute("CoreCap") or mx
	mpT.Text = ("%d / %d%s"):format(cur, mx, mx >= cap and "  LIMIT" or "")
	local r = me:GetAttribute("WingRank") or 1
	rankL.Text = G.RANKS[r] or "D"
	rankL.TextColor3 = G.RANK_COLORS[r] or GOLD
	local pur = G.CorePurity(r, mx, cap)
	local c = rgb(10, 10, 12):Lerp(Color3.new(1, 1, 1), pur ^ 1.4)
	core.BackgroundColor3 = c
	coreGlow.Color = c:Lerp(rgb(140, 190, 255), 0.4)
	core.Size = UDim2.fromScale(0.34 + pur * 0.18, 0.34 + pur * 0.18)
end
for _, a in ipairs({ "Mana", "ManaMax", "CoreCap", "WingRank" }) do
	me:GetAttributeChangedSignal(a):Connect(refreshMana)
end
refreshMana()
local lastHp
RunService.Heartbeat:Connect(function()
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local k = hum.Health / math.max(1, hum.MaxHealth)
		if k ~= lastHp then
			lastHp = k
			setFill(hpFill, k)
			hpT.Text = ("%d / %d"):format(math.floor(hum.Health), math.floor(hum.MaxHealth))
		end
	end
	-- the core breathes while meditating / seeing
	local t = os.clock()
	local active = me:GetAttribute("Meditating") or me:GetAttribute("Vision")
	coreGlow.Thickness = active and (2 + 2 * (0.5 + 0.5 * math.sin(t * 4))) or 2
end)

---------------------------------------------------------------------------
-- MENU ORB
---------------------------------------------------------------------------
local O = isMobile and 58 or 64
local orb = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = isMobile and UDim2.new(1, -14, 0.5, 20) or UDim2.new(1, -18, 1, -112), Size = UDim2.fromOffset(O, O), BackgroundColor3 = DARK, Text = "", AutoButtonColor = true, ZIndex = 5 }, gui)
corner(orb, 999)
stroke(orb, 3)
-- three gold bars (a drawn menu glyph)
for k = -1, 1 do
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5 + k * 0.17), Size = UDim2.fromScale(0.46, 0.07), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6 }, orb)
	corner(b, 4)
end
local ping = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.88, 0.12), Size = UDim2.fromScale(0.26, 0.26), BackgroundColor3 = rgb(255, 90, 90), Visible = false, ZIndex = 7 }, orb)
corner(ping, 999)

local ITEMS = {
	{ "SKILLS", "skills", function()
		return _G.InkwingToggleSkills
	end, "K" },
	{ "MAP", "map", function()
		return _G.InkwingToggleMap
	end, "M" },
	{ "INVENTORY", "inv", function()
		return _G.InkwingTogglePlumes
	end },
	{ "WINGS", "wings", function()
		return _G.InkwingToggleWings
	end },
	{ "QUALITY", "quality", function()
		return _G.InkwingToggleQuality
	end },
	{ "HIDE UI", "hide", function()
		return _G.InkwingHideUI and function()
			_G.InkwingHideUI(true)
		end
	end, "H" },
}
for _ = 1, 30 do
	if me:GetAttribute("IsAdmin") ~= nil then
		break
	end
	task.wait(0.1)
end
if me:GetAttribute("IsAdmin") then
	table.insert(ITEMS, { "ADMIN", "admin", function()
		return _G.InkwingToggleAdmin
	end })
end
local open = false
local btns = {}
local IW, IH = isMobile and 132 or 150, isMobile and 40 or 42
for i, it in ipairs(ITEMS) do
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = orb.Position, Size = UDim2.fromOffset(IW, IH), BackgroundColor3 = DARK, Font = Enum.Font.GothamBold, TextScaled = true, Text = it[1] .. ((not isMobile and it[4]) and ("  (" .. it[4] .. ")") or ""), TextColor3 = GOLD, Visible = false, ZIndex = 4, AutoButtonColor = true }, gui)
	corner(b, IH // 2)
	stroke(b, 2)
	new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
	b.Activated:Connect(function()
		local f = it[3]()
		if f then
			f()
		end
		if it[2] == "skills" then
			ping.Visible = false
		end
	end)
	btns[i] = b
end
local function layout()
	local base = orb.Position
	for i, b in ipairs(btns) do
		-- fan upward along an arc to the left of the orb
		local a = math.rad(100 + (i - 1) * 22)
		local R = (isMobile and 90 or 104) + (i - 1) * 8
		local target = base + UDim2.fromOffset(math.cos(a) * R * 0.9 - O * 0.5 + 10, -O * 0.5 - math.sin(a) * R * 0.95 + R * 0.25 + (i - 1) * (IH + 6) * 0.35)
		if isMobile then -- mid-right edge: a vertical column to the left of the orb
			target = base + UDim2.fromOffset(-O - 8, -O * 0.5 + (i - (#btns + 1) / 2) * (IH + 6))
		end
		if open then
			b.Visible = true
			b.Position = base + UDim2.fromOffset(-O * 0.5, -O * 0.5)
			b.Size = UDim2.fromOffset(IW * 0.3, IH * 0.6)
			TweenService:Create(b, TweenInfo.new(0.18 + i * 0.03, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target, Size = UDim2.fromOffset(IW, IH) }):Play()
		else
			local tw = TweenService:Create(b, TweenInfo.new(0.12), { Position = base + UDim2.fromOffset(-O * 0.5, -O * 0.5), Size = UDim2.fromOffset(IW * 0.3, IH * 0.6) })
			tw:Play()
			tw.Completed:Connect(function()
				if not open then
					b.Visible = false
				end
			end)
		end
	end
end
-- PC: a clean vertical stack above the orb instead of the arc maths above
if not isMobile then
	layout = function()
		local base = orb.Position
		for i, b in ipairs(btns) do
			local target = base + UDim2.fromOffset(0, -O - 8 - (i - 1) * (IH + 8) + IH * 0.5 - IH)
			b.AnchorPoint = Vector2.new(1, 0)
			if open then
				b.Visible = true
				b.Position = base + UDim2.fromOffset(0, -O)
				b.Size = UDim2.fromOffset(IW * 0.4, IH)
				TweenService:Create(b, TweenInfo.new(0.16 + i * 0.035, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = target, Size = UDim2.fromOffset(IW, IH) }):Play()
			else
				local tw = TweenService:Create(b, TweenInfo.new(0.1), { Position = base + UDim2.fromOffset(0, -O), Size = UDim2.fromOffset(IW * 0.4, IH) })
				tw:Play()
				tw.Completed:Connect(function()
					if not open then
						b.Visible = false
					end
				end)
			end
		end
	end
end
orb.Activated:Connect(function()
	open = not open
	TweenService:Create(orb, TweenInfo.new(0.15), { Rotation = open and 90 or 0 }):Play()
	layout()
end)
_G.InkwingMenuPing = function(which)
	if which == "skills" then
		ping.Visible = true
		local s = new("UIScale", { Scale = 1.6 }, orb)
		TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
		task.delay(0.6, function()
			s:Destroy()
		end)
	end
end

-- quality button label follows the setting
for _, b in ipairs(btns) do
	if b.Text:sub(1, 7) == "QUALITY" then
		local function q()
			b.Text = me:GetAttribute("HighQ") and "QUALITY: PC" or "QUALITY: MOBILE"
		end
		me:GetAttributeChangedSignal("HighQ"):Connect(q)
		q()
	end
end

---------------------------------------------------------------------------
-- v1.10 HIDE ALL UI (H, or the menu): just you and the sky. Tap the eye / press H to bring it back.
---------------------------------------------------------------------------
local pg = me:WaitForChild("PlayerGui")
local eyeGui = new("ScreenGui", { Name = "EyeToggle", ResetOnSpawn = false, DisplayOrder = 50, Enabled = false }, pg)
local eye = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = DARK, BackgroundTransparency = 0.5, Text = "", AutoButtonColor = true }, eyeGui)
corner(eye, 999)
stroke(eye, 2)
local lid = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.34), BackgroundTransparency = 1 }, eye)
corner(lid, 999)
new("UIStroke", { Thickness = 2, Color = GOLD }, lid)
local pupil = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.2), BackgroundColor3 = GOLD }, eye)
corner(pupil, 999)
local hidden, saved = false, {}
local KEEP = { EyeToggle = true, Dialogue = true, Chat = true, BubbleChat = true, Freecam = true }
function _G.InkwingHideUI(on, noEye)
	hidden = on
	if on then
		saved = {}
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and not KEEP[g.Name] and g.Enabled then
				saved[g] = true
				g.Enabled = false
			end
		end
		eyeGui.Enabled = not noEye
	else
		for g in pairs(saved) do
			if g.Parent then
				g.Enabled = true
			end
		end
		saved = {}
		eyeGui.Enabled = false
	end
end
eye.Activated:Connect(function()
	_G.InkwingHideUI(false)
end)
UserInputService.InputBegan:Connect(function(io, gp)
	if not gp and io.KeyCode == Enum.KeyCode.H and not _G.InkwingDialogue then
		_G.InkwingHideUI(not hidden)
	end
end)
