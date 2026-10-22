--------------------------------------------------
-- ADMIN CONFIG (SERVER ONLY)
--
-- Lives in ServerScriptService, so clients can never read it. Admin status
-- is decided ONLY from this list of numeric Roblox UserIds on the server;
-- nothing a client sends can grant it.
--
-- To add / remove an admin, edit the list below and republish. UserIds,
-- not names (names can change).
--------------------------------------------------

local AdminConfig = {}

AdminConfig.Admins = {
	[50333721] = "owner (Studio account)",
	[4467315] = "owner 2",
}

-- Admin commands can only be used while the server is running; every
-- destructive command needs a typed confirmation code (see AdminService).
AdminConfig.ConfirmSeconds = 60

-- Extra safety: resets may only target these UserIds unless this is nil.
-- Leave as an empty table to allow any UserId (after confirmation), or fill
-- it with TEST accounts while you are still testing so a typo cannot reset
-- a real player.
AdminConfig.ResetAllowList = nil -- e.g. { [123456789] = true }

-- ExploitWatch: progress between two 5-minute snapshots above these limits is
-- FLAGGED for review (never auto-punished). Tune after launch from real players'
-- "history": set each a bit above the best honest rate you see.
AdminConfig.WatchLimits = {
	WinsPerMinute = 2000000, -- late-game x2 wins + passes can be very high; adjust
	RebirthsPerSnapshot = 6, -- more than 6 rebirths in 5 minutes
	LevelsPerSnapshot = 3000, -- global levels in 5 minutes
}

-- give <player> wins|oil <amount>: the largest single support grant
AdminConfig.MaxGrant = 10000000

return AdminConfig
