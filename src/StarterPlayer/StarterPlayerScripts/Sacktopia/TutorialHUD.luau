--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local TutorialHUD = {}

local function show()
	local pg = player:WaitForChild("PlayerGui")
	-- replace any existing
	local prior = pg:FindFirstChild("SacktopiaTutorial")
	if prior then
		prior:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaTutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80
	gui.Parent = pg

	-- dim the rest of the screen
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(560, 460)
	card.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(245, 200, 80)
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 24)
	pad.PaddingLeft = UDim.new(0, 28)
	pad.PaddingRight = UDim.new(0, 28)
	pad.PaddingBottom = UDim.new(0, 20)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(245, 200, 80)
	title.TextStrokeTransparency = 0.4
	title.Text = Config.Tutorial.Title
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 48)
	sub.Size = UDim2.new(1, 0, 0, 22)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(180, 180, 180)
	sub.Text = "How to play"
	sub.Parent = card

	-- bullet lines
	local list = Instance.new("Frame")
	list.Position = UDim2.fromOffset(0, 84)
	list.Size = UDim2.new(1, 0, 1, -160)
	list.BackgroundTransparency = 1
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i, line in Config.Tutorial.Lines do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(245, 245, 245)
		row.LayoutOrder = i
		row.Text = line
		row.Parent = list
	end

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, 0)
	button.Size = UDim2.fromOffset(220, 50)
	button.BackgroundColor3 = Color3.fromRGB(245, 200, 80)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBlack
	button.TextScaled = true
	button.TextColor3 = Color3.fromRGB(20, 18, 28)
	button.Text = "GOT IT"
	button.AutoButtonColor = true
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = button
	button.Parent = card

	button.MouseButton1Click:Connect(function()
		Remotes.TutorialAck:FireServer()
		local fade = TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end)

	-- pop in
	card.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(
		card,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(560, 460) }
	):Play()
end

function TutorialHUD.start()
	Remotes.TutorialShow.OnClientEvent:Connect(show)
end

return TutorialHUD
