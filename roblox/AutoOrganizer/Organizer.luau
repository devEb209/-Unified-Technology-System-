-- Explicit, transactional routing for the recovered UTS/Arkhe packages.
-- No global scan, network access, source execution, deletion, rename, merge or overwrite.
local Organizer = {}
Organizer.__index = Organizer
local FORMAT = "uts-recovery/1"
local ALLOWED = { ServerStorage = true, ReplicatedStorage = true, Workspace = true }

local function marker(root, name)
	local item = root:FindFirstChild(name)
	return if item and item:IsA("StringValue") then item.Value else nil
end

local function activeScript(item)
	if item:IsA("BaseScript") and not item.Disabled then return true end
	for _, child in ipairs(item:GetDescendants()) do
		if child:IsA("BaseScript") and not child.Disabled then return true end
	end
	return false
end

local function immutableList(items)
	for _, item in ipairs(items) do
		if type(item) == "table" then table.freeze(item) end
	end
	return table.freeze(items)
end

function Organizer.new(services)
	assert(type(services) == "table", "provide explicit destination services")
	return setmetatable({ services = table.clone(services),
		plans = setmetatable({}, { __mode = "k" }), receipts = setmetatable({}, { __mode = "k" }) }, Organizer)
end

function Organizer:Plan(roots)
	assert(type(roots) == "table" and #roots > 0, "select at least one package")
	local moves, descriptions, errors, containers, packages = {}, {}, {}, {}, {}
	local seen, destinations = {}, {}
	for _, root in ipairs(roots) do
		if not seen[root] then
			seen[root] = true
			local kind = marker(root, "PackageKind")
			local payload = root:FindFirstChild("Payload")
			if not root:IsA("Model") or marker(root, "PackageFormat") ~= FORMAT
				or (kind ~= "UTS" and kind ~= "ARKHE") or not payload or not payload:IsA("Folder") then
				table.insert(errors, "Not a supported recovered package: " .. root.Name)
			else
				table.insert(packages, { root = root, kind = kind, payload = payload, count = #payload:GetChildren() })
				local usedServices = {}
				for _, container in ipairs(payload:GetChildren()) do
					local serviceName, target = container.Name, self.services[container.Name]
					if not container:IsA("Folder") or not ALLOWED[serviceName] or not target or usedServices[serviceName] then
						table.insert(errors, "Unsupported, unavailable or duplicate destination: " .. serviceName)
					else
						usedServices[serviceName] = true
						local children = container:GetChildren()
						table.insert(containers, { item = container, parent = payload, count = #children, name = serviceName })
						destinations[target] = destinations[target] or {}
						for _, item in ipairs(children) do
							if item == target or target:IsDescendantOf(item) then
								table.insert(errors, "Cyclic destination: " .. item.Name)
							elseif target:FindFirstChild(item.Name) or destinations[target][item.Name] then
								table.insert(errors, "Name conflict (nothing will be overwritten): " .. serviceName .. "." .. item.Name)
							elseif activeScript(item) then
								table.insert(errors, "Active Script/LocalScript refused: " .. item.Name)
							else
								destinations[target][item.Name] = true
								table.insert(moves, { item = item, from = container, target = target, name = item.Name })
								table.insert(descriptions, { name = item.Name, destination = serviceName, package = root.Name })
							end
						end
					end
				end
			end
		end
	end
	local plan = table.freeze({ moves = immutableList(descriptions), errors = immutableList(errors),
		canApply = #errors == 0, count = #moves })
	self.plans[plan] = { moves = moves, containers = containers, packages = packages, state = "planned" }
	return plan
end

local function restore(moves)
	local failures = {}
	for i = #moves, 1, -1 do
		local move = moves[i]
		local ok, err = pcall(function() move.item.Parent = move.from end)
		if not ok then table.insert(failures, move.name .. ": " .. tostring(err)) end
	end
	return failures
end

function Organizer:Apply(plan, confirmed)
	if confirmed ~= true then return false, "Explicit confirmation is required" end
	local state = self.plans[plan]
	if not state or state.state ~= "planned" then return false, "Unknown or already used plan" end
	if not plan.canApply then return false, table.concat(plan.errors, "\n") end
	for _, package in ipairs(state.packages) do
		if marker(package.root, "PackageFormat") ~= FORMAT or marker(package.root, "PackageKind") ~= package.kind
			or package.payload.Parent ~= package.root or #package.payload:GetChildren() ~= package.count then
			return false, "Package changed; preview again"
		end
	end
	for _, container in ipairs(state.containers) do
		if container.item.Parent ~= container.parent or container.item.Name ~= container.name
			or #container.item:GetChildren() ~= container.count then return false, "Payload changed; preview again" end
	end
	for _, move in ipairs(state.moves) do
		if move.item.Parent ~= move.from or move.item.Name ~= move.name or move.target:FindFirstChild(move.name)
			or activeScript(move.item) then return false, "Stale or unsafe plan; preview again: " .. move.name end
	end
	local moved = {}
	for _, move in ipairs(state.moves) do
		local ok, err = pcall(function() move.item.Parent = move.target end)
		if not ok then
			local failures = restore(moved)
			state.state = "failed"
			return false, "Move failed: " .. tostring(err) .. if #failures > 0 then "; ROLLBACK FAILED: " .. table.concat(failures, "; ") else "; prior moves restored"
		end
		table.insert(moved, move)
	end
	state.state = "applied"
	local receipt = table.freeze({ count = #moved })
	self.receipts[receipt] = { moves = moved, state = "applied" }
	return true, receipt
end

function Organizer:Undo(receipt, confirmed)
	if confirmed ~= true then return false, "Explicit confirmation is required" end
	local state = self.receipts[receipt]
	if not state or state.state ~= "applied" then return false, "Unknown or already undone receipt" end
	for _, move in ipairs(state.moves) do
		if move.item.Parent ~= move.target or move.item.Name ~= move.name or not move.from.Parent
			or move.from:FindFirstChild(move.name) then return false, "Installation changed; refusing destructive undo" end
	end
	local restored = {}
	for i = #state.moves, 1, -1 do
		local move = state.moves[i]
		local ok, err = pcall(function() move.item.Parent = move.from end)
		if not ok then
			local failures = {}
			for j = #restored, 1, -1 do
				local previous = restored[j]
				local repaired, message = pcall(function() previous.item.Parent = previous.target end)
				if not repaired then table.insert(failures, previous.name .. ": " .. tostring(message)) end
			end
			state.state = if #failures == 0 then "applied" else "undo_failed"
			return false, "UNDO FAILED: " .. tostring(err)
				.. (if #failures == 0 then "; installation retained" else "; rollback failed: " .. table.concat(failures, "; "))
		end
		table.insert(restored, move)
	end
	state.state = "undone"
	return true, "Restored " .. tostring(#state.moves) .. " items"
end

return Organizer
