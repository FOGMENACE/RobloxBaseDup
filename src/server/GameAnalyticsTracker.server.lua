--------------------------------------------------
-- GAME ANALYTICS TRACKER (SERVER)
--
-- Reports what other services already decided, by watching server-set
-- player attributes. It never writes player data or attributes.
--
--   Onboarding funnel  only for players whose FIRST TutorialStep this
--                      session is 1 (with 0 rebirths), then one step at a
--                      time. Players loading at a saved / veteran / fallback
--                      step are never logged, so no earlier step is assumed.
--   Rebirths           every increase of the Rebirths attribute (the saved
--                      value at join is ignored).
--   Sessions           minutes and runs, logged when the player leaves.
--   Game passes        after Roblox confirms ownership, once per pass.
--------------------------------------------------

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local GameAnalytics = require(ServerScriptService:WaitForChild("GameAnalytics"))
local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

-- [player] = last logged tutorial step, or false = not tracked this session
local funnel = {}
-- [player] = last seen Rebirths value
local lastRebirths = {}
-- [player] = { [passId] = true }
local loggedPasses = {}

local function onTutorialStep(player)
	local step = player:GetAttribute("TutorialStep")
	if typeof(step) ~= "number" then
		return
	end
	local last = funnel[player]
	if last == nil then
		-- first value this session (TutorialService publishes it once after loading)
		if step == 1 and PlayerDataService.GetRebirths(player) == 0 then
			funnel[player] = 1
			GameAnalytics.OnboardingStep(player, 1)
		else
			funnel[player] = false
		end
	elseif last and step == last + 1 then
		funnel[player] = step
		GameAnalytics.OnboardingStep(player, step)
	elseif last and step ~= last then
		-- a jump or a reset (admin reset, rewind): stop, never infer steps
		funnel[player] = false
	end
end

local function onRebirths(player)
	local now = player:GetAttribute("Rebirths")
	local last = lastRebirths[player]
	if typeof(now) ~= "number" then
		return
	end
	lastRebirths[player] = now
	if typeof(last) == "number" and now > last then
		-- one progression event per rebirth reached (a grant can add more than one)
		for n = last + 1, math.min(now, last + 5) do
			GameAnalytics.RebirthComplete(player, n)
		end
	end
end

local function onPlayerAdded(player)
	GameAnalytics.SessionStart(player)
	loggedPasses[player] = {}

	player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		onTutorialStep(player)
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		onRebirths(player)
	end)

	-- values already published before this script connected
	onTutorialStep(player)
	lastRebirths[player] = player:GetAttribute("Rebirths")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	GameAnalytics.SessionEnd(player)
	funnel[player] = nil
	lastRebirths[player] = nil
	loggedPasses[player] = nil
end)

-- Game passes: do not trust `purchased`; ask Roblox before logging.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased or typeof(passId) ~= "number" then
		return
	end
	local logged = loggedPasses[player]
	if not logged or logged[passId] then
		return
	end
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns == true and loggedPasses[player] and not loggedPasses[player][passId] then
			loggedPasses[player][passId] = true
			GameAnalytics.GamePassPurchased(player, passId)
		end
	end)
end)
