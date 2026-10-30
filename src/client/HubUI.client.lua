--------------------------------------------------
-- HUB UI
--
-- CLIENT ONLY. The left-side hub:
--   * Wins counter with a trophy. Every time the server raises the
--     "Wins" attribute (e.g. per WinCourse tile) a "+N" trophy flies
--     into the counter with a sound.
--   * SHOP     -> game pass list (ShopConfig)
--   * REBIRTH  -> toggles the existing RebirthUIClient panel
--   * GIFT     -> timed gift countdown / claim
--   * DAILY    -> daily gift (calendar) / claim
--
-- Nothing here decides rewards. Gifts are claimed through the
-- GiftClaim remote; the server validates, grants and answers via
-- GiftResult. Success is only shown when the server confirms it.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")

local GiftConfig = require(ReplicatedStorage:WaitForChild("GiftConfig"))
local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local giftState = remotes:WaitForChild("GiftState")
local giftClaim = remotes:WaitForChild("GiftClaim")
local giftResult = remotes:WaitForChild("GiftResult")

--------------------------------------------------
-- STYLE (bowling alley: ink, lane wood, cream)
--------------------------------------------------

local INK = Color3.fromRGB(24, 22, 34)          -- outlines / text strokes
local INK_LIGHT = Color3.fromRGB(255, 247, 232)   -- cream pill
local LANE = Color3.fromRGB(240, 178, 82)         -- polished lane wood
local CREAM = Color3.fromRGB(255, 250, 240)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GREEN = Color3.fromRGB(88, 196, 110)
local SKY = Color3.fromRGB(86, 168, 240)
local PURPLE = Color3.fromRGB(150, 98, 230)
local FONT = Enum.Font.FredokaOne

local TROPHY_IMAGE = "rbxassetid://135956636242633"
-- Built-in client sound, no asset id needed. Swap for a custom one later.
local WIN_SOUND_ID = "rbxasset://sounds/electronicpingshort.wav"

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function outline(inst, color, thickness)
	create("UIStroke", { Color = color, Thickness = thickness }, inst)
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	-- each step starts where the one below would round up to "1000.0" (999,996,000 is 1.0B)
	if value >= 999.95e9 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 999.995e6 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 999.995e3 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.2fK", value / 1e3)
	end
	return tostring(value)
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

local function bump(scaleObject, amount)
	scaleObject.Scale = amount
	TweenService:Create(
		scaleObject,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

--------------------------------------------------
-- ROOT
--------------------------------------------------

local old = playerGui:FindFirstChild("HubUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "HubUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 6,
}, playerGui)

local left = create("Frame", {
	Name = "Left",
	BackgroundTransparency = 1,
	-- lower than before so the Roblox chat window does not cover the wins counter
	Position = UDim2.new(0, 10, 0.37, 0),
	Size = UDim2.fromOffset(216, 440),
}, gui)

local rootScale = create("UIScale", { Scale = 1 }, left)

-- The column starts below the Roblox chat window and must end above the
-- rebirth panel in the bottom-left corner (HudUI: 132 tall, scaled by
-- width / 900 up to 1, 10 px from the bottom). It is as big as the screen
-- allows: scaled to fit that gap, and if the screen is too short it starts
-- higher instead of overlapping.
local COLUMN_HEIGHT = 338 -- content height at scale 1
-- When XP lands while the level bar is full (a rebirth is required), the REBIRTH
-- button wiggles in sync with the shaking meter (HudUI), so the eye is led to it.
task.spawn(function()
	local xpAward = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("XPAward")
	local wiggling = false
	xpAward.OnClientEvent:Connect(function(amount)
		if wiggling or player:GetAttribute("RebirthMaxReached") ~= true then
			return
		end
		local button
		for _, d in ipairs(gui:GetDescendants()) do
			if d.Name == "RebirthButton" and d:IsA("GuiObject") then
				button = d
				break
			end
		end
		if not button or not button.Visible then
			return
		end
		wiggling = true
		local base = button.Rotation
		for _, angle in ipairs({ 7, -7, 5, -5, 0 }) do
			TweenService:Create(button, TweenInfo.new(0.06), { Rotation = base + angle }):Play()
			task.wait(0.06)
		end
		button.Rotation = base
		task.wait(0.5)
		wiggling = false
	end)
end)

local function updateRootScale()
	local viewport = gui.AbsoluteSize
	local rebirthScale = math.clamp(viewport.X / 900, 0.65, 1)
	-- touch screens: the rebirth multipliers are a compact panel in the bottom-left corner
	-- (HudUI: 15% of the screen height), so the column ends just above it
	local rebirthTop = UserInputService.TouchEnabled
		and (viewport.Y - 8 - 132 * math.clamp(viewport.Y * 0.15 / 132, 0.4, 1) - 10)
		or (viewport.Y - 10 - 132 * rebirthScale - 10)

	local topFraction = UserInputService.TouchEnabled and 0.2 or 0.335 -- phones: a little higher
	local fit = (rebirthTop - topFraction * viewport.Y) / COLUMN_HEIGHT
	if fit < 0.75 then
		topFraction = 0.28
		fit = (rebirthTop - topFraction * viewport.Y) / COLUMN_HEIGHT
	end
	if fit < 0.75 then
		topFraction = 0.2
		fit = (rebirthTop - topFraction * viewport.Y) / COLUMN_HEIGHT
	end

	left.Position = UDim2.new(0, 10, topFraction, 0)
	-- Phones: the old viewport.Y / 760 cap halved the hub on a ~370 px tall screen even
	-- though there was room. On touch screens it fills the free height above the
	-- multipliers panel (fit), a little larger than before (alignWinsToBoost below then
	-- lines the trophy up with x2 WINS and trims the size if it would reach the multipliers).
	if UserInputService.TouchEnabled then
		rootScale.Scale = math.clamp(fit * 1.12, 0.5, 1.2)
	else
		rootScale.Scale = math.clamp(math.min(viewport.Y / 760, fit), 0.5, 1.2)
	end
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateRootScale)
updateRootScale()

-- All devices: the wins trophy sits level with (top edge = top edge of) the x2 WINS tile on the right
-- side of the screen. The column slides down to that line; if its bottom would then reach
-- the oil / trophy multipliers panel in the bottom-left corner, it is scaled down to fit.
-- (Measured from the real on-screen objects, so it follows any screen shape.)
do
	local function winsPillObject()
		return left:FindFirstChild("Wins")
	end
	-- The x2 WINS tile is a Frame (button + "4 ONLY!" label); the trophy lines up with its button.
	local function firstBoostTile()
		local boost = playerGui:FindFirstChild("BoostButtonsUI")
		local column = boost and boost:FindFirstChildWhichIsA("Frame")
		if not column then
			return nil
		end
		local best
		for _, child in ipairs(column:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible and (not best or child.LayoutOrder < best.LayoutOrder) then
				best = child
			end
		end
		return best and (best:FindFirstChildWhichIsA("GuiButton") or best)
	end
	local function alignWinsToBoost()
		local pill, tile = winsPillObject(), firstBoostTile()
		if not pill or not tile or tile.AbsoluteSize.Y <= 0 or not gui.Enabled then
			return
		end
		-- TOP edges level (the pill is shorter than the x2 WINS button, so centring it looked low)
		local delta = tile.AbsolutePosition.Y - pill.AbsolutePosition.Y
		if math.abs(delta) > 1 then
			left.Position = UDim2.new(left.Position.X.Scale, left.Position.X.Offset, left.Position.Y.Scale, left.Position.Y.Offset + delta)
		end
		-- keep clear of the multipliers panel
		local hud = playerGui:FindFirstChild("HudUI")
		local multipliers = hud and hud:FindFirstChild("RebirthPanel", true)
		if multipliers and multipliers.AbsoluteSize.Y > 0 then
			local top = left.AbsolutePosition.Y
			local bottom = top + COLUMN_HEIGHT * rootScale.Scale
			local limit = multipliers.AbsolutePosition.Y - 6
			if bottom > limit and limit > top + 60 then
				rootScale.Scale = math.max(0.45, rootScale.Scale * (limit - top) / (bottom - top))
			end
		end
	end
	-- every frame (cheap, exits as soon as the two are level): the x2 WINS column moves when a
	-- tile appears or the window resizes, and a slow poll left the trophy visibly off in between
	RunService.RenderStepped:Connect(function()
		pcall(alignWinsToBoost)
	end)
end

--------------------------------------------------
-- WINS COUNTER
--------------------------------------------------

-- The wins counter: a wide gold plate (wider than the button grid below it, so big totals
-- like 12.34M never look cramped), soft top-to-bottom gold gradient with a thin shine line,
-- and the trophy popping slightly out of its left end.
local WINS_WIDTH = 216
local winsPill = create("Frame", {
	Name = "Wins",
	Size = UDim2.fromOffset(WINS_WIDTH, 60),
	BackgroundColor3 = Color3.new(1, 1, 1), -- the gradient below gives the gold
	BackgroundTransparency = 0,
}, left)
round(winsPill, 18)
outline(winsPill, INK, 3)
create("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(232, 160, 60)),
}, winsPill)
local winsShine = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 6, 0, 6),
	Size = UDim2.new(1, -76, 0, 5),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, winsPill)
round(winsShine, 3)
local winsScale = create("UIScale", { Scale = 1 }, winsPill)

local winsIcon = create("ImageLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(2, 1),
	Size = UDim2.fromOffset(56, 56),
	Image = TROPHY_IMAGE,
	ZIndex = 2,
}, winsPill)

local winsLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(62, 0),
	Size = UDim2.new(1, -72, 1, 0),
	Font = FONT,
	Text = "0",
	TextColor3 = CREAM,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 2,
}, winsPill)
create("UIStroke", { Color = INK, Thickness = 2.5 }, winsLabel)

local displayedWins = 0
local inFlight = 0

local function setDisplayedWins(value)
	displayedWins = value
	winsLabel.Text = formatNumber(value)
end

local winSound = create("Sound", {
	SoundId = WIN_SOUND_ID,
	Volume = 0.45,
}, gui)

local comboCount = 0
local lastWinTime = 0

local function playWinSound()
	local now = os.clock()
	comboCount = (now - lastWinTime < 1.2) and math.min(comboCount + 1, 8) or 0
	lastWinTime = now

	winSound.PlaybackSpeed = 1 + comboCount * 0.06
	winSound:Play()
end

local function flyWins(amount)
	inFlight += 1

	local viewport = gui.AbsoluteSize
	local startPosition = UDim2.fromOffset(
		viewport.X * 0.3 + math.random(-40, 40),
		viewport.Y * 0.5 + math.random(-60, 60)
	)

	local token = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = startPosition,
		Size = UDim2.fromOffset(200, 64),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, gui)

	create("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(0, 4),
		Image = TROPHY_IMAGE,
		ZIndex = 30,
	}, token)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(1, -62, 1, 0),
		Font = FONT,
		Text = "+" .. formatNumber(amount),
		TextColor3 = CREAM,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 30,
	}, token)
	create("UIStroke", { Color = INK, Thickness = 4.5 }, label)

	-- Pop in big, hold a beat, then drag into the counter (shrinking as it goes).
	token.Size = UDim2.fromOffset(90, 30)
	TweenService:Create(
		token,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(200, 64) }
	):Play()

	task.delay(0.28, function()
		local target = winsPill.AbsolutePosition
			+ Vector2.new(24, winsPill.AbsoluteSize.Y / 2)

		local tween = TweenService:Create(
			token,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(target.X + 40, target.Y), Size = UDim2.fromOffset(120, 38) }
		)
		tween.Completed:Once(function()
			token:Destroy()
			inFlight -= 1
			setDisplayedWins(displayedWins + amount)
			bump(winsScale, 1.2)
			playWinSound()
		end)
		tween:Play()
	end)
end

local lastWins = nil

local function onWinsChanged()
	local wins = player:GetAttribute("Wins")
	if typeof(wins) ~= "number" then
		return
	end

	if lastWins == nil then
		-- First value: show it without animation.
		lastWins = wins
		setDisplayedWins(wins)
		return
	end

	local delta = wins - lastWins
	lastWins = wins

	if delta > 0 then
		flyWins(delta)
	else
		-- Spent or reset: snap to the real value.
		setDisplayedWins(wins)
	end
end

player:GetAttributeChangedSignal("Wins"):Connect(onWinsChanged)
onWinsChanged()

-- Safety net: if nothing is in flight, the label must equal the real value.
task.spawn(function()
	while true do
		task.wait(1)
		local wins = player:GetAttribute("Wins")
		if inFlight == 0 and typeof(wins) == "number" and displayedWins ~= wins then
			setDisplayedWins(wins)
		end
	end
end)

--------------------------------------------------
-- HUB BUTTONS
--------------------------------------------------

local grid = create("Frame", {
	Name = "Buttons",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.fromOffset(176, 268),
}, left)

create("UIGridLayout", {
	CellSize = UDim2.fromOffset(84, 84),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

local BadgeOverlay = require(game:GetService("ReplicatedStorage"):WaitForChild("BadgeOverlay"))

local function makeHubButton(order, name, icon, caption, color, tilt)
	local button = create("TextButton", {
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		Rotation = tilt or 0,
		Text = "",
		AutoButtonColor = false,
	}, grid)
	round(button, 14)
	outline(button, INK, 3)
	local scale = create("UIScale", { Scale = 1 }, button)

	-- Soft glare across the button every 5 seconds (staggered per button).
	Shine.Attach(button, { Offset = order * 0.8 })

	-- Icon area (emoji, or a 3D/trophy preview placed by the caller).
	local iconHolder = create("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 46),
	}, button)

	create("TextLabel", {
		Name = "Emoji",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = icon,
		TextSize = 32,
		TextColor3 = CREAM,
	}, iconHolder)

	local captionLabel = create("TextLabel", {
		Name = "Caption",
		BackgroundColor3 = INK_LIGHT,
		Position = UDim2.new(0, 6, 1, -26),
		Size = UDim2.new(1, -12, 0, 20),
		Font = FONT,
		Text = caption,
		TextColor3 = INK,
		TextSize = 14,
	}, button)
	round(captionLabel, 8)

	-- "!" badge for something claimable.
	local badge = create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = PIN_RED,
		Font = FONT,
		Text = "!",
		TextColor3 = CREAM,
		TextSize = 16,
		Visible = false,
		ZIndex = 5,
	}, button)
	round(badge, 12)
	local badgeScale = create("UIScale", { Scale = 1 }, badge)

	-- The badge is drawn in an overlay layer ABOVE every button (see
	-- BadgeOverlay) and pops in whenever it appears.
	badge:GetPropertyChangedSignal("Visible"):Connect(function()
		if badge.Visible then
			badgeScale.Scale = 0.3
			TweenService:Create(badgeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
	BadgeOverlay.Attach(badge, button, { Dx = 6, Dy = -6 })

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	return {
		Button = button,
		Scale = scale,
		Icon = iconHolder,
		Caption = captionLabel,
		Badge = badge,
		BadgeScale = badgeScale,
	}
end

local shopButton = makeHubButton(1, "ShopButton", "🎳", "STORE", PIN_RED, -3)
-- the store's "!" stays on permanently, also while the store is open
if shopButton.Badge then
	shopButton.Badge.Visible = true
	shopButton.Badge:GetPropertyChangedSignal("Visible"):Connect(function()
		if not shopButton.Badge.Visible then
			shopButton.Badge.Visible = true
		end
	end)
end
local rebirthButton = makeHubButton(2, "RebirthButton", "♻", "REBIRTH", PURPLE, 2)

-- Percent to the next rebirth, floating over the REBIRTH button.
-- The percentage floats OVER the REBIRTH button's top-right corner: no box, just big bright
-- outlined text. It is drawn in the hub's overlay layer (BadgeOverlay), so the
-- buttons around it can never cover or cut it off.
local PERCENT_GREEN = Color3.fromRGB(120, 255, 120)
local rebirthPercent = create("TextLabel", {
	Name = "RebirthPercent",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(90, 30),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "0%",
	TextColor3 = PERCENT_GREEN,
	TextSize = 24, -- fixed size, no tilt and no scaling: rotated or scaled text is resampled and looks blurry
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 7,
}, rebirthButton.Button)
outline(rebirthPercent, INK, 3)
BadgeOverlay.Attach(rebirthPercent, rebirthButton.Button, { Dx = 10, Dy = -14 })

local function refreshRebirthPercent()
	local level = player:GetAttribute("Level") or 1
	local required = math.max(player:GetAttribute("RebirthLevelRequirement") or 2, 1)
	local progress = player:GetAttribute("LevelProgress") or 0
	local fraction = math.clamp((level - 1 + (level >= required and 0 or progress)) / math.max(required - 1, 1), 0, 1)

	if fraction >= 1 then
		rebirthPercent.Text = "READY!"
		rebirthPercent.TextColor3 = Color3.fromRGB(255, 96, 96)
		rebirthButton.Badge.Visible = false -- the READY! sticker already says it
	else
		rebirthPercent.Text = math.floor(fraction * 100) .. "%"
		rebirthPercent.TextColor3 = PERCENT_GREEN
		rebirthButton.Badge.Visible = false
	end
end

for _, name in ipairs({ "Level", "RebirthLevelRequirement", "LevelProgress" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshRebirthPercent)
end
refreshRebirthPercent()
local giftButton = makeHubButton(3, "GiftButton", "🎁", "...", SKY, 3)
local dailyButton = makeHubButton(4, "DailyButton", "📅", "...", GREEN, -2)
local x6Button = makeHubButton(5, "X6Button", "X6", "...", Color3.fromRGB(255, 170, 40), 3)
x6Button.Button.Visible = false -- X6 now arrives as a random timed popup (PopupsUI)

--------------------------------------------------
-- TUTORIAL VISIBILITY
--
-- New players start with REBIRTH and the DAILY calendar hidden so the
-- tutorial can introduce them (TutorialService publishes TutorialStep):
-- REBIRTH appears at step 4, the calendar at step 11. Veterans (step 12)
-- see everything. If the step never arrives, show everything after 8 s.
--------------------------------------------------

local TUTORIAL_REBIRTH_STEP = 4
local TUTORIAL_CALENDAR_STEP = 11
local tutorialWaitedOut = false

local function applyTutorialVisibility()
	local step = player:GetAttribute("TutorialStep")
	local known = typeof(step) == "number" and step >= 1

	local showRebirth = known and step >= TUTORIAL_REBIRTH_STEP or (not known and tutorialWaitedOut)
	local showCalendar = known and step >= TUTORIAL_CALENDAR_STEP or (not known and tutorialWaitedOut)

	rebirthButton.Button.Visible = showRebirth
	dailyButton.Button.Visible = showCalendar
end

player:GetAttributeChangedSignal("TutorialStep"):Connect(applyTutorialVisibility)
applyTutorialVisibility()
task.delay(8, function()
	tutorialWaitedOut = true
	applyTutorialVisibility()
end)
local questsButton = makeHubButton(6, "QuestsButton", "📋", "QUESTS", Color3.fromRGB(255, 140, 80), -2)

--------------------------------------------------
-- REWARD PREVIEW (automatic ViewportFrame for ball rewards)
--------------------------------------------------

local function applyRewardPreview(holder, reward)
	local existing = holder:FindFirstChild("Preview")
	if existing then
		existing:Destroy()
	end

	local emoji = holder:FindFirstChild("Emoji")

	if reward.Type == "Wins" then
		if emoji then
			emoji.Visible = false
		end
		create("ImageLabel", {
			Name = "Preview",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(40, 40),
			Image = TROPHY_IMAGE,
			ZIndex = 24,
		}, holder)
		return
	end

	if reward.Type == "Ball" or reward.Type == "Offer" then
		local models = ReplicatedStorage:FindFirstChild("BallModels")
		local template = models and models:FindFirstChild(reward.BallId)
		if not template then
			-- designs without a BallModels mesh (Oil Barrel): a plain sphere
			local BA = require(ReplicatedStorage:WaitForChild("BallAccessories"))
			if BA.HasDesign(reward.BallId) then
				template = Instance.new("Part")
				template.Shape = Enum.PartType.Ball
				template.Size = Vector3.new(2.8, 2.8, 2.8)
			end
		end
		if template then
			if emoji then
				emoji.Visible = false
			end

			local viewport = create("ViewportFrame", {
				Name = "Preview",
				BackgroundTransparency = 1,
				ZIndex = 24,
				Size = UDim2.fromScale(1, 1),
			}, holder)

			local model = template:Clone()
			model.Anchored = true
			model.CFrame = CFrame.new(0, 0, 0)
			model.Parent = viewport

			local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))
			BallAccessories.Apply(model, reward.BallId)
			if reward.BallId == "OilBarrel" then
				model:SetAttribute("PreviewSpeed", 12)
			end
			local hasDesign = BallAccessories.HasDesign(reward.BallId)

			local radius = math.max(model.Size.X, model.Size.Y, model.Size.Z)
			local camera = create("Camera", {
				CFrame = reward.BallId == "OilBarrel" and CFrame.lookAt(Vector3.new(4.6, 3.4, 6.2), Vector3.new(0, -0.1, 0)) or CFrame.lookAt(
					Vector3.new(0, hasDesign and radius * 0.5 or 0, radius * (reward.BallId == "OilBarrel" and 2.7 or (hasDesign and 3.3 or 2.2))),
					Vector3.zero
				),
				FieldOfView = reward.BallId == "OilBarrel" and 34 or 35,
			}, viewport)
			viewport.CurrentCamera = camera

			-- Slow spin, only while the viewport exists.
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				if not viewport.Parent then
					connection:Disconnect()
					return
				end
				if reward.BallId ~= "OilBarrel" then
					model.CFrame = model.CFrame * CFrame.Angles(0, dt * 1.2, 0)
				end
				BallAccessories.Pose(model, os.clock())
			end)
		end
	end
end

applyRewardPreview(giftButton.Icon, GiftConfig.TimedGift.Reward)

-- The daily gift keeps the calendar emoji; its reward is shown in the toast.

--------------------------------------------------
-- TOAST (server-confirmed results only)
--------------------------------------------------

local toast = create("TextLabel", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 80),
	Size = UDim2.fromOffset(320, 42),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.1,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 18,
	Visible = false,
	ZIndex = 40,
}, gui)
round(toast, 12)
outline(toast, INK, 3)

local toastToken = 0
local function showToast(text, good)
	toastToken += 1
	local token = toastToken

	toast.Text = text
	toast.TextColor3 = good and CREAM or PIN_RED
	toast.Visible = true

	task.delay(2.5, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

local function describe(reward)
	if reward.Type == "Wins" then
		return "+" .. formatNumber(reward.Amount) .. " 🏆"
	elseif reward.Type == "Oil" then
		return "+" .. formatNumber(reward.Amount) .. " starter oil for your next run"
	elseif reward.Type == "Ball" then
		return "New ball unlocked: " .. tostring(reward.BallId)
	elseif reward.Type == "Rebirth" then
		return "+1 Rebirth!"
	end
	return "Reward"
end

--------------------------------------------------
-- GIFT STATE (timed gift + daily calendar)
--------------------------------------------------

local timedReadyAt = nil   -- os.clock() when the timed gift becomes ready
local calendar = nil       -- { Streak, NextSlot, SecondsToNext } from the server
local calendarNextAt = nil -- os.clock() when a new calendar day starts

local rebuildCalendar -- defined below

local function pullGiftState()
	local ok, state = pcall(function()
		return giftState:InvokeServer()
	end)

	if not ok or typeof(state) ~= "table" then
		return
	end

	timedReadyAt = os.clock() + (state.Timed or 0)

	if typeof(state.Calendar) == "table" then
		calendar = state.Calendar
		calendarNextAt = os.clock() + (calendar.SecondsToNext or 0)
	else
		calendar = nil
	end

	if rebuildCalendar then
		rebuildCalendar()
	end
end

local function refreshGiftButtons()
	local now = os.clock()

	if timedReadyAt then
		local remaining = timedReadyAt - now
		if remaining <= 0 then
			giftButton.Caption.Text = "CLAIM!"
			giftButton.Badge.Visible = true
		else
			giftButton.Caption.Text = formatTime(remaining)
			giftButton.Badge.Visible = false
		end
	end

	if not calendar then
		dailyButton.Caption.Text = "..."
		dailyButton.Badge.Visible = false
	elseif calendar.NextSlot then
		dailyButton.Caption.Text = "CLAIM!"
		dailyButton.Badge.Visible = true
	else
		dailyButton.Caption.Text = formatTime(calendarNextAt - now)
		dailyButton.Badge.Visible = false
	end

	-- X6 limited-time boost (state is published by the server)
	local x6Mode = player:GetAttribute("X6Mode")
	local x6Until = player:GetAttribute("X6Until")
	local x6Remaining = typeof(x6Until) == "number"
		and (x6Until - workspace:GetServerTimeNow())
		or 0

	-- stationary CLAIM label (the countdown lives on the X6 generator itself)
	x6Button.Caption.Text = "CLAIM"
	x6Button.Badge.Visible = x6Mode == "Ready"
	local _ = x6Remaining
end

-- Arrow trail to the X6 generator of the player's CURRENT world after
-- claiming; it disappears once they roll onto it (or the boost ends).
local x6Trail = require(ReplicatedStorage:WaitForChild("GroundArrows")).new("X6Arrows")
local x6Arrow = nil
local function showX6Arrow()
	if x6Arrow then
		return
	end
	local worldId = player:GetAttribute("World") or 1
	local worlds = workspace:FindFirstChild("Worlds")
	local root = worldId == 1 and workspace:FindFirstChild("XPGenerators")
		or (worlds and worlds:FindFirstChild("World" .. worldId) and worlds["World" .. worldId]:FindFirstChild("XPGenerators"))
	local gen = root and root:FindFirstChild("GenX6", true)
	if not gen or not gen:IsA("BasePart") then
		return
	end
	local conn
	local function clear()
		conn:Disconnect()
		x6Trail:Hide()
		x6Arrow = nil
	end
	conn = game:GetService("RunService").RenderStepped:Connect(function()
		local balls = workspace:FindFirstChild("PlayerBalls")
		local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
		x6Trail:Update(ball, gen.Position)
		if ball then
			local flat = Vector3.new(ball.Position.X - gen.Position.X, 0, ball.Position.Z - gen.Position.Z)
			if flat.Magnitude < math.max(gen.Size.X, gen.Size.Z) / 2 + 3 then
				clear() -- rolled onto it
				return
			end
		end
		local mode = player:GetAttribute("X6Mode")
		if (mode ~= "Active" and mode ~= "Ready") or (player:GetAttribute("World") or 1) ~= worldId then
			clear()
		end
	end)
	x6Arrow = clear
end
local x6ClaimRemote = remotes:WaitForChild("X6Claim")
local x6ResultRemote = remotes:WaitForChild("X6Result")

x6Button.Button.Activated:Connect(function()
	local mode = player:GetAttribute("X6Mode")

	-- does nothing until the gift is ready (the timer is on the generator)
	if mode == "Ready" then
		x6ClaimRemote:FireServer()
	elseif mode == "Active" then
		showX6Arrow()
	end
end)

x6ResultRemote.OnClientEvent:Connect(function(success, info)
	if success then
		showX6Arrow()
		showToast("X6 BOOST ON for " .. formatTime(info) .. "! Roll onto the X6 generator!", true)
	else
		showToast(tostring(info), false)
	end
end)

task.spawn(function()
	local sinceRetry = 0
	pullGiftState()
	while true do
		task.wait(1)
		sinceRetry += 1

		-- The server loads the calendar asynchronously after join, so keep
		-- asking until it is known; also re-ask when a new day starts.
		local newDay = calendar and not calendar.NextSlot
			and calendarNextAt and os.clock() >= calendarNextAt
		if (timedReadyAt == nil or calendar == nil or newDay) and sinceRetry >= 2 then
			sinceRetry = 0
			pullGiftState()
		end

		refreshGiftButtons()
	end
end)

-- Badge pulse so a claimable gift is noticeable but not noisy.
task.spawn(function()
	while true do
		task.wait(2.5)
		if giftButton.Badge.Visible then
			bump(giftButton.BadgeScale, 1.25)
		end
		if dailyButton.Badge.Visible then
			bump(dailyButton.BadgeScale, 1.25)
		end
	end
end)

-- Tutorial nudge: pulse the button the current tutorial step points at
-- (step 5 = Rebirth, step 6 = Daily). The step itself is server-owned.
task.spawn(function()
	while true do
		task.wait(1.3)
		local step = player:GetAttribute("TutorialStep")
		if step == 5 then
			bump(rebirthButton.Scale, 1.14)
		elseif step == 6 then
			bump(dailyButton.Scale, 1.14)
		end
	end
end)

giftButton.Button.Activated:Connect(function()
	if timedReadyAt and timedReadyAt - os.clock() > 0 then
		showToast("Next gift in " .. formatTime(timedReadyAt - os.clock()), true)
		return
	end
	giftClaim:FireServer("Timed")
end)

--------------------------------------------------
-- DAILY CALENDAR PANEL (horizontal, 7 slots, manual claim)
--------------------------------------------------

local calendarPanel = create("Frame", {
	Name = "CalendarPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.44),
	Size = UDim2.fromOffset(760, 262),
	BackgroundColor3 = LANE,
	Visible = false,
	ZIndex = 20,
}, gui)
round(calendarPanel, 18)
outline(calendarPanel, INK, 4)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(240, 160, 60)),
	Rotation = 90,
}, calendarPanel)
local calendarScale = create("UIScale", { Scale = 1 }, calendarPanel)

local function updateCalendarScale()
	local viewport = gui.AbsoluteSize
	calendarScale.Scale = math.clamp(viewport.X / 800, 0.45, 1.1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCalendarScale)
updateCalendarScale()

local calendarTitle = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.fromOffset(400, 34),
	Font = FONT,
	Text = "DAILY CALENDAR",
	TextColor3 = CREAM,
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
}, calendarPanel)
create("UIStroke", { Color = INK, Thickness = 3 }, calendarTitle)

local calendarHint = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 44),
	Size = UDim2.new(1, -90, 0, 20),
	Font = FONT,
	Text = "Claim every day to keep your streak!",
	TextColor3 = INK,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
}, calendarPanel)

local calendarClose = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = PIN_RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
	ZIndex = 21,
}, calendarPanel)
round(calendarClose, 10)
outline(calendarClose, INK, 3)

local slotRow = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 76),
	Size = UDim2.new(1, -24, 1, -90),
	ZIndex = 21,
}, calendarPanel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, slotRow)

local calendarDays = GiftConfig.DailyCalendar.Days

-- Day 7 is the Oil Barrel's Robux offer, never a reward. Display only: the buy
-- button opens Roblox's own purchase prompt, and the SERVER (ExclusiveBallService)
-- verifies the pass and grants the ball.
local CAL_ROBUX = utf8.char(0xE002)
local CalExclusive = require(ReplicatedStorage:WaitForChild("ExclusiveOffer")) -- same cached module (pricing helper)
local barrelBallOwned = false -- the saved ball is owned (pass, Captain pack or an earlier free day 7)


local function barrelOwned()
	return player:GetAttribute("OwnsBarrelPass") == true or barrelBallOwned
end

local function slotText(reward)
	if reward.Type == "Offer" then
		return "RAINBOW\nOIL BARREL"
	elseif reward.Type == "Wins" then
		return "+" .. formatNumber(reward.Amount) .. "\n🏆"
	elseif reward.Type == "Oil" then
		return formatNumber(reward.Amount) .. " OIL\nSTART"
	elseif reward.Type == "Ball" then
		return "OIL BARREL\nBALL"
	elseif reward.Type == "BallNext" then
		return "NEXT\nBALL"
	elseif reward.Type == "Rebirth" then
		return "+1\nREBIRTH"
	end
	return "GIFT"
end

local function slotIcon(holder, reward)
	if reward.Type == "Wins" or reward.Type == "Ball" or reward.Type == "Offer" then
		applyRewardPreview(holder, reward)
		return
	end

	if reward.Type == "Oil" then
		create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = require(ReplicatedStorage:WaitForChild("UiAssets")).OilImages.Black,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 23,
		}, holder)
		return
	end

	local emoji = ({ BallNext = "🎳", Rebirth = "♻" })[reward.Type] or "🎁"
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = emoji,
		TextSize = 34,
		ZIndex = 23,
	}, holder)
end

rebuildCalendar = function()
	for _, child in ipairs(slotRow:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local nextSlot = calendar and calendar.NextSlot
	local streak = calendar and calendar.Streak or 0

	-- A new cycle (next slot 1) shows nothing claimed.
	local claimedUpTo = (nextSlot == 1) and 0 or streak

	for index, reward in ipairs(calendarDays) do
		local claimed = index <= claimedUpTo
		local claimable = nextSlot == index

		local jackpot = reward.Special == true
		local slot = create("TextButton", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(94, 154),
			BackgroundColor3 = claimable and Color3.fromRGB(255, 244, 190)
				or (claimed and Color3.fromRGB(214, 238, 214) or (jackpot and Color3.fromRGB(255, 220, 110) or CREAM)),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 22,
		}, slotRow)
		round(slot, 12)
		create("UIStroke", {
			Color = claimable and PIN_RED or (jackpot and Color3.fromRGB(200, 130, 0) or INK),
			Thickness = (claimable or jackpot) and 4 or 3,
		}, slot)
		if jackpot then
			-- the day 7 jackpot stands out: gold card with a shine
			create("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 190, 60)),
				Rotation = 90,
			}, slot)
			Shine.Attach(slot, { Offset = 0.5 })
		end
		if claimable then
			-- today's reward breathes so the eye goes straight to it
			local pulse = create("UIScale", { Scale = 1 }, slot)
			TweenService:Create(pulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.06 }):Play()
		end

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 20),
			Font = FONT,
			Text = reward.Type == "Offer" and "EXCLUSIVE" or (reward.Special and "JACKPOT!" or ("DAY " .. index)),
			TextColor3 = reward.Special and PIN_RED or INK,
			TextSize = 14,
			ZIndex = 23,
		}, slot)

		local iconHolder = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.fromOffset(70, 56),
			ZIndex = 23,
		}, slot)
		slotIcon(iconHolder, reward)
		if (reward.Type == "Ball" or reward.Type == "Offer") and not iconHolder:FindFirstChild("Preview") then
			-- a 3D barrel preview did not render reliably here (its mesh loads late):
			-- the jackpot slot shows a big swaying barrel icon instead, never empty
			for _, child in ipairs(iconHolder:GetChildren()) do
				child:Destroy()
			end
			local icon = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = FONT,
				Text = "🛢️",
				TextSize = 44,
				ZIndex = 24,
			}, iconHolder)
			TweenService:Create(icon, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 8 }):Play()
		end
		if claimed then
			-- a clear check over every collected day
			local check = create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = GREEN,
				Font = FONT,
				Text = "✓",
				TextColor3 = CREAM,
				TextSize = 28,
				ZIndex = 25,
			}, iconHolder)
			round(check, 20)
			outline(check, INK, 2)
		end

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 86),
			Size = UDim2.new(1, -4, 0, 34),
			Font = FONT,
			Text = slotText(reward),
			TextColor3 = INK,
			TextSize = 13,
			ZIndex = 23,
		}, slot)

		local offer = reward.Type == "Offer" and ShopConfig.ExclusiveBalls[reward.BallId] or nil
		local offerOwned = offer ~= nil and barrelOwned()
		local status = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 22),
			BackgroundColor3 = offer and (offerOwned and INK or Color3.fromRGB(0, 190, 112))
				or (claimable and PIN_RED or (claimed and GREEN or INK)),
			Font = FONT,
			Text = offer and (offerOwned and "OWNED"
					or (offer.PassId ~= 0 and ("      " .. tostring(offer.Price)) or "SOON"))
				or (claimable and "CLAIM!" or (claimed and "DONE" or "LOCKED")),
			TextColor3 = CREAM,
			TextSize = 13,
			ZIndex = 23,
		}, slot)
		round(status, 8)
		if offer and not offerOwned and offer.PassId ~= 0 then
			local pricing = CalExclusive.CachedPricing(offer)
			if pricing.Pay < pricing.Base then
				status.Text = tostring(pricing.Pay)
				CalExclusive.ShowDiscount(status, pricing, { Mode = "Center", Inset = 24, Width = 54, OldSize = 10 })
			end
		end
		if offer and not offerOwned and offer.PassId ~= 0 then
			-- the same Robux icon the Ball Shop uses, then the configured price (never a live lookup)
			-- a sibling of the price pill (not its child): the pill gets left padding when a discount is
			-- shown, and a child icon was pushed along with the text, landing on the old price
			create("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 1, -17), -- the pill's left end: slot bottom - 6 margin - 22/2
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = "rbxasset://textures/ui/common/robux.png",
				ZIndex = 24,
			}, slot)
		end

		-- The Oil Barrel offer slot: tapping it only opens Roblox's own purchase prompt
		-- (a deliberate tap, never automatic); it is never claimed and grants nothing here.
		if offer then
			slot.Activated:Connect(function()
				if offer.PassId ~= 0 and not barrelOwned() then
					MarketplaceService:PromptGamePassPurchase(player, offer.PassId)
				end
			end)
		end

		if claimable then
			slot.Activated:Connect(function()
				giftClaim:FireServer("Daily")
			end)
		end
	end

	-- visible streak: only days actually completed in a row count
	if calendar and streak > 0 then
		calendarTitle.Text = "DAILY CALENDAR  -  " .. streak .. " DAY STREAK"
	else
		calendarTitle.Text = "DAILY CALENDAR"
	end
	calendarTitle.Size = UDim2.fromOffset(560, 34)

	if calendar == nil then
		calendarHint.Text = "Loading your calendar..."
	elseif nextSlot then
		calendarHint.Text = "Day " .. nextSlot .. " is ready! Tap it to claim."
	else
		local tutorialStep = player:GetAttribute("TutorialStep")
		if typeof(tutorialStep) == "number" and tutorialStep < 12 then
			calendarHint.Text = "Claimed! Nice work." -- no "come back" talk while the tutorial runs
		else
			calendarHint.Text = "Claimed today. Come back tomorrow to keep your streak!"
		end
	end

	-- the Oil Barrel slot is a paid offer, not part of the free days
	if calendar ~= nil and not barrelOwned() then
		calendarHint.Text = calendarHint.Text .. "  The Oil Barrel is a one-time Robux offer."
	end
end

-- Day 7 offer: live price from Roblox, and "OWNED" once the pass or the ball is owned.
-- Both only change what is DRAWN; the server verifies the pass and grants the ball.
local function refreshBarrelOffer()
	local entry = ShopConfig.ExclusiveBalls.OilBarrel
	if not entry then
		return
	end
	task.spawn(function()
		local changed = false
		local payBefore = CalExclusive.CachedPricing(entry).Pay
		if CalExclusive.GetPricing(entry).Pay ~= payBefore then
			changed = true
		end
		local okState, state = pcall(function()
			return remotes:WaitForChild("BallShopState"):InvokeServer()
		end)
		if okState and typeof(state) == "table" and typeof(state.Balls) == "table" then
			for _, ball in ipairs(state.Balls) do
				if ball.BallId == entry.BallId then
					local owned = ball.Owned == true
					if owned ~= barrelBallOwned then
						barrelBallOwned = owned
						changed = true
					end
				end
			end
		end
		if changed then
			rebuildCalendar()
		end
	end)
end
player:GetAttributeChangedSignal("OwnsBarrelPass"):Connect(function()
	rebuildCalendar()
	refreshBarrelOffer()
end)

PanelManager.Register("Calendar", calendarPanel, function()
	pullGiftState()
	refreshBarrelOffer()
	updateCalendarScale()
end)

-- A tap anywhere outside the calendar closes it, so the panel can never get stuck open if another
-- element covers its X on some screen. It sits just below the panel, above the rest of the hub.
local calendarBackdrop = create("TextButton", {
	Name = "CalendarBackdrop",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 19,
}, gui)
calendarPanel:GetPropertyChangedSignal("Visible"):Connect(function()
	calendarBackdrop.Visible = calendarPanel.Visible
end)
calendarBackdrop.Activated:Connect(function()
	PanelManager.Close("Calendar")
end)

-- Starting a run closes every open panel (the player is rolling now; the panels used to be left
-- open over the course).
player:GetAttributeChangedSignal("RunState"):Connect(function()
	local state = player:GetAttribute("RunState")
	if state == "Starting" or state == "Running" then
		PanelManager.CloseAll()
	end
	-- on a course (oil or win) only the wins trophy stays; the hub buttons come back in the lobby
	grid.Visible = state == nil or state == "" or state == "Waiting"
end)

local function setCalendarOpen(open)
	if open then
		PanelManager.Open("Calendar")
	else
		PanelManager.Close("Calendar")
	end
end

dailyButton.Button.Activated:Connect(function()
	PanelManager.Toggle("Calendar")
end)
calendarClose.Activated:Connect(function()
	setCalendarOpen(false)
end)

-- "Claim before you leave": opening the Roblox menu (the way players leave)
-- with an unclaimed daily reward opens the calendar with a reminder. The
-- leave-reward card in PopupsUI takes priority when that one is ready.
game:GetService("GuiService").MenuOpened:Connect(function()
	if not (calendar and calendar.NextSlot) or not dailyButton.Button.Visible then
		return
	end
	local leaveAt = player:GetAttribute("LeaveRewardNextAt")
	if typeof(leaveAt) == "number" and os.time() >= leaveAt then
		return
	end
	local step = player:GetAttribute("TutorialStep")
	if typeof(step) == "number" and step < 12 then
		return
	end
	setCalendarOpen(true)
	showToast("Claim your daily reward before you leave!", true)
end)

giftResult.OnClientEvent:Connect(function(kind, success, result, slot)
	if success then
		showToast(describe(result), true)
	else
		showToast(tostring(result), false)
	end
	pullGiftState()
	refreshGiftButtons()
end)

rebuildCalendar()

--------------------------------------------------
-- REBIRTH (existing panel owned by RebirthUIClient)
--------------------------------------------------

rebirthButton.Button.Activated:Connect(function()
	local toggle = playerGui:FindFirstChild("ToggleRebirthPanel")
	if toggle then
		toggle:Fire()
	else
		showToast("Rebirth is not ready yet.", false)
	end
end)

--------------------------------------------------
-- STORE PANEL
--
-- A large scrollable store: the Captain Oil Server Pack (with a discounted
-- price for verified Oil Barrel owners), the Rainbow Oil Barrel, the two
-- timed boosts (x2 wins / x2 oil) as their own tiles, and the game passes.
-- Every tile has the shine sweep. The client only ASKS to buy: ids, prices
-- charged and every reward stay on the server; prices shown here are labels.
--------------------------------------------------

local BoostConfig = require(ReplicatedStorage:WaitForChild("BoostConfig"))
local ExclusiveOffer = require(ReplicatedStorage:WaitForChild("ExclusiveOffer"))
local ROBUX = utf8.char(0xE002)
local STORE_W, STORE_H = 624, 620
local NAVY = Color3.fromRGB(34, 36, 74)

local function commas(value)
	return (tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local shopPanel = create("Frame", {
	Name = "ShopPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(STORE_W, STORE_H),
	BackgroundColor3 = NAVY,
	Visible = false,
	ZIndex = 20,
}, gui)
round(shopPanel, 20)
outline(shopPanel, LANE, 5)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(58, 52, 120), Color3.fromRGB(26, 26, 58)),
	Rotation = 90,
}, shopPanel)
local shopScale = create("UIScale", { Scale = 1 }, shopPanel)

-- fits any screen: as large as it can be, never off screen
local function fitStore()
	local viewport = gui.AbsoluteSize
	-- scale by width; the panel's own height then fills the screen height, so
	-- short phone/tablet screens get a shorter (scrolling) panel at a readable
	-- text size instead of a shrunken-to-nothing one
	local s = math.clamp((viewport.X - 24) / STORE_W, 0.5, 1.25)
	if viewport.Y < 500 then
		s = math.min(s, 0.85)
	end
	shopScale.Scale = s
	shopPanel.Size = UDim2.fromOffset(STORE_W, math.clamp((viewport.Y - 16) / s, 280, 700))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitStore)
fitStore()

-- gold header ribbon
local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 64),
	BackgroundColor3 = LANE,
	ZIndex = 21,
}, shopPanel)
round(header, 20)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(236, 150, 50)),
	Rotation = 90,
}, header)
create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 8),
	Size = UDim2.new(1, -90, 0, 48),
	Font = FONT,
	Text = "STORE",
	TextColor3 = CREAM,
	TextSize = 38,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 22,
}, header)
create("UIStroke", { Color = INK, Thickness = 3 }, header:FindFirstChildOfClass("TextLabel"))
Shine.Attach(header, { Offset = 0 })

local shopClose = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = PIN_RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 22,
	ZIndex = 23,
}, header)
round(shopClose, 12)
outline(shopClose, INK, 3)

local shopList = create("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 76),
	Size = UDim2.new(1, -28, 1, -90),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollBarImageColor3 = LANE,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BorderSizePixel = 0,
	ZIndex = 21,
}, shopPanel)
create("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shopList)
-- left gutter: pop icons overhang a tile's left edge into it, unclipped
create("UIPadding", { PaddingLeft = UDim.new(0, 44), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, shopList)

-- "scroll for more" hint: shows while there is more below, bobs gently
local moreHint = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(170, 26),
	BackgroundColor3 = Color3.fromRGB(30, 22, 80),
	BackgroundTransparency = 0.15,
	Font = FONT,
	Text = "▼  MORE BELOW  ▼",
	TextColor3 = Color3.fromRGB(255, 226, 140),
	TextSize = 14,
	ZIndex = 40,
}, shopPanel)
round(moreHint, 13)
outline(moreHint, INK, 2)
local function updateMoreHint()
	moreHint.Visible = shopList.CanvasPosition.Y + shopList.AbsoluteWindowSize.Y < shopList.AbsoluteCanvasSize.Y - 24
end
shopList:GetPropertyChangedSignal("CanvasPosition"):Connect(updateMoreHint)
shopList:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updateMoreHint)
shopList:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateMoreHint)
RunService.RenderStepped:Connect(function()
	if moreHint.Visible and shopPanel.Visible then
		moreHint.Position = UDim2.new(0.5, 0, 1, -8 + math.sin(os.clock() * 4) * 3)
	end
end)
task.defer(updateMoreHint)

local function sectionTitle(order, text)
	local label = create("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 226, 140),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, shopList)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, label)
	return label
end

-- ROBLOX PLUS banner: first thing in the store. Roblox gives Plus members a discount on passes and
-- items; the real prices come from Roblox (GetProductInfo), this only advertises it. Tapping it
-- opens Roblox's own Plus subscribe prompt (never automatic), or confirms the discount is active.
do
	local plusBanner = create("TextButton", {
		Name = "PlusBanner",
		LayoutOrder = -100,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Color3.fromRGB(86, 52, 190),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 22,
	}, shopList)
	round(plusBanner, 14)
	outline(plusBanner, INK, 3)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(140, 96, 255), Color3.fromRGB(70, 40, 170)),
		Rotation = 90,
	}, plusBanner)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -28, 0, 28),
		Font = FONT,
		Text = "ROBLOX PLUS USERS DISCOUNT",
		TextColor3 = Color3.fromRGB(255, 226, 120),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, plusBanner)
	local plusSub = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 31),
		Size = UDim2.new(1, -28, 0, 20),
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = CREAM,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 23,
	}, plusBanner)
	local function hasPlus()
		local ok, value = pcall(function()
			return player.HasRobloxSubscription
		end)
		return ok and value == true
	end
	local function refreshPlus()
		plusSub.Text = hasPlus() and "Roblox Plus is active: your discount is applied to the prices below!"
			or "Roblox Plus members save on passes & items. Tap to find out more!"
	end
	refreshPlus()
	pcall(function()
		player:GetPropertyChangedSignal("HasRobloxSubscription"):Connect(refreshPlus)
	end)
	plusBanner.Activated:Connect(function()
		if hasPlus() then
			showToast("Roblox Plus is active. Your discount is applied!", true)
			return
		end
		local ok = pcall(function()
			MarketplaceService:PromptRobloxSubscriptionPurchase(player)
		end)
		if not ok then
			showToast("Roblox Plus is not available right now.", false)
		end
	end)
end

-- one tile: gradient background, outline, shine sweep
local function tile(order, height, top, bottom)
	local row = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = top,
		ZIndex = 22,
	}, shopList)
	round(row, 16)
	outline(row, INK, 3.5)
	create("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }, row)
	Shine.Attach(row, { Offset = (order % 7) * 0.8 })
	return row
end

local function text(parent, props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.ZIndex = props.ZIndex or 24
	return create("TextLabel", props, parent)
end

local function buyButton(parent, color)
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(150, 48),
		BackgroundColor3 = color or GREEN,
		Font = FONT,
		Text = "",
		TextColor3 = CREAM,
		TextSize = 22,
		AutoButtonColor = true,
		ZIndex = 25,
	}, parent)
	round(button, 12)
	outline(button, INK, 3)
	Shine.Attach(button, { Offset = 1.7 })
	return button
end

-- Tiles that clip their children (shine sweep) cannot let an icon overhang
-- their own edge, so a pop tile sits inside an unclipped wrapper and the icon
-- lives in the wrapper, overlapping the tile's left edge (the list has a left
-- gutter so it is not cut off).
local INSET = 6
local function popTile(order, height, top, bottom)
	local row = tile(order, height, top, bottom)
	local wrap = create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
	}, shopList)
	row.Parent = wrap
	row.Position = UDim2.new()
	row.Size = UDim2.fromScale(1, 1)
	return row, wrap
end

-- the rolling rainbow oil barrel, hovering over the tile's left edge
local function rollingBarrel(parent, width, height, position, anchor, zIndex)
	local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))
	local viewport = create("ViewportFrame", {
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = position or UDim2.new(0, INSET + 2, 0.5, 0),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		ZIndex = zIndex or 30,
	}, parent)

	local barrel = Instance.new("Part")
	barrel.Shape = Enum.PartType.Ball
	barrel.Size = Vector3.new(2.8, 2.8, 2.8)
	barrel.Anchored = true
	barrel.CFrame = CFrame.new(0, 0, 0)
	barrel.Parent = viewport
	barrel:SetAttribute("PreviewSpeed", 9)

	task.spawn(function()
		BallAccessories.Apply(barrel, "OilBarrel")
		BallAccessories.Pose(barrel, os.clock())
	end)

	local cam = Instance.new("Camera")
	cam.FieldOfView = 34
	cam.CFrame = CFrame.lookAt(Vector3.new(4.6, 3.4, 6.2), Vector3.new(0, -0.1, 0))
	cam.Parent = viewport
	viewport.CurrentCamera = cam

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not viewport.Parent then
			conn:Disconnect()
			return
		end
		if shopPanel.Visible then
			BallAccessories.Pose(barrel, os.clock())
		end
	end)
end

-- 1) CAPTAIN OIL SERVER PACK ------------------------------------------------
sectionTitle(6, "SERVER PACK")
do
	local row, wrap = popTile(7, 196, Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 150, 50))

	text(row, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -200, 0, 30),
		Text = "CAPTAIN OIL SERVER PACK",
		TextColor3 = INK,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local description = text(row, {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -200, 0, 112),
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(90, 40, 10),
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- what the pack includes: a small icon row above the Robux button
	local includes = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 40),
		Size = UDim2.fromOffset(150, 40),
		BackgroundTransparency = 1,
		ZIndex = 26,
	}, row)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, includes)
	rollingBarrel(includes, 62, 40, nil, nil, 26)
	for _, emoji in ipairs({ "🏆", "🛢️" }) do
		text(includes, {
			Size = UDim2.fromOffset(34, 34),
			Text = emoji,
			TextSize = 28,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 26,
		})
	end
	local buy = buyButton(row)
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.new(1, -14, 1, -44)
	buy.Size = UDim2.fromOffset(150, 60)
	local oldPrice = text(buy, {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 20),
		RichText = true,
		TextColor3 = Color3.fromRGB(230, 255, 230),
		TextSize = 16,
		ZIndex = 26,
	})
	local newPrice = text(buy, {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = CREAM,
		TextSize = 22,
		ZIndex = 26,
	})
	create("UIStroke", { Color = INK, Thickness = 2 }, newPrice)

	-- Owners of the paid Oil Barrel Game Pass see a different description and
	-- the barrel's price struck off. This is DISPLAY only: the server decides
	-- which product it prompts and re-verifies ownership on the receipt.
	local function refresh()
		local owner = player:GetAttribute("OwnsBarrelPass") == true
		if owner then
			description.Text = "YOU ALREADY OWN THE OIL BARREL, so the barrel is taken off the price!"
				.. "\nYOU: 150,000 wins + x2 oil, x2 wins and x3 CAPTAIN for 1 hour."
				.. "\nEVERYONE in the server: 25,000 wins + boosts for 30 min!"
			oldPrice.Text = "<s>" .. ROBUX .. " " .. commas(ShopConfig.CaptainPrice) .. "</s>"
			newPrice.Text = ROBUX .. " " .. commas(ShopConfig.CaptainOwnerPrice)
		else
			description.Text = "YOU: 150,000 wins, the rainbow OIL BARREL ball, and x2 oil + x2 wins + x3 CAPTAIN boost for 1 hour."
				.. "\nEVERYONE in the server: 25,000 wins + boosts for 30 min!"
			oldPrice.Text = ""
			newPrice.Text = ROBUX .. " " .. commas(ShopConfig.CaptainPrice)
		end

		-- Roblox Plus: only when Roblox reports a Plus discount on the product this player
		-- would be sold, the discounted price is shown with the full price struck through.
		-- Roblox charges the real price; nothing granted or charged changes here.
		local entry = owner
			and { ProductId = ShopConfig.CaptainOwnerProductId, Price = ShopConfig.CaptainOwnerPrice }
			or { ProductId = ShopConfig.CaptainProductId, Price = ShopConfig.CaptainPrice }
		task.spawn(function()
			local pricing = ExclusiveOffer.GetPricing(entry)
			if pricing.Pay < pricing.Base and (player:GetAttribute("OwnsBarrelPass") == true) == owner then
				oldPrice.Text = "<s>" .. ROBUX .. " " .. commas(pricing.Base) .. "</s>"
				newPrice.Text = ROBUX .. " " .. commas(pricing.Pay)
			end
		end)
	end
	player:GetAttributeChangedSignal("OwnsBarrelPass"):Connect(refresh)
	refresh()

	buy.Activated:Connect(function()
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StorePrompt"):FireServer("Captain")
	end)
end

-- 2) RAINBOW OIL BARREL -----------------------------------------------------
sectionTitle(4, "EXCLUSIVE BALL")
do
	local entry = ShopConfig.ExclusiveBalls.OilBarrel
	local row, wrap = popTile(5, 178, Color3.fromRGB(150, 110, 255), Color3.fromRGB(70, 200, 230))
	-- the rolling barrel sits above the Robux button
	rollingBarrel(row, 160, 96, UDim2.new(1, -89, 0, 6), Vector2.new(0.5, 0), 26)

	text(row, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -190, 0, 30),
		Text = "RAINBOW OIL BARREL",
		TextColor3 = CREAM,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	create("UIStroke", { Color = INK, Thickness = 2.5 }, row:FindFirstChildOfClass("TextLabel"))
	text(row, {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -190, 0, 80),
		Font = Enum.Font.GothamBold,
		Text = "The exclusive rainbow barrel ball. Everyone will know you are the Leader of All Oils!",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local buy = buyButton(row)
	buy.Size = UDim2.fromOffset(150, 52)
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.new(1, -14, 1, -12)
	buy.Text = entry.PassId ~= 0 and (ROBUX .. " " .. tostring(entry.Price)) or "SOON"
	create("UIStroke", { Color = INK, Thickness = 2 }, buy)
	if entry.PassId ~= 0 then
		task.spawn(function()
			local pricing = ExclusiveOffer.GetPricing(entry)
			if buy.Parent and buy.Text ~= "OWNED" and pricing.Pay < pricing.Base then
				buy.Text = ROBUX .. " " .. tostring(pricing.Pay)
				ExclusiveOffer.ShowDiscount(buy, pricing, { Mode = "Center", Inset = 0, Width = 150, OldSize = 15 })
			end
		end)
	end

	-- the Oil Barrel shows its configured price (ShopConfig, 499); only a Roblox-reported Plus discount adds the slashed old price

	local function refreshOwned()
		if player:GetAttribute("OwnsBarrelPass") == true or ExclusiveOffer.OwnsPass(entry.PassId) then
			ExclusiveOffer.ClearDiscount(buy)
			buy.TextXAlignment = Enum.TextXAlignment.Center
			buy.Text = "OWNED"
			buy.BackgroundColor3 = INK
			buy.AutoButtonColor = false
		end
	end
	player:GetAttributeChangedSignal("OwnsBarrelPass"):Connect(refreshOwned)
	task.spawn(refreshOwned)

	buy.Activated:Connect(function()
		if entry.PassId ~= 0 and buy.Text ~= "OWNED" then
			MarketplaceService:PromptGamePassPurchase(player, entry.PassId)
		end
	end)
end

-- 3) TIMED BOOSTS: x2 wins and x2 oil as their own tiles ---------------------
sectionTitle(1, "BOOSTS (30 MIN)")
do
	local tiles = {
		{ Icon = "🏆", Key = "Wins2x", Order = 2, Top = Color3.fromRGB(255, 220, 70), Bottom = Color3.fromRGB(255, 130, 30), Text = "x2 WINS", Sub = "Double wins from every win course for 30 minutes." },
		{ Icon = "🛢️", Key = "Oil2x", Order = 3, Top = Color3.fromRGB(110, 110, 135), Bottom = Color3.fromRGB(36, 36, 56), Text = "x2 OIL", Sub = "Double oil from every platform you collect for 30 minutes." },
	}

	for _, spec in ipairs(tiles) do
		local boost = BoostConfig.Boosts[spec.Key]
		local row, wrap = popTile(spec.Order, 114, spec.Top, spec.Bottom)

		local title = text(row, {
			Position = UDim2.fromOffset(50, 8),
			Size = UDim2.new(1, -226, 0, 36),
			Text = spec.Text,
			TextColor3 = CREAM,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		create("UIStroke", { Color = INK, Thickness = 3 }, title)
		-- icon popping out of the tile's left edge (about a third outside it)
		text(wrap, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, INSET + 2, 0.5, 0),
			Size = UDim2.fromOffset(64, 64),
			Text = spec.Icon,
			TextSize = 52,
			Rotation = -12,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 30,
		})
		text(row, {
			Position = UDim2.fromOffset(50, 48),
			Size = UDim2.new(1, -226, 0, 44),
			Font = Enum.Font.GothamBold,
			Text = spec.Sub,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		})

		local available = boost and boost.ProductId ~= 0 and boost.PriceRobux
		local buy = buyButton(row)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -14, 0.5, 0)
		buy.Size = UDim2.fromOffset(150, 52)
		buy.Text = available and (ROBUX .. " " .. boost.PriceRobux) or "SOON"
		buy.BackgroundColor3 = available and GREEN or INK
		if available then
			buy.Activated:Connect(function()
				ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostPrompt"):FireServer(spec.Key)
			end)
		end
	end
end

-- 4) GAME PASSES --------------------------------------------------------------
sectionTitle(8, "GAME PASSES")
local STORE_PASSES = {} -- the store lists only the Starter Pack (other passes stay elsewhere)
for _, pass in ipairs(ShopConfig.GamePasses) do
	if pass.Name == "STARTER PACK" then
		table.insert(STORE_PASSES, pass)
	end
end
for index, pass in ipairs(STORE_PASSES) do
	local row = popTile(10 + index, 124, Color3.fromRGB(255, 250, 240), Color3.fromRGB(240, 214, 160))

	text(row, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -190, 0, 28),
		Text = pass.Name,
		TextColor3 = INK,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(row, {
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.new(1, -190, 0, 58),
		Font = Enum.Font.GothamBold,
		Text = pass.Description,
		TextColor3 = Color3.fromRGB(110, 70, 30),
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- present icon above the buy button (absolute-positioned: does not change the tile size)
	text(row, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(1, -89, 0, 2),
		Size = UDim2.fromOffset(34, 34),
		Text = "🎁",
		TextSize = 28,
		Rotation = -8,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 26,
	})

	local available = pass.PassId ~= 0
	local buy = buyButton(row, available and GREEN or INK)
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -14, 0.5, 0)
	buy.Size = UDim2.fromOffset(150, 52)
	buy.Text = available and "BUY" or "SOON"
	buy.AutoButtonColor = available

	if available then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pass.PassId, Enum.InfoType.GamePass)
			end)
			if buy.Parent and ok and typeof(info) == "table" and info.PriceInRobux then
				buy.Text = ROBUX .. " " .. info.PriceInRobux
			end
		end)

		buy.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
		end)
	end
end
PanelManager.Register("Store", shopPanel)

local function setShopOpen(open)
	if open then
		PanelManager.Open("Store")
	else
		PanelManager.Close("Store")
	end
end

shopButton.Button.Activated:Connect(function()
	PanelManager.Toggle("Store")
end)
shopClose.Activated:Connect(function()
	setShopOpen(false)
end)
