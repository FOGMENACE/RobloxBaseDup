--------------------------------------------------
-- REBIRTH BONUSES (shared, pure functions)
--
-- What each rebirth is worth. The SERVER applies these (oil collection,
-- WinCourse winnings, XP); the client only uses them to show the
-- numbers, so they can never be spoofed from the client.
--
--   XP    : +10x per rebirth           (existing rule: 1, 11, 21, ...)
--   Oil   : +1x per rebirth            (rebirth 1 = x2, 2 = x3, ...)
--   Wins  : +1x per rebirth from the 2nd on (x1 oil -> x2 oil is the free
--           tutorial rebirth; the rebirth to x3 oil also starts wins: x2, x3, ...)
--------------------------------------------------

local RebirthBonuses = {}

RebirthBonuses.XP_PER_REBIRTH = 10
RebirthBonuses.OIL_PER_REBIRTH = 1
RebirthBonuses.WINS_PER_REBIRTH = 1
RebirthBonuses.WINS_START_REBIRTH = 2

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

-- REACH-LEVEL SCHEDULE: the level you must reach to rebirth, per rebirth
-- you already have. Index 1 = 0 rebirths (the tutorial rebirth: just earn
-- your first level-up on the X1 generator). Steps are strategic: small
-- early, +10 / +15 in the middle, wider later, but never huge jumps.
local REQUIRED_LEVELS = {
	2, 9, 17, 30, 45, 55, 70, 80, 95, 110,
	125, 145, 165, 190, 215, 245, 275, 310, 345, 385,
}

function RebirthBonuses.RequiredLevel(rebirths)
	local count = clean(rebirths)
	if count + 1 <= #REQUIRED_LEVELS then
		return REQUIRED_LEVELS[count + 1]
	end

	-- beyond the table: +45 and growing by 5 each rebirth
	local extra = count - (#REQUIRED_LEVELS - 1)
	return REQUIRED_LEVELS[#REQUIRED_LEVELS] + extra * 45 + (extra * (extra - 1) / 2) * 5
end

return RebirthBonuses
