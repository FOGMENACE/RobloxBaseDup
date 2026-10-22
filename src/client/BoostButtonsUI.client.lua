--------------------------------------------------
-- BOOST BUTTONS (right edge)
--
-- x2 WINS sits above x2 OIL, each with "R$ 4 ONLY!" underneath. Clicking
-- only asks the server to open the purchase prompt; the server owns the
-- product id and the grant. While a boost runs the button shows the time
-- left (BoostOilUntil / BoostWinsUntil attributes, set by BoostService).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BoostConfig = require(ReplicatedStorage:WaitForChild("BoostConfig"))
local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local boostPrompt = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostPrompt")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("BoostButtonsUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "BoostButtonsUI",
	ResetOnSpawn = false,
	DisplayOrder = 4,
}, playerGui)

local column = create("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, -30),
	Size = UDim2.fromOffset(160, 0),
	AutomaticSize = Enum.AutomaticSize.Y, -- grows when the Captain tile shows
	BackgroundTransparency = 1,
}, gui)
local columnLayout = create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, column)

-- Big on large screens, but it must stay clear of the Music / camera-zoom /
-- jump buttons stacked in the bottom-right (their top edge is 266 px above the
-- bottom), so it shrinks on short screens.
local columnScale = Instance.new("UIScale")
columnScale.Parent = column
local function fitColumn()
	local h = gui.AbsoluteSize.Y
	-- AbsoluteContentSize includes the UIScale, so divide it out; and only touch
	-- the scale when it really changes (setting it re-fires this signal)
	local content = math.max(columnLayout.AbsoluteContentSize.Y / math.max(columnScale.Scale, 0.01), 220)
	if h < 520 then
		-- phone-height screens: tuck it into the top-right corner, above the
		-- Music / zoom buttons
		column.AnchorPoint = Vector2.new(1, 0)
		column.Position = UDim2.new(1, -12, 0, 8)
		local s = math.clamp((h - 266 - 16) / content, 0.4, 0.55)
		if math.abs(s - columnScale.Scale) > 0.005 then columnScale.Scale = s end
	else
		column.AnchorPoint = Vector2.new(1, 0.5)
		column.Position = UDim2.new(1, -12, 0.5, -30)
		local s = math.clamp((h / 2 - 244) / (content / 2), 0.55, 1.15)
		if math.abs(s - columnScale.Scale) > 0.005 then columnScale.Scale = s end
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitColumn)
columnLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitColumn)
fitColumn()
local STYLES = {
	Wins2x = { Order = 1, Top = Color3.fromRGB(255, 214, 60), Bottom = Color3.fromRGB(255, 130, 30), Attr = "BoostWinsUntil" },
	Oil2x = { Order = 2, Top = Color3.fromRGB(90, 90, 110), Bottom = Color3.fromRGB(30, 30, 44), Attr = "BoostOilUntil" },
}

local entries = {}

for key, style in pairs(STYLES) do
	local boost = BoostConfig.Boosts[key]
	if boost and boost.ProductId ~= 0 then
		local holder = create("Frame", {
			LayoutOrder = style.Order,
			Size = UDim2.fromOffset(160, 96),
			BackgroundTransparency = 1,
		}, column)

		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			AutoButtonColor = false,
		}, holder)
		create("UICorner", { CornerRadius = UDim.new(0, 14) }, button)
		create("UIStroke", { Color = INK, Thickness = 3 }, button)
		create("UIGradient", { Color = ColorSequence.new(style.Top, style.Bottom), Rotation = 90 }, button)
		local scale = create("UIScale", { Scale = 1 }, button)

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = FONT,
			Text = boost.Label,
			TextColor3 = CREAM,
			TextSize = 30,
		}, button)
		create("UIStroke", { Color = INK, Thickness = 2.5 }, label)


		local price = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 64),
			Size = UDim2.new(1, 0, 0, 28),
			Font = FONT,
			Text = " " .. boost.PriceRobux .. " ONLY!",
			TextColor3 = Color3.fromRGB(255, 240, 120),
			TextSize = 19,
		}, holder)
		create("UIStroke", { Color = INK, Thickness = 2 }, price)

		Shine.Attach(button, { Offset = style.Order * 1.3 })

		button.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		button.Activated:Connect(function()
			scale.Scale = 0.94
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			boostPrompt:FireServer(key)
		end)

		entries[key] = { Label = label, Price = price, Attr = style.Attr, Name = boost.Label, Rate = boost.PriceRobux }
	end
end

-- CAPTAIN x3 timer tile: shown only while the Captain pack's boost is active
-- (granted to the buyer and the whole server). Not a button: it cannot be
-- bought on its own.
local captainTile = create("Frame", {
	LayoutOrder = 5,
	Size = UDim2.fromOffset(160, 62),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, column)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, captainTile)
create("UIStroke", { Color = INK, Thickness = 3 }, captainTile)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 120, 30)),
	Rotation = 90,
}, captainTile)
local captainTitleLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 28),
	Font = FONT,
	Text = "CAPTAIN x3",
	TextColor3 = CREAM,
	TextSize = 24,
}, captainTile)
create("UIStroke", { Color = INK, Thickness = 2.5 }, captainTitleLabel)
local captainTimeLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 26),
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 22,
}, captainTile)
create("UIStroke", { Color = INK, Thickness = 2.5 }, captainTimeLabel)
Shine.Attach(captainTile, { Offset = 0.4 })

-- x4 XP timer tile (the "WAIT! Don't Leave!" gift and quest rewards): shown while
-- the boost runs, counting down to when it ends
local xpTile = create("Frame", {
	LayoutOrder = 6,
	Size = UDim2.fromOffset(160, 62),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, column)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, xpTile)
create("UIStroke", { Color = INK, Thickness = 3 }, xpTile)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 130, 230), Color3.fromRGB(130, 80, 255)),
	Rotation = 90,
}, xpTile)
local xpTitleLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 28),
	Font = FONT,
	Text = "x4 XP",
	TextColor3 = CREAM,
	TextSize = 24,
}, xpTile)
create("UIStroke", { Color = INK, Thickness = 2.5 }, xpTitleLabel)
local xpTimeLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 26),
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 22,
}, xpTile)
create("UIStroke", { Color = INK, Thickness = 2.5 }, xpTimeLabel)
Shine.Attach(xpTile, { Offset = 0.7 })

local function refreshXPTile()
	local left = math.ceil((player:GetAttribute("BoostXPUntil") or 0) - workspace:GetServerTimeNow())
	xpTile.Visible = left > 0
	if left > 0 then
		xpTimeLabel.Text = string.format("%d:%02d", left // 60, left % 60)
	end
end
player:GetAttributeChangedSignal("BoostXPUntil"):Connect(refreshXPTile)
refreshXPTile()

local function refreshCaptainTile()
	local left = (player:GetAttribute("BoostCaptainUntil") or 0) - os.time()
	captainTile.Visible = left > 0
	if left > 0 then
		captainTimeLabel.Text = string.format("%d:%02d", left // 60, left % 60)
	end
end
player:GetAttributeChangedSignal("BoostCaptainUntil"):Connect(refreshCaptainTile)
refreshCaptainTile()
task.spawn(function()
	while true do
		for _, entry in pairs(entries) do
			local untilTime = player:GetAttribute(entry.Attr) or 0
			local left = untilTime - os.time()
			if left > 0 then
				entry.Label.Text = string.format("%d:%02d", left // 60, left % 60)
				entry.Price.Text = entry.Name .. " ACTIVE"
			else
				entry.Label.Text = entry.Name
				entry.Price.Text = " " .. entry.Rate .. " ONLY!"
			end
		end
		refreshCaptainTile()
		refreshXPTile()
		task.wait(0.5)
	end
end)

-- Friend bonus (+10% XP per friend in the server, computed by the server).
local friendLabel = create("TextLabel", {
	LayoutOrder = 10,
	Size = UDim2.fromOffset(160, 28),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(150, 255, 190),
	TextSize = 17,
	Visible = false,
}, column)
create("UIStroke", { Color = INK, Thickness = 2 }, friendLabel)

local function refreshFriends()
	local pct = player:GetAttribute("FriendBonusPct") or 0
	friendLabel.Visible = pct > 0
	friendLabel.Text = "FRIENDS +" .. math.floor(pct) .. "% XP"
end
player:GetAttributeChangedSignal("FriendBonusPct"):Connect(refreshFriends)
refreshFriends()
