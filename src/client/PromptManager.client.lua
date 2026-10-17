--------------------------------------------------
-- PROMPT MANAGER
--
-- CLIENT ONLY.
--   1. Friendly, dismissible invitations to JOIN THE GROUP and to
--      FAVORITE the game. They only appear in the lobby (RunState
--      Waiting), never while a run, the shop or a panel is open, and they
--      loop on a timer until the player has done them. The server says
--      what is already done (PromptService) and re-checks group
--      membership itself.
--   2. Anti-AFK: keeps Roblox from kicking idle players (20 minute idle
--      timeout) by sending a harmless virtual click when the idle event
--      fires.
--
-- Nothing here grants a reward; it is purely an invitation.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local promptState = remotes:WaitForChild("PromptState")
local promptDone = remotes:WaitForChild("PromptDone")

-- Timing (seconds)
local FIRST_PROMPT_DELAY = 180
local PROMPT_INTERVAL = 420
local AUTO_DISMISS = 25

--------------------------------------------------
-- ANTI-AFK
--------------------------------------------------

player.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

--------------------------------------------------
-- STYLE
--------------------------------------------------

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GREEN = Color3.fromRGB(88, 196, 110)
local SKY = Color3.fromRGB(86, 168, 240)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("PromptManagerUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "PromptManagerUI",
	ResetOnSpawn = false,
	DisplayOrder = 11,
}, playerGui)

local card = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 380, 0.45, 0), -- off-screen, slides in
	Size = UDim2.fromOffset(340, 150),
	BackgroundColor3 = LANE,
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
create("UIStroke", { Color = INK, Thickness = 4 }, card)
local cardScale = create("UIScale", { Scale = 1 }, card)

local function fitCard()
	cardScale.Scale = math.clamp(gui.AbsoluteSize.X / 900, 0.6, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCard)
fitCard()

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.new(1, -28, 0, 30),
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
}, card)
create("UIStroke", { Color = INK, Thickness = 2.5 }, title)

local body = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.new(1, -28, 0, 44),
	Font = Enum.Font.GothamMedium,
	Text = "",
	TextColor3 = INK,
	TextSize = 15,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, card)

local yesButton = create("TextButton", {
	Position = UDim2.new(0, 14, 1, -52),
	Size = UDim2.fromOffset(150, 40),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 18,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, yesButton)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, yesButton)

local laterButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 1, -52),
	Size = UDim2.fromOffset(110, 40),
	BackgroundColor3 = CREAM,
	Font = FONT,
	Text = "NOT NOW",
	TextColor3 = INK,
	TextSize = 16,
}, card)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, laterButton)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, laterButton)

--------------------------------------------------
-- SHOW / HIDE
--------------------------------------------------

local visible = false
local currentToken = 0

local function hideCard()
	if not visible then
		return
	end
	visible = false
	currentToken += 1

	local tween = TweenService:Create(
		card,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(1, 380, 0.45, 0) }
	)
	tween.Completed:Once(function()
		if not visible then
			card.Visible = false
		end
	end)
	tween:Play()
end

local function showCard(heading, text, yesText, color)
	visible = true
	currentToken += 1
	local token = currentToken

	title.Text = heading
	body.Text = text
	yesButton.Text = yesText
	yesButton.BackgroundColor3 = color

	card.Visible = true
	TweenService:Create(
		card,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -16, 0.45, 0) }
	):Play()

	task.delay(AUTO_DISMISS, function()
		if visible and token == currentToken then
			hideCard()
		end
	end)
end

-- Single, permanent click handlers (connected once, below) that act on
-- whichever prompt is current, so reopening never stacks connections.
local activeAction = nil

yesButton.Activated:Connect(function()
	local action = activeAction
	hideCard()
	if action then
		task.spawn(action)
	end
end)

laterButton.Activated:Connect(function()
	hideCard()
end)

--------------------------------------------------
-- WHEN IS IT OK TO INTERRUPT?
--------------------------------------------------

local function canInterrupt()
	local runState = player:GetAttribute("RunState")
	if not (runState == nil or runState == "" or runState == "Waiting") then
		return false
	end

	-- Never over the shop, calendar or other panels.
	for _, name in ipairs({ "BallShopUI" }) do
		local other = playerGui:FindFirstChild(name)
		if other and other:IsA("ScreenGui") and other.Enabled then
			return false
		end
	end

	local hub = playerGui:FindFirstChild("HubUI")
	if hub then
		for _, panelName in ipairs({ "ShopPanel", "CalendarPanel" }) do
			local panel = hub:FindFirstChild(panelName)
			if panel and panel.Visible then
				return false
			end
		end
	end

	return true
end

--------------------------------------------------
-- THE TWO INVITATIONS
--------------------------------------------------

local function offerGroup(groupId)
	activeAction = function()
		local ok, status = pcall(function()
			return GroupService:PromptJoinAsync(groupId)
		end)

		if not ok then
			warn("[PromptManager] Group prompt failed:", status)
		end
	end

	showCard(
		"JOIN OUR GROUP!",
		"Join the community for news, updates and giveaways.",
		"JOIN",
		SKY
	)
end

local favoriteBusy = false

local function offerFavorite()
	activeAction = function()
		if favoriteBusy then
			return
		end
		favoriteBusy = true

		local connection
		connection = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(success)
			favoriteBusy = false
			connection:Disconnect()

			if success then
				promptDone:FireServer("Favorite")
			end
		end)

		local ok, err = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)

		if not ok then
			favoriteBusy = false
			connection:Disconnect()
			warn("[PromptManager] Favorite prompt failed:", err)
		end
	end

	showCard(
		"LIKE THE GAME?",
		"Tap FAVORITE so you never lose your lane.",
		"FAVORITE",
		PIN_RED
	)
end

--------------------------------------------------
-- LOOP
--------------------------------------------------

task.spawn(function()
	task.wait(FIRST_PROMPT_DELAY)

	local turn = 0

	while true do
		-- Wait for a good moment.
		while not canInterrupt() or visible do
			task.wait(5)
		end

		local ok, state = pcall(function()
			return promptState:InvokeServer()
		end)

		if ok and typeof(state) == "table" then
			local pending = {}

			if not state.GroupDone then
				table.insert(pending, "Group")
			end
			if not state.FavoriteDone then
				table.insert(pending, "Favorite")
			end

			if #pending == 0 then
				-- Everything done: stop for the rest of the session.
				break
			end

			turn += 1
			local pick = pending[(turn - 1) % #pending + 1]

			if pick == "Group" then
				offerGroup(state.GroupId)
			else
				offerFavorite()
			end
		end

		task.wait(PROMPT_INTERVAL)
	end
end)
