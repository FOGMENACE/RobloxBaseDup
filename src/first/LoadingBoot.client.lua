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

-- Each step says what it is waiting for. Nothing here is a fixed timer: the screen stays
-- up until the player can really play (a slow connection just waits a little longer),
-- with a generous cap so nobody is ever stuck behind it. Each step also owns a slice of
-- the progress bar (the pins and the %), so the numbers follow the real loading.
local MAX_WAIT = 120
local started = os.clock()
local slowShown = false

local function setStatus(text)
	LoadingScreen.SetStatus(gui, text)
end

local function waitFor(text, from, to, check)
	setStatus(text)
	LoadingScreen.Step(gui, from, to)
	while not check() and os.clock() - started < MAX_WAIT do
		if not slowShown and os.clock() - started > 25 then
			slowShown = true
		end
		if slowShown then
			setStatus(text .. "  (slow connection - hang tight!)")
		end
		task.wait(0.25)
	end
end

if not game:IsLoaded() then
	setStatus("Connecting to the lanes...")
	LoadingScreen.Step(gui, 0, 0.25)
	game.Loaded:Wait()
end

waitFor(arriving and "Welcome back! Loading your progress..." or "Loading your progress...", 0.25, 0.55, function()
	return player:GetAttribute("Level") ~= nil
end)

waitFor("Setting up your world...", 0.55, 0.8, function()
	return player:GetAttribute("WorldReady") == true
end)

-- the ball exists and the floor under it has streamed in (raycast hits ground)
waitFor("Placing your ball...", 0.8, 0.95, function()
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
LoadingScreen.Step(gui, 1, 1)
-- let the counter reach 100% before the screen lifts
local finishBy = os.clock() + 1.4
while (gui:GetAttribute("ProgShown") or 0) < 1 and os.clock() < finishBy do
	task.wait()
end
task.wait(0.35)

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
