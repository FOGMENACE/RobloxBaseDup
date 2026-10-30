--------------------------------------------------
-- RUN CONTROLLER
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--
-- TYPE:
-- Script
--
-- PURPOSE:
--
-- Controls:
-- - Run start
-- - Run state
-- - Oil course generation
-- - Run finish
-- - Start/Finish wall detection
-- - Launching WinCourse
--
-- IMPORTANT:
--
-- RunController DOES NOT:
-- - Calculate oil rewards
-- - Calculate WinCourse speed
-- - Calculate acceleration
-- - Move the ball
-- - Control WinCourse physics
--
-- OilCollectionService is a NORMAL SERVER SCRIPT.
-- It is NOT required with require().
--
-- BindableEvents are created automatically.
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService(
		"Players"
	)

local RunService =
	game:GetService(
		"RunService"
	)

local ServerScriptService =
	game:GetService(
		"ServerScriptService"
	)

local GameAnalytics = require(ServerScriptService:WaitForChild("GameAnalytics"))

-- FINISH CHECKS (anti-exploit): when each player's run started. A finish only counts if
-- the server simulated the ball the whole way (it owns the ball during the course) and the
-- run took at least as long as the fastest possible ball needs for the course length.
-- The oil course tops out around 82-110 studs/s; 140 leaves a generous margin for lag.
local MAX_PLAUSIBLE_COURSE_SPEED = 140
local runStartedAt = setmetatable({}, { __mode = "k" }) -- [player] = os.clock()


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)

local course =
	workspace:WaitForChild(
		"Course"
	)

local startWall =
	workspace:WaitForChild(
		"StartWall"
	)

local finishWall =
	workspace:WaitForChild(
		"FinishWall"
	)


--------------------------------------------------
-- CREATE / GET BINDABLE EVENTS
--------------------------------------------------

local function getOrCreateBindableEvent(
	name
)

	local existing =
		ServerScriptService:FindFirstChild(
			name
		)


	if existing then

		if not existing:IsA(
			"BindableEvent"
		) then

			error(
				"[RunController] "
					.. name
					.. " already exists but is not a BindableEvent."
			)

		end


		return existing

	end


	local event =
		Instance.new(
			"BindableEvent"
		)


	event.Name =
		name


	event.Parent =
		ServerScriptService


	print(
		"[RunController] Created BindableEvent:",
		name
	)


	return event

end


local startWinCourse =
	getOrCreateBindableEvent(
		"StartWinCourse"
	)


local generateOilCourse =
	getOrCreateBindableEvent(
		"GenerateOilCourse"
	)


local resetCurrentOil =
	getOrCreateBindableEvent(
		"ResetCurrentOil"
	)


--------------------------------------------------
-- SAFE NUMBER
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
-- READ CURRENT RUN OIL
--------------------------------------------------

local function getCurrentRunOil(
	player
)

	if not player then

		return 0

	end


	local currentOil =
		player:GetAttribute(
			"CurrentOil"
		)


	if not isFiniteNumber(
		currentOil
	) then

		warn(
			"[RunController]",
			player.Name,
			"CurrentOil is invalid:",
			currentOil
		)

		return 0

	end


	return math.max(
		0,
		currentOil
	)

end


--------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------

local function setupPlayer(
	player
)

	if player:GetAttribute(
		"RunState"
	) == nil then

		player:SetAttribute(
			"RunState",
			"Waiting"
		)

	end


	if player:GetAttribute(
		"CurrentOil"
	) == nil then

		player:SetAttribute(
			"CurrentOil",
			0
		)

	end


	if player:GetAttribute(
		"CollectedOilCount"
	) == nil then

		player:SetAttribute(
			"CollectedOilCount",
			0
		)

	end


	print(
		"[RunController]",
		player.Name,
		"RunState =",
		player:GetAttribute(
			"RunState"
		),
		"CurrentOil =",
		getCurrentRunOil(
			player
		)
	)

end


--------------------------------------------------
-- PLAYERS
--------------------------------------------------

Players.PlayerAdded:Connect(
	function(
		player
	)

		setupPlayer(
			player
		)

	end
)


for _, player in ipairs(
	Players:GetPlayers()
) do

	setupPlayer(
		player
	)

end


--------------------------------------------------
-- GET PLAYER FROM BALL
--------------------------------------------------

local function getPlayerFromBall(
	ball
)

	if not ball then

		return nil

	end


	if not ball:IsA(
		"BasePart"
	) then

		return nil

	end


	if ball.Parent ~= playerBalls then

		return nil

	end


	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	if not isFiniteNumber(
		ownerUserId
	) then

		return nil

	end


	local player =
		Players:GetPlayerByUserId(
			ownerUserId
		)


	if not player then

		return nil

	end


	local expectedName =
		"PlayerBall_"
		..
		tostring(
			player.UserId
		)


	if ball.Name ~= expectedName then

		return nil

	end


	return player

end


--------------------------------------------------
-- REMOVE LOBBY COURSE
--------------------------------------------------

-- The lobby preview is shared by every player in the server, so one player's run
-- must NOT delete it (that left everyone else with a bare lane until a rebuild).
-- Each client hides it locally while ITS player is running (CourseVisibility).
local function removeLobbyCourse()
	return

end


--------------------------------------------------
-- REMOVE OLD PLAYER COURSE
--------------------------------------------------

local function removeOldPlayerCourse(
	player
)

	local playerCourse =
		course:FindFirstChild(
			"PlayerCourse_"
			..
			tostring(
				player.UserId
			)
		)


	if playerCourse then

		print(
			"[RunController]",
			"Removing old player course:",
			playerCourse:GetFullName()
		)


		playerCourse:Destroy()

	end

end


--------------------------------------------------
-- GET PLAYER COURSE
--------------------------------------------------

local function getPlayerCourse(
	player
)

	if not player then

		return nil

	end


	return course:FindFirstChild(
		"PlayerCourse_"
		..
		tostring(
			player.UserId
		)
	)

end


--------------------------------------------------
-- RESET CURRENT RUN OIL
--
-- OilCollectionService is a NORMAL SCRIPT.
--
-- Therefore RunController does NOT require it.
--
-- Instead we fire ResetCurrentOil.
--
-- OilCollectionService should listen to:
--
-- ServerScriptService.ResetCurrentOil.Event
--
--------------------------------------------------

local function resetRunCollectionState(player)
	if not player then
		return false
	end

	-- Reset directly through the player's server attributes.
	-- Do not depend on a BindableEvent listener to reset the oil.
	player:SetAttribute("CurrentOil", 0)
	player:SetAttribute("CollectedOilCount", 0)

	-- Verify the reset immediately.
	local currentOil = player:GetAttribute("CurrentOil")
	local collectedCount = player:GetAttribute("CollectedOilCount")

	print(
		"[RunController] RESET VERIFICATION:",
		player.Name,
		"| CurrentOil:", currentOil,
		"| CollectedOilCount:", collectedCount
	)

	if currentOil ~= 0 or collectedCount ~= 0 then
		warn("[RunController] Oil reset failed for", player.Name)
		return false
	end

	return true
end


--------------------------------------------------
-- PREPARE BALL FOR RUN
--------------------------------------------------

local function prepareBallForRun(
	player,
	ball
)

	if not ball
		or not ball.Parent then

		return false

	end


	if ball:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		return false

	end


	--------------------------------------------------
	-- CLEAR OLD WIN COURSE STATE
	--------------------------------------------------

	ball:SetAttribute(
		"WinCourseActive",
		false
	)


	--------------------------------------------------
	-- CLEAR OLD WIN COURSE CONTROLLER
	--------------------------------------------------

	local oldController =
		ball:FindFirstChild(
			"WinCourseLinearVelocity"
		)


	if oldController then

		oldController:Destroy()

	end


	--------------------------------------------------
	-- STOP OLD MOTION
	--------------------------------------------------

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	return true

end


--------------------------------------------------
-- START RUN
--------------------------------------------------

--------------------------------------------------
-- CENTER BALL IN THE LANE AT RUN START
--
-- The start opening is ~23 studs wide but the panels sit in the middle, and the ball
-- keeps whatever X it crossed the line at. Other players then saw runners rolling far to
-- the left of the course. Glide the ball to the lane centre during the first moments of
-- the run (server-side, so every client sees the same thing).
--------------------------------------------------

local function centerBallInLane(player, ball)
	local worldOffset = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig")).Offset(player)
	local centerX = startWall.Position.X + worldOffset.X

	-- The server must own the ball BEFORE it is moved: the owning client keeps simulating it for a
	-- few frames after the run starts and would otherwise put it back at the side, which is what
	-- other players saw (a runner crossing the wall far to the left of the course).
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)

	local function snap()
		local dx = centerX - ball.Position.X
		if math.abs(dx) > 0.25 then
			ball.CFrame += Vector3.new(dx, 0, 0)
			local v = ball.AssemblyLinearVelocity
			ball.AssemblyLinearVelocity = Vector3.new(0, v.Y, v.Z)
		end
	end
	snap()

	-- re-pin for a moment in case a late client packet moved it again
	task.spawn(function()
		local elapsed = 0
		while elapsed < 0.25 and ball.Parent and player.Parent do
			elapsed += RunService.Heartbeat:Wait()
			local state = player:GetAttribute("RunState")
			if state ~= "Starting" and state ~= "Running" then
				return
			end
			snap()
		end
	end)
end

local function startRun(
	player,
	ball
)

	if player:GetAttribute(
		"RunState"
	) ~= "Waiting" then

		return

	end


	if not ball
		or not ball:IsA(
			"BasePart"
		) then

		return

	end


	if ball:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		warn(
			"[RunController]",
			player.Name,
			"StartWall ownership mismatch"
		)

		return

	end


	-- JoinGate: no run until the player's data, world and loading screen are done
	-- (slow connections could roll in behind the loading screen). The ball goes
	-- back to the spawn pad instead of being left on the course.
	if player:GetAttribute("JoinReady") ~= true then

		local spawnPart = workspace:FindFirstChild("BallSpawn")
		if spawnPart then
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.CFrame = CFrame.new(spawnPart.Position + WorldConfig.Offset(player) + Vector3.new(0, ball.Size.Y / 2 + 1, 0))
		end

		return

	end


	--------------------------------------------------
	-- LOCK RUN
	--------------------------------------------------

	player:SetAttribute(
		"RunState",
		"Starting"
	)


	print("================================")


	print(
		"[RunController]",
		player.Name,
		"START WALL REACHED"
	)


	--------------------------------------------------
	-- PREPARE BALL
	--------------------------------------------------

	if not prepareBallForRun(
		player,
		ball
	) then

		player:SetAttribute(
			"RunState",
			"Waiting"
		)

		return

	end

	centerBallInLane(player, ball)

	--------------------------------------------------
	-- RESET RUN OIL
	--------------------------------------------------

	if not resetRunCollectionState(
		player
	) then

		player:SetAttribute(
			"RunState",
			"Waiting"
		)

		return

	end


	--------------------------------------------------
	-- STARTER OIL (daily calendar reward)
	--
	-- Added AFTER the run-oil reset above, otherwise it would be wiped.
	-- Failure here must never block the run.
	--------------------------------------------------

	local starterOk, starterError = pcall(
		function()

			local starterOil = require(
				ServerScriptService:WaitForChild("StarterOil")
			).Take(player)

			if starterOil > 0 then

				-- Same accounting as OilCollectionService: the lifetime total
				-- (PlayerDataService) grows by the amount, and the player's
				-- CurrentOil ATTRIBUTE is this run's oil. AddOil overwrites the
				-- attribute with the lifetime total, so set the run oil
				-- explicitly afterwards; otherwise the previous run's oil
				-- leaks into the new run.
				require(
					ServerScriptService
						:WaitForChild("PlayerDataLoader")
						:WaitForChild("PlayerDataService")
				).AddOil(
					player,
					starterOil
				)

				player:SetAttribute(
					"CurrentOil",
					starterOil
				)

			end

		end
	)

	if not starterOk then

		warn(
			"[RunController] Starter oil failed:",
			starterError
		)

	end

	--------------------------------------------------
	-- REMOVE LOBBY COURSE
	--------------------------------------------------

	removeLobbyCourse()


	--------------------------------------------------
	-- REMOVE OLD COURSE
	--------------------------------------------------

	removeOldPlayerCourse(
		player
	)


	--------------------------------------------------
	-- GENERATE NEW COURSE
	--------------------------------------------------

	print(
		"[RunController]",
		player.Name,
		"FIRING GenerateOilCourse"
	)


	generateOilCourse:Fire(
		player
	)


	--------------------------------------------------
	-- WAIT FOR COURSE
	--------------------------------------------------

	local playerCourse = nil


	for attempt = 1, 20 do

		playerCourse =
			getPlayerCourse(
				player
			)


		if playerCourse then

			break

		end


		task.wait(
			0.05
		)

	end


	--------------------------------------------------
	-- GENERATION FAILED
	--------------------------------------------------

	if not playerCourse then

		warn(
			"[RunController]",
			player.Name,
			"FAILED: PlayerCourse was not generated"
		)


		player:SetAttribute(
			"RunState",
			"Waiting"
		)


		return

	end


	--------------------------------------------------
	-- COUNT ROWS
	--------------------------------------------------

	local rowCount =
		0


	for _, object in ipairs(
		playerCourse:GetChildren()
	) do

		if object:IsA(
			"Model"
		)
			and object.Name:match(
				"^OilRow_"
			) then

			rowCount += 1

		end

	end


	print(
		"[RunController]",
		player.Name,
		"Generated rows:",
		rowCount
	)


	--------------------------------------------------
	-- VALIDATE COURSE
	--------------------------------------------------

	if rowCount <= 0 then

		warn(
			"[RunController]",
			player.Name,
			"Generated course contains no OilRow models."
		)


		player:SetAttribute(
			"RunState",
			"Waiting"
		)


		return

	end


	--------------------------------------------------
	-- START RUN
	--------------------------------------------------

	player:SetAttribute(
		"RunState",
		"Running"
	)
	runStartedAt[player] = os.clock()


	print(
		"[RunController]",
		player.Name,
		"STARTED RUN"
	)


	print(
		"[RunController]",
		"Ball:",
		ball.Name
	)


	print(
		"[RunController]",
		"CurrentOil:",
		getCurrentRunOil(
			player
		)
	)


	print("================================")

end


--------------------------------------------------
-- FINISH RUN
--------------------------------------------------

local function finishRun(
	player,
	ball
)

	if player:GetAttribute(
		"RunState"
	) ~= "Running" then

		return

	end


	if not ball
		or not ball:IsA(
			"BasePart"
		) then

		return

	end


	if ball:GetAttribute(
		"OwnerUserId"
	) ~= player.UserId then

		warn(
			"[RunController]",
			player.Name,
			"FinishWall ownership mismatch"
		)

		return

	end


	--------------------------------------------------
	-- FINISH CHECKS (server-side, anti-exploit)
	--------------------------------------------------

	local suspicious = nil
	local okOwner, networkOwner = pcall(function()
		return ball:GetNetworkOwner()
	end)
	if okOwner and networkOwner ~= nil then
		suspicious = "the ball was not server-owned at the finish"
	end
	local startedAt = runStartedAt[player]
	local minSeconds = (finishWall.Position - startWall.Position).Magnitude / MAX_PLAUSIBLE_COURSE_SPEED
	local took = startedAt and (os.clock() - startedAt) or 0
	if not startedAt then
		suspicious = suspicious or "no recorded run start"
	elseif took < minSeconds then
		suspicious = suspicious or string.format("finished in %.1fs (fastest possible %.1fs)", took, minSeconds)
	end
	runStartedAt[player] = nil

	--------------------------------------------------
	-- LOCK FINISH
	--------------------------------------------------

	player:SetAttribute(
		"RunState",
		"Finishing"
	)

	-- an impossible finish earns nothing: this run's oil is taken back (from the run and
	-- from the saved total it was added to), so the WinCourse sends the ball home with no wins
	if suspicious then
		warn("[AUDIT] invalid oil-course finish:", player.Name, player.UserId, suspicious)
		local runOil = getCurrentRunOil(player)
		if runOil > 0 then
			pcall(function()
				local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
				local saved = PlayerDataService.GetOil(player)
				local take = math.min(runOil, saved)
				if take > 0 then
					PlayerDataService.RemoveOil(player, take)
				end
			end)
		end
		player:SetAttribute("CurrentOil", 0)
		player:SetAttribute("OilRawCollected", 0)
	end


	--------------------------------------------------
-- READ FINAL CURRENT OIL
--------------------------------------------------

local currentOil =
    getCurrentRunOil(player)

local collectedOilCount =
    player:GetAttribute("CollectedOilCount")

if not isFiniteNumber(collectedOilCount) then
    collectedOilCount = 0
end

print(
    "[RunController] FINAL OIL AUDIT:",
    player.Name,
    "| CurrentOil:",
    currentOil,
    "| CollectedOilCount:",
    collectedOilCount
)


	-- analytics: one event per finished run (report only)
	GameAnalytics.RunFinished(player, currentOil)


	--------------------------------------------------
	-- SAFETY REPAIR
	--------------------------------------------------

	local rawCurrentOil =
		player:GetAttribute(
			"CurrentOil"
		)


	if rawCurrentOil ~= currentOil then

		player:SetAttribute(
			"CurrentOil",
			currentOil
		)

	end


	print("================================")


	print(
		"[RunController]",
		player.Name,
		"FINISH WALL REACHED"
	)


	print(
		"[RunController]",
		"ACCUMULATED RUN OIL:",
		currentOil
	)


	print(
		"[RunController]",
		"CollectedOilCount:",
		player:GetAttribute(
			"CollectedOilCount"
		)
	)


	--------------------------------------------------
	-- APPLY THE OIL MULTIPLIERS ONCE (rebirth x boosts) to the final total
	--------------------------------------------------

	do
		local finishBridge = ServerScriptService:FindFirstChild("ApplyFinishOilMultiplier")
		if finishBridge then
			local okMultiply, finalOil = pcall(function()
				return finishBridge:Invoke(player)
			end)
			if okMultiply and isFiniteNumber(finalOil) then
				currentOil = finalOil
			else
				warn("[RunController] finish oil multiplier failed:", finalOil)
			end
		end
	end

	--------------------------------------------------
	-- ACTIVATE WIN COURSE
	--------------------------------------------------

	ball:SetAttribute(
		"WinCourseActive",
		true
	)


	--------------------------------------------------
	-- START WIN COURSE
	--------------------------------------------------

	print(
		"[RunController]",
		player.Name,
		"FIRING StartWinCourse"
	)


	startWinCourse:Fire(
		player,
		ball
	)


	print(
		"[RunController]",
		"WinCourseActive:",
		ball:GetAttribute(
			"WinCourseActive"
		)
	)


	print(
		"[RunController]",
		"WinCourse will use CurrentOil:",
		currentOil
	)


	print("================================")

end


--------------------------------------------------
-- OVERLAP SETTINGS
--------------------------------------------------

local overlapParams =
	OverlapParams.new()


overlapParams.FilterType =
	Enum.RaycastFilterType.Include


overlapParams.FilterDescendantsInstances = {
	playerBalls
}


overlapParams.MaxParts =
	100


--------------------------------------------------
-- GET BALLS INSIDE WALL
--------------------------------------------------

local function getBallsInWall(
	wall
)

	if not wall then

		return {}

	end


	if not wall:IsA(
		"BasePart"
	) then

		warn(
			"[RunController]",
			"Wall is not a BasePart:",
			wall:GetFullName()
		)


		return {}

	end


	return workspace:GetPartBoundsInBox(
		wall.CFrame,
		wall.Size,
		overlapParams
	)

end


--------------------------------------------------
-- CHECK START WALL
--------------------------------------------------

-- HARDENED START: a ball only starts a run when it ROLLS INTO the wall.
-- Rejected (no run, nothing changes) when the ball
--   * was created / respawned less than START_GRACE seconds ago (spawn
--     glitches, balls popping out of the floor),
--   * is anchored, moving absurdly fast, or high above the lane,
--   * is outside the lane width,
--   * was not on the LOBBY side of the wall on the previous frame, or
--     moved more than MAX_STEP studs since then (teleport / exploit).
local START_GRACE = 0.6
local MAX_START_SPEED = 160
local MAX_STEP = 14
local startSamples = setmetatable({}, { __mode = "k" }) -- [ball] = { Seen, LastZ }

-- The invisible StartWall is wider (about 35 studs) than the real opening in the
-- front wall (about 23 studs, between the two wall parts). A ball pressed against
-- the solid wall beside the opening used to touch the StartWall box and start a
-- run it could never roll into. Only the opening counts, measured from the
-- course's own side boundaries when they exist.
local OPENING_HALF = 11.5
do
	local course = workspace:FindFirstChild("Course")
	local left = course and course:FindFirstChild("LeftBoundary")
	local right = course and course:FindFirstChild("RightBoundary")
	if left and right then
		OPENING_HALF = math.min(OPENING_HALF, math.abs(left.Position.X - right.Position.X) / 2)
	end
end

local function inLaneOpening(ball, offset)
	local dx = ball.Position.X - (startWall.Position.X + offset.X)
	return math.abs(dx) <= OPENING_HALF - ball.Size.X * 0.25
end

local function startAllowed(ball, player)
	local now = os.clock()
	local sample = startSamples[ball]
	local z = ball.Position.Z

	if not sample then
		startSamples[ball] = { Seen = now, LastZ = z, Near = 0 }
		return false
	end

	local lastZ = sample.LastZ
	sample.LastZ = z

	-- the ball must have ROLLED toward the wall: seen on the lobby side within
	-- 14 studs of it for several consecutive frames before entering
	-- (approach is remembered for a couple of seconds, so a fast or laggy ball
	-- that is already inside the wall on its first frame still counts)
	-- A run now starts on ANY continuous touch of the wall from the lobby side:
	-- slow, angled, near the edge, or just a nudge. The old "must have rolled in
	-- for several frames" rule made some real rolls not count. The no-teleport
	-- rule below (MAX_STEP + previous frame on the lobby side) still blocks
	-- glitches and exploits.
	if sample.Near >= 3 then
		sample.ApproachAt = now
	end
	sample.Near = 0

	if now - sample.Seen < START_GRACE then
		return false
	end

	if ball.Anchored or ball.AssemblyLinearVelocity.Magnitude > MAX_START_SPEED then
		return false
	end

	local wallZ = startWall.Position.Z
	if lastZ >= wallZ or math.abs(z - lastZ) > MAX_STEP then
		return false
	end

	-- inside the lane OPENING and not flying
	if not inLaneOpening(ball, Vector3.zero) then
		return false
	end

	local half = startWall.Size / 2
	local bottom = startWall.Position.Y - half.Y
	if ball.Position.Y - bottom > 14 or ball.Position.Y < bottom - 2 then
		return false
	end

	return true
end

local WorldConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig"))

local function checkStartWall()

	-- the wall is a flat plane: check a box 0.75 stud thicker on each side so a
	-- ball that just touches / nearly touches it counts, not only one cutting it
	local wallSize = startWall.Size
	local thin = "X"
	if wallSize.Y < wallSize[thin] then thin = "Y" end
	if wallSize.Z < wallSize[thin] then thin = "Z" end
	local grown = Vector3.new(
		wallSize.X + (thin == "X" and 1.5 or 0),
		wallSize.Y + (thin == "Y" and 1.5 or 0),
		wallSize.Z + (thin == "Z" and 1.5 or 0)
	)
	local balls = workspace:GetPartBoundsInBox(startWall.CFrame, grown, overlapParams)

	-- Higher worlds: each lobby copy has its own course behind its own start
	-- wall; rolling through it starts the run right there.
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Id > 1 then
			for _, ball in ipairs(workspace:GetPartBoundsInBox(startWall.CFrame + world.Offset, grown, overlapParams)) do
				local player = getPlayerFromBall(ball)
				-- rolling forward through the copied wall (the copies are scenery, so
				-- the lobby-side history used by startAllowed does not apply here)
				if player and player:GetAttribute("World") == world.Id
					and player:GetAttribute("RunState") == "Waiting" and ball.AssemblyLinearVelocity.Z > 1
					and inLaneOpening(ball, world.Offset) then
					startRun(player, ball)
				end
			end
		end
	end

	local present = {}

	for _, ball in ipairs(
		balls
	) do

		local player =
			getPlayerFromBall(
				ball
			)

		if player then

			present[ball] = true

			if player:GetAttribute("RunState") == "Waiting" and startAllowed(ball, player) then
				startRun(
					player,
					ball
				)
			end

		end

	end

	-- keep tracking balls that are NOT in the wall so "previous side" is real
	local ballFolder = workspace:FindFirstChild("PlayerBalls")
	if ballFolder then
		for _, ball in ipairs(ballFolder:GetChildren()) do
			if ball:IsA("BasePart") and not present[ball] then
				local sample = startSamples[ball]
				if not sample then
					sample = { Seen = os.clock(), LastZ = ball.Position.Z, Near = 0 }
					startSamples[ball] = sample
				end
				sample.LastZ = ball.Position.Z
				local gap = startWall.Position.Z - ball.Position.Z
				if gap > 1 and gap <= MAX_STEP then
					sample.Near += 1
					if sample.Near >= 3 then
						sample.ApproachAt = os.clock()
					end
				else
					sample.Near = 0
				end

				-- SAFETY NET: a ball that ended up PAST the wall while the player is
				-- still in the lobby must never be left on the course without a game.
				if ball.Position.Z > startWall.Position.Z + 3 then
					local owner = getPlayerFromBall(ball)
					if owner and owner:GetAttribute("RunState") == "Waiting" then
						if sample.ApproachAt and os.clock() - sample.ApproachAt <= 4 then
							startRun(owner, ball) -- it did roll in: start the run now
						else
							-- it got there some other way (glitch / exploit): back to spawn
							local spawnPart = workspace:FindFirstChild("BallSpawn")
							if spawnPart then
								ball.AssemblyLinearVelocity = Vector3.zero
								ball.CFrame = CFrame.new(spawnPart.Position + WorldConfig.Offset(owner) + Vector3.new(0, ball.Size.Y / 2 + 1, 0))
							end
						end
					end
				end
			end
		end
	end

end

local function checkFinishWall(wallPart)

	local balls =
		getBallsInWall(
			wallPart or finishWall
		)


	for _, ball in ipairs(
		balls
	) do

		local player =
			getPlayerFromBall(
				ball
			)


		if player then

			if player:GetAttribute(
				"RunState"
			) == "Running" then

				print(
					"[RunController DEBUG]",
					"Finish ball detected:",
					ball.Name,
					"Player:",
					player.Name,
					"CurrentOil:",
					getCurrentRunOil(
						player
					)
				)


				finishRun(
					player,
					ball
				)

			end

		end

	end

end


--------------------------------------------------
-- FORCED RESET / RESPAWN RECOVERY
--
-- Players cannot reset from the menu (client/NoReset), but an exploiter or a
-- lethal glitch can still respawn the character. A respawn creates a NEW ball
-- and used to leave the run, win course, old course and RunState untouched, so
-- the player could not move and several scripts kept stale state.
--
-- On every RESPAWN (not the first spawn) the run is cut: other services drop
-- their per-run state (ForceResetRun event), this run's course and oil are
-- cleared, nothing is paid out for the unfinished run, progression that was
-- already credited is saved, and RunState returns to Waiting.
--------------------------------------------------

local forceResetEvent = ServerScriptService:FindFirstChild("ForceResetRun")
if not forceResetEvent then
	forceResetEvent = Instance.new("BindableEvent")
	forceResetEvent.Name = "ForceResetRun"
	forceResetEvent.Parent = ServerScriptService
end

local recovering = {}

local function recoverFromRespawn(player)
	if recovering[player] then
		return
	end
	recovering[player] = true

	local previous = player:GetAttribute("RunState")
	print("[AUDIT] respawn recovery:", player.Name, player.UserId, "RunState was", previous)

	-- 1) other services drop their state for this player
	pcall(function()
		forceResetEvent:Fire(player)
	end)

	-- 2) this run's course, oil and attributes
	removeOldPlayerCourse(player)
	resetRunCollectionState(player)
	for _, name in ipairs({ "WinTravelBudget", "WinDistanceTravelled", "WinSpeed" }) do
		player:SetAttribute(name, nil)
	end

	-- 3) the new ball must be a plain lobby ball
	task.spawn(function()
		local balls = workspace:WaitForChild("PlayerBalls")
		local ball
		for _ = 1, 60 do
			ball = balls:FindFirstChild("PlayerBall_" .. player.UserId)
			if ball then
				break
			end
			task.wait(0.1)
		end
		if ball then
			ball:SetAttribute("WinCourseActive", false)
			for _, name in ipairs({ "WinCourseLinearVelocity" }) do
				local leftover = ball:FindFirstChild(name)
				if leftover then
					leftover:Destroy()
				end
			end
			ball.Anchored = false
		end

		-- 4) back to the lobby, progress saved (only what was already credited)
		player:SetAttribute("RunState", "Waiting")

		pcall(function()
			require(
				ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
			).SavePlayer(player)
		end)

		recovering[player] = nil
	end)
end

local function watchRespawns(player)
	local spawnedOnce = false
	player.CharacterAdded:Connect(function()
		if spawnedOnce then
			recoverFromRespawn(player)
		end
		spawnedOnce = true
	end)
end

Players.PlayerAdded:Connect(watchRespawns)
for _, existing in ipairs(Players:GetPlayers()) do
	watchRespawns(existing)
end

Players.PlayerRemoving:Connect(function(player)
	recovering[player] = nil
end)

--------------------------------------------------
-- DUPLICATE COURSE SWEEP
--
-- There must be at most ONE oil course folder per player and no leftover
-- LobbyCourse preview during a run. A stray extra copy draws a second set of
-- platform numbers on top of the real ones.
--------------------------------------------------

task.spawn(function()
	while true do
		task.wait(2)

		local seen = {}
		for _, child in ipairs(course:GetChildren()) do
			if child:IsA("Folder") then
				local id = child.Name:match("^PlayerCourse_(%d+)$")
				if id then
					local owner = Players:GetPlayerByUserId(tonumber(id))
					if not owner then
						child:Destroy() -- course of a player who left
					elseif seen[id] then
						warn("[AUDIT] duplicate PlayerCourse removed for", id)
						child:Destroy()
					else
						seen[id] = child
					end
				end
			end
		end

	end
end)

--------------------------------------------------
-- FINISHED COURSE CLEANUP
--
-- Back in the lobby the finished course is removed: its rows sit exactly on the
-- lobby preview's rows, and the leftover see-through panels mixed with the preview
-- (a green preview panel behind a red one showed orange). Every run builds a new
-- course anyway (startRun).
--------------------------------------------------

local function watchCourseCleanup(player)
	player:GetAttributeChangedSignal("RunState"):Connect(function()
		if player:GetAttribute("RunState") == "Waiting" then
			removeOldPlayerCourse(player)
		end
	end)
end
Players.PlayerAdded:Connect(watchCourseCleanup)
for _, existing in ipairs(Players:GetPlayers()) do
	watchCourseCleanup(existing)
end

--------------------------------------------------
-- STUCK-RUN WATCHDOG
--
-- A run that started while the ball is still in the lobby (for any reason) can
-- never reach the course. If the ball stays clearly on the lobby side of the
-- start wall for 4 s during Starting/Running, the run is cancelled with the
-- same clean reset as a respawn (nothing extra is paid) and the ball goes back
-- to its world's spawn.
--------------------------------------------------

task.spawn(function()
	local stuckSince = {}
	while true do
		task.wait(0.5)
		local balls = workspace:FindFirstChild("PlayerBalls")
		for _, player in ipairs(Players:GetPlayers()) do
			local state = player:GetAttribute("RunState")
			local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
			local inLobby = ball ~= nil and (state == "Starting" or state == "Running")
				and ball:GetAttribute("WinCourseActive") ~= true
				and ball.Position.Z < startWall.Position.Z - 4
			if inLobby then
				stuckSince[player] = stuckSince[player] or os.clock()
				if os.clock() - stuckSince[player] > 4 then
					stuckSince[player] = nil
					warn("[RunController] run started but the ball never left the lobby, resetting:", player.Name)
					recoverFromRespawn(player)
					local spawnPart = workspace:FindFirstChild("BallSpawn")
					if spawnPart and ball.Parent then
						ball.AssemblyLinearVelocity = Vector3.zero
						ball.CFrame = CFrame.new(spawnPart.Position + WorldConfig.Offset(player) + Vector3.new(0, ball.Size.Y / 2 + 1, 0))
					end
				end
			else
				stuckSince[player] = nil
			end
		end
	end
end)

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

RunService.Heartbeat:Connect(
	function()

		checkStartWall()

		checkFinishWall()
		-- each world's own finish wall (WorldService places them)
		local worldsFolder = workspace:FindFirstChild("Worlds")
		if worldsFolder then
			for _, worldModel in ipairs(worldsFolder:GetChildren()) do
				local wall = worldModel:FindFirstChild("FinishWall")
				if wall then
					checkFinishWall(wall)
				end
			end
		end

	end
)


--------------------------------------------------
-- PLAYER CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(
		player
	)

		print(
			"[RunController]",
			player.Name,
			"removed"
		)

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")


print(
	"[RunController]",
	"SERVER READY"
)


print(
	"[RunController]",
	"Script type:",
	"NORMAL SERVER SCRIPT"
)


print(
	"[RunController]",
	"StartWall:",
	startWall:GetFullName()
)


print(
	"[RunController]",
	"FinishWall:",
	finishWall:GetFullName()
)


print(
	"[RunController]",
	"StartWinCourse:",
	startWinCourse:GetFullName()
)


print(
	"[RunController]",
	"GenerateOilCourse:",
	generateOilCourse:GetFullName()
)


print(
	"[RunController]",
	"ResetCurrentOil:",
	resetCurrentOil:GetFullName()
)


print(
	"[RunController]",
	"OilCollectionService:",
	"NORMAL SERVER SCRIPT - NO REQUIRE()"
)


print(
	"[RunController]",
	"Oil rewards:",
	"CONTROLLED BY OilCollectionService"
)


print(
	"[RunController]",
	"CurrentOil:",
	"ACCUMULATED POSITIVE OIL FOR CURRENT RUN"
)


print(
	"[RunController]",
	"WinCourse:",
	"READS CurrentOil SERVER-SIDE"
)


print(
	"[RunController]",
	"WinCourseActive:",
	"SET TRUE WHEN FINISH WALL IS REACHED"
)


print("================================")