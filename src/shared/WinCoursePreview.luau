--[[
	WinCoursePreview

	LOCATION:
	ReplicatedStorage
		> WinCoursePreview (ModuleScript)

	PURPOSE:
	Read-only Win Course preview data.

	SECURITY:
	- Does NOT generate the real Win Course.
	- Does NOT fire StartWinCourse.
	- Does NOT modify Workspace.
	- Safe for client-side display/data usage.
	- Actual Win Course generation remains server-authoritative.

	IMPORTANT:
	This module contains DATA ONLY.

	The actual WinTile template is responsible for its
	visual hierarchy.

	CURRENT WIN TILE LAYOUT:

	WinTile
	├── Floor
	│
	└── TrophyDisplay
	    └── SurfaceGui
	        ├── ImageLabel
	        └── WinAmount

	Notes:
	- Floor is the actual colored floor part.
	- No ColorOverlay is used.
	- TrophyDisplay is a separate BasePart.
	- SurfaceGui belongs to TrophyDisplay.
	- ImageLabel is a direct child of SurfaceGui.
	- WinAmount is a direct child of SurfaceGui.
	- ImageLabel displays the trophy.
	- WinAmount displays the win amount.

	This module does NOT create, configure, or manipulate
	any of those objects.
]]

local WinCoursePreview = {}

----------------------------------------------------------------
-- WIN AMOUNTS
--
-- MUST MATCH:
-- WinCourseGenerator.WIN_AMOUNTS
----------------------------------------------------------------

WinCoursePreview.WIN_AMOUNTS = {

	1,
	2,
	3,
	5,
	7,
	10,
	15,
	20,
	25,
	30,
	35,
	40,

}

----------------------------------------------------------------
-- LAYOUT
--
-- MUST MATCH:
-- WinCourseGenerator.TILE_SPACING
----------------------------------------------------------------

WinCoursePreview.TILE_SPACING = 43

----------------------------------------------------------------
-- TILE COUNT
----------------------------------------------------------------

WinCoursePreview.TILE_COUNT =
	#WinCoursePreview.WIN_AMOUNTS

----------------------------------------------------------------
-- TILE INDICES
----------------------------------------------------------------

WinCoursePreview.FIRST_TILE_INDEX = 1

WinCoursePreview.LAST_TILE_INDEX =
	#WinCoursePreview.WIN_AMOUNTS

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--------------------------------------------------
-- GET ALL WIN AMOUNTS
--------------------------------------------------

function WinCoursePreview.GetWinAmounts()

	local result =
		table.create(
			#WinCoursePreview.WIN_AMOUNTS
		)

	for index, amount in ipairs(
		WinCoursePreview.WIN_AMOUNTS
	) do

		result[index] =
			amount

	end

	return result

end

--------------------------------------------------
-- GET TILE COUNT
--------------------------------------------------

function WinCoursePreview.GetTileCount()

	return #WinCoursePreview.WIN_AMOUNTS

end

--------------------------------------------------
-- GET TILE SPACING
--------------------------------------------------

function WinCoursePreview.GetTileSpacing()

	return WinCoursePreview.TILE_SPACING

end

--------------------------------------------------
-- GET AMOUNT BY INDEX
--------------------------------------------------

function WinCoursePreview.GetAmount(index)

	if typeof(index) ~= "number" then

		return nil

	end

	index =
		math.floor(index)

	if index < 1
		or index > #WinCoursePreview.WIN_AMOUNTS then

		return nil

	end

	return WinCoursePreview.WIN_AMOUNTS[index]

end

--------------------------------------------------
-- GET INDEX FOR AMOUNT
--------------------------------------------------

function WinCoursePreview.GetIndexForAmount(amount)

	if typeof(amount) ~= "number" then

		return nil

	end

	for index, value in ipairs(
		WinCoursePreview.WIN_AMOUNTS
	) do

		if value == amount then

			return index

		end

	end

	return nil

end

----------------------------------------------------------------
-- TILE DATA
----------------------------------------------------------------

--------------------------------------------------
-- GET TILE DATA
--
-- The real generator positions tiles using:
--
-- START_POSITION
-- +
-- Vector3.new(
--     0,
--     0,
--     (index - 1) * TILE_SPACING
-- )
--
-- This module only provides the matching offset.
--------------------------------------------------

function WinCoursePreview.GetTileData(index)

	local amount =
		WinCoursePreview.GetAmount(index)

	if amount == nil then

		return nil

	end

	local offset =
		(index - 1)
		*
		WinCoursePreview.TILE_SPACING

	return {

		Index =
			index,

		Amount =
			amount,

		DisplayText =
			"+" .. tostring(amount),

		Offset =
			offset,

		ZOffset =
			offset,

		IsRainbow =
			amount == 40,

		IsFirstTile =
			index ==
			WinCoursePreview.FIRST_TILE_INDEX,

		IsLastTile =
			index ==
			WinCoursePreview.LAST_TILE_INDEX,

	}

end

--------------------------------------------------
-- GET ALL TILE DATA
--------------------------------------------------

function WinCoursePreview.GetAllTileData()

	local result =
		table.create(
			#WinCoursePreview.WIN_AMOUNTS
		)

	for index = 1,
		#WinCoursePreview.WIN_AMOUNTS do

		result[index] =
			WinCoursePreview.GetTileData(
				index
			)

	end

	return result

end

----------------------------------------------------------------
-- VALIDATION
----------------------------------------------------------------

--------------------------------------------------
-- VALIDATE WIN AMOUNT
--------------------------------------------------

function WinCoursePreview.IsValidAmount(amount)

	if typeof(amount) ~= "number" then

		return false

	end

	for _, validAmount in ipairs(
		WinCoursePreview.WIN_AMOUNTS
	) do

		if amount == validAmount then

			return true

		end

	end

	return false

end

--------------------------------------------------
-- VALIDATE TILE INDEX
--------------------------------------------------

function WinCoursePreview.IsValidIndex(index)

	if typeof(index) ~= "number" then

		return false

	end

	index =
		math.floor(index)

	return (
		index >= 1
		and index <=
			#WinCoursePreview.WIN_AMOUNTS
	)

end

----------------------------------------------------------------
-- GET OFFSET
----------------------------------------------------------------

function WinCoursePreview.GetOffset(index)

	if not WinCoursePreview.IsValidIndex(index) then

		return nil

	end

	return (
		index - 1
	)
	*
	WinCoursePreview.TILE_SPACING

end

----------------------------------------------------------------
-- GET TILE NAME
--
-- Matches WinCourseGenerator:
--
-- WinTile_1
-- WinTile_2
-- WinTile_3
-- ...
-- WinTile_40
----------------------------------------------------------------

function WinCoursePreview.GetTileName(index)

	local amount =
		WinCoursePreview.GetAmount(index)

	if amount == nil then

		return nil

	end

	return (
		"WinTile_"
		..
		tostring(amount)
	)

end

----------------------------------------------------------------
-- GET TILE NAME FROM AMOUNT
----------------------------------------------------------------

function WinCoursePreview.GetTileNameFromAmount(amount)

	if not WinCoursePreview.IsValidAmount(
		amount
	) then

		return nil

	end

	return (
		"WinTile_"
		..
		tostring(amount)
	)

end

----------------------------------------------------------------
-- RAINBOW
--
-- The 40 tile is the rainbow tile.
--
-- The actual visual rainbow behavior belongs to
-- WinCourseGenerator / the tile itself.
----------------------------------------------------------------

function WinCoursePreview.IsRainbowAmount(amount)

	return amount == 40

end

--------------------------------------------------

function WinCoursePreview.IsRainbowIndex(index)

	local amount =
		WinCoursePreview.GetAmount(index)

	if amount == nil then

		return false

	end

	return amount == 40

end

----------------------------------------------------------------
-- TILE LAYOUT INFORMATION
--
-- EXACT HIERARCHY:
--
-- WinTile
-- ├── Floor
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
----------------------------------------------------------------

function WinCoursePreview.GetLayout()

	return {

		TileCount =
			#WinCoursePreview.WIN_AMOUNTS,

		TileSpacing =
			WinCoursePreview.TILE_SPACING,

		FirstTileIndex =
			WinCoursePreview.FIRST_TILE_INDEX,

		LastTileIndex =
			WinCoursePreview.LAST_TILE_INDEX,

		WinAmounts =
			WinCoursePreview.GetWinAmounts(),

		--------------------------------------------------
		-- TILE HIERARCHY
		--------------------------------------------------

		FloorName =
			"Floor",

		TrophyDisplayName =
			"TrophyDisplay",

		SurfaceGuiName =
			"SurfaceGui",

		ImageLabelName =
			"ImageLabel",

		WinAmountName =
			"WinAmount",

	}

end

----------------------------------------------------------------
-- IMMUTABLE-STYLE SNAPSHOT
--
-- Returns a fresh copy.
----------------------------------------------------------------

function WinCoursePreview.GetSnapshot()

	return {

		TileCount =
			#WinCoursePreview.WIN_AMOUNTS,

		WinAmounts =
			WinCoursePreview.GetWinAmounts(),

		TileSpacing =
			WinCoursePreview.TILE_SPACING,

		FirstTileIndex =
			WinCoursePreview.FIRST_TILE_INDEX,

		LastTileIndex =
			WinCoursePreview.LAST_TILE_INDEX,

		--------------------------------------------------
		-- TILE HIERARCHY
		--------------------------------------------------

		FloorName =
			"Floor",

		TrophyDisplayName =
			"TrophyDisplay",

		SurfaceGuiName =
			"SurfaceGui",

		ImageLabelName =
			"ImageLabel",

		WinAmountName =
			"WinAmount",

	}

end

----------------------------------------------------------------
-- RETURN
----------------------------------------------------------------

return WinCoursePreview
