--------------------------------------------------
-- SCREEN BORDER (CLIENT)
--
-- A soft violet-to-gold vignette that fades inward from each screen edge.
-- It sits inside the frame, below every other interface (DisplayOrder 0)
-- and never takes input.
--------------------------------------------------

local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("ScreenBorder")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ScreenBorder"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 0
gui.Parent = playerGui

local THICKNESS = 0.07 -- fraction of the shorter side, set below
local EDGE = Color3.fromRGB(88, 56, 205)
local RIM = Color3.fromRGB(255, 214, 70)

local function edge(name, anchor, position, size, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = EDGE
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RIM),
		ColorSequenceKeypoint.new(0.12, EDGE),
		ColorSequenceKeypoint.new(1, EDGE),
	})
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.12, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

-- gradient runs from the screen edge inward
local top = edge("Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 0), 90)
local bottom = edge("Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.new(1, 0, 0, 0), 270)
local left = edge("Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.new(0, 0, 1, 0), 0)
local right = edge("Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.new(0, 0, 1, 0), 180)

local function fit()
	local size = gui.AbsoluteSize
	local t = math.floor(math.clamp(math.min(size.X, size.Y) * THICKNESS, 24, 70))
	top.Size = UDim2.new(1, 0, 0, t)
	bottom.Size = UDim2.new(1, 0, 0, t)
	left.Size = UDim2.new(0, t, 1, 0)
	right.Size = UDim2.new(0, t, 1, 0)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()