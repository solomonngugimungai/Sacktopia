--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local RateLimit = require(script.Parent:WaitForChild("RateLimit"))

type Loadout = { [string]: string } -- slot -> itemId

local Inventory = {}

local listeners: { (player: Player, slot: string, itemId: string) -> () } = {}

local function fireSnapshot(player: Player)
	local save = PlayerData.get(player)
	if not save then
		return
	end
	Remotes.InventoryUpdated:FireClient(player, {
		owned = save.owned,
		ownedSkins = save.ownedSkins,
		loadout = save.loadout,
	})
end

function Inventory.getLoadout(player: Player): Loadout?
	local save = PlayerData.get(player)
	return save and save.loadout or nil
end

function Inventory.getEquipped(player: Player, slot: string): string?
	local save = PlayerData.get(player)
	return save and save.loadout[slot] or nil
end

function Inventory.equip(player: Player, slot: string, itemId: string): boolean
	local save = PlayerData.get(player)
	if not save then
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
		if not save.ownedSkins[itemId] or not Items.getSkin(itemId) then
			return false
		end
	else
		local item = Items.getItem(itemId)
		if not item or item.slot ~= slot then
			return false
		end
		if not save.owned[itemId] then
			return false
		end
	end
	save.loadout[slot] = itemId
	PlayerData.markDirty(player)
	fireSnapshot(player)
	for _, fn in listeners do
		fn(player, slot, itemId)
	end
	return true
end

function Inventory.onEquip(fn: (player: Player, slot: string, itemId: string) -> ())
	table.insert(listeners, fn)
end

local function applyLoadoutListeners(player: Player)
	local save = PlayerData.get(player)
	if not save then
		return
	end
	for _, slot in Config.Slots do
		local id = save.loadout[slot]
		if id then
			for _, fn in listeners do
				fn(player, slot, id)
			end
		end
	end
end

function Inventory.start()
	-- when a player's data finishes loading, push the snapshot + fire the listeners so
	-- EquipController etc. can apply cosmetics to the character
	PlayerData.onLoaded(function(player, _save)
		fireSnapshot(player)
		applyLoadoutListeners(player)
	end)

	Remotes.EquipItem.OnServerEvent:Connect(function(player: Player, slot, itemId)
		if not RateLimit.allow(player, "EquipItem") then
			return
		end
		if typeof(slot) ~= "string" or typeof(itemId) ~= "string" then
			return
		end
		Inventory.equip(player, slot, itemId)
	end)
end

return Inventory
