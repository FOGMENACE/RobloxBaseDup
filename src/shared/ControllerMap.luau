--------------------------------------------------
-- CONTROLLER MAP (client, shared module)
--
-- The one place that says which controller button does what. Roblox reports every
-- controller with the same button codes: A = Cross, B = Circle, X = Square,
-- Y = Triangle, L1/R1 = LB/RB, Select = View/Share. So Xbox and PlayStation use this
-- same table, and the hints ask Roblox for the icon of the player's own controller.
-- Change a button here and the control and its on-screen hint both follow.
--
-- Leave ButtonX free: it is the default button of interaction prompts.
--------------------------------------------------

local ControllerMap = {}

ControllerMap.Confirm = Enum.KeyCode.ButtonA
ControllerMap.Back = Enum.KeyCode.ButtonB
ControllerMap.Browse = Enum.KeyCode.DPadDown -- never a console's own button
ControllerMap.BrowseAlt = Enum.KeyCode.ButtonSelect -- View / Share / touchpad, where the console lets it through
ControllerMap.FreeCursor = Enum.KeyCode.ButtonL3 -- a fast double press
ControllerMap.Move = Enum.KeyCode.Thumbstick1

-- Shortcuts in the lobby. Action names are the ones ConsoleControls knows how to run;
-- Tile is the hub button that shows this shortcut's icon.
ControllerMap.Shortcuts = {
	{ Action = "Store", Key = Enum.KeyCode.ButtonY, Tile = "ShopButton" },
	{ Action = "Quests", Key = Enum.KeyCode.DPadUp, Tile = "QuestsButton" },
	{ Action = "Rebirth", Key = Enum.KeyCode.ButtonR1, Tile = "RebirthButton" },
	{ Action = "Daily", Key = Enum.KeyCode.ButtonL1, Tile = "DailyButton" },
}

return ControllerMap
