--------------------------------------------------
-- LOADING BOOT (ReplicatedFirst)
--
-- Replaces Roblox's default loading screen with the branded one on every
-- join (or keeps the one carried over from an AFK rejoin / server move),
-- then fades it out once the game and the player's data have loaded.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")

local LoadingScreen = require(script.Parent:WaitForChild("LoadingScreen"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = TeleportService:GetArrivingTeleportGui()
local arriving = gui ~= nil
if not gui then
	gui = LoadingScreen.Build("Loading...")
end
gui.Parent = playerGui
LoadingScreen.Animate(gui)
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local status = gui:FindFirstChild("Status")
-- Each step says what it is waiting for. Nothing here is a fixed timer: the screen stays
-- up until the player can really play (a slow connection just waits a little longer),
-- with a generous cap so nobody is ever stuck behind it.
local MAX_WAIT = 120
local started = os.clock()
local slowShown = false

local function setStatus(text)
	if status then
		status.Text = text
	end
end

local function waitFor(text, check)
	setStatus(text)
	while not check() and os.clock() - started < MAX_WAIT do
		if not slowShown and os.clock() - started > 25 then
			slowShown = true
		end
		if slowShown and status then
			status.Text = text .. "  (slow connection - hang tight!)"
		end
		task.wait(0.25)
	end
end

if not game:IsLoaded() then
	setStatus("Connecting to the lanes...")
	game.Loaded:Wait()
end

waitFor(arriving and "Welcome back! Loading your progress..." or "Loading your progress...", function()
	return player:GetAttribute("Level") ~= nil
end)

waitFor("Setting up your world...", function()
	return player:GetAttribute("WorldReady") == true
end)

-- the ball exists and the floor under it has streamed in (raycast hits ground)
waitFor("Placing your ball...", function()
	local balls = workspace:FindFirstChild("PlayerBalls")
	local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
	if not ball or not ball:IsA("BasePart") then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { balls }
	return workspace:Raycast(ball.Position, Vector3.new(0, -12, 0), params) ~= nil
end)

setStatus("Ready - let's roll!")
task.wait(0.4)

-- the ball's controls unlock (BallController reads this local attribute) and the
-- server is told, so it allows this player's first run (JoinGate)
player:SetAttribute("LoadingDone", true)
task.spawn(function()
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("ClientLoaded", 30)
	if remote then
		remote:FireServer()
	end
end)

LoadingScreen.FadeOut(gui, 0.7)
