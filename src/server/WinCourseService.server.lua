--------------------------------------------------
-- WIN COURSE SERVICE
--
-- SERVER ONLY
--
-- RESPONSIBILITY:
--
-- 1. Validate Win Course start
-- 2. Freeze/prep the ball
-- 3. Generate Win Course
-- 4. Move ball ONCE to official start
-- 5. Initialize Win Course speed state
-- 6. Initialize oil boost state
-- 7. Hand movement ownership to WinCourseProgressService
--
--
-- MOVEMENT OWNERSHIP:
--
-- BallPhysicsController
--     -> Lobby
--     -> Normal Course
--
-- WinCourseProgressService
--     -> Win Course
--
-- WinCourseService NEVER moves the ball after
-- activation.
--
--
-- WIN COURSE BALL:
--
--     Anchored = true
--     Server owned
--
--
-- SPEED:
--
-- BallDefinitions.ForwardSpeed
--     -> base Win Course speed
--
-- WinCourseOilBoost
--     -> oil speed multiplier
--
-- WinCourseCurrentSpeed
--     -> authoritative current speed
--
-- WinCourseProgressService is responsible for
-- accelerating this speed every frame.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ServerScriptService =
	game:GetService("ServerScriptService")

local Workspace =
	game:GetService("Workspace")


--------------------------------------------------
-- BALL DEFINITIONS
--------------------------------------------------

local BallDefinitions =
	require(
		ServerScriptService:WaitForChild(
			"BallDefinitions"
		)
	)


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local playerBalls =
	Workspace:WaitForChild(
		"PlayerBalls"
	)

local course =
	Workspace:WaitForChild(
		"Course"
	)


--------------------------------------------------
-- START WIN COURSE EVENT
--------------------------------------------------

local startWinCourse =
	ServerScriptService:WaitForChild(
		"StartWinCourse"
	)


if not startWinCourse:IsA("BindableEvent") then

	error(
		"[WinCourseService] StartWinCourse MUST be a BindableEvent."
	)

end


--------------------------------------------------
-- WIN COURSE GENERATOR
--------------------------------------------------

local generatorModule =
	ServerScriptService:WaitForChild(
		"WinCourseGenerator"
	)


if not generatorModule:IsA("ModuleScript") then

	error(
		"[WinCourseService] WinCourseGenerator must be a ModuleScript."
	)

end


local requireSuccess,
	WinCourseGenerator =
	pcall(function()

		return require(generatorModule)

	end)


if not requireSuccess then

	error(
		"[WinCourseService] Failed to require WinCourseGenerator:\n"
		.. tostring(WinCourseGenerator)
	)

end


if type(WinCourseGenerator) ~= "table" then

	error(
		"[WinCourseService] WinCourseGenerator must return a table."
	)

end


if type(WinCourseGenerator.Generate) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.Generate() is missing."
	)

end


--------------------------------------------------
-- OFFICIAL START POSITION
--------------------------------------------------

if type(WinCourseGenerator.GetStartPosition) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.GetStartPosition() is missing."
	)

end


--------------------------------------------------
-- TILE SPACING
--------------------------------------------------

if type(WinCourseGenerator.GetTileSpacing) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.GetTileSpacing() is missing."
	)

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

--------------------------------------------------
-- Same acceleration model as normal course.
--
-- BallPhysicsController uses:
--
--     COURSE_ACCELERATION = 12
--
-- Keep the Win Course identical.
--------------------------------------------------

local WIN_COURSE_ACCELERATION =
	12


--------------------------------------------------
-- Starting speed.
--
-- This is only a fallback.
--
-- The actual ball ForwardSpeed from
-- BallDefinitions is preferred.
--------------------------------------------------

local WIN_COURSE_FALLBACK_SPEED =
	10


--------------------------------------------------
-- Minimum speed.
--------------------------------------------------

local WIN_COURSE_MIN_SPEED =
	6


--------------------------------------------------
-- Oil boost.
--
-- The ProgressService should increase this when
-- oil is collected.
--
-- This value is intentionally initialized to 0.
--------------------------------------------------

local DEFAULT_OIL_BOOST =
	0


--------------------------------------------------
-- STATE
--------------------------------------------------

local winCourseBusy = {}


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
--------------------------------------------------

local function getBallDefinition(
	ball
)

	if not ball then

		return nil

	end


	local ballId =
		ball:GetAttribute(
			"BallId"
		)


	if typeof(ballId) ~= "string" then

		ballId =
			ball:GetAttribute(
				"BallType"
			)

	end


	if typeof(ballId) ~= "string" then

		return nil

	end


	local definition =
		BallDefinitions[
			ballId
		]


	if typeof(definition) ~= "table" then

		warn(
			"[WinCourseService] Missing BallDefinitions entry:",
			ballId
		)

		return nil

	end


	return definition

end


--------------------------------------------------
-- GET BALL FORWARD SPEED
--
-- THIS IS THE BALL'S ACTUAL SPEED.
--
-- BallDefinitions is authoritative.
--------------------------------------------------

local function getBallForwardSpeed(
	ball
)

	local definition =
		getBallDefinition(
			ball
		)


	if definition
		and isFiniteNumber(
			definition.ForwardSpeed
		)
		and definition.ForwardSpeed > 0 then

		return definition.ForwardSpeed

	end


	--------------------------------------------------
	-- Attribute fallback
	--------------------------------------------------

	local attributeSpeed =
		ball:GetAttribute(
			"ForwardSpeed"
		)


	if isFiniteNumber(
		attributeSpeed
	)
	and attributeSpeed > 0 then

		return attributeSpeed

	end


	--------------------------------------------------
	-- Final fallback
	--------------------------------------------------

	return WIN_COURSE_FALLBACK_SPEED

end


--------------------------------------------------
-- GET HORIZONTAL SPEED
--
-- Stored as WinCourseHorizontalSpeed so the
-- ProgressService can optionally use it.
--------------------------------------------------

local function getBallHorizontalSpeed(
	ball
)

	local definition =
		getBallDefinition(
			ball
		)


	if definition
		and isFiniteNumber(
			definition.HorizontalSpeed
		)
		and definition.HorizontalSpeed > 0 then

		return definition.HorizontalSpeed

	end


	local attributeSpeed =
		ball:GetAttribute(
			"HorizontalSpeed"
		)


	if isFiniteNumber(
		attributeSpeed
	)
	and attributeSpeed > 0 then

		return attributeSpeed

	end


	return getBallForwardSpeed(
		ball
	)

end


--------------------------------------------------
-- GET OIL BOOST
--
-- Supports an existing oil boost attribute if
-- another service already placed one on the ball.
--
-- Otherwise starts at 0.
--------------------------------------------------

local function getExistingOilBoost(
	ball
)

	local boostNames = {

		"OilBoost",
		"WinCourseOilBoost",
		"OilSpeedBoost",

	}


	for _, attributeName in ipairs(
		boostNames
	) do

		local value =
			ball:GetAttribute(
				attributeName
			)


		if isFiniteNumber(
			value
		)
		and value >= 0 then

			return value

		end

	end


	return DEFAULT_OIL_BOOST

end


--------------------------------------------------
-- INITIALIZE WIN COURSE SPEED
--
-- THIS DOES NOT MOVE THE BALL.
--
-- It only establishes authoritative values that
-- WinCourseProgressService will consume.
--------------------------------------------------

local function initializeWinCourseSpeed(
	ball
)

	if not ball
		or not ball:IsA("BasePart") then

		return false

	end


	--------------------------------------------------
	-- BALL'S ACTUAL BASE SPEED
	--------------------------------------------------

	local baseSpeed =
		getBallForwardSpeed(
			ball
		)


	--------------------------------------------------
	-- BALL'S HORIZONTAL SPEED
	--------------------------------------------------

	local horizontalSpeed =
		getBallHorizontalSpeed(
			ball
		)


	--------------------------------------------------
	-- OIL
	--------------------------------------------------

	local oilBoost =
		getExistingOilBoost(
			ball
		)


	--------------------------------------------------
	-- SANITIZE
	--------------------------------------------------

	baseSpeed =
		math.max(
			baseSpeed,
			WIN_COURSE_MIN_SPEED
		)


	horizontalSpeed =
		math.max(
			horizontalSpeed,
			0
		)


	oilBoost =
		math.max(
			oilBoost,
			0
		)


	--------------------------------------------------
	-- INITIAL SPEED
	--
	-- Oil boost is represented as an additive
	-- percentage multiplier.
	--
	-- Example:
	--
	-- base = 40
	-- oil  = 0.25
	--
	-- current = 50
	--------------------------------------------------

	local currentSpeed =
		baseSpeed
		*
		(
			1
			+
			oilBoost
		)


	--------------------------------------------------
	-- ATTRIBUTES
	--
	-- WinCourseProgressService should read these.
	--------------------------------------------------

	ball:SetAttribute(
		"WinCourseBaseSpeed",
		baseSpeed
	)


	ball:SetAttribute(
		"WinCourseHorizontalSpeed",
		horizontalSpeed
	)


	ball:SetAttribute(
		"WinCourseOilBoost",
		oilBoost
	)


	ball:SetAttribute(
		"WinCourseAcceleration",
		WIN_COURSE_ACCELERATION
	)


	ball:SetAttribute(
		"WinCourseMinSpeed",
		WIN_COURSE_MIN_SPEED
	)


	ball:SetAttribute(
		"WinCourseCurrentSpeed",
		currentSpeed
	)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"[WinCourseService]",
		"Win Course speed initialized:",
		"BaseSpeed =",
		baseSpeed,
		"HorizontalSpeed =",
		horizontalSpeed,
		"OilBoost =",
		oilBoost,
		"CurrentSpeed =",
		currentSpeed,
		"Acceleration =",
		WIN_COURSE_ACCELERATION
	)


	return true

end


--------------------------------------------------
-- GET OFFICIAL START POSITION
--------------------------------------------------

local function getWinCourseStartPosition()

	local startPosition =
		WinCourseGenerator.GetStartPosition()


	if typeof(startPosition) ~= "Vector3" then

		error(
			"[WinCourseService] "
			.. "WinCourseGenerator.GetStartPosition() "
			.. "must return a Vector3."
		)

	end


	return startPosition

end


--------------------------------------------------
-- REMOVE LOBBY WIN PREVIEW
--------------------------------------------------

local function removeLobbyWinPreview()

	local previewNames = {

		"LobbyWinCourse",
		"WinCoursePreview",

	}


	for _, previewName in ipairs(
		previewNames
	) do

		local preview =
			course:FindFirstChild(
				previewName
			)


		if preview then

			print(
				"[WinCourseService] Removing lobby preview:",
				preview:GetFullName()
			)

			preview:Destroy()

		end

	end

end


--------------------------------------------------
-- REMOVE OLD ACTUAL WIN COURSE
--------------------------------------------------

local function removeOldWinCourse()

	local oldCourse =
		course:FindFirstChild(
			"WinCourse"
		)


	if oldCourse then

		print(
			"[WinCourseService] Removing old WinCourse:",
			oldCourse:GetFullName()
		)

		oldCourse:Destroy()

	end

end


--------------------------------------------------
-- HARD FREEZE BALL
--
-- This only prepares the ball.
--
-- It does NOT provide Win Course movement.
--------------------------------------------------

local function freezeBall(
	ball
)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return false

	end

	-- The server drives the ball from here on.
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)

	-- NOT a hard freeze any more: the ball keeps the momentum it arrived with
	-- and WinCourseProgressService eases it to the middle of the WinCourse
	-- start (beginGlideToStart). It used to be stopped dead and teleported.
	local linearVelocity =
		ball:FindFirstChild(
			"BallLinearVelocity"
		)

	if linearVelocity
		and linearVelocity:IsA(
			"LinearVelocity"
		) then

		linearVelocity.Enabled =
			false

	end

	return true

end

--------------------------------------------------
-- MOVE BALL TO OFFICIAL WIN START
--
-- THIS IS THE ONLY MOVEMENT THIS SERVICE DOES.
--
-- It happens once during initialization.
--------------------------------------------------

local function moveBallToStart(
	ball
)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return false

	end

	-- Movement is handled by WinCourseProgressService.beginGlideToStart, which
	-- eases the ball to the official start instead of teleporting it there.
	return true

end

--------------------------------------------------
-- VALIDATE REQUEST
--------------------------------------------------

local function validateWinCourseRequest(
	player,
	ball
)

	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

	if not player
		or not player:IsA("Player") then

		warn(
			"[WinCourseService] Invalid player."
		)

		return false

	end


	--------------------------------------------------
	-- BALL
	--------------------------------------------------

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid ball."
		)

		return false

	end


	--------------------------------------------------
	-- BALL LOCATION
	--------------------------------------------------

	if ball.Parent ~= playerBalls then

		warn(
			"[WinCourseService]",
			player.Name,
			"Ball is not directly inside PlayerBalls."
		)

		return false

	end


	--------------------------------------------------
	-- BALL NAME
	--------------------------------------------------

	local expectedName =
		"PlayerBall_"
		..
		tostring(
			player.UserId
		)


	if ball.Name ~= expectedName then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid ball:",
			ball.Name,
			"Expected:",
			expectedName
		)

		return false

	end


	--------------------------------------------------
	-- OWNER
	--------------------------------------------------

	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	if ownerUserId ~= player.UserId then

		warn(
			"[WinCourseService]",
			player.Name,
			"Ball ownership mismatch."
		)

		return false

	end


	--------------------------------------------------
	-- RUN STATE
	--------------------------------------------------

	local runState =
		player:GetAttribute(
			"RunState"
		)


	if runState ~= "Finishing" then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid RunState:",
			runState
		)

		return false

	end


	return true

end


--------------------------------------------------
-- COUNT GENERATED TILES
--------------------------------------------------

local function countGeneratedTiles(
	winCourse
)

	local tileCount =
		0


	for _, child in ipairs(
		winCourse:GetChildren()
	) do

		if child:IsA("Model")
			and child.Name:match(
				"^WinTile_"
			) then

			tileCount += 1

		end

	end


	return tileCount

end


--------------------------------------------------
-- VERIFY GENERATED WIN COURSE
--------------------------------------------------

local function verifyGeneratedWinCourse(
	winCourse
)

	if not winCourse
		or not winCourse:IsA("Folder") then

		warn(
			"[WinCourseService] Generated WinCourse is not a Folder."
		)

		return false

	end


	if winCourse.Parent ~= course then

		warn(
			"[WinCourseService] Generated WinCourse is not directly inside Workspace.Course."
		)

		return false

	end


	if winCourse:GetAttribute(
		"IsWinCourse"
	) ~= true then

		warn(
			"[WinCourseService] Generated WinCourse is missing IsWinCourse attribute."
		)

		return false

	end


	local tileCount =
		countGeneratedTiles(
			winCourse
		)


	local expectedCount =
		winCourse:GetAttribute(
			"TileCount"
		)


	if expectedCount
		and tileCount ~= expectedCount then

		warn(
			"[WinCourseService] Tile count mismatch:",
			tileCount,
			"expected",
			expectedCount
		)

		return false

	end


	for _, tile in ipairs(
		winCourse:GetChildren()
	) do

		if tile:IsA("Model")
			and tile.Name:match(
				"^WinTile_"
			) then


			--------------------------------------------------
			-- FLOOR
			--------------------------------------------------

			local floor =
				tile:FindFirstChild(
					"Floor"
				)


			if not floor
				or not floor:IsA(
					"BasePart"
				) then

				warn(
					"[WinCourseService] Tile missing Floor:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- TROPHY DISPLAY
			--------------------------------------------------

			local trophyDisplay =
				tile:FindFirstChild(
					"TrophyDisplay"
				)


			if not trophyDisplay
				or not trophyDisplay:IsA(
					"BasePart"
				) then

				warn(
					"[WinCourseService] Tile missing direct TrophyDisplay:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- SURFACE GUI
			--------------------------------------------------

			local surfaceGui =
				trophyDisplay:FindFirstChild(
					"SurfaceGui"
				)


			if not surfaceGui
				or not surfaceGui:IsA(
					"SurfaceGui"
				) then

				warn(
					"[WinCourseService] Tile missing TrophyDisplay.SurfaceGui:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- IMAGE LABEL
			--------------------------------------------------

			local imageLabel =
				surfaceGui:FindFirstChild(
					"ImageLabel"
				)


			if not imageLabel
				or not imageLabel:IsA(
					"ImageLabel"
				) then

				warn(
					"[WinCourseService] Tile missing SurfaceGui.ImageLabel:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- WIN AMOUNT
			--------------------------------------------------

			local winAmount =
				surfaceGui:FindFirstChild(
					"WinAmount"
				)


			if not winAmount
				or not winAmount:IsA(
					"TextLabel"
				) then

				warn(
					"[WinCourseService] Tile missing SurfaceGui.WinAmount:",
					tile:GetFullName()
				)

				return false

			end

		end

	end


	return true

end


--------------------------------------------------
-- GENERATE WIN COURSE
--------------------------------------------------

local function generateWinCourse(
	player
)

	print("================================")

	print(
		"[WinCourseService] GENERATING WIN COURSE FOR:",
		player.Name
	)

	print("================================")


	removeLobbyWinPreview()

	removeOldWinCourse()


	local success,
		result =
		pcall(function()

			return WinCourseGenerator.Generate()

		end)


	if not success then

		warn(
			"[WinCourseService] WinCourseGenerator ERROR:"
		)

		warn(
			tostring(result)
		)

		return nil

	end


	if not result then

		warn(
			"[WinCourseService] WinCourseGenerator returned nil."
		)

		return nil

	end


	if not result:IsDescendantOf(
		course
	) then

		warn(
			"[WinCourseService] Generated WinCourse is not inside Workspace.Course."
		)

		return nil

	end


	if not verifyGeneratedWinCourse(
		result
	) then

		warn(
			"[WinCourseService] Generated WinCourse failed verification."
		)

		return nil

	end


	local tileCount =
		countGeneratedTiles(
			result
		)


	print("================================")

	print(
		"[WinCourseService] WIN COURSE GENERATED"
	)

	print(
		"[WinCourseService] Folder:",
		result:GetFullName()
	)

	print(
		"[WinCourseService] Tiles:",
		tileCount
	)

	print(
		"[WinCourseService] Start Position:",
		getWinCourseStartPosition()
	)

	print(
		"[WinCourseService] Tile Spacing:",
		WinCourseGenerator.GetTileSpacing()
	)

	print("================================")


	return result

end


--------------------------------------------------
-- PLAYER CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(
		player
	)

		winCourseBusy[player] =
			nil

	end
)


--------------------------------------------------
-- START WIN COURSE
--------------------------------------------------

startWinCourse.Event:Connect(
	function(
		player,
		ball
	)

		print("================================")

		print(
			"[WinCourseService] StartWinCourse EVENT RECEIVED:",
			player and player.Name,
			ball and ball.Name
		)

		print("================================")


		--------------------------------------------------
		-- VALIDATE
		--------------------------------------------------

		if not validateWinCourseRequest(
			player,
			ball
		) then

			return

		end


		--------------------------------------------------
		-- PREVENT DOUBLE START
		--------------------------------------------------

		if winCourseBusy[player] then

			warn(
				"[WinCourseService]",
				player.Name,
				"WinCourse already active."
			)

			return

		end


		winCourseBusy[player] =
			true


		--------------------------------------------------
		-- FREEZE
		--------------------------------------------------

		if not freezeBall(
			ball
		) then

			winCourseBusy[player] =
				nil

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO FREEZE BALL"
			)

			return

		end


		print(
			"[WinCourseService]",
			player.Name,
			"BALL HARD FROZEN"
		)


		--------------------------------------------------
		-- MARK ACTIVE
		--------------------------------------------------

		ball:SetAttribute(
			"WinCourseActive",
			true
		)


		--------------------------------------------------
		-- GENERATE COURSE
		--------------------------------------------------

		local winCourse =
			generateWinCourse(
				player
			)


		if not winCourse then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO GENERATE WIN COURSE"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- MOVE BALL TO START
		--------------------------------------------------

		if not moveBallToStart(
			ball
		) then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO MOVE BALL TO WIN COURSE"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- INITIALIZE SPEED
		--
		-- IMPORTANT:
		--
		-- This uses the actual ball's
		-- BallDefinitions.ForwardSpeed.
		--
		-- Oil boost is also initialized.
		--
		-- WinCourseProgressService will accelerate
		-- and update the current speed.
		--------------------------------------------------

		if not initializeWinCourseSpeed(
			ball
		) then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO INITIALIZE WIN COURSE SPEED"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- KEEP RUN STATE FINISHING
		--------------------------------------------------

		player:SetAttribute(
			"RunState",
			"Finishing"
		)


		--------------------------------------------------
		-- READY
		--------------------------------------------------

		print("================================")

		print(
			"[WinCourseService]",
			player.Name,
			"WIN COURSE ACTIVE"
		)

		print(
			"[WinCourseService]",
			"Ball remains ANCHORED."
		)

		print(
			"[WinCourseService]",
			"Ball remains SERVER OWNED."
		)

		print(
			"[WinCourseService]",
			"Base Ball Speed:",
			ball:GetAttribute(
				"WinCourseBaseSpeed"
			)
		)

		print(
			"[WinCourseService]",
			"Oil Boost:",
			ball:GetAttribute(
				"WinCourseOilBoost"
			)
		)

		print(
			"[WinCourseService]",
			"Current Speed:",
			ball:GetAttribute(
				"WinCourseCurrentSpeed"
			)
		)

		print(
			"[WinCourseService]",
			"Acceleration:",
			ball:GetAttribute(
				"WinCourseAcceleration"
			)
		)

		print(
			"[WinCourseService]",
			"WinCourseProgressService now controls movement."
		)

		print("================================")

	end
)


--------------------------------------------------
-- SERVER READY
--------------------------------------------------

print("================================")

print(
	"[WinCourseService] SERVER READY"
)

print(
	"[WinCourseService] StartWinCourse:",
	startWinCourse:GetFullName()
)

print(
	"[WinCourseService] StartWinCourse Class:",
	startWinCourse.ClassName
)

print(
	"[WinCourseService] WinCourseGenerator:",
	generatorModule:GetFullName()
)

print(
	"[WinCourseService] Win Course Start:",
	getWinCourseStartPosition()
)

print(
	"[WinCourseService] Win Course Spacing:",
	WinCourseGenerator.GetTileSpacing()
)

print(
	"[WinCourseService] BALL MOVEMENT:",
	"WinCourseProgressService ONLY"
)

print(
	"[WinCourseService] BALL ANCHORED:",
	"TRUE"
)

print(
	"[WinCourseService] WIN COURSE ACCELERATION:",
	WIN_COURSE_ACCELERATION
)

print(
	"[WinCourseService] BALL SPEED:",
	"BallDefinitions.ForwardSpeed"
)

print(
	"[WinCourseService] OIL BOOST:",
	"WinCourseOilBoost"
)

print("================================")