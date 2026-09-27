-- Optional Studio diagnostics. Does not mutate the world.
-- In Studio's SERVER command bar: require(game.ServerScriptService.Diagnostics).Run()
local Diagnostics = {}
function Diagnostics.Run()
	local checks = 0
	local function check(condition, text)
		assert(condition, "[Heavensunder diagnostics] " .. text)
		checks += 1
	end
	local world = workspace:FindFirstChild("World")
	check(world ~= nil, "Workspace.World must exist before Play")
	for _, name in {"Islands", "Foliage", "Architecture", "Paths", "Waterfalls", "Interactables", "Zones", "Training", "Ground"} do
		check(world:FindFirstChild(name) ~= nil, "Missing world folder: " .. name)
	end
	check(#world.Islands:GetChildren() == 5, "Expected five main islands")
	check(#world.Zones:GetChildren() == 9, "Expected nine zone markers")
	check(#world.Training:GetChildren() == 3, "Expected three practice targets")
	for _, object in game:GetDescendants() do
		if object:IsA("Model") and object.PrimaryPart then
			check(object.PrimaryPart:IsA("BasePart") and object.PrimaryPart:IsDescendantOf(object), "Invalid PrimaryPart: " .. object:GetFullName())
		end
	end
	local lighting = game:GetService("Lighting")
	for _, name in {"SkyVeil", "CelestialSky", "JadeBloom", "CelestialGrade", "WeatherGrade", "EveningRays", "FarSkyDepth"} do
		check(lighting:FindFirstChild(name) ~= nil, "Missing authored lighting instance: " .. name)
	end
	local custom = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	check(custom ~= nil, "Missing custom StarterCharacter")
	local rigs = {custom}
	for _, folder in {workspace.Actors.NPCs, workspace.Actors.Enemies} do
		for _, rig in folder:GetChildren() do table.insert(rigs, rig) end
	end
	for _, rig in rigs do
		check(rig ~= nil, "Missing custom character")
		check(rig.PrimaryPart ~= nil, rig.Name .. " has no PrimaryPart")
		check(rig:FindFirstChildOfClass("Humanoid") ~= nil, rig.Name .. " has no humanoid")
		check(rig:FindFirstChild("QiCore") ~= nil, rig.Name .. " has no Qi core")
		local count = 0
		for _, object in rig:GetDescendants() do
			if object:IsA("Motor6D") then
				count += 1
				check(object.Part0 ~= nil and object.Part1 ~= nil, "Unbound motor: " .. object:GetFullName())
				check(object.Part0:IsDescendantOf(rig) and object.Part1:IsDescendantOf(rig), "Motor links across rigs")
			end
		end
		check(count == (rig:FindFirstChild("RigKind") and 29 or 16), rig.Name .. " has the wrong articulated joint count")
	end
	for _, tree in world.Foliage:GetChildren() do
		local canopy = tree:FindFirstChild("WindCanopy")
		check(canopy ~= nil and canopy.PrimaryPart ~= nil, tree.Name .. " needs a wind pivot")
	end
	for _, item in world.Interactables:GetChildren() do
		check(item:FindFirstChild("Anchor") ~= nil, item.Name .. " is missing its interaction anchor")
		check(item:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, item.Name .. " is missing its prompt")
	end
	local shrines = 0
	for _, item in world.Interactables:GetChildren() do
		local id = item:FindFirstChild("ShrineId")
		if id then check(id:IsA("NumberValue") and id.Value >= 1 and id.Value <= 4, "Invalid shrine ID"); shrines += 1 end
	end
	check(shrines == 4, "Expected four meridian shrines")
	check(game:GetService("ReplicatedStorage").Remotes:FindFirstChild("NpcChoice") ~= nil, "Missing dialogue-choice remote")
	local hud = game:GetService("StarterGui"):FindFirstChild("HeavensunderHUD")
	check(hud ~= nil and hud.Canvas:FindFirstChild("Journal") ~= nil, "Missing journal UI")
	check(hud.Canvas.Hotbar:FindFirstChild("Guard") ~= nil, "Missing guard button")
	check(hud.Canvas:FindFirstChild("Minimap") == nil, "Legacy minimap should be removed")
	check(hud.Canvas:FindFirstChild("Interact") ~= nil, "Missing custom prompt UI")
	check(hud.Canvas.Journal:FindFirstChild("Scroll") ~= nil, "Missing scrolling journal")
	check(hud.Canvas:FindFirstChild("RecallProgress") ~= nil, "Missing recall progress UI")
	local count = 0
	for _, object in world:GetDescendants() do
		if object:IsA("BasePart") then
			count += 1
			check(object.Anchored, "Static scenery is unanchored: " .. object:GetFullName())
		end
	end
	print(string.format("[Heavensunder] %d structural checks passed; %d static scenery parts. This does not test network behavior or rendering.", checks, count))
	return {Checks = checks, SceneryParts = count, RigCount = #rigs}
end
return Diagnostics
