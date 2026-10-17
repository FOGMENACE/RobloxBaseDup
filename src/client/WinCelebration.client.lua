--------------------------------------------------
-- WIN CELEBRATION
--
-- CLIENT ONLY, visual.
--   * Countdown: a "HOLD ON!" banner, a tightening vignette and a tick
--     sound each second, so the 5 seconds before the WinCourse feel busy.
--   * Result: when the server publishes LastWinCourseWinnings (after the
--     wins are granted) a big bold "+N WINS!" counts up in the middle of
--     the screen with a fanfare and confetti.
-- The numbers come from server attributes; nothing here awards anything.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TICK_SOUND = "rbxassetid://9120386436"
local FANFARE_SOUND = "rbxassetid://9125402735"

local INK = Color3.fromRGB(24, 22, 34)
local FONT = Enum.Font.FredokaOne
local RNG = Random.new()

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function play(id, volume, speed)
	local sound = create("Sound", { SoundId = id, Volume = volume or 0.6, PlaybackSpeed = speed or 1 }, SoundService)
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)
end

local old = playerGui:FindFirstChild("WinCelebration")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "WinCelebration",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 40,
}, playerGui)

--------------------------------------------------
-- COUNTDOWN
--------------------------------------------------

local vignette = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
create("UIStroke", { Color = Color3.fromRGB(255, 200, 60), Thickness = 0, Transparency = 0.4 }, vignette)

local banner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromOffset(520, 70),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "WIN RUSH INCOMING!",
	TextColor3 = Color3.fromRGB(255, 225, 80),
	TextSize = 46,
	Visible = false,
}, gui)
create("UIStroke", { Color = INK, Thickness = 4 }, banner)
local bannerScale = create("UIScale", { Scale = 1 }, banner)

local function countdown(seconds)
	seconds = tonumber(seconds) or 5

	banner.Visible = true
	vignette.Visible = true
	local stroke = vignette:FindFirstChildOfClass("UIStroke")
	stroke.Thickness = 0
	TweenService:Create(stroke, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Thickness = 70 }):Play()

	local messages = { "WIN RUSH INCOMING!", "HOLD ON TIGHT!", "GET READY!", "ALMOST...", "GO GO GO!" }
	for step = 1, math.floor(seconds) do
		banner.Text = messages[math.min(step, #messages)]
		bannerScale.Scale = 1.3
		TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		banner.Rotation = (step % 2 == 0) and 3 or -3
		play(TICK_SOUND, 0.4, 0.9 + step * 0.08)
		task.wait(seconds / math.floor(seconds))
	end

	banner.Visible = false
	banner.Rotation = 0
	vignette.Visible = false
end

--------------------------------------------------
-- RESULT
--------------------------------------------------

local function confetti()
	local colors = {
		Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 150),
		Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 110, 255),
	}

	for _ = 1, 90 do
		local size = RNG:NextInteger(8, 16)
		local piece = create("Frame", {
			Position = UDim2.fromScale(RNG:NextNumber(0.05, 0.95), -0.05),
			Size = UDim2.fromOffset(size, size * RNG:NextNumber(0.5, 1.6)),
			BackgroundColor3 = colors[RNG:NextInteger(1, #colors)],
			Rotation = RNG:NextInteger(0, 360),
			BorderSizePixel = 0,
			ZIndex = 60,
		}, gui)

		local fall = RNG:NextNumber(1.8, 3.2)
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine), {
			Position = UDim2.fromScale(piece.Position.X.Scale + RNG:NextNumber(-0.12, 0.12), 1.1),
			Rotation = piece.Rotation + RNG:NextInteger(-540, 540),
			BackgroundTransparency = 0.3,
		}):Play()
		task.delay(fall + 0.1, function()
			piece:Destroy()
		end)
	end
end

local lastShown = 0

local function showResult(amount)
	if amount <= 0 then
		return
	end

	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(760, 140),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "+0 WINS!",
		TextColor3 = Color3.fromRGB(255, 232, 90),
		TextSize = 110,
		ZIndex = 70,
	}, gui)
	create("UIStroke", { Color = INK, Thickness = 8 }, label)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 160, 30)),
		Rotation = 90,
	}, label)
	local scale = create("UIScale", { Scale = 0.2 }, label)

	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	play(FANFARE_SOUND, 0.7)
	confetti()

	-- count up
	local duration = 1.6
	local start = os.clock()
	while true do
		local alpha = math.min((os.clock() - start) / duration, 1)
		local eased = 1 - (1 - alpha) ^ 3
		label.Text = "+" .. string.format("%d", math.floor(amount * eased)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") .. " WINS!"
		if alpha >= 1 then
			break
		end
		task.wait()
	end

	-- final slam
	scale.Scale = 1.25
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	confetti()

	task.wait(2.6)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.4)
	label:Destroy()
end

player:GetAttributeChangedSignal("LastWinCourseWinnings"):Connect(function()
	local amount = player:GetAttribute("LastWinCourseWinnings")
	if typeof(amount) == "number" and os.clock() - lastShown > 1 then
		lastShown = os.clock()
		task.spawn(showResult, amount)
	end
end)

--------------------------------------------------
-- SERVER EVENTS
--------------------------------------------------

local winCourse = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WinCourse")

winCourse.OnClientEvent:Connect(function(eventName, value)
	if eventName == "CountdownStart" then
		task.spawn(countdown, value)
	end
end)
