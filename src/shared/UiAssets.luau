--------------------------------------------------
-- UI ASSETS
--
-- Roblox image asset ids used by the HUD and generators.
--
-- The oil PNGs in assets/textures/ must be UPLOADED to Roblox first
-- (Creator Hub -> Assets, or Studio Asset Manager -> Bulk Import),
-- then paste the ids here as "rbxassetid://123456789".
--
-- While an id is empty the UI draws a simple oil droplet instead, so
-- nothing breaks; the real image appears as soon as the id is set.
--------------------------------------------------

local UiAssets = {}

UiAssets.OilImages = {
	-- assets/textures/dangerousblackoil spill.png
	Black = "rbxassetid://97000428428004",
	-- assets/textures/dangerousyellowdarkenoil spill.png
	Yellow = "rbxassetid://87174949328054",
	-- assets/textures/dangerousgreendarkenoil spill.png
	Green = "rbxassetid://75803779771688",
}

UiAssets.TrophyImage = "rbxassetid://135956636242633"

return UiAssets
