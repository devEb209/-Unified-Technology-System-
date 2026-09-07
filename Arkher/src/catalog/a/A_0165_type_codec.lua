-- ARKHER SYSTEM A.0165 :: Type Codec
-- Category A - UES / CORE
-- Kernel-level engine capability: the UES foundation every other ARKHER framework stands on.
-- Kit: codec (encode/decode/diff of the subsystem payloads)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "A.0165"
	S.key = "arkher.core.type.codec"
	S.name = "Type Codec"
	S.category = "A"
	S.family = "UES / CORE"
	S.area = "Type"
	S.aspect = "Codec"
	S.kit = "codec"
	S.version = "1.0.0"
	S.deps = { "arkher.core.type.access_guard" }
	S.tags = { "a", "type", "codec", "core" }
	S.description = "Type Codec: encode/decode/diff of the subsystem payloads for the Type subsystem."
	S.params = {
		backlogLimit = 9,
		baseRadius = 360,
		baseWeight = 0.71,
		bias = 0.01,
		biasWeight = 0.06,
		ceiling = 369,
		detailWeight = 0.61,
		failureTolerance = 1,
		horizon = 2,
		integrator = "verlet",
		minConfidence = 0.41,
		minThrottle = 0.155,
		regressionSlope = 0.055,
		saturation = 0.91,
		scale = 2.1
	}
	S.features = { "encode", "decode", "diff", "patch", "checksum", "roundTrip", "stats", "pack", "unpack", "compressionRatio", "transmit", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("codec", { id = "arkher.core.type.codec", format = "quantized", quantBits = 9 })
		inst.system = S
		inst.ctx = ctx

	function inst.pack(value)
		local payload = inst.encode(value)
		return { data = payload, crc = inst.checksum(value), bytes = #payload }
	end
	function inst.unpack(packet)
		local value = inst.decode(packet.data)
		return value, inst.checksum(value) == packet.crc
	end
	function inst.compressionRatio(value)
		local raw = #tostring(value)
		local packed = #inst.encode(value)
		if packed == 0 then return 1 end
		return raw / packed
	end
	function inst.transmit(value, channel)
		local packet = inst.pack(value)
		if channel then channel(packet) end
		return packet.bytes
	end

		function inst.describe()
			return { id = S.id, key = S.key, name = S.name, category = S.category, family = S.family,
				area = S.area, aspect = S.aspect, kit = S.kit, features = S.features,
				params = S.params, stats = inst.stats() }
		end

		function inst.health()
			local st = inst.stats()
			local status = "ok"
			for k, v in pairs(st) do
				if k == "failures" and type(v) == "number" and v > 0 then status = "degraded" end
				if k == "blocked" and type(v) == "number" and v > 0 and status == "ok" then status = "throttled" end
			end
			return { system = S.key, status = status, stats = st }
		end

		function inst.integrate(engine)
			if not engine then return false end
			inst.engine = engine
			if engine.bus then
				engine.bus:subscribe("arkher.core.type.*", function(payload) inst.lastSignal = payload end)
			end
			if engine.registry then engine.registry[S.key] = inst end
			return true
		end

		function inst.selfTest()
			local ok, err = pcall(function()
		local value = { area = S.area, samples = { 1, 2, 3 }, label = "probe" }
		local packet = inst.pack(value)
		local decoded, valid = inst.unpack(packet)
		if inst.format == "quantized" or inst.format == "json" then return decoded ~= nil end
		return valid and decoded.label == "probe" 
			end)
			if not ok then return false, tostring(err) end
			return err == true or err == nil, err
		end

		return inst
	end

	return S
end
