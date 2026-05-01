--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Worlds = require(ReplicatedStorage.Sacktopia:WaitForChild("Worlds"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local PlayerState = require(script.Parent.PlayerState)

type World = Worlds.World

type Vec3 = Vector3

local SackController = {}
SackController.__index = SackController

local nextSackId = 0

local function buildSackPart(): BasePart
	local p = Instance.new("Part")
	p.Name = "Sack"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(Config.Sack.Radius * 2, Config.Sack.Radius * 2, Config.Sack.Radius * 2)
	p.Material = Enum.Material.Fabric
	p.Color = Color3.fromRGB(220, 60, 70)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true -- server integrates manually so motion replicates cleanly
	p.CastShadow = true
	return p
end

local function attachHighlight(part: BasePart): Highlight
	local h = Instance.new("Highlight")
	h.Name = "SackOutline"
	h.Adornee = part
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = part
	return h
end

local function attachTrail(part: BasePart): Trail
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, Config.Sack.Radius * 0.4, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -Config.Sack.Radius * 0.4, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Name = "SackTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = Config.Trail.Lifetime
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Config.Trail.WidthScaleStart),
		NumberSequenceKeypoint.new(1, Config.Trail.WidthScaleEnd),
	})
	trail.Color = ColorSequence.new(Config.Trail.NeutralColor)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 0.4
	trail.Parent = part
	return trail
end

local function applySkin(part: BasePart, skin: Items.SackSkin)
	part.Color = skin.color
	part.Material = skin.material
	part.Transparency = skin.transparency
end

function SackController.new(arena: World, roster: { Player })
	local self = setmetatable({}, SackController)
	self.id = (function()
		nextSackId += 1
		return nextSackId
	end)()
	self.arena = arena
	self.roster = roster -- only these players are valid targets
	self.part = buildSackPart()
	self.trail = attachTrail(self.part)
	self.highlight = attachHighlight(self.part)
	self.position = arena.center + Vector3.new(0, arena.sackSpawnHeight, 0)
	self.velocity = Vector3.new(0, 0, 0)
	self.speed = Config.Sack.BaseSpeed
	self.lastDeflector = nil :: Player?
	self.consecutiveByLast = 0
	self.target = nil :: Player?
	self.windowOpenFor = nil :: Player?
	self.predictedImpactAt = 0
	self.alive = true
	self._heartbeatConn = nil :: RBXScriptConnection?
	self._lastSnapshot = 0
	self._cycleT = 0
	self._activeSkin = Items.getSkin("Classic") :: Items.SackSkin
	self._onPlayerHit = nil :: ((player: Player) -> ())?
	self._onDeflect = nil :: ((player: Player, combo: number) -> ())?
	self._onDrop = nil :: ((player: Player?, reason: string) -> ())?
	self._resetting = false -- true while sack is between plays (post-elimination respawn)
	self.practiceMode = false -- if true, _eliminate doesn't kill players
	self.landingZoneRadius = Config.Combat.LandingZoneRadius -- shrinks with combo in practice
	applySkin(self.part, self._activeSkin)
	self.part.Position = self.position
	self.part.Parent = Workspace
	return self
end

-- MatchController registers a callback so it can record placement order
function SackController:setOnPlayerHit(fn: (player: Player) -> ())
	self._onPlayerHit = fn
end

function SackController:setPracticeMode(v: boolean)
	self.practiceMode = v
end

function SackController:setOnDeflect(fn: (player: Player, combo: number) -> ())
	self._onDeflect = fn
end

function SackController:setOnDrop(fn: (player: Player?, reason: string) -> ())
	self._onDrop = fn
end

function SackController:_setHolderSkin(player: Player)
	local equipped = Inventory.getEquipped(player, "SackSkin")
	local skin = equipped and Items.getSkin(equipped) or Items.getSkin("Classic")
	if skin and skin ~= self._activeSkin then
		self._activeSkin = skin
		applySkin(self.part, skin)
	end
	-- recolor trail to skin color
	if self.trail then
		self.trail.Color = ColorSequence.new(self._activeSkin.color)
	end
end

function SackController:_tickSkinCycle(dt: number)
	local skin = self._activeSkin
	if not skin or not skin.cycleColors or not skin.cycleSpeed then
		return
	end
	self._cycleT += dt * skin.cycleSpeed
	local n = #skin.cycleColors
	local t = self._cycleT % n
	local i = math.floor(t) + 1
	local nextI = (i % n) + 1
	local frac = t - math.floor(t)
	local a = skin.cycleColors[i]
	local b = skin.cycleColors[nextI]
	self.part.Color = a:Lerp(b, frac)
end

function SackController:destroy()
	self.alive = false
	if self.windowOpenFor then
		Remotes.WindowClosed:FireClient(self.windowOpenFor, self.id, "matchend")
		self.windowOpenFor = nil
	end
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	if self.part then
		self.part:Destroy()
		self.part = nil :: any
	end
end

function SackController:_aliveRoster(): { Player }
	local out = {}
	for _, p in self.roster do
		if PlayerState.isAlive(p) and p.Character then
			table.insert(out, p)
		end
	end
	return out
end

function SackController:_pickInitialTarget()
	local candidates = self:_aliveRoster()
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

function SackController:start()
	-- Practice mode: spawn the sack directly above the practice player and just let it
	-- fall straight down — pure vertical from the start.
	if self.practiceMode and self.roster[1] then
		local p = self.roster[1]
		local root = characterRoot(p)
		if root then
			self.position = Vector3.new(root.Position.X, root.Position.Y + self.arena.sackSpawnHeight, root.Position.Z)
			self.part.Position = self.position
		end
		self.velocity = Vector3.new(0, 0, 0) -- gravity will start pulling it down
		self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			self:_step(dt)
		end)
		return
	end
	-- Seed: launch toward a random alive player from above center.
	local target = self:_pickInitialTarget()
	if target and target.Character and target.Character.PrimaryPart then
		local dir = (target.Character.PrimaryPart.Position - self.position).Unit
		self.velocity = (dir + Vector3.new(0, 0.4, 0)).Unit * self.speed
	else
		self.velocity = Vector3.new(0, -1, 0) * self.speed
	end

	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

local function characterRoot(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function SackController:_clampInBounds()
	local center = self.arena.center
	local horiz = Vector3.new(self.position.X - center.X, 0, self.position.Z - center.Z)
	local horizDist = horiz.Magnitude
	if horizDist > self.arena.boundsRadius then
		-- soft wrap: reflect velocity inward and clamp position to boundary
		local inward = -horiz.Unit
		local v = self.velocity
		local horizV = Vector3.new(v.X, 0, v.Z)
		local reflected = horizV - 2 * horizV:Dot(inward * -1) * (inward * -1)
		self.velocity = Vector3.new(reflected.X * 0.7, v.Y, reflected.Z * 0.7)
		self.position = center + inward * -1 * self.arena.boundsRadius + Vector3.new(0, self.position.Y - center.Y, 0)
	end
	-- (no floor bounce — ground-touch elimination is handled in _checkGroundTouch)
	if self.position.Y > center.Y + self.arena.boundsHeight then
		self.position = Vector3.new(self.position.X, center.Y + self.arena.boundsHeight, self.position.Z)
		self.velocity = Vector3.new(self.velocity.X, -math.abs(self.velocity.Y), self.velocity.Z)
	end
end

function SackController:_predictImpact(player: Player): number?
	if not PlayerState.isAlive(player) then
		return nil
	end
	local root = characterRoot(player)
	if not root then
		return nil
	end
	local rel = root.Position - self.position
	local v = self.velocity
	local speed = v.Magnitude
	if speed < 1 then
		return nil
	end
	-- approximate ETA along velocity direction (ignoring gravity for short horizons; gravity arc handled by step)
	local along = rel:Dot(v.Unit) / speed
	if along <= 0 then
		return nil
	end
	-- only consider as a real incoming threat if velocity broadly points at them
	local lateral = (rel - v.Unit * (rel:Dot(v.Unit))).Magnitude
	if lateral > 6 then
		return nil
	end
	return along
end

-- Predict where the sack will land on the arena floor under current velocity + gravity.
-- Returns Vector3 of the predicted landing point, or nil if the sack is moving up
-- forever (won't happen with positive gravity).
function SackController:_predictLanding(): Vector3?
	local center = self.arena.center
	local groundY = center.Y + Config.ArenaDefaults.PlatformThickness / 2 + Config.Sack.Radius
	local g = Config.Sack.Gravity
	local s = self.position
	local v = self.velocity
	-- Solve s.y + v.y*t - 0.5*g*t² = groundY for t > 0
	-- => 0.5*g*t² - v.y*t + (groundY - s.y) = 0
	-- discriminant: v.y² + 2*g*(s.y - groundY)
	local disc = v.Y * v.Y + 2 * g * (s.Y - groundY)
	if disc < 0 then
		return nil -- already past ground level somehow
	end
	local t = (v.Y + math.sqrt(disc)) / g
	if t <= 0 then
		return nil
	end
	local landX = s.X + v.X * t
	local landZ = s.Z + v.Z * t
	return Vector3.new(landX, groundY, landZ)
end

function SackController:_chooseTarget()
	-- Pick the alive player closest to where the sack will land, not closest to the sack.
	-- Players run TO the landing zone to claim the deflect.
	local landing = self:_predictLanding()
	local best: Player? = nil
	local bestDist = math.huge
	for _, p in self:_aliveRoster() do
		local root = characterRoot(p)
		if not root then
			continue
		end
		local d
		if landing then
			-- horizontal-only distance to landing point (ignore Y)
			d = Vector3.new(root.Position.X - landing.X, 0, root.Position.Z - landing.Z).Magnitude
		else
			d = (root.Position - self.position).Magnitude
		end
		if d < bestDist then
			best = p
			bestDist = d
		end
	end
	if best ~= self.target then
		if self.windowOpenFor then
			Remotes.WindowClosed:FireClient(self.windowOpenFor, self.id, "retargeted")
			self.windowOpenFor = nil
		end
		self.target = best
	end
end

function SackController:_maybeOpenWindow()
	local target = self.target
	if not target then
		return
	end
	local root = characterRoot(target)
	if not root then
		return
	end
	-- Window is open when the target is in the predicted landing zone.
	local landing = self:_predictLanding()
	local horizDist
	if landing then
		horizDist = Vector3.new(root.Position.X - landing.X, 0, root.Position.Z - landing.Z).Magnitude
	else
		horizDist = (root.Position - self.position).Magnitude
	end

	if horizDist > self.landingZoneRadius then
		if self.windowOpenFor == target then
			Remotes.WindowClosed:FireClient(target, self.id, "outofzone")
			self.windowOpenFor = nil
		end
		return
	end
	-- Sack already at ground / hitting target — let _checkHit handle it.
	if (root.Position - self.position).Magnitude <= Config.Sack.HitRadius then
		return
	end
	if self.windowOpenFor ~= target then
		self.windowOpenFor = target
		-- ETA so the timing-ring UI has something to drain
		local v = self.velocity.Magnitude
		local eta = (root.Position - self.position).Magnitude / math.max(v, 1)
		self.predictedImpactAt = workspace:GetServerTimeNow() + eta
		Remotes.WindowOpened:FireClient(target, self.id, self.predictedImpactAt)
		print(string.format("[Sacktopia] window OPEN for %s (zoneDist=%.1f, eta=%.2fs)", target.Name, horizDist, eta))
	end
end

-- shared eliminate-and-reset used by both direct sack hits and ground-touch falls
function SackController:_eliminate(player: Player?, reason: string)
	if self._resetting then
		return
	end
	self._resetting = true

	if self.windowOpenFor then
		Remotes.WindowClosed:FireClient(self.windowOpenFor, self.id, reason)
		self.windowOpenFor = nil
	end

	if player then
		if self.practiceMode then
			-- practice: no elimination, no kill, just notify the drop callback so stats can tick
			if self._onDrop then
				self._onDrop(player, reason)
			end
		else
			Remotes.Eliminated:FireClient(player)
			PlayerState.markOut(player)
			if self._onPlayerHit then
				self._onPlayerHit(player)
			end
			if player.Character then
				local hum = player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Health = 0
				end
			end
			-- broadcast a drop alert to all clients so they all see who dropped
			Remotes.DropAlert:FireAllClients({
				userId = player.UserId,
				displayName = player.DisplayName,
				reason = reason,
			})
		end
	end

	-- reset sack: lift back to spawn height, clear combo, reset landing zone for next play
	self.target = nil
	self.lastDeflector = nil
	self.consecutiveByLast = 0
	self.landingZoneRadius = Config.Combat.LandingZoneRadius
	-- in practice mode the sack reappears above the player (not arena center)
	if self.practiceMode and self.roster[1] then
		local p = self.roster[1]
		local root = characterRoot(p)
		if root then
			self.position = Vector3.new(root.Position.X, root.Position.Y + self.arena.sackSpawnHeight, root.Position.Z)
		else
			self.position = self.arena.center + Vector3.new(0, self.arena.sackSpawnHeight, 0)
		end
	else
		self.position = self.arena.center + Vector3.new(0, self.arena.sackSpawnHeight, 0)
	end
	self.velocity = Vector3.new(0, 0, 0)
	self.speed = Config.Sack.BaseSpeed
	self.part.Position = self.position

	task.delay(0.6, function()
		if not self.alive then
			return
		end
		if self.practiceMode then
			-- practice: sack is already above the player, just let gravity do its thing
			self.velocity = Vector3.new(0, 0, 0)
		else
			local nextTarget = self:_pickInitialTarget()
			if nextTarget and nextTarget.Character and nextTarget.Character.PrimaryPart then
				local dir = (nextTarget.Character.PrimaryPart.Position - self.position).Unit
				self.velocity = (dir + Vector3.new(0, 0.4, 0)).Unit * self.speed
			else
				self.velocity = Vector3.new(0, -1, 0) * self.speed
			end
		end
		self._resetting = false
	end)
end

function SackController:_checkHit()
	local target = self.target
	if not target then
		return
	end
	local root = characterRoot(target)
	if not root then
		return
	end
	local dist = (root.Position - self.position).Magnitude
	if dist <= Config.Sack.HitRadius then
		self:_eliminate(target, "missed")
	end
end

-- Blade-Ball-style ground-touch elimination: if the sack falls to the floor without
-- being deflected, the player it was targeting (or last deflector if no current target)
-- is out, then the sack resets above center for the next play.
function SackController:_checkGroundTouch()
	local center = self.arena.center
	local groundY = center.Y + Config.ArenaDefaults.PlatformThickness / 2 + Config.Sack.Radius
	-- only fire when descending into the ground plane
	if self.position.Y > groundY or self.velocity.Y > 0 then
		return
	end
	-- only count it as "ground" if we're roughly over the platform (not in the void past bounds)
	local horizDist = Vector3.new(self.position.X - center.X, 0, self.position.Z - center.Z).Magnitude
	if horizDist > self.arena.platformRadius then
		return -- went over the edge; let it keep falling, the bounds clamp will handle it
	end

	-- pick the player to eliminate: current target preferred, else last deflector
	local victim: Player? = nil
	if self.target and PlayerState.isAlive(self.target) then
		victim = self.target
	elseif self.lastDeflector and PlayerState.isAlive(self.lastDeflector) then
		victim = self.lastDeflector
	end

	self:_eliminate(victim, "ground")
end

function SackController:_broadcastSnapshot()
	local now = workspace:GetServerTimeNow()
	if now - self._lastSnapshot < 0.1 then
		return
	end
	self._lastSnapshot = now
	local landing = (not self._resetting) and self:_predictLanding() or nil
	Remotes.SackState:FireAllClients({
		id = self.id,
		holder = self.lastDeflector and self.lastDeflector.UserId or 0,
		combo = self.consecutiveByLast,
		speed = self.velocity.Magnitude,
		landing = landing,
		zoneRadius = self.landingZoneRadius or Config.Combat.LandingZoneRadius,
		practice = self.practiceMode == true,
	})
end

function SackController:_step(dt: number)
	if not self.alive then
		return
	end
	-- frozen mid-respawn — keep replicating the held position but skip integration / hits
	if self._resetting then
		self._tickSkinCycle(dt)
		self:_broadcastSnapshot()
		return
	end
	-- integrate gravity + drag, then update part
	local v = self.velocity
	v = v + Vector3.new(0, -Config.Sack.Gravity * dt, 0)
	v = v * (1 - Config.Sack.Drag * dt)
	self.velocity = v
	self.position = self.position + v * dt
	-- In practice mode the sack tracks the player horizontally so it always falls toward
	-- them — pure vertical play. Deflects also become pure vertical (see onDeflectAttempt).
	if self.practiceMode and self.roster[1] then
		local p = self.roster[1]
		local root = characterRoot(p)
		if root then
			self.position = Vector3.new(root.Position.X, self.position.Y, root.Position.Z)
			-- kill any horizontal drift from drag/integration
			self.velocity = Vector3.new(0, self.velocity.Y, 0)
		end
	end
	self:_clampInBounds()
	self.part.Position = self.position

	self:_tickSkinCycle(dt)
	self:_chooseTarget()
	self:_maybeOpenWindow()
	self:_checkHit()
	self:_checkGroundTouch()
	self:_broadcastSnapshot()
end

function SackController:onDeflectAttempt(player: Player, aimDirection: Vector3, _clientTime: number, targetUserId: number?)
	print(string.format("[Sacktopia] deflect attempt from %s (windowOpenFor=%s, alive=%s)",
		player.Name, tostring(self.windowOpenFor and self.windowOpenFor.Name or "nil"), tostring(self.alive)))
	if not self.alive or self.windowOpenFor ~= player then
		return false
	end
	-- successful deflect: clear window, accumulate combo, set new velocity
	Remotes.WindowClosed:FireClient(player, self.id, "deflected")
	self.windowOpenFor = nil

	if self.lastDeflector == player then
		self.consecutiveByLast += 1
	else
		self.lastDeflector = player
		self.consecutiveByLast = 1
	end

	-- Speed scaling. In matches the combo cap stops the bonus past MaxComboPerPlayer so
	-- self-juggling loses value; in practice we let it scale uncapped so the timing gets
	-- meaningfully harder the longer your combo lasts.
	local effectiveDeflects
	if self.practiceMode then
		effectiveDeflects = self.consecutiveByLast
	else
		effectiveDeflects = math.min(self.consecutiveByLast, Config.Combat.MaxComboPerPlayer)
	end
	local newSpeed = math.min(
		Config.Sack.BaseSpeed + Config.Sack.SpeedPerDeflect * (effectiveDeflects - 1) * 1.0
			+ Config.Sack.SpeedPerDeflect * 1.5,
		Config.Sack.MaxSpeed
	)
	self.speed = newSpeed

	-- In practice mode, every deflect is pure vertical so the sack stays above the player.
	-- We also shrink the landing zone with each combo for difficulty.
	if self.practiceMode then
		self.velocity = Vector3.new(0, newSpeed, 0)
		local minRadius = Config.Sack.HitRadius + 1.5
		self.landingZoneRadius = math.max(
			minRadius,
			Config.Combat.LandingZoneRadius - (self.consecutiveByLast - 1) * 0.6
		)
		self.target = nil
		self:_setHolderSkin(player)
		Remotes.KickFX:FireAllClients(player, Vector3.new(0, 1, 0))
		if self._onDeflect then
			self._onDeflect(player, self.consecutiveByLast)
		end
		self:_broadcastSnapshot()
		return true
	end

	-- Cursor-aim: if the client identified a target player, aim at them. Otherwise fall
	-- back to the camera lookVector.
	local dir: Vector3? = nil
	if targetUserId and targetUserId > 0 then
		local targetPlayer = Players:GetPlayerByUserId(targetUserId)
		if targetPlayer and targetPlayer ~= player and PlayerState.isAlive(targetPlayer) then
			local root = characterRoot(targetPlayer)
			if root then
				dir = (root.Position - self.position).Unit
			end
		end
	end
	if not dir then
		if aimDirection.Magnitude < 0.01 then
			dir = Vector3.new(0, 1, 0)
		else
			dir = aimDirection.Unit
		end
	end
	if (dir :: Vector3).Y < Config.Combat.MinUpwardComponent then
		dir = Vector3.new((dir :: Vector3).X, (dir :: Vector3).Y + Config.Combat.AimUpwardBias, (dir :: Vector3).Z).Unit
	end
	self.velocity = (dir :: Vector3) * newSpeed
	self.target = nil -- force retarget next step based on new velocity

	-- visual: adopt the deflector's chosen sack skin
	self:_setHolderSkin(player)
	-- broadcast a kick FX cue so all clients animate that player's leg
	Remotes.KickFX:FireAllClients(player, dir)

	if self._onDeflect then
		self._onDeflect(player, self.consecutiveByLast)
	end

	self:_broadcastSnapshot()
	return true
end

return SackController
