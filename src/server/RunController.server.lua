local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild("PlayerBalls")

local course =
	workspace:WaitForChild("Course")

local startWall =
	workspace:WaitForChild("StartWall")

local finishWall =
	workspace:WaitForChild("FinishWall")

--------------------------------------------------
-- EVENTS
--------------------------------------------------

local startWinCourse =
	ServerScriptService:WaitForChild(
		"StartWinCourse"
	)

local generateOilCourse =
	ServerScriptService:WaitForChild(
		"GenerateOilCourse"
	)

assert(
	startWinCourse:IsA("BindableEvent"),
	"[RunController] StartWinCourse must be a BindableEvent"
)

assert(
	generateOilCourse:IsA("BindableEvent"),
	"[RunController] GenerateOilCourse must be a BindableEvent"
)

--------------------------------------------------
-- PLAYER SETUP
--------------------------------------------------

local function setupPlayer(player)

	--------------------------------------------------
	-- ONLY INITIALIZE IF THE ATTRIBUTES DO NOT
	-- ALREADY EXIST.
	--
	-- IMPORTANT:
	-- Do NOT blindly reset CurrentOil.
	--------------------------------------------------

	if player:GetAttribute("RunState") == nil then

		player:SetAttribute(
			"RunState",
			"Waiting"
		)

	end

	if player:GetAttribute("CurrentOil") == nil then

		player:SetAttribute(
			"CurrentOil",
			0
		)

	end

	print(
		"[RunController]",
		player.Name,
		"RunState =",
		player:GetAttribute("RunState"),
		"CurrentOil =",
		player:GetAttribute("CurrentOil")
	)

end

--------------------------------------------------
-- PLAYERS
--------------------------------------------------

Players.PlayerAdded:Connect(
	function(player)

		setupPlayer(player)

	end
)

for _, player in ipairs(
	Players:GetPlayers()
) do

	setupPlayer(player)

end

--------------------------------------------------
-- GET PLAYER FROM BALL
--------------------------------------------------

local function getPlayerFromBall(ball)

	if not ball then
		return nil
	end

	if not ball:IsA("BasePart") then
		return nil
	end

	if ball.Parent ~= playerBalls then
		return nil
	end

	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)

	if typeof(ownerUserId) ~= "number" then
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
		"PlayerBall_" ..
		player.UserId

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

		print(
			"[RunController] No LobbyCourse found to remove"
		)

		return

	end

	print(
		"[RunController] Removing LobbyCourse:",
		lobbyCourse:GetFullName()
	)

	lobbyCourse:Destroy()

	print(
		"[RunController] LobbyCourse removed"
	)

end

--------------------------------------------------
-- REMOVE OLD PLAYER COURSE
--------------------------------------------------

local function removeOldPlayerCourse(player)

	local playerCourse =
		course:FindFirstChild(
			"PlayerCourse_" ..
			player.UserId
		)

	if playerCourse then

		print(
			"[RunController] Removing old player course:",
			playerCourse:GetFullName()
		)

		playerCourse:Destroy()

	end

end

--------------------------------------------------
-- GET PLAYER COURSE
--------------------------------------------------

local function getPlayerCourse(player)

	if not player then
		return nil
	end

	return course:FindFirstChild(
		"PlayerCourse_" ..
		player.UserId
	)

end

--------------------------------------------------
-- CALCULATE COLLECTED OIL
--
-- THIS IS THE IMPORTANT FIX.
--
-- OilCollection marks the actual selected platform:
--
--     Collected = true
--
-- and the generator gives it:
--
--     OilAmount
--
-- Therefore the generated course itself is the
-- authoritative record of what was collected.
--
-- We do NOT depend exclusively on CurrentOil.
--------------------------------------------------

local function calculateCollectedOil(player)

	local playerCourse =
		getPlayerCourse(player)

	if not playerCourse then

		warn(
			"[RunController]",
			player.Name,
			"cannot calculate collected oil:",
			"PlayerCourse does not exist"
		)

		return nil, 0

	end

	local totalOil = 0
	local collectedCount = 0

	--------------------------------------------------
	-- SCAN EVERY OIL ROW
	--------------------------------------------------

	for _, row in ipairs(
		playerCourse:GetChildren()
	) do

		if not row:IsA("Model") then
			continue
		end

		if not row.Name:match(
			"^OilRow_"
		) then
			continue
		end

		--------------------------------------------------
		-- CHECK BOTH PLATFORMS
		--------------------------------------------------

		for _, object in ipairs(
			row:GetDescendants()
		) do

			if not object:IsA("BasePart") then
				continue
			end

			if object.Name ~= "OilPlatformL"
				and object.Name ~= "OilPlatformR" then

				continue

			end

			--------------------------------------------------
			-- ONLY COUNT ACTUALLY COLLECTED PLATFORMS
			--------------------------------------------------

			if object:GetAttribute(
				"Collected"
			) ~= true then

				continue

			end

			local amount =
				object:GetAttribute(
					"OilAmount"
				)

			if typeof(amount) ~= "number" then

				warn(
					"[RunController]",
					player.Name,
					"Collected platform has invalid OilAmount:",
					object:GetFullName()
				)

				continue

			end

			totalOil += amount
			collectedCount += 1

			print(
				"[RunController] COLLECTED PLATFORM:",
				object:GetFullName(),
				"OilAmount:",
				amount,
				"RunningTotal:",
				totalOil
			)

		end

	end

	return totalOil, collectedCount

end

--------------------------------------------------
-- SYNCHRONIZE CURRENT OIL
--
-- CurrentOil becomes a cached value.
--
-- The actual collected platforms are the source
-- of truth.
--------------------------------------------------

local function synchronizeCurrentOil(player)

	local totalOil, collectedCount =
		calculateCollectedOil(player)

	if totalOil == nil then

		return nil

	end

	--------------------------------------------------
	-- WRITE THE AUTHORITATIVE VALUE
	--------------------------------------------------

	player:SetAttribute(
		"CurrentOil",
		totalOil
	)

	--------------------------------------------------
	-- OPTIONAL DEBUG ATTRIBUTE
	--------------------------------------------------

	player:SetAttribute(
		"CollectedOilCount",
		collectedCount
	)

	print("================================")
	print(
		"[RunController] OIL SYNCHRONIZED"
	)
	print(
		"[RunController] Player:",
		player.Name
	)
	print(
		"[RunController] Collected platforms:",
		collectedCount
	)
	print(
		"[RunController] CurrentOil:",
		totalOil
	)
	print("================================")

	return totalOil

end

--------------------------------------------------
-- START RUN
--------------------------------------------------

local function startRun(
	player,
	ball
)

	--------------------------------------------------
	-- MUST BE WAITING
	--------------------------------------------------

	if player:GetAttribute(
		"RunState"
	) ~= "Waiting" then

		return

	end

	--------------------------------------------------
	-- VERIFY BALL OWNERSHIP
	--------------------------------------------------

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
	-- LOCK IMMEDIATELY
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
	-- RESET OIL FOR THE NEW RUN
	--
	-- THIS IS THE ONLY PLACE WE INTENTIONALLY
	-- RESET CURRENT OIL.
	--------------------------------------------------

	player:SetAttribute(
		"CurrentOil",
		0
	)

	player:SetAttribute(
		"CollectedOilCount",
		0
	)

	print(
		"[RunController]",
		player.Name,
		"CurrentOil RESET TO 0 FOR NEW RUN"
	)

	--------------------------------------------------
	-- REMOVE LOBBY
	--------------------------------------------------

	removeLobbyCourse()

	--------------------------------------------------
	-- REMOVE OLD PLAYER COURSE
	--------------------------------------------------

	removeOldPlayerCourse(player)

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
	-- VERIFY GENERATED COURSE
	--------------------------------------------------

	local playerCourse

	for attempt = 1, 20 do

		playerCourse =
			getPlayerCourse(player)

		if playerCourse then
			break
		end

		task.wait(0.05)

	end

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
	-- VERIFY ROW COUNT
	--------------------------------------------------

	local rowCount = 0

	for _, object in ipairs(
		playerCourse:GetChildren()
	) do

		if object:IsA("Model")
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
		"[RunController] Ball:",
		ball.Name
	)

	print(
		"[RunController] RunState:",
		player:GetAttribute(
			"RunState"
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

	--------------------------------------------------
	-- MUST BE RUNNING
	--------------------------------------------------

	if player:GetAttribute(
		"RunState"
	) ~= "Running" then

		return

	end

	--------------------------------------------------
	-- VERIFY BALL OWNERSHIP
	--------------------------------------------------

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
	-- IMPORTANT:
	--
	-- DO NOT TRUST THE EXISTING CurrentOil VALUE.
	--
	-- REBUILD IT FROM THE ACTUALLY COLLECTED
	-- OIL PLATFORMS.
	--------------------------------------------------

	local oil =
		synchronizeCurrentOil(
			player
		)

	if oil == nil then

		warn(
			"[RunController]",
			player.Name,
			"FAILED TO CALCULATE COLLECTED OIL"
		)

		--------------------------------------------------
		-- Allow another attempt rather than sending
		-- WinCourse an invalid zero.
		--------------------------------------------------

		player:SetAttribute(
			"RunState",
			"Running"
		)

		return

	end

	print("================================")

	print(
		"[RunController]",
		player.Name,
		"FINISH WALL REACHED"
	)

	print(
		"[RunController] AUTHORITATIVE OIL:",
		oil
	)

	print(
		"[RunController] CurrentOil ATTRIBUTE:",
		player:GetAttribute(
			"CurrentOil"
		)
	)

	print(
		"[RunController] CollectedOilCount:",
		player:GetAttribute(
			"CollectedOilCount"
		)
	)

	print(
		"[RunController] RunState:",
		player:GetAttribute(
			"RunState"
		)
	)

	--------------------------------------------------
	-- WIN
	--------------------------------------------------

	print(
		"[RunController]",
		player.Name,
		"FIRING StartWinCourse WITH OIL:",
		player:GetAttribute(
			"CurrentOil"
		)
	)

	startWinCourse:Fire(
		player,
		ball
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

overlapParams.MaxParts = 100

--------------------------------------------------
-- GET BALLS INSIDE WALL
--------------------------------------------------

local function getBallsInWall(wall)

	if not wall then
		return {}
	end

	if not wall:IsA("BasePart") then

		warn(
			"[RunController] Wall is not a BasePart:",
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

local function checkStartWall()

	local balls =
		getBallsInWall(
			startWall
		)

	for _, ball in ipairs(
		balls
	) do

		local player =
			getPlayerFromBall(
				ball
			)

		if player then

			startRun(
				player,
				ball
			)

		end

	end

end

--------------------------------------------------
-- CHECK FINISH WALL
--------------------------------------------------

local function checkFinishWall()

	local balls =
		getBallsInWall(
			finishWall
		)

	for _, ball in ipairs(
		balls
	) do

		print(
			"[RunController DEBUG] Ball detected:",
			ball.Name,
			"Owner:",
			ball:GetAttribute(
				"OwnerUserId"
			)
		)

		local player =
			getPlayerFromBall(
				ball
			)

		if player then

			print(
				"[RunController DEBUG] Player detected:",
				player.Name,
				"RunState:",
				player:GetAttribute(
					"RunState"
				),
				"CurrentOil:",
				player:GetAttribute(
					"CurrentOil"
				)
			)

			finishRun(
				player,
				ball
			)

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
	function(player)

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
print("[RunController] SERVER READY")

print(
	"[RunController] StartWall:",
	startWall:GetFullName()
)

print(
	"[RunController] FinishWall:",
	finishWall:GetFullName()
)

print(
	"[RunController] StartWinCourse:",
	startWinCourse:GetFullName()
)

print(
	"[RunController] GenerateOilCourse:",
	generateOilCourse:GetFullName()
)

print("================================")
