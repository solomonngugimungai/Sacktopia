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

return Config
