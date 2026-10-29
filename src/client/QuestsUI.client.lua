--------------------------------------------------
-- QUESTS PANEL (client): DAILY quests + WEEKLY milestones
--
-- Opened from the hub's QUESTS button (HubUI). Everything shown comes from
-- the server (QuestService): titles, progress, rewards and the claim
-- result. The client never reports progress or decides a reward. The
-- "SKIP" button only asks the server to open the R$ 29 purchase prompt
-- for that quest; the server validates and grants.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local GREY = Color3.fromRGB(110, 110, 130)
local BLUE = Color3.fromRGB(86, 84, 130)
local GOLD = Color3.fromRGB(255, 226, 90)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function formatNumber(value)
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local old = playerGui:FindFirstChild("QuestsUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "QuestsUI",
	ResetOnSpawn = false,
	DisplayOrder = 22,
}, playerGui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(480, 520),
	BackgroundColor3 = Color3.fromRGB(46, 36, 96),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
create("UIStroke", { Color = INK, Thickness = 5 }, panel)

-- The panel is a fixed 480 x 520: on a phone (landscape is only ~350 px tall) its bottom,
-- including the last weekly quest, ran off the screen. It scales down to always fit.
local panelScale = create("UIScale", { Scale = 1 }, panel)
local function fitPanel()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		panelScale.Scale = math.clamp(math.min((size.X - 20) / 480, (size.Y - 20) / 520), 0.45, 1)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
fitPanel()

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local l = create("TextLabel", props, parent or panel)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, l)
	return l
end

local function button(props, parent)
	props.Font = FONT
	local b = create("TextButton", props, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	create("UIStroke", { Color = INK, Thickness = 3 }, b)
	return b
end

label({
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -70, 0, 38),
	Text = "QUESTS",
	TextColor3 = GOLD,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local close = button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(235, 70, 70),
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)

-- tabs
local dailyTab = button({
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(120, 30),
	BackgroundColor3 = GREEN,
	Text = "DAILY",
	TextColor3 = CREAM,
	TextSize = 16,
}, panel)

local weeklyTab = button({
	Position = UDim2.fromOffset(142, 52),
	Size = UDim2.fromOffset(120, 30),
	BackgroundColor3 = BLUE,
	Text = "WEEKLY",
	TextColor3 = CREAM,
	TextSize = 16,
}, panel)

local subtitle = label({
	Position = UDim2.fromOffset(16, 86),
	Size = UDim2.new(1, -32, 0, 20),
	Text = "",
	TextColor3 = CREAM,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local message = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 488),
	Size = UDim2.new(1, -24, 0, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(190, 255, 200),
	TextSize = 14,
})

--------------------------------------------------
-- DAILY VIEW
--------------------------------------------------

local dailyFrame = create("Frame", {
	Position = UDim2.fromOffset(0, 112),
	Size = UDim2.new(1, 0, 0, 370),
	BackgroundTransparency = 1,
}, panel)

-- The paid SKIP as a slanted gold ribbon on the right edge of a quest row: tilted,
-- with a shine, so it reads as a "tempting offer" and not a plain button. The
-- server still opens the purchase and validates it (this is display only).
local function skipRibbon(row, fromRight, rowHeight)
	-- A slanted SASH running through the quest row (top to bottom, clipped by the
	-- row's edges), like a sale ribbon: "SKIP" over the Robux price. The whole sash
	-- is the button.
	row.ClipsDescendants = true
	local sash = button({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -fromRight - 34, 0.5, 0),
		Size = UDim2.fromOffset(64, rowHeight * 2),
		BackgroundColor3 = Color3.fromRGB(255, 176, 40),
		Text = "",
		Rotation = 18,
	}, row)
	for _, child in ipairs(sash:GetChildren()) do
		if child:IsA("UICorner") then
			child:Destroy() -- a sash has straight edges
		end
	end
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 120, 20)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 214, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 20)),
		}),
		Rotation = 0,
	}, sash)
	-- thin darker edge lines down both sides of the sash
	for _, x in ipairs({ 0, 1 }) do
		create("Frame", {
			AnchorPoint = Vector2.new(x, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = Color3.fromRGB(150, 60, 10),
			BorderSizePixel = 0,
		}, sash)
	end
	local word = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -9),
		Size = UDim2.new(1, -6, 0, 20),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "SKIP",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
	}, sash)
	create("UIStroke", { Color = Color3.fromRGB(130, 50, 10), Thickness = 1.5 }, word)
	local price = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1, -6, 0, 16),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = utf8.char(0xE002) .. " 29",
		TextColor3 = Color3.fromRGB(70, 28, 6),
		TextSize = 14,
	}, sash)
	Shine.Attach(sash, { Offset = 1.7 })
	return sash
end
local rows = {}
for index = 1, 3 do
	local row = create("Frame", {
		Position = UDim2.fromOffset(16, (index - 1) * 80),
		Size = UDim2.new(1, -32, 0, 74),
		BackgroundColor3 = Color3.fromRGB(36, 28, 80),
	}, dailyFrame)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, row)
	create("UIStroke", { Color = Color3.fromRGB(96, 78, 190), Thickness = 1.5, Transparency = 0.3 }, row)
	create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 180, 230)), Rotation = 90 }, row)

	local title = label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 24),
		Text = "...",
		TextColor3 = CREAM,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local track = create("Frame", {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -250, 0, 20),
		BackgroundColor3 = Color3.fromRGB(70, 66, 100),
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GREEN,
	}, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local progress = label({
		Size = UDim2.fromScale(1, 1),
		Text = "0 / 0",
		TextColor3 = CREAM,
		TextSize = 12,
	}, track)

	-- paid skip (R$ 29), only while the quest is unfinished
	local skip = skipRibbon(row, 128, 74)

	local claim = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 52),
		BackgroundColor3 = GREY,
		Text = "",
		TextColor3 = CREAM,
		TextSize = 15,
	}, row)
	Shine.Attach(claim, { Offset = index })

	rows[index] = { Title = title, Fill = fill, Progress = progress, Claim = claim, Skip = skip }
end

local bonusButton = button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 250),
	Size = UDim2.fromOffset(420, 56),
	BackgroundColor3 = GREY,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 17,
}, dailyFrame)

--------------------------------------------------
-- WEEKLY VIEW
--------------------------------------------------

local weeklyList = create("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 112),
	Size = UDim2.new(1, -32, 0, 366),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Visible = false,
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, weeklyList)

local weeklyRows = {}

for index = 1, 7 do
	local row = create("Frame", {
		LayoutOrder = index,
		Size = UDim2.new(1, -8, 0, 62),
		BackgroundColor3 = Color3.fromRGB(36, 28, 80),
	}, weeklyList)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, row)
	create("UIStroke", { Color = Color3.fromRGB(96, 78, 190), Thickness = 1.5, Transparency = 0.3 }, row)
	create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 180, 230)), Rotation = 90 }, row)

	local title = label({
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -130, 0, 22),
		Text = "...",
		TextColor3 = CREAM,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local track = create("Frame", {
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -240, 0, 18),
		BackgroundColor3 = Color3.fromRGB(70, 66, 100),
	}, row)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN }, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local progress = label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = CREAM,
		TextSize = 11,
	}, track)

	local claim = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(104, 46),
		BackgroundColor3 = GREY,
		Text = "",
		TextColor3 = CREAM,
		TextSize = 14,
	}, row)

	-- paid skip (one per milestone), shown while it is unfinished
	local skip = skipRibbon(row, 118, 62)

	weeklyRows[index] = { Title = title, Fill = fill, Progress = progress, Claim = claim, Skip = skip }
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local current = nil
local view = "Daily"

local function questsHubButton()
	local hub = playerGui:FindFirstChild("HubUI")
	return hub and hub:FindFirstChild("QuestsButton", true)
end

-- Which tab has something to claim (drives the red notification dots).
local function dailyClaimable(state)
	for _, quest in ipairs(state.Quests) do
		if not quest.Claimed and quest.Progress >= quest.Target then
			return true
		end
	end
	return state.AllDone == true and not state.BonusClaimed
end

local function weeklyClaimable(state)
	for _, milestone in ipairs(state.Weekly or {}) do
		if not milestone.Claimed and milestone.Progress >= milestone.Target then
			return true
		end
	end
	return false
end

local function anythingClaimable(state)
	return dailyClaimable(state) or weeklyClaimable(state)
end

-- Small red "!" dot on a tab, like a notification badge. Hidden when there is
-- nothing left to claim on that tab.
local function makeTabDot(tab)
	local dot = Instance.new("TextLabel")
	dot.Name = "ClaimDot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(22, 22)
	dot.BackgroundColor3 = Color3.fromRGB(235, 55, 60)
	dot.Font = Enum.Font.FredokaOne
	dot.Text = "!"
	dot.TextColor3 = Color3.new(1, 1, 1)
	dot.TextSize = 15
	dot.Visible = false
	dot.ZIndex = (tab.ZIndex or 1) + 5
	dot.Parent = tab
	local dotScale = Instance.new("UIScale")
	dotScale.Parent = dot
	dot:GetPropertyChangedSignal("Visible"):Connect(function()
		if dot.Visible then
			dotScale.Scale = 0.3
			game:GetService("TweenService"):Create(dotScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
	require(game:GetService("ReplicatedStorage"):WaitForChild("BadgeOverlay")).Attach(dot, tab, { Dx = 4, Dy = -2 })
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(24, 22, 34)
	stroke.Thickness = 2
	stroke.Parent = dot
	return dot
end

local dailyDot = makeTabDot(dailyTab)
local weeklyDot = makeTabDot(weeklyTab)

local function weekLeftText(state)
	local left = math.max(0, (state.WeekEndsAt or 0) - workspace:GetServerTimeNow())
	local days = math.floor(left / 86400)
	local hours = math.floor((left % 86400) / 3600)
	return days .. "d " .. hours .. "h"
end

local function setView(name)
	view = name
	dailyFrame.Visible = name == "Daily"
	weeklyList.Visible = name == "Weekly"
	dailyTab.BackgroundColor3 = name == "Daily" and GREEN or BLUE
	weeklyTab.BackgroundColor3 = name == "Weekly" and GREEN or BLUE

	if name == "Daily" then
		subtitle.Text = "New quests every day. Finish all 3 for a bonus!"
	else
		subtitle.Text = "Weekly milestones - resets in " .. (current and weekLeftText(current) or "...")
	end
end

local function render(state)
	current = state

	for index, row in ipairs(rows) do
		local quest = state.Quests[index]
		if quest then
			row.Title.Text = quest.Title
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Target, 0, 1), 1)
			row.Progress.Text = formatNumber(quest.Progress) .. " / " .. formatNumber(quest.Target)

			local done = quest.Progress >= quest.Target
			row.Skip.Visible = not quest.Claimed and not done

			if quest.Claimed then
				row.Claim.Text = "DONE"
				row.Claim.BackgroundColor3 = GREY
			elseif done then
				row.Claim.Text = "CLAIM\n+" .. formatNumber(quest.Reward)
				row.Claim.BackgroundColor3 = GREEN
			else
				row.Claim.Text = "+" .. formatNumber(quest.Reward) .. "\nWINS"
				row.Claim.BackgroundColor3 = BLUE
			end
		end
	end

	if state.BonusClaimed then
		bonusButton.Text = "BONUS CLAIMED - see you tomorrow!"
		bonusButton.BackgroundColor3 = GREY
	elseif state.AllDone then
		bonusButton.Text = "CLAIM BONUS: +" .. formatNumber(state.BonusWins) .. " WINS + x4 XP (5 MIN)"
		bonusButton.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
	else
		bonusButton.Text = "ALL 3 DONE: +" .. formatNumber(state.BonusWins) .. " WINS + x4 XP"
		bonusButton.BackgroundColor3 = BLUE
	end

	for index, row in ipairs(weeklyRows) do
		local milestone = state.Weekly and state.Weekly[index]
		if milestone then
			row.Title.Text = milestone.Title
			row.Fill.Size = UDim2.fromScale(math.clamp(milestone.Progress / milestone.Target, 0, 1), 1)
			row.Progress.Text = formatNumber(milestone.Progress) .. " / " .. formatNumber(milestone.Target)

			local done = milestone.Progress >= milestone.Target
			row.Skip.Visible = not milestone.Claimed and not done
			local extra = milestone.BoostMinutes > 0 and ("\n+x4 XP " .. milestone.BoostMinutes .. "m") or ""

			if milestone.Claimed then
				row.Claim.Text = "DONE"
				row.Claim.BackgroundColor3 = GREY
			elseif done then
				row.Claim.Text = "CLAIM\n+" .. formatNumber(milestone.Reward) .. extra
				row.Claim.BackgroundColor3 = GREEN
			else
				row.Claim.Text = "+" .. formatNumber(milestone.Reward) .. extra
				row.Claim.BackgroundColor3 = BLUE
			end
		end
	end

	if view == "Weekly" then
		subtitle.Text = "Weekly milestones - resets in " .. weekLeftText(state)
	end

	dailyDot.Visible = dailyClaimable(state)
	weeklyDot.Visible = weeklyClaimable(state)

	local hubButton = questsHubButton()
	local badge = hubButton and hubButton:FindFirstChild("Badge")
	if badge then
		badge.Visible = anythingClaimable(state)
	end
end

local function result(ok, success, reason, doneText)
	if ok and success then
		message.Text = doneText
	elseif ok and reason == "NOT_DONE" then
		message.Text = "Not finished yet - keep rolling!"
	else
		message.Text = "Could not claim right now. Try again!"
	end
end

for index, row in ipairs(rows) do
	row.Claim.Activated:Connect(function()
		local quest = current and current.Quests[index]
		if quest and not quest.Claimed then
			local ok, success, reason = pcall(function()
				return remotes.QuestsClaim:InvokeServer(index)
			end)
			result(ok, success, reason, "Reward claimed!")
		end
	end)

	row.Skip.Activated:Connect(function()
		remotes.QuestSkipPrompt:FireServer(index, "Daily")
		message.Text = "Opening the skip purchase..."
	end)
end

bonusButton.Activated:Connect(function()
	if current and current.AllDone and not current.BonusClaimed then
		local ok, success, reason = pcall(function()
			return remotes.QuestsClaim:InvokeServer(0)
		end)
		result(ok, success, reason, "Bonus claimed! x4 XP is running.")
	end
end)

for index, row in ipairs(weeklyRows) do
	row.Claim.Activated:Connect(function()
		local milestone = current and current.Weekly and current.Weekly[index]
		if milestone and not milestone.Claimed then
			local ok, success, reason = pcall(function()
				return remotes.WeeklyClaim:InvokeServer(index)
			end)
			result(ok, success, reason, "Milestone claimed!")
		end
	end)
end

for index, row in ipairs(weeklyRows) do
	row.Skip.Activated:Connect(function()
		remotes.QuestSkipPrompt:FireServer(index, "Weekly")
		message.Text = "Opening the skip purchase..."
	end)
end

dailyTab.Activated:Connect(function()
	setView("Daily")
end)
weeklyTab.Activated:Connect(function()
	setView("Weekly")
end)

remotes:WaitForChild("QuestsUpdate").OnClientEvent:Connect(render)

PanelManager.Register("Quests", panel, function()
	message.Text = ""
	setView("Daily")
	task.spawn(function()
		local ok, state = pcall(function()
			return remotes.QuestsState:InvokeServer()
		end)
		if ok and state then
			render(state)
		end
	end)
end)

close.Activated:Connect(function()
	PanelManager.Close("Quests")
end)

-- Hook the hub button once HubUI has built it.
task.spawn(function()
	local hub = playerGui:WaitForChild("HubUI", 30)
	if not hub then
		return
	end

	local hubButton
	for _ = 1, 100 do
		hubButton = hub:FindFirstChild("QuestsButton", true)
		if hubButton then
			break
		end
		task.wait(0.1)
	end

	if hubButton then
		hubButton.Activated:Connect(function()
			PanelManager.Toggle("Quests")
		end)
	end
end)

setView("Daily")

-- Fill the notification dots / hub badge right after joining, not only once
-- the panel is opened.
task.spawn(function()
	local ok, state = pcall(function()
		return remotes.QuestsState:InvokeServer()
	end)
	if ok and state then
		render(state)
	end
end)
