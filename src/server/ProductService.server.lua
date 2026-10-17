--------------------------------------------------
-- PRODUCT SERVICE
--
-- SERVER ONLY. Developer Products that are not balls:
--   * XP KIT 1 / 2 / 3  (sized from the player's current level, see
--                        shared/XPKits)
--   * x2 OIL and x2 WINS timed boosts (shared/BoostConfig; skipped until
--     their ProductId is filled in)
--
-- Purchase flow (clients only ever send an index / key):
--   client -> request remote -> server validates + (for kits) quotes the
--   amount -> PromptProductPurchase -> ProcessReceipt (owned by
--   PurchaseService) -> handler below grants, SAVES, records the
--   PurchaseId, and only then consumes the receipt.
--
-- Prices are set on the products in the Creator Hub; this script never
-- trusts a client-supplied price, product id or amount.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local XPKits = require(ReplicatedStorage:WaitForChild("XPKits"))
local BoostConfig = require(ReplicatedStorage:WaitForChild("BoostConfig"))

local PurchaseService = require(ServerScriptService:WaitForChild("PurchaseServiceModule"))
local ReceiptLedger = require(ServerScriptService:WaitForChild("ReceiptLedger"))
local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local QUOTE_SECONDS = 10 * 60
local REQUEST_COOLDOWN = 0.6

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = remotes
	return created
end

local kitPrompt = getOrCreate("XPKitPrompt")
local boostPrompt = getOrCreate("BoostPrompt")
local purchaseConfirmed = getOrCreate("PurchaseConfirmed")

--------------------------------------------------
-- SHARED HELPERS
--------------------------------------------------

local lastRequest = {} -- [player] = os.clock()

local function rateLimited(player)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- The amount a kit is worth for this player RIGHT NOW (server data only).
local function currentKitAmount(player, kit)
	return XPKits.Amount(
		kit,
		player:GetAttribute("XPNeededForLevel"),
		PlayerDataService.GetRebirths(player)
	)
end

-- [player] = { [productId] = { Amount, Time } }: the price shown when the
-- prompt opened is the amount granted (a level-up mid-prompt cannot
-- shrink it).
local quotes = {}

local function consume(player, receiptInfo, grantFunction, label)
	local purchaseId = receiptInfo.PurchaseId

	local recorded = ReceiptLedger.IsRecorded(player, purchaseId)
	if recorded == nil then
		return false -- DataStore down: retry later
	end
	if recorded then
		return true -- already granted and saved
	end

	if not ReceiptLedger.IsPending(purchaseId) then
		if not grantFunction() then
			return false
		end
		ReceiptLedger.MarkPending(purchaseId)
	end

	-- Persist BEFORE the receipt is consumed.
	if PlayerDataService.SavePlayer(player) ~= true then
		warn("[ProductService] Save failed; receipt stays pending:", player.Name, purchaseId)
		return false
	end

	if not ReceiptLedger.Record(player, purchaseId) then
		return false
	end

	ReceiptLedger.ClearPending(purchaseId)

	-- Only now (granted, saved and recorded) is it confirmed to the player.
	if label then
		purchaseConfirmed:FireClient(player, label)
	end
	return true
end

--------------------------------------------------
-- XP KITS
--------------------------------------------------

for kit, product in ipairs(XPKits.Products) do
	PurchaseService.RegisterProduct(product.ProductId, function(player, receiptInfo)
		if not player or not player:IsDescendantOf(Players) then
			return false
		end

		return consume(player, receiptInfo, function()
			local quote = quotes[player] and quotes[player][product.ProductId]
			local amount

			if quote and os.time() - quote.Time <= QUOTE_SECONDS then
				amount = quote.Amount
			else
				amount = currentKitAmount(player, kit)
			end

			if amount <= 0 then
				return false
			end

			local granted = PlayerDataService.AddXP(player, amount)
			if granted and quotes[player] then
				quotes[player][product.ProductId] = nil
			end

			return granted == true
		end, "XP KIT " .. kit)
	end)
end

kitPrompt.OnServerEvent:Connect(function(player, kit)
	if rateLimited(player) or typeof(kit) ~= "number" then
		return
	end

	local product = XPKits.Products[kit]
	if not product then
		return
	end

	quotes[player] = quotes[player] or {}
	quotes[player][product.ProductId] = {
		Amount = currentKitAmount(player, kit),
		Time = os.time(),
	}

	pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
	end)
end)

--------------------------------------------------
-- BOOSTS (x2 oil / x2 wins)
--------------------------------------------------

for key, boost in pairs(BoostConfig.Boosts) do
	if boost.PriceRobux and boost.ProductId ~= 0 then
		PurchaseService.RegisterProduct(boost.ProductId, function(player, receiptInfo)
			if not player or not player:IsDescendantOf(Players) then
				return false
			end

			return consume(player, receiptInfo, function()
				return BoostService.Grant(player, key, boost.Duration)
			end, boost.Label)
		end)
	end
end

boostPrompt.OnServerEvent:Connect(function(player, key)
	if rateLimited(player) or typeof(key) ~= "string" then
		return
	end

	local boost = BoostConfig.Boosts[key]
	if not boost or not boost.PriceRobux or boost.ProductId == 0 then
		return
	end

	pcall(function()
		MarketplaceService:PromptProductPurchase(player, boost.ProductId)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	quotes[player] = nil
	lastRequest[player] = nil
end)

print("[ProductService] READY | XP kits:", #XPKits.Products)
