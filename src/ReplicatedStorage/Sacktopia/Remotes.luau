local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getOrCreate(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local root = getOrCreateFolder(ReplicatedStorage, "SacktopiaRemotes")

local Remotes = {
	-- client → server: player attempted a deflect at `clientTime` aiming at `aimDirection`
	DeflectAttempt = getOrCreate(root, "RemoteEvent", "DeflectAttempt") :: RemoteEvent,
	-- server → client: timing window opened for this player; pass predictedImpactTime + sackId
	WindowOpened = getOrCreate(root, "RemoteEvent", "WindowOpened") :: RemoteEvent,
	-- server → client: window closed (deflected by them, missed, or sack retargeted)
	WindowClosed = getOrCreate(root, "RemoteEvent", "WindowClosed") :: RemoteEvent,
	-- server → all: round state {phase, alive, roundId, message?}
	RoundState = getOrCreate(root, "RemoteEvent", "RoundState") :: RemoteEvent,
	-- server → all: sack state snapshot (combo holder + count) for HUD
	SackState = getOrCreate(root, "RemoteEvent", "SackState") :: RemoteEvent,
	-- server → eliminated player: you are out
	Eliminated = getOrCreate(root, "RemoteEvent", "Eliminated") :: RemoteEvent,
	-- client → server: equip an item id into a slot ("Head"|"Hand"|"SackSkin")
	EquipItem = getOrCreate(root, "RemoteEvent", "EquipItem") :: RemoteEvent,
	-- server → owning client: full inventory + current loadout snapshot
	InventoryUpdated = getOrCreate(root, "RemoteEvent", "InventoryUpdated") :: RemoteEvent,
	-- server → all: a player just successfully deflected — clients play kick FX on that character
	KickFX = getOrCreate(root, "RemoteEvent", "KickFX") :: RemoteEvent,
	-- server → owning client: stats snapshot {wins, top3, points, matchesPlayed, tierId}
	StatsUpdated = getOrCreate(root, "RemoteEvent", "StatsUpdated") :: RemoteEvent,
	-- server → owning client: a player ranked up {fromTierId, toTierId}
	RankUp = getOrCreate(root, "RemoteEvent", "RankUp") :: RemoteEvent,
	-- client → server: ask to join (or leave) a world's queue {worldId}
	JoinQueue = getOrCreate(root, "RemoteEvent", "JoinQueue") :: RemoteEvent,
	LeaveQueue = getOrCreate(root, "RemoteEvent", "LeaveQueue") :: RemoteEvent,
	-- server → all: queue snapshot per world {worldId, count, secondsToStart?}
	QueueState = getOrCreate(root, "RemoteEvent", "QueueState") :: RemoteEvent,
	-- server → match participants: match ended summary
	-- {placement, totalPlayers, pointsEarned, totalPoints, fromTierId, toTierId}
	MatchEnded = getOrCreate(root, "RemoteEvent", "MatchEnded") :: RemoteEvent,
	-- server → all clients: a player let the sack drop / got hit. Payload: {userId, displayName, reason}
	-- where reason is "ground" (sack landed) or "missed" (direct sack-to-player hit)
	DropAlert = getOrCreate(root, "RemoteEvent", "DropAlert") :: RemoteEvent,
}

return Remotes
