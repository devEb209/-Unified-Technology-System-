-- Opt-in starting point, NOT a hyperrealism switch. No textures, shaders or assets are downloaded.
-- LightingStyle and PrioritizeLightingQuality must be set in Studio Properties, not bypassed by a script.
local Profile = {}
local snapshots = setmetatable({}, { __mode = "k" })
local values = {
	Brightness = 2,
	ClockTime = 15,
	GeographicLatitude = 23,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	ExposureCompensation = 0,
	GlobalShadows = true,
	ShadowSoftness = 0.3,
}

function Profile.Describe()
	return {
		properties = table.clone(values),
		manual = { "Lighting.LightingStyle = Realistic (Studio Properties)",
			"Lighting.PrioritizeLightingQuality = true (optional, Studio Properties)",
			"Workspace.StreamingEnabled = true (Studio Properties; test game logic)",
			"Author and upload licensed PBR maps; this package includes no photogrammetry assets" },
	}
end

function Profile.Apply(lighting, confirmed)
	if confirmed ~= true then return false, "Explicit confirmation required" end
	if snapshots[lighting] then return false, "Restore the previous profile before applying again" end
	local old, applied = {}, {}
	local ok, err = pcall(function()
		for name in pairs(values) do old[name] = lighting[name] end
		local names = {}
		for name in pairs(values) do table.insert(names, name) end
		table.sort(names)
		for _, name in ipairs(names) do lighting[name] = values[name]; table.insert(applied, name) end
	end)
	if not ok then
		local failures = {}
		for i = #applied, 1, -1 do
			local name = applied[i]
			local restored, message = pcall(function() lighting[name] = old[name] end)
			if not restored then table.insert(failures, name .. ": " .. tostring(message)) end
		end
		return false, tostring(err) .. (#failures > 0 and "; rollback failed: " .. table.concat(failures, "; ") or "")
	end
	snapshots[lighting] = old
	return true, "Applied starting profile; scene and device testing still required"
end

function Profile.Restore(lighting, confirmed)
	if confirmed ~= true then return false, "Explicit confirmation required" end
	local old = snapshots[lighting]
	if not old then return false, "No profile to restore" end
	for name, expected in pairs(values) do
		if lighting[name] ~= expected then return false, "Lighting changed externally; refusing to overwrite " .. name end
	end
	local ok, err = pcall(function()
		for name, value in pairs(old) do lighting[name] = value end
	end)
	if not ok then return false, "Restore failed (may be partial): " .. tostring(err) end
	snapshots[lighting] = nil
	return true, "Restored"
end

return Profile
