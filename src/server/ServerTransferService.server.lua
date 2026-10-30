--------------------------------------------------
-- SERVER TRANSFER SERVICE (SERVER)
--
-- 1. AFK: Roblox disconnects players after 20 minutes without real input and
--    game scripts cannot fake input (VirtualUser lacks the LocalUser
--    capability, verified). So before the limit the client quietly asks
--    (Remotes.AfkRejoin, with its branded loading screen already set) and the
--    player is re-teleported into this SAME server, keeping friends together.
-- 2. LAGGY SERVER: if this server's frame rate stays very low, players in the
--    lobby are moved to a fresh server in FRIEND GROUPS (one TeleportAsync
--    per group keeps a group together). Players mid-run are moved after it.
--
-- Data: PlayerRemoving saves, and PlayerDataService's session lock makes the
-- next server wait for that save, so nothing is lost.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local AFK_COOLDOWN = 120
local LAG_FPS = 20 -- server heartbeat FPS considered "very laggy"
local LAG_WINDOWS = 4 -- consecutive 30 s windows below LAG_FPS before moving
local LAG_RETRY = 600 -- seconds before another move attempt

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local function remote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local afkRejoin = remote("AfkRejoin")
local transferNotice = remote("ServerTransferNotice") -- server -> client: show loading screen
local connectionRejoin = remote("ConnectionRejoin") -- client -> server: weak connection, move me

local lastAfk = {}
local pending = {}
local lastConnection = {}

-- Rejoin attempts already used by this player's session lineage (carried in the teleport data),
-- so a connection that never recovers cannot loop forever.
local MAX_CONNECTION_RETRIES = 2
local CONNECTION_COOLDOWN = 90
-- after ARRIVING through one of these rejoins the player gets this long to just play before
-- another may happen (the reload itself re-downloads everything and can look "weak" again)
local ARRIVAL_GRACE = 300
local joinedAt = {}
Players.PlayerAdded:Connect(function(player)
	joinedAt[player] = os.clock()
end)
for _, player in ipairs(Players:GetPlayers()) do
	joinedAt[player] = os.clock()
end
local function connectionAttempts(player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = ok and joinData and joinData.TeleportData
	if typeof(data) == "table" and typeof(data.ConnAttempt) == "number" then
		return math.clamp(data.ConnAttempt, 0, 10)
	end
	return 0
end

local function teleport(players, sameServer, reason, attempt)
	local options = Instance.new("TeleportOptions")
	if sameServer and game.JobId ~= "" then
		options.ServerInstanceId = game.JobId
	end
	options:SetTeleportData({ Transfer = reason, ConnAttempt = attempt or 0 })
	return pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
end

--------------------------------------------------
-- AFK REJOIN
--------------------------------------------------

afkRejoin.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if pending[player] or (lastAfk[player] and now - lastAfk[player] < AFK_COOLDOWN) then
		return
	end
	lastAfk[player] = now
	if RunService:IsStudio() then
		print("[ServerTransfer] AFK rejoin requested by", player.Name, "(teleports do not run in Studio)")
		return
	end
	pending[player] = "afk"
	local ok, err = teleport({ player }, true, "afk", connectionAttempts(player))
	if not ok then
		ok, err = teleport({ player }, false, "afk", connectionAttempts(player))
	end
	if not ok then
		warn("[ServerTransfer] AFK rejoin failed:", player.Name, err)
		pending[player] = nil
	end
end)

--------------------------------------------------
-- WEAK CONNECTION REJOIN
--
-- The client (ConnectionWatch) asks for this when its connection is clearly bad: assets and
-- sounds failing to download, a very high ping for a long time, or loading that never finishes.
-- The player is moved back into THIS server (any server if it is full or closed) with the
-- branded loading screen, which reloads everything over a fresh connection. The client only
-- asks; this side decides (cooldown, a cap per session, never in Studio).
--------------------------------------------------

connectionRejoin.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if pending[player] or (lastConnection[player] and now - lastConnection[player] < CONNECTION_COOLDOWN) then
		return
	end
	local attempt = connectionAttempts(player)
	if attempt >= MAX_CONNECTION_RETRIES then
		return
	end
	if attempt > 0 and now - (joinedAt[player] or now) < ARRIVAL_GRACE then
		return
	end
	lastConnection[player] = now
	if RunService:IsStudio() then
		print("[ServerTransfer] connection rejoin requested by", player.Name, "(teleports do not run in Studio)")
		return
	end
	pending[player] = "connection"
	transferNotice:FireClient(player, "Weak connection - moving you back into your server...")
	task.delay(1.5, function()
		if not player.Parent then
			return
		end
		local ok = teleport({ player }, true, "connection", attempt + 1)
		if not ok then
			ok = teleport({ player }, false, "connection", attempt + 1)
		end
		if not ok then
			warn("[ServerTransfer] connection rejoin failed:", player.Name)
			pending[player] = nil
		end
	end)
end)

-- players whose ONE fallback retry was already used: a failure after that is final
-- (it used to retry on every failure with no limit, which can end in Roblox's
-- "too many teleport requests" block)
local retried = {}

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	local reason = pending[player]
	if not reason then
		return
	end
	pending[player] = nil
	warn("[ServerTransfer] teleport failed:", player.Name, result, message)
	-- the same server is full / closing: any server of the game instead, ONCE
	if not retried[player] and (reason == "afk" or reason == "connection")
		and (result == Enum.TeleportResult.GameFull or result == Enum.TeleportResult.GameEnded) then
		retried[player] = true
		pending[player] = reason
		teleport({ player }, false, reason, connectionAttempts(player) + (reason == "connection" and 1 or 0))
	end
end)

-- arrived through a lag move recently: not moved again (it could land back on this server)
local function arrivedByLagMove(player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = ok and joinData and joinData.TeleportData
	return typeof(data) == "table" and data.Transfer == "lag"
		and os.clock() - (joinedAt[player] or 0) < LAG_RETRY
end

--------------------------------------------------
-- LAGGY SERVER -> MOVE IN FRIEND GROUPS
--------------------------------------------------

local function friendGroups(list)
	local parent = {}
	local function find(p)
		while parent[p] ~= p do
			parent[p] = parent[parent[p]]
			p = parent[p]
		end
		return p
	end
	for _, p in ipairs(list) do
		parent[p] = p
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local ok, friends = pcall(function()
				return list[i]:IsFriendsWith(list[j].UserId)
			end)
			if ok and friends then
				parent[find(list[i])] = find(list[j])
			end
		end
	end
	local groups = {}
	for _, p in ipairs(list) do
		local root = find(p)
		groups[root] = groups[root] or {}
		table.insert(groups[root], p)
	end
	return groups
end

local function inLobby(p)
	local state = p:GetAttribute("RunState")
	return state == nil or state == "" or state == "Waiting"
end

local function moveServer()
	local groups = friendGroups(Players:GetPlayers())
	for _, group in pairs(groups) do
		local ready = true
		for _, p in ipairs(group) do
			if not inLobby(p) or pending[p] or arrivedByLagMove(p) then
				ready = false
			end
		end
		if ready then
			for _, p in ipairs(group) do
				pending[p] = "lag"
				transferNotice:FireClient(p, "This server is lagging - moving you and your friends to a smoother one...")
			end
			task.delay(2.5, function()
				local alive = {}
				for _, p in ipairs(group) do
					if p.Parent then
						table.insert(alive, p)
					end
				end
				if #alive > 0 then
					local ok, err = teleport(alive, false, "lag")
					if not ok then
						warn("[ServerTransfer] lag move failed:", err)
						for _, p in ipairs(alive) do
							pending[p] = nil
						end
					end
				end
			end)
		end
	end
end

task.spawn(function()
	local frames, slow, lastMove = 0, 0, -math.huge
	RunService.Heartbeat:Connect(function()
		frames += 1
	end)
	while true do
		frames = 0
		task.wait(30)
		local fps = frames / 30
		slow = (fps < LAG_FPS) and slow + 1 or 0
		if slow >= LAG_WINDOWS and not RunService:IsStudio() and os.clock() - lastMove > LAG_RETRY and #Players:GetPlayers() > 0 then
			warn(string.format("[ServerTransfer] server FPS %.1f for %d windows, moving players", fps, slow))
			lastMove = os.clock()
			moveServer()
		elseif slow >= LAG_WINDOWS and os.clock() - lastMove <= LAG_RETRY and os.clock() - lastMove > 60 then
			moveServer() -- pick up players who were mid-run last time
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAfk[player] = nil
	lastConnection[player] = nil
	joinedAt[player] = nil
	pending[player] = nil
	retried[player] = nil
end)