--[[ place/ + scripts/ -> build/Heavensunder.rbxl

     lune run lune/build.luau [Heavensunder.rbxl] [build/Heavensunder.rbxl]

     Takes the base place (world, rigs, UI - everything made in Studio or by the asset builder)
     and overwrites every script's Source with the file from scripts/, which is the source of truth
     for code. New files in scripts/ become new scripts (their parent folders must already exist in
     the place, or are created as Folders). Output format follows the extension (.rbxl / .rbxlx).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local map = require("./scriptmap")

local placePath = process.args[1] or "Heavensunder.rbxl"
local outPath = process.args[2] or "build/Heavensunder.rbxl"
local game = roblox.deserializePlace(fs.readFile(placePath))

local updated, created, same, used = 0, 0, 0, {}
for _, f in map.listSrc(fs, "scripts") do
	local node = game
	for i, seg in f.segments do
		local nxt = node:FindFirstChild(seg)
		if not nxt then
			if i == 1 then
				nxt = game:GetService(seg) -- top level must be a service
			else
				nxt = roblox.Instance.new("Folder"); nxt.Name = seg; nxt.Parent = node
				print("created folder " .. nxt:GetFullName())
			end
		end
		node = nxt
	end
	local inst = node:FindFirstChild(f.name)
	if inst and inst.ClassName ~= f.class then
		error(string.format("%s is a %s in the place but scripts/%s says %s", inst:GetFullName(), inst.ClassName, f.rel, f.class))
	end
	local src = fs.readFile(f.path)
	if not inst then
		inst = roblox.Instance.new(f.class); inst.Name = f.name
		if f.class == "Script" then pcall(function() inst.RunContext = roblox.Enum.RunContext.Legacy end) end
		inst.Source = src; inst.Parent = node
		created += 1; print("new script  " .. inst:GetFullName())
	elseif inst.Source ~= src then
		inst.Source = src; updated += 1; print("updated     " .. inst:GetFullName())
	else
		same += 1
	end
	used[inst:GetFullName()] = true
end
for _, inst in game:GetDescendants() do
	if map.isScript(inst) and not used[inst:GetFullName()] then
		print("WARNING: " .. inst:GetFullName() .. " has no file in scripts/ (kept as-is; run tools/pull_scripts.luau?)")
	end
end
local dir = string.match(outPath, "^(.*)/[^/]+$")
if dir then fs.writeDir(dir) end
fs.writeFile(outPath, roblox.serializePlace(game, string.find(outPath, "%.rbxlx$") ~= nil))
print(string.format("built %s  (%d updated, %d new, %d unchanged)", outPath, updated, created, same))
