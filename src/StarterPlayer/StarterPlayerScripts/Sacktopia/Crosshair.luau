--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Crosshair = {}

local dot: Frame? = nil
local outerRing: Frame? = nil

local function build()
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SacktopiaCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	-- outer ring (target indicator)
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(20, 20)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.4
	stroke.Parent = ring
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring
	ring.Parent = gui

	-- center dot
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(4, 4)
	d.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	d.BackgroundTransparency = 0.2
	d.BorderSizePixel = 0
	local dCorner = Instance.new("UICorner")
	dCorner.CornerRadius = UDim.new(1, 0)
	dCorner.Parent = d
	d.Parent = gui

	dot = d
	outerRing = ring
end

local function isOverPlayer(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	if player.Character then
		rayParams.FilterDescendantsInstances = { player.Character }
	end
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	if not result then
		return false
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return false
	end
	local hitPlayer = Players:GetPlayerFromCharacter(model)
	return hitPlayer ~= nil and hitPlayer ~= player
end

function Crosshair.start()
	build()
	RunService.RenderStepped:Connect(function()
		if not dot or not outerRing then
			return
		end
		local target = isOverPlayer()
		local color = target and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
		dot.BackgroundColor3 = color
		local stroke = outerRing:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
		end
		-- outer ring grows slightly when over a target
		outerRing.Size = target and UDim2.fromOffset(28, 28) or UDim2.fromOffset(20, 20)
	end)
end

return Crosshair
