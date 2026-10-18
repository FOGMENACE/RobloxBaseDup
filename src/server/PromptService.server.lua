--------------------------------------------------
-- PROMPT SERVICE
--
-- SERVER ONLY. Remembers which invitations a player has already
-- answered, so the group / favorite prompts stop once they are done
-- (DataStore "PromptFlags_v1").
--
--   Group    : verified here with Player:IsInGroupAsync (never trusts the
--              client). Done = the player is a member.
--   Favorite : Roblox exposes no reliable server-side check for this, so
--              the client reports the prompt result. It only controls
--              whether the invitation is shown again; it unlocks nothing.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GROUP_ID = 42308423

local store = DataStoreService:GetDataStore("PromptFlags_v1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = remotes
	return created
end

local promptState = getOrCreate("RemoteFunction", "PromptState")
local promptDone = getOrCreate("RemoteEvent", "PromptDone")

local flags = {} -- [player] = { Favorite = bool, Loaded = bool }

local function key(player)
	return "Flags_" .. tostring(player.UserId)
end

local function loadPlayer(player)
	local state = { Favorite = false, Loaded = false }
	flags[player] = state

	local ok, value = pcall(function()
		return store:GetAsync(key(player))
	end)

	if ok then
		-- FavoriteVerified: older "Favorite" flags were wrongly set when a
		-- player pressed No, so they are ignored.
		state.Favorite = typeof(value) == "table" and value.FavoriteVerified == true
		state.Loaded = true
	else
		warn("[PromptService] Load failed:", player.Name, value)
	end
end

local function isGroupMember(player)
	local ok, result = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)

	return ok and result == true
end

promptState.OnServerInvoke = function(player)
	local state = flags[player]
	if not state or not state.Loaded then
		return nil
	end

	return {
		GroupId = GROUP_ID,
		GroupDone = isGroupMember(player),
		FavoriteDone = state.Favorite,
	}
end

promptDone.OnServerEvent:Connect(function(player, kind)
	local state = flags[player]
	if not state or kind ~= "Favorite" or state.Favorite then
		return
	end

	state.Favorite = true

	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				old = typeof(old) == "table" and old or {}
				old.FavoriteVerified = true
				return old
			end)
		end)

		if not ok then
			warn("[PromptService] Save failed:", player.Name, err)
		end
	end)
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	flags[player] = nil
end)

print("[PromptService] READY | group:", GROUP_ID)
