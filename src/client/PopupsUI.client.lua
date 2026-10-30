--------------------------------------------------
-- POPUPS
--
--   * FREE x6 claim: a small card in the top-right that pops in and out
--     while the server says the x6 boost is claimable (X6Mode == "Ready").
--     It sits on a soft white glow.
--   * "WAIT! Don't Leave!": shown when the player opens the Roblox menu
--     (GuiService.MenuOpened). Roblox gives games no hook into the real
--     "close Roblox" prompt, so the menu is the closest trigger. The server
--     decides if it is claimable (time played this session, 25 minute
--     cooldown) and what it pays.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
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

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

-- The gift card is shown in EVERY world (the old random "FREE x6" popup is no
-- longer used). It names that world's X6 generator: x6 in the Rookie Lanes,
-- the world's own number (x30 / x60 / ...) in the higher worlds.
local function themedWorld()
	return WorldConfig.Of(player)
end

local function x6Value(world)
	return world.Generators and world.Generators.GenX6 or 6
end

--------------------------------------------------
-- FREE x6 CARD
--------------------------------------------------

local cardGui = create("ScreenGui", {
	Name = "FreeClaimCardUI",
	ResetOnSpawn = false,
	DisplayOrder = 5, -- below HubUI (6): hub panels and their X buttons always cover the card
}, playerGui)

local x6Holder = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 70),
	Size = UDim2.fromOffset(150, 74),
	BackgroundTransparency = 1,
	Visible = false,
}, cardGui)
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

-- A card that can be TAPPED or CLICKED but never swallows a drag. A normal button takes the
-- whole press, so a finger or cursor that started over the card could not turn the camera.
-- This one leaves the input alone (Active = false): a drag starting on it orbits the camera
-- as usual, and a short press-and-release on it (little movement) counts as the click.
local TAP_SLOP = 14 -- pixels a finger / cursor may move and still be a tap

local function tapOnly(button, onTap)
	button.Active = false
	local starts = {} -- [InputObject] = Vector2 where the press began

	local function topmostIsButton(position)
		local hits = playerGui:GetGuiObjectsAtPosition(position.X, position.Y)
		for _, object in ipairs(hits) do
			if object == button or object:IsDescendantOf(button) then
				return true
			end
			-- something clickable in front of the card (a panel, the hub, a popup) wins
			if (object:IsA("GuiButton") and object.Active) or (object:IsA("GuiObject") and object.Active and not object:IsDescendantOf(cardGui)) then
				return false
			end
		end
		return false
	end

	UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.Touch and kind ~= Enum.UserInputType.MouseButton1 then
			return
		end
		-- (gameProcessed is ignored on purpose: an Active object BEHIND the card also sets it;
		-- topmostIsButton already rejects anything clickable IN FRONT of the card)
		if not cardGui.Enabled then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if topmostIsButton(at) then
			starts[input] = at
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		local start = starts[input]
		if not start then
			return
		end
		starts[input] = nil
		local at = Vector2.new(input.Position.X, input.Position.Y)
		if (at - start).Magnitude <= TAP_SLOP and cardGui.Enabled and topmostIsButton(at) then
			onTap()
		end
	end)
end

tapOnly(x6Button, function()
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

-- stationary in the top-right corner (it used to jump to random spots)
local function randomSpot()
	return UDim2.new(1, -110, 0, 70)
end
local _ = x6Rng

x6Holder.AnchorPoint = Vector2.new(0.5, 0.5)
x6Holder.Position = randomSpot()

task.spawn(function()
	while true do
		if player:GetAttribute("X6Mode") == "Ready" and not themedWorld() and player:GetAttribute("SettingPopups") ~= false and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then
			x6Holder.Position = randomSpot()
			x6Holder.Visible = true
			x6Scale.Scale = 0
			tweenScale(x6Scale, 1, 0.45)
			ding()

			local sinceMove = 0
			while player:GetAttribute("X6Mode") == "Ready" and not themedWorld() and player:GetAttribute("SettingPopups") ~= false and (player:GetAttribute("RunState") or "Waiting") == "Waiting" do
				task.wait(0.25)
				sinceMove += 0.25

				local untilTime = player:GetAttribute("X6Until") or 0
				local left = math.max(0, math.ceil(untilTime - workspace:GetServerTimeNow()))
				x6Claim.Text = "CLAIM" -- no timer here; the countdown is on the X6 generator
				local _ = left

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
-- WORLD GENERATOR GIFT (worlds 2-4)
--
-- A floating gift (no card): oil drop on a slowly turning sunburst with
-- FREE! above and CLAIM below. It sits low on the right, under the boost
-- cards and clear of the top-right leaderboard. Same server timer as the
-- world 1 popup:
--   Ready   -> press to claim      Active -> time left
--   Waiting -> pressing says when it will be free
--------------------------------------------------

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(150, 110, 255)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 120, 200)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90)),
})
local FREE_GRADIENT = ColorSequence.new(Color3.fromRGB(235, 255, 90), Color3.fromRGB(60, 200, 70))
local PINK_GRADIENT = ColorSequence.new(Color3.fromRGB(255, 120, 230), Color3.fromRGB(150, 90, 255))

local genHolder = create("Frame", {
	Name = "WorldGenCard",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -228, 0, 180),
	Size = UDim2.fromOffset(170, 196),
	BackgroundTransparency = 1,
	Visible = false,
}, cardGui)
local genScale = create("UIScale", {}, genHolder)
-- Size follows the screen: a big, eye-catching gift on computers (it used to
-- shrink with the phone change), a compact badge up by the x2 buttons on
-- phones / tablets so it never covers the middle of the screen.
local TOUCH_SIZE = 1
local function fitGift()
	local height = gui.AbsoluteSize.Y
	if UserInputService.TouchEnabled then
		TOUCH_SIZE = math.clamp(height / 700, 0.45, 0.7)
		genHolder.AnchorPoint = Vector2.new(1, 0)
		genHolder.Position = UDim2.new(1, -150, 0, 120)
	else
		local width = gui.AbsoluteSize.X
		if width < 1400 or height < 760 then
			-- laptops / small windows: a smaller card tucked into the top-right corner, just left of
			-- the x2 buttons (the big centred layout put it in the middle of the screen)
			TOUCH_SIZE = math.clamp(math.min(width / 1400, height / 760), 0.5, 1)
			genHolder.AnchorPoint = Vector2.new(1, 0)
			genHolder.Position = UDim2.new(1, -(math.floor(width * 0.115) + 12), 0, 70)
		else
			TOUCH_SIZE = math.clamp(height / 600, 1.05, 1.45)
			genHolder.AnchorPoint = Vector2.new(1, 0.5)
			genHolder.Position = UDim2.new(1, -228, 0, 180)
		end
	end
end
fitGift()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGift)

-- sunburst behind everything (turns slowly)
local rays = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(230, 230),
	BackgroundTransparency = 1,
}, genHolder)
for index = 0, 9 do
	local ray = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 230),
		Rotation = index * 18,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, rays)
	create("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, ray)
end
local genGlow = create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(190, 190),
	BackgroundTransparency = 1,
	Image = "rbxasset://textures/ui/Controls/DesignSystem/DropShadow.png",
	ImageColor3 = Color3.new(1, 1, 1),
	ImageTransparency = 0.35,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(0, 0, 1, 1),
}, genHolder)

local genOil = create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(86, 94),
	Rotation = -12,
	ImageTransparency = 0.12,
	BackgroundTransparency = 1,
	Image = require(ReplicatedStorage:WaitForChild("UiAssets")).OilImages.Black,
	ScaleType = Enum.ScaleType.Fit,
}, genHolder)

local function giftLabel(position, height, size, gradient, rotation)
	local l = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.new(1, 0, 0, height),
		Font = FONT,
		Text = "",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = size,
		TextTransparency = 0.12,
		Rotation = rotation or 0,
	}, genHolder)
	create("UIStroke", { Color = INK, Thickness = 3.5, Transparency = 0.2 }, l)
	create("UIGradient", { Color = gradient, Rotation = 90 }, l)
	return l
end
local genTop = giftLabel(UDim2.fromOffset(0, 0), 44, 34, FREE_GRADIENT, -4)
local genName = giftLabel(UDim2.fromOffset(0, 126), 32, 28, PINK_GRADIENT, 0)
local genSub = giftLabel(UDim2.fromOffset(0, 158), 34, 30, RAINBOW, 0)

local genButton = create("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
}, genHolder)

local genTip = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(0, -8, 0.5, 0),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.1,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 16,
	TextWrapped = true,
	Visible = false,
}, genHolder)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, genTip)
create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, genTip)

local tipToken = 0
local function showTip(text)
	tipToken += 1
	local token = tipToken
	genTip.Text = text
	genTip.Visible = true
	task.delay(3.5, function()
		if token == tipToken then
			genTip.Visible = false
		end
	end)
end

local function remainingSeconds()
	local untilTime = player:GetAttribute("X6Until")
	return typeof(untilTime) == "number" and math.max(0, untilTime - workspace:GetServerTimeNow()) or 0
end

tapOnly(genButton, function()
	local world = themedWorld()
	if not world then
		return
	end
	local mode = player:GetAttribute("X6Mode")
	if mode == "Ready" then
		remotes:WaitForChild("X6Claim"):FireServer()
	elseif mode == "Active" then
		showTip("Boost on! Roll onto the X" .. x6Value(world) .. " generator.")
	else
		local minutes = math.max(1, math.ceil(remainingSeconds() / 60))
		showTip("Will be FREE IN " .. minutes .. (minutes == 1 and " minute." or " minutes."))
	end
end)

task.spawn(function()
	local lastMode = nil
	while true do
		local world = themedWorld()
		local show = world ~= nil and (player:GetAttribute("RunState") or "Waiting") == "Waiting"
		genHolder.Visible = show
		if show then
			local mode = player:GetAttribute("X6Mode")
			genName.Text = "X" .. x6Value(world) .. " XP"
			if mode == "Ready" then
				genTop.Text = "FREE!"
				genSub.Text = "CLAIM!"
				genGlow.ImageTransparency = 0.25
				if lastMode ~= "Ready" then
					ding()
				end
			elseif mode == "Active" then
				local left = math.ceil(remainingSeconds())
				genTop.Text = "BOOST ON"
				genSub.Text = string.format("%d:%02d", left // 60, left % 60)
				genGlow.ImageTransparency = 0.5
			else
				genTop.Text = "FREE!"
				genSub.Text = "CLAIM!"
				genGlow.ImageTransparency = 0.7
			end
			lastMode = mode
		end
		task.wait(0.25)
	end
end)

-- sunburst turns, the drop bobs, the whole gift breathes while it can be claimed
RunService.RenderStepped:Connect(function()
	if not genHolder.Visible then
		return
	end
	local now = os.clock()
	rays.Rotation = (now * 14) % 360
	genOil.Position = UDim2.new(0.5, 0, 0.5, math.sin(now * 2.6) * 4)
	genOil.Rotation = -12 + math.sin(now * 1.7) * 4
	if player:GetAttribute("X6Mode") == "Ready" then
		genScale.Scale = (0.9 + math.sin(now * 4) * 0.045) * TOUCH_SIZE
	else
		genScale.Scale = 0.9 * TOUCH_SIZE
	end
end)
--------------------------------------------------
-- WAIT! DON'T LEAVE!
--------------------------------------------------


-- Dim the whole screen so the popup cannot be missed (and nothing behind it
-- can be clicked by accident while it is open).
local leaveDim = create("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(10, 8, 30),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 48,
}, gui)

local leaveFrame = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 400),
	BackgroundColor3 = Color3.fromRGB(35, 37, 39), -- the dark grey of Roblox's own menus
	Visible = false,
	ZIndex = 50,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, leaveFrame)
local leaveStroke = create("UIStroke", {
	Color = Color3.fromRGB(86, 88, 94),
	Thickness = 2,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, leaveFrame)
local leaveScale = create("UIScale", { Scale = 0 }, leaveFrame)

-- big enough to be unmissable (and not hidden behind Roblox's own menu): about
-- 80% of the screen width / 85% of its height at most
local function leaveTarget()
	local size = gui.AbsoluteSize
	return math.clamp(math.min(size.X * 0.8 / 660, size.Y * 0.85 / 400), 0.7, 1.5)
end

local function label(text, props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.Text = text
	props.ZIndex = props.ZIndex or 52
	local l = create("TextLabel", props, parent)
	if props.NoStroke ~= true then
		create("UIStroke", { Color = Color3.fromRGB(18, 19, 21), Thickness = 1.5, Transparency = 0.2 }, l)
	end
	return l
end

local leaveHeader = label("WAIT! DON'T LEAVE!", {
	Position = UDim2.fromOffset(20, 34),
	Size = UDim2.new(1, -40, 0, 64),
	TextColor3 = Color3.fromRGB(255, 72, 72),
	TextSize = 52,
}, leaveFrame)
label("You're about to miss your free gift!", {
	Position = UDim2.fromOffset(20, 98),
	Size = UDim2.new(1, -40, 0, 30),
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextSize = 20,
}, leaveFrame)

-- the gift
local gift = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 144),
	Size = UDim2.new(1, -72, 0, 122),
	BackgroundColor3 = Color3.fromRGB(57, 59, 61),
	ZIndex = 51,
}, leaveFrame)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, gift)
create("UIStroke", { Color = Color3.fromRGB(86, 88, 94), Thickness = 1.5 }, gift)
label("FREE GIFT", {
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 22),
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(190, 192, 198),
	TextSize = 15,
}, gift)
label("+360 WINS", {
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 56),
	TextColor3 = Color3.fromRGB(120, 255, 150),
	TextSize = 50,
}, gift)
label("+ x4 XP for 8 minutes", {
	Position = UDim2.fromOffset(0, 84),
	Size = UDim2.new(1, 0, 0, 30),
	TextColor3 = Color3.fromRGB(255, 170, 230),
	TextSize = 24,
}, gift)

local leaveClaimButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 292),
	Size = UDim2.fromOffset(380, 76),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "CLAIM & STAY!",
	TextColor3 = CREAM,
	TextSize = 36,
	AutoButtonColor = false,
	ZIndex = 52,
}, leaveFrame)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, leaveClaimButton)
create("UIStroke", { Color = INK, Thickness = 2, Transparency = 0.2 }, leaveClaimButton)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(100, 220, 120), Color3.fromRGB(48, 170, 80)),
	Rotation = 90,
}, leaveClaimButton)
local claimPulse = create("UIScale", { Scale = 1 }, leaveClaimButton)
Shine.Attach(leaveClaimButton, { Offset = 0 })

-- small, grey and easy to overlook on purpose: top-right corner
local leaveNo = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 8),
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "X",
	TextColor3 = Color3.fromRGB(110, 112, 118),
	TextTransparency = 0.45,
	TextSize = 14,
	AutoButtonColor = false,
	ZIndex = 52,
}, leaveFrame)
-- the headline bobs and the claim button pulses while it is open
RunService.RenderStepped:Connect(function()
	if not leaveFrame.Visible then
		return
	end
	local t = os.clock()
	claimPulse.Scale = 1 + math.sin(t * 5) * 0.035
	leaveHeader.TextSize = 50 + math.sin(t * 6) * 1.5
	-- urgent: the border breathes between the menu grey and alarm red
	local k = (math.sin(t * 5) + 1) / 2
	leaveStroke.Color = Color3.fromRGB(86, 88, 94):Lerp(Color3.fromRGB(255, 60, 60), k)
end)

local function setLeaveOpen(open)
	if open then
		leaveDim.Visible = true
		leaveDim.BackgroundTransparency = 1
		TweenService:Create(leaveDim, TweenInfo.new(0.25), { BackgroundTransparency = 0.4 }):Play()
		leaveFrame.Visible = true
		leaveClaimButton.Text = "CLAIM & STAY!"
		leaveScale.Scale = 0.3
		tweenScale(leaveScale, leaveTarget(), 0.4)
		ding()
	else
		TweenService:Create(leaveDim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		tweenScale(leaveScale, 0, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
			leaveFrame.Visible = false
			leaveDim.Visible = false
		end)
	end
end

-- closing the card keeps it away for a while, so it never nags on every menu open
local LEAVE_SNOOZE_SECONDS = 10 * 60
local leaveSnoozedUntil = 0

leaveNo.Activated:Connect(function()
	leaveSnoozedUntil = os.clock() + LEAVE_SNOOZE_SECONDS
	setLeaveOpen(false)
	remotes.LeaveCardEvent:FireServer("Dismissed")
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
		leaveClaimButton.Text = (ok and (reason == "COOLDOWN" or reason == "TOO_SOON")) and "NOT READY" or "TRY AGAIN"
		task.wait(1.5)
		leaveClaimButton.Text = "CLAIM & STAY!"
	end

	claiming = false
end)

local showStayMessage -- defined below (needs the toast label)
local stayMessageShown = false

GuiService.MenuOpened:Connect(function()
	local step = player:GetAttribute("TutorialStep")
	if typeof(step) == "number" and step < 12 then
		-- still in the tutorial: no "claim and stay" card on top of it, a friendly nudge
		-- instead (once per session)
		if showStayMessage and not stayMessageShown then
			stayMessageShown = true
			showStayMessage()
		end
		return
	end
	-- the server decides when this session has earned the offer (RewardService);
	-- never during a run, where the dimmed card would cost the player their roll
	local nextAt = player:GetAttribute("LeaveRewardNextAt")
	local offerAt = player:GetAttribute("LeaveOfferAt")
	if (player:GetAttribute("RunState") or "Waiting") == "Waiting"
		and typeof(nextAt) == "number" and os.time() >= nextAt
		and typeof(offerAt) == "number" and os.time() >= offerAt
		and os.clock() >= leaveSnoozedUntil
		and not leaveFrame.Visible and player:GetAttribute("SettingPopups") ~= false then
		setLeaveOpen(true)
		remotes.LeaveCardEvent:FireServer("Shown")
	end
end)

--------------------------------------------------
-- PURCHASE CONFIRMED (only after the server granted, saved and recorded it)
--------------------------------------------------

local confirmToast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -170),
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
		TweenService:Create(confirmToast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -170) }):Play()
	end)
end)

--------------------------------------------------
-- CAPTAIN ANNOUNCEMENT (everyone in the server sees who bought the pack)
--
-- A volcano-style ERUPTION: a deep layered boom, a medium-small shake of the
-- screen, and a full-screen announcement that fades in over the game, says what
-- EVERYONE in the server now has, then fades out. Visual / audio only; the
-- rewards themselves are granted by the server (ProductService).
--------------------------------------------------

local captainOverlay = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(70, 18, 6),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 90,
}, gui)

create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 60)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(230, 70, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 40)),
	}),
	Rotation = 90,
}, captainOverlay)

local function overlayText(name, y, height, size, color)
	local label = create("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, y, 0),
		Size = UDim2.new(0.9, 0, 0, height),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "",
		TextColor3 = color,
		TextSize = size,
		TextWrapped = true,
		TextTransparency = 1,
		ZIndex = 91,
	}, captainOverlay)
	create("UIStroke", { Color = INK, Thickness = 5 }, label)
	return label
end

local captainTitle = overlayText("Title", 0.30, 90, 64, Color3.fromRGB(255, 236, 130))
local captainWho = overlayText("Who", 0.44, 56, 34, CREAM)
local captainGets = overlayText("Gets", 0.62, 150, 40, Color3.fromRGB(190, 255, 190))

-- screen shake: nudges the camera and the whole UI for a moment
local shakeUntil = 0
local shakeStrength = 0

local function startShake(strength, duration)
	shakeStrength = strength
	shakeUntil = os.clock() + duration
	local started = os.clock()

	pcall(function()
		RunService:UnbindFromRenderStep("CaptainShake")
	end)
	RunService:BindToRenderStep("CaptainShake", Enum.RenderPriority.Last.Value + 5, function()
		local now = os.clock()
		if now >= shakeUntil then
			RunService:UnbindFromRenderStep("CaptainShake")
			return
		end

		local fade = 1 - (now - started) / (shakeUntil - started)
		local s = shakeStrength * fade
		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame = camera.CFrame
				* CFrame.Angles(math.rad((math.random() - 0.5) * s), math.rad((math.random() - 0.5) * s), 0)
		end
	end)
end

-- Layered built-in sounds, pitched down and run through reverb: a deep
-- rumble, a boom, a splash and glass for the burst (volume follows SFX).
local function eruptionSound()
	if player:GetAttribute("SettingSfx") == false then
		return
	end

	local layers = {
		{ "rbxasset://sounds/bass.mp3", 1.0, 0.35, 0 },
		{ "rbxasset://sounds/bass.mp3", 0.9, 0.5, 0.18 },
		{ "rbxasset://sounds/impact_water.mp3", 0.9, 0.45, 0.1 },
		{ "rbxasset://sounds/glassbreak.wav", 0.45, 0.4, 0.35 },
		{ "rbxasset://sounds/splat.wav", 0.7, 0.5, 0.25 },
		{ "rbxasset://sounds/snap.mp3", 0.5, 0.3, 0.5 },
	}

	for _, layer in ipairs(layers) do
		task.delay(layer[4], function()
			local sound = create("Sound", { SoundId = layer[1], Volume = layer[2], PlaybackSpeed = layer[3] }, SoundService)
			create("ReverbSoundEffect", { DecayTime = 3.2, Density = 0.9, Diffusion = 0.9, DryLevel = -2, WetLevel = -3 }, sound)
			sound:Play()
			task.delay(8, function()
				sound:Destroy()
			end)
		end)
	end
end

local announcing = false

remotes:WaitForChild("CaptainAnnounce").OnClientEvent:Connect(function(name, wins, minutes)
	if typeof(name) ~= "string" or typeof(wins) ~= "number" or typeof(minutes) ~= "number" or announcing then
		return
	end
	announcing = true

	captainTitle.Text = "CAPTAIN OIL SERVER PACK!"
	captainWho.Text = string.sub(name, 1, 24) .. " just bought it for the whole server!"
	captainGets.Text = string.format(
		"EVERYONE NOW HAS:\n+%s WINS   x2 OIL   x2 WINS   x3 CAPTAIN\nfor %d minutes!",
		tostring(wins):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""),
		minutes
	)

	captainOverlay.Visible = true
	eruptionSound()
	startShake(7, 1.6)

	local fadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(captainOverlay, fadeIn, { BackgroundTransparency = 0.45 }):Play()
	for _, label in ipairs({ captainTitle, captainWho, captainGets }) do
		TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()
	end

	task.delay(6.5, function()
		local fadeOut = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(captainOverlay, fadeOut, { BackgroundTransparency = 1 }):Play()
		for _, label in ipairs({ captainTitle, captainWho, captainGets }) do
			TweenService:Create(label, fadeOut, { TextTransparency = 1 }):Play()
		end
		task.delay(1.3, function()
			captainOverlay.Visible = false
			announcing = false
		end)
	end)
end)
-- Tutorial retention nudge (opening the Roblox menu before the tutorial is finished): a short
-- toast instead of the leave-reward card, which would sit on top of the tutorial.
local stayToastToken = 0
showStayMessage = function()
	stayToastToken += 1
	local token = stayToastToken
	confirmToast.Text = "Almost there! Finish the tutorial to unlock rewards"
	confirmToast.Size = UDim2.fromOffset(520, 52)
	ding()
	TweenService:Create(confirmToast, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 24) }):Play()
	task.delay(4, function()
		if token == stayToastToken then
			TweenService:Create(confirmToast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -170) }):Play()
		end
	end)
end

-- Belt and braces: the FREE claim card is hidden whenever ANY panel (calendar, store, quests, shop...)
-- is open, so it can never sit over a panel's X button on a small screen, whatever the layering is.
do
	local PanelManagerForCard = require(ReplicatedStorage:WaitForChild("PanelManager"))
	-- menus that are not PanelManager panels but are also big (Ball Shop, Settings, Worlds)
	local OVERLAYS = { "BallShopUI", "SettingsUI", "WorldsUI" }
	local function overlayOpen()
		for _, name in ipairs(OVERLAYS) do
			local g = playerGui:FindFirstChild(name)
			if g and g:IsA("ScreenGui") and g.Enabled then
				for _, child in ipairs(g:GetChildren()) do
					if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.X > 300 and child.AbsoluteSize.Y > 200 then
						return true
					end
				end
			end
		end
		return false
	end
	task.spawn(function()
		while true do
			local runState = player:GetAttribute("RunState")
			local onCourse = runState ~= nil and runState ~= "" and runState ~= "Waiting"
			-- the free x6 / generator gifts stay away until the tutorial is finished
			local inTutorial = (player:GetAttribute("TutorialStep") or 0) < 12
			cardGui.Enabled = not (inTutorial or onCourse or PanelManagerForCard.AnyOpen() or overlayOpen() or leaveFrame.Visible)
			task.wait(0.1)
		end
	end)
end
