--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

-- In Studio solo Play (F5) there's only one player — let them queue alone so they can
-- test. The moment a second player joins (multi-client test), require the real Config min
-- so the queue actually waits for both. Live servers always use Config.Round.MinPlayers.
local function effectiveMinPlayers(): number
	if RunService:IsStudio() and #Players:GetPlayers() < 2 then
		return 1
	end
	return Config.Round.MinPlayers
end
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local ArenaBuilder = require(script.Parent:WaitForChild("ArenaBuilder"))
local MatchController = require(script.Parent:WaitForChild("MatchController"))
local Practice = require(script.Parent:WaitForChild("Practice"))
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

local function updateQueueBoard(worldId: string)
	local label = ArenaBuilder.getQueueBoardLabel(worldId)
	if not label then
		return
	end
	local world = Worlds.byId(worldId)
	if world and world.isPractice then
		return -- practice arena keeps its static "SOLO TRAINING" text
	end
	local q = queues[worldId]
	if not q then
		return
	end
	local minP = effectiveMinPlayers()
	local cap = Config.Lobby.MaxPlayersPerMatch
	local count = #q.players
	if activeMatches[worldId] then
		label.Text = string.format("MATCH IN PROGRESS\n%d / %d queued for next", count, cap)
	elseif q.autoStartAt then
		local seconds = math.max(math.ceil(q.autoStartAt - os.clock()), 0)
		label.Text = string.format("%d / %d in queue\nMatch starts in %ds", count, cap, seconds)
	elseif count >= minP then
		label.Text = string.format("%d / %d in queue\nReady…", count, cap)
	elseif count > 0 then
		label.Text = string.format("%d / %d in queue\nNeed %d more to start", count, cap, minP - count)
	else
		label.Text = string.format("0 / %d in queue\nNeed %d to start", cap, minP)
	end
end

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
	updateQueueBoard(worldId)
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

local function teleportToWorldStaging(player: Player, worldId: string)
	local cf = ArenaBuilder.getStagingCFrame(worldId)
	if not cf then
		return
	end
	if not player.Character then
		player:LoadCharacter()
		player.CharacterAdded:Wait()
	end
	local char = player.Character
	if char then
		char:PivotTo(cf)
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
		-- send everyone back to the world's staging area so re-queueing is one step
		task.delay(2.5, function()
			for _, p in placements do
				if p and p.Parent then
					teleportToWorldStaging(p, worldId)
				end
			end
			activeMatches[worldId] = nil
			updateQueueBoard(worldId)
			-- if more players have queued in the meantime, fire next match
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
	if #q.players >= Config.Lobby.MaxPlayersPerMatch then
		return -- queue full; player should wait for next cycle
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

-- shared touch → player resolver with debounce so we don't fire 30x per second
local touchDebounce: { [Player]: number } = {}
local function resolveTouchedPlayer(hit: BasePart, debounceSeconds: number): Player?
	local char = hit:FindFirstAncestorWhichIsA("Model")
	if not char then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		return nil
	end
	local now = os.clock()
	local last = touchDebounce[player]
	if last and now - last < debounceSeconds then
		return nil
	end
	touchDebounce[player] = now
	return player
end

local function bindPortalTouch(portal: ArenaBuilder.Portal)
	-- Portals NO LONGER auto-queue. They just teleport you to that world's staging area.
	-- Queueing is opt-in via the green QUEUE pad inside the world (or yellow PRACTICE pad).
	portal.part.Touched:Connect(function(hit: BasePart)
		local player = resolveTouchedPlayer(hit, 1.0)
		if not player then
			return
		end
		local stats = PlayerStats.get(player)
		if not stats then
			return
		end
		if not Worlds.canEnter(portal.world, stats.tierId) then
			return -- gated; LobbyHUD shows the lock
		end
		if isInAnyMatch(player) or Practice.isInSession(player) then
			return
		end
		teleportToWorldStaging(player, portal.world.id)
	end)
end

local function bindQueuePadTouch(worldId: string, pad: BasePart)
	local world = Worlds.byId(worldId)
	print(string.format("[Sacktopia] bound pad for world=%s, isPractice=%s", worldId, tostring(world and world.isPractice)))
	pad.Touched:Connect(function(hit: BasePart)
		local player = resolveTouchedPlayer(hit, 0.4)
		if not player then
			return
		end
		print(string.format("[Sacktopia] pad TOUCHED in world=%s by %s (isPractice=%s)",
			worldId, player.Name, tostring(world and world.isPractice)))
		if world and world.isPractice then
			Practice.startSession(player, world)
		else
			joinQueue(player, worldId)
		end
	end)
end

local function bindReturnPadTouch(worldId: string, pad: BasePart)
	pad.Touched:Connect(function(hit: BasePart)
		local player = resolveTouchedPlayer(hit, 0.4)
		if not player then
			return
		end
		if isInAnyMatch(player) then
			return -- can't bail mid-match via the pad; fall off or die
		end
		-- end any practice session before teleporting out
		if Practice.isInSession(player) then
			Practice.endSession(player)
		end
		removeFromAllQueues(player)
		teleportToLobby(player)
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
	-- bind queue + return pads inside each world
	for _, world in Worlds.List do
		local qPad = ArenaBuilder.getQueuePad(world.id)
		if qPad then
			bindQueuePadTouch(world.id, qPad)
		end
		local rPad = ArenaBuilder.getReturnPad(world.id)
		if rPad then
			bindReturnPadTouch(world.id, rPad)
		end
		updateQueueBoard(world.id) -- initial paint
	end

	-- player lifecycle
	local function onPlayerAdded(player: Player)
		PlayerState.add(player)
		-- bind respawn to the lobby spawn so default SpawnLocations can't steal them
		if lobbySpawn then
			player.RespawnLocation = lobbySpawn
		end
		player.CharacterAdded:Connect(function(character: Model)
			-- disable jumping so SPACE only triggers deflect, never jump
			task.spawn(function()
				local hum = character:WaitForChild("Humanoid", 5)
				if hum and hum:IsA("Humanoid") then
					hum.JumpPower = 0
					hum.JumpHeight = 0
				end
			end)
			-- a respawn means whatever the player was doing is over — clear any stale practice
			-- session so the HUD doesn't keep ticking drops in the background
			if Practice.isInSession(player) then
				Practice.endSession(player)
			end
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
		touchDebounce[p] = nil
	end)

	-- deflect remote → forward to whichever match (or practice session) the player is in
	Remotes.DeflectAttempt.OnServerEvent:Connect(function(player: Player, aimDirection, clientTime, targetUserId)
		if typeof(aimDirection) ~= "Vector3" or typeof(clientTime) ~= "number" then
			return
		end
		local tUid: number? = nil
		if typeof(targetUserId) == "number" and targetUserId > 0 then
			tUid = targetUserId
		end
		-- practice takes priority (a player can't be in both a match and practice)
		if Practice.isInSession(player) then
			Practice.handleDeflect(player, aimDirection, clientTime, tUid)
			return
		end
		for _, match in activeMatches do
			if match:isPlayerInMatch(player) and match.sack then
				match.sack:onDeflectAttempt(player, aimDirection, clientTime, tUid)
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
