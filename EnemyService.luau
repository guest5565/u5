-- Heavensunder enemy runtime. Geometry is baked in Workspace/Actors/Enemies.
-- This module supplies behavior, not an enemy or map generator.
-- Each actor has a telegraphed state machine, home leash, line-of-sight checks,
-- path recovery, server-owned physics, contribution rewards and finite respawns.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.CombatRules)
local Journey = require(ReplicatedStorage.Shared.JourneyRules)
local attackStarts = setmetatable({}, {__mode = "k"})
local EnemyService = {}
local actors = {}
local targetCache, targetCacheDirty = {}, true
local byModel = {}
local hooks = {}
local effectRemote
local alive = true
local heartbeat
local attackSerial = 0
local pathWindow, pathRequests = 0, 0
local rng = Random.new()
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local function now()
	return workspace:GetServerTimeNow()
end
local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end
local function distanceXZ(a, b)
	return horizontal(a - b).Magnitude
end
local function livingCharacter(player)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return nil end
	return character, humanoid, root
end
local function setAction(record, action, duration)
	if not record.Model.Parent then return end
	record.Model:SetAttribute("Action", action)
	record.Model:SetAttribute("ActionAt", now())
	record.Model:SetAttribute("ActionUntil", duration and now() + duration or 0)
end
local function transition(record, state, duration)
	record.State = state
	record.StateAt = now()
	record.StateUntil = duration and now() + duration or 0
	record.Model:SetAttribute("AIState", state)
end
local function fx(kind, data)
	if effectRemote then effectRemote:FireAllClients(kind, data) end
end
local function groundAt(position)
	local hit = workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -35, 0), floorParams)
	return hit and hit.Position or nil
end
local function canStand(position, referenceY)
	local point = groundAt(position)
	return point ~= nil and math.abs(point.Y - referenceY) < 10
end
local function face(record, position)
	local delta = horizontal(position - record.Root.Position)
	if delta.Magnitude > 0.1 then
		record.Root.CFrame = CFrame.lookAt(record.Root.Position, record.Root.Position + delta)
	end
end
local function lineOfSight(record, character, point)
	sightParams.FilterDescendantsInstances = {record.Model, character, workspace:FindFirstChild("LocalEffects")}
	local start = record.Root.Position + Vector3.new(0, 1.5, 0)
	local hit = workspace:Raycast(start, point - start, sightParams)
	return hit == nil
end
local function validTarget(record, player)
	local character, humanoid, root = livingCharacter(player)
	if not root then return false end
	if character:FindFirstChildOfClass("ForceField") then return false end
	if distanceXZ(root.Position, record.Home.Position) > record.Def.Leash + 15 then return false end
	if math.abs(root.Position.Y - record.Root.Position.Y) > 20 then return false end
	return true, character, humanoid, root
end
local function chooseTarget(record)
	local best, score = nil, math.huge
	for _, player in Players:GetPlayers() do
		local valid, character, _, root = validTarget(record, player)
		if valid and (character:GetAttribute("InvulnerableUntil") or 0) <= now() then
			local d = (root.Position - record.Root.Position).Magnitude
			local threat = record.Contributions[player] or 0
			local weighted = d - math.min(threat * 0.03, 12)
			if d < record.Def.Aggro and weighted < score and lineOfSight(record, character, root.Position) then
				best, score = player, weighted
			end
		end
	end
	return best
end
local function stopMoving(record)
	record.Humanoid:MoveTo(record.Root.Position)
	record.Humanoid.WalkSpeed = 0
end
local function follow(record, destination)
	if now() < (record.NextMoveCommand or 0) then return true end
	record.NextMoveCommand = now() + 0.22
	if record.Path and #record.Path > 0 then
		local waypoint = record.Path[record.Waypoint]
		if waypoint then
			if (record.Root.Position - waypoint.Position).Magnitude < 4 then
				record.Waypoint += 1
				waypoint = record.Path[record.Waypoint]
			end
			if waypoint then
				if waypoint.Action == Enum.PathWaypointAction.Jump then record.Humanoid.Jump = true end
				destination = waypoint.Position
			else
				record.Path = nil
			end
		end
	end
	local delta = horizontal(destination - record.Root.Position)
	if delta.Magnitude > 0.1 then
		local probe = record.Root.Position + delta.Unit * 6
		local ground = groundAt(record.Root.Position)
		if ground and not canStand(probe, ground.Y) then
			record.Path = nil
			record.Humanoid:MoveTo(record.Root.Position)
			return false
		end
	end
	record.Humanoid.WalkSpeed = record.Def.Speed * (record.Enraged and 1.18 or 1)
	record.Humanoid:MoveTo(destination)
	return true
end
local function requestPath(record, destination)
	if record.PathPending or now() < record.NextPath then return end
	if now() - pathWindow >= 1 then pathWindow = now(); pathRequests = 0 end
	if pathRequests >= 2 then return end
	pathRequests += 1
	record.NextPath = now() + 3.5
	record.PathPending = true
	local pathGeneration = record.PathGeneration or 0
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = record.Def.Boss and 3 or 2,
			AgentHeight = record.Def.Boss and 10 or 6,
			AgentCanJump = false,
			WaypointSpacing = 6,
		})
		local ok = pcall(function() path:ComputeAsync(record.Root.Position, destination) end)
		if ok and record.State ~= "Dead" and record.Model.Parent and (record.PathGeneration or 0) == pathGeneration and path.Status == Enum.PathStatus.Success then
			record.Path = path:GetWaypoints()
			record.Waypoint = 2
		end
		record.PathPending = false
	end)
end
local function cancelTelegraph(record)
	if record.Attack then fx("CancelTelegraph", {Id = record.Attack.Serial, Position = record.Attack.Position}) end
	for id, position in record.EchoWarnings do fx("CancelTelegraph", {Id = id, Position = position}) end
	table.clear(record.EchoWarnings)
end
local function damagePlayer(record, player, amount, origin)
	local character, humanoid, root = livingCharacter(player)
	if not root or character:FindFirstChildOfClass("ForceField") then return end
	if (character:GetAttribute("InvulnerableUntil") or 0) > now() then return end
	if not lineOfSight(record, character, root.Position) then return end
	if hooks.CancelMeditation then hooks.CancelMeditation(player) end
	local incoming = horizontal((origin or record.Root.Position) - root.Position)
	local dot = incoming.Magnitude > 0.1 and root.CFrame.LookVector:Dot(incoming.Unit) or 1
	local response, damage, focusCost = Rules.Guard(now(), character:GetAttribute("GuardAt") or 0,
		character:GetAttribute("GuardUntil") or 0, player:GetAttribute("Focus") or 0, amount, dot)
	if response ~= "Hit" then
		player:SetAttribute("Focus", math.max(0, (player:GetAttribute("Focus") or 0) - focusCost))
		fx(response, {Position = root.Position, CFrame = root.CFrame, Color = Color3.fromRGB(255, 220, 149)})
	end
	if response == "Parry" then
		character:SetAttribute("GuardUntil", 0)
		character:SetAttribute("Action", "Parry"); character:SetAttribute("ActionAt", now()); character:SetAttribute("ActionUntil", now() + 0.45)
		character:SetAttribute("InvulnerableUntil", now() + 0.25)
		if hooks.Parried then hooks.Parried(player) end
		EnemyService.Stagger(record.Model, 0.8)
		return
	elseif response == "GuardBreak" then character:SetAttribute("GuardUntil", 0) end
	amount = response == "Block" and math.ceil(damage * Journey.Discipline(player:GetAttribute("Discipline")).Block) or damage
	humanoid:TakeDamage(amount)
	if record.Model:GetAttribute("AttackKind") == "Web" then
		character:SetAttribute("WebbedUntil", now() + 2.2)
		fx("SpiderWeb", {Position = root.Position - Vector3.new(0, 2.6, 0), Radius = 4, Color = record.Def.Color})
	end
	-- Short post-hit grace prevents simultaneous guardians from chain-staggering a player.
	character:SetAttribute("InvulnerableUntil", now() + 0.28)
	character:SetAttribute("Action", response == "Block" and "Guard" or "Stagger")
	character:SetAttribute("ActionAt", now())
	character:SetAttribute("ActionUntil", now() + 0.3)
	fx("Hit", {Position = root.Position, Damage = amount, Color = Color3.fromRGB(255, 147, 139)})
	if hooks.Damaged then hooks.Damaged(player, record.Def.Name) end
end
local function areaDamage(record, position, radius, amount, annulus)
	for _, player in Players:GetPlayers() do
		local _, _, root = livingCharacter(player)
		if root and math.abs(root.Position.Y - position.Y) < 12 then
			local d = distanceXZ(root.Position, position)
			if d <= radius and (not annulus or d >= annulus) then
				damagePlayer(record, player, amount, position)
			end
		end
	end
end
local function announceAttack(record, kind, position, radius, duration)
	attackSerial += 1
	record.Attack = {
		Kind = kind,
		Position = position,
		Radius = radius,
		Duration = duration,
		Serial = attackSerial,
		InnerRadius = kind == "Ring" and 10 or 0,
		Resolved = false,
	}
	record.Model:SetAttribute("AttackKind", kind)
	transition(record, "Windup", duration)
	setAction(record, "Windup", duration)
	stopMoving(record)
	fx("Telegraph", {
		Position = position,
		Radius = radius,
		Duration = duration,
		Id = attackSerial,
		InnerRadius = record.Attack.InnerRadius,
		Label = kind == "Web" and "SILK SNARE · MOVE OUT" or kind == "Pounce" and "FANG STRIKE · EVADE" or kind == "Ring" and "SAFE CENTER / OUTSIDE" or kind == "Storm" and "STORM · MOVE AWAY" or "CLEAVE · EVADE / GUARD",
		Color = record.Def.Color,
	})
end
local function beginAttack(record, root)
	local def = record.Def
	local ground = groundAt(record.Root.Position) or record.Root.Position - Vector3.new(0, 3, 0)
	local targetGround = groundAt(root.Position) or ground
	local count = record.AttackCount + 1
	record.AttackCount = count
	face(record, root.Position)
	if record.Kind == "SilkSpider" or record.Kind == "SilkMatriarch" then
		announceAttack(record, count % 2 == 0 and "Web" or "Pounce", targetGround + Vector3.new(0, 0.14, 0), record.Kind == "SilkMatriarch" and 10 or 6, count % 2 == 0 and 1.4 or 1.05)
	elseif def.Boss and count % 3 == 0 then
		-- The arena-wide bloom has a generous warning. Run or use dash invulnerability.
		announceAttack(record, "Ring", ground + Vector3.new(0, 0.14, 0), record.Enraged and 31 or 26, 1.6)
	elseif record.Kind == "StormDisciple" and (count % 2 == 0 or distanceXZ(root.Position, record.Root.Position) > 13) then
		-- Target location is frozen at cast start. Moving avoids the strike.
		announceAttack(record, "Storm", targetGround + Vector3.new(0, 0.14, 0), 9, 1.25)
	elseif def.Boss and count % 2 == 0 then
		announceAttack(record, "Storm", targetGround + Vector3.new(0, 0.14, 0), 12, 1.35)
	else
		local offset = record.Root.CFrame.LookVector * (def.Boss and 7 or 4.5)
		announceAttack(record, "Cleave", ground + offset + Vector3.new(0, 0.14, 0), def.Boss and 11 or 7, def.Windup)
	end
end
local function resolveAttack(record)
	local attack = record.Attack
	if not attack or attack.Resolved then return end
	attack.Resolved = true
	cancelTelegraph(record)
	local multiplier = record.Enraged and 1.2 or 1
	if attack.Kind == "Ring" then
		areaDamage(record, attack.Position, attack.Radius, record.Def.Damage * 1.3 * multiplier, attack.InnerRadius)
		fx("Lotus", {Position = attack.Position, Radius = attack.Radius, Color = record.Def.Color})
	elseif attack.Kind == "Storm" then
		areaDamage(record, attack.Position, attack.Radius, record.Def.Damage * 1.25 * multiplier)
		fx("Palm", {Position = attack.Position + Vector3.new(0, 38, 0), Direction = -Vector3.yAxis, Range = 38, Color = record.Def.Color})
		fx("Slam", {Position = attack.Position, Radius = attack.Radius, Color = record.Def.Color})
		if record.Def.Boss and record.Enraged then
			attackSerial += 1
			local echoId = attackSerial
			local point = attack.Position
			record.EchoWarnings[echoId] = point
			fx("Telegraph", {Id = echoId, Position = point, Radius = 8, Duration = 1.0, Label = "ECHO · KEEP MOVING", Color = record.Def.Color})
			task.delay(1.0, function()
				local stillPending = record.EchoWarnings[echoId] ~= nil
				fx("CancelTelegraph", {Id = echoId, Position = point})
				record.EchoWarnings[echoId] = nil
				if not stillPending or record.State == "Dead" or not record.Model.Parent then return end
				areaDamage(record, point, 8, record.Def.Damage)
				fx("Slam", {Position = point, Radius = 8, Color = record.Def.Color})
			end)
		end
	else
		areaDamage(record, attack.Position, attack.Radius, record.Def.Damage * multiplier)
		fx("Slam", {Position = attack.Position, Radius = attack.Radius, Color = record.Def.Color})
	end
	if record.State == "Stagger" then return end
	setAction(record, "Slam", 0.55)
	transition(record, "Recover", record.Def.Boss and 1.15 or 0.72)
	record.NextAttack = now() + record.Def.Cooldown
end
local function resetToHome(record)
	record.PathGeneration = (record.PathGeneration or 0) + 1
	cancelTelegraph(record)
	record.Target = nil
	record.Path = nil
	record.Attack = nil
	transition(record, "Return")
	setAction(record, "Idle")
end
local function patrolDestination(record)
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(5, record.Def.Boss and 9 or 17)
		local point = record.Home.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local ground = groundAt(point)
		if ground and math.abs(ground.Y - (record.Home.Position.Y - record.Humanoid.HipHeight - record.Root.Size.Y / 2)) < 12 then
			return Vector3.new(point.X, record.Home.Position.Y, point.Z)
		end
	end
	return record.Home.Position
end
local function updateHealthBillboard(record)
	local head = record.Model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("Nameplate")
	if not gui then return end
	local label = gui:FindFirstChild("Title")
	local fill = gui:FindFirstChild("Bar") and gui.Bar:FindFirstChild("Fill")
	if label then
		label.Text = record.Def.Name .. (record.Enraged and " • ENRAGED" or "")
	end
	if fill then fill.Size = UDim2.fromScale(math.clamp(record.Humanoid.Health / record.Humanoid.MaxHealth, 0, 1), 1) end
end
local register
local function onDeath(record)
	targetCacheDirty = true
	if record.State == "Dead" then return end
	cancelTelegraph(record)
	transition(record, "Dead")
	setAction(record, "Dead")
	record.Target = nil
	record.Attack = nil
	fx("Death", {Position = record.Root.Position, Color = record.Def.Color})
	for player, damage in record.Contributions do
		local _, _, root = livingCharacter(player)
		if player.Parent and root and damage > 0 and (root.Position - record.Root.Position).Magnitude < 180 then
			if hooks.Reward then hooks.Reward(player, record.Def.Reward, record.Def.Spirit, record.Def.Boss == true, record.Kind) end
		end
	end
	for _, part in record.Model:GetDescendants() do
		if part:IsA("BasePart") then part.CanCollide = false; part.Anchored = part == record.Root end
	end
	task.delay(3.5, function()
		if record.Model.Parent then record.Model:Destroy() end
	end)
	task.delay(record.Def.Respawn, function()
		if not alive or not record.Template then return end
		local model = record.Template:Clone()
		model.Parent = workspace.Actors.Enemies
		model:PivotTo(record.Home)
		register(model, record.Template, record.Home)
	end)
end
register = function(model, template, home)
	targetCacheDirty = true
	local kindValue = model:FindFirstChild("Archetype")
	local kind = kindValue and kindValue.Value
	local def = kind and Config.Enemies[kind]
	local root = model:FindFirstChild("HumanoidRootPart")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not def or not root or not hum then
		warn("[Heavensunder] Invalid baked enemy:", model:GetFullName())
		return
	end
	local record = {
		Model = model,
		Root = root,
		Humanoid = hum,
		Kind = kind,
		Def = def,
		Home = home or model:GetPivot(),
		Template = template or model:Clone(),
		State = "Idle",
		StateAt = now(),
		StateUntil = 0,
		Target = nil,
		NextAttack = now() + 2,
		NextScan = now() + rng:NextNumber(0, 1),
		NextPatrol = now() + rng:NextNumber(2, 6),
		NextPath = 0,
		PathPending = false,
		Path = nil,
		Waypoint = 1,
		AttackCount = 0,
		Contributions = {},
		EchoWarnings = {},
		Enraged = false,
		LastPosition = root.Position,
		StuckTime = 0,
		LastHit = 0,
	}
	table.insert(actors, record)
	byModel[model] = record
	model:SetAttribute("Enemy", true)
	model:SetAttribute("Boss", def.Boss == true)
	model:SetAttribute("Archetype", kind)
	model:SetAttribute("DisplayName", def.Name)
	hum.MaxHealth = def.Health
	hum.Health = def.Health
	hum.WalkSpeed = def.Speed
	hum.BreakJointsOnDeath = false
	hum.AutoRotate = true
	pcall(function() root:SetNetworkOwner(nil) end)
	setAction(record, "Idle")
	hum.Died:Connect(function() onDeath(record) end)
	hum.HealthChanged:Connect(function()
		updateHealthBillboard(record)
		if def.Boss and hum.Health > 0 and hum.Health / hum.MaxHealth <= 0.45 and not record.Enraged then
			record.Enraged = true
			model:SetAttribute("Enraged", true)
			fx("Breakthrough", {Position = root.Position, Color = def.Color})
			updateHealthBillboard(record)
		end
	end)
	updateHealthBillboard(record)
end
-- Third-strike criticals interrupt ordinary guardians, but not the boss.
-- Telegraph cancellation is part of the state machine, not a client-only illusion.
function EnemyService.Stagger(model, duration)
	local record = byModel[model]
	if not record or record.State == "Dead" then return false end
	if record.Def.Boss or record.Humanoid.Health <= 0 then return false end
	if record.State == "Stagger" then return false end
	if now() - (record.LastStagger or 0) < 2 then return false end
	record.LastStagger = now()
	cancelTelegraph(record)
	if record.Attack then record.Attack.Resolved = true end
	record.Attack = nil
	record.Path = nil
	stopMoving(record)
	transition(record, "Stagger", duration)
	setAction(record, "Stagger", duration)
	record.NextAttack = math.max(record.NextAttack, now() + duration + 0.8)
	return true
end
function EnemyService.Damage(model, player, amount, critical)
	local record = byModel[model]
	if not record or record.State == "Dead" or record.Humanoid.Health <= 0 then return false end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then return false end
	amount = math.clamp(amount, 0, 1000)
	record.Contributions[player] = (record.Contributions[player] or 0) + math.min(amount, record.Humanoid.Health)
	record.LastHit = now()
	if record.Target == nil then record.Target = player end
	record.Humanoid:TakeDamage(amount)
	if critical and record.Humanoid.Health > 0 then
		EnemyService.Stagger(model, 0.45)
	end
	fx("Hit", {Position = record.Root.Position, Damage = amount, Critical = critical, Color = record.Def.Color})
	return true
end
function EnemyService.GetTargets()
	if targetCacheDirty then
		table.clear(targetCache)
		for _, record in actors do
			if record.State ~= "Dead" and record.Model.Parent and record.Humanoid.Health > 0 then table.insert(targetCache, record) end
		end
		targetCacheDirty = false
	end
	return targetCache
end
local function step(record, dt)
	if record.State == "Dead" or not record.Model.Parent then return end
	if record.Humanoid.Health <= 0 then onDeath(record); return end
	local t = now()
	-- Falling off an island is not a soft lock. Return to the baked home safely.
	if record.Root.Position.Y < record.Home.Position.Y - 45 then
		record.Model:PivotTo(record.Home)
		record.Root.AssemblyLinearVelocity = Vector3.zero
		resetToHome(record)
		return
	end
	if record.State == "Windup" then
		if t >= record.StateUntil then resolveAttack(record) end
		return
	elseif record.State == "Stagger" then
		if t >= record.StateUntil then
			transition(record, "Chase")
			setAction(record, "Idle")
		end
		return
	elseif record.State == "Recover" then
		if t >= record.StateUntil then transition(record, "Chase"); setAction(record, "Idle") end
		return
	end
	if record.Target then
		local valid, character, _, targetRoot = validTarget(record, record.Target)
		if not valid or distanceXZ(record.Root.Position, record.Home.Position) > record.Def.Leash then
			resetToHome(record)
		else
			if record.State ~= "Chase" then transition(record, "Chase") end
			local d = distanceXZ(record.Root.Position, targetRoot.Position)
			local range = record.Kind == "StormDisciple" and 26 or record.Def.Reach
			if d <= range and t >= record.NextAttack and lineOfSight(record, character, targetRoot.Position) then
				local windups = 0
				for _, other in actors do
					if other ~= record and other.Target == record.Target and other.State == "Windup" then windups += 1 end
				end
				if Journey.AttackSlot(windups, attackStarts[record.Target] or 0, t, record.Def.Boss) then
					attackStarts[record.Target] = t; beginAttack(record, targetRoot)
				else stopMoving(record); face(record, targetRoot.Position) end
			else
				if d > record.Def.Reach * 0.75 then follow(record, targetRoot.Position) else stopMoving(record); face(record, targetRoot.Position) end
				if (record.Root.Position - record.LastPosition).Magnitude < 0.18 and d > range then
					record.StuckTime += dt
					if record.StuckTime > 1.5 then requestPath(record, targetRoot.Position); record.StuckTime = 0 end
				else record.StuckTime = 0 end
			end
			record.LastPosition = record.Root.Position
			return
		end
	end
	if record.State == "Return" then
		follow(record, record.Home.Position)
		if distanceXZ(record.Root.Position, record.Home.Position) < 5 then
			record.Humanoid.Health = record.Humanoid.MaxHealth
			record.Enraged = false; record.Model:SetAttribute("Enraged", false)
			updateHealthBillboard(record)
			transition(record, "Idle")
			record.NextPatrol = t + 4
			table.clear(record.Contributions)
		elseif t - record.StateAt > 14 then
			record.Model:PivotTo(record.Home)
			record.Humanoid.Health = record.Humanoid.MaxHealth
			record.Enraged = false; record.Model:SetAttribute("Enraged", false)
			table.clear(record.Contributions); updateHealthBillboard(record)
			transition(record, "Idle")
		end
		return
	end
	if t >= record.NextScan then
		record.NextScan = t + 0.6
		record.Target = chooseTarget(record)
		if record.Target then transition(record, "Chase"); return end
	end
	if record.State == "Patrol" then
		follow(record, record.PatrolPoint)
		if distanceXZ(record.Root.Position, record.PatrolPoint) < 4 or t - record.StateAt > 7 then
			transition(record, "Idle")
			stopMoving(record)
			record.NextPatrol = t + rng:NextNumber(3, 7)
		end
	elseif t >= record.NextPatrol then
		record.PatrolPoint = patrolDestination(record)
		transition(record, "Patrol")
	end
end
function EnemyService.Start(remote, callbacks)
	effectRemote = remote
	hooks = callbacks or {}
	floorParams.FilterDescendantsInstances = {workspace.World.Islands, workspace.World.Architecture, workspace.World.Paths, workspace.World.Ground}
	for _, model in workspace.Actors.Enemies:GetChildren() do register(model) end
	local accumulator = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then return end
		local stepDt = math.min(accumulator, 0.3)
		accumulator = 0
		for i = #actors, 1, -1 do
			local record = actors[i]
			if record.State == "Dead" and not record.Model.Parent then
				byModel[record.Model] = nil
				table.remove(actors, i)
			else step(record, stepDt) end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, record in actors do
			record.Contributions[player] = nil
			if record.Target == player then resetToHome(record) end
		end
	end)
end
function EnemyService.Stop()
	alive = false
	if heartbeat then heartbeat:Disconnect() end
	for _, record in actors do if record.Template then record.Template:Destroy() end end
	table.clear(actors)
	table.clear(byModel); table.clear(targetCache); targetCacheDirty = true
end
return EnemyService
