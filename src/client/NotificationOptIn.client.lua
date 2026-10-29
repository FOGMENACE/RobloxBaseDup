--------------------------------------------------
-- NOTIFICATION OPT-IN (client)
--
-- Right after a player claims today's calendar gift, Roblox's own "get notified" prompt
-- is offered once per session, so they can be reminded when tomorrow's gift is ready.
-- Roblox decides whether the prompt may show (CanPromptOptInAsync) and the player
-- chooses; nothing is sent from here. The reminders themselves are sent with Roblox's
-- Open Cloud notification API (a notification set up in the Creator Dashboard).
--------------------------------------------------

local Players = game:GetService("Players")

-- Switched OFF for now: the game does not offer Roblox's "get notified" prompt. Set to true
-- when the reminders (and their changelog note) are ready to go live.
local NOTIFICATIONS_ENABLED = false
if not NOTIFICATIONS_ENABLED then
	return
end

local player = Players.LocalPlayer

local asked = false

local function offer()
	if asked then
		return
	end
	asked = true

	local ok, service = pcall(function()
		return game:GetService("ExperienceNotificationService")
	end)
	if not ok or not service then
		return
	end

	-- let the claim celebration play first
	task.wait(2.5)

	local canPrompt = false
	pcall(function()
		canPrompt = service:CanPromptOptInAsync()
	end)
	if canPrompt then
		pcall(function()
			service:PromptOptIn()
		end)
	end
end

player:GetAttributeChangedSignal("CalendarClaimedToday"):Connect(function()
	if player:GetAttribute("CalendarClaimedToday") == true
		and (player:GetAttribute("TutorialStep") or 0) >= 11 then -- the day-1 claim ends the tutorial
		task.spawn(offer)
	end
end)
