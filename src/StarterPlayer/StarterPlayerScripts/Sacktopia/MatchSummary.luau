--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ranks = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local MatchSummary = {}

local function placementText(placement: number): string
	if placement == 1 then
		return "1st"
	elseif placement == 2 then
		return "2nd"
	elseif placement == 3 then
		return "3rd"
	else
		return tostring(placement) .. "th"
	end
end

local function placementColor(placement: number): Color3
	if placement == 1 then
		return Color3.fromRGB(255, 215, 80)
	elseif placement == 2 then
		return Color3.fromRGB(220, 220, 220)
	elseif placement == 3 then
		return Color3.fromRGB(205, 130, 70)
	else
		return Color3.fromRGB(200, 200, 200)
	end
end

local function show(payload: {
	placement: number,
	totalPlayers: number,
	pointsEarned: number,
	totalPoints: number,
	fromTierId: string,
	toTierId: string,
})
	local pg = player:WaitForChild("PlayerGui")
	-- clean any prior
	local prior = pg:FindFirstChild("SacktopiaMatchSummary")
	if prior then
		prior:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaMatchSummary"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 220)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = placementColor(payload.placement)
	stroke.Parent = card

	local placement = Instance.new("TextLabel")
	placement.Position = UDim2.fromOffset(0, 16)
	placement.Size = UDim2.new(1, 0, 0, 60)
	placement.BackgroundTransparency = 1
	placement.Font = Enum.Font.GothamBlack
	placement.TextScaled = true
	placement.TextColor3 = placementColor(payload.placement)
	placement.Text = placementText(payload.placement) .. " of " .. tostring(payload.totalPlayers)
	placement.Parent = card

	local pts = Instance.new("TextLabel")
	pts.Position = UDim2.fromOffset(0, 86)
	pts.Size = UDim2.new(1, 0, 0, 32)
	pts.BackgroundTransparency = 1
	pts.Font = Enum.Font.GothamBold
	pts.TextScaled = true
	pts.TextColor3 = Color3.fromRGB(255, 255, 255)
	pts.Text = string.format("+%d pts • %d total", payload.pointsEarned, payload.totalPoints)
	pts.Parent = card

	local rank = Instance.new("TextLabel")
	rank.Position = UDim2.fromOffset(0, 124)
	rank.Size = UDim2.new(1, 0, 0, 22)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.Gotham
	rank.TextScaled = true
	rank.TextColor3 = Color3.fromRGB(200, 200, 200)
	if payload.fromTierId == payload.toTierId then
		local tier = Ranks.tierForPoints(payload.totalPoints)
		local nxt = Ranks.nextTier(payload.totalPoints)
		if nxt then
			rank.Text = string.format("%s • %d to %s", tier.name, nxt.minPoints - payload.totalPoints, nxt.name)
		else
			rank.Text = tier.name .. " (max)"
		end
	else
		rank.Text = string.format("RANK UP! %s → %s", payload.fromTierId, payload.toTierId)
		rank.TextColor3 = Color3.fromRGB(255, 215, 80)
	end
	rank.Parent = card

	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(0, 168)
	hint.Size = UDim2.new(1, 0, 0, 24)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(140, 140, 140)
	hint.Text = "Returning to lobby…"
	hint.Parent = card

	card.Parent = gui

	-- pop-in
	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(420, 220),
	}):Play()

	task.delay(4.5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

function MatchSummary.start()
	Remotes.MatchEnded.OnClientEvent:Connect(show)
end

return MatchSummary
