--------------------------------------------------
-- POPUPS
--
--   * FREE x6 claim: a small card in the top-right that pops in and out
--     while the server says the x6 boost is claimable (X6Mode == "Ready").
--     It sits on a soft white glow.
--   * "WAIT! Don't Leave!": shown when the player opens the Roblox menu
--     (GuiService.MenuOpened). Roblox gives games no hook into the real
--     "close Roblox" prompt, so the menu is the closest trigger. The server
--     decides if it is claimable (25 minute cooldown) and what it pays.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local RED = Color3.fromRGB(230, 70, 70)
local FONT = Enum.Font.FredokaOne

-- Short notification "ding". Replace the id here if you prefer another.
local NOTIFY_SOUND = "rbxassetid://4590662766"

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function ding()
	local sound = create("Sound", { SoundId = NOTIFY_SOUND, Volume = 0.6 }, SoundService)
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local old = playerGui:FindFirstChild("PopupsUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "PopupsUI",
	ResetOnSpawn = false,
	DisplayOrder = 30,
}, playerGui)

--------------------------------------------------
-- FREE x6 CARD
--------------------------------------------------

local x6Holder = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 70),
	Size = UDim2.fromOffset(150, 74),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local x6Scale = create("UIScale", { Scale = 0 }, x6Holder)

-- soft white glow behind the card
local glow = create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 70, 1, 70),
	BackgroundTransparency = 1,
	Image = "rbxasset://textures/ui/Controls/DesignSystem/DropShadow.png",
	ImageColor3 = Color3.new(1, 1, 1),
	ImageTransparency = 0.55,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(0, 0, 1, 1),
	ZIndex = 0,
}, x6Holder)

local x6Button = create("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Text = "",
	AutoButtonColor = false,
}, x6Holder)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, x6Button)
create("UIStroke", { Color = INK, Thickness = 3 }, x6Button)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 214, 60), Color3.fromRGB(255, 120, 30)),
	Rotation = 90,
}, x6Button)

local x6Free = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 40),
	Font = FONT,
	Text = "FREE x6",
	TextColor3 = CREAM,
	TextSize = 32,
}, x6Button)
create("UIStroke", { Color = INK, Thickness = 3 }, x6Free)

local x6Claim = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 42),
	Size = UDim2.new(1, 0, 0, 26),
	Font = FONT,
	Text = "CLAIM!",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 22,
}, x6Button)
create("UIStroke", { Color = INK, Thickness = 2.5 }, x6Claim)

Shine.Attach(x6Button, { Offset = 0.5 })

x6Button.Activated:Connect(function()
	remotes:WaitForChild("X6Claim"):FireServer()
end)

local function tweenScale(target, scale, time, style, direction)
	local tween = TweenService:Create(
		target,
		TweenInfo.new(time, style or Enum.EasingStyle.Back, direction or Enum.EasingDirection.Out),
		{ Scale = scale }
	)
	tween:Play()
	return tween
end

-- While an offer is open (server X6Mode == "Ready") the card pops in at a
-- random spot on screen with a countdown, hops to a new random spot every
-- 25 s, and goes away when claimed or when the claim window ends.
local x6Rng = Random.new()

local function randomSpot()
	return UDim2.fromScale(x6Rng:NextNumber(0.1, 0.9), x6Rng:NextNumber(0.16, 0.62))
end

x6Holder.AnchorPoint = Vector2.new(0.5, 0.5)
x6Holder.Position = randomSpot()

task.spawn(function()
	while true do
		if player:GetAttribute("X6Mode") == "Ready" and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then
			x6Holder.Position = randomSpot()
			x6Holder.Visible = true
			x6Scale.Scale = 0
			tweenScale(x6Scale, 1, 0.45)
			ding()

			local sinceMove = 0
			while player:GetAttribute("X6Mode") == "Ready" and (player:GetAttribute("RunState") or "Waiting") == "Waiting" do
				task.wait(0.25)
				sinceMove += 0.25

				local untilTime = player:GetAttribute("X6Until") or 0
				local left = math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow()))
				x6Claim.Text = string.format("CLAIM  %d:%02d", left // 60, left % 60)

				-- gentle breathing
				x6Scale.Scale = 1 + math.sin(os.clock() * 4) * 0.04

				if sinceMove >= 25 then
					sinceMove = 0
					tweenScale(x6Scale, 0, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
					x6Holder.Position = randomSpot()
					tweenScale(x6Scale, 1, 0.4)
				end
			end

			tweenScale(x6Scale, 0, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
			x6Holder.Visible = false
		else
			task.wait(1)
		end
	end
end)

--------------------------------------------------
-- WAIT! DON'T LEAVE!
--------------------------------------------------

local leaveFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 300),
	BackgroundColor3 = Color3.fromRGB(40, 50, 110),
	Visible = false,
	ZIndex = 50,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, leaveFrame)
create("UIStroke", { Color = INK, Thickness = 5 }, leaveFrame)
local leaveScale = create("UIScale", { Scale = 0 }, leaveFrame)

local function label(text, y, h, size, color, parent)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, y),
		Size = UDim2.new(1, -20, 0, h),
		Font = FONT,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		TextWrapped = true,
		ZIndex = 51,
	}, parent)
	create("UIStroke", { Color = INK, Thickness = 3 }, l)
	return l
end

label("WAIT! Don't Leave!", 14, 48, 38, Color3.fromRGB(255, 220, 70), leaveFrame)
label("Stay and grab a FREE gift:", 66, 28, 20, CREAM, leaveFrame)
label("+360 WINS", 100, 46, 36, Color3.fromRGB(120, 255, 150), leaveFrame)
label("x4 XP for 8 minutes", 148, 36, 26, Color3.fromRGB(255, 150, 220), leaveFrame)

local leaveClaimButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 200),
	Size = UDim2.fromOffset(240, 54),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "CLAIM & STAY!",
	TextColor3 = CREAM,
	TextSize = 26,
	ZIndex = 51,
}, leaveFrame)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, leaveClaimButton)
create("UIStroke", { Color = INK, Thickness = 3 }, leaveClaimButton)
Shine.Attach(leaveClaimButton, { Offset = 0 })

local leaveNo = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 262),
	Size = UDim2.fromOffset(160, 26),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "no thanks",
	TextColor3 = Color3.fromRGB(190, 190, 215),
	TextSize = 15,
	ZIndex = 51,
}, leaveFrame)

local function setLeaveOpen(open)
	if open then
		leaveFrame.Visible = true
		leaveClaimButton.Text = "CLAIM & STAY!"
		leaveScale.Scale = 0.3
		tweenScale(leaveScale, 1, 0.4)
		ding()
	else
		tweenScale(leaveScale, 0, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
			leaveFrame.Visible = false
		end)
	end
end

leaveNo.Activated:Connect(function()
	setLeaveOpen(false)
end)

local claiming = false

leaveClaimButton.Activated:Connect(function()
	if claiming then
		return
	end
	claiming = true

	local ok, success, reason = pcall(function()
		return remotes.LeaveRewardClaim:InvokeServer()
	end)

	if ok and success then
		leaveClaimButton.Text = "CLAIMED!"
		task.wait(1.2)
		setLeaveOpen(false)
	else
		leaveClaimButton.Text = (ok and reason == "COOLDOWN") and "NOT READY" or "TRY AGAIN"
		task.wait(1.5)
		leaveClaimButton.Text = "CLAIM & STAY!"
	end

	claiming = false
end)

GuiService.MenuOpened:Connect(function()
	local nextAt = player:GetAttribute("LeaveRewardNextAt")
	if typeof(nextAt) == "number" and os.time() >= nextAt and not leaveFrame.Visible then
		setLeaveOpen(true)
	end
end)

--------------------------------------------------
-- PURCHASE CONFIRMED (only after the server granted, saved and recorded it)
--------------------------------------------------

local confirmToast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -80),
	Size = UDim2.fromOffset(420, 52),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 22,
	ZIndex = 80,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, confirmToast)
create("UIStroke", { Color = INK, Thickness = 3 }, confirmToast)

remotes:WaitForChild("PurchaseConfirmed").OnClientEvent:Connect(function(label)
	if typeof(label) ~= "string" then
		return
	end

	confirmToast.Text = "PURCHASED: " .. string.sub(label, 1, 24) .. "  - thank you!"
	ding()
	TweenService:Create(confirmToast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 24) }):Play()
	task.delay(3.5, function()
		TweenService:Create(confirmToast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
	end)
end)

--------------------------------------------------
-- CAPTAIN ANNOUNCEMENT (everyone in the server sees who bought the pack)
--------------------------------------------------

local captainBanner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -140),
	Size = UDim2.fromOffset(640, 92),
	BackgroundColor3 = Color3.fromRGB(255, 190, 50),
	Font = FONT,
	Text = "",
	TextColor3 = INK,
	TextSize = 22,
	TextWrapped = true,
	ZIndex = 90,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, captainBanner)
create("UIStroke", { Color = INK, Thickness = 4 }, captainBanner)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 40)),
	Rotation = 90,
}, captainBanner)

remotes:WaitForChild("CaptainAnnounce").OnClientEvent:Connect(function(name, wins, minutes)
	if typeof(name) ~= "string" or typeof(wins) ~= "number" or typeof(minutes) ~= "number" then
		return
	end

	captainBanner.Text = string.format(
		"CAPTAIN %s bought the Captain Oil Server Pack!\n+%d WINS for everyone and x2/x3 boosts for %d minutes!",
		string.sub(name, 1, 24),
		wins,
		minutes
	)
	ding()
	TweenService:Create(captainBanner, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 16) }):Play()
	task.delay(8, function()
		TweenService:Create(captainBanner, TweenInfo.new(0.4), { Position = UDim2.new(0.5, 0, 0, -140) }):Play()
	end)
end)
