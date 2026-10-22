--------------------------------------------------
-- BALL SHOP UI
--
-- CLIENT ONLY. A vertical list of balls. Each card shows:
--   * a spinning 3D preview (ViewportFrame from ReplicatedStorage.BallModels)
--   * the name and what it needs
--   * a WINS button, with the ROBUX button directly under it
--     (owned balls show a single EQUIP button instead)
--
-- Everything shown comes from the server:
--   Remotes.BallShopState (RemoteFunction) -> ball list + ownership
--   Remotes.BallShop (RemoteEvent)         -> BuyWithWins / BuyWithRobux /
--                                             Equip requests, and the
--                                             PurchaseResult / EquipResult
--                                             answers
-- The client only sends a ball id. The server validates ownership,
-- price, rebirths and rate limits, and picks the Developer Product.
-- Success is only ever shown after the server says so.
--
-- Opened by Remotes.OpenBowlingShop (fired when the player's ball
-- rolls onto the shop pad). Replaces the old StarterGui.BowlingShopGui.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ballShop = remotes:WaitForChild("BallShop")
local ballShopState = remotes:WaitForChild("BallShopState")
local openShop = remotes:WaitForChild("OpenBowlingShop")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local WorldSkinStyle = require(ReplicatedStorage:WaitForChild("WorldSkinStyle"))
local skinShop = remotes:WaitForChild("SkinShop")
local worldTeleport = remotes:WaitForChild("WorldTeleport")
local expanded = {} -- [ballId] = true while its SKINS list is open
local refresh, setOpen, buildSkins -- defined below

--------------------------------------------------
-- STYLE (same family as HubUI)
--------------------------------------------------

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GREEN = Color3.fromRGB(88, 196, 110)
local GREY = Color3.fromRGB(170, 160, 150)
local ROBUX = Color3.fromRGB(70, 160, 235)
local FONT = Enum.Font.FredokaOne

local REASONS = {
	PURCHASED = "Purchased!",
	NOT_ENOUGH_WINS = "Not enough Wins yet.",
	ALREADY_OWNED = "You already own this ball.",
	NOT_OWNED = "You don't own that ball.",
	INVALID_BALL = "That ball isn't available.",
	REBIRTH_REQUIRED = "Needs more rebirths.",
	PURCHASE_BUSY = "One moment...",
	DATA_NOT_LOADED = "Your data is still loading.",
	PROMPTED = "Opening Robux purchase...",
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

local function outline(inst, thickness)
	create("UIStroke", { Color = INK, Thickness = thickness }, inst)
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fK", value / 1e3)
	end

	-- 1,234 style thousands separators for small numbers.
	local text = tostring(value)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

--------------------------------------------------
-- ROOT
--------------------------------------------------

local old = playerGui:FindFirstChild("BallShopUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "BallShopUI",
	ResetOnSpawn = false,
	DisplayOrder = 12,
	Enabled = false,
}, playerGui)

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(470, 560),
	BackgroundColor3 = LANE,
}, gui)
round(panel, 18)
outline(panel, 4)
local panelScale = create("UIScale", { Scale = 1 }, panel)

local function updateScale()
	local viewport = gui.AbsoluteSize
	panelScale.Scale = math.clamp(math.min(viewport.X / 520, viewport.Y / 620), 0.55, 1.1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
updateScale()

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.fromOffset(220, 36),
	Font = FONT,
	Text = "BALL SHOP",
	TextColor3 = CREAM,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
create("UIStroke", { Color = INK, Thickness = 3 }, title)

local slogan = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 44),
	Size = UDim2.fromOffset(300, 18),
	Font = FONT,
	Text = "ROLL IN. ROLL UP. ROLL RICH!",
	TextColor3 = Color3.fromRGB(255, 226, 120),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
create("UIStroke", { Color = INK, Thickness = 2 }, slogan)

local winsPill = create("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -62, 0, 12),
	Size = UDim2.fromOffset(150, 34),
	BackgroundColor3 = CREAM,
}, panel)
round(winsPill, 10)
outline(winsPill, 3)

local winsLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	Text = "0 WINS",
	TextColor3 = INK,
	TextSize = 18,
}, winsPill)

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = PIN_RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
round(closeButton, 10)
outline(closeButton, 3)

local list = create("ScrollingFrame", {
	Name = "List",
	BackgroundColor3 = CREAM,
	BackgroundTransparency = 0.15,
	Position = UDim2.fromOffset(12, 58),
	Size = UDim2.new(1, -24, 0, 388),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	BorderSizePixel = 0,
}, panel)
round(list, 12)
create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)
create("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, list)

local statusLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 452),
	Size = UDim2.new(1, -24, 0, 30),
	BackgroundColor3 = INK,
	Font = FONT,
	Text = "Roll onto the pad any time to shop.",
	TextColor3 = CREAM,
	TextSize = 16,
}, panel)
round(statusLabel, 10)

local statusToken = 0
local function setStatus(text)
	statusToken += 1
	local token = statusToken
	statusLabel.Text = text

	task.delay(3, function()
		if token == statusToken then
			statusLabel.Text = "Roll onto the pad any time to shop."
		end
	end)
end

--------------------------------------------------
-- 3D PREVIEW
--------------------------------------------------

local ballModels = ReplicatedStorage:FindFirstChild("BallModels")
local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))
local spinners = {}
local shines = {} -- Robux button shine frames (animated by the loop below)

RunService.RenderStepped:Connect(function(deltaTime)
	if not gui.Enabled then
		return
	end

	for index = #spinners, 1, -1 do
		local model = spinners[index]
		if model.Parent then
			model.CFrame = model.CFrame * CFrame.Angles(0, deltaTime * 1.2, 0)
			BallAccessories.Pose(model, os.clock())
		else
			table.remove(spinners, index)
		end
	end

	-- Shine: a 1 second sweep every 5 seconds, staggered per button.
	local now = os.clock()
	for _, entry in ipairs(shines) do
		if entry.Frame.Parent then
			local t = (now + entry.Offset) % 5
			entry.Frame.Position = UDim2.fromScale(t < 1 and (-0.3 + t * 1.6) or -0.3, 0.5)
		end
	end
end)

local function addPreview(holder, ballId, zIndex)
	local template = ballModels and ballModels:FindFirstChild(ballId)
	if not template and BallAccessories.HasDesign(ballId) then
		-- designs without a BallModels mesh (Oil Barrel) get a plain sphere
		template = Instance.new("Part")
		template.Shape = Enum.PartType.Ball
		template.Size = Vector3.new(2.8, 2.8, 2.8)
	end
	if not template then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = FONT,
			Text = "🎳",
			TextSize = 40,
		}, holder)
		return
	end

	local viewport = create("ViewportFrame", {
		BackgroundTransparency = 1,
		ZIndex = zIndex or 1,
		Size = UDim2.fromScale(1, 1),
	}, holder)

	local model = template:Clone()
	model.Anchored = true
	model.CFrame = CFrame.new(0, 0, 0)
	model.Parent = viewport

	-- Premium balls show their unique accessories (cat, spikes, dragon...).
	BallAccessories.Apply(model, ballId)
	-- in a themed world every ball on display wears that world's coating
	local world = WorldConfig.Of(player)
	if world.Theme then
		WorldSkinStyle.Apply(model, world.Theme, false)
	end
	if ballId == "OilBarrel" then
		model:SetAttribute("PreviewSpeed", 12) -- the barrel spins on its own axis
	end
	local hasDesign = BallAccessories.HasDesign(ballId)

	local radius = math.max(model.Size.X, model.Size.Y, model.Size.Z)
	local camera = create("Camera", {
		-- Pull back a little for designs that reach beyond the ball.
		CFrame = CFrame.lookAt(
			Vector3.new(0, hasDesign and radius * 0.5 or 0, radius * (ballId == "OilBarrel" and 2.7 or (hasDesign and 3.3 or 2.2))),
			Vector3.zero
		),
		FieldOfView = 35,
	}, viewport)
	viewport.CurrentCamera = camera

	table.insert(spinners, model)
end

--------------------------------------------------
-- EXCLUSIVE OFFER (floating over the bottom edge of the panel)
--
-- The Oil Barrel is only sold for Robux (Game Pass), so it is not a card
-- in the list. While the player does not own it, a hovering 3D barrel with
-- its price pokes out below the panel (no background frame).
--------------------------------------------------

local ExclusiveOffer = require(ReplicatedStorage:WaitForChild("ExclusiveOffer"))

local barrelOffer = ExclusiveOffer.Create(panel, {
	BallId = "OilBarrel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 62),
	Size = UDim2.fromOffset(430, 124),
	ZIndex = 40,
})

local function updateBanner(balls)
	local owned = false
	for _, ball in ipairs(balls) do
		if ball.BallId == "OilBarrel" then
			owned = ball.Owned == true
		end
	end

	-- hidden once the ball is owned (pass, Captain pack or calendar reward)
	barrelOffer.Frame.Visible = not owned and not ExclusiveOffer.OwnsPass(barrelOffer.Entry.PassId)
end

--------------------------------------------------
-- CARDS
--------------------------------------------------

local function makeButton(parent, order, text, color, enabled)
	local button = create("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = enabled and color or GREY,
		Font = FONT,
		Text = text,
		TextColor3 = CREAM,
		TextSize = 14,
		AutoButtonColor = enabled,
		Active = enabled,
	}, parent)
	round(button, 10)
	outline(button, 2)
	create("UIStroke", {
		Color = INK,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, button)
	return button
end

local function request(action, ballId)
	ballShop:FireServer(action, ballId)
end

--------------------------------------------------
-- "GET THE ORIGINAL FIRST" POPUP (themed worlds)
--------------------------------------------------

local popup, popupBall = nil, nil

local function closePopup()
	if popup then
		popup:Destroy()
	end
	popup, popupBall = nil, nil
end

local function showOriginalPopup(ball, wins, rebirths)
	closePopup()
	popupBall = ball.BallId
	-- full-screen container (covers the top bar too); the dim and the box are SIBLINGS
	-- so the dim can never sit over the popup or swallow its clicks
	local inset = game:GetService("GuiService"):GetGuiInset()
	popup = create("Frame", {
		Name = "OriginalPopup",
		Position = UDim2.fromOffset(0, -inset.Y),
		Size = UDim2.new(1, 0, 1, inset.Y),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, gui)
	local dim = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 50,
	}, popup)
	dim.Activated:Connect(closePopup)

	local box = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CREAM,
		Active = true, -- clicks on the box must not reach the dim behind it
		ZIndex = 51,
	}, popup)
	round(box, 14)
	outline(box, 3)
	create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, box)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, box)

	create("TextLabel", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = FONT,
		Text = "GET THE ORIGINAL FIRST",
		TextColor3 = INK,
		TextSize = 20,
	}, box)
	create("TextLabel", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = FONT,
		Text = string.upper(ball.DisplayName or ball.BallId) .. "\nneeded to buy its evolved ball.",
		TextColor3 = Color3.fromRGB(110, 70, 30),
		TextSize = 14,
		TextWrapped = true,
	}, box)

	local locked = (ball.RequiredRebirths or 0) > rebirths
	local affordable = wins >= (ball.WinsCost or 0)
	local winsButton = makeButton(
		box, 3,
		locked and ("🔒 REBIRTH " .. ball.RequiredRebirths) or (formatNumber(ball.WinsCost or 0) .. " WINS"),
		LANE, (not locked) and affordable
	)
	winsButton.Size = UDim2.new(1, 0, 0, 38)
	winsButton.Activated:Connect(function()
		if locked then
			return
		elseif affordable then
			request("BuyWithWins", ball.BallId)
		else
			setStatus("You need " .. formatNumber((ball.WinsCost or 0) - wins) .. " more Wins.")
		end
	end)

	if ball.HasDeveloperProduct and not ball.IsTutorial then
		local price = ShopConfig.RobuxPrices[ball.BallId]
		local robux = makeButton(box, 4, price and (" " .. price) or " BUY", ROBUX, true)
		robux.Size = UDim2.new(1, 0, 0, 38)
		robux.Activated:Connect(function()
			closePopup()
			request("BuyWithRobux", ball.BallId)
		end)
	end

	local close = makeButton(box, 5, "CLOSE", GREY, true)
	close.Activated:Connect(closePopup)

	for _, d in ipairs(box:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 52
		end
	end
end
--------------------------------------------------
-- EVOLVED SKINS (collapsible list under every ball)
--------------------------------------------------

local function skinButton(parent, text, color, enabled)
	local b = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = color,
		Font = FONT,
		Text = text,
		TextColor3 = CREAM,
		TextSize = 14,
		TextWrapped = true,
		AutoButtonColor = enabled,
	}, parent)
	round(b, 8)
	outline(b, 2)
	if not enabled then
		b.BackgroundTransparency = 0.25
	end
	return b
end

buildSkins = function(card, ball, wins, rebirths)
	local open = expanded[ball.BallId] == true
	local toggle = create("TextButton", {
		Position = UDim2.fromOffset(8, 126),
		Size = UDim2.new(1, -16, 0, 20),
		BackgroundColor3 = Color3.fromRGB(46, 38, 96),
		Font = FONT,
		Text = (open and "▾  " or "▸  ") .. "EVOLVED SKINS  (" .. (#WorldConfig.Worlds - 1) .. ")",
		TextColor3 = Color3.fromRGB(255, 226, 120),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	round(toggle, 6)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10) }, toggle)
	toggle.Activated:Connect(function()
		expanded[ball.BallId] = not expanded[ball.BallId] or nil
		refresh()
	end)
	if not open then
		return
	end

	local here = player:GetAttribute("World") or 1
	local ownsOriginal = ball.Owned == true
	local box = create("Frame", {
		Name = ball.BallId .. "_Skins",
		LayoutOrder = (ball.DisplayOrder or 0) * 10 + 1,
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(34, 28, 74),
	}, list)
	round(box, 10)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, box)
	create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, box)

	-- the rule, stated clearly (not a small hidden note)
	if not ownsOriginal then
		local warn = create("TextLabel", {
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(215, 45, 55),
			Font = FONT,
			Text = "OWN THE ORIGINAL FIRST TO BUY SKINS WITH WINS",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 15,
			TextWrapped = true,
		}, box)
		round(warn, 8)
		outline(warn, 2)
	end

	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Theme then
			local key = WorldConfig.SkinKey(ball.BallId, world.Id)
			local row = create("Frame", {
				LayoutOrder = world.Id,
				Size = UDim2.new(1, 0, 0, 50),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			}, box)
			round(row, 8)
			create("UIGradient", { Rotation = 0, Color = ColorSequence.new(world.Theme.Wrap, world.Theme.Primary) }, row)
			create("Frame", {
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = world.Theme.Wrap,
			}, row)
			round(row:FindFirstChildOfClass("Frame"), 15)
			local cost = WorldConfig.SkinWinsCost(ball.BallId, world.Id, ball.WinsCost) or 0
			local name = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(48, 4),
				Size = UDim2.new(1, -210, 0, 24),
				Font = FONT,
				Text = world.Name .. " SKIN",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, row)
			create("UIStroke", { Color = INK, Thickness = 2 }, name)
			local sub = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(48, 26),
				Size = UDim2.new(1, -210, 0, 20),
				Font = FONT,
				Text = (ball.BallId == "OilBarrel" and "+5 SPEED  •  " or "") .. formatNumber(cost) .. " WINS",
				TextColor3 = Color3.fromRGB(255, 240, 170),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, row)
			create("UIStroke", { Color = INK, Thickness = 1.5 }, sub)

			if WorldConfig.OwnsSkin(player, ball.BallId, world.Id) then
				skinButton(row, "OWNED", GREEN, false)
			elseif not WorldConfig.Unlocked(rebirths, world.Id) then
				skinButton(row, "🔒 UNLOCK IN WORLD: " .. world.Name, Color3.fromRGB(90, 86, 104), false)
			elseif here ~= world.Id then
				local go = skinButton(row, "TELEPORT", ROBUX, true)
				go.Activated:Connect(function()
					player:SetAttribute("PendingSkin", key) -- the shop opens on this skin there
					worldTeleport:FireServer(world.Id)
					setOpen(false)
				end)
			elseif not ownsOriginal then
				skinButton(row, "OWN ORIGINAL FIRST", PIN_RED, false)
			elseif wins >= cost then
				local buy = skinButton(row, "BUY  " .. formatNumber(cost), LANE, true)
				buy.Activated:Connect(function()
					skinShop:FireServer("Buy", ball.BallId, world.Id)
				end)
			else
				local short = skinButton(row, "NEED " .. formatNumber(cost - wins), GREY, true)
				short.Activated:Connect(function()
					setStatus("You need " .. formatNumber(cost - wins) .. " more Wins.")
				end)
			end
		end
	end
end

local function buildCard(ball, wins, rebirths, equippedSpeed, maxSpeed, topPrice, skinWorld)
	local card = create("Frame", {
		Name = ball.BallId,
		LayoutOrder = (ball.DisplayOrder or 0) * 10,
		Size = UDim2.new(1, -4, 0, 152),
		BackgroundColor3 = ball.Equipped and Color3.fromRGB(214, 244, 214) or Color3.fromRGB(255, 255, 255),
	}, list)
	round(card, 12)
	outline(card, 3)

	-- Preview
	local previewHolder = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(235, 225, 205),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(96, 112),
	}, card)
	round(previewHolder, 10)
	addPreview(previewHolder, ball.BallId)

	-- Name + info
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(114, 8),
		Size = UDim2.new(1, -266, 0, 26),
		Font = FONT,
		Text = string.upper(ball.DisplayName or ball.BallId),
		TextColor3 = INK,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	local info = {}
	if skinWorld then
		table.insert(info, "EVOLVED  •  " .. skinWorld.Name)
	end
	if ball.IsTutorial then
		table.insert(info, "Starter ball")
	end

	-- Persuasion that is true: what this ball would change for you.
	if not ball.Equipped and equippedSpeed and equippedSpeed > 0
		and (ball.ForwardSpeed or 0) > equippedSpeed then
		table.insert(info, string.format("+%d%% SPEED", math.floor((ball.ForwardSpeed / equippedSpeed - 1) * 100 + 0.5)))
	end

	if BallAccessories.HasDesign(ball.BallId) then
		table.insert(info, "UNIQUE LOOK")
	end

	local legendary = topPrice and topPrice > 0
		and ShopConfig.RobuxPrices[ball.BallId] == topPrice
	if legendary then
		table.insert(info, "LEGENDARY")
	end
	if (ball.RequiredRebirths or 0) > 0 then
		table.insert(info, "Rebirth " .. ball.RequiredRebirths)
	end
	if ball.Equipped then
		table.insert(info, "Equipped")
	end

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(114, 36),
		Size = UDim2.new(1, -266, 0, 40),
		Font = Enum.Font.Gotham,
		Text = table.concat(info, "  •  "),
		TextColor3 = Color3.fromRGB(110, 70, 30),
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)

	-- Speed bar (relative to the fastest ball in the shop)
	local barTrack = create("Frame", {
		Position = UDim2.fromOffset(114, 94),
		Size = UDim2.new(1, -266, 0, 10),
		BackgroundColor3 = Color3.fromRGB(210, 200, 185),
	}, card)
	round(barTrack, 5)
	create("Frame", {
		Size = UDim2.fromScale(math.clamp((ball.ForwardSpeed or 0) / math.max(maxSpeed or 1, 1), 0.05, 1), 1),
		BackgroundColor3 = GREEN,
	}, barTrack)
	round(barTrack:FindFirstChildOfClass("Frame"), 5)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(114, 102),
		Size = UDim2.new(1, -266, 0, 18),
		Font = FONT,
		Text = tostring(math.floor(ball.ForwardSpeed or 0)) .. " SPEED",
		TextColor3 = Color3.fromRGB(70, 40, 10),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	buildSkins(card, ball, wins, rebirths)

	-- Action column (Wins on top, Robux directly underneath)
	local actions = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(144, 112),
	}, card)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, actions)

	-- THEMED WORLD: each card IS the evolved ball of this world (Wins or Robux)
	if skinWorld then
		local worldId = skinWorld.Id
		local hasSkin = WorldConfig.OwnsSkin(player, ball.BallId, worldId)
		if ball.Owned and hasSkin then
			if ball.Equipped then
				makeButton(actions, 1, "EQUIPPED", GREEN, false)
			else
				local equip = makeButton(actions, 1, "EQUIP", GREEN, true)
				equip.Activated:Connect(function()
					request("Equip", ball.BallId)
				end)
			end
			return
		end

		local cost = WorldConfig.SkinWinsCost(ball.BallId, worldId, ball.WinsCost) or 0
		if not ball.Owned then
			local need = makeButton(actions, 1, "🔒 " .. formatNumber(cost) .. " WINS", LANE, true)
			need.Activated:Connect(function()
				showOriginalPopup(ball, wins, rebirths)
			end)
		elseif wins >= cost then
			local buy = makeButton(actions, 1, formatNumber(cost) .. " WINS", LANE, true)
			buy.Activated:Connect(function()
				skinShop:FireServer("Buy", ball.BallId, worldId)
			end)
		else
			local short = makeButton(actions, 1, formatNumber(cost) .. " WINS", LANE, false)
			short.Activated:Connect(function()
				setStatus("You need " .. formatNumber(cost - wins) .. " more Wins.")
			end)
		end

		local price = WorldConfig.SkinRobuxPrice(ball.BallId, worldId)
		if price and not (ball.BallId == "OilBarrel" and not ball.Owned) then
			local onSale = string.find("," .. tostring(ReplicatedStorage:GetAttribute("SkinSalePrices") or "") .. ",", "," .. price .. ",", 1, true) ~= nil
			-- always show the price; until its Developer Product exists the button just says so when pressed
			local robux = makeButton(actions, 2, " " .. price, ROBUX, true)
			robux.Activated:Connect(function()
				if onSale then
					skinShop:FireServer("BuyRobux", ball.BallId, worldId)
				else
					setStatus("Robux R$" .. price .. " opens soon.")
				end
			end)
		end
		return
	end

	if ball.Owned then
		if ball.Equipped then
			makeButton(actions, 1, "EQUIPPED", GREEN, false)
		else
			local equip = makeButton(actions, 1, "EQUIP", GREEN, true)
			equip.Activated:Connect(function()
				request("Equip", ball.BallId)
			end)
		end
		return
	end

	-- WINS button
	local locked = (ball.RequiredRebirths or 0) > rebirths
	local affordable = wins >= (ball.WinsCost or 0)

	local winsText
	if locked then
		winsText = "🔒 REBIRTH " .. ball.RequiredRebirths
	else
		winsText = formatNumber(ball.WinsCost) .. " WINS"
	end

	local winsButton = makeButton(
		actions,
		1,
		winsText,
		LANE,
		(not locked) and affordable
	)
	if (not locked) and affordable then
		winsButton.Activated:Connect(function()
			request("BuyWithWins", ball.BallId)
		end)
	elseif not locked then
		winsButton.Activated:Connect(function()
			setStatus("You need " .. formatNumber(ball.WinsCost - wins) .. " more Wins.")
		end)
	end

	-- ROBUX button, directly under the Wins button
	if ball.HasDeveloperProduct and not ball.IsTutorial then
		local price = ShopConfig.RobuxPrices[ball.BallId]
		local robuxButton = makeButton(
			actions,
			2,
			price and (" " .. price) or " BUY",
			ROBUX,
			true
		)
		robuxButton.Activated:Connect(function()
			request("BuyWithRobux", ball.BallId)
		end)

		-- A soft shine sweeps across the Robux button every few seconds.
		robuxButton.ClipsDescendants = true
		local shine = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 22, 2, 0),
			Rotation = 20,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(-0.3, 0.5),
			ZIndex = 5,
		}, robuxButton)
		table.insert(shines, { Frame = shine, Offset = math.random() * 2 })
	end
end

--------------------------------------------------
-- REFRESH (one rebuild path, no duplicate connections)
--------------------------------------------------

local refreshing = false

refresh = function()
	if refreshing then
		return
	end
	refreshing = true

	local ok, state = pcall(function()
		return ballShopState:InvokeServer()
	end)

	refreshing = false

	if not ok or typeof(state) ~= "table" then
		setStatus("Shop is unavailable right now.")
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinners)

	local wins = state.Wins or player:GetAttribute("Wins") or 0
	local rebirths = state.Rebirths or player:GetAttribute("Rebirths") or 0
	winsLabel.Text = formatNumber(wins) .. " WINS"

	local balls = state.Balls or {}
	table.sort(balls, function(a, b)
		return (a.DisplayOrder or 0) < (b.DisplayOrder or 0)
	end)
	for _, ball in ipairs(balls) do
		if ball.BallId == popupBall and ball.Owned then
			closePopup()
		end
	end

	-- Comparison data for the cards: how fast is the ball you roll now,
	-- what is the fastest ball, and what is the priciest (legendary) one.
	local equippedSpeed, maxSpeed, topPrice = nil, 1, 0

	for _, ball in ipairs(balls) do
		maxSpeed = math.max(maxSpeed, ball.ForwardSpeed or 0)
		if ball.Equipped then
			equippedSpeed = ball.ForwardSpeed
		end
		topPrice = math.max(topPrice, ShopConfig.RobuxPrices[ball.BallId] or 0)
	end

	table.clear(shines)
	updateBanner(balls)

	local world = WorldConfig.Of(player)
	local skinWorld = (world.Id >= 2 and world.Theme) and world or nil

	if skinWorld then
		-- one big, clear rule (not a small hidden note)
		local rule = create("TextLabel", {
			Name = "SkinRule",
			LayoutOrder = -1,
			Size = UDim2.new(1, -4, 0, 40),
			BackgroundColor3 = Color3.fromRGB(205, 40, 52),
			Font = FONT,
			Text = "EVOLVED BALLS  •  Wins need the original ball  •  Robux skips it",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 15,
			TextWrapped = true,
		}, list)
		round(rule, 10)
		outline(rule, 3)
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, rule)
	end

	for _, ball in ipairs(balls) do
		if not (ball.IsExclusive and not ball.Owned) then
			buildCard(ball, wins, rebirths, equippedSpeed, maxSpeed, topPrice, skinWorld)
		end
	end
end

--------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------

setOpen = function(open)
	if open == gui.Enabled then
		return
	end

	gui.Enabled = open

	if open then
		panelScale.Scale = panelScale.Scale * 0.9
		updateScale()
		-- arrived from a skin's TELEPORT: open that ball's skins and scroll to it
		local pending = player:GetAttribute("PendingSkin")
		local pendingBall, pendingWorld = nil, nil
		if typeof(pending) == "string" then
			pendingBall, pendingWorld = string.match(pending, "^(.-)@(%d+)$")
		end
		if pendingBall and tonumber(pendingWorld) == (player:GetAttribute("World") or 1) then
			expanded[pendingBall] = true
			player:SetAttribute("PendingSkin", nil)
		end
		refresh()
		if pendingBall then
			task.defer(function()
				local target = list:FindFirstChild(pendingBall)
				if target then
					list.CanvasPosition = Vector2.new(0, math.max(0, target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 8))
				end
			end)
		end
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)

openShop.OnClientEvent:Connect(function()
	setOpen(true)
end)

--------------------------------------------------
-- SERVER ANSWERS
--------------------------------------------------

ballShop.OnClientEvent:Connect(function(kind, result)
	if kind ~= "PurchaseResult" and kind ~= "EquipResult" then
		return
	end
	if typeof(result) ~= "table" then
		return
	end

	local text = REASONS[result.Reason] or tostring(result.Reason or "")
	if kind == "EquipResult" and result.Success then
		text = "Equipped!"
	end
	if kind == "PurchaseResult" and result.Success then
		closePopup()
	end
	setStatus(text)

	if gui.Enabled then
		refresh()
	end
end)

-- skin purchase answers
local SKIN_REASONS = {
	Bought = "Skin unlocked! It shows while you roll in that world.",
	NeedOriginal = "Get the original ball first!",
	NotOnSale = "This price is not on sale yet.",
	NotEnoughWins = "Not enough Wins.",
	NotInWorld = "Go to that world to buy its skin.",
	WorldLocked = "That world is still locked.",
	AlreadyOwned = "You already own this skin.",
}
skinShop.OnClientEvent:Connect(function(kind, result)
	if kind == "Result" and typeof(result) == "table" then
		setStatus(SKIN_REASONS[result.Reason] or "Could not buy that skin.")
		-- equip the ball you just bought the skin for (the server checks ownership)
		local boughtBall = result.Success and typeof(result.Key) == "string" and string.match(result.Key, "^(.-)@")
		if boughtBall then
			request("Equip", boughtBall)
		end
		if gui.Enabled then
			refresh()
		end
	end
end)

-- Keep prices/affordability fresh while the shop is open.
for _, attribute in ipairs({ "Wins", "Rebirths" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end

-- Robux purchases complete outside our remotes; refresh when the
-- player comes back from the purchase prompt.
game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId)
	if userId == player.UserId and gui.Enabled then
		task.delay(1.5, refresh)
	end
end)
