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
}

return Remotes
