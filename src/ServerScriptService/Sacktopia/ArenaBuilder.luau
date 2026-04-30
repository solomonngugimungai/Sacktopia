--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))

local ArenaBuilder = {}

local ROOT_NAME = "SacktopiaWorld"

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

local function platform(name: string, center: Vector3, radius: number, thickness: number, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, radius * 2, radius * 2)
	-- cylinders point along X by default; rotate so the disc face is horizontal
	p.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = true
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
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

export type Portal = {
	world: Worlds.World,
	part: BasePart,
}

local builtPortals: { Portal } = {}

local function buildLobby(root: Folder)
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = root

	local pad = platform(
		"LobbyPlatform",
		Config.Lobby.Center,
		Config.Lobby.PlatformRadius,
		Config.Lobby.PlatformThickness,
		Color3.fromRGB(60, 70, 95),
		Enum.Material.SmoothPlastic
	)
	pad.Parent = lobbyFolder

	-- spawn point: an actual SpawnLocation so Players spawn here
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "LobbySpawn"
	spawnPart.Size = Vector3.new(8, 1, 8)
	spawnPart.CFrame = CFrame.new(Config.Lobby.Center + Vector3.new(0, Config.Lobby.PlatformThickness / 2 + 0.5, 0))
	spawnPart.Anchored = true
	spawnPart.CanCollide = true
	spawnPart.Neutral = true
	spawnPart.AllowTeamChangeOnTouch = false
	spawnPart.TopSurface = Enum.SurfaceType.Smooth
	spawnPart.Material = Enum.Material.Neon
	spawnPart.Color = Color3.fromRGB(80, 200, 255)
	spawnPart.Transparency = 0.3
	spawnPart.Parent = lobbyFolder
	billboard(spawnPart, "SACKTOPIA", Color3.fromRGB(255, 255, 255), Vector2.new(14, 3.2), 6)
end

local function buildPortal(parent: Folder, world: Worlds.World, angle: number)
	local center = Config.Lobby.Center
	local pos = center + Vector3.new(
		math.cos(angle) * Config.Lobby.PortalRingRadius,
		Config.Lobby.PlatformThickness / 2 + Config.Lobby.PortalSize.Y / 2,
		math.sin(angle) * Config.Lobby.PortalRingRadius
	)
	local p = Instance.new("Part")
	p.Name = "Portal_" .. world.id
	p.Size = Config.Lobby.PortalSize
	p.CFrame = CFrame.new(pos)
	p.Anchored = true
	p.CanCollide = false
	p.Material = world.platformMaterial
	p.Color = world.platformColor
	p.Transparency = 0.2
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent

	-- glowing ring effect
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 14
	light.Color = world.platformColor
	light.Parent = p

	-- label
	local tier = Ranks.tierIndex(world.requiredTier)
	local tierName = Config.Rank.Tiers[tier].name
	billboard(
		p,
		string.format("%s\n%s+ • %s", world.name, tierName, world.tagline),
		world.platformColor,
		Vector2.new(11, 2.6),
		3.5
	)

	table.insert(builtPortals, { world = world, part = p })
end

local function buildArenas(root: Folder)
	local arenasFolder = Instance.new("Folder")
	arenasFolder.Name = "Arenas"
	arenasFolder.Parent = root
	for _, world in Worlds.List do
		local arenaFolder = Instance.new("Folder")
		arenaFolder.Name = world.id
		arenaFolder.Parent = arenasFolder
		local pad = platform(
			"ArenaPlatform",
			world.center,
			world.platformRadius,
			Config.ArenaDefaults.PlatformThickness,
			world.platformColor,
			world.platformMaterial
		)
		pad.Parent = arenaFolder
		billboard(pad, world.name, world.platformColor, Vector2.new(20, 4), world.platformRadius / 2)
	end
end

function ArenaBuilder.build(): { Portal }
	local root = getRoot()
	-- if already built, don't rebuild (idempotent for hot reloads via Rojo)
	if root:FindFirstChild("Lobby") then
		return builtPortals
	end
	buildLobby(root)
	buildArenas(root)
	for i, world in Worlds.List do
		local angle = (i - 1) / #Worlds.List * math.pi * 2 - math.pi / 2
		buildPortal(root.Lobby, world, angle)
	end
	return builtPortals
end

function ArenaBuilder.getPortals(): { Portal }
	return builtPortals
end

function ArenaBuilder.getLobbyCFrame(): CFrame
	return CFrame.new(Config.Lobby.Center + Vector3.new(0, Config.Lobby.PlatformThickness / 2 + 4, 0))
end

return ArenaBuilder
