--------------------------------------------------
-- CONNECTION WATCH (client)
--
-- A very weak connection leaves the game half-broken: sounds and models fail to
-- download, loading never finishes. Reloading over a fresh connection fixes it, so when
-- the signs are clear this asks the server (Remotes.ConnectionRejoin) to move the player
-- back into the same server. The server owns the decision (cooldown, cap per session) and
-- shows the "moving you" loading screen (PromptManager); nothing here teleports.
--
-- Signs, each deliberately strict so a normal hiccup never triggers it:
--   1. network-class download failures (SslConnectFail, ConnectFail, TimedOut, DnsResolve,
--      NetFail) for MANY different assets inside a short window. One missing / removed
--      asset never counts: a reload could not fix that.
--   2. ping stuck above PING_LIMIT ms for PING_SECONDS in a row.
--   3. the loading screen still up after LOAD_LIMIT seconds.
-- It waits until the player is in the lobby, never in the middle of a run.
--------------------------------------------------

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer

local FAIL_COUNT = 6 -- different assets failing ...
local FAIL_WINDOW = 40 -- ... within this many seconds
local PING_LIMIT = 2000 -- ms
local PING_SECONDS = 30
local LOAD_LIMIT = 110 -- seconds the loading screen may stay up (LoadingBoot itself gives up at 120)

local NETWORK_ERRORS = { "SslConnectFail", "ConnectFail", "TimedOut", "DnsResolve", "NetFail" }
local ASSET_FAILURES = { "Failed to load sound", "MeshContentProvider failed", "Failed to load", "could not fetch" }

local function contains(text, list)
	for _, needle in ipairs(list) do
		if string.find(text, needle, 1, true) then
			return true
		end
	end
	return false
end

local failures = {} -- [message] = os.clock() it was last seen
local reason = nil

LogService.MessageOut:Connect(function(message, messageType)
	if reason or messageType ~= Enum.MessageType.MessageWarning and messageType ~= Enum.MessageType.MessageError then
		return
	end
	if not contains(message, ASSET_FAILURES) then
		return
	end
	-- "could not fetch" has no error name: it only counts together with the network-class ones
	if string.find(message, "could not fetch", 1, true) or contains(message, NETWORK_ERRORS) then
		failures[message] = os.clock()
	end
end)

local function failingAssets()
	local now, count = os.clock(), 0
	for message, seen in pairs(failures) do
		if now - seen > FAIL_WINDOW then
			failures[message] = nil
		else
			count += 1
		end
	end
	return count
end

local function ping()
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return ok and value or 0
end

local function inLobby()
	local state = player:GetAttribute("RunState")
	return state == nil or state == "" or state == "Waiting"
end

local started = os.clock()
local slowSince = nil

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ConnectionRejoin")
local lastAsk = -math.huge
local asks = 0
local MAX_ASKS = 3 -- per session; the server also caps real moves (2 per session, 5 min apart)

task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()

		if ping() > PING_LIMIT then
			slowSince = slowSince or now
		else
			slowSince = nil
		end

		if failingAssets() >= FAIL_COUNT then
			reason = "downloads"
		elseif slowSince and now - slowSince >= PING_SECONDS then
			reason = "ping"
		elseif player:GetAttribute("LoadingDone") ~= true and now - started >= LOAD_LIMIT then
			reason = "loading"
		else
			reason = nil
		end

		-- loading that never finishes is asked for right away; the rest wait for the lobby
		if reason and (reason == "loading" or inLobby()) and now - lastAsk > 120 and asks < MAX_ASKS and not RunService:IsStudio() then
			lastAsk = now
			asks += 1
			warn("[ConnectionWatch] weak connection (" .. reason .. "), asking to be moved back in")
			remote:FireServer()
			failures = {}
			slowSince = nil
		elseif reason and RunService:IsStudio() and now - lastAsk > 60 then
			lastAsk = now
			warn("[ConnectionWatch] would ask to be moved (" .. reason .. ") - not in Studio")
		end
	end
end)
