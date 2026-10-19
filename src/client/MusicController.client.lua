--------------------------------------------------
-- MUSIC CONTROLLER
--
-- CLIENT ONLY. One scene at a time:
--   Lobby      RunState Waiting
--   OilCourse  RunState Starting / Running
--   WinCourse  RunState Finishing (the countdown) and the WinCourse itself
--
-- Changing scene is a short DJ-style move instead of a plain fade:
-- the old track "spins down" (pitch drops while it fades) and the new
-- track rises in through a low-cut filter sweep. Going into the
-- WinCourse starts that build during the 5-second countdown, so the
-- drop lands on GO.
--
-- Also: a music button (cycles 100% / 50% / off) and focus-aware
-- fading (music ducks when the game window loses focus).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AudioConfig = require(ReplicatedStorage:WaitForChild("AudioConfig"))

--------------------------------------------------
-- SOUNDS
--------------------------------------------------

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Volume = 1
musicGroup.Parent = SoundService

local tracks = {} -- [scene] = { Sound, Eq, BaseVolume }

for scene, config in pairs(AudioConfig.Music) do
	if config.SoundId ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music_" .. scene
		sound.SoundId = config.SoundId
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = musicGroup
		sound.Parent = musicGroup

		-- Low-cut used for the DJ "filter riser".
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 0
		eq.MidGain = 0
		eq.HighGain = 0
		eq.Parent = sound

		tracks[scene] = {
			Sound = sound,
			Eq = eq,
			BaseVolume = config.Volume or 0.5,
		}
	end
end

task.spawn(function()
	local assets = {}
	for _, track in pairs(tracks) do
		table.insert(assets, track.Sound)
	end
	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end)

--------------------------------------------------
-- MASTER VOLUME + FOCUS
--------------------------------------------------

local masterLevels = { 1, 0.5, 0 } -- button cycle
local masterIndex = 1
local focusMultiplier = 1
local lastFocusStamp = 0

-- Idle ducking: after IDLE_SECONDS without any input the music drops to the
-- same level as when the game window loses focus, and returns on input.
local IDLE_SECONDS = 40
local idleMultiplier = 1
local lastInput = os.clock()

local function master()
	-- Settings > Music OFF (attribute set by SettingsUI; nil = default on)
	if player:GetAttribute("SettingMusic") == false then
		return 0
	end
	return AudioConfig.DefaultMasterVolume * masterLevels[masterIndex] * focusMultiplier * idleMultiplier
end

local currentScene = nil

local function applyVolumes(duration)
	for scene, track in pairs(tracks) do
		local target = (scene == currentScene) and (track.BaseVolume * master()) or 0
		TweenService:Create(
			track.Sound,
			TweenInfo.new(duration or 0.4, Enum.EasingStyle.Sine),
			{ Volume = target }
		):Play()
	end
end

local function setIdle(idle)
	local target = idle and AudioConfig.UnfocusedMultiplier or 1
	if idleMultiplier ~= target then
		idleMultiplier = target
		applyVolumes(idle and 1.5 or 0.5)
	end
end

UserInputService.InputBegan:Connect(function()
	lastInput = os.clock()
	setIdle(false)
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		lastInput = os.clock()
		setIdle(false)
	end
end)
task.spawn(function()
	while true do
		task.wait(2)
		if os.clock() - lastInput > IDLE_SECONDS then
			setIdle(true)
		end
	end
end)

player:GetAttributeChangedSignal("SettingMusic"):Connect(function()
	applyVolumes(0.3)
end)

-- Focus-aware ducking.
UserInputService.WindowFocusReleased:Connect(function()
	lastFocusStamp = 0
	focusMultiplier = AudioConfig.UnfocusedMultiplier
	applyVolumes(0.6)
end)

UserInputService.WindowFocused:Connect(function()
	-- Swell above normal on return, then settle back.
	focusMultiplier = AudioConfig.RefocusBoost
	applyVolumes(0.6)

	local stamp = os.clock()
	lastFocusStamp = stamp
	task.delay(3, function()
		if lastFocusStamp == stamp then
			focusMultiplier = 1
			applyVolumes(2)
		end
	end)
end)

--------------------------------------------------
-- DJ TRANSITION
--------------------------------------------------

local transitionToken = 0

local function switchScene(scene)
	if scene == currentScene then
		return
	end

	local previous = currentScene
	currentScene = scene

	transitionToken += 1
	local token = transitionToken

	local outgoing = previous and tracks[previous]
	local incoming = scene and tracks[scene]

	-- Spin the old track down.
	if outgoing then
		TweenService:Create(
			outgoing.Sound,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Volume = 0, PlaybackSpeed = 0.55 }
		):Play()

		task.delay(1.0, function()
			if token == transitionToken and outgoing.Sound.Playing then
				outgoing.Sound:Pause()
				outgoing.Sound.PlaybackSpeed = 1
			end
		end)
	end

	-- Bring the new track up through a filter riser.
	if incoming then
		local sound = incoming.Sound
		sound.PlaybackSpeed = 1
		incoming.Eq.LowGain = -60
		incoming.Eq.MidGain = -20
		sound.Volume = 0

		if not sound.Playing then
			sound:Play()
		end

		local riseTime = 1.6

		TweenService:Create(
			sound,
			TweenInfo.new(riseTime, Enum.EasingStyle.Sine),
			{ Volume = incoming.BaseVolume * master() }
		):Play()

		TweenService:Create(
			incoming.Eq,
			TweenInfo.new(riseTime, Enum.EasingStyle.Quad),
			{ LowGain = 0, MidGain = 0 }
		):Play()
	end
end

--------------------------------------------------
-- SCENE FROM SERVER STATE
--------------------------------------------------

local function sceneFromState()
	local runState = player:GetAttribute("RunState")
	local budget = player:GetAttribute("WinTravelBudget")

	-- OilCourse and WinCourse share one track, so nothing restarts when
	-- the run rolls on into the WinCourse.
	if typeof(budget) == "number" or runState == "Finishing"
		or runState == "Starting" or runState == "Running" then
		return "Course"
	end

	return "Lobby"
end

local function refreshScene()
	switchScene(sceneFromState())
end

player:GetAttributeChangedSignal("RunState"):Connect(refreshScene)
player:GetAttributeChangedSignal("WinTravelBudget"):Connect(refreshScene)

--------------------------------------------------
-- MUSIC BUTTON
--------------------------------------------------

local old = playerGui:FindFirstChild("MusicControls")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MusicControls"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.Name = "MusicButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -16, 1, -214)
button.Size = UDim2.fromOffset(52, 52)
button.BackgroundColor3 = Color3.fromRGB(240, 178, 82)
button.Text = "MUSIC"
button.TextColor3 = Color3.fromRGB(24, 22, 34)
button.Font = Enum.Font.FredokaOne
button.TextSize = 11
button.Parent = gui

Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(24, 22, 34)
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button

local function refreshButton()
	local labels = { "MUSIC\nON", "MUSIC\n50%", "MUSIC\nOFF" }
	button.Text = labels[masterIndex]
end

button.Activated:Connect(function()
	masterIndex = masterIndex % #masterLevels + 1
	refreshButton()
	applyVolumes(0.3)
end)

refreshButton()

--------------------------------------------------
-- START
--------------------------------------------------

refreshScene()
