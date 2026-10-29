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

--------------------------------------------------
-- ROBLOX CONTROL MODULE (thumbstick / gamepad)
--------------------------------------------------

local cachedControls = nil

-- On-screen joystick state (touch devices; Roblox's own thumbstick is turned off
-- by TouchControls on the server). x = right, z = forward, both -1..1.
local stickX, stickZ = 0, 0
-- Oil-course arrow buttons (touch): -1 left, 0, 1 right.
local arrowX = 0

local function getControls()
	if cachedControls then
		return cachedControls
	end

	local playerScripts = player:FindFirstChild("PlayerScripts")
	local module = playerScripts
		and playerScripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end

	local ok, result = pcall(function()
		return require(module):GetControls()
	end)
	if ok then
		cachedControls = result
	end
	return cachedControls
end

local function updateKeys()
	-- Typing in any TextBox (feedback mailbox, admin console) must never
	-- move the ball / avatar.
	if UserInputService:GetFocusedTextBox() then
		inputX = 0
		inputZ = 0
		return
	end

	-- No movement behind the loading screen (LoadingBoot sets this when the
	-- player's data, world and floor are in). The server gates runs too (JoinGate).
	if player:GetAttribute("LoadingDone") ~= true then
		inputX = 0
		inputZ = 0
		return
	end

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


	-- Touch thumbstick / gamepad stick: read Roblox's own control module
	-- (analog, already respects the device) instead of a second input path.
	-- MoveVector: x = right, z = -forward.
	if x == 0 and z == 0 then
		local controls = getControls()
		if controls then
			local ok, moveVector = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and typeof(moveVector) == "Vector3" then
				x = moveVector.X
				z = -moveVector.Z
			end
		end
	end

	if x == 0 and z == 0 and (stickX ~= 0 or stickZ ~= 0) then
		x, z = stickX, stickZ
	end

	if x == 0 and arrowX ~= 0 then
		x = arrowX
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

local KEEPALIVE_INTERVAL = 0.1
local lastSentMovement = nil
local lastSentTime = 0

local function sendMovement()

	local movement =
		getCurrentMovement()

	if movement == nil then

		return

	end

	-- Only send on change, plus a keep-alive while input is held
	-- (server INPUT_TIMEOUT is 0.20s). Idle zero input is not resent;
	-- resending it at 60 Hz exhausted the remote queue.
	local now = os.clock()
	local changed = lastSentMovement == nil
		or movement ~= lastSentMovement

	if not changed then
		if movement.Magnitude == 0
			or now - lastSentTime < KEEPALIVE_INTERVAL then
			return
		end
	end

	lastSentMovement = movement
	lastSentTime = now

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
-- CLIENT-OWNED LOBBY BALL
--
-- In the lobby (RunState Waiting) the server hands this player
-- network ownership of the ball and sets the ball attribute
-- ClientDriven = true. While that is true, this script drives the
-- ball's existing LinearVelocity locally so rolling is instant.
-- The server still validates (XP distance is capped to LobbySpeed)
-- and takes ownership back for every other state.
--------------------------------------------------

local LOCAL_JUMP_VELOCITY = 40
local LOCAL_JUMP_COOLDOWN = 0.12 -- just enough that one press cannot fire twice
local JUMP_BUFFER = 0.2 -- a press a hair before landing still jumps on touchdown
local lastLocalJump = 0
local jumpBufferedUntil = 0

local function getOwnBall()
	local balls = workspace:FindFirstChild("PlayerBalls")
	return balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
end

local function isClientDriven(ball)
	return ball ~= nil
		and ball:GetAttribute("ClientDriven") == true
		and getRunState() == "Waiting"
		and ball:GetAttribute("WinCourseActive") ~= true
end

RunService.RenderStepped:Connect(function()
	local ball = getOwnBall()
	if not isClientDriven(ball) then
		return
	end

	local controller = ball:FindFirstChild("BallLinearVelocity")
	if not controller or not controller:IsA("LinearVelocity") then
		return
	end

	local speed = ball:GetAttribute("LobbySpeed")
	if typeof(speed) ~= "number" then
		return
	end

	updateKeys()
	local movement = getLobbyMovement()
	controller.VectorVelocity = Vector3.new(
		movement.X * speed,
		0,
		movement.Y * speed
	)
end)

-- Returns true when the ball really jumped.
local function localJump(ball)
	local now = os.clock()
	if now - lastLocalJump < LOCAL_JUMP_COOLDOWN then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		workspace:FindFirstChild("PlayerBalls"),
		player.Character,
	}

	local radius = ball.Size.Y * 0.5
	local hit = workspace:Raycast(
		ball.Position,
		Vector3.new(0, -(radius + 1.1), 0), -- a little slack so a landing bounce still counts as ground
		params
	)
	if not hit then
		return false
	end

	-- already flying upward from a jump: do not stack another one
	local v = ball.AssemblyLinearVelocity
	if v.Y > 12 then
		return false
	end

	lastLocalJump = now
	ball.AssemblyLinearVelocity = Vector3.new(v.X, LOCAL_JUMP_VELOCITY, v.Z)
	return true
end

--------------------------------------------------
-- JUMP (lobby)
--
-- Space / gamepad A / mobile button all raise
-- UserInputService.JumpRequest. The client only
-- reports the request; the server validates lobby
-- state, ground contact and cooldown.
--------------------------------------------------

local lastJumpSent = 0

local function requestJump(held)
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("LoadingDone") ~= true then
		return
	end

	local runState = getRunState()
	if runState ~= "Waiting" then
		return
	end

	local ownBall = getOwnBall()
	if isClientDriven(ownBall) then
		if localJump(ownBall) then
			jumpBufferedUntil = 0
		elseif held ~= true then
			-- not on the ground yet: remember the press so it fires on touchdown
			jumpBufferedUntil = os.clock() + JUMP_BUFFER
		end
		return
	end

	-- server-driven ball: the remote is rate limited
	local now = os.clock()
	if now - lastJumpSent < 0.25 then
		return
	end
	lastJumpSent = now

	ballMovement:FireServer(getLobbyMovement(), true)
end

UserInputService.JumpRequest:Connect(function()
	requestJump(false)
end)

-- HOLD TO KEEP JUMPING: JumpRequest only fires on the press, so while the key
-- (or gamepad A / the touch button) stays down the ball jumps again as soon
-- as it has landed. requestJump still applies the cooldown, ground check and
-- lobby-only rule, so holding does not allow air jumps or spam.
local jumpHeld = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		jumpHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		jumpHeld = false
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	jumpHeld = false
end)

RunService.Heartbeat:Connect(function()
	if jumpHeld then
		requestJump(true)
	elseif jumpBufferedUntil > 0 then
		if os.clock() > jumpBufferedUntil then
			jumpBufferedUntil = 0
		else
			requestJump(true) -- keeps trying until the ball touches down (does not re-buffer)
		end
	end
end)

-- Roblox's own DynamicThumbstick fades a dark background over the left part of
-- the screen (its touch area) until the player first touches it. Keep that
-- frame's background invisible; the stick itself still appears where they touch.
if UserInputService.TouchEnabled then
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local function hideBackground(frame)
			if not frame:IsA("Frame") then
				return
			end
			frame.BackgroundTransparency = 1
			frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
				if frame.BackgroundTransparency ~= 1 then
					frame.BackgroundTransparency = 1
				end
			end)
		end
		local function watch(gui)
			if gui.Name ~= "TouchGui" then
				return
			end
			for _, d in ipairs(gui:GetDescendants()) do
				if d.Name == "DynamicThumbstickFrame" then
					hideBackground(d)
				end
			end
			gui.DescendantAdded:Connect(function(d)
				if d.Name == "DynamicThumbstickFrame" then
					hideBackground(d)
				end
			end)
		end
		for _, gui in ipairs(playerGui:GetChildren()) do
			watch(gui)
		end
		playerGui.ChildAdded:Connect(watch)
	end)
end

-- On-screen joystick: a small FIXED stick (dark disc + light knob) that sits right of
-- the bottom-left rebirth panel and matches the jump button. A drag can start anywhere
-- in the left 45% of the screen (outside buttons/panels); the knob shows its direction.
-- It is the only stick: Roblox's thumbstick is off (TouchControls), and it is lobby-only.
if UserInputService.TouchEnabled then
	local STICK_RADIUS = 48 -- finger travel for full speed
	local BASE_SIZE = 96
	local KNOB_SIZE = 44
	local KNOB_TRAVEL = (BASE_SIZE - KNOB_SIZE) / 2
	local sGui = Instance.new("ScreenGui")
	sGui.Name = "BallJoystick"
	sGui.ResetOnSpawn = false
	sGui.DisplayOrder = 5
	sGui.IgnoreGuiInset = true
	sGui.Parent = player:WaitForChild("PlayerGui")

	local function disc(size, color, transparency, parent)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(size, size)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Parent = parent
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke")
		s.Color = Color3.new(1, 1, 1)
		s.Transparency = 0.55
		s.Thickness = 2
		s.Parent = f
		return f
	end

	local base = disc(BASE_SIZE, Color3.fromRGB(20, 18, 32), 0.55, sGui)
	local knob = disc(KNOB_SIZE, Color3.fromRGB(235, 235, 240), 0.2, base)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	local baseStroke = base:FindFirstChildOfClass("UIStroke")

	-- resting spot sits right of the bottom-left rebirth panel so it never covers it
	local restPos = UDim2.new(0, 110, 1, -110)
	local function placeRest()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(800, 400)
		restPos = UDim2.fromOffset(math.clamp(size.X * 0.27, 150, 290), size.Y - 80)
	end
	placeRest()
	base.Position = restPos

	local activeTouch = nil
	local origin = Vector2.zero

	local function release()
		activeTouch = nil
		stickX, stickZ = 0, 0
		knob.Position = UDim2.fromScale(0.5, 0.5)
		base.BackgroundTransparency = 0.55
		baseStroke.Transparency = 0.55
	end

	local function drag(pos)
		local delta = pos - origin
		local mag = delta.Magnitude
		if mag > STICK_RADIUS then
			delta = delta * (STICK_RADIUS / mag)
		end
		-- the knob moves inside the small base (scaled finger travel)
		local shown = delta * (KNOB_TRAVEL / STICK_RADIUS)
		knob.Position = UDim2.new(0.5, shown.X, 0.5, shown.Y)
		local nx, nz = delta.X / STICK_RADIUS, -delta.Y / STICK_RADIUS
		if math.sqrt(nx * nx + nz * nz) < 0.15 then
			nx, nz = 0, 0 -- dead zone
		end
		stickX, stickZ = nx, nz
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or activeTouch or input.UserInputType ~= Enum.UserInputType.Touch
			or not sGui.Enabled then
			return
		end
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(800, 400)
		if input.Position.X > size.X * 0.45 then
			return
		end
		activeTouch = input
		origin = Vector2.new(input.Position.X, input.Position.Y)
		base.BackgroundTransparency = 0.4
		baseStroke.Transparency = 0.25
		drag(origin)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if activeTouch and input == activeTouch then
			drag(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if activeTouch and input == activeTouch then
			release()
		end
	end)

	UserInputService.WindowFocusReleased:Connect(release)

	-- lobby only: on a course the arrow buttons steer instead
	RunService.RenderStepped:Connect(function()
		local inLobby = getRunState() == nil or getRunState() == "Waiting"
		if sGui.Enabled ~= inLobby then
			sGui.Enabled = inLobby
			release()
		end
		if not activeTouch then
			placeRest()
			base.Position = restPos
		end
	end)

	----------------------------------------------
	-- OIL COURSE ARROWS: two big see-through buttons, hold to steer
	-- left/right. Shown only while on the oil course (Starting/Running).
	----------------------------------------------
	local aGui = Instance.new("ScreenGui")
	aGui.Name = "BallArrowControls"
	aGui.ResetOnSpawn = false
	aGui.DisplayOrder = 5
	aGui.IgnoreGuiInset = true
	aGui.Enabled = false
	aGui.Parent = player:WaitForChild("PlayerGui")

	local held = { [-1] = 0, [1] = 0 } -- touches holding each side

	local function arrowButton(dir)
		local b = Instance.new("TextButton")
		b.Name = dir < 0 and "LeftArrow" or "RightArrow"
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(dir < 0 and 0 or 1, 0.5)
		b.Position = UDim2.new(dir < 0 and 0 or 1, dir < 0 and 28 or -28, 0.66, 0)
		b.Size = UDim2.fromScale(0.24, 0.24)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BackgroundTransparency = 0.72
		b.Text = ""
		b.Parent = aGui
		Instance.new("UICorner", b).CornerRadius = UDim.new(0.22, 0)
		local ar = Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.DominantAxis = Enum.DominantAxis.Height
		ar.Parent = b
		local s = Instance.new("UIStroke")
		s.Color = Color3.new(1, 1, 1)
		s.Transparency = 0.45
		s.Thickness = 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b

		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Size = UDim2.fromScale(0.62, 0.62)
		glyph.Rotation = dir < 0 and 180 or 0
		glyph.Font = Enum.Font.FredokaOne
		glyph.Text = "➡"
		glyph.TextScaled = true
		glyph.TextColor3 = Color3.new(1, 1, 1)
		glyph.TextTransparency = 0.15
		glyph.Parent = b

		local function refresh()
			b.BackgroundTransparency = held[dir] > 0 and 0.5 or 0.72
			arrowX = (held[1] > 0 and 1 or 0) - (held[-1] > 0 and 1 or 0)
		end
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				held[dir] += 1
				refresh()
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				held[dir] = math.max(held[dir] - 1, 0)
				refresh()
			end
		end)
		return refresh
	end

	local refreshLeft = arrowButton(-1)
	local refreshRight = arrowButton(1)

	local function clearArrows()
		held[-1], held[1] = 0, 0
		refreshLeft()
		refreshRight()
	end
	UserInputService.WindowFocusReleased:Connect(clearArrows)

	RunService.RenderStepped:Connect(function()
		local state = getRunState()
		local onCourse = state == "Starting" or state == "Running"
		if aGui.Enabled ~= onCourse then
			aGui.Enabled = onCourse
			clearArrows()
		end
	end)
end

if UserInputService.TouchEnabled then
	local gui = Instance.new("ScreenGui")
	gui.Name = "BallJumpControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	-- same look as the joystick: a small dark see-through disc with a thin light ring
	-- and an up arrow
	local button = Instance.new("TextButton")
	button.Name = "JumpButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -28, 1, -28)
	button.Size = UDim2.fromOffset(76, 76)
	button.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
	button.BackgroundTransparency = 0.55
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.55
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = button

	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.47)
	arrow.Size = UDim2.fromScale(0.62, 0.62)
	arrow.Font = Enum.Font.GothamBold
	arrow.Text = "⬆"
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(235, 235, 240)
	arrow.Parent = button

	-- press feedback, like the stick
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.4
			ring.Transparency = 0.25
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.55
			ring.Transparency = 0.55
		end
	end)

	button.Activated:Connect(function()
		requestJump(false)
	end)
	-- holding the touch button keeps jumping too
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			jumpHeld = true
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			jumpHeld = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		button.Visible = getRunState() == "Waiting"
	end)
end

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