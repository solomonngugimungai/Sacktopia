--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local PlayerState = require(script.Parent.PlayerState)
local SackController = require(script.Parent:WaitForChild("SackController"))

type World = Worlds.World

local Practice = {}

type Stats = {
	deflects: number,
	drops: number,
	currentCombo: number,
	maxCombo: number,
}

type Session = {
	player: Player,
	world: World,
	sack: any, -- SackController instance
	stats: Stats,
}

local sessions: { [Player]: Session } = {}

local function fireStats(session: Session, sessionActive: boolean)
	Remotes.PracticeStats:FireClient(session.player, {
		deflects = session.stats.deflects,
		drops = session.stats.drops,
		currentCombo = session.stats.currentCombo,
		maxCombo = session.stats.maxCombo,
		sessionActive = sessionActive,
	})
end

function Practice.isInSession(player: Player): boolean
	return sessions[player] ~= nil
end

function Practice.startSession(player: Player, world: World)
	print(string.format("[Sacktopia] startSession requested by %s, world.id=%s, isPractice=%s",
		player.Name, world.id, tostring(world.isPractice)))
	if not world.isPractice then
		print("[Sacktopia] startSession rejected: world is not Practice")
		return
	end
	if sessions[player] then
		print("[Sacktopia] startSession rejected: already in a session")
		return -- already in a session
	end

	-- Build everything inside a pcall so a constructor error doesn't leave a ghost
	-- session entry that locks out future attempts.
	PlayerState.setAlive(player, true)
	local session: Session = {
		player = player,
		world = world,
		sack = nil,
		stats = { deflects = 0, drops = 0, currentCombo = 0, maxCombo = 0 },
	}
	local builtSack
	local ok, err = pcall(function()
		builtSack = SackController.new(world, { player })
		builtSack:setPracticeMode(true)
		builtSack:setOnDeflect(function(_p: Player, combo: number)
			session.stats.deflects += 1
			session.stats.currentCombo = combo
			if combo > session.stats.maxCombo then
				session.stats.maxCombo = combo
			end
			fireStats(session, true)
		end)
		builtSack:setOnDrop(function(_p: Player?, _reason: string)
			session.stats.drops += 1
			session.stats.currentCombo = 0
			fireStats(session, true)
		end)
		builtSack:start()
	end)
	if not ok then
		warn("[Sacktopia] startSession FAILED: " .. tostring(err))
		PlayerState.setAlive(player, false)
		if builtSack and builtSack.destroy then
			pcall(function() builtSack:destroy() end)
		end
		return
	end
	-- only register the session AFTER the sack is up — so failures don't leave a stale entry
	session.sack = builtSack
	sessions[player] = session
	fireStats(session, true)
	print(string.format("[Sacktopia] startSession SUCCESS for %s", player.Name))
end

function Practice.endSession(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.sack then
		session.sack:destroy()
	end
	-- clear alive flag so they don't accidentally count as in any other match logic
	PlayerState.setAlive(player, false)
	sessions[player] = nil
	-- final stats snapshot, sessionActive=false
	Remotes.PracticeStats:FireClient(player, {
		deflects = session.stats.deflects,
		drops = session.stats.drops,
		currentCombo = 0,
		maxCombo = session.stats.maxCombo,
		sessionActive = false,
	})
end

function Practice.handleDeflect(player: Player, aimDirection: Vector3, clientTime: number, targetUserId: number?): boolean
	local session = sessions[player]
	if not session or not session.sack then
		return false
	end
	return session.sack:onDeflectAttempt(player, aimDirection, clientTime, targetUserId)
end

function Practice.start()
	Players.PlayerRemoving:Connect(function(p: Player)
		Practice.endSession(p)
	end)
end

return Practice
