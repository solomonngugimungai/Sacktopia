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
local LandingZone = require(script:WaitForChild("LandingZone"))
local DashController = require(script:WaitForChild("DashController"))
local Killfeed = require(script:WaitForChild("Killfeed"))
local Crosshair = require(script:WaitForChild("Crosshair"))
local CameraShake = require(script:WaitForChild("CameraShake"))
local StreakAlert = require(script:WaitForChild("StreakAlert"))
local LeaderboardHUD = require(script:WaitForChild("LeaderboardHUD"))
local Sounds = require(script:WaitForChild("Sounds"))
local Music = require(script:WaitForChild("Music"))
local TutorialHUD = require(script:WaitForChild("TutorialHUD"))
local DailyRewardHUD = require(script:WaitForChild("DailyRewardHUD"))

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

local function tryDeflect(_source: string)
	if not windowOpen then
		return
	end
	Remotes.DeflectAttempt:FireServer(aimDirection(), workspace:GetServerTimeNow(), cursorTargetUserId())
end

-- Three deflect inputs, all equally valid: SPACE, left-click, gamepad R2. We DON'T gate
-- on the `processed` flag for these because Roblox's default systems sometimes flag
-- Space (jump action) and MouseButton1 (camera control) as processed even when the
-- player isn't focused on a GUI / TextBox. The deflect itself is harmless when no
-- window is open (tryDeflect returns immediately), and GUI buttons still receive their
-- own click events alongside.
--
-- Kick animation is gated on `not processed` though — clicking the equip cycle button
-- shouldn't make your leg swing.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	local isDeflectInput = input.KeyCode == Enum.KeyCode.Space
		or input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2
	if not isDeflectInput then
		return
	end
	tryDeflect("input")
	if not processed and player.Character then
		KickFX.playLocalKick(player.Character)
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
LandingZone.start()
DashController.start()
Killfeed.start()
Crosshair.start()
CameraShake.start()
StreakAlert.start()
LeaderboardHUD.start()
Sounds.start()
Music.start()
TutorialHUD.start()
DailyRewardHUD.start()
print("[Sacktopia] client boot")
