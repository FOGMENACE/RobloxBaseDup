--------------------------------------------------
-- BALL CONTROLLER
--
-- CLIENT ONLY
--
-- LOCATION:
-- StarterPlayer
--   > StarterPlayerScripts
--
-- PURPOSE:
--
-- Reads player movement intent and sends it to the
-- server.
--
-- THIS SCRIPT NEVER:
--
-- - Moves the ball
-- - Sets velocity
-- - Changes physics
-- - Changes network ownership
--
-- SERVER OWNS ACTUAL BALL MOVEMENT.
--
-- LOBBY:
--     Camera-relative X/Z movement.
--
-- COURSE:
--     Left/right only.
--     Forward movement is server-controlled.
--
-- FINISHING / WIN COURSE:
--     No normal movement input.
--
-- INPUT:
--
--     Immediate packet on input change.
--     60 Hz synchronization while active.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local UserInputService =
	game:GetService("UserInputService")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local RunService =
	game:GetService("RunService")


--------------------------------------------------
-- PLAYER
--------------------------------------------------

local player =
	Players.LocalPlayer


--------------------------------------------------
-- CAMERA
--------------------------------------------------

local camera =
	workspace.CurrentCamera


--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)

local ballMovement =
	remotes:WaitForChild(
		"BallMovement"
	)


--------------------------------------------------
-- INPUT STATE
--------------------------------------------------

local inputX = 0
local inputZ = 0


--------------------------------------------------
-- SEND RATE
--
-- 60 Hz keeps the server supplied with very
-- current input without going back to an
-- unrestricted every-frame RemoteEvent loop.
--------------------------------------------------

local SEND_INTERVAL =
	1 / 60

local sendAccumulator =
	0


--------------------------------------------------
-- MOVEMENT KEY CHECK
--------------------------------------------------

local function isMovementKey(
	keyCode
)

	return keyCode == Enum.KeyCode.W
		or keyCode == Enum.KeyCode.A
		or keyCode == Enum.KeyCode.S
		or keyCode == Enum.KeyCode.D
		or keyCode == Enum.KeyCode.Up
		or keyCode == Enum.KeyCode.Left
		or keyCode == Enum.KeyCode.Down
		or keyCode == Enum.KeyCode.Right

end


--------------------------------------------------
-- UPDATE KEY STATE
--------------------------------------------------

local function updateKeys()

	local x = 0
	local z = 0


	--------------------------------------------------
	-- LEFT
	--------------------------------------------------

	if UserInputService:IsKeyDown(
		Enum.KeyCode.A
	)
	or UserInputService:IsKeyDown(
		Enum.KeyCode.Left
	) then

		x -= 1

	end


	--------------------------------------------------
	-- RIGHT
	--------------------------------------------------

	if UserInputService:IsKeyDown(
		Enum.KeyCode.D
	)
	or UserInputService:IsKeyDown(
		Enum.KeyCode.Right
	) then

		x += 1

	end


	--------------------------------------------------
	-- FORWARD
	--------------------------------------------------

	if UserInputService:IsKeyDown(
		Enum.KeyCode.W
	)
	or UserInputService:IsKeyDown(
		Enum.KeyCode.Up
	) then

		z += 1

	end


	--------------------------------------------------
	-- BACKWARD
	--------------------------------------------------

	if UserInputService:IsKeyDown(
		Enum.KeyCode.S
	)
	or UserInputService:IsKeyDown(
		Enum.KeyCode.Down
	) then

		z -= 1

	end


	inputX = x
	inputZ = z

end


--------------------------------------------------
-- GET RUN STATE
--------------------------------------------------

local function getRunState()

	return player:GetAttribute(
		"RunState"
	)

end

local function debugRunState()
    print(
        "[BallController] Current RunState:",
        player:GetAttribute("RunState")
    )
end

--------------------------------------------------
-- GET LOBBY MOVEMENT
--
-- Camera-relative movement.
--
-- W = camera forward
-- S = camera backward
-- A = camera left
-- D = camera right
--------------------------------------------------

local function getLobbyMovement()

	local cameraCFrame =
		camera.CFrame


	--------------------------------------------------
	-- CAMERA FORWARD
	--------------------------------------------------

	local forward =
		Vector3.new(
			cameraCFrame.LookVector.X,
			0,
			cameraCFrame.LookVector.Z
		)


	--------------------------------------------------
	-- CAMERA RIGHT
	--------------------------------------------------

	local right =
		Vector3.new(
			cameraCFrame.RightVector.X,
			0,
			cameraCFrame.RightVector.Z
		)


	--------------------------------------------------
	-- SAFETY
	--------------------------------------------------

	if forward.Magnitude >
		0.001 then

		forward =
			forward.Unit

	else

		forward =
			Vector3.new(
				0,
				0,
				-1
			)

	end


	if right.Magnitude >
		0.001 then

		right =
			right.Unit

	else

		right =
			Vector3.new(
				1,
				0,
				0
			)

	end


	--------------------------------------------------
	-- COMBINE
	--------------------------------------------------

	local movement =
		(
			right * inputX
		)
		+
		(
			forward * inputZ
		)


	--------------------------------------------------
	-- NORMALIZE
	--------------------------------------------------

	if movement.Magnitude >
		1 then

		movement =
			movement.Unit

	end


	return Vector2.new(
		movement.X,
		movement.Z
	)

end


--------------------------------------------------
-- GET COURSE MOVEMENT
--
-- Course only uses left/right.
--
-- Forward movement is server-owned.
--------------------------------------------------

local function getCourseMovement()

	return Vector2.new(
		math.clamp(
			inputX,
			-1,
			1
		),
		0
	)

end


--------------------------------------------------
-- GET CURRENT MOVEMENT
--------------------------------------------------

local function getCurrentMovement()

	local runState =
		getRunState()


	--------------------------------------------------
	-- LOBBY / STARTING
	--
	-- Both states use normal camera-relative
	-- movement.
	--------------------------------------------------

	if runState == "Waiting"
		or runState == "Starting" then

		return getLobbyMovement()

	end


	--------------------------------------------------
	-- RUNNING
	--
	-- Course movement is left/right only.
	--------------------------------------------------

	if runState == "Running" then

		return getCourseMovement()

	end


	--------------------------------------------------
	-- FINISHING / WIN COURSE
	--
	-- Server owns the ball from this point.
	--------------------------------------------------

	if runState == "Finishing" then

		return nil

	end


	--------------------------------------------------
	-- UNKNOWN STATE
	--------------------------------------------------

	warn(
		"[BallController]",
		"Movement blocked because RunState is:",
		runState
	)

	return nil

end


--------------------------------------------------
-- SEND MOVEMENT
--------------------------------------------------

local function sendMovement()

	local movement =
		getCurrentMovement()

	if movement == nil then

		return

	end

	print(
		"[BallController]",
		"Sending movement:",
		movement,
		"RunState:",
		getRunState()
	)

	ballMovement:FireServer(
		movement
	)

end


--------------------------------------------------
-- INPUT CHANGED
--
-- Immediate update.
--
-- There is NO intentional delay here.
--------------------------------------------------

local function processInputChange()

	updateKeys()

	sendMovement()

	debugRunState()

end


--------------------------------------------------
-- INPUT BEGAN
--------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)

	--------------------------------------------------
	-- Ignore chat / UI / Roblox controls.
	--------------------------------------------------

	if gameProcessed then

		return

	end


	--------------------------------------------------
	-- Keyboard only.
	--------------------------------------------------

	if input.UserInputType
		~= Enum.UserInputType.Keyboard then

		return

	end


	--------------------------------------------------
	-- Ignore unrelated keys.
	--------------------------------------------------

	if not isMovementKey(
		input.KeyCode
	) then

		return

	end


	--------------------------------------------------
	-- SEND IMMEDIATELY.
	--------------------------------------------------

	processInputChange()

end)


--------------------------------------------------
-- INPUT ENDED
--------------------------------------------------

UserInputService.InputEnded:Connect(
	function(
		input
	)

	--------------------------------------------------
	-- Keyboard only.
	--------------------------------------------------

	if input.UserInputType
		~= Enum.UserInputType.Keyboard then

		return

	end


	--------------------------------------------------
	-- Ignore unrelated keys.
	--------------------------------------------------

	if not isMovementKey(
		input.KeyCode
	) then

		return

	end


	--------------------------------------------------
	-- SEND IMMEDIATELY.
	--------------------------------------------------

	processInputChange()

end)


--------------------------------------------------
-- CONTINUOUS SYNCHRONIZATION
--
-- 60 Hz.
--
-- This is only synchronization.
-- It does NOT control physics locally.
--------------------------------------------------

RunService.RenderStepped:Connect(
	function(deltaTime)

		if typeof(deltaTime) ~= "number"
			or deltaTime <= 0 then

			return

		end


		sendAccumulator +=
			deltaTime


		if sendAccumulator <
			SEND_INTERVAL then

			return

		end


		--------------------------------------------------
		-- Consume one interval.
		--------------------------------------------------

		sendAccumulator -=
			SEND_INTERVAL


		--------------------------------------------------
		-- Prevent accumulator runaway after a
		-- frame hitch.
		--------------------------------------------------

		if sendAccumulator >
			SEND_INTERVAL then

			sendAccumulator =
				0

		end


		--------------------------------------------------
		-- Refresh actual keyboard state.
		--------------------------------------------------

		updateKeys()


		--------------------------------------------------
		-- Send latest intent.
		--------------------------------------------------

		sendMovement()

	end
)


--------------------------------------------------
-- WINDOW FOCUS LOST
--------------------------------------------------

UserInputService.WindowFocusReleased:Connect(
	function()

		inputX = 0
		inputZ = 0


		local runState =
			getRunState()


		--------------------------------------------------
		-- Explicitly stop normal movement.
		--------------------------------------------------

		if runState == "Waiting"
			or runState == "Running" then

			ballMovement:FireServer(
				Vector2.zero
			)

		end

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"[BallController] CLIENT READY"
)

print(
	"[BallController] Input:",
	"Immediate + 60 Hz"
)

print(
	"[BallController] Waiting:",
	"Camera-relative X/Z"
)

print(
	"[BallController] Running:",
	"Left/right only"
)

print(
	"[BallController] Starting:",
	"No normal movement"
)

print(
	"[BallController] Finishing:",
	"No normal movement"
)

print(
	"[BallController] WinCourse:",
	"No normal movement"
)

print(
	"[BallController] Client physics:",
	"DISABLED"
)