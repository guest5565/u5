--!nonstrict
-- INKWING :: server (data, combat, enemies, boss, quests, saving)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local Combat = Instance.new("RemoteEvent")
Combat.Name = "Combat"
Combat.Parent = Remotes
local Fx = Instance.new("RemoteEvent")
Fx.Name = "Fx"
Fx.Parent = Remotes
local makeRemains
local feast
local Fn = Instance.new("RemoteFunction")
Fn.Name = "Fn"
Fn.Parent = Remotes
local AdminFn = Instance.new("RemoteFunction")
AdminFn.Name = "Admin"
AdminFn.Parent = Remotes
local TravelEv = Instance.new("RemoteEvent")
TravelEv.Name = "Travel"
TravelEv.Parent = Remotes
Remotes.Parent = ReplicatedStorage

local EnemyFolder = Instance.new("Folder")
EnemyFolder.Name = "Enemies"
EnemyFolder.Parent = workspace

local store
pcall(function()
	store = DataStoreService:GetDataStore("InkwingV1")
end)
local rng = Random.new()
local data = {} -- player -> data
local Hooks = {} -- v1.6 system hooks (filled at the end of this file)
local S = {} -- player -> session state { lock, nextShot, cds = {}, shieldUntil }

local function newData()
	return { level = 1, xp = 0, ink = 0, feathers = 0, wings = { Paper = 1 }, wing = "Paper", quest = 1, qprog = 0, bossKills = 0, found = { ["SKY ISLES"] = true }, rank = 1, evo = 0, mana = 1, manaMax = 1, capBonus = 0, essence = {}, aspPts = {}, aspect = "", skills = {}, sxp = {}, hasWings = false, train = 1, tprog = 0, tactive = false, chests = {}, plumes = {}, equip = {}, shrines = {} }
end

---------------------------------------------------------------------------
-- SYNC / SAVE
---------------------------------------------------------------------------
-- v1.0 ASCENSION helpers
local function hasSkill(d, id)
	return table.find(d.skills, id) ~= nil
end
local function spFree(d)
	local used = 0
	for _, id in ipairs(d.skills) do
		local sk = G.SkillById[id]
		used += sk and sk.sp or 0
	end
	return math.max(0, d.level - 1 + (d.bossKills or 0) - used)
end
-- a skill evolves when its use counter reaches evo.need
local function prof(d, id) -- v1.9 efficiency 0..1
	local sk = G.SkillById[id]
	if not sk then
		return 0
	end
	local _, eff = G.Proficiency(id, d.sxp[id], sk.evo and hasSkill(d, sk.evo.id))
	return eff
end
local function skillUse(p, id, n)
	local d = data[p]
	local sk = G.SkillById[id]
	if not d or not sk or not hasSkill(d, id) or (sk.evo and hasSkill(d, sk.evo.id)) then
		return
	end
	d.sxp[id] = math.min(G.ProfNeed(sk), (d.sxp[id] or 0) + n)
	if sk.evo and d.sxp[id] >= sk.evo.need then
		table.insert(d.skills, sk.evo.id)
		Fx:FireAllClients("Evolve", { player = p, rank = sk.evo.rank })
		Fx:FireAllClients("Announce", { text = p.DisplayName .. ": " .. sk.name .. " EVOLVED INTO " .. sk.evo.name .. "  [RANK " .. G.RANKS[sk.evo.rank] .. "]", color = G.RANK_COLORS[sk.evo.rank] })
	end
	p:SetAttribute("SkillXP", HttpService:JSONEncode(d.sxp))
end
local sync
-- v1.1 skills are not bought: each is AWAKENED by a deed
local function awaken(p, id, why)
	local d = data[p]
	local sk = G.SkillById[id]
	if not d or not sk or hasSkill(d, id) then
		return
	end
	table.insert(d.skills, id)
	Fx:FireAllClients("Evolve", { player = p, rank = sk.rank })
	Fx:FireClient(p, "SkillAwaken", { id = id, name = sk.name, rank = sk.rank, why = why })
	sync(p)
end
-- TRAINING (Master Orren)
local questCheck -- defined below
local function trainSync(p)
	local d = data[p]
	if not d then
		return
	end
	while G.Training[d.train] and hasSkill(d, G.Training[d.train].skill) do -- already know it (old saves / admin)
		d.train += 1
		d.tactive, d.tprog = false, 0
	end
	local T = G.Training[d.train]
	if not T or not d.tactive then
		p:SetAttribute("TrainText", T and "TRAINING: TALK TO MASTER ORREN" or "")
	elseif d.tprog >= T.n then
		p:SetAttribute("TrainText", "TRAINING DONE - RETURN TO MASTER ORREN")
	else
		p:SetAttribute("TrainText", ("TRAINING: %s  (%d/%d)"):format(T.text, math.floor(d.tprog), T.n))
	end
end
local function trainProg(p, kind, n, set)
	local d = data[p]
	local T = d and G.Training[d.train]
	if not T or not d.tactive or T.kind ~= kind or d.tprog >= T.n then
		return
	end
	d.tprog = set and n or (d.tprog + n)
	if d.tprog >= T.n then
		d.tprog = T.n
		Fx:FireClient(p, "Toast", { text = "TRAINING COMPLETE - RETURN TO MASTER ORREN", color = Color3.fromRGB(255, 230, 140) })
	end
	trainSync(p)
end
local function mentorTalk(p)
	local d = data[p]
	if not d then
		return
	end
	trainSync(p)
	local T = G.Training[d.train]
	local said = {}
	local function say(t) -- v1.10: spoken in the dialogue window
		table.insert(said, t)
	end
	if not T then
		say("I have taught you everything. The sky is yours now.")
	elseif not d.tactive then
		d.tactive, d.tprog = true, 0
		say(T.say)
	elseif d.tprog >= T.n then
		d.tactive, d.tprog = false, 0
		d.train += 1
		awaken(p, T.skill, "MASTER ORREN TEACHES YOU")
		questCheck(p, "train")
		local nx = G.Training[d.train]
		if nx then
			task.delay(4.5, function()
				-- (v1.10: the dialogue window offers the next lesson)
			end)
		end
	else
		say(("Not yet. %s  (%d/%d)"):format(T.text:lower():gsub("^%l", string.upper), math.floor(d.tprog), T.n))
	end
	trainSync(p)
	return said
end
task.spawn(function()
	if G.REALM ~= "Overworld" then
		return
	end
	local w = workspace:WaitForChild("World", 30)
	local gate = w and w:WaitForChild("Gate", 30)
	local m = gate and gate:WaitForChild("Mentor", 30)
	local anchor = m and m:WaitForChild("MentorAnchor", 30)
	if not anchor then
		return
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "TalkPrompt"
	pr.ActionText = "Talk"
	pr.ObjectText = "Master Orren"
	pr.HoldDuration = 0.5
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Npc", "mentor")
	pr.Parent = anchor
end)
-- v1.8d MANA CORE helpers ------------------------------------------------------------
local function coreCap(d)
	local b = (d.capBonus or 0) + (table.find(d.skills or {}, "zen") and 0.1 or 0)
	return G.CoreCap(d.rank, b)
end
local function breakHostile(pos)
	return G.REALM ~= "Overworld" or pos.Y > G.STORM_BASE - 300 or pos.Y < G.SEA_SHOW
end
local function breakFail(p, st, d)
	st.brk = nil
	st.brkCd = os.clock() + 30
	d.mana = math.floor(d.mana * 0.75)
	p:SetAttribute("Mana", math.floor(d.mana))
	p:SetAttribute("Breakthrough", nil)
	Fx:FireClient(p, "Toast", { text = "BREAKTHROUGH FAILED - YOUR CORE SETTLES. TRY AGAIN SOON.", color = Color3.fromRGB(255, 120, 120) })
	Fx:FireAllClients("BreakEnd", { player = p, ok = false })
end
-- called every second while meditating; returns true when a breakthrough completes (caller does the rank-up)
local function breakthroughTick(p, st, d, hrp)
	if d.rank >= 5 or not hrp then
		return false
	end
	if not st.brk then
		if d.manaMax < coreCap(d) or os.clock() < (st.brkCd or 0) then
			return false
		end
		if d.evo < G.EVO_ESSENCE[d.rank] then
			if os.clock() > (st.capNag or 0) then
				st.capNag = os.clock() + 20
				Fx:FireClient(p, "Toast", { text = ("YOUR CORE IS AT ITS LIMIT - ABSORB MORE ESSENCE (%d / %d)"):format(d.evo, G.EVO_ESSENCE[d.rank]), color = Color3.fromRGB(200, 170, 255) })
			end
			return false
		end
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		st.brk = { t = 0, hostile = breakHostile(hrp.Position), minHp = 1, hum = hum }
		Fx:FireClient(p, "Toast", { text = "BREAKTHROUGH! KEEP MEDITATING" .. (st.brk.hostile and " - SURVIVE THE SURGE" or ""), color = Color3.fromRGB(255, 230, 140) })
		Fx:FireAllClients("BreakStart", { player = p })
	end
	local b = st.brk
	if b.hum then
		b.minHp = math.min(b.minHp, b.hum.Health / math.max(1, b.hum.MaxHealth))
	end
	local guards = 0
	for _, o in ipairs(Players:GetPlayers()) do
		local oh = o ~= p and o.Character and o.Character:FindFirstChild("HumanoidRootPart")
		if oh and (oh.Position - hrp.Position).Magnitude < 35 then
			guards += 1
		end
	end
	b.t += 1 + 0.25 * math.min(guards, 4) -- friends steady your core
	p:SetAttribute("Breakthrough", math.clamp(b.t / G.BREAK_TIME, 0, 1))
	if b.t < G.BREAK_TIME then
		return false
	end
	local grade = (b.minHp < 0.5) and "Rough" or ((b.hostile and b.minHp >= 0.3) and "Perfect" or "Clean")
	d.capBonus = (d.capBonus or 0) + G.BREAK_BONUS[grade]
	st.lastGrade = grade
	st.brk = nil
	p:SetAttribute("Breakthrough", nil)
	Fx:FireAllClients("BreakEnd", { player = p, ok = true, grade = grade })
	return true
end
local function hpMult(d)
	return G.RANK_POWER[d.rank] ^ 0.7 * (d.aspect == "Ink" and 1.1 or 1)
end
local function maxHP(d)
	return math.floor(G.MaxHP(d.level) * hpMult(d))
end
sync = function(p)
	local d = data[p]
	if not d then
		return
	end
	p:SetAttribute("Level", d.level)
	p:SetAttribute("Blessed", d.blessed == true)
	local fl = {}
	for k in pairs(d.found or {}) do
		table.insert(fl, k)
	end
	p:SetAttribute("Found", table.concat(fl, ","))
	p:SetAttribute("Realm", G.REALM)
	p:SetAttribute("XP", d.xp)
	p:SetAttribute("XPNeed", G.XPNeed(d.level))
	p:SetAttribute("Ink", math.floor(d.ink))
	p:SetAttribute("Feathers", d.feathers)
	p:SetAttribute("Wing", d.wing)
	p:SetAttribute("WingTier", d.wings[d.wing] or 1)
	p:SetAttribute("WingsOwned", HttpService:JSONEncode(d.wings))
	p:SetAttribute("Quest", d.quest)
	p:SetAttribute("WingRank", d.rank)
	p:SetAttribute("Evo", d.evo)
	p:SetAttribute("Mana", math.floor(d.mana))
	p:SetAttribute("ManaMax", math.floor(d.manaMax))
	p:SetAttribute("CoreCap", coreCap(d))
	p:SetAttribute("Aspect", d.aspect)
	p:SetAttribute("Skills", table.concat(d.skills, ","))
	p:SetAttribute("HasWings", d.hasWings ~= false)
	p:SetAttribute("SkillXP", HttpService:JSONEncode(d.sxp))
	local cl = {}
	for k in pairs(d.chests or {}) do
		table.insert(cl, tostring(k))
	end
	p:SetAttribute("Chests", table.concat(cl, ","))
	p:SetAttribute("Plumes", HttpService:JSONEncode(d.plumes or {}))
	p:SetAttribute("Equip", table.concat(d.equip or {}, ","))
	trainSync(p)
	p:SetAttribute("Essence", HttpService:JSONEncode(d.essence))
	p:SetAttribute("QuestProg", d.qprog)
	local ls = p:FindFirstChild("leaderstats")
	if ls then
		ls.Core.Value = G.RANKS[d.rank] .. "-Rank"
	end
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local mx = maxHP(d)
		if hum.MaxHealth ~= mx then
			local frac = hum.Health / math.max(1, hum.MaxHealth)
			hum.MaxHealth = mx
			hum.Health = mx * frac
		end
	end
end
local function save(p)
	local d = data[p]
	if not d or not store or d.loadFailed then
		return
	end
	local blob = { level = d.level, xp = d.xp, ink = d.ink, feathers = d.feathers, wings = d.wings, wing = d.wing, quest = d.quest, qprog = d.qprog, bossKills = d.bossKills, blessed = d.blessed == true, found = d.found, rank = d.rank, evo = d.evo, mana = d.mana, manaMax = d.manaMax, capBonus = d.capBonus, essence = d.essence, aspPts = d.aspPts, aspect = d.aspect, skills = d.skills, sxp = d.sxp, hasWings = d.hasWings, train = d.train, tprog = d.tprog, tactive = d.tactive, chests = d.chests, plumes = d.plumes, equip = d.equip, shrines = d.shrines, V = 1 }
	pcall(function()
		store:SetAsync("p" .. p.UserId, blob)
	end)
end

local function toast(p, text, color)
	Fx:FireClient(p, "Toast", { text = text, color = color })
end

---------------------------------------------------------------------------
-- PROGRESSION
---------------------------------------------------------------------------
questCheck = function(p, kind, arg)
	local d = data[p]
	local q = d and G.Quests[d.quest]
	if not q then
		return
	end
	if q.kind == "kill" and kind == "kill" and arg == q.target then
		d.qprog += 1
	elseif q.kind == "skill" then
		d.qprog = (table.find(d.skills, "absorb") and 1 or 0) + (table.find(d.skills, "meditate") and 1 or 0)
	elseif q.kind == "absorb" and kind == "absorb" then
		d.qprog += arg or 1
	elseif q.kind == "train" then
		d.qprog = (d.train or 1) - 1
	elseif q.kind == "rank" then
		d.qprog = d.rank
	elseif q.kind == "tier" then
		local best = 0
		for _, t in pairs(d.wings) do
			best = math.max(best, t)
		end
		d.qprog = best
	end
	if d.qprog >= q.n then
		d.ink += q.ink
		d.feathers += q.feathers
		d.quest += 1
		d.qprog = 0
		if not d.hasWings and d.quest >= 2 then
			d.hasWings = true
			Fx:FireAllClients("Evolve", { player = p, rank = 2 })
			Fx:FireClient(p, "WingsAwaken", {})
		end
		Fx:FireClient(p, "QuestDone", { text = q.text, ink = q.ink, feathers = q.feathers })
		-- the next quest may already be complete (e.g. tier)
		task.defer(questCheck, p, "check")
	end
	sync(p)
end
local function addXP(p, n)
	local d = data[p]
	d.xp += n
	local leveled = false
	while d.level < G.MAX_LEVEL and d.xp >= G.XPNeed(d.level) do
		d.xp -= G.XPNeed(d.level)
		d.level += 1
		leveled = true
	end
	if leveled then
		Fx:FireAllClients("LevelUp", { player = p, level = d.level })
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		sync(p)
		if hum then
			hum.Health = hum.MaxHealth
		end
	end
end

-- v1.4 WORLD LIFE: treasure chests (once per player, saved) + glowing apples (heal + XP, respawn)
task.spawn(function()
	if G.REALM ~= "Overworld" then
		return
	end
	local w = workspace:WaitForChild("World", 30)
	local gate = w and w:WaitForChild("Gate", 30)
	local life = gate and gate:WaitForChild("Life", 30)
	if not life then
		return
	end
	local function prompt(part, action, obj, dist)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = action
		pr.ObjectText = obj
		pr.HoldDuration = 0
		pr.MaxActivationDistance = dist or 10
		pr.RequiresLineOfSight = false
		pr.Parent = part
		return pr
	end
	for _, d0 in ipairs(life:GetDescendants()) do
		if d0:IsA("BasePart") and d0:GetAttribute("ChestId") then
			local id = tostring(d0:GetAttribute("ChestId"))
			local tier = d0:GetAttribute("Tier") or 1
			prompt(d0, "Open", tier >= 2 and "Ancient Chest" or "Treasure Chest", 12).Triggered:Connect(function(p)
				local d = data[p]
				if not d or d.chests[id] then
					return
				end
				d.chests[id] = true
				local ink, fe, xp = 150 * tier * tier, 2 * tier, 40 * tier
				d.ink += ink
				d.feathers += fe
				local ess = G.ESSENCES.Ink and "Ink" or nil
				if ess then
					d.essence[ess] = (d.essence[ess] or 0) + 3 * tier
				end
				addXP(p, xp)
				local n = 0
				for _ in pairs(d.chests) do
					n += 1
				end
				Fx:FireAllClients("ChestOpen", { player = p, pos = d0.Position, tier = tier })
				if tier >= 2 and Hooks.givePlume then
					Hooks.givePlume(p, nil, "ANCIENT CHEST")
				end
				Fx:FireClient(p, "Toast", { text = ("TREASURE! +%d INK  +%d FEATHERS  +%d XP   (CHESTS %d/%d)"):format(ink, fe, xp, n, G.N_CHESTS), color = Color3.fromRGB(255, 215, 90) })
				sync(p)
			end)
		elseif d0:IsA("BasePart") and d0:GetAttribute("Apple") then
			local pr = prompt(d0, "Eat", "Sky Apple", 12)
			pr.Triggered:Connect(function(p)
				if d0.Transparency > 0.5 then
					return
				end
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.35)
				addXP(p, 6)
				Fx:FireAllClients("AppleEat", { pos = d0.Position })
				d0.Transparency, pr.Enabled = 1, false
				task.delay(75, function()
					d0.Transparency, pr.Enabled = 0.05, true
				end)
			end)
		end
	end
end)

---------------------------------------------------------------------------
-- ENEMIES
---------------------------------------------------------------------------
local enemies = {} -- part -> state
local spawnCount = {}
local bossParts = {} -- boss index -> part
local spawnBoss

-- v0.9b AGGRESSION RULES: peaceful (Heaven) = only after you hit them; strongLv (Cosmos) = only strong players
local function allowed(st, p, now)
	if Hooks.ignore and Hooks.ignore(st, p, now) then
		return false -- v1.6 Moth Plume
	end
	local h = st.hostile and st.hostile[p]
	if h and h > now then
		return true
	end
	if st.def.peaceful then
		return false
	end
	if st.def.strongLv then
		local d = data[p]
		return d ~= nil and d.level >= st.def.strongLv
	end
	return true
end
local function liveChars()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			out[#out + 1] = { p = p, hrp = hrp, hum = hum }
		end
	end
	return out
end

local function hurtPlayer(p, hum, dmg)
	if S[p] and S[p].god then
		return
	end
	local st = S[p]
	if st and st.meditating and not (data[p] and hasSkill(data[p], "zen")) then
		st.meditating = nil
		p:SetAttribute("Meditating", false)
		Fx:FireClient(p, "Toast", { text = "MEDITATION BROKEN", color = Color3.fromRGB(255, 90, 90) })
	end
	if st and st.iframeUntil and os.clock() < st.iframeUntil then
		return -- dodged!
	end
	if st and st.shieldUntil and os.clock() < st.shieldUntil then
		dmg *= 0.4
	end
	hum:TakeDamage(dmg)
	Fx:FireClient(p, "Hurt", { dmg = math.floor(dmg) })
end
 -- v1.6: filled by the systems block at the end of the file
local function spawnEnemy(kind, pos, spawnIdx, opts)
	local def = G.Enemies[kind]
	opts = opts or {}
	local part = Instance.new("Part")
	part.Name = "Enemy"
	part.Size = Vector3.one * (def.size or 4)
	part.Transparency = 1
	part.Anchored, part.CanCollide, part.CanTouch = true, false, false
	part.CanQuery = false
	part.CFrame = CFrame.new(pos)
	part:SetAttribute("Type", kind)
	-- spawn level scaling: the same monster is far stronger up in the storm / down in the depths
	local sp = spawnIdx and G.Spawns[spawnIdx]
	local lvl = (opts.level or (sp and sp.level)) or def.level
	local k = math.max(0, lvl - def.level)
	local maxhp = math.floor(def.hp * (1 + k * 0.3))
	part:SetAttribute("HP", maxhp)
	part:SetAttribute("MaxHP", maxhp)
	part:SetAttribute("Level", lvl)
	if def.neutral then
		part:SetAttribute("Neutral", true)
	end
	if def.peaceful then
		part:SetAttribute("Peaceful", true) -- v0.9b: Heaven's beings ignore you until you strike
	end
	if def.strongLv then
		part:SetAttribute("StrongLv", def.strongLv) -- v0.9b: Cosmos beings only hunt the strong
	end
	part.Parent = EnemyFolder
	enemies[part] = { kind = kind, def = def, hp = maxhp, maxhp = maxhp, lvl = lvl, dmg = math.max(def.dmg, G.MaxHP(lvl) * (def.boss and 0.24 or 0.13) * (0.4 + math.min(lvl, 50) / 50 * 0.6) * (def.ranged and 0.85 or 1)) * (1 + k * 0.12), xp = math.floor(def.xp * (1 + k * 0.3)), ink = math.floor(def.ink * (1 + k * 0.25)),
		aggro = def.aggro * 1.6 + (k > 0 and 25 or 0), speed = def.speed * (1 + math.min(k, 20) * 0.02), home = pos, spawnIdx = spawnIdx, giantIdx = opts.giantIdx, hostile = {}, lastAtk = os.clock(), dmgBy = {}, fly = opts.fly or def.fly, phase = 1, born = os.clock(), bossIdx = opts.bossIdx }
	if spawnIdx then
		spawnCount[spawnIdx] = (spawnCount[spawnIdx] or 0) + 1
	end
	if Hooks.spawn then
		Hooks.spawn(part, enemies[part], opts)
	end
	return part
end

-- v1.0 REMAINS: the fallen stay where they fell (2 min) until someone ABSORBS them
local RemainsF = Instance.new("Folder")
RemainsF.Name = "Remains"
RemainsF.Parent = workspace
makeRemains = function(kind, def, pos)
	local ess = G.EssenceOf[kind]
	if not ess then
		return
	end
	local big = def.giant or def.boss
	local r = Instance.new("Part")
	r.Name = "Remains"
	r.Shape = Enum.PartType.Ball
	r.Anchored, r.CanCollide, r.CanTouch, r.CastShadow = true, false, false, false
	r.CanQuery = false
	local sz = math.clamp((def.size or 4) * 0.25, 3, big and 40 or 10)
	r.Size = Vector3.one * sz
	r.Color = Color3.fromRGB(14, 12, 22)
	r.Material = Enum.Material.SmoothPlastic
	r.Transparency = 0.15
	r.CFrame = CFrame.new(pos)
	r:SetAttribute("Essence", ess)
	r:SetAttribute("Amount", G.EssenceAmount(def))
	r:SetAttribute("Of", def.name)
	r:SetAttribute("Big", big == true)
	r.Parent = RemainsF
	task.delay(big and 300 or 120, function()
		if r.Parent then
			r:Destroy()
		end
	end)
end
local function killEnemy(part)
	local st = enemies[part]
	if not st then
		return
	end
	enemies[part] = nil
	if st.spawnIdx then
		spawnCount[st.spawnIdx] -= 1
	end
	local def = st.def
	Fx:FireAllClients("Die", { pos = part.Position, kind = st.kind, boss = def.boss })
	makeRemains(st.kind, def, part.Position)
	for p, dmg in pairs(st.dmgBy) do
		local d = data[p]
		if d and p.Parent and dmg > 0 then
			d.ink += st.ink
			local fe = 0
			if rng:NextNumber() < def.feather then
				fe = def.featherN or 1
			end
			d.feathers += fe
			if st.rare then
				fe = (fe or 0) + 3 -- golden monsters always drop feathers
			end
			addXP(p, st.xp)
			Fx:FireClient(p, "Loot", { pos = part.Position, ink = st.ink, xp = st.xp, feathers = fe })
			if st.kind == "HaloWarden" and not d.blessed then
				d.blessed = true
			for _, z in ipairs(G.ZONES) do
				d.found[z.name] = true
			end
				Fx:FireClient(p, "Announce", { text = "YOU ARE BLESSED: THE GIANT ANGELS NOW FIGHT BESIDE YOU", color = Color3.fromRGB(255, 220, 120) })
			end
			if def.boss then
				d.bossKills += 1
				local bd = st.bossIdx and G.Bosses[st.bossIdx]
				if bd and bd.wing and not d.wings[bd.wing] then
					d.wings[bd.wing] = 1
					Fx:FireClient(p, "NewWing", { wing = bd.wing })
				end
			end
			questCheck(p, "kill", st.kind)
			trainProg(p, "kill", 1)
			sync(p)
		end
	end
	if st.giantIdx then
		local gi = st.giantIdx
		Fx:FireAllClients("Announce", { text = def.name .. " HAS FALLEN FROM HEAVEN!", color = Color3.fromRGB(255, 200, 60) })
		task.delay(G.Giants[gi].respawn, function()
			spawnEnemy(G.Giants[gi].kind, G.Giants[gi].pos, nil, { giantIdx = gi })
		end)
	end
	if def.boss and st.bossIdx then
		local idx = st.bossIdx
		local bd = G.Bosses[idx]
		bossParts[idx] = nil
		Fx:FireAllClients("Announce", { text = def.name .. " HAS FALLEN!", color = Color3.fromRGB(255, 200, 60) })
		workspace:SetAttribute("BossAt_" .. bd.kind, os.time() + bd.respawn)
		task.delay(bd.respawn, function()
			if not bossParts[idx] then
				spawnBoss(idx)
			end
		end)
	end
	part:Destroy()
end

local function damageEnemy(part, amount, p, crit)
	local st = enemies[part]
	if not st then
		return
	end
	local pd = p and data[p]
	if pd and pd.aspect == "Void" and (st.def.giant or st.def.boss) then
		amount *= 1.2
	end
	if Hooks.taken then
		amount = Hooks.taken(part, st, p, amount)
	end
	amount = math.floor(amount)
	if pd and pd.aspect == "Holy" then
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + amount * 0.03)
		end
	end
	st.hp -= amount
	st.dmgBy[p] = (st.dmgBy[p] or 0) + amount
	if st.def.giant then
		if not (st.hostile[p] and st.hostile[p] > os.clock()) then
			Fx:FireClient(p, "Announce", { text = st.def.name .. " TURNS ITS EYES ON YOU", color = Color3.fromRGB(255, 80, 80) })
		end
		st.hostile[p] = os.clock() + 60
		Fx:FireClient(p, "Hostile", { parts = { part }, t = 60 })
	elseif st.def.peaceful or st.def.strongLv then
		-- provoked: this one and its flock turn on you
		local now = os.clock()
		local list = { part }
		st.hostile[p] = now + 45
		for other, os2 in pairs(enemies) do
			if other ~= part and (os2.def.peaceful or os2.def.strongLv) and (other.Position - part.Position).Magnitude < 110 then
				os2.hostile[p] = now + 45
				table.insert(list, other)
			end
		end
		st.target = p
		Fx:FireClient(p, "Hostile", { parts = list, t = 45 })
	end
	if not st.target then
		st.target = p
		for other, os2 in pairs(enemies) do
			if other ~= part and not os2.target and not os2.def.boss and not os2.def.giant and (other.Position - part.Position).Magnitude < 70 then
				os2.target = p
			end
		end
	end
	part:SetAttribute("HP", math.max(0, st.hp))
	Fx:FireAllClients("Hit", { part = part, dmg = amount, crit = crit, by = p })
	if st.hp <= 0 then
		if Hooks.death then
			Hooks.death(part, st, p)
		end
		killEnemy(part)
	elseif Hooks.hit then
		Hooks.hit(part, st, p, amount)
	end
end

-- telegraphed attack: warn circle at pos, then hit everyone still inside
local function telegraph(pos, radius, t, dmg)
	Fx:FireAllClients("Warn", { pos = pos, r = radius, t = t })
	task.delay(t, function()
		Fx:FireAllClients("Blast", { pos = pos, r = radius })
		for _, c in ipairs(liveChars()) do
			if (c.hrp.Position - pos).Magnitude < radius + 1.5 then
				hurtPlayer(c.p, c.hum, dmg)
			end
		end
	end)
end

function spawnBoss(idx)
	local bd = G.Bosses[idx]
	bossParts[idx] = spawnEnemy(bd.kind, bd.pos, nil, { bossIdx = idx })
	workspace:SetAttribute("BossAt_" .. bd.kind, 0)
	return bossParts[idx]
end
-- where a boss should be right now (roaming bosses swim / orbit in a big circle)
local function bossHome(st, now)
	local bd = G.Bosses[st.bossIdx]
	if not bd.roam then
		return bd.pos
	end
	local a = now * 0.12
	return bd.pos + Vector3.new(math.cos(a) * bd.roam, math.sin(a * 2) * 12, math.sin(a) * bd.roam)
end

-- spawner
task.spawn(function()
	for i, bd in ipairs(G.Bosses) do
		if G.RealmOfY(bd.pos.Y) == G.REALM then
			spawnBoss(i)
		end
	end
	for gi, g in ipairs(G.Giants) do
		if G.RealmOfY(g.pos.Y) == G.REALM then
			spawnEnemy(g.kind, g.pos, nil, { giantIdx = gi })
		end
	end
	while true do
		for i, sp in ipairs(G.Spawns) do
			if (spawnCount[i] or 0) < sp.max and G.RealmOfY(sp.center.Y) == G.REALM then
				local a = rng:NextNumber() * math.pi * 2
				local d = rng:NextNumber() * sp.r
				local pos = sp.center + Vector3.new(math.cos(a) * d, sp.ground and 0 or rng:NextNumber(-12, 12), math.sin(a) * d)
				spawnEnemy(sp.type, pos, i)
			end
		end
		task.wait(2.5)
	end
end)

-- enemy brains (10 Hz)
-- v0.8 GIANT ANGELS: drift around home; smite players who attacked them; smite the monsters the Blessed fight
local function giantThink(part, st, chars, now)
	local seed = (st.giantIdx or 1) * 2.1
	local home = st.home + Vector3.new(math.sin(now * 0.03 + seed) * 120, math.sin(now * 0.2 + seed) * 25, math.cos(now * 0.025 + seed) * 120)
	local foe, fd, ally
	for _, c in ipairs(chars) do
		local dist = (c.hrp.Position - home).Magnitude
		local h = st.hostile[c.p]
		if st.def.aggressive and dist < st.def.aggressive and (not st.def.strongLv or (data[c.p] and data[c.p].level >= st.def.strongLv)) then
			h = now + 5 -- THE NAMELESS: anything that comes close is noticed
		end
		if h and h > now and dist < 900 and (not fd or dist < fd) then
			foe, fd = c, dist
		end
		local d = data[c.p]
		if d and d.blessed and not h and dist < 1100 then
			local ss = S[c.p]
			local lk = ss and ss.lock
			local es = lk and enemies[lk]
			if es and not es.def.giant and (lk.Position - c.hrp.Position).Magnitude < 300 then
				ally = { c = c, lk = lk }
			end
		end
	end
	local face = foe and foe.hrp.Position or (ally and ally.lk.Position) or (home + Vector3.new(math.sin(now * 0.05), 0, math.cos(now * 0.05)))
	part.CFrame = CFrame.lookAt(home, Vector3.new(face.X, home.Y, face.Z))
	if now - st.lastAtk < st.def.atk then
		return
	end
	if foe then
		st.lastAtk = now
		st.cycle = (st.cycle or 0) + 1
		local tp = foe.hrp.Position
		if st.cycle % 4 == 0 then -- JUDGEMENT: a ring of holy pillars around you
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				local at = tp + Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26)
				Fx:FireAllClients("Smite", { from = home, to = at, big = true })
				telegraph(at, 14, 1.4, st.dmg)
			end
			telegraph(tp, 12, 1.6, st.dmg * 1.3)
		else
			Fx:FireAllClients("Smite", { from = home, to = tp })
			telegraph(tp + foe.hrp.AssemblyLinearVelocity * 0.6, 18, 1.1, st.dmg)
		end
	elseif ally then
		st.lastAtk = now
		local tgt = ally.lk
		Fx:FireAllClients("Smite", { from = home, to = tgt.Position, ally = true })
		task.delay(0.35, function()
			if enemies[tgt] then
				damageEnemy(tgt, math.max(st.dmg * 6, enemies[tgt].maxhp * 0.2), ally.c.p, true)
			end
		end)
	elseif st.hp < st.maxhp then
		st.hp = math.min(st.maxhp, st.hp + st.maxhp * 0.02)
		part:SetAttribute("HP", st.hp)
		st.dmgBy = {}
	end
end

local function bossThink(part, st, chars, now)
	local def = st.def
	-- phases at 66% / 33%: summon flying blobs
	local frac = st.hp / st.maxhp
	if (st.phase == 1 and frac < 0.66) or (st.phase == 2 and frac < 0.33) then
		st.phase += 1
		local bd = G.Bosses[st.bossIdx] or G.Bosses[1]
		Fx:FireAllClients("Announce", { text = st.phase == 2 and (def.name .. " CALLS FOR HELP!") or (def.name .. " IS FURIOUS!"), color = Color3.fromRGB(255, 60, 90) })
		for k = 1, 3 + st.phase do
			local a = k / (3 + st.phase) * math.pi * 2
			spawnEnemy(bd.adds, part.Position + Vector3.new(math.cos(a) * 18, -4, math.sin(a) * 18), nil, { fly = true })
		end
	end
	if now - st.lastAtk < (st.phase == 3 and 2.2 or def.atk) then
		return
	end
	local near = {}
	for _, c in ipairs(chars) do
		if (c.hrp.Position - part.Position).Magnitude < st.aggro then
			near[#near + 1] = c
		end
	end
	if #near == 0 then
		return
	end
	st.lastAtk = now
	local roll = rng:NextNumber()
	if roll < 0.4 then -- SLAM: ring around the king
		telegraph(part.Position, 30, 1.6, st.dmg)
	else -- INK RAIN: a blot on every nearby player
		for _, c in ipairs(near) do
			telegraph(c.hrp.Position, 11, 1.2, st.dmg * 0.7)
		end
	end
end

task.spawn(function()
	local dt = 0.1
	while true do
		task.wait(dt)
		local now = os.clock()
		local chars = liveChars()
		for part, st in pairs(enemies) do
			local def = st.def
			if def.giant then
				giantThink(part, st, chars, now)
				continue
			end
			local pos = part.Position
			-- target: current one if still valid, else nearest in aggro range
			local tgt, best
			for _, c in ipairs(chars) do
				local dist = (c.hrp.Position - pos).Magnitude
				if ((c.p == st.target and dist < st.aggro * 3) or dist < st.aggro) and allowed(st, c.p, now) then
					if not best or dist < best or c.p == st.target then
						tgt, best = c, dist
						if c.p == st.target then
							break
						end
					end
				end
			end
			if def.boss then
				if Hooks.boss then
					Hooks.boss(part, st, chars, now)
				end
				bossThink(part, st, chars, now)
				local face = tgt and tgt.hrp.Position or (pos + Vector3.new(0, 0, -1))
				local bob = st.bossIdx and bossHome(st, now) or pos
				if tgt then
					part.CFrame = CFrame.lookAt(bob, Vector3.new(face.X, bob.Y, face.Z))
				else
					local nxt = bossHome(st, now + 0.5)
					part.CFrame = (nxt - bob).Magnitude > 0.05 and CFrame.lookAt(bob, nxt) or CFrame.new(bob)
				end
				-- out of combat: regenerate
				if not tgt and st.hp < st.maxhp then
					st.hp = math.min(st.maxhp, st.hp + st.maxhp * 0.01)
					st.dmgBy = {}
					part:SetAttribute("HP", st.hp)
				end
				continue
			end
			local rooted = st.rootUntil and now < st.rootUntil
			if Hooks.think and Hooks.think(part, st, tgt, chars, now) then
				continue -- a behaviour (flee, merge, affix move) took over this tick
			end
			local goal
			if tgt and (pos - st.home).Magnitude < st.aggro * 6 then
				if st.target ~= tgt.p then
					-- PACK ALERT: a monster that spots you calls the others nearby
					for other, os2 in pairs(enemies) do
						if other ~= part and not os2.target and not os2.def.boss and not os2.def.giant and (other.Position - pos).Magnitude < 70 and allowed(os2, tgt.p, now) then
							os2.target = tgt.p
						end
					end
				end
				st.target = tgt.p
				local tp = tgt.hrp.Position
				local tv = tgt.hrp.AssemblyLinearVelocity
				local want = def.ranged and 30 or def.reach * 0.6
				local dir = tp - pos
				local dist = dir.Magnitude
				if dist > want then
					-- cut you off: aim a little ahead of where you are flying
					local lead = tp + tv * math.clamp(dist / 60, 0, 0.8)
					local ld = lead - pos
					goal = pos + ld.Unit * math.min(st.speed * dt * (dist > 40 and 1.5 or 1), math.max(0, ld.Magnitude - want))
				elseif st.fly then
					-- in range: circle around you instead of hovering in one spot
					local side = (st.side or 1)
					if rng:NextNumber() < 0.01 then
						st.side = -side
					end
					local flat = Vector3.new(dir.X, 0, dir.Z)
					local tang = flat.Magnitude > 0.1 and Vector3.new(-flat.Z, 0, flat.X).Unit * side or Vector3.zero
					goal = pos + tang * st.speed * 0.5 * dt + Vector3.new(0, (tp.Y + 2 - pos.Y) * 0.1, 0)
				end
				-- attack
				if now - st.lastAtk > def.atk and dist < def.reach + (def.ranged and 0 or 2) then
					st.lastAtk = now
					if def.ranged then
						local aim = tp + tv * 0.5 -- leads its shots
						Fx:FireAllClients("EShot", { from = pos, to = aim, k = part:GetAttribute("Type") })
						telegraph(aim, 7, 1.0, st.dmg)
					else
						Fx:FireAllClients("Bite", { part = part, k = part:GetAttribute("Type"), to = tp })
						hurtPlayer(tgt.p, tgt.hum, st.dmg)
					end
				end
			else
				st.target = nil
				-- wander near home (and heal when idle)
				if not st.wander or (st.wander - pos).Magnitude < 2 or rng:NextNumber() < 0.01 then
					local a = rng:NextNumber() * math.pi * 2
					local sp = st.spawnIdx and G.Spawns[st.spawnIdx]
					local r = sp and sp.r or 10
					st.wander = st.home + Vector3.new(math.cos(a) * rng:NextNumber() * r, (st.fly and rng:NextNumber(-6, 6) or 0), math.sin(a) * rng:NextNumber() * r)
				end
				local dir = st.wander - pos
				if dir.Magnitude > 0.5 then
					goal = pos + dir.Unit * math.min(st.speed * 0.35 * dt, dir.Magnitude)
				end
				if st.hp < st.maxhp then
					st.hp = math.min(st.maxhp, st.hp + st.maxhp * 0.02)
					part:SetAttribute("HP", st.hp)
					st.dmgBy = {}
				end
			end
			if goal and not rooted then
				if not st.fly then -- ground blobs stay on their island
					local sp = st.spawnIdx and G.Spawns[st.spawnIdx]
					local c = sp and sp.center or st.home
					local flat = Vector3.new(goal.X - c.X, 0, goal.Z - c.Z)
					local lim = (sp and sp.r or 10) + 2
					if flat.Magnitude > lim then
						flat = flat.Unit * lim
					end
					goal = Vector3.new(c.X + flat.X, c.Y, c.Z + flat.Z)
				end
				-- v1.7 OBSTACLES: flyers steer over / around islands, trees and ships instead of passing through
				if st.fly and Hooks.avoid then
					goal = Hooks.avoid(part, st, pos, goal)
				end
				local look = tgt and tgt.hrp.Position or goal
				local flatLook = Vector3.new(look.X, goal.Y, look.Z)
				if (flatLook - goal).Magnitude > 0.1 then
					part.CFrame = CFrame.lookAt(goal, flatLook)
				else
					part.CFrame = CFrame.new(goal) * part.CFrame.Rotation
				end
			end
			-- ink burn ticks
			if st.dot and now >= st.dot.next then
				st.dot.next = now + 0.5
				st.dot.left -= 1
				local by = st.dot.by
				if st.dot.left <= 0 then
					st.dot = nil
				end
				damageEnemy(part, st.dotDmg or 5, by, false)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- PLAYER COMBAT
---------------------------------------------------------------------------
feast = function(p)
	local st = S[p]
	return (st and st.feastUntil and os.clock() < st.feastUntil) and (st.feast or 0) or 0
end
local function power(p)
	local d = data[p]
	local w = G.Wings[d.wing]
	local m = G.RANK_POWER[d.rank] * (1 + math.min(d.manaMax, 4000) / 8000) * (1 + 0.06 * feast(p)) * (d.aspect == "Infernal" and 1.1 or 1)
	if workspace:GetServerTimeNow() < (p:GetAttribute("BuffDmg") or 0) then
		m *= 1.25 -- Hunter's Brew
	end
	return w.dmg * G.WingPower(d.wings[d.wing] or 1) * G.LevelPower(d.level) * m, w
end
local function diving(p)
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.AssemblyLinearVelocity.Y < -25
end
local function validTarget(p, part, range)
	local st = part and enemies[part]
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not st or not hrp then
		return nil
	end
	local reach = range + (st.def.size or 4) * 0.5
	if (part.Position - hrp.Position).Magnitude > reach then
		return nil
	end
	return st, hrp
end

Combat.OnServerEvent:Connect(function(p, action, a)
	local d, st = data[p], S[p]
	if not d or not st then
		return
	end
	if action == "fire" then
		if S[p] then
			S[p].fireUntil = os.clock() + 0.3
			S[p].lastShotT = os.clock()
		end
		return
	end
	if action == "lock" then
		st.lock = (typeof(a) == "Instance" and enemies[a]) and a or nil
	elseif action == "absorb" then
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hasSkill(d, "absorb") or os.clock() < (st.nextAbsorb or 0) then
			return
		end
		local glut = hasSkill(d, "gluttony")
		local reach = glut and 150 or 60
		local got = {}
		for _, r in ipairs(RemainsF:GetChildren()) do
			local dist = (r.Position - hrp.Position).Magnitude - r.Size.X / 2
			if dist < reach then
				table.insert(got, { r = r, d = dist })
			end
		end
		if #got == 0 then
			return
		end
		table.sort(got, function(x, y)
			return x.d < y.d
		end)
		if not glut then
			got = { got[1] }
		end
		st.nextAbsorb = os.clock() + (glut and 2 or 0.6)
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		local total = {}
		for _, g in ipairs(got) do
			local r = g.r
			local ess = r:GetAttribute("Essence")
			local n = r:GetAttribute("Amount") or 1
			n = math.max(n, math.floor(n * (1 + prof(d, "absorb") * 0.5) + 0.5))
			d.essence[ess] = (d.essence[ess] or 0) + n
			if workspace:GetServerTimeNow() < (p:GetAttribute("BuffEss") or 0) then
				n *= 2 -- Essence Lantern
			end
			total[ess] = (total[ess] or 0) + n
			Fx:FireAllClients("Absorb", { from = r.Position, player = p, color = G.ESSENCES[ess].color, big = r:GetAttribute("Big"), vortex = glut })
			r:Destroy()
			if glut and hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.05)
			end
		end
		if glut then
			st.feast = math.min(10, (feast(p) > 0 and st.feast or 0) + #got)
			st.feastUntil = os.clock() + 30
			p:SetAttribute("Feast", st.feast)
			p:SetAttribute("FeastUntil", workspace:GetServerTimeNow() + 30)
		end
		for ess, n in pairs(total) do
			Fx:FireClient(p, "Toast", { text = ("+%d %s ESSENCE"):format(n, ess:upper()), color = G.ESSENCES[ess].color })
		end
		skillUse(p, "absorb", #got)
		questCheck(p, "absorb", #got)
		sync(p)
	elseif action == "sense" and a ~= nil then -- v1.9 MANA VISION: hold on / off, drained per second
		if a == true and (hasSkill(d, "sense") or hasSkill(d, "truesight")) and d.mana >= 1 then
			local eff = prof(d, "sense")
			local _, rr = G.SenseStats(eff)
			st.sensing = true
			p:SetAttribute("Vision", true)
			Fx:FireClient(p, "Vision", { on = true, r = hasSkill(d, "truesight") and math.max(rr, 280) or rr, eff = hasSkill(d, "truesight") and 1 or eff })
		else
			if a == true then
				Fx:FireClient(p, "Toast", { text = "NOT ENOUGH MANA", color = Color3.fromRGB(120, 180, 255) })
			end
			st.sensing = nil
			p:SetAttribute("Vision", false)
			Fx:FireClient(p, "Vision", { on = false })
		end
	elseif action == "sense" then
		if not (hasSkill(d, "sense") or hasSkill(d, "truesight")) or os.clock() < (st.nextSense or 0) or d.mana < 1 then
			if d.mana < 1 then
				Fx:FireClient(p, "Toast", { text = "NOT ENOUGH MANA TO SENSE (3)", color = Color3.fromRGB(120, 180, 255) })
			end
			return
		end
		st.nextSense = os.clock() + 0.8
		d.mana -= 1
		p:SetAttribute("Mana", math.floor(d.mana))
		skillUse(p, "sense", 1)
		Fx:FireClient(p, "SensePulse", { r = hasSkill(d, "truesight") and 280 or 170 })
	elseif action == "unleash" then
		if not hasSkill(d, "unleash") or os.clock() < (st.nextUnleash or 0) then
			return
		end
		local cat = hasSkill(d, "catastrophe")
		local cost = cat and 6 or 10
		-- your aspect's essence first, otherwise whatever you hold most of
		local ess = (d.aspect ~= "" and (d.essence[d.aspect] or 0) >= cost) and d.aspect or nil
		if not ess then
			local bv = 0
			for k, v in pairs(d.essence) do
				if v >= cost and v > bv then
					ess, bv = k, v
				end
			end
		end
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not ess or not hrp then
			Fx:FireClient(p, "Toast", { text = "NOT ENOUGH ESSENCE (" .. cost .. ")", color = Color3.fromRGB(255, 120, 120) })
			return
		end
		local U = G.UNLEASH[ess]
		local tgt = st.lock and enemies[st.lock] and st.lock
		local center = tgt and tgt.Position or hrp.Position + hrp.CFrame.LookVector * 30
		if (center - hrp.Position).Magnitude > 260 then
			center = hrp.Position + hrp.CFrame.LookVector * 30
		end
		d.essence[ess] -= cost
		if d.essence[ess] <= 0 then
			d.essence[ess] = nil
		end
		st.nextUnleash = os.clock() + (cat and 4 or 6)
		local big = cat and 1.6 or 1
		local base = power(p) * U.mult * (cat and 1.5 or 1)
		local R = U.radius * big
		local hits = {}
		local function near(pos, r)
			local out = {}
			for part, es in pairs(enemies) do
				local dd = (part.Position - pos).Magnitude - (es.def.size or 4) * 0.5
				if dd < r then
					table.insert(out, { part = part, es = es, d = dd })
				end
			end
			table.sort(out, function(x, y)
				return x.d < y.d
			end)
			return out
		end
		local hum = p.Character:FindFirstChildOfClass("Humanoid")
		if ess == "Storm" then
			local list = near(center, R)
			local prev = hrp.Position
			for k = 1, math.min(#list, U.chain + (cat and 4 or 0)) do
				table.insert(hits, { list[k].part, prev })
				prev = list[k].part.Position
				damageEnemy(list[k].part, base, p, false)
			end
		elseif ess == "Abyssal" then
			if tgt then
				damageEnemy(tgt, base, p, true)
				if hum then
					hum.Health = math.min(hum.MaxHealth, hum.Health + base * U.drain)
				end
				table.insert(hits, { tgt, hrp.Position })
			end
		elseif ess == "Cosmic" then
			for k = 1, U.strikes + (cat and 5 or 0) do
				task.delay(k * 0.18, function()
					local at = center + Vector3.new(math.random(-1, 1) * R * 0.6 * math.random(), 0, math.random(-1, 1) * R * 0.6 * math.random())
					Fx:FireAllClients("UnleashHit", { kind = ess, pos = at, radius = 14 * big, color = G.ESSENCES[ess].color })
					for _, h in ipairs(near(at, 16 * big)) do
						damageEnemy(h.part, base, p, false)
					end
				end)
			end
		else
			for _, h in ipairs(near(center, R)) do
				damageEnemy(h.part, base, p, false)
				if U.root and not h.es.def.giant then
					h.es.rootUntil = os.clock() + (h.es.def.boss and 1.5 or U.root)
				end
				if U.pull and not h.es.def.giant and not h.es.def.boss and h.part.Parent then
					h.part.CFrame = CFrame.new(h.part.Position:Lerp(center, 0.7))
				end
			end
			if U.heal and hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * U.heal)
			end
		end
		Fx:FireAllClients("Unleash", { kind = ess, name = U.name, pos = center, from = hrp.Position, radius = R, color = G.ESSENCES[ess].color, hits = hits, player = p, cat = cat })
		skillUse(p, "unleash", 1)
		sync(p)
	elseif action == "meditate" then
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local airborne = hum and hum.FloorMaterial == Enum.Material.Air
		if a == true and airborne and not hasSkill(d, "zen") then
			Fx:FireClient(p, "Toast", { text = "LAND TO MEDITATE (ZEN FLIGHT LETS YOU MEDITATE IN THE AIR)", color = Color3.fromRGB(255, 200, 120) })
			return
		end
		st.meditating = (a == true) and hasSkill(d, "meditate") or nil
		p:SetAttribute("Meditating", st.meditating == true)
	elseif action == "ability" then
		local w = G.Wings[d.wing]
		local idx = tonumber(a)
		local ab = idx and w.abilities[idx]
		if not ab then
			return
		end
		local key = d.wing .. idx
		local now = os.clock()
		if st.cds[key] and now < st.cds[key] then
			return
		end
		local cost = G.AbilityMana(ab)
		if d.mana < cost then
			return
		end
		if ab.kind ~= "shield" and not validTarget(p, st.lock, ab.kind == "dive" and 75 or w.range) then
			Fx:FireClient(p, "Toast", { text = "NO MONSTER IN RANGE", color = Color3.fromRGB(255, 120, 120) })
			return
		end
		d.mana -= cost
		p:SetAttribute("Mana", math.floor(d.mana))
		local base = power(p)
		local dive = diving(p) and 1.5 or 1
		if ab.kind == "shield" then
			st.cds[key] = now + ab.cd
			st.shieldUntil = now + ab.dur
			p:SetAttribute("ShieldUntil", workspace:GetServerTimeNow() + ab.dur)
			Fx:FireAllClients("Ability", { id = ab.id, player = p })
			return
		end
		local tgt = st.lock
		local est, hrp = validTarget(p, tgt, ab.kind == "dive" and 75 or w.range)
		if not est then
			Fx:FireClient(p, "Toast", { text = "LOCK ONTO AN ENEMY FIRST", color = Color3.fromRGB(255, 120, 120) })
			return
		end
		st.cds[key] = now + ab.cd
		Fx:FireAllClients("Ability", { id = ab.id, player = p, pos = tgt.Position, r = ab.radius })
		if ab.kind == "aoe" then
			local center = tgt.Position
			for part2, _ in pairs(enemies) do
				if (part2.Position - center).Magnitude < ab.radius + (enemies[part2].def.boss and 12 or 0) then
					damageEnemy(part2, base * ab.mult * dive, p, false)
				end
			end
		elseif ab.kind == "dive" then
			Fx:FireClient(p, "Dash", { to = tgt.Position })
			task.delay(0.25, function()
				damageEnemy(tgt, base * ab.mult * 1.5, p, true)
			end)
		elseif ab.kind == "dot" then
			est.dot = { left = ab.ticks, next = now + 0.5, by = p }
			est.dotDmg = base * ab.mult
			damageEnemy(tgt, base * ab.mult, p, false)
		elseif ab.kind == "root" then
			est.rootUntil = now + (est.def.boss and 1.5 or ab.dur)
			damageEnemy(tgt, base * ab.mult * dive, p, false)
		end
		local _ = hrp
	end
end)

-- v0.7 DODGE: a short invulnerability window (rate-limited server-side)
Fx.OnServerEvent:Connect(function(p, kind)
	local st = S[p]
	if kind == "Dodge" and st and os.clock() > (st.nextDodge or 0) then
		st.nextDodge = os.clock() + 1.4
		st.iframeUntil = os.clock() + 0.35
	end
end)

-- ======================= v0.9 TRAVEL (gates + realm map) =======================
local function travel(p, realm, arrive)
	local st, d = S[p], data[p]
	if not st or not d or st.traveling then
		return
	end
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if realm == G.REALM then
		local dest = G.ARRIVE[arrive] or (G.ZONE_BY_NAME[arrive] and G.ZONE_BY_NAME[arrive].point)
		if dest and c then
			Fx:FireClient(p, "Blink", {})
			task.wait(0.35)
			c:PivotTo(CFrame.new(dest))
		end
		return
	end
	local placeId = G.PLACES[realm] or 0
	if placeId == 0 or RunService:IsStudio() then
		-- not published (or testing in Studio): push them back and explain
		toast(p, G.REALM_NAMES[realm] .. " IS A SEPARATE PLACE - TELEPORTS ONLY WORK IN THE LIVE GAME", Color3.fromRGB(255, 200, 90))
		if hrp then
			local y = hrp.Position.Y
			local back = (G.REALM == "Overworld" and (y > 0 and G.GATE_UP - 200 or G.GATE_DOWN + 200)) or (G.REALM == "Celestial" and G.CEL_FLOOR + 250) or (G.UND_ROOF - 250)
			c:PivotTo(CFrame.new(hrp.Position.X, back, hrp.Position.Z))
		end
		return
	end
	st.traveling = true
	Fx:FireClient(p, "TravelStart", { realm = realm, title = G.REALM_NAMES[realm] })
	save(p)
	st.teleported = true
	local opts = Instance.new("TeleportOptions")
	opts:SetTeleportData({ arrive = arrive })
	local ok
	for _ = 1, 3 do
		ok = pcall(function()
			TeleportService:TeleportAsync(placeId, { p }, opts)
		end)
		if ok then
			break
		end
		task.wait(2)
	end
	if not ok then
		st.traveling, st.teleported = false, false
		Fx:FireClient(p, "TravelFailed", {})
		toast(p, "THE GATE FLICKERED... TRY AGAIN", Color3.fromRGB(255, 120, 120))
	else
		task.delay(20, function() -- the teleport itself can still fail later
			if p.Parent and S[p] then
				S[p].traveling, S[p].teleported = false, false
				Fx:FireClient(p, "TravelFailed", {})
			end
		end)
	end
end
TeleportService.TeleportInitFailed:Connect(function(p)
	if S[p] then
		S[p].traveling, S[p].teleported = false, false
		Fx:FireClient(p, "TravelFailed", {})
		toast(p, "THE GATE FLICKERED... TRY AGAIN", Color3.fromRGB(255, 120, 120))
	end
end)
TravelEv.OnServerEvent:Connect(function(p, zoneName)
	local d = data[p]
	local z = type(zoneName) == "string" and G.ZONE_BY_NAME[zoneName]
	if not d or not z or not d.found[z.name] then
		return
	end
	local st = S[p]
	if st and os.clock() < (st.nextTravel or 0) then
		return
	end
	if st then
		st.nextTravel = os.clock() + 3
	end
	task.spawn(travel, p, z.realm, z.name)
end)
-- discovery + gates (5 Hz)
task.spawn(function()
	while true do
		task.wait(0.2)
		for p, d in pairs(data) do
			local c = p.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local y = hrp.Position.Y
				local zone = G.ZoneOf(y)
				if zone and not d.found[zone] and G.ZONE_BY_NAME[zone].realm == G.REALM then
					d.found[zone] = true
					Fx:FireClient(p, "Announce", { text = "DISCOVERED: " .. zone .. "  -  FAST TRAVEL UNLOCKED", color = Color3.fromRGB(140, 220, 255) })
					sync(p)
				end
				local realm, arrive = G.GateCheck(y)
				if realm then
					task.spawn(travel, p, realm, arrive)
				end
			end
		end
	end
end)

-- v0.7 SOFT GATES: zones above your wings slowly hurt you (server-side, can't be skipped)
task.spawn(function()
	while true do
		task.wait(0.5)
		for p, d in pairs(data) do
			local c = p.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local hrp = c and c:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				local zone, need, why = G.ZoneNeed(hrp.Position.Y)
				local have = G.BestRank(d.wings)
				local miss = math.max(0, need - have)
				p:SetAttribute("BestRank", have)
				p:SetAttribute("Exposure", miss)
				p:SetAttribute("ExposureWhy", miss > 0 and why or "")
				p:SetAttribute("ExposureNeed", miss > 0 and G.WING_ORDER[need] or "")
				if miss > 0 and not (S[p] and S[p].god) then
					hum:TakeDamage(hum.MaxHealth * G.EXPOSURE_DPS * miss * 0.5)
				end
			end
		end
	end
end)

-- attack loop: shots only fire while the player is holding attack (client sends "fire" ~7x/s)
task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for p, st in pairs(S) do
			local d = data[p]
			if d and st.lock and (st.fireUntil or 0) > now and now >= (st.nextShot or 0) then
				local base, w = power(p)
				local est, hrp = validTarget(p, st.lock, w.range)
				if est then
					st.nextShot = now + w.rate
					local crit = rng:NextNumber() < (d.aspect == "Abyssal" and 0.2 or 0.1)
					local dmg = base * (crit and 2 or 1) * (diving(p) and 1.5 or 1)
					local tgt = st.lock
					Fx:FireAllClients("Shot", { from = hrp.Position, to = tgt.Position, color = w.shot, player = p })
					local flight = (tgt.Position - hrp.Position).Magnitude / 140
					task.delay(flight, function()
						damageEnemy(tgt, dmg, p, crit)
						if Hooks.plumeHit then
							Hooks.plumeHit(p, tgt, dmg, crit)
						end
					end)
				elseif not enemies[st.lock] then
					st.lock = nil
				end
			end
			-- v0.8 GUARDIAN OPHAN (Blessed players): a little wheel of eyes that smites your target
			if d and d.blessed and st.lock and enemies[st.lock] and not enemies[st.lock].def.giant and now >= (st.nextGuard or 0) then
				local base = power(p)
				local _, hrp = validTarget(p, st.lock, 90)
				if hrp then
					st.nextGuard = now + 2.2
					local tgt = st.lock
					Fx:FireAllClients("Smite", { from = hrp.Position + Vector3.new(0, 5, 0), to = tgt.Position, ally = true })
					task.delay(0.3, function()
						damageEnemy(tgt, base * 1.6, p, false)
					end)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- WING UPGRADES / EQUIP
---------------------------------------------------------------------------
Fn.OnServerInvoke = function(p, action, a)
	local d = data[p]
	if not d then
		return { ok = false }
	end
	if action == "mentor" then -- v1.10 dialogue: ask Orren for a lesson
		return { ok = true, lines = mentorTalk(p) or {} }
	elseif action == "mentorState" then
		local T = G.Training[d.train]
		return { ok = true, has = T ~= nil, active = d.tactive and true or false, done = T and d.tactive and d.tprog >= T.n or false, text = T and T.text or "" }
	end
	if action == "upgrade" then
		local wing = (type(a) == "string" and d.wings[a]) and a or d.wing
		local tier = d.wings[wing]
		if tier >= G.MAX_TIER then
			return { ok = false, err = "MAX TIER" }
		end
		local c = G.WingCost(tier)
		if d.feathers < c.feathers or d.ink < c.ink then
			return { ok = false, err = ("NEED %d FEATHERS + %d INK"):format(c.feathers, c.ink) }
		end
		d.feathers -= c.feathers
		d.ink -= c.ink
		d.wings[wing] = tier + 1
		sync(p)
		Fx:FireAllClients("WingUp", { player = p, tier = tier + 1 })
		questCheck(p, "tier")
		return { ok = true, tier = tier + 1 }
	elseif action == "learn" and false then -- v1.1: skills are awakened by deeds, not bought
		local sk = type(a) == "string" and G.SkillById[a]
		if not sk or sk.base or hasSkill(d, a) then
			return { ok = false, err = "UNKNOWN" }
		end
		if d.level < sk.level then
			return { ok = false, err = "REACH LEVEL " .. sk.level }
		end
		if sk.req and not hasSkill(d, sk.req) then
			return { ok = false, err = "LEARN " .. G.SkillById[sk.req].name .. " FIRST" }
		end
		if spFree(d) < sk.sp then
			return { ok = false, err = "NEED " .. sk.sp .. " SKILL POINTS" }
		end
		table.insert(d.skills, a)
		questCheck(p, "skill")
		sync(p)
		Fx:FireClient(p, "Announce", { text = "SKILL LEARNED: " .. sk.name .. "  [RANK " .. G.RANKS[sk.rank] .. "]", color = G.RANK_COLORS[sk.rank] })
		return { ok = true }
	elseif action == "equip" then
		if type(a) == "string" and d.wings[a] then
			d.wing = a
			sync(p)
			return { ok = true }
		end
	end
	return { ok = false }
end

---------------------------------------------------------------------------
-- PLAYERS
---------------------------------------------------------------------------
Players.PlayerAdded:Connect(function(p)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local lv = Instance.new("StringValue") -- v1.9: levels are hidden; the board shows your core
	lv.Name = "Core"
	lv.Value = "D-Rank"
	lv.Parent = ls
	ls.Parent = p
	local d = newData()
	if store then
		local ok, saved
		for _ = 1, 3 do
			ok, saved = pcall(function()
				return store:GetAsync("p" .. p.UserId)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
		if not ok then
			d.loadFailed = true
		elseif type(saved) == "table" then
			d.level = tonumber(saved.level) or 1
			d.xp = tonumber(saved.xp) or 0
			d.ink = tonumber(saved.ink) or 0
			d.feathers = tonumber(saved.feathers) or 0
			d.quest = tonumber(saved.quest) or 1
			d.qprog = tonumber(saved.qprog) or 0
			d.bossKills = tonumber(saved.bossKills) or 0
			if type(saved.wings) == "table" then
				for k, v in pairs(saved.wings) do
					if G.Wings[k] then
						d.wings[k] = math.clamp(tonumber(v) or 1, 1, G.MAX_TIER)
					end
				end
			end
			d.wing = (type(saved.wing) == "string" and d.wings[saved.wing]) and saved.wing or "Paper"
			d.blessed = saved.blessed == true
			d.hasWings = saved.hasWings ~= false -- older saves already flew
			d.train = tonumber(saved.train) or 1
			d.tprog = tonumber(saved.tprog) or 0
			d.tactive = saved.tactive == true
			d.chests = type(saved.chests) == "table" and saved.chests or {}
			d.plumes = type(saved.plumes) == "table" and saved.plumes or {}
			d.equip = type(saved.equip) == "table" and saved.equip or {}
			d.shrines = type(saved.shrines) == "table" and saved.shrines or {}
			task.defer(trainSync, p)
			d.rank = math.clamp(tonumber(saved.rank) or 1, 1, 5)
			d.evo = tonumber(saved.evo) or 0
			-- v1.8c: mana is now a pool (current / max). Old saves: the stored mana becomes the max.
			d.manaMax = math.max(1, math.floor(tonumber(saved.manaMax) or tonumber(saved.mana) or 1))
			d.mana = math.clamp(tonumber(saved.mana) or d.manaMax, 0, d.manaMax)
			d.capBonus = math.clamp(tonumber(saved.capBonus) or 0, 0, 2)
			d.aspect = (type(saved.aspect) == "string" and G.ESSENCES[saved.aspect]) and saved.aspect or ""
			for _, key in ipairs({ "essence", "aspPts" }) do
				if type(saved[key]) == "table" then
					for k, v in pairs(saved[key]) do
						if G.ESSENCES[k] then
							d[key][k] = tonumber(v) or 0
						end
					end
				end
			end
			if type(saved.sxp) == "table" then
				for k, v in pairs(saved.sxp) do
					if G.SkillById[k] then
						d.sxp[k] = tonumber(v) or 0
					end
				end
			end
			if type(saved.skills) == "table" then
				for _, id in ipairs(saved.skills) do
					if G.SkillById[id] and not table.find(d.skills, id) then
						table.insert(d.skills, id)
					end
				end
			end
			if type(saved.found) == "table" then
				for k, v in pairs(saved.found) do
					if G.ZONE_BY_NAME[k] and v then
						d.found[k] = true
					end
				end
			end
		end
	end
	if not p.Parent then
		return
	end
	data[p] = d
	S[p] = { cds = {} }
	-- v0.9 ARRIVAL: coming through a gate / the realm map puts you at the right spot
	local okJ, jd = pcall(function()
		return p:GetJoinData().TeleportData
	end)
	local arrive = okJ and type(jd) == "table" and jd.arrive
	local dest = arrive and (G.ARRIVE[arrive] or (G.ZONE_BY_NAME[arrive] and G.ZONE_BY_NAME[arrive].point))
	if dest then
		local function place(c)
			local hrp = c:WaitForChild("HumanoidRootPart", 10)
			if hrp then
				task.wait(0.2)
				c:PivotTo(CFrame.new(dest))
			end
		end
		if p.Character then
			task.spawn(place, p.Character)
		else
			p.CharacterAdded:Once(place)
		end
	end
	p:SetAttribute("NewPlayer", d.level == 1 and d.xp == 0)
	sync(p)
	p.CharacterAdded:Connect(function(char)
		-- v1.0b: a new body starts clean (no meditation / feast carried over from death)
		if S[p] then
			S[p].meditating, S[p].feast, S[p].feastUntil = nil, nil, nil
		end
		p:SetAttribute("Meditating", false)
		p:SetAttribute("FeastUntil", 0)
		local hum = char:WaitForChild("Humanoid")
		hum.MaxHealth = maxHP(d)
		hum.Health = hum.MaxHealth
		S[p].lock = nil
	end)
	if p.Character then
		sync(p)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	if not (S[p] and S[p].teleported) then
		save(p) -- (travellers were already saved right before the teleport)
	end
	data[p] = nil
	S[p] = nil
	for _, st in pairs(enemies) do
		st.dmgBy[p] = nil
		if st.target == p then
			st.target = nil
		end
	end
end)
game:BindToClose(function()
	-- v1.0b: save everyone in parallel (sequential saves can run out the 30s shutdown window)
	local left = 0
	for _, p in ipairs(Players:GetPlayers()) do
		left += 1
		task.spawn(function()
			save(p)
			left -= 1
		end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 25 do
		task.wait(0.2)
	end
end)
task.spawn(function()
	while true do
		task.wait(90)
		for _, p in ipairs(Players:GetPlayers()) do
			save(p)
		end
	end
end)

-- Studio test commands: /ink N, /feathers N, /level N
Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg)
		if not (RunService:IsStudio() or p.UserId == 410255186) then
			return
		end
		local d = data[p]
		local cmd, n = msg:match("^/(%a+)%s*(%d*)")
		n = tonumber(n) or 0
		if not d or not cmd then
			return
		end
		if cmd == "ink" then
			d.ink += n
		elseif cmd == "feathers" then
			d.feathers += n
		elseif cmd == "level" then
			d.level = math.clamp(n, 1, G.MAX_LEVEL)
		end
		sync(p)
	end)
end)

---------------------------------------------------------------------------
-- ADMIN PANEL backend (tim_500 / 410255186, or anyone in Studio)
---------------------------------------------------------------------------
do
	local function isAdmin(p)
		return RunService:IsStudio() or p.UserId == 410255186 or p.Name == "tim_500"
	end
	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("IsAdmin", isAdmin(p))
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("IsAdmin", isAdmin(p))
	end
	local TP = {
		isles = G.HUB + Vector3.new(0, 4, 0),
		storm = Vector3.new(0, G.STORM_BASE + 120, -100),
		depths = Vector3.new(0, G.DEPTH_LINE - 250, -60),
		boss = G.BOSS_POS + Vector3.new(0, 30, 60),
		sea = Vector3.new(0, G.SEA + 20, -60),
		underwater = G.Bosses[2].pos + Vector3.new(0, 40, 150),
		cosmos = Vector3.new(0, G.COSMOS_BASE + 250, -60),
		heaven = Vector3.new(0, 6720, 200),
		hell = Vector3.new(-140, -4500 + 8, -80),
		abyss = Vector3.new(0, G.ABYSS_TOP - 300, -60),
		unknown = Vector3.new(0, G.UNKNOWN_TOP - 250, -60),
	}
	local function findPlayer(name)
		if type(name) ~= "string" or name == "" then
			return nil
		end
		name = name:lower()
		for _, q in ipairs(Players:GetPlayers()) do
			if q.Name:lower() == name or q.DisplayName:lower() == name then
				return q
			end
		end
		for _, q in ipairs(Players:GetPlayers()) do
			if q.Name:lower():sub(1, #name) == name then
				return q
			end
		end
		return nil
	end
	AdminFn.OnServerInvoke = function(p, action, arg, who)
		if not isAdmin(p) then
			return "NOT AN ADMIN"
		end
		local target = p
		if type(who) == "string" and who ~= "" then
			target = findPlayer(who)
			if not target then
				return "PLAYER NOT FOUND: " .. who
			end
		end
		local d = data[target]
		if not d then
			return "NO DATA YET"
		end
		local n = math.floor(tonumber(arg) or 0)
		if action == "tod_day" or action == "tod_sunset" or action == "tod_night" or action == "tod_real" then
			local ph = ({ tod_day = 0.3, tod_sunset = 0.62, tod_night = 0.82, tod_real = -1 })[action]
			workspace:SetAttribute("ForcePhase", ph)
			return "TIME SET"
		elseif action == "leviathan" then
			if _G.InkwingLeviathan then
				_G.InkwingLeviathan()
			end
			return "LEVIATHAN SUMMONED"
		elseif action == "star" then
			if _G.InkwingStar then
				_G.InkwingStar()
			end
			return "A STAR FALLS"
		elseif action == "plume" then
			if Hooks.givePlume then
				Hooks.givePlume(target, G.PLUME_ORDER[math.clamp(n, 1, #G.PLUME_ORDER)] or nil, "ADMIN")
			end
			return "PLUME GIVEN"
		elseif action == "shower" then
			if _G.InkwingShower then
				_G.InkwingShower()
			end
			return "SKY SHOWER STARTED"
		elseif action == "ink" then
			d.ink = math.max(0, d.ink + n)
		elseif action == "essence" then -- v1.0b: +N of every essence
			for k in pairs(G.ESSENCES) do
				d.essence[k] = (d.essence[k] or 0) + math.max(1, n)
			end
			sync(target)
			return "+" .. math.max(1, n) .. " OF EVERY ESSENCE"
		elseif action == "rank" then
			d.rank = math.clamp(n, 1, 5)
			d.evo = 0
			sync(target)
			return "WING RANK " .. G.RANKS[d.rank]
		elseif action == "mana" then
			d.manaMax += math.max(0, n)
			d.mana = d.manaMax
			sync(target)
			return "+" .. n .. " MAX MANA"
		elseif action == "skills" then -- learn every skill and evolve them all
			for _, sk in ipairs(G.Skills) do
				for _, id in ipairs({ sk.id, sk.evo and sk.evo.id or sk.id }) do
					if not table.find(d.skills, id) then
						table.insert(d.skills, id)
					end
				end
			end
			sync(target)
			return "ALL SKILLS LEARNED + EVOLVED"
		elseif action == "unskill" then
			d.skills, d.sxp = {}, {}
			sync(target)
			return "SKILLS RESET (POINTS REFUNDED)"
		elseif action == "feathers" then
			d.feathers = math.max(0, d.feathers + n)
		elseif action == "level" then
			d.level = math.clamp(n, 1, G.MAX_LEVEL)
			d.xp = 0
		elseif action == "unlock" then
			for id in pairs(G.Wings) do
				d.wings[id] = G.MAX_TIER
			end
			d.blessed = true
			Fx:FireClient(target, "Toast", { text = "ALL WINGS UNLOCKED AT MAX TIER", color = Color3.fromRGB(255, 220, 90) })
		elseif action == "tier" then
			d.wings[d.wing] = math.clamp(n, 1, G.MAX_TIER)
		elseif action == "quest" then
			d.quest = math.clamp(d.quest + 1, 1, #G.Quests + 1)
			d.qprog = 0
		elseif action == "reset" then
			local fresh = newData()
			for k in pairs(d) do
				if k ~= "loadFailed" then
					d[k] = nil
				end
			end
			for k, v in pairs(fresh) do
				d[k] = v
			end
			target:SetAttribute("NewPlayer", true)
			if target.Character then
				target:LoadCharacter()
			end
		elseif action == "tp" then
			local pos = TP[arg]
			local hrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not (pos and hrp) then
				return "BAD TELEPORT"
			end
			if G.RealmOfY(pos.Y) ~= G.REALM then -- v0.9: other realm -> real teleport
				task.spawn(travel, target, G.RealmOfY(pos.Y), G.ZoneOf(pos.Y))
				return "TRAVELLING TO " .. G.REALM_NAMES[G.RealmOfY(pos.Y)]
			end
			hrp.CFrame = CFrame.new(pos)
		elseif action == "heal" then
			local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = hum.MaxHealth
			end
		elseif action == "god" then
			S[target].god = not S[target].god
			sync(target)
			return "GOD MODE " .. (S[target].god and "ON" or "OFF") .. " FOR " .. target.Name
		elseif action == "boss" then
			local n2 = 0
			for i in ipairs(G.Bosses) do
				if not (bossParts[i] and bossParts[i].Parent) then
					spawnBoss(i)
					n2 += 1
				end
			end
			return n2 == 0 and "ALL BOSSES ARE ALREADY ALIVE" or ("SPAWNED " .. n2 .. " BOSSES")
		elseif action == "killall" then
			local list = {}
			for part, st in pairs(enemies) do
				if not st.def.boss then
					st.dmgBy[target] = (st.dmgBy[target] or 0) + 1
					list[#list + 1] = part
				end
			end
			for _, part in ipairs(list) do
				killEnemy(part)
			end
			return "KILLED " .. #list .. " MONSTERS"
		else
			return "UNKNOWN ACTION"
		end
		sync(target)
		return "OK: " .. action .. " -> " .. target.Name
	end
end

-- v1.0 MEDITATION (1 Hz): mana grows; stored essence fuses into your wings; at the threshold the wings EVOLVE
task.spawn(function()
	while true do
		task.wait(1)
		for p, st in pairs(S) do
			local d = data[p]
			local hrp0 = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if d and hrp0 and not d.hasWings and G.REALM == "Overworld" and hrp0.Position.Y < -20 then
				hrp0.CFrame = CFrame.new(0, 46, 380) -- no wings yet: the sky catches you and puts you back
				Fx:FireClient(p, "Toast", { text = "YOU HAVE NO WINGS YET. FINISH THE FIRST HUNT.", color = Color3.fromRGB(255, 200, 120) })
			end
			if d and d.mana < d.manaMax and not st.meditating then -- v1.8c slow natural regen
				local rot = hasSkill(d, "rotation")
				if not st.sensing then
					d.mana = math.min(d.manaMax, d.mana + math.max(0.05, d.manaMax * 0.01) * (rot and (3 + prof(d, "rotation") * 2) or 1))
				end
				if rot and hrp0 and hrp0.AssemblyLinearVelocity.Magnitude > 2 then
					skillUse(p, "rotation", 1)
				end
				p:SetAttribute("Mana", math.floor(d.mana))
			end
			if d and st.sensing then -- v1.9 Mana Vision drain
				local cost = G.SenseStats(hasSkill(d, "truesight") and 1 or prof(d, "sense"))
				d.mana -= cost
				skillUse(p, "sense", 0.3)
				if d.mana <= 0 then
					d.mana = 0
					st.sensing = nil
					p:SetAttribute("Vision", false)
					Fx:FireClient(p, "Vision", { on = false, empty = true })
				end
				p:SetAttribute("Mana", math.floor(d.mana))
			end
			if d and hrp0 then -- training ticks (once per second)
				local T = G.Training[d.train]
				if T and d.tactive then
					if T.kind == "still" then
						if hrp0.AssemblyLinearVelocity.Magnitude < 0.5 then
							trainProg(p, "still", 1)
						elseif d.tprog > 0 and d.tprog < T.n then
							d.tprog = 0 -- moved: start over
							trainSync(p)
						end
					elseif T.kind == "depth" and hrp0.Position.Y < -1500 then
						trainProg(p, "depth", 1, true)
					end
				end
			end
			if d and hrp0 and hasSkill(d, "abysseye") and hrp0.Position.Y < G.ABYSS_TOP + 250 then
				skillUse(p, "abysseye", 1)
			end
			if st.brk and d and not st.meditating then -- left meditation mid-breakthrough
				breakFail(p, st, d)
			end
			if st.meditating and d then
				local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if not hrp or hrp.AssemblyLinearVelocity.Magnitude > 12 then
					st.meditating = nil
					p:SetAttribute("Meditating", false)
				else
					skillUse(p, "meditate", 1)
					trainProg(p, "meditate", 1)
					if not hasSkill(d, "rotation") and G.Proficiency("meditate", d.sxp.meditate, hasSkill(d, "zen")) >= 4 then
						awaken(p, "rotation", "MEDITATE REACHED PROFICIENCY C")
					end
					local gain = (1 + prof(d, "meditate")) * G.MANA_PER_SEC * (hasSkill(d, "zen") and 2 or 1) * (d.aspect == "Cosmic" and 1.25 or 1) * (1 + (d.rank - 1) * 0.25)
					if d.mana < d.manaMax then -- refill fast first...
						d.mana = math.min(d.manaMax, d.mana + gain * 2 + d.manaMax * 0.08)
					else -- ...and once you're full, meditation stretches your pool - up to your core's limit
						local cap = coreCap(d)
						if d.manaMax < cap then
							d.manaMax = math.min(cap, d.manaMax + gain)
						end
						d.mana = d.manaMax
						p:SetAttribute("ManaMax", math.floor(d.manaMax))
					end
					p:SetAttribute("Mana", math.floor(d.mana))
					if d.rank < 5 then
						local fuse = 1 + d.level / 25
						local need = G.EVO_ESSENCE[d.rank] - d.evo
						fuse = math.min(fuse, math.max(0, need))
						while fuse >= 1 do
							local bestK, bestV = nil, 0
							for k, v in pairs(d.essence) do
								if v > bestV then
									bestK, bestV = k, v
								end
							end
							if not bestK then
								break
							end
							local take = math.min(bestV, math.floor(fuse))
							d.essence[bestK] = bestV - take
							if d.essence[bestK] <= 0 then
								d.essence[bestK] = nil
							end
							d.aspPts[bestK] = (d.aspPts[bestK] or 0) + take
							d.evo += take
							fuse -= take
						end
						if breakthroughTick(p, st, d, hrp) then
							d.rank += 1
							d.evo = 0
							local bestK, bestV = nil, 0
							for k, v in pairs(d.aspPts) do
								if v > bestV then
									bestK, bestV = k, v
								end
							end
							d.aspect = bestK or ""
							local asp = G.ESSENCES[d.aspect]
							local label = (asp and asp.aspect .. " " or "") .. "WINGS"
							Fx:FireAllClients("Evolve", { player = p, rank = d.rank })
							questCheck(p, "rank")
							Fx:FireAllClients("Announce", { text = p.DisplayName .. " BROKE THROUGH (" .. string.upper(st.lastGrade or "") .. "): CORE RANK " .. G.RANKS[d.rank] .. " - " .. label, color = G.RANK_COLORS[d.rank] })
							p:SetAttribute("CoreCap", coreCap(d))
						end
					end
					sync(p)
				end
			end
		end
	end
end)


---------------------------------------------------------------------------
-- v1.5 THE WANDERING MERCHANT (airship) + SKY SHOWERS (island weather, golden monsters, rainbow)
---------------------------------------------------------------------------
if G.REALM == "Overworld" then
	-- the merchant: an invisible anchored root the clients dress up as an airship; the prompt lives on it
	local root = Instance.new("Part")
	root.Name = "MerchantRoot"
	root.Size = Vector3.new(10, 6, 30)
	root.Transparency = 1
	root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	root.CFrame = CFrame.new(G.MerchantDocks[1].pos)
	root.Parent = workspace
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Trade"
	pr.ObjectText = "Wandering Merchant"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 45
	pr.RequiresLineOfSight = false
	pr.Parent = root
	local stock = {}
	local docked = false
	local function rollStock()
		stock = { "map" }
		local pool = {}
		for _, it in ipairs(G.ShopItems) do
			if it.id ~= "map" then
				table.insert(pool, it.id)
			end
		end
		for _ = 1, 4 do
			table.insert(stock, table.remove(pool, rng:NextInteger(1, #pool)))
		end
		root:SetAttribute("Stock", table.concat(stock, ","))
	end
	local function itemById(id)
		for _, it in ipairs(G.ShopItems) do
			if it.id == id then
				return it
			end
		end
	end
	pr.Triggered:Connect(function(p)
		if docked then
			Fx:FireClient(p, "ShopOpen", { stock = stock })
		end
	end)
	task.spawn(function()
		local i = 1
		while true do
			local dock = G.MerchantDocks[i]
			rollStock()
			docked = true
			pr.Enabled = true
			root:SetAttribute("Docked", dock.name)
			task.wait(G.MERCHANT_DOCK_TIME)
			docked = false
			pr.Enabled = false
			root:SetAttribute("Docked", "")
			i = i % #G.MerchantDocks + 1
			local a, b = root.Position, G.MerchantDocks[i].pos
			local t0 = os.clock()
			while os.clock() - t0 < G.MERCHANT_TRAVEL_TIME do
				local k = (os.clock() - t0) / G.MERCHANT_TRAVEL_TIME
				local e = k * k * (3 - 2 * k)
				local pos = a:Lerp(b, e) + Vector3.new(0, math.sin(k * math.pi) * 60, 0) -- climbs while travelling
				local dir = (b - a) * Vector3.new(1, 0, 1)
				root.CFrame = CFrame.lookAt(pos, pos + (dir.Magnitude > 1 and dir or Vector3.new(0, 0, 1)))
				task.wait(0.1)
			end
			root.CFrame = CFrame.lookAt(b, b + ((b - a) * Vector3.new(1, 0, 1)))
		end
	end)
	Combat.OnServerEvent:Connect(function(p, action, id)
		if action ~= "buy" then
			return
		end
		local d = data[p]
		local it = itemById(id)
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not d or not it or not docked or not table.find(stock, id) or not hrp or (hrp.Position - root.Position).Magnitude > 70 then
			return
		end
		if d.ink < it.price then
			Fx:FireClient(p, "Toast", { text = "NOT ENOUGH INK", color = Color3.fromRGB(255, 120, 120) })
			return
		end
		local now = workspace:GetServerTimeNow()
		if it.id == "map" then
			local best, bd
			for _, c in ipairs(workspace.World.Gate.Life:GetDescendants()) do
				if c:IsA("BasePart") and c:GetAttribute("ChestId") and not d.chests[tostring(c:GetAttribute("ChestId"))] then
					local dist = (c.Position - hrp.Position).Magnitude
					if not bd or dist < bd then
						best, bd = c, dist
					end
				end
			end
			if not best then
				Fx:FireClient(p, "Toast", { text = "YOU HAVE ALREADY FOUND EVERY CHEST!", color = Color3.fromRGB(255, 215, 90) })
				return
			end
			d.ink -= it.price
			Fx:FireClient(p, "MapReveal", { pos = best.Position })
		else
			d.ink -= it.price
			if it.buff then
				p:SetAttribute(it.buff, math.max(now, p:GetAttribute(it.buff) or 0) + it.dur)
			elseif it.id == "feathers" then
				d.feathers += 4
			elseif it.id == "crystal" then
				local keys = {}
				for k in pairs(G.ESSENCES) do
					table.insert(keys, k)
				end
				table.sort(keys)
				local k = keys[rng:NextInteger(1, #keys)]
				d.essence[k] = (d.essence[k] or 0) + 6
				Fx:FireClient(p, "Toast", { text = "+6 " .. k:upper() .. " ESSENCE", color = G.ESSENCES[k].color })
			elseif it.id == "basket" then
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Health = hum.MaxHealth
				end
			end
		end
		Fx:FireClient(p, "Bought", { id = id })
		sync(p)
	end)

	-- SKY SHOWERS
	local showerBusy = false
	local function runShower()
		if showerBusy then
			return
		end
		showerBusy = true
		do
			workspace:SetAttribute("IslandShower", true)
			Fx:FireAllClients("Toast", { text = "A SKY SHOWER SWEEPS THE ISLES... GOLDEN MONSTERS ARE OUT!", color = Color3.fromRGB(140, 210, 255) })
			local golden = {}
			for k = 1, 4 do
				local kind = G.GOLDEN_KINDS[rng:NextInteger(1, #G.GOLDEN_KINDS)]
				local spot = G.GOLDEN_SPOTS[rng:NextInteger(1, #G.GOLDEN_SPOTS)] + Vector3.new(rng:NextNumber(-25, 25), 6 + k, rng:NextNumber(-25, 25))
				local def = G.Enemies[kind]
				local ok, part = pcall(spawnEnemy, kind, spot, nil, { level = def.level + 4 })
				if ok and part then
					local st = enemies[part]
					if st then
						st.rare = true
						st.xp *= 5
						st.ink *= 6
						part:SetAttribute("Rare", true)
						table.insert(golden, part)
					end
				end
			end
			task.wait(G.SHOWER_LEN)
			workspace:SetAttribute("IslandShower", false)
			workspace:SetAttribute("Rainbow", workspace:GetServerTimeNow() + 75)
			for _, part in ipairs(golden) do -- the golden ones fade with the rain
				if enemies[part] then
					enemies[part] = nil
					part:Destroy()
				end
			end
		end
		showerBusy = false
	end
	_G.InkwingShower = function()
		task.spawn(runShower)
	end
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(G.SHOWER_EVERY[1], G.SHOWER_EVERY[2]))
			runShower()
		end
	end)
end

---------------------------------------------------------------------------
-- v1.6 SYSTEMS: feather plumes, monster behaviours, elite affixes, boss arena mechanics,
-- sky shrines, perches, world events (Leviathan migration, falling stars)
---------------------------------------------------------------------------
do
	local function knock(p, v)
		Fx:FireClient(p, "Knock", { v = v })
	end
	local function nearestEnemies(pos, r, n, skip)
		local out = {}
		for part, st in pairs(enemies) do
			if part ~= skip and not st.def.giant then
				local d = (part.Position - pos).Magnitude
				if d < r then
					table.insert(out, { part = part, d = d })
				end
			end
		end
		table.sort(out, function(a, b)
			return a.d < b.d
		end)
		local res = {}
		for i = 1, math.min(n, #out) do
			res[i] = out[i].part
		end
		return res
	end
	local function hasPlume(p, id)
		local d = data[p]
		return d and d.equip and table.find(d.equip, id) ~= nil
	end

	-------------------------------------------------------------------
	-- OBSTACLE AVOIDANCE for flying monsters
	-------------------------------------------------------------------
	local avoidRP = RaycastParams.new()
	avoidRP.FilterType = Enum.RaycastFilterType.Include
	avoidRP.RespectCanCollide = true
	avoidRP.FilterDescendantsInstances = { workspace:FindFirstChild("World") or workspace }
	Hooks.avoid = function(part, st, pos, goal)
		local mv = goal - pos
		local step = mv.Magnitude
		if step < 0.05 or st.def.giant then
			return goal
		end
		local rad = math.clamp((st.def.size or 4) * 0.5, 2, 10)
		local dir = mv / step
		local hit = workspace:Raycast(pos, dir * (step + rad + 4), avoidRP)
		if not hit then
			-- also never sink into the ground below
			local down = workspace:Raycast(goal + Vector3.new(0, 2, 0), Vector3.new(0, -(rad + 2), 0), avoidRP)
			if down then
				return Vector3.new(goal.X, math.max(goal.Y, down.Position.Y + rad), goal.Z)
			end
			return goal
		end
		-- slide along the surface and climb over it
		local n = hit.Normal
		local slide = dir - n * dir:Dot(n)
		local up = Vector3.new(0, 1, 0)
		local new = slide.Magnitude > 0.05 and (slide.Unit * 0.6 + up * 0.8).Unit or up
		st.climbUntil = os.clock() + 0.6
		return pos + new * math.max(step, st.speed * 0.08)
	end

	-------------------------------------------------------------------
	-- PLUMES
	-------------------------------------------------------------------
	local function givePlume(p, id, why)
		local d = data[p]
		if not d then
			return
		end
		if not id then
			local tot = 0
			for _, k in ipairs(G.PLUME_ORDER) do
				tot += G.Plumes[k].w
			end
			local r = rng:NextNumber() * tot
			for _, k in ipairs(G.PLUME_ORDER) do
				r -= G.Plumes[k].w
				if r <= 0 then
					id = k
					break
				end
			end
			id = id or "split"
		end
		local first = (d.plumes[id] or 0) == 0
		d.plumes[id] = (d.plumes[id] or 0) + 1
		local pl = G.Plumes[id]
		if first then
			Fx:FireClient(p, "PlumeGet", { id = id, why = why })
		else
			-- duplicates melt into ink + essence
			d.ink += 200
			Fx:FireClient(p, "Toast", { text = "DUPLICATE " .. pl.name .. " MELTS INTO +200 INK", color = pl.color })
		end
		-- auto-equip into a free slot
		if first and #d.equip < G.PlumeSlots(d.rank) then
			table.insert(d.equip, id)
		end
		sync(p)
	end
	Hooks.givePlume = givePlume
	local hitCount = {}
	Hooks.plumeHit = function(p, tgt, dmg, crit)
		local d = data[p]
		if not d or not d.equip or #d.equip == 0 then
			return
		end
		local pos = tgt.Position
		if hasPlume(p, "split") then
			for _, o in ipairs(nearestEnemies(pos, 28, 2, tgt)) do
				Fx:FireAllClients("Shot", { from = pos, to = o.Position, color = G.Plumes.split.color, player = p })
				task.delay(0.15, function()
					damageEnemy(o, dmg * 0.5, p, false)
				end)
			end
		end
		if hasPlume(p, "storm") then
			hitCount[p] = (hitCount[p] or 0) + 1
			if hitCount[p] % 5 == 0 then
				local pts = { pos }
				for _, o in ipairs(nearestEnemies(pos, 45, 3, tgt)) do
					table.insert(pts, o.Position)
					damageEnemy(o, dmg * 0.8, p, false)
				end
				Fx:FireAllClients("Chain", { pts = pts })
			end
		end
		if hasPlume(p, "ember") and enemies[tgt] then
			local est = enemies[tgt]
			if not est.burning or est.burning < os.clock() then
				est.burning = os.clock() + 3
				task.spawn(function()
					for _ = 1, 3 do
						task.wait(1)
						if enemies[tgt] then
							Fx:FireAllClients("Burn", { pos = tgt.Position })
							damageEnemy(tgt, dmg * 0.12, p, false)
						end
					end
				end)
			end
		end
		if hasPlume(p, "blood") then
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + dmg * 0.05)
			end
		end
		if crit and hasPlume(p, "echo") and enemies[tgt] then
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				Fx:FireAllClients("Shot", { from = hrp.Position, to = pos, color = G.Plumes.echo.color, player = p })
				task.delay(0.25, function()
					damageEnemy(tgt, dmg, p, true)
				end)
			end
		end
	end
	Hooks.ignore = function(st, p, now)
		if st.def.boss or st.def.giant or not hasPlume(p, "moth") then
			return false
		end
		local ps = S[p]
		if st.hostile and st.hostile[p] and st.hostile[p] > now then
			return false
		end
		return ps and os.clock() - (ps.lastShotT or 0) > 3 and p:GetAttribute("Flying") == true
	end
	local inkPools = {}
	task.spawn(function()
		while true do
			task.wait(0.3)
			local now = os.clock()
			for i = #inkPools, 1, -1 do
				local pool = inkPools[i]
				if now > pool.t then
					table.remove(inkPools, i)
				else
					for part, st in pairs(enemies) do
						if not st.def.boss and not st.def.giant and (part.Position - pool.pos).Magnitude < 16 then
							st.rootUntil = now + 0.5
						end
					end
				end
			end
		end
	end)
	Combat.OnServerEvent:Connect(function(p, action, id, ...)
		local d = data[p]
		if not d then
			return
		end
		if action == "equip" and type(id) == "string" and G.Plumes[id] and (d.plumes[id] or 0) > 0 and not table.find(d.equip, id) then
			if #d.equip >= G.PlumeSlots(d.rank) then
				table.remove(d.equip, 1)
			end
			table.insert(d.equip, id)
			sync(p)
		elseif action == "unequip" and type(id) == "string" then
			local i = table.find(d.equip, id)
			if i then
				table.remove(d.equip, i)
				sync(p)
			end
		elseif action == "slam" and typeof(id) == "Vector3" then
			local ps = S[p]
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if ps and hrp and os.clock() > (ps.nextSlam or 0) and (hrp.Position - id).Magnitude < 25 then
				ps.nextSlam = os.clock() + 2
				local speed = math.clamp(tonumber(select(1, ...)) or 120, 100, 260)
				local k = speed / 120
				local R = 16 + 10 * k
				Fx:FireAllClients("Slam", { pos = id, r = R, player = p })
				local base = power(p)
				for _, o in ipairs(nearestEnemies(id, R, 12)) do
					local st = enemies[o]
					if st and not st.def.giant then
						if not st.def.boss then
							local away = o.Position - id
							away = Vector3.new(away.X, 0, away.Z)
							away = (away.Magnitude > 0.1 and away.Unit or Vector3.xAxis) * 14 + Vector3.new(0, 10, 0)
							o.CFrame = o.CFrame + away
							st.rootUntil = os.clock() + 1.2 -- dazed
						end
						damageEnemy(o, base * 1.6 * k, p, false)
					end
				end
			end
		elseif action == "boost" and hasPlume(p, "gale") then
			local ps = S[p]
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if ps and hrp and os.clock() > (ps.nextGale or 0) then
				ps.nextGale = os.clock() + 3
				local base = power(p)
				Fx:FireAllClients("GaleBlast", { pos = hrp.Position })
				for _, o in ipairs(nearestEnemies(hrp.Position, 30, 8)) do
					local st = enemies[o]
					if st and not st.def.boss then
						local away = (o.Position - hrp.Position)
						away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 1, 0)
						o.CFrame = o.CFrame + away * 18
					end
					damageEnemy(o, base * 0.6, p, false)
				end
			end
		end
	end)

	-------------------------------------------------------------------
	-- ELITES (spawn) + damage taken
	-------------------------------------------------------------------
	Hooks.spawn = function(part, st, opts)
		-- v1.9 the HIDDEN BLOB: looks like any other blob until Mana Vision sees through it
		if st and st.kind == "InkBlob" and st.spawnIdx == 1 and not (opts and opts.noElite) and rng:NextNumber() < 0.12 then
			st.hidden = true
			st.lvl += 3
			st.maxhp = math.floor(st.maxhp * 1.8)
			st.hp = st.maxhp
			st.dmg *= 1.3
			st.xp *= 3
			st.ink *= 3
			part:SetAttribute("Level", st.lvl)
			part:SetAttribute("MaxHP", st.maxhp)
			part:SetAttribute("HP", st.hp)
			part:SetAttribute("Conceal", true)
			return
		end
		if not st or st.def.boss or st.def.giant or st.def.peaceful or (opts and opts.noElite) or st.spawnIdx == 1 then
			return
		end
		if rng:NextNumber() > G.ELITE_CHANCE then
			return
		end
		local id = G.AFFIX_ORDER[rng:NextInteger(1, #G.AFFIX_ORDER)]
		st.elite = id
		st.maxhp = math.floor(st.maxhp * 2.5)
		st.hp = st.maxhp
		st.dmg *= 1.4
		st.xp *= 3
		st.ink *= 3
		if id == "swift" then
			st.speed *= 1.7
		end
		part:SetAttribute("MaxHP", st.maxhp)
		part:SetAttribute("HP", st.hp)
		part:SetAttribute("Affix", id)
		part:SetAttribute("Scale", 1.35)
	end
	Hooks.taken = function(part, st, p, amount)
		if st.elite == "shielded" and st.hp > st.maxhp * 0.5 then
			amount *= 0.3
		end
		if st.shieldUntil and os.clock() < st.shieldUntil then
			amount *= 0.5
		end
		return amount
	end

	-------------------------------------------------------------------
	-- BEHAVIOURS (think = every 0.1 s per monster; return true = I moved it myself)
	-------------------------------------------------------------------
	local ANGELS = { HaloSentinel = true, GildedMoth = true, Seraphim = true, Throne = true }
	Hooks.think = function(part, st, tgt, chars, now)
		local pos = part.Position
		local kind = st.kind
		-- elite affixes
		if st.elite == "vampiric" and st.hp < st.maxhp then
			st.hp = math.min(st.maxhp, st.hp + st.maxhp * 0.0015)
			part:SetAttribute("HP", st.hp)
		elseif st.elite == "gale" and tgt and now > (st.nextAff or 0) and (tgt.hrp.Position - pos).Magnitude < 32 then
			st.nextAff = now + 4
			local away = (tgt.hrp.Position - pos)
			Fx:FireAllClients("GalePulse", { pos = pos })
			knock(tgt.p, (away.Magnitude > 0.1 and away.Unit or Vector3.yAxis) * 130)
		elseif st.elite == "anchored" and tgt and now > (st.nextAff or 0) and (tgt.hrp.Position - pos).Magnitude < 75 then
			st.nextAff = now + 5
			local to = (pos - tgt.hrp.Position)
			Fx:FireAllClients("AnchorPull", { from = pos, to = tgt.hrp.Position })
			knock(tgt.p, to.Unit * math.min(110, to.Magnitude * 2.2))
		end
		-- parasites ride along with the Leviathan
		if st.rideOf then
			local root = st.rideOf
			if root.Parent then
				st.home = root.Position + st.rideOff
				if not tgt then
					part.CFrame = CFrame.new(part.Position:Lerp(st.home, 0.15))
					return true
				end
			end
		end
		-- v1.9 a hurt blob FLEES to a brother and merges into it
		if kind == "InkBlob" and st.blobFlee then
			local o = st.blobFlee
			local os2 = enemies[o]
			if not (o.Parent and os2) then
				st.blobFlee = nil
			else
				local to = o.Position - pos
				if to.Magnitude < 6 then
					enemies[part] = nil
					if st.spawnIdx then
						spawnCount[st.spawnIdx] -= 1
					end
					Fx:FireAllClients("Merge", { from = pos, to = o.Position })
					part:Destroy()
					os2.merged = (os2.merged or 1) + 1
					os2.maxhp = math.floor(os2.maxhp * 1.6)
					os2.hp = math.min(os2.maxhp, os2.hp + st.hp + os2.maxhp * 0.3)
					os2.dmg *= 1.3
					os2.xp = math.floor(os2.xp * 1.7)
					os2.ink = math.floor(os2.ink * 1.7)
					os2.target = st.target
					o:SetAttribute("MaxHP", os2.maxhp)
					o:SetAttribute("HP", os2.hp)
					o:SetAttribute("Scale", math.min(2.6, 1 + (os2.merged - 1) * 0.4))
					return true
				end
				local np = pos + to.Unit * math.min(to.Magnitude, st.speed * 1.7 * 0.1)
				part.CFrame = CFrame.lookAt(np, np + to.Unit)
				return true
			end
		end
		-- INK BLOBS merge when left alone (up to 3x)
		if kind == "InkBlob" and st.spawnIdx ~= 1 and not tgt and not st.elite and (st.merged or 1) < 3 and now > (st.nextMerge or 0) then
			st.nextMerge = now + 2 + rng:NextNumber() * 2
			for other, os2 in pairs(enemies) do
				if other ~= part and os2.kind == "InkBlob" and not os2.target and not os2.elite and (os2.merged or 1) < 3 and (other.Position - pos).Magnitude < 14 then
					enemies[other] = nil
					if os2.spawnIdx then
						spawnCount[os2.spawnIdx] -= 1
					end
					Fx:FireAllClients("Merge", { from = other.Position, to = pos })
					other:Destroy()
					st.merged = (st.merged or 1) + 1
					st.maxhp = math.floor(st.maxhp * 1.7)
					st.hp = st.maxhp
					st.dmg *= 1.4
					st.xp = math.floor(st.xp * 1.8)
					st.ink = math.floor(st.ink * 1.8)
					part:SetAttribute("MaxHP", st.maxhp)
					part:SetAttribute("HP", st.hp)
					part:SetAttribute("Scale", 1 + (st.merged - 1) * 0.45)
					break
				end
			end
		end
		-- SCRIBBLE BATS flee when hurt, then come back with the swarm
		if st.fleeUntil then
			if now < st.fleeUntil then
				local away = pos - (st.fleeFrom or pos)
				away = Vector3.new(away.X, math.abs(away.Y) * 0.3 + 4, away.Z)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.yAxis
				local np = pos + away * st.speed * 1.5 * 0.1
				part.CFrame = CFrame.lookAt(np, np + away)
				return true
			else
				st.fleeUntil = nil
				local who = st.fleeBy
				if who then
					for other, os2 in pairs(enemies) do
						if os2.kind == "ScribbleBat" and (other.Position - pos).Magnitude < 160 then
							os2.target = who
							os2.hostile[who] = now + 30
						end
					end
					Fx:FireAllClients("Swarm", { pos = pos })
				end
			end
		end
		-- ASH WRAITHS blink behind you
		if kind == "AshWraith" and tgt and now > (st.nextBlink or 0) and (tgt.hrp.Position - pos).Magnitude < 90 then
			st.nextBlink = now + 6 + rng:NextNumber() * 3
			local look = tgt.hrp.CFrame.LookVector
			local np = tgt.hrp.Position - look * 9 + Vector3.new(0, 3, 0)
			Fx:FireAllClients("Blink", { from = pos, to = np })
			part.CFrame = CFrame.lookAt(np, tgt.hrp.Position)
			return true
		end
		return false
	end
	Hooks.hit = function(part, st, p, amount)
		local now = os.clock()
		local kind = st.kind
		if kind == "InkBlob" and st.spawnIdx ~= 1 and not st.fled and not st.hidden and st.hp < st.maxhp * 0.35 and st.hp > 0 then
			st.fled = true
			local best, bd = nil, 120
			for other, os2 in pairs(enemies) do
				if other ~= part and os2.kind == "InkBlob" and not os2.blobFlee and (other.Position - part.Position).Magnitude < bd then
					best, bd = other, (other.Position - part.Position).Magnitude
				end
			end
			st.blobFlee = best
		elseif kind == "ScribbleBat" and not st.fled and st.hp < st.maxhp * 0.35 then
			st.fled = true
			st.fleeUntil = now + 3.5
			st.fleeBy = p
			local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			st.fleeFrom = hrp and hrp.Position or part.Position
		elseif kind == "PaperWasp" and now > (st.nextCall or 0) then
			st.nextCall = now + 6
			Fx:FireAllClients("WaspCall", { pos = part.Position })
			for other, os2 in pairs(enemies) do
				if os2.kind == "PaperWasp" and (other.Position - part.Position).Magnitude < 140 then
					os2.target = p
					if p then
						os2.hostile[p] = now + 30
					end
					if not os2.enraged then
						os2.enraged = true
						os2.speed *= 1.35
					end
				end
			end
		elseif ANGELS[kind] and now > (st.nextShieldCall or 0) then
			st.nextShieldCall = now + 6
			for other, os2 in pairs(enemies) do
				if ANGELS[os2.kind] and (other.Position - part.Position).Magnitude < 100 then
					os2.shieldUntil = now + 2.5
					Fx:FireAllClients("EShield", { part = other, t = 2.5 })
				end
			end
		end
	end
	local blobKills, motherAlive = 0, false
	Hooks.death = function(part, st, p)
		local pos = part.Position
		-- v1.9 BLOB MOTHER: thin the hunting grounds and she comes for her children
		if st.kind == "BlobMother" then
			motherAlive = false
		elseif st.kind == "InkBlob" and st.spawnIdx == 1 and not motherAlive then
			blobKills += 1
			if blobKills >= 10 then
				blobKills = 0
				motherAlive = true
				local c = G.Spawns[1].center
				task.delay(4, function()
					local ok, m = pcall(spawnEnemy, "BlobMother", c + Vector3.new(0, 6, 0), nil, { noElite = true })
					if ok and m and enemies[m] then
						enemies[m].target = p
						Fx:FireAllClients("Merge", { from = c + Vector3.new(0, 30, 0), to = c })
					else
						motherAlive = false
					end
				end)
			end
		end
		if st.elite == "mirrored" then
			task.delay(0.1, function()
				for k = -1, 1, 2 do
					local ok, np = pcall(spawnEnemy, st.kind, pos + Vector3.new(k * 6, 2, 0), nil, { level = st.lvl, noElite = true })
					if ok and np and enemies[np] then
						enemies[np].target = p
					end
				end
				Fx:FireAllClients("Mirror", { pos = pos })
			end)
		end
		if st.elite == "volatile" or st.kind == "CinderImp" then
			telegraph(pos, st.elite and 18 or 12, 0.9, st.dmg * 1.3)
		end
		-- plume drops
		if st.def.boss then
			for who in pairs(st.dmgBy) do
				if typeof(who) == "Instance" and data[who] then
					givePlume(who, nil, st.def.name)
				end
			end
		elseif p and data[p] then
			if st.rare and rng:NextNumber() < 0.5 then
				givePlume(p, nil, "GOLDEN " .. st.def.name)
			elseif st.elite and rng:NextNumber() < 0.2 then
				givePlume(p, nil, "ELITE " .. st.def.name)
			end
			if hasPlume(p, "ink") then
				table.insert(inkPools, { pos = pos, t = os.clock() + 5 })
				Fx:FireAllClients("InkPool", { pos = pos, t = 5 })
			end
		end
	end

	-------------------------------------------------------------------
	-- BOSS ARENA MECHANICS (on top of the existing 3 phases)
	-------------------------------------------------------------------
	local MECH = {
		BlotKing = { "INK FLOOD", "THE WHIRLPOOL" },
		CinderKing = { "ERUPTION", "METEOR RAIN" },
		Inkvern = { "TIDAL WAVE", "THE MAELSTROM" },
		CometEater = { "GRAVITY WELL", "SUPERNOVA" },
	}
	Hooks.boss = function(part, st, chars, now)
		local phase = st.phase or 1
		if phase ~= (st.seenPhase or 1) then
			st.seenPhase = phase
			Fx:FireAllClients("BossPhase", { pos = part.Position, phase = phase, name = st.def.name })
		end
		if phase < 2 or now < (st.nextMech or 0) then
			return
		end
		local near = {}
		for _, c in ipairs(chars) do
			if (c.hrp.Position - part.Position).Magnitude < 160 then
				table.insert(near, c)
			end
		end
		if #near == 0 then
			return
		end
		st.nextMech = now + (phase >= 3 and 7 or 9)
		local m = MECH[st.kind] or { "SHOCKWAVE", "CATACLYSM" }
		local name = m[phase >= 3 and 2 or 1]
		Fx:FireAllClients("Announce", { text = st.def.name .. ": " .. name .. "!", color = Color3.fromRGB(255, 90, 60) })
		local bp = part.Position
		if name == "INK FLOOD" or name == "ERUPTION" or name == "SHOCKWAVE" then
			for _, c in ipairs(near) do
				telegraph(c.hrp.Position, 12, 1.4, st.dmg * 0.8)
			end
			for _ = 1, 4 do
				telegraph(bp + Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(-8, 8), rng:NextNumber(-45, 45)), 12, 1.6, st.dmg * 0.8)
			end
		elseif name == "THE WHIRLPOOL" or name == "GRAVITY WELL" or name == "THE MAELSTROM" then
			for _, c in ipairs(near) do
				local to = bp - c.hrp.Position
				knock(c.p, to.Unit * math.min(120, to.Magnitude * 1.6))
			end
			Fx:FireAllClients("AnchorPull", { from = bp, to = bp + Vector3.new(0, 1, 0), big = true })
			task.delay(1.2, function()
				telegraph(bp, 34, 1.4, st.dmg * 1.4)
			end)
		elseif name == "TIDAL WAVE" then
			for _, c in ipairs(near) do
				local away = c.hrp.Position - bp
				knock(c.p, away.Unit * 150 + Vector3.new(0, 40, 0))
				hurtPlayer(c.p, c.hum, st.dmg * 0.6)
			end
			Fx:FireAllClients("GalePulse", { pos = bp, big = true })
		elseif name == "METEOR RAIN" or name == "CATACLYSM" then
			for _ = 1, 9 do
				local c = near[rng:NextInteger(1, #near)]
				telegraph(c.hrp.Position + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25)), 10, 1.2 + rng:NextNumber() * 1.2, st.dmg * 0.9)
			end
		elseif name == "SUPERNOVA" then
			telegraph(bp, 48, 2.6, st.dmg * 2)
		end
	end

	if G.REALM == "Overworld" then
		-------------------------------------------------------------------
		-- SKY SHRINES
		-------------------------------------------------------------------
		task.spawn(function()
			local life = workspace:WaitForChild("World"):WaitForChild("Gate"):WaitForChild("Life", 30)
			if not life then
				return
			end
			local shrines = {}
			for _, b in ipairs(life:GetDescendants()) do
				if b:IsA("BasePart") and b:GetAttribute("ShrineId") then
					local sid = b:GetAttribute("ShrineId")
					shrines[sid] = shrines[sid] or { braziers = {}, who = {}, t0 = nil, busy = false }
					table.insert(shrines[sid].braziers, b)
				end
			end
			for sid, sh in pairs(shrines) do
				local def
				for _, sd in ipairs(G.Shrines) do
					if sd.id == sid then
						def = sd
					end
				end
				local function reset()
					for _, b in ipairs(sh.braziers) do
						b:SetAttribute("Lit", false)
						local pr = b:FindFirstChildOfClass("ProximityPrompt")
						if pr then
							pr.Enabled = true
						end
					end
					sh.t0, sh.who = nil, {}
				end
				for _, b in ipairs(sh.braziers) do
					local pr = Instance.new("ProximityPrompt")
					pr.ActionText = "Light"
					pr.ObjectText = def and def.name or "Brazier"
					pr.HoldDuration = 0
					pr.MaxActivationDistance = 12
					pr.RequiresLineOfSight = false
					pr.Parent = b
					pr.Triggered:Connect(function(p)
						if sh.busy or b:GetAttribute("Lit") then
							return
						end
						b:SetAttribute("Lit", true)
						pr.Enabled = false
						sh.who[p] = true
						if not sh.t0 then
							sh.t0 = os.clock()
							local myT = sh.t0
							Fx:FireAllClients("ShrineStart", { id = sid, t = G.SHRINE_TIME, name = def and def.name })
							task.delay(G.SHRINE_TIME, function()
								if sh.t0 == myT and not sh.busy then
									Fx:FireAllClients("Toast", { text = (def and def.name or "THE SHRINE") .. ": THE FLAMES DIE OUT. TRY AGAIN.", color = Color3.fromRGB(255, 150, 120) })
									reset()
								end
							end)
						end
						local all = true
						for _, b2 in ipairs(sh.braziers) do
							if not b2:GetAttribute("Lit") then
								all = false
							end
						end
						if all then
							sh.busy = true
							Fx:FireAllClients("ShrineDone", { id = sid, pos = sh.braziers[1].Position })
							for who in pairs(sh.who) do
								local d = data[who]
								if d then
									if not d.shrines[sid] then
										d.shrines[sid] = true
										givePlume(who, def and def.plume, def and def.name)
									else
										d.ink += 300
										addXP(who, 60)
										Fx:FireClient(who, "Toast", { text = "THE SHRINE BLESSES YOU AGAIN: +300 INK +60 XP", color = Color3.fromRGB(255, 220, 140) })
										sync(who)
									end
								end
							end
							task.delay(6, function()
								sh.busy = false
								reset()
							end)
						end
					end)
				end
			end
		end)

		-------------------------------------------------------------------
		-- PERCHES: stand still on a tree top, crag or ruin column to gather mana
		-------------------------------------------------------------------
		local PERCH = { Leaves = true, Needles = true, PineTip = true, Crag = true, RuinColumn = true, ChainPost = true, ShrinePillar = true, PillarCap = true, Frond = true }
		task.spawn(function()
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			while true do
				task.wait(1)
				for _, p in ipairs(Players:GetPlayers()) do
					local d = data[p]
					local c = p.Character
					local hrp = c and c:FindFirstChild("HumanoidRootPart")
					if d and hrp then
						rp.FilterDescendantsInstances = { c }
						local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp)
						local perched = hit and PERCH[hit.Instance.Name] and hrp.AssemblyLinearVelocity.Magnitude < 2 and not p:GetAttribute("Meditating")
						if perched then
							d.mana = math.min(d.manaMax, d.mana + math.max(0.3, d.manaMax * 0.03)) -- perching rests you
							p:SetAttribute("Mana", math.floor(d.mana))
						end
						if (p:GetAttribute("Perched") == true) ~= (perched == true) then
							p:SetAttribute("Perched", perched == true)
						end
					end
				end
			end
		end)

		-------------------------------------------------------------------
		-- WORLD EVENT: THE LEVIATHAN MIGRATION
		-------------------------------------------------------------------
		local levBusy = false
		local function leviathan()
			if levBusy then
				return
			end
			levBusy = true
			local root = Instance.new("Part")
			root.Name = "LeviathanRoot"
			root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
			root.Transparency = 1
			root.Size = Vector3.new(20, 20, 140)
			local a, b = Vector3.new(-1700, 230, 380), Vector3.new(1700, 230, 260)
			root.CFrame = CFrame.lookAt(a, b)
			root.Parent = workspace
			Fx:FireAllClients("Announce", { text = "THE SKY LEVIATHAN IS PASSING OVER THE GENESIS ISLES!", color = Color3.fromRGB(140, 220, 255) })
			Fx:FireAllClients("Toast", { text = "CLEAR THE PARASITES FROM ITS BACK BEFORE IT LEAVES FOR ITS GIFT", color = Color3.fromRGB(180, 230, 255) })
			local parasites = {}
			for k = 1, 7 do
				local off = Vector3.new(rng:NextNumber(-14, 14), 16 + rng:NextNumber(0, 8), (k - 4) * 14)
				local kind = k % 3 == 0 and "PaperWasp" or "ScribbleBat"
				local ok, part = pcall(spawnEnemy, kind, root.Position + off, nil, { level = 10, noElite = true })
				if ok and part and enemies[part] then
					local st = enemies[part]
					st.rideOf, st.rideOff = root, off
					st.xp *= 3
					st.ink *= 3
					part:SetAttribute("Parasite", true)
					table.insert(parasites, part)
				end
			end
			local helpers = {}
			local t0 = os.clock()
			local gifted = false
			while os.clock() - t0 < G.LEVIATHAN_TIME do
				local k = (os.clock() - t0) / G.LEVIATHAN_TIME
				local pos = a:Lerp(b, k) + Vector3.new(0, math.sin(k * math.pi * 3) * 25, 0)
				root.CFrame = CFrame.lookAt(pos, pos + (b - a).Unit)
				local alive = 0
				for _, pp in ipairs(parasites) do
					local st = enemies[pp]
					if st then
						alive += 1
						for who in pairs(st.dmgBy) do
							helpers[who] = true
						end
					end
				end
				if alive == 0 and not gifted then
					gifted = true
					Fx:FireAllClients("LeviathanGift", { pos = root.Position })
					Fx:FireAllClients("Announce", { text = "THE LEVIATHAN SINGS. ITS GIFT RAINS DOWN!", color = Color3.fromRGB(140, 220, 255) })
					for who in pairs(helpers) do
						if typeof(who) == "Instance" and data[who] then
							data[who].ink += 500
							addXP(who, 200)
							givePlume(who, nil, "THE SKY LEVIATHAN")
							sync(who)
						end
					end
				end
				task.wait(0.1)
			end
			for _, pp in ipairs(parasites) do
				if enemies[pp] then
					enemies[pp] = nil
					pp:Destroy()
				end
			end
			root:Destroy()
			levBusy = false
		end
		_G.InkwingLeviathan = function()
			task.spawn(leviathan)
		end
		task.spawn(function()
			while true do
				task.wait(rng:NextInteger(G.LEVIATHAN_EVERY[1], G.LEVIATHAN_EVERY[2]))
				leviathan()
			end
		end)

		-------------------------------------------------------------------
		-- WORLD EVENT: A FALLING STAR
		-------------------------------------------------------------------
		local function fallingStar()
			local spot = G.GOLDEN_SPOTS[rng:NextInteger(1, #G.GOLDEN_SPOTS)]
			local ray = workspace:Raycast(spot + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
			local pos = ray and ray.Position or spot
			Fx:FireAllClients("StarFall", { pos = pos })
			Fx:FireAllClients("Announce", { text = "A STAR IS FALLING ON THE ISLES!", color = Color3.fromRGB(200, 180, 255) })
			task.wait(2.6)
			local shard = Instance.new("Part")
			shard.Name = "StarShard"
			shard.Shape = Enum.PartType.Ball
			shard.Size = Vector3.one * 4
			shard.Material = Enum.Material.Neon
			shard.Color = Color3.fromRGB(200, 190, 255)
			shard.Anchored, shard.CanCollide = true, false
			shard.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
			shard.Parent = workspace
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = Color3.fromRGB(200, 180, 255), 40, 3
			l.Parent = shard
			local claimed = {}
			local n = 0
			local pr = Instance.new("ProximityPrompt")
			pr.ActionText = "Claim"
			pr.ObjectText = "Fallen Star"
			pr.HoldDuration = 1
			pr.MaxActivationDistance = 12
			pr.RequiresLineOfSight = false
			pr.Parent = shard
			pr.Triggered:Connect(function(p)
				local d = data[p]
				if not d or claimed[p] or n >= 4 then
					return
				end
				claimed[p] = true
				n += 1
				d.essence.Cosmic = (d.essence.Cosmic or 0) + 8
				d.ink += 300
				addXP(p, 120)
				if n == 1 or rng:NextNumber() < 0.3 then
					givePlume(p, nil, "THE FALLEN STAR")
				end
				Fx:FireClient(p, "Toast", { text = "+8 COSMIC ESSENCE  +300 INK  +120 XP", color = Color3.fromRGB(200, 180, 255) })
				sync(p)
				if n >= 4 then
					shard:Destroy()
				end
			end)
			pcall(spawnEnemy, "StarWisp", pos + Vector3.new(0, 14, 0), nil, { level = 12, noElite = true })
			task.delay(150, function()
				if shard.Parent then
					shard:Destroy()
				end
			end)
		end
		_G.InkwingStar = function()
			task.spawn(fallingStar)
		end
		task.spawn(function()
			while true do
				task.wait(rng:NextInteger(G.STAR_EVERY[1], G.STAR_EVERY[2]))
				fallingStar()
			end
		end)
	end
end
