--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local StreakAlert = {}

local function show(payload: {
	playerName: string,
	streakName: string,
	count: number,
	color: Color3?,
})
	local pg = player:WaitForChild("PlayerGui")
	-- replace any active alert
	local prior = pg:FindFirstChild("SacktopiaStreakAlert")
	if prior then
		prior:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaStreakAlert"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = pg

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.4)
	container.Size = UDim2.fromOffset(640, 130)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local color = payload.color or Color3.fromRGB(255, 200, 80)

	local big = Instance.new("TextLabel")
	big.AnchorPoint = Vector2.new(0.5, 0)
	big.Position = UDim2.fromScale(0.5, 0)
	big.Size = UDim2.fromScale(1, 0.65)
	big.BackgroundTransparency = 1
	big.Font = Enum.Font.GothamBlack
	big.TextScaled = true
	big.TextColor3 = color
	big.TextStrokeTransparency = 0
	big.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	big.Text = payload.streakName
	big.Parent = container

	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 1)
	sub.Position = UDim2.new(0.5, 0, 1, 0)
	sub.Size = UDim2.fromScale(1, 0.32)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextStrokeTransparency = 0.3
	sub.Text = string.format("%s — %d in a row", payload.playerName, payload.count)
	sub.Parent = container

	-- pop in: scale from 0 to full
	container.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(
		container,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(640, 130) }
	):Play()

	task.delay(2.4, function()
		if not gui.Parent then
			return
		end
		local fadeBig = TweenService:Create(big, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 })
		local fadeSub = TweenService:Create(sub, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fadeBig:Play()
		fadeSub:Play()
		fadeSub.Completed:Connect(function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end)
end

function StreakAlert.start()
	Remotes.StreakAlert.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.streakName) ~= "string" then
			return
		end
		show(payload)
	end)
end

return StreakAlert
