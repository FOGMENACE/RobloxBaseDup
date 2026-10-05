--------------------------------------------------
-- OIL COLLECTION
--
-- SERVER ONLY
--
-- CurrentOil is the authoritative oil value used
-- by the player progression systems.
--
-- IMPORTANT:
--
-- This script does NOT modify the physical state
-- of collected oil platforms.
--
-- It does NOT:
--     - Anchor platforms
--     - Move platforms
--     - Change CanCollide
--     - Change CanTouch
--     - Change CanQuery
--     - Change Transparency
--
-- A collected platform is only marked as collected.
--
-- The row is also marked as collected so the same
-- oil row cannot award oil twice.
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild("PlayerBalls")

local course =
	workspace:WaitForChild("Course")

--------------------------------------------------
-- SERVER-SIDE RUN OIL
--
-- [player] = total oil collected during
-- the current run.
--------------------------------------------------

local runOil = {}

--------------------------------------------------
-- SERVER-SIDE COLLECTION COUNT
--
-- [player] = number of platforms collected
-- during the current run.
--------------------------------------------------

local runCollectedCount = {}

--------------------------------------------------
-- LAST RUN STATE
--
-- Used to detect:
--
-- non-Running -> Running
--
-- and initialize the run exactly once.
--------------------------------------------------

local lastRunState = {}

--------------------------------------------------
-- BALL -> PLAYER
--------------------------------------------------

local function getPlayerFromBall(ball)

	if not ball
		or not ball:IsA("BasePart") then

		return nil

	end


	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	if typeof(ownerUserId) ~= "number" then

		return nil

	end


	return Players:GetPlayerByUserId(
		ownerUserId
	)

end

--------------------------------------------------
-- OVERLAP SCORE
--
-- This only checks whether the ball overlaps
-- the platform.
--
-- It does NOT modify either object.
--------------------------------------------------

local function getOverlapScore(
	ball,
	platform
)

	if not ball
		or not platform
		or not platform:IsA("BasePart") then

		return 0

	end


	local platformCFrame =
		platform.CFrame

	local platformSize =
		platform.Size


	local localPosition =
		platformCFrame:PointToObjectSpace(
			ball.Position
		)


	local ballHalfX =
		ball.Size.X / 2

	local ballHalfY =
		ball.Size.Y / 2

	local ballHalfZ =
		ball.Size.Z / 2


	local platformHalfX =
		platformSize.X / 2

	local platformHalfY =
		platformSize.Y / 2

	local platformHalfZ =
		platformSize.Z / 2


	local overlapX =
		math.max(
			0,

			math.min(
				localPosition.X + ballHalfX,
				platformHalfX
			)
			-
			math.max(
				localPosition.X - ballHalfX,
				-platformHalfX
			)
		)


	local overlapY =
		math.max(
			0,

			math.min(
				localPosition.Y + ballHalfY,
				platformHalfY
			)
			-
			math.max(
				localPosition.Y - ballHalfY,
				-platformHalfY
			)
		)


	local overlapZ =
		math.max(
			0,

			math.min(
				localPosition.Z + ballHalfZ,
				platformHalfZ
			)
			-
			math.max(
				localPosition.Z - ballHalfZ,
				-platformHalfZ
			)
		)


	return overlapX *
		overlapY *
		overlapZ

end

--------------------------------------------------
-- INITIALIZE NEW RUN
--------------------------------------------------

local function initializeRun(
	player
)

	--------------------------------------------------
	-- START FROM CURRENT OIL
	--
	-- We preserve whatever value currently exists.
	--------------------------------------------------

	local currentOil =
		player:GetAttribute(
			"CurrentOil"
		)


	if typeof(currentOil) ~= "number" then

		currentOil = 0

	end


	if currentOil < 0 then

		currentOil = 0

	end


	--------------------------------------------------
	-- SERVER ACCUMULATOR
	--------------------------------------------------

	runOil[player] =
		currentOil


	--------------------------------------------------
	-- COLLECTION COUNT
	--------------------------------------------------

	runCollectedCount[player] =
		0


	--------------------------------------------------
	-- SYNCHRONIZE ATTRIBUTES
	--------------------------------------------------

	player:SetAttribute(
		"CurrentOil",
		currentOil
	)

	player:SetAttribute(
		"CollectedOilCount",
		0
	)


	print("================================")

	print(
		"[OilCollection]",
		player.Name,
		"NEW RUN INITIALIZED"
	)

	print(
		"[OilCollection] Starting CurrentOil:",
		currentOil
	)

	print(
		"[OilCollection] Starting CollectedOilCount:",
		0
	)

	print("================================")

end

--------------------------------------------------
-- CLEAR RUN
--------------------------------------------------

local function clearRun(
	player
)

	runOil[player] =
		nil

	runCollectedCount[player] =
		nil

end

--------------------------------------------------
-- GET SERVER OIL
--------------------------------------------------

local function getRunOil(
	player
)

	local oil =
		runOil[player]


	if typeof(oil) ~= "number" then

		--------------------------------------------------
		-- SAFETY FALLBACK
		--------------------------------------------------

		oil =
			player:GetAttribute(
				"CurrentOil"
			)


		if typeof(oil) ~= "number" then

			oil = 0

		end


		if oil < 0 then

			oil = 0

		end


		runOil[player] =
			oil

	end


	return oil

end

--------------------------------------------------
-- VALIDATE OIL AMOUNT
--------------------------------------------------

local function getValidOilAmount(
	platform
)

	local oilAmount =
		platform:GetAttribute(
			"OilAmount"
		)


	if typeof(oilAmount) ~= "number" then

		warn(
			"[OilCollection]",
			platform:GetFullName(),
			"has invalid OilAmount:",
			oilAmount
		)

		return nil

	end


	if oilAmount ~= oilAmount then

		warn(
			"[OilCollection]",
			platform:GetFullName(),
			"OilAmount is NaN"
		)

		return nil

	end


	if oilAmount == math.huge
		or oilAmount == -math.huge then

		warn(
			"[OilCollection]",
			platform:GetFullName(),
			"OilAmount is infinite"
		)

		return nil

	end


	if oilAmount < 0 then

		warn(
			"[OilCollection]",
			platform:GetFullName(),
			"OilAmount is negative:",
			oilAmount
		)

		return nil

	end


	return oilAmount

end

--------------------------------------------------
-- COLLECT PLATFORM
--
-- IMPORTANT:
--
-- THIS FUNCTION DOES NOT CHANGE THE PLATFORM'S
-- PHYSICAL PROPERTIES.
--
-- No:
--     Transparency
--     CanCollide
--     CanTouch
--     CanQuery
--     Anchored
--     CFrame
--
-- are changed here.
--------------------------------------------------

local function collectPlatform(
	platform,
	player
)

	if not platform
		or not platform.Parent then

		return false

	end


	if not player
		or not player:IsDescendantOf(Players) then

		return false

	end


	--------------------------------------------------
	-- ALREADY COLLECTED
	--------------------------------------------------

	if platform:GetAttribute(
		"Collected"
	) == true then

		return false

	end


	--------------------------------------------------
	-- GET OIL AMOUNT
	--------------------------------------------------

	local oilAmount =
		getValidOilAmount(
			platform
		)


	if oilAmount == nil then

		return false

	end


	--------------------------------------------------
	-- LOCK PLATFORM FIRST
	--
	-- This prevents duplicate collection.
	--------------------------------------------------

	platform:SetAttribute(
		"Collected",
		true
	)


	--------------------------------------------------
	-- READ SERVER-SIDE RUN TOTAL
	--------------------------------------------------

	local previousOil =
		getRunOil(
			player
		)


	--------------------------------------------------
	-- ADD OIL
	--------------------------------------------------

	local newOil =
		previousOil +
		oilAmount


	--------------------------------------------------
	-- STORE SERVER-SIDE TOTAL
	--------------------------------------------------

	runOil[player] =
		newOil


	--------------------------------------------------
	-- SYNCHRONIZE PLAYER ATTRIBUTE
	--------------------------------------------------

	player:SetAttribute(
		"CurrentOil",
		newOil
	)


	--------------------------------------------------
	-- COLLECTION COUNT
	--------------------------------------------------

	local previousCount =
		runCollectedCount[player]


	if typeof(previousCount) ~= "number" then

		previousCount = 0

	end


	local newCount =
		previousCount + 1


	runCollectedCount[player] =
		newCount


	--------------------------------------------------
	-- SYNCHRONIZE COUNT ATTRIBUTE
	--------------------------------------------------

	player:SetAttribute(
		"CollectedOilCount",
		newCount
	)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print("================================")

	print(
		"[OilCollection]",
		player.Name,
		"COLLECTED OIL"
	)

	print(
		"[OilCollection] Platform:",
		platform.Name
	)

	print(
		"[OilCollection] Amount:",
		oilAmount
	)

	print(
		"[OilCollection] Previous:",
		previousOil
	)

	print(
		"[OilCollection] CurrentOil:",
		newOil
	)

	print(
		"[OilCollection] CollectedOilCount:",
		newCount
	)

	print(
		"[OilCollection] SERVER TOTAL:",
		runOil[player]
	)

	print(
		"[OilCollection] Platform physics:",
		"UNCHANGED"
	)

	print("================================")


	--------------------------------------------------
	-- HIDE EXISTING GUI ONLY
	--
	-- This does not affect the platform itself.
	--------------------------------------------------

	for _, descendant in ipairs(
		platform:GetDescendants()
	) do

		if descendant:IsA("SurfaceGui") then

			descendant.Enabled =
				false

		end

	end


	--------------------------------------------------
	-- IMPORTANT:
	--
	-- DO NOT TOUCH:
	--
	-- platform.Transparency
	-- platform.CanCollide
	-- platform.CanTouch
	-- platform.CanQuery
	-- platform.Anchored
	-- platform.CFrame
	--
	-- The platform remains physically identical
	-- after collection.
	--------------------------------------------------

	return true

end

--------------------------------------------------
-- GET PLATFORMS
--------------------------------------------------

local function getPlatforms(row)

	local left =
		row:FindFirstChild(
			"OilPlatformL",
			true
		)


	local right =
		row:FindFirstChild(
			"OilPlatformR",
			true
		)


	if not left
		or not right then

		return nil, nil

	end


	if not left:IsA("BasePart")
		or not right:IsA("BasePart") then

		return nil, nil

	end


	return left, right

end

--------------------------------------------------
-- CHECK ROW
--------------------------------------------------

local function checkRow(
	row,
	ball,
	player
)

	if not row
		or not row:IsA("Model") then

		return

	end

	--------------------------------------------------
	-- GET PLATFORMS
	--------------------------------------------------

	local left, right =
		getPlatforms(row)

	if not left
		or not right then

		return

	end

	--------------------------------------------------
	-- READ INDIVIDUAL PLATFORM STATE
	--------------------------------------------------

	local leftCollected =
		left:GetAttribute("Collected") == true

	local rightCollected =
		right:GetAttribute("Collected") == true

	--------------------------------------------------
	-- IF BOTH PLATFORMS HAVE BEEN COLLECTED,
	-- THE ROW IS FINISHED.
	--------------------------------------------------

	if leftCollected and rightCollected then

		row:SetAttribute(
			"OilCollected",
			true
		)

		return

	end

	--------------------------------------------------
	-- IMPORTANT:
	--
	-- DO NOT use OilCollected as the individual
	-- platform collection lock.
	--
	-- The platforms themselves own their state.
	--------------------------------------------------

	local leftOverlap = 0
	local rightOverlap = 0

	if not leftCollected then

		leftOverlap =
			getOverlapScore(
				ball,
				left
			)

	end

	if not rightCollected then

		rightOverlap =
			getOverlapScore(
				ball,
				right
			)

	end

	--------------------------------------------------
	-- NOTHING HIT
	--------------------------------------------------

	if leftOverlap <= 0
		and rightOverlap <= 0 then

		return

	end

	--------------------------------------------------
	-- SELECT THE PLATFORM ACTUALLY HIT
	--------------------------------------------------

	local selectedPlatform

	if leftOverlap > 0
		and rightOverlap <= 0 then

		selectedPlatform = left

	elseif rightOverlap > 0
		and leftOverlap <= 0 then

		selectedPlatform = right

	else

		--------------------------------------------------
		-- BOTH OVERLAPPED.
		-- Choose the one with the greatest overlap.
		--------------------------------------------------

		if leftOverlap > rightOverlap then

			selectedPlatform = left

		elseif rightOverlap > leftOverlap then

			selectedPlatform = right

		else

			local leftDistance =
				(ball.Position - left.Position).Magnitude

			local rightDistance =
				(ball.Position - right.Position).Magnitude

			if leftDistance <= rightDistance then

				selectedPlatform = left

			else

				selectedPlatform = right

			end

		end

	end

	--------------------------------------------------
	-- SAFETY
	--------------------------------------------------

	if not selectedPlatform then
		return
	end

	--------------------------------------------------
	-- COLLECT ONLY THIS PLATFORM
	--------------------------------------------------

	local collected =
		collectPlatform(
			selectedPlatform,
			player
		)

	if not collected then
		return
	end

	--------------------------------------------------
	-- DO NOT MARK THE WHOLE ROW COLLECTED HERE.
	--
	-- Only mark the row complete if BOTH platforms
	-- are now collected.
	--------------------------------------------------

	local leftNowCollected =
		left:GetAttribute("Collected") == true

	local rightNowCollected =
		right:GetAttribute("Collected") == true

	if leftNowCollected
		and rightNowCollected then

		row:SetAttribute(
			"OilCollected",
			true
		)

		row:SetAttribute(
			"CollectedPlatform",
			"BOTH"
		)

	else

		row:SetAttribute(
			"OilCollected",
			false
		)

		row:SetAttribute(
			"CollectedPlatform",
			selectedPlatform.Name
		)

	end

end


--------------------------------------------------
-- PLAYER INITIALIZATION
--------------------------------------------------

local function setupPlayer(
	player
)

	if typeof(
		player:GetAttribute(
			"CurrentOil"
		)
	) ~= "number" then

		player:SetAttribute(
			"CurrentOil",
			0
		)

	end


	if typeof(
		player:GetAttribute(
			"CollectedOilCount"
		)
	) ~= "number" then

		player:SetAttribute(
			"CollectedOilCount",
			0
		)

	end


	lastRunState[player] =
		player:GetAttribute(
			"RunState"
		)

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

	setupPlayer(player)

end

--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		clearRun(
			player
		)

		lastRunState[player] =
			nil

	end
)

--------------------------------------------------
-- HANDLE RUN STATE
--------------------------------------------------

local function updateRunState(
	player
)

	local state =
		player:GetAttribute(
			"RunState"
		)


	local previousState =
		lastRunState[player]


	--------------------------------------------------
	-- NEW RUN
	--
	-- Anything -> Running
	--------------------------------------------------

	if state == "Running"
		and previousState ~= "Running" then

		initializeRun(
			player
		)


	--------------------------------------------------
	-- RUN ENDED
	--------------------------------------------------

	elseif state ~= "Running"
		and previousState == "Running" then

		print(
			"[OilCollection]",
			player.Name,
			"RUN ENDED"
		)


		print(
			"[OilCollection] Final CurrentOil:",
			player:GetAttribute(
				"CurrentOil"
			)
		)


		print(
			"[OilCollection] Final CollectedOilCount:",
			player:GetAttribute(
				"CollectedOilCount"
			)
		)


		clearRun(
			player
		)

	end


	lastRunState[player] =
		state

end

--------------------------------------------------
-- FIND PLAYER BALL
--------------------------------------------------

local function findPlayerBall(
	player
)

	local expectedName =
		"PlayerBall_" ..
		tostring(
			player.UserId
		)


	local namedBall =
		playerBalls:FindFirstChild(
			expectedName
		)


	if namedBall
		and namedBall:IsA("BasePart") then

		local ownerUserId =
			namedBall:GetAttribute(
				"OwnerUserId"
			)


		if ownerUserId ==
			player.UserId then

			return namedBall

		end

	end


	--------------------------------------------------
	-- FALLBACK:
	-- Search by OwnerUserId.
	--------------------------------------------------

	for _, child in ipairs(
		playerBalls:GetChildren()
	) do

		if not child:IsA("BasePart") then
			continue
		end


		if child:GetAttribute(
			"OwnerUserId"
		) == player.UserId then

			return child

		end

	end


	return nil

end

--------------------------------------------------
-- HEARTBEAT
--------------------------------------------------

RunService.Heartbeat:Connect(
	function()

		for _, player in ipairs(
			Players:GetPlayers()
		) do

			--------------------------------------------------
			-- HANDLE RUN STATE
			--------------------------------------------------

			updateRunState(
				player
			)


			--------------------------------------------------
			-- ONLY COLLECT DURING ACTIVE RUN
			--------------------------------------------------

			if player:GetAttribute(
				"RunState"
			) ~= "Running" then

				continue

			end


			--------------------------------------------------
			-- FIND PLAYER BALL
			--------------------------------------------------

			local ball =
				findPlayerBall(
					player
				)


			if not ball then

				continue

			end


			--------------------------------------------------
			-- PLAYER COURSE
			--------------------------------------------------

			local playerCourse =
				course:FindFirstChild(
					"PlayerCourse_" ..
					player.UserId
				)


			if not playerCourse then

				continue

			end


			--------------------------------------------------
			-- CHECK ALL OIL ROWS
			--------------------------------------------------

			for _, row in ipairs(
				playerCourse:GetChildren()
			) do

				if row:IsA("Model")
					and row.Name:match(
						"^OilRow_"
					) then

					checkRow(
						row,
						ball,
						player
					)

				end

			end

		end

	end
)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")

print(
	"[OilCollection]",
	"SERVER READY"
)

print(
	"[OilCollection]",
	"CurrentOil = authoritative oil value"
)

print(
	"[OilCollection]",
	"Server-side run accumulator ENABLED"
)

print(
	"[OilCollection]",
	"CollectedOilCount = platforms collected"
)

print(
	"[OilCollection]",
	"Collected platform physics = UNCHANGED"
)

print(
	"[OilCollection]",
	"No platform transparency/collision modification"
)

print("================================")
