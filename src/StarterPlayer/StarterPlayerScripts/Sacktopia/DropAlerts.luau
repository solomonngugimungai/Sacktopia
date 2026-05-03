--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local DropAlerts = {}

local screenGui: ScreenGui? = nil
local activeBanner: Frame? = nil

local function ensureGui(): ScreenGui
	if screenGui then
		return screenGui
	end
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaDropAlerts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50 -- on top of HUD ring
	gui.Parent = pg
	screenGui = gui
	return gui
end

local function show(payload: { userId: number, displayName: string, reason: string })
	local gui = ensureGui()
	-- replace any existing banner
	if activeBanner then
		activeBanner:Destroy()
		activeBanner = nil
	end

	local isSelf = payload.userId == player.UserId
	-- Both "ground" (sack landed) and "missed" (sack hit you) are dropped — Blade Ball
	-- terminology. Failing to deflect = drop, period.
	local verb = "DROPPED IT"
	local accent = isSelf and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 200, 80)

	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -80) -- start above viewport, slide down
	banner.Size = UDim2.fromOffset(520, 78)
	banner.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	banner.BackgroundTransparency = 0.1
	banner.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = accent
	stroke.Parent = banner

	local nameLabel = Instance.new("TextLabel")
	nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	nameLabel.Position = UDim2.fromScale(0.5, 0.32)
	nameLabel.Size = UDim2.fromScale(0.92, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = isSelf and Color3.fromRGB(255, 255, 255) or accent
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = isSelf and "YOU " .. verb or string.upper(payload.displayName) .. " " .. verb
	nameLabel.Parent = banner

	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 1)
	sub.Position = UDim2.new(0.5, 0, 1, -10)
	sub.Size = UDim2.fromScale(0.9, 0.32)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(180, 180, 180)
	sub.TextStrokeTransparency = 0.4
	sub.Text = "Failed to deflect"
	sub.Parent = banner

	banner.Parent = gui
	activeBanner = banner

	-- slide down + fade in
	local slideIn = TweenService:Create(
		banner,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 56) }
	)
	slideIn:Play()

	-- hold then fade out
	task.delay(1.6, function()
		if banner.Parent == nil then
			return
		end
		local fadeOut = TweenService:Create(
			banner,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -80), BackgroundTransparency = 1 }
		)
		local strokeFade = TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 })
		local nameFade = TweenService:Create(nameLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		local subFade = TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fadeOut:Play()
		strokeFade:Play()
		nameFade:Play()
		subFade:Play()
		fadeOut.Completed:Connect(function()
			if banner.Parent then
				banner:Destroy()
			end
			if activeBanner == banner then
				activeBanner = nil
			end
		end)
	end)
end

function DropAlerts.start()
	ensureGui()
	Remotes.DropAlert.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.displayName) ~= "string" then
			return
		end
		show(payload)
	end)
end

return DropAlerts
