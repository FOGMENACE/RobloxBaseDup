--------------------------------------------------
-- XP KITS (shared)
--
-- Three developer products sell XP "kits". Their size is not fixed: it
-- follows the player's CURRENT level, so every level-up makes the kits
-- bigger (and more tempting).
--
-- Our formula:
--
--     kit XP = XP needed for the current level (drops after a rebirth,
--              because the level resets)
--              x fraction of that kit
--
-- Fractions: kit 1 = a quarter of a level, kit 2 = about one and a half
-- levels, kit 3 = about five and a half levels. Tune FRACTIONS to
-- rebalance; the server uses the same function the client displays, and
-- always recomputes from the player's real data before granting.
--------------------------------------------------

local XPKits = {}

XPKits.Products = {
	{ Name = "XP KIT 1", ProductId = 3719127634 },
	{ Name = "XP KIT 2", ProductId = 3719127707 },
	{ Name = "XP KIT 3", ProductId = 3719129040 },
}

XPKits.FRACTIONS = { 0.28, 1.4, 5.5 }

local MAX_REBIRTH_BONUS = 20
local BONUS_PER_REBIRTH = 0.04

function XPKits.Amount(kit, xpNeededForLevel, rebirths)
	local fraction = XPKits.FRACTIONS[kit]
	xpNeededForLevel = tonumber(xpNeededForLevel) or 0

	if not fraction or xpNeededForLevel <= 0 then
		return 0
	end

	local bonus = 1

	return math.floor(xpNeededForLevel * fraction * bonus)
end

function XPKits.IndexOfProduct(productId)
	for index, product in ipairs(XPKits.Products) do
		if product.ProductId == productId then
			return index
		end
	end

	return nil
end

return XPKits
