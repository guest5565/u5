-- v0.2 profile polish: explicit save outcomes, retries, lease ownership checks,
-- safe migration, bounded release waits and NO DataStore access in temporary Studio mode.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Schema = require(ReplicatedStorage.Shared.ProfileSchema)
local Profiles = {}
local store
local session = game.JobId ~= "" and game.JobId or HttpService:GenerateGUID(false)
local records = {}
local function status(player, text)
	if player.Parent then player:SetAttribute("SaveStatus", text) end
end
local function snapshot(player)
	local data = {}
	for key in Schema.Defaults do data[key] = player:GetAttribute(key) end
	return Schema.Sanitize(data)
end
function Profiles.Load(player)
	local persistent = not RunService:IsStudio() or Config.AllowStudioPersistence
	local data, writable, locked = nil, false, false
	if persistent and not store then
		local ok, result = pcall(function() return DataStoreService:GetDataStore("Heavensunder_Profiles_v1") end)
		if ok then store = result else persistent = false end
	end
	if persistent then
		local success, result
		for attempt = 1, 3 do
			locked = false
			success, result = pcall(function()
				return store:UpdateAsync("u_" .. player.UserId, function(old)
					if not Schema.CanAcquire(old, session, os.time()) then locked = true; return nil end
					old = type(old) == "table" and old or {}
					old.Session = session; old.Lease = os.time(); old.Version = Schema.Version
					old.Data = Schema.Sanitize(old.Data)
					return old
				end)
			end)
			if success then break end
			task.wait(attempt * 0.7)
		end
		if locked then player:Kick("Your cultivation record is open in another server. Please try again shortly."); return false end
		if success and result and result.Session == session then data = result.Data; writable = true end
	end
	records[player] = {Writable = writable, Saving = false, Releasing = false}
	for key, value in Schema.Sanitize(data) do player:SetAttribute(key, value) end
	status(player, writable and "SYNCED · AUTOSAVE ON" or "TEMPORARY SESSION")
	player:SetAttribute("ProfileLoaded", true)
	return true
end
function Profiles.Save(player, release)
	local record = records[player]
	if not record then return false end
	if release then record.Releasing = true elseif record.Releasing then return false end
	if record.Saving then
		if not release then return false end
		local deadline = os.clock() + 12
		while record.Saving and os.clock() < deadline do task.wait(0.1) end
		if record.Saving then warn("[Heavensunder] Release deferred; the lease will expire."); return false end
	end
	if not record.Writable then
		if release then records[player] = nil end
		return false
	end
	record.Saving = true
	status(player, "SAVING…")
	local data = snapshot(player)
	local success, saved, lostLease = false, false, false
	for attempt = 1, 3 do
		success = pcall(function()
			local result = store:UpdateAsync("u_" .. player.UserId, function(old)
				if type(old) ~= "table" or old.Session ~= session then lostLease = true; return nil end
				old.Data = data; old.Version = Schema.Version; old.Lease = os.time()
				if release then old.Session = nil end
				return old
			end)
			saved = result ~= nil and not lostLease
		end)
		if (success and saved) or lostLease then break end
		task.wait(attempt * 0.5)
	end
	record.Saving = false
	if lostLease then
		record.Writable = false
		status(player, "SAVE LOCK LOST · REJOIN")
		warn("[Heavensunder] Save blocked: this server no longer owns the profile lease.", player.UserId)
	elseif success and saved then
		status(player, "SAVED · " .. os.date("!%H:%M", os.time()) .. " UTC")
	else
		status(player, "SAVE DELAYED · RETRYING NEXT CYCLE")
		warn("[Heavensunder] Profile save failed after retries for", player.UserId)
	end
	if release then records[player] = nil end
	return success and saved
end
return Profiles
