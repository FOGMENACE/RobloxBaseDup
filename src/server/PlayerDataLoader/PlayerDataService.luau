--------------------------------------------------
-- PLAYER DATA SERVICE
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > PlayerDataLoader
--         > PlayerDataService
--------------------------------------------------

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")


--------------------------------------------------
-- MODULE
--------------------------------------------------

local PlayerDataService = {}


--------------------------------------------------
-- BALL DEFINITIONS
--------------------------------------------------

local BallDefinitions = require(
	ServerScriptService:WaitForChild("BallDefinitions")
)


--------------------------------------------------
-- DATASTORE
--------------------------------------------------

local DATASTORE_NAME = "PlayerData_v1"

local playerDataStore = DataStoreService:GetDataStore(
	DATASTORE_NAME
)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local AUTOSAVE_INTERVAL = 60

local SAVE_TIMEOUT = 20

local MAX_XP = 1e15

local MAX_LEVEL = 1000000

local MAX_WINS = 1e15

local MAX_REBIRTHS = 1000000

local MAX_OIL = 1e9

local MAX_BALL_NAME_LENGTH = 64


--------------------------------------------------
-- XP SETTINGS
--------------------------------------------------

local BASE_XP_PER_LEVEL = 100

local XP_LEVEL_GROWTH = 1.35


--------------------------------------------------
-- BALL SETTINGS
--------------------------------------------------

local DEFAULT_BALL_ID = "StraightBall"


--------------------------------------------------
-- DEFAULT DATA
--------------------------------------------------

local DEFAULT_DATA = {
	XP = 0,
	Level = 1,
	Wins = 0,
	Rebirths = 0,
	CurrentOil = 0,

	OwnedBalls = {
		[DEFAULT_BALL_ID] = true,
	},

	EquippedBall = DEFAULT_BALL_ID,
}


--------------------------------------------------
-- SERVER MEMORY
--------------------------------------------------

local loadedData = {}

local saving = {}

local saveRequested = {}

local shuttingDown = false


--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function isFiniteNumber(value)

	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge

end


--------------------------------------------------
-- COPY OWNED BALLS
--------------------------------------------------

local function copyOwnedBalls(ownedBalls)

	local copy = {}

	if typeof(ownedBalls) ~= "table" then
		return copy
	end

	for ballId, owned in pairs(ownedBalls) do

		if typeof(ballId) == "string"
			and owned == true then

			copy[ballId] = true

		end

	end

	return copy

end


--------------------------------------------------
-- COPY DATA
--------------------------------------------------

local function copyData(data)

	local copy = {}

	if typeof(data) ~= "table" then
		return copy
	end

	for key, value in pairs(data) do

		if key == "OwnedBalls"
			and typeof(value) == "table" then

			copy.OwnedBalls = copyOwnedBalls(value)

		else

			copy[key] = value

		end

	end

	return copy

end


--------------------------------------------------
-- VALID BALL ID
--------------------------------------------------

local function isValidBallId(ballId)

	if typeof(ballId) ~= "string"
		or ballId == ""
		or #ballId > MAX_BALL_NAME_LENGTH then

		return false

	end

	local definition = BallDefinitions[ballId]

	if typeof(definition) ~= "table" then
		return false
	end

	return true

end


--------------------------------------------------
-- GET BALL DEFINITION
--------------------------------------------------

local function getBallDefinition(ballId)

	if not isValidBallId(ballId) then
		return nil
	end

	return BallDefinitions[ballId]

end


--------------------------------------------------
-- VALIDATE BALL DEFINITION
--------------------------------------------------

local function validateBallDefinition(
	ballId,
	definition
)

	if typeof(ballId) ~= "string"
		or not isValidBallId(ballId) then

		return false, "INVALID_BALL_ID"

	end

	if typeof(definition) ~= "table" then
		return false, "INVALID_DEFINITION"
	end

	if not isFiniteNumber(definition.ForwardSpeed) then
		return false, "INVALID_FORWARD_SPEED"
	end

	if definition.ForwardSpeed < 0 then
		return false, "NEGATIVE_FORWARD_SPEED"
	end

	if not isFiniteNumber(definition.HorizontalSpeed) then
		return false, "INVALID_HORIZONTAL_SPEED"
	end

	if definition.HorizontalSpeed < 0 then
		return false, "NEGATIVE_HORIZONTAL_SPEED"
	end

	if definition.WinsCost ~= nil then

		if not isFiniteNumber(definition.WinsCost) then
			return false, "INVALID_WINS_COST"
		end

		if definition.WinsCost < 0 then
			return false, "NEGATIVE_WINS_COST"
		end

	end

	if definition.RequiredRebirths ~= nil then

		if not isFiniteNumber(definition.RequiredRebirths) then
			return false, "INVALID_REQUIRED_REBIRTHS"
		end

		if definition.RequiredRebirths < 0 then
			return false, "NEGATIVE_REQUIRED_REBIRTHS"
		end

	end

	if definition.DeveloperProductId ~= nil then

		if not isFiniteNumber(definition.DeveloperProductId) then
			return false, "INVALID_DEVELOPER_PRODUCT_ID"
		end

		if definition.DeveloperProductId < 0 then
			return false, "NEGATIVE_DEVELOPER_PRODUCT_ID"
		end

		if definition.DeveloperProductId % 1 ~= 0 then
			return false, "NON_INTEGER_DEVELOPER_PRODUCT_ID"
		end

	end

	if definition.DisplayOrder ~= nil then

		if not isFiniteNumber(definition.DisplayOrder) then
			return false, "INVALID_DISPLAY_ORDER"
		end

	end

	return true, "VALID"

end


--------------------------------------------------
-- VALIDATE DEFAULT BALL
--------------------------------------------------

do

	local defaultDefinition = getBallDefinition(
		DEFAULT_BALL_ID
	)

	if not defaultDefinition then

		error(
			"[PlayerDataService] DEFAULT_BALL_ID does not exist in BallDefinitions: "
				.. DEFAULT_BALL_ID
		)

	end

	local valid, reason = validateBallDefinition(
		DEFAULT_BALL_ID,
		defaultDefinition
	)

	if not valid then

		error(
			"[PlayerDataService] Invalid default ball definition: "
				.. DEFAULT_BALL_ID
				.. " | "
				.. reason
		)

	end

	if defaultDefinition.DeveloperProductId ~= nil
		and defaultDefinition.DeveloperProductId ~= 0 then

		error(
			"[PlayerDataService] StraightBall cannot have a DeveloperProductId."
		)

	end

end


--------------------------------------------------
-- XP REQUIRED FOR LEVEL
--------------------------------------------------

local function getXPRequiredForLevel(level)

	if not isFiniteNumber(level) then
		level = 1
	end

	level = math.clamp(
		math.floor(level),
		1,
		MAX_LEVEL
	)

	return BASE_XP_PER_LEVEL
		* (
			XP_LEVEL_GROWTH ^ (level - 1)
		)

end


--------------------------------------------------
-- TOTAL XP REQUIRED TO REACH LEVEL
--------------------------------------------------

local function getTotalXPForLevel(level)

	if not isFiniteNumber(level) then
		return 0
	end

	level = math.max(
		1,
		math.floor(level)
	)

	if level <= 1 then
		return 0
	end

	return BASE_XP_PER_LEVEL
		* (
			(
				XP_LEVEL_GROWTH ^ (level - 1)
			) - 1
		)
		/
		(
			XP_LEVEL_GROWTH - 1
		)

end


--------------------------------------------------
-- CALCULATE LEVEL FROM XP
--------------------------------------------------

local function calculateLevelFromXP(xp)

	if not isFiniteNumber(xp)
		or xp <= 0 then

		return 1

	end

	xp = math.clamp(
		xp,
		0,
		MAX_XP
	)

	local inside =
		(
			xp
			* (XP_LEVEL_GROWTH - 1)
			/ BASE_XP_PER_LEVEL
		)
		+ 1

	if inside <= 1 then
		return 1
	end

	local level = math.floor(
		1
			+ (
				math.log(inside)
				/ math.log(XP_LEVEL_GROWTH)
			)
	)

	level = math.clamp(
		level,
		1,
		MAX_LEVEL
	)

	while level > 1
		and xp < getTotalXPForLevel(level) do

		level -= 1

	end

	while level < MAX_LEVEL
		and xp >= getTotalXPForLevel(level + 1) do

		level += 1

	end

	return level

end


--------------------------------------------------
-- XP PROGRESS
--------------------------------------------------

local function getXPProgress(xp)

	if not isFiniteNumber(xp) then
		xp = 0
	end

	xp = math.clamp(
		xp,
		0,
		MAX_XP
	)

	local level = calculateLevelFromXP(xp)

	local currentLevelXP =
		getTotalXPForLevel(level)

	local nextLevelXP =
		getTotalXPForLevel(level + 1)

	local xpIntoLevel =
		math.max(
			0,
			xp - currentLevelXP
		)

	local xpNeededForLevel =
		math.max(
			0,
			nextLevelXP - currentLevelXP
		)

	local progress = 0

	if xpNeededForLevel > 0 then

		progress =
			xpIntoLevel
			/
			xpNeededForLevel

	end

	return {
		Level = level,

		CurrentLevelXP = currentLevelXP,

		NextLevelXP = nextLevelXP,

		XPIntoLevel = xpIntoLevel,

		XPNeededForLevel = xpNeededForLevel,

		Progress = math.clamp(
			progress,
			0,
			1
		),
	}

end


--------------------------------------------------
-- SANITIZE NUMBER
--------------------------------------------------

local function sanitizeNumber(
	value,
	defaultValue,
	maximum
)

	if not isFiniteNumber(value) then
		return defaultValue
	end

	if value < 0 then
		return defaultValue
	end

	return math.min(
		value,
		maximum
	)

end


--------------------------------------------------
-- SANITIZE OWNED BALLS
--------------------------------------------------

local function sanitizeOwnedBalls(value)

	local ownedBalls = {}

	if typeof(value) == "table" then

		for ballId, owned in pairs(value) do

			if typeof(ballId) == "string"
				and ballId ~= ""
				and #ballId <= MAX_BALL_NAME_LENGTH
				and owned == true
				and isValidBallId(ballId) then

				local definition =
					getBallDefinition(ballId)

				local valid =
					validateBallDefinition(
						ballId,
						definition
					)

				if valid then
					ownedBalls[ballId] = true
				end

			end

		end

	end

	ownedBalls[DEFAULT_BALL_ID] = true

	return ownedBalls

end


--------------------------------------------------
-- SANITIZE DATA
--------------------------------------------------

local function sanitizeData(data)

	if typeof(data) ~= "table" then
		data = {}
	end

	local sanitized = {

		XP = sanitizeNumber(
			data.XP,
			DEFAULT_DATA.XP,
			MAX_XP
		),

		Level = 1,

		Wins = sanitizeNumber(
			data.Wins,
			DEFAULT_DATA.Wins,
			MAX_WINS
		),

		Rebirths = sanitizeNumber(
			data.Rebirths,
			DEFAULT_DATA.Rebirths,
			MAX_REBIRTHS
		),

		CurrentOil = sanitizeNumber(
			data.CurrentOil,
			DEFAULT_DATA.CurrentOil,
			MAX_OIL
		),

		OwnedBalls = sanitizeOwnedBalls(
			data.OwnedBalls
		),

		EquippedBall = DEFAULT_BALL_ID,
	}

	sanitized.Wins = math.floor(
		sanitized.Wins
	)

	sanitized.Rebirths = math.floor(
		sanitized.Rebirths
	)

	sanitized.Level = calculateLevelFromXP(
		sanitized.XP
	)

	if typeof(data.EquippedBall) == "string"
		and data.EquippedBall ~= ""
		and #data.EquippedBall <= MAX_BALL_NAME_LENGTH
		and isValidBallId(data.EquippedBall)
		and sanitized.OwnedBalls[data.EquippedBall] == true then

		local definition =
			getBallDefinition(
				data.EquippedBall
			)

		local valid =
			validateBallDefinition(
				data.EquippedBall,
				definition
			)

		if valid then

			sanitized.EquippedBall =
				data.EquippedBall

		end

	end

	if sanitized.OwnedBalls[
		sanitized.EquippedBall
	] ~= true then

		sanitized.EquippedBall =
			DEFAULT_BALL_ID

	end

	return sanitized

end


--------------------------------------------------
-- DATA KEY
--------------------------------------------------

local function getDataKey(player)

	return "Player_" .. tostring(
		player.UserId
	)

end


--------------------------------------------------
-- LOAD DATA
--------------------------------------------------

local function loadData(player)

	if shuttingDown then
		return nil
	end

	if loadedData[player] then
		return loadedData[player]
	end

	local key = getDataKey(player)

	local success, result = pcall(
		function()
			return playerDataStore:GetAsync(key)
		end
	)

	if not success then

		warn(
			"[PlayerDataService]",
			"Failed to load:",
			player.Name,
			result
		)

		return nil

	end

	local data = sanitizeData(result)

	loadedData[player] = data

	return data

end


--------------------------------------------------
-- CREATE LEADERSTATS
--------------------------------------------------

local function createLeaderstats(
	player,
	data
)

	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then

		leaderstats =
			Instance.new("Folder")

		leaderstats.Name =
			"leaderstats"

		leaderstats.Parent =
			player

	end

	local rebirths =
		leaderstats:FindFirstChild("Rebirths")

	if not rebirths then

		rebirths =
			Instance.new("IntValue")

		rebirths.Name =
			"Rebirths"

		rebirths.Parent =
			leaderstats

	end

	local wins =
		leaderstats:FindFirstChild("Wins")

	if not wins then

		wins =
			Instance.new("IntValue")

		wins.Name =
			"Wins"

		wins.Parent =
			leaderstats

	end

	local level =
		leaderstats:FindFirstChild("Level")

	if not level then

		level =
			Instance.new("IntValue")

		level.Name =
			"Level"

		level.Parent =
			leaderstats

	end

	rebirths.Value = data.Rebirths
	wins.Value = data.Wins
	level.Value = data.Level

end


--------------------------------------------------
-- UPDATE PLAYER VALUES
--------------------------------------------------

local function updatePlayerValues(
	player,
	data
)

	data.Level =
		calculateLevelFromXP(
			data.XP
		)

	local progress =
		getXPProgress(
			data.XP
		)

	player:SetAttribute(
		"XP",
		data.XP
	)

	player:SetAttribute(
		"Level",
		data.Level
	)

	player:SetAttribute(
		"Wins",
		data.Wins
	)

	player:SetAttribute(
		"Rebirths",
		data.Rebirths
	)

	player:SetAttribute(
		"CurrentOil",
		data.CurrentOil
	)

	player:SetAttribute(
		"EquippedBall",
		data.EquippedBall
	)

	player:SetAttribute(
		"XPForCurrentLevel",
		progress.CurrentLevelXP
	)

	player:SetAttribute(
		"XPForNextLevel",
		progress.NextLevelXP
	)

	player:SetAttribute(
		"XPIntoLevel",
		progress.XPIntoLevel
	)

	player:SetAttribute(
		"XPNeededForLevel",
		progress.XPNeededForLevel
	)

	player:SetAttribute(
		"LevelProgress",
		progress.Progress
	)

	local leaderstats =
		player:FindFirstChild("leaderstats")

	if not leaderstats then
		return
	end

	local level =
		leaderstats:FindFirstChild("Level")

	if level then
		level.Value = data.Level
	end

	local wins =
		leaderstats:FindFirstChild("Wins")

	if wins then
		wins.Value = data.Wins
	end

	local rebirths =
		leaderstats:FindFirstChild("Rebirths")

	if rebirths then
		rebirths.Value = data.Rebirths
	end

end


--------------------------------------------------
-- LOAD PLAYER
--------------------------------------------------

function PlayerDataService.LoadPlayer(player)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if shuttingDown then
		return false
	end

	if loadedData[player] then
		return true
	end

	local data = loadData(player)

	if not data then
		return false
	end

	data.OwnedBalls[DEFAULT_BALL_ID] = true

	if typeof(data.EquippedBall) ~= "string"
		or data.EquippedBall == ""
		or not isValidBallId(data.EquippedBall)
		or data.OwnedBalls[data.EquippedBall] ~= true then

		data.EquippedBall =
			DEFAULT_BALL_ID

	end

	data.Level =
		calculateLevelFromXP(
			data.XP
		)

	createLeaderstats(
		player,
		data
	)

	updatePlayerValues(
		player,
		data
	)

	print(
		"[PlayerDataService]",
		"Loaded:",
		player.Name,
		"| XP:",
		data.XP,
		"| Level:",
		data.Level,
		"| Wins:",
		data.Wins,
		"| Rebirths:",
		data.Rebirths,
		"| Oil:",
		data.CurrentOil,
		"| EquippedBall:",
		data.EquippedBall
	)

	return true

end


--------------------------------------------------
-- GET DATA
--------------------------------------------------

function PlayerDataService.GetData(player)

	local data =
		loadedData[player]

	if not data then
		return nil
	end

	return copyData(data)

end


--------------------------------------------------
-- GET XP
--------------------------------------------------

function PlayerDataService.GetXP(player)

	local data =
		loadedData[player]

	if not data then
		return 0
	end

	return data.XP

end


--------------------------------------------------
-- GET WINS
--------------------------------------------------

function PlayerDataService.GetWins(player)

	local data =
		loadedData[player]

	if not data then
		return 0
	end

	return data.Wins

end


--------------------------------------------------
-- GET REBIRTHS
--------------------------------------------------

function PlayerDataService.GetRebirths(player)

	local data =
		loadedData[player]

	if not data then
		return 0
	end

	return data.Rebirths

end


--------------------------------------------------
-- GET OIL
--------------------------------------------------

function PlayerDataService.GetOil(player)

	local data =
		loadedData[player]

	if not data then
		return 0
	end

	return math.max(
		0,
		data.CurrentOil
	)

end


--------------------------------------------------
-- XP GETTERS
--------------------------------------------------

function PlayerDataService.GetXPRequiredForLevel(
	level
)

	return getXPRequiredForLevel(level)

end


function PlayerDataService.GetTotalXPForLevel(
	level
)

	return getTotalXPForLevel(level)

end


function PlayerDataService.GetXPProgress(player)

	local data =
		loadedData[player]

	if not data then
		return nil
	end

	return getXPProgress(
		data.XP
	)

end


--------------------------------------------------
-- ADD XP
--------------------------------------------------

function PlayerDataService.AddXP(
	player,
	amount
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isFiniteNumber(amount)
		or amount <= 0 then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	amount =
		math.floor(amount)

	if amount <= 0 then
		return false
	end

	data.XP =
		math.min(
			data.XP + amount,
			MAX_XP
		)

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- ADD WINS
--------------------------------------------------

function PlayerDataService.AddWins(
	player,
	amount
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isFiniteNumber(amount)
		or amount <= 0 then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	amount =
		math.floor(amount)

	if amount <= 0 then
		return false
	end

	data.Wins =
		math.min(
			data.Wins + amount,
			MAX_WINS
		)

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- REMOVE WINS
--------------------------------------------------

function PlayerDataService.RemoveWins(
	player,
	amount
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isFiniteNumber(amount)
		or amount <= 0 then

		return false

	end

	amount =
		math.floor(amount)

	if amount <= 0 then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	if data.Wins < amount then
		return false
	end

	data.Wins -= amount

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- DEFAULT BALL
--------------------------------------------------

function PlayerDataService.GetDefaultBallId()

	return DEFAULT_BALL_ID

end


--------------------------------------------------
-- BALL DEFINITION
--------------------------------------------------

function PlayerDataService.GetBallDefinition(
	ballId
)

	local definition =
		getBallDefinition(ballId)

	if not definition then
		return nil
	end

	local copy = {}

	for key, value in pairs(definition) do
		copy[key] = value
	end

	return copy

end


--------------------------------------------------
-- VALID BALL
--------------------------------------------------

function PlayerDataService.IsValidBallId(
	ballId
)

	return isValidBallId(ballId)

end


--------------------------------------------------
-- OWNED BALLS
--------------------------------------------------

function PlayerDataService.GetOwnedBalls(
	player
)

	local data =
		loadedData[player]

	if not data then
		return {}
	end

	return copyOwnedBalls(
		data.OwnedBalls
	)

end


--------------------------------------------------
-- OWNS BALL
--------------------------------------------------

function PlayerDataService.OwnsBall(
	player,
	ballId
)

	if not isValidBallId(ballId) then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	return data.OwnedBalls[ballId] == true

end


--------------------------------------------------
-- ADD OWNED BALL
--------------------------------------------------

function PlayerDataService.AddOwnedBall(
	player,
	ballId
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isValidBallId(ballId) then
		return false
	end

	local definition =
		getBallDefinition(ballId)

	local valid =
		validateBallDefinition(
			ballId,
			definition
		)

	if not valid then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	data.OwnedBalls[ballId] = true

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- REMOVE OWNED BALL
--------------------------------------------------

function PlayerDataService.RemoveOwnedBall(
	player,
	ballId
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isValidBallId(ballId) then
		return false
	end

	if ballId == DEFAULT_BALL_ID then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	if data.OwnedBalls[ballId] ~= true then
		return false
	end

	data.OwnedBalls[ballId] = nil

	if data.EquippedBall == ballId then

		data.EquippedBall =
			DEFAULT_BALL_ID

	end

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- GET EQUIPPED BALL
--------------------------------------------------

function PlayerDataService.GetEquippedBall(
	player
)

	local data =
		loadedData[player]

	if not data then
		return DEFAULT_BALL_ID
	end

	if typeof(data.EquippedBall) ~= "string"
		or data.EquippedBall == ""
		or not isValidBallId(data.EquippedBall)
		or data.OwnedBalls[data.EquippedBall] ~= true then

		return DEFAULT_BALL_ID

	end

	return data.EquippedBall

end


--------------------------------------------------
-- EQUIP BALL
--------------------------------------------------

function PlayerDataService.EquipBall(
	player,
	ballId
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isValidBallId(ballId) then
		return false
	end

	local definition =
		getBallDefinition(ballId)

	local valid =
		validateBallDefinition(
			ballId,
			definition
		)

	if not valid then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	if data.OwnedBalls[ballId] ~= true then
		return false
	end

	data.EquippedBall = ballId

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- SET OIL
--------------------------------------------------

function PlayerDataService.SetOil(
	player,
	amount
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not isFiniteNumber(amount)
		or amount < 0 then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	data.CurrentOil =
		math.clamp(
			amount,
			0,
			MAX_OIL
		)

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- ADD OIL
--------------------------------------------------

function PlayerDataService.AddOil(
	player,
	amount
)

	if not isFiniteNumber(amount)
		or amount <= 0 then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	data.CurrentOil =
		math.min(
			data.CurrentOil + amount,
			MAX_OIL
		)

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- REMOVE OIL
--------------------------------------------------

function PlayerDataService.RemoveOil(
	player,
	amount
)

	if not isFiniteNumber(amount)
		or amount <= 0 then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	if data.CurrentOil < amount then
		return false
	end

	data.CurrentOil -= amount

	if data.CurrentOil < 0 then
		data.CurrentOil = 0
	end

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- SET LEVEL
--------------------------------------------------

function PlayerDataService.SetLevel(
	player,
	level
)

	if not isFiniteNumber(level) then
		return false
	end

	level =
		math.floor(level)

	if level < 1
		or level > MAX_LEVEL then

		return false

	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	local calculatedLevel =
		calculateLevelFromXP(
			data.XP
		)

	if level > calculatedLevel then
		return false
	end

	data.Level =
		calculatedLevel

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- SET REBIRTHS
--------------------------------------------------

function PlayerDataService.SetRebirths(
	player,
	rebirths
)

	if not isFiniteNumber(rebirths) then
		return false
	end

	rebirths =
		math.floor(rebirths)

	if rebirths < 0 then
		return false
	end

	local data =
		loadedData[player]

	if not data then
		return false
	end

	data.Rebirths =
		math.min(
			rebirths,
			MAX_REBIRTHS
		)

	updatePlayerValues(
		player,
		data
	)

	return true

end


--------------------------------------------------
-- SAVE PLAYER
--------------------------------------------------

function PlayerDataService.SavePlayer(
	player
)

	if not player
		or not player:IsA("Player") then

		return false

	end

	if not loadedData[player] then
		return false
	end

	if saving[player] then

		saveRequested[player] = true

		local deadline =
			os.clock() + SAVE_TIMEOUT

		while saving[player]
			and os.clock() < deadline do

			task.wait(0.1)

		end

		return not saving[player]

	end

	saving[player] = true

	local overallSuccess = true

	while true do

		saveRequested[player] = nil

		local currentData =
			loadedData[player]

		if not currentData then

			overallSuccess = false
			break

		end

		local sanitized =
			sanitizeData(
				currentData
			)

		loadedData[player] =
			sanitized

		updatePlayerValues(
			player,
			sanitized
		)

		local dataToSave =
			copyData(
				sanitized
			)

		local key =
			getDataKey(player)

		local success, errorMessage =
			pcall(
				function()

					playerDataStore:UpdateAsync(
						key,
						function()

							return dataToSave

						end
					)

				end
			)

		if not success then

			warn(
				"[PlayerDataService]",
				"Failed to save:",
				player.Name,
				errorMessage
			)

			overallSuccess = false
			break

		end

		if not saveRequested[player] then
			break
		end

	end

	saving[player] = nil

	saveRequested[player] = nil

	return overallSuccess

end


--------------------------------------------------
-- SAVE STATE
--------------------------------------------------

function PlayerDataService.IsSaving(
	player
)

	return saving[player] == true

end


--------------------------------------------------
-- BEGIN SHUTDOWN
--------------------------------------------------

function PlayerDataService.BeginShutdown()

	shuttingDown = true

end


--------------------------------------------------
-- IS SHUTTING DOWN
--------------------------------------------------

function PlayerDataService.IsShuttingDown()

	return shuttingDown

end


--------------------------------------------------
-- AUTOSAVE
--------------------------------------------------

task.spawn(
	function()

		while true do

			task.wait(
				AUTOSAVE_INTERVAL
			)

			if shuttingDown then
				break
			end

			for player in pairs(loadedData) do

				if player.Parent then

					task.spawn(
						function()

							PlayerDataService.SavePlayer(
								player
							)

						end
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
	"[PlayerDataService]",
	"Loaded."
)

print(
	"[PlayerDataService]",
	"DataStore:",
	DATASTORE_NAME
)

print(
	"[PlayerDataService]",
	"Default Ball:",
	DEFAULT_BALL_ID
)

print(
	"[PlayerDataService]",
	"BallDefinitions:",
	"AUTHORITATIVE"
)

print(
	"[PlayerDataService]",
	"Universal Ball Ownership:",
	"ENABLED"
)

print(
	"[PlayerDataService]",
	"Persistent EquippedBall:",
	"ENABLED"
)

print(
	"[PlayerDataService]",
	"XP Authoritative Level:",
	"ENABLED"
)

print(
	"[PlayerDataService]",
	"Tutorial Ball Developer Products:",
	"DISABLED"
)

print(
	"[PlayerDataService]",
	"Invalid Ball IDs:",
	"REJECTED"
)

print(
	"[PlayerDataService]",
	"Legacy Striker System:",
	"DISABLED"
)

print(
	"[PlayerDataService]",
	"Lifecycle Ownership:",
	"PlayerDataLoader"
)

print(
	"[PlayerDataService]",
	"Server Authoritative:",
	"ENABLED"
)

print(
	"[PlayerDataService]",
	"================================"
)


--------------------------------------------------
-- RETURN
--------------------------------------------------

return PlayerDataService