--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

export type Tier = {
	id: string,
	name: string,
	minPoints: number,
	color: Color3,
}

local Ranks = {}

function Ranks.tierForPoints(points: number): Tier
	local current = Config.Rank.Tiers[1]
	for _, tier in Config.Rank.Tiers do
		if points >= tier.minPoints then
			current = tier
		else
			break
		end
	end
	return current
end

function Ranks.nextTier(points: number): Tier?
	for _, tier in Config.Rank.Tiers do
		if tier.minPoints > points then
			return tier
		end
	end
	return nil
end

-- 0..1 progress to next tier; 1 if already at top
function Ranks.progress(points: number): number
	local current = Ranks.tierForPoints(points)
	local nxt = Ranks.nextTier(points)
	if not nxt then
		return 1
	end
	local span = nxt.minPoints - current.minPoints
	if span <= 0 then
		return 1
	end
	local within = points - current.minPoints
	return math.clamp(within / span, 0, 1)
end

function Ranks.tiersAtOrBelow(tierId: string): { Tier }
	local out = {}
	for _, tier in Config.Rank.Tiers do
		table.insert(out, tier)
		if tier.id == tierId then
			break
		end
	end
	return out
end

function Ranks.tierIndex(tierId: string): number
	for i, tier in Config.Rank.Tiers do
		if tier.id == tierId then
			return i
		end
	end
	return 0
end

function Ranks.pointsForPlacement(placement: number): number
	local p = Config.Rank.Points[placement]
	if p then
		return p
	end
	return Config.Rank.Points.Participation
end

return Ranks
