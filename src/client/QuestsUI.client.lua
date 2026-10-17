--------------------------------------------------
-- DAILY QUESTS PANEL (client)
--
-- Opened from the hub's QUESTS button (HubUI). Everything shown comes from
-- the server (QuestService): titles, progress, rewards and the claim
-- result. The client never reports progress or decides a reward.
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
	Size = UDim2.fromOffset(460, 430),
	BackgroundColor3 = Color3.fromRGB(46, 36, 96),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
create("UIStroke", { Color = INK, Thickness = 5 }, panel)
local scale = create("UIScale", { Scale = 1 }, panel)

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local l = create("TextLabel", props, parent or panel)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, l)
	return l
end

label({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 38),
	Text = "DAILY QUESTS",
	TextColor3 = Color3.fromRGB(255, 226, 90),
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(235, 70, 70),
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, close)
create("UIStroke", { Color = INK, Thickness = 3 }, close)

label({
	Position = UDim2.fromOffset(16, 46),
	Size = UDim2.new(1, -32, 0, 20),
	Text = "New quests every day. Finish all 3 for a bonus!",
	TextColor3 = CREAM,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local rows = {}

for index = 1, 3 do
	local row = create("Frame", {
		Position = UDim2.fromOffset(16, 76 + (index - 1) * 82),
		Size = UDim2.new(1, -32, 0, 74),
		BackgroundColor3 = Color3.fromRGB(30, 24, 66),
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, row)

	local title = label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 24),
		Text = "...",
		TextColor3 = CREAM,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local track = create("Frame", {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(1, -150, 0, 20),
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

	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(112, 52),
		BackgroundColor3 = GREY,
		Font = FONT,
		Text = "",
		TextColor3 = CREAM,
		TextSize = 15,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, button)
	create("UIStroke", { Color = INK, Thickness = 3 }, button)
	Shine.Attach(button, { Offset = index })

	rows[index] = { Title = title, Fill = fill, Progress = progress, Button = button }
end

local bonusButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 330),
	Size = UDim2.fromOffset(400, 56),
	BackgroundColor3 = GREY,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, bonusButton)
create("UIStroke", { Color = INK, Thickness = 3 }, bonusButton)

local message = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 394),
	Size = UDim2.new(1, -24, 0, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(190, 255, 200),
	TextSize = 14,
})

--------------------------------------------------
-- STATE
--------------------------------------------------

local current = nil

-- The hub button lives in HubUI; find it and mirror a "!" when claimable.
local function questsHubButton()
	local hub = playerGui:FindFirstChild("HubUI")
	return hub and hub:FindFirstChild("QuestsButton", true)
end

local function anythingClaimable(state)
	for _, quest in ipairs(state.Quests) do
		if not quest.Claimed and quest.Progress >= quest.Target then
			return true
		end
	end
	return state.AllDone and not state.BonusClaimed
end

local function render(state)
	current = state

	for index, row in ipairs(rows) do
		local quest = state.Quests[index]
		if quest then
			row.Title.Text = quest.Title
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Target, 0, 1), 1)
			row.Progress.Text = formatNumber(quest.Progress) .. " / " .. formatNumber(quest.Target)

			if quest.Claimed then
				row.Button.Text = "DONE"
				row.Button.BackgroundColor3 = GREY
			elseif quest.Progress >= quest.Target then
				row.Button.Text = "CLAIM\n+" .. formatNumber(quest.Reward)
				row.Button.BackgroundColor3 = GREEN
			else
				row.Button.Text = "+" .. formatNumber(quest.Reward) .. "\nWINS"
				row.Button.BackgroundColor3 = Color3.fromRGB(86, 84, 130)
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
		bonusButton.BackgroundColor3 = Color3.fromRGB(86, 84, 130)
	end

	local hubButton = questsHubButton()
	local badge = hubButton and hubButton:FindFirstChild("Badge")
	if badge then
		badge.Visible = anythingClaimable(state)
	end
end

local function claim(index)
	local ok, success, reason = pcall(function()
		return remotes.QuestsClaim:InvokeServer(index)
	end)

	if ok and success then
		message.Text = index == 0 and "Bonus claimed! x4 XP is running." or "Reward claimed!"
	elseif ok and reason == "NOT_DONE" then
		message.Text = "Not finished yet - keep rolling!"
	else
		message.Text = "Could not claim right now. Try again!"
	end
end

for index, row in ipairs(rows) do
	row.Button.Activated:Connect(function()
		if current and current.Quests[index] and not current.Quests[index].Claimed then
			claim(index)
		end
	end)
end

bonusButton.Activated:Connect(function()
	if current and current.AllDone and not current.BonusClaimed then
		claim(0)
	end
end)

remotes:WaitForChild("QuestsUpdate").OnClientEvent:Connect(render)

PanelManager.Register("Quests", panel, function()
	message.Text = ""
	task.spawn(function()
		local ok, state = pcall(function()
			return remotes.QuestsState:InvokeServer()
		end)
		if ok and state then
			render(state)
		end
	end)
end)

local function setOpen(open)
	if open then
		PanelManager.Open("Quests")
	else
		PanelManager.Close("Quests")
	end
end

close.Activated:Connect(function()
	setOpen(false)
end)

-- Hook the hub button once HubUI has built it.
task.spawn(function()
	local hub = playerGui:WaitForChild("HubUI", 30)
	if not hub then
		return
	end

	local button
	for _ = 1, 100 do
		button = hub:FindFirstChild("QuestsButton", true)
		if button then
			break
		end
		task.wait(0.1)
	end

	if button then
		button.Activated:Connect(function()
			PanelManager.Toggle("Quests")
		end)
	end
end)
