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

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(560, 300)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
frame.BackgroundTransparency = 0.1
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local output = Instance.new("TextLabel")
output.Size = UDim2.new(1, -16, 1, -48)
output.Position = UDim2.fromOffset(8, 8)
output.BackgroundTransparency = 1
output.Font = Enum.Font.Code
output.TextSize = 14
output.TextColor3 = Color3.fromRGB(210, 235, 210)
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Bottom
output.TextWrapped = true
output.Text = "Admin console. Type help."
output.Parent = frame

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

local function push(text)
	table.insert(lines, text)
	while #lines > 14 do
		table.remove(lines, 1)
	end
	output.Text = table.concat(lines, "\n")
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
			task.defer(function()
				box:CaptureFocus()
			end)
		end
	end
end)
