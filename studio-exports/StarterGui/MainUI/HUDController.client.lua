--------------------------------------------------
-- HUD CONTROLLER
--
-- CLIENT ONLY
--
-- LOCATION:
-- StarterGui
--   > MainUI
--       > HUDController
--
-- PURPOSE:
--
-- Displays server-authoritative player attributes
-- on the MainUI.
--
-- OWNS:
-- - Level display
-- - Oil display
-- - Wins display
-- - Rebirths display
--
-- XP BAR:
--     XPBarController owns XPBar / XPLabel.
--
-- LEVEL-UP:
--     LevelUpController owns level-up animation.
--
-- DOES NOT OWN:
-- - XP calculation
-- - XP progression
-- - Level progression
-- - Oil calculation
-- - Wins calculation
-- - Rebirth calculation
-- - PlayerData
-- - Current run rewards
--
-- SERVER-AUTHORITATIVE ATTRIBUTES:
--
-- Level
-- XP
-- XPIntoLevel
-- XPNeededForLevel
-- LevelProgress
-- Oil
-- Wins
-- Rebirths
-- CurrentOil
-- CollectedOilCount
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService(
		"Players"
	)


--------------------------------------------------
-- PLAYER
--------------------------------------------------

local player =
	Players.LocalPlayer


--------------------------------------------------
-- UI
--------------------------------------------------

local mainUI =
	script.Parent


if not mainUI:IsA("ScreenGui") then

	error(
		"[HUDController] HUDController must be inside a ScreenGui."
	)

end


--------------------------------------------------
-- MAIN FRAME
--------------------------------------------------

local mainFrame =
	mainUI:WaitForChild(
		"MainFrame"
	)


--------------------------------------------------
-- HUD LABELS
--------------------------------------------------

local levelLabel =
	mainFrame:WaitForChild(
		"LevelLabel"
	)


local oilLabel =
	mainFrame:WaitForChild(
		"OilLabel"
	)


local winsLabel =
	mainFrame:WaitForChild(
		"WinsLabel"
	)


local rebirthsLabel =
	mainFrame:WaitForChild(
		"RebirthsLabel"
	)


--------------------------------------------------
-- SAFE NUMBER
--
-- Client-side validation only.
--
-- The client never calculates progression.
--------------------------------------------------

local function getSafeNumber(
	value,
	defaultValue
)

	if typeof(value) ~= "number" then

		return defaultValue

	end


	if value ~= value then

		return defaultValue

	end


	if value == math.huge
		or value == -math.huge then

		return defaultValue

	end


	return value

end


--------------------------------------------------
-- GET INTEGER ATTRIBUTE
--------------------------------------------------

local function getSafeInteger(
	attributeName,
	defaultValue,
	minimum
)

	local value =
		getSafeNumber(
			player:GetAttribute(
				attributeName
			),
			defaultValue
		)


	value =
		math.floor(
			value
		)


	if minimum ~= nil then

		value =
			math.max(
				minimum,
				value
			)

	end


	return value

end


--------------------------------------------------
-- GET PERSISTENT OIL
--
-- IMPORTANT:
--
-- Oil = persistent player oil.
--
-- CurrentOil = temporary current-run oil.
--
-- The main HUD displays persistent Oil.
--------------------------------------------------

local function getPersistentOil()

	return getSafeInteger(
		"CurrentOil",
		0,
		0
	)

end


--------------------------------------------------
-- UPDATE LEVEL
--
-- Level is completely server-authoritative.
--
-- This controller only displays it.
--------------------------------------------------

local function updateLevel()

	local level =
		getSafeInteger(
			"Level",
			1,
			1
		)


	levelLabel.Text =
		"LEVEL "
		..
		tostring(
			level
		)

end


--------------------------------------------------
-- UPDATE OIL
--
-- Displays persistent Oil.
--
-- DOES NOT use CurrentOil.
--------------------------------------------------

local function updateOil()

	local oil =
		getPersistentOil()


	oilLabel.Text =
		"OIL   "
		..
		tostring(
			oil
		)

end


--------------------------------------------------
-- UPDATE WINS
--------------------------------------------------

local function updateWins()

	local wins =
		getSafeInteger(
			"Wins",
			0,
			0
		)


	winsLabel.Text =
		"WINS   "
		..
		tostring(
			wins
		)

end


--------------------------------------------------
-- UPDATE REBIRTHS
--------------------------------------------------

local function updateRebirths()

	local rebirths =
		getSafeInteger(
			"Rebirths",
			0,
			0
		)


	rebirthsLabel.Text =
		"REBIRTHS   "
		..
		tostring(
			rebirths
		)

end


--------------------------------------------------
-- UPDATE HUD
--
-- This function ONLY reads attributes.
--
-- No client-side progression calculations.
--------------------------------------------------

local function updateHUD()

	updateLevel()

	updateOil()

	updateWins()

	updateRebirths()

end


--------------------------------------------------
-- LEVEL
--------------------------------------------------

player:GetAttributeChangedSignal(
	"Level"
):Connect(
	updateLevel
)


--------------------------------------------------
-- OIL
--------------------------------------------------

player:GetAttributeChangedSignal(
	"CurrentOil"
):Connect(
	updateOil
)


--------------------------------------------------
-- WINS
--------------------------------------------------

player:GetAttributeChangedSignal(
	"Wins"
):Connect(
	updateWins
)


--------------------------------------------------
-- REBIRTHS
--------------------------------------------------

player:GetAttributeChangedSignal(
	"Rebirths"
):Connect(
	updateRebirths
)


--------------------------------------------------
-- CURRENT RUN OIL
--
-- IMPORTANT:
--
-- CurrentOil is NOT displayed as persistent Oil.
--
-- It belongs to the active run and is handled
-- separately by the run/oil systems.
--
-- We intentionally do not update the main
-- OilLabel from this attribute.
--------------------------------------------------

player:GetAttributeChangedSignal(
	"CurrentOil"
):Connect(
	function()

		-- Intentionally ignored.
		--
		-- CurrentOil != persistent Oil.

	end
)


--------------------------------------------------
-- COLLECTION COUNT
--
-- Also intentionally not displayed by this HUD.
--
-- This remains available to other UI/controllers.
--------------------------------------------------

player:GetAttributeChangedSignal(
	"CollectedOilCount"
):Connect(
	function()

		-- Intentionally ignored.

	end
)


--------------------------------------------------
-- INITIAL UPDATE
--------------------------------------------------

updateHUD()


--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"================================"
)

print(
	"[HUDController]",
	"HUD READY"
)

print(
	"[HUDController]",
	"Level source:",
	"Server Attribute"
)

print(
	"[HUDController]",
	"Oil source:",
	"Server Attribute: Oil"
)

print(
	"[HUDController]",
	"Wins source:",
	"Server Attribute"
)

print(
	"[HUDController]",
	"Rebirths source:",
	"Server Attribute"
)

print(
	"[HUDController]",
	"XP calculation:",
	"DISABLED"
)

print(
	"[HUDController]",
	"XP bar ownership:",
	"XPBarController"
)

print(
	"[HUDController]",
	"Level-up animation ownership:",
	"LevelUpController"
)

print(
	"[HUDController]",
	"CurrentOil displayed as persistent Oil:",
	"NO"
)

print(
	"================================"
)
