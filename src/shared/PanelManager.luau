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

return PanelManager
