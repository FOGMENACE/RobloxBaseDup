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
	math.rad(-15)

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

		-- Drag right turns the view right: the camera orbits toward +X when
		-- facing +Z, i.e. yaw DEcreases (Ry(-a)*(0,0,-d) = (+sin a, 0, -cos a)).
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
	-- Course direction = +Z, so "behind" is -Z. Yaw is applied first,
	-- then pitch about the yawed X axis. (Previously pitch was applied
	-- about the WORLD X axis after yaw, which tilted the orbit the wrong
	-- way whenever the camera had been turned.)
	local rotation =
		CFrame.Angles(0, lobbyYaw, 0)
		* CFrame.Angles(lobbyPitch, 0, 0)

	return ballPosition + rotation * Vector3.new(0, 0, -distance)
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

	-- Speed feel: the field of view widens a little as the ball speeds up
	-- (read-only use of the replicated velocity), eased so it never snaps.
	local speedPush =
		math.clamp(
			(ball.AssemblyLinearVelocity.Magnitude - 25) / 120,
			0,
			1
		)
		* 14

	local targetFov =
		COURSE_FOV + speedPush

	camera.FieldOfView =
		camera.FieldOfView
		+ (targetFov - camera.FieldOfView)
		* (1 - math.exp(-6 * deltaTime))


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
-- TOUCH ROTATION + ZOOM BUTTON (mobile and desktop)
--
-- Touch: drag on the right half of the screen to orbit.
-- (Left half belongs to the movement thumbstick; touches
-- consumed by GUI are ignored via gameProcessed.)
-- Zoom button: cycles the same 3 presets as the mouse wheel.
--------------------------------------------------

local TOUCH_SENSITIVITY = 0.006
local activeTouch = nil

local function applyOrbitDelta(dx, dy)
	-- Drag right turns the view right; drag down raises the camera, same as the mouse.
	lobbyYaw -= dx
	lobbyPitch = math.clamp(
		lobbyPitch + dy,
		MIN_LOBBY_PITCH,
		MAX_LOBBY_PITCH
	)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed
		or input.UserInputType ~= Enum.UserInputType.Touch
		or activeTouch then
		return
	end

	local viewport = camera.ViewportSize
	if input.Position.X < viewport.X * 0.4 then
		return
	end

	local ball = getBall()
	if ball and getCameraMode(ball) == "Lobby" then
		activeTouch = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input ~= activeTouch then
		return
	end

	local ball = getBall()
	if not ball or getCameraMode(ball) ~= "Lobby" then
		activeTouch = nil
		return
	end

	applyOrbitDelta(
		input.Delta.X * TOUCH_SENSITIVITY,
		input.Delta.Y * TOUCH_SENSITIVITY
	)
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeTouch then
		activeTouch = nil
	end
end)

local function cycleLobbyZoom()
	-- 1 close -> 2 normal -> 3 far -> back to 1
	currentLobbyZoom = currentLobbyZoom % #LOBBY_ZOOM_LEVELS + 1
end

local zoomGui = Instance.new("ScreenGui")
zoomGui.Name = "BallCameraControls"
zoomGui.ResetOnSpawn = false
zoomGui.DisplayOrder = 5
zoomGui.Parent = player:WaitForChild("PlayerGui")

local zoomButton = Instance.new("TextButton")
zoomButton.Name = "ZoomButton"
zoomButton.AnchorPoint = Vector2.new(1, 1)
zoomButton.Position = UDim2.new(1, -16, 1, -150)
zoomButton.Size = UDim2.fromOffset(52, 52)
zoomButton.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
zoomButton.BackgroundTransparency = 0.25
zoomButton.TextColor3 = Color3.new(1, 1, 1)
zoomButton.Font = Enum.Font.GothamBold
zoomButton.TextSize = 14
zoomButton.AutoButtonColor = true
zoomButton.Parent = zoomGui

local zoomCorner = Instance.new("UICorner")
zoomCorner.CornerRadius = UDim.new(1, 0)
zoomCorner.Parent = zoomButton

local ZOOM_LABELS = { "NEAR", "MID", "FAR" }

local function refreshZoomButton()
	zoomButton.Text = ZOOM_LABELS[currentLobbyZoom] or "ZOOM"

	local ball = getBall()
	zoomButton.Visible = ball ~= nil and getCameraMode(ball) == "Lobby"
end

zoomButton.Activated:Connect(function()
	cycleLobbyZoom()
	refreshZoomButton()
end)

RunService.RenderStepped:Connect(refreshZoomButton)

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
