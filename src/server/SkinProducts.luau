--------------------------------------------------
-- SKIN PRODUCTS (SERVER ONLY)
--
-- One Developer Product per evolved ball per world (named e.g. "Pro Alley Voltage", so the
-- Robux purchase prompt shows the right ball). [ballId] = { [worldId] = productId }.
-- 0 = not created: the shop shows the price but the button only says it opens soon.
-- The server decides what a purchase grants from its own pending record and checks that the
-- product bought is the one for that ball and world.
--
-- World 2 = Pro Alley, 3 = Master Arena, 4 = GrandMaster.
--------------------------------------------------

return {
	StraightBall = { [2] = 3720931609, [3] = 3720934362, [4] = 3720938613 },
	Aftershock = { [2] = 3720931860, [3] = 3720934407, [4] = 3720938696 },
	CatPlz = { [2] = 3720931998, [3] = 3720934605, [4] = 3720938803 },
	Thrifty = { [2] = 3720932156, [3] = 3720934692, [4] = 3720938893 },
	Voltage = { [2] = 3720932309, [3] = 3720934785, [4] = 3720938972 },
	Venom = { [2] = 3720932418, [3] = 3720934925, [4] = 3720939541 },
	SnotOoze = { [2] = 3720932647, [3] = 3720935060, [4] = 3720939640 },
	Meteor = { [2] = 3720932764, [3] = 3720935191, [4] = 3720939834 },
	AttitudePausible = { [2] = 3720932968, [3] = 3720935374, [4] = 3720939932 },
	GreenNature = { [2] = 3720933006, [3] = 3720935494, [4] = 3720940046 },
	Detailo = { [2] = 3720933036, [3] = 3720935597, [4] = 3720940327 },
	NeonVestOff = { [2] = 3720933096, [3] = 3720935708, [4] = 3720940434 },
	StarDoodle = { [2] = 3720933165, [3] = 3720935801, [4] = 3720940682 },
	PainMoon = { [2] = 3720933249, [3] = 3720935902, [4] = 3720940781 },
	VoidMinter = { [2] = 3720933336, [3] = 3720935945, [4] = 3720940921 },
	Voidwalker = { [2] = 3720933454, [3] = 3720935975, [4] = 3720941231 },
	PinkMonster = { [2] = 3720933518, [3] = 3720936067, [4] = 3720941668 },
	StormGatherer = { [2] = 3720933642, [3] = 3720936132, [4] = 3720941746 },
	SingleKnot = { [2] = 3720933778, [3] = 3720936180, [4] = 3720941826 },
	OilBarrel = { [2] = 3720933934, [3] = 3720936254, [4] = 3720941912 },
}
