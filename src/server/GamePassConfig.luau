--------------------------------------------------
-- GAME PASS CONFIG (SERVER ONLY)
--
-- Lives in ServerScriptService, so clients can never read it.
-- The silent multiplier passes are intentionally NOT shown in any UI
-- and have no generator.
--------------------------------------------------

local GamePassConfig = {}

-- Generator part name -> Game Pass id required to earn XP on it.
GamePassConfig.AdminGenerators = {
	["GenX100 Admin XP"] = 2038347056,
	["GenX1000 Admin XP"] = 2036523093,
}

-- Silent passes: Game Pass id -> XP multiplier (applies everywhere).
-- If a player owns several, the highest one applies.
GamePassConfig.SecretMultipliers = {
	[2040686570] = 2200,
	[2037333067] = 360,
	[2040152655] = 240,
	[2038023070] = 1900,
}

return GamePassConfig
