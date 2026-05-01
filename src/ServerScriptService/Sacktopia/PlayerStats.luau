--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

export type Stats = {
	wins: number,
	top3: number,
	points: number,
	matchesPlayed: number,
	tierId: string,
	coins: number,
}

local PlayerStats = {}

local function fire(player: Player)
	local save = PlayerData.get(player)
	if not save then
		return
	end
	Remotes.StatsUpdated:FireClient(player, {
		wins = save.wins,
		top3 = save.top3,
		points = save.points,
		matchesPlayed = save.matchesPlayed,
		tierId = save.tierId,
		coins = save.coins,
	})
end

function PlayerStats.get(player: Player): Stats?
	local save = PlayerData.get(player)
	if not save then
		return nil
	end
	return {
		wins = save.wins,
		top3 = save.top3,
		points = save.points,
		matchesPlayed = save.matchesPlayed,
		tierId = save.tierId,
		coins = save.coins,
	}
end

local function coinsForPlacement(placement: number): number
	local c = Config.Coins[placement]
	if c then
		return c
	end
	return Config.Coins.Participation
end

function PlayerStats.recordMatch(player: Player, placement: number, totalPlayers: number)
	local save = PlayerData.get(player)
	if not save then
		return
	end
	local fromTier = save.tierId
	local pts = Ranks.pointsForPlacement(placement)
	local coins = coinsForPlacement(placement)
	save.matchesPlayed += 1
	save.points += pts
	save.coins += coins
	if placement == 1 then
		save.wins += 1
	end
	if placement <= 3 then
		save.top3 += 1
	end
	local newTier = Ranks.tierForPoints(save.points)
	save.tierId = newTier.id
	PlayerData.markDirty(player)
	fire(player)
	if newTier.id ~= fromTier and Ranks.tierIndex(newTier.id) > Ranks.tierIndex(fromTier) then
		Remotes.RankUp:FireClient(player, { fromTierId = fromTier, toTierId = newTier.id })
	end
	Remotes.MatchEnded:FireClient(player, {
		placement = placement,
		totalPlayers = totalPlayers,
		pointsEarned = pts,
		coinsEarned = coins,
		totalPoints = save.points,
		totalCoins = save.coins,
		fromTierId = fromTier,
		toTierId = save.tierId,
	})
end

function PlayerStats.start()
	-- Stats live in PlayerData; we just push the snapshot whenever a player loads in.
	PlayerData.onLoaded(function(player, _save)
		fire(player)
	end)
end

return PlayerStats
