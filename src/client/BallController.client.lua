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

-- On-screen joystick: a small FIXED stick in the bottom-left corner (like the jump button
-- in the bottom-right), in the game's own style: cream disc, dark outline, cream knob.
-- On touch screens that corner is free (the rebirth badge sits beside QUESTS), and the
-- stick is sized to the screen. A drag can start anywhere in the left 45% of the screen
-- (outside buttons/panels); the knob shows its direction. It is the only stick: Roblox's
-- thumbstick is off (TouchControls), and it is lobby-only.
local CONTROL_CREAM = Color3.fromRGB(255, 247, 232)
local CONTROL_INK = Color3.fromRGB(24, 22, 34)
local CONTROL_MARGIN = 14

-- one size for every touch control (stick, jump, course arrows): ~18% of the screen height
local function controlSize()
	local cam = workspace.CurrentCamera
	local size = cam and cam.ViewportSize or Vector2.new(800, 400)
	return math.floor(math.clamp(size.Y * 0.18, 58, 92))
end

if UserInputService.TouchEnabled then
	local STICK_RADIUS = 48 -- finger travel for full speed
	local sGui = Instance.new("ScreenGui")
	sGui.Name = "BallJoystick"
	sGui.ResetOnSpawn = false
	sGui.DisplayOrder = 5
	sGui.IgnoreGuiInset = true
	sGui.Parent = player:WaitForChild("PlayerGui")

	local function disc(color, transparency, parent)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		f.Parent = parent
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke")
		s.Color = CONTROL_INK
		s.Transparency = 0.15
		s.Thickness = 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		return f
	end

	local base = disc(CONTROL_CREAM, 0.5, sGui)
	local knob = disc(CONTROL_CREAM, 0.05, base)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	local knobTravel = 20

	-- bottom-left corner, sized to the screen
	local restPos = UDim2.fromOffset(0, 0)
	local function placeRest()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(800, 400)
		local d = controlSize()
		base.Size = UDim2.fromOffset(d, d)
		knob.Size = UDim2.fromOffset(math.floor(d * 0.46), math.floor(d * 0.46))
		knobTravel = (d - d * 0.46) / 2
		-- right of the oil / trophy multipliers panel in the bottom-left corner (HudUI)
		local x = CONTROL_MARGIN + d / 2
		local hud = player.PlayerGui:FindFirstChild("HudUI")
		local panel = hud and hud:FindFirstChild("RebirthPanel", true)
		if panel and panel:IsA("GuiObject") and panel.Visible and panel.AbsoluteSize.X > 0 then
			x = panel.AbsolutePosition.X + panel.AbsoluteSize.X + 12 + d / 2
		end
		restPos = UDim2.fromOffset(x, size.Y - CONTROL_MARGIN - d / 2)
	end
	placeRest()
	base.Position = restPos

	local activeTouch = nil
	local origin = Vector2.zero

	local function release()
		activeTouch = nil
		stickX, stickZ = 0, 0
		knob.Position = UDim2.fromScale(0.5, 0.5)
		base.BackgroundTransparency = 0.5
	end

	local function drag(pos)
		local delta = pos - origin
		local mag = delta.Magnitude
		if mag > STICK_RADIUS then
			delta = delta * (STICK_RADIUS / mag)
		end
		-- the knob moves inside the small base (scaled finger travel)
		local shown = delta * (knobTravel / STICK_RADIUS)
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
		base.BackgroundTransparency = 0.3
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

	-- STEERING: the WHOLE left half of the screen steers left and the whole right half steers
	-- right (the arrows are only the picture of it), so thumbs never have to find a small
	-- button. Touches are tracked by their position, not by what they landed on:
	--   * a finger that came from the lobby joystick is picked up the moment it moves;
	--   * sliding across the middle switches the side;
	--   * taps on real UI (settings, panels) are left alone (gameProcessed).
	local touchSide = {} -- [InputObject] = -1 / 1
	local arrowFaces = {} -- [dir] = { Button, Refresh }

	local function viewportWidth()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize.X or 800
	end

	local function sideOf(input)
		return input.Position.X < viewportWidth() / 2 and -1 or 1
	end

	local function recompute()
		local left, right = false, false
		for _, side in pairs(touchSide) do
			if side < 0 then
				left = true
			else
				right = true
			end
		end
		arrowX = (right and 1 or 0) - (left and 1 or 0)
		for dir, face in pairs(arrowFaces) do
			face.Button.BackgroundTransparency = ((dir < 0 and left) or (dir > 0 and right)) and 0.3 or 0.5
		end
	end

	local function onCourse()
		local state = getRunState()
		return state == "Starting" or state == "Running"
	end

	local function arrowButton(dir)
		-- same style, size and height as the lobby controls: a rounded cream square with
		-- the dark outline and a drawn dark chevron, in the bottom corners (display only)
		local b = Instance.new("Frame")
		b.Name = dir < 0 and "LeftArrow" or "RightArrow"
		b.AnchorPoint = Vector2.new(dir < 0 and 0 or 1, 1)
		b.BackgroundColor3 = CONTROL_CREAM
		b.BackgroundTransparency = 0.5
		b.Parent = aGui
		Instance.new("UICorner", b).CornerRadius = UDim.new(0.3, 0)
		local s = Instance.new("UIStroke")
		s.Color = CONTROL_INK
		s.Transparency = 0.15
		s.Thickness = 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b

		local function fitArrow()
			local d = math.floor(controlSize() * 1.1)
			b.Size = UDim2.fromOffset(d, d)
			b.Position = UDim2.new(dir < 0 and 0 or 1, dir < 0 and CONTROL_MARGIN or -CONTROL_MARGIN, 1, -CONTROL_MARGIN)
		end
		fitArrow()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitArrow)
		end

		-- the chevron: two rounded dark bars meeting at the tip (points right; mirrored for left)
		for _, side in ipairs({ -1, 1 }) do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Position = UDim2.fromScale(0.5 - dir * 0.02, 0.5 + side * 0.11)
			bar.Size = UDim2.fromScale(0.36, 0.12)
			bar.Rotation = -side * 45 * dir
			bar.BackgroundColor3 = CONTROL_INK
			bar.BorderSizePixel = 0
			bar.Parent = b
			Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		end
		arrowFaces[dir] = { Button = b }
	end

	arrowButton(-1)
	arrowButton(1)

	local function clearArrows()
		table.clear(touchSide)
		recompute()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not onCourse() or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		touchSide[input] = sideOf(input)
		recompute()
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not onCourse() or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local side = sideOf(input)
		-- also picks up a finger that started in the lobby (the joystick) and is still down
		if touchSide[input] ~= side and (touchSide[input] ~= nil or input.UserInputState ~= Enum.UserInputState.End) then
			touchSide[input] = side
			recompute()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if touchSide[input] then
			touchSide[input] = nil
			recompute()
		end
	end)
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

	-- same look and size as the joystick (cream disc, dark outline), bottom-right corner,
	-- with a drawn up arrow (a glyph could turn into an emoji on some phones)
	gui.IgnoreGuiInset = true
	local button = Instance.new("TextButton")
	button.Name = "JumpButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.BackgroundColor3 = CONTROL_CREAM
	button.BackgroundTransparency = 0.5
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = gui

	local function fitJump()
		local d = controlSize()
		button.Size = UDim2.fromOffset(d, d)
		button.Position = UDim2.new(1, -CONTROL_MARGIN, 1, -CONTROL_MARGIN)
	end
	fitJump()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitJump)
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local ring = Instance.new("UIStroke")
	ring.Color = CONTROL_INK
	ring.Transparency = 0.15
	ring.Thickness = 3
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = button

	-- icon: a bowling ball hopping up - the dark ball with its three finger holes, a
	-- small up chevron above it and a soft shadow under it, all drawn with frames
	local ball = Instance.new("Frame")
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(0.5, 0.58)
	ball.Size = UDim2.fromScale(0.42, 0.42)
	ball.BackgroundColor3 = Color3.fromRGB(46, 40, 92)
	ball.BorderSizePixel = 0
	ball.Parent = button
	Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)
	local ballRing = Instance.new("UIStroke")
	ballRing.Color = CONTROL_INK
	ballRing.Thickness = 2
	ballRing.Parent = ball
	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.3, 0.3)
	shine.Size = UDim2.fromScale(0.22, 0.22)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.55
	shine.BorderSizePixel = 0
	shine.Parent = ball
	Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)
	for _, hole in ipairs({ { 0.56, 0.36 }, { 0.72, 0.5 }, { 0.6, 0.62 } }) do
		local h = Instance.new("Frame")
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.Position = UDim2.fromScale(hole[1], hole[2])
		h.Size = UDim2.fromScale(0.16, 0.16)
		h.BackgroundColor3 = CONTROL_INK
		h.BorderSizePixel = 0
		h.Parent = ball
		Instance.new("UICorner", h).CornerRadius = UDim.new(1, 0)
	end
	-- the up chevron: two rounded bars meeting at the top
	for _, side in ipairs({ -1, 1 }) do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5 + side * 0.065, 0.24)
		bar.Size = UDim2.fromScale(0.2, 0.07)
		bar.Rotation = side * 38
		bar.BackgroundColor3 = CONTROL_INK
		bar.BorderSizePixel = 0
		bar.Parent = button
		Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	end
	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromScale(0.5, 0.86)
	shadow.Size = UDim2.fromScale(0.34, 0.06)
	shadow.BackgroundColor3 = CONTROL_INK
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.Parent = button
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)

	-- press feedback, like the stick
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.3
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			button.BackgroundTransparency = 0.5
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