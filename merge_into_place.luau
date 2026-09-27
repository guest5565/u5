--[[ Merge builder-generated .rbxmx models into an EXISTING place (e.g. Heavensunder-v0.4.rbxl)
     without touching anything else.  Needs Lune (https://lune-org.github.io/docs).

     lune run lune/merge_into_place.luau <in.rbxl> <out.rbxl> <Workspace/Path/To/Folder=file.rbxmx> ...
     e.g.
     lune run lune/merge_into_place.luau Heavensunder.rbxl Heavensunder-v0.5.rbxl \
         Workspace/Actors/Enemies=rojo_example/assets/JadeSilkweaver_99.rbxmx \
         Workspace/World/Foliage=rojo_example/assets/LowlandBough_99.rbxmx
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local input, output = process.args[1], process.args[2]
assert(input and output and #process.args >= 3, "usage: <in.rbxl> <out.rbxl> Parent/Path=model.rbxmx ...")
local game = roblox.deserializePlace(fs.readFile(input))

local function resolve(path: string)
	local node: any = game
	for segment in string.gmatch(path, "[^/]+") do
		local nextNode = node:FindFirstChild(segment)
		if not nextNode then
			nextNode = roblox.Instance.new("Folder"); nextNode.Name = segment; nextNode.Parent = node
			print("  created folder", nextNode:GetFullName())
		end
		node = nextNode
	end
	return node
end

for i = 3, #process.args do
	local target, file = string.match(process.args[i], "^(.-)=(.+)$")
	assert(target, "bad argument " .. process.args[i])
	local parent = resolve(target)
	for _, inst in roblox.deserializeModel(fs.readFile(file)) do
		local old = parent:FindFirstChild(inst.Name)
		if old then old:Destroy(); print("  replaced", inst.Name) end
		inst.Parent = parent
		print("added", inst:GetFullName(), "(" .. #inst:GetDescendants() .. " descendants)")
	end
end
-- .rbxl -> binary, .rbxlx -> XML
local binary = string.sub(output, -5) ~= "rbxlx"
fs.writeFile(output, roblox.serializePlace(game, not binary))
print("wrote", output)
