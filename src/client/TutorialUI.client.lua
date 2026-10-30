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
-- XP LOCKED NOTE
--
-- Rolling onto a generator before the first run earns nothing (the server decides,
-- BallPhysicsController), so plain text says what to do instead.
--------------------------------------------------

local xpLockedNote = create("TextLabel", {
	Name = "XPLockedNote",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.68),
	Size = UDim2.new(0.9, 0, 0, 44),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "Finish your first roll to start earning XP!",
	TextColor3 = CREAM,
	TextSize = 30,
	TextTransparency = 1,
	ZIndex = 30,
}, gui)
local xpLockedStroke = create("UIStroke", { Color = INK, Thickness = 3, Transparency = 1 }, xpLockedNote)

player:GetAttributeChangedSignal("XPLockedOnGenerator"):Connect(function()
	local show = player:GetAttribute("XPLockedOnGenerator") == true
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	TweenService:Create(xpLockedNote, info, { TextTransparency = show and 0 or 1 }):Play()
	TweenService:Create(xpLockedStroke, info, { Transparency = show and 0 or 1 }):Play()
end)

--------------------------------------------------
-- SPOTLIGHT (dims everything except the target)
--------------------------------------------------

local function dimFrame(name)
	return create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(8, 6, 24),
		BackgroundTransparency = 1, -- invisible: `shade` below draws the dark, with a rounded hole
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
local ringCorner = create("UICorner", { CornerRadius = UDim.new(0, 18) }, ring)
local ringStroke = create("UIStroke", { Color = GOLD, Thickness = 5 }, ring)

-- The dark around the spotlight: an outline so thick it covers the whole screen, around
-- an empty frame with the ring's corners, which leaves a rounded hole. (The four frames
-- above could only leave a square one, with lit corners sticking out past the ring.)
local shade = create("Frame", {
	Name = "Shade",
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 1,
}, gui)
local shadeCorner = create("UICorner", { CornerRadius = UDim.new(0, 18) }, shade)
create("UIStroke", {
	Color = Color3.fromRGB(8, 6, 24),
	Thickness = 4000,
	Transparency = 0.38,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, shade)

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
		for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight, shade, ring, pointer }) do
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
	-- the ring and the hole follow the target's own corners, a pad's width further out
	local corner = PanelManager.CornerFor(target, pad)
	ringCorner.CornerRadius = corner
	shade.Position, shade.Size = ring.Position, ring.Size
	shadeCorner.CornerRadius = corner
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

	for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight, shade, ring, pointer }) do
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
local lastShopScroll = 0
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
	TextSize = 15,
	ZIndex = 11,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 15) }, tab)
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
	Font = Enum.Font.GothamMedium, -- lighter than the game font: easy to read at a glance
	Text = "",
	TextColor3 = Color3.fromRGB(255, 250, 235),
	TextSize = 20,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 10,
}, panel)
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
	-- Arrows are for where to go next on the lobby floor. During a run the player can't
	-- turn back, so they only pointed back down the course and confused people.
	local runState = player:GetAttribute("RunState")
	if runState ~= nil and runState ~= "" and runState ~= "Waiting" then
		return nil
	end

	if step == 1 or step == 5 or step == 9 then
		return workspace:FindFirstChild("StartWall")

	elseif step == 3 then
		local generators = workspace:FindFirstChild("XPGenerators")
		return generators and generators:FindFirstChild("GenX1")

	elseif step == 7 or step == 8 then
		-- not enough wins for the tutorial ball yet: point at the START wall so they
		-- roll more courses first (the win course pays the wins)
		if step == 7 and aftershockCost and (player:GetAttribute("Wins") or 0) < aftershockCost then
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

-- the calendar slot to spotlight: the one that can be CLAIMED today (it is not always day 1, e.g. a
-- player whose calendar already has a streak); the first slot only if none is claimable
local function calendarDayOne()
	local panel = findGui("CalendarPanel")
	if not panel then
		return nil
	end
	local best, claimable
	for _, child in ipairs(panel:GetDescendants()) do
		if child:IsA("TextButton") and child.Size.X.Offset == 94 and child.Size.Y.Offset == 154 then
			if not best or child.LayoutOrder < best.LayoutOrder then
				best = child
			end
			for _, label in ipairs(child:GetChildren()) do
				if label:IsA("TextLabel") and label.Text == "CLAIM!" then
					claimable = child
				end
			end
		end
	end
	return claimable or best
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
			-- the first rebirth needs several level-ups, not just one full bar: say so
			local level = tonumber(player:GetAttribute("Level")) or 1
			local needed = tonumber(player:GetAttribute("RebirthLevelRequirement")) or 6
			local left = math.max(0, needed - level)
			if left <= 1 then
				return "ALMOST THERE! Stay on the generator, one more level!"
			elseif level >= 3 then
				return "ALMOST THERE! Stay on the generator, " .. left .. " more levels!"
			end
			return "Stay on the generator and keep LEVELING UP!"
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
			return "EARN DAILY! Claim today's gift, then close the calendar."
		end
		return "EARN DAILY! Tap the calendar and claim your daily gift!"
	end

	return ""
end
--------------------------------------------------
-- UPDATE
--------------------------------------------------

--------------------------------------------------
-- WELCOME SCREEN (first time only, at step 1)
--
-- A full-screen card so the player knows they are in the TUTORIAL before any
-- hints appear. They press CONTINUE to start.
--------------------------------------------------

local introActive = false
local introDone = false

local function showCard(opts, onContinue)
	introActive = true
	local dim = create("Frame", {
		Name = "TutorialIntro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 26),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Active = true, -- swallows clicks behind it
	}, gui)
	TweenService:Create(dim, TweenInfo.new(0.35), { BackgroundTransparency = 0.35 }):Play()

	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 340),
		BackgroundColor3 = Color3.fromRGB(24, 16, 60),
		ZIndex = 41,
	}, dim)
	create("UICorner", { CornerRadius = UDim.new(0, 22) }, card)
	create("UIStroke", { Color = Color3.fromRGB(255, 205, 70), Thickness = 3 }, card)
	local cardScale = create("UIScale", { Scale = 0.6 }, card)
	local function fit()
		local viewport = gui.AbsoluteSize
		cardScale.Scale = math.clamp(math.min(viewport.X / 560, viewport.Y / 380), 0.5, 1.1)
	end
	fit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	local tab = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(250, 38),
		BackgroundColor3 = Color3.fromRGB(255, 205, 70),
		Font = FONT,
		Text = opts.Tab,
		TextColor3 = Color3.fromRGB(40, 24, 70),
		TextSize = 24,
		ZIndex = 43,
	}, card)
	create("UICorner", { CornerRadius = UDim.new(0, 19) }, tab)

	create("TextLabel", {
		Position = UDim2.fromOffset(20, 34),
		Size = UDim2.new(1, -40, 0, 44),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = opts.Heading,
		TextColor3 = Color3.fromRGB(255, 232, 130),
		TextSize = 26,
		ZIndex = 42,
	}, card)
	create("TextLabel", {
		Position = UDim2.fromOffset(30, 84),
		Size = UDim2.new(1, -60, 0, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = opts.Body,
		TextColor3 = Color3.fromRGB(240, 236, 255),
		TextSize = 17,
		TextWrapped = true,
		ZIndex = 42,
	}, card)
	for index, goal in ipairs(opts.Goals) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local chip = create("Frame", {
			Position = UDim2.fromOffset(30 + column * 240, 150 + row * 50),
			Size = UDim2.fromOffset(230, 40),
			BackgroundColor3 = Color3.fromRGB(52, 36, 112),
			ZIndex = 42,
		}, card)
		create("UICorner", { CornerRadius = UDim.new(0, 12) }, chip)
		create("TextLabel", {
			Size = UDim2.new(1, -8, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = goal[1] .. "  " .. goal[2],
			TextColor3 = Color3.fromRGB(245, 240, 255),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 43,
		}, chip)
	end

	local button = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(260, 54),
		BackgroundColor3 = Color3.fromRGB(88, 196, 110),
		Font = FONT,
		Text = opts.Button,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 26,
		AutoButtonColor = true,
		ZIndex = 43,
	}, card)
	create("UICorner", { CornerRadius = UDim.new(0, 16) }, button)
	create("UIStroke", { Color = Color3.fromRGB(20, 60, 30), Thickness = 2 }, button)

	TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = math.clamp(math.min(gui.AbsoluteSize.X / 560, gui.AbsoluteSize.Y / 380), 0.5, 1.1) }):Play()

	PanelManager.RegisterModal(dim) -- controllers land on its button; it has no close

	button.Activated:Once(function()
		introDone = true
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		task.delay(0.3, function()
			dim:Destroy()
			introActive = false
			onContinue()
		end)
	end)
end


local function showIntro(onContinue)
	showCard({
		Tab = "TUTORIAL",
		Heading = "WELCOME TO STRIKE OIL!",
		Body = "Let's learn the basics, which will only take a few steps! Follow the hints and arrows at the top of your screen.",
		Goals = { { "🛢️", "Roll the oil course" }, { "⚡", "Earn XP on the generator" }, { "♻️", "Rebirth for big bonuses" }, { "🎳", "Buy your first new ball" } },
		Button = "CONTINUE",
	}, onContinue)
end

local function showOutro()
	showCard({
		Tab = "TUTORIAL COMPLETE",
		Heading = "YOU KNOW HOW TO BOWL!",
		Body = "Roll, rebirth and collect every ball. Become the best bowler on the leaderboards!",
		Goals = { { "🎳", "Collect every ball" }, { "🌍", "Unlock new worlds" }, { "🏆", "Climb the leaderboards" }, { "🎁", "Claim your daily gifts" } },
		Button = "KEEP GOING!",
	}, function() end)
end

--------------------------------------------------
-- CONTROLLER WALKTHROUGH
--
-- Right after the welcome card, for controller players: try the controls, then a look at
-- the menu buttons. On screen only: it sends nothing to the server and changes no step or
-- reward. Every part has a time limit and any failure skips it, so nobody gets stuck.
--------------------------------------------------

local CONTROLS_TIME = 10 -- seconds before the controls part moves on by itself
local MENUS_TIME = 12

local tourTarget, tourButton = nil, nil -- what RenderStepped spotlights and selects

local function tourPanel(title, body, height)
	local frame = create("Frame", {
		Size = UDim2.fromOffset(330, height),
		BackgroundColor3 = Color3.fromRGB(24, 16, 60),
		ZIndex = 50,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, frame)
	create("UIStroke", { Color = GOLD, Thickness = 3 }, frame)
	create("TextLabel", {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 32),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = title,
		TextColor3 = GOLD,
		TextSize = 24,
		ZIndex = 51,
	}, frame)
	local label = create("TextLabel", {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -32, 0, height - 54),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = body,
		TextColor3 = CREAM,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 51,
	}, frame)
	return frame, label
end

local function runControllerTour(onDone)
	local UserInputService = game:GetService("UserInputService")
	local lastInput = UserInputService:GetLastInputType()

	-- only someone really on a controller: a plugged-in pad nobody is using doesn't count
	if player:GetAttribute("TutorialReplayStep") ~= nil
		or not (lastInput.Name:sub(1, 7) == "Gamepad" or GuiService:IsTenFootInterface()) then
		onDone()
		return
	end

	-- a run starting, or the player moving to a mouse, keyboard or touch, ends it at once
	local function stillOn()
		local kind = UserInputService:GetLastInputType()
		return (player:GetAttribute("RunState") or "Waiting") == "Waiting"
			and kind ~= Enum.UserInputType.Keyboard and kind ~= Enum.UserInputType.MouseButton1
			and kind ~= Enum.UserInputType.Touch
	end

	introActive = true
	local panel, connections = nil, {}

	local function clearPart()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		connections = {}
		if panel then
			panel:Destroy()
			panel = nil
		end
		tourTarget, tourButton = nil, nil
		PanelManager.ControllerTour = nil
	end

	local function controlsPart()
		local hints = playerGui:FindFirstChild("ConsoleHints")
		local row = hints and hints:FindFirstChild("HintRow")
		if not row then
			return
		end
		PanelManager.ControllerTour = "Controls"
		tourTarget = row

		local names = { "Move", "Jump", "All Buttons" }
		local done = { false, false, false }
		local label
		panel, label = tourPanel("TRY THE CONTROLS!", "", 136)
		panel.AnchorPoint = Vector2.new(1, 1)
		panel.Position = UDim2.new(1, -12, 1, -124)

		local function redraw()
			local lines = {}
			for index, name in ipairs(names) do
				table.insert(lines, (done[index] and "✓  " or "•  ") .. name)
			end
			label.Text = table.concat(lines, "\n")
		end
		redraw()

		local function mark(index)
			if not done[index] then
				done[index] = true
				redraw()
			end
		end
		-- only real input from the controller earns a check
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude >= 0.5 then
				mark(1)
			end
		end))
		table.insert(connections, UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonA then
				mark(2)
			elseif input.KeyCode == Enum.KeyCode.DPadDown then
				mark(3)
			end
		end))

		local deadline = os.clock() + CONTROLS_TIME
		while os.clock() < deadline and stillOn() and not (done[1] and done[2] and done[3]) do
			task.wait(0.1)
		end
		if done[1] and done[2] and done[3] then
			task.wait(0.7) -- let the last check be seen
		end
	end

	local function menusPart()
		local hub = playerGui:FindFirstChild("HubUI")
		local tile = hub and hub:FindFirstChild("ShopButton", true)
		local grid = tile and tile.Parent
		if not stillOn() or not grid or not isShown(grid) then
			return
		end
		PanelManager.ControllerTour = "Menus"
		tourTarget = grid

		local _
		panel, _ = tourPanel("YOUR MENUS", "As you unlock them, each one shows its own shortcut button.", 170)
		local position, size = screenRect(grid)
		panel.AnchorPoint = Vector2.new(0, 0.5)
		panel.Position = UDim2.fromOffset(position.X + size.X + 28, position.Y + size.Y / 2)

		local pressed = false
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			Size = UDim2.fromOffset(200, 46),
			BackgroundColor3 = Color3.fromRGB(88, 196, 110),
			Font = FONT,
			Text = "CONTINUE",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 24,
			ZIndex = 52,
		}, panel)
		create("UICorner", { CornerRadius = UDim.new(0, 14) }, button)
		table.insert(connections, button.Activated:Connect(function()
			pressed = true
		end))
		tourButton = button -- ConsoleControls selects it, so A presses it

		local deadline = os.clock() + MENUS_TIME
		while os.clock() < deadline and stillOn() and not pressed do
			task.wait(0.1)
		end
	end

	task.spawn(function()
		for _, part in ipairs({ controlsPart, menusPart }) do
			local ok, problem = pcall(part)
			if not ok then
				warn("[TutorialUI] Controller walkthrough skipped a part:", problem)
			end
			clearPart()
		end
		introActive = false
		onDone()
	end)
end

local shownStep = nil
local wasInTutorial = false

local function updateBanner(step)
	if step == shownStep then
		return
	end
	-- first time in the tutorial: the welcome card comes first, hints start after CONTINUE
	if step == 1 and not introDone and not introActive and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then
		showIntro(function()
			runControllerTour(function()
				shownStep = nil
				updateBanner(player:GetAttribute("TutorialReplayStep") or player:GetAttribute("TutorialStep"))
			end)
		end)
	end
	shownStep = step

	if step == DONE and wasInTutorial then
		-- finished this session: the completion card (same style as the welcome card)
		wasInTutorial = false
		banner.Visible = false
		-- the completion card comes after the player closes the calendar
		task.spawn(function()
			while PanelManager.IsOpen("Calendar") do
				task.wait(0.25)
			end
			task.wait(0.4)
			if not introActive then
				showOutro()
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

	if step == 5 and PanelManager.IsOpen("Rebirth") then
		PanelManager.Close("Rebirth") -- the panel used to sit open and hide the next hint
	end
	banner.Text = textFor(step)
	setStepDecor(step)
	banner.Visible = (player:GetAttribute("RunState") or "Waiting") == "Waiting" and not introActive
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
	-- a replay (TUTORIAL button) drives the guide with its own step; the saved step stays 12
	local step = player:GetAttribute("TutorialReplayStep") or player:GetAttribute("TutorialStep")
	updateBanner(step)

	local active = typeof(step) == "number" and step >= 1 and step < DONE and not introActive

	-- the banner text depends on state (wins, panels), so keep it fresh
	if active and banner.Visible then
		banner.Text = textFor(step)
	end

	-- spotlight for button steps (only in the lobby)
	local lobby = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	local extra = (step == 4 and PanelManager.IsOpen("Rebirth")) and findGui("FreeTag") or nil
	if (step == 7 or step == 8) and shopOpen() then
		-- Do not trap clicks while the shop is open (the player must always be able to press its
		-- X), and scroll the list so the highlighted ball card is really on screen: it used to sit
		-- far above the visible list, which stretched the spotlight over the whole screen.
		for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight }) do
			frame.Active = false
		end
		local shopGui = playerGui:FindFirstChild("BallShopUI")
		local card = shopGui and shopGui:FindFirstChild(TUTORIAL_BALL, true)
		local scroller = card and card:FindFirstAncestorOfClass("ScrollingFrame")
		if scroller and os.clock() - lastShopScroll > 0.6 then
			local top = card.AbsolutePosition.Y - scroller.AbsolutePosition.Y
			if top < 0 or top + card.AbsoluteSize.Y > scroller.AbsoluteSize.Y then
				lastShopScroll = os.clock()
				scroller.CanvasPosition = Vector2.new(0, math.max(0, scroller.CanvasPosition.Y + top - 8))
			end
		end
	else
		for _, frame in ipairs({ dimTop, dimBottom, dimLeft, dimRight }) do
			frame.Active = true
		end
	end
	local spotlight = active and lobby and spotlightTarget(step) or nil
	if tourTarget then
		-- the controller walkthrough: lights its target, selects only its own button
		PanelManager.TutorialTarget = tourButton
		setSpotlight(tourTarget, nil)
	else
		PanelManager.TutorialTarget = spotlight -- controllers get it selected (ConsoleControls)
		setSpotlight(spotlight, extra)
	end

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
-- The whole tutorial (banner, arrows, distance) is hidden while on a course and comes
-- back in the lobby, so nothing covers the run.
local function applyCourseVisibility()
	local inLobby = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	gui.Enabled = inLobby
	if inLobby and shownStep ~= nil and shownStep < DONE and shownStep >= 1 then
		banner.Visible = true
	end
end
player:GetAttributeChangedSignal("RunState"):Connect(applyCourseVisibility)
applyCourseVisibility()

-- While the Ball Shop is open, dock the instruction panel at the BOTTOM of the screen: on
-- laptops and short windows it used to sit over the shop's X, so players could not leave it.
task.spawn(function()
	local docked = false
	while true do
		task.wait(0.1)
		local wantDock = panel.Visible and shopOpen()
		if wantDock ~= docked then
			docked = wantDock
			if docked then
				panel.AnchorPoint = Vector2.new(0.5, 1)
				panel.Position = UDim2.new(0.5, 0, 1, -10)
			else
				panel.AnchorPoint = Vector2.new(0.5, 0)
				panel.Position = UDim2.new(0.5, 0, PANEL_Y, 0)
			end
		end
	end
end)
