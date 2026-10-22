--------------------------------------------------
-- RESTART NOTICE (CLIENT, display only)
--
-- When an admin restarts the server for an update (AdminService "restart" /
-- "restartall"), the server fires Remotes.RestartNotice(seconds, reason) and
-- this shows a countdown banner. seconds = 0 hides it (restart cancelled).
-- The kick itself is done by the server; this changes nothing.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local notice = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RestartNotice")

local FONT = Enum.Font.FredokaOne

local gui = Instance.new("ScreenGui")
gui.Name = "RestartNotice"
gui.ResetOnSpawn = false
gui.DisplayOrder = 150
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 14)
panel.Size = UDim2.fromOffset(520, 76)
panel.BackgroundColor3 = Color3.fromRGB(30, 18, 70)
panel.BackgroundTransparency = 0.05
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 205, 70)
stroke.Thickness = 3
stroke.Parent = panel
local scale = Instance.new("UIScale")
scale.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 6)
title.Size = UDim2.new(1, -24, 0, 34)
title.Font = FONT
title.TextColor3 = Color3.fromRGB(255, 226, 120)
title.TextSize = 26
title.Text = ""
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(12, 40)
sub.Size = UDim2.new(1, -24, 0, 28)
sub.Font = Enum.Font.GothamMedium
sub.TextColor3 = Color3.fromRGB(240, 236, 255)
sub.TextSize = 16
sub.TextWrapped = true
sub.Text = ""
sub.Parent = panel

local function fit()
	local viewport = gui.AbsoluteSize
	scale.Scale = math.clamp(viewport.X / 600, 0.55, 1)
end
fit()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

local deadline = nil
local reasonText = ""

notice.OnClientEvent:Connect(function(seconds, reason)
	if typeof(seconds) ~= "number" or seconds <= 0 then
		deadline = nil
		gui.Enabled = false
		return
	end
	deadline = os.clock() + seconds
	reasonText = typeof(reason) == "string" and reason or ""
	gui.Enabled = true
end)

RunService.RenderStepped:Connect(function()
	if not deadline then
		return
	end
	local left = math.max(0, math.ceil(deadline - os.clock()))
	title.Text = "UPDATE! RESTARTING IN " .. left .. "s"
	sub.Text = "Your progress is saved. You will be moved to a fresh server automatically. " .. reasonText
	stroke.Thickness = 3 + math.sin(os.clock() * 5) * 0.8
end)
