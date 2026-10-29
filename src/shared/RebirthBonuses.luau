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

RebirthBonuses.XP_PER_REBIRTH = 5 -- was 10: early rebirths levelled in seconds
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
-- your first level-up on the X1 generator).
--
-- Tuned for the ADDITIVE pass XP (pass numbers are added to the rebirth bonus,
-- not multiplied) and the generator ladder. Target time for a player with NO
-- passes rolling on the best generator they can use:
--   R0-3 : 1-4 min    R4-10 : 5-10 min    R11-20 : 10-19 min
--   R21-40 : 19-30 min    R41-75 : 30-45 min    R76-100 : 45-60 min
-- The jumps at R8 / R15 / R20 / R25 ... line up with the new generator that
-- unlocks there (each one pays more XP, so the next climb is longer).
-- Pass owners are several times faster (a x240 pass about 2x early, all six
-- passes a lot more), which is the thing they pay for.
-- Rebirths 1-5 were raised (5,9,14,19,25 -> 7,12,17,22,27): the 2nd rebirth took ~45 s and
-- half a world went by in minutes; they now take ~2-3 min each. From rebirth 6 on it is unchanged.
-- smooth curve (old-scale levels): 2 + 3r + 0.33r^2, so every rebirth is only a little
-- harder than the last (no 36 -> 81 jumps): 2, 5, 9, 14, 19, 25 ... 650 at rebirth 40
local REQUIRED_LEVELS = {
	2, 7, 12, 17, 22, 27, 32, 39, 47, 56, 65, 75, 86, 97, 109, 121, 134, 148, 163, 178, 194, 211, 228, 246, 264, 283, 303, 324, 345, 367, 389, 412, 436, 460, 485, 511, 538, 565, 593, 621, 650,
}
-- LEVELS ARE 5x FINER: each old level is now 5 levels, so the level-up sound
-- comes often, while the XP to the next rebirth stays a real (but fair) climb. PlayerDataService uses the same scale.
RebirthBonuses.LEVEL_SCALE = 5

local function scaleLevel(oldLevel)
	return 1 + RebirthBonuses.LEVEL_SCALE * (oldLevel - 1)
end

function RebirthBonuses.RequiredLevel(rebirths)
	local count = clean(rebirths)
	if count + 1 <= #REQUIRED_LEVELS then
		return scaleLevel(REQUIRED_LEVELS[count + 1])
	end

	-- beyond the table: a steady +22 levels per rebirth. The old rule grew the
	-- step by 5 every rebirth (quadratic), so around 37 rebirths one cycle
	-- needed ~1,960 levels and kept exploding. Linear steps keep each rebirth a
	-- similar, reachable climb while the rebirth XP bonus keeps growing too:
	-- 50 -> 909, 75 -> 1,459, 100 -> 2,009.
	local extra = count - (#REQUIRED_LEVELS - 1)
	return scaleLevel(REQUIRED_LEVELS[#REQUIRED_LEVELS] + extra * 22)
end

return RebirthBonuses
