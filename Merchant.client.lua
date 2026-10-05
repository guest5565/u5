-- Merchant.client (v1.5): dresses the server's MerchantRoot as a flying airship, the shop window,
-- the treasure-map trail and little buff timers.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
if (RS:FindFirstChild("Realm") and RS.Realm.Value or "Overworld") ~= "Overworld" then
	return
end
local G = require(RS:WaitForChild("Shared"):WaitForChild("Game"))
local Audio = require(RS:WaitForChild("Shared"):WaitForChild("Audio"))
local Remotes = RS:WaitForChild("Remotes")
local Combat, Fx = Remotes:WaitForChild("Combat"), Remotes:WaitForChild("Fx")
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local rgb = Color3.fromRGB

---------------------------------------------------------------------------
-- the airship (client visuals, smoothly following the server root)
---------------------------------------------------------------------------
local root = workspace:WaitForChild("MerchantRoot", 60)
if not root then
	return
end
local ship = Instance.new("Model")
ship.Name = "MerchantAirship"
local parts = {}
local function add(size, off, color, mat, shape, tr)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.Color, p.Material = size, color, mat or Enum.Material.Wood
	if shape then
		p.Shape = shape
	end
	p.Transparency = tr or 0
	p.Parent = ship
	table.insert(parts, { p = p, off = off })
	return p
end
local WOOD, DARK, CLOTH, GOLD = rgb(140, 90, 50), rgb(90, 58, 34), rgb(200, 70, 60), rgb(240, 190, 70)
-- hull + deck + bow (v1.7: solid - you can land on the airship and it carries you)
local solid = {}
local function solidify(p)
	p.CanCollide, p.CanQuery = true, true
	solid[p] = true
	return p
end
solidify(add(Vector3.new(10, 5, 28), CFrame.new(0, 0, 0), WOOD))
solidify(add(Vector3.new(9, 0.6, 27), CFrame.new(0, 2.8, 0), rgb(170, 120, 75), Enum.Material.WoodPlanks))
local bow = solidify(add(Vector3.new(10, 5, 7), CFrame.new(0, 0, -17.5) * CFrame.Angles(0, math.pi, 0), WOOD))
bow.Shape = Enum.PartType.Block
add(Vector3.new(10.4, 0.6, 28.4), CFrame.new(0, 1.2, 0), GOLD, Enum.Material.Metal)
for _, sd in ipairs({ -1, 1 }) do
	solidify(add(Vector3.new(0.5, 1.6, 27), CFrame.new(sd * 4.8, 3.9, 0), DARK)) -- rails
	for k = -1, 1 do
		add(Vector3.new(0.3, 1.4, 1.4), CFrame.new(sd * 5.1, 0.6, k * 8) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder) -- portholes
	end
end
-- mast + balloon (striped envelope) + ropes
add(Vector3.new(14, 1, 1), CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.pi / 2), DARK, nil, Enum.PartType.Cylinder)
local env = add(Vector3.new(30, 16, 16), CFrame.new(0, 22, 0) * CFrame.Angles(0, math.pi / 2, 0), CLOTH, Enum.Material.Fabric, Enum.PartType.Cylinder)
add(Vector3.new(16, 16, 16), CFrame.new(0, 22, -15), CLOTH, Enum.Material.Fabric, Enum.PartType.Ball)
add(Vector3.new(16, 16, 16), CFrame.new(0, 22, 15), CLOTH, Enum.Material.Fabric, Enum.PartType.Ball)
for k = -2, 2 do
	add(Vector3.new(1.2, 16.4, 16.4), CFrame.new(0, 22, k * 6) * CFrame.Angles(0, math.pi / 2, 0), rgb(250, 235, 200), Enum.Material.Fabric, Enum.PartType.Cylinder)
end
for _, c in ipairs({ { -4, -12 }, { 4, -12 }, { -4, 12 }, { 4, 12 } }) do
	add(Vector3.new(0.2, 12, 0.2), CFrame.new(c[1] * 0.9, 9, c[2] * 0.9) * CFrame.Angles(c[2] > 0 and 0.25 or -0.25, 0, c[1] > 0 and -0.25 or 0.25), rgb(80, 70, 60), Enum.Material.Fabric)
end
-- propeller + lanterns + the merchant himself
local prop = add(Vector3.new(0.4, 7, 1), CFrame.new(0, 1, 16.5), DARK)
local lantL = add(Vector3.new(1.2, 1.2, 1.2), CFrame.new(-5, 4.8, -12), rgb(255, 200, 100), Enum.Material.Neon, Enum.PartType.Ball)
local lantR = add(Vector3.new(1.2, 1.2, 1.2), CFrame.new(5, 4.8, -12), rgb(255, 200, 100), Enum.Material.Neon, Enum.PartType.Ball)
for _, l in ipairs({ lantL, lantR }) do
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = rgb(255, 200, 120), 18, 1.5
	pl.Parent = l
end
-- crates of wares
for k = 0, 3 do
	solidify(add(Vector3.new(2.2, 2.2, 2.2), CFrame.new(k % 2 == 0 and -2.8 or 2.8, 4.2, 4 + math.floor(k / 2) * 3), rgb(160, 120, 70), Enum.Material.WoodPlanks))
end
-- sign
local signP = add(Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 33, 0), WOOD, nil, nil, 1)
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(260, 46)
bb.MaxDistance = 600
bb.LightInfluence = 0
bb.AlwaysOnTop = false
bb.Enabled = false -- v1.8: no floating sign (the ship speaks for itself)
bb.Parent = signP
local signT = Instance.new("TextLabel")
signT.Size = UDim2.fromScale(1, 1)
signT.BackgroundTransparency = 1
signT.Font = FONT
signT.TextScaled = true
signT.Text = "WANDERING MERCHANT"
signT.TextColor3 = rgb(255, 215, 120)
signT.TextStrokeTransparency = 0
signT.Parent = bb
ship.Parent = workspace
local _ = env

local NPCModel = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("NPCModel"))
local captain = NPCModel.build("merchant", ship)
local cur = root.CFrame
local prevBase
local rideRP = RaycastParams.new()
rideRP.FilterType = Enum.RaycastFilterType.Include
rideRP.FilterDescendantsInstances = { ship }
RunService.RenderStepped:Connect(function(dt)
	cur = cur:Lerp(root.CFrame, math.clamp(dt * 4, 0, 1))
	local t = os.clock()
	local bob = CFrame.new(0, math.sin(t * 0.9) * 0.8, 0) * CFrame.Angles(math.sin(t * 0.7) * 0.02, 0, math.sin(t * 0.8) * 0.025)
	local base = cur * bob
	for _, e in ipairs(parts) do
		e.p.CFrame = base * e.off
	end
	-- carry the local player standing on the deck
	local ch = me.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if hrp and prevBase then
		local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -4.5, 0), rideRP)
		if hit and solid[hit.Instance] then
			hrp.CFrame = base * prevBase:Inverse() * hrp.CFrame
		end
	end
	prevBase = base
	local head = ch and ch:FindFirstChild("Head")
	NPCModel.pose(captain, base * CFrame.new(0, 3.1, -6), t, head and head.Position)
	prop.CFrame = base * CFrame.new(0, 1, 16.5) * CFrame.Angles(0, 0, t * (root:GetAttribute("Docked") ~= "" and 3 or 14))
	signT.Text = (root:GetAttribute("Docked") or "") ~= "" and "WANDERING MERCHANT - TRADE" or "WANDERING MERCHANT (TRAVELLING)"
end)

---------------------------------------------------------------------------
-- shop window
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Merchant"
gui.ResetOnSpawn = false
gui.DisplayOrder = 8
gui.Parent = me:WaitForChild("PlayerGui")
local function new(cls, props, parent)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end
local function stroke(o, t)
	new("UIStroke", { Thickness = t or 3, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local shop = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0.8, 0), BackgroundColor3 = rgb(250, 240, 220), Visible = false }, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(640, 460) }, shop)
round(shop, 18)
stroke(shop, 4)
new("TextLabel", { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 38), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "THE WANDERING MERCHANT", TextColor3 = rgb(150, 80, 40) }, shop)
local inkL = new("TextLabel", { Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 22), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = INK }, shop)
local x = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = rgb(255, 90, 90), Font = FONT, TextScaled = true, Text = "X", TextColor3 = Color3.new(1, 1, 1) }, shop)
round(x, 21)
stroke(x, 3)
local list = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 78), Size = UDim2.new(1, -28, 1, -90), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, shop)
new("UIListLayout", { Padding = UDim.new(0, 8) }, list)
x.Activated:Connect(function()
	shop.Visible = false
end)
local ICONCOL = { wind = rgb(120, 200, 255), hunt = rgb(255, 110, 90), lantern = rgb(150, 120, 255), map = rgb(230, 190, 110), feathers = rgb(255, 255, 255), crystal = rgb(120, 230, 200), basket = rgb(255, 90, 90) }
local function openShop(stock)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	inkL.Text = "YOUR INK: " .. tostring(me:GetAttribute("Ink") or (me:FindFirstChild("leaderstats") and "?" or "?"))
	for i, id in ipairs(stock) do
		local it
		for _, s in ipairs(G.ShopItems) do
			if s.id == id then
				it = s
			end
		end
		if it then
			local row = new("Frame", { Size = UDim2.new(1, -8, 0, isMobile and 62 or 70), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i }, list)
			round(row, 12)
			stroke(row, 2)
			local ic = new("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.new(0, isMobile and 44 or 52, 0, isMobile and 44 or 52), BackgroundColor3 = ICONCOL[id] or rgb(200, 200, 200) }, row)
			round(ic, 26)
			stroke(ic, 2)
			new("TextLabel", { Position = UDim2.fromOffset(isMobile and 64 or 74, 8), Size = UDim2.new(1, -220, 0, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = it.name, TextColor3 = INK }, row)
			new("TextLabel", { Position = UDim2.fromOffset(isMobile and 64 or 74, 36), Size = UDim2.new(1, -220, 0, 22), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = it.desc, TextColor3 = rgb(100, 95, 110) }, row)
			local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, isMobile and 42 or 48), BackgroundColor3 = rgb(90, 200, 110), Font = FONT, TextScaled = true, Text = it.price .. " INK", TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3 }, row)
			round(b, 12)
			stroke(b, 2)
			b.Activated:Connect(function()
				Combat:FireServer("buy", id)
			end)
		end
	end
	shop.Visible = true
end

---------------------------------------------------------------------------
-- treasure-map trail + buff timers
---------------------------------------------------------------------------
local trail
local function mapTrail(pos)
	if trail then
		trail:Destroy()
	end
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	trail = Instance.new("Folder")
	trail.Parent = workspace
	local endP = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) }, trail)
	local a0 = new("Attachment", {}, hrp)
	local a1 = new("Attachment", {}, endP)
	new("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 0.8, Width1 = 0.8, Color = ColorSequence.new(rgb(255, 215, 90)), LightEmission = 1, FaceCamera = true, Transparency = NumberSequence.new(0.2), TextureSpeed = 2, Segments = 30, CurveSize0 = 0, CurveSize1 = 0 }, trail)
	local pillar = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = rgb(255, 215, 90), Transparency = 0.5, Size = Vector3.new(1.5, 120, 1.5), CFrame = CFrame.new(pos + Vector3.new(0, 60, 0)) }, trail)
	local _ = pillar
	local f = trail
	task.delay(150, function()
		if trail == f then
			trail:Destroy()
			trail = nil
		end
		a0:Destroy()
	end)
end
local buffL = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, isMobile and 150 or 170), Size = UDim2.fromOffset(240, 60), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, Text = "", TextColor3 = rgb(255, 235, 170), TextStrokeTransparency = 0, TextStrokeColor3 = INK }, gui)
local BUFFS = { { "BuffWind", "TAILWIND" }, { "BuffDmg", "HUNTER'S BREW" }, { "BuffEss", "ESSENCE LANTERN" } }
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()
		local lines = {}
		for _, b in ipairs(BUFFS) do
			local left = (me:GetAttribute(b[1]) or 0) - now
			if left > 0 then
				table.insert(lines, ("%s  %d:%02d"):format(b[2], math.floor(left / 60), math.floor(left % 60)))
			end
		end
		buffL.Text = table.concat(lines, "\n")
		buffL.Size = UDim2.fromOffset(240, 20 * #lines)
	end
end)

Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "ShopOpen" then
		openShop(info.stock)
		pcall(Audio.play, "ui_click", { vol = 0.5 })
	elseif kind == "Bought" then
		pcall(Audio.play, "reveal_uncommon", { vol = 0.6 })
		if shop.Visible then
			inkL.Text = "BOUGHT!  YOUR INK: " .. tostring(me:GetAttribute("Ink") or "?")
		end
	elseif kind == "MapReveal" then
		shop.Visible = false
		mapTrail(info.pos)
	end
end)
