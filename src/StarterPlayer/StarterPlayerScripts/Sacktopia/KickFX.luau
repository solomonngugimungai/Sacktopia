--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))

local KickFX = {}

local function findRightUpperLegMotor(character: Model): Motor6D?
	-- R15 path
	local hip = character:FindFirstChild("RightUpperLeg")
	if hip and hip:IsA("BasePart") then
		local m = hip:FindFirstChild("RightHip")
		if m and m:IsA("Motor6D") then
			return m
		end
	end
	-- R6 fallback
	local torso = character:FindFirstChild("Torso")
	if torso then
		local m = torso:FindFirstChild("Right Hip")
		if m and m:IsA("Motor6D") then
			return m
		end
	end
	return nil
end

local function playKick(character: Model, direction: Vector3)
	local motor = findRightUpperLegMotor(character)
	if not motor then
		return
	end
	local baseC0 = motor.C0
	-- Swing the upper leg forward (around X, in joint local space). Direction is for future use
	-- (e.g. side-kick if direction is mostly lateral); v2 keeps it a forward kick.
	local _ = direction
	local outCFrame = baseC0 * CFrame.Angles(-Config.KickFX.SwingAngleRadians, 0, 0)
	local outTween = TweenService:Create(
		motor,
		TweenInfo.new(Config.KickFX.SwingOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = outCFrame }
	)
	local backTween = TweenService:Create(
		motor,
		TweenInfo.new(Config.KickFX.SwingBackSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = baseC0 }
	)
	outTween:Play()
	outTween.Completed:Connect(function()
		if motor.Parent then
			backTween:Play()
		end
	end)
end

function KickFX.start()
	local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
	Remotes.KickFX.OnClientEvent:Connect(function(player: Player, direction: Vector3)
		if not player or not player.Character then
			return
		end
		playKick(player.Character, direction)
	end)
end

return KickFX
