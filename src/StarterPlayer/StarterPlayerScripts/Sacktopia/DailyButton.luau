--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local DailyButton = {}

function DailyButton.start()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaDailyButton"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	-- floats just under the rank card on the top-left
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.Position = UDim2.new(0, 16, 0, 124)
	btn.Size = UDim2.fromOffset(160, 36)
	btn.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBlack
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(20, 18, 28)
	btn.Text = "DAILY 🎁"
	btn.AutoButtonColor = true
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = btn
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(60, 140, 180)
	stroke.Parent = btn
	btn.Parent = gui

	btn.MouseButton1Click:Connect(function()
		Remotes.DailyRewardRequest:FireServer()
	end)
end

return DailyButton
