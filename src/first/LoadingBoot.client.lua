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
if not game:IsLoaded() then
	game.Loaded:Wait()
end
if status then
	status.Text = arriving and "Welcome back! Loading your progress..." or "Loading your progress..."
end

-- wait for the server to hand over the saved data (Level attribute), max 20 s
local waited = 0
while player:GetAttribute("Level") == nil and waited < 20 do
	task.wait(0.25)
	waited += 0.25
end
task.wait(0.4)
LoadingScreen.FadeOut(gui, 0.7)