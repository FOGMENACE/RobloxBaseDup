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
local GameAnalytics = require(ServerScriptService:WaitForChild("GameAnalytics"))
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

--------------------------------------------------
-- CAPTAIN OIL SERVER PACK + SKIP REBIRTH
--------------------------------------------------

local StoreConfig = require(ServerScriptService:WaitForChild("StoreConfig"))
local BadgeAwards = require(ServerScriptService:WaitForChild("BadgeAwards"))

local storePrompt = getOrCreate("StorePrompt")
local captainAnnounce = getOrCreate("CaptainAnnounce")

local function grantBoosts(player, seconds)
	BoostService.Grant(player, "Oil2x", seconds)
	BoostService.Grant(player, "Wins2x", seconds)
	BoostService.Grant(player, "Captain", seconds)
end

local captain = StoreConfig.Captain
local captainOwner = StoreConfig.CaptainOwner
local ShopConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("ShopConfig"))

-- The owner discount is only for players who PAID for the Oil Barrel Game Pass.
-- Owning the ball is not enough (it is also a free calendar reward and part of
-- this very pack), and the client's word is never used: ownership is read from
-- Roblox. Returns (owns, verified).
local function ownsBarrelPass(player)
	local entry = ShopConfig.ExclusiveBalls.OilBarrel
	if not entry or entry.PassId == 0 then
		return false, true
	end

	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.PassId)
	end)

	return ok and result == true, ok
end

local function registerCaptainProduct(productId, ownerOnly)
	PurchaseService.RegisterProduct(productId, function(player, receiptInfo)
		if not player or not player:IsDescendantOf(Players) then
			return false
		end

		if ownerOnly then
			-- someone can prompt ANY product id from a modified client, so the
			-- discounted pack is validated again when the receipt arrives
			local owns, verified = ownsBarrelPass(player)
			if not verified then
				warn("[AUDIT] owner-pack ownership check unavailable, receipt stays pending:", player.Name, receiptInfo.PurchaseId)
				return false
			end
			if not owns then
				warn("[AUDIT] owner-pack bought WITHOUT the barrel pass, NOT granted:", player.Name, player.UserId, receiptInfo.PurchaseId)
				return false
			end
		end

		return ReceiptLedger.Consume(player, receiptInfo, function()
			-- The captain: the biggest reward and the longest boost.
			local winsBefore = GameAnalytics.WinsBefore(player)
			if not PlayerDataService.AddWins(player, captain.BuyerWins) then
				return false
			end
			GameAnalytics.WinsChanged(player, winsBefore, "IAP", "CaptainPack")
			grantBoosts(player, captain.BuyerBoostSeconds)

			-- exclusive reward: the rainbow Oil Barrel ball (idempotent for owners)
			PlayerDataService.AddOwnedBall(player, "OilBarrel")

			-- Everyone else in the server: a thank-you from the captain.
			for _, other in ipairs(Players:GetPlayers()) do
				if other ~= player then
					local otherBefore = GameAnalytics.WinsBefore(other)
					PlayerDataService.AddWins(other, captain.OthersWins)
					GameAnalytics.WinsChanged(other, otherBefore, "Social", "CaptainGift")
					grantBoosts(other, captain.ServerBoostSeconds)
					task.spawn(PlayerDataService.SavePlayer, other)
				end
			end

			return true
		end, function(buyer)
			-- Confirmed (granted, saved, recorded): the same badge for both
			-- versions of the pack, then the server-wide announcement.
			BadgeAwards.Award(buyer, "Captain")
			captainAnnounce:FireAllClients(
				buyer.DisplayName,
				captain.OthersWins,
				math.floor(captain.ServerBoostSeconds / 60)
			)
			purchaseConfirmed:FireClient(buyer, "CAPTAIN OIL SERVER PACK")
		end)
	end)
end

registerCaptainProduct(captain.ProductId, false)
if captainOwner and captainOwner.ProductId ~= 0 then
	registerCaptainProduct(captainOwner.ProductId, true)
end
-- Skip Rebirth: a rebirth without the level requirement.
local rebirthSkip = StoreConfig.RebirthSkip

PurchaseService.RegisterProduct(rebirthSkip.ProductId, function(player, receiptInfo)
	if not player or not player:IsDescendantOf(Players) then
		return false
	end

	return ReceiptLedger.Consume(player, receiptInfo, function()
		return PlayerDataService.ForceRebirth(player)
	end, function(buyer)
		purchaseConfirmed:FireClient(buyer, "SKIP REBIRTH")
	end)
end)

-- The client only sends a key; ids and prices stay on the server.
storePrompt.OnServerEvent:Connect(function(player, key)
	if rateLimited(player) or typeof(key) ~= "string" then
		return
	end

	local productId
	if key == "Captain" then
		-- the SERVER picks the version: the owner pack only for verified owners
		productId = captain.ProductId
		if captainOwner and captainOwner.ProductId ~= 0 and (ownsBarrelPass(player)) then
			productId = captainOwner.ProductId
		end
	elseif key == "RebirthSkip" then
		-- no point selling a skip the player cannot use
		if (PlayerDataService.GetRebirths(player) or 0) >= 1000 then
			return
		end
		productId = rebirthSkip.ProductId
	else
		return
	end

	pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	quotes[player] = nil
	lastRequest[player] = nil
end)

print("[ProductService] READY | XP kits:", #XPKits.Products)
