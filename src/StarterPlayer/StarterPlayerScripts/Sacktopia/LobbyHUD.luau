--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Ranks = require(ReplicatedStorage.Sacktopia:WaitForChild("Ranks"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))

local player = Players.LocalPlayer

local LobbyHUD = {}

type Stats = {
	wins: number,
	top3: number,
	points: number,
	matchesPlayed: number,
	tierId: string,
}

local stats: Stats? = nil
local queueByWorld: { [string]: { count: number, secondsToStart: number?, matchInProgress: boolean } } = {}

local rankCard: Frame? = nil
local rankNameLabel: TextLabel? = nil
local rankPointsLabel: TextLabel? = nil
local rankProgressFill: Frame? = nil
local statsLabel: TextLabel? = nil
local worldsPanel: Frame? = nil
local worldRows: { [string]: { container: Frame, count: TextLabel, status: TextLabel, lock: TextLabel } } = {}

local function build()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaLobby"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	-- top-left rank card
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0, 0)
	card.Position = UDim2.fromOffset(16, 16)
	card.Size = UDim2.fromOffset(280, 96)
	card.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	card.BackgroundTransparency = 0.4
	card.BorderSizePixel = 0
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = card

	local rankName = Instance.new("TextLabel")
	rankName.Size = UDim2.new(1, 0, 0, 22)
	rankName.BackgroundTransparency = 1
	rankName.Font = Enum.Font.GothamBlack
	rankName.TextScaled = true
	rankName.TextXAlignment = Enum.TextXAlignment.Left
	rankName.TextColor3 = Color3.fromRGB(255, 255, 255)
	rankName.Text = "Bronze"
	rankName.Parent = card

	local rankPoints = Instance.new("TextLabel")
	rankPoints.Position = UDim2.new(0, 0, 0, 24)
	rankPoints.Size = UDim2.new(1, 0, 0, 16)
	rankPoints.BackgroundTransparency = 1
	rankPoints.Font = Enum.Font.Gotham
	rankPoints.TextScaled = true
	rankPoints.TextXAlignment = Enum.TextXAlignment.Left
	rankPoints.TextColor3 = Color3.fromRGB(180, 180, 180)
	rankPoints.Text = "0 pts"
	rankPoints.Parent = card

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0, 0, 0, 46)
	barBg.Size = UDim2.new(1, 0, 0, 8)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBg.BorderSizePixel = 0
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = barBg
	barBg.Parent = card

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill
	fill.Parent = barBg

	local statsTxt = Instance.new("TextLabel")
	statsTxt.Position = UDim2.new(0, 0, 0, 58)
	statsTxt.Size = UDim2.new(1, 0, 0, 16)
	statsTxt.BackgroundTransparency = 1
	statsTxt.Font = Enum.Font.Gotham
	statsTxt.TextScaled = true
	statsTxt.TextXAlignment = Enum.TextXAlignment.Left
	statsTxt.TextColor3 = Color3.fromRGB(220, 220, 220)
	statsTxt.Text = "0W • 0 top-3 • 0 played"
	statsTxt.Parent = card

	card.Parent = gui

	-- right-side worlds panel
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(280, 320)
	panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 10)
	pc.Parent = panel
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 10)
	panelPad.PaddingLeft = UDim.new(0, 10)
	panelPad.PaddingRight = UDim.new(0, 10)
	panelPad.PaddingBottom = UDim.new(0, 10)
	panelPad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "WORLDS"
	title.LayoutOrder = 0
	title.Parent = panel

	for i, world in Worlds.List do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(8, 4)
		name.Size = UDim2.new(0.6, -8, 0, 18)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = world.platformColor
		name.Text = world.name
		name.Parent = row

		local req = Instance.new("TextLabel")
		req.Position = UDim2.fromOffset(8, 22)
		req.Size = UDim2.new(0.6, -8, 0, 16)
		req.BackgroundTransparency = 1
		req.Font = Enum.Font.Gotham
		req.TextScaled = true
		req.TextXAlignment = Enum.TextXAlignment.Left
		req.TextColor3 = Color3.fromRGB(180, 180, 180)
		req.Text = world.requiredTier .. "+"
		req.Parent = row

		local count = Instance.new("TextLabel")
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -8, 0, 4)
		count.Size = UDim2.new(0.4, -8, 0, 18)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamBold
		count.TextScaled = true
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.TextColor3 = Color3.fromRGB(255, 255, 255)
		count.Text = "0 in queue"
		count.Parent = row

		local status = Instance.new("TextLabel")
		status.AnchorPoint = Vector2.new(1, 0)
		status.Position = UDim2.new(1, -8, 0, 22)
		status.Size = UDim2.new(0.4, -8, 0, 16)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.Gotham
		status.TextScaled = true
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.TextColor3 = Color3.fromRGB(180, 180, 180)
		status.Text = "—"
		status.Parent = row

		local lock = Instance.new("TextLabel")
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.fromScale(0.5, 0.5)
		lock.Size = UDim2.fromScale(1, 1)
		lock.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		lock.BackgroundTransparency = 0.55
		lock.Font = Enum.Font.GothamBlack
		lock.TextScaled = true
		lock.TextColor3 = Color3.fromRGB(220, 220, 220)
		lock.Text = "LOCKED"
		lock.Visible = false
		local lockCorner = Instance.new("UICorner")
		lockCorner.CornerRadius = UDim.new(0, 6)
		lockCorner.Parent = lock
		lock.Parent = row

		row.Parent = panel
		worldRows[world.id] = { container = row, count = count, status = status, lock = lock }
	end

	rankCard = card
	rankNameLabel = rankName
	rankPointsLabel = rankPoints
	rankProgressFill = fill
	statsLabel = statsTxt
	worldsPanel = panel
end

local function refreshRankCard()
	if not stats or not rankNameLabel or not rankPointsLabel or not rankProgressFill or not statsLabel then
		return
	end
	local tier = Ranks.tierForPoints(stats.points)
	rankNameLabel.Text = tier.name
	rankNameLabel.TextColor3 = tier.color
	local nxt = Ranks.nextTier(stats.points)
	if nxt then
		rankPointsLabel.Text = string.format("%d / %d → %s", stats.points, nxt.minPoints, nxt.name)
	else
		rankPointsLabel.Text = string.format("%d pts • MAX", stats.points)
	end
	rankProgressFill.Size = UDim2.fromScale(Ranks.progress(stats.points), 1)
	rankProgressFill.BackgroundColor3 = tier.color
	local coins = stats.coins or 0
	statsLabel.Text = string.format("%dW • %d top-3 • %d played • 🪙 %d", stats.wins, stats.top3, stats.matchesPlayed, coins)
end

local function refreshWorlds()
	for worldId, row in worldRows do
		local world = Worlds.byId(worldId)
		if not world then
			continue
		end
		local q = queueByWorld[worldId]
		if q then
			row.count.Text = string.format("%d in queue", q.count)
			if q.matchInProgress then
				row.status.Text = "match in progress"
			elseif q.secondsToStart then
				row.status.Text = string.format("starts in %ds", math.ceil(q.secondsToStart))
			else
				row.status.Text = (q.count > 0) and "waiting…" or "—"
			end
		end
		-- lock if player is below required tier
		if stats then
			local canEnter = Ranks.tierIndex(stats.tierId) >= Ranks.tierIndex(world.requiredTier)
			row.lock.Visible = not canEnter
		end
	end
end

function LobbyHUD.start()
	build()
	Remotes.StatsUpdated.OnClientEvent:Connect(function(payload)
		stats = payload
		refreshRankCard()
		refreshWorlds()
	end)
	Remotes.QueueState.OnClientEvent:Connect(function(payload)
		queueByWorld[payload.worldId] = {
			count = payload.count,
			secondsToStart = payload.secondsToStart,
			matchInProgress = payload.matchInProgress,
		}
		refreshWorlds()
	end)
	Remotes.RankUp.OnClientEvent:Connect(function(payload)
		-- simple flash; could be a fancier popup later
		if rankNameLabel then
			rankNameLabel.Text = string.format("RANK UP! %s → %s", payload.fromTierId, payload.toTierId)
		end
		task.delay(3, refreshRankCard)
	end)
end

return LobbyHUD
