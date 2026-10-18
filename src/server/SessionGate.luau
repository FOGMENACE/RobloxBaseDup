--------------------------------------------------
-- SESSION GATE (server)
--
-- Cross-server safety for the small per-player DataStores (quests, boosts,
-- calendar, tutorial, settings, limited generator ...).
--
-- PlayerData_v1 holds a session lock: a joining server only gets the player's
-- main data once the previous server has saved and released it. The small
-- stores are written by their own services when a player leaves, so a server
-- that loaded them straight away could read values the old server had not
-- written yet. Every such service calls SessionGate.Wait(player) before its
-- first read, so they all load AFTER the previous server is done with the
-- player (PlayerDataService.ReleasePlayer also waits a short grace period
-- before releasing the lock so those other saves can land).
--------------------------------------------------

local ServerScriptService = game:GetService("ServerScriptService")

local SessionGate = {}

local MAX_WAIT = 45 -- a little longer than the main data's lock wait

function SessionGate.Wait(player, timeout)
	local ok, PlayerDataService = pcall(function()
		return require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
	end)
	if not ok then
		return false
	end

	local deadline = os.clock() + (timeout or MAX_WAIT)
	while player.Parent and os.clock() < deadline do
		if PlayerDataService.GetData(player) then
			return true
		end
		task.wait(0.25)
	end

	if player.Parent then
		warn("[SessionGate] main data not ready in time; continuing:", player.Name)
	end
	return false
end

return SessionGate
