-- This ModuleScript belongs ONLY in ServerScriptService. Never store real API keys in source.
return {
	DisableAvatar = true, -- standalone editor experience; does not destroy existing Characters.
	EditorUserIds = {}, -- e.g. [123456789] = true; Studio test players and a user-owned experience's creator are allowed.
	PersistenceEnabled = false, -- enable only after publishing and configuring Studio API access as appropriate.
	DataStoreName = "ARKHER_PROJECTS_G1",
	DataStoreKey = "team-project",
	MaxDynamics = 128, -- active simulation budget, NOT a count/limit of architectural systems.
	Provider = {
		Endpoint = "", -- HTTPS Chat Completions-compatible endpoint, explicitly chosen by the experience owner.
		Model = "",
		SecretName = "", -- Roblox secrets-store NAME, not the secret value.
	},
}
