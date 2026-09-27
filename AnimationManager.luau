-- Procedural, asset-independent animation for the custom 15-joint rigs + Qi core.
-- Runs locally for every visible actor. The server replicates intent + timestamps,
-- never per-frame joint updates. C0 poses avoid uploaded animation permissions.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local AnimationManager = {}
local rigs = {}
local foliage = {}
local connection
local lowQuality = false
local pi = math.pi
local sin, cos = math.sin, math.cos
local angles = CFrame.Angles
local zero = CFrame.new()
local Pose = require(game:GetService("ReplicatedStorage").Shared.PoseLibrary)
local function toFrame(v)
	return v and CFrame.new(v[4], v[5], v[6]) * angles(v[1], v[2], v[3]) or zero
end
local put = Pose.put
local neutral = Pose.neutral
local locomotion = Pose.locomotion
local meditation = Pose.meditation
local attack = Pose.attack
local windup = Pose.windup
local slam = Pose.slam
local palm = Pose.palm
local lotus = Pose.lotus
local jump = Pose.jump
local talking = Pose.talking
local alchemy = Pose.alchemy
local guard = Pose.guard
local attune = Pose.attune
function AnimationManager.SetQuality(low)
	lowQuality = low
end
function AnimationManager.Attach(model)
	if rigs[model] then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end
	local joints, eyes = {}, {}
	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") and (obj.Name == "EyeWhite" or obj.Name == "Iris" or obj.Name == "ClosedEye") then table.insert(eyes, obj) end
		if obj:IsA("Motor6D") then
			joints[obj.Name] = {Motor = obj, Base = obj.C0, Pose = zero}
		end
	end
	local animate = model:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then animate.Disabled = true end
	local rig = {Joints = joints, Eyes = eyes, EyesClosed = nil, Humanoid = humanoid, Root = root, Phase = math.random() * 10,
		Gait = 0, Speed = 0, Accumulator = 0, WasAir = false, LandAt = 0, TargetPose = {}}
	rig.Added = model.DescendantAdded:Connect(function(obj)
		if obj:IsA("Motor6D") and not joints[obj.Name] then joints[obj.Name] = {Motor = obj, Base = obj.C0, Pose = zero} end
	end)
	rigs[model] = rig
end
function AnimationManager.Detach(model)
	local rig = rigs[model]
	if rig then
		if rig.Added then rig.Added:Disconnect() end
		for _, joint in rig.Joints do
			if joint.Motor.Parent then joint.Motor.C0 = joint.Base end
		end
		rigs[model] = nil
	end
end
function AnimationManager.RegisterFoliage(folder)
	for _, tree in folder:GetChildren() do
		local canopy = tree:FindFirstChild("WindCanopy")
		if canopy and canopy:IsA("Model") then
			local base = canopy:GetPivot()
			table.insert(foliage, {Model = canopy, Base = base, Phase = math.random() * 20,
				Weight = tree:FindFirstChild("WindWeight") and tree.WindWeight.Value or 1, NextAt = 0})
		end
	end
end
function AnimationManager.Start()
	if connection then return end
	local windClock = 0
	connection = RunService.PreSimulation:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local t = workspace:GetServerTimeNow()
		local cameraPos = camera.CFrame.Position
		for model, rig in rigs do
			if not model.Parent then AnimationManager.Detach(model); continue end
			rig.Accumulator += dt
			local distance = (rig.Root.Position - cameraPos).Magnitude
			if distance > 300 then rig.Accumulator = 0; continue end
			local interval = distance < 95 and 0 or distance < 180 and 1 / 30 or 1 / 12
			if rig.Accumulator < interval then continue end
			local stepDt = math.min(rig.Accumulator, 0.1)
			rig.Accumulator = 0
			local p = rig.TargetPose
			table.clear(p)
			local hum = rig.Humanoid
			local state = model:GetAttribute("Action") or "Idle"
			local elapsed = t - (model:GetAttribute("ActionAt") or 0)
			local untilTime = model:GetAttribute("ActionUntil") or 0
			if untilTime > 0 and t > untilTime then state = "Idle" end
			local closed = state == "Meditate"
			if rig.EyesClosed ~= closed then
				rig.EyesClosed = closed
				for _, eye in rig.Eyes do eye.Transparency = eye.Name == "ClosedEye" and (closed and 0 or 1) or (closed and 1 or 0) end
			end
			local velocity = rig.Root.AssemblyLinearVelocity
			local measured = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			rig.Speed += (measured - rig.Speed) * (1 - math.exp(-stepDt * 10))
			local speed = rig.Speed
			rig.Gait += math.min(speed, 26) * stepDt * 0.57 / math.max(1, rig.Root.Size.Y / 2)
			local airborne = hum.FloorMaterial == Enum.Material.Air
			if rig.WasAir and not airborne then rig.LandAt = t end
			rig.WasAir = airborne
			neutral(p, t + rig.Phase, 0.045, rig.Phase)
			if hum.Health <= 0 then
				put(p, "Root", 0.65, 0, 0.30, 0, -1.1, 0)
				put(p, "Neck", 0.5, 0, 0)
			elseif state == "Meditate" then
				meditation(p, t, rig.Root.Size.Y / 2)
			else
				if speed > 1 then locomotion(p, rig.Gait, speed, model:GetAttribute("Boss")) end
				local hs = hum:GetState()
				if hs == Enum.HumanoidStateType.Jumping or hs == Enum.HumanoidStateType.Freefall then
					jump(p, hs == Enum.HumanoidStateType.Freefall)
				end
				if state == "Strike" then attack(p, elapsed, model:GetAttribute("Combo") or 1)
				elseif state == "Windup" then windup(p, t, model:GetAttribute("AttackKind"))
				elseif state == "Slam" then slam(p, elapsed)
				elseif state == "Palm" then palm(p, elapsed)
				elseif state == "Lotus" or state == "Breakthrough" then lotus(p, elapsed)
				elseif state == "Talk" then talking(p, t)
				elseif state == "Alchemy" then alchemy(p, t)
				elseif state == "Guard" or state == "Parry" then guard(p, elapsed, state == "Parry")
				elseif state == "Attune" then attune(p, elapsed)
				elseif state == "Stagger" then put(p, "Waist", -0.35, 0, 0.15)
				elseif state == "Dash" then
					put(p, "Root", -0.45, 0, 0)
					put(p, "LeftShoulder", 0.7, 0, -0.15)
					put(p, "RightShoulder", 0.7, 0, 0.15)
				end
			end
			if state == "Idle" then
				local localVelocity = rig.Root.CFrame:VectorToObjectSpace(velocity)
				p.Root = p.Root or {0, 0, 0, 0, 0, 0}
				p.Root[3] += math.clamp(-localVelocity.X / 135, -0.13, 0.13)
				local land = math.sin(math.clamp((t - rig.LandAt) / 0.26, 0, 1) * pi)
				if land > 0 then
					p.Root[5] -= 0.25 * land
					put(p, "LeftKnee", land * 0.30, 0, 0)
					put(p, "RightKnee", land * 0.30, 0, 0)
				end
			end
			local blend = 1 - math.exp(-stepDt * (state == "Strike" and 26 or 13))
			for name, joint in rig.Joints do
				if joint.Motor.Parent then
					joint.Pose = joint.Pose:Lerp(toFrame(p[name]), blend)
					joint.Motor.C0 = joint.Base * joint.Pose
				end
			end
		end
		windClock += dt
		if windClock < (lowQuality and 1 / 12 or 1 / 24) then return end
		windClock = 0
		local storm = 1 + (workspace:GetAttribute("WeatherIntensity") or 0) * 0.75
		for _, item in foliage do
			if not item.Model.Parent then continue end
			local distance = (item.Base.Position - cameraPos).Magnitude
			if distance > (lowQuality and 220 or 300) or t < item.NextAt then continue end
			item.NextAt = t + (distance > 145 and 1 / 8 or (lowQuality and 1 / 12 or 1 / 24))
			local a = sin(t * 0.85 + item.Phase) * 0.022 * item.Weight * storm
			local b = cos(t * 0.64 + item.Phase) * 0.015 * item.Weight * storm
			item.Model:PivotTo(item.Base * angles(a, 0, b))
		end
	end)
end
function AnimationManager.Stop()
	if connection then connection:Disconnect(); connection = nil end
	for model in rigs do AnimationManager.Detach(model) end
	for _, item in foliage do
		if item.Model.Parent then item.Model:PivotTo(item.Base) end
	end
	table.clear(foliage)
end
return AnimationManager
