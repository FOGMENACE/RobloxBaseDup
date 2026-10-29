--------------------------------------------------
-- CHAT ANNOUNCEMENTS (client, display only)
--
-- Shows the server's purchase announcements (PurchaseAnnouncer) as a styled
-- system line in the normal chat:
--     [52] Name bought X1000 LESSONS for  1,249
-- The name is coloured like the buyer's rebirth number on their name tag.
-- Only the server fires this event; the client just formats it.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local RebirthColors = require(ReplicatedStorage:WaitForChild("RebirthColors"))

local ROBUX = utf8.char(0xE002)

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function commas(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function channel()
	local channels = TextChatService:FindFirstChild("TextChannels")
	return channels and channels:FindFirstChild("RBXGeneral")
end

local remote = ReplicatedStorage:WaitForChild("PurchaseAnnouncement")

remote.OnClientEvent:Connect(function(userId, itemName, robux)
	if typeof(userId) ~= "number" or typeof(robux) ~= "number" then
		return
	end
	local buyer = Players:GetPlayerByUserId(userId)
	if not buyer then
		return
	end
	local general = channel()
	if not general then
		return
	end

	local rebirths = math.floor(buyer:GetAttribute("Rebirths") or 0)
	local color = RebirthColors.Hex(RebirthColors.Get(rebirths))
	local line = string.format(
		'<font color="#FFD54A">🛒</font> <font color="%s"><b>[%d] %s</b></font>'
			.. ' <font color="#E8E4F5">bought</font> <font color="#FFE27A"><b>%s</b></font>'
			.. ' <font color="#E8E4F5">for</font> <font color="#7CFF9B"><b>%s %s</b></font>',
		color,
		rebirths,
		escape(buyer.DisplayName),
		escape(itemName),
		ROBUX,
		commas(robux)
	)

	pcall(function()
		general:DisplaySystemMessage(line)
	end)
end)
