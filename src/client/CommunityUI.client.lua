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

local PANEL_W, PANEL_H = 640, 480
local GOLD = Color3.fromRGB(255, 205, 40)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	BackgroundColor3 = Color3.new(1, 1, 1), -- the purple comes from the gradient below
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(86, 62, 170), Color3.fromRGB(34, 28, 78)),
	Rotation = 90,
}, panel)
create("UIStroke", { Color = INK, Thickness = 5 }, panel)
local scale = create("UIScale", { Scale = 1 }, panel)

-- fits any screen: as large as possible, never off screen
local function fit()
	local viewport = gui.AbsoluteSize
	scale.Scale = math.clamp(math.min((viewport.X - 24) / PANEL_W, (viewport.Y - 24) / PANEL_H), 0.4, 1.15)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local strokeThickness = props.StrokeThickness or 3
	props.StrokeThickness = nil
	local l = create("TextLabel", props, parent or panel)
	if strokeThickness > 0 then
		create("UIStroke", { Color = INK, Thickness = strokeThickness }, l)
	end
	return l
end

-- gold title bar with a red X, like the reference
local bar = create("Frame", {
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.new(1, -20, 0, 62),
	BackgroundColor3 = GOLD,
	ZIndex = 2,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, bar)
create("UIStroke", { Color = INK, Thickness = 3 }, bar)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 232, 90), Color3.fromRGB(240, 170, 10)),
	Rotation = 90,
}, bar)
label({
	Position = UDim2.fromOffset(14, 4),
	Size = UDim2.new(1, -90, 1, -8),
	Text = "COMMUNITY REWARDS",
	TextColor3 = CREAM,
	TextSize = 36,
	TextXAlignment = Enum.TextXAlignment.Left,
	StrokeThickness = 4,
	ZIndex = 3,
}, bar)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 24,
	ZIndex = 4,
}, bar)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, close)
create("UIStroke", { Color = INK, Thickness = 3 }, close)

local trophy = create("ImageLabel", {
	Position = UDim2.fromOffset(34, 82),
	Size = UDim2.fromOffset(150, 140),
	BackgroundTransparency = 1,
	Image = UiAssets.TrophyImage,
	ScaleType = Enum.ScaleType.Fit,
}, panel)

local limited = label({
	Position = UDim2.fromOffset(200, 80),
	Size = UDim2.fromOffset(420, 44),
	Text = "~ LIMITED TIME! ~",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 38,
	StrokeThickness = 3,
})
create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 200)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(150, 70, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 220, 200)),
		ColorSequenceKeypoint.new(0.85, Color3.fromRGB(120, 240, 90)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 70)),
	}),
}, limited)
local winsText = label({
	Position = UDim2.fromOffset(200, 124),
	Size = UDim2.fromOffset(420, 84),
	Text = "+500 Wins!",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 78,
	StrokeThickness = 5,
})
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 244, 150), Color3.fromRGB(255, 196, 40)),
	Rotation = 90,
}, winsText)

-- one step card: a title and a little picture of WHERE to press, with red arrows
local function stepCard(x, title)
	local card = create("TextButton", {
		Position = UDim2.fromOffset(x, 226),
		Size = UDim2.fromOffset(292, 156),
		BackgroundColor3 = Color3.fromRGB(30, 24, 66),
		Text = "",
		AutoButtonColor = false,
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
	create("UIStroke", { Color = INK, Thickness = 3 }, card)
	label({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 40),
		Text = title,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 30,
		StrokeThickness = 3,
	}, card)
	local mock = create("Frame", {
		Position = UDim2.fromOffset(6, 46),
		Size = UDim2.new(1, -12, 1, -52),
		BackgroundColor3 = Color3.fromRGB(34, 36, 44),
		ClipsDescendants = true,
	}, card)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, mock)
	-- "DONE" cover, shown once the step is complete
	local done = create("Frame", {
		Name = "Done",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 150, 70),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 20,
	}, mock)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, done)
	label({
		Size = UDim2.fromScale(1, 1),
		Text = "DONE!",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 44,
		ZIndex = 21,
	}, done)
	return card, mock
end

local function redArrow(parent, x, y, rotation, size)
	return label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size or 70, size or 70),
		Text = "➡",
		TextColor3 = Color3.fromRGB(240, 30, 30),
		TextSize = size or 70,
		Rotation = rotation,
		StrokeThickness = 2,
		ZIndex = 10,
	}, parent)
end

-- card 1: the like bar of a game page
local likeButton, likeMock = stepCard(20, "1. Like the game!")
for _, spec in ipairs({
	{ x = 52, icon = "🔔", text = "Notify" },
	{ x = 140, icon = "👍", text = "17" },
	{ x = 226, icon = "👎", text = "8" },
}) do
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(spec.x, 6),
		Size = UDim2.fromOffset(60, 44),
		Text = spec.icon,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 36,
		StrokeThickness = 0,
	}, likeMock)
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(spec.x, 50),
		Size = UDim2.fromOffset(60, 20),
		Text = spec.text,
		TextColor3 = Color3.fromRGB(235, 235, 240),
		TextSize = 16,
		StrokeThickness = 0,
	}, likeMock)
end
for i = 0, 3 do -- the like ratio bar under the thumbs
	create("Frame", {
		Position = UDim2.fromOffset(112 + i * 18, 42),
		Size = UDim2.fromOffset(15, 3),
		BackgroundColor3 = i < 3 and Color3.fromRGB(240, 240, 245) or Color3.fromRGB(110, 110, 120),
		BorderSizePixel = 0,
	}, likeMock)
end
redArrow(likeMock, 110, 86, -42, 62)

-- card 2: the group page's Join Community button
local joinButton, joinMock = stepCard(328, "2. Join the community!")
local fakeJoin = create("Frame", {
	Position = UDim2.fromOffset(20, 30),
	Size = UDim2.fromOffset(180, 40),
	BackgroundColor3 = Color3.fromRGB(51, 95, 255),
}, joinMock)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, fakeJoin)
label({
	Size = UDim2.fromScale(1, 1),
	Text = "Join Community",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 20,
	StrokeThickness = 0,
}, fakeJoin)
local fakeMore = create("Frame", {
	Position = UDim2.fromOffset(208, 30),
	Size = UDim2.fromOffset(42, 40),
	BackgroundColor3 = Color3.fromRGB(70, 72, 84),
}, joinMock)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, fakeMore)
label({
	Size = UDim2.fromScale(1, 1),
	Text = "...",
	TextColor3 = Color3.fromRGB(230, 230, 235),
	TextSize = 22,
	StrokeThickness = 0,
}, fakeMore)
redArrow(joinMock, 60, 92, -35, 60)
redArrow(joinMock, 240, 12, 140, 44)

local claimButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 392),
	Size = UDim2.fromOffset(300, 64),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "CLAIM!",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 46,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, claimButton)
create("UIStroke", { Color = INK, Thickness = 3.5 }, claimButton)
Shine.Attach(claimButton, { Offset = 0 })
local message = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 458),
	Size = UDim2.new(1, -24, 0, 18),
	Text = "",
	TextColor3 = RED,
	TextSize = 16,
	StrokeThickness = 2,
})

local function setDone(card, isDone)
	local cover = card:FindFirstChild("Done", true)
	if cover then
		cover.Visible = isDone == true
	end
end

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
	setDone(likeButton, result.Liked)
	setDone(joinButton, result.Group)

	if result.Claimed then
		claimButton.Text = "CLAIMED"
		claimButton.BackgroundColor3 = Color3.fromRGB(110, 110, 130)
		message.Text = "You already claimed this reward. Thank you!"
		message.TextColor3 = Color3.fromRGB(190, 255, 200)
	else
		claimButton.Text = "CLAIM!"
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
			message.Text = "Tap card 1 and press Yes to favorite the game, then give it a thumbs up on its page."
			message.TextColor3 = RED
		end
	end)

	local ok = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		connection:Disconnect()
		message.Text = "Could not open the favorite prompt here."
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

	local unit = panel.AbsoluteSize.X / PANEL_W
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
		message.Text = "Finish both steps first, then claim!"
		message.TextColor3 = RED
		refresh()
		message.Text = "Finish both steps first, then claim!"
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
