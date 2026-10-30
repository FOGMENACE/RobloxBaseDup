--------------------------------------------------
-- CONSOLE CONTROLS (client, controller only)
--
-- Moving and jumping use the normal controls. This handles everything else, built
-- around one rule, because a selected button takes the stick and A away from the ball:
--   PLAYING   nothing is selected: the stick rolls the ball, A jumps
--   BROWSING  a button is selected: only while a menu or tutorial card is up, on a
--             tutorial spotlight, or after pressing Browse to reach the HUD buttons
-- Inside a menu the D-pad moves between buttons and the left stick turns on Roblox's
-- free cursor. With no menu open it is forced off, unless the player double tapped Browse,
-- BrowseAlt or L3 for it. Roblox's Plus window gets a card behind it that is cursor only (HubUI).
-- Buttons live in ControllerMap. Nothing here changes for mouse, keyboard or touch, and
-- every action opens the same panels as tapping, so the server's checks still apply.
--------------------------------------------------

local GamepadService = game:GetService("GamepadService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ControllerMap = require(ReplicatedStorage:WaitForChild("ControllerMap"))
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SELECTION_GROUP = "ConsoleMenu"
local GOLD = Color3.fromRGB(255, 214, 70)
local INK = Color3.fromRGB(24, 22, 34)

-- Browsing is handled below, so Roblox must not also pick a button by itself
GuiService.AutoSelectGuiEnabled = false

local function isGamepad(inputType)
	return inputType.Name:sub(1, 7) == "Gamepad"
end

-- a console has no mouse or keyboard, so it is in controller mode from the first frame
local usingGamepad = isGamepad(UserInputService:GetLastInputType())
	or (UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.TouchEnabled)

--------------------------------------------------
-- SELECTION HIGHLIGHT
--------------------------------------------------

local highlight = Instance.new("Frame")
highlight.Name = "ControllerHighlight"
highlight.Size = UDim2.fromScale(1, 1)
highlight.BackgroundColor3 = GOLD
highlight.BackgroundTransparency = 0.8
highlight.BorderSizePixel = 0

local highlightCorner = Instance.new("UICorner")
highlightCorner.CornerRadius = UDim.new(0, 14)
highlightCorner.Parent = highlight

local highlightStroke = Instance.new("UIStroke")
highlightStroke.Color = GOLD
highlightStroke.Thickness = 4
highlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
highlightStroke.Parent = highlight

playerGui.SelectionImageObject = highlight

-- the highlight takes the corners of whatever is selected, so it never bulges past them
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	local selected = GuiService.SelectedObject
	if selected then
		highlightCorner.CornerRadius = PanelManager.CornerFor(selected)
		playerGui.SelectionImageObject = nil
		playerGui.SelectionImageObject = highlight
	end
end)

--------------------------------------------------
-- WHICH MENU IS ON TOP
--------------------------------------------------

local openedAt = {} -- [frame] = the order it opened in, the newest is on top
local openCounter = 0

local function topMenu()
	local top = nil
	local seen = {}
	for _, menu in ipairs(PanelManager.OpenMenus()) do
		seen[menu.Frame] = true
		if not openedAt[menu.Frame] then
			openCounter += 1
			openedAt[menu.Frame] = openCounter
		end
		if not top or openedAt[menu.Frame] > openedAt[top.Frame] then
			top = menu
		end
	end
	for frame in pairs(openedAt) do
		if not seen[frame] then
			openedAt[frame] = nil
		end
	end
	return top
end

--------------------------------------------------
-- SELECTION
--------------------------------------------------

local function isShown(object, root)
	local current = object
	while current and current ~= root.Parent do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil
end

-- The top-left button of the menu, leaving the X as a last resort (B does its job).
local function firstButton(root)
	local best, bestClose = nil, nil
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("GuiButton") and object.Selectable and isShown(object, root) then
			if object:IsA("TextButton") and object.Text == "X" then
				bestClose = object
			elseif not best
				or object.AbsolutePosition.Y < best.AbsolutePosition.Y - 4
				or (math.abs(object.AbsolutePosition.Y - best.AbsolutePosition.Y) <= 4
					and object.AbsolutePosition.X < best.AbsolutePosition.X) then
				best = object
			end
		end
	end
	return best or bestClose
end

-- The button the tutorial is pointing at (the target may be a card holding the button).
local function findTutorialButton()
	local target = PanelManager.TutorialTarget
	if not target or not target.Parent then
		return nil
	end
	return target:IsA("GuiButton") and target or firstButton(target)
end

-- The system menu has the controller: hands off, or selecting our own buttons would
-- pull the focus away from it.
local function robloxWindowOpen()
	return GuiService.MenuIsOpen
end

local selectedMenu = nil
local menuCanClose = false
local tutorialButton = nil
local browsing = false -- the player pressed Select to reach the HUD buttons
local menuPick = nil -- the button last selected in the open menu
local cursorWasOn = false
local freeCursor = false -- the player double tapped Browse for the cursor
local DOUBLE_TAP = 0.3 -- seconds: a slower second press is just a normal press
local lastBrowseTap = 0
local browseOpenedAt = 0
local CURSOR_DOUBLE_TAP = 0.4 -- a stick click is slower to repeat than a button
local lastCursorTap = 0
local freeCursorEndedAt = 0

local function inTutorial()
	local step = player:GetAttribute("TutorialStep")
	return typeof(step) == "number" and step < 12
end

local function onLobbyFloor()
	local state = player:GetAttribute("RunState")
	return state == nil or state == "Waiting"
end

local function updateSelection()
	if robloxWindowOpen() then
		return
	end

	local menu = usingGamepad and topMenu() or nil
	local frame = menu and menu.Frame
	menuCanClose = menu ~= nil and menu.Close ~= nil

	-- A free cursor never survives a run starting, the tutorial, or Roblox ending it
	local cursorOn = GamepadService.GamepadCursorEnabled
	if freeCursor and (not cursorOn or not usingGamepad or not onLobbyFloor() or inTutorial()) then
		freeCursor = false
	end

	-- The Plus card is cursor only: if anything (Roblox's own B) ends it, it comes back.
	if PanelManager.ControllerReleased and frame and not cursorOn then
		GamepadService:EnableGamepadCursor(nil)
		cursorOn = true
	end

	-- Safety: with no menu open and no free cursor asked for, the cursor must never stay
	-- on, or the stick would steer it while the ball sits frozen.
	if not frame and not freeCursor and (cursorOn or PanelManager.ControllerReleased) then
		PanelManager.ReclaimController()
		cursorOn = false
	end
	local cursorJustOff = cursorWasOn and not cursorOn
	cursorWasOn = cursorOn

	if frame ~= selectedMenu then
		GuiService:RemoveSelectionGroup(SELECTION_GROUP)
		selectedMenu = frame
		if frame then
			GuiService:AddSelectionParent(SELECTION_GROUP, frame)
		end
		browsing = false -- a menu opening or closing always ends browsing
		menuPick = nil
		GuiService.SelectedObject = nil
	end

	-- the tutorial's spotlight comes first: it is what the player has to press next
	local wanted = usingGamepad and findTutorialButton() or nil
	if wanted and frame and not wanted:IsDescendantOf(frame) then
		wanted = nil
	end
	tutorialButton = wanted

	if not usingGamepad then
		return
	end

	-- the cursor is in charge, or a Roblox window has the controller: select nothing
	if cursorOn or PanelManager.ControllerReleased then
		return
	end

	-- the cursor just went off (window closed, D-pad, B): back to the button from before
	if cursorJustOff and frame and not wanted and not GuiService.SelectedObject then
		GuiService.SelectedObject = menuPick and menuPick:IsDescendantOf(frame) and isShown(menuPick, frame)
			and menuPick or firstButton(frame)
	end

	local selected = GuiService.SelectedObject
	if wanted then
		if selected ~= wanted then
			GuiService.SelectedObject = wanted
		end
	elseif frame then
		if selected and selected:IsDescendantOf(frame) then
			menuPick = selected
		elseif not menuPick or not menuPick:IsDescendantOf(frame) or not isShown(menuPick, frame) then
			-- first open, or the list was rebuilt under the selected button
			menuPick = firstButton(frame)
			GuiService.SelectedObject = menuPick
		end
		-- otherwise the button is still there and nothing is selected: a Roblox window
		-- (a purchase prompt) took the controller, so it is left alone
	elseif browsing then
		if not selected or not selected:IsDescendantOf(playerGui) then
			browsing = false
		end
	elseif selected then
		-- playing: the stick and A must belong to the ball
		GuiService.SelectedObject = nil
	end
end

--------------------------------------------------
-- BUTTONS
--------------------------------------------------

local ACTIONS = {
	Store = function()
		PanelManager.Toggle("Store")
	end,
	Quests = function()
		PanelManager.Toggle("Quests")
	end,
	Daily = function()
		PanelManager.Toggle("Calendar")
	end,
	Rebirth = function()
		local toggle = playerGui:FindFirstChild("ToggleRebirthPanel")
		if toggle then
			toggle:Fire()
		end
	end,
}

local shortcutByKey = {}
for _, shortcut in ipairs(ControllerMap.Shortcuts) do
	shortcutByKey[shortcut.Key] = shortcut.Action
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not isGamepad(input.UserInputType) then
		return
	end

	if robloxWindowOpen() then
		return
	end

	-- The Plus card is cursor only: no button here can interfere with it. Its own
	-- NO, GO BACK button is the way out.
	if PanelManager.ControllerReleased then
		return
	end

	-- The tutorial's controls walkthrough only asks the player to press these: opening
	-- the HUD buttons there would take the stick away from the ball.
	if PanelManager.ControllerTour and (input.KeyCode == ControllerMap.Browse or input.KeyCode == ControllerMap.BrowseAlt) then
		return
	end

	-- L3 only counts as a fast double press, as people click it out of habit. It is the
	-- backup in case a PlayStation keeps Share for itself.
	if input.KeyCode == ControllerMap.FreeCursor then
		local now = os.clock()
		if now - lastCursorTap >= CURSOR_DOUBLE_TAP then
			lastCursorTap = now
		else
			lastCursorTap = 0
			if freeCursor then
				freeCursor = false
				GamepadService:DisableGamepadCursor()
			elseif onLobbyFloor() and not inTutorial() then
				browsing = false
				freeCursor = true
				GuiService.SelectedObject = nil
				GamepadService:EnableGamepadCursor(nil)
			end
		end
		return
	end

	-- Double tap in the lobby or a menu: the free cursor. The first tap has already done
	-- its normal job and is undone, so one press stays instant; a second press slower
	-- than DOUBLE_TAP is an ordinary press.
	if input.KeyCode == ControllerMap.BrowseAlt then
		local now = os.clock()
		if freeCursor then
			freeCursor = false
			freeCursorEndedAt = now
			GamepadService:DisableGamepadCursor()
			return
		elseif now - freeCursorEndedAt < DOUBLE_TAP then
			return -- the second tap of the double tap that ended it
		elseif now - lastBrowseTap < DOUBLE_TAP and onLobbyFloor() and not inTutorial() then
			lastBrowseTap = 0
			browsing = false
			freeCursor = true
			GuiService.SelectedObject = nil
			GamepadService:EnableGamepadCursor(nil)
			return
		end
		lastBrowseTap = now
	end

	if input.KeyCode == ControllerMap.Back and freeCursor then
		freeCursor = false
		GamepadService:DisableGamepadCursor()
		return
	end

	local menu = topMenu()
	local isDPad = input.KeyCode == Enum.KeyCode.DPadUp or input.KeyCode == Enum.KeyCode.DPadDown
		or input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.DPadRight

	-- A second fast Browse right after the press that opened the HUD buttons: the free
	-- cursor. Only that press counts, so moving down a list or a menu can never trigger it.
	if input.KeyCode == ControllerMap.Browse and browsing and not menu
		and os.clock() - browseOpenedAt < DOUBLE_TAP then
		browseOpenedAt = 0
		browsing = false
		freeCursor = true
		GuiService.SelectedObject = nil
		GamepadService:EnableGamepadCursor(nil)
		return
	end

	-- In a menu the D-pad is always button selection: it switches the cursor off and
	-- brings the selection back if there is none.
	if isDPad and menu and (GamepadService.GamepadCursorEnabled or not GuiService.SelectedObject) then
		freeCursor = false
		PanelManager.ReclaimController()
		GuiService.SelectedObject = menuPick and menuPick:IsDescendantOf(menu.Frame) and isShown(menuPick, menu.Frame)
			and menuPick or firstButton(menu.Frame)
		return
	end

	if input.KeyCode == ControllerMap.Back then
		if menu then
			if menu.Close then
				PanelManager.ReclaimController()
				menu.Close()
			end
		elseif browsing then
			browsing = false
			GuiService.SelectedObject = nil
		end
		return
	end

	-- Browse opens the HUD buttons. Once open it just moves between them (B leaves), and
	-- only the alternative button also closes. Never mid-run, the stick is steering.
	if input.KeyCode == ControllerMap.BrowseAlt or (input.KeyCode == ControllerMap.Browse and not browsing) then
		if menu or tutorialButton or not onLobbyFloor() then
			return
		end
		-- leaving the cursor this way doesn't start a double tap, or it would come straight back
		browseOpenedAt = (input.KeyCode == ControllerMap.Browse and not freeCursor) and os.clock() or 0
		if freeCursor then
			freeCursor = false
			GamepadService:DisableGamepadCursor()
		end
		browsing = not browsing
		local hub = playerGui:FindFirstChild("HubUI")
		GuiService.SelectedObject = browsing and hub and firstButton(hub) or nil
		if not GuiService.SelectedObject then
			browsing = false
		end
		return
	end

	-- while a button is selected the D-pad and shoulders belong to it
	if processed or menu or GuiService.SelectedObject then
		return
	end
	local action = shortcutByKey[input.KeyCode]
	if action and onLobbyFloor() and not inTutorial() then
		ACTIONS[action]()
	end
end)

-- Pushing the left stick in a menu switches to the free cursor (Roblox's own, it also
-- reaches Roblox's windows); the safety check in updateSelection ends it with the menu.
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode ~= ControllerMap.Move or input.Position.Magnitude < 0.5 then
		return
	end
	if selectedMenu and not tutorialButton and not robloxWindowOpen()
		and not GamepadService.GamepadCursorEnabled then
		GuiService.SelectedObject = nil
		GamepadService:EnableGamepadCursor(nil)
	end
end)

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	-- a bumped mouse must not drop controller mode: only a real press switches it off
	if isGamepad(inputType) then
		usingGamepad = true
	elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.Touch
		or inputType == Enum.UserInputType.MouseButton1 then
		if usingGamepad then
			usingGamepad = false
			browsing = false
			GuiService.SelectedObject = nil
			PanelManager.ReclaimController()
		end
	end
end)

--------------------------------------------------
-- BUTTON HINTS
--------------------------------------------------

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "ConsoleHints"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 45
hintGui.Parent = playerGui

local hintRow = Instance.new("Frame")
hintRow.AnchorPoint = Vector2.new(1, 1)
hintRow.Position = UDim2.new(1, -12, 1, -26)
hintRow.Name = "HintRow"
hintRow.Size = UDim2.fromOffset(0, 30)
hintRow.AutomaticSize = Enum.AutomaticSize.X -- exactly its hints, the tutorial spotlights it
hintRow.BackgroundTransparency = 1
hintRow.Visible = false
hintRow.Parent = hintGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = hintRow

local function addHint(order, keyCode, text)
	local icon = Instance.new("ImageLabel")
	icon.LayoutOrder = order * 2
	icon.Size = UDim2.fromOffset(26, 26)
	icon.BackgroundTransparency = 1
	icon.Image = UserInputService:GetImageForKeyCode(keyCode)
	icon.Parent = hintRow

	local label = Instance.new("TextLabel")
	label.LayoutOrder = order * 2 + 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text .. "   "
	label.TextColor3 = Color3.fromRGB(255, 247, 232)
	label.TextSize = 18
	label.Parent = hintRow

	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Parent = label
end

local HINTS = {
	Menu = function()
		addHint(1, ControllerMap.Confirm, "Select")
		addHint(2, ControllerMap.Back, "Back")
	end,
	Press = function()
		addHint(1, ControllerMap.Confirm, "Select")
	end,
	Cursor = function()
		addHint(1, ControllerMap.Move, "Cursor")
		addHint(2, ControllerMap.Confirm, "Click")
		addHint(3, Enum.KeyCode.DPadDown, "Buttons")
		addHint(4, ControllerMap.Back, "Back")
	end,
	Tour = function()
		addHint(1, ControllerMap.Move, "Move")
		addHint(2, ControllerMap.Confirm, "Jump")
		addHint(3, ControllerMap.Browse, "All Buttons")
	end,
	CursorOnly = function()
		addHint(1, ControllerMap.Move, "Cursor")
		addHint(2, ControllerMap.Confirm, "Click")
	end,
	FreeCursor = function()
		addHint(1, ControllerMap.Move, "Cursor")
		addHint(2, ControllerMap.Confirm, "Click")
		addHint(3, ControllerMap.Back, "Exit")
	end,
	Move = function()
		addHint(1, ControllerMap.Move, "Move")
		addHint(2, ControllerMap.Confirm, "Jump")
	end,
	Lobby = function()
		addHint(1, ControllerMap.Move, "Move")
		addHint(2, ControllerMap.Confirm, "Jump")
		addHint(3, ControllerMap.Browse, "All Buttons")
		addHint(4, ControllerMap.Browse, "x2 Free Cursor")
	end,
	Course = function()
		addHint(1, ControllerMap.Move, "Steer")
	end,
}

local shownHints = nil

local function showHints(kind)
	if kind == shownHints then
		return
	end
	shownHints = kind
	for _, child in ipairs(hintRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	hintRow.Visible = kind ~= nil
	if kind then
		HINTS[kind]()
	end
end

local function chooseHints()
	if not usingGamepad or player:GetAttribute("LoadingDone") ~= true or robloxWindowOpen() then
		return nil
	elseif PanelManager.ControllerTour == "Controls" then
		return "Tour"
	elseif PanelManager.ControllerReleased then
		return "CursorOnly"
	elseif freeCursor then
		return "FreeCursor"
	elseif GamepadService.GamepadCursorEnabled then
		return "Cursor"
	elseif selectedMenu then
		return menuCanClose and "Menu" or "Press"
	elseif browsing then
		return "Menu"
	elseif tutorialButton then
		return "Press"
	elseif not onLobbyFloor() then
		return "Course"
	end
	return inTutorial() and "Move" or "Lobby"
end

--------------------------------------------------
-- SHORTCUT ICONS ON THE HUB TILES
--
-- Each shortcut's button icon sits in the top-left corner of its tile (the caption
-- has the bottom, the "!" and READY! badges the top-right), only while it works.
--------------------------------------------------

local function updateTileIcons(show)
	local hub = playerGui:FindFirstChild("HubUI")
	if not hub then
		return
	end
	for _, shortcut in ipairs(ControllerMap.Shortcuts) do
		local tile = hub:FindFirstChild(shortcut.Tile, true)
		if tile then
			local icon = tile:FindFirstChild("ControllerIcon")
			if not icon and show then
				icon = Instance.new("ImageLabel")
				icon.Name = "ControllerIcon"
				icon.Position = UDim2.fromOffset(3, 3)
				icon.Size = UDim2.fromOffset(24, 24)
				icon.BackgroundTransparency = 1
				icon.Image = UserInputService:GetImageForKeyCode(shortcut.Key)
				icon.ZIndex = 6
				icon.Parent = tile
			end
			if icon then
				icon.Visible = show
				icon.Image = UserInputService:GetImageForKeyCode(shortcut.Key) -- the controller can change
			end
		end
	end
end

--------------------------------------------------
-- LOOP
--------------------------------------------------

local nextUpdate = 0
local shownIconSet = nil
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextUpdate then
		return
	end
	nextUpdate = now + 0.1

	-- another controller was connected (Xbox to PlayStation): redraw the hints in its icons
	local iconSet = UserInputService:GetImageForKeyCode(ControllerMap.Confirm)
	if iconSet ~= shownIconSet then
		shownIconSet = iconSet
		shownHints = nil
		showHints(nil)
	end

	updateSelection()
	showHints(chooseHints())
	updateTileIcons(usingGamepad and onLobbyFloor() and not robloxWindowOpen()
		and (not inTutorial() or PanelManager.ControllerTour == "Menus"))
end)
