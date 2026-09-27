-- v0.2: explicit dialogue choices, nonce-checked purchases and staged NPC routines.
-- Every transaction is confirmed by the player, validated at the NPC, and consumed once.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local NPC = {}
local records, offers, cooldowns = {}, {}, {}
local notify
local function now() return workspace:GetServerTimeNow() end
local function characterOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return nil end
	return char, hum, root
end
local function near(player, point, range)
	local _, _, root = characterOf(player)
	return root and (root.Position - point).Magnitude <= range
end
local function say(player, title, text)
	notify:FireClient(player, "Dialogue", {Title = title, Text = text})
end
local function elder(player)
	local index = player:GetAttribute("Quest") or 1
	local quest = Config.Quests[index]
	if not quest then say(player, "ELDER YUN · A THREAD RESTORED", "You have silenced the hollow crown. Restore the four meridian shrines, then seek the ninth realm. The next story is yours to write."); return end
	local kills, gather, boss = player:GetAttribute("QuestKills") or 0, player:GetAttribute("QuestGather") or 0, player:GetAttribute("QuestBoss") or 0
	if kills >= quest.Kills and gather >= quest.Gather and (not quest.Boss or boss >= 1) then
		local realm = Config.Realms[player:GetAttribute("Realm") or 1]
		player:SetAttribute("Qi", math.min(realm.Need * 2, (player:GetAttribute("Qi") or 0) + quest.Reward))
		player:SetAttribute("Spirit", (player:GetAttribute("Spirit") or 0) + quest.Spirit)
		player:SetAttribute("Quest", index + 1)
		player:SetAttribute("QuestKills", 0); player:SetAttribute("QuestGather", 0); player:SetAttribute("QuestBoss", 0)
		local nextQuest = Config.Quests[index + 1]
		say(player, "TRIAL COMPLETE · +" .. quest.Reward .. " QI", nextQuest and nextQuest.Text or "The crown is silent. Visit the four shrines and let the broken heavens remember their names.")
	else
		local progress = ""
		if quest.Gather > 0 then progress ..= string.format("\nSpirit lotuses: %d / %d", math.min(gather, quest.Gather), quest.Gather) end
		if quest.Kills > 0 then progress ..= string.format("\nGuardians defeated: %d / %d", math.min(kills, quest.Kills), quest.Kills) end
		if quest.Boss then progress ..= boss > 0 and "\nHollow Lotus: defeated" or "\nHollow Lotus: still waiting" end
		say(player, "ELDER YUN · " .. quest.Title, quest.Text .. progress .. "\nPress J to review your journey.")
	end
end
local function heal(player, record)
	if not near(player, record.Root.Position, 16) then return end
	local char, hum, root = characterOf(player)
	if not char then return end
	if hum.Health >= hum.MaxHealth and (player:GetAttribute("Focus") or 0) >= Config.MaxFocus then
		say(player, record.Model.Name:gsub("_", " "):upper() .. " · NO CHARGE", "Your meridians are already clear. Save those petals for a harder day."); return
	end
	local petals, spirit = player:GetAttribute("Petals") or 0, player:GetAttribute("Spirit") or 0
	if petals < 3 or spirit < 20 then
		say(player, record.Model.Name:gsub("_", " "):upper() .. " · MISSING INGREDIENTS", "A draught needs 3 petals and 20 spirit. Collect glowing lotuses and defeat the outer-island guardians."); return
	end
	-- No yields between checking funds and committing the purchase.
	player:SetAttribute("Petals", petals - 3); player:SetAttribute("Spirit", spirit - 20)
	hum.Health = hum.MaxHealth; player:SetAttribute("Focus", Config.MaxFocus)
	ReplicatedStorage.Remotes.Effect:FireAllClients("Heal", {Position = root.Position})
	say(player, record.Model.Name:gsub("_", " "):upper() .. " · DRAUGHT COMPLETE", "Health and focus restored. 3 petals and 20 spirit spent. Try not to make a habit of catching lightning with your face.")
end
local function valleyTrial(player)
	local stage = player:GetAttribute("ValleyQuest") or 0
	if stage == 0 then
		player:SetAttribute("ValleyQuest", 1)
		say(player, "MEI LAN · A MAP WITHOUT A SKY", "Record the survey seal on Cloudroot Peak, north-west of town, and defeat five silkweavers in the eastern grove. The mountain's winding stone steps lead to its old observatory. Return to me when both are done.")
	elseif stage == 1 and (player:GetAttribute("SilkKills") or 0) >= 5 and player:GetAttribute("MountainSeal") == 1 then
		player:SetAttribute("ValleyQuest", 2)
		local realm = Config.Realms[player:GetAttribute("Realm") or 1]
		player:SetAttribute("Qi", math.min(realm.Need*2, (player:GetAttribute("Qi") or 0) + 160))
		player:SetAttribute("Spirit", (player:GetAttribute("Spirit") or 0) + 85)
		say(player, "THE VALLEY REMEMBERS · +160 QI", "And 85 spirit for the road. Our map has its mountain back. The Silk Matriarch still guards the far grove, but that fight is now your choice.")
	else
		say(player, "MEI LAN · FIELD NOTES", stage == 2 and "Your survey is complete. Lanternwake will remember the pilgrim who gave us back the horizon." or string.format("Silkweavers: %d / 5\nCloudroot seal: %s\nThere is no rush. Use the journal to keep your bearings.", math.min(player:GetAttribute("SilkKills") or 0, 5), player:GetAttribute("MountainSeal") == 1 and "recorded" or "undiscovered"))
	end
end
local function openDialogue(player, record)
	local role = record.Role
	local token = HttpService:GenerateGUID(false)
	local allowed, title, text, options
	if role == "Cartographer" then
		allowed = {Valley = true, Lore = true, Lesson = true}
		title = "MEI LAN · CARTOGRAPHER OF LANTERNWAKE"
		text = "We kept drawing maps after the sky broke. Somebody had to remember where the roads went. Will you help with the blank places?"
		options = {{Id = "Valley", Label = "THE VALLEY COMMISSION"}, {Id = "Lore", Label = "WHY LANTERNWAKE?"}}
	elseif role == "Herbalist" then
		allowed = {Heal = true, Lore = true, Lesson = true}
		title = "TAO · REEDWATER APOTHECARY"
		text = "Spider silk makes a fine bandage. Less fine while it is still attached to the spider. A restorative draught costs 3 petals and 20 spirit."
		options = {{Id = "Heal", Label = "BUY · 3 PETALS + 20 SPIRIT"}, {Id = "Lore", Label = "THE SILKWOOD"}}
	elseif role == "Elder" then
		allowed = {Trial = true, Lore = true, Lesson = true}
		title = "ELDER YUN · KEEPER OF DAWN"
		text = "The sky did not break in a single day. Nor will you mend it in one breath. What brings you back to the tree?"
		options = {{Id = "Trial", Label = "REVIEW / CLAIM TRIAL"}, {Id = "Lore", Label = "THE FOUR MERIDIANS"}}
	elseif role == "Alchemist" then
		allowed = {Heal = true, Lore = true, Lesson = true}
		title = "LIORA · ALCHEMIST"
		text = "A restorative draught costs 3 petals and 20 spirit. It restores both health and focus. Shall I prepare one?"
		options = {{Id = "Heal", Label = "BUY · 3 PETALS + 20 SPIRIT"}, {Id = "Lore", Label = "ASK ABOUT CULTIVATION"}}
	else
		allowed = {Route = true, Lore = true, Lesson = true}
		title = "SHEN · SKY FERRYMAN"
		text = "I used to charge by the crossing. Then the boats fell through the clouds. Now I charge for advice. Fortunately, today it is free."
		options = {{Id = "Route", Label = "WHICH ISLAND NEXT?"}, {Id = "Lore", Label = "HOW TO SURVIVE THE CROWN"}}
	end
	table.insert(options, {Id = "Lesson", Label = role == "Cartographer" and "FIND CLOUDROOT" or role == "Herbalist" and "WEBBED?" or role == "Elder" and "TRAINING LESSON" or role == "Alchemist" and "CULTIVATE TOGETHER" or "HOMEWARD RECALL"})
	offers[player] = {Token = token, Record = record, Until = now() + 25, Allowed = allowed}
	notify:FireClient(player, "Dialogue", {Title = title, Text = text, Token = token, Options = options})
end
function NPC.Start(event)
	notify = event
	ReplicatedStorage.Remotes.NpcChoice.OnServerEvent:Connect(function(player, token, choice)
		if typeof(token) ~= "string" or typeof(choice) ~= "string" or #token > 80 or #choice > 20 then return end
		local offer = offers[player]
		if not offer or offer.Token ~= token or now() > offer.Until or not offer.Allowed[choice] then return end
		if not player:GetAttribute("ProfileLoaded") or not near(player, offer.Record.Root.Position, 16) then return end
		offers[player] = nil -- consume before processing: repeated clicks cannot double-charge
		local role = offer.Record.Role
		if choice == "Valley" then valleyTrial(player)
		elseif choice == "Lesson" then
			if role == "Cartographer" then
				say(player, "MEI LAN · THE HIGH TRAIL", "Take the southern stair out of town, then travel north-west to the tall peak. Follow its winding stone steps to the survey ring. The eastern grove holds the silkweavers; your journal records both objectives.")
			elseif role == "Herbalist" then
				say(player, "TAO · CUT THE THREAD", "A silk snare slows you for just over two seconds. Do not panic: guard and your other techniques still work. The warning freezes before impact, so leave the circle before the silk lands.")
			elseif role == "Elder" then
				local trained = (player:GetAttribute("TrainingHits") or 0) > 0
				say(player, "YUN · THE PATIENT WOOD", trained and "Your strikes are finding their rhythm. Face a practice post, wait for its countdown, then press G just before it ends. Training parries grant no battle rewards. The southern altars let you choose Tiger, Crane or Tortoise." or "The three wooden posts east of the tree offer thirty-second lessons. Press E at one, then strike it. Watch your hits and damage per second. A gold warning lets you safely practice your guard; the post never harms you.")
			elseif role == "Alchemist" then
				say(player, "LIORA · SHARED BREATH", "Meditate within eighteen studs of another cultivator for ten percent extra Qi per companion, capped at thirty percent. The tree and bell bonuses still apply. The Cloud Crane altar also improves focus recovery by a quarter.")
			else
				say(player, "SHEN · THE HOMEWARD THREAD", "Press K or the RECALL button after eight seconds out of combat. Stand still on solid ground for four seconds; the seal returns you to Dawnreach. Moving, attacking or taking damage interrupts it. A successful recall has a twenty-five-second cooldown.")
			end
		elseif choice == "Trial" then elder(player)
		elseif choice == "Heal" then heal(player, offer.Record)
		elseif choice == "Route" then
			local realm = player:GetAttribute("Realm") or 1
			say(player, "SHEN · YOUR NEXT CROSSING", realm < 3 and "Start at Verdant Fang. Learn the wardens' windups and practice G to parry. Reach Jade Foundation before trying the crown." or "Frostveil's exiles strike where you were standing. Keep moving. For the Hollow Lotus, go through the pink gate and stay alert for its hollow ring.")
		elseif role == "Cartographer" then
			say(player, "MEI LAN · LANTERNWAKE", "When the heavens rose, the first survivors lit lanterns so the people above would know there was still somebody below. We have kept them burning ever since. Take the southern stair to the meadow; Cloudroot Peak stands north-west.")
		elseif role == "Herbalist" then
			say(player, "TAO · THE SILKWOOD", "The eastern grove belongs to the jade silkweavers. Their gold warning circles lock onto where you were standing. Keep moving when they spit; a snare slows you briefly. The great pink-eyed one is their matriarch.")
		elseif role == "Elder" then
			say(player, "ELDER YUN · MERIDIANS OF THE SKY", "Four shrines hold the islands together: Root, Stillwater, Starlight and Hollow. Attune each once for Qi and spirit. Restore all four for a completion reward. Your journal remembers.")
		elseif role == "Alchemist" then
			say(player, "LIORA · A PRACTICAL LESSON", "F cultivates Qi and restores health. The great tree increases Qi yield; the Dawn Bell adds a blessing. Focus restores by itself, faster at higher realms. B opens the next realm when your Qi is ready.")
		else
			say(player, "SHEN · THE HOLLOW RING", "The sovereign's wide ring leaves a safe center, marked in jade. Its storm circles do not. At low health, storm strikes echo once: do not return to the same spot too soon.")
		end
	end)
	for _, model in workspace.Actors.NPCs:GetChildren() do
		local role, root, hum = model:FindFirstChild("Role"), model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid")
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not role or not root or not hum then continue end
		local record = {Model = model, Root = root, Humanoid = hum, Role = role.Value, Home = root.CFrame, TalkingUntil = 0, Step = 0}
		table.insert(records, record)
		hum.MaxHealth = 100000; hum.Health = 100000; hum.WalkSpeed = 5; hum.BreakJointsOnDeath = false
		pcall(function() root:SetNetworkOwner(nil) end)
		model:SetAttribute("NPC", true); model:SetAttribute("Action", role.Value == "Alchemist" and "Alchemy" or "Idle")
		if prompt then prompt.Triggered:Connect(function(player)
			if not player:GetAttribute("ProfileLoaded") or not near(player, root.Position, 16) then return end
			if (cooldowns[player] or 0) > now() then return end
			cooldowns[player] = now() + 1
			record.TalkingUntil = now() + 25
			hum:MoveTo(root.Position)
			model:SetAttribute("Action", "Talk")
			local _, _, playerRoot = characterOf(player)
			if playerRoot then
				local point = Vector3.new(playerRoot.Position.X, root.Position.Y, playerRoot.Position.Z)
				if (point - root.Position).Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, point) end
			end
			openDialogue(player, record)
		end) end
	end
	Players.PlayerRemoving:Connect(function(player) offers[player] = nil; cooldowns[player] = nil end)
	task.spawn(function()
		while true do
			task.wait(4)
			for player, offer in offers do if now() > offer.Until then offers[player] = nil end end
			for _, record in records do
				if not record.Model.Parent then continue end
				if record.Root.Position.Y < record.Home.Position.Y - 20 then record.Model:PivotTo(record.Home) end
				if now() < record.TalkingUntil then continue end
				record.Step = record.Step % 6 + 1
				if record.Role == "Alchemist" or record.Role == "Herbalist" then
					record.Model:SetAttribute("Action", record.Step <= 4 and "Alchemy" or "Attune")
					record.Model:SetAttribute("ActionAt", now()); record.Model:SetAttribute("ActionUntil", 0)
				elseif record.Role == "Elder" then
					record.Model:SetAttribute("Action", record.Step <= 4 and "Meditate" or "Idle")
				else
					local stops = {Vector3.new(-4, 0, 1), Vector3.zero, Vector3.new(4, 0, -2)}
					if record.Step % 2 == 1 then
						record.Model:SetAttribute("Action", "Idle")
						record.Humanoid:MoveTo(record.Home.Position + stops[math.ceil(record.Step / 2)])
					else record.Model:SetAttribute("Action", "Talk") end
				end
			end
		end
	end)
end
return NPC
