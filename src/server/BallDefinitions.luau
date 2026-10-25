--------------------------------------------------
-- BALL DEFINITIONS
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > BallDefinitions
--
-- PURPOSE:
--
-- Authoritative server-side definition registry
-- for every bowling ball.
--
-- IMPORTANT:
--
-- DO NOT PUT THIS MODULE IN REPLICATEDSTORAGE.
--
-- Clients should never be trusted with:
-- - WinsCost
-- - RequiredRebirths
-- - ForwardSpeed
-- - HorizontalSpeed
--
-- The client may DISPLAY these values if the server
-- sends them, but the server is always authoritative.
--
-- DeveloperProductIds are intentionally NOT stored
-- here. They belong in the separate server-only
-- BallProductDefinitions module.
--
--------------------------------------------------

local BallDefinitions = {

	--------------------------------------------------
	-- BALL 1
	-- DEFAULT / FREE BALL
	--------------------------------------------------

	StraightBall = {

		DisplayName =
			"Straight Ball",

		ForwardSpeed =
			50,

		HorizontalSpeed =
			50,

		WinsCost =
			0,

		RequiredRebirths =
			0,

		DisplayOrder =
			1,
	},


	--------------------------------------------------
	-- BALL 2
	-- TUTORIAL BALL
	--------------------------------------------------

	Aftershock = {

		DisplayName =
			"Aftershock",

		ForwardSpeed =
			55,

		HorizontalSpeed =
			55,

		WinsCost =
			24,

		RequiredRebirths =
			0,

		IsTutorial =
			true,

		DisplayOrder =
			2,
	},


	--------------------------------------------------
	-- BALL 3
	--------------------------------------------------

	CatPlz = {

		DisplayName =
			"Cat plz",

		ForwardSpeed =
			60,

		HorizontalSpeed =
			60,

		WinsCost =
			850,

		RequiredRebirths =
			2,

		DisplayOrder =
			3,
	},


	--------------------------------------------------
	-- BALL 4
	--------------------------------------------------

	Thrifty = {

		DisplayName =
			"Thrifty",

		ForwardSpeed =
			65,

		HorizontalSpeed =
			65,

		WinsCost =
			3500,

		RequiredRebirths =
			3,

		DisplayOrder =
			4,
	},


	--------------------------------------------------
	-- BALL 5
	--------------------------------------------------

	Voltage = {

		DisplayName =
			"Voltage",

		ForwardSpeed =
			70,

		HorizontalSpeed =
			70,

		WinsCost =
			7000,

		RequiredRebirths =
			3,

		DisplayOrder =
			5,
	},


	--------------------------------------------------
	-- BALL 6
	--------------------------------------------------

	Venom = {

		DisplayName =
			"Venom",

		ForwardSpeed =
			75,

		HorizontalSpeed =
			75,

		WinsCost =
			11000,

		RequiredRebirths =
			3,

		DisplayOrder =
			6,
	},


	--------------------------------------------------
	-- BALL 7
	--------------------------------------------------

	SnotOoze = {

		DisplayName =
			"Snot Ooze",

		ForwardSpeed =
			80,

		HorizontalSpeed =
			80,

		WinsCost =
			22000,

		RequiredRebirths =
			4,

		DisplayOrder =
			7,
	},


	--------------------------------------------------
	-- BALL 8
	--------------------------------------------------

	Meteor = {

		DisplayName =
			"Meteor",

		ForwardSpeed =
			85,

		HorizontalSpeed =
			85,

		WinsCost =
			41000,

		RequiredRebirths =
			4,

		DisplayOrder =
			8,
	},


	--------------------------------------------------
	-- BALL 9
	--------------------------------------------------

	AttitudePausible = {

		DisplayName =
			"Attitude Pausible",

		ForwardSpeed =
			90,

		HorizontalSpeed =
			90,

		WinsCost =
			68000,

		RequiredRebirths =
			5,

		DisplayOrder =
			9,
	},


	--------------------------------------------------
	-- BALL 10
	--------------------------------------------------

	GreenNature = {

		DisplayName =
			"Green Nature",

		ForwardSpeed =
			95,

		HorizontalSpeed =
			95,

		WinsCost =
			105000,

		RequiredRebirths =
			5,

		DisplayOrder =
			10,
	},


	--------------------------------------------------
	-- BALL 11
	--------------------------------------------------

	Detailo = {

		DisplayName =
			"Detailo",

		ForwardSpeed =
			100,

		HorizontalSpeed =
			100,

		WinsCost =
			170000,

		RequiredRebirths =
			6,

		DisplayOrder =
			11,
	},


	--------------------------------------------------
	-- BALL 12
	--------------------------------------------------

	NeonVestOff = {

		DisplayName =
			"Neon VestOff",

		ForwardSpeed =
			105,

		HorizontalSpeed =
			105,

		WinsCost =
			250000,

		RequiredRebirths =
			6,

		DisplayOrder =
			12,
	},


	--------------------------------------------------
	-- BALL 13
	--------------------------------------------------

	StarDoodle = {

		DisplayName =
			"Star Doodle",

		ForwardSpeed =
			110,

		HorizontalSpeed =
			110,

		WinsCost =
			380000,

		RequiredRebirths =
			7,

		DisplayOrder =
			13,
	},


	--------------------------------------------------
	-- BALL 14
	--------------------------------------------------

	PainMoon = {

		DisplayName =
			"Pain Moon",

		ForwardSpeed =
			115,

		HorizontalSpeed =
			115,

		WinsCost =
			580000,

		RequiredRebirths =
			8,

		DisplayOrder =
			14,
	},


	--------------------------------------------------
	-- BALL 15
	--------------------------------------------------

	VoidMinter = {

		DisplayName =
			"Void Minter",

		ForwardSpeed =
			120,

		HorizontalSpeed =
			120,

		WinsCost =
			850000,

		RequiredRebirths =
			9,

		DisplayOrder =
			15,
	},


	--------------------------------------------------
	-- BALL 16
	--------------------------------------------------

	Voidwalker = {

		DisplayName =
			"Voidwalker",

		ForwardSpeed =
			125,

		HorizontalSpeed =
			125,

		WinsCost =
			1200000,

		RequiredRebirths =
			10,

		DisplayOrder =
			16,
	},


	--------------------------------------------------
	-- BALL 17
	--------------------------------------------------

	PinkMonster = {

		DisplayName =
			"Pink Monster",

		ForwardSpeed =
			130,

		HorizontalSpeed =
			130,

		WinsCost =
			1800000,

		RequiredRebirths =
			11,

		DisplayOrder =
			17,
	},


	--------------------------------------------------
	-- BALL 18
	--------------------------------------------------

	StormGatherer = {

		DisplayName =
			"Storm Gatherer",

		ForwardSpeed =
			135,

		HorizontalSpeed =
			135,

		WinsCost =
			2600000,

		RequiredRebirths =
			12,

		DisplayOrder =
			18,
	},


	--------------------------------------------------
	-- BALL 19
	--------------------------------------------------

	SingleKnot = {

		DisplayName =
			"Single Knot",

		ForwardSpeed =
			140,

		HorizontalSpeed =
			140,

		WinsCost =
			3800000,

		RequiredRebirths =
			13,

		DisplayOrder =
			19,
	},


	--------------------------------------------------
	-- EXCLUSIVE: OIL BARREL
	--
	-- Not for sale with wins or a Developer Product. Owned through the
	-- Game Pass, the Captain Oil Server Pack, or the day-7 calendar
	-- reward (all granted by the server). WinsCost is a huge placeholder
	-- so the normal wins purchase can never succeed, and
	-- IsExclusive = true makes BallService refuse it outright.
	--------------------------------------------------

	OilBarrel = {

		DisplayName =
			"Oil Barrel",

		ForwardSpeed =
			150,

		HorizontalSpeed =
			150,

		WinsCost =
			999999999,

		RequiredRebirths =
			0,

		DisplayOrder =
			20,

		IsExclusive =
			true,
	},
}


--------------------------------------------------
-- VALIDATION
--
-- Catch configuration mistakes immediately
-- during server startup.
--------------------------------------------------

for ballId, definition in pairs(BallDefinitions) do

	assert(
		type(definition.DisplayName) == "string",
		"[BallDefinitions] Invalid DisplayName for " .. ballId
	)

	assert(
		type(definition.ForwardSpeed) == "number",
		"[BallDefinitions] Invalid ForwardSpeed for " .. ballId
	)

	assert(
		type(definition.HorizontalSpeed) == "number",
		"[BallDefinitions] Invalid HorizontalSpeed for " .. ballId
	)

	assert(
		type(definition.WinsCost) == "number",
		"[BallDefinitions] Invalid WinsCost for " .. ballId
	)

	assert(
		type(definition.RequiredRebirths) == "number",
		"[BallDefinitions] Invalid RequiredRebirths for " .. ballId
	)

	assert(
		type(definition.DisplayOrder) == "number",
		"[BallDefinitions] Invalid DisplayOrder for " .. ballId
	)

end

return BallDefinitions
