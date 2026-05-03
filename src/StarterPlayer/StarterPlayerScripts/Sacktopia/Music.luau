--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local Music = {}

local current: Sound? = nil
local currentKey: string? = nil

local function makeTrack(assetId: string): Sound
	local s = Instance.new("Sound")
	s.Name = "SacktopiaMusic"
	s.SoundId = assetId
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end

local function fadeOut(track: Sound, dur: number)
	local t = TweenService:Create(track, TweenInfo.new(dur), { Volume = 0 })
	t:Play()
	t.Completed:Connect(function()
		track:Stop()
		track:Destroy()
	end)
end

local function fadeIn(track: Sound, dur: number, target: number)
	track.Volume = 0
	track:Play()
	TweenService:Create(track, TweenInfo.new(dur), { Volume = target }):Play()
end

-- swap to a different track. key = "Lobby" or "Match" (looks up Config.Music[key.."TrackId"])
local function play(key: string)
	if currentKey == key then
		return
	end
	currentKey = key
	local id = (Config.Music :: any)[key .. "TrackId"]
	if typeof(id) ~= "string" or id == "" then
		-- no track configured; just stop any current
		if current then
			fadeOut(current, Config.Music.FadeSeconds)
			current = nil
		end
		return
	end
	if current then
		fadeOut(current, Config.Music.FadeSeconds)
	end
	current = makeTrack(id)
	fadeIn(current, Config.Music.FadeSeconds, Config.Music.Volume)
end

-- decide which track based on whether the local player is in a match arena vs the lobby.
-- We approximate by checking the Y of the character — lobby is at y=1000, arenas at y=0.
local function pickTrackForLocation()
	local char = player.Character
	if not char then
		play("Lobby")
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if not root or not root:IsA("BasePart") then
		play("Lobby")
		return
	end
	if root.Position.Y > 500 then
		play("Lobby")
	else
		play("Match")
	end
end

function Music.start()
	-- start with whatever track is appropriate for spawn location
	task.spawn(function()
		while true do
			pickTrackForLocation()
			task.wait(2)
		end
	end)

	-- override on round start so the music switches sharply when a match begins
	Remotes.RoundState.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.phase == "playing" then
			play("Match")
		elseif payload.phase == "ended" then
			play("Lobby")
		end
	end)
end

return Music
