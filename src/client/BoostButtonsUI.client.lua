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
	Position = UDim2.new(1, -12, 0.5, 40),
	Size = UDim2.fromOffset(128, 180),
	BackgroundTransparency = 1,
}, gui)
create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, column)

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
			Size = UDim2.fromOffset(128, 76),
			BackgroundTransparency = 1,
		}, column)

		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 50),
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
			TextSize = 24,
		}, button)
		create("UIStroke", { Color = INK, Thickness = 2.5 }, label)

		local price = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 0, 22),
			Font = FONT,
			Text = "R$ " .. boost.PriceRobux .. " ONLY!",
			TextColor3 = Color3.fromRGB(255, 240, 120),
			TextSize = 15,
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
				entry.Price.Text = "R$ " .. entry.Rate .. " ONLY!"
			end
		end
		task.wait(0.5)
	end
end)

-- Friend bonus (+10% XP per friend in the server, computed by the server).
local friendLabel = create("TextLabel", {
	LayoutOrder = 10,
	Size = UDim2.fromOffset(128, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(150, 255, 190),
	TextSize = 14,
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
