--------------------------------------------------
-- OIL METER UI
--
-- CLIENT ONLY. Presentation only: every number comes from
-- server-owned player attributes.
--
-- Oil course (RunState == "Running"):
--   shows the oil collected this run (CurrentOil) and flies a
--   droplet into the meter whenever it increases.
-- WinCourse (WinTravelBudget attribute present):
--   the same meter drains as the travel budget is used.
--
-- Hidden otherwise, so it disappears after each WinCourse and
-- reappears when the next run starts.
--------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoftPop = require(game:GetService("ReplicatedStorage"):WaitForChild("SoftPop"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_NAME = "OilMeterUI"

local old = playerGui:FindFirstChild(GUI_NAME)
if old then
	old:Destroy()
end

local INK = Color3.fromRGB(28, 30, 48)
local LANE = Color3.fromRGB(232, 190, 120)
local OIL = Color3.fromRGB(70, 60, 120)
local CREAM = Color3.fromRGB(250, 244, 230)

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = create("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 8,
}, playerGui)

local BASE_TILT = 0 -- the meter is straight; oil makes it SHAKE side to side

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -130),
	Size = UDim2.new(0.74, 0, 0, 86),
	BackgroundTransparency = 1,
	Rotation = BASE_TILT,
	Visible = false,
}, gui)
create("UISizeConstraint", { MinSize = Vector2.new(460, 86), MaxSize = Vector2.new(1000, 86) }, panel)
local scale = create("UIScale", { Scale = 1 }, panel)

-- wide chunky gauge (deep bowling-purple, glossy), like a speed-game fuel bar
local bar = create("Frame", {
	Position = UDim2.fromOffset(46, 12),
	Size = UDim2.new(1, -52, 1, -22),
	BackgroundColor3 = Color3.fromRGB(46, 30, 96),
	ClipsDescendants = true,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, bar)
create("UIStroke", { Color = Color3.fromRGB(22, 12, 52), Thickness = 6 }, bar)

local track = bar -- (kept name: the fill lives inside the bar)

local fill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(150, 90, 235),
}, bar)
local fillGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 130, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 70, 235)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(98, 44, 190)),
	}),
	Rotation = 90,
}, fill)

-- bar colour theme: purple while collecting, green -> amber -> red as the
-- win-course oil burns down
local THEMES = {
	oil = { Color3.fromRGB(196, 130, 255), Color3.fromRGB(140, 70, 235), Color3.fromRGB(98, 44, 190) },
	high = { Color3.fromRGB(150, 255, 150), Color3.fromRGB(60, 205, 90), Color3.fromRGB(30, 150, 60) },
	mid = { Color3.fromRGB(255, 232, 120), Color3.fromRGB(250, 190, 50), Color3.fromRGB(215, 140, 20) },
	low = { Color3.fromRGB(255, 140, 130), Color3.fromRGB(240, 70, 70), Color3.fromRGB(180, 35, 45) },
}
local currentTheme = "oil"
local function setTheme(name)
	if name == currentTheme then
		return
	end
	currentTheme = name
	local c = THEMES[name]
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c[1]),
		ColorSequenceKeypoint.new(0.5, c[2]),
		ColorSequenceKeypoint.new(1, c[3]),
	})
end

-- a soft light sweep that keeps gliding across the bar
local shine = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(-0.2, 0.5),
	Size = UDim2.new(0, 70, 1.6, 0),
	Rotation = 18,
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.78,
	BorderSizePixel = 0,
	ZIndex = 3,
}, bar)
task.spawn(function()
	while true do
		shine.Position = UDim2.fromScale(-0.2, 0.5)
		local tween = TweenService:Create(shine, TweenInfo.new(1.8, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1.2, 0.5) })
		tween:Play()
		tween.Completed:Wait()
		task.wait(1.2)
	end
end)

-- gloss on the upper half
create("Frame", {
	Size = UDim2.new(1, 0, 0.42, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
	ZIndex = 2,
}, bar)

-- light plate behind the icon so the dark spill pops against the purple bar
local plate = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(52, 46),
	Size = UDim2.fromOffset(84, 84),
	BackgroundColor3 = Color3.fromRGB(255, 244, 214),
	ZIndex = 4,
}, panel)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, plate)
create("UIStroke", { Color = Color3.fromRGB(22, 12, 52), Thickness = 5 }, plate)

-- oil spill icon, tilted, overlapping the left end of the bar
local icon = create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(52, 46),
	Size = UDim2.fromOffset(112, 82),
	BackgroundTransparency = 1,
	Image = require(game:GetService("ReplicatedStorage"):WaitForChild("UiAssets")).OilImages.Black,
	ScaleType = Enum.ScaleType.Fit,
	Rotation = -8,
	ZIndex = 5,
}, panel)
-- the icon gently breathes so the meter always feels alive
task.spawn(function()
	while true do
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local a = TweenService:Create(icon, info, { Rotation = 6, Size = UDim2.fromOffset(118, 86) })
		a:Play()
		a.Completed:Wait()
		local b = TweenService:Create(icon, info, { Rotation = -8, Size = UDim2.fromOffset(112, 82) })
		b:Play()
		b.Completed:Wait()
	end
end)

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(108, 12),
	Size = UDim2.fromOffset(200, 60),
	Font = Enum.Font.FredokaOne,
	Text = "OIL",
	TextColor3 = CREAM,
	TextSize = 40,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
}, panel)
create("UIStroke", { Color = Color3.fromRGB(22, 12, 52), Thickness = 4 }, title)

local valueLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -20, 0.5, -2),
	Size = UDim2.fromOffset(380, 76),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 62,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 6,
}, panel)
create("UIStroke", { Color = Color3.fromRGB(22, 12, 52), Thickness = 7 }, valueLabel)
create("UIGradient", {
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(235, 205, 255)),
	Rotation = 90,
}, valueLabel)

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(value)
end

local shown = false
local function setShown(visible)
	if visible == shown then
		return
	end
	shown = visible

	if visible then
		panel.Visible = true
		TweenService:Create(
			panel,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 40) }
		):Play()
	else
		local tween = TweenService:Create(
			panel,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -130) }
		)
		tween.Completed:Once(function()
			if not shown then
				panel.Visible = false
			end
		end)
		tween:Play()
	end
end

local function bump(target, amount)
	target.Scale = amount
	TweenService:Create(
		target,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- The meter shakes side to side whenever oil goes in (straight otherwise).
local shakeToken = 0
local function kickTilt(strength)
	shakeToken += 1
	local token = shakeToken
	task.spawn(function()
		local steps = 10
		for step = 1, steps do
			if token ~= shakeToken then
				return
			end
			local amount = (strength or 8) * (1 - step / (steps + 1))
			panel.Position = UDim2.new(0.5, (step % 2 == 0 and 1 or -1) * amount, 0, 40)
			task.wait(0.035)
		end
		panel.Position = UDim2.new(0.5, 0, 0, 40)
	end)
end
local lastCurrentOil = 0
local runOil = 0 -- oil carried into the WinCourse

-- While the multiplier animation runs (WinCelebration fires OilMeterAnim) the
-- meter shows the oil BEFORE the multipliers and counts up as each one lands.
-- The real CurrentOil (already multiplied by the server) is shown at the end.
local displayOverride = nil

-- An oil spill with the platform's "+amount" beside it flies into the meter.
local function flyDroplet(amount)
	local center = gui.AbsoluteSize / 2
	local drop = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y + 60),
		Size = UDim2.fromOffset(190, 56),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, gui)
	local dropScale = create("UIScale", { Scale = 1 }, drop)
	create("ImageLabel", {
		Size = UDim2.fromOffset(72, 52),
		Position = UDim2.fromOffset(0, 2),
		BackgroundTransparency = 1,
		Image = require(game:GetService("ReplicatedStorage"):WaitForChild("UiAssets")).OilImages.Black,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 20,
	}, drop)
	if amount and amount >= 1 then
		local text = create("TextLabel", {
			Position = UDim2.fromOffset(76, 0),
			Size = UDim2.new(1, -76, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = "+" .. formatNumber(amount),
			TextColor3 = Color3.fromRGB(120, 235, 110),
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 21,
		}, drop)
		create("UIStroke", { Color = INK, Thickness = 3.5 }, text)
	end

	local target = panel.AbsolutePosition + panel.AbsoluteSize / 2
	local info = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(drop, info, {
		Position = UDim2.fromOffset(target.X + panel.AbsoluteSize.X * 0.12, target.Y),
	})
	TweenService:Create(dropScale, info, { Scale = 0.4 }):Play()
	tween.Completed:Once(function()
		drop:Destroy()
		bump(scale, 1.08)
		SoftPop.Play(0.5)
	end)
	tween:Play()
end

-- Hide only after the run has been out of every active state for a short
-- grace period, so the meter does not blink out in the gap between the
-- finish-wall countdown and WinCourse taking over (RunState/attribute handoff).
local HIDE_GRACE = 1.5
local hideToken = 0

local function scheduleHide()
	hideToken += 1
	local token = hideToken
	task.delay(HIDE_GRACE, function()
		if token == hideToken then
			setShown(false)
		end
	end)
end

local function refresh()
	local budget = player:GetAttribute("WinTravelBudget")
	local runState = player:GetAttribute("RunState")

	if typeof(budget) == "number" and budget > 0 then
		-- WinCourse: the budget drains as distance is travelled.
		local travelled = player:GetAttribute("WinDistanceTravelled") or 0
		local remaining = math.clamp(1 - travelled / budget, 0, 1)

		title.Text = "OIL LEFT"
		displayOverride = nil
		setTheme(remaining > 0.5 and "high" or (remaining > 0.2 and "mid" or "low"))
		-- remaining oil as a number (the oil you rolled in with), not a percentage
		valueLabel.Text = formatNumber(runOil * remaining)
		TweenService:Create(
			fill,
			TweenInfo.new(0.1, Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(remaining, 1) }
		):Play()
		hideToken += 1
		setShown(true)
		return
	end

	if runState == "Starting"
		or runState == "Running"
		or runState == "Finishing" then

		-- Oil course (and the finish countdown): show oil collected.
		local oil = player:GetAttribute("CurrentOil") or 0
		title.Text = "OIL"
		setTheme("oil")
		runOil = oil
		fill.Size = UDim2.fromScale(1, 1)

		-- a platform's result shows when the ball the player SEES reaches it
		-- (the server counts it a little earlier, see RunTiming)
		local wait = (runState == "Running" and oil ~= lastCurrentOil)
			and require(game:GetService("ReplicatedStorage"):WaitForChild("RunTiming")).Delay() or 0
		if wait > 0.02 then
			local previous = lastCurrentOil
			lastCurrentOil = oil
			task.delay(wait, function()
				if displayOverride == nil then
					valueLabel.Text = formatNumber(player:GetAttribute("CurrentOil") or oil)
				end
				if oil > previous then
					if displayOverride == nil then
						flyDroplet(oil - previous)
					end
					kickTilt(math.clamp(5 + (oil - previous) / 300, 5, 12))
				end
			end)
			hideToken += 1
			setShown(true)
			return
		end

		if displayOverride == nil then
			valueLabel.Text = formatNumber(oil)
		end

		if oil > lastCurrentOil then
			-- the finish-wall multiplier jump has its own animation
			if runState ~= "Finishing" and displayOverride == nil then
				flyDroplet(oil - lastCurrentOil)
			end
			kickTilt(math.clamp(5 + (oil - lastCurrentOil) / 300, 5, 12))
		end
		lastCurrentOil = oil
		hideToken += 1
		setShown(true)
		return
	end

	lastCurrentOil = player:GetAttribute("CurrentOil") or 0
	if shown then
		scheduleHide()
	end
end

--------------------------------------------------
-- DASH EFFECT (WinCourse)
--
-- Thin streaks that rush past the screen edges. Their rate follows
-- the server-published WinSpeed; crossing each 40-speed step gives a
-- small pulse. Purely visual, no speed readout.
--------------------------------------------------

local RunService = game:GetService("RunService")

local streakLayer = create("Frame", {
	Name = "DashStreaks",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 1,
}, gui)

local streakTimer = 0
local random = Random.new()

local function spawnStreak(speed)
	local fromLeft = random:NextInteger(0, 1) == 0
	local startX = fromLeft and random:NextNumber(0.02, 0.28) or random:NextNumber(0.72, 0.98)
	local length = random:NextInteger(50, 110) + math.floor(speed / 4)

	local streak = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(startX, random:NextNumber(0.1, 0.9)),
		Size = UDim2.fromOffset(2, length),
		BackgroundColor3 = CREAM,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Rotation = fromLeft and -12 or 12,
	}, streakLayer)

	local inward = fromLeft and 0.08 or -0.08
	local tween = TweenService:Create(
		streak,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromScale(startX + inward, streak.Position.Y.Scale + 0.25),
			BackgroundTransparency = 1,
		}
	)
	tween.Completed:Once(function()
		streak:Destroy()
	end)
	tween:Play()
end

RunService.RenderStepped:Connect(function(deltaTime)
	local budget = player:GetAttribute("WinTravelBudget")
	local speed = player:GetAttribute("WinSpeed")
	if typeof(budget) ~= "number" or typeof(speed) ~= "number" or speed < 60 then
		return
	end

	streakTimer += deltaTime
	local interval = math.clamp(0.28 - speed / 1200, 0.05, 0.28)
	if streakTimer >= interval then
		streakTimer = 0
		spawnStreak(speed)
	end
end)

local lastSpeedBucket = 0
player:GetAttributeChangedSignal("WinSpeed"):Connect(function()
	local speed = player:GetAttribute("WinSpeed")
	if typeof(speed) ~= "number" then
		lastSpeedBucket = 0
		return
	end

	local bucket = math.floor(speed / 40)
	if bucket > lastSpeedBucket and lastSpeedBucket > 0 then
		bump(scale, 1.1)
	end
	lastSpeedBucket = bucket
end)

for _, attribute in ipairs({
	"WinTravelBudget",
	"WinDistanceTravelled",
	"RunState",
	"CurrentOil",
}) do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

refresh()

--------------------------------------------------
-- MULTIPLIER ANIMATION HOOK (driven by WinCelebration)
--   Begin(base)      show `base` instead of the real oil
--   Multiply(factor) count the shown number up to base * factor
--   End()            back to the real, server-owned number
--------------------------------------------------

local animEvent = create("BindableEvent", { Name = "OilMeterAnim" }, gui)

animEvent.Event:Connect(function(command, value)
	if command == "Begin" and typeof(value) == "number" then
		displayOverride = value
		valueLabel.Text = formatNumber(value)

	elseif command == "Multiply" and typeof(value) == "number" and displayOverride then
		-- count up to raw x multiplier while the icon drags in
		local from = displayOverride
		local to = from * value
		displayOverride = to

		local duration = math.clamp(0.5 + math.log10(math.max(value, 1)) * 0.3, 0.5, 1.4)
		local started = os.clock()
		bump(scale, 1.22)
		kickTilt(12)
		valueLabel.TextColor3 = Color3.fromRGB(255, 232, 110)
		while os.clock() - started < duration and displayOverride == to do
			local t = (os.clock() - started) / duration
			valueLabel.Text = formatNumber(from + (to - from) * (t * t * (1.6 - 0.6 * t)))
			-- the fill flares and the number swells while it counts
			fill.BackgroundTransparency = 0.25 * math.abs(math.sin(t * math.pi * 6))
			valueLabel.TextSize = 62 + math.floor(10 * math.sin(t * math.pi))
			panel.Position = UDim2.new(0.5, 9 * math.sin(t * math.pi * 8) * (1 - t), 0, 40)
			task.wait()
		end
		panel.Position = UDim2.new(0.5, 0, 0, 40)
		fill.BackgroundTransparency = 0
		valueLabel.TextSize = 62
		valueLabel.TextColor3 = Color3.new(1, 1, 1)
		if displayOverride == to then
			valueLabel.Text = formatNumber(to)
		end
	elseif command == "End" then
		displayOverride = nil
		refresh()
	end
end)

--------------------------------------------------
-- GUTTER PENALTY FEEDBACK
--
-- The server (GutterService) decides and applies the penalty; this
-- only shows it: a big red popup, a screen flash and a meter shake.
--------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gutterRemote = remotes:WaitForChild("GutterPenalty")

	local flash = create("Frame", {
		Name = "GutterFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(230, 70, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 40,
	}, gui)

	gutterRemote.OnClientEvent:Connect(function(amount, fraction, row, totalRows, oilLeft)
		-- Popup
		local popup = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromOffset(460, 110),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = "GUTTER!\n-" .. formatNumber(amount) .. " OIL  (" .. math.floor(fraction * 100 + 0.5) .. "%)",
			TextColor3 = Color3.fromRGB(255, 250, 240),
			TextSize = 34,
			ZIndex = 41,
		}, gui)
		create("UIStroke", { Color = Color3.fromRGB(150, 30, 30), Thickness = 4 }, popup)
		local popupScale = create("UIScale", { Scale = 0.4 }, popup)

		TweenService:Create(
			popupScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()

		task.delay(1.1, function()
			local fade = TweenService:Create(
				popup,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.33) }
			)
			fade.Completed:Once(function()
				popup:Destroy()
			end)
			fade:Play()
		end)

		-- Red flash
		flash.BackgroundTransparency = 0.7
		TweenService:Create(
			flash,
			TweenInfo.new(0.5),
			{ BackgroundTransparency = 1 }
		):Play()

		-- Meter shake
		for index = 1, 6 do
			task.delay(index * 0.04, function()
				panel.Rotation = (index % 2 == 0 and 1 or -1) * (7 - index)
			end)
		end
		task.delay(0.3, function()
			panel.Rotation = BASE_TILT
		end)
	end)
end)
