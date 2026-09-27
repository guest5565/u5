-- Bounded client-side effects. No effect deals damage; authoritative hit tests live on server.
-- Parts are pooled, particle rates scale with quality, text and lights have finite lifetimes.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Budget = require(game:GetService("ReplicatedStorage").Shared.EffectBudget)
local VFX = {}
local folder
local pool, active = {}, {}
local created = 0
local MAX_PARTS = 360
local MAX_ACTIVE = 360
local MAX_COSMETIC = 220
local reducedMotion = false
local rng = Random.new()
local jade = Color3.fromRGB(128, 255, 210)
local gold = Color3.fromRGB(255, 217, 134)
local pink = Color3.fromRGB(255, 153, 208)
local connection
local weatherPart, rain, snow, motes
local impactShake = 0
local quality = 1
local textCount = 0
local petals
local shelterParams = RaycastParams.new()
shelterParams.FilterType = Enum.RaycastFilterType.Include
local function ensure()
	if folder then return end
	folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = workspace
end
local function acquire()
	ensure()
	local part = table.remove(pool)
	if not part then
		if created >= MAX_PARTS then return nil end
		part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		created += 1
	end
	part.Shape = Enum.PartType.Block
	part.Transparency = 0
	part.Color = jade
	part.Size = Vector3.one
	part.Parent = folder
	return part
end
local function release(part)
	part.Parent = nil
	for _, obj in part:GetChildren() do obj:Destroy() end
	table.insert(pool, part)
end
local function effect(lifetime, update, priority, id)
	priority = priority or 0
	local allowed, victim = Budget.Admit(active, priority, MAX_COSMETIC, MAX_ACTIVE)
	if not allowed then return nil end
	if victim then release(active[victim].Part); table.remove(active, victim) end
	local part = acquire()
	if not part then return nil end
	part.CFrame = CFrame.new()
	local item = {Part = part, Age = 0, Life = lifetime, Update = update, Priority = priority, Id = id}
	table.insert(active, item)
	update(part, 0, 0)
	return part
end
function VFX.CancelTelegraph(id)
	if id == nil then return end
	for i = #active, 1, -1 do
		if active[i].Id == id then release(active[i].Part); table.remove(active, i) end
	end
end
local function beamBetween(a, b, width, color, life, priority, id)
	local delta = b - a
	if delta.Magnitude < 0.01 then return end
	local p = effect(life, function(part, alpha)
		part.Transparency = priority == 2 and 0.12 or alpha
		part.Size = Vector3.new(width * (1 - alpha * 0.8), width * (1 - alpha * 0.8), delta.Magnitude)
	end, priority, id)
	if p then
		p.Color = color
		p.Size = Vector3.new(width, width, delta.Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
	end
end
function VFX.Ring(position, radius, color, life, grow, width, priority, id, segmentCount)
	local segments = segmentCount or (quality < 0.7 and 20 or 32)
	for i = 1, segments do
		local angle = i / segments * math.pi * 2
		local p = effect(life, function(part, alpha)
			local r = radius * (1 + (grow or 0) * alpha)
			part.Size = Vector3.new(width or 0.12, width or 0.12, r * math.pi * 2 / segments * 1.08)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.new(r, 0, 0)
			part.Transparency = priority == 2 and 0.12 or math.clamp(alpha ^ 1.6, 0, 1)
		end, priority, id)
		if p then p.Color = color end
	end
end
function VFX.Burst(position, color, count, speed)
	count = math.floor(count * quality)
	for _ = 1, count do
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.15, 1), rng:NextNumber(-1, 1))
		if direction.Magnitude < 0.01 then direction = Vector3.yAxis end
		local velocity = direction.Unit * rng:NextNumber(speed * 0.3, speed)
		local life = rng:NextNumber(0.4, 0.95)
		local size = rng:NextNumber(0.12, 0.38)
		local p = effect(life, function(part, alpha, age)
			local point = position + velocity * age + Vector3.new(0, -5 * age * age, 0)
			part.CFrame = CFrame.new(point) * CFrame.Angles(age * 4, age * 3, age * 2)
			part.Size = Vector3.new(size, size * 1.7, size) * (1 - alpha * 0.85)
			part.Transparency = alpha
		end)
		if p then p.Color = color end
	end
end
function VFX.Orb(position, color, size, life)
	local p = effect(life, function(part, alpha)
		part.Size = Vector3.one * (size * (0.3 + alpha * 1.7))
		part.Transparency = 0.25 + alpha * 0.75
	end)
	if p then p.Shape = Enum.PartType.Ball; p.Position = position; p.Color = color end
end
function VFX.Lightning(a, b, color)
	local last = a
	for i = 1, 10 do
		local alpha = i / 10
		local nextPoint = a:Lerp(b, alpha)
		if i < 10 then
			nextPoint += Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
		end
		beamBetween(last, nextPoint, 0.18, color, 0.24)
		if i % 3 == 0 then
			beamBetween(nextPoint, nextPoint + Vector3.new(rng:NextNumber(-3, 3), 3, rng:NextNumber(-3, 3)), 0.08, color, 0.15)
		end
		last = nextPoint
	end
end
function VFX.Slash(cf, color, combo)
	local center = cf * CFrame.new(0, 0.3, -3)
	for i = 1, 12 do
		local a = -1.1 + i / 12 * 2.2
		local start = (center * CFrame.Angles(0, a, (combo or 1) % 2 == 0 and -0.3 or 0.3) * CFrame.new(0, 0, -4)).Position
		local finish = (center * CFrame.Angles(0, a + 0.16, 0) * CFrame.new(0, 0, -4)).Position
		beamBetween(start, finish, 0.16, color, 0.20 + i * 0.008)
	end
end
function VFX.Damage(position, amount, critical)
	if textCount >= 24 then return end
	ensure()
	textCount += 1
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
	anchor.Transparency = 1; anchor.Size = Vector3.one * 0.1
	anchor.Position = position + Vector3.new(rng:NextNumber(-1, 1), 3, 0); anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 55); gui.AlwaysOnTop = true; gui.MaxDistance = 180; gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1); text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold; text.TextSize = critical and 28 or 22
	text.TextColor3 = critical and gold or Color3.fromRGB(237, 255, 250)
	text.TextStrokeColor3 = Color3.fromRGB(17, 30, 38); text.TextStrokeTransparency = 0.25
	text.Text = type(amount) == "string" and amount or tostring(math.floor(amount)); text.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = anchor.Position + Vector3.new(0, 3, 0)}):Play()
	TweenService:Create(text, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(0.9, function() anchor:Destroy(); textCount -= 1 end)
end
function VFX.Shake(position, strength)
	if reducedMotion then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local distance = (camera.CFrame.Position - position).Magnitude
	impactShake = math.min(1.2, impactShake + strength * math.clamp(1 - distance / 110, 0, 1))
end
-- Warning geometry has its own priority reserve and never fades before impact.
-- Inner-safe attacks are drawn as annuli; the center is not painted as danger.
function VFX.Telegraph(position, radius, duration, color, id, inner, caption)
	inner = inner or 0
	local label
	local anchor = effect(duration, function(part, _, age)
		part.Transparency = 1; part.Size = Vector3.one * 0.1; part.Position = position + Vector3.new(0, 2.6, 0)
		if label then label.Text = (caption or (inner > 0 and "SAFE CENTER / OUTSIDE" or "MOVE OUT / GUARD")) .. string.format("  %.1fs", math.max(0, duration - age)) end
	end, 2, id)
	if anchor then
		local gui = Instance.new("BillboardGui"); gui.Size = UDim2.fromOffset(270, 34); gui.AlwaysOnTop = true; gui.MaxDistance = 160; gui.Parent = anchor
		label = Instance.new("TextLabel"); label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 0.18
		label.BackgroundColor3 = Color3.fromRGB(20, 27, 34); label.TextColor3 = Color3.fromRGB(255, 233, 185)
		label.Font = Enum.Font.GothamBold; label.TextSize = 12; label.TextStrokeTransparency = 0.6; label.Parent = gui
	end
	VFX.Ring(position, radius, color, duration, 0, 0.17, 2, id, 24)
	if inner > 0 then
		VFX.Ring(position + Vector3.new(0, 0.03, 0), inner, jade, duration, 0, 0.16, 2, id, 20)
		for i = 1, 24 do
			local angle = i / 24 * math.pi * 2
			local mid = (inner + radius) / 2
			local cf = CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.new(mid, 0, 0)
			local p = effect(duration, function(part, alpha)
				part.CFrame = cf; part.Size = Vector3.new(radius - inner, 0.06, mid * math.pi * 2 / 24 * 0.90)
				part.Transparency = 0.87 - alpha * 0.18
			end, 2, id)
			if p then p.Color = color end
		end
	else
		local p = effect(duration, function(part, alpha)
			part.Size = Vector3.new(0.06, radius * 2, radius * 2)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
			part.Transparency = 0.89 - alpha * 0.22
		end, 2, id)
		if p then p.Shape = Enum.PartType.Cylinder; p.Color = color end
	end
end
function VFX.Shield(cf, color, strong)
	local center = cf * CFrame.new(0, 0.4, -1.8)
	for i = 1, 20 do
		local a = i / 20 * math.pi * 2
		local b = (i + 1) / 20 * math.pi * 2
		local radius = strong and 2.5 or 1.9
		beamBetween((center * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)).Position,
			(center * CFrame.new(math.cos(b) * radius, math.sin(b) * radius, 0)).Position,
			strong and 0.18 or 0.09, color, strong and 0.45 or 0.28, 1)
	end
end
function VFX.Petals(position, color)
	for i = 1, math.floor(12 * quality) do
		local angle = i / 12 * math.pi * 2
		local p = effect(0.9, function(part, alpha)
			local radius = 2 + alpha * 9
			part.Size = Vector3.new(1.5, 3.4, 0.2) * (1 - alpha * 0.7)
			part.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * radius, math.sin(alpha * math.pi) * 4, math.sin(angle) * radius)) * CFrame.Angles(-alpha * 0.6, -angle, 0.5)
			part.Transparency = 0.15 + alpha * 0.85
		end)
		if p then p.Shape = Enum.PartType.Ball; p.Color = color end
	end
end
function VFX.Echoes(position, direction, color)
	local cf = CFrame.lookAt(position, position + direction)
	local pieces = {{Vector3.new(0, 0, 0), Vector3.new(1.8, 2.1, 0.8)},
		{Vector3.new(0, 1.8, 0), Vector3.new(1, 1, 1)},
		{Vector3.new(-0.5, -1.5, 0), Vector3.new(0.6, 1.5, 0.6)},
		{Vector3.new(0.5, -1.5, 0), Vector3.new(0.6, 1.5, 0.6)}}
	for step = 1, (quality < 1 and 2 or 4) do
		for _, piece in pieces do
			local snapshot = cf * CFrame.new(piece[1] + Vector3.new(0, 0, step * 1.7))
			local p = effect(0.18 + step * 0.055, function(part, alpha)
				part.CFrame = snapshot; part.Size = piece[2]; part.Transparency = 0.70 + alpha * 0.30
			end)
			if p then p.Color = color end
		end
	end
end
function VFX.SetReducedMotion(enabled)
	reducedMotion = enabled
	if enabled then impactShake = 0 end
end
function VFX.Handle(kind, data)
	local position = data.Position
	local camera = workspace.CurrentCamera
	if position and camera and (camera.CFrame.Position - position).Magnitude > 320 then return end
	local color = data.Color or jade
	if kind == "CancelTelegraph" then VFX.CancelTelegraph(data.Id)
	elseif kind == "Guard" or kind == "Block" then VFX.Shield(data.CFrame, jade, false)
	elseif kind == "Parry" then
		VFX.Shield(data.CFrame, gold, true); VFX.Burst(position, gold, 20, 16)
		VFX.Damage(position, "PARRY", true); VFX.Shake(position, 0.22)
	elseif kind == "GuardBreak" then
		VFX.Burst(position, pink, 18, 13); VFX.Damage(position, "GUARD BREAK", false)
	elseif kind == "SpiderWeb" then
		VFX.Ring(position, data.Radius or 4, color, 2.2, 0, .07, 1)
		for i=1,8 do
			local a=i/8*math.pi*2
			beamBetween(position,position+Vector3.new(math.cos(a)*4,0,math.sin(a)*4),.07,color,2.2,1)
		end
	elseif kind == "Recall" then
		VFX.Ring(position - Vector3.new(0, 2.7, 0), 3, jade, data.Duration or 4, 0.35, 0.10, 1, data.Id, 24)
	elseif kind == "Attune" then
		VFX.Petals(position, gold); VFX.Ring(position - Vector3.new(0, 2.6, 0), 3, jade, 1.2, 1.5)
	elseif kind == "Strike" then
		VFX.Slash(data.CFrame, color, data.Combo)
	elseif kind == "Hit" then
		VFX.Burst(position, color, 12, 14)
		VFX.Orb(position, color, 2.5, 0.2)
		if data.Damage then VFX.Damage(position, data.Damage, data.Critical) end
		VFX.Shake(position, 0.12)
	elseif kind == "Palm" then
		local finish = position + data.Direction * (data.Range or 40)
		VFX.Lightning(position, finish, color)
		VFX.Burst(finish, color, 16, 13)
		VFX.Ring(position - Vector3.new(0, 2.5, 0), 3, color, 0.45, 1.5)
	elseif kind == "Dash" then
		VFX.Echoes(position, data.Direction, color)
	elseif kind == "Telegraph" then
		VFX.Telegraph(position, data.Radius, data.Duration, color, data.Id, data.InnerRadius, data.Label)
	elseif kind == "Slam" or kind == "Lotus" then
		if kind == "Lotus" then VFX.Petals(position, color) end
		VFX.Ring(position, data.Radius or 12, color, 0.8, 0.4, 0.25)
		VFX.Ring(position + Vector3.new(0, 0.6, 0), 2, color, 0.6, 8, 0.12)
		VFX.Burst(position, color, 38, 24)
		VFX.Orb(position, color, 8, 0.45)
		VFX.Shake(position, 0.55)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local tip = position + Vector3.new(math.cos(a) * 8, 6, math.sin(a) * 8)
			beamBetween(position, tip, 0.15, color, 0.5)
		end
	elseif kind == "Breakthrough" then
		VFX.Ring(position - Vector3.new(0, 2.5, 0), 5, gold, 1.5, 3, 0.2)
		VFX.Ring(position + Vector3.new(0, 1, 0), 3, color, 1.2, 2, 0.15)
		VFX.Burst(position, gold, 60, 28)
		if not reducedMotion then VFX.Lightning(position + Vector3.new(0, 65, 0), position, gold) end
		VFX.Orb(position, gold, 15, 0.75)
		VFX.Shake(position, 0.8)
	elseif kind == "Death" then
		VFX.Burst(position, color, 36, 18)
		VFX.Ring(position, 3, color, 0.7, 2.5)
	elseif kind == "Gather" or kind == "Heal" then
		VFX.Burst(position, gold, 18, 9)
		VFX.Ring(position - Vector3.new(0, 2, 0), 2, jade, 0.7, 1.8)
	elseif kind == "Teleport" then
		VFX.Burst(position, color, 35, 16)
		VFX.Ring(position, 4, color, 0.6, 2)
	end
end
local function emitter(name, texture, parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = name; e.Texture = texture; e.Enabled = true
	e.LightInfluence = 0; e.LockedToPart = false
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(10, 10)
	e.Parent = parent
	return e
end
function VFX.SetQuality(low)
	quality = low and 0.5 or 1
	if rain then rain.Rate = (rain.Enabled and 220 or 0) * quality end
	if snow then snow.Rate = (snow.Enabled and 95 or 0) * quality end
end
function VFX.Start()
	if connection then return end
	ensure()
	weatherPart = Instance.new("Part")
	weatherPart.Name = "LocalWeatherVolume"
	weatherPart.Size = Vector3.new(85, 1, 85); weatherPart.Anchored = true
	weatherPart.Transparency = 1; weatherPart.CanCollide = false
	weatherPart.CanQuery = false; weatherPart.CanTouch = false; weatherPart.Parent = folder
	rain = emitter("Rain", "rbxasset://textures/particles/sparkles_main.dds", weatherPart)
	rain.Lifetime = NumberRange.new(0.8, 1.1); rain.Speed = NumberRange.new(75, 95)
	rain.Acceleration = Vector3.new(-8, -25, 0); rain.Size = NumberSequence.new(0.10)
	rain.Transparency = NumberSequence.new(0.35); rain.Color = ColorSequence.new(Color3.fromRGB(168, 216, 246))
	rain.VelocityInheritance = 0; rain.Rate = 0
	rain.Squash = NumberSequence.new(-0.95)
	snow = emitter("Snow", "rbxasset://textures/particles/sparkles_main.dds", weatherPart)
	snow.Lifetime = NumberRange.new(5, 7); snow.Speed = NumberRange.new(7, 11)
	snow.Acceleration = Vector3.new(1.6, -1, 0); snow.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.24), NumberSequenceKeypoint.new(1, 0)})
	snow.Color = ColorSequence.new(Color3.fromRGB(229, 242, 255)); snow.Rate = 0
	snow.Rotation = NumberRange.new(0, 360); snow.RotSpeed = NumberRange.new(-40, 40)
	motes = emitter("SpiritMotes", "rbxasset://textures/particles/sparkles_main.dds", weatherPart)
	motes.Lifetime = NumberRange.new(4, 6); motes.Speed = NumberRange.new(3, 7)
	motes.Acceleration = Vector3.new(0, 1, 0); motes.Size = NumberSequence.new(0.13)
	motes.Color = ColorSequence.new(gold); motes.Rate = 16; motes.LightEmission = 0.8
	petals = emitter("CherryPetals", "rbxasset://textures/particles/sparkles_main.dds", weatherPart)
	petals.Lifetime = NumberRange.new(5, 7); petals.Speed = NumberRange.new(4, 6)
	petals.Size = NumberSequence.new(0.22); petals.Color = ColorSequence.new(pink)
	petals.Rotation = NumberRange.new(0, 360); petals.RotSpeed = NumberRange.new(-65, 65)
	petals.Acceleration = Vector3.new(1, -0.5, 0); petals.Rate = 0
	shelterParams.FilterDescendantsInstances = {workspace.World.Architecture, workspace.World.Ground.Buildings}
	local bakedSpray={}
	for _,e in workspace.World.Waterfalls:GetDescendants() do if e:IsA("ParticleEmitter") then table.insert(bakedSpray,{Emitter=e,Rate=e.Rate}) end end
	local auraClock, weatherClock, footClock = 0, 0, 0
	connection = RunService.Heartbeat:Connect(function(dt)
		for i = #active, 1, -1 do
			local item = active[i]
			item.Age += dt
			if item.Age >= item.Life then
				release(item.Part); table.remove(active, i)
			else
				item.Update(item.Part, item.Age / item.Life, item.Age)
			end
		end
		local camera = workspace.CurrentCamera
		if camera then weatherPart.Position = camera.CFrame.Position + Vector3.new(0, 38, 0) end
		weatherClock += dt
		if weatherClock > 0.5 then
			weatherClock = 0
			for _,item in bakedSpray do
				local e=item.Emitter
				if e.Parent and camera then e.Enabled=(e.Parent.Position-camera.CFrame.Position).Magnitude<200; e.Rate=item.Rate*quality end
			end
			local zone = Players.LocalPlayer:GetAttribute("Zone")
			local isSnow = zone == "Frost"
			local intensity = workspace:GetAttribute("WeatherIntensity") or 0
			local char = Players.LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local sheltered = root and workspace:Raycast(root.Position, Vector3.new(0, 80, 0), shelterParams) ~= nil
			local isRain = not isSnow and intensity > 0.04 and not sheltered
			rain.Enabled = isRain; rain.Rate = isRain and 210 * quality * intensity or 0
			snow.Enabled = isSnow and not sheltered; snow.Rate = snow.Enabled and 85 * quality or 0
			rain.Acceleration = Vector3.new(-7 - intensity * 5, -25, 2)
			snow.Acceleration = Vector3.new(1.5 + intensity * 2, -1, 0)
			motes.Enabled = not isSnow and intensity < 0.3
			petals.Rate = (zone == "Sanctuary" or zone == "Garden") and not sheltered and 9 * quality * (1 - intensity) or 0
		end
		footClock += dt
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and footClock > 0.28 and hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air then
			footClock = 0
			VFX.Burst(root.Position - Vector3.new(0, 2.8, 0), Players.LocalPlayer:GetAttribute("Zone") == "Frost" and Color3.fromRGB(215, 235, 250) or Color3.fromRGB(140, 170, 149), 2, 3)
		end
		auraClock += dt
		if auraClock > 0.9 then
			auraClock = 0
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and character:GetAttribute("Action") == "Meditate" and camera and (root.Position - camera.CFrame.Position).Magnitude < 140 then
					VFX.Ring(root.Position - Vector3.new(0, 2.7, 0), 2.6, (player:GetAttribute("Resonance") or 1) > 1 and gold or jade, 1.3, 0.45, 0.07)
					VFX.Burst(root.Position - Vector3.new(0, 2, 0), jade, 5, 3)
				end
			end
		end
	end)
	RunService:BindToRenderStep("HeavensunderShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then return end
		-- Default camera replaces its frame each render; don't accumulate displacement.
		impactShake *= math.exp(-dt * 10)
		if not reducedMotion and impactShake > 0.005 then
			local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * impactShake * 0.16
			camera.CFrame *= CFrame.new(offset)
		end
	end)
end
function VFX.Stop()
	if connection then connection:Disconnect(); connection = nil end
	RunService:UnbindFromRenderStep("HeavensunderShake")
	for _, item in active do item.Part:Destroy() end
	for _, part in pool do part:Destroy() end
	table.clear(active); table.clear(pool); created = 0
	if folder then folder:Destroy(); folder = nil end
end
return VFX
