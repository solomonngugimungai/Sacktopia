--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

type Loadout = { [string]: string } -- slot -> itemId
type PlayerData = {
	owned: { [string]: boolean }, -- itemId -> true
	ownedSkins: { [string]: boolean }, -- skinId -> true
	loadout: Loadout,
}

local Inventory = {}

local data: { [Player]: PlayerData } = {}
local listeners: { (player: Player, slot: string, itemId: string) -> () } = {}

local function snapshot(player: Player): PlayerData?
	return data[player]
end

local function fireSnapshot(player: Player)
	local d = data[player]
	if not d then
		return
	end
	Remotes.InventoryUpdated:FireClient(player, {
		owned = d.owned,
		ownedSkins = d.ownedSkins,
		loadout = d.loadout,
	})
end

function Inventory.add(player: Player)
	local owned: { [string]: boolean } = {}
	local ownedSkins: { [string]: boolean } = {}
	if Config.Equip.GrantAllOnJoin then
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
	local loadout: Loadout = {}
	for slot, defaultId in Config.Equip.DefaultLoadout do
		loadout[slot] = defaultId
	end
	data[player] = { owned = owned, ownedSkins = ownedSkins, loadout = loadout }
	fireSnapshot(player)
	for _, slot in Config.Slots do
		local id = loadout[slot]
		if id then
			for _, fn in listeners do
				fn(player, slot, id)
			end
		end
	end
end

function Inventory.remove(player: Player)
	data[player] = nil
end

function Inventory.getLoadout(player: Player): Loadout?
	local d = data[player]
	return d and d.loadout or nil
end

function Inventory.getEquipped(player: Player, slot: string): string?
	local d = data[player]
	return d and d.loadout[slot] or nil
end

function Inventory.equip(player: Player, slot: string, itemId: string): boolean
	local d = data[player]
	if not d then
		return false
	end
	-- validate slot
	local validSlot = false
	for _, s in Config.Slots do
		if s == slot then
			validSlot = true
			break
		end
	end
	if not validSlot then
		return false
	end
	-- validate ownership + slot match
	if slot == "SackSkin" then
		if not d.ownedSkins[itemId] then
			return false
		end
		if not Items.getSkin(itemId) then
			return false
		end
	else
		local item = Items.getItem(itemId)
		if not item or item.slot ~= slot then
			return false
		end
		if not d.owned[itemId] then
			return false
		end
	end
	d.loadout[slot] = itemId
	fireSnapshot(player)
	for _, fn in listeners do
		fn(player, slot, itemId)
	end
	return true
end

function Inventory.onEquip(fn: (player: Player, slot: string, itemId: string) -> ())
	table.insert(listeners, fn)
end

function Inventory.start()
	for _, p in Players:GetPlayers() do
		Inventory.add(p)
	end
	Players.PlayerAdded:Connect(Inventory.add)
	Players.PlayerRemoving:Connect(Inventory.remove)

	Remotes.EquipItem.OnServerEvent:Connect(function(player: Player, slot, itemId)
		if typeof(slot) ~= "string" or typeof(itemId) ~= "string" then
			return
		end
		Inventory.equip(player, slot, itemId)
	end)
end

return Inventory
