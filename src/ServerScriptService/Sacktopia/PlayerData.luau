--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))

local PlayerData = {}

export type Save = {
	version: number,
	wins: number,
	top3: number,
	points: number,
	matchesPlayed: number,
	tierId: string,
	coins: number,
	owned: { [string]: boolean },
	ownedSkins: { [string]: boolean },
	loadout: { [string]: string },
}

local SAVE_VERSION = 1
local STORE_NAME = "Sacktopia_PlayerData_v1"

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Sacktopia] DataStore unavailable: " .. tostring(result))
	end
end

local cache: { [Player]: Save } = {}
local dirty: { [Player]: boolean } = {}
local loadedSignal = Instance.new("BindableEvent") -- (player, save)

local function defaultSave(): Save
	local owned: { [string]: boolean } = {}
	local ownedSkins: { [string]: boolean } = {}
	if Config.Debug.GrantAllItems then
		for id in Items.Items do
			owned[id] = true
		end
		for id in Items.Skins do
			ownedSkins[id] = true
		end
	else
		for id, item in Items.Items do
			if item.rarity == "Starter" then
				owned[id] = true
			end
		end
		for id, skin in Items.Skins do
			if skin.rarity == "Starter" then
				ownedSkins[id] = true
			end
		end
	end
	local loadout: { [string]: string } = {}
	for slot, defaultId in Config.Equip.DefaultLoadout do
		loadout[slot] = defaultId
	end
	return {
		version = SAVE_VERSION,
		wins = 0,
		top3 = 0,
		points = 0,
		matchesPlayed = 0,
		tierId = "Bronze",
		coins = 0,
		owned = owned,
		ownedSkins = ownedSkins,
		loadout = loadout,
	}
end

-- Migrate older saves up to current version (just adds missing fields here).
local function migrate(raw: any): Save
	if typeof(raw) ~= "table" then
		return defaultSave()
	end
	local def = defaultSave()
	for k, v in def do
		if raw[k] == nil then
			raw[k] = v
		end
	end
	-- ensure starter items remain owned even after a migration
	for id, item in Items.Items do
		if item.rarity == "Starter" and raw.owned then
			raw.owned[id] = true
		end
	end
	for id, skin in Items.Skins do
		if skin.rarity == "Starter" and raw.ownedSkins then
			raw.ownedSkins[id] = true
		end
	end
	raw.version = SAVE_VERSION
	return raw
end

local function loadPlayer(player: Player): Save
	if not store then
		return defaultSave()
	end
	local key = "u_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		warn("[Sacktopia] load failed for " .. player.Name .. ": " .. tostring(result))
		return defaultSave()
	end
	if result == nil then
		return defaultSave()
	end
	return migrate(result)
end

local function savePlayer(player: Player)
	if not store then
		return
	end
	local data = cache[player]
	if not data then
		return
	end
	if not dirty[player] then
		return
	end
	dirty[player] = false
	local key = "u_" .. player.UserId
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	if not ok then
		warn("[Sacktopia] save failed for " .. player.Name .. ": " .. tostring(err))
		dirty[player] = true -- retry next cycle
	end
end

function PlayerData.get(player: Player): Save?
	return cache[player]
end

function PlayerData.markDirty(player: Player)
	if cache[player] then
		dirty[player] = true
	end
end

function PlayerData.onLoaded(fn: (player: Player, save: Save) -> ()): RBXScriptConnection
	return loadedSignal.Event:Connect(fn)
end

function PlayerData.start()
	local function onAdded(player: Player)
		local save = loadPlayer(player)
		cache[player] = save
		dirty[player] = false
		loadedSignal:Fire(player, save)
	end
	for _, p in Players:GetPlayers() do
		task.spawn(onAdded, p)
	end
	Players.PlayerAdded:Connect(onAdded)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = true -- force save on leave
		savePlayer(player)
		cache[player] = nil
		dirty[player] = nil
	end)

	-- periodic auto-save (DataStore writes are rate-limited; 5 min is conservative)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, p in Players:GetPlayers() do
				savePlayer(p)
			end
		end
	end)

	-- on shutdown, force-save everyone with a small grace period for DataStore to flush
	game:BindToClose(function()
		if RunService:IsStudio() then
			return -- skip the wait in Studio so test sessions close fast
		end
		for _, p in Players:GetPlayers() do
			dirty[p] = true
			savePlayer(p)
		end
		task.wait(2)
	end)
end

return PlayerData
