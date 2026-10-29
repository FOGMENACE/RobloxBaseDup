--------------------------------------------------
-- ORIENTATION (phones and tablets only)
--
-- The game's interface is laid out for landscape. On a phone/tablet:
--   1. every ScreenGui (and the PlayerGui) is asked for LandscapeSensor, so
--      Roblox locks the game to either landscape side where the OS lets it;
--   2. if the screen is still portrait (Roblox cannot force a rotation on every
--      device: rotation lock, split-screen, some tablets/browsers), a
--      full-screen "Please rotate your device" overlay covers the game and
--      disappears by itself as soon as the screen is landscape.
--
-- A "mobile device" means touch input and NO keyboard and NO mouse, so PCs,
-- touch laptops, Macs and consoles are never locked or covered by this script.
--
-- Debug only: the client attribute OrientationTest = "portrait" / "landscape"
-- (and "mobile") lets the overlay be exercised in Studio. It affects nothing
-- but this local overlay.
--------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function isMobileDevice()
	if player:GetAttribute("OrientationTest") ~= nil then
		return true
	end
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

--------------------------------------------------
-- 1. ASK FOR LANDSCAPE
--------------------------------------------------

local OVERLAY_NAME = "RotateDeviceOverlay"

local function lock(gui)
	if gui:IsA("ScreenGui") and gui.Name ~= OVERLAY_NAME then
		pcall(function()
			gui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end)
	end
end

-- only on a phone/tablet: a PC is never asked to change orientation
if isMobileDevice() then
	for _, gui in ipairs(playerGui:GetChildren()) do
		lock(gui)
	end
	playerGui.ChildAdded:Connect(lock)

	pcall(function()
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end)
end

--------------------------------------------------
-- 2. "PLEASE ROTATE YOUR DEVICE" OVERLAY
--------------------------------------------------

local old = playerGui:FindFirstChild(OVERLAY_NAME)
if old then
	old:Destroy()
end

local overlay = Instance.new("ScreenGui")
overlay.Name = OVERLAY_NAME
overlay.ResetOnSpawn = false
overlay.IgnoreGuiInset = true
overlay.DisplayOrder = 1000
overlay.Enabled = false
-- cover the whole physical screen, notch areas included
pcall(function()
	overlay.ScreenInsets = Enum.ScreenInsets.None
end)
-- landscape like everything else: a "Sensor" overlay would let the device turn
-- portrait again and keep the prompt up instead of auto-rotating
pcall(function()
	overlay.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)
overlay.Parent = playerGui

-- a full-screen button swallows touches so nothing underneath (joystick, jump,
-- shop) reacts while the overlay is up
local shield = Instance.new("TextButton")
shield.Size = UDim2.fromScale(1, 1)
shield.BackgroundColor3 = Color3.fromRGB(28, 29, 33)
shield.BorderSizePixel = 0
shield.AutoButtonColor = false
shield.Text = ""
shield.Active = true
shield.Parent = overlay

local content = Instance.new("Frame")
content.AnchorPoint = Vector2.new(0.5, 0.5)
content.Position = UDim2.fromScale(0.5, 0.5)
content.Size = UDim2.fromOffset(440, 360)
content.BackgroundTransparency = 1
content.Parent = shield
local contentScale = Instance.new("UIScale")
contentScale.Parent = content

-- phone drawn with frames, tilting from upright to sideways
local phone = Instance.new("Frame")
phone.AnchorPoint = Vector2.new(0.5, 0.5)
phone.Position = UDim2.new(0.5, 0, 0, 120)
phone.Size = UDim2.fromOffset(92, 160)
phone.BackgroundColor3 = Color3.fromRGB(57, 59, 61)
phone.Parent = content
Instance.new("UICorner", phone).CornerRadius = UDim.new(0, 16)
local phoneStroke = Instance.new("UIStroke")
phoneStroke.Color = Color3.fromRGB(255, 226, 90)
phoneStroke.Thickness = 4
phoneStroke.Parent = phone
local screen = Instance.new("Frame")
screen.AnchorPoint = Vector2.new(0.5, 0.5)
screen.Position = UDim2.fromScale(0.5, 0.5)
screen.Size = UDim2.new(1, -18, 1, -34)
screen.BackgroundColor3 = Color3.fromRGB(86, 100, 190)
screen.BorderSizePixel = 0
screen.Parent = phone
Instance.new("UICorner", screen).CornerRadius = UDim.new(0, 8)

local function text(str, y, size, color, font)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.FredokaOne
	l.Text = str
	l.TextColor3 = color
	l.TextSize = size
	l.TextWrapped = true
	l.TextScaled = false
	l.Parent = content
	return l
end
text("PLEASE ROTATE YOUR DEVICE", 232, 28, Color3.fromRGB(255, 226, 90))
text("This game plays in landscape.", 276, 20, Color3.fromRGB(200, 202, 208), Enum.Font.GothamBold)
text("Turn your phone or tablet sideways to continue.", 304, 16, Color3.fromRGB(150, 152, 160), Enum.Font.GothamMedium)

--------------------------------------------------
-- PORTRAIT DETECTION
--------------------------------------------------

local function viewportSize()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1, 0)
	return size
end

local function isPortrait()
	local test = player:GetAttribute("OrientationTest")
	if test == "portrait" then
		return true
	elseif test == "landscape" then
		return false
	end
	local size = viewportSize()
	return size.Y > size.X
end

-- The screen is locked to landscape, so the device normally turns by itself. The prompt
-- only shows when it is still portrait after a short wait (rotation lock on, etc.).
local portraitSince = nil
local PORTRAIT_GRACE = 2

local function update()
	-- never on a PC / touch laptop: the overlay only exists for phones and tablets
	local portrait = isMobileDevice() and isPortrait()
	if not portrait then
		portraitSince = nil
	elseif not portraitSince then
		portraitSince = os.clock()
		task.delay(PORTRAIT_GRACE + 0.05, update)
	end
	portrait = portrait and os.clock() - portraitSince >= PORTRAIT_GRACE
		or (portrait and player:GetAttribute("OrientationTest") == "portrait")
	overlay.Enabled = portrait
	if portrait then
		local size = viewportSize()
		-- fit the 360 px block into a narrow portrait screen
		contentScale.Scale = math.clamp(math.min(size.X / 460, size.Y / 420), 0.5, 1.4)
	end
end

local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchCamera()
	update()
end)
player:GetAttributeChangedSignal("OrientationTest"):Connect(update)
playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(update)

-- the phone icon tilts from upright to sideways and back while the overlay is up
RunService.RenderStepped:Connect(function()
	if not overlay.Enabled then
		return
	end
	local t = os.clock() % 3
	local k = 0
	if t < 1.2 then
		k = 0
	elseif t < 1.9 then
		k = (t - 1.2) / 0.7
		k = k * k * (3 - 2 * k)
	else
		k = 1
	end
	phone.Rotation = -90 * k
end)

update()