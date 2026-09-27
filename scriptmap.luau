--[[ Shared mapping between script instances in the place and files in scripts/.

     scripts/<Service>/<Folder>/.../<Name><suffix>
       .luau          ModuleScript
       .server.luau   Script
       .client.luau   LocalScript
     (same convention as Rojo, so `rojo serve` and these tools agree)
]]
local M = {}

M.SUFFIX = { ModuleScript = ".luau", Script = ".server.luau", LocalScript = ".client.luau" }

function M.classFromFile(fileName: string): (string?, string?)
	for class, suffix in { Script = ".server.luau", LocalScript = ".client.luau" } do
		if string.sub(fileName, -#suffix) == suffix then return class, string.sub(fileName, 1, -#suffix - 1) end
	end
	if string.sub(fileName, -5) == ".luau" then return "ModuleScript", string.sub(fileName, 1, -6) end
	return nil, nil
end

-- instance -> "ReplicatedStorage/Shared/Config.luau"
function M.fileFor(inst): string
	local parts = {}
	local node = inst
	while node and node.ClassName ~= "DataModel" do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, "/") .. M.SUFFIX[inst.ClassName]
end

-- recursively list src files: { {rel = "ReplicatedStorage/Shared/Config.luau", segments = {...}, class=..., name=...} }
function M.listSrc(fs, root: string)
	local out = {}
	local function walk(dir: string, segs)
		for _, entry in fs.readDir(dir) do
			local path = dir .. "/" .. entry
			if fs.isDir(path) then
				local s = table.clone(segs); table.insert(s, entry); walk(path, s)
			else
				local class, name = M.classFromFile(entry)
				if class then
					table.insert(out, { path = path, rel = table.concat(segs, "/") .. (#segs > 0 and "/" or "") .. entry,
						segments = segs, class = class, name = name })
				end
			end
		end
	end
	walk(root, {})
	table.sort(out, function(a, b) return a.rel < b.rel end)
	return out
end

function M.isScript(inst): boolean
	return M.SUFFIX[inst.ClassName] ~= nil
end

return M
