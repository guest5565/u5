--[[ Sanity check for a place patched with patch_v041.luau
     lune run patches/v041/verify_v041.luau <patched.rbxl>   (from the repo root) ]]
local fs = require("@lune/fs"); local roblox = require("@lune/roblox"); local process = require("@lune/process")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local fails = 0
local function check(ok, msg) if not ok then fails += 1; print("FAIL " .. msg) end end
local houses, necks, rigs = 0, 0, 0
for _, m in game:GetDescendants() do
	if m:IsA("Model") and m:FindFirstChild("RaisedStoneFoundation") and m:FindFirstChild("SweptEave") then
		houses += 1
		local n = { GableInfill = 0, EaveInfill = 0, CrossBeam = 0 }
		for _, p in m:GetChildren() do
			if n[p.Name] then
				n[p.Name] += 1
				check(p.Anchored == true and p.CanCollide == true or p.Name == "CrossBeam", m:GetFullName() .. "." .. p.Name .. " not anchored/collidable")
				check(p.Anchored == true, p:GetFullName() .. " not anchored")
			end
		end
		check(n.GableInfill == 6 and n.EaveInfill == 2 and n.CrossBeam == 5, string.format("%s parts Gable %d Eave %d Beam %d", m:GetFullName(), n.GableInfill, n.EaveInfill, n.CrossBeam))
	end
	if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("UpperTorso") then
		rigs += 1
		local neck = m:FindFirstChild("NeckColumn")
		check(neck ~= nil, m:GetFullName() .. " has no NeckColumn")
		if neck then
			necks += 1
			local w = neck:FindFirstChild("DetailWeld")
			check(w and w.Part0 == m.Head and w.Part1 == neck, m:GetFullName() .. " neck weld wrong")
			check(neck.Anchored == false and neck.CanCollide == false and neck.Massless == true, m:GetFullName() .. " neck physics props")
			check(neck.Color == m.Head.Color, m:GetFullName() .. " neck colour differs from head")
		end
	end
end
-- the patched PoseLibrary must still compile and return the new pose
local src = game.ReplicatedStorage.Shared.PoseLibrary.Source
local Pose = require("@lune/luau").load(src, { debugName = "PoseLibrary" })()
local p = {}; Pose.meditation(p, 0, 1.3)
check(math.abs(p.Root[5] + 1.70 * 1.3) < 1e-6, "Root drop not scaled")
check(p.LeftKnee and math.abs(p.LeftKnee[3] - 2.511) < 1e-6, "LeftKnee pose missing")
check(string.find(game.ReplicatedStorage.Shared.AnimationManager.Source, "meditation(p, t, rig.Root.Size.Y / 2)", 1, true) ~= nil, "AnimationManager call not patched")
print(string.format("houses %d, humanoid R15 rigs %d, necks %d, failures %d", houses, rigs, necks, fails))
process.exit(fails == 0 and 0 or 1)
