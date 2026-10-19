--------------------------------------------------
-- PROMPT MANAGER
--
-- CLIENT ONLY.
--   1. Invitations to JOIN THE GROUP and to FAVORITE the game, using
--      Roblox's own native prompts (GroupService:PromptJoinAsync and
--      AvatarEditorService:PromptSetFavorite) in the middle of the screen.
--      Each one runs on its own timer, so they may overlap or follow each
--      other closely, and they repeat until that task is done. They are
--      allowed over the store and other panels, and only held back during a
--      run. A short, non-blocking "do it now" banner appears with each one.
--      The server says what is already done (PromptService) and re-checks
--      group membership itself.
--   2. Anti-AFK: keeps Roblox from kicking idle players (20 minute idle
--      timeout) by sending a harmless virtual click when the idle event
--      fires.
--
-- Nothing here grants a reward; it is purely an invitation. The Settings
-- "Pop ups" switch turns the invitations off.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local promptState = remotes:WaitForChild("PromptState")
local promptDone = remotes:WaitForChild("PromptDone")

-- Timing (seconds). Each invitation has its own clock (small random jitter so
-- the two drift in and out of sync): first one about half a minute in, then
-- about every minute until that task is done.
local FIRST_DELAY = { Group = 35, Favorite = 55 }
local REPEAT_EVERY = 65
local JITTER = 12

--------------------------------------------------
-- ANTI-AFK
--------------------------------------------------

player.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end)
end)

--------------------------------------------------
-- "DO IT NOW" BANNER (small, non-blocking, never takes input)
--------------------------------------------------

local old = playerGui:FindFirstChild("PromptManagerUI")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PromptManagerUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = playerGui

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -60)
banner.Size = UDim2.fromOffset(380, 40)
banner.BackgroundColor3 = Color3.fromRGB(35, 37, 39)
banner.Font = Enum.Font.FredokaOne
banner.TextSize = 20
banner.TextColor3 = Color3.fromRGB(255, 226, 90)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 226, 90)
bannerStroke.Thickness = 2
bannerStroke.Parent = banner

local bannerToken = 0
local function showBanner(text)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.Visible = true
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0, 14),
	}):Play()
	task.delay(5, function()
		if bannerToken == token then
			local hide = TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) })
			hide.Completed:Once(function()
				if bannerToken == token then
					banner.Visible = false
				end
			end)
			hide:Play()
		end
	end)
end

--------------------------------------------------
-- WHEN IS IT OK TO INTERRUPT?
--------------------------------------------------

-- Lobby only: never in the middle of a run. (Panels such as the store are fine.)
local function canInterrupt()
	local runState = player:GetAttribute("RunState")
	return runState == nil or runState == "" or runState == "Waiting"
end

--------------------------------------------------
-- THE TWO INVITATIONS (native Roblox prompts)
--------------------------------------------------

local favoriteBusy = false

local function offerGroup(groupId)
	showBanner("JOIN OUR COMMUNITY for free wins!")
	local ok, status = pcall(function()
		return GroupService:PromptJoinAsync(groupId)
	end)
	if not ok then
		warn("[PromptManager] Group prompt failed:", status)
	end
end

local function offerFavorite()
	if favoriteBusy then
		return
	end
	favoriteBusy = true
	showBanner("LIKE THE GAME - tap Yes to favorite!")

	local connection
	connection = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		favoriteBusy = false
		connection:Disconnect()
		-- The event passes an Enum.AvatarPromptResult (always truthy), so only
		-- an explicit Success counts; "No"/dismiss must not.
		if result == Enum.AvatarPromptResult.Success then
			promptDone:FireServer("Favorite")
		end
	end)

	local ok, err = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		favoriteBusy = false
		connection:Disconnect()
		warn("[PromptManager] Favorite prompt failed:", err)
	end
end

--------------------------------------------------
-- LOOPS (one per invitation, independent so they can overlap)
--------------------------------------------------

local rng = Random.new()

local function runLoop(kind)
	task.wait(FIRST_DELAY[kind])

	while true do
		-- wait for a good moment, and for Pop ups to be on
		while not canInterrupt() or player:GetAttribute("SettingPopups") == false do
			task.wait(4)
		end

		local ok, state = pcall(function()
			return promptState:InvokeServer()
		end)

		if ok and typeof(state) == "table" then
			if kind == "Group" then
				if state.GroupDone then
					return -- done: stop for the rest of the session
				end
				offerGroup(state.GroupId)
			else
				if state.FavoriteDone then
					return
				end
				offerFavorite()
			end
		end

		task.wait(REPEAT_EVERY + rng:NextNumber(-JITTER, JITTER))
	end
end

task.spawn(runLoop, "Group")
task.spawn(runLoop, "Favorite")