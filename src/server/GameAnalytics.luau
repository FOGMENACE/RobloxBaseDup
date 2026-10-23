--------------------------------------------------
-- GAME ANALYTICS (SERVER MODULE)
--
-- The ONLY place that calls AnalyticsService. Every event is sent in its
-- own thread inside pcall, so an analytics failure can never break or
-- delay gameplay, saving or a purchase receipt. Nothing here changes any
-- player data; it only reports what the server already did.
--
-- Roblox records these events only from live servers (not Studio). In
-- Studio this module prints "[Analytics]" lines instead of sending.
--
-- Events:
--   Onboarding funnel  TutorialStep 1..12 (GameAnalyticsTracker)
--   Progression        "Rebirth" path, level = rebirth count
--   Economy            "Wins" sources / sinks, amount = ACTUAL balance change
--   Custom             RunFinished, SessionMinutes, SessionRuns,
--                      ProductPurchased, GamePassPurchased, QuestClaimed
--------------------------------------------------

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local GameAnalytics = {}

local IS_STUDIO = RunService:IsStudio()
local FIELD1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name

local TUTORIAL_STEPS = {
	"Roll onto START",
	"Finish first course",
	"Reach max level on X1",
	"First rebirth",
	"Second roll started",
	"Second roll finished",
	"Buy Aftershock",
	"Equip Aftershock",
	"Third roll started",
	"Third roll finished",
	"Daily calendar shown",
	"Tutorial complete",
}

--------------------------------------------------
-- SENDING (rate guard + pcall)
--------------------------------------------------

-- Roblox allows 120 + 20 * CCU requests per minute per server; stay under 80% of that.
local windowStart = os.clock()
local sentThisWindow = 0

local function allowSend()
	local now = os.clock()
	if now - windowStart >= 60 then
		windowStart = now
		sentThisWindow = 0
	end
	local budget = math.floor((120 + 20 * #Players:GetPlayers()) * 0.8)
	if sentThisWindow >= budget then
		return false
	end
	sentThisWindow += 1
	return true
end

local lastWarn = {}

local function send(kind, description, fn)
	if not allowSend() then
		return
	end
	if IS_STUDIO then
		print("[Analytics]", kind, description)
		return
	end
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok and os.clock() - (lastWarn[kind] or -math.huge) > 60 then
			lastWarn[kind] = os.clock()
			warn("[GameAnalytics]", kind, "failed:", err)
		end
	end)
end

local function isLivePlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function fields(value)
	if value == nil then
		return nil
	end
	return { [FIELD1] = tostring(value) }
end

--------------------------------------------------
-- SESSION COUNTERS (cleared by GameAnalyticsTracker on leave)
--------------------------------------------------

local sessions = {}

function GameAnalytics.SessionStart(player)
	if not sessions[player] then
		sessions[player] = { Joined = os.clock(), Runs = 0 }
	end
end

function GameAnalytics.SessionEnd(player)
	local session = sessions[player]
	sessions[player] = nil
	if not session then
		return
	end
	-- the player is already leaving, so log directly (isLivePlayer would refuse)
	local minutes = math.floor((os.clock() - session.Joined) / 6) / 10
	send("Custom", "SessionMinutes " .. player.Name .. " " .. minutes, function()
		AnalyticsService:LogCustomEvent(player, "SessionMinutes", minutes)
	end)
	send("Custom", "SessionRuns " .. player.Name .. " " .. session.Runs, function()
		AnalyticsService:LogCustomEvent(player, "SessionRuns", session.Runs)
	end)
end

--------------------------------------------------
-- ONBOARDING FUNNEL
--------------------------------------------------

function GameAnalytics.OnboardingStep(player, step)
	if not isLivePlayer(player) or typeof(step) ~= "number" or step % 1 ~= 0
		or step < 1 or step > #TUTORIAL_STEPS then
		return
	end
	local name = TUTORIAL_STEPS[step]
	send("Onboarding", player.Name .. " step " .. step .. " " .. name, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

--------------------------------------------------
-- PROGRESSION
--------------------------------------------------

function GameAnalytics.RebirthComplete(player, rebirths)
	if not isLivePlayer(player) or typeof(rebirths) ~= "number" or rebirths < 1 or rebirths % 1 ~= 0 then
		return
	end
	send("Progression", player.Name .. " Rebirth " .. rebirths, function()
		AnalyticsService:LogProgressionCompleteEvent(player, "Rebirth", rebirths, "Rebirth " .. rebirths)
	end)
end

--------------------------------------------------
-- WINS ECONOMY
--
-- Call WinsBefore right before an AddWins / RemoveWins call and
-- WinsChanged right after it. The logged amount is the real balance
-- change (MAX_WINS caps, failed calls and refunds log nothing extra).
--------------------------------------------------

local function getWins(player)
	local ok, wins = pcall(PlayerDataService.GetWins, player)
	return ok and isFiniteNumber(wins) and wins or nil
end

function GameAnalytics.WinsBefore(player)
	return getWins(player)
end

-- Returns the logged change (0 when nothing changed) so a caller can log it later.
function GameAnalytics.WinsDelta(player, before)
	local after = getWins(player)
	if not before or not after then
		return 0, after
	end
	return after - before, after
end

function GameAnalytics.LogWinsDelta(player, delta, after, transactionType, sku)
	if not isLivePlayer(player) or not isFiniteNumber(delta) or delta == 0 or not isFiniteNumber(after) then
		return
	end
	local flow = delta > 0 and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
	local amount = math.abs(delta)
	transactionType = tostring(transactionType or "Gameplay")
	sku = tostring(sku or "None")
	send("Economy", string.format("%s %s Wins %d -> %d %s/%s", player.Name, flow.Name, amount, after, transactionType, sku), function()
		AnalyticsService:LogEconomyEvent(player, flow, "Wins", amount, after, transactionType, sku)
	end)
end

function GameAnalytics.WinsChanged(player, before, transactionType, sku)
	local delta, after = GameAnalytics.WinsDelta(player, before)
	GameAnalytics.LogWinsDelta(player, delta, after, transactionType, sku)
end

--------------------------------------------------
-- RUNS, PURCHASES, QUESTS (custom events)
--------------------------------------------------

function GameAnalytics.RunFinished(player, runOil)
	if not isLivePlayer(player) then
		return
	end
	GameAnalytics.SessionStart(player)
	sessions[player].Runs += 1
	local oil = isFiniteNumber(runOil) and math.max(0, math.floor(runOil)) or 0
	send("Custom", "RunFinished " .. player.Name .. " oil " .. oil, function()
		AnalyticsService:LogCustomEvent(player, "RunFinished", oil)
	end)
end

local loggedPurchases = {}

-- Called only after a receipt is granted. A PurchaseId is logged once per server.
function GameAnalytics.ProductPurchased(player, receiptInfo)
	if not isLivePlayer(player) or typeof(receiptInfo) ~= "table" then
		return
	end
	local purchaseId = receiptInfo.PurchaseId
	if purchaseId == nil or loggedPurchases[purchaseId] then
		return
	end
	loggedPurchases[purchaseId] = true
	local robux = isFiniteNumber(receiptInfo.CurrencySpent) and receiptInfo.CurrencySpent or 0
	local productId = receiptInfo.ProductId
	send("Custom", "ProductPurchased " .. player.Name .. " " .. tostring(productId) .. " R$" .. robux, function()
		AnalyticsService:LogCustomEvent(player, "ProductPurchased", robux, fields(productId))
	end)
end

function GameAnalytics.GamePassPurchased(player, passId)
	if not isLivePlayer(player) then
		return
	end
	send("Custom", "GamePassPurchased " .. player.Name .. " " .. tostring(passId), function()
		AnalyticsService:LogCustomEvent(player, "GamePassPurchased", 1, fields(passId))
	end)
end

function GameAnalytics.QuestClaimed(player, questId)
	if not isLivePlayer(player) then
		return
	end
	send("Custom", "QuestClaimed " .. player.Name .. " " .. tostring(questId), function()
		AnalyticsService:LogCustomEvent(player, "QuestClaimed", 1, fields(questId))
	end)
end

return GameAnalytics
