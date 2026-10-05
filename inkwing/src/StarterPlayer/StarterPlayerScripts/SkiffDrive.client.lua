--!nonstrict
-- INKWING :: SKY SKIFF PILOTING (v1.8c) + the SKY ARK's slow voyage around the far sky.
-- W/S (or the thumbstick) = throttle, A/D = turn, X / Z (or look up/down while moving) = climb / dive.
-- Jump to leave the helm (your wings catch you).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local me = Players.LocalPlayer

local MAX_SPEED, CLIMB, TURN = 85, 40, 1.1
local speed, yaw, bank = 0, nil, 0
local up, down = false, false
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.X then up = true end
	if i.KeyCode == Enum.KeyCode.Z then down = true end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.X then up = false end
	if i.KeyCode == Enum.KeyCode.Z then down = false end
end)

local hint
local function showHint(on)
	if on and not hint then
		local g = Instance.new("ScreenGui")
		g.Name = "SkiffHint"
		g.ResetOnSpawn = false
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 1)
		t.Position = UDim2.new(0.5, 0, 1, -130)
		t.Size = UDim2.fromOffset(460, 26)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.Text = UserInputService.TouchEnabled and "STEER WITH THE STICK - LOOK UP / DOWN TO CLIMB - JUMP TO LEAVE"
			or "W/S SPEED - A/D TURN - X/Z UP/DOWN - SPACE TO LEAVE"
		t.Parent = g
		g.Parent = me:WaitForChild("PlayerGui")
		hint = g
	elseif not on and hint then
		hint:Destroy()
		hint = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat.Name == "SkiffSeat") then
		yaw, speed = nil, 0
		showHint(false)
		return
	end
	showHint(true)
	local hull = seat.Parent:FindFirstChild("SkiffHull")
	local lv = hull and hull:FindFirstChild("Drive")
	local ao = hull and hull:FindFirstChild("Level")
	if not (lv and ao) then
		return
	end
	if not yaw then
		local _, y = hull.CFrame:ToEulerAnglesYXZ()
		yaw = y
	end
	local thr, steer = seat.ThrottleFloat, seat.SteerFloat
	speed += (thr * MAX_SPEED - speed) * math.clamp(dt * (thr ~= 0 and 0.9 or 0.6), 0, 1)
	yaw -= steer * TURN * dt * math.clamp(0.35 + math.abs(speed) / MAX_SPEED, 0, 1.2)
	local climb = (up and 1 or 0) - (down and 1 or 0)
	if climb == 0 and math.abs(speed) > 10 then -- look up/down while sailing to climb/dive (mobile friendly)
		local ly = workspace.CurrentCamera.CFrame.LookVector.Y
		if math.abs(ly) > 0.25 then
			climb = math.clamp((ly - math.sign(ly) * 0.25) * 2.5, -1, 1)
		end
	end
	bank += (-steer * 0.25 - bank) * math.clamp(dt * 3, 0, 1)
	local rot = CFrame.Angles(0, yaw, 0)
	lv.VectorVelocity = rot.LookVector * speed + Vector3.new(0, climb * CLIMB, 0)
	ao.CFrame = rot * CFrame.Angles(climb * 0.12 * math.sign(speed + 0.01), 0, bank)
end)

-- THE SKY ARK: circles the far sky (same position for everyone - driven by server time)
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	if not world then return end
	task.wait(3)
	local ark, path
	for _, d in ipairs(world:GetDescendants()) do
		if d.Name == "SkyArk" and d:IsA("Model") then
			ark = d
			path = d:FindFirstChild("ArkPath")
			break
		end
	end
	if not (ark and path) then return end
	local center = path.Position
	local speedA = path:GetAttribute("Speed") or 0.0016
	local rel = CFrame.new(center):Inverse() * ark:GetPivot()
	local acc = 0
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { ark }
	local prev
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local near = hrp and (hrp.Position - ark:GetPivot().Position).Magnitude < 900
		if not near and acc < 1 / 20 then return end -- far away: 20 Hz is plenty; close: every frame so the deck is smooth
		acc = 0
		local th = -workspace:GetServerTimeNow() * speedA
		local bob = math.sin(workspace:GetServerTimeNow() * 0.3) * 6
		local cf = CFrame.new(center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, -th, 0) * rel
		ark:PivotTo(cf)
		-- v1.10: the ark is walkable - it carries you while you stand on it
		if near and prev and Players.LocalPlayer:GetAttribute("Flying") ~= true then
			local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp)
			if hit then
				hrp.CFrame = cf * prev:Inverse() * hrp.CFrame
			end
		end
		prev = cf
	end)
end)
