-- Engine-independent admission policy: warning effects can evict decoration,
-- never the reverse. Shared by VFXManager and the regression suite.
local Budget = {}
function Budget.Admit(active, priority, cosmeticCap, hardCap)
	if priority == 0 and #active >= cosmeticCap then return false, nil end
	if #active < hardCap then return true, nil end
	for index, item in active do
		if (item.Priority or 0) < priority then return true, index end
	end
	return false, nil
end
return table.freeze(Budget)
