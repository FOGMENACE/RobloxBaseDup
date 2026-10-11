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
-- SETTINGS
--------------------------------------------------

local LOBBY_SPEED =
	24

local COURSE_START_SPEED =
	10

local COURSE_ACCELERATION =
	12

local MIN_COURSE_SPEED =
	6

local INPUT_TIMEOUT =
	0.20

local BASE_XP_PER_STUD =
	0.5

local XP_AWARD_CHUNK =
	4

local MAX_XP_DISTANCE_PER_HEARTBEAT =
	10


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

		return definition.ForwardSpeed

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

	controller.MaxForce =
		math.huge

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

local function ensureServerOwnership(ball)

	if not ball or not ball.Parent then
		return
	end

	-- WinCourse may manage its own physics while active.
	-- This controller must not override it during that time.
	if ball:GetAttribute("WinCourseActive") == true then
		return
	end

	pcall(function()
		if ball:GetNetworkOwner() ~= nil then
			ball:SetNetworkOwner(nil)
		end
	end)

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

	ballSpeeds[ball] =
		COURSE_START_SPEED


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
-- MOVEMENT INPUT
--------------------------------------------------

ballMovement.OnServerEvent:Connect(
	function(
		player,
		input
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
ensureServerOwnership(ball)

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
				ball
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

				local currentXZ =
					Vector3.new(
						currentPosition.X,
						0,
						currentPosition.Z
					)


				local previousXZ =
					Vector3.new(
						previousPosition.X,
						0,
						previousPosition.Z
					)


				local distance =
					(
						currentXZ
						-
						previousXZ
					).Magnitude


				if distance > 0
					and distance
						<= MAX_XP_DISTANCE_PER_HEARTBEAT then

					xpDistanceBuffer[player] =
						(
							xpDistanceBuffer[player]
							or 0
						)
						+
						distance


					local xpPerStud =
						BASE_XP_PER_STUD
						*
						(
							getForwardSpeed(
								ball
							)
							/
							50
						)


					if isFiniteNumber(
						xpPerStud
					)
						and xpPerStud > 0 then

						local availableXP =
							math.floor(
								xpDistanceBuffer[player]
								*
								xpPerStud
							)


						local wholeXP =
							math.floor(
								availableXP
								/
								XP_AWARD_CHUNK
							)
							*
							XP_AWARD_CHUNK


						if wholeXP >=
							XP_AWARD_CHUNK then

							local success =
								PlayerDataService.AddXP(
									player,
									wholeXP
								)


							if success then

								xpDistanceBuffer[player] -=
									wholeXP
									/
									xpPerStud

							end

						end

					end

				end

			end


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

	controller.VectorVelocity = Vector3.new(
		input.X * LOBBY_SPEED,
		0,
		input.Y * LOBBY_SPEED
	)


			--------------------------------------------------
			-- RUNNING
			--------------------------------------------------

			elseif runState == "Running" then

				controller.Enabled =
					true


				--------------------------------------------------
				-- TARGET SPEEDS
				--------------------------------------------------

				local targetForwardSpeed =
					getForwardSpeed(
						ball
					)


				local targetHorizontalSpeed =
					getHorizontalSpeed(
						ball
					)


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

				currentSpeed =
					math.min(
						currentSpeed
						+
						COURSE_ACCELERATION
						*
						deltaTime,

						targetForwardSpeed
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


				local currentHorizontalSpeed =
					math.min(
						currentSpeed
						*
						horizontalRatio,

						targetHorizontalSpeed
					)


				--------------------------------------------------
				-- SERVER VELOCITY
				--------------------------------------------------

				controller.VectorVelocity =
	Vector3.new(
		-input.X
			*
			currentHorizontalSpeed,

		0,

		currentSpeed
	)

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

		playerInputs[player] =
			nil

		lastBallPositions[player] =
			nil

		xpDistanceBuffer[player] =
			nil

	end
)


--------------------------------------------------
-- BALL CLEANUP
--------------------------------------------------

playerBalls.ChildRemoved:Connect(
	function(
		ball
	)

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