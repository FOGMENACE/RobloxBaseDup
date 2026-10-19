--------------------------------------------------
-- COMMUNITY REWARDS (podium) - CLIENT
--
--   * Animates the podium: rainbow, glowing, shaking "FREE WINS!" sign and
--     a clean gold circle.
--   * Using the circle's prompt opens the COMMUNITY REWARDS panel with the
--     two steps (like the game, join the group) and a claim button.
--   * Eligibility, the +500 wins and the "already claimed" flag are all
--     decided by RewardService; the client only asks and shows the answer.
--     The panel never says "claimed" until the server confirms.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GROUP_ID = 42308423

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local RED = Color3.fromRGB(235, 70, 70)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

--------------------------------------------------
-- PODIUM ANIMATION
--------------------------------------------------

task.spawn(function()
	local podium = workspace:WaitForChild("Podium", 30)
	if not podium then
		return
	end

	local anchor = podium:WaitForChild("TitleAnchor")
	local billboard = anchor:WaitForChild("FreeWinsBillboard")
	local text = billboard:WaitForChild("Text")
	local gradient = text:WaitForChild("Rainbow")
	local circle = podium:WaitForChild("CommunityCircle")
	local home = billboard.StudsOffset

	-- soft golden glow behind the text
	local glow = create("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1.3, 0, 1.8, 0),
		BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/Controls/DesignSystem/DropShadow.png",
		ImageColor3 = Color3.fromRGB(255, 230, 120),
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(0, 0, 1, 1),
		ZIndex = 0,
	}, billboard)

	local hues = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		hues += dt * 0.35

		gradient.Offset = Vector2.new((hues % 2) - 1, 0)
		text.Rotation = math.sin(t * 22) * 2.2
		text.Position = UDim2.fromScale(0.5 + math.sin(t * 31) * 0.008, 0.5 + math.cos(t * 27) * 0.02)
		glow.ImageTransparency = 0.45 + math.sin(t * 3) * 0.15
		billboard.StudsOffset = home + Vector3.new(0, math.sin(t * 2) * 0.4, 0)

	end)
end)

--------------------------------------------------
-- PANEL
--------------------------------------------------

local old = playerGui:FindFirstChild("CommunityUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "CommunityUI",
	ResetOnSpawn = false,
	DisplayOrder = 25,
}, playerGui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 470),
	BackgroundColor3 = Color3.fromRGB(46, 36, 96),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
create("UIStroke", { Color = INK, Thickness = 5 }, panel)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(86, 62, 170), Color3.fromRGB(34, 28, 78)),
	Rotation = 90,
}, panel)
local scale = create("UIScale", { Scale = 1 }, panel)

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local strokeThickness = props.StrokeThickness or 3
	props.StrokeThickness = nil
	local l = create("TextLabel", props, parent or panel)
	create("UIStroke", { Color = INK, Thickness = strokeThickness }, l)
	return l
end

label({
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -60, 0, 40),
	Text = "COMMUNITY REWARDS",
	TextColor3 = Color3.fromRGB(255, 226, 90),
	TextSize = 30,
})

local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, close)
create("UIStroke", { Color = INK, Thickness = 3 }, close)

local trophy = create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(120, 120),
	BackgroundTransparency = 1,
	Image = UiAssets.TrophyImage,
	ScaleType = Enum.ScaleType.Fit,
}, panel)

label({
	Position = UDim2.fromOffset(10, 180),
	Size = UDim2.new(1, -20, 0, 26),
	Text = "LIMITED TIME",
	TextColor3 = Color3.fromRGB(255, 120, 150),
	TextSize = 20,
})
label({
	Position = UDim2.fromOffset(10, 204),
	Size = UDim2.new(1, -20, 0, 54),
	Text = "+500 WINS!",
	TextColor3 = Color3.fromRGB(120, 255, 150),
	TextSize = 46,
	StrokeThickness = 4,
})

-- the two steps
local function step(y, number, text, buttonText)
	local row = create("Frame", {
		Position = UDim2.fromOffset(24, y),
		Size = UDim2.new(1, -48, 0, 46),
		BackgroundColor3 = Color3.fromRGB(30, 24, 66),
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, row)

	label({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -150, 1, 0),
		Text = number .. "  " .. text,
		TextColor3 = CREAM,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 2,
	}, row)

	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(108, 32),
		BackgroundColor3 = Color3.fromRGB(86, 168, 240),
		Font = FONT,
		Text = buttonText,
		TextColor3 = CREAM,
		TextSize = 16,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, button)
	return button
end

local likeButton = step(268, "1", "Like the game!", "LIKE")
local joinButton = step(322, "2", "Join the community!", "JOIN")

local claimButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 382),
	Size = UDim2.fromOffset(260, 52),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "CLAIM",
	TextColor3 = CREAM,
	TextSize = 28,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, claimButton)
create("UIStroke", { Color = INK, Thickness = 3 }, claimButton)
Shine.Attach(claimButton, { Offset = 0 })

local message = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 438),
	Size = UDim2.new(1, -24, 0, 26),
	Text = "",
	TextColor3 = RED,
	TextSize = 16,
	StrokeThickness = 2,
})

--------------------------------------------------
-- LOGIC
--------------------------------------------------

local state = nil

local function refresh()
	local ok, result = pcall(function()
		return remotes.CommunityRewardState:InvokeServer()
	end)
	if not ok or typeof(result) ~= "table" then
		message.Text = "Could not reach the server. Try again!"
		message.TextColor3 = RED
		return
	end

	state = result
	likeButton.Text = result.Liked and "DONE" or "LIKE"
	likeButton.BackgroundColor3 = result.Liked and GREEN or Color3.fromRGB(86, 168, 240)
	joinButton.Text = result.Group and "DONE" or "JOIN"
	joinButton.BackgroundColor3 = result.Group and GREEN or Color3.fromRGB(86, 168, 240)

	if result.Claimed then
		claimButton.Text = "CLAIMED"
		claimButton.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
		message.Text = "You already claimed this reward. Thank you!"
		message.TextColor3 = Color3.fromRGB(190, 255, 200)
	else
		claimButton.Text = "CLAIM"
		claimButton.BackgroundColor3 = GREEN
		message.Text = ""
	end
end

PanelManager.Register("Community", panel, function()
	message.Text = ""
	task.spawn(refresh)
end)

local function setOpen(open)
	if open then
		PanelManager.Open("Community")
	else
		PanelManager.Close("Community")
	end
end

close.Activated:Connect(function()
	setOpen(false)
end)

likeButton.Activated:Connect(function()
	if state and state.Liked then
		return
	end

	local connection
	connection = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		connection:Disconnect()
		-- The event passes an Enum.AvatarPromptResult (always truthy): only an
		-- explicit Success counts, so pressing No / closing the prompt does not.
		if result == Enum.AvatarPromptResult.Success then
			remotes.PromptDone:FireServer("Favorite")
			task.wait(1.5) -- let the server save the flag first
			refresh()
		else
			message.Text = "Tap LIKE and press Yes to favorite the game."
			message.TextColor3 = RED
		end
	end)

	local ok = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		connection:Disconnect()
		message.Text = "Could not open the like prompt here."
		message.TextColor3 = RED
	end
end)

joinButton.Activated:Connect(function()
	if state and state.Group then
		return
	end
	pcall(function()
		GroupService:PromptJoinAsync(GROUP_ID)
	end)
	task.wait(1)
	refresh()
end)

local claiming = false

-- Click hint: a mouse cursor that glides to the next button the player still
-- has to press (LIKE, then JOIN, then CLAIM) and clicks it, with a ripple.
-- Display only; hidden once the reward is claimed.
local cursor = create("ImageLabel", {
	Name = "ClickHint",
	AnchorPoint = Vector2.new(0.12, 0.05),
	Size = UDim2.fromOffset(60, 60),
	BackgroundTransparency = 1,
	Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
	ZIndex = 60,
	Visible = false,
}, panel)
local ripple = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(10, 10),
	BackgroundTransparency = 1,
	ZIndex = 59,
	Visible = false,
}, panel)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, ripple)
local rippleStroke = create("UIStroke", { Color = Color3.fromRGB(255, 226, 90), Thickness = 3 }, ripple)

RunService.RenderStepped:Connect(function()
	if not panel.Visible then
		return
	end
	local target = nil
	if state then
		if not state.Liked then
			target = likeButton
		elseif not state.Group then
			target = joinButton
		elseif not state.Claimed then
			target = claimButton
		end
	end
	cursor.Visible = target ~= nil
	ripple.Visible = target ~= nil
	if not target then
		return
	end

	local unit = panel.AbsoluteSize.X / 440
	local c = (target.AbsolutePosition - panel.AbsolutePosition + target.AbsoluteSize / 2) / unit
	local t = (os.clock() % 1.5) / 1.5
	local away = 30 * (1 - math.min(t / 0.5, 1)) -- glides in from the bottom-right
	local pressed = t > 0.5 and t < 0.7
	cursor.Position = UDim2.fromOffset(c.X + away, c.Y + away)
	cursor.Size = pressed and UDim2.fromOffset(50, 50) or UDim2.fromOffset(60, 60)
	ripple.Position = UDim2.fromOffset(c.X, c.Y)
	if t > 0.5 then
		local k = (t - 0.5) / 0.5
		ripple.Size = UDim2.fromOffset(10 + 54 * k, 10 + 54 * k)
		rippleStroke.Transparency = k
	else
		rippleStroke.Transparency = 1
	end
end)

claimButton.Activated:Connect(function()
	if claiming or (state and state.Claimed) then
		return
	end
	claiming = true

	local ok, success, reason = pcall(function()
		return remotes.CommunityRewardClaim:InvokeServer()
	end)

	if ok and success then
		claimButton.Text = "+500 WINS!"
		message.Text = "Reward claimed. Enjoy!"
		message.TextColor3 = Color3.fromRGB(190, 255, 200)
		task.wait(1)
		refresh()
	elseif ok and reason == "REQUIREMENTS" then
		message.Text = "Like game and join community to claim!"
		message.TextColor3 = RED
		refresh()
		message.Text = "Like game and join community to claim!"
	elseif ok and reason == "CLAIMED" then
		refresh()
	else
		message.Text = "Something went wrong. Try again!"
		message.TextColor3 = RED
	end

	claiming = false
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt.Name == "CommunityPrompt" then
		PanelManager.Toggle("Community")
	end
end)
