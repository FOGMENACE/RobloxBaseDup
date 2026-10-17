--------------------------------------------------
-- LEADERBOARD UI
--
-- CLIENT ONLY. Makes the three lobby boards (built by
-- LeaderboardService) clickable / tappable. Clicking one opens a panel
-- with the full TOP 20 as a vertical, scrollable list, with tabs to
-- switch between MOST WINS / MOST REBIRTHS / ROBUX SPENT.
-- The data comes from the server (Remotes.LeaderboardData).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dataRemote = remotes:WaitForChild("LeaderboardData")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GOLD = Color3.fromRGB(255, 205, 70)
local SILVER = Color3.fromRGB(205, 210, 220)
local BRONZE = Color3.fromRGB(214, 140, 90)
local GREEN = Color3.fromRGB(88, 196, 110)
local FONT = Enum.Font.FredokaOne

local TABS = {
	{ Key = "Wins", Label = "WINS" },
	{ Key = "Rebirths", Label = "REBIRTHS" },
	{ Key = "Robux", Label = "ROBUX" },
}

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

--------------------------------------------------
-- PANEL
--------------------------------------------------

local old = playerGui:FindFirstChild("LeaderboardUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "LeaderboardUI",
	ResetOnSpawn = false,
	DisplayOrder = 13,
	Enabled = false,
}, playerGui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(430, 560),
	BackgroundColor3 = LANE,
}, gui)
round(panel, 18)
create("UIStroke", { Color = INK, Thickness = 4 }, panel)
local panelScale = create("UIScale", { Scale = 1 }, panel)

local function fit()
	local viewport = gui.AbsoluteSize
	panelScale.Scale = math.clamp(math.min(viewport.X / 480, viewport.Y / 620), 0.55, 1.1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.fromOffset(300, 36),
	Font = FONT,
	Text = "TOP 20",
	TextColor3 = CREAM,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
create("UIStroke", { Color = INK, Thickness = 3 }, title)

local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = PIN_RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
round(close, 10)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)

-- Tabs
local tabButtons = {}
local tabRow = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 52),
	Size = UDim2.new(1, -24, 0, 36),
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabRow)

for index, tab in ipairs(TABS) do
	local button = create("TextButton", {
		LayoutOrder = index,
		Size = UDim2.new(1 / #TABS, -4, 1, 0),
		BackgroundColor3 = CREAM,
		Font = FONT,
		Text = tab.Label,
		TextColor3 = INK,
		TextSize = 16,
	}, tabRow)
	round(button, 10)
	create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	tabButtons[tab.Key] = button
end

-- Vertical scrolling list
local list = create("ScrollingFrame", {
	BackgroundColor3 = CREAM,
	BackgroundTransparency = 0.1,
	Position = UDim2.fromOffset(12, 98),
	Size = UDim2.new(1, -24, 1, -112),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 8,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	BorderSizePixel = 0,
}, panel)
round(list, 12)
create("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)
create("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 10),
}, list)

local currentKey = "Wins"
local requestToken = 0

local function rankColor(rank)
	if rank == 1 then
		return GOLD
	elseif rank == 2 then
		return SILVER
	elseif rank == 3 then
		return BRONZE
	end
	return CREAM
end

local function show(key)
	currentKey = key
	requestToken += 1
	local token = requestToken

	for tabKey, button in pairs(tabButtons) do
		button.BackgroundColor3 = (tabKey == key) and GREEN or CREAM
		button.TextColor3 = (tabKey == key) and CREAM or INK
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local loading = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "Loading...",
		TextColor3 = INK,
		TextSize = 20,
	}, list)

	local ok, data = pcall(function()
		return dataRemote:InvokeServer(key)
	end)

	if token ~= requestToken then
		return -- the player switched tabs meanwhile
	end

	loading:Destroy()

	if not ok or typeof(data) ~= "table" then
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = "Not available right now.",
			TextColor3 = INK,
			TextSize = 18,
		}, list)
		return
	end

	title.Text = "TOP 20  -  " .. tostring(data.Title or "")

	local entries = data.Entries or {}
	local any = false

	for rank = 1, 20 do
		local entry = entries[rank]
		local isMe = entry and entry.UserId == player.UserId

		local row = create("Frame", {
			LayoutOrder = rank,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = isMe and Color3.fromRGB(255, 244, 190)
				or ((rank % 2 == 0) and Color3.fromRGB(46, 44, 66) or Color3.fromRGB(36, 34, 52)),
		}, list)
		round(row, 8)

		if isMe then
			create("UIStroke", { Color = PIN_RED, Thickness = 3 }, row)
		end

		local textColor = isMe and INK or rankColor(rank)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(52, 38),
			Font = FONT,
			Text = "#" .. rank,
			TextColor3 = textColor,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(66, 0),
			Size = UDim2.new(1, -190, 1, 0),
			Font = FONT,
			Text = entry and entry.Name or "-",
			TextColor3 = textColor,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.fromOffset(110, 38),
			Font = FONT,
			Text = entry and entry.Value or "",
			TextColor3 = textColor,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)

		any = any or entry ~= nil
	end

	list.CanvasPosition = Vector2.zero

	if not any then
		title.Text = "TOP 20  -  " .. tostring(data.Title or "") .. " (nobody yet)"
	end
end

for key, button in pairs(tabButtons) do
	button.Activated:Connect(function()
		show(key)
	end)
end

local function setOpen(open, key)
	if open then
		gui.Enabled = true
		panelScale.Scale = panelScale.Scale * 0.9
		fit()
		task.spawn(show, key or currentKey)
	else
		gui.Enabled = false
	end
end

close.Activated:Connect(function()
	setOpen(false)
end)

--------------------------------------------------
-- MAKE THE WALL BOARDS CLICKABLE
--------------------------------------------------

local function hookBoard(part)
	if not part:IsA("BasePart") then
		return
	end

	local key = part.Name:match("^(%a+)Board$")
	if not key or not table.find({ "Wins", "Rebirths", "Robux" }, key) then
		return
	end

	if part:FindFirstChildOfClass("ClickDetector") then
		return
	end

	local detector = create("ClickDetector", {
		MaxActivationDistance = 90,
	}, part)

	detector.MouseClick:Connect(function()
		setOpen(true, key)
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild("Leaderboards")

	for _, child in ipairs(folder:GetChildren()) do
		hookBoard(child)
	end

	folder.ChildAdded:Connect(hookBoard)
end)
