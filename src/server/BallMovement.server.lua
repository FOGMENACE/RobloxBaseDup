local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayerDataService =
	require(
		script.Parent
			:WaitForChild("PlayerDataLoader")
			:WaitForChild("PlayerDataService")
	)

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes = ReplicatedStorage:FindFirstChild("Remotes")

if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local ballMovement = remotes:FindFirstChild("BallMovement")

if not ballMovement then
	ballMovement = Instance.new("RemoteEvent")
	ballMovement.Name = "BallMovement"
	ballMovement.Parent = remotes
end

--------------------------------------------------
-- WORLD
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild("PlayerBalls")

local course =
	workspace:WaitForChild("Course")

local leftBoundary =
	course:WaitForChild("LeftBoundary")

local rightBoundary =
	course:WaitForChild("RightBoundary")

local playerInputs = {}
local lastBallPositions = {}

local xpDistanceBuffer = {}
local XP_PER_STUD = 1

--------------------------------------------------
-- BOUNDARIES
--------------------------------------------------

local LEFT_LIMIT = math.min(
	leftBoundary.Position.X,
	rightBoundary.Position.X
)

local RIGHT_LIMIT = math.max(
	leftBoundary.Position.X,
	rightBoundary.Position.X
)

--------------------------------------------------
-- INPUT
--------------------------------------------------

ballMovement.OnServerEvent:Connect(function(player, input)

	if typeof(input) ~= "Vector2" then
		return
	end

	if input.X < -1
		or input.X > 1
		or input.Y < -1
		or input.Y > 1 then
		return
	end

	if input.Magnitude > 1.01 then
		return
	end

	--------------------------------------------------
	-- SERVER RECEIVES INPUT ONLY.
	-- NEVER TRUST CLIENT PROGRESSION.
	--------------------------------------------------

	playerInputs[player] = input

end)

--------------------------------------------------
-- GET PHYSICS CONTROLLER
--------------------------------------------------

local function getLinearVelocity(ball)

	local linearVelocity =
		ball:FindFirstChild("BallLinearVelocity")

	if not linearVelocity then

		local attachment =
			ball:FindFirstChild("BallAttachment")

		if not attachment then

			attachment =
				Instance.new("Attachment")

			attachment.Name =
				"BallAttachment"

			attachment.Parent =
				ball

		end

		linearVelocity =
			Instance.new("LinearVelocity")

		linearVelocity.Name =
			"BallLinearVelocity"

		linearVelocity.Attachment0 =
			attachment

		linearVelocity.RelativeTo =
			Enum.ActuatorRelativeTo.World

		linearVelocity.VelocityConstraintMode =
			Enum.VelocityConstraintMode.Vector

		linearVelocity.MaxForce =
			math.huge

		linearVelocity.Enabled =
			false

		linearVelocity.Parent =
			ball

	end

	return linearVelocity

end

--------------------------------------------------
-- MOVEMENT
--------------------------------------------------

RunService.Heartbeat:Connect(function()

	for player, input in pairs(playerInputs) do
print(
	"[BallMovement DEBUG]",
	player.Name,
	"Input:",
	input
)

		if not player.Parent then
			playerInputs[player] = nil
			continue
		end

		local ball =
			playerBalls:FindFirstChild(
				"PlayerBall_" .. player.UserId
			)

		if not ball then
			continue
		end

		if not ball:IsA("BasePart") then
			continue
		end

		if ball:GetAttribute("OwnerUserId")
			~= player.UserId then
			continue
		end

		local currentPosition = ball.Position

local previousPosition =
	lastBallPositions[player]

if previousPosition then

	local distance =
		(
			Vector3.new(
				currentPosition.X,
				0,
				currentPosition.Z
			)
			-
			Vector3.new(
				previousPosition.X,
				0,
				previousPosition.Z
			)
		).Magnitude

	--------------------------------------------------
	-- SERVER VALIDATES MOVEMENT
	--------------------------------------------------

	if distance > 0 and distance < 10 then

		xpDistanceBuffer[player] =
			(xpDistanceBuffer[player] or 0)
			+
			distance

		local wholeXP =
			math.floor(
				xpDistanceBuffer[player]
				* XP_PER_STUD
			)

		if wholeXP >= 1 then

			local success =
				PlayerDataService.AddXP(
					player,
					wholeXP
				)

			if success then

				xpDistanceBuffer[player] -=
					wholeXP

			end

		end

	end

end

lastBallPositions[player] =
	currentPosition

		--------------------------------------------------
		-- WIN COURSE OWNS THE BALL
		--------------------------------------------------

		if ball:GetAttribute("WinCourseActive")
			== true then

			continue

		end

		local runState =
			player:GetAttribute("RunState")

		local linearVelocity =
			getLinearVelocity(ball)

		--------------------------------------------------
		-- LOBBY
		--------------------------------------------------

		if runState == "Waiting" then

			local speed =
				ball:GetAttribute(
					"HorizontalSpeed"
				) or 20

			pcall(function()
				ball:SetNetworkOwner(player)
			end)

			linearVelocity.Enabled = true

			linearVelocity.VectorVelocity =
				Vector3.new(
					input.X * speed,
					0,
					input.Y * speed
				)

		--------------------------------------------------
		-- COURSE
		--------------------------------------------------

		elseif runState == "Running" then

			local horizontalSpeed =
				ball:GetAttribute(
					"HorizontalSpeed"
				) or 20

			local forwardSpeed =
				ball:GetAttribute(
					"ForwardSpeed"
				) or 20

			pcall(function()
				ball:SetNetworkOwner(player)
			end)

			linearVelocity.Enabled = true

			linearVelocity.VectorVelocity =
				Vector3.new(
					input.X * horizontalSpeed,
					0,
					forwardSpeed
				)

		--------------------------------------------------
		-- FINISHING
		--------------------------------------------------

		elseif runState == "Finishing" then

			linearVelocity.Enabled = false

		--------------------------------------------------
		-- BONUS
		--------------------------------------------------

		elseif runState == "Bonus" then

			linearVelocity.Enabled = false

		else

			linearVelocity.Enabled = false

		end

	end

end)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(function(player)

	playerInputs[player] = nil
	lastBallPositions[player] = nil
	xpDistanceBuffer[player] = nil

end)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("[BallMovement] PHYSICS MOVEMENT READY")
print("[BallMovement] BallMovement RemoteEvent READY")
print(
	"[BallMovement] LEFT:",
	LEFT_LIMIT,
	"RIGHT:",
	RIGHT_LIMIT
)
