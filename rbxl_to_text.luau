--[[ Place file -> readable text outline (small enough for an AI to read in one go).

     lune run lune/rbxl_to_text.luau [Heavensunder.rbxl] [place_overview.txt]

     Prints the whole hierarchy with class names, positions of models, and the important values
     (StringValues, prompts, humanoids, lights …). To keep it short:
       - identical leaf parts under the same parent are merged ("RoofRib [Part] x176")
       - a model with the same structure as one already printed is shown as one line
       - welds/attachments are omitted; Motor6D joints are listed on their parent part
       - script sources are NOT included (they are in scripts/)
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local placePath = process.args[1] or "Heavensunder.rbxl"
local outPath = process.args[2] or "place_overview.txt"
local game = roblox.deserializePlace(fs.readFile(placePath))
local lines = {}
local function out(s) table.insert(lines, s) end

local _db = roblox.getReflectionDatabase()
local _known = {}
-- Lune crashes (not just errors) when reading properties of classes missing from its API database (e.g. Packages)
local function knownClass(inst)
	local c = inst.ClassName
	if _known[c] == nil then _known[c] = _db:GetClass(c) ~= nil end
	return _known[c]
end
local function get(i, k) if not knownClass(i) then return nil end; local ok, v = pcall(function() return i[k] end); if ok then return v end; return nil end
local function v3(v) return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z) end
local function rgb(c) return string.format("rgb(%d,%d,%d)", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end

local function firstPartPos(m)
	local pp = get(m, "PrimaryPart")
	if pp then return pp.CFrame.Position end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then return d.CFrame.Position end
	end
	return nil
end

local function describe(inst)
	if not knownClass(inst) then return "" end
	local c = inst.ClassName
	local bits = {}
	if inst:IsA("BasePart") then
		local s, cf = get(inst, "Size"), get(inst, "CFrame")
		if s then table.insert(bits, "size " .. v3(s)) end
		if cf then table.insert(bits, "at " .. v3(cf.Position)) end
		local col, mat = get(inst, "Color"), get(inst, "Material")
		if col then table.insert(bits, rgb(col)) end
		if mat then table.insert(bits, mat.Name) end
		local t = get(inst, "Transparency"); if t and t > 0 then table.insert(bits, "transp " .. string.format("%.2f", t)) end
	elseif c == "Model" then
		local p = firstPartPos(inst); if p then table.insert(bits, "at " .. v3(p)) end
	elseif c == "StringValue" or c == "NumberValue" or c == "IntValue" or c == "BoolValue" or c == "Vector3Value" or c == "Color3Value" then
		table.insert(bits, "= " .. tostring(get(inst, "Value")))
	elseif c == "Humanoid" then
		table.insert(bits, string.format("HipHeight %s WalkSpeed %s MaxHealth %s", tostring(get(inst, "HipHeight")), tostring(get(inst, "WalkSpeed")), tostring(get(inst, "MaxHealth"))))
	elseif c == "ProximityPrompt" then
		table.insert(bits, string.format("'%s' / '%s'", tostring(get(inst, "ActionText")), tostring(get(inst, "ObjectText"))))
	elseif c == "TextLabel" or c == "TextButton" then
		local t = get(inst, "Text"); if t and t ~= "" then table.insert(bits, "text '" .. string.sub(string.gsub(t, "\n", " "), 1, 60) .. "'") end
	elseif c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" then
		table.insert(bits, string.format("brightness %s range %s", tostring(get(inst, "Brightness")), tostring(get(inst, "Range"))))
	elseif c == "Motor6D" or c == "WeldConstraint" or c == "Weld" then
		local a, b = get(inst, "Part0"), get(inst, "Part1")
		table.insert(bits, (a and a.Name or "?") .. " -> " .. (b and b.Name or "?"))
	elseif inst:IsA("LuaSourceContainer") then
		table.insert(bits, #inst.Source .. " bytes, see scripts/")
	end
	local ok, attrs = pcall(function() return inst:GetAttributes() end)
	if ok then for k, v in attrs do table.insert(bits, "@" .. k .. "=" .. tostring(v)) end end
	return #bits > 0 and ("  " .. table.concat(bits, "  ")) or ""
end

local function isMinor(c)
	return c:IsA("JointInstance") or c.ClassName == "WeldConstraint" or c.ClassName == "Attachment"
end
-- a part whose children are only welds/joints/attachments counts as a leaf
local function leafLike(c)
	if not c:IsA("BasePart") and not isMinor(c) then return false end
	for _, k in c:GetChildren() do if not isMinor(k) then return false end end
	return true
end
local function minorSummary(inst)
	local joints = {}
	for _, k in inst:GetChildren() do
		if k:IsA("JointInstance") and k.ClassName ~= "WeldConstraint" then
			local b = get(k, "Part1"); table.insert(joints, k.Name .. "->" .. (b and b.Name or "?"))
		end
	end
	return #joints > 0 and ("  joints: " .. table.concat(joints, ", ")) or ""
end

local seenModels = {}
local function signature(m)
	local names = {}
	for _, k in m:GetChildren() do table.insert(names, k.Name) end
	table.sort(names)
	return m.ClassName .. "|" .. #m:GetDescendants() .. "|" .. table.concat(names, ",")
end

local function walk(inst, depth)
	local ind = string.rep("  ", depth)
	local kids = inst:GetChildren()
	local head = ind .. inst.Name .. " [" .. inst.ClassName .. "]"
	if #kids > 0 then head ..= " {" .. #inst:GetDescendants() .. "}" end
	if inst.ClassName == "Model" and #inst:GetDescendants() > 15 then
		local sig = signature(inst)
		if seenModels[sig] then
			out(head .. describe(inst) .. "  (same structure as " .. seenModels[sig] .. ")")
			return
		end
		seenModels[sig] = inst.Name
	end
	out(head .. describe(inst) .. (inst:IsA("BasePart") and minorSummary(inst) or ""))
	-- merge same-named leaf parts; skip welds/attachments (summarised on their part)
	local groups, order = {}, {}
	for _, c in kids do
		if isMinor(c) then
			-- summarised via minorSummary / omitted
		elseif leafLike(c) then
			local key = c.Name .. "|" .. c.ClassName
			if not groups[key] then groups[key] = { c }; table.insert(order, { key = key }) else table.insert(groups[key], c) end
		else
			table.insert(order, { inst = c })
		end
	end
	for _, o in order do
		if o.inst then
			walk(o.inst, depth + 1)
		else
			local g = groups[o.key]
			if #g == 1 then
				out(ind .. "  " .. g[1].Name .. " [" .. g[1].ClassName .. "]" .. describe(g[1]) .. minorSummary(g[1]))
			else
				out(ind .. "  " .. g[1].Name .. " [" .. g[1].ClassName .. "] x" .. #g .. "   e.g." .. describe(g[1]))
			end
		end
	end
end

out("# Heavensunder place overview - generated from " .. placePath)
out("# Format: Name [Class] {descendant count}  details.  Positions in studs.  Script code: see scripts/.")
out("")
local skip = { CoreGui = true, CorePackages = true }
for _, service in game:GetChildren() do
	if not skip[service.Name] and (#service:GetChildren() > 0 or service:IsA("Workspace")) then
		walk(service, 0)
	end
end
fs.writeFile(outPath, table.concat(lines, "\n") .. "\n")
print("wrote " .. outPath .. " (" .. #lines .. " lines)")
