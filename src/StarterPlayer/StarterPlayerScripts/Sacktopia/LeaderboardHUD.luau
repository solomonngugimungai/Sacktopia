--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local LeaderboardHUD = {}

local panel: Frame? = nil
local rows: { Frame } = {}

local function tierColor(tierId: string): Color3
	for _, t in Config.Rank.Tiers do
		if t.id == tierId then
			return t.color
		end
	end
	return Color3.fromRGB(180, 180, 180)
end

local function build()
	if panel then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaLeaderboard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 16, 0.5, 0)
	card.Size = UDim2.fromOffset(220, 230)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	card.BackgroundTransparency = 0.3
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(245, 200, 80)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "TOP PLAYERS"
	title.Parent = card

	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(0, 28)
	list.Size = UDim2.new(1, 0, 1, -28)
	list.BackgroundTransparency = 1
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i = 1, 5 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Visible = false
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row
		row.Parent = list

		local rank = Instance.new("TextLabel")
		rank.Position = UDim2.fromOffset(6, 0)
		rank.Size = UDim2.fromOffset(20, 30)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.GothamBlack
		rank.TextScaled = true
		rank.TextColor3 = Color3.fromRGB(180, 180, 180)
		rank.Text = tostring(i)
		rank.Name = "Rank"
		rank.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(28, 2)
		name.Size = UDim2.new(1, -100, 0, 16)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.Name = "PlayerName"
		name.Parent = row

		local tier = Instance.new("TextLabel")
		tier.Position = UDim2.fromOffset(28, 16)
		tier.Size = UDim2.new(1, -100, 0, 12)
		tier.BackgroundTransparency = 1
		tier.Font = Enum.Font.Gotham
		tier.TextScaled = true
		tier.TextXAlignment = Enum.TextXAlignment.Left
		tier.TextColor3 = Color3.fromRGB(160, 160, 160)
		tier.Name = "Tier"
		tier.Parent = row

		local pts = Instance.new("TextLabel")
		pts.AnchorPoint = Vector2.new(1, 0.5)
		pts.Position = UDim2.new(1, -6, 0.5, 0)
		pts.Size = UDim2.fromOffset(60, 22)
		pts.BackgroundTransparency = 1
		pts.Font = Enum.Font.GothamBold
		pts.TextScaled = true
		pts.TextXAlignment = Enum.TextXAlignment.Right
		pts.TextColor3 = Color3.fromRGB(245, 200, 80)
		pts.Name = "Points"
		pts.Parent = row

		table.insert(rows, row)
	end
	panel = card
end

function LeaderboardHUD.start()
	build()
	Remotes.LeaderboardSnapshot.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then
			return
		end
		for i, row in rows do
			local entry = payload.entries[i]
			if entry then
				row.Visible = true
				local nameLabel = row:FindFirstChild("PlayerName") :: TextLabel?
				local tierLabel = row:FindFirstChild("Tier") :: TextLabel?
				local pointsLabel = row:FindFirstChild("Points") :: TextLabel?
				if nameLabel then
					nameLabel.Text = entry.displayName
				end
				if tierLabel then
					tierLabel.Text = entry.tierId .. " • " .. tostring(entry.wins) .. "W"
					tierLabel.TextColor3 = tierColor(entry.tierId)
				end
				if pointsLabel then
					pointsLabel.Text = tostring(entry.points)
				end
			else
				row.Visible = false
			end
		end
	end)
end

return LeaderboardHUD
