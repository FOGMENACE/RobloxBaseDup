--------------------------------------------------
-- BALL VISUAL CONTROLLER
--
-- CLIENT ONLY
--
-- LOCATION:
-- StarterPlayer
--     > StarterPlayerScripts
--
-- PURPOSE:
--
-- Handles CLIENT-SIDE visual effects for the ball.
--
-- IMPORTANT:
--
-- THIS SCRIPT DOES NOT:
--
-- - Set AssemblyLinearVelocity
-- - Set AssemblyAngularVelocity
-- - Set NetworkOwnership
-- - Fire movement commands
-- - Control LinearVelocity
-- - Move the ball physically
--
-- BallPhysicsController owns ALL actual physics.
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local RunService =
	game:GetService("RunService")

local Players =
	game:GetService("Players")


--------------------------------------------------
-- PLAYER
--------------------------------------------------

local player =
	Players.LocalPlayer


--------------------------------------------------
-- PLAYER BALL FOLDER
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)


--------------------------------------------------
-- BALL NAME
--------------------------------------------------

local ballName =
	"PlayerBall_"
		..
		tostring(
			player.UserId
		)


--------------------------------------------------
-- STATE
--------------------------------------------------

local ball = nil

local lastVelocity =
	Vector3.zero

local lastPosition =
	nil


--------------------------------------------------
-- VISUAL SETTINGS
--------------------------------------------------

local MIN_ROLL_SPEED =
	0.1

local MAX_ROLL_SPEED =
	200

local POSITION_EPSILON =
	0.001


--------------------------------------------------
-- FIND BALL
--------------------------------------------------

local function findBall()

	local foundBall =
		playerBalls:FindFirstChild(
			ballName
		)


	if foundBall
		and foundBall:IsA("BasePart") then

		return foundBall

	end


	return nil

end


--------------------------------------------------
-- WAIT FOR BALL
--------------------------------------------------

local function updateBallReference()

	local newBall =
		findBall()


	if newBall == ball then

		return

	end


	ball =
		newBall


	lastVelocity =
		Vector3.zero

	lastPosition =
		ball
		and ball.Position
		or nil


	if ball then

		print(
			"[BallVisualController]",
			"Tracking:",
			ball:GetFullName()
		)

	end

end


--------------------------------------------------
-- BALL CREATED / REMOVED
--------------------------------------------------

playerBalls.ChildAdded:Connect(
	function(child)

		if child.Name ==
			ballName then

			updateBallReference()

		end

	end
)


playerBalls.ChildRemoved:Connect(
	function(child)

		if child == ball then

			ball =
				nil

			lastVelocity =
				Vector3.zero

			lastPosition =
				nil

		end

	end
)


--------------------------------------------------
-- VISUAL VELOCITY
--
-- We READ the server physics.
--
-- We NEVER write physics.
--------------------------------------------------

local function getVisualVelocity()

	if not ball
		or not ball.Parent then

		return Vector3.zero

	end


	local velocity =
		ball.AssemblyLinearVelocity


	if typeof(velocity)
		~= "Vector3" then

		return Vector3.zero

	end


	if velocity.X ~= velocity.X
		or velocity.Y ~= velocity.Y
		or velocity.Z ~= velocity.Z then

		return Vector3.zero

	end


	if velocity.Magnitude >
		MAX_ROLL_SPEED then

		velocity =
			velocity.Unit
			*
			MAX_ROLL_SPEED

	end


	return velocity

end


--------------------------------------------------
-- VISUAL UPDATE
--------------------------------------------------

RunService.RenderStepped:Connect(
	function(deltaTime)

		--------------------------------------------------
		-- BALL REFERENCE
		--------------------------------------------------

		updateBallReference()


		if not ball
			or not ball.Parent then

			return

		end


		--------------------------------------------------
		-- READ SERVER VELOCITY
		--------------------------------------------------

		local velocity =
			getVisualVelocity()


		--------------------------------------------------
		-- HORIZONTAL VELOCITY
		--------------------------------------------------

		local horizontalVelocity =
			Vector3.new(
				velocity.X,
				0,
				velocity.Z
			)


		--------------------------------------------------
		-- STORE VELOCITY
		--
		-- This is useful for visual systems such as:
		--
		-- - rolling sounds
		-- - trails
		-- - particles
		-- - camera effects
		--
		-- It does NOT modify physics.
		--------------------------------------------------

		lastVelocity =
			horizontalVelocity


		--------------------------------------------------
		-- POSITION TRACKING
		--------------------------------------------------

		local currentPosition =
			ball.Position


		if lastPosition then

			local positionDelta =
				currentPosition
				-
				lastPosition


			if positionDelta.Magnitude >
				POSITION_EPSILON then

				-- Server physics moved the ball.
				--
				-- Do NOT modify the ball here.
				--
				-- The physical ball remains completely
				-- server controlled.

			end

		end


		lastPosition =
			currentPosition


		--------------------------------------------------
		-- FUTURE VISUAL EFFECTS
		--------------------------------------------------
		--
		-- Put client-only effects here.
		--
		-- Example:
		--
		-- rollingSound.Volume =
		--     math.clamp(
		--         horizontalVelocity.Magnitude / 50,
		--         0,
		--         1
		--     )
		--
		-- rollingSound.PlaybackSpeed =
		--     0.8
		--     +
		--     math.clamp(
		--         horizontalVelocity.Magnitude / 100,
		--         0,
		--         1
		--     )
		--
		-- IMPORTANT:
		--
		-- Do not write:
		--
		-- ball.CFrame
		-- ball.Position
		-- ball.AssemblyLinearVelocity
		-- ball.AssemblyAngularVelocity
		--
		--------------------------------------------------

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

updateBallReference()


print(
	"[BallVisualController]",
	"CLIENT READY"
)

print(
	"[BallVisualController]",
	"Physics writes:",
	"DISABLED"
)

print(
	"[BallVisualController]",
	"AssemblyLinearVelocity:",
	"READ ONLY"
)

print(
	"[BallVisualController]",
	"AssemblyAngularVelocity:",
	"NOT USED"
)

print(
	"[BallVisualController]",
	"Movement owner:",
	"BallPhysicsController"
)