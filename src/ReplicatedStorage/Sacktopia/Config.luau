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

return Config
