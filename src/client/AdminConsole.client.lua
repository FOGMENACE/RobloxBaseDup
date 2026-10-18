--------------------------------------------------
-- ADMIN CONSOLE (client, display only)
--
-- Appears only for players the server marked with IsAdmin. That attribute
-- is NOT trusted for anything: the server re-checks the caller's UserId
-- on every command (AdminService). Toggle with the backtick key (`).
-- Type "help" for the command list.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if not player:GetAttribute("IsAdmin") then
	player:GetAttributeChangedSignal("IsAdmin"):Wait()
end
if player:GetAttribute("IsAdmin") ~= true then
	return
end

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminCommand")

local gui = Instance.new("ScreenGui")
gui.Name = "AdminConsole"
gui.ResetOnSpawn = false
gui.DisplayOrder = 200
gui.Enabled = false
gui.Parent = playerGui

-- Bottom-left, drawn above the HUD (DisplayOrder 200).
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0, 1)
frame.Size = UDim2.fromOffset(560, 320)
frame.Position = UDim2.new(0, 12, 1, -12)
frame.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
frame.BackgroundTransparency = 0.05
frame.Active = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

-- Scrollable history; always jumps to the newest line, and you can scroll
-- up with the mouse wheel to read older output.
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -52)
scroll.Position = UDim2.fromOffset(8, 8)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 150, 120)
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = frame

local output = Instance.new("TextLabel")
output.Size = UDim2.new(1, -12, 0, 0)
output.BackgroundTransparency = 1
output.Font = Enum.Font.Code
output.TextSize = 14
output.TextColor3 = Color3.fromRGB(210, 235, 210)
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.Text = "Admin console. Type help."
output.Parent = scroll

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -16, 0, 28)
box.Position = UDim2.new(0, 8, 1, -36)
box.BackgroundColor3 = Color3.fromRGB(36, 36, 52)
box.TextColor3 = Color3.new(1, 1, 1)
box.PlaceholderText = "command..."
box.Font = Enum.Font.Code
box.TextSize = 15
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = frame

local lines = { "Admin console. Type help." }
local MAX_LINES = 300

local TextService = game:GetService("TextService")

-- Sizes the text and the scroll canvas by hand (auto sizing clipped long
-- histories), then jumps to the newest line.
local function relayout()
	local width = math.max(100, scroll.AbsoluteWindowSize.X - 24)
	local bounds = TextService:GetTextSize(output.Text, output.TextSize, output.Font, Vector2.new(width, 100000))
	output.Size = UDim2.new(1, -12, 0, bounds.Y + 4)
	scroll.CanvasSize = UDim2.fromOffset(0, bounds.Y + 12)
	scroll.CanvasPosition = Vector2.new(0, math.max(0, bounds.Y + 12 - scroll.AbsoluteWindowSize.Y))
end

local function scrollToNewest()
	relayout()
end

local function push(text)
	table.insert(lines, text)
	while #lines > MAX_LINES do
		table.remove(lines, 1)
	end
	output.Text = table.concat(lines, "\n")
	relayout()
end

box.FocusLost:Connect(function(enter)
	if not enter or box.Text == "" then
		return
	end

	local text = box.Text
	box.Text = ""
	push("> " .. text)

	local ok, success, message = pcall(function()
		return remote:InvokeServer(text)
	end)

	push(ok and tostring(message) or "request failed")
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Backquote then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			task.defer(scrollToNewest)
			task.defer(function()
				box:CaptureFocus()
			end)
		end
	end
end)
