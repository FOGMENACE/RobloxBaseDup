--------------------------------------------------
-- BALL SPAWNER
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > BallSpawner
--
-- PURPOSE:
--
-- Creates and manages the player's physical
-- bowling ball.
--
-- IMPORTANT ARCHITECTURE:
--
-- BallSpawner is ONLY responsible for:
--
-- - Creating the physical ball
-- - Validating the equipped ball
-- - Setting ball identity
-- - Setting physical properties
-- - Positioning the ball
-- - Giving the server network ownership
-- - Placing the ball into workspace.PlayerBalls
--
-- BallSpawner DOES NOT:
--
-- - Read player movement input
-- - Receive movement RemoteEvents
-- - Create BallInput
-- - Create BallMovement
-- - Set LinearVelocity
-- - Set VectorVelocity
-- - Move the ball
-- - Accelerate the ball
-- - Control course speed
-- - Control lobby speed
-- - Control RunState
--
-- BallPhysicsController is the SOLE owner of
-- ball movement.
--
-- BallPhysicsController creates and maintains:
--
--     BallAttachment
--     BallLinearVelocity
--
-- BallPhysicsController also owns:
--
--     Network ownership
--     Movement
--     Acceleration
--     Stopping
--     WinCourse handoff
--     Movement validation
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService(
		"Players"
	)

local ServerStorage =
	game:GetService(
		"ServerStorage"
	)

local ServerScriptService =
	game:GetService(
		"ServerScriptService"
	)

local PhysicsService =
	game:GetService(
		"PhysicsService"
	)


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates =
	ServerStorage:WaitForChild(
		"Templates"
	)


local universalBallTemplate =
	templates:FindFirstChild(
		"BowlingBall"
	)


--------------------------------------------------
-- SERVER-ONLY BALL DEFINITIONS
--------------------------------------------------

local BallDefinitions =
	require(
		ServerScriptService:WaitForChild(
			"BallDefinitions"
		)
	)


--------------------------------------------------
-- WORLD
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)


local ballSpawn =
	workspace:WaitForChild(
		"BallSpawn"
	)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local PLAYER_BALL_PREFIX =
	"PlayerBall_"


local CHARACTER_COLLISION_GROUP =
	"HiddenPlayerCharacter"


local EQUIPPED_BALL_ATTRIBUTE =
	"EquippedBall"


--------------------------------------------------
-- VALIDATE BALL SPAWN
--------------------------------------------------

if not ballSpawn:IsA("BasePart") then

	error(
		"[BallSpawner] Workspace.BallSpawn must be a BasePart."
	)

end


--------------------------------------------------
-- VALIDATE PLAYER BALL FOLDER
--------------------------------------------------

if not playerBalls:IsA("Folder") then

	warn(
		"[BallSpawner]",
		"Workspace.PlayerBalls is not a Folder.",
		"Expected Folder, found:",
		playerBalls.ClassName
	)

end


--------------------------------------------------
-- VALIDATE UNIVERSAL TEMPLATE
--------------------------------------------------

if universalBallTemplate
	and not universalBallTemplate:IsA(
		"BasePart"
	) then

	warn(
		"[BallSpawner]",
		"Templates.BowlingBall exists but is not a BasePart."
	)

	universalBallTemplate =
		nil

end


--------------------------------------------------
-- BALL NAME
--------------------------------------------------

local function getPlayerBallName(
	player
)

	return PLAYER_BALL_PREFIX
		..
		tostring(
			player.UserId
		)

end


--------------------------------------------------
-- FINITE NUMBER
--------------------------------------------------

local function isFiniteNumber(
	value
)

	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge

end


--------------------------------------------------
-- GET BALL DEFINITION
--
-- SERVER ONLY.
--------------------------------------------------

local function getBallDefinition(
	ballId
)

	if typeof(ballId) ~= "string"
		or ballId == "" then

		return nil

	end


	local definition =
		BallDefinitions[
			ballId
		]


	if typeof(definition) ~= "table" then

		return nil

	end


	return definition

end


--------------------------------------------------
-- VALIDATE BALL DEFINITION
--------------------------------------------------

local function validateBallDefinition(
	ballId,
	definition
)

	if typeof(ballId) ~= "string"
		or ballId == "" then

		return false,
			"INVALID_BALL_ID"

	end


	if typeof(definition) ~= "table" then

		return false,
			"INVALID_DEFINITION"

	end


	--------------------------------------------------
	-- FORWARD SPEED
	--------------------------------------------------

	if not isFiniteNumber(
		definition.ForwardSpeed
	)
	or definition.ForwardSpeed <= 0 then

		return false,
			"INVALID_FORWARD_SPEED"

	end


	--------------------------------------------------
	-- HORIZONTAL SPEED
	--------------------------------------------------

	if not isFiniteNumber(
		definition.HorizontalSpeed
	)
	or definition.HorizontalSpeed <= 0 then

		return false,
			"INVALID_HORIZONTAL_SPEED"

	end


	return true,
		"VALID"

end


--------------------------------------------------
-- GET EQUIPPED BALL ID
--
-- BallService owns the actual ownership/equip
-- decision.
--
-- BallSpawner only validates the resulting
-- server attribute against BallDefinitions.
--------------------------------------------------

local function getEquippedBallId(
	player
)

	local equippedBall =
		player:GetAttribute(
			EQUIPPED_BALL_ATTRIBUTE
		)


	if typeof(equippedBall) ~= "string"
		or equippedBall == "" then

		return nil

	end


	local definition =
		getBallDefinition(
			equippedBall
		)


	if not definition then

		warn(
			"[BallSpawner]",
			"Missing BallDefinitions entry:",
			"Player:",
			player.Name,
			"BallId:",
			equippedBall
		)

		return nil

	end


	local valid,
		reason =
		validateBallDefinition(
			equippedBall,
			definition
		)


	if not valid then

		warn(
			"[BallSpawner]",
			"Invalid BallDefinition:",
			"Player:",
			player.Name,
			"BallId:",
			equippedBall,
			"Reason:",
			reason
		)

		return nil

	end


	return equippedBall

end


--------------------------------------------------
-- GET BALL TEMPLATE
--
-- PRIORITY:
--
-- 1. Templates/<BallId>
-- 2. Templates/BowlingBall
--------------------------------------------------

local function getBallTemplate(
	ballId
)

	--------------------------------------------------
	-- BALL-SPECIFIC TEMPLATE
	--------------------------------------------------

	local specificTemplate =
		templates:FindFirstChild(
			ballId
		)


	if specificTemplate
		and specificTemplate:IsA(
			"BasePart"
		) then

		return specificTemplate

	end


	--------------------------------------------------
	-- BALL MODEL (ReplicatedStorage.BallModels/<BallId>)
	--
	-- The real mesh, colour and textures of every ball live here (it
	-- is also what the shop previews). Without this the spawner fell
	-- back to the plain universal Part, so every ball, StraightBall
	-- included, spawned as an unintended grey sphere.
	--------------------------------------------------

	local ballModels =
		game:GetService("ReplicatedStorage"):FindFirstChild(
			"BallModels"
		)

	local modelTemplate =
		ballModels
		and ballModels:FindFirstChild(
			ballId
		)

	if modelTemplate
		and modelTemplate:IsA(
			"BasePart"
		) then
		return modelTemplate
	end

	--------------------------------------------------
	-- UNIVERSAL TEMPLATE
	--------------------------------------------------

	if universalBallTemplate then

		return universalBallTemplate

	end


	--------------------------------------------------
	-- NO TEMPLATE
	--------------------------------------------------

	warn(
		"[BallSpawner]",
		"No valid physical ball template found:",
		ballId
	)

	return nil

end


--------------------------------------------------
-- CHARACTER COLLISION GROUP
--------------------------------------------------

pcall(function()

	PhysicsService:RegisterCollisionGroup(
		CHARACTER_COLLISION_GROUP
	)

end)


--------------------------------------------------
-- CHARACTER COLLISION SETTINGS
--------------------------------------------------

pcall(function()

	PhysicsService:CollisionGroupSetCollidable(
		CHARACTER_COLLISION_GROUP,
		"Default",
		false
	)

	PhysicsService:CollisionGroupSetCollidable(
		CHARACTER_COLLISION_GROUP,
		CHARACTER_COLLISION_GROUP,
		false
	)

end)


--------------------------------------------------
-- DISABLE CHARACTER
--
-- The player character is effectively hidden and
-- prevented from interfering with the physical ball.
--
-- This function DOES NOT control the ball.
--------------------------------------------------

local function disableCharacter(
	character
)

	if not character then

		return

	end


	--------------------------------------------------
	-- HUMANOID
	--------------------------------------------------

	local humanoid =
		character:FindFirstChildOfClass(
			"Humanoid"
		)


	if humanoid then

		humanoid.WalkSpeed =
			0

		humanoid.JumpPower =
			0

		humanoid.JumpHeight =
			0

		humanoid.AutoRotate =
			false


		--------------------------------------------------
		-- DISABLE CHARACTER STATES
		--------------------------------------------------

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.FallingDown,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Ragdoll,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Running,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Jumping,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Freefall,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Climbing,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Swimming,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Seated,
			false
		)

		humanoid:SetStateEnabled(
			Enum.HumanoidStateType.Physics,
			false
		)

	end


	--------------------------------------------------
	-- CHARACTER PARTS
	--------------------------------------------------

	for _, descendant in ipairs(
		character:GetDescendants()
	) do

		--------------------------------------------------
		-- PARTS
		--------------------------------------------------

		if descendant:IsA(
			"BasePart"
		) then

			descendant.Transparency =
				1

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false

			descendant.CollisionGroup =
				CHARACTER_COLLISION_GROUP

			descendant.Anchored =
				true

			descendant.AssemblyLinearVelocity =
				Vector3.zero

			descendant.AssemblyAngularVelocity =
				Vector3.zero


		--------------------------------------------------
		-- DECALS
		--------------------------------------------------

		elseif descendant:IsA(
			"Decal"
		) then

			descendant.Transparency =
				1


		--------------------------------------------------
		-- VISUAL EFFECTS
		--------------------------------------------------

		elseif descendant:IsA(
			"ParticleEmitter"
		)
			or descendant:IsA(
				"Trail"
			)
			or descendant:IsA(
				"Beam"
			) then

			descendant.Enabled =
				false


		--------------------------------------------------
		-- SOUNDS
		--------------------------------------------------

		elseif descendant:IsA(
			"Sound"
		) then

			descendant:Stop()

			descendant.Volume =
				0

			descendant.Playing =
				false

		end

	end

end


--------------------------------------------------
-- POSITION CHARACTER
--------------------------------------------------

local function positionCharacterAtSpawn(
	character
)

	if not character then

		return

	end


	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)


	if not root then

		return

	end


	local characterPosition =
		ballSpawn.Position
		+
		Vector3.new(
			0,
			10,
			0
		)


	root.CFrame =
		CFrame.lookAt(

			characterPosition,

			characterPosition
				+
				Vector3.new(
					0,
					0,
					1
				),

			Vector3.new(
				0,
				1,
				0
			)

		)

end


--------------------------------------------------
-- GET TEMPLATE RADIUS
--------------------------------------------------

local function getTemplateRadius(
	template
)

	if not template:IsA(
		"BasePart"
	) then

		return 1

	end


	return math.max(

		template.Size.X,

		template.Size.Y,

		template.Size.Z

	) / 2

end


--------------------------------------------------
-- GET BALL SPAWN CFRAME
--------------------------------------------------

local function getBallSpawnCFrame(
	template
)

	local ballRadius =
		getTemplateRadius(
			template
		)


	local spawnPosition =
		ballSpawn.Position
		+
		Vector3.new(

			0,

			ballSpawn.Size.Y / 2
				+
				ballRadius
				+
				0.05,

			0

		)


	return CFrame.lookAt(

		spawnPosition,

		spawnPosition
			+
			Vector3.new(
				0,
				0,
				1
			),

		Vector3.new(
			0,
			1,
			0
		)

	)

end


--------------------------------------------------
-- DESTROY PLAYER BALL
--------------------------------------------------

local function destroyPlayerBall(
	player
)

	local ballName =
		getPlayerBallName(
			player
		)


	local oldBall =
		playerBalls:FindFirstChild(
			ballName
		)


	if not oldBall then

		return

	end


	--------------------------------------------------
	-- ONLY DESTROY THE PLAYER'S ACTUAL BALL.
	--------------------------------------------------

	if oldBall:IsA(
		"BasePart"
	)
	and oldBall:GetAttribute(
		"OwnerUserId"
	) == player.UserId then

		oldBall:Destroy()

	end

end


--------------------------------------------------
-- CREATE PLAYER BALL
--------------------------------------------------

local function createPlayerBall(
	player,
	character,
	options
)

	--------------------------------------------------
	-- PLAYER VALIDATION
	--------------------------------------------------

	if not player
		or not player:IsDescendantOf(
			Players
		) then

		return nil

	end


	--------------------------------------------------
	-- CHARACTER VALIDATION
	--------------------------------------------------

	if not character
		or not character:IsDescendantOf(
			workspace
		) then

		return nil

	end


	--------------------------------------------------
	-- KEEP POSITION ON EQUIP
	--
	-- Equipping a ball in the lobby swaps the ball where it is instead
	-- of teleporting the player back to BallSpawn. Runs and the
	-- WinCourse keep the old behaviour.
	--------------------------------------------------

	local keepCFrame = nil

	do
		local oldBall =
			playerBalls:FindFirstChild(
				getPlayerBallName(
					player
				)
			)

		local currentRunState =
			player:GetAttribute(
				"RunState"
			)

		if oldBall
			and oldBall:IsA(
				"BasePart"
			)
			and oldBall:GetAttribute(
				"WinCourseActive"
			) ~= true
			and (
				currentRunState == nil
				or currentRunState == ""
				or currentRunState == "Waiting"
			) then

			-- Slight lift: the lobby ball is smaller than the new one.
			keepCFrame =
				oldBall.CFrame
				+ Vector3.new(0, 0.6, 0)

		end
	end

	-- A mid-run swap passes the exact CFrame to continue from.
	if options and typeof(options.CFrame) == "CFrame" then
		keepCFrame = options.CFrame
	end

	--------------------------------------------------
	-- REMOVE OLD BALL
	--------------------------------------------------

	destroyPlayerBall(
		player
	)


	--------------------------------------------------
	-- GET EQUIPPED BALL
	--------------------------------------------------

	-- options.BallId: a mid-run swap (BallTierGates) uses a specific ball
	-- instead of the equipped one. Validated by BallDefinitions below.
	local ballId =
		(
			options
			and typeof(options.BallId) == "string"
			and getBallDefinition(options.BallId)
			and options.BallId
		)
		or getEquippedBallId(
			player
		)


	if not ballId then

		warn(
			"[BallSpawner]",
			"Cannot create ball.",
			"Player:",
			player.Name
		)

		return nil

	end


	--------------------------------------------------
	-- GET BALL DATA
	--------------------------------------------------

	local ballData =
		getBallDefinition(
			ballId
		)


	if not ballData then

		return nil

	end


	--------------------------------------------------
	-- GET TEMPLATE
	--------------------------------------------------

	local template =
		getBallTemplate(
			ballId
		)


	if not template then

		return nil

	end


	--------------------------------------------------
	-- CHARACTER
	--------------------------------------------------

	disableCharacter(
		character
	)


	positionCharacterAtSpawn(
		character
	)


	--------------------------------------------------
	-- CLONE
	--------------------------------------------------

	local ball =
		template:Clone()


	ball.Name =
		getPlayerBallName(
			player
		)


	--------------------------------------------------
	-- PHYSICAL CONFIGURATION
	--
	-- IMPORTANT:
	--
	-- BallSpawner prepares the physical object.
	--
	-- BallPhysicsController owns movement.
	--------------------------------------------------

	ball.Anchored =
		false

	ball.CanCollide =
		true

	ball.CanTouch =
		true

	ball.CanQuery =
		true


	ball.Massless =
		false


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	--------------------------------------------------
	-- BALL IDENTITY
	--------------------------------------------------

	ball:SetAttribute(
		"OwnerUserId",
		player.UserId
	)


	ball:SetAttribute(
		"BallId",
		ballId
	)


	--------------------------------------------------
	-- MOVEMENT STATE
	--
	-- These attributes are state markers only.
	--
	-- They DO NOT control physics.
	--------------------------------------------------

	ball:SetAttribute(
		"WinCourseActive",
		false
	)


	ball:SetAttribute(
		"MovementActive",
		true
	)


	--------------------------------------------------
	-- IMPORTANT:
	--
	-- Do NOT put ForwardSpeed or HorizontalSpeed
	-- attributes on the ball.
	--
	-- BallPhysicsController reads BallDefinitions
	-- directly from ServerScriptService.
	--
	-- This prevents duplicate authoritative values.
	--------------------------------------------------


	--------------------------------------------------
	-- SPAWN POSITION
	--------------------------------------------------

	ball.CFrame =
		keepCFrame
		or getBallSpawnCFrame(
			template
		)


	--------------------------------------------------
	-- PARENT INTO PLAYER BALL FOLDER
	--
	-- Parent AFTER configuration so the physics
	-- controller sees a fully initialized ball.
	--------------------------------------------------

	-- Unique look for premium balls (cat, spikes, dragon, ...).
	require(
		game:GetService("ReplicatedStorage"):WaitForChild(
			"BallAccessories"
		)
	).Apply(
		ball,
		ballId
	)

	-- Mid-run swap: hand the course speed to BallPhysicsController.
	if options and typeof(options.CarrySpeed) == "number" then
		ball:SetAttribute(
			"CarrySpeed",
			options.CarrySpeed
		)
	end

	ball.Parent =
		playerBalls

	if options and typeof(options.Velocity) == "Vector3" then
		ball.AssemblyLinearVelocity =
			options.Velocity
	end


	--------------------------------------------------
	-- SERVER NETWORK OWNERSHIP
	--
	-- BallPhysicsController will also enforce this.
	--
	-- This is the initial ownership state only.
	--------------------------------------------------

	local ownershipSuccess,
		ownershipError =
		pcall(function()

			ball:SetNetworkOwner(
				nil
			)

		end)


	if not ownershipSuccess then

		warn(
			"[BallSpawner]",
			"Could not set server network ownership:",
			player.Name,
			ownershipError
		)

	end


	--------------------------------------------------
	-- FINAL PHYSICAL VALIDATION
	--------------------------------------------------

	if ball.Anchored then

		warn(
			"[BallSpawner]",
			"WARNING: Ball is still Anchored:",
			ball:GetFullName()
		)

	end


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"[BallSpawner]",
		"Created:",
		ball.Name,
		"| Player:",
		player.Name,
		"| BallId:",
		ballId,
		"| Position:",
		ball.Position,
		"| Anchored:",
		ball.Anchored,
		"| NetworkOwner:",
		ball:GetNetworkOwner()
	)


	return ball

end


--------------------------------------------------
-- MID-RUN BALL SWAP
--
-- BallTierGates fires this (server-only BindableEvent; clients cannot
-- reach it) to replace a player's ball with another ball model while
-- they keep rolling: same position, same velocity, same course speed.
--------------------------------------------------

local swapRunBall =
	ServerScriptService:FindFirstChild(
		"SwapRunBall"
	)

if not swapRunBall then

	swapRunBall =
		Instance.new(
			"BindableEvent"
		)

	swapRunBall.Name =
		"SwapRunBall"

	swapRunBall.Parent =
		ServerScriptService

end

swapRunBall.Event:Connect(
	function(
		player,
		ballId,
		cframe,
		velocity,
		carrySpeed
	)

		if not player
			or not player.Parent then

			return

		end

		local character =
			player.Character

		if not character then

			return

		end

		createPlayerBall(
			player,
			character,
			{
				BallId = ballId,
				CFrame = cframe,
				Velocity = velocity,
				CarrySpeed = carrySpeed,
			}
		)

	end
)


--------------------------------------------------
-- WAIT FOR EQUIPPED BALL
--------------------------------------------------

local function waitForEquippedBall(
	player,
	timeout
)

	timeout =
		timeout
		or 10


	local startTime =
		os.clock()


	while player.Parent
		and os.clock() - startTime < timeout do

		local equippedBall =
			player:GetAttribute(
				EQUIPPED_BALL_ATTRIBUTE
			)


		if typeof(equippedBall) == "string"
			and equippedBall ~= "" then

			return equippedBall

		end


		task.wait()

	end


	return nil

end


--------------------------------------------------
-- CHARACTER SETUP
--------------------------------------------------

local function setupCharacter(
	player,
	character
)

	--------------------------------------------------
	-- WAIT FOR ROOT
	--------------------------------------------------

	local humanoidRootPart =
		character:WaitForChild(
			"HumanoidRootPart",
			10
		)


	if not humanoidRootPart then

		warn(
			"[BallSpawner]",
			"No HumanoidRootPart:",
			player.Name
		)

		return

	end


	--------------------------------------------------
	-- WAIT FOR SERVER EQUIPPED BALL
	--------------------------------------------------

	local equippedBall =
		waitForEquippedBall(
			player,
			10
		)


	if not equippedBall then

		warn(
			"[BallSpawner]",
			"EquippedBall unavailable:",
			player.Name
		)

		return

	end


	--------------------------------------------------
	-- CREATE BALL
	--------------------------------------------------

	createPlayerBall(
		player,
		character
	)

end


--------------------------------------------------
-- EQUIPPED BALL CHANGED
--
-- BallService owns this attribute.
--
-- BallSpawner simply rebuilds the physical ball.
--------------------------------------------------

local function connectEquippedBallListener(
	player
)

	player:GetAttributeChangedSignal(
		EQUIPPED_BALL_ATTRIBUTE
	):Connect(
		function()

			if not player.Parent then

				return

			end


			local character =
				player.Character


			if not character then

				return

			end


			if not character:FindFirstChild(
				"HumanoidRootPart"
			) then

				return

			end


			print(
				"[BallSpawner]",
				player.Name,
				"EquippedBall changed:",
				player:GetAttribute(
					EQUIPPED_BALL_ATTRIBUTE
				)
			)


			createPlayerBall(
				player,
				character
			)

		end
	)

end


--------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------

local function setupPlayer(
	player
)

	--------------------------------------------------
	-- EQUIPPED BALL LISTENER
	--------------------------------------------------

	connectEquippedBallListener(
		player
	)


	--------------------------------------------------
	-- CHARACTER ADDED
	--------------------------------------------------

	player.CharacterAdded:Connect(
		function(character)

			task.spawn(
				function()

					setupCharacter(
						player,
						character
					)

				end
			)

		end
	)


	--------------------------------------------------
	-- CHARACTER ALREADY EXISTS
	--------------------------------------------------

	if player.Character then

		task.spawn(
			function()

				setupCharacter(
					player,
					player.Character
				)

			end
		)

	end

end


--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

Players.PlayerAdded:Connect(
	setupPlayer
)


--------------------------------------------------
-- EXISTING PLAYERS
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	task.spawn(
		function()

			setupPlayer(
				player
			)

		end
	)

end


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		destroyPlayerBall(
			player
		)

	end
)


--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"================================"
)

print(
	"[BallSpawner]",
	"SERVER READY"
)

print(
	"[BallSpawner]",
	"Ball Creation = ENABLED"
)

print(
	"[BallSpawner]",
	"Ball Movement = BallPhysicsController"
)

print(
	"[BallSpawner]",
	"Movement Input = BallController"
)

print(
	"[BallSpawner]",
	"BallMovement Remote = BallPhysicsController"
)

print(
	"[BallSpawner]",
	"Network Ownership = SERVER"
)

print(
	"[BallSpawner]",
	"Ball Definitions = ServerScriptService.BallDefinitions"
)

print(
	"[BallSpawner]",
	"Specific Templates = OPTIONAL"
)

print(
	"[BallSpawner]",
	"Universal BowlingBall Template = OPTIONAL"
)

print(
	"[BallSpawner]",
	"Automatic Ball Replacement = ENABLED"
)

print(
	"[BallSpawner]",
	"Character Physics = DISABLED"
)

print(
	"[BallSpawner]",
	"================================"
)