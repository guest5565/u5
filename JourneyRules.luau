-- Pure v0.3 rules. These functions are used by runtime services and CLI tests.
local Journey = {}
local disciplines = {
	{Name = "Unbound", Damage = 1, Focus = 1, Block = 1},
	{Name = "Jade Tiger", Damage = 1.12, Focus = 1, Block = 1},
	{Name = "Cloud Crane", Damage = 1, Focus = 1.25, Block = 1},
	{Name = "Stone Tortoise", Damage = 1, Focus = 1, Block = 0.75},
}
for _, entry in disciplines do table.freeze(entry) end
function Journey.Discipline(id)
	return disciplines[(type(id) == "number" and id % 1 == 0 and id >= 0 and id <= 3) and id + 1 or 1]
end
function Journey.CanRecall(at, lastCombat, cooldown, grounded)
	if not grounded then return false, "Stand on solid ground first." end
	if cooldown > at then return false, "The recall seal is still recovering." end
	if at - lastCombat < 8 then return false, "Leave combat for eight seconds before recalling." end
	return true, ""
end
function Journey.ChannelValid(distance, damageAt, startedAt, alive)
	return alive and distance <= 2.5 and damageAt < startedAt
end
function Journey.Resonance(companions)
	return 1 + math.clamp(math.floor(companions), 0, 3) * 0.10
end
function Journey.AttackSlot(windups, lastStart, at, boss)
	return boss or (windups < 2 and at - lastStart >= 0.55)
end
function Journey.TrainingDPS(damage, elapsed)
	return math.floor(math.max(0, damage) / math.max(1, elapsed) * 10 + 0.5) / 10
end
function Journey.Quality(averageDt, low, stableSeconds)
	if not low and averageDt > 1 / 42 and stableSeconds >= 4 then return true end
	if low and averageDt < 1 / 56 and stableSeconds >= 12 then return false end
	return low
end
return table.freeze(Journey)
