--!nonstrict
-- INKWING v1.7 :: NPCs (local) - builds + animates the detailed NPC figures (Master Orren)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NPCModel"))
local me = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "NPCFigures"
folder.Parent = workspace

local npcs = {}
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	local gate = world and world:WaitForChild("Gate", 30)
	local m = gate and gate:WaitForChild("Mentor", 30)
	local anchor = m and m:WaitForChild("MentorAnchor", 30)
	if not anchor then
		return
	end
	local feetPos = anchor.Position - Vector3.new(0, 2.2, 0) -- stands on the dais
	local feet = CFrame.lookAt(feetPos, feetPos + Vector3.new(0, 0, 1)) -- faces the spawn
	local n = NPCModel.build("mentor", folder)
	-- solid body so players don't walk through him
	local col = Instance.new("Part")
	col.Name = "OrrenCollider"
	col.Size = Vector3.new(3.6, 8, 3.6)
	col.CFrame = feet * CFrame.new(0, 4, 0)
	col.Anchored, col.CanCollide, col.Transparency, col.CanQuery = true, true, 1, false
	col.Parent = folder
	table.insert(npcs, { n = n, feet = feet })
end)

-- QUILL on Quill's Rest: feet raycast onto the island so he always stands on the ground
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	local deco = world and world:FindFirstChild("Deco", true)
	local q = deco and deco:FindFirstChild("QuillNPC")
	local anchor = q and q:FindFirstChild("QuillAnchor")
	if not anchor then
		return
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { folder, q }
	local hit = workspace:Raycast(anchor.Position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rp)
	local fp = hit and hit.Position or (anchor.Position - Vector3.new(0, 2.5, 0))
	local feet = CFrame.lookAt(fp, fp + Vector3.new(0.4, 0, 1))
	local n = NPCModel.build("quill", folder)
	local col = Instance.new("Part")
	col.Name = "QuillCollider"
	col.Size = Vector3.new(3.6, 8, 3.6)
	col.CFrame = feet * CFrame.new(0, 4, 0)
	col.Anchored, col.CanCollide, col.Transparency, col.CanQuery = true, true, 1, false
	col.Parent = folder
	table.insert(npcs, { n = n, feet = feet })
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local cam = workspace.CurrentCamera.CFrame.Position
	local head = me.Character and me.Character:FindFirstChild("Head")
	for _, e in ipairs(npcs) do
		if (e.feet.Position - cam).Magnitude < 350 then
			NPCModel.pose(e.n, e.feet, t, head and head.Position)
		end
	end
end)
