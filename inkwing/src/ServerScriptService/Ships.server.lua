--!nonstrict
-- INKWING :: SKY SKIFFS (v1.8c). Every "Skiff" model in the world becomes a real rideable ship:
-- welded into one physics assembly, hovering in place while empty, and handed to the pilot's client
-- (network ownership) while someone sits at the helm. SkiffDrive.client does the steering.
local Players = game:GetService("Players")
local world = workspace:WaitForChild("World")
task.wait(2)
local folder = Instance.new("Folder")
folder.Name = "Ships"
folder.Parent = workspace

local function setup(m)
	local hull = m:FindFirstChild("SkiffHull")
	local helm = m:FindFirstChild("SkiffHelm")
	if not hull or not helm then
		return
	end
	m.Parent = folder
	m.PrimaryPart = hull
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= hull then
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = hull, p
			w.Parent = p
		end
	end
	local seat = Instance.new("VehicleSeat")
	seat.Name = "SkiffSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.Transparency = 1
	seat.CFrame = helm.CFrame * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, 0)
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Massless = true
	seat.Parent = m
	local sw = Instance.new("WeldConstraint")
	sw.Part0, sw.Part1 = hull, seat
	sw.Parent = seat
	local att = Instance.new("Attachment")
	att.Name = "SkiffAtt"
	att.Parent = hull
	local ap = Instance.new("AlignPosition")
	ap.Name = "Hover"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.Responsiveness = 8
	ap.Position = hull.Position
	ap.Parent = hull
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Level"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e8
	ao.Responsiveness = 10
	ao.CFrame = hull.CFrame.Rotation
	ao.Parent = hull
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = 1e7
	lv.VectorVelocity = Vector3.zero
	lv.Enabled = false
	lv.Parent = hull
	hull.Anchored = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take the helm"
	prompt.ObjectText = "Sky Skiff"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	prompt.Triggered:Connect(function(p)
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		local pl = occ and Players:GetPlayerFromCharacter(occ.Parent)
		prompt.Enabled = occ == nil
		if pl then
			ap.Enabled = false
			lv.Enabled = true
			pcall(hull.SetNetworkOwner, hull, pl)
		else
			lv.VectorVelocity = Vector3.zero
			lv.Enabled = false
			ap.Position = hull.Position
			ap.Enabled = true
			local _, yaw = hull.CFrame:ToEulerAnglesYXZ()
			ao.CFrame = CFrame.Angles(0, yaw, 0)
			pcall(hull.SetNetworkOwner, hull, nil)
		end
	end)
	pcall(hull.SetNetworkOwner, hull, nil)
end

for _, d in ipairs(world:GetDescendants()) do
	if d:IsA("Model") and d.Name == "Skiff" then
		setup(d)
	end
end
