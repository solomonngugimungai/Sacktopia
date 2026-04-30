--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

-- In Studio solo Play (F5), there's only one player — let them queue alone so they can
-- actually test. Live servers still require Config.Round.MinPlayers.
local function effectiveMinPlayers(): number
	if RunService:IsStudio() then
		return 1
	end
	return Config.Round.MinPlayers
end
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local MatchController = require(script.Parent:WaitForChild("MatchController"))
local PlayerState = require(script.Parent.PlayerState)
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

type World = Worlds.World

local Lobby = {}

type Queue = {
	world: World,
	players: { Player },
	autoStartAt: number?, -- os.clock() at which queue auto-starts
}

local queues: { [string]: Queue } = {}
local activeMatches: { [string]: any } = {} -- worldId -> MatchController

local function broadcastQueueState(worldId: string)
	local q = queues[worldId]
	if not q then
		return
	end
	local secondsToStart: number? = nil
	if q.autoStartAt then
		secondsToStart = math.max(q.autoStartAt - os.clock(), 0)
	end
	Remotes.QueueState:FireAllClients({
		worldId = worldId,
		count = #q.players,
		secondsToStart = secondsToStart,
		matchInProgress = activeMatches[worldId] ~= nil,
	})
end

local function teleportToLobby(player: Player)
	if not player.Character then
		player:LoadCharacter()
		player.CharacterAdded:Wait()
	end
	local char = player.Character
	if char then
		char:PivotTo(ArenaBuilder.getLobbyCFrame())
	end
end

local function removeFromAllQueues(player: Player)
	for worldId, q in queues do
		for i = #q.players, 1, -1 do
			if q.players[i] == player then
				table.remove(q.players, i)
			end
		end
		if #q.players < effectiveMinPlayers() then
			q.autoStartAt = nil
		end
		broadcastQueueState(worldId)
	end
end

local function isInAnyMatch(player: Player): boolean
	for _, match in activeMatches do
		if match:isPlayerInMatch(player) then
			return true
		end
	end
	return false
end

local function tryStartMatch(worldId: string)
	local q = queues[worldId]
	if not q then
		return
	end
	if activeMatches[worldId] then
		return -- one match per world at a time
	end
	if #q.players < effectiveMinPlayers() then
		q.autoStartAt = nil
		broadcastQueueState(worldId)
		return
	end
	-- pull up to MaxPlayersPerMatch
	local roster: { Player } = {}
	while #roster < Config.Lobby.MaxPlayersPerMatch and #q.players > 0 do
		table.insert(roster, table.remove(q.players, 1) :: Player)
	end
	q.autoStartAt = nil
	broadcastQueueState(worldId)

	local match = MatchController.new(q.world, roster)
	activeMatches[worldId] = match
	match:onEnded(function(placements)
		-- teleport survivors + losers back
		task.delay(2.5, function()
			for _, p in placements do
				if p and p.Parent then
					teleportToLobby(p)
				end
			end
			activeMatches[worldId] = nil
			-- maybe a new match is ready
			tryStartMatch(worldId)
		end)
	end)
	match:start()
end

local function joinQueue(player: Player, worldId: string)
	local world = Worlds.byId(worldId)
	if not world then
		return
	end
	local stats = PlayerStats.get(player)
	if not stats then
		return
	end
	if not Worlds.canEnter(world, stats.tierId) then
		-- silent fail; client UI should already prevent this
		return
	end
	if isInAnyMatch(player) then
		return
	end
	-- remove from any other queue first
	for otherId, q in queues do
		if otherId ~= worldId then
			for i = #q.players, 1, -1 do
				if q.players[i] == player then
					table.remove(q.players, i)
				end
			end
			broadcastQueueState(otherId)
		end
	end
	local q = queues[worldId]
	if not q then
		return
	end
	for _, p in q.players do
		if p == player then
			return -- already queued
		end
	end
	table.insert(q.players, player)
	if #q.players >= effectiveMinPlayers() and not q.autoStartAt and not activeMatches[worldId] then
		q.autoStartAt = os.clock() + Config.Lobby.QueueAutoStartSeconds
		task.delay(Config.Lobby.QueueAutoStartSeconds, function()
			if queues[worldId].autoStartAt then
				tryStartMatch(worldId)
			end
		end)
	end
	broadcastQueueState(worldId)
end

local function leaveQueue(player: Player)
	removeFromAllQueues(player)
end

local function bindPortalTouch(portal: ArenaBuilder.Portal)
	portal.part.Touched:Connect(function(hit: BasePart)
		local char = hit:FindFirstAncestorWhichIsA("Model")
		if not char then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		joinQueue(player, portal.world.id)
	end)
end

function Lobby.start()
	-- build geometry first
	local portals = ArenaBuilder.build()
	local lobbySpawn = ArenaBuilder.getLobbySpawn()
	for _, world in Worlds.List do
		queues[world.id] = { world = world, players = {}, autoStartAt = nil }
	end
	for _, portal in portals do
		bindPortalTouch(portal)
	end

	-- player lifecycle
	local function onPlayerAdded(player: Player)
		PlayerState.add(player)
		-- bind respawn to the lobby spawn so default SpawnLocations can't steal them
		if lobbySpawn then
			player.RespawnLocation = lobbySpawn
		end
		player.CharacterAdded:Connect(function()
			-- if not in a match, send to lobby (defense in depth — RespawnLocation should already do this)
			if not isInAnyMatch(player) then
				task.wait(0.1)
				teleportToLobby(player)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
		teleportToLobby(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(p: Player)
		removeFromAllQueues(p)
		for _, match in activeMatches do
			match:handlePlayerLeaving(p)
		end
		PlayerState.remove(p)
	end)

	-- deflect remote → forward to whichever match the player is in
	Remotes.DeflectAttempt.OnServerEvent:Connect(function(player: Player, aimDirection, clientTime)
		if typeof(aimDirection) ~= "Vector3" or typeof(clientTime) ~= "number" then
			return
		end
		for _, match in activeMatches do
			if match:isPlayerInMatch(player) and match.sack then
				match.sack:onDeflectAttempt(player, aimDirection, clientTime)
				return
			end
		end
	end)

	Remotes.JoinQueue.OnServerEvent:Connect(function(player: Player, worldId)
		if typeof(worldId) ~= "string" then
			return
		end
		joinQueue(player, worldId)
	end)
	Remotes.LeaveQueue.OnServerEvent:Connect(function(player: Player)
		leaveQueue(player)
	end)

	-- periodic queue tick to update countdown UI
	task.spawn(function()
		while true do
			task.wait(0.5)
			for worldId in queues do
				broadcastQueueState(worldId)
			end
		end
	end)
end

return Lobby
