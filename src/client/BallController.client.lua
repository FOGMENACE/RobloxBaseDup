local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local remotes =
	ReplicatedStorage:WaitForChild("Remotes")

local ballMovement =
	remotes:WaitForChild("BallMovement")

--------------------------------------------------
-- INPUT STATE
--------------------------------------------------

local inputX = 0
local inputZ = 0

--------------------------------------------------
-- KEY STATE
--------------------------------------------------

local function updateKeys()

	inputX = 0
	inputZ = 0

	--------------------------------------------------
	-- LEFT
	--------------------------------------------------

	if UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.Left) then

		inputX -= 1

	end

	--------------------------------------------------
	-- RIGHT
	--------------------------------------------------

	if UserInputService:IsKeyDown(Enum.KeyCode.D)
		or UserInputService:IsKeyDown(Enum.KeyCode.Right) then

		inputX += 1

	end

	--------------------------------------------------
	-- FORWARD
	--------------------------------------------------

	if UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up) then

		inputZ += 1

	end

	--------------------------------------------------
	-- BACKWARD
	--------------------------------------------------

	if UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.Down) then

		inputZ -= 1

	end

end

--------------------------------------------------
-- CAMERA RELATIVE MOVEMENT
--------------------------------------------------

local function getMovement()

	updateKeys()

	--------------------------------------------------
	-- COURSE CONTROLS
	--
	-- Running AND Finishing use the exact same
	-- controls.
	--
	-- This prevents WinCourse from switching back
	-- to lobby/camera-relative movement when the
	-- FinishWall is reached.
	--------------------------------------------------

	local runState =
		player:GetAttribute("RunState")

	if runState == "Running"
		or runState == "Finishing" then

		--------------------------------------------------
		-- COURSE CONTROLS ONLY
		--
		-- A = LEFT
		-- D = RIGHT
		--
		-- Keep the existing inversion.
		--------------------------------------------------

		return Vector2.new(
			-inputX,
			0
		)

	end


	--------------------------------------------------
	-- LOBBY
	--------------------------------------------------

	local cameraCFrame =
		camera.CFrame


	--------------------------------------------------
	-- FLATTEN CAMERA
	--------------------------------------------------

	local forward =
		Vector3.new(
			cameraCFrame.LookVector.X,
			0,
			cameraCFrame.LookVector.Z
		)

	local right =
		Vector3.new(
			cameraCFrame.RightVector.X,
			0,
			cameraCFrame.RightVector.Z
		)


	if forward.Magnitude > 0.001 then

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


	if right.Magnitude > 0.001 then

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
	-- CAMERA RELATIVE MOVEMENT
	--------------------------------------------------

	local movement =
		(right * inputX)
		+
		(forward * inputZ)


	if movement.Magnitude > 1 then

		movement =
			movement.Unit

	end


	return Vector2.new(
		movement.X,
		movement.Z
	)

end

--------------------------------------------------
-- CONTINUOUS INPUT SEND
--------------------------------------------------
--
-- This is the important change.
--
-- While W/A/S/D is held, we continually recalculate
-- the direction from the CURRENT camera orientation.
--
--------------------------------------------------

RunService.RenderStepped:Connect(function()

	local movement =
		getMovement()

	--------------------------------------------------
	-- Don't spam the server when completely idle.
	--------------------------------------------------

	if inputX == 0 and inputZ == 0 then

		ballMovement:FireServer(
			Vector2.zero
		)

		return

	end

	ballMovement:FireServer(
		movement
	)

end)

--------------------------------------------------
-- WINDOW FOCUS
--------------------------------------------------

UserInputService.WindowFocusReleased:Connect(
	function()

		inputX = 0
		inputZ = 0

		ballMovement:FireServer(
			Vector2.zero
		)

	end
)

print("[BallController] CLIENT READY")
