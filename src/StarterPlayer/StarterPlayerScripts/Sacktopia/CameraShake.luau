--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))

local player = Players.LocalPlayer

local CameraShake = {}

local activeMag = 0
local activeUntil = 0
local conn: RBXScriptConnection? = nil

-- Apply a transient shake by offsetting Humanoid.CameraOffset (composes cleanly with the
-- default camera). Decays linearly to zero by the deadline.
function CameraShake.shake(intensity: number, duration: number)
	activeMag = math.max(activeMag, intensity)
	activeUntil = math.max(activeUntil, os.clock() + duration)
	if conn then
		return
	end
	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= activeUntil then
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.zero
				end
			end
			if conn then
				conn:Disconnect()
				conn = nil
			end
			activeMag = 0
			return
		end
		local remaining = activeUntil - now
		local mag = math.min(activeMag, activeMag * remaining * 6)
		local offset = Vector3.new(
			(math.random() - 0.5) * 2 * mag,
			(math.random() - 0.5) * 2 * mag,
			(math.random() - 0.5) * 2 * mag
		)
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.CameraOffset = offset
			end
		end
	end)
end

function CameraShake.start()
	-- shake on key gameplay events
	Remotes.WindowClosed.OnClientEvent:Connect(function(_id: number, reason: string?)
		if reason == "deflected" then
			CameraShake.shake(0.5, 0.18)
		end
	end)
	Remotes.Eliminated.OnClientEvent:Connect(function()
		CameraShake.shake(2.0, 0.4)
	end)
	Remotes.DropAlert.OnClientEvent:Connect(function(payload)
		if payload and payload.userId == player.UserId then
			CameraShake.shake(1.2, 0.3)
		end
	end)
end

return CameraShake
