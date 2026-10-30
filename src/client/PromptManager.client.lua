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
--      group membership itself. Controller players get a message instead of
--      the prompts (see usingController).
--   2. AFK: Roblox kicks after 20 minutes without input and scripts cannot
--      fake input (VirtualUser needs plugin security, so the old virtual
--      click silently failed). After AFK_REJOIN_AFTER seconds idle the
--      player is quietly re-teleported into this same server behind the
--      branded loading screen (ServerTransferService).
--
-- Nothing here grants a reward; it is purely an invitation. The Settings
-- "Pop ups" switch turns the invitations off.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

-- Quiet AFK rejoin at 18.5 min (Roblox kicks at 20): the branded loading screen
-- is set as the teleport gui, so the player only sees a short reload.
local AFK_REJOIN_AFTER = 18.5 * 60
local TeleportService = game:GetService("TeleportService")
-- required lazily: never block this script if the module is missing
local function loadingScreen()
	local module = game:GetService("ReplicatedFirst"):FindFirstChild("LoadingScreen")
	return module and require(module)
end
local afkRejoin = remotes:WaitForChild("AfkRejoin")
local lastInput = os.clock()

local function markActive()
	lastInput = os.clock()
end
UserInputService.InputBegan:Connect(markActive)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		markActive()
	end
end)
-- Roblox's own idle clock is the source of truth
player.Idled:Connect(function(idleSeconds)
	if typeof(idleSeconds) == "number" then
		lastInput = math.min(lastInput, os.clock() - idleSeconds)
	end
end)

local function setTransferScreen(status)
	local LoadingScreen = loadingScreen()
	if LoadingScreen then
		pcall(function()
			TeleportService:SetTeleportGui(LoadingScreen.Build(status))
		end)
	end
end

task.spawn(function()
	while true do
		task.wait(5)
		if os.clock() - lastInput >= AFK_REJOIN_AFTER then
			setTransferScreen("Keeping your spot... loading back in")
			afkRejoin:FireServer()
			lastInput = os.clock() - AFK_REJOIN_AFTER + 60 -- retry in a minute if it did not happen
		end
	end
end)

-- the server is moving this player (laggy server): show the screen now and carry it over
remotes:WaitForChild("ServerTransferNotice").OnClientEvent:Connect(function(status)
	setTransferScreen(status)
	local LoadingScreen = loadingScreen()
	if not LoadingScreen then
		return
	end
	local screen = LoadingScreen.Build(status)
	screen.Parent = playerGui
	LoadingScreen.Animate(screen)
	task.delay(25, function() -- teleport failed: give the game back
		if screen.Parent then
			LoadingScreen.FadeOut(screen, 0.5)
		end
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
banner.Font = Enum.Font.GothamBold -- plain and readable (the chunky display font blurred together)
banner.TextSize = 17
banner.TextColor3 = Color3.fromRGB(245, 245, 247)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 200, 70)
bannerStroke.Thickness = 1.5
bannerStroke.Transparency = 0.2
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

-- These prompts open by themselves, mid-play, in Roblox's own windows, and one can leave
-- a controller player stuck on it. Those players get a single message per session that
-- blocks nothing instead. (The virtual cursor is for windows the player opens on
-- purpose, like Plus in the store: PanelManager.ReleaseController.)
local CONTROLLER_MESSAGES = {
	Group = "Enjoying it? Join our group from the game page!",
	Favorite = "Enjoying it? Favorite us from the game page!",
}
local controllerMessageShown = {}

local function usingController()
	local lastInput = UserInputService:GetLastInputType()
	return lastInput.Name:sub(1, 7) == "Gamepad"
		or (UserInputService.GamepadEnabled and not UserInputService.MouseEnabled and not UserInputService.TouchEnabled)
end

local function offerToController(kind)
	if not controllerMessageShown[kind] then
		controllerMessageShown[kind] = true
		showBanner(CONTROLLER_MESSAGES[kind])
	end
end

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
				if usingController() then
					offerToController("Group")
				else
					offerGroup(state.GroupId)
				end
			else
				if state.FavoriteDone then
					return
				end
				if usingController() then
					offerToController("Favorite")
				else
					offerFavorite()
				end
			end
		end

		task.wait(REPEAT_EVERY + rng:NextNumber(-JITTER, JITTER))
	end
end

task.spawn(runLoop, "Group")
task.spawn(runLoop, "Favorite")