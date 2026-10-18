--------------------------------------------------
-- PLAYER DATA LOADER
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > PlayerDataLoader (Script)
--         > PlayerDataService (ModuleScript)
--
-- RESPONSIBILITIES:
-- - Load player data when players join
-- - Save player data when players leave
-- - Save player data during server shutdown
-- - Prevent gameplay with unavailable player data
--
-- PlayerDataService remains responsible for:
-- - DataStore operations
-- - Data validation
-- - In-memory player data
-- - XP, levels, wins, rebirths and oil
-- - Ball ownership and equipment
-- - Rebirth processing
-- - Saving individual player data
--
-- THIS SCRIPT IS THE ONLY LIFECYCLE OWNER.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")


--------------------------------------------------
-- PLAYER DATA SERVICE
--------------------------------------------------

local PlayerDataService = require(
	script:WaitForChild("PlayerDataService")
)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG = true

local SHUTDOWN_TIMEOUT = 25


--------------------------------------------------
-- SERVER STATE
--------------------------------------------------

local shuttingDown = false

-- Prevent duplicate concurrent loads for the same player.
local loadingPlayers = {}

-- Track players whose load completed successfully.
local loadedPlayers = {}


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)
	if DEBUG then
		print("[PlayerDataLoader]", ...)
	end
end


--------------------------------------------------
-- LOAD PLAYER
--------------------------------------------------

local function onPlayerAdded(player)
	if not player or not player:IsA("Player") then
		return
	end

	if shuttingDown then
		warn(
			"[PlayerDataLoader] Rejected load during shutdown:",
			player.Name
		)
		return
	end

	if loadedPlayers[player] then
		return
	end

	if loadingPlayers[player] then
		return
	end

	loadingPlayers[player] = true

	debugPrint(
		"Loading data:",
		player.Name,
		player.UserId
	)

	local success, result = pcall(function()
		return PlayerDataService.LoadPlayer(player)
	end)

	loadingPlayers[player] = nil

	if not success or result ~= true then
		warn(
			"[PlayerDataLoader] Data load failed:",
			player.Name,
			player.UserId,
			result
		)

		if player.Parent == Players then
			player:Kick(
				"Your data could not be loaded. Please rejoin."
			)
		end

		return
	end

	loadedPlayers[player] = true

	debugPrint(
		"Data loaded successfully:",
		player.Name,
		player.UserId
	)
end


--------------------------------------------------
-- SAVE PLAYER
--------------------------------------------------

local function savePlayer(player, reason)
	if not player then
		return false
	end

	-- Never save data that this loader failed to load.
	if not loadedPlayers[player] then
		debugPrint(
			"Skipping save for player without confirmed load:",
			player.Name,
			reason
		)
		return false
	end

	debugPrint(
		"Saving data:",
		player.Name,
		"Reason:",
		reason
	)

	local success, result = pcall(function()
		return PlayerDataService.SavePlayer(player)
	end)

	if not success or result ~= true then
		warn(
			"[PlayerDataLoader] Save failed:",
			player.Name,
			player.UserId,
			result
		)

		return false
	end

	debugPrint(
		"Data saved successfully:",
		player.Name,
		"Reason:",
		reason
	)

	return true
end


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

local function onPlayerRemoving(player)
	if not player then
		return
	end

	-- During shutdown, BindToClose owns the save process.
	if shuttingDown then
		debugPrint(
			"Player leaving during shutdown:",
			player.Name
		)
		return
	end

	savePlayer(player, "PlayerRemoving")

	pcall(function()
		PlayerDataService.ReleasePlayer(player)
	end)

	loadedPlayers[player] = nil
	loadingPlayers[player] = nil
end


--------------------------------------------------
-- PLAYER CONNECTIONS
--------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(onPlayerRemoving)


--------------------------------------------------
-- HANDLE PLAYERS ALREADY PRESENT
--------------------------------------------------

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end


--------------------------------------------------
-- SERVER SHUTDOWN
--
-- ONLY THIS SCRIPT OWNS BindToClose.
--------------------------------------------------

game:BindToClose(function()
	if shuttingDown then
		return
	end

	shuttingDown = true

	debugPrint("Server shutdown started.")

	--------------------------------------------------
	-- STOP NORMAL LIFECYCLE ACTIVITY
	--------------------------------------------------

	PlayerDataService.BeginShutdown()

	--------------------------------------------------
	-- SNAPSHOT PLAYERS WITH CONFIRMED LOADED DATA
	--------------------------------------------------

	local playersToSave = {}

	for player in pairs(loadedPlayers) do
		table.insert(playersToSave, player)
	end

	if #playersToSave == 0 then
		debugPrint("No loaded player data to save.")
		return
	end

	--------------------------------------------------
	-- START SAVES CONCURRENTLY
	--------------------------------------------------

	local pending = #playersToSave
	local saveResults = {}

	for _, player in ipairs(playersToSave) do
		task.spawn(function()
			local success = savePlayer(
				player,
				"ServerShutdown"
			)

			saveResults[player] = success

			-- free the session lock so the next server can load immediately
			pcall(function()
				PlayerDataService.ReleasePlayer(player)
			end)

			pending -= 1
		end)
	end

	--------------------------------------------------
	-- WAIT FOR SAVES OR TIMEOUT
	--------------------------------------------------

	local deadline = os.clock() + SHUTDOWN_TIMEOUT

	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end

	--------------------------------------------------
	-- REPORT FINAL STATUS
	--------------------------------------------------

	if pending > 0 then
		warn(
			"[PlayerDataLoader] Shutdown timed out.",
			pending,
			"save(s) did not finish before the deadline."
		)
	else
		local failed = 0

		for _, success in pairs(saveResults) do
			if not success then
				failed += 1
			end
		end

		if failed > 0 then
			warn(
				"[PlayerDataLoader] Shutdown finished with",
				failed,
				"failed save(s)."
			)
		else
			debugPrint("All shutdown saves completed.")
		end
	end
end)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[PlayerDataLoader] SERVER READY")
print("[PlayerDataLoader] Lifecycle owner: ENABLED")
print("[PlayerDataLoader] PlayerAdded loading: ENABLED")
print("[PlayerDataLoader] PlayerRemoving saving: ENABLED")
print("[PlayerDataLoader] BindToClose saving: ENABLED")
print("[PlayerDataLoader] Duplicate load protection: ENABLED")
print("[PlayerDataLoader] Waiting for players...")
print("================================")