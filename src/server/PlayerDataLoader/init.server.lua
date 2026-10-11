--------------------------------------------------
-- PLAYER DATA LOADER
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > PlayerDataLoader
--
-- PURPOSE:
--
-- Owns player data lifecycle.
--
-- PlayerDataService owns:
-- - DataStore
-- - In-memory data
-- - Data validation
-- - Data mutation
-- - Saving
--
-- This script owns:
-- - PlayerAdded
-- - PlayerRemoving
-- - BindToClose
--
-- IMPORTANT:
--
-- There is exactly ONE lifecycle owner.
--
-- No other script should:
-- - Load player data
-- - Save player data
-- - BindToClose for player data
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")


--------------------------------------------------
-- PLAYER DATA SERVICE
--------------------------------------------------

local PlayerDataService =
	require(
		script:WaitForChild(
			"PlayerDataService"
		)
	)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG =
	true

local SHUTDOWN_TIMEOUT =
	25


--------------------------------------------------
-- SERVER STATE
--------------------------------------------------

local shuttingDown =
	false


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if not DEBUG then

		return

	end


	print(
		"[PlayerDataLoader]",
		...
	)

end


--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

local function onPlayerAdded(
	player
)

	if not player
		or not player:IsA("Player") then

		return

	end


	--------------------------------------------------
	-- DO NOT LOAD NEW PLAYERS DURING SHUTDOWN
	--------------------------------------------------

	if shuttingDown then

		warn(
			"[PlayerDataLoader]",
			"Rejected player load during shutdown:",
			player.Name,
			player.UserId
		)

		return

	end


	--------------------------------------------------
	-- LOAD
	--------------------------------------------------

	debugPrint(
		"Loading data for:",
		player.Name,
		player.UserId
	)


	local success =
		PlayerDataService.LoadPlayer(
			player
		)


	if not success then

		warn(
			"[PlayerDataLoader]",
			"Could not load data for:",
			player.Name,
			player.UserId
		)


		--------------------------------------------------
		-- NEVER ALLOW GAMEPLAY WITH UNKNOWN DATA
		--------------------------------------------------

		if player.Parent then

			player:Kick(
				"Your data could not be loaded. Please rejoin."
			)

		end


		return

	end


	debugPrint(
		"Data loaded:",
		player.Name,
		player.UserId
	)

end


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

local function onPlayerRemoving(
	player
)

	if not player then

		return

	end


	--------------------------------------------------
	-- SHUTDOWN HANDLING
	--
	-- During BindToClose, shutdown saves are started
	-- explicitly below.
	--
	-- Do not start another save here if the player
	-- is already being handled by shutdown.
	--------------------------------------------------

	if shuttingDown then

		debugPrint(
			"PlayerRemoving during shutdown:",
			player.Name,
			player.UserId
		)

		return

	end


	--------------------------------------------------
	-- NORMAL PLAYER LEAVE
	--------------------------------------------------

	debugPrint(
		"Saving data for:",
		player.Name,
		player.UserId
	)


	local success =
		PlayerDataService.SavePlayer(
			player
		)


	if not success then

		warn(
			"[PlayerDataLoader]",
			"Could not save data for:",
			player.Name,
			player.UserId
		)

		return

	end


	debugPrint(
		"Data saved:",
		player.Name,
		player.UserId
	)

end


--------------------------------------------------
-- CONNECTIONS
--------------------------------------------------

Players.PlayerAdded:Connect(
	onPlayerAdded
)

Players.PlayerRemoving:Connect(
	onPlayerRemoving
)


--------------------------------------------------
-- HANDLE PLAYERS ALREADY PRESENT
--
-- Important for cases where this script starts
-- after players have already entered the server.
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	task.spawn(
		function()

			onPlayerAdded(
				player
			)

		end
	)

end


--------------------------------------------------
-- SERVER SHUTDOWN
--
-- ONLY THIS SCRIPT OWNS BindToClose.
--------------------------------------------------

game:BindToClose(
	function()

		--------------------------------------------------
		-- PREVENT DUPLICATE SHUTDOWN
		--------------------------------------------------

		if shuttingDown then

			return

		end


		shuttingDown =
			true


		debugPrint(
			"Server shutting down."
		)


		--------------------------------------------------
		-- TELL PLAYER DATA SERVICE TO ENTER SHUTDOWN
		--------------------------------------------------

		PlayerDataService.BeginShutdown()


		--------------------------------------------------
		-- SNAPSHOT CURRENT PLAYERS
		--------------------------------------------------

		local players =
			Players:GetPlayers()


		if #players == 0 then

			debugPrint(
				"Shutdown saves complete."
			)

			return

		end


		--------------------------------------------------
		-- START ALL SHUTDOWN SAVES CONCURRENTLY
		--------------------------------------------------

		for _, player in ipairs(
			players
		) do

			task.spawn(
				function()

					local success =
						PlayerDataService.SavePlayer(
							player
						)


					if not success then

						warn(
							"[PlayerDataLoader]",
							"Shutdown save failed:",
							player.Name,
							player.UserId
						)

					end

				end
			)

		end


		--------------------------------------------------
		-- WAIT FOR ACTIVE SAVES
		--------------------------------------------------

		local deadline =
			os.clock()
			+ SHUTDOWN_TIMEOUT


		while os.clock() < deadline do

			local pending =
				0


			for _, player in ipairs(
				players
			) do

				if PlayerDataService.IsSaving(
					player
				) then

					pending += 1

				end

			end


			if pending <= 0 then

				break

			end


			task.wait(
				0.1
			)

		end


		--------------------------------------------------
		-- FINAL STATUS
		--------------------------------------------------

		local stillSaving =
			0


		for _, player in ipairs(
			players
		) do

			if PlayerDataService.IsSaving(
				player
			) then

				stillSaving += 1

			end

		end


		if stillSaving > 0 then

			warn(
				"[PlayerDataLoader]",
				"Shutdown timeout reached with",
				stillSaving,
				"save(s) still active."
			)

		else

			debugPrint(
				"Shutdown saves complete."
			)

		end

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"================================"
)

print(
	"[PlayerDataLoader]",
	"SERVER READY"
)

print(
	"[PlayerDataLoader]",
	"Lifecycle owner: ENABLED"
)

print(
	"[PlayerDataLoader]",
	"PlayerRemoving save: ENABLED"
)

print(
	"[PlayerDataLoader]",
	"BindToClose save: ENABLED"
)

print(
	"[PlayerDataLoader]",
	"Duplicate shutdown protection: ENABLED"
)

print(
	"[PlayerDataLoader]",
	"Waiting for players..."
)

print(
	"================================"
)