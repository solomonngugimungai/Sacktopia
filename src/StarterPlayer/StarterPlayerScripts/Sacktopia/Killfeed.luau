--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local Killfeed = {}

local container: Frame? = nil
local entries: { Frame } = {}

local MAX_ENTRIES = 5
local LIFETIME = 5

local function ensureContainer()
	if container then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaKillfeed"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local c = Instance.new("Frame")
	c.AnchorPoint = Vector2.new(1, 0)
	c.Position = UDim2.new(1, -16, 0, 130)
	c.Size = UDim2.fromOffset(280, 200)
	c.BackgroundTransparency = 1
	c.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = c

	container = c
end

local function makeEntry(payload: {
	eliminator: number,
	eliminatorName: string?,
	victim: number,
	victimName: string,
	reason: string,
})
	if not container then
		return
	end
	-- evict oldest
	while #entries >= MAX_ENTRIES do
		local oldest = table.remove(entries, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(280, 30)
	row.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.LayoutOrder = os.clock() * 1000 -- newest at the bottom
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(8, 0)
	label.Size = UDim2.new(1, -16, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextStrokeTransparency = 0.3
	if payload.eliminatorName and payload.eliminatorName ~= "" then
		label.TextColor3 = Color3.fromRGB(255, 220, 220)
		label.Text = string.format("%s ⚡ %s", payload.eliminatorName, payload.victimName)
	else
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		label.Text = string.format("%s dropped", payload.victimName)
	end
	label.Parent = row

	row.Parent = container
	table.insert(entries, row)

	-- fade out and remove
	task.delay(LIFETIME, function()
		if not row.Parent then
			return
		end
		local fadeBg = TweenService:Create(row, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		local fadeText = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fadeBg:Play()
		fadeText:Play()
		fadeBg.Completed:Connect(function()
			if row.Parent then
				row:Destroy()
			end
			for i, r in entries do
				if r == row then
					table.remove(entries, i)
					break
				end
			end
		end)
	end)
end

function Killfeed.start()
	ensureContainer()
	Remotes.KillFeed.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		makeEntry(payload)
	end)
end

return Killfeed
