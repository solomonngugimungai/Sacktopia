--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))

local Leaderboard = {}

local TOP_N = 5
local BROADCAST_INTERVAL = 5

local function snapshot()
	local entries = {}
	for _, p in Players:GetPlayers() do
		local s = PlayerStats.get(p)
		if s then
			table.insert(entries, {
				userId = p.UserId,
				displayName = p.DisplayName,
				points = s.points,
				wins = s.wins,
				tierId = s.tierId,
			})
		end
	end
	table.sort(entries, function(a, b)
		if a.points == b.points then
			return a.wins > b.wins
		end
		return a.points > b.points
	end)
	-- truncate
	while #entries > TOP_N do
		table.remove(entries)
	end
	return entries
end

local function broadcast()
	Remotes.LeaderboardSnapshot:FireAllClients({ entries = snapshot() })
end

function Leaderboard.start()
	task.spawn(function()
		while true do
			broadcast()
			task.wait(BROADCAST_INTERVAL)
		end
	end)
end

return Leaderboard
