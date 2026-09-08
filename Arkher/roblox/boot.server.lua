--!strict
-- ARKHER Boot — server side minimal (ChangeHistoryService is client, but we prepare world)
print("[ARKHER] Boot V2 — Server ready. Client HUD will mount Studio.")
-- Ensure a baseplate for testing if workspace empty
if #workspace:GetChildren() < 5 then
	local p = Instance.new("Part")
	p.Name = "Ground"
	p.Size = Vector3.new(512, 2, 512)
	p.Position = Vector3.new(0, -4, 0)
	p.Anchored = true
	p.Material = Enum.Material.Grass
	p.Color = Color3.fromRGB(60, 90, 60)
	p.Parent = workspace
end
