--------------------------------------------------
-- BADGE AWARDS (SERVER ONLY MODULE)
--
-- BadgeAwards.Award(player, "Welcome" | "Played5" | "Played10" |
--                           "Played20" | "Captain")
--
-- Badge ids live in StoreConfig.Badges. A badge is only awarded if the
-- player does not own it yet; failures are logged and never block the
-- caller (a badge is a thank-you, not part of a purchase's success).
-- Roblox badges must belong to THIS experience.
--------------------------------------------------

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local StoreConfig = require(script.Parent:WaitForChild("StoreConfig"))

local BadgeAwards = {}

local inFlight = {} -- [userId .. ":" .. badgeId] = true

function BadgeAwards.Award(player, key)
	local badgeId = StoreConfig.Badges[key]
	if typeof(badgeId) ~= "number" or not player or player.Parent ~= Players then
		return false
	end

	local flightKey = player.UserId .. ":" .. badgeId
	if inFlight[flightKey] then
		return false
	end
	inFlight[flightKey] = true

	local awarded = false

	local okOwned, owned = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)

	if okOwned and not owned then
		local ok, result = pcall(function()
			return BadgeService:AwardBadge(player.UserId, badgeId)
		end)

		if ok and result then
			awarded = true
		else
			warn("[BadgeAwards] Could not award", key, "to", player.Name, result)
		end
	elseif not okOwned then
		warn("[BadgeAwards] Ownership check failed:", key, player.Name, owned)
	end

	inFlight[flightKey] = nil
	return awarded
end

return BadgeAwards
