--------------------------------------------------
-- SETTINGS SERVICE (SERVER)
--
-- Persists each player's four interface settings (music, sfx, low
-- graphics, pop ups) in DataStore "UiSettings_v1" and publishes them as
-- player attributes (SettingMusic / SettingSfx / SettingLowGfx /
-- SettingPopups) - the single source of truth the client scripts read.
-- The client may only ask to flip one of these four known booleans; it
-- cannot touch anything else. These settings carry no progression or
-- purchase data. Loading failure just leaves the defaults.
--------------------------------------------------

local Players = game:GetService("Players")
local DataRetry = require(game:GetService("ServerScriptService"):WaitForChild("DataRetry"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local DEFAULTS = {
	SettingMusic = true,
	SettingSfx = true,
	SettingLowGfx = false,
	SettingPopups = true,
}
local MIN_INTERVAL = 0.25

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local setRemote = remotes:FindFirstChild("SettingSet")
if not setRemote then
	setRemote = Instance.new("RemoteEvent")
	setRemote.Name = "SettingSet"
	setRemote.Parent = remotes
end

local store = DataStoreService:GetDataStore("UiSettings_v1")
local loaded = {} -- [player] = true once the stored values were read (or failed)
local lastSet = {} -- [player] = os.clock()
local dirty = {}

local function apply(player, values)
	for key, default in pairs(DEFAULTS) do
		local v = values and values[key]
		if typeof(v) ~= "boolean" then
			v = default
		end
		player:SetAttribute(key, v)
	end
end

local function save(player)
	if not loaded[player] or not dirty[player] then
		return
	end
	dirty[player] = nil
	local data = {}
	for key in pairs(DEFAULTS) do
		data[key] = player:GetAttribute(key) == true
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), data)
	end)
	if not ok then
		warn("[SettingsService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onJoin(player)
	apply(player, nil) -- defaults immediately so the UI never shows nil
	local ok, data = DataRetry.Get(store, tostring(player.UserId))
	if player.Parent == nil then
		return
	end
	if ok and typeof(data) == "table" and not dirty[player] then
		apply(player, data)
	elseif not ok then
		warn("[SettingsService] load failed for " .. player.Name .. ": " .. tostring(data))
	end
	loaded[player] = ok
end

setRemote.OnServerEvent:Connect(function(player, key, value)
	if typeof(key) ~= "string" or DEFAULTS[key] == nil or typeof(value) ~= "boolean" then
		return
	end
	local now = os.clock()
	if lastSet[player] and now - lastSet[player] < MIN_INTERVAL then
		return
	end
	lastSet[player] = now
	player:SetAttribute(key, value)
	dirty[player] = true
	task.delay(5, function()
		if player.Parent then
			save(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	loaded[player] = nil
	lastSet[player] = nil
	dirty[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)

Players.PlayerAdded:Connect(function(p)
	task.spawn(onJoin, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end