--!strict
-- Simple per-player, per-key minimum-interval rate limiter.
-- Use: if not RateLimit.allow(player, "DeflectAttempt") then return end
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

local RateLimit = {}

local last: { [Player]: { [string]: number } } = {}

function RateLimit.allow(player: Player, key: string): boolean
	local interval = (Config.RateLimit :: any)[key] or 0.1
	local pTable = last[player]
	if not pTable then
		pTable = {}
		last[player] = pTable
	end
	local now = os.clock()
	local prev = pTable[key] or 0
	if now - prev < interval then
		return false
	end
	pTable[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(p: Player)
	last[p] = nil
end)

return RateLimit
