--------------------------------------------------
-- BALL PHYSICS CONTROLLER
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--
-- SOLE OWNER OF BALL MOVEMENT
--
-- CLIENT:
--     Sends Vector2 movement intent only.
--
-- SERVER:
--     Owns physics.
--     Owns network ownership.
--     Owns velocity.
--     Owns acceleration.
--     Owns course forward movement.
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local RunService =
	game:GetService("RunService")


--------------------------------------------------
-- SERVER CHECK
--------------------------------------------------

if not RunService:IsServer() then

	error(
		"[BallPhysicsController] This script must run on the server."
	)

end


--------------------------------------------------
-- SAFE MODULE LOADER
--------------------------------------------------

local function requireModule(
	parent,
	name
)

	local module =
		parent:WaitForChild(
			name
		)

	if not module:IsA("ModuleScript") then

		error(
			"[BallPhysicsController] "
				.. name
				.. " must be a ModuleScript. Found: "
				.. module.ClassName
		)

	end

	local success, result =
		pcall(
			require,
			module
		)

	if not success then

		error(
			"[BallPhysicsController] Failed to require "
				.. name
				.. ": "
				.. tostring(result)
		)

	end

	return result

end


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local BallDefinitions =
	requireModule(
		ServerScriptService,
		"BallDefinitions"
	)


local playerDataLoader =
	ServerScriptService:WaitForChild(
		"PlayerDataLoader"
	)


local PlayerDataService =
	requireModule(
		playerDataLoader,
		"PlayerDataService"
	)


local GamePassService =
	requireModule(
		ServerScriptService,
		"GamePassService"
	)


local LimitedGenerator =
	requireModule(
		ServerScriptService,
		"LimitedGenerator"
	)


-- Keeps a ball's accessory parts (cat, spikes, dragon...) sized with it.
local BallAccessories =
	requireModule(
		ReplicatedStorage,
		"BallAccessories"
	)


-- Timed boosts (x4 XP reward); see BoostService.
local BoostService =
	requireModule(
		ServerScriptService,
		"BoostService"
	)


local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)


--------------------------------------------------
-- VALIDATE BALL DEFINITIONS
--------------------------------------------------

if typeof(BallDefinitions) ~= "table" then

	error(
		"[BallPhysicsController] BallDefinitions must return a table."
	)

end


--------------------------------------------------
-- REMOTE FOLDER
--------------------------------------------------

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new("Folder")

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage

end


if not remotes:IsA("Folder") then

	error(
		"[BallPhysicsController] ReplicatedStorage.Remotes must be a Folder."
	)

end


--------------------------------------------------
-- MOVEMENT REMOTE
--------------------------------------------------

local ballMovement =
	remotes:FindFirstChild(
		"BallMovement"
	)


if not ballMovement then

	ballMovement =
		Instance.new("RemoteEvent")

	ballMovement.Name =
		"BallMovement"

	ballMovement.Parent =
		remotes

end


if not ballMovement:IsA("RemoteEvent") then

	error(
		"[BallPhysicsController] Remotes.BallMovement must be a RemoteEvent."
	)

end

--------------------------------------------------
-- XP AWARD REMOTE
--------------------------------------------------

local xpAward = remotes:FindFirstChild("XPAward")

if not xpAward then
    xpAward = Instance.new("RemoteEvent")
    xpAward.Name = "XPAward"
    xpAward.Parent = remotes
end

assert(
    xpAward:IsA("RemoteEvent"),
    "Remotes.XPAward must be a RemoteEvent"
)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local LOBBY_SPEED =
	24

-- Enter the course at (about) the lobby speed instead of dropping to 10 and
-- crawling back up over ~3.5 s, which made the start wall feel delayed.
local COURSE_START_SPEED =
	42

-- smooth, steady ramp to cruising speed (34 felt like a jolt)
local ballLateral = setmetatable({}, { __mode = "k" }) -- smoothed sideways speed per ball

local COURSE_ACCELERATION =
	30

-- the steady pace every ball reaches first on the oil course (see the ramp below)
local COURSE_CRUISE_SPEED =
	52

local MIN_COURSE_SPEED =
	6

local INPUT_TIMEOUT =
	0.20

-- Horizontal acceleration budget (studs/s^2) for the velocity controller.
local HORIZONTAL_FORCE_PER_MASS =
	600
local JUMP_VELOCITY =
	40 -- ~4 stud hop at default gravity
local JUMP_COOLDOWN =
	0.4
local BASE_XP_PER_STUD =
	0.5

local XP_AWARD_CHUNK =
	4

local MAX_XP_DISTANCE_PER_HEARTBEAT =
	10

--------------------------------------------------
-- XP GENERATOR SETTINGS
--------------------------------------------------

local XP_GENERATORS =
	workspace:WaitForChild("XPGenerators")

-- EDIT THESE VALUES TO MATCH YOUR ACTUAL GENERATOR NAMES.
-- Names must match the MeshPart names in Explorer.
-- Required rebirth counts must match your game design.

-- Must match XPGeneratorController.client.lua labels.
local GENERATOR_MULTIPLIERS = {
	GenX1 = 1,
	GenX2 = 2,
	GenX4 = 4,
	GenX6 = 6,
	GenX8 = 8,
	GenX10 = 10,
	["GenX100 Admin XP"] = 100,
	["GenX1000 Admin XP"] = 1000,
}

local GENERATOR_REBIRTH_REQUIREMENTS = {
	GenX1 = 0,
	GenX2 = 2,
	GenX4 = 4,
	GenX6 = 0, -- limited-time gift: no rebirth gate (no time gate implemented)
	GenX8 = 8,
	GenX10 = 10,
}

-- Admin generators need their Game Pass (GamePassService, server-side
-- ownership check). Pass ids live in GamePassConfig (server only).
local ADMIN_GENERATORS = {
	["GenX100 Admin XP"] = true,
	["GenX1000 Admin XP"] = true,
}

--------------------------------------------------
-- GET GENERATOR NAME
--------------------------------------------------

local function getGeneratorName(part)

	local current = part

	while current and current ~= XP_GENERATORS do

		if GENERATOR_MULTIPLIERS[current.Name] then
			return current.Name
		end

		current = current.Parent
	end

	return nil
end

--------------------------------------------------
-- GET XP GENERATOR PARTS
--------------------------------------------------

local function getXPGeneratorParts()

	local parts = {}

	for _, instance in ipairs(
		XP_GENERATORS:GetDescendants()
	) do

		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end

	end

	return parts
end

--------------------------------------------------
-- BALL / GENERATOR OVERLAP
--------------------------------------------------

local WorldConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig"))
local WorldBallSpeed = require(ServerScriptService:WaitForChild("WorldBallSpeed"))

local function isBallInsideGenerator(ball, part, offset)

	if not ball or not ball:IsA("BasePart")
		or not part or not part:IsA("BasePart") then

		return false
	end

	-- higher worlds stand on copies of these generators: map the ball back
	local localPosition =
		part.CFrame:PointToObjectSpace(ball.Position - (offset or Vector3.zero))

	local halfGenerator = part.Size * 0.5
	local halfBall = ball.Size * 0.5
	local padding = 0.5

	return math.abs(localPosition.X)
			<= halfGenerator.X + halfBall.X + padding
		and math.abs(localPosition.Z)
			<= halfGenerator.Z + halfBall.Z + padding
		and math.abs(localPosition.Y)
			<= halfGenerator.Y + halfBall.Y + padding
end

--------------------------------------------------
-- FIND ACTIVE GENERATOR
--------------------------------------------------

local function getActiveGeneratorMultiplier(player, ball)

	if not player or not ball or not ball.Parent then
		return 1, nil
	end

	local rebirths =
		PlayerDataService.GetRebirths(player)

	if typeof(rebirths) ~= "number"
		or rebirths < 0
		or rebirths ~= rebirths
		or rebirths == math.huge then

		return 1, nil
	end

	rebirths = math.floor(rebirths)

	local bestMultiplier = 1
	local activeGenerator = nil
	local world = WorldConfig.Of(player)

	for _, part in ipairs(getXPGeneratorParts()) do

		local generatorName = getGeneratorName(part)

		if not generatorName then
			continue
		end

		local multiplier =
			GENERATOR_MULTIPLIERS[generatorName]

		local requiredRebirths =
			GENERATOR_REBIRTH_REQUIREMENTS[generatorName]

		-- GenX6 is the limited-time gift: it only pays while the player
		-- has claimed an active boost (server-timed, see LimitedGenerator).
		if generatorName == "GenX6"
			and not LimitedGenerator.IsActive(player) then
			continue
		end

		if ADMIN_GENERATORS[generatorName] then
			if not GamePassService.OwnsAdminGenerator(player, generatorName, world.Id) then
				continue
			end
			requiredRebirths = world.Rebirths
			multiplier = world.Admin[generatorName] or multiplier
		elseif multiplier and requiredRebirths and world.Generators and world.Generators[generatorName] then
			-- higher worlds: the ladder continues in steps of 5; each generator needs
			-- as many rebirths as its multiplier (the X6 spot stays the limited gift)
			multiplier = world.Generators[generatorName]
			requiredRebirths = generatorName == "GenX6" and world.Rebirths or multiplier
		end

		if not multiplier or not requiredRebirths then
			continue
		end

		if rebirths < requiredRebirths then
			continue
		end

		if activeGenerator and multiplier <= bestMultiplier then
			continue
		end

		if isBallInsideGenerator(ball, part, world.Offset) then

			bestMultiplier = multiplier
			activeGenerator = generatorName

		end
	end

	return bestMultiplier, activeGenerator
end
	--------------------------------------------------
-- REBIRTH XP MULTIPLIER
--------------------------------------------------

local function getRebirthXPMultiplier(player)
    local rebirths = PlayerDataService.GetRebirths(player)

    rebirths = math.max(0, math.floor(rebirths))

    -- Each rebirth adds a 1000% bonus.
    -- 0 rebirths = 1x
    -- 1 rebirth = 11x
    -- 2 rebirths = 21x
    return 1 + (rebirths * 10)
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local playerInputs = {}

local lastBallPositions = {}

local xpDistanceBuffer = {}

local ballSpeeds = {}

local ballControllers = {}

local releasedBalls = {}


--------------------------------------------------
-- FINITE NUMBER
--------------------------------------------------

local function isFiniteNumber(
	value
)

	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge

end


--------------------------------------------------
-- VALIDATE INPUT
--------------------------------------------------

local function isValidInput(
	input
)

	if typeof(input) ~= "Vector2" then

		return false

	end


	if not isFiniteNumber(input.X)
		or not isFiniteNumber(input.Y) then

		return false

	end


	if input.X < -1
		or input.X > 1
		or input.Y < -1
		or input.Y > 1 then

		return false

	end


	if input.Magnitude > 1.01 then

		return false

	end


	return true

end


--------------------------------------------------
-- BALL NAME
--------------------------------------------------

local function getBallName(
	player
)

	return "PlayerBall_"
		..
		tostring(
			player.UserId
		)

end


--------------------------------------------------
-- GET PLAYER BALL
--------------------------------------------------

local function getPlayerBall(
	player
)

	if not player then

		return nil

	end


	local ball =
		playerBalls:FindFirstChild(
			getBallName(
				player
			)
		)


	if not ball
		or not ball:IsA("BasePart") then

		return nil

	end


	if ball:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return nil

	end


	return ball

end


--------------------------------------------------
-- GET BALL DEFINITION
--------------------------------------------------

local function getBallDefinition(
	ball
)

	if not ball then

		return nil

	end


	local ballId =
		ball:GetAttribute(
			"BallId"
		)


	if typeof(ballId) ~= "string" then

		return nil

	end


	local definition =
		BallDefinitions[ballId]


	if typeof(definition) ~= "table" then

		return nil

	end


	return definition

end


--------------------------------------------------
-- FORWARD SPEED
--------------------------------------------------

local function getForwardSpeed(
	ball
)

	local definition =
		getBallDefinition(
			ball
		)


	if definition
		and isFiniteNumber(
			definition.ForwardSpeed
		)
		and definition.ForwardSpeed > 0 then

		-- the evolved Oil Barrel skin of the world you are in is the fastest ball
		-- there (+5); ownership is the server-set Skins attribute (SkinService)
		if ball:GetAttribute("BallId") == "OilBarrel" then
			local owner = Players:GetPlayerByUserId(ball:GetAttribute("OwnerUserId") or 0)
			local worldId = owner and owner:GetAttribute("World") or 1
			if worldId > 1 and WorldConfig.OwnsSkin(owner, "OilBarrel", worldId) then
				return definition.ForwardSpeed + 5
			end
		end
		-- a ball from another world (no skin for this one) rolls at the starter ball's speed
		return WorldBallSpeed.ForBall(ball, definition.ForwardSpeed)

	end


	local attributeSpeed =
		ball:GetAttribute(
			"ForwardSpeed"
		)


	if isFiniteNumber(
		attributeSpeed
	)
		and attributeSpeed > 0 then

		return attributeSpeed

	end


	return 50

end


--------------------------------------------------
-- HORIZONTAL SPEED
--------------------------------------------------

local function getHorizontalSpeed(
	ball
)

	local definition =
		getBallDefinition(
			ball
		)


	if definition
		and isFiniteNumber(
			definition.HorizontalSpeed
		)
		and definition.HorizontalSpeed > 0 then

		return definition.HorizontalSpeed

	end


	local attributeSpeed =
		ball:GetAttribute(
			"HorizontalSpeed"
		)


	if isFiniteNumber(
		attributeSpeed
	)
		and attributeSpeed > 0 then

		return attributeSpeed

	end


	return 50

end


--------------------------------------------------
-- GET / CREATE LINEAR VELOCITY
--------------------------------------------------

local function getLinearVelocity(
	ball
)

	if not ball
		or not ball:IsA("BasePart") then

		return nil

	end


	local cached =
		ballControllers[ball]


	if cached
		and cached.Parent == ball
		and cached:IsA("LinearVelocity") then

		return cached

	end


	--------------------------------------------------
	-- ATTACHMENT
	--------------------------------------------------

	local attachment =
		ball:FindFirstChild(
			"BallAttachment"
		)


	if attachment
		and not attachment:IsA("Attachment") then

		attachment:Destroy()

		attachment = nil

	end


	if not attachment then

		attachment =
			Instance.new("Attachment")

		attachment.Name =
			"BallAttachment"

		attachment.Parent =
			ball

	end


	--------------------------------------------------
	-- LINEAR VELOCITY
	--------------------------------------------------

	local controller =
		ball:FindFirstChild(
			"BallLinearVelocity"
		)


	if controller
		and not controller:IsA("LinearVelocity") then

		controller:Destroy()

		controller = nil

	end


	if not controller then

		controller =
			Instance.new("LinearVelocity")

		controller.Name =
			"BallLinearVelocity"

		controller.Parent =
			ball

	end


	--------------------------------------------------
	-- CONFIGURATION
	--------------------------------------------------

	controller.Attachment0 =
		attachment

	controller.RelativeTo =
		Enum.ActuatorRelativeTo.World

	controller.VelocityConstraintMode =
		Enum.VelocityConstraintMode.Vector

	-- ROOT CAUSE OF HOVERING: this controller used to command a full
	-- 3D velocity (Y = 0) with unlimited force, which pinned the ball's
	-- vertical velocity to zero: no gravity, no falling off edges, no
	-- following lower ground. Only constrain the horizontal axes; Y is
	-- left to the physics engine. Force is finite so steps/slopes can
	-- still push the ball up instead of the ball plowing through them.
	controller.ForceLimitMode =
		Enum.ForceLimitMode.PerAxis
	local horizontalForce =
		math.max(ball.AssemblyMass, 1) * HORIZONTAL_FORCE_PER_MASS
	controller.MaxAxesForce =
		Vector3.new(horizontalForce, 0, horizontalForce)

	controller.Enabled =
		true


	--------------------------------------------------
	-- CACHE
	--------------------------------------------------

	ballControllers[ball] =
		controller


	return controller

end


--------------------------------------------------
-- SERVER NETWORK OWNERSHIP
--------------------------------------------------

local function ensureServerOwnership(ball, player)

	if not ball or not ball.Parent then
		return
	end

	-- WinCourse may manage its own physics while active.
	-- This controller must not override it during that time.
	if ball:GetAttribute("WinCourseActive") == true then
		return
	end

	-- OWNERSHIP MODEL
	--
	-- Lobby (RunState Waiting): the PLAYER owns the ball's physics so
	-- rolling is instant (no server round trip). BallController drives
	-- the velocity locally; this server validates the result (XP
	-- distance is capped to the legal lobby speed).
	--
	-- Every other state (Starting / Running / Finishing / WinCourse):
	-- the SERVER owns the ball and drives it, exactly as before.
	local runState = player and player:GetAttribute("RunState")
	local inLobby = player ~= nil
		and (typeof(runState) ~= "string"
			or runState == ""
			or runState == "Waiting")

	local desiredOwner = inLobby and player or nil

	pcall(function()
		if ball:GetNetworkOwner() ~= desiredOwner then
			ball:SetNetworkOwner(desiredOwner)
		end
	end)

	-- Only claim "client driven" if the owner really is the player.
	local owner = nil
	pcall(function()
		owner = ball:GetNetworkOwner()
	end)

	local clientDriven = player ~= nil and owner == player

	if ball:GetAttribute("ClientDriven") ~= clientDriven then
		ball:SetAttribute("ClientDriven", clientDriven)
	end

	-- Authoritative lobby speed, read by the owning client.
	if ball:GetAttribute("LobbySpeed") ~= LOBBY_SPEED then
		ball:SetAttribute("LobbySpeed", LOBBY_SPEED)
	end

end


--------------------------------------------------
-- STUCK LOBBY BALL
--
-- If the player holds a direction but the ball has not moved for a moment
-- (wedged into the floor after a landing, ownership hiccup), and no wall is in
-- the way, the server pops it up a little and hands ownership back so it rolls
-- again. Pushing against a real wall is left alone.
--------------------------------------------------

local stuckTime = {}
local lastUnstick = {}

local function unstickLobbyBall(player, ball, runState, input, previousPosition, currentPosition, deltaTime)
	if runState ~= "Waiting"
		or not previousPosition
		or typeof(input) ~= "Vector2"
		or input.Magnitude < 0.5
		or ball.Anchored
		or ball:GetAttribute("WinCourseActive") == true then
		stuckTime[player] = 0
		return
	end

	local moved = Vector3.new(currentPosition.X - previousPosition.X, 0, currentPosition.Z - previousPosition.Z).Magnitude
	if moved > LOBBY_SPEED * deltaTime * 0.15 then
		stuckTime[player] = 0
		return
	end

	stuckTime[player] = (stuckTime[player] or 0) + deltaTime
	if stuckTime[player] < 0.6 or os.clock() - (lastUnstick[player] or 0) < 1.5 then
		return
	end

	local radius = ball.Size.Y * 0.5
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ball.Parent }
	params.CollisionGroup = ball.CollisionGroup -- only what can really block this ball
	params.RespectCanCollide = true
	local direction = Vector3.new(input.X, 0, input.Y).Unit
	if workspace:Raycast(currentPosition, direction * (radius + 1), params) then
		stuckTime[player] = 0
		return -- a wall: nothing to fix
	end

	stuckTime[player] = 0
	lastUnstick[player] = os.clock()
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CFrame = ball.CFrame + Vector3.new(0, 0.6, 0)
	ball.AssemblyLinearVelocity = Vector3.new(0, 8, 0)
	pcall(function()
		ball:SetNetworkOwner(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	stuckTime[player] = nil
	lastUnstick[player] = nil
end)


--------------------------------------------------
-- LOBBY BALL SCALE
--
-- Balls are a little smaller in the lobby (Waiting) and pop up to
-- full size when a run starts, so the WinCourse placement math
-- (which reads ball.Size) always sees the full-size ball.
-- The authoritative full size is stored in the "BaseSize" attribute.
--------------------------------------------------

local LOBBY_BALL_SCALE =
	0.7
local BALL_SCALE_TIME =
	0.45

local ballScaleState = {}

local function easeOutBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function updateBallScale(ball, wantSmall, deltaTime)
	local state = ballScaleState[ball]

	if not state then
		local base = ball:GetAttribute("BaseSize")
		if typeof(base) ~= "Vector3" then
			base = ball.Size
			ball:SetAttribute("BaseSize", base)
		end

		local startScale = wantSmall and LOBBY_BALL_SCALE or 1
		state = {
			Base = base,
			Scale = startScale,
			From = startScale,
			To = startScale,
			T = 1,
		}
		ballScaleState[ball] = state
		ball.Size = base * startScale
		BallAccessories.SetScale(ball)
		return
	end

	local target = wantSmall and LOBBY_BALL_SCALE or 1
	if state.To ~= target then
		state.From = state.Scale
		state.To = target
		state.T = 0
	end

	if state.T >= 1 then
		return
	end

	state.T = math.min(1, state.T + deltaTime / BALL_SCALE_TIME)

	-- Growing overshoots slightly (the "pop"); shrinking eases out.
	local eased = state.To > state.From
		and easeOutBack(state.T)
		or (1 - (1 - state.T) ^ 2)

	state.Scale = state.From + (state.To - state.From) * eased
	ball.Size = state.Base * state.Scale
	BallAccessories.SetScale(ball)
end

--------------------------------------------------
-- STOP BALL
--------------------------------------------------

local function stopBall(
	ball
)

	if not ball
		or not ball.Parent then

		return

	end


	local controller =
		getLinearVelocity(
			ball
		)


	if controller then

		controller.VectorVelocity =
			Vector3.zero

		controller.Enabled =
			true

	end


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	ensureServerOwnership(
		ball
	)

end


--------------------------------------------------
-- WIN COURSE HANDOFF
--------------------------------------------------

local function releaseToWinCourse(player, ball)

	if not ball or not ball.Parent then
		return
	end

	-- Do not modify velocity or disable the controller here.
	-- WinCourse owns movement while WinCourseActive is true.

	playerInputs[player] = nil
	ballSpeeds[ball] = nil

	lastBallPositions[player] = ball.Position

end


--------------------------------------------------
-- PREPARE BALL
--------------------------------------------------

local function prepareBall(
	ball
)

	if not ball
		or not ball:IsA("BasePart") then

		return

	end


	--------------------------------------------------
	-- PHYSICS
	--------------------------------------------------

	ball.Anchored =
		false

	ball.CanCollide =
		true

	ball.CanTouch =
		true

	ball.CanQuery =
		true

	-- No bounce: the template's elasticity (0.5) made the ball dribble over
	-- tiny lane seams at speed. Weight 100 makes the ball's value win the
	-- contact-pair average with the floor.
	ball.CustomPhysicalProperties =
		PhysicalProperties.new(
			0.7,
			0.3,
			0,
			1,
			100
		)


	--------------------------------------------------
	-- SERVER OWNERSHIP
	--------------------------------------------------

	pcall(
		function()

			ball:SetNetworkOwner(nil)

		end
	)


	--------------------------------------------------
	-- CONTROLLER
	--------------------------------------------------

	local controller =
		getLinearVelocity(
			ball
		)


	if controller then

		controller.Enabled =
			true

		controller.VectorVelocity =
			Vector3.zero

	end


	--------------------------------------------------
	-- SPEED
	--------------------------------------------------

	-- A mid-run ball swap (BallTierGates) hands over the current course
	-- speed so an upgrade does not restart the speed ramp.
	local carriedSpeed =
		ball:GetAttribute("CarrySpeed")

	ballSpeeds[ball] =
		(
			typeof(carriedSpeed) == "number"
			and carriedSpeed > 0
		)
		and carriedSpeed
		or COURSE_START_SPEED

	ball:SetAttribute("CarrySpeed", nil)


	--------------------------------------------------
	-- RELEASE STATE
	--------------------------------------------------

	releasedBalls[ball] =
		nil


	--------------------------------------------------
	-- POSITION
	--------------------------------------------------

	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	local player =
		Players:GetPlayerByUserId(
			ownerUserId
		)


	if player then

		lastBallPositions[player] =
			ball.Position

	end


	print(
		"[BallPhysicsController]",
		"Prepared:",
		ball.Name,
		"Owner:",
		ownerUserId,
		"Anchored:",
		ball.Anchored
	)
	--------------------------------------------------
-- RESET LOBBY MOVEMENT STATE
--------------------------------------------------

local ownerUserId =
	ball:GetAttribute("OwnerUserId")

local player =
	Players:GetPlayerByUserId(ownerUserId)

if player then

	playerInputs[player] = nil

	lastBallPositions[player] = ball.Position

	xpDistanceBuffer[player] =
		xpDistanceBuffer[player] or 0

end

releasedBalls[ball] = nil

local lobbyController =
	ball:FindFirstChild("BallLinearVelocity")

if lobbyController
	and lobbyController:IsA("LinearVelocity") then

	lobbyController.Enabled = true
	lobbyController.VectorVelocity = Vector3.zero

end

end


--------------------------------------------------
-- JUMP (server validated)
--------------------------------------------------

local lastJumpTimes = {}

local function isBallGrounded(ball)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { playerBalls }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	local radius = ball.Size.Y * 0.5
	local result = workspace:Raycast(
		ball.Position,
		Vector3.new(0, -(radius + 0.75), 0),
		params
	)
	return result ~= nil
end

local function tryJump(player, ball)
	-- A client-owned ball jumps locally (BallController); see ensureServerOwnership.
	if ball:GetAttribute("ClientDriven") == true then
		return
	end

	-- Lobby only (RunController owns RunState).
	local runState = player:GetAttribute("RunState")
	if runState ~= nil and runState ~= "Waiting" then
		return
	end

	if ball:GetAttribute("WinCourseActive") == true then
		return
	end

	local now = os.clock()
	if now - (lastJumpTimes[player] or 0) < JUMP_COOLDOWN then
		return
	end

	if not isBallGrounded(ball) then
		return
	end

	lastJumpTimes[player] = now

	local velocity = ball.AssemblyLinearVelocity
	ball.AssemblyLinearVelocity =
		Vector3.new(velocity.X, JUMP_VELOCITY, velocity.Z)
end

--------------------------------------------------
-- MOVEMENT INPUT
--------------------------------------------------

ballMovement.OnServerEvent:Connect(
	function(
		player,
		input,
		jump
	)

	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

		if not player
			or not player:IsDescendantOf(
				Players
			) then

			return

		end


	--------------------------------------------------
	-- INPUT
	--------------------------------------------------

		if not isValidInput(
			input
		) then

			return

		end


	--------------------------------------------------
	-- BALL
	--------------------------------------------------

		local ball =
			getPlayerBall(
				player
			)


		if not ball then

			return

		end


	--------------------------------------------------
	-- RELEASED
	--------------------------------------------------

		if releasedBalls[ball] then
	return
end
--------------------------------------------------
-- WIN COURSE INPUT GATE
--------------------------------------------------

if ball:GetAttribute("WinCourseActive") == true then
	return
end

-- No permanent releasedBalls check.
-- Lobby input becomes available again after WinCourse.


	--------------------------------------------------
	-- STORE INPUT
	--------------------------------------------------

		playerInputs[player] = {

			Value = Vector2.new(
				math.clamp(
					input.X,
					-1,
					1
				),

				math.clamp(
					input.Y,
					-1,
					1
				)
			),

			Time = os.clock()

		}

		-- Optional jump request. Server decides everything: lobby only,
		-- grounded, rate limited; the client only says "I pressed jump".
		if jump == true then
			tryJump(player, ball)
		end

	end
)


--------------------------------------------------
-- NEW BALL
--------------------------------------------------

playerBalls.ChildAdded:Connect(
	function(
		ball
	)

		task.defer(
			function()

				if ball.Parent ==
					playerBalls then

					prepareBall(
						ball
					)

				end

			end
		)

	end
)


--------------------------------------------------
-- EXISTING BALLS
--------------------------------------------------

for _, ball in ipairs(
	playerBalls:GetChildren()
) do

	prepareBall(
		ball
	)

end


--------------------------------------------------
-- MAIN PHYSICS LOOP
--------------------------------------------------

RunService.Heartbeat:Connect(
	function(
		deltaTime
	)

		if not isFiniteNumber(
			deltaTime
		)
			or deltaTime <= 0 then

			return

		end


		deltaTime =
			math.min(
				deltaTime,
				0.1
			)


		local now =
			os.clock()


		--------------------------------------------------
		-- EVERY PLAYER
		--------------------------------------------------

		for _, player in ipairs(
			Players:GetPlayers()
		) do

			local ball =
				getPlayerBall(
					player
				)


			if not ball then

				continue

			end


			-- Lobby ball scale (see LOBBY BALL SCALE).
			do
				local scaleRunState = player:GetAttribute("RunState")
				local inLobby =
					(typeof(scaleRunState) ~= "string"
						or scaleRunState == ""
						or scaleRunState == "Waiting")
					and ball:GetAttribute("WinCourseActive") ~= true

				updateBallScale(ball, inLobby, deltaTime)
			end

			--------------------------------------------------
-- WIN COURSE ACTIVE
--------------------------------------------------

if ball:GetAttribute("WinCourseActive") == true then

	releaseToWinCourse(player, ball)

	continue

end

--------------------------------------------------
-- WIN COURSE ENDED: RESUME LOBBY PHYSICS
--------------------------------------------------

-- Do not leave a permanent release flag behind.
releasedBalls[ball] = nil

-- Ensure the normal server-owned lobby controller is active.
ensureServerOwnership(ball, player)

local controller = getLinearVelocity(ball)

if not controller then
	continue
end

controller.Enabled = true

-- Reset course acceleration when returning to the lobby.
if player:GetAttribute("RunState") == "Waiting"
	or player:GetAttribute("RunState") == "Starting" then

	ballSpeeds[ball] = COURSE_START_SPEED

end


			--------------------------------------------------
			-- OWNERSHIP
			--------------------------------------------------

			ensureServerOwnership(
				ball, player
			)


			--------------------------------------------------
			-- RUN STATE
			--------------------------------------------------

			local runState =
				player:GetAttribute(
					"RunState"
				)


			--------------------------------------------------
			-- SAFETY FALLBACK
			--
			-- RunController is authoritative, but if the
			-- attribute has not been created yet, the ball
			-- remains controllable in the lobby.
			--------------------------------------------------

			if typeof(runState) ~= "string"
				or runState == "" then

				runState =
					"Waiting"

			end


			--------------------------------------------------
			-- INPUT
			--------------------------------------------------

			local input =
				Vector2.zero


			local state =
				playerInputs[player]


			if state
				and now - state.Time
					<= INPUT_TIMEOUT then

				input =
					state.Value

			end


			--------------------------------------------------
			-- POSITION
			--------------------------------------------------

			local currentPosition =
				ball.Position


			local previousPosition =
				lastBallPositions[player]


			--------------------------------------------------
			-- XP
			--------------------------------------------------

			if runState == "Waiting"
				and previousPosition then

				local currentXZ = Vector3.new(
					currentPosition.X,
					0,
					currentPosition.Z
				)

				local previousXZ = Vector3.new(
					previousPosition.X,
					0,
					previousPosition.Z
				)

				local distance = (
					currentXZ - previousXZ
				).Magnitude

				-- Jumping in place counts as moving: vertical travel earns XP at
				-- most at the lobby rolling rate, and only the larger of the two
				-- counts (never added), so jumping while rolling is not double XP.
				local verticalDistance = math.min(
					math.abs(currentPosition.Y - previousPosition.Y),
					LOBBY_SPEED * deltaTime
				)
				distance = math.max(distance, verticalDistance)

				-- Client-owned lobby ball: never credit more distance than
				-- the legal lobby speed allows (+ small tolerance), so a
				-- teleporting or speed-hacked ball cannot farm XP.
				if ball:GetAttribute("ClientDriven") == true then
					distance = math.min(
						distance,
						LOBBY_SPEED * 1.5 * deltaTime + 0.1
					)
				end

				-- Standing on a generator you qualify for still earns XP,
				-- at the rate of rolling at lobby speed. Server-side only.
				local idleDistance = LOBBY_SPEED * deltaTime
				if distance < idleDistance then
					local _, standingGenerator =
						getActiveGeneratorMultiplier(player, ball)
					if standingGenerator then
						distance = idleDistance
					end
				end

				if distance > 0
					and distance <= MAX_XP_DISTANCE_PER_HEARTBEAT then

					xpDistanceBuffer[player] =
						(xpDistanceBuffer[player] or 0)
						+ distance

					local xpPerStud =
						BASE_XP_PER_STUD
						* (getForwardSpeed(ball) / 50)

					if isFiniteNumber(xpPerStud)
						and xpPerStud > 0 then

						local availableXP = math.floor(
							xpDistanceBuffer[player] * xpPerStud
						)

						local wholeXP =
							math.floor(
								availableXP / XP_AWARD_CHUNK
							) * XP_AWARD_CHUNK

						if wholeXP >= XP_AWARD_CHUNK then

							--------------------------------------------------
-- VALIDATED REBIRTH + GENERATOR MULTIPLIERS
--------------------------------------------------

local rebirthMultiplier =
    getRebirthXPMultiplier(player)

local generatorMultiplier, generatorName =
    getActiveGeneratorMultiplier(player, ball)

-- Silent Game Pass XP bonus: it ADDS to the rebirth bonus (rebirth +4600% and a
-- x240 pass = +4600% + 23900%), it no longer multiplies it. The generator
-- number still multiplies the combined bonus, like before.
rebirthMultiplier = rebirthMultiplier + GamePassService.GetSecretBonus(player)

-- Tutorial (steps 1-3): rolling around freely earns practically nothing, so the
-- first level-up comes from the X1 generator the tutorial points at.
if not generatorName and (player:GetAttribute("TutorialStep") or 12) <= 3 then
    generatorMultiplier *= 0.0001
end

player:SetAttribute(
    "ActiveXPGenerator",
    generatorName or ""
)

local awardedXP = math.floor(
    wholeXP
        * rebirthMultiplier
        * generatorMultiplier
        * (BoostService.XPMultiplier(player)) -- timed x4 XP boost (reward)
)

							if awardedXP > 0 then

								local success, why =
									PlayerDataService.AddXP(
										player,
										awardedXP
									)

								-- At the rebirth cap no XP is added, but the player must still SEE the
								-- XP arrive (and the meter shake) so they know a rebirth is required.
								-- The client only displays this; nothing is granted.
								if not success and why == "CAPPED" then
									xpAward:FireClient(
										player,
										awardedXP
									)

									xpDistanceBuffer[player] -=
										wholeXP / xpPerStud
								end

								if success then

									xpAward:FireClient(
										player,
										awardedXP
									)

									xpDistanceBuffer[player] -=
										wholeXP / xpPerStud

								end
							end
						end
					end
				end
			end


			unstickLobbyBall(player, ball, runState, input, previousPosition, currentPosition, deltaTime)

			lastBallPositions[player] =
				currentPosition


			--------------------------------------------------
			-- CONTROLLER
			--------------------------------------------------

			local controller =
				getLinearVelocity(
					ball
				)


			if not controller then

				continue

			end


			--------------------------------------------------
-- WAITING / STARTING: LOBBY MOVEMENT
--------------------------------------------------

if runState == "Waiting"
	or runState == "Starting" then

	controller.Enabled = true

	ballSpeeds[ball] = COURSE_START_SPEED

	-- Client-owned lobby ball: the owning client drives the velocity
	-- (BallController). Writing it here would fight the client.
	if not (runState == "Waiting"
		and ball:GetAttribute("ClientDriven") == true) then

		controller.VectorVelocity = Vector3.new(
			input.X * LOBBY_SPEED,
			0,
			input.Y * LOBBY_SPEED
		)

	end


			--------------------------------------------------
			-- RUNNING
			--------------------------------------------------

			elseif runState == "Running" then

				controller.Enabled =
					true


				--------------------------------------------------
				-- TARGET SPEEDS
				--------------------------------------------------

				-- On the oil course the raw ball stats (50..150 studs/s) were far too
				-- fast to read and dodge the platform rows (42 studs apart). They are
				-- mapped onto a playable band that still rewards faster balls:
				-- forward 58 -> 110 studs/s, steering 52 -> 78 studs/s. BallDefinitions
				-- (and everything else that reads them) are unchanged.
				-- Every ball starts at the same steady pace (COURSE_CRUISE_SPEED) and
				-- then speeds up SLOWLY during the roll; faster balls ramp quicker
				-- and to a higher cap, so the difference shows over the run instead
				-- of the fast balls blasting through the rows from the first second.
				local tier = math.clamp((getForwardSpeed(ball) - 50) / 100, 0, 1)
				local targetForwardSpeed =
					COURSE_CRUISE_SPEED + tier * 30 -- 52 .. 82 studs/s
				local rollAcceleration = 1.2 + tier * 3.3 -- studs/s per second after reaching cruise

				local targetHorizontalSpeed =
					52 + math.clamp(getHorizontalSpeed(ball) - 50, 0, 100) * 0.26


				--------------------------------------------------
				-- CURRENT SPEED
				--------------------------------------------------

				local currentSpeed =
					ballSpeeds[ball]


				if not isFiniteNumber(
					currentSpeed
				)
					or currentSpeed <= 0 then

					currentSpeed =
						COURSE_START_SPEED

				end


				--------------------------------------------------
				-- ACCELERATION
				--------------------------------------------------

				-- quick, smooth ramp up to cruise; slow, ball-dependent ramp after
				local rate = currentSpeed < COURSE_CRUISE_SPEED and COURSE_ACCELERATION or rollAcceleration
				currentSpeed =
					math.min(
						currentSpeed
						+
						rate
						*
						deltaTime,

						math.max(targetForwardSpeed, math.min(currentSpeed, COURSE_CRUISE_SPEED))
					)


				currentSpeed =
					math.max(
						currentSpeed,
						MIN_COURSE_SPEED
					)


				ballSpeeds[ball] =
					currentSpeed


				--------------------------------------------------
				-- HORIZONTAL SPEED
				--------------------------------------------------

				local horizontalRatio =
					targetHorizontalSpeed
					/
					math.max(
						targetForwardSpeed,
						0.001
					)


				-- Steering is decoupled from the forward ramp (it used to scale with
				-- the current forward speed, so the first second felt sluggish) and
				-- eased toward the pressed direction in a few frames: crisp, no jerk.
				local desiredLateral = -input.X * targetHorizontalSpeed
				local lateral = ballLateral[ball] or 0
				lateral += (desiredLateral - lateral) * (1 - math.exp(-22 * deltaTime))
				ballLateral[ball] = lateral

				controller.VectorVelocity =
					Vector3.new(lateral, 0, currentSpeed)
				-- The lane is flat, so the ball never needs to move UP. Rolling a
				-- mesh ball at speed made it micro-hop ("dribble"); cancelling any
				-- upward velocity keeps it on the floor. Falling is untouched.
				local assemblyVelocity =
					ball.AssemblyLinearVelocity

				if assemblyVelocity.Y > 0 then
					ball.AssemblyLinearVelocity =
						Vector3.new(
							assemblyVelocity.X,
							0,
							assemblyVelocity.Z
						)
				end

			--------------------------------------------------
			-- UNKNOWN STATE
			--------------------------------------------------

			else

				stopBall(
					ball
				)

			end

		end

	end
)


--------------------------------------------------
-- PLAYER CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(
		player
	)

		lastJumpTimes[player] = nil
		playerInputs[player] =
			nil

		lastBallPositions[player] =
			nil

		xpDistanceBuffer[player] =
			nil

		player:SetAttribute("ActiveXPGenerator", nil)

	end
)


--------------------------------------------------
-- BALL CLEANUP
--------------------------------------------------

playerBalls.ChildRemoved:Connect(
	function(
		ball
	)

		ballScaleState[ball] = nil
		ballControllers[ball] =
			nil

		ballSpeeds[ball] =
			nil

		releasedBalls[ball] =
			nil

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")

print(
	"[BallPhysicsController]",
	"SERVER READY"
)

print(
	"[BallPhysicsController]",
	"Movement Owner = SERVER"
)

print(
	"[BallPhysicsController]",
	"Network Owner = SERVER"
)

print(
	"[BallPhysicsController]",
	"Lobby Speed =",
	LOBBY_SPEED
)

print(
	"[BallPhysicsController]",
	"Course Start Speed =",
	COURSE_START_SPEED
)

print(
	"[BallPhysicsController]",
	"Course Acceleration =",
	COURSE_ACCELERATION
)

print(
	"[BallPhysicsController]",
	"Input Timeout =",
	INPUT_TIMEOUT
)

print("================================")
