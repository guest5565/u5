--[[ Heavensunder v0.4 -> v0.4.1 place patch (Lune 0.10+, https://lune-org.github.io/docs)

     lune run patches/v041/patch_v041.luau <in.rbxl|rbxlx> <out.rbxl|rbxlx> [--dry]   (from the repo root)

     Fixes, in the place file itself (nothing else is touched):
       1. Meditation pose  - replaces `meditation` in ReplicatedStorage.Shared.PoseLibrary and makes
                             AnimationManager pass the rig scale (rig.Root.Size.Y / 2).
       2. LanternwakeHome  - the two CrossBeams that ran across every doorway (y 1.5 / 4.5) are split
                             at the door posts; open gable triangles and the wall/roof slot are filled;
                             the floating SweptEave trim is moved onto the eave edge.
       3. Floating heads   - adds a skin-coloured "NeckColumn" (welded to the Head) to every R15-style
                             humanoid rig: StarterCharacter, NPCs, humanoid enemies. Spiders are skipped.

     Idempotent: running it twice changes nothing the second time. Only fresh instances are created
     (no :Clone()), so no duplicate UniqueIds end up in the file.
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local Instance, CFrame, Vector3, Enum = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Enum

local input, output = process.args[1], process.args[2]
local dry = table.find(process.args, "--dry") ~= nil
assert(input and output, "usage: lune run patch_v041.luau <in.rbxl> <out.rbxl> [--dry]")
local game = roblox.deserializePlace(fs.readFile(input))
local counts = {}
local function count(k, n) counts[k] = (counts[k] or 0) + (n or 1) end
local function warn(msg) print("  WARNING: " .. msg); count("warnings") end

------------------------------------------------------------------------------------------------
-- 1. Scripts
------------------------------------------------------------------------------------------------
local NEW_MEDITATION = [==[
-- Seated cross-legged (tailor) pose, hands resting in the lap.
-- Solved offline against the shipped rig proportions (hip 2.34, knee 1.34, ankle 0.46,
-- shoulder 4.13, elbow 3.08, wrist 2.21 rig units): the pelvis is lowered so the hips sit
-- 0.64 above the floor, thighs splay out/forward, shins fold in so the feet meet under the
-- hands. Every leg bone stays above the floor (lowest point ~0.06 below at the shin edge).
-- scale = HumanoidRootPart.Size.Y / 2 (all humanoid rigs are 2*scale tall at the root),
-- needed because the Root drop is a translation in studs.
local MEDITATE_DROP = 1.70
local function meditation(p, t, scale)
	scale = scale or 1
	local breath = sin(t * 1.5)
	put(p, "Root", 0, 0, 0, 0, -MEDITATE_DROP * scale, 0)
	put(p, "Waist", -0.06 - breath * 0.025, 0, 0, 0, breath * 0.03 * scale, 0)
	put(p, "Neck", -0.16 + breath * 0.02, 0, 0)
	put(p, "LeftHip", -1.406, 0.151, -0.843)
	put(p, "RightHip", -1.406, -0.151, 0.843)
	put(p, "LeftKnee", -0.091, -0.297, 2.511)
	put(p, "RightKnee", 0.044, 0.192, -2.389)
	put(p, "LeftAnkle", 1.406, 0.227, 1.226)
	put(p, "RightAnkle", 1.575, -0.138, -1.231)
	put(p, "LeftShoulder", -1.451 - breath * 0.02, 1.275, -0.566)
	put(p, "RightShoulder", -1.451 - breath * 0.02, -1.275, 0.566)
	put(p, "LeftElbow", 1.277, 0, 0)
	put(p, "RightElbow", 1.277, 0, 0)
	put(p, "LeftWrist", -0.607, 0.697, 0)
	put(p, "RightWrist", -0.607, -0.697, 0)
	put(p, "CoreJoint", 0, t, 0, 0, 0.30 + sin(t * 2) * 0.16, -0.3)
end
]==]

local function findScript(path)
	local node = game
	for seg in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(seg)
	end
	return node
end

do
	local pose = findScript("ReplicatedStorage.Shared.PoseLibrary")
	if not pose then
		warn("ReplicatedStorage.Shared.PoseLibrary not found - pose not patched")
	else
		local src = pose.Source
		if string.find(src, "MEDITATE_DROP", 1, true) then
			print("PoseLibrary: already patched")
		else
			local a = string.find(src, "local function meditation(p, t)", 1, true)
			local b = a and string.find(src, "local function attack(", a, true)
			if not (a and b) then
				warn("PoseLibrary: could not locate `local function meditation(p, t)` ... `local function attack(` - not patched")
			else
				pose.Source = string.sub(src, 1, a - 1) .. NEW_MEDITATION .. string.sub(src, b)
				print("PoseLibrary: meditation() replaced"); count("scripts")
			end
		end
	end
	local anim = findScript("ReplicatedStorage.Shared.AnimationManager")
	if not anim then
		warn("ReplicatedStorage.Shared.AnimationManager not found")
	else
		local src = anim.Source
		if string.find(src, "meditation(p, t, rig.Root.Size.Y / 2)", 1, true) then
			print("AnimationManager: already patched")
		else
			local new, n = string.gsub(src, "meditation%(p, t%)", "meditation(p, t, rig.Root.Size.Y / 2)")
			if n ~= 1 then
				warn("AnimationManager: expected exactly one `meditation(p, t)` call, found " .. n .. " - not patched")
			else
				anim.Source = new
				print("AnimationManager: meditation call now passes rig scale"); count("scripts")
			end
		end
	end
end

------------------------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------------------------
local COPY = { "Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Color", "Material",
	"MaterialVariant", "Reflectance", "Transparency", "Locked", "CollisionGroup", "Massless",
	"TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

-- fresh part that looks/behaves like `template` (Lune leaves unset properties absent, so set them all)
local function partLike(className, template, name, size, cframe, parent)
	local p = Instance.new(className)
	p.Name = name
	for _, prop in COPY do
		local ok, v = pcall(function() return template[prop] end)
		if ok and v ~= nil then pcall(function() p[prop] = v end) end
	end
	-- defaults for anything the template didn't carry
	for prop, v in { Anchored = true, CanCollide = true, CanQuery = true, CanTouch = false, CastShadow = true,
		Transparency = 0, Reflectance = 0, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth } do
		local ok, cur = pcall(function() return p[prop] end)
		if not ok or cur == nil then pcall(function() p[prop] = v end) end
	end
	if className == "Part" then
		local ok, shape = pcall(function() return template.Shape end)
		p.Shape = (ok and shape) or Enum.PartType.Block
	end
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 0.08) end

------------------------------------------------------------------------------------------------
-- 2. LanternwakeHome
------------------------------------------------------------------------------------------------
-- all numbers are in the house frame: origin at the foundation's bottom centre, +Y up,
-- door wall at z = -8 (front), exactly as AssetBuilder.house() lays it out.
local function patchHouse(m)
	local foundation = m:FindFirstChild("RaisedStoneFoundation")
	local sideWall, rearWall = m:FindFirstChild("SideWall"), m:FindFirstChild("RearWall")
	if not (foundation and sideWall and rearWall) then
		warn(m:GetFullName() .. ": missing RaisedStoneFoundation/SideWall/RearWall - skipped")
		return
	end
	if m:FindFirstChild("GableInfill") then count("houses already patched"); return end
	local base = foundation.CFrame * CFrame.new(0, -foundation.Size.Y / 2, 0)
	local rot180 = CFrame.Angles(0, math.pi, 0)

	-- (a) doorway crossbeams
	local split = 0
	for _, beam in m:GetChildren() do
		if beam.Name == "CrossBeam" and beam:IsA("BasePart") and beam.Size.X > 19 then
			local lp = base:PointToObjectSpace(beam.CFrame.Position)
			if near(lp.X, 0) and near(lp.Z, -8.5, 0.15) and (near(lp.Y, 1.5) or near(lp.Y, 4.5)) then
				for _, sx in { -1, 1 } do
					partLike("Part", beam, "CrossBeam", Vector3.new(7.25, beam.Size.Y, beam.Size.Z),
						beam.CFrame * CFrame.new(sx * 6.025, 0, 0), m)
				end
				beam:Destroy()
				split += 1
			end
		end
	end
	if split ~= 2 then warn(m:GetFullName() .. ": expected 2 doorway CrossBeams, split " .. split) end
	count("door beams split", split)

	-- (b) gables + wall/roof slot
	for _, x in { -9, 9 } do
		partLike("Part", sideWall, "GableInfill", Vector3.new(0.7, 0.78, 16.7), base * CFrame.new(x, 8.89, 0), m)
		for _, zs in { -1, 1 } do
			local cf = base * CFrame.new(x, 10.70, zs * 4.175)
			if zs > 0 then cf = cf * rot180 end
			partLike("WedgePart", sideWall, "GableInfill", Vector3.new(0.7, 2.84, 8.35), cf, m)
		end
	end
	for _, z in { -8, 8 } do
		partLike("Part", rearWall, "EaveInfill", Vector3.new(18.7, 0.9, 0.7), base * CFrame.new(0, 8.95, z), m)
	end
	count("gable/eave infill parts", 8)

	-- (c) SweptEave trim onto the eave edge
	for _, eave in m:GetChildren() do
		if eave.Name == "SweptEave" and eave:IsA("BasePart") then
			local lp = base:PointToObjectSpace(eave.CFrame.Position)
			if near(lp.Y, 10.2, 0.2) then
				local target = base * Vector3.new(lp.X, 8.88, (lp.Z >= 0 and 1 or -1) * 10.98)
				eave.CFrame = eave.CFrame + (target - eave.CFrame.Position)
				count("SweptEave moved")
			end
		end
	end
	count("houses patched")
end

for _, m in game:GetDescendants() do
	if m:IsA("Model") and m:FindFirstChild("RaisedStoneFoundation") and m:FindFirstChild("SweptEave") then
		patchHouse(m)
	end
end

------------------------------------------------------------------------------------------------
-- 3. Neck columns
------------------------------------------------------------------------------------------------
-- rig units (x scale, scale = Head.Size.X / 1.12): Head Ball centre 5.03 (bottom 4.455),
-- UpperTorso top 4.325, Neck pivot 4.41.  Column: y 4.22 .. 4.70, diameter 0.52.
local function patchRig(m)
	local head, ut = m:FindFirstChild("Head"), m:FindFirstChild("UpperTorso")
	if not (head and ut and head:IsA("BasePart") and m:FindFirstChildOfClass("Humanoid")) then return end
	-- only our R15-style rigs: a Motor6D "Neck" driving the Head (shipped: under UpperTorso; builder: under the model)
	local hasNeck = false
	for _, d in m:GetDescendants() do
		if d.Name == "Neck" and d:IsA("Motor6D") then
			local ok, p1 = pcall(function() return d.Part1 end)
			if ok and p1 == head then hasNeck = true; break end
		end
	end
	if not hasNeck then return end
	if m:FindFirstChild("NeckColumn") then count("rigs already patched"); return end
	local s = head.Size.X / 1.12
	local neck = Instance.new("Part")
	neck.Name = "NeckColumn"
	neck.Shape = Enum.PartType.Cylinder
	neck.Size = Vector3.new(0.48 * s, 0.52 * s, 0.52 * s)
	neck.CFrame = head.CFrame * CFrame.new(0, (4.46 - 5.03) * s, 0) * CFrame.Angles(0, 0, math.pi / 2)
	neck.Color = head.Color
	local okm, mat = pcall(function() return head.Material end)
	neck.Material = (okm and mat) or Enum.Material.SmoothPlastic
	neck.Anchored = false
	neck.CanCollide = false
	neck.CanQuery = false
	neck.CanTouch = false
	neck.Massless = true
	neck.CastShadow = true
	neck.Transparency = 0
	neck.Reflectance = 0
	neck.TopSurface = Enum.SurfaceType.Smooth
	neck.BottomSurface = Enum.SurfaceType.Smooth
	neck.Parent = m
	local weld = Instance.new("WeldConstraint")
	weld.Name = "DetailWeld"
	weld.Part0 = head
	weld.Part1 = neck
	weld.CFrame0 = head.CFrame:ToObjectSpace(neck.CFrame)
	weld.State = 3
	weld.Parent = neck
	count("necks added")
end

for _, m in game:GetDescendants() do
	if m:IsA("Model") then patchRig(m) end
end

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
