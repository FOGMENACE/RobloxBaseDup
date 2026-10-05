--------------------------------------------------
-- PLAYER DATA SERVICE
--
-- SERVER ONLY
--
-- Location:
-- ServerScriptService
--     > PlayerDataLoader
--         > PlayerDataService
--
-- PURPOSE:
-- Central authoritative player progression data.
--
-- SECURITY:
-- Client never writes directly to this module.
-- All progression changes are validated server-side.
--------------------------------------------------

local DataStoreService =
	game:GetService("DataStoreService")

local Players =
	game:GetService("Players")


--------------------------------------------------
-- MODULE
--------------------------------------------------

local PlayerDataService = {}

--------------------------------------------------
-- DATASTORE
--------------------------------------------------

local DATASTORE_NAME =
	"PlayerData_v1"

local playerDataStore =
	DataStoreService:GetDataStore(
		DATASTORE_NAME
	)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local AUTOSAVE_INTERVAL =
	60

local MAX_XP =
	1e15

local MAX_WINS =
	1e15

local MAX_REBIRTHS =
	1000000

local MAX_OIL =
	1e9


--------------------------------------------------
-- DEFAULT DATA
--------------------------------------------------

local DEFAULT_DATA = {

	XP = 0,

	Level = 1,

	Wins = 0,

	Rebirths = 0,

	CurrentOil = 0,

}


--------------------------------------------------
-- SERVER MEMORY
--------------------------------------------------

local loadedData = {}

local saving = {}

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

	if value > maximum then

		return maximum

	end

	return value

end


--------------------------------------------------
-- SANITIZE DATA
--------------------------------------------------

local function sanitizeData(data)

	if typeof(data) ~= "table" then

		data = {}

	end


	local sanitized = {

		XP =
			sanitizeNumber(
				data.XP,
				DEFAULT_DATA.XP,
				MAX_XP
			),

		Level =
			sanitizeNumber(
				data.Level,
				DEFAULT_DATA.Level,
				MAX_REBIRTHS
			),

		Wins =
			sanitizeNumber(
				data.Wins,
				DEFAULT_DATA.Wins,
				MAX_WINS
			),

		Rebirths =
			sanitizeNumber(
				data.Rebirths,
				DEFAULT_DATA.Rebirths,
				MAX_REBIRTHS
			),

		CurrentOil =
			sanitizeNumber(
				data.CurrentOil,
				DEFAULT_DATA.CurrentOil,
				MAX_OIL
			),

	}


	--------------------------------------------------
	-- INTEGER VALUES
	--------------------------------------------------

	sanitized.Level =
		math.floor(
			sanitized.Level
		)

	sanitized.Wins =
		math.floor(
			sanitized.Wins
		)

	sanitized.Rebirths =
		math.floor(
			sanitized.Rebirths
		)


	return sanitized

end


--------------------------------------------------
-- COPY DATA
--------------------------------------------------

local function copyData(data)

	local copy = {}

	for key, value in pairs(data) do

		copy[key] = value

	end

	return copy

end


--------------------------------------------------
-- DATA KEY
--------------------------------------------------

local function getDataKey(player)

	return "Player_" ..
		tostring(player.UserId)

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


	local key =
		getDataKey(player)


	local success, result =
		pcall(function()

			return playerDataStore:GetAsync(
				key
			)

		end)


	if not success then

		warn(
			"[PlayerDataService]",
			"Failed to load data for",
			player.Name,
			result
		)

		return nil

	end


	local data =
		sanitizeData(
			result
		)


	loadedData[player] =
		data


	return data

end


--------------------------------------------------
-- SAVE DATA
--------------------------------------------------

local function saveData(player)

	if not player then

		return false

	end

	local data =
		loadedData[player]

	if not data then

		return false

	end

	if saving[player] then

		return false

	end


	saving[player] =
		true


	local key =
		getDataKey(player)

	local dataToSave =
		copyData(
			data
		)


	local success, errorMessage =
		pcall(function()

			playerDataStore:UpdateAsync(
				key,
				function()

					return dataToSave

				end
			)

		end)


	saving[player] =
		nil


	if not success then

		warn(
			"[PlayerDataService]",
			"Failed to save data for",
			player.Name,
			errorMessage
		)

		return false

	end


	return true

end


--------------------------------------------------
-- CREATE LEADERSTATS
--------------------------------------------------

local function createLeaderstats(
	player,
	data
)

	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)

	if not leaderstats then

		leaderstats =
			Instance.new(
				"Folder"
			)

		leaderstats.Name =
			"leaderstats"

		leaderstats.Parent =
			player

	end


	--------------------------------------------------
	-- REBIRTHS
	--------------------------------------------------

	local rebirths =
		leaderstats:FindFirstChild(
			"Rebirths"
		)

	if not rebirths then

		rebirths =
			Instance.new(
				"IntValue"
			)

		rebirths.Name =
			"Rebirths"

		rebirths.Parent =
			leaderstats

	end


	--------------------------------------------------
	-- WINS
	--------------------------------------------------

	local wins =
		leaderstats:FindFirstChild(
			"Wins"
		)

	if not wins then

		wins =
			Instance.new(
				"IntValue"
			)

		wins.Name =
			"Wins"

		wins.Parent =
			leaderstats

	end


	--------------------------------------------------
	-- VALUES
	--------------------------------------------------

	rebirths.Value =
		data.Rebirths

	wins.Value =
		data.Wins

end

--------------------------------------------------
-- UPDATE PLAYER VALUES
--------------------------------------------------

local function updatePlayerValues(
	player,
	data
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


	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)

	if leaderstats then

		local level =
			leaderstats:FindFirstChild(
				"Level"
			)

		if level then

			level.Value =
				data.Level

		end


		local wins =
			leaderstats:FindFirstChild(
				"Wins"
			)

		if wins then

			wins.Value =
				data.Wins

		end

	end

end


--------------------------------------------------
-- PLAYER LOAD
--------------------------------------------------

function PlayerDataService.LoadPlayer(player)

	if not player
		or not player:IsA("Player") then

		return false

	end

	local data =
		loadData(player)

	if not data then
		return false
	end

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
		data.CurrentOil
	)

	return true

end

--------------------------------------------------
-- GET DATA
--------------------------------------------------

function PlayerDataService.GetData(
	player
)

	return loadedData[player]

end


--------------------------------------------------
-- GET XP
--------------------------------------------------

function PlayerDataService.GetXP(
	player
)

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

function PlayerDataService.GetWins(
	player
)

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

function PlayerDataService.GetRebirths(
	player
)

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

function PlayerDataService.GetOil(
	player
)

	local data =
		loadedData[player]

	if not data then

		return 0

	end

	return data.CurrentOil

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
		math.floor(
			amount
		)

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
		math.floor(
			amount
		)

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
		math.min(
			amount,
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


	local current =
		PlayerDataService.GetOil(
			player
		)


	return PlayerDataService.SetOil(
		player,
		current + amount
	)

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


	data.CurrentOil -=
		amount


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


	if level < 1 then

		return false

	end


	local data =
		loadedData[player]

	if not data then

		return false

	end


	data.Level =
		math.min(
			level,
			MAX_REBIRTHS
		)


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
		math.floor(
			rebirths
		)


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

	return saveData(
		player
	)

end


--------------------------------------------------
-- REMOVE PLAYER
--------------------------------------------------

function PlayerDataService.RemovePlayer(
	player
)

	local data =
		loadedData[player]

	if not data then

		return

	end


	saveData(
		player
	)


	loadedData[player] =
		nil

	saving[player] =
		nil

end


--------------------------------------------------
-- AUTOSAVE
--------------------------------------------------

task.spawn(function()

	while not shuttingDown do

		task.wait(
			AUTOSAVE_INTERVAL
		)


		if shuttingDown then

			break

		end


		for player in pairs(
			loadedData
		) do

			if player.Parent then

				saveData(
					player
				)

			end

		end

	end

end)


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		saveData(player)

		loadedData[player] = nil
		saving[player] = nil

	end
)

--------------------------------------------------
-- SERVER SHUTDOWN
--------------------------------------------------

game:BindToClose(function()

	shuttingDown =
		true


	local players =
		Players:GetPlayers()


	for _, player in ipairs(
		players
	) do

		saveData(
			player
		)

	end

end)


--------------------------------------------------
-- RETURN
--------------------------------------------------

return PlayerDataService
