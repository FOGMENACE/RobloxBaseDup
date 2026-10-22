--------------------------------------------------
-- ADMIN SERVICE (SERVER ONLY)
--
-- One RemoteFunction, "AdminCommand", takes a text command. The server:
--   1. checks the caller's UserId against AdminConfig.Admins (never
--      trusts client claims),
--   2. rate-limits, length-limits and parses the text with a fixed
--      command table (no loadstring, no eval, no free-form execution),
--   3. logs every command (print + DataStore "AdminLog_v1").
--
-- Commands:  help | whoami | find <text> | inspect <name|userid>
--            kick <name> [reason] | goto <name> | bring <name>
--            reset <userid> [dry] | confirm <code> | cancel
--
-- RESET (progression only, one explicit UserId):
--   "reset 123" shows what would be reset and returns a one-time code
--   valid for AdminConfig.ConfirmSeconds; "confirm <code>" runs it.
--   "reset 123 dry" only previews. A backup of the old data is written to
--   DataStore "PlayerDataBackup_v1" first; if the backup fails nothing is
--   changed. Developer Product receipt records are NOT touched.
--   Online target: data reset in memory and saved. Offline target: the
--   stored record is replaced atomically. Other servers are told through
--   MessagingService to drop that player's stale session WITHOUT saving.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")

local AdminConfig = require(ServerScriptService:WaitForChild("AdminConfig"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local logStore = DataStoreService:GetDataStore("AdminLog_v1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local commandRemote = remotes:FindFirstChild("AdminCommand")
if not commandRemote then
	commandRemote = Instance.new("RemoteFunction")
	commandRemote.Name = "AdminCommand"
	commandRemote.Parent = remotes
end

local TOPIC = "AdminReset_v1"
local MAX_COMMAND_LENGTH = 120
local COOLDOWN = 0.4

local lastCommand = {} -- [player] = os.clock()
local pending = {} -- [player] = { Code, UserId, Name, Time }

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function isAdmin(player)
	return player ~= nil and typeof(player) == "Instance" and player:IsA("Player")
		and AdminConfig.Admins[player.UserId] ~= nil
end

local function log(admin, action, target, result)
	print(string.format("[Admin] %s (%d) | %s | %s | %s", admin.Name, admin.UserId, action, tostring(target), tostring(result)))

	task.spawn(function()
		pcall(function()
			logStore:UpdateAsync(os.date("!%Y-%m-%d", os.time()), function(list)
				list = typeof(list) == "table" and list or {}
				if #list >= 400 then
					table.remove(list, 1)
				end
				table.insert(list, {
					Admin = admin.UserId,
					Action = action,
					Target = tostring(target),
					Result = tostring(result),
					Time = os.time(),
				})
				return list
			end)
		end)
	end)
end

-- name (case-insensitive prefix of Name or DisplayName) or numeric id
local function findPlayer(text)
	if typeof(text) ~= "string" or text == "" then
		return nil
	end

	local id = tonumber(text)
	if id then
		return Players:GetPlayerByUserId(id)
	end

	local lower = text:lower()
	local match
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.Name:lower() == lower or candidate.DisplayName:lower() == lower then
			return candidate
		end
		if not match and (candidate.Name:lower():sub(1, #lower) == lower or candidate.DisplayName:lower():sub(1, #lower) == lower) then
			match = candidate
		end
	end
	return match
end

local function summary(data)
	if typeof(data) ~= "table" then
		return "no saved data"
	end

	local balls = 0
	for _ in pairs(data.OwnedBalls or {}) do
		balls += 1
	end

	return string.format(
		"Level %s (global %s) | Strike/Reach level %s | Wins %s | Rebirths %s | Oil %s | Balls %d | Equipped %s",
		tostring(data.Level), tostring(data.GlobalLevel), tostring(data.RebirthLevelRequirement), tostring(data.Wins),
		tostring(data.Rebirths), tostring(data.CurrentOil), balls, tostring(data.EquippedBall)
	)
end

--------------------------------------------------
-- COMMANDS
--------------------------------------------------

local commands = {}

commands.help = function()
	return true, table.concat({
		"help | whoami | find <text> | inspect <name|userid>",
		"kick <name> [reason] | ban <name|id> [reason] | unban <id> | banlist",
		"goto <name> | bring <name>",
		"give <name> wins|oil <amount> | grant <name> ball <id> | grant <name> skin <ballId> <world>",
		"feedback [YYYY-MM-DD | days ago] | flags [YYYY-MM-DD | days ago] | history <name|userid>",
		"reset <userid> [dry]  then  confirm <code>  (progression reset, backed up)",
		"cancel",
	}, "\n")
end

--------------------------------------------------
-- SUPPORT / REVIEW COMMANDS
--------------------------------------------------

local ServerStorage = game:GetService("ServerStorage")

-- "2026-10-22", "3" (days ago) or nothing (today), always UTC like the stores
local function dayKey(arg)
	if typeof(arg) == "string" and arg:match("^%d%d%d%d%-%d%d%-%d%d$") then
		return arg
	end
	local daysAgo = tonumber(arg or "0") or 0
	return os.date("!%Y-%m-%d", os.time() - math.clamp(math.floor(daysAgo), 0, 60) * 86400)
end

local function clock(t)
	return os.date("!%m-%d %H:%M", t or 0)
end

commands.give = function(_, args)
	local target = findPlayer(args[1])
	local what = (args[2] or ""):lower()
	local amount = tonumber(args[3] or "")
	if not target or (what ~= "wins" and what ~= "oil") or not amount then
		return false, "usage: give <name> wins|oil <amount>   (online players only)"
	end
	amount = math.floor(amount)
	if amount <= 0 or amount > (AdminConfig.MaxGrant or 1e7) then
		return false, "amount must be 1 .. " .. tostring(AdminConfig.MaxGrant or 1e7)
	end
	local ok = what == "wins" and PlayerDataService.AddWins(target, amount) or PlayerDataService.AddOil(target, amount)
	if not ok then
		return false, "grant failed (data not loaded?)"
	end
	PlayerDataService.SavePlayer(target)
	return true, string.format("gave %s %d %s", target.Name, amount, what)
end

commands.grant = function(_, args)
	local target = findPlayer(args[1])
	local what = (args[2] or ""):lower()
	local ballId = args[3]
	if not target or not ballId or not PlayerDataService.IsValidBallId(ballId) then
		return false, "usage: grant <name> ball <BallId> | grant <name> skin <BallId> <world 2-4>   (exact BallId, online only)"
	end
	if what == "ball" then
		if PlayerDataService.OwnsBall(target, ballId) then
			return false, target.Name .. " already owns " .. ballId
		end
		if not PlayerDataService.AddOwnedBall(target, ballId) then
			return false, "grant failed"
		end
		PlayerDataService.SavePlayer(target)
		return true, "granted ball " .. ballId .. " to " .. target.Name
	elseif what == "skin" then
		local worldId = tonumber(args[4] or "")
		local hook = ServerStorage:FindFirstChild("SkinService") and ServerStorage.SkinService:FindFirstChild("GrantSkin")
		if not worldId or not hook then
			return false, "usage: grant <name> skin <BallId> <world 2-4>"
		end
		local ok, message = hook:Invoke(target, ballId, worldId)
		return ok == true, tostring(message)
	end
	return false, "grant what? ball or skin"
end

commands.feedback = function(_, args)
	local day = dayKey(args[1])
	local ok, list = pcall(function()
		return DataStoreService:GetDataStore("Feedback_v1"):GetAsync(day)
	end)
	if not ok then
		return false, "could not read feedback"
	end
	if typeof(list) ~= "table" or #list == 0 then
		return true, "no feedback on " .. day
	end
	local lines = { string.format("%d message(s) on %s (newest first):", #list, day) }
	for index = #list, math.max(1, #list - 14), -1 do
		local e = list[index]
		table.insert(lines, string.format("%s  %s R%s: %s", clock(e.Time), tostring(e.Name), tostring(e.Rebirths), tostring(e.Text)))
	end
	return true, table.concat(lines, "\n")
end

commands.flags = function(_, args)
	local day = dayKey(args[1])
	local ok, list = pcall(function()
		return DataStoreService:GetDataStore("Flags_v1"):GetAsync(day)
	end)
	if not ok then
		return false, "could not read flags"
	end
	if typeof(list) ~= "table" or #list == 0 then
		return true, "no flags on " .. day
	end
	local lines = { string.format("%d flag(s) on %s (newest first). Review with: history <userid>", #list, day) }
	for index = #list, math.max(1, #list - 19), -1 do
		local e = list[index]
		table.insert(lines, string.format("%s  %s (%s) %s %s", clock(e.Time), tostring(e.Name), tostring(e.UserId), tostring(e.Kind), tostring(e.Detail)))
	end
	return true, table.concat(lines, "\n")
end

commands.history = function(_, args)
	local target = findPlayer(args[1])
	local id = target and target.UserId or tonumber(args[1] or "")
	if not id then
		return false, "usage: history <name|userid>"
	end
	local ok, list = pcall(function()
		return DataStoreService:GetDataStore("ProgressHistory_v1"):GetAsync("u_" .. id)
	end)
	if not ok then
		return false, "could not read history"
	end
	if typeof(list) ~= "table" or #list == 0 then
		return true, "no snapshots yet for " .. id .. " (one is saved every 5 minutes and on leave)"
	end
	local lines = { string.format("%d snapshot(s) for %d (UTC, newest first):", #list, id) }
	for index = #list, math.max(1, #list - 14), -1 do
		local s = list[index]
		table.insert(lines, string.format("%s  wins %s  rebirths %s  level %s  global %s  oil %s  session %sm",
			clock(s.T), tostring(s.Wins), tostring(s.Rebirths), tostring(s.Level), tostring(s.Global), tostring(s.Oil), tostring(s.Session)))
	end
	return true, table.concat(lines, "\n")
end

commands.whoami = function(admin)
	return true, string.format("%s (%d) - admin: %s", admin.Name, admin.UserId, tostring(AdminConfig.Admins[admin.UserId]))
end

commands.find = function(_, args)
	local needle = (args[1] or ""):lower()
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if needle == "" or p.Name:lower():find(needle, 1, true) or p.DisplayName:lower():find(needle, 1, true) then
			table.insert(out, string.format("%s (@%s) id=%d state=%s", p.DisplayName, p.Name, p.UserId, tostring(p:GetAttribute("RunState"))))
		end
	end
	return true, #out > 0 and table.concat(out, "\n") or "no match"
end

commands.inspect = function(admin, args)
	local target = findPlayer(args[1])
	if target then
		local data = PlayerDataService.GetData(target)
		return true, string.format("%s (%d) ONLINE\n%s", target.Name, target.UserId, summary(data))
	end

	local id = tonumber(args[1] or "")
	if not id then
		return false, "usage: inspect <name|userid>"
	end

	local data, err = PlayerDataService.AdminRead(id)
	if err then
		return false, "could not read: " .. tostring(err)
	end
	return true, string.format("%d OFFLINE (stored)\n%s", id, summary(data))
end

commands.kick = function(admin, args)
	local target = findPlayer(args[1])
	if not target then
		return false, "player not found"
	end
	if target == admin then
		return false, "you cannot kick yourself"
	end
	if isAdmin(target) then
		return false, "cannot kick another admin"
	end

	local reason = table.concat(args, " ", 2)
	target:Kick(reason ~= "" and reason:sub(1, 100) or "Removed by an admin.")
	return true, "kicked " .. target.Name
end

local function ballOf(player)
	local ball = workspace.PlayerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
	return ball and ball:IsA("BasePart") and ball or nil
end

local function lobbyOnly(player)
	return (player:GetAttribute("RunState") or "Waiting") == "Waiting"
end

commands.goto = function(admin, args)
	local target = findPlayer(args[1])
	local mine, theirs = ballOf(admin), target and ballOf(target)
	if not (target and mine and theirs) then
		return false, "player or ball not found"
	end
	if not (lobbyOnly(admin) and lobbyOnly(target)) then
		return false, "both players must be in the lobby"
	end
	mine.CFrame = theirs.CFrame + Vector3.new(4, 1, 0)
	return true, "teleported to " .. target.Name
end

commands.bring = function(admin, args)
	local target = findPlayer(args[1])
	local mine, theirs = ballOf(admin), target and ballOf(target)
	if not (target and mine and theirs) then
		return false, "player or ball not found"
	end
	if not (lobbyOnly(admin) and lobbyOnly(target)) then
		return false, "both players must be in the lobby"
	end
	theirs.CFrame = mine.CFrame + Vector3.new(4, 1, 0)
	theirs.AssemblyLinearVelocity = Vector3.zero
	return true, "brought " .. target.Name
end

--------------------------------------------------
-- BANS (persistent, DataStore "AdminBans_v1", key = UserId)
-- ban <userid|name> [reason]   unban <userid>   banlist
-- Admins cannot be banned. A banned player is kicked now and again on
-- every join (any server). Banning an online player uses the name or id;
-- an offline player needs the numeric id.
--------------------------------------------------

local banStore = DataStoreService:GetDataStore("AdminBans_v1")

local function banReason(id)
	local ok, entry = pcall(function()
		return banStore:GetAsync("u_" .. tostring(id))
	end)
	if ok and typeof(entry) == "table" then
		return entry.Reason or "Banned"
	end
	return nil
end

commands.ban = function(admin, args)
	local target = findPlayer(args[1])
	local id = target and target.UserId or tonumber(args[1] or "")
	if not id or id <= 0 or id % 1 ~= 0 then
		return false, "usage: ban <name|userid> [reason]"
	end
	if AdminConfig.Admins[id] then
		return false, "cannot ban an admin"
	end

	local reason = table.concat(args, " ", 2)
	if reason == "" then
		reason = "Banned by an admin."
	end
	reason = reason:sub(1, 100)

	local ok = pcall(function()
		banStore:SetAsync("u_" .. tostring(id), { Reason = reason, By = admin.UserId, Time = os.time() })
	end)
	if not ok then
		return false, "ban could not be saved"
	end

	if target then
		target:Kick("Banned: " .. reason)
	end
	return true, string.format("banned %d (%s)", id, reason)
end

commands.unban = function(_, args)
	local id = tonumber(args[1] or "")
	if not id then
		return false, "usage: unban <userid>"
	end

	local ok = pcall(function()
		banStore:RemoveAsync("u_" .. tostring(id))
	end)
	return ok, ok and ("unbanned " .. id) or "unban failed"
end

commands.banlist = function()
	local lines = {}
	local ok = pcall(function()
		local pages = banStore:ListKeysAsync("u_")
		for _, key in ipairs(pages:GetCurrentPage()) do
			table.insert(lines, key.KeyName)
		end
	end)
	if not ok then
		return false, "could not list bans"
	end
	return true, #lines > 0 and table.concat(lines, "\n") or "no bans"
end

Players.PlayerAdded:Connect(function(player)
	if AdminConfig.Admins[player.UserId] then
		return
	end
	local reason = banReason(player.UserId)
	if reason and player.Parent then
		player:Kick("Banned: " .. reason)
	end
end)

commands.cancel = function(admin)
	pending[admin] = nil
	return true, "pending action cancelled"
end

commands.reset = function(admin, args)
	local id = tonumber(args[1] or "")
	if not id or id <= 0 or id % 1 ~= 0 then
		return false, "usage: reset <numeric userid> [dry]"
	end

	if AdminConfig.ResetAllowList and not AdminConfig.ResetAllowList[id] then
		return false, "that UserId is not on AdminConfig.ResetAllowList"
	end

	local online = Players:GetPlayerByUserId(id)
	local data = online and PlayerDataService.GetData(online)
	if not data then
		local stored, err = PlayerDataService.AdminRead(id)
		if err then
			return false, "could not read saved data: " .. tostring(err)
		end
		data = stored
	end

	local description = string.format("%d (%s)\nNOW: %s", id, online and ("online as " .. online.Name) or "offline", summary(data))

	if args[2] == "dry" then
		return true, "DRY RUN - nothing changed.\n" .. description .. "\nWOULD BECOME: Level 1, global level 1, Strike/Reach level 65 (base), 0 wins, 0 rebirths, 0 oil, StraightBall only, auto-rebirth off"
	end

	local code = tostring(math.random(1000, 9999))
	pending[admin] = { Code = code, UserId = id, Time = os.clock() }

	return true, string.format(
		"RESET PROGRESSION for %s\nBackup is written first. Type:  confirm %s   (within %ds) or  cancel",
		description, code, AdminConfig.ConfirmSeconds
	)
end

commands.confirm = function(admin, args)
	local action = pending[admin]
	if not action or os.clock() - action.Time > AdminConfig.ConfirmSeconds then
		pending[admin] = nil
		return false, "nothing to confirm (expired or never requested)"
	end
	if args[1] ~= action.Code then
		return false, "wrong code"
	end
	pending[admin] = nil

	local id = action.UserId
	local online = Players:GetPlayerByUserId(id)
	local ok, detail
	local beforeSummary = summary(online and PlayerDataService.GetData(online) or PlayerDataService.AdminRead(id))

	if online then
		ok, detail = PlayerDataService.AdminResetOnline(online)
	else
		ok, detail = PlayerDataService.AdminResetOffline(id)
	end

	if not ok then
		log(admin, "reset", id, "FAILED " .. tostring(detail))
		return false, "reset FAILED (nothing was lost): " .. tostring(detail)
	end

	-- Tell every other server to drop a stale session for this user.
	pcall(function()
		MessagingService:PublishAsync(TOPIC, HttpService:JSONEncode({ UserId = id, JobId = game.JobId }))
	end)

	-- The auto-rebirth switch lives in its own store; a reset turns it off.
	pcall(function()
		DataStoreService:GetDataStore("PlayerSettings_v1"):SetAsync("u_" .. id, { AutoRebirth = false })
	end)
	if online then
		online:SetAttribute("AutoRebirth", false)
	end

	-- the tutorial starts again from step 1
	local tutorialReset = game:GetService("ServerScriptService"):FindFirstChild("TutorialReset")
	if tutorialReset then
		tutorialReset:Fire(id)
	end

	-- Read the result back so the admin sees what is really stored now.
	local after = online and PlayerDataService.GetData(online) or PlayerDataService.AdminRead(id)

	log(admin, "reset", id, "OK backup=" .. tostring(detail))
	return true, "RESET done for " .. id .. ". Backup key: " .. tostring(detail) .. "\nBEFORE: " .. beforeSummary .. "\nNOW:    " .. summary(after)
end

--------------------------------------------------
-- REMOTE
--------------------------------------------------

commandRemote.OnServerInvoke = function(player, text)
	if not isAdmin(player) then
		return false, "not allowed" -- no hint about what exists
	end

	if typeof(text) ~= "string" or #text == 0 or #text > MAX_COMMAND_LENGTH then
		return false, "invalid command"
	end

	local now = os.clock()
	if lastCommand[player] and now - lastCommand[player] < COOLDOWN then
		return false, "slow down"
	end
	lastCommand[player] = now

	-- tokens: letters, digits, basic punctuation only
	local cleaned = text:gsub("[^%w%s_%-%.@']", "")
	local tokens = {}
	for token in cleaned:gmatch("%S+") do
		table.insert(tokens, token)
	end

	local name = table.remove(tokens, 1)
	local handler = name and commands[name:lower()]
	if not handler then
		return false, "unknown command - type help"
	end

	local ok, success, message = pcall(handler, player, tokens)
	if not ok then
		warn("[AdminService] command error:", success)
		return false, "command error"
	end

	local readOnly = { help = true, whoami = true, find = true, inspect = true, banlist = true, feedback = true, flags = true, history = true }
	if not readOnly[name:lower()] then
		log(player, name:lower(), table.concat(tokens, " "), success)
	end

	return success, message
end

--------------------------------------------------
-- STALE-SESSION GUARD (other servers)
--------------------------------------------------

task.spawn(function()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local decoded = nil
			pcall(function()
				decoded = HttpService:JSONDecode(message.Data)
			end)

			if typeof(decoded) ~= "table" or decoded.JobId == game.JobId or typeof(decoded.UserId) ~= "number" then
				return
			end

			local victim = Players:GetPlayerByUserId(decoded.UserId)
			if victim then
				PlayerDataService.AdminForget(victim) -- do NOT save stale data
				victim:Kick("Your progress was reset by an admin. Rejoin to continue.")
			end
		end)
	end)

	if not ok then
		warn("[AdminService] MessagingService unavailable (fine in Studio):", err)
	end
end)

-- Admins get a display-only attribute so the console UI knows to appear.
-- It grants nothing: every command is re-checked above.
local function mark(player)
	player:SetAttribute("IsAdmin", isAdmin(player))
end

Players.PlayerAdded:Connect(mark)
for _, player in ipairs(Players:GetPlayers()) do
	mark(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastCommand[player] = nil
	pending[player] = nil
end)

print("[AdminService] READY")
