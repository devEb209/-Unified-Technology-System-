-- ARKHER SYSTEM X.0068 :: Network Validation Integrity Codec
-- Category X - SECURITY / RELIABILITY
-- Security and reliability capability: nothing enters the engine unvalidated or ungoverned.
-- Kit: codec (checksummed encoding of protected data)
--@arkher-module
return function(A)
	local Kits = A:import("arkher/runtime/kits")
	local Vec = A:import("arkher/kernel/vec")

	local S = {}
	S.id = "X.0068"
	S.key = "arkher.security.network.integrity_codec"
	S.name = "Network Validation Integrity Codec"
	S.category = "X"
	S.family = "SECURITY / RELIABILITY"
	S.area = "Network Validation"
	S.aspect = "Integrity Codec"
	S.kit = "codec"
	S.version = "1.0.0"
	S.deps = { "arkher.security.network.analyzer" }
	S.tags = { "x", "network", "codec", "security" }
	S.description = "Network Validation Integrity Codec: checksummed encoding of protected data for the Network Validation subsystem."
	S.params = {
		backlogLimit = 38,
		baseRadius = 240,
		baseWeight = 0.7,
		bias = 0.3,
		biasWeight = 0.15,
		ceiling = 174,
		detailWeight = 0.7,
		failureTolerance = 0,
		horizon = 7,
		integrator = "euler",
		minConfidence = 0.7,
		minThrottle = 0.2,
		regressionSlope = 0.1,
		saturation = 0.9,
		scale = 3.0
	}
	S.features = { "encode", "decode", "diff", "patch", "checksum", "roundTrip", "stats", "pack", "unpack", "compressionRatio", "transmit", "describe", "health", "integrate", "selfTest" }

	function S.create(ctx)
		ctx = ctx or {}
		local inst = Kits.create("codec", { id = "arkher.security.network.integrity_codec", format = "rle", quantBits = 14 })
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
				engine.bus:subscribe("arkher.security.network.*", function(payload) inst.lastSignal = payload end)
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
