--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local LandingZone = {}

local indicator: BasePart? = nil
local innerRing: BasePart? = nil
local lastLanding: Vector3? = nil
local lastZoneRadius: number = 8
local lastUpdateTime: number = 0

-- create the visual once and re-use it. Cylinder primitive rotated to lie flat.
local function ensureIndicator()
	if indicator and indicator.Parent then
		return
	end
	local p = Instance.new("Part")
	p.Name = "SacktopiaLandingZone"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, 16, 16)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 80)
	p.Transparency = 0.45
	p.CFrame = CFrame.new() * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = Workspace
	indicator = p

	local inner = Instance.new("Part")
	inner.Name = "SacktopiaLandingZoneInner"
	inner.Shape = Enum.PartType.Cylinder
	inner.Size = Vector3.new(0.25, 4, 4)
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanQuery = false
	inner.CanTouch = false
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.fromRGB(255, 255, 255)
	inner.Transparency = 0.3
	inner.CFrame = CFrame.new() * CFrame.Angles(0, 0, math.rad(90))
	inner.Parent = Workspace
	innerRing = inner
end

local function hide()
	if indicator then
		indicator.Transparency = 1
	end
	if innerRing then
		innerRing.Transparency = 1
	end
	lastLanding = nil
end

local function characterPos(): Vector3?
	local char = player.Character
	if not char then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

-- recolor based on whether the local player is currently inside the zone
local function refreshColor()
	if not indicator or not innerRing or not lastLanding then
		return
	end
	local me = characterPos()
	local inZone = false
	if me then
		local d = Vector2.new(me.X - lastLanding.X, me.Z - lastLanding.Z).Magnitude
		inZone = d <= lastZoneRadius
	end
	if inZone then
		indicator.Color = Color3.fromRGB(80, 240, 120)
		innerRing.Color = Color3.fromRGB(180, 255, 200)
		indicator.Transparency = 0.25
	else
		indicator.Color = Color3.fromRGB(255, 220, 80)
		innerRing.Color = Color3.fromRGB(255, 255, 255)
		indicator.Transparency = 0.45
	end
end

function LandingZone.start()
	ensureIndicator()
	hide()

	Remotes.SackState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		lastUpdateTime = os.clock()
		local landing = payload.landing
		if typeof(landing) ~= "Vector3" then
			hide()
			return
		end
		lastLanding = landing
		lastZoneRadius = (typeof(payload.zoneRadius) == "number") and payload.zoneRadius or 8
		ensureIndicator()
		if indicator then
			indicator.Size = Vector3.new(0.2, lastZoneRadius * 2, lastZoneRadius * 2)
			indicator.CFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.rad(90))
		end
		if innerRing then
			innerRing.CFrame = CFrame.new(landing + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
		refreshColor()
	end)

	-- if no SackState arrives for a while (no active sack / between matches), hide
	RunService.Heartbeat:Connect(function()
		if lastLanding and os.clock() - lastUpdateTime > 0.5 then
			hide()
		else
			refreshColor()
		end
	end)
end

return LandingZone
