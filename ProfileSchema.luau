-- v3 retains v1/v2 progress and defaults the newly added discipline to Unbound.
-- Pure functions are exercised by tests/rules.spec.luau without a Roblox emulator.
local Schema = {}
Schema.Version = 4
Schema.Defaults = {Realm = 1, Qi = 0, Spirit = 0, Petals = 0, Kills = 0, Quest = 1,
	QuestKills = 0, QuestGather = 0, BossKills = 0, QuestBoss = 0, Shrines = 0, Parries = 0, IntroSeen = 0, Discipline = 0, SilkKills = 0, ValleyQuest = 0, MountainSeal = 0, MatriarchKills = 0}
Schema.Limits = {Realm = 9, Qi = 10000, Spirit = 100000000, Petals = 100000, Kills = 1000000,
	Quest = 4, QuestKills = 1000000, QuestGather = 100000, BossKills = 1000000,
	QuestBoss = 1000000, Shrines = 15, Parries = 1000000, IntroSeen = 1, Discipline = 3, SilkKills = 1000000, ValleyQuest = 2, MountainSeal = 1, MatriarchKills = 100000}
function Schema.Sanitize(data)
	local clean = {}
	for key, default in Schema.Defaults do
		local value = type(data) == "table" and data[key] or default
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then value = default end
		local minimum = (key == "Realm" or key == "Quest") and 1 or 0
		clean[key] = math.clamp(math.floor(value), minimum, Schema.Limits[key])
	end
	return clean
end
function Schema.CanAcquire(old, session, time)
	if type(old) ~= "table" then return true end
	local lease = type(old.Lease) == "number" and old.Lease or 0
	if lease ~= lease or math.abs(lease) == math.huge then lease = 0 end
	return old.Session == nil or old.Session == session or time - lease >= 210
end
return table.freeze(Schema)
