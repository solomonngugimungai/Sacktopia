--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))
local SackHUD = require(script:WaitForChild("SackHUD"))
local KickFX = require(script:WaitForChild("KickFX"))
local EquipUI = require(script:WaitForChild("EquipUI"))
local LobbyHUD = require(script:WaitForChild("LobbyHUD"))
local MatchSummary = require(script:WaitForChild("MatchSummary"))
local DropAlerts = require(script:WaitForChild("DropAlerts"))
local PracticeHUD = require(script:WaitForChild("PracticeHUD"))

local player = Players.LocalPlayer
local windowOpen = false

local function aimDirection(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 1, 0)
	end
	return camera.CFrame.LookVector
end

-- Cursor-aim raycast: if the cursor is over another player's character, return their UserId
-- so the server aims the sack directly at them. Falls back to 0 (= use camera direction).
local function cursorTargetUserId(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
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
		return 0
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return 0
	end
	local hitPlayer = Players:GetPlayerFromCharacter(model)
	if not hitPlayer or hitPlayer == player then
		return 0
	end
	return hitPlayer.UserId
end

local function tryDeflect(source: string)
	print(string.format("[Sacktopia] %s pressed (windowOpen=%s)", source, tostring(windowOpen)))
	if not windowOpen then
		return
	end
	Remotes.DeflectAttempt:FireServer(aimDirection(), workspace:GetServerTimeNow(), cursorTargetUserId())
end

-- Listen to *all* keyboard input — don't gate on `processed` because Roblox's default
-- jump action sometimes flags Space as game-processed even when the player isn't typing.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	-- skip only if the player is typing in chat / a focused TextBox
	if processed and input.KeyCode ~= Enum.KeyCode.Space then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		tryDeflect("SPACE")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryDeflect("M1")
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		tryDeflect("R2")
	end
end)

Remotes.WindowOpened.OnClientEvent:Connect(function(_sackId: number, predictedImpactAt: number)
	windowOpen = true
	SackHUD.openWindow(predictedImpactAt)
end)

Remotes.WindowClosed.OnClientEvent:Connect(function(_sackId: number, reason: string?)
	windowOpen = false
	SackHUD.closeWindow(reason)
end)

Remotes.RoundState.OnClientEvent:Connect(function(payload)
	SackHUD.setRoundState(payload)
end)

Remotes.SackState.OnClientEvent:Connect(function(payload)
	SackHUD.setSackState(payload)
end)

Remotes.Eliminated.OnClientEvent:Connect(function()
	windowOpen = false
	SackHUD.closeWindow("eliminated")
end)

SackHUD.start()
KickFX.start()
EquipUI.start()
LobbyHUD.start()
MatchSummary.start()
DropAlerts.start()
PracticeHUD.start()
print("[Sacktopia] client boot")
