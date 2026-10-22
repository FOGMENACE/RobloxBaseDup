--------------------------------------------------
-- WORLD BALL MEMORY (SERVER)
--
-- Remembers which ball a player last equipped in each themed world
-- (DataStore "WorldBall_v1") and picks the ball when they arrive there:
--   1. the ball they last chose in that world (if they still own it and its
--      evolved skin for that world);
--   2. otherwise their current ball, if they own its evolved skin there;
--   3. otherwise the fastest ball whose evolved skin they own in that world;
--   4. otherwise nothing changes (they keep the ball from the previous world).
-- Equipping goes through BallService's own validated path (ServerStorage
-- BindableFunction), so ownership is always re-checked on the server.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
local equipBall = ServerStorage:WaitForChild("BallService"):WaitForChild("EquipBall")

local store = DataStoreService:GetDataStore("WorldBall_v1")

local memory = {} -- [player] = { [worldId] = ballId }
local loaded = {}
local dirty = {}
local applying = {} -- [player] = true while this script itself is equipping

local function ownsEvolved(player, ballId, worldId)
	return typeof(ballId) == "string" and PlayerDataService.OwnsBall(player, ballId)
		and WorldConfig.OwnsSkin(player, ballId, worldId)
end

local function fastestEvolved(player, worldId)
	local list = player:GetAttribute("Skins")
	if typeof(list) ~= "string" then
		return nil
	end
	local best, bestSpeed = nil, -1
	for ballId, id in string.gmatch(list, "([^,@]+)@(%d+)") do
		if tonumber(id) == worldId and ownsEvolved(player, ballId, worldId) then
			local definition = PlayerDataService.GetBallDefinition(ballId)
			local speed = definition and definition.ForwardSpeed or 0
			if speed > bestSpeed then
				best, bestSpeed = ballId, speed
			end
		end
	end
	return best
end

local function choose(player, worldId)
	local remembered = memory[player] and memory[player][worldId]
	if ownsEvolved(player, remembered, worldId) then
		return remembered
	end
	local current = player:GetAttribute("EquippedBall")
	if ownsEvolved(player, current, worldId) then
		return current
	end
	return fastestEvolved(player, worldId)
end

local function onWorldChanged(player)
	local worldId = player:GetAttribute("World") or 1
	if worldId < 2 then
		return
	end
	local waited = 0
	while player.Parent and not loaded[player] and waited < 10 do
		task.wait(0.25)
		waited += 0.25
	end
	if (player:GetAttribute("RunState") or "Waiting") ~= "Waiting" then
		return
	end
	local ballId = choose(player, worldId)
	if ballId and ballId ~= player:GetAttribute("EquippedBall") then
		applying[player] = true
		local ok, err = pcall(function()
			return equipBall:Invoke(player, ballId)
		end)
		applying[player] = nil
		if not ok then
			warn("[WorldBallMemory] equip failed:", player.Name, err)
		end
	end
end

local function onEquipped(player)
	if applying[player] or not loaded[player] then
		return
	end
	local worldId = player:GetAttribute("World") or 1
	local ballId = player:GetAttribute("EquippedBall")
	if worldId >= 2 and typeof(ballId) == "string" then
		memory[player][worldId] = ballId
		dirty[player] = true
	end
end

local function save(player)
	if not loaded[player] or not dirty[player] then
		return
	end
	local data = {}
	for worldId, ballId in pairs(memory[player]) do
		data[tostring(worldId)] = ballId
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if ok then
		dirty[player] = nil
	else
		warn("[WorldBallMemory] save failed:", player.Name, err)
	end
end

local function onJoin(player)
	memory[player] = {}
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(data) == "table" then
		for key, ballId in pairs(data) do
			local worldId = tonumber(key)
			if worldId and typeof(ballId) == "string" and #ballId < 40 then
				memory[player][worldId] = ballId
			end
		end
	end
	loaded[player] = ok -- never overwrite saved choices after a failed load
	player:GetAttributeChangedSignal("World"):Connect(function()
		task.defer(onWorldChanged, player)
	end)
	player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
		onEquipped(player)
	end)
	if (player:GetAttribute("World") or 1) >= 2 then
		task.defer(onWorldChanged, player)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onJoin, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, player)
end

Players.PlayerRemoving:Connect(function(player)
	save(player)
	memory[player], loaded[player], dirty[player], applying[player] = nil, nil, nil, nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

-- periodic save so a crash loses little
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end
end)
