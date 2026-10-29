--------------------------------------------------
-- REBIRTH COLORS (shared, display only)
--
-- The colour of a player's rebirth number, by rebirth zone. Used by the ball
-- name tags and the purchase announcements in chat, so both always match.
--------------------------------------------------

local RebirthColors = {}

RebirthColors.Zones = {
	{ From = 0, Color = Color3.fromRGB(150, 235, 90) }, -- lime
	{ From = 5, Color = Color3.fromRGB(80, 220, 230) }, -- aqua
	{ From = 10, Color = Color3.fromRGB(100, 150, 255) }, -- blue
	{ From = 20, Color = Color3.fromRGB(190, 120, 255) },
	{ From = 40, Color = Color3.fromRGB(255, 200, 70) },
	{ From = 75, Color = Color3.fromRGB(255, 90, 130) },
}

function RebirthColors.Get(rebirths)
	local color = RebirthColors.Zones[1].Color
	for _, zone in ipairs(RebirthColors.Zones) do
		if (rebirths or 0) >= zone.From then
			color = zone.Color
		end
	end
	return color
end

function RebirthColors.Hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

return RebirthColors
