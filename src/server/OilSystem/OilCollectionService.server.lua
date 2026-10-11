--------------------------------------------------
-- OIL COLLECTION SERVICE
--
-- MODULESCRIPT
--
-- LOCATION:
-- ServerScriptService
--     > OilSystem
--         > OilCollectionService
--
-- PURPOSE:
--
-- Authoritative server-side oil accounting.
--
-- OWNS:
-- - Validating oil types
-- - Resolving authoritative oil rewards
-- - Positive oil collection
-- - X2 / X4 multipliers
-- - /2 / /4 penalties
-- - Updating CURRENT RUN oil
-- - Updating persistent oil through PlayerDataService
--
-- DOES NOT OWN:
-- - PlayerAdded
-- - PlayerRemoving
-- - BindToClose
-- - Persistent data lifecycle
-- - Oil platform movement
-- - Ball movement
-- - WinCourse movement
-- - Client reward selection
--
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ServerScriptService =
	game:GetService("ServerScriptService")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local PlayerDataService =
	require(
		ServerScriptService
			:WaitForChild("PlayerDataLoader")
			:WaitForChild("PlayerDataService")
	)


local OilDefinitions =
	require(
		ServerScriptService
			:WaitForChild("OilSystem")
			:WaitForChild("OilDefinitions")
	)


--------------------------------------------------
-- MODULE
--------------------------------------------------

local OilCollectionService = {}


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

-- No artificial oil reward or multiplier caps.
-- Finite-number validation still rejects infinity and NaN.
local MAX_OIL_REWARD = math.huge
local MAX_OIL_PENALTY = math.huge
local MAX_MULTIPLIER_RESULT = math.huge

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
-- VALID PLAYER
--------------------------------------------------

local function isValidPlayer(
	player
)

	return player ~= nil
		and player:IsA("Player")
		and player.Parent == Players

end


--------------------------------------------------
-- GET CURRENT RUN OIL
--------------------------------------------------

local function getCurrentRunOil(
	player
)

	if not isValidPlayer(
		player
	) then

		return 0

	end


	local currentOil =
		player:GetAttribute(
			"CurrentOil"
		)


	if not isFiniteNumber(
		currentOil
	) then

		return 0

	end


	return math.max(
		0,
		math.floor(
			currentOil
		)
	)

end


--------------------------------------------------
-- SET CURRENT RUN OIL
--------------------------------------------------

local function setCurrentRunOil(
	player,
	value
)

	if not isValidPlayer(
		player
	) then

		return false

	end


	if not isFiniteNumber(
		value
	) then

		return false

	end


	value =
		math.max(
			0,
			math.floor(
				value
			)
		)


	player:SetAttribute(
		"CurrentOil",
		value
	)


	return true

end


--------------------------------------------------
-- GET OIL DEFINITION
--------------------------------------------------

local function getDefinition(
	oilType
)

	if typeof(oilType) ~= "string" then

		return nil

	end


	if oilType == "" then

		return nil

	end


	local definition =
		OilDefinitions[oilType]


	if typeof(definition) ~= "table" then

		return nil

	end


	return definition

end


--------------------------------------------------
-- IS MULTIPLIER
--------------------------------------------------

local function isMultiplierDefinition(
	definition
)

	if typeof(definition) ~= "table" then

		return false

	end


	return isFiniteNumber(
		definition.Multiplier
	)
		and definition.Multiplier > 0

end


--------------------------------------------------
-- IS DIVISOR
--------------------------------------------------

local function isDividerDefinition(
	definition
)

	if typeof(definition) ~= "table" then

		return false

	end


	return isFiniteNumber(
		definition.Divider
	)
		and definition.Divider > 0

end


--------------------------------------------------
-- GET NORMAL OIL AMOUNT
--
-- Only normal rarities use:
--
-- MinOil
-- MaxOil
--
-- The server performs the random roll here.
--------------------------------------------------

local function getNormalOilAmount(
	definition
)

	if typeof(definition) ~= "table" then

		return nil

	end


	local minOil =
		definition.MinOil


	local maxOil =
		definition.MaxOil


	if not isFiniteNumber(
		minOil
	)
		or not isFiniteNumber(
		maxOil
	) then

		return nil

	end


	minOil =
		math.floor(
			minOil
		)


	maxOil =
		math.floor(
			maxOil
		)


	if minOil <= 0
		or maxOil <= 0 then

		return nil

	end


	if maxOil < minOil then

		return nil

	end


	if maxOil > MAX_OIL_REWARD then

		return nil

	end


	return math.random(
		minOil,
		maxOil
	)

end


--------------------------------------------------
-- GET OIL AMOUNT
--
-- NORMAL RARITIES ONLY
--
-- Returns a newly generated positive reward.
--
-- X2 / X4 / /2 / /4 do NOT use this function
-- because they operate on CurrentOil.
--------------------------------------------------

local function getOilAmount(
	oilType
)

	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return nil

	end


	--------------------------------------------------
	-- SPECIAL RARITIES ARE NOT NORMAL OIL
	--------------------------------------------------

	if isMultiplierDefinition(
		definition
	)
		or isDividerDefinition(
			definition
		) then

		return nil

	end


	return getNormalOilAmount(
		definition
	)

end


--------------------------------------------------
-- CALCULATE SPECIAL OIL RESULT
--
-- Returns:
--
-- newCurrentOil
--
-- based on existing CurrentOil.
--
-- X2:
--     CurrentOil * 2
--
-- X4:
--     CurrentOil * 4
--
-- Divide2:
--     CurrentOil / 2
--
-- Divide4:
--     CurrentOil / 4
--------------------------------------------------

local function calculateSpecialOil(
	currentOil,
	definition
)

	if not isFiniteNumber(
		currentOil
	) then

		return nil

	end


	if typeof(definition) ~= "table" then

		return nil

	end


	currentOil =
		math.max(
			0,
			math.floor(
				currentOil
			)
		)


	--------------------------------------------------
	-- MULTIPLIER
	--------------------------------------------------

	if isMultiplierDefinition(
		definition
	) then

		local multiplier =
			definition.Multiplier


		if multiplier <= 0 then

			return nil

		end


		local newOil =
			currentOil
			*
			multiplier


		if not isFiniteNumber(
			newOil
		) then

			return nil

		end


		if newOil >
			MAX_MULTIPLIER_RESULT then

			return nil

		end


		return math.max(
			0,
			math.floor(
				newOil
			)
		)

	end


	--------------------------------------------------
	-- DIVIDER
	--------------------------------------------------

	if isDividerDefinition(
		definition
	) then

		local divider =
			definition.Divider


		if divider <= 0 then

			return nil

		end


		local newOil =
			currentOil
			/
			divider


		if not isFiniteNumber(
			newOil
		) then

			return nil

		end


		return math.max(
			0,
			math.floor(
				newOil
			)
		)

	end


	return nil

end


--------------------------------------------------
-- GET SPECIAL OIL CHANGE
--
-- Returns the DIFFERENCE between:
--
--     old CurrentOil
--
-- and:
--
--     new CurrentOil
--
-- This is important because persistent Oil
-- should only change by the actual amount gained
-- or lost.
--------------------------------------------------

local function getSpecialOilChange(
	currentOil,
	definition
)

	local newOil =
		calculateSpecialOil(
			currentOil,
			definition
		)


	if newOil == nil then

		return nil

	end


	local change =
		newOil
		-
		currentOil


	if not isFiniteNumber(
		change
	) then

		return nil

	end


	change =
		math.floor(
			change
		)


	return change

end


--------------------------------------------------
-- GET SIGNED OIL CHANGE
--
-- Used for explicitly defined signed oil types.
--
-- NOTE:
--
-- Normal rarity definitions do not contain "Oil".
-- This remains here for compatibility with any
-- existing negative oil definitions that may use:
--
-- Oil = -500
--------------------------------------------------

local function getOilChangeAmount(
	oilType
)

	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return nil

	end


	--------------------------------------------------
	-- SPECIAL RARITIES
	--------------------------------------------------

	if isMultiplierDefinition(
		definition
	)
		or isDividerDefinition(
			definition
		) then

		return nil

	end


	--------------------------------------------------
	-- LEGACY SIGNED OIL
	--------------------------------------------------

	local amount =
		definition.Oil


	if not isFiniteNumber(
		amount
	) then

		return nil

	end


	if amount == 0 then

		return nil

	end


	amount =
		math.floor(
			amount
		)


	if amount == 0 then

		return nil

	end


	--------------------------------------------------
	-- POSITIVE
	--------------------------------------------------

	if amount > 0 then

		if amount >
			MAX_OIL_REWARD then

			return nil

		end


		return amount

	end


	--------------------------------------------------
	-- NEGATIVE
	--------------------------------------------------

	local penalty =
		math.abs(
			amount
		)


	if penalty >
		MAX_OIL_PENALTY then

		return nil

	end


	penalty =
		math.floor(
			penalty
		)


	if penalty <= 0 then

		return nil

	end


	return -penalty

end


--------------------------------------------------
-- APPLY PERSISTENT OIL
--------------------------------------------------

local function applyPersistentOilChange(
	player,
	change
)

	if not isFiniteNumber(
		change
	)
		or change == 0 then

		return false

	end


	--------------------------------------------------
	-- POSITIVE
	--------------------------------------------------

	if change > 0 then

		if typeof(
			PlayerDataService.AddOil
		) ~= "function" then

			warn(
				"[OilCollectionService]",
				"PlayerDataService.AddOil() is missing."
			)

			return false

		end


		return PlayerDataService.AddOil(
			player,
			change
		)

	end


	--------------------------------------------------
	-- NEGATIVE
	--------------------------------------------------

	if change < 0 then

		if typeof(
			PlayerDataService.RemoveOil
		) ~= "function" then

			warn(
				"[OilCollectionService]",
				"PlayerDataService.RemoveOil() is missing."
			)

			return false

		end


		return PlayerDataService.RemoveOil(
			player,
			math.abs(
				change
			)
		)

	end


	return false

end


--------------------------------------------------
-- APPLY CURRENT RUN OIL CHANGE
--------------------------------------------------

local function applyCurrentRunOilChange(
	player,
	change,
	countAsCollection
)

	local currentOil =
		getCurrentRunOil(
			player
		)


	local newOil =
		math.max(
			0,
			currentOil + change
		)


	if not setCurrentRunOil(
		player,
		newOil
	) then

		return false

	end


	--------------------------------------------------
	-- COLLECTION COUNT
	--
	-- Only positive normal oil collection and
	-- positive special results count as a collection.
	--------------------------------------------------

	if countAsCollection == true then

		local count =
			player:GetAttribute(
				"CollectedOilCount"
			)


		if not isFiniteNumber(
			count
		)
			or count < 0 then

			count = 0

		end


		player:SetAttribute(
			"CollectedOilCount",
			math.floor(
				count
			) + 1
		)

	end


	return true

end


--------------------------------------------------
-- APPLY OIL CHANGE
--
-- AUTHORITATIVE SERVER ACCOUNTING
--
-- Positive oil:
--     Adds to CurrentOil and persistent Oil.
--
-- Negative oil:
--     Subtracts from CurrentOil, never below 0.
--     Persistent Oil changes only by the actual
--     amount removed from CurrentOil.
--
-- Collection count:
--     Only increments when countAsCollection
--     is true and oil is actually gained.
--------------------------------------------------

local function applyOilChange(
    player,
    change,
    countAsCollection
)
    --------------------------------------------------
    -- VALIDATE PLAYER
    --------------------------------------------------

    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end

    --------------------------------------------------
    -- VALIDATE CHANGE
    --------------------------------------------------

    if not isFiniteNumber(change) or change == 0 then
        return false, "INVALID_OIL_CHANGE"
    end

    change = math.floor(change)

    if change == 0 then
        return false, "INVALID_OIL_CHANGE"
    end

    --------------------------------------------------
    -- GET CURRENT RUN OIL
    --------------------------------------------------

    local beforeOil = getCurrentRunOil(player)

    --------------------------------------------------
    -- CALCULATE ACTUAL CHANGE
    --
    -- Clamp the result to zero so negative oil
    -- can never make CurrentOil negative.
    --------------------------------------------------

    local afterOil = math.max(0, beforeOil + change)

    local actualChange = afterOil - beforeOil

    --------------------------------------------------
    -- NOTHING TO CHANGE
    --------------------------------------------------

    if actualChange == 0 then
        return true, "NO_OIL_CHANGE"
    end

    --------------------------------------------------
    -- UPDATE PERSISTENT OIL
    --
    -- Only apply the amount that actually changed.
    --
    -- Example:
    -- CurrentOil = 100
    -- Platform = -500
    -- Actual change = -100
    --
    -- Persistent Oil is reduced by 100, not 500.
    --------------------------------------------------

    local persistentSuccess = applyPersistentOilChange(
        player,
        actualChange
    )

    if not persistentSuccess then
        return false, "FAILED_TO_UPDATE_PERSISTENT_OIL"
    end

    --------------------------------------------------
    -- UPDATE CURRENT RUN OIL
    --------------------------------------------------

    local currentRunSuccess = setCurrentRunOil(
        player,
        afterOil
    )

    if not currentRunSuccess then
        warn(
            "[OilCollectionService]",
            "Persistent oil changed but CurrentOil failed:",
            player.Name,
            "ActualChange:",
            actualChange
        )

        return false, "FAILED_TO_UPDATE_CURRENT_OIL"
    end

    --------------------------------------------------
    -- COLLECTION COUNT
    --
    -- Count only actual positive collection events.
    -- Negative platforms and penalties do not count.
    --------------------------------------------------

    if countAsCollection == true and actualChange > 0 then
        local count = player:GetAttribute("CollectedOilCount")

        if not isFiniteNumber(count) or count < 0 then
            count = 0
        end

        player:SetAttribute(
            "CollectedOilCount",
            math.floor(count) + 1
        )
    end

    --------------------------------------------------
    -- AUDIT
    --------------------------------------------------

    print(
        "[OilCollectionService]",
        "OIL CHANGE:",
        player.Name,
        "| Requested:", change,
        "| Actual:", actualChange,
        "| Before:", beforeOil,
        "| After:", afterOil,
        "| Persistent Updated:", persistentSuccess
    )

    return true, actualChange
end


--------------------------------------------------
-- COLLECT OIL
--
-- Uses the exact server-generated platform amount
-- when a platform is provided.
--
-- Special multipliers/dividers continue to use
-- CurrentOil through the existing accounting.
--------------------------------------------------

function OilCollectionService.CollectOil(
    player,
    oilType,
    platform
)
    if not isValidPlayer(player) then
        return false, "INVALID_PLAYER"
    end

    local definition = getDefinition(oilType)

    if not definition then
        return false, "INVALID_OIL_TYPE"
    end

    --------------------------------------------------
    -- MULTIPLIERS AND DIVIDERS
    --------------------------------------------------

    if isMultiplierDefinition(definition)
        or isDividerDefinition(definition) then

        local currentOil = getCurrentRunOil(player)

        local change = getSpecialOilChange(
            currentOil,
            definition
        )

        if change == nil then
            return false, "INVALID_SPECIAL_OIL_TYPE"
        end

        if change == 0 then
            return false, "NO_OIL_CHANGE"
        end

        if math.abs(change) > MAX_MULTIPLIER_RESULT then
            return false, "OIL_CHANGE_TOO_LARGE"
        end

        local beforeOil = getCurrentRunOil(player)

        local success, result = applyOilChange(
            player,
            change,
            change > 0
        )

        print(
            "[OilCollectionService AUDIT]",
            player.Name,
            "| Type:", oilType,
            "| Award:", change,
            "| Before:", beforeOil,
            "| After:", getCurrentRunOil(player),
            "| Success:", success,
            "| Result:", result
        )

        return success, result
    end

    --------------------------------------------------
    -- DETERMINE NORMAL OIL AMOUNT
    --------------------------------------------------

    local amount

    if platform ~= nil then
        if not platform:IsA("BasePart")
            and not platform:IsA("Model") then
            return false, "INVALID_PLATFORM"
        end

        if platform:GetAttribute("OilType") ~= oilType then
            return false, "OIL_TYPE_MISMATCH"
        end

        local platformAmount = platform:GetAttribute("OilAmount")

        if not isFiniteNumber(platformAmount)
    or platformAmount == 0
    or math.abs(platformAmount) > MAX_OIL_REWARD then
    return false, "INVALID_PLATFORM_AMOUNT"
end

        amount = math.floor(platformAmount)
    else
        amount = getNormalOilAmount(definition)

        if amount == nil then
            return false, "INVALID_OIL_TYPE"
        end
    end

    --------------------------------------------------
    -- APPLY AND AUDIT
    --------------------------------------------------

    local beforeOil = getCurrentRunOil(player)

    local success, result = applyOilChange(
        player,
        amount,
        amount > 0
    )

    print(
        "[OilCollectionService AUDIT]",
        player.Name,
        "| Type:", oilType,
        "| Platform:", platform and platform:GetFullName() or "LEGACY",
        "| Award:", amount,
        "| Before:", beforeOil,
        "| After:", getCurrentRunOil(player),
        "| Success:", success,
        "| Result:", result
    )

    return success, result
end

--------------------------------------------------
-- SERVER-TO-SERVER COLLECTION BRIDGE
--------------------------------------------------

local collectionBridge =
	script.Parent:WaitForChild("CollectOilRequest")

assert(
	collectionBridge:IsA("BindableFunction"),
	"[OilCollectionService] CollectOilRequest must be a BindableFunction."
)

collectionBridge.OnInvoke = function(player, oilType, platform)
	return OilCollectionService.CollectOil(
		player,
		oilType,
		platform
	)
end

print(
	"[OilCollectionService]",
	"CollectOilRequest bridge connected."
)

--------------------------------------------------
-- REMOVE OIL
--
-- Supports:
--
-- /2
-- /4
--
-- and legacy negative Oil definitions.
--------------------------------------------------

function OilCollectionService.RemoveOil(
	player,
	oilType
)

	if not isValidPlayer(
		player
	) then

		return false,
			"INVALID_PLAYER"

	end


	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return false,
			"INVALID_OIL_TYPE"

	end


	--------------------------------------------------
	-- DIVISOR
	--------------------------------------------------

	if isDividerDefinition(
		definition
	) then

		local currentOil =
			getCurrentRunOil(
				player
			)


		local change =
			getSpecialOilChange(
				currentOil,
				definition
			)


		if change == nil then

			return false,
				"INVALID_DIVISOR"

		end


		if change >= 0 then

			return false,
				"NOT_A_NEGATIVE_OIL_TYPE"

		end


		print(
			"[OilCollectionService]",
			"OIL DIVISION:",
			player.Name,
			oilType,
			"Before:",
			currentOil,
			"Change:",
			change,
			"After:",
			currentOil + change
		)


		return applyOilChange(
			player,
			change,
			false
		)

	end


	--------------------------------------------------
	-- LEGACY NEGATIVE OIL
	--------------------------------------------------

	local change =
		getOilChangeAmount(
			oilType
		)


	if not change then

		return false,
			"INVALID_OIL_PENALTY"

	end


	if change >= 0 then

		return false,
			"NOT_A_NEGATIVE_OIL_TYPE"

	end


	return applyOilChange(
		player,
		change,
		false
	)

end


--------------------------------------------------
-- SERVER-ONLY SIGNED CHANGE
--------------------------------------------------

function OilCollectionService.ApplyOilChange(
	player,
	change
)

	return applyOilChange(
		player,
		change,
		change > 0
	)

end


--------------------------------------------------
-- GET CURRENT RUN OIL
--------------------------------------------------

function OilCollectionService.GetCurrentOil(
	player
)

	return getCurrentRunOil(
		player
	)

end


--------------------------------------------------
-- RESET CURRENT RUN OIL
--------------------------------------------------

function OilCollectionService.ResetCurrentOil(
	player
)

	if not isValidPlayer(
		player
	) then

		return false

	end


	player:SetAttribute(
		"CurrentOil",
		0
	)


	player:SetAttribute(
		"CollectedOilCount",
		0
	)


	print(
		"[OilCollectionService]",
		player.Name,
		"CURRENT RUN OIL RESET"
	)


	return true

end


--------------------------------------------------
-- GET NORMAL OIL AMOUNT
--------------------------------------------------

function OilCollectionService.GetOilAmount(
	oilType
)

	return getOilAmount(
		oilType
	)

end


--------------------------------------------------
-- GET SIGNED OIL CHANGE
--------------------------------------------------

function OilCollectionService.GetOilChangeAmount(
	oilType
)

	return getOilChangeAmount(
		oilType
	)

end


--------------------------------------------------
-- GET OIL DEFINITION
--------------------------------------------------

function OilCollectionService.GetOilDefinition(
	oilType
)

	return getDefinition(
		oilType
	)

end


--------------------------------------------------
-- CALCULATE SPECIAL RESULT
--
-- Server-side helper.
--
-- Returns the result of applying the special
-- rarity to the player's CURRENT oil amount.
--------------------------------------------------

function OilCollectionService.CalculateSpecialOil(
	player,
	oilType
)

	if not isValidPlayer(
		player
	) then

		return nil

	end


	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return nil

	end


	if not isMultiplierDefinition(
		definition
	)
		and not isDividerDefinition(
			definition
		) then

		return nil

	end


	return calculateSpecialOil(
		getCurrentRunOil(
			player
		),
		definition
	)

end


--------------------------------------------------
-- VALID POSITIVE OIL
--
-- Normal positive oil OR multiplier rarity.
--------------------------------------------------

function OilCollectionService.IsValidOilType(
	oilType
)

	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return false

	end


	if isMultiplierDefinition(
		definition
	) then

		return true

	end


	if isDividerDefinition(
		definition
	) then

		return false

	end


	return getOilAmount(
		oilType
	) ~= nil

end


--------------------------------------------------
-- VALID NEGATIVE OIL
--
-- Divisor rarity OR legacy negative Oil.
--------------------------------------------------

function OilCollectionService.IsValidOilPenalty(
	oilType
)

	local definition =
		getDefinition(
			oilType
		)


	if not definition then

		return false

	end


	if isDividerDefinition(
		definition
	) then

		return true

	end


	local change =
		getOilChangeAmount(
			oilType
		)


	return change ~= nil
		and change < 0

end


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")

print(
	"[OilCollectionService]",
	"MODULE LOADED"
)

print(
	"[OilCollectionService]",
	"OilDefinitions = SERVER ONLY"
)

print(
	"[OilCollectionService]",
	"Normal oil = SERVER AUTHORITATIVE"
)

print(
	"[OilCollectionService]",
	"X2 = CURRENT OIL x2"
)

print(
	"[OilCollectionService]",
	"X4 = CURRENT OIL x4"
)

print(
	"[OilCollectionService]",
	"/2 = CURRENT OIL /2"
)

print(
	"[OilCollectionService]",
	"/4 = CURRENT OIL /4"
)

print(
	"[OilCollectionService]",
	"CurrentOil = CURRENT RUN ACCUMULATOR"
)

print(
	"[OilCollectionService]",
	"CurrentOil minimum = 0"
)

print(
	"[OilCollectionService]",
	"Persistent Oil follows ACTUAL CURRENT OIL CHANGE"
)

print(
	"[OilCollectionService]",
	"Client oil amounts = REJECTED"
)

print("================================")

--------------------------------------------------
-- RETURN MODULE
--------------------------------------------------

return OilCollectionService