-- Attack.client: shooting is MANUAL. Hold left mouse (PC) or the ATTACK button (mobile) to fire at your lock.
-- Also replaces the system cursor with a small ink ring (PC).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer
local Combat = RS:WaitForChild("Remotes"):WaitForChild("Combat")
local INK = Color3.fromRGB(20, 18, 28)
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local gui = Instance.new("ScreenGui")
gui.Name = "Attack"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = me:WaitForChild("PlayerGui")

-- QUALITY: PC = everything (far render distance, monster auras on all beings, full particles), MOBILE = lighter
me:SetAttribute("HighQ", not isMobile)
local q = Instance.new("TextButton")
q.AnchorPoint = Vector2.new(1, 0)
q.Position = UDim2.new(1, -12, 0, 60)
q.Size = UDim2.fromOffset(isMobile and 96 or 120, 26)
q.BackgroundColor3 = Color3.fromRGB(250, 246, 235)
q.Font = Enum.Font.FredokaOne
q.TextScaled = true
q.TextColor3 = INK
q.Parent = gui
q.Visible = false -- v1.10: quality lives in the menu orb
_G.InkwingToggleQuality = function()
	me:SetAttribute("HighQ", not me:GetAttribute("HighQ"))
end
Instance.new("UICorner", q).CornerRadius = UDim.new(0, 8)
local qs = Instance.new("UIStroke", q)
qs.Thickness = 2
qs.Color = INK
qs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local function qText()
	q.Text = me:GetAttribute("HighQ") and "QUALITY: PC" or "QUALITY: MOBILE"
end
qText()
q.MouseButton1Click:Connect(function()
	me:SetAttribute("HighQ", not me:GetAttribute("HighQ"))
	qText()
end)

local holdMouse, holdBtn = false, false
UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.UserInputType == Enum.UserInputType.MouseButton1 then
		holdMouse = true
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then
		holdMouse = false
	end
end)

if isMobile then
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -24, 1, -190)
	b.Size = UDim2.fromOffset(92, 92)
	b.BackgroundColor3 = Color3.fromRGB(200, 40, 50)
	b.Text = "ATTACK"
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke", b)
	st.Thickness = 3
	st.Color = INK
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding", b)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	b.MouseButton1Down:Connect(function()
		holdBtn = true
	end)
	b.MouseButton1Up:Connect(function()
		holdBtn = false
	end)
	b.MouseLeave:Connect(function()
		holdBtn = false
	end)
end

-- small ring cursor (PC)
local cur
if not isMobile then
	cur = Instance.new("Frame")
	cur.AnchorPoint = Vector2.new(0.5, 0.5)
	cur.Size = UDim2.fromOffset(14, 14)
	cur.BackgroundTransparency = 1
	cur.ZIndex = 100
	cur.Parent = gui
	Instance.new("UICorner", cur).CornerRadius = UDim.new(1, 0)
	local s = Instance.new("UIStroke", cur)
	s.Thickness = 2
	s.Color = Color3.new(1, 1, 1)
	local s2 = Instance.new("Frame")
	s2.AnchorPoint = Vector2.new(0.5, 0.5)
	s2.Position = UDim2.fromScale(0.5, 0.5)
	s2.Size = UDim2.fromOffset(3, 3)
	s2.BackgroundColor3 = Color3.new(1, 1, 1)
	s2.BorderSizePixel = 0
	s2.Parent = cur
end

local G = require(RS:WaitForChild("Shared"):WaitForChild("Game"))
local InkFX = require(RS:WaitForChild("Shared"):WaitForChild("InkFX"))
local aimPart, missT = nil, 0
-- v1.8: target for abilities without lock-on: what you aim at, else the monster closest to your aim within range
_G.InkwingPickTarget = function(range)
	local cam = workspace.CurrentCamera
	local m = UIS.MouseBehavior == Enum.MouseBehavior.LockCenter and (cam.ViewportSize / 2) or UIS:GetMouseLocation()
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		m = cam.ViewportSize / 2
	end
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local camD = (hrp.Position - ray.Origin).Magnitude
	local part = _G.InkwingAimPick and _G.InkwingAimPick(ray, range + camD) or nil
	if part then
		return part
	end
	local best, bs
	for _, e in ipairs(workspace:WaitForChild("Enemies"):GetChildren()) do
		if e:IsA("BasePart") and (e:GetAttribute("HP") or 1) > 0 then
			local to = e.Position - hrp.Position
			local d = to.Magnitude
			if d < range + 6 then
				local dot = to.Unit:Dot(ray.Direction.Unit)
				if dot > 0.35 then
					local score = (1 - dot) * 3 + d / range
					if not bs or score < bs then
						best, bs = e, score
					end
				end
			end
		end
	end
	return best
end
-- PC FREE AIM: every pulse, pick the monster under the cursor ring; lock the server onto it silently and fire.
-- Nothing under the ring = the shot flies off where you aimed (a miss).
local function pcPulse()
	local cam = workspace.CurrentCamera
	local m = UIS.MouseBehavior == Enum.MouseBehavior.LockCenter and (cam.ViewportSize / 2) or UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local w = G.Wings[me:GetAttribute("Wing") or "Paper"] or G.Wings.Paper
	local range = w.range or 55
	local hrp0 = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local camD = hrp0 and (hrp0.Position - ray.Origin).Magnitude or 15
	local part = _G.InkwingAimPick and _G.InkwingAimPick(ray, range + camD) or nil
	if part ~= aimPart then
		aimPart = part
		Combat:FireServer("lock", part)
	end
	if part then
		Combat:FireServer("fire")
	else
		local now = os.clock()
		local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		if hrp and now > missT then
			missT = now + (w.rate or 0.7)
			local to = ray.Origin + ray.Direction.Unit * (range + (hrp.Position - ray.Origin).Magnitude)
			pcall(InkFX.projectile, hrp.Position + Vector3.new(0, 1, 0), to, Color3.fromRGB(40, 36, 70), 90, 0.8)
		end
	end
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if cur then
		UIS.MouseIconEnabled = false
		-- the same small ring always: follows the mouse when unlocked, sits in the middle when locked
		local m = UIS.MouseBehavior == Enum.MouseBehavior.LockCenter and (workspace.CurrentCamera.ViewportSize / 2) or UIS:GetMouseLocation()
		cur.Position = UDim2.fromOffset(m.X, m.Y)
		cur.Visible = true
	end
	acc += dt
	if (holdMouse or holdBtn) and acc >= 0.15 then
		acc = 0
		if isMobile then
			Combat:FireServer("fire") -- mobile: fires at the tapped lock
		else
			pcPulse()
		end
	elseif not holdMouse and aimPart and not isMobile then
		aimPart = nil
		Combat:FireServer("lock", nil)
	end
end)
