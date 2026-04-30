--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local PlayerState = require(script.Parent.PlayerState)
local SackController = require(script.Parent.SackController)

local RoundManager = {}

local currentSack: typeof(SackController.new())? = nil
local roundActive = false
local roundId = 0

local function pickSpawnCFrame(i: number, total: number): CFrame
	local angle = (i - 1) / math.max(total, 1) * math.pi * 2
	local radius = Config.Arena.SpawnRadius
	local pos = Config.Arena.Center + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
	local lookAt = Config.Arena.Center + Vector3.new(0, 5, 0)
	return CFrame.lookAt(pos, lookAt)
end

local function broadcastState(phase: string, message: string?)
	local alive = {}
	for _, p in PlayerState.alivePlayers() do
		table.insert(alive, p.UserId)
	end
	Remotes.RoundState:FireAllClients({
		phase = phase,
		alive = alive,
		roundId = roundId,
		message = message,
	})
end

local function teleportPlayers()
	local players = Players:GetPlayers()
	for i, player in players do
		PlayerState.setAlive(player, true)
		local cf = pickSpawnCFrame(i, #players)
		if not player.Character then
			player:LoadCharacter()
		end
		task.wait(0) -- yield once so character is ready
		local char = player.Character
		if char and char.PrimaryPart then
			char:PivotTo(cf)
		end
	end
end

local function endRound(winner: Player?)
	roundActive = false
	if currentSack then
		currentSack:destroy()
		currentSack = nil
	end
	local message = winner and (winner.DisplayName .. " wins!") or "Round ended"
	broadcastState("ended", message)
end

local function watchEliminations()
	while roundActive do
		task.wait(0.5)
		local alive = PlayerState.alivePlayers()
		if #alive <= 1 then
			endRound(alive[1])
			return
		end
	end
end

local function startRound()
	roundId += 1
	PlayerState.resetAllForRound()
	teleportPlayers()
	-- give characters a beat to load
	task.wait(0.75)
	roundActive = true
	currentSack = SackController.new()
	currentSack:start()
	broadcastState("playing")
	task.spawn(watchEliminations)

	-- safety timeout
	local startedAt = os.clock()
	while roundActive do
		task.wait(1)
		if os.clock() - startedAt > Config.Round.MaxRoundSeconds then
			endRound(nil)
			break
		end
	end
end

local function intermission()
	for s = Config.Round.IntermissionSeconds, 1, -1 do
		broadcastState("intermission", "Next round in " .. s)
		task.wait(1)
	end
end

function RoundManager.start()
	-- player lifecycle
	local function onPlayerAdded(player: Player)
		PlayerState.add(player)
		player.CharacterAdded:Connect(function()
			if not roundActive then
				PlayerState.setAlive(player, false)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(p: Player)
		PlayerState.remove(p)
	end)

	-- deflect remote → forward to current sack
	Remotes.DeflectAttempt.OnServerEvent:Connect(function(player: Player, aimDirection: Vector3, clientTime: number)
		if typeof(aimDirection) ~= "Vector3" or typeof(clientTime) ~= "number" then
			return
		end
		if currentSack then
			currentSack:onDeflectAttempt(player, aimDirection, clientTime)
		end
	end)

	task.spawn(function()
		while true do
			-- wait for enough players
			while #Players:GetPlayers() < Config.Round.MinPlayers do
				broadcastState("waiting", "Waiting for players...")
				task.wait(2)
			end
			intermission()
			startRound()
		end
	end)
end

return RoundManager
