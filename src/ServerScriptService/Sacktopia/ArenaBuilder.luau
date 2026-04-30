--!strict
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

	-- enclosing wall ring with gaps where portals will be
	local portalAngles = {}
	for i = 1, #Worlds.List do
		local angle = (i - 1) / #Worlds.List * math.pi * 2 - math.pi / 2
		table.insert(portalAngles, angle)
	end
	wallRing(lobbyFolder, {
		center = center,
		radius = r - 1,
		height = 28,
		thickness = 1.5,
		segmentCount = 24,
		color = LOBBY_DARK,
		material = Enum.Material.SmoothPlastic,
		topAccentColor = NEON_MAGENTA,
		topAccentMaterial = Enum.Material.Neon,
		gapAngles = portalAngles,
		gapHalfWidth = math.rad(14),
	})

	-- corner pillars at each gap (frame each portal)
	for _, angle in portalAngles do
		for _, side in { -1, 1 } do
			local sideAngle = angle + side * math.rad(14)
			local px = math.cos(sideAngle) * (r - 1)
			local pz = math.sin(sideAngle) * (r - 1)
			local pillarPost = part({
				Name = "PortalFrame",
				Size = Vector3.new(2, 30, 2),
				CFrame = CFrame.new(center + Vector3.new(px, 15, pz)),
				Color = LOBBY_DARK,
				Material = Enum.Material.SmoothPlastic,
			})
			pillarPost.Parent = lobbyFolder
			local pl = Instance.new("PointLight")
			pl.Color = NEON_CYAN
			pl.Brightness = 1.5
			pl.Range = 18
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
	local pos = center + Vector3.new(
		math.cos(angle) * r,
		Config.Lobby.PlatformThickness / 2 + Config.Lobby.PortalSize.Y / 2,
		math.sin(angle) * r
	)
	local p = part({
		Name = "Portal_" .. world.id,
		Size = Config.Lobby.PortalSize,
		CFrame = CFrame.new(pos),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	p.Parent = parent
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 20
	light.Color = world.platformColor
	light.Parent = p

	-- portal arch (cylinder rotated to be a vertical hoop suggestion: two short verticals + a top horizontal)
	local archHeight = 14
	for _, side in { -1, 1 } do
		local sideOffset = Vector3.new(math.cos(angle + math.pi / 2) * 3 * side, archHeight / 2, math.sin(angle + math.pi / 2) * 3 * side)
		local pillar = part({
			Name = "PortalArch_" .. world.id,
			Size = Vector3.new(0.8, archHeight, 0.8),
			CFrame = CFrame.new(pos + sideOffset - Vector3.new(0, Config.Lobby.PortalSize.Y / 2, 0)),
			Color = world.platformColor,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.1,
		})
		pillar.Parent = parent
	end
	local topBar = part({
		Name = "PortalTop_" .. world.id,
		Size = Vector3.new(0.8, 0.8, 6.6),
		CFrame = CFrame.new(pos + Vector3.new(0, archHeight - Config.Lobby.PortalSize.Y / 2, 0))
			* CFrame.fromMatrix(
				Vector3.zero,
				Vector3.new(-math.sin(angle), 0, math.cos(angle)),
				Vector3.new(0, 1, 0)
			),
		Color = world.platformColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.1,
	})
	topBar.Parent = parent

	local tier = Ranks.tierIndex(world.requiredTier)
	local tierName = Config.Rank.Tiers[tier].name
	billboard(
		topBar,
		string.format("%s\n%s+ • %s", world.name, tierName, world.tagline),
		world.platformColor,
		Vector2.new(12, 2.8),
		3.5
	)

	table.insert(builtPortals, { world = world, part = p })
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
end

local themeBuilders: { [string]: (Folder, Worlds.World) -> () } = {
	Backyard = buildBackyard,
	Quad = buildQuad,
	FratHouse = buildFratHouse,
	Stadium = buildStadium,
	Olympus = buildOlympus,
}

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
		-- glow underglow
		local glow = disc(
			"ArenaGlow",
			world.center - Vector3.new(0, 1.2, 0),
			world.platformRadius + 2,
			0.4,
			world.platformColor,
			Enum.Material.Neon
		)
		glow.CanCollide = false
		glow.Transparency = 0.3
		glow.Parent = arenaFolder
		-- nameplate above arena
		billboard(pad, world.name, world.platformColor, Vector2.new(22, 4.5), world.platformRadius / 2 + 6)
		-- themed decor
		local builder = themeBuilders[world.id]
		if builder then
			builder(arenaFolder, world)
		end
	end
end

local function tuneLightingForLobby()
	-- gentle global tweaks; arenas at y=0 still feel daylight-ish because point lights
	-- around the lobby take over the visuals up at y=500
	Lighting.Ambient = Color3.fromRGB(80, 80, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
	Lighting.Brightness = 2
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

return ArenaBuilder
