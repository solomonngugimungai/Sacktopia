--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Sacktopia"):WaitForChild("Config"))
local Items = require(ReplicatedStorage.Sacktopia:WaitForChild("Items"))
local Remotes = require(ReplicatedStorage.Sacktopia:WaitForChild("Remotes"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local PlayerState = require(script.Parent.PlayerState)

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

function SackController.new()
	local self = setmetatable({}, SackController)
	self.id = (function()
		nextSackId += 1
		return nextSackId
	end)()
	self.part = buildSackPart()
	self.trail = attachTrail(self.part)
	self.position = Config.Arena.Center + Vector3.new(0, Config.Sack.SpawnHeight, 0)
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
	applySkin(self.part, self._activeSkin)
	self.part.Position = self.position
	self.part.Parent = Workspace
	return self
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
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	if self.part then
		self.part:Destroy()
		self.part = nil :: any
	end
end

function SackController:_pickInitialTarget()
	local candidates = PlayerState.alivePlayers()
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

function SackController:start()
	-- Seed: launch toward a random alive player from above center.
	local target = self:_pickInitialTarget()
	if target and target.Character and target.Character.PrimaryPart then
		local dir = (target.Character.PrimaryPart.Position - self.position).Unit
		self.velocity = (dir + Vector3.new(0, 0.1, 0)).Unit * self.speed
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
	local center = Config.Arena.Center
	local horiz = Vector3.new(self.position.X - center.X, 0, self.position.Z - center.Z)
	local horizDist = horiz.Magnitude
	if horizDist > Config.Arena.BoundsRadius then
		-- soft wrap: reflect velocity inward and clamp position to boundary
		local inward = -horiz.Unit
		local v = self.velocity
		local horizV = Vector3.new(v.X, 0, v.Z)
		local reflected = horizV - 2 * horizV:Dot(inward * -1) * (inward * -1)
		self.velocity = Vector3.new(reflected.X * 0.7, v.Y, reflected.Z * 0.7)
		self.position = center + inward * -1 * Config.Arena.BoundsRadius + Vector3.new(0, self.position.Y - center.Y, 0)
	end
	if self.position.Y < center.Y - 5 then
		-- floor bounce so the sack doesn't fall through the world if no terrain
		self.position = Vector3.new(self.position.X, center.Y - 5, self.position.Z)
		self.velocity = Vector3.new(self.velocity.X * 0.8, math.abs(self.velocity.Y) * 0.5, self.velocity.Z * 0.8)
	end
	if self.position.Y > center.Y + Config.Arena.BoundsHeight then
		self.position = Vector3.new(self.position.X, center.Y + Config.Arena.BoundsHeight, self.position.Z)
		self.velocity = Vector3.new(self.velocity.X, -math.abs(self.velocity.Y), self.velocity.Z)
	end
end

function SackController:_predictImpact(player: Player): number?
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

function SackController:_chooseTarget()
	local best: Player? = nil
	local bestEta = math.huge
	for _, p in PlayerState.alivePlayers() do
		local eta = self:_predictImpact(p)
		if eta and eta < bestEta then
			best = p
			bestEta = eta
		end
	end
	if best ~= self.target then
		-- closing previous window if open
		if self.windowOpenFor then
			Remotes.WindowClosed:FireClient(self.windowOpenFor, self.id, "retargeted")
			self.windowOpenFor = nil
		end
		self.target = best
		self.predictedImpactAt = bestEta < math.huge and (workspace:GetServerTimeNow() + bestEta) or 0
	elseif best then
		self.predictedImpactAt = workspace:GetServerTimeNow() + bestEta
	end
end

function SackController:_maybeOpenWindow()
	local target = self.target
	if not target then
		return
	end
	local now = workspace:GetServerTimeNow()
	local timeToImpact = self.predictedImpactAt - now
	if timeToImpact <= Config.Combat.WindowOpenLead and timeToImpact > Config.Combat.WindowCloseLead then
		if self.windowOpenFor ~= target then
			self.windowOpenFor = target
			Remotes.WindowOpened:FireClient(target, self.id, self.predictedImpactAt)
		end
	end
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
		-- impact reached — if window was open, this is a miss; eliminate
		if self.windowOpenFor == target then
			Remotes.WindowClosed:FireClient(target, self.id, "missed")
			self.windowOpenFor = nil
		end
		Remotes.Eliminated:FireClient(target)
		PlayerState.markOut(target)
		-- Fire eliminated event on character so RoundManager can react
		if target.Character then
			local hum = target.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = 0
			end
		end
		self.target = nil
		self.lastDeflector = nil
		self.consecutiveByLast = 0
		-- pick a new target after a beat
		task.delay(0.4, function()
			if self.alive then
				self:_chooseTarget()
				if not self.target then
					-- nobody left to target; bounce gently
					self.velocity = Vector3.new(0, math.abs(self.velocity.Y) + 5, 0)
				end
			end
		end)
	end
end

function SackController:_broadcastSnapshot()
	local now = workspace:GetServerTimeNow()
	if now - self._lastSnapshot < 0.1 then
		return
	end
	self._lastSnapshot = now
	Remotes.SackState:FireAllClients({
		id = self.id,
		holder = self.lastDeflector and self.lastDeflector.UserId or 0,
		combo = self.consecutiveByLast,
		speed = self.velocity.Magnitude,
	})
end

function SackController:_step(dt: number)
	if not self.alive then
		return
	end
	-- integrate gravity + drag, then update part
	local v = self.velocity
	v = v + Vector3.new(0, -Config.Sack.Gravity * dt, 0)
	v = v * (1 - Config.Sack.Drag * dt)
	self.velocity = v
	self.position = self.position + v * dt
	self:_clampInBounds()
	self.part.Position = self.position

	self:_tickSkinCycle(dt)
	self:_chooseTarget()
	self:_maybeOpenWindow()
	self:_checkHit()
	self:_broadcastSnapshot()
end

function SackController:onDeflectAttempt(player: Player, aimDirection: Vector3, _clientTime: number)
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

	-- speed scales until combo cap; past the cap, the player gets no more bonus (juggle-to-self loses value)
	local effectiveDeflects = math.min(self.consecutiveByLast, Config.Combat.MaxComboPerPlayer)
	local newSpeed = math.min(
		Config.Sack.BaseSpeed + Config.Sack.SpeedPerDeflect * (effectiveDeflects - 1) * 1.0
			+ Config.Sack.SpeedPerDeflect * 1.5,
		Config.Sack.MaxSpeed
	)
	self.speed = newSpeed

	-- shape aim: ensure some upward component so it arcs
	local dir = aimDirection
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 1, 0)
	else
		dir = dir.Unit
	end
	if dir.Y < Config.Combat.MinUpwardComponent then
		dir = Vector3.new(dir.X, dir.Y + Config.Combat.AimUpwardBias, dir.Z).Unit
	end
	self.velocity = dir * newSpeed
	self.target = nil -- force retarget next step based on new velocity

	-- visual: adopt the deflector's chosen sack skin
	self:_setHolderSkin(player)
	-- broadcast a kick FX cue so all clients animate that player's leg
	Remotes.KickFX:FireAllClients(player, dir)

	self:_broadcastSnapshot()
	return true
end

return SackController
