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
	if value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
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
	Position = UDim2.new(0, 10, 0.3, 0),
	Size = UDim2.fromOffset(176, 440),
}, gui)

local rootScale = create("UIScale", { Scale = 1 }, left)

local function updateRootScale()
	local viewport = gui.AbsoluteSize
	rootScale.Scale = math.clamp(viewport.Y / 800, 0.7, 1.15)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateRootScale)
updateRootScale()

--------------------------------------------------
-- WINS COUNTER
--------------------------------------------------

local winsPill = create("Frame", {
	Name = "Wins",
	Size = UDim2.fromOffset(176, 46),
	BackgroundColor3 = LANE,
	BackgroundTransparency = 0,
}, left)
round(winsPill, 12)
outline(winsPill, INK, 3)
local winsScale = create("UIScale", { Scale = 1 }, winsPill)

local winsIcon = create("ImageLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(6, 5),
	Size = UDim2.fromOffset(36, 36),
	Image = TROPHY_IMAGE,
}, winsPill)

local winsLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(46, 0),
	Size = UDim2.new(1, -52, 1, 0),
	Font = FONT,
	Text = "0",
	TextColor3 = CREAM,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
}, winsPill)
create("UIStroke", { Color = INK, Thickness = 2 }, winsLabel)

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
		viewport.X * 0.3 + math.random(-30, 30),
		viewport.Y * 0.5 + math.random(-40, 40)
	)

	local token = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = startPosition,
		Size = UDim2.fromOffset(120, 40),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, gui)

	create("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(0, 3),
		Image = TROPHY_IMAGE,
		ZIndex = 30,
	}, token)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -38, 1, 0),
		Font = FONT,
		Text = "+" .. formatNumber(amount),
		TextColor3 = CREAM,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 30,
	}, token)
	create("UIStroke", { Color = INK, Thickness = 3 }, label)

	-- Pop in, hold a beat, then drag into the counter.
	token.Size = UDim2.fromOffset(60, 20)
	TweenService:Create(
		token,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(120, 40) }
	):Play()

	task.delay(0.28, function()
		local target = winsPill.AbsolutePosition
			+ Vector2.new(24, winsPill.AbsoluteSize.Y / 2)

		local tween = TweenService:Create(
			token,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(target.X + 40, target.Y) }
		)
		tween.Completed:Once(function()
			token:Destroy()
			inFlight -= 1
			setDisplayedWins(displayedWins + amount)
			bump(winsScale, 1.1)
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
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.fromOffset(176, 268),
}, left)

create("UIGridLayout", {
	CellSize = UDim2.fromOffset(84, 84),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)

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
local rebirthButton = makeHubButton(2, "RebirthButton", "♻", "REBIRTH", PURPLE, 2)

-- Percent to the next rebirth, floating over the REBIRTH button.
local rebirthPercent = create("TextLabel", {
	Name = "RebirthPercent",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(52, 20),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "0%",
	TextColor3 = CREAM,
	TextSize = 15,
	ZIndex = 7,
}, rebirthButton.Button)
round(rebirthPercent, 11)
outline(rebirthPercent, INK, 2.5)

local function refreshRebirthPercent()
	local level = player:GetAttribute("Level") or 1
	local required = math.max(player:GetAttribute("RebirthLevelRequirement") or 65, 1)
	local progress = player:GetAttribute("LevelProgress") or 0
	local fraction = math.clamp((level - 1 + (level >= required and 0 or progress)) / math.max(required - 1, 1), 0, 1)

	if fraction >= 1 then
		rebirthPercent.Text = "READY!"
		rebirthPercent.BackgroundColor3 = PIN_RED
		rebirthButton.Badge.Visible = true
	else
		rebirthPercent.Text = math.floor(fraction * 100) .. "%"
		rebirthPercent.BackgroundColor3 = GREEN
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

	if reward.Type == "Ball" then
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
				CFrame = CFrame.lookAt(
					Vector3.new(0, hasDesign and radius * 0.5 or 0, radius * (reward.BallId == "OilBarrel" and 2.7 or (hasDesign and 3.3 or 2.2))),
					Vector3.zero
				),
				FieldOfView = 35,
			}, viewport)
			viewport.CurrentCamera = camera

			-- Slow spin, only while the viewport exists.
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				if not viewport.Parent then
					connection:Disconnect()
					return
				end
				model.CFrame = model.CFrame * CFrame.Angles(0, dt * 1.2, 0)
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
		return "+" .. formatNumber(reward.Amount) .. " 🛢️ starter oil for your next run"
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

	if x6Mode == "Ready" then
		x6Button.Caption.Text = "CLAIM!"
		x6Button.Badge.Visible = true
	elseif x6Mode == "Active" then
		x6Button.Caption.Text = "ON " .. formatTime(x6Remaining)
		x6Button.Badge.Visible = false
	elseif x6Mode == "Waiting" then
		x6Button.Caption.Text = formatTime(x6Remaining)
		x6Button.Badge.Visible = false
	elseif x6Mode == "Done" then
		x6Button.Caption.Text = "TOMORROW"
		x6Button.Badge.Visible = false
	else
		x6Button.Caption.Text = "..."
		x6Button.Badge.Visible = false
	end
end

local x6ClaimRemote = remotes:WaitForChild("X6Claim")
local x6ResultRemote = remotes:WaitForChild("X6Result")

x6Button.Button.Activated:Connect(function()
	local mode = player:GetAttribute("X6Mode")

	if mode == "Ready" then
		x6ClaimRemote:FireServer()
	elseif mode == "Active" then
		showToast("X6 is ON! Roll onto the X6 generator.", true)
	elseif mode == "Waiting" then
		local untilTime = player:GetAttribute("X6Until") or 0
		showToast("X6 boost ready in " .. formatTime(untilTime - workspace:GetServerTimeNow()), true)
	elseif mode == "Done" then
		showToast("No more X6 boosts today. Back tomorrow!", false)
	end
end)

x6ResultRemote.OnClientEvent:Connect(function(success, info)
	if success then
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
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 250),
	BackgroundColor3 = LANE,
	Visible = false,
	ZIndex = 20,
}, gui)
round(calendarPanel, 18)
outline(calendarPanel, INK, 4)
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

local function slotText(reward)
	if reward.Type == "Wins" then
		return "+" .. formatNumber(reward.Amount) .. "\n🏆"
	elseif reward.Type == "Oil" then
		return formatNumber(reward.Amount) .. " 🛢️\nSTART"
	elseif reward.Type == "Ball" then
		return "BALL"
	elseif reward.Type == "BallNext" then
		return "NEXT\nBALL"
	elseif reward.Type == "Rebirth" then
		return "+1\nREBIRTH"
	end
	return "GIFT"
end

local function slotIcon(holder, reward)
	if reward.Type == "Wins" or reward.Type == "Ball" then
		applyRewardPreview(holder, reward)
		return
	end

	local emoji = ({ Oil = "🛢️", BallNext = "🎳", Rebirth = "♻" })[reward.Type] or "🎁"
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

		local slot = create("TextButton", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(94, 154),
			BackgroundColor3 = claimable and Color3.fromRGB(255, 244, 190)
				or (claimed and Color3.fromRGB(210, 235, 210) or CREAM),
			Text = "",
			AutoButtonColor = false,
			ZIndex = 22,
		}, slotRow)
		round(slot, 12)
		create("UIStroke", {
			Color = claimable and PIN_RED or INK,
			Thickness = claimable and 4 or 3,
		}, slot)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 20),
			Font = FONT,
			Text = reward.Special and ("DAY " .. index .. " *") or ("DAY " .. index),
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

		local status = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 22),
			BackgroundColor3 = claimable and PIN_RED or (claimed and GREEN or INK),
			Font = FONT,
			Text = claimable and "CLAIM!" or (claimed and "DONE" or "LOCKED"),
			TextColor3 = CREAM,
			TextSize = 13,
			ZIndex = 23,
		}, slot)
		round(status, 8)

		-- Exclusive ball reward (day 7): also offer it for Robux right here.
		local exclusive = reward.Type == "Ball" and ShopConfig.ExclusiveBalls[reward.BallId]
		if exclusive then
			local OfferModule = require(ReplicatedStorage:WaitForChild("ExclusiveOffer"))
			local buy = create("TextButton", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.fromOffset(100, 30),
				BackgroundColor3 = Color3.fromRGB(0, 190, 112),
				Font = FONT,
				Text = " " .. exclusive.Price, -- literal robux glyph prefix
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 20,
				AutoButtonColor = false,
				ZIndex = 26,
			}, slot)
			round(buy, 12)
			outline(buy, INK, 3)
			TweenService:Create(
				buy,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = UDim2.new(0.5, 0, 0, -7) }
			):Play()

			buy.Activated:Connect(function()
				if exclusive.PassId ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, exclusive.PassId)
				end
			end)

			task.spawn(function()
				if OfferModule.OwnsPass(exclusive.PassId) and buy.Parent then
					buy:Destroy()
				end
			end)
		end

		if claimable then
			slot.Activated:Connect(function()
				giftClaim:FireServer("Daily")
			end)
		end
	end

	if calendar == nil then
		calendarHint.Text = "Loading your calendar..."
	elseif nextSlot then
		calendarHint.Text = "Day " .. nextSlot .. " is ready! Tap it to claim."
	else
		calendarHint.Text = "Claimed today. Come back tomorrow to keep your streak!"
	end
end

PanelManager.Register("Calendar", calendarPanel, function()
	pullGiftState()
	updateCalendarScale()
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
-- GAME PASS SHOP PANEL
--------------------------------------------------

local shopPanel = create("Frame", {
	Name = "ShopPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 470),
	BackgroundColor3 = LANE,
	Visible = false,
	ZIndex = 20,
}, gui)
round(shopPanel, 16)
outline(shopPanel, INK, 4)
local shopScale = create("UIScale", { Scale = 1 }, shopPanel)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -80, 0, 34),
	Font = FONT,
	Text = "STORE",
	TextColor3 = CREAM,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
}, shopPanel)

local shopClose = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = PIN_RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 16,
	ZIndex = 21,
}, shopPanel)
round(shopClose, 10)

local shopList = create("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.new(1, -24, 0, 336),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	BorderSizePixel = 0,
	ZIndex = 21,
}, shopPanel)

create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, shopList)

-- Captain Oil Server Pack (developer product). The client only asks; the
-- server owns the id and every reward.
do
	local row = create("Frame", {
		LayoutOrder = 15,
		Size = UDim2.new(1, -8, 0, 124),
		BackgroundColor3 = Color3.fromRGB(255, 214, 90),
		ZIndex = 22,
	}, shopList)
	round(row, 12)
	outline(row, INK, 3)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 160, 50)),
		Rotation = 90,
	}, row)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -176, 0, 24),
		Font = FONT,
		Text = "CAPTAIN OIL SERVER PACK",
		TextColor3 = INK,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, row)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -176, 0, 88),
		Font = FONT,
		Text = "YOU: 150,000 wins, the rainbow OIL BARREL ball, and x2 oil + x2 wins + x3 CAPTAIN boost for 1 hour." .. "\nEVERYONE in the server: 25,000 wins + boosts for 30 min!",
		TextColor3 = Color3.fromRGB(110, 50, 20),
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 23,
	}, row)

	-- Rolling rainbow Oil Barrel + wins icon: shows what the pack includes.
	do
		local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))

		local viewport = create("ViewportFrame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -88, 0, 8),
			Size = UDim2.fromOffset(60, 54),
			BackgroundTransparency = 1,
			ZIndex = 24,
		}, row)

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
			if row.Visible and shopPanel.Visible then
				BallAccessories.Pose(barrel, os.clock())
			end
		end)

		create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 18),
			Size = UDim2.fromOffset(76, 34),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = "🏆 150K",
			TextColor3 = INK,
			TextSize = 18,
			ZIndex = 24,
		}, row)
	end
	local buy = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(142, 42),
		BackgroundColor3 = GREEN,
		Font = FONT,
		Text = utf8.char(0xE002) .. " 2,799",
		TextColor3 = CREAM,
		TextSize = 18,
		ZIndex = 23,
	}, row)
	round(buy, 10)
	outline(buy, INK, 3)
	Shine.Attach(buy, { Offset = 1 })

	buy.Activated:Connect(function()
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StorePrompt"):FireServer("Captain")
	end)
end

for index, pass in ipairs(ShopConfig.GamePasses) do
	local row = create("Frame", {
		LayoutOrder = index * 10,
		Size = UDim2.new(1, -8, 0, 72),
		BackgroundColor3 = INK_LIGHT,
		ZIndex = 22,
	}, shopList)
	round(row, 12)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -112, 0, 26),
		Font = FONT,
		Text = pass.Name,
		TextColor3 = INK,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
	}, row)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -112, 0, 34),
		Font = FONT,
		Text = pass.Description,
		TextColor3 = Color3.fromRGB(110, 70, 30),
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 23,
	}, row)

	local available = pass.PassId ~= 0
	local buy = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(84, 36),
		BackgroundColor3 = available and GREEN or INK,
		Font = FONT,
		Text = available and "BUY" or "SOON",
		TextColor3 = CREAM,
		TextSize = 15,
		AutoButtonColor = available,
		Active = available,
		ZIndex = 23,
	}, row)
	round(buy, 10)
	buy.Size = UDim2.fromOffset(104, 36)

	if available then
		-- show the real price (read from Roblox; display only)
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pass.PassId, Enum.InfoType.GamePass)
			end)
			if buy.Parent and ok and typeof(info) == "table" and info.PriceInRobux then
				buy.Text = utf8.char(0xE002) .. " " .. info.PriceInRobux
			end
		end)

		buy.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
		end)
	end
end

-- Hovering Oil Barrel offer: pokes out over the bottom edge of the Store.
local ExclusiveOffer = require(ReplicatedStorage:WaitForChild("ExclusiveOffer"))

local storeBarrelOffer = ExclusiveOffer.Create(shopPanel, {
	BallId = "OilBarrel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 58),
	Size = UDim2.fromOffset(410, 124),
	ZIndex = 40,
})

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
