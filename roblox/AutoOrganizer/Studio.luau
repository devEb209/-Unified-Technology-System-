-- Studio Command Bar entry point. Nothing installs merely by importing this model.
local Organizer = require(script.Parent.Organizer)
local Studio = {}
local organizer, pending, receipt

local function context()
	local run = game:GetService("RunService")
	assert(run:IsStudio() and not run:IsRunning(), "Use Studio in edit mode, not Play/Run")
	if not organizer then
		organizer = Organizer.new({
			ServerStorage = game:GetService("ServerStorage"),
			ReplicatedStorage = game:GetService("ReplicatedStorage"),
			Workspace = game:GetService("Workspace"),
		})
	end
	return game:GetService("ChangeHistoryService")
end

function Studio.Preview(roots)
	context()
	roots = roots or game:GetService("Selection"):Get()
	pending = organizer:Plan(roots)
	for _, move in ipairs(pending.moves) do
		print("[UTS preview] " .. move.package .. " / " .. move.name .. " -> " .. move.destination)
	end
	for _, err in ipairs(pending.errors) do warn("[UTS preview] " .. err) end
	print("[UTS preview] " .. pending.count .. " moves; no changes made. Valid: " .. tostring(pending.canApply))
	return pending
end

function Studio.Apply(confirmation)
	local history = context()
	assert(confirmation == "INSTALAR", 'Confirm with Apply("INSTALAR")')
	assert(pending and pending.canApply, "Preview a valid selection first")
	local id = history:TryBeginRecording("UTSRecoveryInstall", "Install recovered UTS / Arkhe")
	assert(id, "Could not begin an undo recording; no changes made")
	local ok, result = organizer:Apply(pending, true)
	local finished, err = pcall(function()
		history:FinishRecording(id, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end)
	if not finished then
		if ok then
			local restored, message = organizer:Undo(result, true)
			warn("[UTS] History failed; rollback: " .. tostring(restored) .. " / " .. tostring(message))
		end
		error("Undo recording failed: " .. tostring(err))
	end
	if ok then receipt = result; pending = nil; print("[UTS] Installed " .. result.count .. " containers") end
	return ok, result
end

function Studio.Undo(confirmation)
	local history = context()
	assert(confirmation == "DESFAZER", 'Confirm with Undo("DESFAZER")')
	assert(receipt, "No receipt in this Studio session; use Studio Undo for its own history")
	local id = history:TryBeginRecording("UTSRecoveryUndo", "Restore imported UTS / Arkhe containers")
	assert(id, "Could not begin an undo recording; no changes made")
	local ok, result = organizer:Undo(receipt, true)
	history:FinishRecording(id, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	if ok then receipt = nil end
	return ok, result
end

return Studio
