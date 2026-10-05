--!nonstrict
-- INKWING :: ARRIVAL (v0.9). Keeps the travel screen up while the new realm loads, then fades it out.
local TeleportService = game:GetService("TeleportService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local g = TeleportService:GetArrivingTeleportGui()
if not g then
	return
end
local me = Players.LocalPlayer
g.Parent = me:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
local bg = g:FindFirstChild("BG")
local ring = bg and bg:FindFirstChild("Ring")
local alive = true
task.spawn(function()
	while alive and ring do
		ring.Rotation += 4
		task.wait(1 / 30)
	end
end)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not me.Character then
	me.CharacterAdded:Wait()
end
task.wait(1.5)
for _, d in ipairs(g:GetDescendants()) do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(0.9)
alive = false
g:Destroy()
