--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

export type World = {
	id: string,
	name: string,
	tagline: string,
	requiredTier: string, -- rank tier id needed to enter
	center: Vector3,
	-- arena tuning
	boundsRadius: number,
	boundsHeight: number,
	spawnRadius: number,
	sackSpawnHeight: number,
	platformRadius: number,
	platformColor: Color3,
	platformMaterial: Enum.Material,
}

local function world(t: { [string]: any }): World
	t.boundsRadius = t.boundsRadius or Config.ArenaDefaults.BoundsRadius
	t.boundsHeight = t.boundsHeight or Config.ArenaDefaults.BoundsHeight
	t.spawnRadius = t.spawnRadius or Config.ArenaDefaults.SpawnRadius
	t.sackSpawnHeight = t.sackSpawnHeight or Config.ArenaDefaults.SackSpawnHeight
	t.platformRadius = t.platformRadius or Config.ArenaDefaults.PlatformRadius
	return t :: World
end

local Worlds = {}

Worlds.List = {
	world({
		id = "Backyard",
		name = "Backyard",
		tagline = "Where every legend starts.",
		requiredTier = "Bronze",
		center = Vector3.new(0, 0, 0),
		platformColor = Color3.fromRGB(80, 140, 70),
		platformMaterial = Enum.Material.Grass,
	}),
	world({
		id = "Quad",
		name = "The Quad",
		tagline = "Dorm-side dust-up.",
		requiredTier = "Silver",
		center = Vector3.new(300, 0, 0),
		platformColor = Color3.fromRGB(190, 170, 140),
		platformMaterial = Enum.Material.Brick,
	}),
	world({
		id = "FratHouse",
		name = "Frat House",
		tagline = "Where the frat caps come out.",
		requiredTier = "Gold",
		center = Vector3.new(-300, 0, 0),
		platformColor = Color3.fromRGB(120, 70, 40),
		platformMaterial = Enum.Material.Wood,
	}),
	world({
		id = "Stadium",
		name = "The Stadium",
		tagline = "Center stage. Bring your skin.",
		requiredTier = "Platinum",
		center = Vector3.new(0, 0, 300),
		platformColor = Color3.fromRGB(110, 110, 130),
		platformMaterial = Enum.Material.Concrete,
	}),
	world({
		id = "Olympus",
		name = "Olympus",
		tagline = "Only the gods kick here.",
		requiredTier = "Diamond",
		center = Vector3.new(0, 0, -300),
		platformColor = Color3.fromRGB(240, 240, 255),
		platformMaterial = Enum.Material.Marble,
	}),
}

function Worlds.byId(id: string): World?
	for _, w in Worlds.List do
		if w.id == id then
			return w
		end
	end
	return nil
end

function Worlds.canEnter(world: World, playerTierId: string): boolean
	local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))
	return Ranks.tierIndex(playerTierId) >= Ranks.tierIndex(world.requiredTier)
end

return Worlds
