--------------------------------------------------
-- OIL COURSE SERVICE
--
-- SERVER ONLY
--
-- LOCATION:
--
-- ServerScriptService
--     > OilCourseService
--     > OilCourseGenerator       <-- ModuleScript
--     > GenerateOilCourse        <-- BindableEvent
--
-- PURPOSE:
--
-- Coordinates oil-course generation.
--
-- RESPONSIBILITIES:
--
-- - Listen for GenerateOilCourse requests
-- - Prevent duplicate generation
-- - Call OilCourseGenerator
-- - Validate the generated course
-- - Validate generated rows
-- - Validate generated oil platforms
-- - Clean up player courses
--
-- THIS SERVICE DOES NOT:
--
-- - Generate oil
-- - Choose oil rarity
-- - Calculate rewards
-- - Apply multipliers
-- - Award Oil
-- - Award Wins
-- - Modify player data
-- - Handle balls
--
-- SPECIAL OIL:
--
-- Normal:
--     +500
--     -500
--
-- Multiplier:
--     X2
--     X4
--
-- Divider:
--     /2
--     /4
--
-- Special platforms are allowed to have:
--
--     OilAmount = 0
--
-- because OilCollectionService calculates their
-- effect from the player's currently accumulated
-- oil.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[OilCourseService] SCRIPT STARTED")
print("================================")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local course = Workspace:WaitForChild("Course")


--------------------------------------------------
-- GENERATE EVENT
--------------------------------------------------

local generateEvent = ServerScriptService:WaitForChild("GenerateOilCourse")

if not generateEvent:IsA("BindableEvent") then
	error("[OilCourseService] GenerateOilCourse must be a BindableEvent.")
end

print(
	"[OilCourseService] GenerateOilCourse found:",
	generateEvent:GetFullName()
)


--------------------------------------------------
-- GENERATOR
--------------------------------------------------

local generatorModule = ServerScriptService:WaitForChild("OilCourseGenerator")

if not generatorModule:IsA("ModuleScript") then
	error("[OilCourseService] OilCourseGenerator must be a ModuleScript.")
end


--------------------------------------------------
-- REQUIRE GENERATOR
--------------------------------------------------

local requireSuccess, OilCourseGenerator = pcall(function()
	return require(generatorModule)
end)

if not requireSuccess then
	error(
		"[OilCourseService] Failed to require OilCourseGenerator: "
			.. tostring(OilCourseGenerator)
	)
end


--------------------------------------------------
-- VALIDATE GENERATOR
--------------------------------------------------

if typeof(OilCourseGenerator) ~= "table" then
	error("[OilCourseService] OilCourseGenerator must return a table.")
end

if typeof(OilCourseGenerator.Generate) ~= "function" then
	error("[OilCourseService] OilCourseGenerator.Generate does not exist.")
end

print("[OilCourseService] OilCourseGenerator loaded successfully.")


--------------------------------------------------
-- GENERATION LOCK
--
-- player -> true
--------------------------------------------------

local generating = {}


--------------------------------------------------
-- GET COURSE NAME
--------------------------------------------------

local function getCourseName(player)
	return "PlayerCourse_" .. tostring(player.UserId)
end


--------------------------------------------------
-- GET PLAYER COURSE
--------------------------------------------------

local function getPlayerCourse(player)
	if not player then
		return nil
	end

	return course:FindFirstChild(getCourseName(player))
end


--------------------------------------------------
-- VALID PLAYER
--------------------------------------------------

local function isValidPlayer(player)
	if not player then
		return false
	end

	if not player:IsA("Player") then
		return false
	end

	if not player:IsDescendantOf(Players) then
		return false
	end

	return true
end


--------------------------------------------------
-- FINITE NUMBER
--------------------------------------------------

local function isFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end


--------------------------------------------------
-- SAFE INTEGER
--
-- NEVER calls math.floor unless the input is
-- confirmed to be a finite number.
--------------------------------------------------

local function getSafeInteger(value)
	if not isFiniteNumber(value) then
		return nil
	end

	return math.floor(value)
end


--------------------------------------------------
-- GET EFFECT TYPE
--
-- Supports:
--
-- Kind = "Normal"
-- Kind = "Multiplier"
-- Kind = "Divider"
--
-- Also supports OilEffectType for compatibility.
--------------------------------------------------

local function getPlatformEffectType(platform)
	local kind = platform:GetAttribute("Kind")

	if kind == "Normal"
		or kind == "Multiplier"
		or kind == "Divider" then
		return kind
	end

	local effectType = platform:GetAttribute("OilEffectType")

	if effectType == "Normal"
		or effectType == "Multiplier"
		or effectType == "Divider" then
		return effectType
	end

	--------------------------------------------------
	-- Legacy detection
	--------------------------------------------------

	local multiplier = platform:GetAttribute("Multiplier")

	if isFiniteNumber(multiplier) then
		if multiplier > 1 then
			return "Multiplier"
		end

		if multiplier > 0 and multiplier < 1 then
			return "Divider"
		end
	end

	return "Normal"
end


--------------------------------------------------
-- VALIDATE PLATFORM
--------------------------------------------------

local function validatePlatform(platform, rowName)
	if not platform then
		return false
	end


	--------------------------------------------------
	-- TYPE
	--------------------------------------------------

	if not platform:IsA("BasePart")
		and not platform:IsA("Model") then

		warn(
			"[OilCourseService] Invalid platform:",
			platform:GetFullName(),
			platform.ClassName
		)

		return false
	end


	--------------------------------------------------
	-- OIL TYPE
	--------------------------------------------------

	local oilType = platform:GetAttribute("OilType")

	if typeof(oilType) ~= "string"
		or oilType == "" then

		warn(
			"[OilCourseService] Platform missing OilType:",
			platform:GetFullName(),
			"Row:",
			rowName
		)

		return false
	end


	--------------------------------------------------
	-- EFFECT TYPE
	--------------------------------------------------

	local effectType = getPlatformEffectType(platform)

	if not effectType then
		warn(
			"[OilCourseService] Platform has invalid effect type:",
			platform:GetFullName(),
			platform:GetAttribute("Kind"),
			platform:GetAttribute("OilEffectType")
		)

		return false
	end


	--------------------------------------------------
	-- OIL AMOUNT
	--
	-- IMPORTANT:
	--
	-- Normal platforms MUST have a non-zero amount.
	--
	-- Special platforms are intentionally allowed
	-- to have OilAmount = 0.
	--------------------------------------------------

	local oilAmount = platform:GetAttribute("OilAmount")

	if not isFiniteNumber(oilAmount) then
		warn(
			"[OilCourseService] Invalid OilAmount:",
			platform:GetFullName(),
			oilAmount
		)

		return false
	end


	if effectType == "Normal" and oilAmount == 0 then
		warn(
			"[OilCourseService] Normal platform cannot have OilAmount = 0:",
			platform:GetFullName()
		)

		return false
	end


	--------------------------------------------------
	-- POSITIVE
	--------------------------------------------------

	local positive = platform:GetAttribute("Positive")

	if typeof(positive) ~= "boolean" then
		warn(
			"[OilCourseService] Platform missing Positive attribute:",
			platform:GetFullName()
		)

		return false
	end


	--------------------------------------------------
	-- COLLECTED
	--------------------------------------------------

	local collected = platform:GetAttribute("Collected")

	if typeof(collected) ~= "boolean" then
		warn(
			"[OilCourseService] Platform missing Collected attribute:",
			platform:GetFullName()
		)

		return false
	end


	--------------------------------------------------
	-- EFFECT VALUE
	--
	-- Normal:
	--     1
	--
	-- X2:
	--     2
	--
	-- X4:
	--     4
	--
	-- /2:
	--     2
	--
	-- /4:
	--     4
	--------------------------------------------------

	local effectValue = platform:GetAttribute("EffectValue")

	if not isFiniteNumber(effectValue) then
		warn(
			"[OilCourseService] Invalid EffectValue:",
			platform:GetFullName(),
			effectValue
		)

		return false
	end


	if effectValue <= 0 then
		warn(
			"[OilCourseService] EffectValue must be greater than zero:",
			platform:GetFullName(),
			effectValue
		)

		return false
	end


	--------------------------------------------------
	-- MULTIPLIER
	--
	-- Compatibility attribute.
	--
	-- Normal:
	--     1
	--
	-- X2:
	--     2
	--
	-- X4:
	--     4
	--
	-- /2:
	--     0.5
	--
	-- /4:
	--     0.25
	--------------------------------------------------

	local multiplier = platform:GetAttribute("Multiplier")

	if not isFiniteNumber(multiplier) then
		warn(
			"[OilCourseService] Invalid Multiplier:",
			platform:GetFullName(),
			multiplier
		)

		return false
	end


	if multiplier <= 0 then
		warn(
			"[OilCourseService] Multiplier must be greater than zero:",
			platform:GetFullName(),
			multiplier
		)

		return false
	end


	--------------------------------------------------
	-- DISPLAY
	--------------------------------------------------

	local display = platform:GetAttribute("Display")

	if typeof(display) ~= "string" then
		warn(
			"[OilCourseService] Invalid Display:",
			platform:GetFullName(),
			display
		)

		return false
	end


	--------------------------------------------------
	-- SPECIAL VALIDATION
	--------------------------------------------------

	if effectType == "Multiplier"
		or effectType == "Divider" then

		if display == "" then
			warn(
				"[OilCourseService] Special platform has empty Display:",
				platform:GetFullName()
			)

			return false
		end
	end


	return true
end


--------------------------------------------------
-- FIND PLATFORM
--------------------------------------------------

local function findPlatform(row, name)
	if not row then
		return nil
	end

	local platform = row:FindFirstChild(name, true)

	if not platform then
		warn(
			"[OilCourseService] Missing platform:",
			name,
			"inside:",
			row:GetFullName()
		)

		return nil
	end

	return platform
end


--------------------------------------------------
-- VALIDATE ROW
--------------------------------------------------

local function validateRow(row, expectedRowNumber)
	if not row:IsA("Model")
		and not row:IsA("Folder") then

		warn(
			"[OilCourseService] Invalid row object:",
			row:GetFullName(),
			row.ClassName
		)

		return false
	end


	--------------------------------------------------
	-- ROW NAME
	--------------------------------------------------

	local expectedName = "OilRow_" .. tostring(expectedRowNumber)

	if row.Name ~= expectedName then
		warn(
			"[OilCourseService] Unexpected row name:",
			row.Name,
			"Expected:",
			expectedName
		)

		return false
	end


	--------------------------------------------------
	-- ROW NUMBER
	--------------------------------------------------

	local rowNumber = row:GetAttribute("RowNumber")

	if not isFiniteNumber(rowNumber) then
		warn(
			"[OilCourseService] Row missing valid RowNumber:",
			row:GetFullName(),
			rowNumber
		)

		return false
	end


	local integerRowNumber = getSafeInteger(rowNumber)

	if integerRowNumber == nil then
		warn(
			"[OilCourseService] RowNumber could not be converted:",
			row:GetFullName(),
			rowNumber
		)

		return false
	end


	if integerRowNumber ~= expectedRowNumber then
		warn(
			"[OilCourseService] RowNumber mismatch:",
			row:GetFullName(),
			"Attribute:",
			rowNumber,
			"Expected:",
			expectedRowNumber
		)

		return false
	end


	--------------------------------------------------
	-- OIL COLLECTED
	--------------------------------------------------

	local oilCollected = row:GetAttribute("OilCollected")

	if typeof(oilCollected) ~= "boolean" then
		warn(
			"[OilCourseService] Row missing OilCollected:",
			row:GetFullName()
		)

		return false
	end


	--------------------------------------------------
	-- COLLECTED PLATFORM
	--------------------------------------------------

	local collectedPlatform = row:GetAttribute("CollectedPlatform")

	if typeof(collectedPlatform) ~= "string" then
		warn(
			"[OilCourseService] Row missing CollectedPlatform:",
			row:GetFullName()
		)

		return false
	end


	--------------------------------------------------
	-- LEFT
	--------------------------------------------------

	local left = findPlatform(row, "OilPlatformL")

	if not left then
		return false
	end


	--------------------------------------------------
	-- RIGHT
	--------------------------------------------------

	local right = findPlatform(row, "OilPlatformR")

	if not right then
		return false
	end


	--------------------------------------------------
	-- VALIDATE LEFT
	--------------------------------------------------

	if not validatePlatform(left, row.Name) then
		return false
	end


	--------------------------------------------------
	-- VALIDATE RIGHT
	--------------------------------------------------

	if not validatePlatform(right, row.Name) then
		return false
	end


	--------------------------------------------------
	-- OPTIONAL POLARITY ATTRIBUTES
	--------------------------------------------------

	local leftPositive = row:GetAttribute("LeftPositive")
	local rightPositive = row:GetAttribute("RightPositive")

	if typeof(leftPositive) ~= "boolean" then
		warn(
			"[OilCourseService] Row missing LeftPositive:",
			row:GetFullName()
		)

		return false
	end

	if typeof(rightPositive) ~= "boolean" then
		warn(
			"[OilCourseService] Row missing RightPositive:",
			row:GetFullName()
		)

		return false
	end


	return true
end


--------------------------------------------------
-- VALIDATE PLAYER COURSE
--------------------------------------------------

local function validatePlayerCourse(player, playerCourse)
	if not playerCourse then
		warn("[OilCourseService] No player course returned.")
		return false, 0
	end


	--------------------------------------------------
	-- TYPE
	--------------------------------------------------

	if not playerCourse:IsA("Folder")
		and not playerCourse:IsA("Model") then

		warn(
			"[OilCourseService] Invalid course type:",
			playerCourse.ClassName
		)

		return false, 0
	end


	--------------------------------------------------
	-- LOCATION
	--------------------------------------------------

	if not playerCourse:IsDescendantOf(course) then
		warn(
			"[OilCourseService] Course is not inside Workspace.Course:",
			playerCourse:GetFullName()
		)

		return false, 0
	end


	--------------------------------------------------
	-- NAME
	--------------------------------------------------

	local expectedName = getCourseName(player)

	if playerCourse.Name ~= expectedName then
		warn(
			"[OilCourseService] Invalid course name:",
			playerCourse.Name,
			"Expected:",
			expectedName
		)

		return false, 0
	end


	--------------------------------------------------
	-- PLAYER USER ID
	--------------------------------------------------

	local playerUserId = playerCourse:GetAttribute("PlayerUserId")

	if not isFiniteNumber(playerUserId) then
		warn(
			"[OilCourseService] Course missing valid PlayerUserId:",
			playerCourse:GetFullName(),
			playerUserId
		)

		return false, 0
	end


	local integerPlayerUserId = getSafeInteger(playerUserId)

	if integerPlayerUserId == nil then
		warn(
			"[OilCourseService] Invalid PlayerUserId:",
			playerUserId
		)

		return false, 0
	end


	if integerPlayerUserId ~= player.UserId then
		warn(
			"[OilCourseService] Course PlayerUserId mismatch:",
			playerUserId,
			"Expected:",
			player.UserId
		)

		return false, 0
	end


	--------------------------------------------------
	-- GENERATED
	--------------------------------------------------

	local generated = playerCourse:GetAttribute("Generated")

	if generated ~= true then
		warn(
			"[OilCourseService] Course Generated attribute is not true:",
			playerCourse:GetFullName()
		)

		return false, 0
	end


	--------------------------------------------------
	-- ROW COUNT
	--------------------------------------------------

	local expectedRows = playerCourse:GetAttribute("RowCount")

	if not isFiniteNumber(expectedRows) then
		warn(
			"[OilCourseService] Invalid RowCount:",
			expectedRows
		)

		return false, 0
	end


	local expectedRowsInteger = getSafeInteger(expectedRows)

	if expectedRowsInteger == nil then
		warn(
			"[OilCourseService] RowCount could not be converted:",
			expectedRows
		)

		return false, 0
	end


	if expectedRowsInteger <= 0 then
		warn(
			"[OilCourseService] RowCount must be greater than zero:",
			expectedRowsInteger
		)

		return false, 0
	end


	--------------------------------------------------
	-- SUCCESSFUL ROWS ATTRIBUTE
	--
	-- If present, it must be a valid number.
	--------------------------------------------------

	local successfulRowsAttribute =
		playerCourse:GetAttribute("SuccessfulRows")

	if successfulRowsAttribute ~= nil then
		if not isFiniteNumber(successfulRowsAttribute) then
			warn(
				"[OilCourseService] Invalid SuccessfulRows:",
				successfulRowsAttribute
			)

			return false, 0
		end
	end


	--------------------------------------------------
	-- COUNT ROWS
	--------------------------------------------------

	local rowCount = 0
	local seenRows = {}


	for _, child in ipairs(playerCourse:GetChildren()) do
		local rowNumberText = child.Name:match("^OilRow_(%d+)$")

		if rowNumberText then
			local rowNumber = tonumber(rowNumberText)

			if not isFiniteNumber(rowNumber) then
				warn(
					"[OilCourseService] Invalid row number:",
					child.Name
				)

				return false, rowCount
			end


			local integerRowNumber = getSafeInteger(rowNumber)

			if integerRowNumber == nil then
				warn(
					"[OilCourseService] Could not convert row number:",
					child.Name
				)

				return false, rowCount
			end


			if seenRows[integerRowNumber] then
				warn(
					"[OilCourseService] Duplicate row:",
					integerRowNumber
				)

				return false, rowCount
			end


			seenRows[integerRowNumber] = true


			if not validateRow(
				child,
				integerRowNumber
			) then

				warn(
					"[OilCourseService] Invalid row:",
					child:GetFullName()
				)

				return false, rowCount
			end


			rowCount += 1
		end
	end


	--------------------------------------------------
	-- VERIFY EXPECTED ROWS
	--------------------------------------------------

	for rowNumber = 1, expectedRowsInteger do
		if not seenRows[rowNumber] then
			warn(
				"[OilCourseService] Missing expected row:",
				rowNumber
			)

			return false, rowCount
		end
	end


	--------------------------------------------------
	-- EXACT COUNT
	--------------------------------------------------

	if rowCount ~= expectedRowsInteger then
		warn(
			"[OilCourseService] Row count mismatch:",
			"Actual:",
			rowCount,
			"Expected:",
			expectedRowsInteger
		)

		return false, rowCount
	end


	--------------------------------------------------
	-- SUCCESSFUL ROWS
	--------------------------------------------------

	if successfulRowsAttribute ~= nil then
		local successfulRows = getSafeInteger(successfulRowsAttribute)

		if successfulRows == nil then
			warn(
				"[OilCourseService] SuccessfulRows is invalid:",
				successfulRowsAttribute
			)

			return false, rowCount
		end


		if successfulRows ~= rowCount then
			warn(
				"[OilCourseService] SuccessfulRows mismatch:",
				"Attribute:",
				successfulRows,
				"Actual:",
				rowCount
			)

			return false, rowCount
		end
	end


	--------------------------------------------------
	-- SUCCESS
	--------------------------------------------------

	return true, rowCount
end


--------------------------------------------------
-- REMOVE PLAYER COURSE
--------------------------------------------------

local function removePlayerCourse(player)
	local playerCourse = getPlayerCourse(player)

	if not playerCourse then
		return
	end

	print(
		"[OilCourseService] Removing player course:",
		playerCourse:GetFullName()
	)

	playerCourse:Destroy()
end


--------------------------------------------------
-- GENERATE PLAYER COURSE
--------------------------------------------------

local function generatePlayerCourse(player)
	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

	if not isValidPlayer(player) then
		warn(
			"[OilCourseService] Invalid generation player."
		)

		return nil
	end


	--------------------------------------------------
	-- EXISTING COURSE
	--------------------------------------------------

	local existingCourse = getPlayerCourse(player)

	if existingCourse then
		print(
			"[OilCourseService]",
			player.Name,
			"already has a course:",
			existingCourse:GetFullName()
		)

		return existingCourse
	end


	--------------------------------------------------
	-- LOCK
	--------------------------------------------------

	if generating[player] then
		warn(
			"[OilCourseService]",
			player.Name,
			"course generation already in progress."
		)

		return nil
	end


	generating[player] = true


	print("================================")
	print("[OilCourseService] GENERATING COURSE")
	print("[OilCourseService] Player:", player.Name)
	print("[OilCourseService] UserId:", player.UserId)
	print("================================")


	--------------------------------------------------
	-- CALL GENERATOR
	--------------------------------------------------

	local success, result = pcall(function()
		return OilCourseGenerator.Generate(player)
	end)


	--------------------------------------------------
	-- RELEASE LOCK
	--------------------------------------------------

	generating[player] = nil


	--------------------------------------------------
	-- GENERATOR FAILURE
	--------------------------------------------------

	if not success then
		warn("================================")
		warn("[OilCourseService] GENERATOR ERROR")
		warn("[OilCourseService] Player:", player.Name)
		warn(tostring(result))
		warn("================================")

		return nil
	end


	--------------------------------------------------
	-- PLAYER LEFT
	--------------------------------------------------

	if not player:IsDescendantOf(Players) then
		if result and result.Parent then
			result:Destroy()
		end

		return nil
	end


	--------------------------------------------------
	-- NIL RESULT
	--------------------------------------------------

	if not result then
		warn(
			"[OilCourseService]",
			player.Name,
			"generator returned nil."
		)

		return nil
	end


	--------------------------------------------------
	-- VALIDATE
	--------------------------------------------------

	local valid, rowCount = validatePlayerCourse(
		player,
		result
	)

	if not valid then
		warn("================================")
		warn(
			"[OilCourseService] GENERATED COURSE FAILED VALIDATION"
		)
		warn("[OilCourseService] Player:", player.Name)
		warn("[OilCourseService] Course:", result:GetFullName())
		warn("================================")


		--------------------------------------------------
		-- Destroy corrupt course.
		--------------------------------------------------

		if result.Parent then
			result:Destroy()
		end

		return nil
	end


	--------------------------------------------------
	-- SUCCESSFUL ROWS
	--------------------------------------------------

	local successfulRows =
		result:GetAttribute("SuccessfulRows")

	if successfulRows ~= nil then
		if isFiniteNumber(successfulRows) then
			local successfulRowsInteger =
				getSafeInteger(successfulRows)

			if successfulRowsInteger ~= nil
				and successfulRowsInteger ~= rowCount then

				warn(
					"[OilCourseService] SuccessfulRows mismatch:",
					"Attribute:",
					successfulRowsInteger,
					"Actual:",
					rowCount
				)
			end
		else
			warn(
				"[OilCourseService] SuccessfulRows is not numeric:",
				successfulRows
			)
		end
	end


	--------------------------------------------------
	-- SUCCESS
	--------------------------------------------------

	print("================================")
	print("[OilCourseService] COURSE READY")
	print("[OilCourseService] Player:", player.Name)
	print("[OilCourseService] Course:", result:GetFullName())
	print("[OilCourseService] Rows:", rowCount)
	print("================================")


	return result
end


--------------------------------------------------
-- GENERATE OIL COURSE EVENT
--------------------------------------------------

generateEvent.Event:Connect(function(player)
	print("================================")
	print("[OilCourseService] GenerateOilCourse EVENT RECEIVED")
	print(
		"[OilCourseService] Player:",
		player and player.Name or "NIL"
	)
	print("================================")

	generatePlayerCourse(player)
end)


--------------------------------------------------
-- PLAYER JOIN
--
-- Do not generate here.
--
-- RunController determines when the course
-- should exist.
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	print(
		"[OilCourseService] Player joined:",
		player.Name
	)
end)


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	generating[player] = nil
	removePlayerCourse(player)

	print(
		"[OilCourseService] Player cleanup complete:",
		player.Name
	)
end)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[OilCourseService] READY")
print(
	"[OilCourseService] Generate Event:",
	generateEvent:GetFullName()
)
print(
	"[OilCourseService] Generator:",
	generatorModule:GetFullName()
)
print(
	"[OilCourseService] Course Folder:",
	course:GetFullName()
)
print("================================")