--------------------------------------------------
-- FEEDBACK PANEL (client)
--
-- Opens from the lobby mailbox prompt. It only collects text; the server
-- validates, filters and saves it. "Sent" is shown ONLY after the server
-- answers true (so a failed save is never reported as success).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local FONT = Enum.Font.FredokaOne

local REASONS = {
	TOO_SHORT = "Write a little more (at least 5 characters).",
	TOO_LONG = "That is too long (max 400 characters).",
	COOLDOWN = "Please wait a bit before sending another one.",
	LIMIT = "You have sent a lot of feedback this session. Thank you!",
	FILTER_FAILED = "Could not check the text right now. Try again.",
	SAVE_FAILED = "Could not save it right now. Try again later.",
	BUSY = "Still sending...",
	INVALID = "Something went wrong. Try again.",
}

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("FeedbackUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", { Name = "FeedbackUI", ResetOnSpawn = false, DisplayOrder = 24 }, playerGui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 360),
	BackgroundColor3 = Color3.fromRGB(46, 36, 96),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
create("UIStroke", { Color = INK, Thickness = 5 }, panel)

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local l = create("TextLabel", props, panel)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, l)
	return l
end

label({
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -70, 0, 38),
	Text = "FEEDBACKS",
	TextColor3 = Color3.fromRGB(255, 226, 90),
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
})
label({
	Position = UDim2.fromOffset(16, 48),
	Size = UDim2.new(1, -32, 0, 22),
	Text = "Tell us what to fix or add!",
	TextColor3 = CREAM,
	TextSize = 15,
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

local box = create("TextBox", {
	Position = UDim2.fromOffset(16, 80),
	Size = UDim2.new(1, -32, 0, 170),
	BackgroundColor3 = CREAM,
	Font = Enum.Font.GothamMedium,
	Text = "",
	PlaceholderText = "Type your feedback here...",
	TextColor3 = INK,
	PlaceholderColor3 = Color3.fromRGB(130, 120, 140),
	TextSize = 16,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ClearTextOnFocus = false,
	MultiLine = true,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, box)
create("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, box)

local counter = label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 254),
	Size = UDim2.fromOffset(120, 18),
	Text = "0 / 400",
	TextColor3 = CREAM,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
})

local send = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 278),
	Size = UDim2.fromOffset(240, 46),
	BackgroundColor3 = GREEN,
	Font = FONT,
	Text = "SEND FEEDBACK",
	TextColor3 = CREAM,
	TextSize = 22,
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, send)
create("UIStroke", { Color = INK, Thickness = 3 }, send)
Shine.Attach(send, { Offset = 0 })

local message = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 328),
	Size = UDim2.new(1, -24, 0, 22),
	Text = "",
	TextColor3 = Color3.fromRGB(190, 255, 200),
	TextSize = 14,
})

box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > 400 then
		box.Text = string.sub(box.Text, 1, 400)
	end
	counter.Text = #box.Text .. " / 400"
end)

local sending = false

send.Activated:Connect(function()
	if sending then
		return
	end
	sending = true
	send.Text = "SENDING..."
	message.Text = ""

	local ok, success, reason = pcall(function()
		return remotes.FeedbackSubmit:InvokeServer(box.Text)
	end)

	if ok and success then
		message.TextColor3 = Color3.fromRGB(190, 255, 200)
		message.Text = "Thank you! Your feedback was sent."
		box.Text = ""
	else
		message.TextColor3 = Color3.fromRGB(255, 140, 140)
		message.Text = REASONS[reason] or "Could not send it. Try again later."
	end

	send.Text = "SEND FEEDBACK"
	sending = false
end)

PanelManager.Register("Feedback", panel, function()
	message.Text = ""
end)

close.Activated:Connect(function()
	PanelManager.Close("Feedback")
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who == player and prompt.Name == "FeedbackPrompt" then
		PanelManager.Toggle("Feedback")
	end
end)
