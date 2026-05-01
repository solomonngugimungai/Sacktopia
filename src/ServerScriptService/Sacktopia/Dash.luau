--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local Dash = {}

local lastDashAt: { [Player]: number } = {}

local function tryDash(player: Player, direction: Vector3)
	if typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.01 then
		return
	end
	local now = os.clock()
	local last = lastDashAt[player] or 0
	if now - last < Config.Dash.Cooldown then
		return
	end
	local char = player.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	-- horizontal direction + slight upward kick
	local horiz = Vector3.new(direction.X, 0, direction.Z)
	if horiz.Magnitude < 0.01 then
		return
	end
	local impulseDir = (horiz.Unit + Vector3.new(0, Config.Dash.UpwardComponent, 0)).Unit
	hrp:ApplyImpulse(impulseDir * Config.Dash.Impulse)
	lastDashAt[player] = now
	Remotes.DashAck:FireClient(player, Config.Dash.Cooldown)
end

function Dash.start()
	Remotes.DashRequest.OnServerEvent:Connect(tryDash)
	Players.PlayerRemoving:Connect(function(p: Player)
		lastDashAt[p] = nil
	end)
end

return Dash
