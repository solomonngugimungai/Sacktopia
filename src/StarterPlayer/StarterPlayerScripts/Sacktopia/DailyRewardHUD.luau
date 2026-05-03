--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Items = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local DailyRewardHUD = {}

local function rewardSummary(payload: { day: number, coins: number, item: string?, skin: string? }): string
	local lines = { string.format("🪙  %d coins", payload.coins) }
	if payload.item then
		local item = Items.getItem(payload.item)
		table.insert(lines, "🎁  " .. (item and item.name or payload.item) .. " unlocked")
	end
	if payload.skin then
		local skin = Items.getSkin(payload.skin)
		table.insert(lines, "✨  " .. (skin and skin.name or payload.skin) .. " skin unlocked")
	end
	return table.concat(lines, "\n")
end

local function show(payload: { day: number, coins: number, item: string?, skin: string? })
	local pg = player:WaitForChild("PlayerGui")
	-- defer if the tutorial is currently up — wait for it to close
	local tutorial = pg:FindFirstChild("SacktopiaTutorial")
	if tutorial then
		task.delay(1, function()
			show(payload)
		end)
		return
	end
	local prior = pg:FindFirstChild("SacktopiaDailyReward")
	if prior then
		prior:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaDailyReward"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.Parent = pg

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 320)
	card.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 220, 255)
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingLeft = UDim.new(0, 22)
	pad.PaddingRight = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 18)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(120, 220, 255)
	title.Text = "DAILY REWARD"
	title.Parent = card

	local day = Instance.new("TextLabel")
	day.Position = UDim2.fromOffset(0, 36)
	day.Size = UDim2.new(1, 0, 0, 22)
	day.BackgroundTransparency = 1
	day.Font = Enum.Font.GothamBold
	day.TextScaled = true
	day.TextColor3 = Color3.fromRGB(255, 255, 255)
	day.Text = string.format("Day %d of 7", payload.day)
	day.Parent = card

	local content = Instance.new("TextLabel")
	content.Position = UDim2.fromOffset(0, 80)
	content.Size = UDim2.new(1, 0, 0, 130)
	content.BackgroundTransparency = 1
	content.Font = Enum.Font.GothamBold
	content.TextScaled = true
	content.TextColor3 = Color3.fromRGB(245, 245, 245)
	content.TextStrokeTransparency = 0.4
	content.TextWrapped = true
	content.Text = rewardSummary(payload)
	content.Parent = card

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, 0)
	button.Size = UDim2.fromOffset(180, 48)
	button.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(20, 18, 28)
	button.Text = "CLAIM"
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = button
	button.Parent = card

	button.MouseButton1Click:Connect(function()
		Remotes.DailyRewardClaim:FireServer()
		button.Text = "CLAIMED ✓"
		button.BackgroundColor3 = Color3.fromRGB(80, 180, 100)
		task.delay(1, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end)

	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(
		card,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(420, 320) }
	):Play()
end

function DailyRewardHUD.start()
	Remotes.DailyRewardOffer.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		show(payload)
	end)
end

return DailyRewardHUD
