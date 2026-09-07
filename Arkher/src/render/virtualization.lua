-- ARKHER RENDER :: Geometry Virtualization Framework
-- ARKHER's answer to a hard instance/draw-call ceiling: cluster the world, build HLOD
-- proxies and impostors, and spend a measured triangle + draw budget on what is visible.
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Mathx = A:import("arkher/kernel/mathx")
	local Vec = A:import("arkher/kernel/vec")
	local Spatial = A:import("arkher/kernel/spatial")
	local v3 = Vec.vec3

	local Virtualization = {}
	Virtualization.__index = Virtualization

	function Virtualization.new(opts)
		opts = opts or {}
		local self = setmetatable({}, Virtualization)
		self.impostors = Kits.create("impostor", { id = "world.impostors",
			atlasSlots = opts.atlasSlots or 128, errorThreshold = opts.errorThreshold or 2.0 })
		self.clusterSize = opts.clusterSize or 128
		self.clusters = {}
		self.clusterOrder = {}
		self.objects = {}
		self.objectOrder = {}
		self.triangleBudget = opts.triangleBudget or 120000
		self.drawBudget = opts.drawBudget or 500
		self.builds = 0
		self.frames = 0
		self.lastPass = nil
		return self
	end

	local function clusterKey(position, size)
		return math.floor(position.x / size) .. ":" .. math.floor(position.z / size)
	end

	function Virtualization:add(id, opts)
		opts = opts or {}
		if self.objects[id] then return nil, "duplicate object" end
		local obj = { id = id, position = opts.position or v3(), radius = opts.radius or 4,
			triangles = opts.triangles or 2000, material = opts.material, static = opts.static ~= false,
			cluster = nil, mode = "mesh" }
		local key = clusterKey(obj.position, self.clusterSize)
		local cluster = self.clusters[key]
		if not cluster then
			cluster = { key = key, members = {}, triangles = 0,
				bounds = Spatial.aabb(obj.position, obj.position), proxy = nil, built = false }
			self.clusters[key] = cluster
			self.clusterOrder[#self.clusterOrder + 1] = key
		end
		cluster.members[#cluster.members + 1] = id
		cluster.triangles = cluster.triangles + obj.triangles
		cluster.bounds = cluster.bounds:expand(obj.position + v3(obj.radius, obj.radius, obj.radius))
		cluster.bounds = cluster.bounds:expand(obj.position - v3(obj.radius, obj.radius, obj.radius))
		cluster.built = false
		obj.cluster = key
		self.objects[id] = obj
		self.objectOrder[#self.objectOrder + 1] = id
		self.impostors.register(id, { triangles = obj.triangles, radius = obj.radius })
		return obj
	end

	-- Build one HLOD proxy per cluster plus impostor views for the heavy members.
	function Virtualization:build(maxViews)
		local built = 0
		for _, key in ipairs(self.clusterOrder) do
			local cluster = self.clusters[key]
			if not cluster.built and #cluster.members > 0 then
				local proxyId = "hlod:" .. key
				if not self.impostors.entries[proxyId] then
					self.impostors.buildHLOD(proxyId, cluster.members)
				end
				cluster.proxy = proxyId
				local heavy = {}
				for _, id in ipairs(cluster.members) do heavy[#heavy + 1] = id end
				table.sort(heavy, function(a, b)
					return self.objects[a].triangles > self.objects[b].triangles
				end)
				for i = 1, math.min(maxViews or 4, #heavy) do
					self.impostors.captureViews(heavy[i], 8)
				end
				cluster.built = true
				built = built + 1
			end
		end
		self.builds = self.builds + 1
		return built
	end

	function Virtualization:clusterCount() return #self.clusterOrder end

	function Virtualization:clustersInRange(viewer, radius)
		local out = {}
		for _, key in ipairs(self.clusterOrder) do
			local cluster = self.clusters[key]
			local center = cluster.bounds:center()
			if center:distance(viewer) <= radius then out[#out + 1] = key end
		end
		table.sort(out)
		return out
	end

	-- The per-frame decision: for everything in range, choose mesh / impostor / proxy /
	-- culled so the frame fits the triangle and draw budgets. Nearest wins.
	function Virtualization:resolve(viewer, opts)
		opts = opts or {}
		self.frames = self.frames + 1
		local radius = opts.radius or 900
		local screenHeight = opts.screenHeight or 720
		local fov = opts.fov or math.rad(70)
		local triangleBudget = opts.triangleBudget or self.triangleBudget
		local drawBudget = opts.drawBudget or self.drawBudget
		local candidates = {}
		for _, id in ipairs(self.objectOrder) do
			local obj = self.objects[id]
			local d = obj.position:distance(viewer)
			if d <= radius then candidates[#candidates + 1] = { id = id, distance = d, obj = obj } end
		end
		table.sort(candidates, function(a, b)
			if a.distance == b.distance then return a.id < b.id end
			return a.distance < b.distance
		end)
		local triangles, draws = 0, 0
		local result = { mesh = {}, impostor = {}, proxy = {}, culled = {},
			triangles = 0, draws = 0, clusters = {} }
		local clusterProxied = {}
		for _, c in ipairs(candidates) do
			local obj = c.obj
			local suggestion = self.impostors.select(obj.id, c.distance, screenHeight, fov)
			if suggestion == "culled" then
				obj.mode = "culled"
				result.culled[#result.culled + 1] = obj.id
			elseif triangles + obj.triangles <= triangleBudget and draws < drawBudget
				and suggestion == "mesh" then
				obj.mode = "mesh"
				triangles = triangles + obj.triangles
				draws = draws + 1
				result.mesh[#result.mesh + 1] = obj.id
			elseif draws < drawBudget and suggestion == "impostor" then
				obj.mode = "impostor"
				triangles = triangles + 2
				draws = draws + 1
				result.impostor[#result.impostor + 1] = obj.id
			else
				-- out of budget: fold the whole cluster into its HLOD proxy, once
				obj.mode = "proxy"
				local cluster = self.clusters[obj.cluster]
				if cluster and cluster.proxy and not clusterProxied[obj.cluster]
					and draws < drawBudget then
					clusterProxied[obj.cluster] = true
					local proxy = self.impostors.entries[cluster.proxy]
					triangles = triangles + (proxy and proxy.triangles or 0)
					draws = draws + 1
					result.clusters[#result.clusters + 1] = cluster.proxy
				end
				result.proxy[#result.proxy + 1] = obj.id
			end
		end
		result.triangles = triangles
		result.draws = draws
		result.candidates = #candidates
		result.withinBudget = triangles <= triangleBudget and draws <= drawBudget
		self.lastPass = result
		return result
	end

	-- What the virtualization actually saved this frame, in triangles.
	function Virtualization:savings()
		if not self.lastPass then return 0, 0 end
		local raw = 0
		for _, id in ipairs(self.objectOrder) do raw = raw + self.objects[id].triangles end
		local drawn = self.lastPass.triangles
		if raw == 0 then return 0, 0 end
		return raw - drawn, 1 - (drawn / raw)
	end

	function Virtualization:applyQuality(quality)
		quality = Mathx.clamp(quality or 1, 0, 1)
		self.triangleBudget = math.floor(30000 + quality * 220000)
		self.drawBudget = math.floor(120 + quality * 900)
		self.impostors.errorThreshold = Mathx.lerp(4.0, 1.2, quality)
		return { triangleBudget = self.triangleBudget, drawBudget = self.drawBudget,
			errorThreshold = self.impostors.errorThreshold }
	end

	function Virtualization:report()
		local saved, ratio = self:savings()
		return {
			objects = #self.objectOrder, clusters = #self.clusterOrder,
			builds = self.builds, frames = self.frames,
			triangleBudget = self.triangleBudget, drawBudget = self.drawBudget,
			lastTriangles = self.lastPass and self.lastPass.triangles or 0,
			lastDraws = self.lastPass and self.lastPass.draws or 0,
			savedTriangles = saved, savedRatio = ratio,
			impostorSlots = self.impostors.stats().slots,
		}
	end

	return Virtualization
end
