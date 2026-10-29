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
-- Also: Settings > Music on/off (SettingMusic attribute) and focus-aware
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

-- Mastering on the whole music bus (same sound ids): a gentle compressor evens out
-- quiet and loud parts so the tracks sound fuller and punchier at the higher level
-- without clipping, and a light "smile" EQ adds warmth (bass) and sparkle (highs).
local compressor = Instance.new("CompressorSoundEffect")
compressor.Threshold = -18
compressor.Ratio = 3
compressor.Attack = 0.01
compressor.Release = 0.15
compressor.GainMakeup = 3
compressor.Priority = 2
compressor.Parent = musicGroup

local tone = Instance.new("EqualizerSoundEffect")
tone.LowGain = 2.5
tone.MidGain = -0.5
tone.HighGain = 2
tone.Priority = 1
tone.Parent = musicGroup

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

local masterLevels = { 1 }
local masterIndex = 1
local focusMultiplier = 1
local lastFocusStamp = 0

-- Idle ducking: after IDLE_SECONDS without any input the music drops to the
-- same level as when the game window loses focus, and returns on input.
local IDLE_SECONDS = 40
-- Long idle: every IDLE_RESTORE_SECONDS without input the music is brought
-- back to the player's full setting (and resumed if it stopped), then it dims
-- again after IDLE_SECONDS like normal. Configurable via AudioConfig.
local IDLE_RESTORE_SECONDS = AudioConfig.IdleRestoreSeconds or 300
local idleMultiplier = 1
local lastInput = os.clock()
local quietSince = lastInput -- dimming is measured from here
local lastRestore = lastInput
local lastTransition = 0

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

local function markActive()
	local now = os.clock()
	lastInput, quietSince, lastRestore = now, now, now
	setIdle(false)
end
UserInputService.InputBegan:Connect(markActive)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		markActive()
	end
end)

local currentSceneTrack -- set below, returns the track table of the scene now playing

-- Bring the music back to the intended setting after a long idle: the current
-- scene's track playing at full (setting-respecting) volume, every other
-- track paused. Runs at most once per IDLE_RESTORE_SECONDS, never per frame.
local function restoreMusic()
	idleMultiplier = 1
	local current = currentSceneTrack and currentSceneTrack()
	local settled = os.clock() - lastTransition > 2.5 -- never fight a DJ transition
	for _, track in pairs(tracks) do
		local sound = track.Sound
		if track == current then
			sound.PlaybackSpeed = 1
			track.Eq.LowGain, track.Eq.MidGain = 0, 0
			if not sound.IsPlaying then
				if sound.TimePosition > 0 then
					sound:Resume()
				else
					sound:Play()
				end
			end
		elseif settled and sound.IsPlaying then
			sound:Pause()
		end
	end
	applyVolumes(1.2)
end

task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()
		if now - lastInput >= IDLE_RESTORE_SECONDS and now - lastRestore >= IDLE_RESTORE_SECONDS then
			lastRestore, quietSince = now, now
			restoreMusic()
		elseif now - quietSince > IDLE_SECONDS then
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
	lastTransition = os.clock()

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

currentSceneTrack = function()
	return currentScene and tracks[currentScene]
end

local function refreshScene()
	switchScene(sceneFromState())
end

player:GetAttributeChangedSignal("RunState"):Connect(refreshScene)
player:GetAttributeChangedSignal("WinTravelBudget"):Connect(refreshScene)

--------------------------------------------------
-- MUSIC ON/OFF
--
-- There is no on-screen music button any more: Settings > Music (saved by the
-- server as the SettingMusic attribute) is the only control. master() reads the
-- attribute, so toggling it fades the music in/out through applyVolumes (hooked
-- to the attribute above).
--------------------------------------------------

-- remove the old button's gui if a previous version left one behind
local oldControls = playerGui:FindFirstChild("MusicControls")
if oldControls then
	oldControls:Destroy()
end
--------------------------------------------------
-- START
--------------------------------------------------

refreshScene()
