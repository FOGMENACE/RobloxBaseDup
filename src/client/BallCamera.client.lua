--------------------------------------------------
-- BALL CAMERA
-- LocalScript
--
-- LOCATION:
-- StarterPlayer
--     StarterPlayerScripts
--
-- CAMERA RULES
--
-- LOBBY:
--   Right Mouse + mouse movement:
--      Horizontal = orbit left/right
--      Vertical   = orbit up/down
--
--   Mouse Wheel:
--      3 zoom levels
--
-- COURSE:
--   Camera is LOCKED behind the ball.
--   Mouse does NOT rotate the camera.
--   Mouse Wheel does NOT zoom.
--
-- IMPORTANT:
--
-- The lobby camera is a FREE ORBIT CAMERA.
--
-- There is NO camera-floor collision restriction.
-- The camera is allowed to orbit below/above the
-- ball according to the pitch limits.
--
-- The hidden Roblox character is never used.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

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
-- LOBBY CAMERA
--------------------------------------------------

local LOBBY_ZOOM_LEVELS = {

	--------------------------------------------------
	-- CLOSE
	--------------------------------------------------

	{
		distance = 14,
		height = 7,
		fov = 60
	},

	--------------------------------------------------
	-- NORMAL
	--------------------------------------------------

	{
		distance = 18,
		height = 8,
		fov = 70
	},

	--------------------------------------------------
	-- FAR
	--------------------------------------------------

	{
		distance = 24,
		height = 10,
		fov = 80
	}

}


--------------------------------------------------
-- CURRENT LOBBY ZOOM
--------------------------------------------------

local currentLobbyZoom =
	2


--------------------------------------------------
-- LOBBY ORBIT
--------------------------------------------------

local lobbyYaw =
	0

local lobbyPitch =
	math.rad(15)


--------------------------------------------------
-- PITCH LIMITS
--
-- NEGATIVE = camera moves below ball
-- POSITIVE = camera moves above ball
--
-- These are intentionally wide so the player
-- can freely look around the ball.
--------------------------------------------------

local MIN_LOBBY_PITCH =
	math.rad(-80)

local MAX_LOBBY_PITCH =
	math.rad(80)


--------------------------------------------------
-- MOUSE ROTATION
--------------------------------------------------

local rotating =
	false

local lastMousePosition =
	nil


--------------------------------------------------
-- CAMERA SMOOTHING
--------------------------------------------------

local currentCameraPosition =
	nil

local currentLookTarget =
	nil


local CAMERA_SMOOTHNESS =
	12


--------------------------------------------------
-- COURSE CAMERA
--------------------------------------------------
--
-- IMPORTANT:
--
-- These values are fixed.
--
-- The player CANNOT change these with
-- the mouse.
--------------------------------------------------

local COURSE_DISTANCE =
	16

local COURSE_HEIGHT =
	14

local COURSE_LOOK_AHEAD =
	20

local COURSE_LOOK_HEIGHT =
	4

local COURSE_FOV =
	70


--------------------------------------------------
-- GET PLAYER BALL
--------------------------------------------------

local function getBall()

	local ballName =
		"PlayerBall_" ..
		player.UserId


	local ball =
		playerBalls:FindFirstChild(
			ballName
		)


	if ball
		and ball:IsA("BasePart") then

		return ball

	end


	return nil

end


--------------------------------------------------
-- GET CAMERA MODE
--------------------------------------------------

local function getCameraMode(ball)

	--------------------------------------------------
	-- WIN COURSE
	--------------------------------------------------

	if ball:GetAttribute(
		"WinCourseActive"
	) == true then

		return "Course"

	end


	--------------------------------------------------
	-- RUN STATE
	--------------------------------------------------

	local runState =
		player:GetAttribute(
			"RunState"
		)


	if runState == "Running" then

		return "Course"

	end


	if runState == "Finishing" then

		return "Course"

	end


	if runState == "Bonus" then

		return "Course"

	end


	--------------------------------------------------
	-- LOBBY
	--------------------------------------------------

	return "Lobby"

end


--------------------------------------------------
-- MOUSE BUTTON
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

			--------------------------------------------------
			-- ONLY ALLOW CAMERA ROTATION IN LOBBY
			--------------------------------------------------

			local ball =
				getBall()

			if not ball then
				return
			end


			if getCameraMode(ball)
				~= "Lobby" then

				return

			end


			rotating =
				true


			lastMousePosition =
				UserInputService:GetMouseLocation()

		end

	end
)


--------------------------------------------------
-- MOUSE RELEASE
--------------------------------------------------

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


--------------------------------------------------
-- MOUSE WHEEL
--------------------------------------------------

UserInputService.InputChanged:Connect(
	function(input)

		if input.UserInputType ~=
			Enum.UserInputType.MouseWheel then

			return

		end


		--------------------------------------------------
		-- GET BALL
		--------------------------------------------------

		local ball =
			getBall()

		if not ball then
			return
		end


		--------------------------------------------------
		-- ONLY ZOOM IN LOBBY
		--------------------------------------------------

		if getCameraMode(ball)
			~= "Lobby" then

			return

		end


		--------------------------------------------------
		-- ZOOM IN
		--------------------------------------------------

		if input.Position.Z > 0 then

			currentLobbyZoom =
				math.clamp(
					currentLobbyZoom - 1,
					1,
					3
				)

		--------------------------------------------------
		-- ZOOM OUT
		--------------------------------------------------

		elseif input.Position.Z < 0 then

			currentLobbyZoom =
				math.clamp(
					currentLobbyZoom + 1,
					1,
					3
				)

		end

	end
)


--------------------------------------------------
-- MOUSE MOVEMENT
--------------------------------------------------

UserInputService.InputChanged:Connect(
	function(input)

		if not rotating then
			return
		end


		if input.UserInputType ~=
			Enum.UserInputType.MouseMovement then

			return

		end


		--------------------------------------------------
		-- MAKE ABSOLUTELY SURE WE ARE IN LOBBY
		--------------------------------------------------

		local ball =
			getBall()

		if not ball then
			return
		end


		if getCameraMode(ball)
			~= "Lobby" then

			rotating =
				false

			lastMousePosition =
				nil

			return

		end


		--------------------------------------------------
		-- CURRENT MOUSE POSITION
		--------------------------------------------------

		local currentMousePosition =
			UserInputService:GetMouseLocation()


		if not lastMousePosition then

			lastMousePosition =
				currentMousePosition

			return

		end


		--------------------------------------------------
		-- DELTA
		--------------------------------------------------

		local delta =
			currentMousePosition
			-
			lastMousePosition


		lastMousePosition =
			currentMousePosition


		--------------------------------------------------
		-- HORIZONTAL
		--
		-- Mouse RIGHT = orbit RIGHT
		-- Mouse LEFT  = orbit LEFT
		--------------------------------------------------

		lobbyYaw -=
			delta.X * 0.005


		--------------------------------------------------
		-- VERTICAL
		--
		-- FIXED:
		--
		-- Mouse UP   = camera UP
		-- Mouse DOWN = camera DOWN
		--
		-- This is the corrected direction.
		--------------------------------------------------

		lobbyPitch +=
			delta.Y * 0.005


		--------------------------------------------------
		-- LIMIT PITCH
		--------------------------------------------------

		lobbyPitch =
			math.clamp(
				lobbyPitch,
				MIN_LOBBY_PITCH,
				MAX_LOBBY_PITCH
			)

	end
)


--------------------------------------------------
-- LOBBY ORBIT POSITION
--------------------------------------------------

local function getLobbyOrbitPosition(
	ballPosition,
	distance
)

	--------------------------------------------------
	-- START BEHIND BALL
	--
	-- Course direction = +Z
	-- Behind = -Z
	--------------------------------------------------

	local direction =
		Vector3.new(
			0,
			0,
			-distance
		)


	--------------------------------------------------
	-- YAW
	--------------------------------------------------

	direction =
		CFrame.Angles(
			0,
			lobbyYaw,
			0
		)
		*
		direction


	--------------------------------------------------
	-- PITCH
	--------------------------------------------------

	direction =
		CFrame.Angles(
			lobbyPitch,
			0,
			0
		)
		*
		direction


	return ballPosition + direction

end


--------------------------------------------------
-- SMOOTH CAMERA
--------------------------------------------------

local function smoothCamera(
	targetPosition,
	targetLookTarget,
	deltaTime
)

	if not currentCameraPosition then

		currentCameraPosition =
			targetPosition

	end


	if not currentLookTarget then

		currentLookTarget =
			targetLookTarget

	end


	--------------------------------------------------
	-- FRAME RATE INDEPENDENT SMOOTHING
	--------------------------------------------------

	local alpha =
		1 -
		math.exp(
			-CAMERA_SMOOTHNESS
			* deltaTime
		)


	currentCameraPosition =
		currentCameraPosition:Lerp(
			targetPosition,
			alpha
		)


	currentLookTarget =
		currentLookTarget:Lerp(
			targetLookTarget,
			alpha
		)


	--------------------------------------------------
	-- APPLY
	--------------------------------------------------

	camera.CFrame =
		CFrame.lookAt(
			currentCameraPosition,
			currentLookTarget,
			Vector3.new(
				0,
				1,
				0
			)
		)

end


--------------------------------------------------
-- LOBBY CAMERA
--------------------------------------------------

local function updateLobbyCamera(
	ball,
	deltaTime
)

	local ballPosition =
		ball.Position


	--------------------------------------------------
	-- GET ZOOM
	--------------------------------------------------

	local zoom =
		LOBBY_ZOOM_LEVELS[
			currentLobbyZoom
		]


	--------------------------------------------------
	-- ORBIT
	--------------------------------------------------

	local cameraPosition =
		getLobbyOrbitPosition(
			ballPosition,
			zoom.distance
		)


	--------------------------------------------------
	-- IMPORTANT:
	--
	-- NO CAMERA FLOOR.
	--
	-- The camera is NOT forced above the ground
	-- or above the ball.
	--
	-- This allows the player to freely orbit
	-- vertically.
	--------------------------------------------------


	--------------------------------------------------
	-- LOOK AT BALL
	--------------------------------------------------

	local lookTarget =
		ballPosition
		+
		Vector3.new(
			0,
			1,
			0
		)


	--------------------------------------------------
	-- FOV
	--------------------------------------------------

	camera.FieldOfView =
		zoom.fov


	--------------------------------------------------
	-- APPLY
	--------------------------------------------------

	smoothCamera(
		cameraPosition,
		lookTarget,
		deltaTime
	)

end


--------------------------------------------------
-- COURSE CAMERA
--------------------------------------------------
--
-- THIS CAMERA DOES NOT USE:
--
-- lobbyYaw
-- lobbyPitch
-- mouse input
-- lobby zoom
--
-- It is completely independent.
--------------------------------------------------

local function updateCourseCamera(
	ball,
	deltaTime
)

	local ballPosition =
		ball.Position


	--------------------------------------------------
	-- FIXED BEHIND-BALL POSITION
	--
	-- Course direction = +Z
	-- Behind = -Z
	--------------------------------------------------

	local cameraPosition =
		ballPosition
		+
		Vector3.new(
			0,
			COURSE_HEIGHT,
			-COURSE_DISTANCE
		)


	--------------------------------------------------
	-- SAFETY
	--------------------------------------------------

	local minimumCameraY =
		ballPosition.Y + 3


	if cameraPosition.Y <
		minimumCameraY then

		cameraPosition =
			Vector3.new(
				cameraPosition.X,
				minimumCameraY,
				cameraPosition.Z
			)

	end


	--------------------------------------------------
	-- LOOK AHEAD
	--
	-- ALWAYS WORLD +Z
	--------------------------------------------------

	local lookTarget =
		ballPosition
		+
		Vector3.new(
			0,
			COURSE_LOOK_HEIGHT,
			COURSE_LOOK_AHEAD
		)


	--------------------------------------------------
	-- FIXED COURSE FOV
	--------------------------------------------------

	camera.FieldOfView =
		COURSE_FOV


	--------------------------------------------------
	-- APPLY
	--------------------------------------------------

	smoothCamera(
		cameraPosition,
		lookTarget,
		deltaTime
	)

end


--------------------------------------------------
-- CAMERA UPDATE
--------------------------------------------------

local function updateCamera(
	deltaTime
)

	--------------------------------------------------
	-- SCRIPTABLE
	--------------------------------------------------

	camera.CameraType =
		Enum.CameraType.Scriptable


	--------------------------------------------------
	-- BALL
	--------------------------------------------------

	local ball =
		getBall()


	if not ball then
		return
	end


	--------------------------------------------------
	-- MODE
	--------------------------------------------------

	local mode =
		getCameraMode(ball)


	--------------------------------------------------
	-- LOBBY
	--------------------------------------------------

	if mode == "Lobby" then

		updateLobbyCamera(
			ball,
			deltaTime
		)

		return

	end


	--------------------------------------------------
	-- COURSE
	--------------------------------------------------

	if mode == "Course" then

		--------------------------------------------------
		-- RELEASE ANY ACTIVE RIGHT-CLICK ROTATION
		--------------------------------------------------

		rotating =
			false

		lastMousePosition =
			nil


		updateCourseCamera(
			ball,
			deltaTime
		)

		return

	end

end


--------------------------------------------------
-- INITIAL CAMERA
--------------------------------------------------

camera.CameraType =
	Enum.CameraType.Scriptable

camera.FieldOfView =
	LOBBY_ZOOM_LEVELS[
		currentLobbyZoom
	].fov


--------------------------------------------------
-- RENDER UPDATE
--------------------------------------------------

RunService:BindToRenderStep(
	CAMERA_BIND_NAME,
	Enum.RenderPriority.Camera.Value + 100,
	updateCamera
)


--------------------------------------------------
-- DEBUG
--------------------------------------------------

print(
	"[BallCamera] CLIENT READY"
)

print(
	"[BallCamera] Lobby = FREE CAMERA"
)

print(
	"[BallCamera] Lobby vertical orbit = CORRECTED"
)

print(
	"[BallCamera] Lobby camera floor = DISABLED"
)

print(
	"[BallCamera] Course = LOCKED CAMERA"
)

print(
	"[BallCamera] Course mouse orbit = DISABLED"
)

print(
	"[BallCamera] Course zoom = DISABLED"
)

print(
	"[BallCamera] Lobby zoom = 3 levels"
)
