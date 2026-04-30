--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Items"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local EquipController = {}

local ATTACH_FOLDER_NAME = "SacktopiaCosmetics"

local function getCosmeticFolder(character: Model): Folder
	local existing = character:FindFirstChild(ATTACH_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = ATTACH_FOLDER_NAME
	f.Parent = character
	return f
end

local function clearSlot(character: Model, slot: string)
	local folder = character:FindFirstChild(ATTACH_FOLDER_NAME)
	if not folder then
		return
	end
	local existing = folder:FindFirstChild(slot)
	if existing then
		existing:Destroy()
	end
end

local function buildPart(item: Items.Item): BasePart?
	local r = item.render
	if not r or not r.shape or r.shape == "None" then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = item.id
	if r.shape == "Cone" then
		p.Shape = Enum.PartType.Block -- no native cone; substitute
	elseif r.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	else
		p.Shape = Enum.PartType.Block
	end
	p.Size = r.size or Vector3.new(1, 1, 1)
	p.Color = r.color or Color3.fromRGB(255, 255, 255)
	p.Material = r.material or Enum.Material.Plastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	return p
end

local function attachToBone(character: Model, slot: string, item: Items.Item)
	clearSlot(character, slot)
	if item.id == "None" then
		return
	end
	local part = buildPart(item)
	if not part then
		return
	end
	local boneName: string
	if slot == "Head" then
		boneName = "Head"
	elseif slot == "Hand" then
		boneName = "RightHand"
	else
		return
	end
	local bone = character:FindFirstChild(boneName) :: BasePart?
	if not bone or not bone:IsA("BasePart") then
		-- R6 fallback for hand
		if slot == "Hand" then
			bone = character:FindFirstChild("Right Arm") :: BasePart?
		end
		if not bone then
			part:Destroy()
			return
		end
	end
	local offset = item.render.offsetCFrame or CFrame.new()
	part.CFrame = bone.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = bone
	weld.Part1 = part
	weld.C0 = offset
	weld.C1 = CFrame.new()
	weld.Parent = part
	local folder = getCosmeticFolder(character)
	-- name the part by slot so we can swap it cleanly later
	part.Name = slot
	part.Parent = folder
end

local function applyAllEquipped(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local loadout = Inventory.getLoadout(player)
	if not loadout then
		return
	end
	for slot, itemId in loadout do
		if slot == "SackSkin" then
			continue
		end
		local item = Items.getItem(itemId)
		if item then
			attachToBone(character, slot, item)
		end
	end
end

function EquipController.start()
	-- (re)apply on character spawn
	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			-- character bones aren't immediately ready; wait one frame
			task.wait(0.1)
			applyAllEquipped(player)
		end)
		if player.Character then
			applyAllEquipped(player)
		end
	end
	for _, p in Players:GetPlayers() do
		bind(p)
	end
	Players.PlayerAdded:Connect(bind)

	-- live re-apply on equip change
	Inventory.onEquip(function(player: Player, slot: string, itemId: string)
		if slot == "SackSkin" then
			return -- handled by SackController via Inventory.getEquipped
		end
		local character = player.Character
		if not character then
			return
		end
		local item = Items.getItem(itemId)
		if item then
			attachToBone(character, slot, item)
		end
	end)
end

return EquipController
