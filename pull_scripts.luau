--[[ place -> scripts/   Copies every script's Source out of the place file into scripts/.

     lune run lune/pull_scripts.luau [Heavensunder.rbxl]

     Use this after editing scripts inside Studio WITHOUT Rojo connected, so scripts/ (the source of
     truth for code) catches up. Existing files are overwritten; files for scripts that no longer
     exist in the place are reported, not deleted.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local map = require("./scriptmap")

local placePath = process.args[1] or "Heavensunder.rbxl"
local game = roblox.deserializePlace(fs.readFile(placePath))
local written, changed, seen = 0, 0, {}
for _, inst in game:GetDescendants() do
	if map.isScript(inst) then
		local rel = map.fileFor(inst)
		if seen[rel] then error("two scripts map to the same file: " .. rel) end
		seen[rel] = true
		local path = "scripts/" .. rel
		local dir = string.match(path, "^(.*)/[^/]+$")
		fs.writeDir(dir)
		local src = inst.Source
		local old = fs.isFile(path) and fs.readFile(path) or nil
		if old ~= src then
			fs.writeFile(path, src)
			changed += 1
			print((old and "updated  " or "created  ") .. path)
		end
		written += 1
	end
end
if fs.isDir("scripts") then
	for _, f in map.listSrc(fs, "scripts") do
		if not seen[f.rel] then print("NOT IN PLACE (left alone): scripts/" .. f.rel) end
	end
end
print(string.format("%d scripts in place, %d files changed", written, changed))
