--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ranks = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

export type Stats = {
	wins: number,
	top3: number,
	points: number,
	matchesPlayed: number,
	tierId: string,
}

local PlayerStats = {}

local data: { [Player]: Stats } = {}

local function snapshot(player: Player): Stats?
	return data[player]
end

local function fire(player: Player)
	local s = data[player]
	if s then
		Remotes.StatsUpdated:FireClient(player, s)
	end
end

function PlayerStats.add(player: Player)
	local s: Stats = {
		wins = 0,
		top3 = 0,
		points = 0,
		matchesPlayed = 0,
		tierId = "Bronze",
	}
	data[player] = s
	fire(player)
end

function PlayerStats.remove(player: Player)
	data[player] = nil
end

function PlayerStats.get(player: Player): Stats?
	return data[player]
end

function PlayerStats.recordMatch(player: Player, placement: number, totalPlayers: number)
	local s = data[player]
	if not s then
		return
	end
	local fromTier = s.tierId
	local pts = Ranks.pointsForPlacement(placement)
	s.matchesPlayed += 1
	s.points += pts
	if placement == 1 then
		s.wins += 1
	end
	if placement <= 3 then
		s.top3 += 1
	end
	local newTier = Ranks.tierForPoints(s.points)
	s.tierId = newTier.id
	fire(player)
	if newTier.id ~= fromTier and Ranks.tierIndex(newTier.id) > Ranks.tierIndex(fromTier) then
		Remotes.RankUp:FireClient(player, { fromTierId = fromTier, toTierId = newTier.id })
	end
	-- match summary remote (lets client show placement card)
	Remotes.MatchEnded:FireClient(player, {
		placement = placement,
		totalPlayers = totalPlayers,
		pointsEarned = pts,
		totalPoints = s.points,
		fromTierId = fromTier,
		toTierId = s.tierId,
	})
end

function PlayerStats.start()
	for _, p in Players:GetPlayers() do
		PlayerStats.add(p)
	end
	Players.PlayerAdded:Connect(PlayerStats.add)
	Players.PlayerRemoving:Connect(PlayerStats.remove)
end

return PlayerStats
