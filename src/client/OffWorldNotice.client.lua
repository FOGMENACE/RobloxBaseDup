--------------------------------------------------
-- OFF-WORLD NOTICE (CLIENT, visual only)
--
-- Fine print in the bottom-right corner while the equipped ball is not from
-- the world the player is in (server attribute "BallNotHome", OffWorldBallFlag):
-- that ball is braked on the courses, so the player can tell why.
--------------------------------------------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("OffWorldNotice")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "OffWorldNotice"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -12, 1, -6)
label.Size = UDim2.fromOffset(320, 16)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.Text = "YOUR BALL IS NOT FROM THIS UNIVERSE"
label.TextColor3 = Color3.fromRGB(255, 247, 232)
label.TextSize = 12
label.TextXAlignment = Enum.TextXAlignment.Right
label.TextTransparency = 1
label.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(24, 22, 34)
stroke.Thickness = 1.2
stroke.Transparency = 1
stroke.Parent = label

local function refresh()
	local show = player:GetAttribute("BallNotHome") == true
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
	TweenService:Create(label, info, { TextTransparency = show and 0.2 or 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = show and 0.45 or 1 }):Play()
end

player:GetAttributeChangedSignal("BallNotHome"):Connect(refresh)
refresh()
