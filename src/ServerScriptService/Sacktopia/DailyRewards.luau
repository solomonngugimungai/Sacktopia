--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local DailyRewards = {}

local CLAIM_COOLDOWN_SECONDS = 22 * 3600 -- eligible 22h after last claim
local STREAK_RESET_SECONDS = 48 * 3600 -- streak resets if gap > 48h

local function streakDayFromSave(save: PlayerData.Save): number
	local now = os.time()
	local since = now - (save.lastDailyClaimAt or 0)
	if save.lastDailyClaimAt == 0 then
		return 1 -- never claimed before
	end
	if since > STREAK_RESET_SECONDS then
		return 1 -- missed too many days
	end
	-- progress to next day, wrapping at 7
	local next_ = (save.dailyStreak or 0) + 1
	if next_ > 7 then
		next_ = 1
	end
	return next_
end

local function isEligible(save: PlayerData.Save): boolean
	if save.lastDailyClaimAt == 0 then
		return true
	end
	return (os.time() - save.lastDailyClaimAt) >= CLAIM_COOLDOWN_SECONDS
end

local function offerToClient(player: Player, save: PlayerData.Save, requestedManually: boolean?)
	if isEligible(save) then
		local day = streakDayFromSave(save)
		local reward = Config.DailyRewards[day]
		if not reward then
			return
		end
		Remotes.DailyRewardOffer:FireClient(player, {
			available = true,
			day = day,
			coins = reward.coins,
			item = reward.item,
			skin = reward.skin,
		})
	elseif requestedManually then
		-- player clicked the DAILY button but it's not ready yet — show a countdown
		Remotes.DailyRewardOffer:FireClient(player, {
			available = false,
			nextAvailableAt = save.lastDailyClaimAt + CLAIM_COOLDOWN_SECONDS,
			currentStreak = save.dailyStreak,
		})
	end
end

local function claim(player: Player)
	local save = PlayerData.get(player)
	if not save then
		return
	end
	if not isEligible(save) then
		return
	end
	local day = streakDayFromSave(save)
	local reward = Config.DailyRewards[day]
	if not reward then
		return
	end
	save.coins += reward.coins
	if reward.item then
		local item = Items.getItem(reward.item)
		if item and not save.owned[reward.item] then
			save.owned[reward.item] = true
		end
	end
	if reward.skin then
		local skin = Items.getSkin(reward.skin)
		if skin and not save.ownedSkins[reward.skin] then
			save.ownedSkins[reward.skin] = true
		end
	end
	save.lastDailyClaimAt = os.time()
	save.dailyStreak = day
	PlayerData.markDirty(player)
	-- push refreshed stats + inventory snapshots so HUD updates immediately
	Remotes.StatsUpdated:FireClient(player, {
		wins = save.wins,
		top3 = save.top3,
		points = save.points,
		matchesPlayed = save.matchesPlayed,
		tierId = save.tierId,
		coins = save.coins,
	})
	Remotes.InventoryUpdated:FireClient(player, {
		owned = save.owned,
		ownedSkins = save.ownedSkins,
		loadout = save.loadout,
	})
end

function DailyRewards.start()
	PlayerData.onLoaded(function(player: Player, save: PlayerData.Save)
		-- offer the daily reward (if eligible) on a small delay so the client UI is ready
		task.delay(2, function()
			if not player.Parent then
				return
			end
			local fresh = PlayerData.get(player)
			if not fresh then
				return
			end
			-- tutorial first if it's their first time
			if not fresh.tutorialSeen then
				Remotes.TutorialShow:FireClient(player)
			end
			offerToClient(player, fresh)
		end)
	end)

	Remotes.DailyRewardClaim.OnServerEvent:Connect(function(player: Player)
		claim(player)
	end)

	Remotes.DailyRewardRequest.OnServerEvent:Connect(function(player: Player)
		local save = PlayerData.get(player)
		if not save then
			return
		end
		offerToClient(player, save, true)
	end)

	Remotes.TutorialAck.OnServerEvent:Connect(function(player: Player)
		local save = PlayerData.get(player)
		if not save then
			return
		end
		if not save.tutorialSeen then
			save.tutorialSeen = true
			PlayerData.markDirty(player)
		end
	end)
end

return DailyRewards
