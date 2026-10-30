--------------------------------------------------
-- PANEL MANAGER (client only, shared module)
--
-- One place that opens / closes the big panels (Store, Calendar, Quests,
-- Rebirth, Community):
--   * only one is open at a time; opening another slides the current one
--     away (down, behind the new one) while the new one slides in
--   * PanelManager.AnyOpen() lets the camera ignore zoom / FOV input while
--     any panel is open
--
-- Usage: PanelManager.Register("Store", frame); PanelManager.Toggle("Store")
-- The frame keeps its own design position (centre etc.) as its "home".
--------------------------------------------------

local TweenService = game:GetService("TweenService")

local PanelManager = {}

local panels = {} -- [name] = { Frame, Home, Open, Token, OnOpen }

local SLIDE_OUT = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SLIDE_IN = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function offscreen(home)
	return UDim2.new(home.X.Scale, home.X.Offset, 1.6, 0)
end

function PanelManager.Register(name, frame, onOpen)
	panels[name] = {
		Frame = frame,
		Home = frame.Position,
		Open = false,
		Token = 0,
		OnOpen = onOpen,
	}
	frame.Visible = false
end

local function slideOut(panel)
	if not panel.Open and not panel.Frame.Visible then
		return
	end

	panel.Open = false
	panel.Token += 1
	local token = panel.Token

	local tween = TweenService:Create(panel.Frame, SLIDE_OUT, { Position = offscreen(panel.Home) })
	tween.Completed:Once(function()
		if panel.Token == token then
			panel.Frame.Visible = false
		end
	end)
	tween:Play()
end

function PanelManager.Close(name)
	local panel = panels[name]
	if panel then
		slideOut(panel)
	end
end

function PanelManager.CloseAll(except)
	for otherName, other in pairs(panels) do
		if otherName ~= except and (other.Open or other.Frame.Visible) then
			slideOut(other)
		end
	end
end

function PanelManager.Open(name)
	local panel = panels[name]
	if not panel or panel.Open then
		return
	end

	PanelManager.CloseAll(name)

	panel.Open = true
	panel.Token += 1

	if panel.OnOpen then
		panel.OnOpen()
	end

	-- keep the design position even if the panel was re-laid out meanwhile
	panel.Frame.Position = offscreen(panel.Home)
	panel.Frame.Visible = true
	TweenService:Create(panel.Frame, SLIDE_IN, { Position = panel.Home }):Play()
end

function PanelManager.Toggle(name)
	local panel = panels[name]
	if not panel then
		return
	end

	if panel.Open then
		PanelManager.Close(name)
	else
		PanelManager.Open(name)
	end
end

function PanelManager.IsOpen(name)
	local panel = panels[name]
	return panel ~= nil and panel.Open
end

function PanelManager.AnyOpen()
	for _, panel in pairs(panels) do
		if panel.Open then
			return true
		end
	end
	return false
end

-- For ConsoleControls: menus that open themselves instead of through this manager
-- (ball shop, worlds, leave card) tell it how to close, so B works on them too.
-- A card the player must answer (tutorial) passes no close function.
local modals = {} -- [frame] = close function, or false
local NO_CLOSE = false

-- What the tutorial is spotlighting right now, if anything (set by TutorialUI).
PanelManager.TutorialTarget = nil

-- The tutorial's controller walkthrough, on screen only: nil, "Controls" or "Menus".
PanelManager.ControllerTour = nil

-- A Roblox window is opening (Plus): our menu lets go of the controller and Roblox's
-- virtual cursor stays on, so the stick and A can reach that window's buttons (a game
-- cannot select them itself). Lasts until the player leaves the card behind that window
-- (HubUI). Returns whether it applied, as mouse and touch need none of this.
PanelManager.ControllerReleased = false

function PanelManager.ReleaseController()
	local UserInputService = game:GetService("UserInputService")
	if UserInputService:GetLastInputType().Name:sub(1, 7) ~= "Gamepad" then
		return false -- mouse and touch reach the window by themselves
	end
	PanelManager.ControllerReleased = true
	game:GetService("GuiService").SelectedObject = nil
	pcall(function()
		game:GetService("GamepadService"):EnableGamepadCursor(nil)
	end)
	return true
end

function PanelManager.ReclaimController()
	PanelManager.ControllerReleased = false
	pcall(function()
		game:GetService("GamepadService"):DisableGamepadCursor()
	end)
end

-- The corner an outline around this object needs, as it appears on screen: its own
-- UICorner (none = square) with any UIScales above it applied. `grow` is how far the
-- outline sits outside the object, so its curve stays parallel to the object's.
function PanelManager.CornerFor(target, grow)
	local corner = target:FindFirstChildOfClass("UICorner")
	if not corner then
		return UDim.new(0, grow or 0)
	end
	local scale = 1
	local current = target
	while current do
		local uiScale = current:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		current = current.Parent
	end
	return UDim.new(corner.CornerRadius.Scale, corner.CornerRadius.Offset * scale + (grow or 0))
end

function PanelManager.RegisterModal(frame, close)
	modals[frame] = close or NO_CLOSE
	frame.Destroying:Once(function()
		modals[frame] = nil
	end)
end

-- Every menu on screen right now: a list of { Frame, Close }.
function PanelManager.OpenMenus()
	local open = {}
	for name, panel in pairs(panels) do
		if panel.Open then
			table.insert(open, {
				Frame = panel.Frame,
				Close = function()
					PanelManager.Close(name)
				end,
			})
		end
	end
	for frame, close in pairs(modals) do
		local screen = frame:FindFirstAncestorOfClass("ScreenGui")
		if frame.Visible and screen and screen.Enabled then
			table.insert(open, { Frame = frame, Close = close or nil })
		end
	end
	return open
end

return PanelManager
