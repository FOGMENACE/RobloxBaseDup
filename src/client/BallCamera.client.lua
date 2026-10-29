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

local WORLD_OFFSETS = {}
for _, w in ipairs(require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig")).Worlds) do
	WORLD_OFFSETS[w.Id] = w.Offset.X
end
local Players =
	game:GetService("Players")

local UserInputService =
	game:GetService("UserInputService")

local RunService =
	game:GetService("RunService")

local PanelManager =
	require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("PanelManager")
	)

-- True while any big panel (or the ball shop) is open: zoom and FOV
-- presets are ignored so scrolling a list never moves the camera.
local function uiBlocksZoom()
	if PanelManager.AnyOpen() then
		return true
	end

	local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("BallShopUI")
	if gui ~= nil and gui:IsA("ScreenGui") and gui.Enabled then
		return true
	end

	-- the admin console is open: the wheel scrolls its output, never the camera
	local adminGui = Players.LocalPlayer.PlayerGui:FindFirstChild("AdminConsole")
	if adminGui ~= nil and adminGui:IsA("ScreenGui") and adminGui.Enabled then
		local mouse = UserInputService:GetMouseLocation()
		local inset = game:GetService("GuiService"):GetGuiInset()
		local point = mouse - inset -- ScreenGui space (the console ignores no inset)
		for _, child in ipairs(adminGui:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				local p, s = child.AbsolutePosition, child.AbsoluteSize
				if point.X >= p.X and point.X <= p.X + s.X and point.Y >= p.Y and point.Y <= p.Y + s.Y then
					return true -- over the console: the wheel scrolls its output
				end
			end
		end
	end

	-- the mouse is over the hologram leaderboard: the wheel scrolls its lists
	local camera = workspace.CurrentCamera
	if camera then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200)
		if hit and hit.Instance.Name == "HoloScreen" then
			return true
		end
	end
	return false
end


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
		distance = 21,
		height = 9,
		fov = 74
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
	21

local COURSE_HEIGHT =
	16

local COURSE_LOOK_AHEAD =
	18

local COURSE_LOOK_HEIGHT =
	1

local COURSE_FOV =
	70

-- Small / touch screens see less around the ball, so the camera pulls back a
-- little and widens on them (1 on a big monitor, up to ~1.15 on a phone).
local function roomy()
	local camera = workspace.CurrentCamera
	local height = camera and camera.ViewportSize.Y or 800
	local extra = math.clamp((800 - height) / 400, 0, 1) * 0.15
	if UserInputService.TouchEnabled then
		extra = math.max(extra, 0.1)
	end
	return 1 + extra
end

local function roomyFov()
	return (roomy() - 1) * 40
end


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

			-- Keep the cursor where it was right-clicked while orbiting
			-- (the camera turns from the mouse DELTA, not the position).
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition

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

			UserInputService.MouseBehavior = Enum.MouseBehavior.Default

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


		if uiBlocksZoom() then
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

			UserInputService.MouseBehavior = Enum.MouseBehavior.Default

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

		local delta = Vector2.new(input.Delta.X, input.Delta.Y)


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
			zoom.distance * roomy()
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
	-- NEVER UNDER THE LOBBY FLOOR
	--
	-- Orbiting down must not pass through the floor: find the floor
	-- under the ball and keep the camera a little above it.
	--------------------------------------------------

	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	floorParams.FilterDescendantsInstances = { playerBalls, player.Character }

	local floorHit = workspace:Raycast(
		ballPosition + Vector3.new(0, 2, 0),
		Vector3.new(0, -30, 0),
		floorParams
	)

	local lowestY = (floorHit and floorHit.Position.Y or (ballPosition.Y - 2)) + 1.4

	if cameraPosition.Y < lowestY then
		cameraPosition = Vector3.new(cameraPosition.X, lowestY, cameraPosition.Z)
	end

	-- Stay inside the lobby room (walls, ceiling): the camera never leaves
	-- through a wall when the ball is near one. The lane opening at the
	-- start wall stays reachable because the ball itself is clamped only by
	-- its own position, not the camera's.
	-- the higher worlds are copies of this room shifted along X
	local worldX = (Players.LocalPlayer:GetAttribute("World") and WORLD_OFFSETS[Players.LocalPlayer:GetAttribute("World")]) or 0
	local LOBBY_X_MIN, LOBBY_X_MAX = -104.6 + worldX, -25.2 + worldX
	local LOBBY_Z_MIN, LOBBY_Z_MAX = -284.4, -197.9 -- back wall is at z -285.5
	local ceilingY = (floorHit and floorHit.Position.Y or (ballPosition.Y - 2)) + 26

	cameraPosition = Vector3.new(
		math.clamp(cameraPosition.X, LOBBY_X_MIN, LOBBY_X_MAX),
		math.min(cameraPosition.Y, ceilingY),
		math.clamp(cameraPosition.Z, LOBBY_Z_MIN, LOBBY_Z_MAX)
	)

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
		zoom.fov + roomyFov()


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

-- The server-owned ball replicates in steps, which at hundreds of studs/s
-- makes a camera glued to ball.Position shake. Track a locally integrated
-- position (velocity dead-reckoning) that is gently pulled to the real one.
local courseTrack = nil
local courseTrackBall = nil
local courseTrackVelocity = Vector3.zero
local courseSettle = 0 -- 0..1, eases in when the WinCourse ball comes to a stop

local function updateCourseCamera(
	ball,
	deltaTime
)

	local realPosition = ball.Position
	local velocity = ball.AssemblyLinearVelocity

	if courseTrackBall ~= ball or not courseTrack or (courseTrack - realPosition).Magnitude > 40 + velocity.Magnitude * 0.45 then
		-- (the snap distance grows with speed: at WinCourse speeds one replication
		-- step is already tens of studs, which used to re-snap the camera every frame)
		courseTrackBall = ball
		courseTrack = realPosition
		courseTrackVelocity = velocity
	end

	-- Speeding up is smoothed, but slowing down / stopping is followed at once:
	-- a lagging velocity kept dead-reckoning the camera target PAST a ball that
	-- had already run out of oil, sending the camera over it and the ball out
	-- of the frame.
	if velocity.Magnitude < courseTrackVelocity.Magnitude then
		courseTrackVelocity = velocity
	else
		courseTrackVelocity = courseTrackVelocity:Lerp(velocity, 1 - math.exp(-6 * deltaTime))
	end
	courseTrack = courseTrack + courseTrackVelocity * deltaTime
	courseTrack = courseTrack:Lerp(realPosition, 1 - math.exp(-5 * deltaTime))
	-- never ahead of the real ball along the course (+Z)
	if courseTrack.Z > realPosition.Z then
		courseTrack = Vector3.new(courseTrack.X, courseTrack.Y, realPosition.Z)
	end

	-- The smoothing below makes the camera trail a moving target by about
	-- velocity / CAMERA_SMOOTHNESS studs (75 studs at 900 studs/s, which is why
	-- the ball looked tiny and far away). Aim that far ahead so the ball stays
	-- at the same place in the frame at every speed.
	local ballPosition = courseTrack + courseTrackVelocity / CAMERA_SMOOTHNESS

	-- The WinCourse runs at hundreds of studs/s, so it uses a tighter, lower
	-- chase view and a narrower field of view than the oil course (which kept
	-- the ball tiny and "very far").
	local isWin = ball:GetAttribute("WinCourseActive") == true
	-- (aimed almost AT the ball so it sits in the middle of the frame, which
	-- is also where the dash streaks converge)
	local viewDistance = (isWin and 19 or COURSE_DISTANCE) * roomy()
	local viewHeight = (isWin and 11 or COURSE_HEIGHT) * roomy()
	local viewAhead = isWin and 2 or COURSE_LOOK_AHEAD
	local baseFov = (isWin and 64 or COURSE_FOV) + roomyFov()

	-- SETTLE: when the ball slows to a stop (out of oil) the camera eases in a
	-- little closer and lower and the view narrows, so the end of the run
	-- feels like a landing and the ball stays big and centred in the frame.
	local settleTarget = (isWin and velocity.Magnitude < 70) and 1 or 0
	courseSettle += (settleTarget - courseSettle) * (1 - math.exp(-2.2 * deltaTime))
	viewDistance *= 1 - 0.3 * courseSettle
	viewHeight *= 1 - 0.22 * courseSettle
	baseFov -= 7 * courseSettle


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
			viewHeight,
			-viewDistance
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
			viewAhead
		)


	--------------------------------------------------
	-- FIXED COURSE FOV
	--------------------------------------------------

	-- Speed feel: the field of view widens a little as the ball speeds up
	-- (read-only use of the replicated velocity), eased so it never snaps.
	local speedPush =
		math.clamp(
			(ball.AssemblyLinearVelocity.Magnitude - 25) / (isWin and 300 or 120),
			0,
			1
		)
		* (isWin and 9 or 14)

	local targetFov =
		baseFov + speedPush

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
	if uiBlocksZoom() then
		return
	end

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
zoomButton.BackgroundColor3 = Color3.fromRGB(255, 247, 232)
zoomButton.BackgroundTransparency = 0.3
zoomButton.TextColor3 = Color3.fromRGB(24, 22, 34)
zoomButton.Font = Enum.Font.GothamBold
zoomButton.TextSize = 14
zoomButton.AutoButtonColor = true
zoomButton.Parent = zoomGui

local zoomCorner = Instance.new("UICorner")
zoomCorner.CornerRadius = UDim.new(1, 0)
zoomCorner.Parent = zoomButton

local ZOOM_LABELS = { "NEAR", "MID", "FAR" }

-- The on-screen zoom control is for phones/tablets only (touch, no keyboard, no
-- mouse); on PC the zoom is changed with the mouse wheel / keys as before.
local function isMobileDevice()
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

local function refreshZoomButton()
	zoomButton.Text = ZOOM_LABELS[currentLobbyZoom] or "ZOOM"

	local ball = getBall()
	zoomButton.Visible = isMobileDevice() and ball ~= nil and getCameraMode(ball) == "Lobby"
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
	"[BallCamera] Lobby camera floor = ENABLED (never under the floor)"
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
