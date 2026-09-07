-- ARKHER UI :: Design System / Theme Framework
-- The single source of truth for every colour, spacing and type size in ARKHER:
-- the engine HUD, the ARKHER Studio surface, the Studio adapter plugin and any
-- game UI built on top of ARKHER. Platform agnostic: it returns numbers, never
-- Roblox objects, so it is testable headless and usable by any adapter.
--
-- Design intent: "instrument panel in a dark cockpit". Deep neutral blues (never
-- pure black, so OLED phones do not smear), one signal accent (ARKHER blue), and
-- three status colours that survive daylight on a phone screen.
--@arkher-module
return function(A)
	local Mathx = A:import("arkher/kernel/mathx")

	local Theme = {}

	-- ------------------------------------------------------------------ tokens
	-- Raw palette. Names describe the colour, not its job (jobs are roles below).
	Theme.TOKENS = {
		void        = 0x0A0C12, -- HUD backdrop
		abyss       = 0x12141A, -- app background
		slate900    = 0x1A1D26, -- panels
		slate800    = 0x232734, -- raised panels / inputs
		slate700    = 0x28303E, -- tracks, dividers
		slate600    = 0x3A4356, -- borders
		slate400    = 0x94A3B8, -- muted text
		slate200    = 0xD7E1F0, -- body text
		white       = 0xF2F6FF,
		arkherBlue  = 0x60B0FF, -- the signal accent
		arkherDeep  = 0x2B6FD4, -- pressed / active accent
		arkherGlow  = 0x78BEFF, -- focus ring, titles
		aurora      = 0x50DC8C, -- success / healthy budget
		amber       = 0xF0C85A, -- warning / degraded budget
		ember       = 0xF06E6E, -- danger / blown budget
		violet      = 0xA98BFF, -- Singularity AI surfaces
		teal        = 0x4FD6D6, -- D-O15 surfaces
	}

	-- ------------------------------------------------------------------ variants
	-- Every variant defines the same role set, so no UI code ever branches on theme.
	local DARK = {
		name = "arkher-dark", dark = true,
		background = Theme.TOKENS.abyss,
		backdrop   = Theme.TOKENS.void,
		surface    = Theme.TOKENS.slate900,
		surfaceAlt = Theme.TOKENS.slate800,
		track      = Theme.TOKENS.slate700,
		border     = Theme.TOKENS.slate600,
		text       = Theme.TOKENS.slate200,
		textStrong = Theme.TOKENS.white,
		textMuted  = Theme.TOKENS.slate400,
		accent     = Theme.TOKENS.arkherBlue,
		accentDeep = Theme.TOKENS.arkherDeep,
		focus      = Theme.TOKENS.arkherGlow,
		success    = Theme.TOKENS.aurora,
		warning    = Theme.TOKENS.amber,
		danger     = Theme.TOKENS.ember,
		ai         = Theme.TOKENS.violet,
		optimizer  = Theme.TOKENS.teal,
	}

	local LIGHT = {
		name = "arkher-light", dark = false,
		background = 0xF4F7FC, backdrop = 0xFFFFFF, surface = 0xFFFFFF,
		surfaceAlt = 0xE9EEF7, track = 0xDCE4F0, border = 0xC3CEDF,
		text = 0x1A2233, textStrong = 0x0B111C, textMuted = 0x5A6880,
		accent = 0x1F6FD0, accentDeep = 0x11498F, focus = 0x1F6FD0,
		success = 0x148A50, warning = 0x9A6A00, danger = 0xC0392B,
		ai = 0x6B4FD6, optimizer = 0x0E7C86,
	}

	local CONTRAST = {
		name = "arkher-contrast", dark = true,
		background = 0x000000, backdrop = 0x000000, surface = 0x0B0B0B,
		surfaceAlt = 0x161616, track = 0x2A2A2A, border = 0xFFFFFF,
		text = 0xFFFFFF, textStrong = 0xFFFFFF, textMuted = 0xD0D0D0,
		accent = 0x7FD4FF, accentDeep = 0x3FA9F5, focus = 0xFFFFFF,
		success = 0x6EFFA8, warning = 0xFFD75E, danger = 0xFF8A8A,
		ai = 0xC9B6FF, optimizer = 0x6FF0F0,
	}

	-- Deuteranopia/protanopia safe: status is carried by blue/amber/magenta, not red/green.
	local DALTON = {
		name = "arkher-daltonic", dark = true,
		background = DARK.background, backdrop = DARK.backdrop, surface = DARK.surface,
		surfaceAlt = DARK.surfaceAlt, track = DARK.track, border = DARK.border,
		text = DARK.text, textStrong = DARK.textStrong, textMuted = DARK.textMuted,
		accent = 0x69B4FF, accentDeep = 0x2B6FD4, focus = 0x9AD1FF,
		success = 0x63C8FF, warning = 0xF0C85A, danger = 0xF07CC8,
		ai = 0xB9A0FF, optimizer = 0x76E2E2,
	}

	Theme.VARIANTS = { [DARK.name] = DARK, [LIGHT.name] = LIGHT,
		[CONTRAST.name] = CONTRAST, [DALTON.name] = DALTON }
	Theme.DEFAULT = DARK.name

	-- ------------------------------------------------------------------ colour maths
	function Theme.rgb(hex)
		local r = math.floor(hex / 65536) % 256
		local g = math.floor(hex / 256) % 256
		local b = hex % 256
		return r, g, b
	end

	function Theme.pack(r, g, b)
		r = Mathx.clamp(math.floor(r + 0.5), 0, 255)
		g = Mathx.clamp(math.floor(g + 0.5), 0, 255)
		b = Mathx.clamp(math.floor(b + 0.5), 0, 255)
		return r * 65536 + g * 256 + b
	end

	function Theme.parse(text)
		local body = string.gsub(tostring(text), "^#", "")
		local n = tonumber(body, 16)
		if not n then return nil, "not a hex colour: " .. tostring(text) end
		return n
	end

	function Theme.toHex(hex)
		return string.format("#%06X", hex)
	end

	function Theme.mix(a, b, t)
		t = Mathx.clamp(t or 0.5, 0, 1)
		local ar, ag, ab = Theme.rgb(a)
		local br, bg, bb = Theme.rgb(b)
		return Theme.pack(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
	end

	function Theme.lighten(hex, amount) return Theme.mix(hex, 0xFFFFFF, amount or 0.15) end
	function Theme.darken(hex, amount) return Theme.mix(hex, 0x000000, amount or 0.15) end

	local function channelLuminance(c)
		local v = c / 255
		if v <= 0.03928 then return v / 12.92 end
		return ((v + 0.055) / 1.055) ^ 2.4
	end

	-- WCAG 2.1 relative luminance.
	function Theme.luminance(hex)
		local r, g, b = Theme.rgb(hex)
		return 0.2126 * channelLuminance(r) + 0.7152 * channelLuminance(g) + 0.0722 * channelLuminance(b)
	end

	-- WCAG contrast ratio, 1.0 (identical) .. 21.0 (black on white).
	function Theme.contrast(a, b)
		local la, lb = Theme.luminance(a), Theme.luminance(b)
		if la < lb then la, lb = lb, la end
		return (la + 0.05) / (lb + 0.05)
	end

	-- Pick whichever of two foregrounds reads better on `background`.
	function Theme.readable(background, light, dark)
		light = light or 0xFFFFFF
		dark = dark or 0x0B111C
		if Theme.contrast(background, light) >= Theme.contrast(background, dark) then return light end
		return dark
	end

	-- ------------------------------------------------------------------ variants API
	function Theme.get(name)
		return Theme.VARIANTS[name or Theme.DEFAULT] or Theme.VARIANTS[Theme.DEFAULT]
	end

	function Theme.role(name, role)
		local v = Theme.get(name)
		local hex = v[role]
		if not hex then return nil, "unknown role: " .. tostring(role) end
		local r, g, b = Theme.rgb(hex)
		return hex, r, g, b
	end

	function Theme.names()
		local out = {}
		for k in pairs(Theme.VARIANTS) do out[#out + 1] = k end
		table.sort(out)
		return out
	end

	-- Every text-on-surface pair a UI is allowed to produce, checked against WCAG AA (4.5:1
	-- for body text, 3.0:1 for large text and UI chrome). Returns ok, failures.
	Theme.PAIRS = {
		{ fg = "text", bg = "background", min = 4.5 },
		{ fg = "text", bg = "surface", min = 4.5 },
		{ fg = "text", bg = "surfaceAlt", min = 4.5 },
		{ fg = "textStrong", bg = "surface", min = 4.5 },
		{ fg = "textMuted", bg = "surface", min = 3.0 },
		{ fg = "accent", bg = "surface", min = 3.0 },
		{ fg = "success", bg = "surface", min = 3.0 },
		{ fg = "warning", bg = "surface", min = 3.0 },
		{ fg = "danger", bg = "surface", min = 3.0 },
		{ fg = "ai", bg = "surface", min = 3.0 },
		{ fg = "optimizer", bg = "surface", min = 3.0 },
	}

	function Theme.audit(name)
		local v = Theme.get(name)
		local failures = {}
		for _, pair in ipairs(Theme.PAIRS) do
			local ratio = Theme.contrast(v[pair.fg], v[pair.bg])
			if ratio < pair.min then
				failures[#failures + 1] = { fg = pair.fg, bg = pair.bg,
					ratio = math.floor(ratio * 100) / 100, min = pair.min }
			end
		end
		return #failures == 0, failures
	end

	function Theme.auditAll()
		local out = {}
		for _, name in ipairs(Theme.names()) do
			local ok, failures = Theme.audit(name)
			out[name] = { ok = ok, failures = failures }
		end
		return out
	end

	-- ------------------------------------------------------------------ metrics (mobile first)
	-- Base unit is 4px. Touch targets never go below 44px, which is the smallest
	-- reliably tappable target on a phone; desktop may shrink to 28.
	Theme.METRICS = {
		unit = 4, radius = 8, radiusLarge = 14, stroke = 1,
		touchTarget = 44, pointerTarget = 28,
		gutter = 12, panelPadding = 12, gap = 8,
		font = { micro = 11, small = 13, body = 15, title = 18, display = 24 },
	}

	-- Scales metrics for a device: phones get bigger targets and type, TVs get more again,
	-- desktops get denser UI. `device` is a table from arkher/do15/device.
	function Theme.metricsFor(device)
		device = device or {}
		local tier = device.tier or "mobile"
		local touch = device.touch
		if touch == nil then touch = (tier == "mobile" or tier == "tablet") end
		local scale = 1.0
		if tier == "mobile" then scale = 1.15
		elseif tier == "tablet" then scale = 1.08
		elseif tier == "console" then scale = 1.35
		elseif tier == "vr" then scale = 1.5
		elseif tier == "desktop" then scale = 1.0 end
		local screen = device.screen or {}
		local width = screen.width or 1280
		if width < 700 then scale = scale * 1.05 end
		local m = {
			scale = scale,
			unit = Theme.METRICS.unit * scale,
			radius = math.floor(Theme.METRICS.radius * scale),
			radiusLarge = math.floor(Theme.METRICS.radiusLarge * scale),
			stroke = Theme.METRICS.stroke,
			gutter = math.floor(Theme.METRICS.gutter * scale),
			panelPadding = math.floor(Theme.METRICS.panelPadding * scale),
			gap = math.floor(Theme.METRICS.gap * scale),
			target = math.floor((touch and Theme.METRICS.touchTarget or Theme.METRICS.pointerTarget) * scale),
			font = {},
		}
		for k, v in pairs(Theme.METRICS.font) do m.font[k] = math.floor(v * scale + 0.5) end
		return m
	end

	-- ------------------------------------------------------------------ semantic helpers
	-- One place decides what "quality 0.62" looks like, everywhere in ARKHER.
	function Theme.qualityColor(q, name)
		local v = Theme.get(name)
		if q >= 0.7 then return v.success end
		if q >= 0.4 then return v.warning end
		return v.danger
	end

	function Theme.statusColor(status, name)
		local v = Theme.get(name)
		local map = { ok = v.success, healthy = v.success, degraded = v.warning,
			warning = v.warning, failed = v.danger, error = v.danger, offline = v.textMuted,
			ai = v.ai, optimizing = v.optimizer }
		return map[status] or v.text
	end

	-- Deterministic colour for an arbitrary key (system category chips, graph edges,
	-- profiler lanes). Golden-ratio hue rotation keeps neighbours distinguishable.
	function Theme.categoryColor(key, name)
		local v = Theme.get(name)
		local seed = 0
		for i = 1, #tostring(key) do
			seed = (seed * 31 + string.byte(tostring(key), i)) % 1000003
		end
		local t = (seed * 0.6180339887) % 1
		local wheel = { v.accent, v.optimizer, v.ai, v.warning, v.success, v.danger, v.focus }
		local idx = math.floor(t * #wheel) + 1
		local nextIdx = idx % #wheel + 1
		local localT = (t * #wheel) - math.floor(t * #wheel)
		return Theme.mix(wheel[idx], wheel[nextIdx], localT * 0.5)
	end

	-- A gradient ramp (profiler heat, terrain material preview, budget bars).
	function Theme.ramp(stops, samples)
		local out = {}
		samples = samples or 8
		if #stops < 2 then return { stops[1] or 0 } end
		for i = 0, samples - 1 do
			local t = i / (samples - 1)
			local pos = t * (#stops - 1)
			local idx = math.min(#stops - 1, math.floor(pos) + 1)
			out[#out + 1] = Theme.mix(stops[idx], stops[idx + 1], pos - (idx - 1))
		end
		return out
	end

	function Theme.describe(name)
		local v = Theme.get(name)
		local ok, failures = Theme.audit(v.name)
		local roles = {}
		for k, hex in pairs(v) do
			if type(hex) == "number" then roles[k] = Theme.toHex(hex) end
		end
		return { name = v.name, dark = v.dark, roles = roles,
			accessible = ok, failures = failures, metrics = Theme.METRICS }
	end

	return Theme
end
