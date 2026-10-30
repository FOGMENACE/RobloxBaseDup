--------------------------------------------------
-- REBIRTH SERVER
-- SERVER AUTHORITATIVE
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local RebirthSystem = ReplicatedStorage:WaitForChild("RebirthSystem")
local RebirthRemote = RebirthSystem:WaitForChild("RebirthRemote")

local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local REQUEST_COOLDOWN = 1.0

local lastRequest = {}

--------------------------------------------------
-- REMOTE HANDLER
--------------------------------------------------

RebirthRemote.OnServerEvent:Connect(function(player, action)

	if not player or not player:IsA("Player") then
		return
	end

	if typeof(action) ~= "string" then
		return
	end

	--------------------------------------------------
	-- RATE LIMIT
	--------------------------------------------------

	local now = os.clock()
	local previous = lastRequest[player]

	if previous and now - previous < REQUEST_COOLDOWN then
		-- always answer, so the client never waits forever
		if action == "Rebirth" then
			RebirthRemote:FireClient(player, "RebirthResult", false, "TOO_FAST")
		end
		return
	end

	lastRequest[player] = now

	--------------------------------------------------
	-- REBIRTH REQUEST
	--------------------------------------------------

	if action == "Rebirth" then

		-- pcall: whatever happens (error, slow save) the client gets an answer
		local ok, success, reason = pcall(PlayerDataService.RebirthPlayer, player)
		if not ok then
			warn("[RebirthServer] RebirthPlayer error:", success)
			success, reason = false, "SERVER_ERROR"
		end

		RebirthRemote:FireClient(
			player,
			"RebirthResult",
			success,
			reason
		)

		return
	end

	--------------------------------------------------
	-- REQUEST CURRENT STATE
	--------------------------------------------------

	if action == "GetState" then

		local data = PlayerDataService.GetData(player)

		if not data then
			RebirthRemote:FireClient(
				player,
				"State",
				nil
			)

			return
		end

		-- the saved requirement (RebirthBonuses schedule), not an old fixed formula
		local requiredLevel = data.RebirthLevelRequirement

		local progress =
			PlayerDataService.GetXPProgress(player)

		RebirthRemote:FireClient(
			player,
			"State",
			{
				XP = data.XP,
				Level = data.Level,
				Rebirths = data.Rebirths,
				RequiredLevel = requiredLevel,
				MaxReached = data.Level >= requiredLevel,
				LevelProgress = progress and progress.Progress or 0,
				XPIntoLevel = progress and progress.XPIntoLevel or 0,
				XPNeededForLevel = progress and progress.XPNeededForLevel or 0,
			}
		)

	end

end)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
end)

print("[RebirthServer] Ready.")