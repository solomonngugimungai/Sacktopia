--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local PlayerState = require(script.Parent.PlayerState)
local PlayerStats = require(script.Parent:WaitForChild("PlayerStats"))
local SackController = require(script.Parent:WaitForChild("SackController"))

type World = Worlds.World

local MatchController = {}
MatchController.__index = MatchController

function MatchController.new(world: World, roster: { Player })
	local self = setmetatable({}, MatchController)
	self.world = world
	self.roster = table.clone(roster)
	self.sack = nil
	self.knockoutOrder = {} :: { Player } -- order of elimination (first out → last out)
	self.alive = true
	self.startedAt = 0
	self.onEndedCallback = nil :: ((survivors: { Player }) -> ())?
	return self
end

local function pickArenaSpawnCFrame(world: World, i: number, total: number): CFrame
	local angle = (i - 1) / math.max(total, 1) * math.pi * 2
	local radius = world.spawnRadius
	local pos = world.center + Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
	local lookAt = world.center + Vector3.new(0, 5, 0)
	return CFrame.lookAt(pos, lookAt)
end

local function broadcast(world: World, payload: { [string]: any })
	payload.worldId = world.id
	Remotes.RoundState:FireAllClients(payload)
end

function MatchController:_teleportRosterToArena()
	for i, player in self.roster do
		if not player.Character then
			player:LoadCharacter()
			player.CharacterAdded:Wait()
		end
		local cf = pickArenaSpawnCFrame(self.world, i, #self.roster)
		local char = player.Character
		if char then
			task.wait(0)
			char:PivotTo(cf)
		end
		PlayerState.setAlive(player, true)
	end
end

function MatchController:_recordKnockout(player: Player)
	-- ensure no duplicates
	for _, p in self.knockoutOrder do
		if p == player then
			return
		end
	end
	table.insert(self.knockoutOrder, player)
end

function MatchController:_alivePlayers(): { Player }
	local out = {}
	for _, p in self.roster do
		if PlayerState.isAlive(p) and p.Parent then
			table.insert(out, p)
		end
	end
	return out
end

function MatchController:_buildPlacements(): { Player } -- index = placement (1 = winner)
	local placements: { Player } = {}
	-- last alive (or empty if everyone died) takes 1st
	local survivors = self:_alivePlayers()
	for _, p in survivors do
		table.insert(placements, p)
	end
	-- knockoutOrder is first-out → last-out; reverse for "best loser first"
	for i = #self.knockoutOrder, 1, -1 do
		local p = self.knockoutOrder[i]
		-- avoid duplicates if a survivor was somehow also recorded
		local alreadyIn = false
		for _, q in placements do
			if q == p then
				alreadyIn = true
				break
			end
		end
		if not alreadyIn then
			table.insert(placements, p)
		end
	end
	return placements
end

function MatchController:_endMatch(reason: string)
	if not self.alive then
		return
	end
	self.alive = false
	if self.sack then
		self.sack:destroy()
		self.sack = nil
	end
	local placements = self:_buildPlacements()
	local total = #self.roster
	for placement, player in placements do
		PlayerStats.recordMatch(player, placement, total)
	end
	broadcast(self.world, {
		phase = "ended",
		message = (placements[1] and (placements[1].DisplayName .. " wins " .. self.world.name .. "!"))
			or ("Match ended (" .. reason .. ")"),
	})
	if self.onEndedCallback then
		self.onEndedCallback(placements)
	end
end

function MatchController:onEnded(fn: (placements: { Player }) -> ())
	self.onEndedCallback = fn
end

function MatchController:_watchAlive()
	while self.alive do
		task.wait(0.5)
		local alive = self:_alivePlayers()
		if #alive <= 1 then
			self:_endMatch("last standing")
			return
		end
	end
end

function MatchController:start()
	self.startedAt = os.clock()
	-- reset roster alive state
	for _, p in self.roster do
		PlayerState.setAlive(p, false)
	end
	self:_teleportRosterToArena()
	task.wait(0.75) -- character settle
	for _, p in self.roster do
		PlayerState.setAlive(p, true)
	end
	broadcast(self.world, { phase = "playing" })
	self.sack = SackController.new(self.world, self.roster)
	self.sack:setOnPlayerHit(function(p: Player)
		self:_recordKnockout(p)
	end)
	self.sack:start()
	task.spawn(function()
		self:_watchAlive()
	end)
	-- safety timeout
	task.spawn(function()
		while self.alive do
			task.wait(1)
			if os.clock() - self.startedAt > Config.Round.MaxRoundSeconds then
				self:_endMatch("timeout")
				break
			end
		end
	end)
end

function MatchController:isPlayerInMatch(p: Player): boolean
	if not self.alive then
		return false
	end
	for _, q in self.roster do
		if q == p then
			return true
		end
	end
	return false
end

function MatchController:handlePlayerLeaving(p: Player)
	if not self:isPlayerInMatch(p) then
		return
	end
	-- treat as a knockout in current order
	PlayerState.markOut(p)
	self:_recordKnockout(p)
end

return MatchController
