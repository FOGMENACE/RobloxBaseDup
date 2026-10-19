--------------------------------------------------
-- OIL DEFINITIONS
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > OilSystem
--         > OilDefinitions
--
-- PURPOSE:
--
-- Defines every possible oil platform type.
--
-- NORMAL OIL TYPES:
--
-- Common
-- Uncommon
-- Rare
--
-- These give a random Oil amount.
--
-- MODIFIER TYPES:
--
-- X2
-- X4
-- /2
-- /4
--
-- These DO NOT give a random Oil amount.
--
-- They modify the player's CURRENT RUN OIL
-- when collected.
--
-- OilCourseGenerator reads this module to:
--
-- - Discover every oil type
-- - Validate definitions
-- - Determine rarity weights
-- - Determine platform display
--
-- OilCollectionService reads the same definition
-- to determine the authoritative collection effect.
--
-- CLIENT MUST NEVER REQUIRE THIS MODULE.
--------------------------------------------------


local OilDefinitions = {

	--------------------------------------------------
	-- COMMON
	--
	-- Normal positive Oil.
	--
	-- Random reward:
	-- 120 - 320 (before the per-course scale)
	--------------------------------------------------

	Common = {

		Kind = "Normal",

		MinOil = 120,

		MaxOil = 320,

		Weight = 46,

		Display = "AMOUNT",

	},


	--------------------------------------------------
	-- UNCOMMON
	--
	-- Normal positive Oil.
	--
	-- Random reward:
	-- 380 - 650 (before the per-course scale)
	--------------------------------------------------

	Uncommon = {

		Kind = "Normal",

		MinOil = 380,

		MaxOil = 650,

		Weight = 25,

		Display = "AMOUNT",

	},


	--------------------------------------------------
	-- RARE
	--
	-- Normal positive Oil.
	--
	-- Random reward:
	-- 800 - 1,100 (before the per-course scale)
	--------------------------------------------------

	Rare = {

		Kind = "Normal",

		MinOil = 800,

		MaxOil = 1100,

		Weight = 12,

		Display = "AMOUNT",

	},


	--------------------------------------------------
	-- EPIC
	--
	-- Big oil, rare. Can be positive OR negative.
	-- Random reward: 1,500 - 2,200 (before the per-course scale)
	--------------------------------------------------

	Epic = {

		Kind = "Normal",

		MinOil = 1500,

		MaxOil = 2200,

		Weight = 5,

		Display = "AMOUNT",

		LabelColor = Color3.fromRGB(255, 214, 70),

	},


	--------------------------------------------------
	-- LEGENDARY
	--
	-- The jackpot: only ever a POSITIVE (green) platform, about 1 in 100 platforms.
	-- Random reward: 3,000 - 4,500 (before the per-course scale)
	--------------------------------------------------

	Legendary = {

		Kind = "Normal",

		PositiveOnly = true,

		MinOil = 3000,

		MaxOil = 4500,

		Weight = 2,

		Display = "AMOUNT",

		LabelColor = Color3.fromRGB(255, 120, 215),

	},

	--------------------------------------------------
	-- X2
	--
	-- MULTIPLIER
	--
	-- Takes the player's CURRENT RUN OIL
	-- and multiplies it by 2.
	--
	-- Example:
	--
	-- CurrentOil = 500
	-- X2
	-- Result = 1,000
	--
	-- The platform should display:
	--
	-- X2
	--------------------------------------------------

	X2 = {

		Kind = "Multiplier",

		Weight = 6,

		Multiplier = 2,

		Display = "X2",

	},


	--------------------------------------------------
	-- X4
	--
	-- MULTIPLIER
	--
	-- Takes the player's CURRENT RUN OIL
	-- and multiplies it by 4.
	--
	-- Example:
	--
	-- CurrentOil = 500
	-- X4
	-- Result = 2,000
	--
	-- The platform should display:
	--
	-- X4
	--------------------------------------------------

	X4 = {

		Kind = "Multiplier",

		Weight = 2,

		Multiplier = 4,

		Display = "X4",

	},


	--------------------------------------------------
	-- DIVIDE 2
	--
	-- DIVISOR
	--
	-- Takes the player's CURRENT RUN OIL
	-- and divides it by 2.
	--
	-- Example:
	--
	-- CurrentOil = 500
	-- /2
	-- Result = 250
	--
	-- The platform should display:
	--
	-- /2
	--------------------------------------------------

	Divide2 = {

		Kind = "Divider",

		Weight = 2,

		Divider = 2,

		Display = "/2",

	},


	--------------------------------------------------
	-- DIVIDE 4
	--
	-- DIVISOR
	--
	-- Takes the player's CURRENT RUN OIL
	-- and divides it by 4.
	--
	-- Example:
	--
	-- CurrentOil = 500
	-- /4
	-- Result = 125
	--
	-- The platform should display:
	--
	-- /4
	--------------------------------------------------

	Divide4 = {

		Kind = "Divider",

		Weight = 1,

		Divider = 4,

		Display = "/4",

	},

}


--------------------------------------------------
-- RETURN
--------------------------------------------------

return OilDefinitions