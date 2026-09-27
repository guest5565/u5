--[[ Sanity check for a place patched with patch_v042.luau (TEMPLATE).
     lune run patches/v042/verify_v042.luau <patched.rbxl> ]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		print("FAIL " .. msg)
	end
end

-- Example checks (replace with real ones):
-- local found = 0
-- for _, m in game:GetDescendants() do
-- 	if m:IsA("Model") and m:FindFirstChild("V042Marker") then found += 1 end
-- end
-- check(found == 6, "expected 6 patched models, found " .. found)

-- Patched script sources must still compile: require them via @lune/luau.
-- local src = game.ReplicatedStorage.Shared.PoseLibrary.Source
-- local Pose = require("@lune/luau").load(src, { debugName = "PoseLibrary" })()

print(string.format("failures %d", fails))
process.exit(fails == 0 and 0 or 1)
