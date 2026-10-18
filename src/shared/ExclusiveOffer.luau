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
