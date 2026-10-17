--------------------------------------------------
-- AUDIO CONFIG
--
-- Music for each part of the game. Swap any id here; MusicController
-- picks them up. An empty id means "no music for that scene".
--
-- These were chosen from free Creator Store tracks by title and
-- description only; audition them in Studio and replace any you do
-- not like.
--------------------------------------------------

local AudioConfig = {}

AudioConfig.Music = {
	-- "High Five Happy (c)" (APM Music, cheerful pop, ~112s)
	Lobby = {
		SoundId = "rbxassetid://9045803411",
		Volume = 0.45,
	},

	-- "Fast Paced DnB for Gaming Sessions" (DistroKid)
	Course = { -- shared by the OilCourse and the WinCourse
		SoundId = "rbxassetid://128760779305846",
		Volume = 0.5,
	},

}

-- Default master level for the player's music control (0..1).
AudioConfig.DefaultMasterVolume = 0.7

-- How loud music gets while the window is not focused.
AudioConfig.UnfocusedMultiplier = 0.1

-- When focus returns the music swells above normal, then settles.
AudioConfig.RefocusBoost = 1.3

return AudioConfig
