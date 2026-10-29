--------------------------------------------------
-- PURCHASE ANNOUNCER (SERVER ONLY MODULE)
--
-- Posts "<name> bought <item> for <robux>" in everyone's chat after a purchase
-- the SERVER has confirmed:
--   * Developer Products: called by PurchaseService once a receipt is granted,
--     with Roblox's own CurrencySpent.
--   * Game Passes: PromptGamePassPurchaseFinished is only a hint; ownership is
--     re-checked with Roblox and the price comes from Roblox's product info.
-- Clients only display what the server sends (ChatAnnouncements.client.lua);
-- they can never trigger an announcement.
--------------------------------------------------

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseAnnouncer = {}

-- one remote, even if this module were ever loaded twice
local remote = ReplicatedStorage:FindFirstChild("PurchaseAnnouncement")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PurchaseAnnouncement"
	remote.Parent = ReplicatedStorage
end

local infoCache = {} -- ["P"/"G" .. id] = { Name, Price }

local function productInfo(id, infoType)
	local key = (infoType == Enum.InfoType.Product and "P" or "G") .. tostring(id)
	if infoCache[key] then
		return infoCache[key]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if not ok or typeof(info) ~= "table" then
		return nil
	end
	local result = { Name = tostring(info.Name or "an item"), Price = tonumber(info.PriceInRobux) or 0 }
	infoCache[key] = result
	return result
end

local function announce(player, itemName, robux)
	robux = math.floor(tonumber(robux) or 0)
	if not player or not player.Parent or robux <= 0 then
		return
	end
	remote:FireAllClients(player.UserId, itemName, robux)
end

-- Developer Product receipt (already validated and granted by PurchaseService)
function PurchaseAnnouncer.Product(player, productId, robuxSpent)
	task.spawn(function()
		local info = productInfo(productId, Enum.InfoType.Product)
		announce(player, info and info.Name or "an item", robuxSpent)
	end)
end

-- Game Passes: verified with Roblox, announced once per player and pass per session
local announcedPasses = {} -- [player] = { [passId] = true }

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or typeof(passId) ~= "number" then
		return
	end
	announcedPasses[player] = announcedPasses[player] or {}
	if announcedPasses[player][passId] then
		return
	end
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if not ok or owns ~= true or announcedPasses[player][passId] then
			return
		end
		announcedPasses[player][passId] = true
		local info = productInfo(passId, Enum.InfoType.GamePass)
		if info then
			announce(player, info.Name, info.Price)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	announcedPasses[player] = nil
end)

return PurchaseAnnouncer
