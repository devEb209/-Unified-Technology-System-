-- ARKHER .rbxm transport installer, not the editor architecture and not a Studio plugin.
-- Use only in an empty/editing place. The .rbxl already contains the installed hierarchy.
local Install = {}
function Install.Install(confirm)
	assert(confirm==true,"Leia o guia e confirme explicitamente Install(true)")
	local run=game:GetService("RunService")
	assert(run:IsStudio() and not run:IsRunning(),"Instale apenas no modo de edição do Studio")
	local payload=script.Parent:FindFirstChild("Payload")
	assert(payload,"Payload ausente")
	local destinations={
		ReplicatedStorage=game:GetService("ReplicatedStorage"),
		ServerScriptService=game:GetService("ServerScriptService"),
		StarterPlayerScripts=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
	}
	local stages={}
	for _,name in ipairs({"ReplicatedStorage","ServerScriptService","StarterPlayerScripts"}) do
		local target=assert(destinations[name],"Destino ausente: "..name)
		local source=assert(payload:FindFirstChild(name),"Pasta de payload ausente: "..name)
		for _,item in ipairs(source:GetChildren()) do
			assert(not target:FindFirstChild(item.Name),"Instalação existente; não sobrescrita: "..item.Name)
			table.insert(stages,{source=item,target=target})
		end
	end
	local history=game:GetService("ChangeHistoryService")
	local recording=history:TryBeginRecording("ARKHER.Install","Instalar ARKHER")
	assert(recording,"Não foi possível iniciar registro de Undo")
	local clones={}
	local ok,message=pcall(function()
		for _,stage in ipairs(stages) do
			assert(not stage.target:FindFirstChild(stage.source.Name),"Destino mudou durante instalação")
			local clone=stage.source:Clone();table.insert(clones,clone)
			clone.Parent=stage.target
			if clone:IsA("BaseScript") then clone.Disabled=false end
			for _,child in ipairs(clone:GetDescendants()) do if child:IsA("BaseScript") then child.Disabled=false end end
		end
	end)
	if not ok then
		for _,clone in ipairs(clones) do clone:Destroy() end
		history:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel)
		error("Instalação revertida: "..tostring(message))
	end
	history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
	print("ARKHER instalado. Pressione Play para abrir o editor. Use Undo do Studio para reverter a instalação.")
	return {installed=#clones,stage="V1 development",studioIntegration="requires smoke test"}
end
return Install
