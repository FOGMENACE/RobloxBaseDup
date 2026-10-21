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

local store = DataStoreService:GetDataStore("WorldSkins_v1")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local skinShop = remotes:FindFirstChild("SkinShop")
if not skinShop then
	skinShop = Instance.new("RemoteEvent")
	skinShop.Name = "SkinShop"
	skinShop.Parent = remotes
end

local owned = {} -- [player] = { [key] = true }
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

skinShop.OnServerEvent:Connect(function(player, action, ballId, worldId)
	-- exact integer world ids only (3.5 must never round into world 3)
	if action ~= "Buy" or typeof(ballId) ~= "string" or #ballId > 40 or typeof(worldId) ~= "number"
		or worldId ~= worldId or worldId % 1 ~= 0 then
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

	local world = WorldConfig.Worlds[worldId]
	if not world or worldId < 2 or not PlayerDataService.IsValidBallId(ballId) then
		return finish(false, "Invalid")
	end
	if (player:GetAttribute("World") or 1) ~= worldId then
		return finish(false, "NotInWorld")
	end
	if not WorldConfig.Unlocked(PlayerDataService.GetRebirths(player), worldId) then
		return finish(false, "WorldLocked")
	end
	local key = WorldConfig.SkinKey(ballId, worldId)
	if owned[player][key] then
		return finish(false, "AlreadyOwned")
	end
	if not PlayerDataService.OwnsBall(player, ballId) then
		return finish(false, "NeedOriginal")
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
	owned[player], loaded[player], busy[player] = nil, nil, nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)