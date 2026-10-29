--------------------------------------------------
-- CHAT BUBBLES (client, visual)
--
-- Roblox's default bubbles hang on the hidden character and are depth tested,
-- so balls rolling past (or the player's own ball and its accessories) covered
-- them. These bubbles are drawn ALWAYS ON TOP, sit above the ball's name tag and
-- follow the ball. The text is the filtered chat text Roblox delivers to this
-- client (TextChatService.MessageReceived), so nothing unfiltered is shown.
-- The normal chat window is untouched.
--------------------------------------------------

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

-- the name tags live on invisible anchor parts that follow each ball (BallNameTags);
-- the bubble hangs on the same anchor, so it moves with the tag and never lags the ball
local tagFolder = workspace:WaitForChild("BallNameTags")

local SHOW_SECONDS = 7
local FADE_SECONDS = 0.4
local MAX_LENGTH = 120

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 42)

local bubbles = {} -- [userId] = { Gui, Token }

-- the default bubbles are replaced by these
task.spawn(function()
	local config = TextChatService:WaitForChild("BubbleChatConfiguration", 10)
	if config then
		config.Enabled = false
	end
end)

local function anchorOf(player)
	return tagFolder:FindFirstChild("Tag_" .. player.UserId)
end

local function remove(userId)
	local entry = bubbles[userId]
	if entry then
		entry.Gui:Destroy()
		bubbles[userId] = nil
	end
end

local function show(player, text)
	local anchor = anchorOf(player)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end

	if #text > MAX_LENGTH then
		text = text:sub(1, MAX_LENGTH - 1) .. "…"
	end

	remove(player.UserId)

	-- hangs on the name tag anchor, with the bubble one gap above the tag
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChatBubble_" .. player.UserId
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(280, 150)
	gui.SizeOffset = Vector2.new(0, 0.5) -- the gui's bottom edge sits on the anchor
	gui.Parent = anchor

	local bubble = Instance.new("Frame")
	bubble.AnchorPoint = Vector2.new(0.5, 1)
	bubble.Position = UDim2.new(0.5, 0, 1, -26) -- clear of the name tag
	bubble.AutomaticSize = Enum.AutomaticSize.XY
	bubble.Size = UDim2.fromOffset(0, 0)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 249, 235)
	bubble.Parent = gui
	Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 7)
	padding.PaddingBottom = UDim.new(0, 7)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = bubble
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(260, 140)
	limit.Parent = bubble

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.Font = FONT
	label.TextSize = 18
	label.TextColor3 = INK
	label.TextWrapped = true
	label.RichText = false
	label.Text = text
	label.Parent = bubble
	local labelLimit = Instance.new("UISizeConstraint")
	labelLimit.MaxSize = Vector2.new(236, 126)
	labelLimit.Parent = label

	-- small pop in
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = bubble
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local entry = { Gui = gui, Bubble = bubble }
	bubbles[player.UserId] = entry

	task.delay(SHOW_SECONDS, function()
		if bubbles[player.UserId] ~= entry then
			return
		end
		local info = TweenInfo.new(FADE_SECONDS)
		TweenService:Create(bubble, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		task.delay(FADE_SECONDS, function()
			if bubbles[player.UserId] == entry then
				remove(player.UserId)
			end
		end)
	end)
end

TextChatService.MessageReceived:Connect(function(message)
	local source = message.TextSource
	if not source or message.Status ~= Enum.TextChatMessageStatus.Success then
		return
	end

	local player = Players:GetPlayerByUserId(source.UserId)
	if player and message.Text ~= "" then
		show(player, message.Text)
	end
end)

-- like the name tags: no bubble over a ball that is on a course
game:GetService("RunService").RenderStepped:Connect(function()
	for userId, entry in pairs(bubbles) do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			remove(userId)
		else
			local state = player:GetAttribute("RunState")
			entry.Gui.Enabled = state == nil or state == "" or state == "Waiting"
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	remove(player.UserId)
end)
