-- Pure combat/progression math, shared with the headless regression tests.
-- No Instances, services, remotes or engine-only types are used in this module.
local Rules = {}
function Rules.Finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end
function Rules.InArc(distance, vertical, dot, range, minimumDot, radial)
	if not (Rules.Finite(distance) and Rules.Finite(vertical) and Rules.Finite(dot)) then return false end
	return distance >= 0 and distance <= range and math.abs(vertical) < 14 and (radial or distance < 0.1 or dot >= minimumDot)
end
function Rules.NextCombo(previous, lastAt, at)
	if at - lastAt > 1.35 then return 1 end
	return previous % 3 + 1
end
function Rules.Damage(base, multiplier, critical)
	return math.max(1, math.floor(base * multiplier * (critical and 1.4 or 1)))
end
function Rules.Guard(at, guardAt, guardUntil, focus, incoming, facingDot)
	if at > guardUntil or at < guardAt or facingDot < 0.05 then return "Hit", incoming, 0 end
	if at - guardAt <= 0.23 then return "Parry", 0, 0 end
	local cost = math.ceil(incoming * 0.65)
	if focus < cost then return "GuardBreak", incoming, focus end
	return "Block", math.ceil(incoming * 0.25), cost
end
function Rules.FocusRegen(realm, meditating)
	return (8 + math.max(0, realm - 1) * 0.6) * (meditating and 1.35 or 1)
end
function Rules.HasShrine(mask, id)
	if id < 1 or id > 4 or id % 1 ~= 0 then return false end
	return bit32.band(mask, bit32.lshift(1, id - 1)) ~= 0
end
function Rules.ClaimShrine(mask, id)
	if id < 1 or id > 4 or id % 1 ~= 0 or Rules.HasShrine(mask, id) then return mask, false end
	return bit32.bor(mask, bit32.lshift(1, id - 1)), true
end
function Rules.Weather(phase)
	phase %= 240
	if phase < 125 then return "Clear", 0 end
	if phase < 150 then return "Gathering", (phase - 125) / 25 end
	if phase < 215 then return "Rain", 1 end
	return "Clearing", 1 - (phase - 215) / 25
end
return table.freeze(Rules)
