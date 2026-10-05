local Players =
	game:GetService("Players")

local UserInputService =
	game:GetService("UserInputService")

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
-- PLAYER BALLS
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)


--------------------------------------------------
-- CAMERA BIND
--------------------------------------------------

local CAMERA_BIND_NAME =
	"BallCamera"


--------------------------------------------------
-- CAMERA SETTINGS
--------------------------------------------------

--------------------------------------------------
-- LOBBY CAMERA
--------------------------------------------------

local LOBBY_DISTANCE =
	18

local LOBBY_HEIGHT =
	8


--------------------------------------------------
-- RUN CAMERA
--
-- IMPORTANT:
--
-- REGULAR COURSE AND WINCOURSE USE THE EXACT
-- SAME CAMERA SETTINGS.
--
-- There is only ONE set of Run Camera values.
--------------------------------------------------

local RUN_DISTANCE =
	16

local RUN_HEIGHT =
	14

local RUN_LOOK_AHEAD =
	20

local RUN_LOOK_HEIGHT =
	4


--------------------------------------------------
-- WORLD FORWARD
--
-- EVERYTHING IN THIS SYSTEM USES +Z.
--------------------------------------------------

local WORLD_FORWARD =
	Vector3.new(
		0,
		0,
		1
	)


--------------------------------------------------
-- ORBIT STATE
--------------------------------------------------

local yaw =
	0

local pitch =
	math.rad(-15)


local MIN_PITCH =
	math.rad(-70)

local MAX_PITCH =
	math.rad(35)


local rotating =
	false

local lastMousePosition =
	nil


--------------------------------------------------
-- CAMERA MODE
--
-- Waiting:
--     Lobby
--
-- Starting:
--     Lobby
--
-- Running:
--     Run
--
-- Finishing:
--     Run
--
-- REGULAR COURSE AND WINCOURSE BOTH USE
-- THE SAME RUN CAMERA.
--------------------------------------------------

local cameraMode =
	"Lobby"


--------------------------------------------------
-- FINISH CAMERA LOCK
--
-- IMPORTANT:
--
-- When FinishWall is touched, RunState changes
-- to "Finishing" and StartWinCourse can move the
-- ball.
--
-- We DO NOT allow that movement to pull the
-- camera downward.
--
-- The camera captures its current Y position
-- when Finishing begins and keeps that Y value
-- during the WinCourse transition.
--------------------------------------------------

local finishCameraY =
	nil

local previousRunState =
	nil


--------------------------------------------------
-- GET PLAYER BALL
--------------------------------------------------

local function getBall()

	return playerBalls:FindFirstChild(
		"PlayerBall_" ..
		player.UserId
	)

end


--------------------------------------------------
-- CAMERA INPUT
--------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)

		if gameProcessed then
			return
		end

		if input.UserInputType ==
			Enum.UserInputType.MouseButton2 then

			rotating =
				true

			lastMousePosition =
				UserInputService:GetMouseLocation()

		end

	end
)


UserInputService.InputEnded:Connect(
	function(input)

		if input.UserInputType ==
			Enum.UserInputType.MouseButton2 then

			rotating =
				false

			lastMousePosition =
				nil

		end

	end
)


UserInputService.InputChanged:Connect(
	function(input)

		if not rotating then
			return
		end

		if input.UserInputType ~=
			Enum.UserInputType.MouseMovement then

			return

		end

		local currentMousePosition =
			UserInputService:GetMouseLocation()

		if not lastMousePosition then

			lastMousePosition =
				currentMousePosition

			return

		end

		local delta =
			currentMousePosition
			-
			lastMousePosition

		lastMousePosition =
			currentMousePosition


		--------------------------------------------------
		-- HORIZONTAL
		--------------------------------------------------

		yaw -=
			delta.X * 0.005


		--------------------------------------------------
		-- VERTICAL
		--------------------------------------------------

		pitch -=
			delta.Y * 0.005

		pitch =
			math.clamp(
				pitch,
				MIN_PITCH,
				MAX_PITCH
			)

	end
)


--------------------------------------------------
-- LOBBY CAMERA
--
-- BALL FACES +Z
--
-- CAMERA SITS BEHIND BALL ON -Z
--
-- CAMERA LOOKS TOWARD +Z
--------------------------------------------------

local function updateLobbyCamera(ball)

	camera.CameraType =
		Enum.CameraType.Scriptable


	--------------------------------------------------
	-- CAMERA BEHIND BALL
	--------------------------------------------------

	local cameraPosition =
		ball.Position
		+
		Vector3.new(
			0,
			LOBBY_HEIGHT,
			-LOBBY_DISTANCE
		)


	--------------------------------------------------
	-- LOOK FORWARD IN +Z
	--------------------------------------------------

	local lookTarget =
		ball.Position
		+
		Vector3.new(
			0,
			1,
			20
		)


	--------------------------------------------------
	-- APPLY CAMERA
	--------------------------------------------------

	camera.CFrame =
		CFrame.lookAt(
			cameraPosition,
			lookTarget,
			Vector3.new(
				0,
				1,
				0
			)
		)

end


--------------------------------------------------
-- RUN CAMERA
--
-- REGULAR COURSE + WINCOURSE
--
-- SAME CAMERA.
--
-- The only special behavior is that during
-- Finishing we lock the CAMERA'S Y position.
--
-- This prevents the WinCourse ball teleport from
-- making the camera drop.
--------------------------------------------------

local function updateRunCamera(ball)

	camera.CameraType =
		Enum.CameraType.Scriptable


	--------------------------------------------------
	-- GET CURRENT RUN STATE
	--------------------------------------------------

	local runState =
		player:GetAttribute(
			"RunState"
		)


	--------------------------------------------------
	-- ENTERING FINISHING
	--
	-- Capture the camera height BEFORE WinCourse
	-- has a chance to move the ball.
	--------------------------------------------------

	if runState ==
		"Finishing"
		and previousRunState ~=
			"Finishing" then

		finishCameraY =
			ball.Position.Y +
			RUN_HEIGHT

	end


	--------------------------------------------------
	-- REGULAR COURSE
	--
	-- Clear the finish lock.
	--------------------------------------------------

	if runState ~=
		"Finishing" then

		finishCameraY =
			nil

	end


	--------------------------------------------------
	-- CAMERA Y
	--------------------------------------------------

	local cameraY =
		ball.Position.Y +
		RUN_HEIGHT


	--------------------------------------------------
	-- FINISHING:
	--
	-- Keep the camera at the height captured when
	-- FinishWall was reached.
	--------------------------------------------------

	if runState ==
		"Finishing"
		and finishCameraY ~= nil then

		cameraY =
			finishCameraY

	end


	--------------------------------------------------
	-- CAMERA POSITION
	--
	-- X/Z continue following the ball.
	--
	-- Y stays locked during WinCourse.
	--------------------------------------------------

	local cameraPosition =
		Vector3.new(
			ball.Position.X,
			cameraY,
			ball.Position.Z - RUN_DISTANCE
		)


	--------------------------------------------------
	-- LOOK TARGET
	--
	-- Keep the same vertical relationship for both
	-- Regular Course and WinCourse.
	--------------------------------------------------

	local lookTargetY

	if runState ==
		"Finishing"
		and finishCameraY ~= nil then

		lookTargetY =
			finishCameraY
			-
			RUN_HEIGHT
			+
			RUN_LOOK_HEIGHT

	else

		lookTargetY =
			ball.Position.Y
			+
			RUN_LOOK_HEIGHT

	end


	local lookTarget =
		Vector3.new(
			ball.Position.X,
			lookTargetY,
			ball.Position.Z + RUN_LOOK_AHEAD
		)


	--------------------------------------------------
	-- APPLY CAMERA
	--------------------------------------------------

	camera.CFrame =
		CFrame.lookAt(
			cameraPosition,
			lookTarget,
			Vector3.new(
				0,
				1,
				0
			)
		)


	--------------------------------------------------
	-- REMEMBER STATE
	--------------------------------------------------

	previousRunState =
		runState

end


--------------------------------------------------
-- UPDATE CAMERA MODE
--------------------------------------------------

local function updateCameraMode()

	--------------------------------------------------
	-- GET BALL
	--------------------------------------------------

	local ball =
		getBall()

	--------------------------------------------------
	-- WIN COURSE HAS PRIORITY
	--
	-- This is checked FIRST.
	--
	-- Even if another script changes RunState to:
	--
	-- "Bonus"
	-- "Finishing"
	-- "Completed"
	-- etc.
	--
	-- the WinCourse camera remains the Run camera.
	--------------------------------------------------

	if ball
		and ball:GetAttribute(
			"WinCourseActive"
		) == true then

		cameraMode =
			"Run"

		return

	end


	--------------------------------------------------
	-- NORMAL RUN STATE
	--------------------------------------------------

	local runState =
		player:GetAttribute(
			"RunState"
		)


	--------------------------------------------------
	-- WAITING
	--------------------------------------------------

	if runState == "Waiting" then

		cameraMode =
			"Lobby"

		return

	end


	--------------------------------------------------
	-- STARTING
	--------------------------------------------------

	if runState == "Starting" then

		cameraMode =
			"Lobby"

		return

	end


	--------------------------------------------------
	-- RUNNING
	--------------------------------------------------

	if runState == "Running" then

		cameraMode =
			"Run"

		return

	end


	--------------------------------------------------
	-- FINISHING
	--------------------------------------------------

	if runState == "Finishing" then

		cameraMode =
			"Run"

		return

	end


	--------------------------------------------------
	-- BONUS
	--------------------------------------------------

	if runState == "Bonus" then

		cameraMode =
			"Run"

		return

	end


	--------------------------------------------------
	-- UNKNOWN
	--------------------------------------------------

	cameraMode =
		"Lobby"

end

--------------------------------------------------
-- UPDATE CAMERA
--------------------------------------------------

local function updateCamera()

	local ball =
		getBall()

	if not ball then
		return
	end


	--------------------------------------------------
	-- UPDATE MODE
	--------------------------------------------------

	updateCameraMode()


	--------------------------------------------------
	-- LOBBY
	--------------------------------------------------

	if cameraMode ==
		"Lobby" then

		updateLobbyCamera(
			ball
		)

		return

	end


	--------------------------------------------------
	-- RUN
	--
	-- BOTH REGULAR COURSE AND WINCOURSE USE THIS.
	--------------------------------------------------

	if cameraMode ==
		"Run" then

		updateRunCamera(
			ball
		)

		return

	end

end


--------------------------------------------------
-- RENDER UPDATE
--------------------------------------------------

RunService:BindToRenderStep(
	CAMERA_BIND_NAME,
	Enum.RenderPriority.Camera.Value + 1,
	updateCamera
)
