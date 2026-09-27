-- v0.3 sanctuary systems. Operates baked training posts and discipline altars.
-- No currency rewards from practice, no client-supplied damage or destinations.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Journey = require(Shared.JourneyRules)
local Rules = require(Shared.CombatRules)
local Service = {}
local sessions, recalls, promptLimits = {}, {}, {}
local effects, notices, callbacks
local warningSerial = 0
local function now() return workspace:GetServerTimeNow() end
local function character(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then return char, hum, root end
end
local function toast(player, title, text)
	notices:FireClient(player, "Toast", {Title = title, Text = text})
end
local function cancelWarning(player, session)
	if session.Cue then effects:FireClient(player, "CancelTelegraph", {Id = session.Cue.Id, Position = session.Cue.Position}); session.Cue = nil end
end
local function finishPractice(player, summary)
	local session = sessions[player]
	if not session then return end
	cancelWarning(player, session); sessions[player] = nil; player:SetAttribute("TrainingUntil", 0)
	if summary and player.Parent then
		toast(player, "PRACTICE COMPLETE", string.format("%d hits · %.1f DPS · %d practice parries. No Qi or spirit rewards.", session.Hits, Journey.TrainingDPS(session.Damage, now() - session.Start), session.Parries))
	end
end
function Service.HitPractice(player, key, origin, direction, range, amount)
	local session = sessions[player]
	if not session or now() > session.Until or player.Character ~= session.Character then return end
	local anchor = session.Target.PrimaryPart
	if not anchor then return end
	local delta = anchor.Position - origin
	local dot = delta.Magnitude > 0.01 and delta.Unit:Dot(direction) or 1
	if not Rules.InArc(delta.Magnitude, delta.Y, dot, range, key == "Palm" and 0.82 or 0.05, key == "Lotus") then return end
	local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = {session.Character, session.Target}
	if workspace:Raycast(origin, delta, ray) then return end
	session.Damage += amount; session.Hits += 1
	player:SetAttribute("TrainingHits", session.Hits); player:SetAttribute("TrainingDamage", session.Damage)
	effects:FireClient(player, "Hit", {Position = anchor.Position, Damage = amount})
end
function Service.CancelRecall(player, reason)
	if not recalls[player] then return end
	effects:FireClient(player, "CancelTelegraph", {Id = "Recall" .. player.UserId, Position = recalls[player].Position})
	recalls[player] = nil; player:SetAttribute("RecallUntil", 0)
	if reason and player.Parent then toast(player, "RECALL INTERRUPTED", reason) end
end
function Service.Recall(player)
	if recalls[player] then Service.CancelRecall(player, "Seal released."); return end
	local char, hum, root = character(player)
	if not char or not player:GetAttribute("ProfileLoaded") then return end
	local t = now()
	local allowed, reason = Journey.CanRecall(t, player:GetAttribute("CombatAt") or -100,
		player:GetAttribute("CDRecall") or 0, hum.FloorMaterial ~= Enum.Material.Air)
	if not allowed then toast(player, "RECALL UNAVAILABLE", reason); return end
	callbacks.CancelMeditation(player); callbacks.CancelSwing(player)
	finishPractice(player, false)
	recalls[player] = {Character = char, Position = root.Position, Started = t, Until = t + 4}
	player:SetAttribute("RecallUntil", t + 4)
	effects:FireClient(player, "Recall", {Position = root.Position, Duration = 4, Id = "Recall" .. player.UserId})
	toast(player, "THE HOMEWARD THREAD", "Stand still for four seconds. Movement, attacks or damage cancel recall.")
end
function Service.Resonance(player, root, players)
	local companions = 0
	for _, other in players do
		if other ~= player and other:GetAttribute("Meditating") and other:GetAttribute("ProfileLoaded") then
			local _, _, otherRoot = character(other)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= 18 then companions += 1 end
		end
	end
	return Journey.Resonance(companions)
end
function Service.Start(fx, notice, hooks)
	effects, notices, callbacks = fx, notice, hooks
	for _, target in workspace.World.Training:GetChildren() do
		local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
		prompt.Triggered:Connect(function(player)
			local char, _, root = character(player)
			if not char or not player:GetAttribute("ProfileLoaded") or (root.Position - target.PrimaryPart.Position).Magnitude > 15 then return end
			if (promptLimits[player] or 0) > now() then return end
			promptLimits[player] = now() + 1
			finishPractice(player, false); Service.CancelRecall(player)
			callbacks.CancelMeditation(player)
			sessions[player] = {Character = char, Target = target, Start = now(), Until = now() + 30, NextCue = now() + 3, Damage = 0, Hits = 0, Parries = 0}
			for _, field in {"TrainingHits", "TrainingDamage", "TrainingParries"} do player:SetAttribute(field, 0) end
			player:SetAttribute("TrainingDPS", 0); player:SetAttribute("TrainingUntil", now() + 30); player:SetAttribute("TrainingHint", "Face the post. Strike; time G at the end of a warning.")
			toast(player, "THE PATIENT WOOD", "A thirty-second lesson. The post never damages you and grants no farmable rewards.")
		end)
	end
	for _, altar in workspace.World.Interactables:GetChildren() do
		local id = altar:FindFirstChild("DisciplineId")
		if not id then continue end
		altar:FindFirstChildWhichIsA("ProximityPrompt", true).Triggered:Connect(function(player)
			local _, _, root = character(player)
			if not root or not player:GetAttribute("ProfileLoaded") or (root.Position - altar.Anchor.Position).Magnitude > 14 then return end
			if (promptLimits[player] or 0) > now() then return end
			promptLimits[player] = now() + 2
			if now() - (player:GetAttribute("CombatAt") or -100) < 8 then toast(player, "STILL YOUR HEART", "Leave combat before changing discipline."); return end
			local value = tonumber(id.Value)
			if not value or value < 1 or value > 3 then return end
			Service.CancelRecall(player); callbacks.CancelSwing(player)
			player:SetAttribute("Discipline", value)
			effects:FireAllClients("Attune", {Position = root.Position})
			toast(player, "PATH ATTUNED · " .. Journey.Discipline(value).Name:upper(), "This replaces your previous discipline. Change freely at these altars outside combat.")
		end)
	end
	Players.PlayerRemoving:Connect(function(player) sessions[player] = nil; recalls[player] = nil; promptLimits[player] = nil end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt; if accumulator < 0.1 then return end; accumulator = 0
		local t = now()
		for player, recall in recalls do
			local char, hum, root = character(player)
			if not root or char ~= recall.Character or not Journey.ChannelValid(root and (root.Position - recall.Position).Magnitude or math.huge, player:GetAttribute("CombatAt") or -100, recall.Started, hum ~= nil) or hum.FloorMaterial == Enum.Material.Air then
				Service.CancelRecall(player, "Your breath was disturbed.")
			elseif t >= recall.Until then
				Service.CancelRecall(player); callbacks.CancelSwing(player)
				char:PivotTo(CFrame.new(0, 137, 48)); root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
				char:SetAttribute("InvulnerableUntil", t + 3); player:SetAttribute("CDRecall", t + 25)
				effects:FireAllClients("Teleport", {Position = root.Position}); toast(player, "DAWNREACH REMEMBERS", "Welcome home. The seal recovers in 25 seconds.")
			end
		end
		for player, session in sessions do
			local char, _, root = character(player)
			if t >= session.Until or not root or char ~= session.Character or (root.Position - session.Target.PrimaryPart.Position).Magnitude > 28 then finishPractice(player, true); continue end
			player:SetAttribute("TrainingDPS", Journey.TrainingDPS(session.Damage, t - session.Start))
			if session.Cue and t >= session.Cue.At then
				local delta = session.Target.PrimaryPart.Position - root.Position
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local dot = flat.Magnitude > 0.01 and root.CFrame.LookVector:Dot(flat.Unit) or 1
				local result = Rules.Guard(t, char:GetAttribute("GuardAt") or 0, char:GetAttribute("GuardUntil") or 0, player:GetAttribute("Focus") or 0, 0, dot)
				if result == "Parry" then
					session.Parries += 1; player:SetAttribute("TrainingParries", session.Parries)
					char:SetAttribute("Action", "Parry"); char:SetAttribute("ActionAt", t); char:SetAttribute("ActionUntil", t + 0.45)
					effects:FireClient(player, "Parry", {Position = root.Position, CFrame = root.CFrame})
				end
				player:SetAttribute("TrainingHint", result == "Parry" and "Perfect. Wait, breathe, then guard just before impact." or "Face the post. Press G just before the countdown ends.")
				cancelWarning(player, session)
			elseif not session.Cue and t >= session.NextCue then
				warningSerial -= 1
				local point = root.Position - Vector3.new(0, 2.8, 0)
				session.Cue = {Id = warningSerial, Position = point, At = t + 1.1}; session.NextCue = t + 4.2
				effects:FireClient(player, "Telegraph", {Id = warningSerial, Position = point, Radius = 4, Duration = 1.1, Label = "PRACTICE · GUARD", Color = Color3.fromRGB(239, 211, 143)})
			end
		end
	end)
end
return Service
