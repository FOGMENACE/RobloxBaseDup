local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local templates =
	ServerStorage:WaitForChild("Templates")

local ballTemplate =
	templates:WaitForChild("BowlingBall")

local BallDefinitions =
	require(
		ReplicatedStorage:WaitForChild("BallDefinitions")
	)

local playerBalls =
	workspace:WaitForChild("PlayerBalls")

local ballSpawn =
	workspace:WaitForChild("BallSpawn")

local PLAYER_BALL_PREFIX = "PlayerBall_"
local STARTER_BALL_ID = "StarterBall"

--------------------------------------------------
-- PLAYER BALL NAME
--------------------------------------------------

local function getPlayerBallName(player)

	return PLAYER_BALL_PREFIX .. player.UserId

end

--------------------------------------------------
-- HIDE CHARACTER
--------------------------------------------------

local function hideCharacter(character)

	local humanoid =
		character:FindFirstChildOfClass("Humanoid")

	if humanoid then

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false

	end

	for _, descendant in ipairs(
		character:GetDescendants()
	) do

		if descendant:IsA("BasePart") then

			descendant.Transparency = 1

			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			descendant.Anchored = true

		elseif descendant:IsA("Decal") then

			descendant.Transparency = 1

		elseif descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam") then

			descendant.Enabled = false

		end

	end

end

--------------------------------------------------
-- GET +Z BALL CFRAME
--
-- IMPORTANT:
--
-- The bowling ball will always face WORLD +Z.
--
-- We intentionally do NOT use ballSpawn.CFrame
-- for rotation.
--------------------------------------------------

local function getBallSpawnCFrame()

	local spawnPosition =
		ballSpawn.Position
		+ Vector3.new(0, 2, 0)

	return CFrame.lookAt(
		spawnPosition,
		spawnPosition + Vector3.new(0, 0, 1),
		Vector3.new(0, 1, 0)
	)

end

--------------------------------------------------
-- POSITION CHARACTER
--
-- Character also faces WORLD +Z.
--------------------------------------------------

local function positionCharacterAtSpawn(character)

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return
	end

	local characterPosition =
		ballSpawn.Position
		+ Vector3.new(0, 2, 0)

	root.CFrame =
		CFrame.lookAt(
			characterPosition,
			characterPosition + Vector3.new(0, 0, 1),
			Vector3.new(0, 1, 0)
		)

end

--------------------------------------------------
-- DESTROY OLD BALL
--------------------------------------------------

local function destroyPlayerBall(player)

	local ball =
		playerBalls:FindFirstChild(
			getPlayerBallName(player)
		)

	if ball then

		ball:Destroy()

	end

end

--------------------------------------------------
-- CREATE BALL
--------------------------------------------------

local function createPlayerBall(
	player,
	character
)

	destroyPlayerBall(player)

	local ballData =
		BallDefinitions[STARTER_BALL_ID]

	if not ballData then

		warn(
			"[BallSpawner] Missing ball definition:",
			STARTER_BALL_ID
		)

		return nil

	end

	--------------------------------------------------
	-- CLONE
	--------------------------------------------------

	local ball =
		ballTemplate:Clone()

	ball.Name =
		getPlayerBallName(player)

	--------------------------------------------------
	-- PHYSICS
	--------------------------------------------------

	ball.Anchored = false

	ball.CanCollide = true
	ball.CanTouch = true
	ball.CanQuery = true

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero

	--------------------------------------------------
	-- IDENTITY
	--------------------------------------------------

	ball:SetAttribute(
		"OwnerUserId",
		player.UserId
	)

	ball:SetAttribute(
		"BallId",
		STARTER_BALL_ID
	)

	--------------------------------------------------
	-- SPEED
	--------------------------------------------------

	ball:SetAttribute(
		"ForwardSpeed",
		ballData.ForwardSpeed
	)

	ball:SetAttribute(
		"HorizontalSpeed",
		ballData.HorizontalSpeed
	)

	--------------------------------------------------
	-- SPAWN POSITION + ROTATION
	--
	-- ALWAYS WORLD +Z.
	--------------------------------------------------

	ball.CFrame =
		getBallSpawnCFrame()

	--------------------------------------------------
	-- PARENT
	--------------------------------------------------

	ball.Parent =
		playerBalls

	--------------------------------------------------
	-- SERVER NETWORK OWNERSHIP
	--------------------------------------------------

	pcall(function()

		ball:SetNetworkOwner(nil)

	end)

	--------------------------------------------------
	-- HIDE CHARACTER
	--------------------------------------------------

	hideCharacter(character)

	positionCharacterAtSpawn(character)

	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"[BallSpawner]",
		"Created:",
		ball.Name,
		"Owner:",
		player.Name,
		"Position:",
		ball.Position,
		"LookVector:",
		ball.CFrame.LookVector
	)

	return ball

end

--------------------------------------------------
-- CHARACTER SETUP
--------------------------------------------------

local function setupCharacter(
	player,
	character
)

	local humanoidRootPart =
		character:WaitForChild(
			"HumanoidRootPart",
			10
		)

	if not humanoidRootPart then

		warn(
			"[BallSpawner]",
			"No HumanoidRootPart for",
			player.Name
		)

		return

	end

	createPlayerBall(
		player,
		character
	)

end

--------------------------------------------------
-- PLAYER JOIN
--------------------------------------------------

Players.PlayerAdded:Connect(
	function(player)

		player.CharacterAdded:Connect(
			function(character)

				setupCharacter(
					player,
					character
				)

			end
		)

	end
)

--------------------------------------------------
-- EXISTING PLAYERS
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	if player.Character then

		task.spawn(
			setupCharacter,
			player,
			player.Character
		)

	end

	player.CharacterAdded:Connect(
		function(character)

			setupCharacter(
				player,
				character
			)

		end
	)

end

--------------------------------------------------
-- PLAYER LEAVE
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		destroyPlayerBall(player)

	end
)

--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"[BallSpawner] SERVER READY"
)

print(
	"[BallSpawner] Ball facing: WORLD +Z"
)
