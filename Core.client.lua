--!nonstrict
-- INKWING :: THE MANA CORE (v1.8d). Every player carries a small core in the chest. It starts BLACK and
-- barely noticeable, and purifies toward glowing WHITE as the core ranks up and fills its limit.
-- Also draws breakthroughs: the core flares, a column of light, and a progress bar for yourself.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local G = require(Shared:WaitForChild("Game"))
local InkFX = require(Shared:WaitForChild("InkFX"))
local me = Players.LocalPlayer
local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")
local rgb = Color3.fromRGB

local BLACK, WHITE = rgb(8, 8, 10), rgb(255, 255, 255)
local function purity(pl)
	local r = pl:GetAttribute("WingRank") or 1
	return G.CorePurity(r, pl:GetAttribute("ManaMax") or 1, pl:GetAttribute("CoreCap") or G.CORE_CAP[r])
end
local function coreColor(p)
	-- black -> smoky grey -> pale silver -> white (stays dark for a long time)
	return BLACK:Lerp(WHITE, p ^ 1.4)
end

local cores = {} -- player -> { part, light, char }
local function build(pl, char)
	local torso = char:WaitForChild("UpperTorso", 5) or char:FindFirstChild("Torso")
	if not torso then
		return
	end
	local c = Instance.new("Part")
	c.Name = "ManaCore"
	c.Shape = Enum.PartType.Ball
	c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow, c.Massless = false, false, false, false, true
	c.Size = Vector3.new(0.3, 0.3, 0.3)
	c.Material = Enum.Material.SmoothPlastic
	c.Color = BLACK
	local front = -(torso.Size.Z / 2) + 0.06
	c.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.12, front)
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = torso, c
	w.C0 = CFrame.new(0, torso.Size.Y * 0.12, front)
	w.Parent = c
	local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Shadows = 2, 0, false
	l.Parent = c
	c.Parent = char
	cores[pl] = { part = c, light = l, char = char, weld = w, front = front, torso = torso }
end
local function hook(pl)
	pl.CharacterAdded:Connect(function(ch)
		task.wait(0.5)
		build(pl, ch)
	end)
	if pl.Character then
		task.spawn(build, pl, pl.Character)
	end
end
for _, pl in ipairs(Players:GetPlayers()) do
	hook(pl)
end
Players.PlayerAdded:Connect(hook)
Players.PlayerRemoving:Connect(function(pl)
	cores[pl] = nil
end)

-- your breakthrough progress bar
local gui = Instance.new("ScreenGui")
gui.Name = "CoreUI"
gui.ResetOnSpawn = false
gui.Parent = me:WaitForChild("PlayerGui")
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 120)
bar.Size = UDim2.fromOffset(320, 26)
bar.BackgroundColor3 = rgb(20, 18, 30)
bar.Visible = false
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)
local bs = Instance.new("UIStroke", bar)
bs.Thickness, bs.Color = 2.5, rgb(255, 235, 170)
local fill = Instance.new("Frame")
fill.BackgroundColor3 = rgb(255, 235, 170)
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = bar
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 10)
local bt = Instance.new("TextLabel")
bt.Size = UDim2.fromScale(1, 1)
bt.BackgroundTransparency = 1
bt.Font = Enum.Font.FredokaOne
bt.TextScaled = true
bt.TextColor3 = Color3.new(1, 1, 1)
bt.TextStrokeTransparency = 0
bt.ZIndex = 3
bt.Parent = bar

-- breakthrough columns for everyone
local columns = {}
local function column(pl)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = rgb(255, 240, 200)
	p.Transparency = 1
	p.Parent = workspace
	return p
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for pl, c in pairs(cores) do
		if not c.part.Parent then
			cores[pl] = nil
		else
			local pu = purity(pl)
			local brk = pl:GetAttribute("Breakthrough")
			local med = pl:GetAttribute("Meditating") == true
			local col = coreColor(pu)
			local pulse = med and (0.5 + 0.5 * math.sin(t * 2.4)) or 0
			if brk then
				pulse = 0.6 + 0.4 * math.sin(t * (6 + brk * 10))
				col = col:Lerp(WHITE, 0.4 + brk * 0.4)
			end
			c.part.Color = col
			c.part.Material = (pu > 0.3 or brk) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			local sz = 0.26 + pu * 0.22 + (brk and 0.15 * pulse or 0)
			c.part.Size = Vector3.new(sz, sz, sz)
			c.weld.C0 = CFrame.new(0, c.torso.Size.Y * 0.12, c.front - sz * 0.15)
			c.light.Color = col
			c.light.Range = 1.5 + pu * 7 + (brk and 10 or 0)
			c.light.Brightness = (pu ^ 2) * 1.6 + pulse * (0.15 + pu) + (brk and 2 or 0)
			-- breakthrough column
			local hrp = c.char:FindFirstChild("HumanoidRootPart")
			if brk and hrp then
				local col_ = columns[pl] or column(pl)
				columns[pl] = col_
				local h = 30 + brk * 120
				col_.Size = Vector3.new(h, 3 + brk * 4, 3 + brk * 4)
				col_.CFrame = CFrame.new(hrp.Position + Vector3.new(0, h / 2 - 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				col_.Transparency = 0.75 - 0.15 * math.sin(t * 5)
			elseif columns[pl] then
				columns[pl]:Destroy()
				columns[pl] = nil
			end
		end
	end
	local b = me:GetAttribute("Breakthrough")
	bar.Visible = b ~= nil
	if b then
		fill.Size = UDim2.fromScale(b, 1)
		bt.Text = ("BREAKTHROUGH  %d%%  - DON'T MOVE"):format(math.floor(b * 100))
	end
end)

if Fx then
	Fx.OnClientEvent:Connect(function(kind, info)
		if (kind == "BreakEnd" or kind == "BreakStart") and typeof(info) == "table" and info.player then
			local c = cores[info.player]
			local pos = c and c.part.Position
			if not pos then
				return
			end
			if kind == "BreakStart" then
				pcall(InkFX.ring, pos, rgb(255, 235, 170), 1, 14, 0.8, 0.8, true)
			elseif info.ok then
				local rc = G.RANK_COLORS[info.player:GetAttribute("WingRank") or 1] or WHITE
				pcall(InkFX.explosion, pos, rc, 18, false)
				pcall(InkFX.ring, pos, WHITE, 2, 60, 1.2, 2, true)
				pcall(InkFX.ring, pos, rc, 2, 40, 0.9, 1.4, true)
				pcall(InkFX.flash, pos, WHITE)
				if info.player == me and _G.InkwingShake then
					_G.InkwingShake(0.8, 1)
				end
			else
				pcall(InkFX.puffs, pos, rgb(60, 60, 70), 10)
			end
		end
	end)
end
