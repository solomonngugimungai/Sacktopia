--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local SackHUD = {}

local screenGui: ScreenGui? = nil
local ringFrame: Frame? = nil
local ringFill: Frame? = nil
local stateLabel: TextLabel? = nil
local comboLabel: TextLabel? = nil
local aliveLabel: TextLabel? = nil

local windowOpenAt: number? = nil
local windowImpactAt: number? = nil

local function ensureUI()
	if screenGui then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local ring = Instance.new("Frame")
	ring.Name = "TimingRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(160, 160)
	ring.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ring.BackgroundTransparency = 0.6
	ring.BorderSizePixel = 0
	ring.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = ring
	ring.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0.5, 1)
	fill.Position = UDim2.fromScale(0.5, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 70)
	fill.BackgroundTransparency = 0.3
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = ring

	local kickHint = Instance.new("TextLabel")
	kickHint.AnchorPoint = Vector2.new(0.5, 0.5)
	kickHint.Position = UDim2.new(0.5, 0, 0.5, -10)
	kickHint.Size = UDim2.fromScale(0.9, 0.28)
	kickHint.BackgroundTransparency = 1
	kickHint.Text = "KICK!"
	kickHint.TextScaled = true
	kickHint.Font = Enum.Font.GothamBlack
	kickHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	kickHint.Parent = ring

	-- spacebar keycap hint inside the ring
	local key = Instance.new("Frame")
	key.AnchorPoint = Vector2.new(0.5, 0)
	key.Position = UDim2.new(0.5, 0, 0.55, 0)
	key.Size = UDim2.fromOffset(64, 24)
	key.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	key.BackgroundTransparency = 0.05
	key.BorderSizePixel = 0
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = key
	local keyStroke = Instance.new("UIStroke")
	keyStroke.Thickness = 2
	keyStroke.Color = Color3.fromRGB(0, 0, 0)
	keyStroke.Parent = key
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextScaled = true
	keyLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	keyLabel.Text = "SPACE"
	keyLabel.Parent = key
	key.Parent = ring

	local state = Instance.new("TextLabel")
	state.AnchorPoint = Vector2.new(0.5, 0)
	state.Position = UDim2.new(0.5, 0, 0, 16)
	state.Size = UDim2.fromOffset(420, 36)
	state.BackgroundTransparency = 1
	state.Font = Enum.Font.GothamBold
	state.TextScaled = true
	state.TextColor3 = Color3.fromRGB(255, 255, 255)
	state.TextStrokeTransparency = 0.3
	state.Text = "Sacktopia"
	state.Parent = gui

	local combo = Instance.new("TextLabel")
	combo.AnchorPoint = Vector2.new(0, 1)
	combo.Position = UDim2.new(0, 16, 1, -16)
	combo.Size = UDim2.fromOffset(220, 32)
	combo.BackgroundTransparency = 1
	combo.Font = Enum.Font.GothamBold
	combo.TextXAlignment = Enum.TextXAlignment.Left
	combo.TextScaled = true
	combo.TextColor3 = Color3.fromRGB(255, 220, 80)
	combo.TextStrokeTransparency = 0.3
	combo.Text = ""
	combo.Parent = gui

	local alive = Instance.new("TextLabel")
	alive.AnchorPoint = Vector2.new(1, 0)
	alive.Position = UDim2.new(1, -16, 0, 16)
	alive.Size = UDim2.fromOffset(180, 28)
	alive.BackgroundTransparency = 1
	alive.Font = Enum.Font.Gotham
	alive.TextXAlignment = Enum.TextXAlignment.Right
	alive.TextScaled = true
	alive.TextColor3 = Color3.fromRGB(255, 255, 255)
	alive.TextStrokeTransparency = 0.3
	alive.Text = ""
	alive.Parent = gui

	screenGui = gui
	ringFrame = ring
	ringFill = fill
	stateLabel = state
	comboLabel = combo
	aliveLabel = alive
end

function SackHUD.openWindow(predictedImpactAt: number)
	ensureUI()
	windowOpenAt = workspace:GetServerTimeNow()
	windowImpactAt = predictedImpactAt
	if ringFrame then
		ringFrame.Visible = true
	end
end

function SackHUD.closeWindow(_reason: string?)
	windowOpenAt = nil
	windowImpactAt = nil
	if ringFrame then
		ringFrame.Visible = false
	end
end

function SackHUD.setRoundState(payload: { phase: string, alive: { number }, message: string? })
	ensureUI()
	if stateLabel then
		stateLabel.Text = payload.message or payload.phase
	end
	if aliveLabel then
		aliveLabel.Text = "Alive: " .. tostring(#payload.alive)
	end
end

function SackHUD.setSackState(payload: { holder: number, combo: number, speed: number })
	ensureUI()
	if not comboLabel then
		return
	end
	if payload.holder == player.UserId and payload.combo > 0 then
		comboLabel.Text = string.format("Combo x%d", payload.combo)
	else
		comboLabel.Text = ""
	end
end

function SackHUD.start()
	ensureUI()
	RunService.RenderStepped:Connect(function()
		if not (windowOpenAt and windowImpactAt and ringFill) then
			return
		end
		local now = workspace:GetServerTimeNow()
		local total = math.max(windowImpactAt - windowOpenAt, 0.001)
		local elapsed = math.clamp(now - windowOpenAt, 0, total)
		local pct = 1 - (elapsed / total)
		ringFill.Size = UDim2.fromScale(1, pct)
	end)
end

return SackHUD
