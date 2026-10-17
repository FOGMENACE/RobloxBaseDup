--------------------------------------------------
-- BOOST CONFIG (shared)
--
-- Timed boosts sold as developer products (R$ 4) and given as rewards.
--
--   Oil2x  : x2 oil from every gain          (paid)
--   Wins2x : x2 wins from the WinCourse      (paid)
--   XP4    : x4 XP while rolling             (leave-reward / gifts)
--
-- ProductId = 0 means "not set up yet": the buttons show SOON and cannot
-- be bought. Paste the real Developer Product ids here.
--
-- A developer product cannot be "owned", so the boost lasts Duration
-- seconds after purchase (saved with absolute timestamps, so leaving and
-- rejoining neither loses nor extends it). Buying again adds time.
--------------------------------------------------

local BoostConfig = {}

BoostConfig.Boosts = {
	Oil2x = {
		Label = "x2 OIL",
		Multiplier = 2,
		ProductId = 3719137352,
		Duration = 30 * 60,
		PriceRobux = 4,
	},
	Wins2x = {
		Label = "x2 WINS",
		Multiplier = 2,
		ProductId = 3719137383,
		Duration = 30 * 60,
		PriceRobux = 4,
	},
	XP4 = {
		Label = "x4 XP",
		Multiplier = 4,
		ProductId = 0, -- reward only, never sold
		Duration = 8 * 60,
	},
}

function BoostConfig.KeyOfProduct(productId)
	if typeof(productId) ~= "number" or productId == 0 then
		return nil
	end

	for key, boost in pairs(BoostConfig.Boosts) do
		if boost.ProductId == productId and boost.PriceRobux then
			return key
		end
	end

	return nil
end

return BoostConfig
