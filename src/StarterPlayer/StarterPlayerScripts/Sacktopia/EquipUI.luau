--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local EquipUI = {}

type Inventory = {
	owned: { [string]: boolean },
	ownedSkins: { [string]: boolean },
	loadout: { [string]: string },
}

local current: Inventory? = nil
local labels: { [string]: TextLabel } = {}

local function ownedIdsForSlot(inv: Inventory, slot: string): { string }
	local out = {}
	if slot == "SackSkin" then
		for id in inv.ownedSkins do
			table.insert(out, id)
		end
	else
		for id, ownedFlag in inv.owned do
			local item = Items.getItem(id)
			if ownedFlag and item and item.slot == slot then
				table.insert(out, id)
			end
		end
	end
	table.sort(out)
	return out
end

local function displayName(slot: string, id: string): string
	if slot == "SackSkin" then
		local s = Items.getSkin(id)
		return s and s.name or id
	else
		local i = Items.getItem(id)
		return i and i.name or id
	end
end

local function cycle(slot: string, dir: number)
	if not current then
		return
	end
	local list = ownedIdsForSlot(current, slot)
	if #list == 0 then
		return
	end
	local equippedId = current.loadout[slot]
	local idx = 1
	for i, id in list do
		if id == equippedId then
			idx = i
			break
		end
	end
	idx = ((idx - 1 + dir) % #list) + 1
	local newId = list[idx]
	Remotes.EquipItem:FireServer(slot, newId)
end

local function build()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaEquip"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -16)
	container.Size = UDim2.fromOffset(560, 70)
	container.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	container.BackgroundTransparency = 0.4
	container.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = container
	container.Parent = gui

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 14)
	list.Parent = container

	for _, slot in Config.Slots do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(170, 60)
		cell.BackgroundTransparency = 1
		cell.Parent = container

		local title = Instance.new("TextLabel")
		title.Position = UDim2.fromOffset(0, 0)
		title.Size = UDim2.new(1, 0, 0, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.Gotham
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(180, 180, 180)
		title.Text = slot
		title.Parent = cell

		local left = Instance.new("TextButton")
		left.Position = UDim2.fromOffset(0, 22)
		left.Size = UDim2.fromOffset(28, 32)
		left.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		left.TextColor3 = Color3.fromRGB(255, 255, 255)
		left.Font = Enum.Font.GothamBold
		left.TextScaled = true
		left.Text = "<"
		left.AutoButtonColor = true
		local lc = Instance.new("UICorner")
		lc.CornerRadius = UDim.new(0, 6)
		lc.Parent = left
		left.Parent = cell
		left.MouseButton1Click:Connect(function()
			cycle(slot, -1)
		end)

		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromOffset(32, 22)
		label.Size = UDim2.fromOffset(106, 32)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = "—"
		label.Parent = cell

		local right = Instance.new("TextButton")
		right.Position = UDim2.fromOffset(142, 22)
		right.Size = UDim2.fromOffset(28, 32)
		right.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		right.TextColor3 = Color3.fromRGB(255, 255, 255)
		right.Font = Enum.Font.GothamBold
		right.TextScaled = true
		right.Text = ">"
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 6)
		rc.Parent = right
		right.Parent = cell
		right.MouseButton1Click:Connect(function()
			cycle(slot, 1)
		end)

		labels[slot] = label
	end
end

local function refresh()
	if not current then
		return
	end
	for slot, lbl in labels do
		local id = current.loadout[slot]
		lbl.Text = id and displayName(slot, id) or "—"
	end
end

function EquipUI.start()
	build()
	Remotes.InventoryUpdated.OnClientEvent:Connect(function(payload)
		current = payload :: Inventory
		refresh()
	end)
end

return EquipUI
