-- Entry point. All scenery, lighting, rigs, portals, gathering nodes and GUI are baked.
-- Runtime code only operates those instances and creates temporary gameplay effects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.CombatRules)
local EnemyService = require(script.Parent.EnemyService)
local Pilgrim = require(script.Parent.PilgrimService)
local Journey = require(ReplicatedStorage.Shared.JourneyRules)
local Profiles = require(script.Parent.ProfileService)
local NPCService = require(script.Parent.NPCService)
local remotes = ReplicatedStorage.Remotes
local actionRemote = remotes.Action
local fx = remotes.Effect
local notice = remotes.Notice
local state = {}
local teleportLocks = {}
local requestRates = {}
local function now() return workspace:GetServerTimeNow() end
local function message(player, title, text)
	notice:FireClient(player, "Toast", {Title = title, Text = text or ""})
end
local function characterOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not hum or hum.Health <= 0 then return nil end
	return char, hum, root
end
local function action(char, name, duration)
	char:SetAttribute("Action", name)
	char:SetAttribute("ActionAt", now())
	char:SetAttribute("ActionUntil", duration and now() + duration or 0)
end
local function cancelMeditation(player)
	local char, hum = characterOf(player)
	if char and char:GetAttribute("Action") == "Meditate" then
		action(char, "Idle")
		hum.WalkSpeed = 18
		hum.JumpPower = 48
		hum.AutoRotate = true
		player:SetAttribute("Meditating", false)
	end
end
local function addQi(player, amount)
	local realm = Config.Realms[player:GetAttribute("Realm") or 1]
	player:SetAttribute("Qi", math.min(realm.Need * 2, (player:GetAttribute("Qi") or 0) + amount))
end
local function reward(player, qi, spirit, boss, kind)
	addQi(player, qi)
	player:SetAttribute("Spirit", (player:GetAttribute("Spirit") or 0) + spirit)
	player:SetAttribute("Kills", (player:GetAttribute("Kills") or 0) + 1)
	player:SetAttribute("QuestKills", (player:GetAttribute("QuestKills") or 0) + 1)
	if kind == "SilkSpider" or kind == "SilkMatriarch" then player:SetAttribute("SilkKills", (player:GetAttribute("SilkKills") or 0) + 1) end
	if kind == "SilkMatriarch" then player:SetAttribute("MatriarchKills", (player:GetAttribute("MatriarchKills") or 0) + 1) end
	if kind == "LotusSovereign" then
		player:SetAttribute("BossKills", (player:GetAttribute("BossKills") or 0) + 1)
		player:SetAttribute("QuestBoss", (player:GetAttribute("QuestBoss") or 0) + 1)
	end
	message(player, kind == "SilkMatriarch" and "THE SILK CROWN FALLS" or boss and "THE HOLLOW CROWN FALLS" or "SPIRIT RECLAIMED", "+" .. qi .. " Qi   ·   +" .. spirit .. " spirit")
end
local function updateRealm(player, heal)
	local _, hum = characterOf(player)
	local data = Config.Realms[player:GetAttribute("Realm") or 1]
	if hum then
		hum.MaxHealth = data.Health
		if heal then hum.Health = data.Health end
	end
	local char = player.Character
	if char then
		local core = char:FindFirstChild("QiCore")
		if core then core.Color = data.Color end
	end
end
local function directionOrRoot(input, root)
	if typeof(input) ~= "Vector3" then return root.CFrame.LookVector end
	if input.X ~= input.X or input.Y ~= input.Y or input.Z ~= input.Z then return root.CFrame.LookVector end
	if math.abs(input.X) > 10000 or math.abs(input.Y) > 10000 or math.abs(input.Z) > 10000 then return root.CFrame.LookVector end
	local direction = Vector3.new(input.X, 0, input.Z)
	if direction.Magnitude < 0.01 then return root.CFrame.LookVector end
	return direction.Unit
end
local function clearSight(char, target, from, to)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, target, workspace:FindFirstChild("LocalEffects")}
	return workspace:Raycast(from, to - from, params) == nil
end
local function guard(player, inputDirection)
	local char, hum, root = characterOf(player)
	local current = state[player]
	if not char or not current or current.BusyUntil > now() then return end
	if (player:GetAttribute("CDGuard") or 0) > now() or (player:GetAttribute("Focus") or 0) < Config.Guard.Cost then return end
	cancelMeditation(player)
	local direction = directionOrRoot(inputDirection, root)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	player:SetAttribute("Focus", player:GetAttribute("Focus") - Config.Guard.Cost)
	player:SetAttribute("CDGuard", now() + Config.Guard.Cooldown)
	char:SetAttribute("GuardAt", now()); char:SetAttribute("GuardUntil", now() + Config.Guard.Duration)
	current.BusyUntil = now() + 0.18
	action(char, "Guard", Config.Guard.Duration)
	fx:FireAllClients("Guard", {Position = root.Position, CFrame = root.CFrame})
end
local function useAbility(player, key, inputDirection)
	local char, hum, root = characterOf(player)
	if not char then return end
	local definition = Config.Abilities[key]
	if not definition then return end
	local realmIndex = player:GetAttribute("Realm") or 1
	if realmIndex < definition.Unlock then
		message(player, "TECHNIQUE SEALED", "Reach Jade Foundation to awaken Lotus Bloom.")
		return
	end
	local cooldownKey = "CD" .. key
	if (player:GetAttribute(cooldownKey) or 0) > now() then return end
	if (player:GetAttribute("Focus") or 0) < definition.Cost then
		message(player, "FOCUS EXHAUSTED", "Pause to recover your focus.")
		return
	end
	local current = state[player]
	if not current or current.BusyUntil > now() then return end
	cancelMeditation(player)
	char:SetAttribute("GuardUntil", 0)
	player:SetAttribute("Focus", math.max(0, (player:GetAttribute("Focus") or 0) - definition.Cost))
	player:SetAttribute(cooldownKey, now() + definition.Cooldown)
	current.BusyUntil = now() + (key == "Lotus" and 0.7 or 0.18)
	local direction = directionOrRoot(inputDirection, root)
	local realm = Config.Realms[realmIndex]
	local discipline = Journey.Discipline(player:GetAttribute("Discipline"))
	if key ~= "Dash" then root.CFrame = CFrame.lookAt(root.Position, root.Position + direction) end
	if key == "Dash" then
		local move = hum.MoveDirection
		if move.Magnitude > 0.1 then direction = move.Unit end
		char:SetAttribute("InvulnerableUntil", now() + 0.32)
		action(char, "Dash", 0.3)
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		local clearance = RaycastParams.new()
		clearance.FilterType = Enum.RaycastFilterType.Exclude
		clearance.FilterDescendantsInstances = {char}
		clearance.RespectCanCollide = true
		local wall = workspace:Blockcast(root.CFrame, Vector3.new(2, 4, 2), direction * 14, clearance)
		local safeDistance = wall and math.max(0, wall.Distance - 1.25) or 13.68
		velocity.VectorVelocity = direction * math.min(76, safeDistance / 0.18) + Vector3.new(0, math.max(root.AssemblyLinearVelocity.Y, 0), 0)
		velocity.MaxForce = 65000
		velocity.Parent = root
		Debris:AddItem(velocity, 0.18); Debris:AddItem(attachment, 0.2)
		fx:FireAllClients("Dash", {Position = root.Position, Direction = direction, Color = realm.Color})
		return
	end
	if key == "Strike" then
		current.Combo = Rules.NextCombo(current.Combo, current.LastStrikeAt or 0, now())
		current.LastStrikeAt = now()
	end
	char:SetAttribute("Combo", current.Combo)
	action(char, key, key == "Lotus" and 1.0 or 0.45)
	current.Swing = (current.Swing or 0) + 1
	local swing = current.Swing
	local windup = key == "Strike" and 0.13 or key == "Palm" and 0.18 or 0.35
	task.delay(windup, function()
		if not char.Parent or player.Character ~= char or hum.Health <= 0 or current.Swing ~= swing then return end
		local origin = root.Position
		if key == "Strike" then
			fx:FireAllClients("Strike", {Position = origin, CFrame = root.CFrame, Combo = current.Combo, Color = realm.Color})
		elseif key == "Palm" then
			local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = {char}
			local wall = workspace:Raycast(origin, direction * definition.Range, ray)
			fx:FireAllClients("Palm", {Position = origin, Direction = direction, Range = wall and wall.Distance or definition.Range, Color = realm.Color})
		else
			fx:FireAllClients("Lotus", {Position = origin - Vector3.new(0, 2.8, 0), Radius = definition.Range, Color = realm.Color})
		end
		local hits = 0
		local riposte = key == "Strike" and (player:GetAttribute("RiposteUntil") or 0) > now()
		for _, enemy in EnemyService.GetTargets() do
			if not enemy.Model.Parent or enemy.Humanoid.Health <= 0 then continue end
			local delta = enemy.Root.Position - origin
			local distance = delta.Magnitude
			local dot = distance > 0.01 and delta.Unit:Dot(direction) or 1
			if Rules.InArc(distance, delta.Y, dot, definition.Range, key == "Palm" and 0.82 or 0.05, key == "Lotus") and clearSight(char, enemy.Model, origin, enemy.Root.Position) then
				local critical = riposte or (current.Combo == 3 and key == "Strike") or math.random() < 0.1
				local amount = Rules.Damage(realm.Damage, definition.Multiplier * discipline.Damage * (riposte and 1.25 or 1), critical)
				if EnemyService.Damage(enemy.Model, player, amount, critical) then hits += 1 end
			end
		end
		if riposte then player:SetAttribute("RiposteUntil", 0) end
		Pilgrim.HitPractice(player, key, origin, direction, definition.Range, Rules.Damage(realm.Damage, definition.Multiplier * discipline.Damage, current.Combo == 3 and key == "Strike"))
		if hits > 0 then
			player:SetAttribute("CombatAt", now())
			notice:FireClient(player, "HitConfirm", {Combo = current.Combo, Hits = hits, Riposte = riposte})
		end
	end)
end

local function meditate(player)
	local char, hum, root = characterOf(player)
	if not char then return end
	if char:GetAttribute("Action") == "Meditate" then cancelMeditation(player); return end
	if state[player].BusyUntil > now() then return end
	char:SetAttribute("GuardUntil", 0)
	if hum.FloorMaterial == Enum.Material.Air then message(player, "FIND YOUR GROUND", "Cultivation requires solid footing."); return end
	if (state[player].LastDamage or 0) + 3 > now() then message(player, "STILL YOUR HEART", "Wait a moment after taking damage."); return end
	hum.WalkSpeed = 0; hum.JumpPower = 0; hum.AutoRotate = false
	action(char, "Meditate")
	player:SetAttribute("Meditating", true)
	message(player, "BREATHE WITH THE HEAVENS", "Qi flows faster near the sanctuary's great tree. Press F or move to stand.")
end
local function breakthrough(player)
	local char, hum, root = characterOf(player)
	if not char then return end
	local index = player:GetAttribute("Realm") or 1
	if index >= #Config.Realms then message(player, "NINEFOLD IMMORTAL", "You have reached the final realm."); return end
	local data = Config.Realms[index]
	local qi = player:GetAttribute("Qi") or 0
	if qi < data.Need then message(player, "MERIDIANS NOT YET FULL", tostring(data.Need - math.floor(qi)) .. " more Qi required."); return end
	if state[player].BusyUntil > now() then return end
	cancelMeditation(player)
	state[player].BusyUntil = now() + 1.2
	player:SetAttribute("Qi", qi - data.Need)
	player:SetAttribute("Realm", index + 1)
	player:SetAttribute("Focus", Config.MaxFocus)
	updateRealm(player, true)
	action(char, "Breakthrough", 1.2)
	char:SetAttribute("InvulnerableUntil", now() + 1.2)
	fx:FireAllClients("Breakthrough", {Position = root.Position, Color = Config.Realms[index + 1].Color})
	message(player, "A NEW HEAVEN OPENS", Config.Realms[index + 1].Name .. " · Health and power increased.")
end
actionRemote.OnServerEvent:Connect(function(player, key, direction)
	if typeof(key) ~= "string" or #key > 30 or not player:GetAttribute("ProfileLoaded") or not state[player] then return end
	local rate = requestRates[player] or {At = now(), Count = 0}
	requestRates[player] = rate
	if now() - rate.At > 1 then rate.At = now(); rate.Count = 0 end
	rate.Count += 1
	if rate.Count > 16 then return end
	if key == "Recall" then Pilgrim.Recall(player); return end
	if key ~= "IntroSeen" then Pilgrim.CancelRecall(player) end
	if key == "Guard" then guard(player, direction)
	elseif key == "IntroSeen" then player:SetAttribute("IntroSeen", 1)
	elseif key == "Meditate" then meditate(player)
	elseif key == "CancelMeditation" then cancelMeditation(player)
	elseif key == "Breakthrough" then breakthrough(player)
	elseif Config.Abilities[key] then useAbility(player, key, direction) end
end)
local function nearby(player, point, distance)
	local _, _, root = characterOf(player)
	return root and (root.Position - point).Magnitude < distance
end
for _, item in workspace.World.Interactables:GetChildren() do
	local kind = item:FindFirstChild("Kind")
	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	local anchor = item:FindFirstChild("Anchor")
	if not kind or not prompt or not anchor then continue end
	if kind.Value == "Lotus" then
		local ready = true
		prompt.Triggered:Connect(function(player)
			if not ready or not player:GetAttribute("ProfileLoaded") or not nearby(player, anchor.Position, 14) then return end
			ready = false; prompt.Enabled = false
			player:SetAttribute("Petals", (player:GetAttribute("Petals") or 0) + 1)
			player:SetAttribute("QuestGather", (player:GetAttribute("QuestGather") or 0) + 1)
			addQi(player, 9)
			fx:FireAllClients("Gather", {Position = anchor.Position})
			local originals = {}
			item:SetAttribute("ReadyAt", now() + 30)
			for _, light in item:GetDescendants() do if light:IsA("PointLight") then light.Enabled = false end end
			for _, part in item:GetDescendants() do
				if part:IsA("BasePart") and part ~= anchor then originals[part] = part.Transparency; part.Transparency = 0.85 end
			end
			message(player, "SPIRIT LOTUS", "+1 petal   ·   +9 Qi")
			task.delay(30, function()
				for part, transparency in originals do if part.Parent then part.Transparency = transparency end end
				ready = true; prompt.Enabled = true
				for _, light in item:GetDescendants() do if light:IsA("PointLight") then light.Enabled = true end end
				fx:FireAllClients("Gather", {Position = anchor.Position})
			end)
		end)
	elseif kind.Value == "Portal" then
		local destination = item:FindFirstChild("Destination")
		prompt.Triggered:Connect(function(player)
			if not destination or not player:GetAttribute("ProfileLoaded") or not nearby(player, anchor.Position, 18) then return end
			if (teleportLocks[player] or 0) > now() then return end
			local char, _, root = characterOf(player)
			if not root then return end
			teleportLocks[player] = now() + 2
			Pilgrim.CancelRecall(player)
			if state[player] then state[player].Swing = (state[player].Swing or 0) + 1 end
			cancelMeditation(player)
			fx:FireAllClients("Teleport", {Position = root.Position})
			char:PivotTo(CFrame.new(destination.Value))
			root.AssemblyLinearVelocity = Vector3.zero
			char:SetAttribute("InvulnerableUntil", now() + 3)
			fx:FireAllClients("Teleport", {Position = destination.Value})
		end)
	elseif kind.Value == "GroundRelic" then
		prompt.Triggered:Connect(function(player)
			if not player:GetAttribute("ProfileLoaded") or not nearby(player, anchor.Position, 15) then return end
			if player:GetAttribute("MountainSeal") == 1 then message(player, "THE OLD SKY", "Mei Lan keeps a record of your discovery in Lanternwake."); return end
			player:SetAttribute("MountainSeal", 1); addQi(player, 45)
			fx:FireAllClients("Attune", {Position = anchor.Position})
			message(player, "CLOUDROOT SURVEY RECORDED", "+45 Qi. Return to Mei Lan after clearing five silkweavers.")
		end)
	elseif kind.Value == "Shrine" then
		local id = item.ShrineId.Value
		prompt.Triggered:Connect(function(player)
			if not player:GetAttribute("ProfileLoaded") or not nearby(player, anchor.Position, 15) then return end
			local old = player:GetAttribute("Shrines") or 0
			local mask, isNew = Rules.ClaimShrine(old, id)
			if not isNew then message(player, "MERIDIAN REMEMBERED", Config.Shrines[id].Lore); return end
			local char, _, root = characterOf(player)
			if not char then return end
			cancelMeditation(player)
			player:SetAttribute("Shrines", mask)
			addQi(player, mask == 15 and 130 or 30)
			player:SetAttribute("Spirit", (player:GetAttribute("Spirit") or 0) + (mask == 15 and 75 or 15))
			action(char, "Attune", 1.5)
			fx:FireAllClients("Attune", {Position = root.Position, Color = Color3.fromRGB(161, 231, 200)})
			message(player, mask == 15 and "FOUR MERIDIANS RESTORED" or Config.Shrines[id].Name:upper(), Config.Shrines[id].Lore)
		end)
	elseif kind.Value == "Bell" then
		local nextRing = 0
		prompt.Triggered:Connect(function(player)
			if now() < nextRing or not nearby(player, anchor.Position, 16) then return end
			nextRing = now() + 15
			fx:FireAllClients("Lotus", {Position = anchor.Position, Radius = 22, Color = Color3.fromRGB(255, 218, 140)})
			for _, other in Players:GetPlayers() do
				if nearby(other, anchor.Position, 80) then
					other:SetAttribute("BlessedUntil", now() + 45)
					message(other, "THE DAWN BELL RESONATES", "+50% meditation Qi for 45 seconds.")
				end
			end
		end)
	end
end
local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then return end
	local animate = char:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	hum.WalkSpeed = 18; hum.UseJumpPower = true; hum.JumpPower = 48
	hum.BreakJointsOnDeath = false; hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	player:SetAttribute("Focus", Config.MaxFocus)
	player:SetAttribute("Meditating", false)
	player:SetAttribute("RiposteUntil", 0)
	char:SetAttribute("GuardUntil", 0)
	action(char, "Idle")
	char:SetAttribute("InvulnerableUntil", now() + 4)
	if state[player] then state[player].BusyUntil = 0; state[player].Combo = 0; state[player].LastStrikeAt = 0 end
	updateRealm(player, true)
	hum.Died:Connect(function()
		Pilgrim.CancelRecall(player)
		if state[player] then state[player].Swing = (state[player].Swing or 0) + 1 end
		player:SetAttribute("Meditating", false)
		message(player, "THE THREAD HOLDS", "Return to Dawnreach. Your cultivation is not lost.")
	end)
end
local function onPlayer(player)
	state[player] = {BusyUntil = 0, Combo = 0, LastDamage = 0}
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	if not Profiles.Load(player) then return end
	if not player.Parent then Profiles.Save(player, true); return end
	player:SetAttribute("Focus", Config.MaxFocus)
	player:SetAttribute("Zone", "Sanctuary")
	updateRealm(player, true)
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
	local realm = Instance.new("StringValue"); realm.Name = "Realm"; realm.Value = Config.Realms[player:GetAttribute("Realm")].Name; realm.Parent = stats
	player:GetAttributeChangedSignal("Realm"):Connect(function() realm.Value = Config.Realms[player:GetAttribute("Realm")].Name end)
	task.delay(3, function()
		if player.Parent then message(player, "WELCOME TO HEAVENSUNDER", "Gather 3 glowing lotuses. Speak to Elder Yun. Press H for the field guide.") end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do task.spawn(onPlayer, player) end
Players.PlayerRemoving:Connect(function(player)
	Profiles.Save(player, true)
	state[player] = nil; teleportLocks[player] = nil; requestRates[player] = nil
end)
EnemyService.Start(fx, {
	Reward = reward,
	CancelMeditation = cancelMeditation,
	Damaged = function(player)
		player:SetAttribute("CombatAt", now())
		Pilgrim.CancelRecall(player, "Taking damage broke the seal.")
		if state[player] then state[player].LastDamage = now(); state[player].Swing = (state[player].Swing or 0) + 1 end
	end,
	Parried = function(player)
		player:SetAttribute("CombatAt", now())
		player:SetAttribute("Parries", (player:GetAttribute("Parries") or 0) + 1)
		player:SetAttribute("RiposteUntil", now() + 2.5)
		player:SetAttribute("Focus", math.min(Config.MaxFocus, (player:GetAttribute("Focus") or 0) + 16))
		message(player, "PERFECT PARRY", "Strike within 2.5 seconds for an empowered riposte.")
	end,
})
Pilgrim.Start(fx, notice, {CancelMeditation = cancelMeditation, CancelSwing = function(player)
	if state[player] then state[player].Swing = (state[player].Swing or 0) + 1 end
end})
NPCService.Start(notice)
workspace:SetAttribute("Weather", "Clear")
local weatherStart = now()
local tickAccumulator = 0
local zoneMarkers = workspace.World.Zones:GetChildren()
RunService.Heartbeat:Connect(function(dt)
	tickAccumulator += dt
	if tickAccumulator < 0.5 then return end
	local elapsed = math.min(tickAccumulator, 1.0)
	tickAccumulator = 0
	local weatherPhase = (now() - weatherStart) % 240
	local weather, intensity = Rules.Weather(weatherPhase)
	workspace:SetAttribute("Weather", weather)
	workspace:SetAttribute("WeatherIntensity", intensity)
	for _, player in Players:GetPlayers() do
		if not player:GetAttribute("ProfileLoaded") then continue end
		local char, hum, root = characterOf(player)
		if not root then continue end
		local zone = "Sky"
		for _, marker in zoneMarkers do
			local delta = root.Position - marker.Position
			if Vector3.new(delta.X, 0, delta.Z).Magnitude < marker.Size.X / 2 and math.abs(delta.Y) < 55 then zone = marker.Name; break end
		end
		player:SetAttribute("Zone", zone)
		if not player:GetAttribute("Meditating") then hum.WalkSpeed = (char:GetAttribute("WebbedUntil") or 0) > now() and 12 or 18 end
		player:SetAttribute("Focus", math.min(Config.MaxFocus, (player:GetAttribute("Focus") or 0) + Rules.FocusRegen(player:GetAttribute("Realm") or 1, player:GetAttribute("Meditating")) * Journey.Discipline(player:GetAttribute("Discipline")).Focus * elapsed))
		if root.Position.Y < -120 then
			Pilgrim.CancelRecall(player)
			if state[player] then state[player].Swing = (state[player].Swing or 0) + 1 end
			char:SetAttribute("InvulnerableUntil", now() + 3)
			cancelMeditation(player)
			char:PivotTo(CFrame.new(0, 137, 48))
			root.AssemblyLinearVelocity = Vector3.zero
			message(player, "CAUGHT BY THE SKY", "The sanctuary's wards return you safely.")
		end
		player:SetAttribute("Resonance", player:GetAttribute("Meditating") and Pilgrim.Resonance(player, root, Players:GetPlayers()) or 1)
		if char:GetAttribute("Action") == "Meditate" then
			local multiplier = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(0, 0, -28)).Magnitude < 32 and 1.6 or 1
			if (player:GetAttribute("BlessedUntil") or 0) > now() then multiplier *= 1.5 end
			addQi(player, Config.QiPerSecond * multiplier * (player:GetAttribute("Resonance") or 1) * elapsed)
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.022 * elapsed)
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(Config.SaveInterval)
		for _, player in Players:GetPlayers() do task.spawn(Profiles.Save, player, false) end
	end
end)
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function() Profiles.Save(player, true); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	EnemyService.Stop()
end)
print("[Heavensunder] Baked world ready. Nine realms. Four techniques, Meridian Guard. One broken heaven.")
