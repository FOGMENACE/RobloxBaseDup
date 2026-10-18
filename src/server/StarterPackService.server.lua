--------------------------------------------------
-- STARTER PACK (Game Pass, SERVER ONLY)
--
-- The pass is owned forever, but its bundle (wins + a short x2 oil / x2
-- wins boost) is granted exactly ONCE per account. Ownership is read from
-- Roblox (UserOwnsGamePassAsync); the client's "purchased" flag only
-- triggers a server re-check. The "granted" flag is saved BEFORE the
-- reward, and rolled back if the grant fails.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local StoreConfig = require(ServerScriptService:WaitForChild("StoreConfig"))
local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local pack = StoreConfig.StarterPack
local store = DataStoreService:GetDataStore("StarterPack_v1")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")

local busy = {}

local function key(player)
	return "u_" .. player.UserId
end

local function owns(player)
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pack.PassId)
	end)
	return ok and result == true
end

local function grantOnce(player)
	if busy[player] or not owns(player) then
		return
	end
	busy[player] = true

	local okRead, already = pcall(function()
		return store:GetAsync(key(player))
	end)

	if okRead and already ~= true and player.Parent == Players then
		-- atomic across servers: only the call that flips it to true grants the pack
		local won = false
		local saved = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if old == true then
					return nil
				end
				won = true
				return true
			end)
		end)

		if saved and won then
			if PlayerDataService.AddWins(player, pack.Wins) then
				BoostService.Grant(player, "Oil2x", pack.BoostSeconds)
				BoostService.Grant(player, "Wins2x", pack.BoostSeconds)
				PlayerDataService.SavePlayer(player)
				purchaseConfirmed:FireClient(player, "STARTER PACK")
			else
				pcall(function()
					store:RemoveAsync(key(player))
				end)
			end
		end
	end

	busy[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	task.delay(8, grantOnce, player) -- after the player's data has loaded
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(grantOnce, player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == pack.PassId then
		task.spawn(grantOnce, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

print("[StarterPackService] READY")
