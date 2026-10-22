--------------------------------------------------
-- TUTORIAL UI
--
-- CLIENT ONLY. Shows a banner, an arrow that points from the player's ball
-- toward the current objective, and (for button steps) a SPOTLIGHT: the
-- whole screen fades except the button to press. The step itself comes
-- from the server attribute "TutorialStep" (see TutorialService); this
-- script never advances anything and grants nothing.
--
-- Steps (12 = done, nothing is shown):
--    1 START wall            2 FINISH wall (while rolling)
--    3 X1 XP generator       4 REBIRTH button (free), then REBIRTH NOW
--    5 START wall (again)    6 FINISH wall
--    7 shop: buy AFTERSHOCK  8 shop: equip AFTERSHOCK
--    9 START wall            10 FINISH wall
--   11 DAILY calendar: claim day 1
--------------------------------------------------

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GOLD = Color3.fromRGB(255, 214, 70)
local FONT = Enum.Font.FredokaOne

local DONE = 12
local TUTORIAL_BALL = "Aftershock"

local old = playerGui:FindFirstChild("TutorialUI")
if old then
	old:Destroy()
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = create("ScreenGui", {
	Name = "TutorialUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- matches WorldToViewportPoint coordinates
	DisplayOrder = 150, -- above the hub and the panels it points at
}, playerGui)

--------------------------------------------------
-- SPOTLIGHT (dims everything except the target)
--------------------------------------------------

local function dimFrame(name)
	return create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(8, 6, 24),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Active = true, -- sinks clicks everywhere except the hole
		Visible = false,
		ZIndex = 1,
	}, gui)
end

local dimTop, dimBottom, dimLeft, dimRight = dimFrame("DimTop"), dimFrame("DimBottom"), dimFrame("DimLeft"), dimFrame("DimRight")

local ring = create("Frame", {
	Name = "Ring",
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 3,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, ring)
local ringStroke = create("UIStroke", { Color = GOLD, Thickness = 5 }, ring)

local pointer = create("TextLabel", {
	Name = "Pointer",
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(60, 50),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "v",
	TextColor3 = GOLD,
	TextSize = 54,
	Visible = false,
	ZIndex = 4,
}, gui)
create("UIStroke", { Color = INK, Thickness = 4 }, pointer)

-- a GuiObject really on screen (every ancestor visible)?
local function isShown(object)
	if not object or not object.Parent then
		return false
	end

	local current = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") then
			return current.Enabled
		end
		current = current.Parent
	end

	return object.AbsoluteSize.X > 4 and object.AbsoluteSize.Y > 4
end

local function screenRect(object)
	local position = object.AbsolutePosition
	local sourceGui = object:FindFirstAncestorWhichIsA("ScreenGui")
	if sourceGui and not sourceGui.IgnoreGuiInset then
		position += GuiService:GetGuiInset()
	end
	return position, object.AbsoluteSize
end

local function setSpotlight(target, extra)
	if not target or not isShown(target) then
		for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight, ring, pointer }) do
			frame.Visible = false
		end
		return
	end

	local position, size = screenRect(target)

	-- an extra object (the FREE tag) is kept inside the lit area too
	if extra and isShown(extra) then
		local extraPosition, extraSize = screenRect(extra)
		local minX = math.min(position.X, extraPosition.X)
		local minY = math.min(position.Y, extraPosition.Y)
		local maxX = math.max(position.X + size.X, extraPosition.X + extraSize.X)
		local maxY = math.max(position.Y + size.Y, extraPosition.Y + extraSize.Y)
		position, size = Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
	end

	local pad = 10
	local x, y = position.X - pad, position.Y - pad
	local w, h = size.X + pad * 2, size.Y + pad * 2
	local screen = gui.AbsoluteSize

	-- Whole-pixel rectangle, frames abut exactly (no overlap, no gap): with
	-- fractional sizes a 1 px gap used to show as a thin line across the screen.
	local x0, y0 = math.floor(x), math.floor(y)
	local x1, y1 = math.ceil(x + w), math.ceil(y + h)
	local sw, sh = math.ceil(screen.X) + 4, math.ceil(screen.Y) + 4

	dimTop.Position, dimTop.Size = UDim2.fromOffset(-2, -2), UDim2.fromOffset(sw, math.max(0, y0 + 2))
	dimBottom.Position, dimBottom.Size = UDim2.fromOffset(-2, y1), UDim2.fromOffset(sw, math.max(0, sh - y1 - 2))
	dimLeft.Position, dimLeft.Size = UDim2.fromOffset(-2, y0), UDim2.fromOffset(math.max(0, x0 + 2), y1 - y0)
	dimRight.Position, dimRight.Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(math.max(0, sw - 2 - x1), y1 - y0)	ring.Position, ring.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	ringStroke.Transparency = 0.5 - math.sin(os.clock() * 6) * 0.45

	local bob = math.sin(os.clock() * 6) * 6
	if y > 90 then
		pointer.Text = "v"
		pointer.AnchorPoint = Vector2.new(0.5, 1)
		pointer.Position = UDim2.fromOffset(x + w / 2, y - 2 + bob)
	else
		pointer.Text = "^"
		pointer.AnchorPoint = Vector2.new(0.5, 0)
		pointer.Position = UDim2.fromOffset(x + w / 2, y + h + 2 - bob)
	end

	for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight, ring, pointer }) do
		frame.Visible = true
	end
end

--------------------------------------------------
-- BANNER
--------------------------------------------------

-- Instruction text: no box. Big cream text with a thick dark outline and a
-- soft gold glow so it reads over any part of the game.
-- An ANNOUNCEMENT, not floating text: a solid dark panel with a gold border, a
-- "TUTORIAL - STEP n/8" tab on its top edge, an icon, one short line of text and
-- progress dots. It sits below the Roblox top bar and slides in on every new step.
local PANEL_Y = game:GetService("UserInputService").TouchEnabled and 0.13 or 0.16
local panel = create("Frame", {
	Name = "TutorialAnnouncement",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, PANEL_Y, 0),
	Size = UDim2.fromOffset(640, 96),
	BackgroundColor3 = Color3.fromRGB(22, 14, 56),
	BackgroundTransparency = 0.04,
	Visible = false,
	ZIndex = 9,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
local panelStroke = create("UIStroke", { Color = Color3.fromRGB(255, 205, 70), Thickness = 2.5 }, panel)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(40, 26, 92), Color3.fromRGB(18, 12, 46)),
	Rotation = 90,
}, panel)
local tab = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(220, 26),
	BackgroundColor3 = Color3.fromRGB(255, 205, 70),
	Font = FONT,
	Text = "TUTORIAL",
	TextColor3 = Color3.fromRGB(40, 24, 70),
	TextSize = 16,
	ZIndex = 11,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 15) }, tab)
create("UIStroke", { Color = Color3.fromRGB(20, 12, 50), Thickness = 2 }, tab)
local iconBox = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 4),
	Size = UDim2.fromOffset(58, 58),
	BackgroundColor3 = Color3.fromRGB(255, 205, 70),
	ZIndex = 10,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, iconBox)
create("UIStroke", { Color = Color3.fromRGB(20, 12, 50), Thickness = 2 }, iconBox)
local iconLabel = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextSize = 34,
	TextColor3 = Color3.fromRGB(40, 24, 70),
	ZIndex = 11,
}, iconBox)
local banner = create("TextLabel", {
	Position = UDim2.fromOffset(86, 16),
	Size = UDim2.new(1, -100, 0, 52),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(250, 240, 215),
	TextSize = 22,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 10,
}, panel)
create("UIStroke", { Color = Color3.fromRGB(20, 12, 50), Thickness = 1, Transparency = 0.35 }, banner) -- light outline: readable, not heavy
local TOTAL_STEPS = 8
local dots = {}
local dotRow = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 86, 1, -8),
	Size = UDim2.new(1, -100, 0, 10),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, panel)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, dotRow)
for index = 1, TOTAL_STEPS do
	local dot = create("Frame", {
		Size = UDim2.fromOffset(34, 6),
		BackgroundColor3 = Color3.fromRGB(80, 66, 130),
		ZIndex = 10,
	}, dotRow)
	create("UICorner", { CornerRadius = UDim.new(0, 3) }, dot)
	dots[index] = dot
end
banner:GetPropertyChangedSignal("Visible"):Connect(function()
	panel.Visible = banner.Visible
end)
local bannerScale = create("UIScale", { Scale = 1 }, panel)

-- the 12 internal steps shown as 8 player-facing ones
local STEP_INFO = {
	[1] = { 1, "🏁" }, [2] = { 1, "🛢️" }, [3] = { 2, "⚡" }, [4] = { 3, "♻️" }, [5] = { 4, "🎳" },
	[6] = { 4, "🛢️" }, [7] = { 5, "🛒" }, [8] = { 6, "✅" }, [9] = { 7, "🎳" }, [10] = { 7, "🛢️" }, [11] = { 8, "🎁" },
}
local function setStepDecor(step)
	local info = STEP_INFO[step]
	if not info then
		return
	end
	tab.Text = "TUTORIAL  •  STEP " .. info[1] .. " OF " .. TOTAL_STEPS
	iconLabel.Text = info[2]
	for index, dot in ipairs(dots) do
		dot.BackgroundColor3 = (index <= info[1]) and Color3.fromRGB(255, 205, 70) or Color3.fromRGB(80, 66, 130)
	end
end

-- gentle pulse on the border so the announcement draws the eye
task.spawn(function()
	while true do
		task.wait(0.05)
		if panel.Visible then
			panelStroke.Thickness = 2.5 + math.sin(os.clock() * 3) * 0.6
		end
	end
end)
local function fitBanner()
	local viewport = gui.AbsoluteSize
	local fit = math.clamp(math.min(viewport.X / 700, viewport.Y / 480), 0.5, 1.1)
	-- phones / tablets: noticeably smaller and tucked up, so it never fills the view
	if game:GetService("UserInputService").TouchEnabled then
		fit = math.min(fit, 0.62)
	end
	bannerScale.Scale = fit
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBanner)
fitBanner()

--------------------------------------------------
-- ARROW (screen space, orbits the ball toward the target)
--------------------------------------------------

-- A chain of GROUND arrows flows out of the ball along the floor toward the
-- objective (world parts, drawn only on this client). Screen-space arrows
-- pointed at the sky whenever the target was straight ahead.
-- shared, cleaner arrow trail (also used for the Bowling Shop after world moves)
local GroundArrows = require(game:GetService("ReplicatedStorage"):WaitForChild("GroundArrows"))
local old = workspace:FindFirstChild("TutorialArrows")
if old then
	old:Destroy()
end
local trail = GroundArrows.new("TutorialArrows")
local function hideArrows()
	trail:Hide()
end
local distanceLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(90, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 22,
	Visible = false,
	ZIndex = 5,
}, gui)
create("UIStroke", { Color = INK, Thickness = 3 }, distanceLabel)

--------------------------------------------------
-- WORLD TARGETS
--------------------------------------------------

local aftershockCost = nil -- the tutorial ball's Wins price (fetched when step 7 starts)

local function worldTarget(step)
	if step == 1 or step == 5 or step == 9 then
		return workspace:FindFirstChild("StartWall")

	elseif step == 2 or step == 6 or step == 10 then
		-- Only during the oil course. Once the finish wall is hit (RunState
		-- Finishing) and the WinCourse runs, there is nothing to point at.
		if player:GetAttribute("RunState") ~= "Running" then
			return nil
		end
		return workspace:FindFirstChild("FinishWall")

	elseif step == 3 then
		local generators = workspace:FindFirstChild("XPGenerators")
		return generators and generators:FindFirstChild("GenX1")

	elseif step == 7 or step == 8 then
		-- not enough wins for the tutorial ball yet: point at the START wall so they
		-- roll more courses first (the win course pays the wins)
		if step == 7 and aftershockCost and (player:GetAttribute("Wins") or 0) < aftershockCost then
			if player:GetAttribute("RunState") == "Running" then
				return workspace:FindFirstChild("FinishWall")
			end
			return workspace:FindFirstChild("StartWall")
		end
		local shop = workspace:FindFirstChild("BowlingShop")
		return shop and shop:FindFirstChild("BallShopInteractionPoint")
	end

	return nil
end

local function positionOf(target)
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

local function getOwnBall()
	local balls = workspace:FindFirstChild("PlayerBalls")
	return balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
end

--------------------------------------------------
-- BUTTON TARGETS (spotlight)
--------------------------------------------------

local function findGui(name)
	return playerGui:FindFirstChild(name, true)
end

local function calendarDayOne()
	local panel = findGui("CalendarPanel")
	if not panel then
		return nil
	end
	local best
	for _, child in ipairs(panel:GetDescendants()) do
		if child:IsA("TextButton") and child.Size.X.Offset == 94 and child.Size.Y.Offset == 154 then
			if not best or child.LayoutOrder < best.LayoutOrder then
				best = child
			end
		end
	end
	return best
end

-- returns the GuiObject to spotlight for this step (nil = none right now)
local function spotlightTarget(step)
	if step == 4 then
		if PanelManager.IsOpen("Rebirth") then
			return findGui("RebirthNowButton")
		end
		local hub = playerGui:FindFirstChild("HubUI")
		local button = hub and hub:FindFirstChild("RebirthButton", true)
		return button

	elseif step == 7 or step == 8 then
		local shop = playerGui:FindFirstChild("BallShopUI")
		if shop and shop.Enabled then
			local card = shop:FindFirstChild(TUTORIAL_BALL, true)
			return card
		end

	elseif step == 11 then
		if PanelManager.IsOpen("Calendar") then
			return calendarDayOne()
		end
		local hub = playerGui:FindFirstChild("HubUI")
		return hub and hub:FindFirstChild("DailyButton", true)
	end

	return nil
end

--------------------------------------------------
-- TEXT
--------------------------------------------------


local function fetchAftershockCost()
	if aftershockCost then
		return
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local state = remotes and remotes:FindFirstChild("BallShopState")
	if not state then
		return
	end

	local ok, result = pcall(function()
		return state:InvokeServer()
	end)

	if ok and typeof(result) == "table" and typeof(result.Balls) == "table" then
		for _, ball in ipairs(result.Balls) do
			if ball.BallId == TUTORIAL_BALL then
				aftershockCost = ball.WinsCost
			end
		end
	end
end

local function shopOpen()
	local shop = playerGui:FindFirstChild("BallShopUI")
	return shop ~= nil and shop.Enabled
end

local function textFor(step)
	local running = player:GetAttribute("RunState") == "Running"

	if step == 1 then
		return "Roll into the START wall to begin!"
	elseif step == 2 or step == 6 or step == 10 then
		if running then
			return "Grab oil, dodge the red panels, reach the FINISH!"
		end
		return "Roll through the tiles to collect WINS!"
	elseif step == 3 then
		if player:GetAttribute("ActiveXPGenerator") == "GenX1" then
			return "Keep rolling here until your level bar is FULL!"
		end
		return "Roll onto the X1 generator to earn XP!"
	elseif step == 4 then
		if PanelManager.IsOpen("Rebirth") then
			return "Press the big REBIRTH button!"
		end
		return "Level full! Tap REBIRTH - it's FREE!"
	elseif step == 5 then
		return "Rebirthed! Oil is now x2. Roll again!"
	elseif step == 7 then
		if shopOpen() then
			return "Press BUY on AFTERSHOCK!"
		end
		local cost = aftershockCost
		local wins = player:GetAttribute("Wins") or 0
		if cost and wins < cost then
			return "Wins " .. wins .. " / " .. cost .. " - roll another course for more!"
		end
		return "Roll onto the SHOP pad and buy AFTERSHOCK!"
	elseif step == 8 then
		if shopOpen() then
			return "Press EQUIP on AFTERSHOCK!"
		end
		return "Open the shop and EQUIP AFTERSHOCK!"
	elseif step == 9 then
		return "Roll again with your new ball!"
	elseif step == 11 then
		if PanelManager.IsOpen("Calendar") then
			return "Claim DAY 1 of your daily gift!"
		end
		return "Tutorial complete! Tap the calendar for your daily gift!"
	end

	return ""
end
--------------------------------------------------
-- UPDATE
--------------------------------------------------

local shownStep = nil
local calendarOpened = false
local wasInTutorial = false

local function updateBanner(step)
	if step == shownStep then
		return
	end
	shownStep = step

	if step == DONE and wasInTutorial then
		-- finished this session: a short, proud send-off, then the banner goes away
		wasInTutorial = false
		banner.Text = "YOU'RE A PRO! Roll, win, rebirth, collect every ball!"
		tab.Text = "TUTORIAL COMPLETE"
		iconLabel.Text = "🏆"
		for _, dot in ipairs(dots) do
			dot.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
		end
		banner.Visible = true
		fitBanner()
		task.delay(6, function()
			if shownStep == DONE then
				banner.Visible = false
			end
		end)
		return
	end

	if step == nil or step >= DONE or step < 1 then
		banner.Visible = false
		return
	end
	wasInTutorial = true

	if step == 7 then
		task.spawn(fetchAftershockCost)
	end

	banner.Text = textFor(step)
	setStepDecor(step)
	banner.Visible = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	panel.Position = UDim2.new(0.5, 0, PANEL_Y - 0.05, 0)
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, PANEL_Y, 0) }):Play()
	fitBanner()
	local finalScale = bannerScale.Scale
	bannerScale.Scale = finalScale * 0.85
	TweenService:Create(
		bannerScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = finalScale }
	):Play()
end

RunService.RenderStepped:Connect(function()
	local step = player:GetAttribute("TutorialStep")
	updateBanner(step)

	local active = typeof(step) == "number" and step >= 1 and step < DONE

	-- the banner text depends on state (wins, panels), so keep it fresh
	if active and banner.Visible then
		banner.Text = textFor(step)
	end

	-- step 11: the calendar appears on screen by itself, once
	if active and step == 11 and not calendarOpened and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then
		calendarOpened = true
		task.delay(0.6, function()
			PanelManager.Open("Calendar")
		end)
	end

	-- spotlight for button steps (only in the lobby)
	local lobby = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	local extra = (step == 4 and PanelManager.IsOpen("Rebirth")) and findGui("FreeTag") or nil
	setSpotlight(active and lobby and spotlightTarget(step) or nil, extra)

	local target = active and worldTarget(step) or nil
	local ball = getOwnBall()

	if not target or not ball then
		hideArrows()
		distanceLabel.Visible = false
		return
	end

	local targetPosition = positionOf(target)
	if not targetPosition then
		hideArrows()
		distanceLabel.Visible = false
		return
	end

	local lastPoint = trail:Update(ball, targetPosition)
	if not lastPoint then
		distanceLabel.Visible = false
		return
	end

	local screen, onScreen = camera:WorldToViewportPoint(lastPoint + Vector3.new(0, 3, 0))
	local distance = (targetPosition - ball.Position).Magnitude
	distanceLabel.Position = UDim2.fromOffset(screen.X, screen.Y)
	distanceLabel.Text = math.floor(distance) .. " studs"
	distanceLabel.Visible = onScreen and screen.Z > 0
end)
-- Keep the banner out of the way while rolling (only shown in the lobby).
player:GetAttributeChangedSignal("RunState"):Connect(function()
	if shownStep ~= nil and shownStep < DONE and shownStep >= 1 then
		banner.Visible = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	end
end)
