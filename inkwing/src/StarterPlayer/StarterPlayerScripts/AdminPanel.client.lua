--!nonstrict
-- INKWING :: ADMIN PANEL (only shows for admins: tim_500 / 410255186, or anyone in Studio)
-- Target box empty = yourself. Amount box feeds +INK / +FEATHERS / LEVEL / TIER.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local me = Players.LocalPlayer
local AdminFn = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin")

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local PAPER = Color3.fromRGB(253, 250, 240)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function new(c, props, parent)
	local o = Instance.new(c)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function deco(o, r, th)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
	if th then
		new("UIStroke", { Thickness = th, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	end
	return o
end

local gui = new("ScreenGui", { Name = "AdminPanel", ResetOnSpawn = false, DisplayOrder = 20, Enabled = false }, me:WaitForChild("PlayerGui"))
local open = new("TextButton", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, isMobile and 104 or 158), Size = UDim2.fromOffset(isMobile and 84 or 104, isMobile and 40 or 46),
	BackgroundColor3 = Color3.fromRGB(60, 60, 80), Font = FONT, Text = "ADMIN", TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, gui)
deco(open, 12, 3)
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 480), BackgroundColor3 = PAPER, Visible = false }, gui)
deco(panel, 20, 5)
local fit = new("UIScale", {}, panel)
local function doFit()
	local vs = workspace.CurrentCamera.ViewportSize
	fit.Scale = math.clamp(math.min((vs.X - 30) / 560, (vs.Y - 30) / 420), 0.45, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(doFit)
doFit()
new("TextLabel", { Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1, Font = FONT, Text = "ADMIN PANEL", TextScaled = true, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left }, panel)
local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(44, 38), BackgroundColor3 = Color3.fromRGB(240, 70, 80), Font = FONT, Text = "X", TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, panel)
deco(close, 10, 3)
local function box(x, w, placeholder, text)
	local b = new("TextBox", { Position = UDim2.fromOffset(x, 54), Size = UDim2.fromOffset(w, 38), BackgroundColor3 = Color3.new(1, 1, 1), Font = FONT, PlaceholderText = placeholder, Text = text or "",
		TextScaled = true, TextColor3 = INK, ClearTextOnFocus = false }, panel)
	deco(b, 10, 2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	return b
end
local who = box(18, 300, "TARGET PLAYER (EMPTY = ME)")
local amount = box(330, 212, "AMOUNT", "10000")
local out = new("TextLabel", { Position = UDim2.new(0, 18, 1, -42), Size = UDim2.new(1, -36, 0, 30), BackgroundTransparency = 1, Font = FONT, Text = "", TextScaled = true, TextColor3 = Color3.fromRGB(70, 120, 70) }, panel)

local grid = new("Frame", { Position = UDim2.fromOffset(18, 104), Size = UDim2.new(1, -36, 0, 320), BackgroundTransparency = 1 }, panel)
new("UIGridLayout", { CellSize = UDim2.fromOffset(124, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
local confirmReset = 0
local BUTTONS = {
	{ "+ INK", "ink", Color3.fromRGB(70, 150, 255) },
	{ "+ FEATHERS", "feathers", Color3.fromRGB(150, 150, 170) },
	{ "+ ESSENCE", "essence", Color3.fromRGB(190, 110, 255) },
	{ "SKY SHOWER", "shower", Color3.fromRGB(120, 190, 255) },
	{ "LEVIATHAN", "leviathan", Color3.fromRGB(90, 160, 230) },
	{ "TIME: DAY", "tod_day", Color3.fromRGB(255, 220, 120) },
	{ "TIME: SUNSET", "tod_sunset", Color3.fromRGB(255, 150, 90) },
	{ "TIME: NIGHT", "tod_night", Color3.fromRGB(80, 90, 170) },
	{ "TIME: REAL", "tod_real", Color3.fromRGB(160, 160, 170) },
	{ "FALLING STAR", "star", Color3.fromRGB(190, 170, 255) },
	{ "GIVE PLUME (N=1-8)", "plume", Color3.fromRGB(255, 160, 230) },
	{ "SET RANK", "rank", Color3.fromRGB(255, 200, 60) },
	{ "+ MANA", "mana", Color3.fromRGB(90, 200, 255) },
	{ "ALL SKILLS", "skills", Color3.fromRGB(230, 170, 60) },
	{ "RESET SKILLS", "unskill", Color3.fromRGB(160, 120, 90) },
	{ "SET LEVEL", "level", Color3.fromRGB(110, 190, 120) },
	{ "SET TIER", "tier", Color3.fromRGB(255, 190, 70) },
	{ "UNLOCK ALL", "unlock", Color3.fromRGB(255, 160, 40) },
	{ "SKIP QUEST", "quest", Color3.fromRGB(220, 170, 40) },
	{ "HEAL", "heal", Color3.fromRGB(90, 200, 140) },
	{ "GOD MODE", "god", Color3.fromRGB(150, 110, 240) },
	{ "SPAWN BOSS", "boss", Color3.fromRGB(200, 40, 80) },
	{ "KILL ALL", "killall", Color3.fromRGB(160, 50, 60) },
	{ "TP ISLES", "tp:isles", Color3.fromRGB(110, 170, 230) },
	{ "TP STORM", "tp:storm", Color3.fromRGB(80, 90, 130) },
	{ "TP DEPTHS", "tp:depths", Color3.fromRGB(90, 50, 150) },
	{ "TP BOSS", "tp:boss", Color3.fromRGB(120, 30, 70) },
	{ "TP SEA", "tp:sea", Color3.fromRGB(40, 110, 200) },
	{ "TP UNDERWATER", "tp:underwater", Color3.fromRGB(20, 70, 150) },
	{ "TP COSMOS", "tp:cosmos", Color3.fromRGB(70, 50, 160) },
	{ "TP HEAVEN", "tp:heaven", Color3.fromRGB(220, 180, 80) },
	{ "TP HELL", "tp:hell", Color3.fromRGB(200, 70, 30) },
	{ "TP ABYSS", "tp:abyss", Color3.fromRGB(40, 40, 60) },
	{ "TP UNKNOWN", "tp:unknown", Color3.fromRGB(110, 40, 160) },
	{ "RESET PLAYER", "reset", Color3.fromRGB(90, 30, 30) },
}
for i, b in ipairs(BUTTONS) do
	local btn = new("TextButton", { LayoutOrder = i, BackgroundColor3 = b[3], Font = FONT, Text = b[1], TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, grid)
	deco(btn, 10, 2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, btn)
	btn.Activated:Connect(function()
		local action, arg = b[2], amount.Text
		if action:sub(1, 3) == "tp:" then
			action, arg = "tp", action:sub(4)
		end
		if action == "reset" then
			if os.clock() - confirmReset > 3 then
				confirmReset = os.clock()
				out.Text = "PRESS RESET AGAIN TO CONFIRM (" .. (who.Text ~= "" and who.Text or me.Name) .. ")"
				out.TextColor3 = Color3.fromRGB(200, 60, 60)
				return
			end
			confirmReset = 0
		end
		local ok, res = pcall(function()
			return AdminFn:InvokeServer(action, arg, who.Text)
		end)
		out.Text = ok and tostring(res) or "ERROR"
		out.TextColor3 = (ok and tostring(res):sub(1, 2) == "OK") and Color3.fromRGB(70, 140, 70) or Color3.fromRGB(200, 60, 60)
	end)
end
open.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
open.Visible = false -- v1.10: opened from the menu orb
_G.InkwingToggleAdmin = function()
	panel.Visible = not panel.Visible
end
close.Activated:Connect(function()
	panel.Visible = false
end)
local function upd()
	gui.Enabled = me:GetAttribute("IsAdmin") == true
end
me:GetAttributeChangedSignal("IsAdmin"):Connect(upd)
upd()

-- ALTITUDE READOUT (admins only, for testing): height, zone, speed
do
	local G = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Game"))
	local alt = Instance.new("TextLabel")
	alt.AnchorPoint = Vector2.new(0.5, 0)
	alt.Position = UDim2.new(0.5, 0, 0, 4)
	alt.Size = UDim2.fromOffset(360, 22)
	alt.BackgroundColor3 = Color3.new(0, 0, 0)
	alt.BackgroundTransparency = 0.45
	alt.TextColor3 = Color3.new(1, 1, 1)
	alt.Font = Enum.Font.Code
	alt.TextSize = 15
	alt.Visible = false
	alt.Parent = gui
	game:GetService("RunService").Heartbeat:Connect(function()
		alt.Visible = false -- v1.10 decluttered
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if not (alt.Visible and hrp) then
			return
		end
		local zone = "OPEN SKY"
		for _, z in ipairs(G.Zones) do
			if z.test(hrp.Position) then
				zone = z.name
				break
			end
		end
		alt.Text = ("Y %d  |  %s  |  %d studs/s"):format(math.floor(hrp.Position.Y), zone, math.floor(hrp.AssemblyLinearVelocity.Magnitude))
	end)
end
