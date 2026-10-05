--!nonstrict
-- INKWING :: GUARDIAN (v0.8). Blessed players (Halo Warden slayers) get a small Ophan that orbits them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyModel"))

local folder = Instance.new("Folder")
folder.Name = "Guardians"
folder.Parent = workspace
local models = {} -- player -> e

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local on = p:GetAttribute("Blessed") and hrp
		local e = models[p]
		if on and not e then
			e = EnemyModel.build("GuardianOphan", folder)
			models[p] = e
		elseif not on and e then
			e.model:Destroy()
			models[p] = nil
			e = nil
		end
		if e then
			local a = t * 1.3 + p.UserId % 7
			local pos = hrp.Position + Vector3.new(math.cos(a) * 4.5, 4 + math.sin(t * 2) * 0.6, math.sin(a) * 4.5)
			EnemyModel.pose(e, CFrame.lookAt(pos, hrp.Position + hrp.CFrame.LookVector * 30), t)
		end
	end
	for p, e in pairs(models) do
		if not p.Parent then
			e.model:Destroy()
			models[p] = nil
		end
	end
end)
