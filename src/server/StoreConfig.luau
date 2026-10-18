--------------------------------------------------
-- STORE CONFIG (SERVER ONLY)
--
-- Ids and reward sizes for the special Robux items. The price that is
-- actually charged is the one set in the Creator Hub; the numbers below
-- are what the SERVER grants. Edit here to rebalance.
--------------------------------------------------

local StoreConfig = {}

-- Captain Oil Server Pack (Developer Product, R$ 2799)
StoreConfig.Captain = {
	ProductId = 3719254046,
	BuyerWins = 150000, -- the captain (buyer) gets the most
	OthersWins = 25000, -- everyone else in the server, as a thank-you from the captain
	BuyerBoostSeconds = 60 * 60, -- x2 oil, x2 wins and CAPTAIN x3 for the buyer
	ServerBoostSeconds = 30 * 60, -- the same boosts for the whole server
	BadgeId = 3538420544972784,
}

-- Skip one quest (Developer Product, R$ 29)
StoreConfig.QuestSkip = { ProductId = 3719263200 }

-- Skip a rebirth (Developer Product, R$ 46)
StoreConfig.RebirthSkip = { ProductId = 3719261487 }

-- Starter Pack (Game Pass, R$ 18). One-time grant, then it is just owned.
StoreConfig.StarterPack = {
	PassId = 2036403334,
	Wins = 10000,
	BoostSeconds = 20 * 60, -- x2 oil and x2 wins
}

-- Badges awarded by BadgeService
StoreConfig.Badges = {
	Welcome = 387745787970702,
	Played5 = 267430523252488,
	Played10 = 2036785900227083,
	Played20 = 2691308063858712,
	Captain = StoreConfig.Captain.BadgeId,
}

return StoreConfig
