--------------------------------------------------
-- BADGE TIMERS (SERVER ONLY)
--
-- "Welcome" on join, then "You played for 5 / 10 / 20 minutes!" counted on
-- the server from the moment the player joined this server (a player who
-- stays 20 minutes gets all three). Awarding is idempotent (BadgeAwards
-- checks ownership first), so rejoining never double-awards.
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local BadgeAwards = require(ServerScriptService:WaitForChild("BadgeAwards"))

local MILESTONES = {
	{ Seconds = 5 * 60, Key = "Played5" },
	{ Seconds = 10 * 60, Key = "Played10" },
	{ Seconds = 20 * 60, Key = "Played20" },
}

local function track(player)
	task.spawn(function()
		BadgeAwards.Award(player, "Welcome")

		local joined = os.clock()

		for _, milestone in ipairs(MILESTONES) do
			local wait = milestone.Seconds - (os.clock() - joined)
			if wait > 0 then
				task.wait(wait)
			end

			if player.Parent ~= Players then
				return
			end

			BadgeAwards.Award(player, milestone.Key)
		end
	end)
end

Players.PlayerAdded:Connect(track)
for _, player in ipairs(Players:GetPlayers()) do
	track(player)
end

print("[BadgeTimers] READY")
