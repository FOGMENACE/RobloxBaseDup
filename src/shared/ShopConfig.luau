--------------------------------------------------
-- SHOP CONFIG
--
-- GamePasses : shown in the hub's pass panel. PassId = 0 shows "SOON".
--              (Passes are granted by server/GamePassService, never by
--              the client; ids here only open the purchase prompt.)
-- RobuxPrices: DISPLAY ONLY labels for the ball shop's Robux buttons.
--              The price that is actually charged is the one set on the
--              Developer Product in the Creator Hub; keep them in sync.
--              The server resolves which product to prompt, never the
--              client.
--------------------------------------------------

local ShopConfig = {}

ShopConfig.GamePasses = {
	{ Name = "X100 LESSONS", Description = "Earn 100x XP on the Admin x100 generator.", PassId = 2039936926 },
	{ Name = "X1000 MOST WANTED LESSONS", Description = "Earn 1000x XP on the Admin x1000 generator.", PassId = 2036355132 },
}

ShopConfig.RobuxPrices = {
	CatPlz = 17,
	Thrifty = 24,
	Voltage = 29,
	Venom = 43,
	SnotOoze = 61,
	Meteor = 79,
	AttitudePausible = 101,
	GreenNature = 127,
	Detailo = 153,
	NeonVestOff = 191,
	StarDoodle = 217,
	PainMoon = 246,
	VoidMinter = 273,
	Voidwalker = 296,
	PinkMonster = 318,
	StormGatherer = 359,
	SingleKnot = 419,
}

return ShopConfig
