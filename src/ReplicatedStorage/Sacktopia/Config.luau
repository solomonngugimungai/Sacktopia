local Config = {}

Config.Round = {
	IntermissionSeconds = 8,
	MinPlayers = 2,
	MaxRoundSeconds = 180,
	SuddenDeathSpeedMultiplier = 1.4,
	SuddenDeathStartSeconds = 90,
}

Config.Sack = {
	BaseSpeed = 60,
	SpeedPerDeflect = 12,
	MaxSpeed = 220,
	Gravity = 110,
	Drag = 0.05,
	Mass = 0.4,
	Radius = 0.6,
	SpawnHeight = 18,
	HitRadius = 3.0,
}

Config.Combat = {
	-- timing window in seconds before predicted impact during which a click counts as a deflect
	WindowOpenLead = 0.45,
	WindowCloseLead = 0.05,
	-- combo
	MaxComboPerPlayer = 3,
	-- vertical bias added to aim so kicks naturally arc rather than ground-skim
	AimUpwardBias = 0.18,
	-- minimum vertical component so the sack always has some hang time
	MinUpwardComponent = 0.12,
}

Config.Arena = {
	Center = Vector3.new(0, 0, 0),
	SpawnRadius = 22,
	-- soft "out of bounds" — sack wrapping back to center if it escapes
	BoundsRadius = 120,
	BoundsHeight = 80,
}

-- Cosmetic-only equippable slots. Mechanic-changing items would mean pay-to-win;
-- v2 deliberately keeps every item visual.
Config.Slots = {
	"Head",
	"Hand",
	"SackSkin",
}

Config.Trail = {
	Lifetime = 0.6,
	WidthScaleStart = 1.4,
	WidthScaleEnd = 0.0,
	NeutralColor = Color3.fromRGB(255, 255, 255),
}

Config.Equip = {
	-- v2: in-memory inventory only. Persistence (DataStore) lands in v3.
	GrantAllOnJoin = true,
	DefaultLoadout = {
		Head = "BasicCap",
		Hand = "None",
		SackSkin = "Classic",
	},
}

Config.KickFX = {
	-- procedural R15 kick: how far to swing the right leg forward (radians) and how long
	SwingAngleRadians = math.rad(70),
	SwingOutSeconds = 0.08,
	SwingBackSeconds = 0.16,
}

-- Lobby + queue tuning
Config.Lobby = {
	Center = Vector3.new(0, 500, 0),
	PlatformRadius = 60,
	PlatformThickness = 4,
	PortalRingRadius = 44,
	PortalSize = Vector3.new(8, 0.5, 8),
	-- queue → match
	QueueAutoStartSeconds = 6, -- once min players are queued, auto-start after this delay
	MaxPlayersPerMatch = 14, -- hard cap on players who actually drop into a single match
}

-- Default per-arena bounds (override per world in Worlds.luau)
Config.ArenaDefaults = {
	BoundsRadius = 120,
	BoundsHeight = 80,
	SpawnRadius = 22,
	SackSpawnHeight = 18,
	PlatformRadius = 90,
	PlatformThickness = 4,
}

-- Hybrid points — wins worth most, top-3 still pays out, all participants get something.
-- Tweak Tiers thresholds to retune progression speed.
Config.Rank = {
	Points = {
		[1] = 10, -- 1st place
		[2] = 4,  -- 2nd
		[3] = 2,  -- 3rd
		Participation = 1, -- everyone else
	},
	Tiers = {
		{ id = "Bronze",   name = "Bronze",   minPoints = 0,    color = Color3.fromRGB(180, 110, 60) },
		{ id = "Silver",   name = "Silver",   minPoints = 50,   color = Color3.fromRGB(190, 190, 200) },
		{ id = "Gold",     name = "Gold",     minPoints = 200,  color = Color3.fromRGB(240, 200, 70) },
		{ id = "Platinum", name = "Platinum", minPoints = 500,  color = Color3.fromRGB(140, 220, 220) },
		{ id = "Diamond",  name = "Diamond",  minPoints = 1500, color = Color3.fromRGB(120, 200, 255) },
		{ id = "Master",   name = "Master",   minPoints = 5000, color = Color3.fromRGB(220, 100, 240) },
	},
}

return Config
