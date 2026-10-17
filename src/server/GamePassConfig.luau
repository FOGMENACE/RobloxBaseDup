--------------------------------------------------
-- GAME PASS CONFIG (SERVER ONLY)
--
-- Lives in ServerScriptService, so clients can never read it.
-- Multiplier passes: their total is published as the PassXPMultiplier
-- attribute (display only; the server never reads it back).
--------------------------------------------------

local GamePassConfig = {}

-- Generator part name -> Game Pass id required to earn XP on it.
GamePassConfig.AdminGenerators = {
	["GenX100 Admin XP"] = 2039936926,
	["GenX1000 Admin XP"] = 2036355132,
}

-- Silent passes: Game Pass id -> XP multiplier (applies everywhere).
-- If a player owns several, the highest one applies.
GamePassConfig.SecretMultipliers = {
	[2039960889] = 2200,
	[2037033103] = 360,
	[2036415199] = 240,
	[2040578649] = 1900,
}

return GamePassConfig
