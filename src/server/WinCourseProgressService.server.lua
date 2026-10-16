--------------------------------------------------
-- WIN COURSE PROGRESS SERVICE
--
-- SERVER ONLY
--
-- This service controls the WinCourse ball.
--
-- ACCELERATION VERSION
--
-- The ball:
--   1. Starts anchored.
--   2. Waits through the countdown.
--   3. Server takes ownership.
--   4. Ball is released.
--   5. One LinearVelocity is created.
--   6. Target speed increases according to
--      the acceleration setting.
--   7. Oil determines total travel distance.
--
-- IMPORTANT:
--
-- No per-frame CFrame movement.
-- No per-frame AssemblyLinearVelocity forcing.
-- No per-frame network ownership changes.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local course = Workspace:WaitForChild("Course")
local playerBalls = Workspace:WaitForChild("PlayerBalls")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ballSpawn = Workspace:WaitForChild("BallSpawn")


--------------------------------------------------
-- GENERATOR
--------------------------------------------------

local generatorModule = ServerScriptService:WaitForChild(
	"WinCourseGenerator"
)

if not generatorModule:IsA("ModuleScript") then
	error(
		"[WinCourseProgressService] "
		.. "WinCourseGenerator must be a ModuleScript."
	)
end

local requireSuccess, WinCourseGenerator = pcall(function()
	return require(generatorModule)
end)

if not requireSuccess then
	error(
		"[WinCourseProgressService] "
		.. "Failed to require WinCourseGenerator:\n"
		.. tostring(WinCourseGenerator)
	)
end

if type(WinCourseGenerator) ~= "table" then
	error(
		"[WinCourseProgressService] "
		.. "WinCourseGenerator must return a table."
	)
end

if type(WinCourseGenerator.GetStartPosition) ~= "function" then
	error(
		"[WinCourseProgressService] "
		.. "WinCourseGenerator.GetStartPosition() is missing."
	)
end


--------------------------------------------------
-- REMOTES
--------------------------------------------------

local winCourseRemote = remotes:FindFirstChild("WinCourse")

if not winCourseRemote then
	winCourseRemote = Instance.new("RemoteEvent")
	winCourseRemote.Name = "WinCourse"
	winCourseRemote.Parent = remotes
end

if not winCourseRemote:IsA("RemoteEvent") then
	error(
		"[WinCourseProgressService] "
		.. "Remotes.WinCourse must be a RemoteEvent."
	)
end


local SpawnAura = remotes:FindFirstChild("SpawnAura")

if not SpawnAura then
	SpawnAura = Instance.new("RemoteEvent")
	SpawnAura.Name = "SpawnAura"
	SpawnAura.Parent = remotes
end

if not SpawnAura:IsA("RemoteEvent") then
	error(
		"[WinCourseProgressService] "
		.. "Remotes.SpawnAura must be a RemoteEvent."
	)
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
-- RESULT DISPLAY
--------------------------------------------------

local RESULT_DISPLAY_TIME = 4


--------------------------------------------------
-- STARTING SPEED
--------------------------------------------------

local BASE_WIN_COURSE_SPEED = 40


--------------------------------------------------
-- OIL SPEED BOOST
--------------------------------------------------

local OIL_SPEED_BOOST_PER_OIL = 0.10


--------------------------------------------------
-- MAXIMUM OIL SPEED BOOST
--------------------------------------------------

local MAX_OIL_SPEED_BOOST = 100


--------------------------------------------------
-- ACCELERATION
--
-- THIS IS THE IMPORTANT PART.
--
-- Example:
--
-- Starting speed = 50
-- Acceleration = 8
--
-- 0 sec = 50
-- 1 sec = 58
-- 2 sec = 66
-- 3 sec = 74
-- etc.
--------------------------------------------------

local WIN_COURSE_ACCELERATION = 8


--------------------------------------------------
-- MAXIMUM SPEED
--------------------------------------------------

local MAX_WIN_COURSE_SPEED = 140


--------------------------------------------------
-- OIL TRAVEL
--
-- 1 oil = 1 stud of travel.
--------------------------------------------------

local OIL_PER_STUD = 1


--------------------------------------------------
-- BALL HEIGHT
--------------------------------------------------

local BALL_VERTICAL_OFFSET = 0


--------------------------------------------------
-- TILE REACH
--------------------------------------------------

local TILE_REACH_EPSILON = 0.25


--------------------------------------------------
-- OIL SETTLE
--------------------------------------------------

local OIL_SETTLE_TIME = 0.10


--------------------------------------------------
-- FINISH
--------------------------------------------------

local FINISH_EPSILON = 0.15


--------------------------------------------------
-- RETURN
--------------------------------------------------

local RETURN_FADE_TIME = 0.35
local RETURN_HOLD_TIME = 0.10


--------------------------------------------------
-- AURA
--------------------------------------------------

local AURA_DURATION = 2
local AURA_STYLE = "WhiteBallAura"


--------------------------------------------------
-- SOUND
--------------------------------------------------

local GET_UP_SOUND_ID =
	"rbxasset://sounds/action_get_up.mp3"


--------------------------------------------------
-- LINEAR VELOCITY
--------------------------------------------------

local LINEAR_VELOCITY_NAME =
	"WinCourseLinearVelocity"


--------------------------------------------------
-- STATE
--------------------------------------------------

local activeRuns = {}
local returningPlayers = {}


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if DEBUG then
		print(
			"[WinCourseProgressService]",
			...
		)
	end

end


--------------------------------------------------
-- SAFE NUMBER
--------------------------------------------------

local function isFiniteNumber(value)

	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge

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
		"PlayerBall_" .. tostring(player.UserId)

	local ball =
		playerBalls:FindFirstChild(expectedName)

	if not ball then
		return nil
	end

	if not ball:IsA("BasePart") then
		return nil
	end

	local ownerUserId =
		ball:GetAttribute("OwnerUserId")

	if ownerUserId ~= player.UserId then
		return nil
	end

	return ball

end


--------------------------------------------------
-- OFFICIAL START POSITION
--------------------------------------------------

local function getOfficialStartPosition()

	local success, position =
		pcall(function()

			return WinCourseGenerator.GetStartPosition()

		end)

	if not success then

		warn(
			"[WinCourseProgressService]",
			"GetStartPosition failed:",
			tostring(position)
		)

		return nil

	end

	if typeof(position) ~= "Vector3" then

		warn(
			"[WinCourseProgressService]",
			"GetStartPosition must return Vector3."
		)

		return nil

	end

	return position

end


--------------------------------------------------
-- GENERATED WIN COURSE
--------------------------------------------------

local function getGeneratedWinCourse()

	local winCourse =
		course:FindFirstChild("WinCourse")

	if not winCourse then
		return nil
	end

	if not winCourse:IsA("Folder")
		and not winCourse:IsA("Model") then
		return nil
	end

	if winCourse:GetAttribute("IsWinCourse") ~= true then
		return nil
	end

	return winCourse

end


--------------------------------------------------
-- TILE INDEX
--------------------------------------------------

local function getTileIndex(tile)
	if not tile or not tile:IsA("Model") then
		return nil
	end

	local index = tile:GetAttribute("TileIndex")

	-- Make sure the attribute exists and is a number.
	if typeof(index) ~= "number" then
		return nil
	end

	-- Reject NaN and infinity.
	if index ~= index
		or index == math.huge
		or index == -math.huge then
		return nil
	end

	-- Check for a positive whole number without math.floor.
	if index < 1 or index % 1 ~= 0 then
		return nil
	end

	return index
end

--------------------------------------------------
-- WIN AMOUNT
--------------------------------------------------

local function getWinAmount(tile)

	if not tile
		or not tile:IsA("Model") then
		return nil
	end

	local amount =
		tile:GetAttribute("WinAmount")

	if not isFiniteNumber(amount) then
		return nil
	end

	if amount < 0 then
		return nil
	end

	return amount

end


--------------------------------------------------
-- TILE POSITION
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
-- COLLECT TILES
--------------------------------------------------

local function collectWinTiles(winCourse)

	local tiles = {}

	for _, child in ipairs(winCourse:GetChildren()) do

		if not child:IsA("Model") then
			continue
		end

		if not child.Name:match("^WinTile_") then
			continue
		end

		local index =
			getTileIndex(child)

		local amount =
			getWinAmount(child)

		local position =
			getTilePosition(child)

		if not index then

			warn(
				"[WinCourseProgressService]",
				"Invalid TileIndex:",
				child:GetFullName()
			)

			continue
		end

		if amount == nil then

			warn(
				"[WinCourseProgressService]",
				"Invalid WinAmount:",
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
-- REFRESH DYNAMIC COURSE TILES
--------------------------------------------------

local function refreshRunTiles(run)

	local success, result = pcall(function()
		return WinCourseGenerator.EnsureTilesThroughDistance(
			run.CourseProgress + run.TravelBudget
		)
	end)

	if not success or result ~= true then
		warn(
			"[WinCourseProgressService] Failed to extend WinCourse:",
			result
		)
		return false
	end

	local tiles = collectWinTiles(run.WinCourse)

	if #tiles == 0 then
		return false
	end

	run.Tiles = tiles
	run.TileCount = #tiles

	return true
end


--------------------------------------------------
-- VALIDATE TILE ORDER
--------------------------------------------------

local function validateTileOrder(tiles)

	if #tiles < 1 then

		warn(
			"[WinCourseProgressService]",
			"No WinTiles found."
		)

		return false

	end

	for expectedIndex, tileData in ipairs(tiles) do

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
-- COURSE DATA
--------------------------------------------------

local function createCourseData()

	local winCourse =
		getGeneratedWinCourse()

	if not winCourse then
		return nil
	end

	local tiles =
		collectWinTiles(winCourse)

	if not validateTileOrder(tiles) then
		return nil
	end

	local startPosition =
		getOfficialStartPosition()

	if not startPosition then
		return nil
	end

	return {

		WinCourse = winCourse,

		Tiles = tiles,

		TileCount = #tiles,

		StartPosition = startPosition,

	}

end


--------------------------------------------------
-- READ CURRENT OIL
--------------------------------------------------

local function readCurrentOil(player)

	local currentOil =
		player:GetAttribute("CurrentOil")

	if not isFiniteNumber(currentOil) then
		return nil
	end

	return math.max(0, currentOil)

end


--------------------------------------------------
-- WAIT FOR OIL TO SETTLE
--------------------------------------------------

local function getCurrentOilAfterSettle(player)

	local deadline =
		os.clock() + OIL_SETTLE_TIME

	repeat

		local oil =
			readCurrentOil(player)

		if oil ~= nil then
			return oil
		end

		task.wait()

	until os.clock() >= deadline

	return readCurrentOil(player)

end


--------------------------------------------------
-- OIL SPEED BOOST
--------------------------------------------------

local function calculateOilSpeedBoost(oil)

	local rawBoost =
		oil * OIL_SPEED_BOOST_PER_OIL

	return math.clamp(
		rawBoost,
		0,
		MAX_OIL_SPEED_BOOST
	)

end


--------------------------------------------------
-- STARTING SPEED
--------------------------------------------------

local function calculateStartingSpeed(oil)

	local oilBoost =
		calculateOilSpeedBoost(oil)

	return math.clamp(
		BASE_WIN_COURSE_SPEED + oilBoost,
		0,
		MAX_WIN_COURSE_SPEED
	)

end


--------------------------------------------------
-- ACCELERATED SPEED
--
-- THIS FUNCTION IS THE CORE OF THE
-- ACCELERATION SYSTEM.
--
-- speed = startingSpeed + acceleration * time
--
-- Then the maximum speed is applied.
--------------------------------------------------

local function calculateRollSpeed(run)

	if not run.RollStartTime then
		return run.StartingSpeed
	end

	local elapsed =
		math.max(
			0,
			os.clock() - run.RollStartTime
		)

	local speed =
		run.StartingSpeed
		+
		(
			WIN_COURSE_ACCELERATION
			*
			elapsed
		)

	return math.clamp(
		speed,
		0,
		MAX_WIN_COURSE_SPEED
	)

end


--------------------------------------------------
-- BALL VERTICAL OFFSET
--------------------------------------------------

local function getBallVerticalOffset(ball)

	if BALL_VERTICAL_OFFSET > 0 then
		return BALL_VERTICAL_OFFSET
	end

	return ball.Size.Y / 2

end


--------------------------------------------------
-- COURSE DIRECTION
--------------------------------------------------

local function getCourseDirection(
	startPosition,
	tiles
)

	if typeof(startPosition) ~= "Vector3" then
		return nil
	end

	if #tiles < 1 then
		return nil
	end

	for _, tileData in ipairs(tiles) do

		local difference =
			tileData.Position - startPosition

		if difference.Magnitude > 0.001 then
			return difference.Unit
		end

	end

	return nil

end


--------------------------------------------------
-- STOP BALL
--------------------------------------------------

local function stopBall(ball)

	if not ball
		or not ball.Parent then
		return
	end

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero

end


--------------------------------------------------
-- REMOVE LINEAR VELOCITY
--------------------------------------------------

local function removePhysicsController(run)

	local controller =
		run.LinearVelocity

	if controller
		and controller.Parent then

		controller.Enabled = false
		controller:Destroy()

	end

	run.LinearVelocity = nil

end


--------------------------------------------------
-- FREEZE BALL
--------------------------------------------------

local function freezeFinishedBall(
	ball,
	run
)

	if not ball
		or not ball.Parent then
		return
	end

	if run then
		removePhysicsController(run)
	end

	stopBall(ball)

	ball.Anchored = true

	pcall(function()
		ball:SetNetworkOwner(nil)
	end)

end


--------------------------------------------------
-- PLACE BALL AT START
--------------------------------------------------

local function placeBallAtStart(
	ball,
	position
)

	if not ball
		or not ball.Parent then
		return false
	end

	local offset =
		getBallVerticalOffset(ball)

	local finalPosition =
		Vector3.new(
			position.X,
			position.Y + offset,
			position.Z
		)

	ball.Anchored = true

	stopBall(ball)

	ball.CFrame =
		CFrame.new(finalPosition)

	return true

end


--------------------------------------------------
-- BALL SPAWN CFRAME
--------------------------------------------------

local function getBallSpawnCFrame()

	if ballSpawn:IsA("BasePart") then
		return ballSpawn.CFrame
	end

	if ballSpawn:IsA("Model") then
		return ballSpawn:GetPivot()
	end

	warn(
		"[WinCourseProgressService]",
		"BallSpawn must be a BasePart or Model."
	)

	return nil

end


--------------------------------------------------
-- GET UP SOUND
--------------------------------------------------

local function createGetUpSound(ball)

	if not ball
		or not ball.Parent then
		return nil
	end

	local existing =
		ball:FindFirstChild(
			"WinCourseGetUpSound"
		)

	if existing
		and existing:IsA("Sound") then

		return existing

	end

	local sound =
		Instance.new("Sound")

	sound.Name =
		"WinCourseGetUpSound"

	sound.SoundId =
		GET_UP_SOUND_ID

	sound.Volume = 1

	sound.RollOffMode =
		Enum.RollOffMode.InverseTapered

	sound.RollOffMaxDistance = 80

	sound.Parent = ball

	return sound

end


--------------------------------------------------
-- PLAY SOUND
--------------------------------------------------

local function playGetUpSound(
	player,
	ball
)

	local sound =
		createGetUpSound(ball)

	if not sound then
		return
	end

	pcall(function()

		sound:Stop()
		sound:Play()

	end)

	debugPrint(
		player.Name,
		"RETURN SOUND PLAYED"
	)

end


--------------------------------------------------
-- FADE BALL
--------------------------------------------------

local function fadeBallOut(ball)

	if not ball
		or not ball.Parent then
		return
	end

	local originalTransparency =
		ball.Transparency

	local steps = 12

	for step = 1, steps do

		if not ball.Parent then
			return
		end

		local alpha =
			step / steps

		ball.Transparency =
			originalTransparency
			+
			(
				1 - originalTransparency
			)
			*
			alpha

		task.wait(
			RETURN_FADE_TIME / steps
		)

	end

end


--------------------------------------------------
-- RESTORE TRANSPARENCY
--------------------------------------------------

local function restoreBallTransparency(
	ball,
	transparency
)

	if not ball
		or not ball.Parent then
		return
	end

	ball.Transparency =
		transparency

end


--------------------------------------------------
-- SPAWN AURA
--------------------------------------------------

local function fireSpawnAura(
	player,
	ball
)

	if not player
		or not player.Parent then
		return
	end

	if not ball
		or not ball.Parent then
		return
	end

	SpawnAura:FireClient(
		player,
		{
			Duration = AURA_DURATION,

			Ball = ball,

			Style = AURA_STYLE,
		}
	)

	debugPrint(
		player.Name,
		"SPAWN AURA FIRED"
	)

end

--------------------------------------------------
-- RETURN BALL TO LOBBY
--------------------------------------------------

local function returnBallToLobby(player, run)

	if not run or run.Returned then
		return
	end

	run.Returned = true
	returningPlayers[player] = true

	local ball = run.Ball

	if not ball or not ball.Parent then
		returningPlayers[player] = nil
		return
	end

	--------------------------------------------------
	-- STOP WIN COURSE PHYSICS
	--------------------------------------------------

	removePhysicsController(run)

	stopBall(ball)

	-- Clear the release flag used by the lobby controller.
	ball:SetAttribute("WinCourseActive", false)

	winCourseRemote:FireClient(
		player,
		"ReturnToLobbyStart"
	)

	--------------------------------------------------
	-- FADE OUT
	--------------------------------------------------

	fadeBallOut(ball)

	if not ball.Parent then
		returningPlayers[player] = nil
		return
	end

	task.wait(RETURN_HOLD_TIME)

	if not ball.Parent then
		returningPlayers[player] = nil
		return
	end

	--------------------------------------------------
	-- MOVE TO LOBBY SPAWN
	--------------------------------------------------

	local spawnCFrame = getBallSpawnCFrame()

	if not spawnCFrame then
		warn(
			"[WinCourseProgressService] "
				.. "Cannot return ball: invalid BallSpawn."
		)

		restoreBallTransparency(
			ball,
			run.OriginalTransparency
		)

		returningPlayers[player] = nil
		return
	end

	local offset = getBallVerticalOffset(ball)

	local finalCFrame =
		spawnCFrame * CFrame.new(0, offset, 0)

	-- Keep the ball anchored while repositioning it.
	ball.Anchored = true

	stopBall(ball)

	ball.CFrame = finalCFrame

	--------------------------------------------------
	-- RESET WIN COURSE STATE
	--------------------------------------------------

	ball:SetAttribute("WinCourseActive", false)

	-- Remove stale WinCourse velocity objects.
	local winVelocity =
		ball:FindFirstChild(LINEAR_VELOCITY_NAME)

	if winVelocity then
		winVelocity:Destroy()
	end

	local winAttachment =
		ball:FindFirstChild("WinCourseAttachment")

	if winAttachment then
		winAttachment:Destroy()
	end

	--------------------------------------------------
	-- RESTORE APPEARANCE
	--------------------------------------------------

	restoreBallTransparency(
		ball,
		run.OriginalTransparency
	)

	--------------------------------------------------
	-- RESET PHYSICS BEFORE UNANCHORING
	--------------------------------------------------

	-- Keep the ball anchored while resetting its velocity.
	ball.Anchored = true

	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero

	--------------------------------------------------
	-- RELEASE BALL TO LOBBY PHYSICS
	--------------------------------------------------

	-- IMPORTANT:
	-- Unanchor FIRST. Network ownership cannot be
	-- assigned while the ball is anchored.
	ball.Anchored = false

	-- Wait for Roblox to update the physics assembly.
	RunService.Heartbeat:Wait()

	if not ball.Parent then
		returningPlayers[player] = nil
		return
	end

	-- Reset velocity again after release.
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero

	-- Release the ball before setting network ownership.
ball.Anchored = false

-- Wait for Roblox to update the physics assembly.
RunService.Heartbeat:Wait()

if not ball.Parent then
    returningPlayers[player] = nil
    return
end

-- Only set ownership if the entire assembly is unanchored.
local ownershipSuccess, ownershipError = pcall(function()
    if not ball.Anchored then
        ball:SetNetworkOwner(nil)
    end
end)

if not ownershipSuccess then
    warn(
        "[WinCourseProgressService] "
            .. "Server ownership reset failed:",
        ownershipError
    )
end

stopBall(ball)
	
-- Restore normal lobby movement.
player:SetAttribute("RunState", "Waiting")
	--------------------------------------------------
	-- COMPLETE RETURN
	--------------------------------------------------

	playGetUpSound(player, ball)

	winCourseRemote:FireClient(
		player,
		"ReturnedToLobby"
	)

	returningPlayers[player] = nil

	debugPrint(
		player.Name,
		"BALL RETURNED TO LOBBY",
		"| Anchored:",
		ball.Anchored,
		"| WinCourseActive:",
		ball:GetAttribute("WinCourseActive")
	)
end

--------------------------------------------------
-- AWARD WINNINGS
--------------------------------------------------

local function awardWinnings(
	player,
	amount
)

	amount =
		math.max(
			0,
			math.floor(
				tonumber(amount) or 0
			)
		)

	player:SetAttribute(
		"LastWinCourseWinnings",
		amount
	)

	if amount <= 0 then

		debugPrint(
			player.Name,
			"received 0 WinCourse winnings."
		)

		return true

	end


	--------------------------------------------------
	-- LEADERSTATS
	--------------------------------------------------

	local leaderstats =
		player:FindFirstChild("leaderstats")

	if leaderstats then

		local wins =
			leaderstats:FindFirstChild("Wins")

		if wins
			and (
				wins:IsA("IntValue")
				or wins:IsA("NumberValue")
			) then

			wins.Value += amount

			debugPrint(
				"WINNINGS AWARDED:",
				player.Name,
				"| Amount:",
				amount,
				"| New Wins:",
				wins.Value
			)

			return true

		end

	end


	--------------------------------------------------
	-- ATTRIBUTE ECONOMY
	--------------------------------------------------

	local existingWins =
		player:GetAttribute("Wins")

	if isFiniteNumber(existingWins) then

		player:SetAttribute(
			"Wins",
			existingWins + amount
		)

		debugPrint(
			"WINNINGS AWARDED:",
			player.Name,
			"| Amount:",
			amount,
			"| New Wins:",
			existingWins + amount
		)

		return true

	end

	warn(
		"[WinCourseProgressService]",
		"Could not award winnings for",
		player.Name,
		"| Amount:",
		amount
	)

	return false

end
--------------------------------------------------
-- UPDATE TILE PROGRESS
--
-- Awards each tile immediately when passed.
-- The ball continues rolling after the reward.
--------------------------------------------------

local function updateProgress(run)

	if run.Finished or not run.Rolling then
		return
	end

	local ball = run.Ball

	if not ball or not ball.Parent then
		return
	end

	local currentPosition = ball.Position

	-- Measure forward progress along the course.
	local forwardProgress =
		(currentPosition - run.RollStartPosition)
		:Dot(run.CourseDirection)

	forwardProgress = math.max(0, forwardProgress)

	-- Progress must never move backwards.
	run.CourseProgress = math.max(
		run.CourseProgress,
		forwardProgress
	)

	-- Process every tile crossed, in order.
	while run.FurthestTileIndex < run.TileCount do

		local nextIndex = run.FurthestTileIndex + 1
		local tileData = run.Tiles[nextIndex]

		if not tileData then
			break
		end

		local tileDistance =
			(tileData.Position - run.RollStartPosition)
			:Dot(run.CourseDirection)

		tileDistance = math.max(0, tileDistance)

		-- The server confirms that the ball has passed
		-- the tile's forward position.
		if run.CourseProgress + TILE_REACH_EPSILON
			< tileDistance then
			break
		end

		-- Advance first to prevent duplicate awards.
		run.FurthestTileIndex = nextIndex

		table.insert(run.CollectedTiles, tileData)

		-- Record the reward in the run total.
		run.TotalWinAmount += tileData.Amount

		-- Award this tile immediately.
		local awarded = awardWinnings(
			run.Player,
			tileData.Amount
		)

		if awarded then
			run.WinningsAwarded = true
			run.WinningsCredited =
				(run.WinningsCredited or 0)
				+ math.floor(tileData.Amount)
		else
			warn(
				"[WinCourseProgressService]",
				"Failed to award tile:",
				tileData.Model.Name,
				"to",
				run.Player.Name
			)
		end

		debugPrint(
			run.Player.Name,
			"PASSED TILE:",
			tileData.Model.Name,
			"| TILE WIN:",
			tileData.Amount,
			"| TOTAL WIN:",
			run.TotalWinAmount,
			"| BALL CONTINUES ROLLING"
		)

		-- Optional client notification for UI updates.
		winCourseRemote:FireClient(
			run.Player,
			"WinCourseTileCollected",
			{
				TileName = tileData.Model.Name,
				TileIndex = tileData.Index,
				TileWin = tileData.Amount,
				TotalWin = run.TotalWinAmount,
				DistanceTravelled = run.DistanceTravelled,
			}
		)
	end
end


--------------------------------------------------
-- FINALIZE WINNINGS
--
-- Rewards were credited when each tile was passed.
-- This function only finalizes the result.
--------------------------------------------------

local function finalizeWinnings(player, run)

	if run.WinningsFinalized then
		return run.FinalizedWinAmount
	end

	run.WinningsFinalized = true

	local amount = math.max(
		0,
		math.floor(run.TotalWinAmount)
	)

	run.FinalizedWinAmount = amount

	-- Do not call awardWinnings here.
	-- Every tile reward was already processed
	-- by updateProgress.

	debugPrint(
		"WINNINGS FINALIZED:",
		player.Name,
		"| Total:",
		amount,
		"| Already Credited:",
		run.WinningsCredited or 0
	)

	return amount
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


	--------------------------------------------------
	-- FINAL PROGRESS SAMPLE
	--------------------------------------------------

	if run.Ball
		and run.Ball.Parent then

		updateProgress(run)

	end

	run.Finished = true
	run.Rolling = false


	--------------------------------------------------
	-- STOP PHYSICS
	--------------------------------------------------

	freezeFinishedBall(
		run.Ball,
		run
	)


	--------------------------------------------------
	-- FINAL TILE
	--------------------------------------------------

	local finalTile = nil

	if run.FurthestTileIndex > 0 then

		finalTile =
			run.Tiles[
				run.FurthestTileIndex
			]

	end


	--------------------------------------------------
	-- WINNINGS
	--------------------------------------------------

	local finalizedWin =
		finalizeWinnings(
			player,
			run
		)


	--------------------------------------------------
	-- INACTIVE
	--------------------------------------------------

	if run.Ball
		and run.Ball.Parent then

		run.Ball:SetAttribute(
			"WinCourseActive",
			false
		)

	end


	--------------------------------------------------
	-- RESULT
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
				finalizedWin,

			DistanceTravelled =
				run.DistanceTravelled,

			CurrentOil =
				run.CurrentOil,

			StartingSpeed =
				run.StartingSpeed,

			OilSpeedBoost =
				run.OilSpeedBoost,

			MaxSpeed =
				run.MaxSpeed,

			Acceleration =
				WIN_COURSE_ACCELERATION,

			Reason =
				reason,

			ResultDisplayTime =
				RESULT_DISPLAY_TIME,

			WinningsAwarded =
				run.WinningsAwarded == true,
		}
	)


	debugPrint(
		"FINISHED:",
		player.Name,
		"| Reason:",
		reason,
		"| Distance:",
		run.DistanceTravelled,
		"| CourseProgress:",
		run.CourseProgress,
		"| Tiles:",
		run.FurthestTileIndex,
		"| Win:",
		run.TotalWinAmount,
		"| StartingSpeed:",
		run.StartingSpeed,
		"| OilBoost:",
		run.OilSpeedBoost
	)


	--------------------------------------------------
	-- RETURN
	--------------------------------------------------

	task.spawn(function()

		task.wait(
			RESULT_DISPLAY_TIME
		)

		if player.Parent then

			returnBallToLobby(
				player,
				run
			)

		else

			stopBall(run.Ball)

		end

		if activeRuns[player] == run then
			activeRuns[player] = nil
		end

	end)

end


--------------------------------------------------
-- UPDATE ROLLING RUN
--------------------------------------------------

local function updateRollingRun(
	player,
	run
)

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
	-- CURRENT POSITION
	--------------------------------------------------

	local currentPosition =
		ball.Position


	--------------------------------------------------
-- DISTANCE TRAVELLED
--------------------------------------------------

local previousPosition = run.LastPosition

if previousPosition then

	local frameDistance =
		(currentPosition - previousPosition).Magnitude

	if frameDistance >= 0 then
		run.DistanceTravelled += frameDistance
		run.LastGoodPosition = currentPosition
	end

end

run.LastPosition = currentPosition


	--------------------------------------------------
	-- ACCELERATION
	--
	-- Calculate the desired speed from elapsed
	-- roll time.
	--------------------------------------------------

	local currentSpeed =
		calculateRollSpeed(run)

	run.CurrentSpeed =
		currentSpeed


	--------------------------------------------------
	-- UPDATE THE EXISTING CONTROLLER
	--
	-- We do NOT create a new LinearVelocity.
	--------------------------------------------------

	local controller =
		run.LinearVelocity

	if controller
		and controller.Parent then

		controller.VectorVelocity =
			run.CourseDirection
			*
			currentSpeed

	end


--------------------------------------------------
-- TILE PROGRESS + DISTANCE GENERATION
--------------------------------------------------

updateProgress(run)

local ensured =
	WinCourseGenerator.EnsureTilesThroughDistance(
		run.CourseProgress
	)

if ensured then

	local refreshedTiles =
		collectWinTiles(run.WinCourse)

	if #refreshedTiles > 0 then
		run.Tiles = refreshedTiles
		run.TileCount = #refreshedTiles
	end

end

	--------------------------------------------------
	-- OIL EXHAUSTED
	--------------------------------------------------

	if run.DistanceTravelled
		>= run.TravelBudget
		-
		FINISH_EPSILON then

		finishRun(
			player,
			run,
			"OIL_EXHAUSTED"
		)

		return

	end

end


--------------------------------------------------
-- CREATE PHYSICS CONTROLLER
--------------------------------------------------

local function createPhysicsController(run)

	local ball =
		run.Ball

	if not ball
		or not ball.Parent then
		return nil
	end


	--------------------------------------------------
	-- REMOVE OLD CONTROLLER
	--------------------------------------------------

	local old =
		ball:FindFirstChild(
			LINEAR_VELOCITY_NAME
		)

	if old then
		old:Destroy()
	end


	--------------------------------------------------
	-- ATTACHMENT
	--------------------------------------------------

	local attachment =
		ball:FindFirstChild(
			"WinCourseAttachment"
		)

	if attachment
		and not attachment:IsA("Attachment") then

		attachment:Destroy()
		attachment = nil

	end

	if not attachment then

		attachment =
			Instance.new("Attachment")

		attachment.Name =
			"WinCourseAttachment"

		attachment.Parent =
			ball

	end


	--------------------------------------------------
	-- LINEAR VELOCITY
	--------------------------------------------------

	local linearVelocity =
		Instance.new("LinearVelocity")

	linearVelocity.Name =
		LINEAR_VELOCITY_NAME

	linearVelocity.Attachment0 =
		attachment

	linearVelocity.RelativeTo =
		Enum.ActuatorRelativeTo.World

	linearVelocity.VelocityConstraintMode =
		Enum.VelocityConstraintMode.Vector

	linearVelocity.VectorVelocity =
		run.CourseDirection
		*
		run.StartingSpeed


	--------------------------------------------------
	-- IMPORTANT
	--
	-- The target velocity is controlled by this
	-- service.
	--
	-- We do NOT directly force
	-- AssemblyLinearVelocity.
	--------------------------------------------------

	linearVelocity.ForceLimitsEnabled =
		false

	linearVelocity.Enabled =
		true

	linearVelocity.Parent =
		ball

	return linearVelocity

end


--------------------------------------------------
-- START PHYSICS ROLL
--------------------------------------------------

local function startPhysicsRoll(run)

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


	--------------------------------------------------
-- RELEASE BALL
--
-- Unanchor before setting network ownership.
--------------------------------------------------

ball.Anchored = false

-- Give Roblox a moment to update the physics assembly.
RunService.Heartbeat:Wait()

if not ball.Parent then
	return false
end

--------------------------------------------------
-- SERVER NETWORK OWNERSHIP
--------------------------------------------------

local success, err = pcall(function()
	ball:SetNetworkOwner(nil)
end)

if not success then
	warn(
		"[WinCourseProgressService]",
		"Could not set server network ownership:",
		tostring(err)
	)
end


	--------------------------------------------------
	-- CALCULATE SPEED
	--------------------------------------------------

	run.OilSpeedBoost =
		calculateOilSpeedBoost(
			run.CurrentOil
		)

	run.StartingSpeed =
		calculateStartingSpeed(
			run.CurrentOil
		)

	run.MaxSpeed =
		MAX_WIN_COURSE_SPEED

	run.CurrentSpeed =
		run.StartingSpeed

	--------------------------------------------------
	-- CREATE ONE CONTROLLER
	--------------------------------------------------

	local controller =
		createPhysicsController(run)

	if not controller then

		ball.Anchored =
			true

		return false

	end

	run.LinearVelocity =
		controller


	--------------------------------------------------
	-- START ROLL TIMER
	--
	-- Acceleration begins HERE.
	--------------------------------------------------

	run.RollStartTime =
		os.clock()

	run.Rolling =
		true

	run.Started =
		true


	--------------------------------------------------
	-- POSITION TRACKING
	--------------------------------------------------

	run.LastPosition =
		ball.Position

	run.LastGoodPosition =
		ball.Position

	run.DistanceTravelled =
		0

	run.CourseProgress =
		0


	--------------------------------------------------
	-- AURA
	--------------------------------------------------

	fireSpawnAura(
		run.Player,
		ball
	)


	--------------------------------------------------
	-- CLIENT
	--------------------------------------------------

	winCourseRemote:FireClient(
		run.Player,
		"RollStarted",
		{

			StartingSpeed =
				run.StartingSpeed,

			OilSpeedBoost =
				run.OilSpeedBoost,

			Acceleration =
				WIN_COURSE_ACCELERATION,

			MaxSpeed =
				run.MaxSpeed,

			CurrentOil =
				run.CurrentOil,

		}
	)


	debugPrint(
		"PHYSICS ROLL STARTED:",
		run.Player.Name,
		"| Oil:",
		run.CurrentOil,
		"| Oil Speed Boost:",
		run.OilSpeedBoost,
		"| Starting Speed:",
		run.StartingSpeed,
		"| Acceleration:",
		WIN_COURSE_ACCELERATION,
		"| Max Speed:",
		run.MaxSpeed,
		"| Direction:",
		run.CourseDirection
	)

	return true

end


--------------------------------------------------
-- UPDATE RUN
--------------------------------------------------

local function updateRun(
	player,
	run
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
	-- BALL NAME
	--------------------------------------------------

	local expectedName =
		"PlayerBall_"
		.. tostring(player.UserId)

	if ball.Name ~= expectedName then

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

		if not ball.Anchored then
			ball.Anchored = true
		end

		local elapsed =
			os.clock()
			-
			run.CountdownStarted

		if elapsed >= START_DELAY then

			local started =
				startPhysicsRoll(run)

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
	-- PHYSICS ROLL
	--------------------------------------------------

	updateRollingRun(
		player,
		run
	)

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

	if returningPlayers[player] then
		return
	end


	--------------------------------------------------
	-- COURSE
	--------------------------------------------------

	local courseData =
		createCourseData()

	if not courseData then
		return
	end


	--------------------------------------------------
	-- OIL
	--------------------------------------------------

	local currentOil =
		getCurrentOilAfterSettle(player)

	if currentOil == nil then

		warn(
			"[WinCourseProgressService]",
			"CurrentOil missing for",
			player.Name
		)

		return

	end


	--------------------------------------------------
	-- TRAVEL BUDGET
	--------------------------------------------------

	local travelBudget =
		currentOil * OIL_PER_STUD

	if travelBudget <= 0 then

		ball:SetAttribute(
			"WinCourseActive",
			false
		)

		return

	end


	--------------------------------------------------
	-- START
	--------------------------------------------------

	local startPosition =
		courseData.StartPosition


	--------------------------------------------------
	-- DIRECTION
	--------------------------------------------------

	local direction =
		getCourseDirection(
			startPosition,
			courseData.Tiles
		)

	if not direction then

		warn(
			"[WinCourseProgressService]",
			"Could not determine course direction."
		)

		return

	end


	--------------------------------------------------
	-- SPEED PREVIEW
	--------------------------------------------------

	local oilSpeedBoost =
		calculateOilSpeedBoost(
			currentOil
		)

	local startingSpeed =
		calculateStartingSpeed(
			currentOil
		)


	--------------------------------------------------
	-- MAX FRAME DISTANCE
	--------------------------------------------------

	local maxFrameDistance =
		math.max(
			25,
			MAX_WIN_COURSE_SPEED * 0.25
		)


	--------------------------------------------------
	-- CREATE RUN
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

		CurrentOil =
			currentOil,

		TravelBudget =
			travelBudget,

		WinningsCredited = 0,


		--------------------------------------------------
		-- SPEED
		--------------------------------------------------

		OilSpeedBoost =
			oilSpeedBoost,

		StartingSpeed =
			startingSpeed,

		CurrentSpeed =
			startingSpeed,

		MaxSpeed =
			MAX_WIN_COURSE_SPEED,


		--------------------------------------------------
		-- COUNTDOWN
		--------------------------------------------------

		CountdownStarted =
			os.clock(),

		Rolling =
			false,

		Started =
			false,

		RollStartTime =
			nil,


		--------------------------------------------------
		-- POSITION
		--------------------------------------------------

		RollStartPosition =
			startPosition,

		LastPosition =
			nil,

		LastGoodPosition =
			nil,

		DistanceTravelled =
			0,

		CourseProgress =
			0,

		MaxFrameDistance =
			maxFrameDistance,


		--------------------------------------------------
		-- TILES
		--------------------------------------------------

		FurthestTileIndex =
			0,

		CollectedTiles =
			{},

		TotalWinAmount =
			0,


		--------------------------------------------------
		-- STATE
		--------------------------------------------------

		Finished =
			false,

		Returned =
			false,


		--------------------------------------------------
		-- WINNINGS
		--------------------------------------------------

		WinningsFinalized =
			false,

		WinningsAwarded =
			false,

		FinalizedWinAmount =
			0,


		--------------------------------------------------
		-- PHYSICS
		--------------------------------------------------

		LinearVelocity =
			nil,


		--------------------------------------------------
		-- APPEARANCE
		--------------------------------------------------

		OriginalTransparency =
			ball.Transparency,

	}


	activeRuns[player] =
		run


	--------------------------------------------------
	-- PLACE BALL
	--------------------------------------------------

	local positioned =
		placeBallAtStart(
			ball,
			startPosition
		)

	if not positioned then

		activeRuns[player] =
			nil

		return

	end


	--------------------------------------------------
	-- COUNTDOWN
	--------------------------------------------------

	winCourseRemote:FireClient(
		player,
		"CountdownStart",
		START_DELAY
	)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print("================================")

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
		"CurrentOil:",
		currentOil
	)

	print(
		"[WinCourseProgressService]",
		"TravelBudget:",
		travelBudget
	)

	print(
		"[WinCourseProgressService]",
		"OilSpeedBoost:",
		oilSpeedBoost
	)

	print(
		"[WinCourseProgressService]",
		"StartingSpeed:",
		startingSpeed
	)

	print(
		"[WinCourseProgressService]",
		"Acceleration:",
		WIN_COURSE_ACCELERATION
	)

	print(
		"[WinCourseProgressService]",
		"MaxSpeed:",
		MAX_WIN_COURSE_SPEED
	)

	print(
		"[WinCourseProgressService]",
		"Official Start:",
		startPosition
	)

	print(
		"[WinCourseProgressService]",
		"Direction:",
		direction
	)

	print(
		"[WinCourseProgressService]",
		"Countdown:",
		START_DELAY
	)

	print(
		"[WinCourseProgressService]",
		"Aura:",
		AURA_STYLE
	)

	print("================================")

end


--------------------------------------------------
-- DISCOVER ACTIVE RUNS
--------------------------------------------------

local function discoverActiveRuns()

	for _, player in ipairs(
		Players:GetPlayers()
	) do

		if activeRuns[player] then
			continue
		end

		if returningPlayers[player] then
			continue
		end

		local ball =
			getPlayerBall(player)

		if not ball then
			continue
		end

		if ball:GetAttribute(
			"WinCourseActive"
		) ~= true then

			continue

		end

		if not getGeneratedWinCourse() then
			continue
		end

		startTracking(
			player,
			ball
		)

	end

end


--------------------------------------------------
-- HEARTBEAT
--------------------------------------------------

RunService.Heartbeat:Connect(
	function()

		discoverActiveRuns()

		for player, run in pairs(
			activeRuns
		) do

			if not player.Parent then

				removePhysicsController(run)

				stopBall(run.Ball)

				activeRuns[player] =
					nil

				continue

			end

			updateRun(
				player,
				run
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

			run.Finished =
				true

			removePhysicsController(
				run
			)

			stopBall(
				run.Ball
			)

		end

		activeRuns[player] =
			nil

		returningPlayers[player] =
			nil

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")

print(
	"[WinCourseProgressService]",
	"SERVER READY"
)

print(
	"[WinCourseProgressService]",
	"MODE:",
	"SERVER PHYSICS"
)

print(
	"[WinCourseProgressService]",
	"MOVEMENT:",
	"LinearVelocity"
)

print(
	"[WinCourseProgressService]",
	"BALL OWNERSHIP:",
	"SERVER"
)

print(
	"[WinCourseProgressService]",
	"COUNTDOWN BALL:",
	"ANCHORED"
)

print(
	"[WinCourseProgressService]",
	"ROLL RELEASE:",
	"SERVER CONTROLLED"
)

print(
	"[WinCourseProgressService]",
	"PER-FRAME CFRAME:",
	"DISABLED"
)

print(
	"[WinCourseProgressService]",
	"PER-FRAME ASSEMBLY VELOCITY:",
	"DISABLED"
)

print(
	"[WinCourseProgressService]",
	"PER-FRAME NETWORK OWNERSHIP:",
	"DISABLED"
)

print(
	"[WinCourseProgressService]",
	"START POSITION:",
	"WinCourseGenerator.GetStartPosition()"
)

print(
	"[WinCourseProgressService]",
	"RETURN POSITION:",
	"Workspace.BallSpawn"
)

print(
	"[WinCourseProgressService]",
	"SPAWN AURA REMOTE:",
	"Remotes.SpawnAura"
)

print(
	"[WinCourseProgressService]",
	"AURA STYLE:",
	AURA_STYLE
)

print(
	"[WinCourseProgressService]",
	"BASE SPEED:",
	BASE_WIN_COURSE_SPEED,
	"studs/sec"
)

print(
	"[WinCourseProgressService]",
	"OIL SPEED BOOST:",
	OIL_SPEED_BOOST_PER_OIL,
	"studs/sec per oil"
)

print(
	"[WinCourseProgressService]",
	"MAX OIL BOOST:",
	MAX_OIL_SPEED_BOOST,
	"studs/sec"
)

print(
	"[WinCourseProgressService]",
	"ACCELERATION:",
	WIN_COURSE_ACCELERATION,
	"studs/sec²"
)

print(
	"[WinCourseProgressService]",
	"MAX SPEED:",
	MAX_WIN_COURSE_SPEED,
	"studs/sec"
)

print(
	"[WinCourseProgressService]",
	"OIL TRAVEL:",
	OIL_PER_STUD,
	"oil/stud"
)

print(
	"[WinCourseProgressService]",
	"COUNTDOWN:",
	START_DELAY,
	"seconds"
)

print(
	"[WinCourseProgressService]",
	"RESULT DISPLAY:",
	RESULT_DISPLAY_TIME,
	"seconds"
)

print(
	"[WinCourseProgressService]",
	"RETURN FADE:",
	RETURN_FADE_TIME,
	"seconds"
)

print("================================")