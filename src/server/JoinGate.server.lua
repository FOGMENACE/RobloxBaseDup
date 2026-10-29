--------------------------------------------------
-- JOIN GATE (server)
--
-- A player on a slow connection could roll into the START wall while their
-- loading screen was still up (before their data, world and floor were in).
-- The server now publishes "JoinReady" and RunController refuses to start a
-- run until it is true:
--   * the saved data is loaded (Level attribute, set by PlayerDataService)
--   * the player is placed in their saved world (WorldReady, WorldService)
--   * the client reports its loading screen finished (ClientLoaded remote),
--     or 90 s have passed (so a client that never reports is never trapped)
-- The client's report can only make ITS OWN start possible a little sooner;
-- the data / world checks stay server-side.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CLIENT_TIMEOUT = 90

local remote = Instance.new("RemoteEvent")
remote.Name = "ClientLoaded"
remote.Parent = ReplicatedStorage

local clientLoaded = {} -- [player] = true

local function refresh(player)
	if not player.Parent then
		return
	end
	local ready = clientLoaded[player] == true
		and player:GetAttribute("WorldReady") == true
		and player:GetAttribute("Level") ~= nil
	if player:GetAttribute("JoinReady") ~= ready then
		player:SetAttribute("JoinReady", ready)
	end
end

local function onJoin(player)
	player:SetAttribute("JoinReady", false)

	-- stream the lobby around the spawn pad in early, so the floor is there
	local spawnPad = workspace:FindFirstChild("BallSpawn")
	if spawnPad then
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(spawnPad.Position, 20)
			end)
		end)
	end

	player:GetAttributeChangedSignal("WorldReady"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		refresh(player)
	end)

	task.delay(CLIENT_TIMEOUT, function()
		if player.Parent and not clientLoaded[player] then
			clientLoaded[player] = true
			refresh(player)
		end
	end)
end

remote.OnServerEvent:Connect(function(player)
	if clientLoaded[player] then
		return -- once per session; repeats are ignored
	end
	clientLoaded[player] = true
	refresh(player)
end)

Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do
	onJoin(player)
end

Players.PlayerRemoving:Connect(function(player)
	clientLoaded[player] = nil
end)

print("[JoinGate] READY")
