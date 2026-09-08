--!strict
-- ARKHER Config — single source for paths, sizes, input, product identity
local Config = {}

Config.product = {
	name = "ARKHER Studio",
	version = "1.0.0-V2",
	trademark = "ARKHER™",
	tagline = "AAA console/PC quality — mobile → unlimited",
	company = "Unified Technology System",
}

Config.layout = {
	topBarH = 36,           -- TopBar height — hosts 1 row tabs + tool row (32+4 gap)
	toolRowH = 36,          -- second row INSIDE topBar container → total 72 but visually grouped
	statusH = 22,
	explorerW = 260,
	propertiesW = 300,
	windowHeaderH = 28,
	windowMin = Vector2.new(280, 180),
	corner = 8,
	cornerLarge = 14,
	gutter = 12,
	gap = 8,
}

Config.input = {
	flySpeed = 16,
	flyFastMult = 3.5,
	mouseSens = 0.22,
}

Config.worldCover = {
	-- ESA WorldCover 10m — 11 classes exact palette (from PUM)
	-- Tree #006400 Shrub #ffbb22 Grass #ffff4c Crop #f096ff Built #fa0000 Bare #b4b4b4 Snow #f0f0f0 Water #0064c8 Wet #0096a0 Mang #00cf75 Moss #fae6a0
	classes = {
		{ id=10, name="Tree cover",        color=Color3.fromRGB(0,100,0)   },
		{ id=20, name="Shrubland",         color=Color3.fromRGB(255,187,34)},
		{ id=30, name="Grassland",         color=Color3.fromRGB(255,255,76)},
		{ id=40, name="Cropland",          color=Color3.fromRGB(240,150,255)},
		{ id=50, name="Built-up",          color=Color3.fromRGB(250,0,0)   },
		{ id=60, name="Bare / Sparse",     color=Color3.fromRGB(180,180,180)},
		{ id=70, name="Snow / Ice",        color=Color3.fromRGB(240,240,240)},
		{ id=80, name="Water",             color=Color3.fromRGB(0,100,200) },
		{ id=90, name="Wetlands",          color=Color3.fromRGB(0,150,160) },
		{ id=95, name="Mangroves",         color=Color3.fromRGB(0,207,117)},
		{ id=100,name="Moss / Lichen",     color=Color3.fromRGB(250,230,160)},
	}
}

Config.biomes = {
	-- OpenLandMap PNV — 32 biomes simplified labels (1km global)
	names = {"Tropical rain","Tropical moist deciduous","Tropical dry","Tropical shrub","Tropical desert","Tropical steppe","Subtropical humid","Subtropical dry","Subtropical desert","Subtropical steppe","Temperate broadleaf","Temperate conifer","Temperate mixed","Temperate deciduous","Boreal forest","Boreal taiga","Boreal tundra","Montane grass","Montane forest","Mediterranean","Desert hot","Desert cold","Semi-desert","Savanna","Grassland","Shrubland","Wetland","Mangrove","Tundra","Ice","Urban","Water"}
}

return Config
