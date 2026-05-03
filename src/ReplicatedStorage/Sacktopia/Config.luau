local Config = {}

Config.Round = {
	IntermissionSeconds = 8,
	MinPlayers = 2,
	MaxRoundSeconds = 180,
	SuddenDeathSpeedMultiplier = 1.4,
	SuddenDeathStartSeconds = 90,
}

Config.Sack = {
	BaseSpeed = 45, -- was 60 — slower base so reactions are humanly possible
	SpeedPerDeflect = 10,
	MaxSpeed = 180,
	Gravity = 35, -- was 110 — much gentler arc so the sack actually hangs in the air
	Drag = 0.04,
	Mass = 0.4,
	Radius = 0.6,
	SpawnHeight = 26, -- was 18 — gives more travel time before first contact
	HitRadius = 3.0,
}

Config.Combat = {
	-- LANDING-ZONE-BASED deflect (sports / Pokken style). The server predicts where the
	-- sack will land; any alive player whose character is within LandingZoneRadius studs
	-- of that landing point can press SPACE to deflect. Clients render a disc at the
	-- landing point so you know where to be.
	LandingZoneRadius = 8,
	-- WindowOpenDistance is the fallback proximity in case landing prediction fails
	-- (e.g. zero velocity). Stays open while sack is within this distance of target.
	WindowOpenDistance = 24,
	-- legacy lead times — kept for the timing-ring UI animation only
	WindowOpenLead = 0.45,
	WindowCloseLead = 0.05,
	-- combo
	MaxComboPerPlayer = 3,
	-- vertical bias added to aim so kicks naturally arc rather than ground-skim
	AimUpwardBias = 0.4,
	-- minimum vertical component so the sack always has some hang time
	MinUpwardComponent = 0.3,
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
	-- New in-memory inventories grant Starter items only by default; in dev (Debug.GrantAllItems)
	-- every player gets every cosmetic so we can test cycling without buying.
	-- Persistence is now handled by PlayerData.luau.
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

-- Dash ability (Q key): short directional impulse with cooldown
Config.Dash = {
	Cooldown = 5,
	Impulse = 6000, -- raw impulse magnitude applied to the HumanoidRootPart
	UpwardComponent = 0.15, -- small lift so dashes feel snappy
}

-- Master debug switches. Flip Enabled = false for public release; flip Logs to false to
-- silence the diagnostic prints. GrantAllItems=true gives every player every cosmetic at
-- join (no shop wired yet, so off would mean players can never equip anything).
Config.Debug = {
	Enabled = false,
	Logs = false,
	GrantAllItems = true,
}

-- Coins are a separate currency from rank Points — used (later) to buy cosmetics.
Config.Coins = {
	[1] = 50,
	[2] = 20,
	[3] = 10,
	Participation = 5,
}

-- Built-in Roblox sounds; the user can swap any of these for purchased asset IDs later.
Config.Sounds = {
	Deflect = "rbxasset://sounds/electronicpingshort.wav",
	Drop = "rbxasset://sounds/snap.mp3",
	Eliminated = "rbxasset://sounds/uuhhh.mp3",
	Win = "rbxasset://sounds/action_jump_landing.mp3",
	UiClick = "rbxasset://sounds/electronicpingshort.wav",
}

-- Music tracks. Replace these IDs with real Roblox audio asset IDs you've purchased
-- (or that allow free game use). Format: "rbxassetid://<numeric_id>".
-- Find tracks on https://create.roblox.com/store/audio  → "Use" → copy the asset ID.
-- Until you set real IDs, the music system stays silent (no error).
Config.Music = {
	-- TODO: replace with an upbeat track
	LobbyTrackId = "",
	MatchTrackId = "",
	Volume = 0.35, -- 0 to 1; keep low so it doesn't drown out SFX
	FadeSeconds = 1.5,
}

-- Daily login rewards. Tier resets to day 1 if a player misses a day (>48 h since last
-- claim). Eligibility for the next claim opens 22 h after the previous one.
Config.DailyRewards = {
	[1] = { coins = 50 },
	[2] = { coins = 100 },
	[3] = { coins = 150, item = "FratCap" }, -- gifts the cosmetic if not owned
	[4] = { coins = 200 },
	[5] = { coins = 300 },
	[6] = { coins = 500 },
	[7] = { coins = 1000, skin = "Disco" },
	-- After day 7 streak resets to day 1.
}

-- First-time tutorial shown once per save (tutorialSeen flag flips to true after dismiss).
Config.Tutorial = {
	Title = "WELCOME TO SACKTOPIA",
	Lines = {
		"🎯  Walk through a PORTAL to enter a world",
		"🟢  Step on the GREEN pad to queue for a match",
		"💥  SPACE or LEFT-CLICK = deflect the sack",
		"🎯  Aim with your cursor — sack flies where you point",
		"⚡  Q = dash",
		"🚫  DROP the sack and you're OUT",
		"🥋  Yellow pad in PRACTICE = solo training, no elimination",
	},
}

-- Anti-spam intervals in seconds for each client→server remote.
Config.RateLimit = {
	DeflectAttempt = 0.05, -- 20 Hz cap
	EquipItem = 0.4,
	JoinQueue = 0.3,
	LeaveQueue = 0.3,
	DashRequest = 0.5,
}

-- Streak thresholds — name + min consecutive eliminations within a single match
Config.Streaks = {
	{ count = 2, name = "DOUBLE KILL", color = Color3.fromRGB(255, 200, 80) },
	{ count = 3, name = "TRIPLE KILL", color = Color3.fromRGB(255, 140, 60) },
	{ count = 4, name = "QUADRA KILL", color = Color3.fromRGB(255, 60, 80) },
	{ count = 5, name = "PENTA KILL", color = Color3.fromRGB(220, 70, 220) },
	{ count = 6, name = "GODLIKE", color = Color3.fromRGB(120, 220, 255) },
}

-- Lobby + queue tuning
Config.Lobby = {
	-- Sky lobby — high enough to see all worlds at y=0 below, like Natural Disasters
	Center = Vector3.new(0, 1000, 0),
	PlatformRadius = 60,
	PlatformThickness = 4,
	PortalRingRadius = 44,
	PortalSize = Vector3.new(8, 0.5, 8),
	RailingHeight = 3, -- low decorative parapet so the worlds below stay visible
	InvisibleBarrierHeight = 26, -- transparent collision wall so nobody falls off
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
