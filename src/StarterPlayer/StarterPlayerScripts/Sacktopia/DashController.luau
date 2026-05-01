--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local DashController = {}

local cooldownEndsAt = 0
local hudFill: Frame? = nil
local hudKey: TextLabel? = nil

local function buildHud()
	if hudFill then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaDashHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(1, 1)
	card.Position = UDim2.new(1, -16, 1, -100)
	card.Size = UDim2.fromOffset(60, 60)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.new(0.5, 0, 1, 0)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
	fill.BackgroundTransparency = 0.3
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = fill
	fill.Parent = card

	local key = Instance.new("TextLabel")
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.fromScale(0.5, 0.5)
	key.Size = UDim2.fromScale(1, 0.6)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBlack
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(255, 255, 255)
	key.TextStrokeTransparency = 0.4
	key.Text = "Q"
	key.Parent = card

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, 0, 0, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(180, 180, 180)
	label.Text = "DASH"
	label.Parent = card

	card.Parent = gui
	hudFill = fill
	hudKey = key
end

local function setReady(ready: boolean)
	if not hudFill or not hudKey then
		return
	end
	hudFill.BackgroundColor3 = ready and Color3.fromRGB(120, 80, 200) or Color3.fromRGB(60, 50, 80)
	hudKey.TextColor3 = ready and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 140)
end

local function dashDirection(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, -1)
	end
	-- prefer player's movement direction if they're moving, else camera lookVector
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0.1 then
		local md = hum.MoveDirection
		return Vector3.new(md.X, 0, md.Z).Unit
	end
	local lv = camera.CFrame.LookVector
	return Vector3.new(lv.X, 0, lv.Z).Unit
end

local function tryDash()
	if os.clock() < cooldownEndsAt then
		return
	end
	Remotes.DashRequest:FireServer(dashDirection())
end

function DashController.start()
	buildHud()
	setReady(true)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			tryDash()
		end
	end)

	Remotes.DashAck.OnClientEvent:Connect(function(cd: number)
		cooldownEndsAt = os.clock() + cd
		setReady(false)
		if hudFill then
			hudFill.Size = UDim2.fromScale(1, 1)
			TweenService:Create(hudFill, TweenInfo.new(cd, Enum.EasingStyle.Linear), {
				Size = UDim2.fromScale(1, 0),
			}):Play()
		end
		task.delay(cd, function()
			setReady(true)
		end)
	end)
end

return DashController
