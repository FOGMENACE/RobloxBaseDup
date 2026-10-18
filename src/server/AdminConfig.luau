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

return AdminConfig
