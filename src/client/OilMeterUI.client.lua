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

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -90),
	Size = UDim2.fromOffset(300, 64),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.1,
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, panel)
create("UIStroke", { Color = LANE, Thickness = 2 }, panel)
local scale = create("UIScale", { Scale = 1 }, panel)

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 4),
	Size = UDim2.new(0.6, 0, 0, 22),
	Font = Enum.Font.GothamBlack,
	Text = "OIL",
	TextColor3 = CREAM,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)


local track = create("Frame", {
	Position = UDim2.fromOffset(12, 34),
	Size = UDim2.new(1, -24, 0, 18),
	BackgroundColor3 = Color3.fromRGB(48, 50, 72),
}, panel)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

local fill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = OIL,
}, track)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

local valueLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = Enum.Font.GothamBold,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 12,
}, track)

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
			{ Position = UDim2.new(0.5, 0, 0, 12) }
		):Play()
	else
		local tween = TweenService:Create(
			panel,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, -90) }
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

local lastCurrentOil = 0

local function flyDroplet()
	local center = gui.AbsoluteSize / 2
	local drop = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y + 60),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = OIL,
		ZIndex = 20,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, drop)
	create("UIStroke", { Color = CREAM, Thickness = 2 }, drop)

	local target = panel.AbsolutePosition + panel.AbsoluteSize / 2
	local tween = TweenService:Create(
		drop,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromOffset(target.X, target.Y + 36),
			Size = UDim2.fromOffset(8, 8),
		}
	)
	tween.Completed:Once(function()
		drop:Destroy()
		bump(scale, 1.08)
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
		valueLabel.Text = string.format("%d%%", math.floor(remaining * 100))
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
		valueLabel.Text = formatNumber(oil)
		fill.Size = UDim2.fromScale(1, 1)

		if oil > lastCurrentOil then
			flyDroplet()
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
			panel.Rotation = 0
		end)
	end)
end)
