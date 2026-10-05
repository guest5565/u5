--!nonstrict
-- INKWING :: ZONE STREAMING (local, from Doodle Pets' RealmStream). The Storm and the Ink Deepsea are
-- removed from your world until you fly toward them, so from the isles you only ever see sky.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local me = Players.LocalPlayer
local World = workspace:WaitForChild("World")
local zones = {
	{ folder = World:WaitForChild("Storm"), show = function(y)
		return y > G.STORM_BASE - 300 and y < G.COSMOS_BASE
	end },
	{ folder = World:WaitForChild("Ocean"), show = function(y)
		return y < G.SEA_SHOW
	end },
	{ folder = World:WaitForChild("Depths"), show = function(y)
		return y < G.DEPTH_SHOW and y > G.HELL_TOP + 200
	end },
	{ folder = World:WaitForChild("Hell"), show = function(y)
		return y < G.HELL_SHOW and y > G.ABYSS_TOP + 200
	end },
	{ folder = World:WaitForChild("Abyss"), show = function(y)
		return y < G.ABYSS_SHOW and y > G.UNKNOWN_TOP + 200
	end },
	{ folder = World:WaitForChild("Unknown"), show = function(y)
		return y < G.UNKNOWN_SHOW
	end },
	{ folder = World:WaitForChild("Cosmos"), show = function(y)
		return y > G.COSMOS_SHOW and y < G.HEAVEN_BASE - 300
	end },
	{ folder = World:WaitForChild("Heaven"), show = function(y)
		return y > G.HEAVEN_SHOW
	end },
}
while true do
	local cam = workspace.CurrentCamera
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local y = hrp and hrp.Position.Y or (cam and cam.CFrame.Position.Y) or 100
	for _, z in ipairs(zones) do
		local want = z.show(y)
		if want and z.folder.Parent ~= World then
			z.folder.Parent = World
		elseif not want and z.folder.Parent ~= nil then
			z.folder.Parent = nil
		end
	end
	task.wait(0.25)
end
