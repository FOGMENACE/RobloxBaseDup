--------------------------------------------------
-- WIN COURSE PROGRESS SERVICE
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > WinCourseProgressService
--
-- OIL FLOW:
--
-- OilCollection
--      ↓
-- player.CurrentOil
--      ↓
-- FinishWall
--      ↓
-- WinCourse becomes active
--      ↓
-- WinCourseProgressService reads CurrentOil
--      ↓
-- CurrentOil becomes travel distance
--      ↓
-- Ball moves through generated WinTiles
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local RunService =
	game:GetService("RunService")

local Workspace =
	game:GetService("Workspace")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local course =
	Workspace:WaitForChild(
		"Course"
	)

local playerBalls =
	Workspace:WaitForChild(
		"PlayerBalls"
	)

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--------------------------------------------------
-- REMOTE
--------------------------------------------------

local winCourseRemote =
	remotes:FindFirstChild(
		"WinCourse"
	)

if not winCourseRemote then

	winCourseRemote =
		Instance.new(
			"RemoteEvent"
		)

	winCourseRemote.Name =
		"WinCourse"

	winCourseRemote.Parent =
		remotes

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG = true


--------------------------------------------------
-- COUNTDOWN
--------------------------------------------------

local START_DELAY = 5


--------------------------------------------------
-- MOVEMENT SPEED
--------------------------------------------------

local WIN_COURSE_SPEED = 40


--------------------------------------------------
-- OIL DISTANCE
--
-- 1 CurrentOil = 1 stud
--------------------------------------------------

local OIL_PER_STUD = 1


--------------------------------------------------
-- UPDATE RATE
--------------------------------------------------

local UPDATE_INTERVAL = 0.016


--------------------------------------------------
-- BALL HEIGHT
--
-- 0 = automatically use half the ball height.
--------------------------------------------------

local BALL_VERTICAL_OFFSET = 0


--------------------------------------------------
-- TILE REACH TOLERANCE
--------------------------------------------------

local TILE_REACH_EPSILON = 0.25


--------------------------------------------------
-- POSITION TOLERANCE
--------------------------------------------------

local POSITION_EPSILON = 0.05


--------------------------------------------------
-- OIL SETTLE TIME
--
-- This gives OilCollection a tiny amount of time
-- to finish writing CurrentOil before we snapshot it.
--
-- This is NOT used to continuously modify oil.
--
-- It is only used when starting a WinCourse.
--------------------------------------------------

local OIL_SETTLE_TIME = 0.10


--------------------------------------------------
-- ACTIVE RUNS
--------------------------------------------------

local activeRuns = {}


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if not DEBUG then
		return
	end

	print(
		"[WinCourseProgressService]",
		...
	)

end


--------------------------------------------------
-- GET PLAYER BALL
--------------------------------------------------

local function getPlayerBall(player)

	if not player
		or not player:IsA("Player") then

		return nil

	end


	local expectedName =
		"PlayerBall_" ..
		tostring(player.UserId)


	local ball =
		playerBalls:FindFirstChild(
			expectedName
		)


	if not ball then
		return nil
	end


	if not ball:IsA("BasePart") then

		warn(
			"[WinCourseProgressService]",
			"Player ball is not a BasePart:",
			ball:GetFullName()
		)

		return nil

	end


	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	if ownerUserId ~= player.UserId then

		warn(
			"[WinCourseProgressService]",
			"Ball owner mismatch for",
			player.Name,
			"Expected:",
			player.UserId,
			"Found:",
			ownerUserId
		)

		return nil

	end


	return ball

end


--------------------------------------------------
-- GET GENERATED WIN COURSE
--------------------------------------------------

local function getGeneratedWinCourse()

	local winCourse =
		course:FindFirstChild(
			"WinCourse"
		)


	if not winCourse then
		return nil
	end


	if not winCourse:IsA("Folder")
		and not winCourse:IsA("Model") then

		return nil

	end


	if winCourse:GetAttribute(
		"IsWinCourse"
	) ~= true then

		return nil

	end


	return winCourse

end


--------------------------------------------------
-- GET TILE INDEX
--------------------------------------------------

local function getTileIndex(tile)

	if not tile
		or not tile:IsA("Model") then

		return nil

	end


	local index =
		tile:GetAttribute(
			"TileIndex"
		)


	if typeof(index) ~= "number" then
		return nil
	end


	if index ~= math.floor(index) then
		return nil
	end


	if index < 1 then
		return nil
	end


	return index

end


--------------------------------------------------
-- GET WIN AMOUNT
--------------------------------------------------

local function getWinAmount(tile)

	if not tile
		or not tile:IsA("Model") then

		return nil

	end


	local amount =
		tile:GetAttribute(
			"WinAmount"
		)


	if typeof(amount) ~= "number" then
		return nil
	end


	if amount ~= amount then
		return nil
	end


	if amount == math.huge
		or amount == -math.huge then

		return nil

	end


	if amount < 0 then
		return nil
	end


	return amount

end


--------------------------------------------------
-- GET TILE POSITION
--------------------------------------------------

local function getTilePosition(tile)

	if not tile
		or not tile:IsA("Model") then

		return nil

	end


	local success, pivot =
		pcall(function()

			return tile:GetPivot()

		end)


	if not success then
		return nil
	end


	if typeof(pivot) ~= "CFrame" then
		return nil
	end


	return pivot.Position

end


--------------------------------------------------
-- COLLECT WIN TILES
--------------------------------------------------

local function collectWinTiles(
	winCourse
)

	local tiles = {}


	for _, child in ipairs(
		winCourse:GetChildren()
	) do

		if not child:IsA("Model") then
			continue
		end


		if not child.Name:match(
			"^WinTile_"
		) then

			continue

		end


		local index =
			getTileIndex(
				child
			)


		local amount =
			getWinAmount(
				child
			)


		local position =
			getTilePosition(
				child
			)


		if not index then

			warn(
				"[WinCourseProgressService]",
				"Missing TileIndex:",
				child:GetFullName()
			)

			continue

		end


		if amount == nil then

			warn(
				"[WinCourseProgressService]",
				"Missing WinAmount:",
				child:GetFullName()
			)

			continue

		end


		if not position then

			warn(
				"[WinCourseProgressService]",
				"Invalid tile position:",
				child:GetFullName()
			)

			continue

		end


		table.insert(
			tiles,
			{

				Model = child,

				Index = index,

				Amount = amount,

				Position = position,

			}
		)

	end


	table.sort(
		tiles,
		function(a, b)

			return a.Index < b.Index

		end
	)


	return tiles

end


--------------------------------------------------
-- VALIDATE TILE ORDER
--------------------------------------------------

local function validateTileOrder(
	tiles
)

	if #tiles < 1 then

		warn(
			"[WinCourseProgressService]",
			"Generated WinCourse contains no WinTiles."
		)

		return false

	end


	for expectedIndex, tileData in ipairs(
		tiles
	) do

		if tileData.Index ~= expectedIndex then

			warn(
				"[WinCourseProgressService]",
				"Invalid WinTile order.",
				"Expected:",
				expectedIndex,
				"Found:",
				tileData.Index
			)

			return false

		end

	end


	return true

end


--------------------------------------------------
-- CREATE COURSE DATA
--------------------------------------------------

local function createCourseData()

	local winCourse =
		getGeneratedWinCourse()


	if not winCourse then
		return nil
	end


	local tiles =
		collectWinTiles(
			winCourse
		)


	if not validateTileOrder(
		tiles
	) then

		return nil

	end


	debugPrint(
		"GENERATED WIN COURSE FOUND:",
		winCourse:GetFullName()
	)

	debugPrint(
		"Generated WinTiles:",
		#tiles
	)


	for _, tileData in ipairs(
		tiles
	) do

		debugPrint(
			"WinTile",
			tileData.Index,
			"|",
			tileData.Model.Name,
			"| Position:",
			tileData.Position,
			"| Win:",
			tileData.Amount
		)

	end


	return {

		WinCourse =
			winCourse,

		Tiles =
			tiles,

		TileCount =
			#tiles,

	}

end


--------------------------------------------------
-- READ CURRENT OIL
--
-- IMPORTANT:
--
-- CurrentOil is the authoritative oil value.
--
-- CollectedOilCount is NOT used for movement.
--
-- Example:
--
-- CurrentOil = 25
-- CollectedOilCount = 12
--
-- Travel budget = 25
--
-- NOT 12.
--------------------------------------------------

local function readCurrentOil(player)

	local currentOil =
		player:GetAttribute(
			"CurrentOil"
		)


	if typeof(currentOil) ~= "number" then

		warn(
			"[WinCourseProgressService]",
			player.Name,
			"CurrentOil is missing or invalid."
		)

		return nil

	end


	if currentOil ~= currentOil then

		warn(
			"[WinCourseProgressService]",
			player.Name,
			"CurrentOil is NaN."
		)

		return nil

	end


	if currentOil == math.huge
		or currentOil == -math.huge then

		warn(
			"[WinCourseProgressService]",
			player.Name,
			"CurrentOil is infinite."
		)

		return nil

	end


	--------------------------------------------------
	-- DO NOT CHANGE THE PLAYER ATTRIBUTE.
	--
	-- We only normalize the value locally.
	--------------------------------------------------

	local usableOil =
		math.max(
			0,
			currentOil
		)


	local collectedOilCount =
		player:GetAttribute(
			"CollectedOilCount"
		)


	print(
		"================================"
	)

	print(
		"[WinCourseProgressService]",
		"OIL SNAPSHOT"
	)

	print(
		"[WinCourseProgressService]",
		"Player:",
		player.Name
	)

	print(
		"[WinCourseProgressService]",
		"CurrentOil:",
		currentOil
	)

	print(
		"[WinCourseProgressService]",
		"UsableOil:",
		usableOil
	)

	print(
		"[WinCourseProgressService]",
		"CollectedOilCount:",
		collectedOilCount
	)

	print(
		"[WinCourseProgressService]",
		"================================"
	)


	return usableOil

end


--------------------------------------------------
-- READ OIL AFTER SETTLE
--
-- This is specifically here because the FinishWall
-- and OilCollection systems can execute very close
-- together.
--
-- We wait a tiny amount and then read CurrentOil.
--
-- We do NOT calculate oil ourselves.
-- We do NOT use CollectedOilCount.
--------------------------------------------------

local function getCurrentOilAfterSettle(player)

	local oil = nil


	local deadline =
		os.clock()
		+
		OIL_SETTLE_TIME


	repeat

		oil =
			readCurrentOil(
				player
			)


		if oil ~= nil then
			break
		end


		task.wait()

	until os.clock() >= deadline


	return oil

end


--------------------------------------------------
-- GET BALL OFFSET
--------------------------------------------------

local function getBallVerticalOffset(
	ball
)

	if BALL_VERTICAL_OFFSET > 0 then

		return BALL_VERTICAL_OFFSET

	end


	return ball.Size.Y / 2

end


--------------------------------------------------
-- GET COURSE DIRECTION
--------------------------------------------------

local function getCourseDirection(
	tiles
)

	if #tiles < 2 then

		return nil

	end


	local difference =
		tiles[2].Position
		-
		tiles[1].Position


	if difference.Magnitude <= 0.001 then

		warn(
			"[WinCourseProgressService]",
			"WinTile_1 and WinTile_2 are too close."
		)

		return nil

	end


	return difference.Unit

end


--------------------------------------------------
-- GET START POSITION
--------------------------------------------------

local function getStartPosition(
	ball
)

	if not ball
		or not ball.Parent then

		return nil

	end


	return ball.Position

end


--------------------------------------------------
-- CALCULATE DISTANCE ALONG COURSE
--------------------------------------------------

local function getForwardDistance(
	startPosition,
	position,
	direction
)

	return math.max(
		0,
		(position - startPosition):Dot(
			direction
		)
	)

end


--------------------------------------------------
-- GET TILE DISTANCE
--------------------------------------------------

local function getTileDistance(
	startPosition,
	tilePosition,
	direction
)

	return getForwardDistance(
		startPosition,
		tilePosition,
		direction
	)

end


--------------------------------------------------
-- FIND REACHABLE TILES
--------------------------------------------------

local function findReachableTiles(
	tiles,
	startPosition,
	direction,
	travelBudget
)

	local finalTileIndex = 0

	local finalTileDistance = 0


	for _, tileData in ipairs(
		tiles
	) do

		local distance =
			getTileDistance(
				startPosition,
				tileData.Position,
				direction
			)


		if distance <=
			travelBudget
			+
			TILE_REACH_EPSILON then

			finalTileIndex =
				tileData.Index

			finalTileDistance =
				distance

		else

			break

		end

	end


	return finalTileIndex,
		finalTileDistance

end


--------------------------------------------------
-- TAKE SERVER CONTROL
--------------------------------------------------

local function takeServerControl(
	ball
)

	if not ball
		or not ball.Parent then

		return false

	end


	pcall(function()

		ball:SetNetworkOwner(nil)

	end)


	return true

end


--------------------------------------------------
-- STOP BALL
--------------------------------------------------

local function stopBall(
	ball
)

	if not ball
		or not ball.Parent then

		return

	end


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	pcall(function()

		ball:SetNetworkOwner(nil)

	end)

end


--------------------------------------------------
-- POSITION BALL EXACTLY
--------------------------------------------------

local function positionBallExact(
	ball,
	position
)

	if not ball
		or not ball.Parent then

		return false

	end


	local offset =
		getBallVerticalOffset(
			ball
		)


	local finalPosition =
		Vector3.new(
			position.X,
			position.Y + offset,
			position.Z
		)


	ball.CFrame =
		CFrame.new(
			finalPosition
		)


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	return true

end


--------------------------------------------------
-- GET COURSE POSITION
--------------------------------------------------

local function getPositionAtDistance(
	run,
	distance
)

	return run.RollStartPosition
		+
		run.CourseDirection
		*
		distance

end


--------------------------------------------------
-- COLLECT TILES THROUGH INDEX
--------------------------------------------------

local function collectThroughTile(
	run,
	targetIndex
)

	if targetIndex <=
		run.FurthestTileIndex then

		return

	end


	for index =
		run.FurthestTileIndex + 1,
		targetIndex do

		local tileData =
			run.Tiles[index]


		if not tileData then
			break
		end


		run.FurthestTileIndex =
			index


		table.insert(
			run.CollectedTiles,
			tileData
		)


		run.TotalWinAmount +=
			tileData.Amount


		debugPrint(
			run.Player.Name,
			"COLLECTED",
			tileData.Model.Name,
			"| INDEX:",
			tileData.Index,
			"| WIN:",
			tileData.Amount,
			"| TOTAL:",
			run.TotalWinAmount
		)

	end

end


--------------------------------------------------
-- UPDATE TILE PROGRESS
--------------------------------------------------

local function updateProgress(
	run,
	distanceTravelled
)

	if run.Finished then
		return
	end


	for index =
		run.FurthestTileIndex + 1,
		run.TileCount do

		local tileData =
			run.Tiles[index]


		if not tileData then
			break
		end


		local tileDistance =
			getTileDistance(
				run.RollStartPosition,
				tileData.Position,
				run.CourseDirection
			)


		if distanceTravelled
			+
			TILE_REACH_EPSILON
			>=
			tileDistance then

			collectThroughTile(
				run,
				index
			)

		else

			break

		end

	end

end


--------------------------------------------------
-- FINISH RUN
--------------------------------------------------

local function finishRun(
	player,
	run,
	reason
)

	if not run
		or run.Finished then

		return

	end


	run.Finished =
		true

	run.Rolling =
		false


	stopBall(
		run.Ball
	)


	--------------------------------------------------
	-- FINAL TILE
	--------------------------------------------------

	local finalTile


	if run.FurthestTileIndex > 0 then

		finalTile =
			run.Tiles[
				run.FurthestTileIndex
			]

	end


	--------------------------------------------------
	-- ALL TILES REACHED
	--------------------------------------------------

	if run.FurthestTileIndex >=
		run.TileCount then

		finalTile =
			run.Tiles[
				run.TileCount
			]

		if finalTile then

			positionBallExact(
				run.Ball,
				finalTile.Position
			)

		end

	end


	--------------------------------------------------
	-- ACTIVE OFF
	--------------------------------------------------

	if run.Ball
		and run.Ball.Parent then

		run.Ball:SetAttribute(
			"WinCourseActive",
			false
		)

	end


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"================================"
	)

	print(
		"[WinCourseProgressService]",
		"WIN COURSE FINISHED"
	)

	print(
		"[WinCourseProgressService]",
		"Player:",
		player.Name
	)

	print(
		"[WinCourseProgressService]",
		"Reason:",
		reason
	)

	print(
		"[WinCourseProgressService]",
		"Oil At Start:",
		run.CurrentOil
	)

	print(
		"[WinCourseProgressService]",
		"Travel Budget:",
		run.TravelBudget
	)

	print(
		"[WinCourseProgressService]",
		"Distance Travelled:",
		run.DistanceTravelled
	)

	print(
		"[WinCourseProgressService]",
		"Furthest Tile:",
		run.FurthestTileIndex
	)

	print(
		"[WinCourseProgressService]",
		"Final Tile:",
		finalTile
			and finalTile.Model.Name
			or "NONE"
	)

	print(
		"[WinCourseProgressService]",
		"Final Index:",
		finalTile
			and finalTile.Index
			or 0
	)

	print(
		"[WinCourseProgressService]",
		"Total Win:",
		run.TotalWinAmount
	)

	print(
		"[WinCourseProgressService]",
		"Collected Tiles:",
		#run.CollectedTiles
	)

	print(
		"================================"
	)


	--------------------------------------------------
	-- CLIENT
	--------------------------------------------------

	winCourseRemote:FireClient(
		player,
		"WinCourseFinished",
		{

			FinalTile =
				finalTile
					and finalTile.Model.Name
					or nil,

			FinalTileIndex =
				finalTile
					and finalTile.Index
					or 0,

			FinalTileWin =
				finalTile
					and finalTile.Amount
					or 0,

			TotalWin =
				run.TotalWinAmount,

			DistanceTravelled =
				run.DistanceTravelled,

			CurrentOil =
				run.CurrentOil,

			Reason =
				reason,

		}
	)


	activeRuns[player] =
		nil

end


--------------------------------------------------
-- START ROLL
--------------------------------------------------

local function startRoll(
	run
)

	if run.Finished
		or run.Rolling then

		return false

	end


	local ball =
		run.Ball


	if not ball
		or not ball.Parent then

		return false

	end


	if not takeServerControl(
		ball
	) then

		return false

	end


	ball.Anchored =
		true


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	run.Rolling =
		true

	run.Started =
		true

	run.DistanceTravelled =
		0


	winCourseRemote:FireClient(
		run.Player,
		"RollStarted"
	)


	print(
		"================================"
	)

	print(
		"[WinCourseProgressService]",
		"ROLL STARTED"
	)

	print(
		"[WinCourseProgressService]",
		"Player:",
		run.Player.Name
	)

	print(
		"[WinCourseProgressService]",
		"Ball:",
		ball:GetFullName()
	)

	print(
		"[WinCourseProgressService]",
		"Start Position:",
		run.RollStartPosition
	)

	print(
		"[WinCourseProgressService]",
		"Oil At Start:",
		run.CurrentOil
	)

	print(
		"[WinCourseProgressService]",
		"Travel Budget:",
		run.TravelBudget
	)

	print(
		"[WinCourseProgressService]",
		"Course Direction:",
		run.CourseDirection
	)

	print(
		"[WinCourseProgressService]",
		"Speed:",
		WIN_COURSE_SPEED
	)

	print(
		"================================"
	)


	return true

end


--------------------------------------------------
-- MOVE BALL
--------------------------------------------------

local function moveBall(
	run,
	deltaTime
)

	local ball =
		run.Ball


	if not ball
		or not ball.Parent then

		return false,
			"BALL_DISAPPEARED"

	end


	local remainingDistance =
		run.TravelBudget
		-
		run.DistanceTravelled


	if remainingDistance <=
		POSITION_EPSILON then

		return true,
			"OIL_EXHAUSTED"

	end


	local movement =
		WIN_COURSE_SPEED
		*
		deltaTime


	movement =
		math.min(
			movement,
			remainingDistance
		)


	local newDistance =
		run.DistanceTravelled
		+
		movement


	local nextPosition =
		getPositionAtDistance(
			run,
			newDistance
		)


	local offset =
		getBallVerticalOffset(
			ball
		)


	local ballPosition =
		Vector3.new(
			nextPosition.X,
			nextPosition.Y + offset,
			nextPosition.Z
		)


	ball.CFrame =
		CFrame.new(
			ballPosition
		)


	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	run.DistanceTravelled =
		newDistance


	updateProgress(
		run,
		run.DistanceTravelled
	)


	if run.FurthestTileIndex >=
		run.TileCount then

		return true,
			"ALL_TILES_REACHED"

	end


	if run.DistanceTravelled >=
		run.TravelBudget
		-
		POSITION_EPSILON then

		return true,
			"OIL_EXHAUSTED"

	end


	return false,
		nil

end


--------------------------------------------------
-- UPDATE RUN
--------------------------------------------------

local function updateRun(
	player,
	run,
	deltaTime
)

	if run.Finished then
		return
	end


	local ball =
		run.Ball


	if not ball
		or not ball.Parent then

		finishRun(
			player,
			run,
			"BALL_DISAPPEARED"
		)

		return

	end


	--------------------------------------------------
	-- BALL IDENTITY
	--------------------------------------------------

	if ball.Name ~=
		("PlayerBall_" ..
		tostring(player.UserId)) then

		finishRun(
			player,
			run,
			"BALL_NAME_CHANGED"
		)

		return

	end


	--------------------------------------------------
	-- OWNER
	--------------------------------------------------

	if ball:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		finishRun(
			player,
			run,
			"BALL_OWNERSHIP_CHANGED"
		)

		return

	end


	--------------------------------------------------
	-- ACTIVE
	--------------------------------------------------

	if ball:GetAttribute(
		"WinCourseActive"
	) ~= true then

		finishRun(
			player,
			run,
			"WINCOURSE_CANCELLED"
		)

		return

	end


	--------------------------------------------------
	-- COUNTDOWN
	--------------------------------------------------

	if not run.Rolling then

		local elapsed =
			os.clock()
			-
			run.CountdownStarted


		if elapsed >=
			START_DELAY then

			local started =
				startRoll(
					run
				)


			if not started then

				finishRun(
					player,
					run,
					"FAILED_TO_START_ROLL"
				)

			end

		end


		return

	end


	--------------------------------------------------
	-- KEEP BALL ANCHORED
	--------------------------------------------------

	if not ball.Anchored then

		ball.Anchored =
			true

	end


	--------------------------------------------------
	-- SERVER CONTROL
	--------------------------------------------------

	takeServerControl(
		ball
	)


	--------------------------------------------------
	-- MOVE
	--------------------------------------------------

	local finished,
		reason =
		moveBall(
			run,
			deltaTime
		)


	if finished then

		finishRun(
			player,
			run,
			reason
		)

	end

end


--------------------------------------------------
-- START TRACKING
--------------------------------------------------

local function startTracking(
	player,
	ball
)

	if activeRuns[player] then
		return
	end


	--------------------------------------------------
	-- GENERATED COURSE
	--------------------------------------------------

	local courseData =
		createCourseData()


	if not courseData then

		warn(
			"[WinCourseProgressService]",
			"WinCourseActive detected, but generated WinCourse was not found."
		)

		return

	end


	--------------------------------------------------
	-- OIL
	--
	-- IMPORTANT:
	--
	-- Read CurrentOil AFTER the WinCourse has become
	-- active, with a tiny settle period.
	--------------------------------------------------

	local currentOil =
		getCurrentOilAfterSettle(
			player
		)


	if currentOil == nil then
		return
	end


	--------------------------------------------------
	-- TRAVEL BUDGET
	--------------------------------------------------

	local travelBudget =
		currentOil *
		OIL_PER_STUD


	--------------------------------------------------
	-- NO OIL
	--------------------------------------------------

	if travelBudget <= 0 then

		warn(
			"[WinCourseProgressService]",
			player.Name,
			"HAS NO COLLECTED OIL."
		)

		ball:SetAttribute(
			"WinCourseActive",
			false
		)

		return

	end


	--------------------------------------------------
	-- START POSITION
	--------------------------------------------------

	local startPosition =
		getStartPosition(
			ball
		)


	if not startPosition then
		return
	end


	--------------------------------------------------
	-- COURSE DIRECTION
	--------------------------------------------------

	local direction =
		getCourseDirection(
			courseData.Tiles
		)


	if not direction then

		warn(
			"[WinCourseProgressService]",
			"Could not determine generated WinCourse direction."
		)

		return

	end


	--------------------------------------------------
	-- REACHABLE TILES
	--------------------------------------------------

	local finalTileIndex,
		finalTileDistance =
		findReachableTiles(
			courseData.Tiles,
			startPosition,
			direction,
			travelBudget
		)


	--------------------------------------------------
	-- RUN DATA
	--------------------------------------------------

	local run = {

		Player =
			player,

		Ball =
			ball,

		WinCourse =
			courseData.WinCourse,

		Tiles =
			courseData.Tiles,

		TileCount =
			courseData.TileCount,

		CourseDirection =
			direction,

		--------------------------------------------------
		-- THIS IS THE IMPORTANT VALUE
		--------------------------------------------------

		CurrentOil =
			currentOil,

		TravelBudget =
			travelBudget,

		--------------------------------------------------
		-- TIMING
		--------------------------------------------------

		CountdownStarted =
			os.clock(),

		Rolling =
			false,

		Started =
			false,

		--------------------------------------------------
		-- POSITION
		--------------------------------------------------

		RollStartPosition =
			startPosition,

		DistanceTravelled =
			0,

		--------------------------------------------------
		-- REACHABLE TILES
		--------------------------------------------------

		FinalTileIndex =
			finalTileIndex,

		FinalTileDistance =
			finalTileDistance,

		FurthestTileIndex =
			0,

		CollectedTiles =
			{},

		TotalWinAmount =
			0,

		Finished =
			false,

	}


	activeRuns[player] =
		run


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"================================"
	)

	print(
		"[WinCourseProgressService]",
		"WIN COURSE DETECTED"
	)

	print(
		"[WinCourseProgressService]",
		"Player:",
		player.Name
	)

	print(
		"[WinCourseProgressService]",
		"GENERATED COURSE:",
		courseData.WinCourse:GetFullName()
	)

	print(
		"[WinCourseProgressService]",
		"Ball:",
		ball:GetFullName()
	)

	print(
		"[WinCourseProgressService]",
		"Ball Start:",
		startPosition
	)

	print(
		"[WinCourseProgressService]",
		"CurrentOil:",
		currentOil
	)

	print(
		"[WinCourseProgressService]",
		"Travel Budget:",
		travelBudget
	)

	print(
		"[WinCourseProgressService]",
		"Course Direction:",
		direction
	)

	print(
		"[WinCourseProgressService]",
		"Reachable Tile Index:",
		finalTileIndex
	)

	print(
		"[WinCourseProgressService]",
		"Reachable Tile Distance:",
		finalTileDistance
	)

	print(
		"[WinCourseProgressService]",
		"RunState:",
		player:GetAttribute(
			"RunState"
		),
		"(ignored)"
	)

	print(
		"================================"
	)


	--------------------------------------------------
	-- COUNTDOWN
	--------------------------------------------------

	winCourseRemote:FireClient(
		player,
		"CountdownStart",
		START_DELAY
	)

end


--------------------------------------------------
-- DISCOVER ACTIVE GENERATED WIN COURSES
--------------------------------------------------

local function discoverActiveRuns()

	for _, player in ipairs(
		Players:GetPlayers()
	) do

		if activeRuns[player] then
			continue
		end


		--------------------------------------------------
		-- BALL
		--------------------------------------------------

		local ball =
			getPlayerBall(
				player
			)


		if not ball then
			continue
		end


		--------------------------------------------------
		-- WIN COURSE ACTIVE
		--------------------------------------------------

		if ball:GetAttribute(
			"WinCourseActive"
		) ~= true then

			continue

		end


		--------------------------------------------------
		-- GENERATED COURSE
		--------------------------------------------------

		local generatedCourse =
			getGeneratedWinCourse()


		if not generatedCourse then
			continue
		end


		--------------------------------------------------
		-- START
		--------------------------------------------------

		startTracking(
			player,
			ball
		)

	end

end


--------------------------------------------------
-- HEARTBEAT
--------------------------------------------------

local accumulator =
	0


RunService.Heartbeat:Connect(
	function(deltaTime)

		accumulator +=
			deltaTime


		if accumulator <
			UPDATE_INTERVAL then

			return

		end


		local step =
			accumulator


		accumulator =
			0


		--------------------------------------------------
		-- DISCOVER
		--------------------------------------------------

		discoverActiveRuns()


		--------------------------------------------------
		-- UPDATE
		--------------------------------------------------

		for player, run in pairs(
			activeRuns
		) do

			if not player.Parent then

				stopBall(
					run.Ball
				)

				activeRuns[player] =
					nil

				continue

			end


			updateRun(
				player,
				run,
				step
			)

		end

	end
)


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		local run =
			activeRuns[player]


		if run then

			stopBall(
				run.Ball
			)

		end


		activeRuns[player] =
			nil

	end)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"================================"
)

print(
	"[WinCourseProgressService]",
	"SERVER READY"
)

print(
	"[WinCourseProgressService]",
	"Preview:",
	"IGNORED"
)

print(
	"[WinCourseProgressService]",
	"Generated Course:",
	"Course.WinCourse"
)

print(
	"[WinCourseProgressService]",
	"Required Attribute:",
	"IsWinCourse = true"
)

print(
	"[WinCourseProgressService]",
	"Oil Source:",
	"Player.CurrentOil"
)

print(
	"[WinCourseProgressService]",
	"Collection Count:",
	"Player.CollectedOilCount"
)

print(
	"[WinCourseProgressService]",
	"Movement:",
	"DIRECT SERVER MOVEMENT"
)

print(
	"[WinCourseProgressService]",
	"Speed:",
	WIN_COURSE_SPEED,
	"studs/sec"
)

print(
	"[WinCourseProgressService]",
	"Countdown:",
	START_DELAY,
	"seconds"
)

print(
	"[WinCourseProgressService]",
	"Oil Settle Time:",
	OIL_SETTLE_TIME,
	"seconds"
)

print(
	"[WinCourseProgressService]",
	"RunState:",
	"NOT USED AS WIN COURSE BLOCKER"
)

print(
	"================================"
)
