-- ARKHER PLATFORM :: Adapter Interface
-- ARKHER never talks to Roblox directly. Every engine subsystem talks to this
-- interface, and exactly one adapter implementation binds it to a host platform
-- (Roblox runtime, Roblox Studio, headless test VM, future hosts).
--@arkher-module
return function(A)
	local Errors = A:import("arkher/kernel/errors")
	local Adapter = {}

	Adapter.REQUIRED = {
		"now", "wait", "spawn", "isServer", "isClient", "isStudio",
		"createNode", "destroyNode", "setProperty", "getProperty", "setParent", "children",
		"deviceProfile", "screenSize", "inputKinds", "log",
	}

	Adapter.CAPABILITY_MATRIX = {
		roblox = {
			instances = true, luau = true, terrain = true, particles = true, physics = true,
			customShaders = false, computeShaders = false, rawGPU = false, threads = "parallel-luau",
			maxPartsRecommended = 25000, maxDrawCallsMobile = 900, textureStreaming = true,
		},
		headless = {
			instances = "virtual", luau = true, terrain = "virtual", particles = "virtual", physics = "virtual",
			customShaders = false, computeShaders = false, rawGPU = false, threads = "single",
			maxPartsRecommended = math.huge, maxDrawCallsMobile = math.huge, textureStreaming = false,
		},
	}

	function Adapter.validate(impl)
		local missing = {}
		for _, name in ipairs(Adapter.REQUIRED) do
			if type(impl[name]) ~= "function" then missing[#missing + 1] = name end
		end
		if #missing > 0 then
			return false, Errors.new(Errors.Codes.UNIMPLEMENTED, "adapter missing: " .. table.concat(missing, ", "))
		end
		return true
	end

	-- Limitation registry: documented Roblox constraints and the ARKHER substitute.
	Adapter.LIMITATIONS = {
		{ id = "no-custom-shaders", platform = "roblox",
		  limitation = "no user-authored GPU shader programs",
		  arkherSubstitute = "ARKHER Material Framework: layered PBR parameter synthesis + SurfaceAppearance composition + screen-space post stack built from ViewportFrames, decals and adaptive texture atlases" },
		{ id = "no-compute", platform = "roblox",
		  limitation = "no compute shaders",
		  arkherSubstitute = "ARKHER Compute Fabric: parallel Luau actor pools with deterministic job graph partitioning and cached result fields" },
		{ id = "no-native-gi", platform = "roblox",
		  limitation = "no engine-level realtime global illumination control",
		  arkherSubstitute = "ARKHER Global Illumination Framework: precomputed irradiance probe volumes + runtime light-transport approximation baked into part/atmosphere parameters" },
		{ id = "part-budget", platform = "roblox",
		  limitation = "draw-call and instance budget, harsh on mobile",
		  arkherSubstitute = "ARKHER Geometry Virtualization: chunked instancing, impostor synthesis, HLOD cascades and D-O15 budget-driven streaming" },
		{ id = "no-native-upscaler", platform = "roblox",
		  limitation = "no DLSS/FSR style reconstruction hooks",
		  arkherSubstitute = "ARKHER Reconstruction Framework: temporal detail redistribution, adaptive render scaling via viewport composition and perceptual quality controller" },
	}

	function Adapter.limitationFor(id)
		for _, l in ipairs(Adapter.LIMITATIONS) do if l.id == id then return l end end
		return nil
	end

	return Adapter

end
