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

-- Stronger admin generators in the higher worlds (WorldConfig.Admin has the
-- multipliers). Paste each Game Pass id when it is created; 0 = not on sale.
GamePassConfig.WorldAdminGenerators = {
	[2] = { ["GenX100 Admin XP"] = 2036415199, ["GenX1000 Admin XP"] = 2040578649 }, -- x240 R$ 575 / x1900 R$ 1,650
	[3] = { ["GenX100 Admin XP"] = 2037033103, ["GenX1000 Admin XP"] = 2039960889 }, -- x360 R$ 710 / x2200 R$ 1,899
	[4] = { ["GenX100 Admin XP"] = 2036387283, ["GenX1000 Admin XP"] = 2039765108 }, -- x490 R$ 869 / x2800 R$ 2,299
}

-- Silent passes: Game Pass id -> XP multiplier (applies everywhere).
-- If a player owns several, the highest one applies.
GamePassConfig.SecretMultipliers = {
	[2039960889] = 2200,
	[2037033103] = 360,
	[2036415199] = 240,
	[2040578649] = 1900,
	[2036387283] = 490,
	[2039765108] = 2800,
}

return GamePassConfig
