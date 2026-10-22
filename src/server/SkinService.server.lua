--------------------------------------------------
-- SKIN SERVICE (SERVER)
--
-- Evolved world skins of the balls (cosmetic coating + aura in that world;
-- the Oil Barrel skin also adds +5 speed in its world). Server authority:
--   * a skin can only be bought while the player is IN that world (unlocked
--     by rebirths, validated by WorldService before they got there);
--   * with Wins only if they own the Rookie Lanes original of the ball;
--   * the price comes from WorldConfig (never from the client);
--   * ownership is saved in DataStore "WorldSkins_v1" and published as the
--     player attribute "Skins" ("Ball@2,Ball@3") for everyone's display.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))

local MarketplaceService = game:GetService("MarketplaceService")
local PurchaseService = require(ServerScriptService:WaitForChild("PurchaseServiceModule"))
local ReceiptLedger = require(ServerScriptService:WaitForChild("ReceiptLedger"))
local SkinProducts = require(script.Parent:WaitForChild("SkinProducts"))

local store = DataStoreService:GetDataStore("WorldSkins_v1")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skinShop = remotes:FindFirstChild("SkinShop")
if not skinShop then
	skinShop = Instance.new("RemoteEvent")
	skinShop.Name = "SkinShop"
	skinShop.Parent = remotes
end

-- skins that already have a Developer Product ("Ball@World"): the shop shows the price but
-- "opens soon" for the rest
local live = {}
for ballId, row in pairs(SkinProducts) do
	for worldId, productId in pairs(row) do
		if productId ~= 0 then
			table.insert(live, WorldConfig.SkinKey(ballId, worldId))
		end
	end
end
table.sort(live)
for ballId in pairs(WorldConfig.SkinRobux) do
	for worldId = 2, #WorldConfig.Worlds do
		if not (SkinProducts[ballId] and SkinProducts[ballId][worldId]) then
			warn("[SkinService] SkinProducts.luau has no entry for " .. WorldConfig.SkinKey(ballId, worldId))
		end
	end
end
ReplicatedStorage:SetAttribute("SkinSaleKeys", table.concat(live, ","))

local owned = {} -- [player] = { [key] = true }
local pendingRobux = {} -- [player] = { Key, BallId, WorldId, ProductId, At }
local loaded = {}
local busy = {}

local function publish(player)
	local keys = {}
	for key in pairs(owned[player] or {}) do
		table.insert(keys, key)
	end
	table.sort(keys)
	player:SetAttribute("Skins", table.concat(keys, ","))
end

local function save(player)
	if not loaded[player] then
		return false
	end
	local list = {}
	for key in pairs(owned[player] or {}) do
		table.insert(list, key)
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), list)
	end)
	if not ok then
		warn("[SkinService] save failed:", player.Name, err)
	end
	return ok
end

local function reply(player, success, reason, key)
	skinShop:FireClient(player, "Result", { Success = success, Reason = reason, Key = key })
end

-- Checks shared by the Wins and the Robux route. Returns the world and key, or nil + reason.
local function check(player, ballId, worldId, viaRobux)
	local world = WorldConfig.Worlds[worldId]
	if not world or worldId < 2 or not PlayerDataService.IsValidBallId(ballId) then
		return nil, "Invalid"
	end
	if (player:GetAttribute("World") or 1) ~= worldId then
		return nil, "NotInWorld"
	end
	if not WorldConfig.Unlocked(PlayerDataService.GetRebirths(player), worldId) then
		return nil, "WorldLocked"
	end
	local key = WorldConfig.SkinKey(ballId, worldId)
	if owned[player][key] then
		return nil, "AlreadyOwned"
	end
	-- the Oil Barrel skin always needs the original barrel; every other skin needs
	-- the original with Wins but not with Robux (that purchase also gives the ball)
	if (ballId == "OilBarrel" or not viaRobux) and not PlayerDataService.OwnsBall(player, ballId) then
		return nil, "NeedOriginal"
	end
	return world, key
end

skinShop.OnServerEvent:Connect(function(player, action, ballId, worldId)
	-- exact integer world ids only (3.5 must never round into world 3)
	if (action ~= "Buy" and action ~= "BuyRobux") or typeof(ballId) ~= "string" or #ballId > 40
		or typeof(worldId) ~= "number" or worldId ~= worldId or worldId % 1 ~= 0 then
		return
	end
	if busy[player] or not loaded[player] then
		return
	end
	busy[player] = true

	local function finish(success, reason, key)
		busy[player] = nil
		reply(player, success, reason, key)
	end

	if action == "BuyRobux" then
		local world, key = check(player, ballId, worldId, true)
		if not world then
			return finish(false, key)
		end
		local row = SkinProducts[ballId]
		local productId = row and row[worldId]
		if not productId or productId == 0 then
			return finish(false, "NotOnSale")
		end
		pendingRobux[player] = { Key = key, BallId = ballId, WorldId = worldId, ProductId = productId, At = os.clock() }
		busy[player] = nil
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
		return
	end
	local world, key = check(player, ballId, worldId, false)
	if not world then
		return finish(false, key)
	end
	local definition = PlayerDataService.GetBallDefinition(ballId)
	local cost = WorldConfig.SkinWinsCost(ballId, worldId, definition and definition.WinsCost or 0)
	if not cost or cost <= 0 then
		return finish(false, "Invalid")
	end
	if (PlayerDataService.GetWins(player) or 0) < cost then
		return finish(false, "NotEnoughWins")
	end
	if not PlayerDataService.RemoveWins(player, cost) then
		return finish(false, "NotEnoughWins")
	end
	owned[player][key] = true
	publish(player)
	if not save(player) then
		-- keep it for this session and retry on leave; the wins are already spent
		warn("[AUDIT] skin save deferred", player.Name, key)
	end
	finish(true, "Bought", key)
end)

-- Robux receipts: the grant is the skin THIS player asked for (the server-side pending
-- record), and it must be the product made for that exact ball and world. No pending
-- record = nothing granted and the receipt stays pending.
for productBall, row in pairs(SkinProducts) do
	for productWorld, productId in pairs(row) do
		if productId ~= 0 then
			PurchaseService.RegisterProduct(productId, function(player, receiptInfo)
				if not player or not player:IsDescendantOf(Players) or not loaded[player] then
					return false
				end
				local pending = pendingRobux[player]
				if not pending or pending.ProductId ~= receiptInfo.ProductId or os.clock() - pending.At > 1800
					or pending.BallId ~= productBall or pending.WorldId ~= productWorld then
					warn("[AUDIT] skin product bought without a matching request, NOT granted:", player.Name, receiptInfo.PurchaseId)
					return false
				end
				-- re-validated at the receipt: a modified client can prompt any product
				if not WorldConfig.Unlocked(PlayerDataService.GetRebirths(player), pending.WorldId) then
					return false
				end
				if pending.BallId == "OilBarrel" and not PlayerDataService.OwnsBall(player, "OilBarrel") then
					return false
				end
				return ReceiptLedger.Consume(player, receiptInfo, function()
					owned[player][pending.Key] = true
					if pending.BallId ~= "OilBarrel" then
						PlayerDataService.AddOwnedBall(player, pending.BallId) -- the original comes with it
					end
					publish(player)
					return save(player)
				end, function(buyer)
					pendingRobux[buyer] = nil
					reply(buyer, true, "Bought", pending.Key)
				end)
			end)
		end
	end
end

local function onJoin(player)
	owned[player] = {}
	player:SetAttribute("Skins", "")
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not player.Parent then
		return
	end
	if ok and typeof(data) == "table" then
		for _, key in ipairs(data) do
			if typeof(key) == "string" and #key < 64 then
				owned[player][key] = true
			end
		end
	end
	loaded[player] = ok -- never overwrite saved skins after a failed load
	publish(player)
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(onJoin, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	owned[player], loaded[player], busy[player], pendingRobux[player] = nil, nil, nil, nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)