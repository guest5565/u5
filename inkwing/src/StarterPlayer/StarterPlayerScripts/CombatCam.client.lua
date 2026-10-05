--!nonstrict
-- INKWING :: COMBAT CAMERA (v0.7)
--   When you are locked onto a monster, the camera snaps over your shoulder and a crosshair appears.
--   PC: the mouse locks in the centre, aim with the mouse. Mobile: drag the right side of the screen to aim.
--   The monster closest to the crosshair becomes your target (soft aim), so aiming = target switching.
--   Also: hit feedback (camera kick, hit-stop) and the soft-gate EXPOSURE warning.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local me = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Combat = Remotes:WaitForChild("Combat")
local Fx = Remotes:WaitForChild("Fx")
local Lock = me:WaitForChild("Lock")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)

local gui = Instance.new("ScreenGui")
gui.Name = "CombatCamUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.Parent = me:WaitForChild("PlayerGui")

-- crosshair: an ink ring + 4 ticks + centre dot
local cross = Instance.new("Frame")
cross.AnchorPoint = Vector2.new(0.5, 0.5)
cross.Position = UDim2.fromScale(0.5, 0.5)
cross.Size = UDim2.fromOffset(24, 24)
cross.BackgroundTransparency = 1
cross.Visible = false
cross.Parent = gui
local ring = Instance.new("Frame")
ring.Size = UDim2.fromScale(1, 1)
ring.BackgroundTransparency = 1
ring.Parent = cross
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
local rs = Instance.new("UIStroke", ring)
rs.Thickness = 2.5
rs.Color = Color3.new(1, 1, 1)
local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.fromScale(0.5, 0.5)
dot.Size = UDim2.fromOffset(6, 6)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.Parent = cross
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", dot).Color = INK
local ticks = {}
for k = 0, 3 do
	local t = Instance.new("Frame")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	local a = k * math.pi / 2
	t.Position = UDim2.new(0.5, math.cos(a) * 31, 0.5, math.sin(a) * 31)
	t.Size = (k % 2 == 0) and UDim2.fromOffset(12, 3) or UDim2.fromOffset(3, 12)
	t.BackgroundColor3 = Color3.new(1, 1, 1)
	t.BorderSizePixel = 0
	t.Parent = cross
	local s = Instance.new("UIStroke", t)
	s.Color = INK
	ticks[k + 1] = t
end

-- unlock button (mobile) / key hint (PC)
local unlockB = Instance.new("TextButton")
unlockB.AnchorPoint = Vector2.new(0.5, 0)
unlockB.Position = UDim2.new(0.5, 0, 0, isMobile and 150 or 160)
unlockB.Size = UDim2.fromOffset(isMobile and 150 or 210, isMobile and 40 or 34)
unlockB.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
unlockB.TextColor3 = Color3.new(1, 1, 1)
unlockB.Font = FONT
unlockB.TextScaled = true
unlockB.Text = "AIM"
unlockB.Visible = false
unlockB.Parent = gui
Instance.new("UICorner", unlockB).CornerRadius = UDim.new(1, 0)
local us = Instance.new("UIStroke", unlockB)
us.Thickness = 3
us.Color = INK
us.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- EXPOSURE warning (soft gates): red vignette edges + message
local vign = {}
for k = 1, 4 do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(200, 20, 40)
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGradient", f)
	g.Transparency = NumberSequence.new(0, 1)
	g.Rotation = ({ 90, -90, 0, 180 })[k]
	if k == 1 then
		f.Size = UDim2.fromScale(1, 0.22)
	elseif k == 2 then
		f.Size, f.Position = UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78)
	elseif k == 3 then
		f.Size = UDim2.fromScale(0.18, 1)
	else
		f.Size, f.Position = UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0)
	end
	f.Parent = gui
	vign[k] = f
end
local expL = Instance.new("TextLabel")
expL.AnchorPoint = Vector2.new(0.5, 0)
expL.Position = UDim2.fromScale(0.5, 0.2)
expL.Size = UDim2.fromOffset(isMobile and 420 or 620, isMobile and 52 or 64)
expL.BackgroundTransparency = 1
expL.Font = FONT
expL.TextScaled = true
expL.TextColor3 = Color3.fromRGB(255, 110, 110)
expL.TextStrokeTransparency = 0
expL.TextStrokeColor3 = INK
expL.Text = ""
expL.Parent = gui

---------------------------------------------------------------------------
local combatMode = not isMobile -- v1.2: PC joins LOCKED (mouse in the middle); F toggles. v0.7b: stays on (even between kills) until you turn it off
local function unlock()
	combatMode = false
	Lock.Value = nil
	Combat:FireServer("lock", nil)
	me:SetAttribute("AutoLockOff", os.clock() + 2.5)
end
local function toggle()
	if combatMode then
		unlock()
	else
		combatMode = true
	end
end
unlockB.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then
		return
	end
	if i.KeyCode == Enum.KeyCode.F then
		toggle()
	end
end)
Lock.Changed:Connect(function(v)
	if v then
		combatMode = true -- locking onto anything enters combat mode
	end
end)

-- hit feedback: camera kick + tiny hit-stop (FOV punch) on your own hits
local kick, kickT = 0, 0
Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Hit" and info and info.by == me then
		kick = math.max(kick, info.crit and 1 or 0.45)
		kickT = os.clock()
		if info.crit then
			local cam = workspace.CurrentCamera
			local f0 = cam.FieldOfView
			cam.FieldOfView = f0 - 3
			TweenService:Create(cam, TweenInfo.new(0.18, Enum.EasingStyle.Back), { FieldOfView = f0 }):Play()
		end
	elseif kind == "Hurt" then
		kick = math.max(kick, 0.8)
		kickT = os.clock()
	end
end)

---------------------------------------------------------------------------
local active = false
local offset = Vector3.zero
local retargetT = 0
local function setActive(on)
	if on == active then
		return
	end
	active = on
	me:SetAttribute("CombatCam", on)
	cross.Visible = false -- v1.2: no big crosshair, the small cursor ring (Attack.client) is the only reticle
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = not on
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function screenDist(cam, pos)
	local sp, on = cam:WorldToViewportPoint(pos)
	if not on then
		return math.huge
	end
	local vs = cam.ViewportSize
	return (Vector2.new(sp.X, sp.Y) - vs / 2).Magnitude
end

local deadAt = nil
RunService:BindToRenderStep("InkwingCombatCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local char = me.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then
		return
	end
	local cam = workspace.CurrentCamera
	local now = os.clock()
	if _G.InkwingDialogue then -- v1.10 dialogue owns the camera + mouse
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	if hum.Health <= 0 then
		combatMode = false
		deadAt = now
	elseif deadAt and now - deadAt > 1 then
		deadAt = nil
		combatMode = not isMobile -- respawn: back to locked on PC
	end
	setActive(combatMode)
	unlockB.Visible = isMobile -- v1.10 PC: F key only
	unlockB.Text = combatMode and (isMobile and "UNLOCK" or "UNLOCK MOUSE (F)") or (isMobile and "AIM" or "LOCK MOUSE (F)")
	unlockB.BackgroundColor3 = combatMode and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(90, 170, 255)

	-- shoulder offset (smoothly in / out)
	local goal = active and Vector3.new(2.4, 1.1, 0) or Vector3.zero
	offset = offset:Lerp(goal, math.clamp(dt * 8, 0, 1))
	hum.CameraOffset = offset

	if active then
		if not isMobile then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		-- on foot: turn the body to the camera
		if not me:GetAttribute("Flying") then
			local lv = cam.CFrame.LookVector
			local flat = Vector3.new(lv.X, 0, lv.Z)
			if flat.Magnitude > 0.01 then
				local want = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
				hrp.CFrame = hrp.CFrame:Lerp(want, math.clamp(dt * 14, 0, 1))
			end
		end
		-- SOFT AIM: the monster nearest the crosshair becomes the target
		if now - retargetT > 0.15 then
			retargetT = now
			local folder = workspace:FindFirstChild("Enemies")
			local cur = Lock.Value
			local curD = cur and cur.Parent and screenDist(cam, cur.Position) or math.huge
			local best, bd = nil, math.huge
			local lim = cam.ViewportSize.X * 0.14
			if folder then
				for _, p in ipairs(folder:GetChildren()) do
					if p:IsA("BasePart") and p ~= cur and (not _G.InkwingCanAuto or _G.InkwingCanAuto(p)) and (p.Position - hrp.Position).Magnitude < 150 then
						local d = screenDist(cam, p.Position)
						if d < lim and d < bd then
							best, bd = p, d
						end
					end
				end
			end
			if not best and not (cur and cur.Parent) and folder then
				local nd = 150
				for _, p in ipairs(folder:GetChildren()) do
					if p:IsA("BasePart") and (not _G.InkwingCanAuto or _G.InkwingCanAuto(p)) then
						local d = (p.Position - hrp.Position).Magnitude
						if d < nd then
							best, nd, bd = p, d, 0
						end
					end
				end
			end
			if best and (bd < curD * 0.6 or not (cur and cur.Parent)) then
				Lock.Value = best
				Combat:FireServer("lock", best)
			end
		end
		-- crosshair turns red when the target is near the centre
		local cd = Lock.Value and screenDist(cam, Lock.Value.Position) or math.huge
		local onT = cd < cam.ViewportSize.X * 0.08
		local col = onT and Color3.fromRGB(255, 80, 90) or Color3.new(1, 1, 1)
		rs.Color = col
		dot.BackgroundColor3 = col
		for _, t in ipairs(ticks) do
			t.BackgroundColor3 = col
		end
		cross.Size = cross.Size:Lerp(UDim2.fromOffset(onT and 40 or 50, onT and 40 or 50), math.clamp(dt * 12, 0, 1))
		cross.Rotation = onT and (now * 120) % 360 or 0
	end

	-- camera kick (decays fast)
	if kick > 0.01 then
		local k = kick * math.exp(-(now - kickT) * 14)
		cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * 0.02 * k, (math.random() - 0.5) * 0.02 * k, 0)
		if now - kickT > 0.35 then
			kick = 0
		end
	end

	-- exposure warning
	local exp = me:GetAttribute("Exposure") or 0
	local pulse = exp > 0 and (0.55 - math.sin(now * 5) * 0.15 - math.min(exp, 3) * 0.08) or 1
	for _, f in ipairs(vign) do
		f.BackgroundTransparency = f.BackgroundTransparency + (pulse - f.BackgroundTransparency) * math.clamp(dt * 6, 0, 1)
	end
	if exp > 0 then
		expL.Text = (me:GetAttribute("ExposureWhy") or "") .. "  -  NEED " .. string.upper(me:GetAttribute("ExposureNeed") or "") .. " WINGS"
	else
		expL.Text = ""
	end
end)
