--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local Sounds = {}

local cache: { [string]: Sound } = {}

local function get(key: string): Sound
	local cached = cache[key]
	if cached then
		return cached
	end
	local id = (Config.Sounds :: any)[key]
	local s = Instance.new("Sound")
	s.Name = "SacktopiaSfx_" .. key
	s.SoundId = id or ""
	s.Volume = 0.6
	s.Parent = SoundService
	cache[key] = s
	return s
end

local function play(key: string, volume: number?)
	local s = get(key)
	s.Volume = volume or 0.6
	s.TimePosition = 0
	pcall(function()
		s:Play()
	end)
end

function Sounds.start()
	-- preload
	for key in Config.Sounds do
		get(key)
	end

	Remotes.WindowClosed.OnClientEvent:Connect(function(_id: number, reason: string?)
		if reason == "deflected" then
			play("Deflect", 0.7)
		end
	end)
	Remotes.DropAlert.OnClientEvent:Connect(function(payload)
		if payload and payload.userId == player.UserId then
			play("Drop", 0.8)
		else
			play("Drop", 0.3)
		end
	end)
	Remotes.Eliminated.OnClientEvent:Connect(function()
		play("Eliminated", 0.7)
	end)
	Remotes.MatchEnded.OnClientEvent:Connect(function(payload)
		if payload and payload.placement == 1 then
			play("Win", 0.8)
		end
	end)
end

return Sounds
