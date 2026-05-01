--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))

local ArenaBuilder = {}

local ROOT_NAME = "SacktopiaWorld"

-- ---- shared helpers -------------------------------------------------------

local function getRoot(): Folder
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = ROOT_NAME
	f.Parent = Workspace
	return f
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function disc(name: string, center: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material): BasePart
	-- Cylinder primitive aligned along X by default; rotate so the round face is the floor.
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

local function billboard(parent: Instance, text: string, color: Color3, sizeStuds: Vector2, offsetY: number): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = "Label"
	b.Size = UDim2.fromScale(sizeStuds.X, sizeStuds.Y)
	b.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.MaxDistance = 1500
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = text
	label.Parent = b
	b.Parent = parent
	return b
end

-- ring of N wall segments around `center` at `radius`, height H, thickness T.
-- segmentCount divides the circle; gaps optional via gapAngles (radians) — any segment whose
-- center angle is within gapHalfWidth of a gap angle is skipped (lets portals "punch through").
local function wallRing(parent: Instance, opts: {
	center: Vector3,
	radius: number,
	height: number,
	thickness: number,
	segmentCount: number,
	color: Color3,
	material: Enum.Material,
	topAccentColor: Color3?,
	topAccentMaterial: Enum.Material?,
	gapAngles: { number }?,
	gapHalfWidth: number?,
})
	local segCount = opts.segmentCount
	local stepAngle = math.pi * 2 / segCount
	-- chord length for the polygon side
	local chord = 2 * opts.radius * math.sin(stepAngle / 2)
	local segLen = chord + opts.thickness * 0.4 -- slight overlap so corners look closed
	for i = 1, segCount do
		local angle = (i - 0.5) * stepAngle
		if opts.gapAngles and opts.gapHalfWidth then
			local skip = false
			for _, ga in opts.gapAngles do
				local d = math.atan2(math.sin(angle - ga), math.cos(angle - ga))
				if math.abs(d) < opts.gapHalfWidth then
					skip = true
					break
				end
			end
			if skip then
				continue
			end
		end
		local cx = math.cos(angle) * opts.radius
		local cz = math.sin(angle) * opts.radius
		local pos = opts.center + Vector3.new(cx, opts.height / 2, cz)
		local cf = CFrame.new(pos) * CFrame.fromMatrix(
			Vector3.zero,
			Vector3.new(-math.sin(angle), 0, math.cos(angle)), -- right
			Vector3.new(0, 1, 0) -- up
		)
		local seg = part({
			Name = "WallSeg_" .. i,
			Size = Vector3.new(segLen, opts.height, opts.thickness),
			CFrame = cf,
			Color = opts.color,
			Material = opts.material,
		})
		seg.Parent = parent
		if opts.topAccentColor then
			local accent = part({
				Name = "WallAccent_" .. i,
				Size = Vector3.new(segLen, 0.4, opts.thickness * 0.6),
				CFrame = CFrame.new(pos + Vector3.new(0, opts.height / 2, 0))
					* CFrame.fromMatrix(
						Vector3.zero,
						Vector3.new(-math.sin(angle), 0, math.cos(angle)),
						Vector3.new(0, 1, 0)
					),
				Color = opts.topAccentColor,
				Material = opts.topAccentMaterial or Enum.Material.Neon,
				CanCollide = false,
			})
			accent.Parent = parent
		end
	end
end

-- ---- lobby (Blade Ball aesthetic) -----------------------------------------

local builtPortals: { { world: Worlds.World, part: BasePart } } = {}
local lobbySpawn: SpawnLocation? = nil

-- per-world queue infrastructure
local queuePads: { [string]: BasePart } = {}
local returnPads: { [string]: BasePart } = {}
local queueBoardLabels: { [string]: TextLabel } = {}
local stagingCFrames: { [string]: CFrame } = {}

export type Portal = { world: Worlds.World, part: BasePart }

local LOBBY_DARK = Color3.fromRGB(20, 14, 38)
local LOBBY_DARK_2 = Color3.fromRGB(34, 22, 58)
local NEON_CYAN = Color3.fromRGB(80, 220, 255)
local NEON_MAGENTA = Color3.fromRGB(255, 70, 200)

local function buildLobby(root: Folder)
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = root

	local center = Config.Lobby.Center
	local r = Config.Lobby.PlatformRadius

	-- tiered glow plinth
	local glowDisc = disc("LobbyGlow", center - Vector3.new(0, 1.5, 0), r + 8, 0.4, NEON_CYAN, Enum.Material.Neon)
	glowDisc.CanCollide = false
	glowDisc.Transparency = 0.2
	glowDisc.Parent = lobbyFolder

	local underTier = disc("LobbyUnder", center - Vector3.new(0, 1.0, 0), r + 4, 1.5, LOBBY_DARK, Enum.Material.SmoothPlastic)
	underTier.CanCollide = false
	underTier.Parent = lobbyFolder

	local mainPad = disc("LobbyPad", center, r, Config.Lobby.PlatformThickness, LOBBY_DARK_2, Enum.Material.SmoothPlastic)
	mainPad.Parent = lobbyFolder

	-- magenta trim ring on top edge (thin disc with hollow look = full disc in neon, slightly raised)
	local trim = disc("LobbyTrim", center + Vector3.new(0, Config.Lobby.PlatformThickness / 2 + 0.05, 0), r, 0.1, NEON_MAGENTA, Enum.Material.Neon)
	trim.CanCollide = false
	trim.Parent = lobbyFolder

	-- radial floor lines (alternating cyan/magenta)
	for i = 1, 8 do
		local angle = (i - 1) / 8 * math.pi * 2
		local color = (i % 2 == 0) and NEON_CYAN or NEON_MAGENTA
		local len = r - 8
		local cx = math.cos(angle) * (len / 2 + 6)
		local cz = math.sin(angle) * (len / 2 + 6)
		local stripe = part({
			Name = "FloorStripe_" .. i,
			Size = Vector3.new(len, 0.1, 0.6),
			CFrame = CFrame.new(center + Vector3.new(cx, Config.Lobby.PlatformThickness / 2 + 0.06, cz))
				* CFrame.Angles(0, -angle, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		stripe.Transparency = 0.05
		stripe.Parent = lobbyFolder
	end

	-- center pillar (energy beam)
	local pillar = part({
		Name = "CenterPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(45, 5, 5), -- length along X (will become height after rotate)
		CFrame = CFrame.new(center + Vector3.new(0, 22, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = NEON_CYAN,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.15,
	})
	pillar.Parent = lobbyFolder
	local pillarLight = Instance.new("PointLight")
	pillarLight.Color = NEON_CYAN
	pillarLight.Brightness = 4
	pillarLight.Range = 60
	pillarLight.Parent = pillar

	-- pillar cap halo (a thin disc above)
	local cap = disc("PillarCap", center + Vector3.new(0, 46, 0), 9, 0.4, NEON_MAGENTA, Enum.Material.Neon)
	cap.CanCollide = false
	cap.Transparency = 0.1
	cap.Parent = lobbyFolder

	-- portal angles around the perimeter
	local portalAngles = {}
	for i = 1, #Worlds.List do
		local angle = (i - 1) / #Worlds.List * math.pi * 2 - math.pi / 2
		table.insert(portalAngles, angle)
	end

	-- low decorative parapet so the worlds below stay visible (Natural Disasters style)
	wallRing(lobbyFolder, {
		center = center,
		radius = r - 1,
		height = Config.Lobby.RailingHeight,
		thickness = 1.2,
		segmentCount = 32,
		color = LOBBY_DARK,
		material = Enum.Material.SmoothPlastic,
		topAccentColor = NEON_MAGENTA,
		topAccentMaterial = Enum.Material.Neon,
		gapAngles = portalAngles,
		gapHalfWidth = math.rad(11),
	})

	-- invisible safety barrier above the parapet so nobody falls off this 1000-stud-high lobby.
	-- Only the doorways (gaps) let players through; portals teleport them before they fall.
	wallRing(lobbyFolder, {
		center = center,
		radius = r - 0.6,
		height = Config.Lobby.InvisibleBarrierHeight,
		thickness = 1.0,
		segmentCount = 32,
		color = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.ForceField,
		gapAngles = portalAngles,
		gapHalfWidth = math.rad(11),
	})
	-- (set transparency on the barrier segments now that they exist)
	for _, child in lobbyFolder:GetChildren() do
		if child:IsA("BasePart") and child.Material == Enum.Material.ForceField and child.Name:match("^WallSeg_") then
			child.Transparency = 0.85
		end
	end

	-- short pylon at each gap to frame the portal doorway visually
	for _, angle in portalAngles do
		for _, side in { -1, 1 } do
			local sideAngle = angle + side * math.rad(11)
			local px = math.cos(sideAngle) * (r - 1)
			local pz = math.sin(sideAngle) * (r - 1)
			local pillarPost = part({
				Name = "PortalFrame",
				Size = Vector3.new(1.6, 8, 1.6),
				CFrame = CFrame.new(center + Vector3.new(px, 4, pz)),
				Color = LOBBY_DARK,
				Material = Enum.Material.SmoothPlastic,
			})
			pillarPost.Parent = lobbyFolder
			local pl = Instance.new("PointLight")
			pl.Color = NEON_CYAN
			pl.Brightness = 1.2
			pl.Range = 14
			pl.Parent = pillarPost
		end
	end

	-- spawn pad (replaces the previous neon spawn — keeps it a SpawnLocation)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "LobbySpawn"
	spawnPart.Size = Vector3.new(10, 1, 10)
	spawnPart.CFrame = CFrame.new(center + Vector3.new(0, Config.Lobby.PlatformThickness / 2 + 0.5, 0))
	spawnPart.Anchored = true
	spawnPart.CanCollide = true
	spawnPart.Neutral = true
	spawnPart.AllowTeamChangeOnTouch = false
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Color = NEON_CYAN
	spawnPart.Transparency = 0.25
	spawnPart.Parent = lobbyFolder
	-- octagon ring around spawn pad
	for i = 1, 8 do
		local angle = (i - 0.5) / 8 * math.pi * 2
		local rx = math.cos(angle) * 7
		local rz = math.sin(angle) * 7
		local nub = part({
			Name = "SpawnRing_" .. i,
			Size = Vector3.new(1.2, 0.4, 1.2),
			CFrame = CFrame.new(center + Vector3.new(rx, Config.Lobby.PlatformThickness / 2 + 0.4, rz)),
			Color = NEON_MAGENTA,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		nub.Parent = lobbyFolder
	end

	-- lobby title hovering above pillar
	billboard(pillar, "SACKTOPIA", Color3.fromRGB(255, 255, 255), Vector2.new(28, 6), 24)
	billboard(pillar, "PVP HACKY SACK", NEON_CYAN, Vector2.new(20, 2.4), 30)
	billboard(pillar, "WALK THROUGH A PORTAL TO PLAY", Color3.fromRGB(255, 220, 255), Vector2.new(24, 2), 18)

	-- ambient particle emitter on the pillar (rising sparks)
	local emitterAttach = Instance.new("Attachment")
	emitterAttach.Position = Vector3.new(0, -22, 0)
	emitterAttach.Parent = pillar
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 28
	emitter.Lifetime = NumberRange.new(2.5, 4)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Color = ColorSequence.new(NEON_CYAN, NEON_MAGENTA)
	emitter.LightEmission = 0.8
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Parent = emitterAttach

	lobbySpawn = spawnPart
end

local function buildPortal(parent: Folder, world: Worlds.World, angle: number)
	local center = Config.Lobby.Center
	local r = Config.Lobby.PortalRingRadius
	local floorY = center.Y + Config.Lobby.PlatformThickness / 2

	-- doorway dimensions
	local doorWidth = 9
	local doorHeight = 14
	local energyThickness = 0.6
	local frameThickness = 0.7

	-- portal centered vertically in front of the lobby's perimeter wall
	local portalCenter = Vector3.new(
		center.X + math.cos(angle) * r,
		floorY + doorHeight / 2,
		center.Z + math.sin(angle) * r
	)
	-- doorway faces the lobby center: LookVector points inward
	local inward = Vector3.new(-math.cos(angle), 0, -math.sin(angle))
	local portalCFrame = CFrame.lookAt(portalCenter, portalCenter + inward)

	-- energy plane — players walk through this to enter
	local energy = part({
		Name = "Portal_" .. world.id,
		Size = Vector3.new(doorWidth, doorHeight, energyThickness),
		CFrame = portalCFrame,
		Color = world.platformColor,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
	})
	energy.Parent = parent
	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 28
	light.Color = world.platformColor
	light.Parent = energy

	-- frame (top, left, right) — neon doorway outline
	local frameTop = part({
		Name = "PortalTop_" .. world.id,
		Size = Vector3.new(doorWidth + frameThickness * 2, frameThickness, frameThickness * 1.6),
		CFrame = portalCFrame * CFrame.new(0, doorHeight / 2 + frameThickness / 2, 0),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	frameTop.Parent = parent
	local frameLeft = part({
		Name = "PortalLeft_" .. world.id,
		Size = Vector3.new(frameThickness, doorHeight, frameThickness * 1.6),
		CFrame = portalCFrame * CFrame.new(-doorWidth / 2 - frameThickness / 2, 0, 0),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	frameLeft.Parent = parent
	local frameRight = part({
		Name = "PortalRight_" .. world.id,
		Size = Vector3.new(frameThickness, doorHeight, frameThickness * 1.6),
		CFrame = portalCFrame * CFrame.new(doorWidth / 2 + frameThickness / 2, 0, 0),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	frameRight.Parent = parent

	-- inner rim (a second slightly recessed glow ring inside the frame for depth)
	for _, offset in { Vector3.new(0, doorHeight / 2 - 0.4, 0), Vector3.new(-doorWidth / 2 + 0.4, 0, 0), Vector3.new(doorWidth / 2 - 0.4, 0, 0) } do
		local size: Vector3
		if offset.Y ~= 0 then
			size = Vector3.new(doorWidth - 0.8, 0.25, energyThickness * 0.6)
		else
			size = Vector3.new(0.25, doorHeight - 0.8, energyThickness * 0.6)
		end
		local rim = part({
			Name = "PortalRim_" .. world.id,
			Size = size,
			CFrame = portalCFrame * CFrame.new(offset),
			Color = world.platformColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		rim.Transparency = 0.3
		rim.Parent = parent
	end

	-- step in front of the doorway (the player approaches this from the lobby center)
	local step = part({
		Name = "PortalStep_" .. world.id,
		Size = Vector3.new(doorWidth + 4, 0.4, 4),
		CFrame = portalCFrame * CFrame.new(0, -doorHeight / 2 - 0.2, -1.8),
		Color = LOBBY_DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	step.Parent = parent
	local stepGlow = part({
		Name = "PortalStepGlow_" .. world.id,
		Size = Vector3.new(doorWidth + 2, 0.1, 2.5),
		CFrame = portalCFrame * CFrame.new(0, -doorHeight / 2 + 0.05, -1.8),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	stepGlow.Transparency = 0.25
	stepGlow.Parent = parent

	-- subtle pulsing of the energy plane (Sine ease, looped, reverse on each cycle)
	local pulseInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(energy, pulseInfo, { Transparency = 0.55 }):Play()

	-- swirling particles inside the doorway, attached to the energy plane
	local emitterAttach = Instance.new("Attachment")
	emitterAttach.Position = Vector3.new(0, 0, 0)
	emitterAttach.Parent = energy
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(world.platformColor)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Rate = 50
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.9
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.Parent = emitterAttach

	-- floating label above the doorway
	local tier = Ranks.tierIndex(world.requiredTier)
	local tierName = Config.Rank.Tiers[tier].name
	billboard(
		frameTop,
		string.format("%s\n%s+ • %s", world.name, tierName, world.tagline),
		world.platformColor,
		Vector2.new(14, 3.4),
		3
	)

	table.insert(builtPortals, { world = world, part = energy })
end

-- ---- per-world arena builders ---------------------------------------------

local function arenaWalls(folder: Folder, world: Worlds.World, color: Color3, material: Enum.Material, accent: Color3?)
	wallRing(folder, {
		center = world.center,
		radius = world.platformRadius - 1,
		height = 18,
		thickness = 1.5,
		segmentCount = 28,
		color = color,
		material = material,
		topAccentColor = accent,
		topAccentMaterial = Enum.Material.Neon,
	})
end

local function buildBackyard(folder: Folder, world: Worlds.World)
	-- picket fence ring
	wallRing(folder, {
		center = world.center,
		radius = world.platformRadius - 1,
		height = 5,
		thickness = 0.5,
		segmentCount = 36,
		color = Color3.fromRGB(240, 240, 230),
		material = Enum.Material.Wood,
	})
	-- trees scattered around outside the play area
	local treePositions = { 0, math.pi / 3, 2 * math.pi / 3, math.pi, 4 * math.pi / 3, 5 * math.pi / 3 }
	for _, ang in treePositions do
		local r = world.platformRadius + 18
		local pos = world.center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local trunk = part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(8, 1.6, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
		})
		trunk.Parent = folder
		local canopy = part({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(8, 8, 8),
			CFrame = CFrame.new(pos + Vector3.new(0, 11, 0)),
			Color = Color3.fromRGB(60, 130, 70),
			Material = Enum.Material.Grass,
		})
		canopy.Parent = folder
	end
	-- tiny "house" silhouette in the distance (block + roof)
	local housePos = world.center + Vector3.new(0, 0, -world.platformRadius - 60)
	local house = part({
		Name = "House",
		Size = Vector3.new(20, 12, 16),
		CFrame = CFrame.new(housePos + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(220, 200, 170),
		Material = Enum.Material.Plaster,
	})
	house.Parent = folder
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(22, 6, 18),
		CFrame = CFrame.new(housePos + Vector3.new(0, 15, 0)),
		Color = Color3.fromRGB(150, 70, 60),
		Material = Enum.Material.Slate,
	})
	roof.Parent = folder

	-- ARENA FEATURES --

	-- two raised wooden decks at +X and -X (jumping platforms)
	for _, sign in { -1, 1 } do
		local deckPos = world.center + Vector3.new(sign * 28, 2.5, 0)
		local deck = part({
			Name = "Deck",
			Size = Vector3.new(18, 1.2, 14),
			CFrame = CFrame.new(deckPos),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.Wood,
		})
		deck.Parent = folder
		-- short stair stub (just a single block ramp)
		local ramp = part({
			Name = "DeckStep",
			Size = Vector3.new(4, 1.4, 4),
			CFrame = CFrame.new(deckPos + Vector3.new(-sign * 11, -0.8, 0)),
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.Wood,
		})
		ramp.Parent = folder
		-- railing on the far edge so deck reads as a deck
		local rail = part({
			Name = "DeckRail",
			Size = Vector3.new(0.4, 2.5, 14),
			CFrame = CFrame.new(deckPos + Vector3.new(sign * 9, 1.6, 0)),
			Color = Color3.fromRGB(120, 90, 60),
			Material = Enum.Material.Wood,
		})
		rail.Parent = folder
	end

	-- inflatable kiddie pool roughly in center (low + decorative; sack flies over it)
	local poolY = world.center.Y + Config.ArenaDefaults.PlatformThickness / 2 + 0.6
	local poolWall = part({
		Name = "PoolWall",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 14, 14),
		CFrame = CFrame.new(world.center + Vector3.new(0, poolY - world.center.Y, 12)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.SmoothPlastic,
	})
	poolWall.Parent = folder
	local poolWater = part({
		Name = "PoolWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 12, 12),
		CFrame = CFrame.new(world.center + Vector3.new(0, poolY - world.center.Y + 0.3, 12)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 180, 240),
		Material = Enum.Material.Glass,
		CanCollide = false,
		Transparency = 0.3,
	})
	poolWater.Parent = folder

	-- lawn flamingos at three perimeter spots
	for _, ang in { math.pi / 6, math.pi - math.pi / 6, -math.pi / 2 } do
		local r = world.platformRadius - 8
		local pos = world.center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local body = part({
			Name = "Flamingo",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.4, 2.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0)),
			Color = Color3.fromRGB(255, 130, 170),
			Material = Enum.Material.SmoothPlastic,
		})
		body.Parent = folder
		local neck = part({
			Name = "FlamingoNeck",
			Size = Vector3.new(0.4, 2.5, 0.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 4.2, -0.6)) * CFrame.Angles(math.rad(20), 0, 0),
			Color = Color3.fromRGB(255, 130, 170),
			Material = Enum.Material.SmoothPlastic,
		})
		neck.Parent = folder
		local leg = part({
			Name = "FlamingoLeg",
			Size = Vector3.new(0.25, 2.0, 0.25),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.0, 0)),
			Color = Color3.fromRGB(220, 100, 130),
			Material = Enum.Material.SmoothPlastic,
		})
		leg.Parent = folder
	end

	-- BACKYARD FLOURISHES --

	-- swing set: 2 vertical posts + horizontal beam + 2 swings
	local swingPos = world.center + Vector3.new(-26, 0, 0)
	for _, side in { -1, 1 } do
		local post = part({
			Name = "SwingPost",
			Size = Vector3.new(0.6, 12, 0.6),
			CFrame = CFrame.new(swingPos + Vector3.new(0, 6, side * 4)) * CFrame.Angles(0, 0, math.rad(side * 8)),
			Color = Color3.fromRGB(180, 180, 180),
			Material = Enum.Material.Metal,
		})
		post.Parent = folder
	end
	local beam = part({
		Name = "SwingBeam",
		Size = Vector3.new(0.7, 0.7, 9),
		CFrame = CFrame.new(swingPos + Vector3.new(0, 11.5, 0)),
		Color = Color3.fromRGB(180, 180, 180),
		Material = Enum.Material.Metal,
	})
	beam.Parent = folder
	for _, sign in { -1, 1 } do
		-- chains
		for _, dz in { -0.7, 0.7 } do
			local chain = part({
				Name = "SwingChain",
				Size = Vector3.new(0.15, 5, 0.15),
				CFrame = CFrame.new(swingPos + Vector3.new(0, 8.5, sign * 1.6 + dz)),
				Color = Color3.fromRGB(120, 120, 120),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			chain.Parent = folder
		end
		-- seat
		local seat = part({
			Name = "SwingSeat",
			Size = Vector3.new(2.4, 0.3, 1.4),
			CFrame = CFrame.new(swingPos + Vector3.new(0, 6, sign * 1.6)),
			Color = Color3.fromRGB(80, 50, 30),
			Material = Enum.Material.Wood,
		})
		seat.Parent = folder
	end

	-- mailbox at perimeter
	local mailPos = world.center + Vector3.new(world.platformRadius + 12, 0, -10)
	local mailPost = part({
		Name = "MailboxPost",
		Size = Vector3.new(0.4, 6, 0.4),
		CFrame = CFrame.new(mailPos + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(80, 50, 30),
		Material = Enum.Material.Wood,
	})
	mailPost.Parent = folder
	local box = part({
		Name = "MailboxBody",
		Size = Vector3.new(2.8, 1.8, 2),
		CFrame = CFrame.new(mailPos + Vector3.new(0, 6.8, 0)),
		Color = Color3.fromRGB(120, 30, 30),
		Material = Enum.Material.SmoothPlastic,
	})
	box.Parent = folder
	local flag = part({
		Name = "MailboxFlag",
		Size = Vector3.new(0.2, 1.2, 0.8),
		CFrame = CFrame.new(mailPos + Vector3.new(1.6, 7.5, 0)),
		Color = Color3.fromRGB(220, 30, 30),
		Material = Enum.Material.SmoothPlastic,
	})
	flag.Parent = folder

	-- 2 lawn chairs near the pool (the pool is at +Z 12 in this arena)
	for _, sign in { -1, 1 } do
		local chairPos = world.center + Vector3.new(sign * 12, 0, 24)
		local seat = part({
			Name = "LawnChairSeat",
			Size = Vector3.new(3, 0.4, 3),
			CFrame = CFrame.new(chairPos + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(220, 240, 220),
			Material = Enum.Material.Fabric,
		})
		seat.Parent = folder
		local back = part({
			Name = "LawnChairBack",
			Size = Vector3.new(3, 4, 0.4),
			CFrame = CFrame.new(chairPos + Vector3.new(0, 3, -1.3)) * CFrame.Angles(math.rad(15), 0, 0),
			Color = Color3.fromRGB(220, 240, 220),
			Material = Enum.Material.Fabric,
		})
		back.Parent = folder
	end

	-- two garden gnomes at perimeter spots not already occupied by flamingos
	for _, ang in { math.rad(50), math.rad(220) } do
		local r = world.platformRadius - 6
		local pos = world.center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local body = part({
			Name = "GnomeBody",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.8, 1.8, 1.8),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(220, 60, 60),
			Material = Enum.Material.SmoothPlastic,
		})
		body.Parent = folder
		local gnomeHead = part({
			Name = "GnomeHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0)),
			Color = Color3.fromRGB(255, 220, 190),
			Material = Enum.Material.SmoothPlastic,
		})
		gnomeHead.Parent = folder
		-- pointy hat
		local hat = part({
			Name = "GnomeHat",
			Size = Vector3.new(1.6, 2.2, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Color3.fromRGB(220, 60, 60),
			Material = Enum.Material.SmoothPlastic,
		})
		hat.Parent = folder
		-- white beard suggestion
		local beard = part({
			Name = "GnomeBeard",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.2, 1.0, 0.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0.5)),
			Color = Color3.fromRGB(245, 245, 245),
			Material = Enum.Material.SmoothPlastic,
		})
		beard.Parent = folder
	end
end

local function buildQuad(folder: Folder, world: Worlds.World)
	arenaWalls(folder, world, Color3.fromRGB(160, 120, 90), Enum.Material.Brick, nil)
	-- 4 brick "campus" pillars at cardinal points
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2
		local r = world.platformRadius + 8
		local pos = world.center + Vector3.new(math.cos(ang) * r, 8, math.sin(ang) * r)
		local pillar = part({
			Name = "BrickPillar",
			Size = Vector3.new(5, 16, 5),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(140, 90, 70),
			Material = Enum.Material.Brick,
		})
		pillar.Parent = folder
	end
	-- a couple of trees along the perimeter for the "quad" feel
	for _, ang in { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 } do
		local r = world.platformRadius + 14
		local pos = world.center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local trunk = part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 1.6, 1.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(90, 60, 40),
			Material = Enum.Material.Wood,
		})
		trunk.Parent = folder
		local canopy = part({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(10, 10, 10),
			CFrame = CFrame.new(pos + Vector3.new(0, 13, 0)),
			Color = Color3.fromRGB(70, 110, 50),
			Material = Enum.Material.Grass,
		})
		canopy.Parent = folder
	end

	-- ARENA FEATURES --

	-- octagonal stone fountain off-center so it doesn't block sack spawn
	local fountainPos = world.center + Vector3.new(0, 0, 18)
	local fountainBasin = part({
		Name = "FountainBasin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.5, 18, 18),
		CFrame = CFrame.new(fountainPos + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 175, 165),
		Material = Enum.Material.Cobblestone,
	})
	fountainBasin.Parent = folder
	local fountainWater = part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 14, 14),
		CFrame = CFrame.new(fountainPos + Vector3.new(0, 2.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 160, 220),
		Material = Enum.Material.Glass,
		CanCollide = false,
		Transparency = 0.2,
	})
	fountainWater.Parent = folder
	local fountainSpire = part({
		Name = "FountainSpire",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 1.4, 1.4),
		CFrame = CFrame.new(fountainPos + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 175, 165),
		Material = Enum.Material.Cobblestone,
	})
	fountainSpire.Parent = folder
	-- water spout particle from the spire
	local spoutAttach = Instance.new("Attachment")
	spoutAttach.Position = Vector3.new(0, 4, 0)
	spoutAttach.Parent = fountainSpire
	local spout = Instance.new("ParticleEmitter")
	spout.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spout.Color = ColorSequence.new(Color3.fromRGB(150, 200, 240))
	spout.Lifetime = NumberRange.new(1.4, 2.2)
	spout.Rate = 80
	spout.Speed = NumberRange.new(8, 14)
	spout.SpreadAngle = Vector2.new(20, 20)
	spout.Acceleration = Vector3.new(0, -10, 0)
	spout.Size = NumberSequence.new(0.5, 0.0)
	spout.Transparency = NumberSequence.new(0.1, 1)
	spout.LightEmission = 0.4
	spout.Parent = spoutAttach

	-- 4 stone benches around the fountain
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local r = 18
		local benchPos = fountainPos + Vector3.new(math.cos(ang) * r, 1.2, math.sin(ang) * r)
		local bench = part({
			Name = "Bench",
			Size = Vector3.new(7, 0.6, 2.2),
			CFrame = CFrame.new(benchPos) * CFrame.Angles(0, -ang, 0),
			Color = Color3.fromRGB(180, 175, 165),
			Material = Enum.Material.Cobblestone,
		})
		bench.Parent = folder
		local benchLeg1 = part({
			Name = "BenchLeg",
			Size = Vector3.new(0.8, 1.6, 2.0),
			CFrame = CFrame.new(benchPos + Vector3.new(math.cos(-ang) * 2.6, -1.0, math.sin(-ang) * 2.6)),
			Color = Color3.fromRGB(150, 145, 140),
			Material = Enum.Material.Cobblestone,
		})
		benchLeg1.Parent = folder
	end

	-- 4 lamp posts at +/-X and +/-Z (taller, brass-ish)
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2
		local r = world.platformRadius - 12
		local pos = world.center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local pole = part({
			Name = "LampPole",
			Size = Vector3.new(0.6, 14, 0.6),
			CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)),
			Color = Color3.fromRGB(60, 50, 40),
			Material = Enum.Material.Metal,
		})
		pole.Parent = folder
		local lampHead = part({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 14.6, 0)),
			Color = Color3.fromRGB(255, 220, 130),
			Material = Enum.Material.Neon,
		})
		lampHead.Parent = folder
		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 220, 130)
		lampLight.Brightness = 1.6
		lampLight.Range = 18
		lampLight.Parent = lampHead
	end

	-- ROYAL HIGH / IVY LEAGUE FLOURISHES --

	-- 1) Clock tower in the distance behind the platform (-X)
	local towerBase = world.center + Vector3.new(-(world.platformRadius + 60), 0, 0)
	local tower = part({
		Name = "ClockTower",
		Size = Vector3.new(14, 80, 14),
		CFrame = CFrame.new(towerBase + Vector3.new(0, 40, 0)),
		Color = Color3.fromRGB(170, 130, 100),
		Material = Enum.Material.Brick,
	})
	tower.Parent = folder
	-- pyramid roof on tower (block angled)
	local towerRoof = part({
		Name = "ClockTowerRoof",
		Size = Vector3.new(18, 12, 18),
		CFrame = CFrame.new(towerBase + Vector3.new(0, 86, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = Color3.fromRGB(60, 40, 30),
		Material = Enum.Material.Slate,
	})
	towerRoof.Parent = folder
	-- clock face on the +X side (facing the arena)
	local clockFace = part({
		Name = "ClockFace",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 8, 8),
		CFrame = CFrame.new(towerBase + Vector3.new(7.2, 60, 0)) * CFrame.Angles(0, 0, 0),
		Color = Color3.fromRGB(245, 240, 220),
		Material = Enum.Material.SmoothPlastic,
	})
	clockFace.Parent = folder
	billboard(clockFace, "10:10", Color3.fromRGB(40, 30, 20), Vector2.new(7, 3.5), 0)
	local clockGlow = Instance.new("PointLight")
	clockGlow.Color = Color3.fromRGB(255, 240, 200)
	clockGlow.Brightness = 1.5
	clockGlow.Range = 20
	clockGlow.Parent = clockFace

	-- 2) Welcome arch at +X edge of the platform (entry gateway)
	local archCenter = world.center + Vector3.new(world.platformRadius + 6, 0, 0)
	for _, side in { -1, 1 } do
		local pillar = part({
			Name = "ArchPillar",
			Size = Vector3.new(2.5, 18, 2.5),
			CFrame = CFrame.new(archCenter + Vector3.new(0, 9, side * 6)),
			Color = Color3.fromRGB(220, 210, 190),
			Material = Enum.Material.Marble,
		})
		pillar.Parent = folder
		-- gold pillar cap
		local cap = part({
			Name = "ArchPillarCap",
			Size = Vector3.new(3.5, 1, 3.5),
			CFrame = CFrame.new(archCenter + Vector3.new(0, 18.5, side * 6)),
			Color = Color3.fromRGB(245, 200, 80),
			Material = Enum.Material.Foil,
		})
		cap.Parent = folder
	end
	local archTop = part({
		Name = "ArchTop",
		Size = Vector3.new(3, 2.5, 14.5),
		CFrame = CFrame.new(archCenter + Vector3.new(0, 20.5, 0)),
		Color = Color3.fromRGB(220, 210, 190),
		Material = Enum.Material.Marble,
	})
	archTop.Parent = folder
	billboard(archTop, "THE QUAD", Color3.fromRGB(245, 200, 80), Vector2.new(14, 3.2), 3)

	-- 3) Hanging banner flags between the brick campus pillars (alternating school colors)
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 -- aligns with the brick pillars at cardinal points
		local r = world.platformRadius + 8
		local pos = world.center + Vector3.new(math.cos(ang) * r, 12, math.sin(ang) * r)
		local color = (i % 2 == 0) and Color3.fromRGB(60, 90, 170) or Color3.fromRGB(245, 200, 80)
		local flagAtt1 = pos + Vector3.new(0, 4, 0)
		local flag = part({
			Name = "Banner",
			Size = Vector3.new(0.3, 8, 4),
			CFrame = CFrame.new(flagAtt1 - Vector3.new(0, 4, 0)),
			Color = color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		flag.Parent = folder
		-- white trim
		local trim = part({
			Name = "BannerTrim",
			Size = Vector3.new(0.4, 0.4, 4.2),
			CFrame = CFrame.new(flagAtt1 - Vector3.new(0, 8, 0)),
			Color = Color3.fromRGB(245, 245, 245),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		trim.Parent = folder
	end

	-- 4) "Founder" statue on a marble pedestal in one quadrant
	local statuePos = world.center + Vector3.new(world.platformRadius - 22, 0, world.platformRadius - 22)
	local pedestal = part({
		Name = "StatuePedestal",
		Size = Vector3.new(5, 4, 5),
		CFrame = CFrame.new(statuePos + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(220, 210, 190),
		Material = Enum.Material.Marble,
	})
	pedestal.Parent = folder
	-- humanoid silhouette: torso + head + 2 arms
	local statueColor = Color3.fromRGB(180, 180, 180)
	local torso = part({
		Name = "StatueTorso",
		Size = Vector3.new(2.8, 5, 1.8),
		CFrame = CFrame.new(statuePos + Vector3.new(0, 6.5, 0)),
		Color = statueColor,
		Material = Enum.Material.Marble,
	})
	torso.Parent = folder
	local head = part({
		Name = "StatueHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = CFrame.new(statuePos + Vector3.new(0, 10, 0)),
		Color = statueColor,
		Material = Enum.Material.Marble,
	})
	head.Parent = folder
	local arm = part({
		Name = "StatueArm",
		Size = Vector3.new(1, 4.2, 1),
		CFrame = CFrame.new(statuePos + Vector3.new(2.3, 6, 0)) * CFrame.Angles(0, 0, math.rad(20)),
		Color = statueColor,
		Material = Enum.Material.Marble,
	})
	arm.Parent = folder
	local plaque = part({
		Name = "StatuePlaque",
		Size = Vector3.new(2.6, 0.5, 4.6),
		CFrame = CFrame.new(statuePos + Vector3.new(0, 4.3, 0)),
		Color = Color3.fromRGB(245, 200, 80),
		Material = Enum.Material.Foil,
	})
	plaque.Parent = folder

	-- 5) Cobblestone walkway pavers across the platform (subtle X-pattern in the floor)
	local platformTopY = world.center.Y + Config.ArenaDefaults.PlatformThickness / 2
	for i = 1, 2 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local len = (world.platformRadius - 8) * 2
		local stripe = part({
			Name = "WalkwayPaver",
			Size = Vector3.new(len, 0.18, 4),
			CFrame = CFrame.new(world.center + Vector3.new(0, platformTopY - world.center.Y + 0.05, 0))
				* CFrame.Angles(0, -ang, 0),
			Color = Color3.fromRGB(200, 190, 170),
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
		})
		stripe.Parent = folder
	end
end

local function buildFratHouse(folder: Folder, world: Worlds.World)
	arenaWalls(folder, world, Color3.fromRGB(80, 50, 30), Enum.Material.Wood, Color3.fromRGB(255, 60, 60))
	-- four corner posts (porch columns)
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local r = world.platformRadius + 4
		local pos = world.center + Vector3.new(math.cos(ang) * r, 12, math.sin(ang) * r)
		local post = part({
			Name = "PorchColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(24, 2.5, 2.5),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(220, 200, 170),
			Material = Enum.Material.Plaster,
		})
		post.Parent = folder
	end
	-- string of lights between porch columns (small neon balls along an arc)
	local lightCount = 24
	for i = 1, lightCount do
		local ang = (i - 1) / lightCount * math.pi * 2
		local r = world.platformRadius + 4
		local pos = world.center + Vector3.new(math.cos(ang) * r, 22, math.sin(ang) * r)
		local color = if i % 3 == 0 then Color3.fromRGB(255, 200, 100)
			elseif i % 3 == 1 then Color3.fromRGB(255, 100, 100)
			else Color3.fromRGB(100, 200, 255)
		local bulb = part({
			Name = "PartyLight",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(pos),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		bulb.Parent = folder
		local pl = Instance.new("PointLight")
		pl.Color = color
		pl.Brightness = 1.2
		pl.Range = 8
		pl.Parent = bulb
	end
	-- a few red SOLO cup props near the perimeter (red cylinder + white rim)
	for i = 1, 6 do
		local ang = (i - 1) / 6 * math.pi * 2 + math.pi / 12
		local r = world.platformRadius - 5
		local pos = world.center + Vector3.new(math.cos(ang) * r, 1.2, math.sin(ang) * r)
		local cup = part({
			Name = "SoloCup",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.2, 1.3, 1.3),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(220, 30, 40),
			Material = Enum.Material.SmoothPlastic,
		})
		cup.Parent = folder
		local rim = part({
			Name = "CupRim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 1.4, 1.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(245, 245, 245),
			Material = Enum.Material.SmoothPlastic,
		})
		rim.Parent = folder
	end

	-- ARENA FEATURES --

	-- beer pong table: long brown rectangle off-center, with cup triangles at each end
	local tablePos = world.center + Vector3.new(0, 0, 16)
	local table_ = part({
		Name = "PongTable",
		Size = Vector3.new(8, 2.4, 22),
		CFrame = CFrame.new(tablePos + Vector3.new(0, 1.2, 0)),
		Color = Color3.fromRGB(110, 70, 40),
		Material = Enum.Material.Wood,
	})
	table_.Parent = folder
	-- triangle of cups at each end (10 cups, 4-3-2-1)
	for endSign = -1, 1, 2 do
		for row = 0, 3 do
			local cupsThisRow = 4 - row
			for c = 1, cupsThisRow do
				local x = (c - (cupsThisRow + 1) / 2) * 1.5
				local zOffset = endSign * (8 - row * 1.3)
				local pos = tablePos + Vector3.new(x, 2.7, zOffset)
				local cup = part({
					Name = "PongCup",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1.0, 1.0, 1.0),
					CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
					Color = Color3.fromRGB(220, 30, 40),
					Material = Enum.Material.SmoothPlastic,
				})
				cup.Parent = folder
			end
		end
	end

	-- 2 couches at +X and -X (red leather)
	for _, sign in { -1, 1 } do
		local couchPos = world.center + Vector3.new(sign * 28, 1.2, -8)
		local seat = part({
			Name = "Couch",
			Size = Vector3.new(10, 1.4, 4),
			CFrame = CFrame.new(couchPos) * CFrame.Angles(0, sign > 0 and -math.pi / 2 or math.pi / 2, 0),
			Color = Color3.fromRGB(120, 30, 40),
			Material = Enum.Material.Fabric,
		})
		seat.Parent = folder
		local back = part({
			Name = "CouchBack",
			Size = Vector3.new(10, 3, 1),
			CFrame = CFrame.new(couchPos + Vector3.new(sign * 1.5, 1.4, 0)) * CFrame.Angles(0, sign > 0 and -math.pi / 2 or math.pi / 2, 0),
			Color = Color3.fromRGB(100, 25, 35),
			Material = Enum.Material.Fabric,
		})
		back.Parent = folder
		local arm1 = part({
			Name = "CouchArm",
			Size = Vector3.new(1.2, 2.5, 4),
			CFrame = CFrame.new(couchPos + Vector3.new(0, 0.5, 4.4)) * CFrame.Angles(0, sign > 0 and -math.pi / 2 or math.pi / 2, 0),
			Color = Color3.fromRGB(120, 30, 40),
			Material = Enum.Material.Fabric,
		})
		arm1.Parent = folder
		local arm2 = part({
			Name = "CouchArm",
			Size = Vector3.new(1.2, 2.5, 4),
			CFrame = CFrame.new(couchPos + Vector3.new(0, 0.5, -4.4)) * CFrame.Angles(0, sign > 0 and -math.pi / 2 or math.pi / 2, 0),
			Color = Color3.fromRGB(120, 30, 40),
			Material = Enum.Material.Fabric,
		})
		arm2.Parent = folder
	end

	-- BBQ grill on the -Z side
	local grillPos = world.center + Vector3.new(0, 1.5, -28)
	local grill = part({
		Name = "Grill",
		Size = Vector3.new(6, 3, 4),
		CFrame = CFrame.new(grillPos),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
	})
	grill.Parent = folder
	local grillTop = part({
		Name = "GrillLid",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 3, 4),
		CFrame = CFrame.new(grillPos + Vector3.new(0, 1.6, 0)),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
	})
	grillTop.Parent = folder
	-- glowing coals
	local coals = part({
		Name = "Coals",
		Size = Vector3.new(4.5, 0.4, 3),
		CFrame = CFrame.new(grillPos + Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(255, 90, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
	})
	coals.Parent = folder
	local coalLight = Instance.new("PointLight")
	coalLight.Color = Color3.fromRGB(255, 110, 40)
	coalLight.Brightness = 1.5
	coalLight.Range = 10
	coalLight.Parent = coals
	-- smoke particles
	local smokeAttach = Instance.new("Attachment")
	smokeAttach.Position = Vector3.new(0, 2, 0)
	smokeAttach.Parent = grillTop
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(180, 180, 180))
	smoke.Lifetime = NumberRange.new(2, 4)
	smoke.Rate = 12
	smoke.Speed = NumberRange.new(2, 4)
	smoke.SpreadAngle = Vector2.new(15, 15)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Size = NumberSequence.new(1, 4)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = smokeAttach

	-- FRAT HOUSE FLOURISHES --

	-- big neon Greek-letter sign hovering above the +Z perimeter (above the porch line)
	-- using simple part shapes so we don't depend on TextLabel readability from far away
	local signCenter = world.center + Vector3.new(0, 24, world.platformRadius - 8)
	-- a backing plate
	local signPlate = part({
		Name = "GreekSignPlate",
		Size = Vector3.new(20, 6, 0.6),
		CFrame = CFrame.new(signCenter),
		Color = Color3.fromRGB(20, 15, 12),
		Material = Enum.Material.SmoothPlastic,
	})
	signPlate.Parent = folder
	-- glowing letters via billboard
	billboard(signPlate, "ΣΑΘ", Color3.fromRGB(255, 80, 80), Vector2.new(14, 5), 0)
	-- string lights bordering the sign
	local lightCount = 18
	for i = 1, lightCount do
		local x = (i - (lightCount + 1) / 2) * 1.2
		local color = (i % 2 == 0) and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 200, 100)
		local bulb = part({
			Name = "SignBulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = CFrame.new(signCenter + Vector3.new(x, 3.4, 0)),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		bulb.Parent = folder
	end

	-- keg in the corner of the platform
	local kegPos = world.center + Vector3.new(world.platformRadius - 14, 0, world.platformRadius - 14)
	local kegBody = part({
		Name = "KegBody",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5.2, 4, 4),
		CFrame = CFrame.new(kegPos + Vector3.new(0, 2.6, 0)),
		Color = Color3.fromRGB(180, 180, 195),
		Material = Enum.Material.Metal,
	})
	kegBody.Parent = folder
	local kegTop = part({
		Name = "KegTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 4.2, 4.2),
		CFrame = CFrame.new(kegPos + Vector3.new(0, 5.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 140, 160),
		Material = Enum.Material.Metal,
	})
	kegTop.Parent = folder
	local tap = part({
		Name = "KegTap",
		Size = Vector3.new(0.6, 0.6, 1.6),
		CFrame = CFrame.new(kegPos + Vector3.new(2.6, 4.5, 0)),
		Color = Color3.fromRGB(80, 80, 80),
		Material = Enum.Material.Metal,
	})
	tap.Parent = folder

	-- disco ball hanging from above (mid-air centerpiece)
	local ballPos = world.center + Vector3.new(0, 22, 0)
	local discoBall = part({
		Name = "DiscoBall",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(ballPos),
		Color = Color3.fromRGB(220, 220, 240),
		Material = Enum.Material.Foil,
		CanCollide = false,
	})
	discoBall.Parent = folder
	local hangCord = part({
		Name = "DiscoHang",
		Size = Vector3.new(0.2, 6, 0.2),
		CFrame = CFrame.new(ballPos + Vector3.new(0, 5, 0)),
		Color = Color3.fromRGB(40, 40, 40),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	hangCord.Parent = folder
	-- pulsing color light
	local discoLight = Instance.new("PointLight")
	discoLight.Color = Color3.fromRGB(220, 100, 220)
	discoLight.Brightness = 2
	discoLight.Range = 30
	discoLight.Parent = discoBall
	-- spinning effect
	local discoTween = TweenService:Create(
		discoBall,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ CFrame = CFrame.new(ballPos) * CFrame.Angles(0, math.pi * 2, 0) }
	)
	discoTween:Play()
end

local function buildStadium(folder: Folder, world: Worlds.World)
	arenaWalls(folder, world, Color3.fromRGB(90, 90, 100), Enum.Material.Concrete, Color3.fromRGB(255, 255, 255))
	-- bleacher rows around the perimeter (3 stepped tiers)
	for tier = 1, 3 do
		wallRing(folder, {
			center = world.center,
			radius = world.platformRadius + 6 + tier * 6,
			height = 4,
			thickness = 6,
			segmentCount = 36,
			color = Color3.fromRGB(70, 80, 110),
			material = Enum.Material.Concrete,
		})
	end
	-- 4 floodlight poles
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local r = world.platformRadius + 30
		local pos = world.center + Vector3.new(math.cos(ang) * r, 30, math.sin(ang) * r)
		local pole = part({
			Name = "LightPole",
			Size = Vector3.new(1.2, 60, 1.2),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Metal,
		})
		pole.Parent = folder
		local lampPos = pos + Vector3.new(0, 30, 0)
		local lamp = part({
			Name = "Floodlight",
			Size = Vector3.new(6, 1.5, 4),
			CFrame = CFrame.new(lampPos) * CFrame.Angles(math.rad(-30), -ang + math.pi, 0),
			Color = Color3.fromRGB(245, 245, 220),
			Material = Enum.Material.Neon,
		})
		lamp.Parent = folder
		local sl = Instance.new("SpotLight")
		sl.Color = Color3.fromRGB(245, 245, 220)
		sl.Brightness = 5
		sl.Range = 80
		sl.Angle = 90
		sl.Face = Enum.NormalId.Bottom
		sl.Parent = lamp
	end
	-- scoreboard
	local boardPos = world.center + Vector3.new(0, 26, -world.platformRadius - 24)
	local boardBack = part({
		Name = "Scoreboard",
		Size = Vector3.new(40, 16, 1.5),
		CFrame = CFrame.new(boardPos),
		Color = Color3.fromRGB(20, 20, 30),
		Material = Enum.Material.SmoothPlastic,
	})
	boardBack.Parent = folder
	billboard(boardBack, "SACKTOPIA STADIUM", Color3.fromRGB(255, 220, 80), Vector2.new(20, 4.5), 0)

	-- ARENA FEATURES --

	local platformTopY = world.center.Y + Config.ArenaDefaults.PlatformThickness / 2

	-- center logo: a yellow disc with the SACKTOPIA mark
	local logo = part({
		Name = "FieldLogo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 26, 26),
		CFrame = CFrame.new(world.center + Vector3.new(0, platformTopY - world.center.Y + 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(220, 200, 100),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	logo.Parent = folder
	-- inner ring on the logo
	local logoInner = part({
		Name = "FieldLogoInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.25, 16, 16),
		CFrame = CFrame.new(world.center + Vector3.new(0, platformTopY - world.center.Y + 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 40, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	logoInner.Parent = folder

	-- field markings: 4 white painted radial stripes
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local stripeLen = world.platformRadius - 16
		local stripePos = world.center + Vector3.new(
			math.cos(ang) * (stripeLen / 2 + 16),
			platformTopY - world.center.Y + 0.05,
			math.sin(ang) * (stripeLen / 2 + 16)
		)
		local stripe = part({
			Name = "FieldStripe",
			Size = Vector3.new(stripeLen, 0.15, 1.2),
			CFrame = CFrame.new(stripePos) * CFrame.Angles(0, -ang, 0),
			Color = Color3.fromRGB(245, 245, 245),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		stripe.Parent = folder
	end

	-- two H-shape goal posts at +Z and -Z perimeter
	for _, side in { -1, 1 } do
		local zEdge = world.center.Z + side * (world.platformRadius - 6)
		local goalY = world.center.Y + 12
		-- two uprights
		local crossLen = 16
		for _, xOff in { -crossLen / 2, crossLen / 2 } do
			local upright = part({
				Name = "GoalUpright",
				Size = Vector3.new(0.8, 24, 0.8),
				CFrame = CFrame.new(world.center.X + xOff, goalY, zEdge),
				Color = Color3.fromRGB(245, 245, 220),
				Material = Enum.Material.Metal,
			})
			upright.Parent = folder
		end
		-- crossbar
		local crossbar = part({
			Name = "GoalCrossbar",
			Size = Vector3.new(crossLen + 0.8, 0.8, 0.8),
			CFrame = CFrame.new(world.center.X, goalY + 5, zEdge),
			Color = Color3.fromRGB(245, 245, 220),
			Material = Enum.Material.Metal,
		})
		crossbar.Parent = folder
	end

	-- two team benches behind the goal lines
	for _, side in { -1, 1 } do
		local benchPos = world.center + Vector3.new(side * (world.platformRadius - 8), 1, -10)
		local bench = part({
			Name = "TeamBench",
			Size = Vector3.new(2, 1.4, 12),
			CFrame = CFrame.new(benchPos),
			Color = Color3.fromRGB(60, 70, 100),
			Material = Enum.Material.Concrete,
		})
		bench.Parent = folder
		local benchBack = part({
			Name = "TeamBenchBack",
			Size = Vector3.new(0.5, 3, 12),
			CFrame = CFrame.new(benchPos + Vector3.new(side * 1, 1.5, 0)),
			Color = Color3.fromRGB(45, 55, 80),
			Material = Enum.Material.Concrete,
		})
		benchBack.Parent = folder
	end

	-- STADIUM FLOURISHES --

	-- jumbotron mounted high opposite the scoreboard (+Z side)
	local jumboPos = world.center + Vector3.new(0, 38, world.platformRadius + 24)
	local jumboFrame = part({
		Name = "JumbotronFrame",
		Size = Vector3.new(50, 22, 2),
		CFrame = CFrame.new(jumboPos),
		Color = Color3.fromRGB(20, 20, 30),
		Material = Enum.Material.Metal,
	})
	jumboFrame.Parent = folder
	local jumboScreen = part({
		Name = "JumbotronScreen",
		Size = Vector3.new(46, 18, 0.6),
		CFrame = CFrame.new(jumboPos + Vector3.new(0, 0, -1.2)),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.05,
	})
	jumboScreen.Parent = folder
	billboard(jumboScreen, "🏈 SACKTOPIA 🏈\nLIVE", Color3.fromRGB(255, 220, 80), Vector2.new(36, 14), 0)
	-- 4 support struts holding the jumbotron up
	for _, sx in { -1, 1 } do
		local strut = part({
			Name = "JumbotronStrut",
			Size = Vector3.new(1.5, 38, 1.5),
			CFrame = CFrame.new(jumboPos + Vector3.new(sx * 22, -19, 0)),
			Color = Color3.fromRGB(40, 40, 60),
			Material = Enum.Material.Metal,
		})
		strut.Parent = folder
	end

	-- 6 hanging team flags around the perimeter (red + blue alternating)
	for i = 1, 6 do
		local ang = (i - 1) / 6 * math.pi * 2 + math.pi / 12
		local r = world.platformRadius + 18
		local pos = world.center + Vector3.new(math.cos(ang) * r, 26, math.sin(ang) * r)
		local color = (i % 2 == 0) and Color3.fromRGB(50, 90, 200) or Color3.fromRGB(220, 50, 50)
		local pole = part({
			Name = "FlagPole",
			Size = Vector3.new(0.4, 16, 0.4),
			CFrame = CFrame.new(pos + Vector3.new(0, -8, 0)),
			Color = Color3.fromRGB(150, 150, 160),
			Material = Enum.Material.Metal,
		})
		pole.Parent = folder
		local fabric = part({
			Name = "FlagFabric",
			Size = Vector3.new(0.2, 5, 7),
			CFrame = CFrame.new(pos + Vector3.new(0, -2, 3.5)) * CFrame.Angles(0, -ang, 0),
			Color = color,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		fabric.Parent = folder
	end
end

local function buildOlympus(folder: Folder, world: Worlds.World)
	arenaWalls(folder, world, Color3.fromRGB(230, 230, 240), Enum.Material.Marble, Color3.fromRGB(245, 200, 80))
	-- 8 marble columns around the perimeter
	for i = 1, 8 do
		local ang = (i - 1) / 8 * math.pi * 2
		local r = world.platformRadius + 6
		local pos = world.center + Vector3.new(math.cos(ang) * r, 16, math.sin(ang) * r)
		local col = part({
			Name = "MarbleColumn",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(32, 3, 3),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(245, 245, 250),
			Material = Enum.Material.Marble,
		})
		col.Parent = folder
		-- gold cap
		local cap = part({
			Name = "ColumnCap",
			Size = Vector3.new(4.5, 1.2, 4.5),
			CFrame = CFrame.new(pos + Vector3.new(0, 16.5, 0)),
			Color = Color3.fromRGB(245, 200, 80),
			Material = Enum.Material.Foil,
		})
		cap.Parent = folder
	end
	-- floating cloud parts in the air around the arena
	for i = 1, 14 do
		local ang = math.random() * math.pi * 2
		local r = world.platformRadius + math.random(20, 60)
		local h = math.random(20, 50)
		local pos = world.center + Vector3.new(math.cos(ang) * r, h, math.sin(ang) * r)
		local cloud = part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(math.random(10, 18), math.random(6, 10), math.random(10, 18)),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		cloud.Transparency = 0.2
		cloud.Parent = folder
	end

	-- ARENA FEATURES --

	local platformTopY = world.center.Y + Config.ArenaDefaults.PlatformThickness / 2

	-- central altar (white marble block topped with gold disc)
	local altar = part({
		Name = "Altar",
		Size = Vector3.new(8, 4, 8),
		CFrame = CFrame.new(world.center + Vector3.new(0, 2, 18)),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.Marble,
	})
	altar.Parent = folder
	local altarTop = part({
		Name = "AltarTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 7, 7),
		CFrame = CFrame.new(world.center + Vector3.new(0, 4.25, 18)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(245, 200, 80),
		Material = Enum.Material.Foil,
	})
	altarTop.Parent = folder
	-- eternal flame on the altar
	local flame = part({
		Name = "AltarFlame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.5, 4, 2.5),
		CFrame = CFrame.new(world.center + Vector3.new(0, 6.5, 18)),
		Color = Color3.fromRGB(255, 160, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.15,
	})
	flame.Parent = folder
	local flameLight = Instance.new("PointLight")
	flameLight.Color = Color3.fromRGB(255, 180, 90)
	flameLight.Brightness = 3
	flameLight.Range = 20
	flameLight.Parent = flame
	-- fire particles
	local flameAttach = Instance.new("Attachment")
	flameAttach.Position = Vector3.new(0, 0, 0)
	flameAttach.Parent = flame
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 100, 30))
	fire.Lifetime = NumberRange.new(0.6, 1.2)
	fire.Rate = 30
	fire.Speed = NumberRange.new(2, 4)
	fire.Acceleration = Vector3.new(0, 4, 0)
	fire.Size = NumberSequence.new(2, 0.3)
	fire.Transparency = NumberSequence.new(0.2, 1)
	fire.LightEmission = 0.8
	fire.Parent = flameAttach

	-- 4 raised marble platforms at corners (small jumpable pads, 2 stud high)
	for i = 1, 4 do
		local ang = (i - 1) * math.pi / 2 + math.pi / 4
		local r = world.platformRadius - 18
		local pos = world.center + Vector3.new(math.cos(ang) * r, 1, math.sin(ang) * r)
		local pad = part({
			Name = "MarblePad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 12, 12),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(245, 245, 250),
			Material = Enum.Material.Marble,
		})
		pad.Parent = folder
		local trim = part({
			Name = "MarblePadTrim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 12, 12),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(245, 200, 80),
			Material = Enum.Material.Foil,
			CanCollide = false,
		})
		trim.Parent = folder
	end

	-- gold radial strips on the platform from the altar to the edges
	for i = 1, 8 do
		local ang = (i - 1) / 8 * math.pi * 2
		local len = world.platformRadius - 6
		local stripPos = world.center + Vector3.new(
			math.cos(ang) * (len / 2 + 4),
			platformTopY - world.center.Y + 0.05,
			math.sin(ang) * (len / 2 + 4)
		)
		local strip = part({
			Name = "GoldRay",
			Size = Vector3.new(len, 0.15, 0.6),
			CFrame = CFrame.new(stripPos) * CFrame.Angles(0, -ang, 0),
			Color = Color3.fromRGB(245, 200, 80),
			Material = Enum.Material.Foil,
			CanCollide = false,
		})
		strip.Parent = folder
	end

	-- OLYMPUS FLOURISHES --

	-- pegasus statue on a tall pedestal opposite the altar (-Z)
	local pegPos = world.center + Vector3.new(0, 0, -22)
	local pegPedestal = part({
		Name = "PegasusPedestal",
		Size = Vector3.new(7, 6, 7),
		CFrame = CFrame.new(pegPos + Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.Marble,
	})
	pegPedestal.Parent = folder
	-- horse body
	local pegBody = part({
		Name = "PegasusBody",
		Size = Vector3.new(2.4, 3, 6),
		CFrame = CFrame.new(pegPos + Vector3.new(0, 8, 0)),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.Marble,
	})
	pegBody.Parent = folder
	-- 4 legs
	for _, dx in { -1, 1 } do
		for _, dz in { -1.8, 1.8 } do
			local leg = part({
				Name = "PegasusLeg",
				Size = Vector3.new(0.7, 3, 0.7),
				CFrame = CFrame.new(pegPos + Vector3.new(dx, 5, dz)),
				Color = Color3.fromRGB(245, 245, 250),
				Material = Enum.Material.Marble,
			})
			leg.Parent = folder
		end
	end
	-- neck + head
	local pegNeck = part({
		Name = "PegasusNeck",
		Size = Vector3.new(1.5, 3.2, 1.5),
		CFrame = CFrame.new(pegPos + Vector3.new(0, 10.2, 2.4)) * CFrame.Angles(math.rad(-30), 0, 0),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.Marble,
	})
	pegNeck.Parent = folder
	local pegHead = part({
		Name = "PegasusHead",
		Size = Vector3.new(1.5, 1.6, 2.6),
		CFrame = CFrame.new(pegPos + Vector3.new(0, 11.5, 3.6)) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.Marble,
	})
	pegHead.Parent = folder
	-- wings (gold-trimmed)
	for _, side in { -1, 1 } do
		local wing = part({
			Name = "PegasusWing",
			Size = Vector3.new(0.4, 5, 4),
			CFrame = CFrame.new(pegPos + Vector3.new(side * 1.6, 10, 0)) * CFrame.Angles(math.rad(-20), 0, math.rad(side * 30)),
			Color = Color3.fromRGB(245, 200, 80),
			Material = Enum.Material.Foil,
			CanCollide = false,
		})
		wing.Parent = folder
	end

	-- 3 floating gold rings around the arena (slowly rotating decorative tori suggested by torus-flat parts)
	for i = 1, 3 do
		local angle = (i - 1) / 3 * math.pi * 2
		local ringHeight = 18 + i * 6
		local ringPos = world.center + Vector3.new(math.cos(angle) * 14, ringHeight, math.sin(angle) * 14)
		-- 12 small gold blocks arranged in a circle to suggest a ring
		local segments = 12
		local ringRadius = 4
		for s = 1, segments do
			local a = (s - 1) / segments * math.pi * 2
			local segPos = ringPos + Vector3.new(math.cos(a) * ringRadius, 0, math.sin(a) * ringRadius)
			local seg = part({
				Name = "GoldRingSeg",
				Size = Vector3.new(0.6, 0.6, 1.4),
				CFrame = CFrame.new(segPos) * CFrame.Angles(0, -a, 0),
				Color = Color3.fromRGB(245, 200, 80),
				Material = Enum.Material.Foil,
				CanCollide = false,
			})
			seg.Parent = folder
		end
	end

	-- lightning bolt of light shooting up from the altar (the eternal flame already exists at world.center +Z 18)
	local boltCenter = world.center + Vector3.new(0, 30, 18)
	local bolt = part({
		Name = "ZeusBolt",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, 1.4, 1.4),
		CFrame = CFrame.new(boltCenter) * CFrame.Angles(0, 0, math.rad(85)),
		Color = Color3.fromRGB(255, 255, 200),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
	})
	bolt.Parent = folder
	local boltGlow = Instance.new("PointLight")
	boltGlow.Color = Color3.fromRGB(255, 240, 200)
	boltGlow.Brightness = 4
	boltGlow.Range = 30
	boltGlow.Parent = bolt
end

local themeBuilders: { [string]: (Folder, Worlds.World) -> () } = {
	Backyard = buildBackyard,
	Quad = buildQuad,
	FratHouse = buildFratHouse,
	Stadium = buildStadium,
	Olympus = buildOlympus,
}

local function buildArenaQueueZone(folder: Folder, world: Worlds.World)
	local platformTopY = world.center.Y + Config.ArenaDefaults.PlatformThickness / 2
	local isPractice = world.isPractice == true
	local padColor = isPractice and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 220, 120)
	local padName = isPractice and "PracticeStartPad" or "QueuePad"
	-- queue/practice pad: glowing disc, near +Z edge of platform
	local queuePos = Vector3.new(world.center.X, platformTopY + 0.3, world.center.Z + world.platformRadius * 0.55)
	local queuePad = part({
		Name = padName,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 12, 12),
		CFrame = CFrame.new(queuePos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = padColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.15,
	})
	queuePad.Parent = folder
	local qLight = Instance.new("PointLight")
	qLight.Color = padColor
	qLight.Brightness = 2
	qLight.Range = 16
	qLight.Parent = queuePad

	-- queue board: floating BillboardGui with multi-line state
	local board = Instance.new("Part")
	board.Name = "QueueBoardAnchor"
	board.Size = Vector3.new(0.5, 0.5, 0.5)
	board.Position = queuePos + Vector3.new(0, 14, 0)
	board.Anchored = true
	board.CanCollide = false
	board.Transparency = 1
	board.Parent = folder
	local bg = Instance.new("BillboardGui")
	bg.Name = "QueueBoard"
	bg.Size = UDim2.fromScale(22, 11)
	bg.AlwaysOnTop = false
	bg.LightInfluence = 0
	bg.MaxDistance = 1500
	bg.Parent = board
	-- card background
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 14)
	frameCorner.Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Thickness = 2
	frameStroke.Color = world.platformColor
	frameStroke.Parent = frame
	frame.Parent = bg
	-- title
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0, 0.05)
	title.Size = UDim2.fromScale(1, 0.30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = world.platformColor
	title.TextStrokeTransparency = 0.4
	title.Text = world.name:upper()
	title.Parent = frame
	-- status (count + countdown)
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromScale(0, 0.36)
	status.Size = UDim2.fromScale(1, 0.40)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(255, 255, 255)
	status.TextStrokeTransparency = 0.4
	status.Text = isPractice and "SOLO TRAINING\nNo elimination" or "0 / 14 in queue\nNeed 2 to start"
	status.Parent = frame
	-- footer hint
	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromScale(0, 0.78)
	hint.Size = UDim2.fromScale(1, 0.18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = isPractice and Color3.fromRGB(255, 220, 160) or Color3.fromRGB(160, 200, 160)
	hint.TextStrokeTransparency = 0.4
	hint.Text = isPractice and "Step on the YELLOW pad to start practicing" or "Step on the GREEN pad to queue"
	hint.Parent = frame

	queueBoardLabels[world.id] = status

	-- return pad: red glowing disc, opposite side
	local returnPos = Vector3.new(world.center.X, platformTopY + 0.3, world.center.Z - world.platformRadius * 0.55)
	local returnPad = part({
		Name = "ReturnPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 8, 8),
		CFrame = CFrame.new(returnPos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 70, 70),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
	})
	returnPad.Parent = folder
	local rLight = Instance.new("PointLight")
	rLight.Color = Color3.fromRGB(230, 70, 70)
	rLight.Brightness = 1.5
	rLight.Range = 12
	rLight.Parent = returnPad
	billboard(returnPad, "← BACK TO LOBBY", Color3.fromRGB(255, 200, 200), Vector2.new(10, 2.2), 4)

	queuePads[world.id] = queuePad
	returnPads[world.id] = returnPad
	-- staging position: a few studs in front of the queue pad (toward arena center) so arrivals
	-- aren't standing on top of the pad and don't auto-fire its Touched event
	local stagingPos = queuePos + Vector3.new(0, 4, -8)
	stagingCFrames[world.id] = CFrame.lookAt(stagingPos, queuePos + Vector3.new(0, 4, 0))
end

local function buildArenas(root: Folder)
	local arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = root
	for _, world in Worlds.List do
		local arenaFolder = Instance.new("Folder")
		arenaFolder.Name = world.id
		arenaFolder.Parent = arenasFolder
		-- main pad
		local pad = disc(
			"ArenaPlatform",
			world.center,
			world.platformRadius,
			Config.ArenaDefaults.PlatformThickness,
			world.platformColor,
			world.platformMaterial
		)
		pad.Parent = arenaFolder
		-- glow underglow — fatter and brighter so the arena reads from the sky lobby
		local glow = disc(
			"ArenaGlow",
			world.center - Vector3.new(0, 1.2, 0),
			world.platformRadius + 8,
			0.6,
			world.platformColor,
			Enum.Material.Neon
		)
		glow.CanCollide = false
		glow.Transparency = 0.2
		glow.Parent = arenaFolder
		-- beacon beam shooting up so you can find this arena from the lobby (Y = +900 from arena top)
		local beam = part({
			Name = "ArenaBeacon",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(900, 4, 4),
			CFrame = CFrame.new(world.center + Vector3.new(0, 450, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = world.platformColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.8,
		})
		beam.Parent = arenaFolder
		-- nameplate above arena
		billboard(pad, world.name, world.platformColor, Vector2.new(22, 4.5), world.platformRadius / 2 + 6)
		-- giant nameplate visible from very high up
		local skyAnchor = part({
			Name = "SkyLabel",
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = CFrame.new(world.center + Vector3.new(0, 220, 0)),
			Transparency = 1,
			CanCollide = false,
		})
		skyAnchor.Parent = arenaFolder
		billboard(skyAnchor, world.name:upper(), world.platformColor, Vector2.new(80, 16), 0)
		-- themed decor
		local builder = themeBuilders[world.id]
		if builder then
			builder(arenaFolder, world)
		end
		-- invisible safety + isolation barrier so players can't jump out / between arenas
		local barrierFolder = Instance.new("Folder")
		barrierFolder.Name = "InvisibleBarrier"
		barrierFolder.Parent = arenaFolder
		wallRing(barrierFolder, {
			center = world.center,
			radius = world.platformRadius + 1,
			height = 36,
			thickness = 1.0,
			segmentCount = 36,
			color = Color3.fromRGB(255, 255, 255),
			material = Enum.Material.ForceField,
		})
		for _, child in barrierFolder:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = 0.92 -- almost invisible, faint sheen so players see the limit
			end
		end
		-- queue zone (queue pad, return pad, board, staging cframe)
		buildArenaQueueZone(arenaFolder, world)
	end
end

local function getOrMake(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function tuneLightingForLobby()
	Lighting.Ambient = Color3.fromRGB(80, 80, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
	Lighting.Brightness = 2

	-- bloom: makes neon parts pop dramatically
	local bloom = getOrMake(Lighting, "BloomEffect", "SacktopiaBloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 0.85

	-- atmosphere: adds depth haze, separates the lobby from the worlds below visually
	local atmosphere = getOrMake(Lighting, "Atmosphere", "SacktopiaAtmosphere") :: Atmosphere
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(90, 80, 110)
	atmosphere.Decay = Color3.fromRGB(60, 50, 90)
	atmosphere.Glare = 0.6
	atmosphere.Haze = 1.6

	-- color correction: subtle saturation + contrast bump
	local cc = getOrMake(Lighting, "ColorCorrectionEffect", "SacktopiaColor") :: ColorCorrectionEffect
	cc.Saturation = 0.12
	cc.Contrast = 0.08
	cc.Brightness = 0
end

local function disableForeignSpawns()
	-- Any SpawnLocation that isn't ours (e.g. the default baseplate spawn) gets disabled
	-- so the engine routes new characters to LobbySpawn.
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") and inst ~= lobbySpawn then
			inst.Enabled = false
		end
	end
end

function ArenaBuilder.build(): { Portal }
	local root = getRoot()
	if root:FindFirstChild("Lobby") then
		return builtPortals
	end
	tuneLightingForLobby()
	buildLobby(root)
	buildArenas(root)
	for i, world in Worlds.List do
		local angle = (i - 1) / #Worlds.List * math.pi * 2 - math.pi / 2
		buildPortal(root.Lobby, world, angle)
	end
	disableForeignSpawns()
	return builtPortals
end

function ArenaBuilder.getPortals(): { Portal }
	return builtPortals
end

function ArenaBuilder.getLobbySpawn(): SpawnLocation?
	return lobbySpawn
end

function ArenaBuilder.getLobbyCFrame(): CFrame
	return CFrame.new(Config.Lobby.Center + Vector3.new(0, Config.Lobby.PlatformThickness / 2 + 4, 0))
end

function ArenaBuilder.getQueuePad(worldId: string): BasePart?
	return queuePads[worldId]
end

function ArenaBuilder.getReturnPad(worldId: string): BasePart?
	return returnPads[worldId]
end

function ArenaBuilder.getQueueBoardLabel(worldId: string): TextLabel?
	return queueBoardLabels[worldId]
end

function ArenaBuilder.getStagingCFrame(worldId: string): CFrame?
	return stagingCFrames[worldId]
end

return ArenaBuilder
