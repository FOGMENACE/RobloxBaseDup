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

local lastAfk = {}
local pending = {}

local function teleport(players, sameServer, reason)
	local options = Instance.new("TeleportOptions")
	if sameServer and game.JobId ~= "" then
		options.ServerInstanceId = game.JobId
	end
	options:SetTeleportData({ Transfer = reason })
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
	local ok, err = teleport({ player }, true, "afk")
	if not ok then
		ok, err = teleport({ player }, false, "afk")
	end
	if not ok then
		warn("[ServerTransfer] AFK rejoin failed:", player.Name, err)
		pending[player] = nil
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	local reason = pending[player]
	if not reason then
		return
	end
	pending[player] = nil
	warn("[ServerTransfer] teleport failed:", player.Name, result, message)
	-- the same server is full / closing: any server of the game instead
	if reason == "afk" and (result == Enum.TeleportResult.GameFull or result == Enum.TeleportResult.GameEnded) then
		pending[player] = reason
		teleport({ player }, false, reason)
	end
end)

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
			if not inLobby(p) or pending[p] then
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
	pending[player] = nil
end)