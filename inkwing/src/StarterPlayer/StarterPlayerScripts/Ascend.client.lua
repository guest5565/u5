--!nonstrict
-- INKWING :: ASCENSION (v1.0, local)
--   SKILLS panel: your wing rank (D..S), aspect, mana, evolution progress, essence stock, MEDITATE,
--                 and the list of learnable ranked skills (skill points: 1 per level + 1 per boss)
--   ABSORB (E):   draw in the remains of the fallen (needs the ABSORB skill)
--   MEDITATE (R): float still, grow mana, fuse essence into your wings until they evolve
--   FX:           remains markers, absorb streams, meditation rings, rank auras on every player
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Combat = Remotes:WaitForChild("Combat")
local Fx = Remotes:WaitForChild("Fx")
local Fn = Remotes:WaitForChild("Fn")
local me = Players.LocalPlayer
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local PAPER = Color3.fromRGB(252, 248, 236)
local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local Audio = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Audio"))
local function sfx(name, opts)
	pcall(Audio.play, name, opts)
end
local UNLEASH_SFX = { Infernal = "el_fire", Holy = "el_holy", Storm = "el_storm", Cosmic = "magic", Abyssal = "el_frost", Void = "el_void", Ink = "el_nature" }

local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
	return o
end
local function stroke(o, t)
	new("UIStroke", { Thickness = t or 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	return o
end
local function skills()
	local t = {}
	for id in string.gmatch(me:GetAttribute("Skills") or "", "[^,]+") do
		t[id] = true
	end
	return t
end

local gui = new("ScreenGui", { Name = "Ascend", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 6 }, me:WaitForChild("PlayerGui"))

---------------------------------------------------------------------------
-- buttons
---------------------------------------------------------------------------
local function bigBtn(text, color, pos, size)
	local b = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = pos, Size = size, BackgroundColor3 = color, Font = FONT, TextScaled = true, Text = text, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK, AutoButtonColor = true }, gui)
	corner(b, 40)
	stroke(b, 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, b)
	return b
end
local BS = isMobile and 62 or 80
local absorbB = bigBtn(isMobile and "ABSORB" or "ABSORB (E)", rgb(90, 60, 200), isMobile and UDim2.new(1, -200, 1, -96) or UDim2.new(1, -110, 1, -18), UDim2.fromOffset(BS, BS))
local medB = bigBtn(isMobile and "MEDITATE" or "MEDITATE (R)", rgb(60, 150, 140), isMobile and UDim2.new(1, -200, 1, -166) or UDim2.new(1, -200, 1, -18), UDim2.fromOffset(BS, BS))
local unB = bigBtn(isMobile and "UNLEASH" or "UNLEASH (Q)", rgb(220, 70, 110), isMobile and UDim2.new(1, -200, 1, -236) or UDim2.new(1, -290, 1, -18), UDim2.fromOffset(BS, BS))
local senseB = bigBtn(isMobile and "SENSE" or "SENSE (V)", rgb(70, 140, 230), isMobile and UDim2.new(1, -270, 1, -166) or UDim2.new(1, -380, 1, -18), UDim2.fromOffset(BS, BS))
senseB.Visible = false
absorbB.Visible, medB.Visible, unB.Visible = false, false, false
local skillB = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, isMobile and 50 or 76), Size = UDim2.fromOffset(isMobile and 84 or 104, isMobile and 52 or 66), BackgroundColor3 = rgb(230, 170, 60), Font = FONT, TextScaled = true, Text = isMobile and "SKILLS" or "SKILLS (K)", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)
corner(skillB, 14)
stroke(skillB, 3)
skillB.Visible = false -- v1.9: the menu orb opens skills

-- always-on rank badge under the level panel: wing rank + mana (+ meditating hint)
local badge = new("TextButton", { Position = UDim2.new(0, 14, 0, 138), Size = UDim2.fromOffset(isMobile and 190 or 230, isMobile and 26 or 30), BackgroundColor3 = rgb(36, 32, 58), Font = FONT, TextScaled = true, Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4 }, gui)
corner(badge, 10)
stroke(badge, 2)
-- current training from Master Orren (under the mana badge)
local trainL = new("TextLabel", { Position = UDim2.new(0, 14, 0, isMobile and 168 or 172), Size = UDim2.fromOffset(isMobile and 260 or 340, isMobile and 20 or 24), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = rgb(255, 235, 160), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)
local function trainRefresh()
	trainL.Text = me:GetAttribute("TrainText") or ""
end
me:GetAttributeChangedSignal("TrainText"):Connect(trainRefresh)
trainRefresh()
-- v1.8c MANA BAR: current / max. Meditate to refill; meditate while FULL to raise the max.
badge.Text = ""
local manaFill = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundColor3 = rgb(80, 150, 255), BorderSizePixel = 0 }, badge)
corner(manaFill, 8)
new("UIGradient", { Color = ColorSequence.new(rgb(120, 200, 255), rgb(70, 110, 255)) }, manaFill)
local manaTxt = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK, ZIndex = 3 }, badge)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, manaTxt)
local function badgeRefresh()
badge.Visible = false -- v1.9: the bottom-left vitals show mana
trainL.Position = UDim2.new(0, 14, 0, isMobile and 104 or 12)
	local cur, mx = me:GetAttribute("Mana") or 0, math.max(1, me:GetAttribute("ManaMax") or 1)
	local med = me:GetAttribute("Meditating")
	manaFill.Size = UDim2.new(math.clamp(cur / mx, 0, 1), -6 * math.clamp(cur / mx, 0, 1), 1, -6)
	manaFill.Visible = cur > 0
	local cap = me:GetAttribute("CoreCap") or mx
	local atCap = mx >= cap
	manaTxt.Text = ("MANA  %d / %d%s"):format(cur, mx, atCap and "  (CORE LIMIT)" or (med and (cur >= mx and "   GROWING" or "   ...") or ""))
	badge:FindFirstChildOfClass("UIStroke").Color = G.RANK_COLORS[me:GetAttribute("WingRank") or 1]
end
for _, a in ipairs({ "WingRank", "Mana", "ManaMax", "CoreCap", "Meditating" }) do
	me:GetAttributeChangedSignal(a):Connect(badgeRefresh)
end
badgeRefresh()

-- SKILLS BOARD (v1.2, drawn like the sketch): a white hand-drawn board of skill tiles.
-- Tap a tile -> a skill card pops up: name on top, the symbol in a circle, a short line, "Rank C" at the bottom.
---------------------------------------------------------------------------
local HAND = Enum.Font.GothamBold
local WHITE = rgb(40, 40, 44) -- v1.9: dark grey + gold board
local TILE = rgb(54, 54, 60)
local YEL = rgb(240, 200, 70)
local function strokeY(o, t)
	new("UIStroke", { Thickness = t or 3, Color = YEL, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	return o
end
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0.8, 0), BackgroundColor3 = WHITE, Rotation = 0, Visible = false }, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(720, 480) }, panel)
corner(panel, 26)
strokeY(panel, 3)
local close = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = WHITE, Font = HAND, TextScaled = true, Text = "x", TextColor3 = YEL, ZIndex = 5 }, panel)
corner(close, 19)
strokeY(close, 2)
-- v1.8: a SCROLLING board of hand-drawn slots (3 per row, 2 rows visible) - room for every skill
local JIT = {
	{ 0.03, 0.05, 0.27, 0.46, -1.2 }, { 0.36, 0.04, 0.3, 0.48, 1.0 }, { 0.73, 0.08, 0.22, 0.42, -0.6 },
	{ 0.05, 0.06, 0.25, 0.4, 0.8 }, { 0.38, 0.05, 0.27, 0.41, -0.9 }, { 0.72, 0.07, 0.23, 0.39, 1.3 },
}
local N_SLOTS = 8
local ROWS = 2
local scroller = new("ScrollingFrame", { Position = UDim2.fromScale(0.02, 0.04), Size = UDim2.fromScale(0.96, 0.54), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = YEL, CanvasSize = UDim2.fromScale(0, 1), ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar }, panel)
local SLOTS = {}
for i = 1, N_SLOTS do
	local row, col = math.floor((i - 1) / 4), (i - 1) % 4
	SLOTS[i] = { 0.01 + col * 0.248, row * 0.5 + 0.02, 0.23, 0.46, 0 }
end
local TAG = { rotation = "Mana that never rests", sense = "See the mana of all things", meditate = "Gather strength", absorb = "Devour what falls", unleash = "Release everything", abysseye = "See what hides" }
local ORDER = { "meditate", "absorb", "sense", "rotation", "unleash", "abysseye" }
local byId = {}
for _, sk in ipairs(G.Skills) do
	byId[sk.id] = sk
end

-- symbols drawn with UI shapes (no images needed)
local function shape(parent, props, round)
	local f = new("Frame", props, parent)
	f.BorderSizePixel = 0
	if round then
		corner(f, 999)
	end
	return f
end
local function ring(parent, sc, col, th)
	local f = shape(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(sc, sc), BackgroundTransparency = 1 }, true)
	new("UIStroke", { Thickness = th or 3, Color = col }, f)
	return f
end
local ICON = {}
function ICON.meditate(f, col) -- a seated figure inside a circle
	ring(f, 0.92, col, 3)
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = col }, true)
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 0.26), BackgroundColor3 = col }, true)
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.5, 0.12), BackgroundColor3 = col }, true)
	for _, sd in ipairs({ -1, 1 }) do
		shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + sd * 0.16, 0.56), Size = UDim2.fromScale(0.2, 0.05), Rotation = sd * 35, BackgroundColor3 = col }, true)
	end
end
function ICON.absorb(f, col) -- a spiral drawing inward
	for k = 1, 4 do
		local r = ring(f, 0.95 - k * 0.19, col, 3)
		r.Rotation = k * 25
		local gap = shape(r, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.3, 0.12), BackgroundColor3 = TILE })
		gap.ZIndex = 3
	end
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.1), BackgroundColor3 = col }, true)
end
function ICON.rotation(f, col) -- mana circling a core
	ring(f, 0.9, col, 3)
	ring(f, 0.5, col, 2)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45), Size = UDim2.fromScale(0.14, 0.14), BackgroundColor3 = col }, true)
	end
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = col }, true)
end
function ICON.unleash(f, col) -- a burst
	for k = 0, 7 do
		shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k % 2 == 0 and 0.9 or 0.6, 0.06), Rotation = k * 22.5, BackgroundColor3 = col }, true)
	end
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = col }, true)
end
function ICON.sense(f, col) -- ripples spreading from a dot
	for k = 1, 3 do
		local r = ring(f, 0.3 + k * 0.22, col, 3 - k * 0.6)
		r.BackgroundTransparency = 1
	end
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = col }, true)
end
function ICON.abysseye(f, col) -- an open eye
	local lid = shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.42), BackgroundTransparency = 1 }, true)
	new("UIStroke", { Thickness = 3, Color = col }, lid)
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = col }, true)
	shape(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.12, 0.12), BackgroundColor3 = rgb(20, 16, 34) }, true)
end

local tiles = {}
local selected = nil
local refreshRef
local cardF -- the pop-up skill card
local function makeTile(slot, sk)
	local tile = new("TextButton", { Position = UDim2.fromScale(slot[1], slot[2]), Size = UDim2.fromScale(slot[3], slot[4]), Rotation = 0, BackgroundColor3 = TILE, Text = "", AutoButtonColor = true }, scroller) -- v1.8b: rotated tiles escape ScrollingFrame clipping
	corner(tile, 12)
	local st = new("UIStroke", { Thickness = 2.5, Color = sk and YEL or rgb(150, 145, 160), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tile)
	local ic = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.06, 0), Size = UDim2.fromScale(0.56, 0.56), BackgroundTransparency = 1 }, tile)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, ic)
	local circ = new("Frame", { Name = "Circ", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, ic)
	corner(circ, 999)
	new("UIStroke", { Thickness = 2, Color = YEL }, circ)
	local q = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = HAND, TextScaled = true, Text = "?", TextColor3 = rgb(150, 145, 160) }, ic)
	local nm = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.66, 0), Size = UDim2.new(0.9, 0, 0.14, 0), BackgroundTransparency = 1, Font = HAND, TextScaled = true, Text = "", TextColor3 = YEL }, tile)
	local rk = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.82, 0), Size = UDim2.new(0.8, 0, 0.13, 0), BackgroundTransparency = 1, Font = HAND, TextScaled = true, Text = "", TextColor3 = YEL }, tile)
	local t = { tile = tile, st = st, ic = ic, q = q, nm = nm, rk = rk, sk = sk }
	tile.Activated:Connect(function()
		if sk then
			selected = sk.id
			if refreshRef then
				refreshRef()
			end
		end
	end)
	return t
end
for i, slot in ipairs(SLOTS) do
	local sk = byId[ORDER[i] or ""]
	local t = makeTile(slot, sk)
	if sk then
		tiles[sk.id] = t
	else
		t.nm.Text = "???"
		t.rk.Text = "coming soon"
		t.rk.TextColor3 = rgb(160, 150, 160)
	end
end
-- v1.9 detail panel along the bottom: icon, name, proficiency rank, EXP bar, efficiency, description
cardF = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.975), Size = UDim2.fromScale(0.96, 0.37), BackgroundColor3 = TILE, Visible = false, ZIndex = 10 }, panel)
corner(cardF, 12)
strokeY(cardF, 2)
local cClose = new("TextButton", { Visible = false, Size = UDim2.fromOffset(1, 1), Text = "" }, cardF)
local cTitle = new("TextLabel", { Position = UDim2.fromScale(0.22, 0.05), Size = UDim2.fromScale(0.52, 0.2), BackgroundTransparency = 1, Font = HAND, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = YEL, ZIndex = 11 }, cardF)
local cIc = new("Frame", { Position = UDim2.fromScale(0.02, 0.1), Size = UDim2.fromScale(0.18, 0.8), BackgroundTransparency = 1, ZIndex = 11 }, cardF)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, cIc)
local cCirc = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11 }, cIc)
corner(cCirc, 999)
new("UIStroke", { Thickness = 2.5, Color = YEL }, cCirc)
local cSym = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1, ZIndex = 11 }, cIc)
new("UIAspectRatioConstraint", { AspectRatio = 1 }, cSym)
local cTag = new("TextLabel", { Position = UDim2.fromScale(0.22, 0.27), Size = UDim2.fromScale(0.52, 0.13), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = rgb(200, 195, 180), ZIndex = 11 }, cardF)
local cRank = new("TextLabel", { Position = UDim2.fromScale(0.78, 0.04), Size = UDim2.fromScale(0.2, 0.42), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = "", TextColor3 = YEL, ZIndex = 11 }, cardF)
local expBg = new("Frame", { Position = UDim2.fromScale(0.22, 0.46), Size = UDim2.fromScale(0.76, 0.09), BackgroundColor3 = rgb(28, 28, 32), BorderSizePixel = 0, ZIndex = 11 }, cardF)
corner(expBg, 6)
local expFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = YEL, BorderSizePixel = 0, ZIndex = 12 }, expBg)
corner(expFill, 6)
local expT = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = HAND, TextScaled = true, Text = "", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, ZIndex = 13 }, expBg)
local effL = new("TextLabel", { Position = UDim2.fromScale(0.22, 0.58), Size = UDim2.fromScale(0.76, 0.13), BackgroundTransparency = 1, Font = HAND, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = YEL, ZIndex = 11 }, cardF)
local cInfo = new("TextLabel", { Position = UDim2.fromScale(0.22, 0.73), Size = UDim2.fromScale(0.76, 0.23), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", TextColor3 = rgb(175, 172, 165), ZIndex = 11 }, cardF)
cClose.Activated:Connect(function()
	selected = nil
	cardF.Visible = false
end)

local function drawInto(f, id, col)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIAspectRatioConstraint") and not c:IsA("UIStroke") and not c:IsA("UICorner") and c.Name ~= "Keep" then
			c:Destroy()
		end
	end
	ICON[id](f, col)
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = math.max(d.ZIndex, f.ZIndex)
		end
	end
end

local function refresh()
	local rank = me:GetAttribute("WingRank") or 1
	local mana = me:GetAttribute("Mana") or 0
	local evo = me:GetAttribute("Evo") or 0
	local has = skills()
	local okx, sxp = pcall(HttpService.JSONDecode, HttpService, me:GetAttribute("SkillXP") or "{}")
	sxp = okx and sxp or {}
	for id, t in pairs(tiles) do
		local sk = t.sk
		local learned, evolved = has[id], sk.evo and has[sk.evo.id]
		local shown = evolved and sk.evo or sk
		local key = learned and (evolved and 2 or 1) or 0
		if t.drawn ~= key then
			t.drawn = key
			for _, c in ipairs(t.ic:GetChildren()) do
				if c ~= t.q and c:IsA("GuiObject") and c.Name ~= "Circ" then
					c:Destroy()
				end
			end
			if learned then
				local hold = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1 }, t.ic)
				ICON[id](hold, evolved and G.RANK_COLORS[shown.rank] or YEL)
			end
		end
		t.q.Visible = not learned
		t.nm.Text = learned and shown.name:lower():gsub("^%l", string.upper) or "???"
		local pr = G.Proficiency(id, sxp[id], evolved)
		t.rk.Text = learned and ("Rank " .. G.PROF_RANKS[pr]) or "locked"
		t.rk.TextColor3 = learned and G.PROF_COLORS[pr] or rgb(130, 128, 125)
		t.st.Thickness = id == selected and 4 or 2.5
	end
	if not selected then
		for _, id in ipairs(ORDER) do
			if has[id] then
				selected = id
				break
			end
		end
		selected = selected or ORDER[1]
	end
	local sk = selected and byId[selected]
	if sk and not has[sk.id] then
		sk = nil -- v1.10: nothing to show for a skill you don't have
	end
	cardF.Visible = sk ~= nil
	if sk then
		local learned, evolved = has[sk.id], sk.evo and has[sk.evo.id]
		local shown = evolved and sk.evo or sk
		cTitle.Text = learned and shown.name:lower():gsub("^%l", string.upper) or "???"
		if cSym:GetAttribute("D") ~= sk.id .. tostring(learned) .. tostring(evolved) then
			cSym:SetAttribute("D", sk.id .. tostring(learned) .. tostring(evolved))
			for _, c in ipairs(cSym:GetChildren()) do
				if not c:IsA("UIAspectRatioConstraint") then
					c:Destroy()
				end
			end
			if learned then
				drawInto(cSym, sk.id, evolved and G.RANK_COLORS[shown.rank] or YEL)
			else
				new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = HAND, TextScaled = true, Text = "?", TextColor3 = rgb(150, 145, 160), ZIndex = 11 }, cSym)
			end
		end
		cTag.Text = TAG[sk.id] or ""
		local pr, eff, prog = G.Proficiency(sk.id, sxp[sk.id], evolved)
		if not learned then
			cInfo.Text = sk.how or "Train with Master Orren on the Genesis Isles."
			cRank.Text, expFill.Size, expT.Text, effL.Text = "-", UDim2.fromScale(0, 1), "LOCKED", ""
		else
			local extra = ""
			if sk.id == "meditate" and rank < 5 then
				extra = ("   Wings evolve: essence %d/%d, mana %d/%d"):format(evo, G.EVO_ESSENCE[rank], me:GetAttribute("ManaMax") or 1, G.EVO_MANA[rank])
			end
			cInfo.Text = (sk.key and ("[" .. sk.key .. "]  ") or "") .. (shown.desc or "") .. extra
			cRank.Text = G.PROF_RANKS[pr]
			cRank.TextColor3 = G.PROF_COLORS[pr]
			expFill.Size = UDim2.fromScale(prog, 1)
			expT.Text = pr >= 7 and "MASTERED" or (pr == 6 and sk.evo) and ("EVOLVES AT %d / %d %s"):format(math.floor(sxp[sk.id] or 0), sk.evo.need, sk.evo.unit) or ("PROFICIENCY %s  ->  %s"):format(G.PROF_RANKS[pr], G.PROF_RANKS[pr + 1])
			effL.Text = "EFFICIENCY  " .. G.EffLines(evolved and sk.evo.id or sk.id, eff)
		end
	end
	unB.Visible = has.unleash == true
	senseB.Visible = has.sense == true or has.truesight == true
	medB.Visible = has.meditate == true
	absorbB.Visible = absorbB.Visible and has.absorb == true
	local m = me:GetAttribute("Meditating")
	medB.Text = m and "STOP" or (isMobile and "MEDITATE" or "MEDITATE (R)")
	medB.BackgroundColor3 = m and rgb(220, 90, 90) or rgb(60, 150, 140)
end
for _, a in ipairs({ "WingRank", "Level", "HasWings", "Mana", "Evo", "Aspect", "Skills", "Essence", "Meditating", "Wing", "SkillXP" }) do
	me:GetAttributeChangedSignal(a):Connect(refresh)
end
refreshRef = refresh
refresh()

local function toggle(v)
	panel.Visible = (v == nil) and not panel.Visible or v
	if panel.Visible then
		refresh()
	else
		selected = nil
		cardF.Visible = false
	end
end
badge.Activated:Connect(function()
	toggle()
end)
_G.InkwingToggleSkills = function()
	toggle()
end
skillB.Activated:Connect(function()
	toggle()
end)
close.Activated:Connect(function()
	toggle(false)
end)

local function meditate()
	if not skills().meditate then
		return
	end
	Combat:FireServer("meditate", not me:GetAttribute("Meditating"))
end
local function absorb()
	Combat:FireServer("absorb")
end
medB.Activated:Connect(meditate)
unB.Activated:Connect(function()
	Combat:FireServer("unleash")
end)
absorbB.Activated:Connect(absorb)
-- v1.8e: SENSE IS HELD - press to open your senses (costs mana once), look around, release to close
local function senseDown()
	if _G.InkwingSenseHold then
		_G.InkwingSenseHold(true)
	end
	Combat:FireServer("sense", true)
end
local function senseUp()
	if _G.InkwingSenseHold then
		_G.InkwingSenseHold(false)
	end
	Combat:FireServer("sense", false)
end
senseB.InputBegan:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
		senseDown()
	end
end)
senseB.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
		senseUp()
	end
end)
UserInputService.InputEnded:Connect(function(io)
	if io.KeyCode == Enum.KeyCode.V then
		senseUp()
	end
end)
UserInputService.InputBegan:Connect(function(io, gp)
	if gp then
		return
	end
	if io.KeyCode == Enum.KeyCode.K then
		toggle()
	elseif io.KeyCode == Enum.KeyCode.E then
		absorb()
	elseif io.KeyCode == Enum.KeyCode.R then
		meditate()
	elseif io.KeyCode == Enum.KeyCode.V then
		senseDown()
	elseif io.KeyCode == Enum.KeyCode.Q and skills().unleash then
		Combat:FireServer("unleash")
	end
end)

---------------------------------------------------------------------------
-- remains: a marker + wisps on every corpse; ABSORB button when one is in reach
---------------------------------------------------------------------------
local RemainsF = workspace:WaitForChild("Remains")
local function dress(r)
	local e = G.ESSENCES[r:GetAttribute("Essence") or ""]
	if not e then
		return
	end
	-- v1.8e: a glossy ink orb with the essence glowing inside, soft rising wisps and twinkling motes
	local big = r:GetAttribute("Big")
	local S_ = r.Size.X
	r.Material = Enum.Material.Glass
	r.Reflectance = 0.15
	local core = new("Part", { Name = "EssenceCore", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Size = Vector3.one * S_ * 0.45, Material = Enum.Material.Neon, Color = e.color, Transparency = 0.2, CFrame = r.CFrame }, r)
	new("PointLight", { Color = e.color, Range = S_ * 2.5, Brightness = 1.2 }, core)
	local pe = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(e.color:Lerp(Color3.new(1, 1, 1), 0.5), e.color), LightEmission = 1,
		Rate = big and 30 or 6, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(0.3, 1.2), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S_ * 0.05), NumberSequenceKeypoint.new(0.5, S_ * 0.1), NumberSequenceKeypoint.new(1, 0) }) }, r)
	new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Color = ColorSequence.new(e.color), LightEmission = 0.8,
		Rate = big and 12 or 3, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(15, 15),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S_ * 0.15), NumberSequenceKeypoint.new(1, S_ * 0.4) }), RotSpeed = NumberRange.new(-30, 30) }, r)
	local bb = new("BillboardGui", { Size = UDim2.fromOffset(220, 46), StudsOffset = Vector3.new(0, r.Size.X * 0.6 + 2, 0), AlwaysOnTop = true, MaxDistance = r:GetAttribute("Big") and 120 or 28, LightInfluence = 0 }, r)
	new("TextLabel", { Size = UDim2.new(1, 0, 0.55, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "REMAINS OF " .. string.upper(r:GetAttribute("Of") or "?"), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0 }, bb)
	new("TextLabel", { Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = ("+%d %s ESSENCE"):format(r:GetAttribute("Amount") or 1, string.upper(r:GetAttribute("Essence") or "")), TextColor3 = e.color, TextStrokeTransparency = 0 }, bb)
	local _ = pe
end
for _, r in ipairs(RemainsF:GetChildren()) do
	dress(r)
end
RemainsF.ChildAdded:Connect(dress)
task.spawn(function()
	while true do
		task.wait(0.25)
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		local near = false
		if hrp and skills().absorb then
			for _, r in ipairs(RemainsF:GetChildren()) do
				if (r.Position - hrp.Position).Magnitude - r.Size.X / 2 < (skills().gluttony and 150 or 60) then
					near = true
					break
				end
			end
		end
		absorbB.Visible = near
		absorbB.Text = skills().gluttony and "DEVOUR" or (isMobile and "ABSORB" or "ABSORB (E)")
	end
end)

---------------------------------------------------------------------------
-- FX: absorb streams, evolution burst, meditation rings, rank auras
---------------------------------------------------------------------------
local fxF = new("Folder", { Name = "AscendFX" }, workspace)
local function orb(pos, color, size)
	local p = new("Part", { Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = color, Size = Vector3.one * size, CFrame = CFrame.new(pos) }, fxF)
	return p
end
Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Absorb" then
		-- v1.7 SOUL ABSORB (Skyrim dragon-soul style): the remains flare up and dissolve into
		-- spiralling streams of light that rise, swirl and pour into the absorber's chest.
		local pl = info.player
		local big = info.big
		local col = info.color
		if pl == me then
			sfx(big and "reveal_epic" or "heal", { vol = 0.6 })
			sfx("magic", { vol = 0.35 })
		end
		local from = info.from
		local ghost = orb(from, col, big and 7 or 3.2)
		ghost.Transparency = 0.2
		TweenService:Create(ghost, TweenInfo.new(big and 2.2 or 1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 0.3, Transparency = 1 }):Play()
		task.delay(big and 2.3 or 1.5, function()
			ghost:Destroy()
		end)
		local gl = new("PointLight", { Color = col, Range = big and 30 or 16, Brightness = 3 }, ghost)
		TweenService:Create(gl, TweenInfo.new(big and 2.2 or 1.4), { Brightness = 0 }):Play()
		local n = big and 16 or 8
		local arrived = 0
		for i = 1, n do
			task.delay((i - 1) * (big and 0.06 or 0.05), function()
				local hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end
				local o = orb(from, col:Lerp(Color3.new(1, 1, 1), 0.3), big and 0.7 or 0.45)
				local a0 = new("Attachment", { Position = Vector3.new(0, big and 0.6 or 0.35, 0) }, o)
				local a1 = new("Attachment", { Position = Vector3.new(0, -(big and 0.6 or 0.35), 0) }, o)
				new("Trail", {
					Attachment0 = a0, Attachment1 = a1, Lifetime = big and 0.7 or 0.45, FaceCamera = true, LightEmission = 1, MinLength = 0.05,
					Color = ColorSequence.new(Color3.new(1, 1, 1), col),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
					WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) }),
				}, o)
				local spread = big and 6 or 2.5
				local start = from + Vector3.new(math.random() * 2 - 1, math.random() * 0.5, math.random() * 2 - 1) * spread
				local rise = start + Vector3.new(0, (big and 9 or 5) + math.random() * 4, 0)
				local spin, ph = (math.random() < 0.5 and -1 or 1) * (big and 9 or 7), math.random() * 6.28
				local t0, dur = os.clock(), (big and 1.7 or 1.15) + math.random() * 0.4
				local c
				c = RunService.Heartbeat:Connect(function()
					local u = math.min(1, (os.clock() - t0) / dur)
					local goal = hrp.Position + Vector3.new(0, 0.8, 0)
					-- quadratic bezier: start -> high above the remains -> into the chest
					local e = u * u * (3 - 2 * u)
					local a, b = start:Lerp(rise, e), rise:Lerp(goal, e)
					local p = a:Lerp(b, e)
					-- corkscrew around the path, tightening as it arrives
					local fwd = (goal - p)
					local axis = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.yAxis
					local side = axis:Cross(Vector3.yAxis)
					side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
					local up2 = side:Cross(axis)
					local r = (big and 3 or 1.6) * math.sin(u * math.pi) 
					local ang = ph + u * spin
					o.CFrame = CFrame.new(p + side * math.cos(ang) * r + up2 * math.sin(ang) * r)
					if u >= 1 then
						c:Disconnect()
						o.Transparency = 1
						task.delay(0.8, function()
							o:Destroy()
						end)
						arrived += 1
						if arrived == 1 or arrived == n then
							local hp = hrp.Position
							local big2 = arrived == n
							local ring = orb(hp, col, 1)
							ring.Shape = Enum.PartType.Cylinder
							ring.Size = Vector3.new(0.2, 2, 2)
							ring.CFrame = CFrame.new(hp - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
							ring.Transparency = 0.3
							local R = big2 and (big and 26 or 14) or 6
							TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, R, R), Transparency = 1 }):Play()
							task.delay(0.55, function()
								ring:Destroy()
							end)
							if big2 then
								local body = orb(hp, col, 5)
								body.Transparency = 0.5
								TweenService:Create(body, TweenInfo.new(0.6), { Size = Vector3.one * 9, Transparency = 1 }):Play()
								task.delay(0.65, function()
									body:Destroy()
								end)
								if pl == me then
									local cc = new("ColorCorrectionEffect", { TintColor = col:Lerp(Color3.new(1, 1, 1), 0.55), Brightness = big and 0.25 or 0.12, Saturation = 0.2 }, game:GetService("Lighting"))
									TweenService:Create(cc, TweenInfo.new(big and 1.4 or 0.8), { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 }):Play()
									task.delay(big and 1.5 or 0.9, function()
										cc:Destroy()
									end)
									if _G.InkwingShake then
										_G.InkwingShake(big and 0.55 or 0.2, big and 0.9 or 0.4)
									end
								end
							end
						end
					end
				end)
			end)
		end
	elseif kind == "Unleash" or kind == "UnleashHit" then
		local col = info.color
		if kind == "Unleash" then
			sfx(UNLEASH_SFX[info.kind] or "magic", { vol = info.player == me and 0.8 or 0.4 })
		end
		local R = math.max(8, info.radius or 20)
		local ball = orb(info.pos, col, 2)
		ball.Transparency = 0.3
		TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * R * 2, Transparency = 1 }):Play()
		task.delay(0.55, function()
			ball:Destroy()
		end)
		if info.kind == "Cosmic" and kind == "UnleashHit" then -- a falling star
			local st = orb(info.pos + Vector3.new(0, 120, 0), col, 3)
			TweenService:Create(st, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { CFrame = CFrame.new(info.pos) }):Play()
			task.delay(0.3, function()
				st:Destroy()
			end)
		end
		if info.kind == "Void" and kind == "Unleash" then -- the singularity collapses inward
			local shell = orb(info.pos, Color3.new(0, 0, 0), R * 2)
			shell.Material = Enum.Material.SmoothPlastic
			shell.Transparency = 0.5
			TweenService:Create(shell, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.one * 2, Transparency = 0 }):Play()
			task.delay(0.85, function()
				shell:Destroy()
			end)
		end
		for _, h in ipairs(info.hits or {}) do -- lightning / drain beams
			local a, b = h[2], typeof(h[1]) == "Instance" and h[1].Position or info.pos
			local segs, prev = 6, a
			for k = 1, segs do
				local u = k / segs
				local pt = a:Lerp(b, u) + (k < segs and Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3)) or Vector3.zero)
				local len = (pt - prev).Magnitude
				local seg = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = col, Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt((pt + prev) / 2, pt) }, fxF)
				TweenService:Create(seg, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				task.delay(0.45, function()
					seg:Destroy()
				end)
				prev = pt
			end
		end
		if kind == "Unleash" and info.player == me then
			local l = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(500, 50), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = (info.cat and "CATASTROPHE: " or "") .. info.name, TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)
			TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1, Position = UDim2.fromScale(0.5, 0.25) }):Play()
			task.delay(1.3, function()
				l:Destroy()
			end)
		end
	elseif kind == "Evolve" then
		local pl = info.player
		local hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local col = G.RANK_COLORS[info.rank] or Color3.new(1, 1, 1)
		if pl == me then
			sfx(({ "reveal_common", "reveal_uncommon", "reveal_rare", "reveal_epic", "reveal_legendary" })[info.rank] or "level_up", { vol = 0.8 })
		end
		for k = 1, 3 do
			task.delay(k * 0.15, function()
				local ring = new("Part", { Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = 0.2, Size = Vector3.new(0.4, 4, 4), CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.pi / 2) }, fxF)
				TweenService:Create(ring, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, 90, 90), Transparency = 1 }):Play()
				task.delay(1.3, function()
					ring:Destroy()
				end)
			end)
		end
		local pillar = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = 0.3, Size = Vector3.new(6, 400, 6), CFrame = CFrame.new(hrp.Position + Vector3.new(0, 200, 0)) }, fxF)
		TweenService:Create(pillar, TweenInfo.new(2), { Size = Vector3.new(0.5, 400, 0.5), Transparency = 1 }):Play()
		task.delay(2.1, function()
			pillar:Destroy()
		end)
		if pl == me then
			workspace.CurrentCamera.FieldOfView = 90
			TweenService:Create(workspace.CurrentCamera, TweenInfo.new(1.4), { FieldOfView = 70 }):Play()
		end
	end
end)

-- per-player aura that rises OUT OF THE BODY (every limb emits flame-like wisps):
-- rank B+ = a faint aura, A = strong, S = blazing; meditating = the aura flares and breathes
local FLAME = "rbxasset://textures/particles/fire_main.dds"
local auras = {}
local LIMBS = { "UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local function auraFor(pl)
	local c = pl.Character
	local a = auras[pl]
	if a and a.char == c then
		return a
	end
	if a then
		for _, e in ipairs(a.ems) do
			e:Destroy()
		end
	end
	if not c or not c:FindFirstChild("Head") then
		return nil
	end
	a = { char = c, ems = {} }
	for _, n in ipairs(LIMBS) do
		local part = c:FindFirstChild(n)
		if part and part:IsA("BasePart") then
			local e = new("ParticleEmitter", { Name = "AscendAura", Texture = FLAME, LightEmission = 1, LightInfluence = 0, Rate = 0, Lifetime = NumberRange.new(0.45, 0.8), Speed = NumberRange.new(0.6, 1.6), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 7, 0), Drag = 1.5, Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-40, 40), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.6, 0.6), NumberSequenceKeypoint.new(1, 0) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 1) }) }, part)
			table.insert(a.ems, e)
		end
	end
	auras[pl] = a
	return a
end
Players.PlayerRemoving:Connect(function(pl)
	auras[pl] = nil
end)
local auraAcc = 0
RunService.RenderStepped:Connect(function(dt)
	auraAcc += dt
	if auraAcc < 0.1 then
		return
	end
	auraAcc = 0
	local t = os.clock()
	for _, pl in ipairs(Players:GetPlayers()) do
		local a = auraFor(pl)
		if a then
			local rank = pl:GetAttribute("WingRank") or 1
			local asp = G.ESSENCES[pl:GetAttribute("Aspect") or ""]
			local col = asp and asp.color or G.RANK_COLORS[rank]
			local m = pl:GetAttribute("Meditating") == true
			local rate = (rank >= 3 and (rank - 2) * 3 or 0)
			if m then
				rate = 10 + rank * 3 + math.sin(t * 1.8) * 4 -- breathing flare
			end
			if me:GetAttribute("HighQ") == false then
				rate *= 0.4
			end
			local cs = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.35), col)
			for _, e in ipairs(a.ems) do
				e.Rate = rate
				e.Color = cs
			end
		end
	end
end)

-- awakening banners: a skill wakes up / your wings unfold
local function banner(top, big, col, sub)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(620, 150), BackgroundTransparency = 1 }, gui)
	local a = new("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = top, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, f)
	local b = new("TextLabel", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = big, TextColor3 = col, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, f)
	local c = new("TextLabel", { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = sub, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, f)
	new("UIScale", { Scale = isMobile and 0.62 or 1 }, f)
	task.delay(4.5, function()
		for _, l in ipairs({ a, b, c }) do
			TweenService:Create(l, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.delay(0.9, function()
			f:Destroy()
		end)
	end)
end
Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "SkillAwaken" then
		-- v1.8f: no awakening banner - a soft chime + the menu orb pulses
		sfx("level_up", { vol = 0.4 })
		if _G.InkwingMenuPing then
			_G.InkwingMenuPing("skills")
		end
	elseif kind == "WingsAwaken" then
		banner("THE SHRINE ANSWERS YOUR HUNT", "YOUR PAPER WINGS UNFOLD", rgb(255, 230, 150), isMobile and "JUMP, THEN TAP UP TO FLY" or "JUMP, THEN HOLD SPACE TO FLY")
		sfx("level_up", { vol = 0.9 })
	end
end)

-------------------------------------------------------------------------
-- ALL-SEEING EYE: screen markers for remains / giants / bosses within 1500 studs; FEAST counter
---------------------------------------------------------------------------
local markF = new("Folder", { Name = "SeeMarks" }, gui)
local pool = {}
local feastL = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, isMobile and 200 or 214), Size = UDim2.fromOffset(260, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "", TextColor3 = rgb(255, 120, 90), TextStrokeTransparency = 0, TextStrokeColor3 = INK, Visible = false }, gui)
local function mark(i)
	local m = pool[i]
	if not m then
		m = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(150, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextStrokeTransparency = 0, TextStrokeColor3 = INK }, markF)
		pool[i] = m
	end
	return m
end
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	local fu = me:GetAttribute("FeastUntil") or 0
	local left = fu - workspace:GetServerTimeNow()
	feastL.Visible = left > 0
	if left > 0 then
		feastL.Text = ("FEAST x%d  (+%d%% DAMAGE)  %ds"):format(me:GetAttribute("Feast") or 0, (me:GetAttribute("Feast") or 0) * 6, math.ceil(left))
	end
	acc += dt
	if acc < 0.05 then
		return
	end
	acc = 0
	local n = 0
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if skills().allsee and hrp and not panel.Visible and me:GetAttribute("Vision") then -- v1.10: only inside Mana Vision
		local cam = workspace.CurrentCamera
		local function put(pos, text, col)
			local sp, on = cam:WorldToViewportPoint(pos)
			if not on then
				return
			end
			n += 1
			local m = mark(n)
			m.Visible = true
			m.Position = UDim2.fromOffset(sp.X, sp.Y)
			m.Text = text
			m.TextColor3 = col
		end
		for _, r in ipairs(RemainsF:GetChildren()) do
			local d = (r.Position - hrp.Position).Magnitude
			if d < 1500 and d > 60 then
				local e = G.ESSENCES[r:GetAttribute("Essence") or ""]
				put(r.Position, "+", e and e.color or Color3.new(1, 1, 1))
			end
		end
		local ef = workspace:FindFirstChild("Enemies")
		for _, part in ipairs(ef and ef:GetChildren() or {}) do
			if part:IsA("BasePart") then
				local def = G.Enemies[part:GetAttribute("Type") or ""]
				if def and (def.giant or def.boss) then
					local d = (part.Position - hrp.Position).Magnitude
					if d < 2500 then
						put(part.Position, "!", rgb(255, 90, 90))
					end
				end
			end
		end
	end
	for i = n + 1, #pool do
		pool[i].Visible = false
	end
end)
