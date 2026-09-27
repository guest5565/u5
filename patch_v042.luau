--[[ Heavensunder v0.4.1 -> v0.4.2 place patch (TEMPLATE - does nothing yet).

     lune run patches/v042/patch_v042.luau <in.rbxl|rbxlx> <out.rbxl|rbxlx> [--dry]

     Copy this folder to patches/v042/, rename to patch_v042.luau, and fill in
     the sections below following patches/v041/patch_v041.luau as the example.

     Rules (learned the hard way in v0.4.1):
       - Find things by name AND position; warn + skip anything unexpected.
       - Only create fresh instances with Instance.new (no :Clone()).
       - Be idempotent: a second run changes nothing (check for a marker first).
       - Instance.new leaves properties absent -> set everything explicitly
         (Anchored, CanCollide, CanQuery, CanTouch, CastShadow, ...).
       - Output format follows the extension (.rbxl = binary, .rbxlx = XML).
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local input, output = process.args[1], process.args[2]
local dry = table.find(process.args, "--dry") ~= nil
assert(input and output, "usage: lune run patches/v042/patch_v042.luau <in.rbxl> <out.rbxl> [--dry]")
local game = roblox.deserializePlace(fs.readFile(input))
local counts = {}
local function count(k, n) counts[k] = (counts[k] or 0) + (n or 1) end
local function warn(msg) print("  WARNING: " .. msg); count("warnings") end

------------------------------------------------------------------------------------------------
-- 1. Scripts (string surgery with markers, e.g. replace a function between two anchors)
------------------------------------------------------------------------------------------------
-- local node = game:GetService("ReplicatedStorage"):FindFirstChild("Shared", true)
-- ... if already patched (string.find(src, "V042_MARKER", 1, true)) then print("already patched") ...

------------------------------------------------------------------------------------------------
-- 2. Geometry (fresh parts only, positioned from a measured base CFrame)
------------------------------------------------------------------------------------------------
-- for _, m in game:GetDescendants() do
-- 	if m:IsA("Model") and m:FindFirstChild("SomeMarker") then
-- 		if m:FindFirstChild("V042Marker") then count("already patched"); continue end
-- 		...
-- 	end
-- end

------------------------------------------------------------------------------------------------
print("\nsummary:")
local keys = {}
for k in counts do table.insert(keys, k) end
table.sort(keys)
for _, k in keys do print(string.format("  %-26s %d", k, counts[k])) end
if dry then
	print("--dry: nothing written")
else
	local xml = string.find(string.lower(output), "%.rbxlx$") ~= nil
	fs.writeFile(output, roblox.serializePlace(game, xml))
	print("wrote " .. output .. (xml and " (XML)" or " (binary)"))
end
