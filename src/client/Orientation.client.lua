--------------------------------------------------
-- ORIENTATION
--
-- Phones and tablets are locked to landscape (sensor-driven, so either
-- landscape side works). The game's HUD is laid out for a wide screen.
--------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if not UserInputService.TouchEnabled then
	return
end

local function lock(gui)
	if gui:IsA("ScreenGui") then
		pcall(function()
			gui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end)
	end
end

for _, gui in ipairs(playerGui:GetChildren()) do
	lock(gui)
end
playerGui.ChildAdded:Connect(lock)

pcall(function()
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)