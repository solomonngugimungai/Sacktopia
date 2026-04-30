local Players = game:GetService("Players")

local PlayerState = {}

local state: { [Player]: { alive: boolean, inMatch: boolean } } = {}

function PlayerState.add(player: Player)
	state[player] = { alive = false, inMatch = false }
end

function PlayerState.remove(player: Player)
	state[player] = nil
end

function PlayerState.setAlive(player: Player, alive: boolean)
	local s = state[player]
	if s then
		s.alive = alive
		s.inMatch = alive or s.inMatch
	end
end

function PlayerState.markOut(player: Player)
	local s = state[player]
	if s then
		s.alive = false
	end
end

function PlayerState.isAlive(player: Player): boolean
	local s = state[player]
	return s ~= nil and s.alive
end

function PlayerState.alivePlayers(): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if PlayerState.isAlive(p) then
			table.insert(out, p)
		end
	end
	return out
end

function PlayerState.resetAllForRound()
	for player, s in state do
		s.alive = false
		s.inMatch = false
		if not player.Parent then
			state[player] = nil
		end
	end
end

return PlayerState
