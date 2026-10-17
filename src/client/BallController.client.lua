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
local LOCAL_JUMP_COOLDOWN = 0.4
local lastLocalJump = 0

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

local function localJump(ball)
	local now = os.clock()
	if now - lastLocalJump < LOCAL_JUMP_COOLDOWN then
		return
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
		Vector3.new(0, -(radius + 0.75), 0),
		params
	)
	if not hit then
		return
	end

	lastLocalJump = now
	local v = ball.AssemblyLinearVelocity
	ball.AssemblyLinearVelocity = Vector3.new(v.X, LOCAL_JUMP_VELOCITY, v.Z)
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

local function requestJump()
	local runState = getRunState()
	if runState ~= "Waiting" then
		return
	end

	local now = os.clock()
	if now - lastJumpSent < 0.25 then
		return
	end
	lastJumpSent = now
	local ownBall = getOwnBall()
	if isClientDriven(ownBall) then
		localJump(ownBall)
		return
	end


	ballMovement:FireServer(getLobbyMovement(), true)
end

UserInputService.JumpRequest:Connect(requestJump)

if UserInputService.TouchEnabled then
	local gui = Instance.new("ScreenGui")
	gui.Name = "BallJumpControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "JumpButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -80)
	button.Size = UDim2.fromOffset(64, 64)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	button.BackgroundTransparency = 0.25
	button.Text = "JUMP"
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	button.Activated:Connect(requestJump)

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