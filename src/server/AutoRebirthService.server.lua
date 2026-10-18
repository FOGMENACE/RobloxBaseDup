--------------------------------------------------
-- AUTO REBIRTH (SERVER ONLY, free feature)
--
-- A per-player on/off switch shown in the Rebirth window. Default OFF.
-- While ON, the server rebirths the player as soon as the normal
-- requirement is met (PlayerDataService.RebirthPlayer re-checks it) and
-- the player is in the lobby (RunState Waiting), so a run is never cut
-- short. The choice is saved ("PlayerSettings_v1") and published as the
-- AutoRebirth player attribute for the UI. The client only sends a
-- boolean; nothing else about the rebirth is client-controlled.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local store = DataStoreService:GetDataStore("PlayerSettings_v1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local toggleRemote = remotes:FindFirstChild("AutoRebirthToggle")
if not toggleRemote then
	toggleRemote = Instance.new("RemoteEvent")
	toggleRemote.Name = "AutoRebirthToggle"
	toggleRemote.Parent = remotes
end

local rebirthRemote = ReplicatedStorage:WaitForChild("RebirthSystem"):WaitForChild("RebirthRemote")

local loaded = {} -- [player] = true once the saved value was read
local lastToggle = {}
local lastAttempt = {}

local function key(player)
	return "u_" .. player.UserId
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("AutoRebirth", false)

	task.spawn(function()
		require(game:GetService("ServerScriptService"):WaitForChild("SessionGate")).Wait(player)

		local ok, value = pcall(function()
			return store:GetAsync(key(player))
		end)

		if player.Parent then
			if ok and typeof(value) == "table" and value.AutoRebirth == true then
				player:SetAttribute("AutoRebirth", true)
			end
			loaded[player] = true
		end
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("AutoRebirth", false)
	loaded[player] = true
end

toggleRemote.OnServerEvent:Connect(function(player, enabled)
	if typeof(enabled) ~= "boolean" or not loaded[player] then
		return
	end

	local now = os.clock()
	if lastToggle[player] and now - lastToggle[player] < 0.5 then
		return
	end
	lastToggle[player] = now

	player:SetAttribute("AutoRebirth", enabled)

	task.spawn(function()
		pcall(function()
			store:SetAsync(key(player), { AutoRebirth = enabled })
		end)
	end)
end)

task.spawn(function()
	while true do
		task.wait(1.5)

		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("AutoRebirth") == true
				and player:GetAttribute("RebirthMaxReached") == true
				and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then

				local now = os.clock()
				if not lastAttempt[player] or now - lastAttempt[player] > 3 then
					lastAttempt[player] = now

					local success, reason = PlayerDataService.RebirthPlayer(player)
					rebirthRemote:FireClient(player, "RebirthResult", success, reason)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	loaded[player] = nil
	lastToggle[player] = nil
	lastAttempt[player] = nil
end)

print("[AutoRebirthService] READY")
