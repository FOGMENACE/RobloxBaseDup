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
	{ Name = "STARTER PACK", Description = "One-time bundle: 10,000 wins + x2 oil and x2 wins for 20 minutes.", PassId = 2036403334 },
	{ Name = "X100 LESSONS", Description = "Earn 100x XP on the Admin x100 generator.", PassId = 2039936926 },
	{ Name = "X1000 MOST WANTED LESSONS", Description = "Earn 1000x XP on the Admin x1000 generator.", PassId = 2036355132 },
}

-- Exclusive balls sold ONLY for Robux as a Game Pass (never for wins).
-- PassId 0 = "coming soon": the buy button stays disabled. Paste the real
-- Game Pass id here and the server (ExclusiveBallService) and both shop
-- screens pick it up. The ball is also given by the Captain Oil Server
-- Pack and by the day-7 calendar reward.
ShopConfig.ExclusiveBalls = {
	OilBarrel = {
		BallId = "OilBarrel",
		DisplayName = "OIL BARREL",
		PassId = 2036487321,
		Price = 499,
	},
}

-- Captain Oil Server Pack display prices (labels only; the charged price is the
-- developer product's). The owner price is the full price minus the barrel's.
ShopConfig.CaptainPrice = 2799
ShopConfig.CaptainOwnerPrice = 2799 - ShopConfig.ExclusiveBalls.OilBarrel.Price

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
