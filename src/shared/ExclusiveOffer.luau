--------------------------------------------------
-- EXCLUSIVE OFFER (client UI module)
--
-- A floating, 3D-looking offer for an exclusive ball (the Oil Barrel):
-- a spinning model that pokes out over the edge of a panel, with the name
-- and a Robux price button beside it. There is NO background frame, so it
-- looks like it hovers over the UI. Used by the Ball Shop and the Store.
--
--   local offer = ExclusiveOffer.Create(parent, {
--       BallId = "OilBarrel",       -- key in ShopConfig.ExclusiveBalls
--       AnchorPoint, Position, Size, ZIndex,
--   })
--   offer.Frame   -- the holder (set .Position yourself if needed)
--   offer.Refresh() -- re-check ownership (also runs after a purchase)
--
-- Clicking the price only opens the Roblox purchase prompt for the Game
-- Pass; the SERVER (ExclusiveBallService) verifies ownership and grants
-- the ball. The offer hides itself once the player owns the pass.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local ShopConfig = require(script.Parent:WaitForChild("ShopConfig"))
local BallAccessories = require(script.Parent:WaitForChild("BallAccessories"))

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)

local ExclusiveOffer = {}

--------------------------------------------------
-- OWNERSHIP (cached per pass; refreshed after a purchase prompt)
--------------------------------------------------

local ownership = {} -- [passId] = true / false / nil (unknown)

function ExclusiveOffer.OwnsPass(passId, force)
	if passId == 0 then
		return false
	end

	if ownership[passId] == nil or force then
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			ownership[passId] = result == true
		end
	end

	return ownership[passId] == true
end

--------------------------------------------------
-- PRICING (display only)
--
-- The Oil Barrel is ALWAYS shown at its configured price (ShopConfig, 499). Only when Roblox
-- itself reports a Roblox Plus discount for THIS player (PriceDiscountDetails with Type
-- "RobloxPlusSubscription") is the cheaper price shown next to the struck-through full price.
-- Roblox charges the real price either way; this never changes what is granted or charged.
--------------------------------------------------

local pricingCache = {} -- [passId] = { Base, Pay, Percent }

local function fetchInfo(passId)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(passId, Enum.InfoType.GamePass)
	end)
	if not ok then
		ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)
	end
	return ok and typeof(info) == "table" and info or nil
end

-- the last known pricing (never yields); the configured price until the lookup finishes
function ExclusiveOffer.CachedPricing(entry)
	return pricingCache[entry.PassId] or { Base = entry.Price, Pay = entry.Price, Percent = 0 }
end

-- looks the price up once per session (yields the first time)
function ExclusiveOffer.GetPricing(entry)
	local cached = pricingCache[entry.PassId]
	if cached then
		return cached
	end
	local result = { Base = entry.Price, Pay = entry.Price, Percent = 0 }
	local info = entry.PassId ~= 0 and fetchInfo(entry.PassId) or nil
	if info and typeof(info.PriceDiscountDetails) == "table" then
		for _, detail in ipairs(info.PriceDiscountDetails) do
			if typeof(detail) == "table" and detail.Type == "RobloxPlusSubscription"
				and typeof(detail.Percent) == "number" and detail.Percent > 0 then
				local pay = entry.Price
				if info.UserBasePriceInRobux == entry.Price and typeof(info.PriceInRobux) == "number" then
					pay = info.PriceInRobux
				else
					pay = math.floor(entry.Price * (1 - detail.Percent / 100))
				end
				if pay < entry.Price then
					result = { Base = entry.Price, Pay = pay, Percent = detail.Percent }
				end
			end
		end
	end
	pricingCache[entry.PassId] = result
	return result
end

local TextService = game:GetService("TextService")

-- Plus discount look: the NEW price takes the main place, and the old price sits small beside it
-- with a red diagonal slash through it. `label` is a TextLabel/TextButton whose text is the main
-- price (the caller sets label.Text to the new price, with any prefix). opts:
--   Mode   "Left" (group starts at Inset) or "Center" (group centred between Inset and Inset + Width)
--   Inset, Width, OldSize
function ExclusiveOffer.ShowDiscount(label, pricing, opts)
	ExclusiveOffer.ClearDiscount(label)
	opts = opts or {}
	local inset = opts.Inset or 0
	local oldSize = opts.OldSize or math.max(10, math.floor(label.TextSize * 0.62))
	local gap = 5
	local mainW = TextService:GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(1000, 100)).X
	local oldText = tostring(pricing.Base)
	local oldW = TextService:GetTextSize(oldText, oldSize, label.Font, Vector2.new(1000, 100)).X
	local groupW = mainW + gap + oldW
	local startX = inset
	if opts.Mode == "Center" and opts.Width then
		startX = inset + math.max(0, (opts.Width - groupW) / 2)
	end
	label.TextXAlignment = Enum.TextXAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.Name = "PricePad"
	pad.PaddingLeft = UDim.new(0, startX)
	pad.Parent = label

	local old = Instance.new("TextLabel")
	old.Name = "OldPrice"
	old.BackgroundTransparency = 1
	old.AnchorPoint = Vector2.new(0, 0.5)
	old.Position = UDim2.new(0, mainW + gap, 0.5, 2) -- the label's UIPadding already shifts its children by startX
	old.Size = UDim2.fromOffset(oldW, oldSize + 4)
	old.Font = label.Font
	old.Text = oldText
	old.TextSize = oldSize
	old.TextColor3 = Color3.fromRGB(235, 235, 240)
	old.TextTransparency = 0.1
	old.ZIndex = label.ZIndex + 2
	old.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(24, 22, 34)
	stroke.Thickness = 1.5
	stroke.Parent = old

	-- the slash: red and slightly diagonal, like a real sale tag
	local slash = Instance.new("Frame")
	slash.Name = "Slash"
	slash.AnchorPoint = Vector2.new(0.5, 0.5)
	slash.Position = UDim2.fromScale(0.5, 0.5)
	slash.Size = UDim2.new(1, 10, 0, math.max(3, math.floor(oldSize / 4.5)))
	slash.Rotation = -22
	slash.BackgroundColor3 = Color3.fromRGB(255, 40, 55)
	slash.BorderSizePixel = 0
	slash.ZIndex = old.ZIndex + 1
	slash.Parent = old
	Instance.new("UICorner", slash).CornerRadius = UDim.new(1, 0)
	local slashStroke = Instance.new("UIStroke")
	slashStroke.Color = Color3.fromRGB(90, 0, 10)
	slashStroke.Thickness = 1
	slashStroke.Parent = slash
end

function ExclusiveOffer.ClearDiscount(label)
	local old = label:FindFirstChild("OldPrice")
	if old then
		old:Destroy()
	end
	local pad = label:FindFirstChild("PricePad")
	if pad then
		pad:Destroy()
	end
end


local listeners = {} -- functions called after ownership may have changed

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
	if who == player and purchased then
		ownership[passId] = true
		for _, callback in ipairs(listeners) do
			task.spawn(callback)
		end
	end
end)

--------------------------------------------------
-- BUILD
--------------------------------------------------

function ExclusiveOffer.Create(parent, options)
	local entry = ShopConfig.ExclusiveBalls[options.BallId]
	assert(entry, "ExclusiveOffer: unknown ball " .. tostring(options.BallId))

	local z = options.ZIndex or 40

	local holder = Instance.new("Frame")
	holder.Name = "ExclusiveOffer"
	holder.AnchorPoint = options.AnchorPoint or Vector2.new(0.5, 1)
	holder.Position = options.Position or UDim2.new(0.5, 0, 1, 56)
	holder.Size = options.Size or UDim2.fromOffset(430, 124)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent

	-- soft shadow on the "floor" under the model
	local shadow = Instance.new("Frame")
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.fromOffset(62, 112)
	shadow.Size = UDim2.fromOffset(96, 14)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.ZIndex = z
	shadow.Parent = holder
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)

	-- the spinning 3D model (3/4 view from above, so it reads as 3D)
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Position = UDim2.fromOffset(-6, -6)
	viewport.Size = UDim2.fromOffset(136, 124)
	viewport.ZIndex = z + 5
	viewport.Parent = holder

	local model = Instance.new("Part")
	model.Shape = Enum.PartType.Ball
	model.Size = Vector3.new(2.8, 2.8, 2.8)
	model.Anchored = true
	model.CFrame = CFrame.new(0, 0, 0)
	model.Parent = viewport
	model:SetAttribute("PreviewSpeed", 9)

	task.spawn(function()
		BallAccessories.Apply(model, entry.BallId)
		BallAccessories.Pose(model, os.clock())
	end)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(4.6, 3.4, 6.2), Vector3.new(0, -0.1, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not holder.Parent then
			connection:Disconnect()
			return
		end
		BallAccessories.Pose(model, os.clock())
	end)

	-- name + tag
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(128, 12)
	title.Size = UDim2.new(1, -280, 0, 34)
	title.Font = FONT
	title.Text = entry.DisplayName
	title.TextColor3 = CREAM
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = z + 6
	title.Parent = holder
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = INK
	titleStroke.Thickness = 4
	titleStroke.Parent = title

	local tag = Instance.new("TextLabel")
	tag.BackgroundTransparency = 1
	tag.Position = UDim2.fromOffset(128, 48)
	tag.Size = UDim2.new(1, -280, 0, 30)
	tag.Font = FONT
	tag.Text = "EXCLUSIVE BALL"
	tag.TextColor3 = Color3.fromRGB(255, 226, 120)
	tag.TextSize = 14
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.ZIndex = z + 6
	tag.Parent = holder
	local tagStroke = Instance.new("UIStroke")
	tagStroke.Color = INK
	tagStroke.Thickness = 2.5
	tagStroke.Parent = tag

	-- price pill beside it
	local buy = Instance.new("TextButton")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -4, 0.5, -6)
	buy.Size = UDim2.fromOffset(132, 58)
	buy.BackgroundColor3 = Color3.fromRGB(0, 190, 112)
	buy.Text = ""
	buy.AutoButtonColor = false
	buy.ZIndex = z + 6
	buy.Parent = holder
	Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 16)
	local buyStroke = Instance.new("UIStroke")
	buyStroke.Color = INK
	buyStroke.Thickness = 3.5
	buyStroke.Parent = buy
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(90, 235, 160), Color3.fromRGB(0, 160, 96))
	gradient.Rotation = 90
	gradient.Parent = buy

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxasset://textures/ui/common/robux.png"
	icon.ZIndex = z + 7
	icon.Parent = buy

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromOffset(50, 0)
	price.Size = UDim2.new(1, -54, 1, 0)
	price.Font = FONT
	price.Text = tostring(entry.Price)
	price.TextColor3 = Color3.new(1, 1, 1)
	price.TextSize = 32
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.ZIndex = z + 7
	price.Parent = buy
	local priceStroke = Instance.new("UIStroke")
	priceStroke.Color = INK
	priceStroke.Thickness = 2.5
	priceStroke.Parent = price

	-- Roblox Plus: the discounted price takes the main spot, the old one is slashed beside it
	local function showPricing(pricing)
		if not price.Parent then
			return
		end
		if pricing.Pay < pricing.Base then
			price.Text = tostring(pricing.Pay)
			price.TextSize = 28
			ExclusiveOffer.ShowDiscount(price, pricing, { Mode = "Left", OldSize = 17 })
		else
			ExclusiveOffer.ClearDiscount(price)
			price.TextXAlignment = Enum.TextXAlignment.Left
			price.Text = tostring(pricing.Base)
			price.TextSize = 32
		end
	end
	task.spawn(function()
		showPricing(ExclusiveOffer.GetPricing(entry))
	end)

	local scale = Instance.new("UIScale")
	scale.Parent = buy
	buy.MouseEnter:Connect(function()
		scale.Scale = 1.06
	end)
	buy.MouseLeave:Connect(function()
		scale.Scale = 1
	end)

	buy.Activated:Connect(function()
		if entry.PassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, entry.PassId)
		end
	end)

	local offer = { Frame = holder, Entry = entry }

	function offer.Refresh()
		holder.Visible = not ExclusiveOffer.OwnsPass(entry.PassId)
	end

	table.insert(listeners, offer.Refresh)
	task.spawn(offer.Refresh)

	return offer
end

return ExclusiveOffer
