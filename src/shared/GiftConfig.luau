--------------------------------------------------
-- GIFT CONFIG
--
-- Edit this file to change what the gifts give. The SERVER
-- (GiftService) reads it to grant rewards; the client reads it only
-- to display them, so editing it on a client changes nothing.
--
-- Reward types:
--   { Type = "Wins",     Amount = 2000 }
--   { Type = "Oil",      Amount = 500 }      -- "starter oil": added to the
--                                            -- player's next run, after the
--                                            -- run's oil reset
--   { Type = "Ball",     BallId = "Venom" }  -- must exist in BallDefinitions
--   { Type = "BallNext" }                    -- the next ball in shop order the
--                                            -- player does not own yet
--                                            -- (tutorial ball excluded)
--   { Type = "Rebirth" }                     -- +1 rebirth (no level reset)
--
-- Add Special = true to highlight a slot (e.g. day 7).
-- The ViewportFrame preview for ball rewards is automatic.
--------------------------------------------------

local GiftConfig = {}

-- Timed gift: claimable every IntervalSeconds of play time
-- (session based; the timer restarts when the player joins).
GiftConfig.TimedGift = {
	IntervalSeconds = 600,
	Reward = { Type = "Wins", Amount = 250 },
}

-- Daily calendar: one slot per consecutive day, claimed manually.
-- Missing a day restarts the streak at day 1. After the last slot
-- the cycle starts again. Days are UTC calendar days.
--
-- Day 7 is the "special" slot: swap it for { Type = "Ball", ... }
-- (e.g. a special ball that is also sold as a Game Pass) when ready.
GiftConfig.DailyCalendar = {
	Days = {
		{ Type = "Oil", Amount = 500 },
		{ Type = "Wins", Amount = 2000 },
		{ Type = "Oil", Amount = 1500 },
		{ Type = "BallNext" },
		{ Type = "Wins", Amount = 8000 },
		{ Type = "Oil", Amount = 5000 },
		{ Type = "Wins", Amount = 25000, Special = true },
	},
}

return GiftConfig
