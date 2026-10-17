--------------------------------------------------
-- REBIRTH BONUSES (shared, pure functions)
--
-- What each rebirth is worth. The SERVER applies these (oil collection,
-- WinCourse winnings, XP); the client only uses them to show the
-- numbers, so they can never be spoofed from the client.
--
--   XP    : +10x per rebirth           (existing rule: 1, 11, 21, ...)
--   Oil   : +1x per rebirth            (rebirth 1 = x2, 2 = x3, ...)
--   Wins  : +1x per rebirth from the 3rd on
--           (rebirths 0-2 = x1, rebirth 3 = x2, 4 = x3, ...)
--------------------------------------------------

local RebirthBonuses = {}

RebirthBonuses.XP_PER_REBIRTH = 10
RebirthBonuses.OIL_PER_REBIRTH = 1
RebirthBonuses.WINS_PER_REBIRTH = 1
RebirthBonuses.WINS_START_REBIRTH = 3

local function clean(rebirths)
	rebirths = tonumber(rebirths) or 0
	if rebirths ~= rebirths or rebirths < 0 then
		return 0
	end
	return math.floor(rebirths)
end

function RebirthBonuses.XPMultiplier(rebirths)
	return 1 + clean(rebirths) * RebirthBonuses.XP_PER_REBIRTH
end

function RebirthBonuses.OilMultiplier(rebirths)
	return 1 + clean(rebirths) * RebirthBonuses.OIL_PER_REBIRTH
end

function RebirthBonuses.WinsMultiplier(rebirths)
	local earned = math.max(0, clean(rebirths) - (RebirthBonuses.WINS_START_REBIRTH - 1))
	return 1 + earned * RebirthBonuses.WINS_PER_REBIRTH
end

return RebirthBonuses
