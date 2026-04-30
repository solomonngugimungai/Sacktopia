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

local player = Players.LocalPlayer
local windowOpen = false

local function aimDirection(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 1, 0)
	end
	return camera.CFrame.LookVector
end

local function tryDeflect()
	if not windowOpen then
		return
	end
	Remotes.DeflectAttempt:FireServer(aimDirection(), workspace:GetServerTimeNow())
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2
		or input.KeyCode == Enum.KeyCode.Space
	then
		tryDeflect()
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
print("[Sacktopia] client boot")
