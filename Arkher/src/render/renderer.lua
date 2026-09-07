-- ARKHER RENDER :: Render Pipeline
-- The frame itself. A declarative frame graph (depth -> shadows -> GI -> opaque ->
-- transparent -> post -> UI) driven by the camera, visibility, geometry virtualization,
-- lighting, materials and neural reconstruction, all inside a D-O15 millisecond budget.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local Lighting = A:import("arkher/render/lighting")
	local Virtualization = A:import("arkher/render/virtualization")
	local Reconstruction = A:import("arkher/neural/reconstruction")
	local MaterialFramework = A:import("arkher/materials/material_framework")
	local v3 = Vec.vec3

	local Renderer = {}
	Renderer.__index = Renderer

	function Renderer.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Renderer)
		self.width = opts.width or 1280
		self.height = opts.height or 720
		self.budgetMs = opts.budgetMs or 16.6
		self.camera = Kits.create("camera", { id = "render.camera",
			width = self.width, height = self.height, fov = opts.fov or math.rad(70),
			far = opts.far or 2000 })
		self.visibility = Kits.create("visibility", { id = "render.visibility", maxDepth = 3 })
		self.graph = Kits.create("framegraph", { id = "render.frame", budgetMs = self.budgetMs })
		self.lighting = opts.lighting or Lighting.new({ bounds = opts.bounds })
		self.geometry = opts.geometry or Virtualization.new({})
		self.reconstruction = opts.reconstruction or Reconstruction.new({ targetMs = self.budgetMs })
		self.materials = opts.materials or MaterialFramework.new({ tier = opts.tier or "mobile" })
		self.quality = opts.quality or 1.0
		self.frames = 0
		self.stats = { drawCalls = 0, triangles = 0, lights = 0, passes = 0, skipped = 0,
			frameMs = 0, gpuBoundFrames = 0 }
		self.timeline = {}
		self:buildFrameGraph()
		return self
	end

	-- ------------------------------------------------------------------ frame graph
	-- Each pass declares what it reads and writes; the graph culls, orders and budgets.
	function Renderer:buildFrameGraph()
		local g = self.graph
		local ctxRef = self

		g.addResource("depth", { bytes = self.width * self.height * 4 })
		g.addResource("shadow", { bytes = 1024 * 1024 * 2 })
		g.addResource("gi", { bytes = 262144 })
		g.addResource("color", { bytes = self.width * self.height * 8 })
		g.addResource("history", { bytes = self.width * self.height * 8, transient = false })
		g.addResource("post", { bytes = self.width * self.height * 8 })
		g.addResource("frame", { bytes = self.width * self.height * 4, transient = false })

		g.addPass("depthPrepass", { writes = { "depth" }, cost = 1.2,
			execute = function(ctx) ctx.visible = ctxRef:cullPass(ctx) end })
		g.addPass("shadows", { reads = { "depth" }, writes = { "shadow" }, cost = 2.6,
			optional = true, priority = 3,
			execute = function(ctx) ctx.shadowCasters = ctxRef.lighting:shadowCasters() end })
		g.addPass("giResolve", { reads = { "depth" }, writes = { "gi" }, cost = 1.1,
			optional = true, priority = 4,
			execute = function(ctx) ctx.relit = ctxRef.lighting:relight(6) end })
		g.addPass("opaque", { reads = { "depth", "shadow", "gi" }, writes = { "color" }, cost = 4.5,
			execute = function(ctx) ctx.opaque = ctxRef:shadePass(ctx) end })
		g.addPass("transparent", { reads = { "color", "depth" }, writes = { "color" }, cost = 1.4,
			optional = true, priority = 6,
			execute = function(ctx) ctx.transparent = true end })
		g.addPass("temporalResolve", { reads = { "color", "history" }, writes = { "post" }, cost = 1.6,
			optional = true, priority = 7,
			execute = function(ctx) ctx.resolved = ctxRef:resolvePass(ctx) end })
		g.addPass("postProcess", { reads = { "post" }, writes = { "frame" }, cost = 1.0,
			optional = true, priority = 5,
			execute = function(ctx) ctx.exposure = ctxRef.lighting:autoExposure(
				ctxRef.lighting.skyLuminance, ctx.dt or (1 / 60)) end })
		g.addPass("ui", { reads = { "frame" }, writes = { "frame" }, cost = 0.6, final = true,
			execute = function(ctx) ctx.ui = true end })
		return g.compile()
	end

	-- ------------------------------------------------------------------ passes
	function Renderer:cullPass(ctx)
		local viewer = self.camera.position
		local pass = self.geometry:resolve(viewer, {
			radius = ctx.radius or 900, screenHeight = self.height,
			fov = self.camera.fov, triangleBudget = self.geometry.triangleBudget,
			drawBudget = self.geometry.drawBudget })
		self.stats.triangles = pass.triangles
		self.stats.drawCalls = pass.draws
		return pass
	end

	function Renderer:shadePass(ctx)
		local viewer = self.camera.position
		local lights = self.lighting:lightsFor(viewer)
		self.stats.lights = #lights
		local shaded = 0
		local pass = ctx.visible
		if pass then
			for _, id in ipairs(pass.mesh) do
				local obj = self.geometry.objects[id]
				if obj and obj.material then
					local distance = obj.position:distance(viewer)
					self.materials:resolveForDistance(obj.material, { wetness = ctx.wetness or 0 }, distance)
					shaded = shaded + 1
				end
			end
		end
		return { lights = #lights, shaded = shaded }
	end

	function Renderer:resolvePass(ctx)
		local frame = self.reconstruction:beginFrame()
		return frame
	end

	-- ------------------------------------------------------------------ the frame
	function Renderer:renderFrame(dt, measuredMs)
		self.frames = self.frames + 1
		self.camera.advance()
		local ctx = { dt = dt or (1 / 60), frame = self.frames, wetness = 0 }
		local budget = self.budgetMs * Mathx.clamp(self.quality + 0.25, 0.4, 1.2)
		local result = self.graph.execute(ctx, budget)
		self.stats.passes = #result.executed
		self.stats.skipped = #result.skipped
		self.stats.frameMs = measuredMs or result.costMs
		if self.stats.frameMs > self.budgetMs then
			self.stats.gpuBoundFrames = self.stats.gpuBoundFrames + 1
		end
		-- neural policy decides the next frame's resolution from what this frame cost
		local decision = self.reconstruction:apply({
			frameMs = self.stats.frameMs, motion = ctx.motion or 0,
			complexity = Mathx.clamp(self.stats.triangles / 200000, 0, 1),
			battery = ctx.battery or 1 })
		self.timeline[#self.timeline + 1] = { frame = self.frames, ms = self.stats.frameMs,
			scale = decision.scale, draws = self.stats.drawCalls, passes = self.stats.passes }
		if #self.timeline > 240 then table.remove(self.timeline, 1) end
		return {
			frame = self.frames, executed = result.executed, skipped = result.skipped,
			costMs = result.costMs, scale = decision.scale, sharpen = decision.sharpen,
			triangles = self.stats.triangles, draws = self.stats.drawCalls,
			lights = self.stats.lights,
		}
	end

	function Renderer:run(frames, dt)
		local total = 0
		for _ = 1, (frames or 30) do
			local r = self:renderFrame(dt or (1 / 60))
			total = total + r.costMs
		end
		return total / math.max(1, frames or 30)
	end

	-- ------------------------------------------------------------------ D-O15 integration
	-- One call moves the whole image stack: geometry budgets, lighting, materials, scale.
	function Renderer:applyQuality(quality)
		self.quality = Mathx.clamp(quality or 1, 0, 1)
		local geo = self.geometry:applyQuality(self.quality)
		local light = self.lighting:applyQuality(self.quality)
		local tier = self.quality < 0.45 and "mobile" or (self.quality < 0.8 and "tablet" or "desktop")
		self.materials:setTier(tier)
		self.reconstruction.upscaler.targetMs = self.budgetMs
		local target = math.max(1, math.floor(#self.reconstruction.upscaler.ladder * self.quality))
		self.reconstruction.upscaler.index = target
		return { quality = self.quality, geometry = geo, lighting = light, tier = tier,
			scale = self.reconstruction.upscaler.scale() }
	end

	function Renderer:setViewport(width, height)
		self.width, self.height = width, height
		self.camera.setViewport(width, height)
		self.reconstruction:invalidate("resize")
		self.graph = Kits.create("framegraph", { id = "render.frame", budgetMs = self.budgetMs })
		self:buildFrameGraph()
		return true
	end

	function Renderer:teleportCamera(position, target)
		self.camera.setPosition(position)
		if target then self.camera.lookAt(target) end
		self.reconstruction:onCameraCut()
		return true
	end

	-- ------------------------------------------------------------------ analysis
	function Renderer:frameBreakdown()
		local out = {}
		if not self.graph.compiled then self.graph.compile() end
		for _, id in ipairs(self.graph.compiled) do
			local pass = self.graph.passes[id]
			out[#out + 1] = { id = id, costMs = pass.cost, optional = pass.optional,
				share = pass.cost / math.max(0.001, self.graph.totalCost()) }
		end
		table.sort(out, function(a, b) return a.costMs > b.costMs end)
		return out
	end

	function Renderer:bottleneck()
		local breakdown = self:frameBreakdown()
		if #breakdown == 0 then return nil end
		local worst = breakdown[1]
		local kind = "cpu"
		if self.stats.triangles > 150000 then kind = "geometry" end
		if self.stats.drawCalls > 400 then kind = "draws" end
		if self.stats.lights > 8 then kind = "lighting" end
		return { pass = worst.id, costMs = worst.costMs, kind = kind,
			suggestion = kind == "geometry" and "lower triangleBudget / promote impostors"
				or kind == "draws" and "increase cluster size to merge draws"
				or kind == "lighting" and "reduce maxActive lights or shadow casters"
				or "reduce render scale" }
	end

	function Renderer:report()
		local aliasing = self.graph.alias()
		return {
			frames = self.frames, width = self.width, height = self.height,
			quality = self.quality, budgetMs = self.budgetMs,
			passes = self.stats.passes, skipped = self.stats.skipped,
			triangles = self.stats.triangles, draws = self.stats.drawCalls,
			lights = self.stats.lights, frameMs = self.stats.frameMs,
			gpuBoundFrames = self.stats.gpuBoundFrames,
			renderScale = self.reconstruction.upscaler.scale(),
			effectiveScale = self.reconstruction:effectiveScale(),
			memoryPeakBytes = aliasing.peakBytes, memorySavedBytes = aliasing.savedBytes,
			geometry = self.geometry:report(), lighting = self.lighting:report(),
			materials = self.materials:report(), reconstruction = self.reconstruction:report(),
		}
	end

	return Renderer
end
