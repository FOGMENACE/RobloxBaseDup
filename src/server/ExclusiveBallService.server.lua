--------------------------------------------------
-- EXCLUSIVE BALL SERVICE (SERVER ONLY)
--
-- Owns the Game Pass for exclusive balls (ShopConfig.ExclusiveBalls):
-- ownership is read from Roblox (UserOwnsGamePassAsync) on join and
-- re-checked after a purchase prompt finishes; the client's "purchased"
-- flag only triggers that server check. The ball is added to the
-- player's saved OwnedBalls (idempotent), so it also survives if the pass
-- is ever removed. Other grants (Captain pack, calendar day 7) call
-- PlayerDataService.AddOwnedBall themselves.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")

local function owns(player, passId)
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and result == true
end

local function grant(player, entry, announce)
	if entry.PassId == 0 or not player.Parent then
		return
	end

	if PlayerDataService.OwnsBall(player, entry.BallId) then
		return
	end

	if owns(player, entry.PassId) and PlayerDataService.AddOwnedBall(player, entry.BallId) then
		PlayerDataService.SavePlayer(player)
		if announce then
			purchaseConfirmed:FireClient(player, entry.DisplayName .. " BALL")
		end
	end
end

local function checkAll(player, announce)
	for _, entry in pairs(ShopConfig.ExclusiveBalls) do
		grant(player, entry, announce)
		-- display only (the store shows the discounted Captain pack); the server
		-- re-checks real ownership whenever it sells or grants anything
		if entry.BallId == "OilBarrel" and entry.PassId ~= 0 and player.Parent then
			player:SetAttribute("OwnsBarrelPass", owns(player, entry.PassId))
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.delay(8, checkAll, player, false) -- after the player's data has loaded
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(checkAll, player, false)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end

	for _, entry in pairs(ShopConfig.ExclusiveBalls) do
		if entry.PassId ~= 0 and entry.PassId == passId then
			task.spawn(function()
				grant(player, entry, true)
				checkAll(player, false) -- refresh the display flag
			end)
		end
	end
end)

print("[ExclusiveBallService] READY")
