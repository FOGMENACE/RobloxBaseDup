--------------------------------------------------
-- OIL COURSE GENERATOR
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > OilCourseGenerator
--
-- PURPOSE:
--
-- Generates the authoritative oil course for each
-- player.
--
-- COMPATIBLE WITH:
--
-- Normal definitions:
--     MinOil
--     MaxOil
--     Weight
--
-- Special definitions:
--     Multiplier
--     Divider
--
-- Optional:
--     Kind
--     Display
--
-- SUPPORTED SPECIAL EFFECTS:
--
--     X2
--     X4
--     /2
--     /4
--
-- IMPORTANT:
--
-- This generator NEVER awards Oil.
-- OilCollectionService owns collection/rewards.
--
-- Special platforms have OilAmount = 0.
-- OilCollectionService must apply the effect to
-- the player's CURRENT collectedOil total.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")


--------------------------------------------------
-- MODULE
--------------------------------------------------

local OilCourseGenerator = {}


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates = ServerStorage:WaitForChild("Templates")
local oilRowTemplate = templates:WaitForChild("OilRow")

local oilSystem = ServerScriptService:WaitForChild("OilSystem")
local oilDefinitionsModule = oilSystem:WaitForChild("OilDefinitions")
local OilDefinitions = require(oilDefinitionsModule)

local course = workspace:WaitForChild("Course")


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local NUMBER_OF_ROWS = 12
local ROW_SPACING = 42
local PLATFORM_SEPARATION = 5

local START_POSITION = Vector3.new(
	-64.718,
	67.994,
	-154.612
)


--------------------------------------------------
-- POLARITY
--------------------------------------------------

local POSITIVE_CHANCE = 0.45
local NEGATIVE_CHANCE = 0.55


--------------------------------------------------
-- RNG
--------------------------------------------------

local rng = Random.new()


--------------------------------------------------
-- COLORS
--------------------------------------------------

local POSITIVE_COLOR = Color3.fromRGB(40, 222, 72)
local NEGATIVE_COLOR = Color3.fromRGB(236, 42, 52)


--------------------------------------------------
-- OIL TYPES
--------------------------------------------------

local OIL_TYPES = {}


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
-- BUILD OIL TYPE LIST
--------------------------------------------------

local function buildOilTypeList()
	table.clear(OIL_TYPES)

	for oilType, definition in pairs(OilDefinitions) do
		if typeof(oilType) == "string" and typeof(definition) == "table" then
			table.insert(OIL_TYPES, oilType)
		end
	end

	table.sort(OIL_TYPES, function(a, b)
		return a < b
	end)

	if #OIL_TYPES == 0 then
		error("[OilCourseGenerator] OilDefinitions contains no valid oil types.")
	end
end


--------------------------------------------------
-- GET DEFINITION KIND
--
-- Supports:
--
-- NEW:
--     Kind = "Normal"
--     Kind = "Multiplier"
--     Kind = "Divider"
--
-- LEGACY:
--     MinOil / MaxOil = Normal
--     Multiplier = Multiplier
--     Divider = Divider
--------------------------------------------------

local function getDefinitionKind(definition)
	if typeof(definition) ~= "table" then
		return nil
	end

	if definition.Kind ~= nil then
		if definition.Kind == "Normal"
			or definition.Kind == "Multiplier"
			or definition.Kind == "Divider" then
			return definition.Kind
		end

		return nil
	end

	if definition.Multiplier ~= nil then
		return "Multiplier"
	end

	if definition.Divider ~= nil then
		return "Divider"
	end

	if definition.MinOil ~= nil or definition.MaxOil ~= nil then
		return "Normal"
	end

	return nil
end


--------------------------------------------------
-- GET DISPLAY
--------------------------------------------------

local function getDisplay(oilType, definition, kind)
	if typeof(definition.Display) == "string" and definition.Display ~= "" then
		return definition.Display
	end

	if kind == "Multiplier" then
		if definition.Multiplier == 2 then
			return "X2"
		end

		if definition.Multiplier == 4 then
			return "X4"
		end

		if isFiniteNumber(definition.Multiplier) then
			return "X" .. tostring(definition.Multiplier)
		end
	end

	if kind == "Divider" then
		if definition.Divider == 2 then
			return "/2"
		end

		if definition.Divider == 4 then
			return "/4"
		end

		if isFiniteNumber(definition.Divider) then
			return "/" .. tostring(definition.Divider)
		end
	end

	return oilType
end


--------------------------------------------------
-- GET EFFECT VALUE
--------------------------------------------------

local function getEffectValue(definition, kind)
	if kind == "Multiplier" then
		return definition.Multiplier
	end

	if kind == "Divider" then
		return definition.Divider
	end

	return 1
end


--------------------------------------------------
-- GET COMPATIBILITY MULTIPLIER
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

local function getCompatibilityMultiplier(definition, kind)
	if kind == "Multiplier" then
		return definition.Multiplier
	end

	if kind == "Divider" then
		return 1 / definition.Divider
	end

	return 1
end


--------------------------------------------------
-- VALIDATE ONE OIL DEFINITION
--------------------------------------------------

local function validateOilDefinition(oilType, definition)
	if typeof(definition) ~= "table" then
		warn("[OilCourseGenerator] Invalid OilDefinition:", oilType)
		return false
	end

	if not isFiniteNumber(definition.Weight) then
		warn("[OilCourseGenerator] Invalid Weight:", oilType)
		return false
	end

	if definition.Weight <= 0 then
		warn("[OilCourseGenerator] Weight must be greater than 0:", oilType)
		return false
	end

	local kind = getDefinitionKind(definition)

if not kind then
    warn(
        "[OilCourseGenerator] Could not determine definition kind:",
        oilType
    )
    return false
end

	if kind == "Normal" then
		if not isFiniteNumber(definition.MinOil) then
			warn("[OilCourseGenerator] Normal oil missing MinOil:", oilType)
			return false
		end

		if not isFiniteNumber(definition.MaxOil) then
			warn("[OilCourseGenerator] Normal oil missing MaxOil:", oilType)
			return false
		end

		if definition.MinOil <= 0 then
			warn("[OilCourseGenerator] MinOil must be greater than 0:", oilType)
			return false
		end

		if definition.MaxOil < definition.MinOil then
			warn("[OilCourseGenerator] MaxOil cannot be less than MinOil:", oilType)
			return false
		end
	end

	if kind == "Multiplier" then
		if not isFiniteNumber(definition.Multiplier) then
			warn("[OilCourseGenerator] Invalid Multiplier:", oilType)
			return false
		end

		if definition.Multiplier <= 0 then
			warn("[OilCourseGenerator] Multiplier must be greater than 0:", oilType)
			return false
		end
	end

	if kind == "Divider" then
		if not isFiniteNumber(definition.Divider) then
			warn("[OilCourseGenerator] Invalid Divider:", oilType)
			return false
		end

		if definition.Divider <= 0 then
			warn("[OilCourseGenerator] Divider must be greater than 0:", oilType)
			return false
		end
	end

	if definition.Display ~= nil and typeof(definition.Display) ~= "string" then
		warn("[OilCourseGenerator] Invalid Display:", oilType)
		return false
	end

	return true
end


--------------------------------------------------
-- VALIDATE ALL DEFINITIONS
--------------------------------------------------

local function validateOilDefinitions()
	if typeof(OilDefinitions) ~= "table" then
		error("[OilCourseGenerator] OilDefinitions must return a table.")
	end

	local totalWeight = 0

	for _, oilType in ipairs(OIL_TYPES) do
		local definition = OilDefinitions[oilType]

		if not validateOilDefinition(oilType, definition) then
			error("[OilCourseGenerator] Missing or invalid oil type: " .. tostring(oilType))
		end

		totalWeight += definition.Weight
	end

	if totalWeight <= 0 then
		error("[OilCourseGenerator] Total oil rarity weight must be greater than 0.")
	end

	return totalWeight
end


--------------------------------------------------
-- VALIDATE PLAYER
--------------------------------------------------

local function isValidPlayer(player)
	return player ~= nil
		and player:IsA("Player")
		and player:IsDescendantOf(Players)
end


--------------------------------------------------
-- COURSE NAME
--------------------------------------------------

local function getCourseName(player)
	return "PlayerCourse_" .. tostring(player.UserId)
end


--------------------------------------------------
-- FIND PLATFORM
--------------------------------------------------

local function findPlatform(oilRow, name)
	if not oilRow then
		return nil
	end

	local platform = oilRow:FindFirstChild(name, true)

	if not platform then
		warn(
			"[OilCourseGenerator] Missing platform:",
			name,
			"inside",
			oilRow:GetFullName()
		)

		return nil
	end

	if not platform:IsA("BasePart") and not platform:IsA("Model") then
		warn(
			"[OilCourseGenerator] Invalid platform type:",
			platform:GetFullName(),
			platform.ClassName
		)

		return nil
	end

	return platform
end


--------------------------------------------------
-- GET PLATFORM PARTS
--------------------------------------------------

local function getPlatformParts(platform)
	local parts = {}

	if not platform then
		return parts
	end

	if platform:IsA("BasePart") then
		table.insert(parts, platform)
		return parts
	end

	if platform:IsA("Model") then
		for _, object in ipairs(platform:GetDescendants()) do
			if object:IsA("BasePart") then
				table.insert(parts, object)
			end
		end
	end

	return parts
end


--------------------------------------------------
-- GET PLATFORM CFRAME
--------------------------------------------------

local function getPlatformCFrame(platform)
	if platform:IsA("BasePart") then
		return platform.CFrame
	end

	if platform:IsA("Model") then
		return platform:GetPivot()
	end

	return nil
end


--------------------------------------------------
-- OFFSET PLATFORM X
--------------------------------------------------

local function offsetPlatformX(platform, offsetX)
	local currentCFrame = getPlatformCFrame(platform)

	if not currentCFrame then
		return false
	end

	local targetCFrame = currentCFrame + Vector3.new(offsetX, 0, 0)

	if platform:IsA("BasePart") then
		platform.CFrame = targetCFrame
	elseif platform:IsA("Model") then
		platform:PivotTo(targetCFrame)
	else
		return false
	end

	return true
end


--------------------------------------------------
-- SPACE PLATFORMS
--------------------------------------------------

local function spacePlatforms(left, right)
	local leftCFrame = getPlatformCFrame(left)
	local rightCFrame = getPlatformCFrame(right)

	if not leftCFrame or not rightCFrame then
		return false
	end

	local leftX = leftCFrame.Position.X
	local rightX = rightCFrame.Position.X

	local currentDistance = math.abs(rightX - leftX)

	if currentDistance >= PLATFORM_SEPARATION then
		return true
	end

	local midpointX = (leftX + rightX) / 2
	local halfSeparation = PLATFORM_SEPARATION / 2

	local leftTargetX = midpointX - halfSeparation
	local rightTargetX = midpointX + halfSeparation

	local leftOffset = leftTargetX - leftX
	local rightOffset = rightTargetX - rightX

	if not offsetPlatformX(left, leftOffset) then
		return false
	end

	if not offsetPlatformX(right, rightOffset) then
		return false
	end

	return true
end


--------------------------------------------------
-- FIND EXISTING OIL LABEL
--------------------------------------------------

local function findOilLabel(platform)
	if not platform then
		return nil
	end

	local namedLabel = platform:FindFirstChild("OilAmount", true)

	if namedLabel and namedLabel:IsA("TextLabel") then
		return namedLabel
	end

	for _, object in ipairs(platform:GetDescendants()) do
		if object:IsA("TextLabel") then
			local surfaceGui = object:FindFirstAncestorOfClass("SurfaceGui")

			if surfaceGui then
				return object
			end
		end
	end

	return nil
end


--------------------------------------------------
-- CONFIGURE OIL LABEL
--------------------------------------------------

local function configureOilLabel(platform, oilType, definition, amount)
	local label = findOilLabel(platform)

	if not label then
		warn(
			"[OilCourseGenerator] No existing oil label:",
			platform:GetFullName()
		)

		return false
	end

	local kind = getDefinitionKind(definition)

	if kind == "Multiplier" or kind == "Divider" then
		label.Text = getDisplay(oilType, definition, kind)
		return true
	end

	local displayAmount = math.floor(math.abs(amount))

	if amount >= 0 then
		label.Text = "+" .. tostring(displayAmount)
	else
		label.Text = "-" .. tostring(displayAmount)
	end

	-- rare tiers get their own colour so a big one is spotted at a glance
	if typeof(definition.LabelColor) == "Color3" then
		label.TextColor3 = definition.LabelColor
	end

	return true
end


--------------------------------------------------
-- CONFIGURE PLATFORM VISUALS
--------------------------------------------------

local function configurePlatformVisuals(platform, isPositive)
	local color = if isPositive then POSITIVE_COLOR else NEGATIVE_COLOR
	local parts = getPlatformParts(platform)

	if #parts == 0 then
		warn(
			"[OilCourseGenerator] Platform has no BaseParts:",
			platform:GetFullName()
		)

		return false
	end

	for _, part in ipairs(parts) do
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0.3
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = true
		part.CanQuery = true
	end

	return true
end


--------------------------------------------------
-- CHOOSE OIL TYPE BASED ON PLATFORM POLARITY
--------------------------------------------------

-- MIXED DIFFICULTY: each course rolls how many X2/X4 (helpers) and /2 /4
-- (hurters) it may contain, so a course is never wall-to-wall x4 or all
-- dividers. BallTierGates also reads "MultiplierPlatforms" to give fewer
-- upgrade platforms to a course that is already generous.
local helperCap, hurtCap = 1, 1
local helperUsed, hurtUsed = 0, 0

local function rollCap(weights)
	local roll = rng:NextNumber() * 100
	local acc = 0
	for count = 0, #weights do
		acc += weights[count]
		if roll <= acc then
			return count
		end
	end
	return 0
end

local function rollSpecialCaps()
	helperCap = rollCap({ [0] = 30, 45, 25 })
	hurtCap = rollCap({ [0] = 25, 45, 30 })
	helperUsed, hurtUsed = 0, 0
end

-- DIFFICULTY (0..1, reaches 1 at rebirth 40): the better a platform tier is, the
-- harder it is to GET as rebirths rise. Good (green) Rare / Epic / Legendary get
-- rarer, the same tiers on the red side get more common, and fewer rows are
-- green/green. Sizes are unchanged; only how often the big ones can be caught.
local difficulty = 0
local TIER_HARDNESS = { Rare = 0.3, Epic = 0.6, Legendary = 0.7 }

local function chooseOilType(isPositive)
	local eligibleTypes = {}
	local totalWeight = 0

	for _, oilType in ipairs(OIL_TYPES) do
		local definition = OilDefinitions[oilType]

		if definition then
			local kind = getDefinitionKind(definition)

			local eligible = false

			if kind == "Normal" then
				eligible = isPositive == true or definition.PositiveOnly ~= true

			elseif kind == "Multiplier" then
				eligible = isPositive == true

			elseif kind == "Divider" then
				eligible = isPositive == false
			end

			if kind == "Multiplier" and helperUsed >= helperCap then
				eligible = false
			elseif kind == "Divider" and hurtUsed >= hurtCap then
				eligible = false
			end

			if eligible
				and isFiniteNumber(definition.Weight)
				and definition.Weight > 0 then

				local weight = definition.Weight
				local hardness = kind == "Normal" and TIER_HARDNESS[oilType]
				if hardness then
					if isPositive then
						-- good Rare / Epic / Legendary get a bit rarer as rebirths rise
						weight *= (1 - hardness * difficulty * 0.5)
					elseif oilType ~= "Rare" then
						-- big RED panels (-2k and worse) are the rarest of all and no longer
						-- get more common with rebirths
						weight *= 0.75
					end
				end

				table.insert(eligibleTypes, {
					Name = oilType,
					Weight = weight,
				})

				totalWeight += weight
			end
		end
	end

	if totalWeight <= 0 then
		warn(
			"[OilCourseGenerator] No eligible oil types for polarity:",
			isPositive and "POSITIVE" or "NEGATIVE"
		)

		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local accumulated = 0

	for _, entry in ipairs(eligibleTypes) do
		accumulated += entry.Weight

		if roll <= accumulated then
			local chosen = OilDefinitions[entry.Name]
			local chosenKind = chosen and getDefinitionKind(chosen)
			if chosenKind == "Multiplier" then helperUsed += 1 elseif chosenKind == "Divider" then hurtUsed += 1 end
			return entry.Name
		end
	end

	return eligibleTypes[#eligibleTypes].Name
end


--------------------------------------------------
-- ROLL NORMAL OIL
--------------------------------------------------

-- Digits scale with the player's rebirths (a new player sees small numbers,
-- a high-rebirth player bigger ones) and every course also rolls its own
-- "luck" so rounds are not all equally rich. Server-side only; the
-- collection service still reads the amount stored on the platform.
local oilScale = 1

local function computeOilScale(player)
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
	local base = math.clamp(0.3 + rebirths * 0.07, 0.3, 1.6)

	local roll = rng:NextNumber()
	local luck
	if roll < 0.25 then
		luck = 0.6 -- lean round
	elseif roll < 0.6 then
		luck = 0.85
	elseif roll < 0.9 then
		luck = 1.15
	else
		luck = 1.5 -- jackpot round
	end

	return base * luck
end

local function rollOilAmount(definition)
	local kind = getDefinitionKind(definition)

	if kind ~= "Normal" then
		return 0
	end

	local minimum = math.floor(definition.MinOil)
	local maximum = math.floor(definition.MaxOil)

	local amount = math.max(20, math.floor(rng:NextInteger(minimum, maximum) * oilScale + 0.5))
	-- 2,000+ panels (green or red) stay special: only the Epic / Legendary tiers
	-- can reach them, so high rebirths and lucky rounds do not turn ordinary
	-- panels into 2k+ ones
	if amount >= 2000 and minimum < 1500 then
		amount = 1900 + rng:NextInteger(0, 90)
	end
	return amount
end


--------------------------------------------------
-- BUILD POLARITY PLAN
--
-- Uses a randomized course-wide budget.
--
-- This keeps the complete course close to:
--
--     45% positive
--     55% negative
--
-- while still allowing:
--
--     + / +
--     + / -
--     - / +
--     - / -
--------------------------------------------------

local function buildPolarityPlan(platformCount)
	local plan = {}

	if platformCount <= 0 then
		return plan
	end

	local rowCount = math.floor(platformCount / 2)

	-- Row types:
	-- 1 = green / green
	-- 2 = green / red
	-- 3 = red / red

	-- Balanced so an average course nets positive oil: high-rebirth players used to
	-- get ~45% green with larger red tiers and ended on 0 oil far too often.
	local doubleGreenRows = math.floor(rowCount * (0.20 - 0.04 * difficulty))
	local doubleRedRows = math.floor(rowCount * (0.10 + 0.04 * difficulty))

	local mixedRows = rowCount - doubleGreenRows - doubleRedRows

	-- Build paired outcomes.
	for _ = 1, doubleGreenRows do
		table.insert(plan, true)
		table.insert(plan, true)
	end

	for _ = 1, mixedRows do
		table.insert(plan, true)
		table.insert(plan, false)
	end

	for _ = 1, doubleRedRows do
		table.insert(plan, false)
		table.insert(plan, false)
	end

	-- Shuffle the order of individual platforms.
	for index = #plan, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		plan[index], plan[swapIndex] =
			plan[swapIndex], plan[index]
	end

	return plan
end


--------------------------------------------------
-- SETUP ONE PLATFORM
--------------------------------------------------

local function setupPlatform(platform, isPositive)
	if not platform then
		return false
	end

	-- Select a type compatible with the intended polarity.
	local oilType = chooseOilType(isPositive)

	if not oilType then
		return false
	end

	local definition = OilDefinitions[oilType]

	if not validateOilDefinition(oilType, definition) then
		return false
	end

	local kind = getDefinitionKind(definition)

	--------------------------------------------------
	-- ENFORCE SPECIAL PLATFORM POLARITY
	--------------------------------------------------

	if kind == "Multiplier" then
		isPositive = true

	elseif kind == "Divider" then
		isPositive = false
	end

	--------------------------------------------------
	-- ROLL NORMAL OIL
	--------------------------------------------------

	local oilAmount = rollOilAmount(definition)
	if oilAmount > 0 and not isPositive then
		oilAmount = math.max(20, math.floor(oilAmount * 0.8 + 0.5)) -- red panels bite, but a little less than green pays
	end

	if kind == "Normal" and not isPositive then
		-- reds used to scale up to x1.55 with rebirths on top of everything else, which
		-- pushed most runs to 0 oil; they now just subtract their (already trimmed) amount
		oilAmount = -oilAmount
	end

	--------------------------------------------------
	-- SPECIAL EFFECTS DO NOT USE A RANDOM AMOUNT
	--------------------------------------------------

	if kind == "Multiplier" or kind == "Divider" then
		oilAmount = 0
	end

	--------------------------------------------------
	-- AUTHORITATIVE ATTRIBUTES
	--------------------------------------------------

	platform:SetAttribute("OilType", oilType)
	platform:SetAttribute("OilAmount", oilAmount)
	platform:SetAttribute("Positive", isPositive)
	platform:SetAttribute("Collected", false)

	platform:SetAttribute("OilEffectType", kind)
	platform:SetAttribute("Kind", kind)

	--------------------------------------------------
	-- DISPLAY
	--------------------------------------------------

	local display = getDisplay(oilType, definition, kind)

	platform:SetAttribute("Display", display)

	--------------------------------------------------
	-- EFFECT VALUE
	--------------------------------------------------

	platform:SetAttribute(
		"EffectValue",
		getEffectValue(definition, kind)
	)

	platform:SetAttribute(
		"Multiplier",
		getCompatibilityMultiplier(definition, kind)
	)

	--------------------------------------------------
	-- SPECIAL FLAGS
	--------------------------------------------------

	local isSpecial = kind == "Multiplier"
		or kind == "Divider"

	platform:SetAttribute("IsSpecial", isSpecial)
	platform:SetAttribute("IsMultiplier", kind == "Multiplier")
	platform:SetAttribute("IsDivider", kind == "Divider")

	--------------------------------------------------
	-- VISUALS
	--------------------------------------------------

	if not configurePlatformVisuals(platform, isPositive) then
		return false
	end

	--------------------------------------------------
	-- LABEL
	--------------------------------------------------

	if not configureOilLabel(
		platform,
		oilType,
		definition,
		oilAmount
	) then
		return false
	end

	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"[OilCourseGenerator] Platform configured:",
		platform:GetFullName(),
		"| Type:", oilType,
		"| Kind:", kind,
		"| Polarity:", isPositive and "POSITIVE/GREEN" or "NEGATIVE/RED",
		"| Amount:", oilAmount,
		"| Display:", display
	)

	return true
end


--------------------------------------------------
-- RESET ROW PHYSICS
--------------------------------------------------

local function resetRowPhysics(oilRow)
	for _, object in ipairs(oilRow:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = true
			object.CanQuery = true
		end
	end
end


--------------------------------------------------
-- CONFIGURE ROW
--------------------------------------------------

local function configureRow(
	oilRow,
	rowNumber,
	leftPositive,
	rightPositive
)
	local left = findPlatform(oilRow, "OilPlatformL")
	local right = findPlatform(oilRow, "OilPlatformR")

	if not left or not right then
		return false
	end

	--------------------------------------------------
	-- SPACE PLATFORMS
	--------------------------------------------------

	if not spacePlatforms(left, right) then
		warn(
			"[OilCourseGenerator] Failed to space platforms in row:",
			rowNumber
		)

		return false
	end

	--------------------------------------------------
	-- CONFIGURE LEFT
	--------------------------------------------------

	local leftOK = setupPlatform(left, leftPositive)

	--------------------------------------------------
	-- CONFIGURE RIGHT
	--------------------------------------------------

	local rightOK = setupPlatform(right, rightPositive)

	if not leftOK or not rightOK then
		return false
	end

	--------------------------------------------------
-- ROW ATTRIBUTES: STORE ACTUAL PLATFORM POLARITY
--------------------------------------------------

oilRow:SetAttribute("RowNumber", rowNumber)
oilRow:SetAttribute("OilCollected", false)
oilRow:SetAttribute("CollectedPlatform", "")

oilRow:SetAttribute(
	"LeftPositive",
	left:GetAttribute("Positive") == true
)

oilRow:SetAttribute(
	"RightPositive",
	right:GetAttribute("Positive") == true
)

return true
end


--------------------------------------------------
-- POSITION ROW
--------------------------------------------------

-- offset: the player's world (WorldConfig) - every world has its own course
local function positionRow(oilRow, rowNumber, offset)
	offset = offset or Vector3.zero
	local rowZ = START_POSITION.Z + offset.Z + ((rowNumber - 1) * ROW_SPACING)

	local currentPivot = oilRow:GetPivot()
	local rotation = currentPivot - currentPivot.Position

	local targetCFrame = CFrame.new(
		START_POSITION.X + offset.X,
		START_POSITION.Y + offset.Y,
		rowZ
	) * rotation

	oilRow:PivotTo(targetCFrame)
end


--------------------------------------------------
-- REMOVE PLAYER COURSE
--------------------------------------------------

local function removePlayerCourse(player)
	local courseName = getCourseName(player)
	local oldCourse = course:FindFirstChild(courseName)

	if oldCourse then
		oldCourse:Destroy()
	end
end


--------------------------------------------------
-- COUNT COURSE POLARITIES
--------------------------------------------------

local function countCoursePolarities(playerCourse)
	local positiveCount = 0
	local negativeCount = 0

	for _, oilRow in ipairs(playerCourse:GetChildren()) do
		local left = findPlatform(oilRow, "OilPlatformL")
		local right = findPlatform(oilRow, "OilPlatformR")

		if left then
			if left:GetAttribute("Positive") == true then
				positiveCount += 1
			else
				negativeCount += 1
			end
		end

		if right then
			if right:GetAttribute("Positive") == true then
				positiveCount += 1
			else
				negativeCount += 1
			end
		end
	end

	return positiveCount, negativeCount
end


--------------------------------------------------
-- GENERATE
--------------------------------------------------

function OilCourseGenerator.Generate(player)
	if not isValidPlayer(player) then
		warn("[OilCourseGenerator] Generate() received invalid player.")
		return nil
	end

	--------------------------------------------------
	-- REMOVE OLD COURSE
	--------------------------------------------------

	removePlayerCourse(player)

	--------------------------------------------------
	-- CREATE COURSE
	--------------------------------------------------

	local playerCourse = Instance.new("Folder")
	playerCourse.Name = getCourseName(player)

	--------------------------------------------------
	-- COURSE ATTRIBUTES
	--------------------------------------------------

	playerCourse:SetAttribute("PlayerUserId", player.UserId)
	playerCourse:SetAttribute("Generated", true)
	playerCourse:SetAttribute("RowCount", NUMBER_OF_ROWS)
	playerCourse:SetAttribute("SuccessfulRows", 0)
	playerCourse:SetAttribute("OilCollected", false)
	playerCourse:SetAttribute("RowSpacing", ROW_SPACING)
	playerCourse:SetAttribute("PlatformSeparation", PLATFORM_SEPARATION)
	playerCourse:SetAttribute("PositiveChance", POSITIVE_CHANCE)
	playerCourse:SetAttribute("NegativeChance", NEGATIVE_CHANCE)

	oilScale = computeOilScale(player)
	-- starts at 0.25 for a brand-new player and reaches 1 at rebirth 25 (was 0 -> 1 at 40)
	difficulty = math.clamp(0.25 + ((tonumber(player:GetAttribute("Rebirths")) or 0) / 25) * 0.75, 0, 1)
	rollSpecialCaps()
	playerCourse:SetAttribute("OilScale", oilScale)
	playerCourse:SetAttribute("PositivePlatforms", 0)
	playerCourse:SetAttribute("NegativePlatforms", 0)

	--------------------------------------------------
	-- TOTAL PLATFORM COUNT
	--------------------------------------------------

	local totalPlatforms = NUMBER_OF_ROWS * 2

	--------------------------------------------------
	-- BUILD COURSE-WIDE POLARITY PLAN
	--------------------------------------------------

	local polarityPlan = buildPolarityPlan(totalPlatforms)
	local polarityIndex = 1
	local successfulRows = 0

	--------------------------------------------------
	-- GENERATE ROWS
	--------------------------------------------------

	for rowNumber = 1, NUMBER_OF_ROWS do
		local oilRow = oilRowTemplate:Clone()

		oilRow.Name = "OilRow_" .. tostring(rowNumber)

		--------------------------------------------------
		-- POSITION
		--------------------------------------------------

		positionRow(oilRow, rowNumber, require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig")).Offset(player))

		--------------------------------------------------
		-- PHYSICS
		--------------------------------------------------

		resetRowPhysics(oilRow)

		--------------------------------------------------
		-- POLARITY
		--------------------------------------------------

		local leftPositive = polarityPlan[polarityIndex]
		local rightPositive = polarityPlan[polarityIndex + 1]

		polarityIndex += 2

		--------------------------------------------------
		-- SAFETY FALLBACK
		--------------------------------------------------

		if leftPositive == nil then
			leftPositive = false
		end

		if rightPositive == nil then
			rightPositive = false
		end

		--------------------------------------------------
		-- CONFIGURE
		--------------------------------------------------

		local success = configureRow(
			oilRow,
			rowNumber,
			leftPositive,
			rightPositive
		)

		if not success then
			warn(
				"[OilCourseGenerator] Row failed:",
				rowNumber
			)

			oilRow:Destroy()
			continue
		end

		--------------------------------------------------
		-- PARENT AFTER SUCCESS
		--------------------------------------------------

		oilRow.Parent = playerCourse
		successfulRows += 1
	end

	--------------------------------------------------
	-- FINALIZE COURSE
	--------------------------------------------------

	playerCourse:SetAttribute(
		"SuccessfulRows",
		successfulRows
	)

	--------------------------------------------------
	-- PARENT COURSE
	--------------------------------------------------

	playerCourse.Parent = course

	--------------------------------------------------
	-- COUNT POLARITIES
	--------------------------------------------------

	local positiveCount, negativeCount = countCoursePolarities(playerCourse)
	playerCourse:SetAttribute("MultiplierPlatforms", helperUsed)
	playerCourse:SetAttribute("DividerPlatforms", hurtUsed)

	playerCourse:SetAttribute(
		"PositivePlatforms",
		positiveCount
	)

	playerCourse:SetAttribute(
		"NegativePlatforms",
		negativeCount
	)

	--------------------------------------------------
	-- VALIDATION
	--------------------------------------------------

	if successfulRows <= 0 then
		warn(
			"[OilCourseGenerator] Course generated with ZERO valid rows:",
			player.Name
		)
	end

	--------------------------------------------------
	-- DEBUG OUTPUT
	--------------------------------------------------

	print(
		"[OilCourseGenerator]",
		"Generated course:",
		player.Name,
		"| Rows:",
		successfulRows,
		"/",
		NUMBER_OF_ROWS,
		"| Positive:",
		positiveCount,
		"| Negative:",
		negativeCount
	)

	return playerCourse
end


--------------------------------------------------
-- REMOVE COURSE
--
-- Optional public helper.
--------------------------------------------------

function OilCourseGenerator.Remove(player)
	if not isValidPlayer(player) then
		return false
	end

	removePlayerCourse(player)
	return true
end


--------------------------------------------------
-- GET PLAYER COURSE
--
-- Optional public helper.
--------------------------------------------------

function OilCourseGenerator.GetCourse(player)
	if not isValidPlayer(player) then
		return nil
	end

	return course:FindFirstChild(getCourseName(player))
end


--------------------------------------------------
-- STARTUP VALIDATION
--------------------------------------------------

buildOilTypeList()
validateOilDefinitions()


--------------------------------------------------
-- READY
--------------------------------------------------

print("[OilCourseGenerator] SERVER READY")

print(
	"[OilCourseGenerator]",
	"OilDefinitions:",
	"ServerScriptService.OilSystem.OilDefinitions"
)

print(
	"[OilCourseGenerator]",
	"Rows:",
	NUMBER_OF_ROWS
)

print(
	"[OilCourseGenerator]",
	"Row spacing:",
	ROW_SPACING
)

print(
	"[OilCourseGenerator]",
	"Platform separation:",
	PLATFORM_SEPARATION
)

print(
	"[OilCourseGenerator]",
	"Positive chance:",
	POSITIVE_CHANCE
)

print(
	"[OilCourseGenerator]",
	"Negative chance:",
	NEGATIVE_CHANCE
)

print(
	"[OilCourseGenerator]",
	"Oil rarities:",
	table.concat(OIL_TYPES, ", ")
)


--------------------------------------------------
-- REQUIRED MODULE RETURN
--------------------------------------------------

return OilCourseGenerator