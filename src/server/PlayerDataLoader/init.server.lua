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
-- Handles player join/leave lifecycle.
--
-- PlayerDataService owns the actual data.
-- This script simply tells it when to load
-- and save players.
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


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if DEBUG then

		print(
			"[PlayerDataLoader]",
			...
		)

	end

end


--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

local function onPlayerAdded(player)

	debugPrint(
		"Loading data for:",
		player.Name
	)


	local success =
		PlayerDataService.LoadPlayer(
		player
	)

	if not success then

		warn(
			"[PlayerDataLoader]",
			"Could not load data for:",
			player.Name
		)

		--------------------------------------------------
		-- DO NOT ALLOW A PLAYER INTO THE GAME WITH
		-- UNKNOWN/UNLOADED PERSISTENT DATA.
		--------------------------------------------------

		player:Kick(
			"Your data could not be loaded. Please rejoin."
		)

		return

	end


	debugPrint(
		"Data loaded:",
		player.Name
	)

end


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

local function onPlayerRemoving(player)

	debugPrint(
		"Saving data for:",
		player.Name
	)


	local success =
		PlayerDataService.SavePlayer(
			player
		)


	if not success then

		warn(
			"[PlayerDataLoader]",
			"Could not save data for:",
			player.Name
		)

		return

	end


	debugPrint(
		"Data saved:",
		player.Name
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
-- HANDLE PLAYERS ALREADY IN SERVER
--
-- Useful if this script starts after players
-- have already joined.
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	task.spawn(
		onPlayerAdded,
		player
	)

end


--------------------------------------------------
-- SERVER SHUTDOWN
--------------------------------------------------

game:BindToClose(
	function()

		debugPrint(
			"Server shutting down."
		)

		local players =
			Players:GetPlayers()


		for _, player in ipairs(
			players
		) do

			PlayerDataService:SavePlayer(
				player
			)

		end


		debugPrint(
			"Shutdown saves complete."
		)

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
	"Waiting for players..."
)

print(
	"================================"
)
