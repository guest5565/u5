--[[ Look inside the binary place file as text (handy for humans and AI assistants).

     lune run lune/inspect.luau tree  [Path.To.Instance] [depth]     -- hierarchy with class + counts
     lune run lune/inspect.luau props Path.To.Instance               -- common properties of one instance
     lune run lune/inspect.luau find  <NamePattern> [ClassName]      -- full names of matching instances
     lune run lune/inspect.luau export Path.To.Instance out.rbxmx    -- save a subtree as an XML model file

     Paths are dot-separated from the DataModel, e.g. Workspace.World.Ground.Buildings
     Set PLACE=... to inspect another file (default Heavensunder.rbxl).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile(process.env.PLACE or "Heavensunder.rbxl"))
local _db = roblox.getReflectionDatabase()
local _known = {}
-- Lune crashes (not just errors) when reading properties of classes missing from its API database (e.g. Packages)
local function knownClass(inst)
	local c = inst.ClassName
	if _known[c] == nil then _known[c] = _db:GetClass(c) ~= nil end
	return _known[c]
end
local cmd = process.args[1] or "tree"

local function resolve(path: string?)
	local node = game
	if not path or path == "" or path == "game" then return node end
	for seg in string.gmatch(path, "[^%.]+") do
		local nxt = node:FindFirstChild(seg)
		if not nxt then error("no child '" .. seg .. "' under " .. node:GetFullName()) end
		node = nxt
	end
	return node
end

local function fmt(v)
	local t = typeof(v)
	if t == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
		return string.format("pos(%.3f, %.3f, %.3f) rot[%.3f %.3f %.3f | %.3f %.3f %.3f | %.3f %.3f %.3f]", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	elseif t == "Vector3" then
		return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
	elseif t == "Color3" then
		return string.format("rgb(%d, %d, %d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif t == "Instance" then
		return v:GetFullName()
	end
	return tostring(v)
end

if cmd == "tree" then
	local root = resolve(process.args[2])
	local maxDepth = tonumber(process.args[3]) or 3
	local function walk(inst, depth)
		local kids = inst:GetChildren()
		local byClass = {}
		for _, c in kids do byClass[c.ClassName] = (byClass[c.ClassName] or 0) + 1 end
		local line = string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]"
		if #kids > 0 then line ..= "  (" .. #inst:GetDescendants() .. " descendants)" end
		print(line)
		if depth >= maxDepth then return end
		-- collapse big groups of same-named leaf parts
		local shown = {}
		for _, c in kids do
			local key = c.Name .. "|" .. c.ClassName
			if #c:GetChildren() == 0 and c:IsA("BasePart") then
				shown[key] = (shown[key] or 0) + 1
				if shown[key] == 1 then
					local n = 0
					for _, o in kids do if o.Name == c.Name and o.ClassName == c.ClassName then n += 1 end end
					print(string.rep("  ", depth + 1) .. c.Name .. " [" .. c.ClassName .. "]" .. (n > 1 and (" x" .. n) or ""))
				end
			else
				walk(c, depth + 1)
			end
		end
	end
	walk(root, 0)
elseif cmd == "props" then
	local inst = resolve(process.args[2])
	print(inst:GetFullName() .. " [" .. inst.ClassName .. "]")
	local names = { "Size", "CFrame", "Color", "Material", "Transparency", "Anchored", "CanCollide", "CanQuery", "CanTouch",
		"Massless", "Shape", "Part0", "Part1", "C0", "C1", "CFrame0", "Value", "Text", "Enabled", "Brightness", "Range",
		"PrimaryPart", "HipHeight", "WalkSpeed", "MaxHealth", "RigType", "DisplayName", "ActionText", "ObjectText",
		"MaxActivationDistance", "Attachment0", "Attachment1", "Position", "Orientation" }
	for _, n in (knownClass(inst) and names or {}) do
		local ok, v = pcall(function() return inst[n] end)
		if ok and v ~= nil then print(string.format("  %-22s %s", n, fmt(v))) end
	end
	local ok, attrs = pcall(function() return inst:GetAttributes() end)
	if ok then for k, v in attrs do print(string.format("  @%-21s %s", k, fmt(v))) end end
	if inst:IsA("LuaSourceContainer") then print("  Source: " .. #inst.Source .. " bytes (see scripts/)") end
elseif cmd == "find" then
	local pat, cls = process.args[2] or "", process.args[3]
	local n = 0
	for _, d in game:GetDescendants() do
		if string.find(d.Name, pat) and (not cls or d.ClassName == cls) then
			n += 1
			if n <= 200 then print(d:GetFullName() .. " [" .. d.ClassName .. "]") end
		end
	end
	print(n .. " matches" .. (n > 200 and " (first 200 shown)" or ""))
elseif cmd == "export" then
	local inst = resolve(process.args[2])
	fs.writeFile(assert(process.args[3], "output file?"), roblox.serializeModel({ inst }, true))
	print("wrote " .. process.args[3])
else
	print("unknown command " .. cmd)
end
