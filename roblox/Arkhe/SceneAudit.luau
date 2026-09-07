-- On-demand inventory of a selected scene, not a GPU benchmark or a quality certificate.
local Audit = {}

function Audit.Inspect(root)
	assert(root, "provide a scene root")
	local result = { instances = 0, parts = 0, unanchoredParts = 0, meshParts = 0,
		pbrSurfaces = 0, lights = 0, shadowLights = 0, emitters = 0, warnings = {} }
	local items = root:GetDescendants()
	table.insert(items, root)
	for _, item in ipairs(items) do
		result.instances += 1
		if item:IsA("BasePart") then
			result.parts += 1
			if not item.Anchored then result.unanchoredParts += 1 end
		end
		if item:IsA("MeshPart") then result.meshParts += 1 end
		if item:IsA("SurfaceAppearance") then result.pbrSurfaces += 1 end
		if item:IsA("Light") then
			result.lights += 1
			if item.Enabled and item.Shadows then result.shadowLights += 1 end
		end
		if item:IsA("ParticleEmitter") and item.Enabled then result.emitters += 1 end
	end
	if result.unanchoredParts > 0 then
		table.insert(result.warnings, "Review active assemblies and collision complexity; count alone does not measure physics cost")
	end
	if result.meshParts > 0 and result.pbrSurfaces == 0 then
		table.insert(result.warnings, "No SurfaceAppearance found; inspect whether built-in materials already meet the scene's requirements")
	end
	table.insert(result.warnings, "Measure frame time, memory, draw calls and network in Studio/device profiling; this inventory cannot certify hyperrealism")
	return result
end

return Audit
