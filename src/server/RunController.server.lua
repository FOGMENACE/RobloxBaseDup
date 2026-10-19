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

local function removeLobbyCourse()

	local lobbyCourse =
		course:FindFirstChild(
			"LobbyCourse"
		)


	if not lobbyCourse then

		return

	end


	print(
		"[RunController]",
		"Removing LobbyCourse:",
		lobbyCourse:GetFullName()
	)


	lobbyCourse:Destroy()

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
	-- LOCK FINISH
	--------------------------------------------------

	player:SetAttribute(
		"RunState",
		"Finishing"
	)


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

	-- inside the lane and not flying
	local localPosition = startWall.CFrame:PointToObjectSpace(ball.Position)
	local half = startWall.Size / 2
	local laneHalf = math.max(half.X, half.Z) -- the long horizontal axis
	local horizontal = math.max(math.abs(localPosition.X), math.abs(localPosition.Z))
	if horizontal > laneHalf + ball.Size.X / 2 then
		return false
	end

	local bottom = startWall.Position.Y - half.Y
	if ball.Position.Y - bottom > 14 or ball.Position.Y < bottom - 2 then
		return false
	end

	return true
end

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
								ball.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, ball.Size.Y / 2 + 1, 0))
							end
						end
					end
				end
			end
		end
	end

end

local function checkFinishWall()

	local balls =
		getBallsInWall(
			finishWall
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
-- MAIN LOOP
--------------------------------------------------

RunService.Heartbeat:Connect(
	function()

		checkStartWall()

		checkFinishWall()

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