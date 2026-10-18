--------------------------------------------------
-- PLATFORM SOUNDS (client, audio only)
--
-- Every oil platform makes a sound, driven only by the server-owned
-- CurrentOil attribute:
--   oil gained   -> a bright "pin hit": a crisp snap + a little ping
--                   (pitch rises with the size of the gain)
--   big jump     -> (X2 / X4 style) a double ping going up
--   oil lost     -> a low thump + a downward whoosh
--   big drop     -> (/2 / /4) a longer low swoosh
-- Upgrade / downgrade sounds live in BallTierUI. Built-in Roblox sounds
-- are used so they always load; volumes are kept under the music.
--------------------------------------------------

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local SNAP = "rbxasset://sounds/snap.mp3"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local THUMP = "rbxasset://sounds/bass.mp3"
local SPLAT = "rbxasset://sounds/splat.wav"
local HIT = "rbxasset://sounds/hit.wav"
local METAL = "rbxasset://sounds/metal.mp3"
local GLASS = "rbxasset://sounds/glassbreak.wav"

local function play(id, volume, speed, delay)
	task.delay(delay or 0, function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume
		sound.PlaybackSpeed = speed
		sound.Parent = SoundService
		sound:Play()
		task.delay(2.5, function()
			sound:Destroy()
		end)
	end)
end

local last = player:GetAttribute("CurrentOil") or 0
local lastRunState = player:GetAttribute("RunState")

local function onOilChanged()
	local state = player:GetAttribute("RunState")
	local now = player:GetAttribute("CurrentOil")
	if typeof(now) ~= "number" then
		return
	end

	-- only while rolling the oil course (not the reset at run start / end)
	if state == "Running" and lastRunState == "Running" then
		local change = now - last

		if change > 0 then
			local big = last > 0 and now >= last * 1.9 and change >= 200
			local pitch = math.clamp(1 + math.log10(math.max(change, 1)) * 0.08, 1, 1.5)

			play(SNAP, 0.45, pitch)
			play(PING, 0.32, pitch * 1.15, 0.06)
			if big then
				play(PING, 0.34, pitch * 1.5, 0.2)
				play(PING, 0.34, pitch * 1.9, 0.34)
			end
		elseif change < 0 then
			local halved = last > 0 and now <= last * 0.55 and -change >= 200
			-- a wet, low "squelch + thud" (no sword / whoosh sounds)
			play(SPLAT, 0.5, halved and 0.6 or 0.8)
			play(HIT, 0.4, 0.55, 0.05)
			if halved then
				play(THUMP, 0.5, 0.6, 0.1)
			end
		end
	end

	last = now
	lastRunState = state
end

player:GetAttributeChangedSignal("CurrentOil"):Connect(onOilChanged)
player:GetAttributeChangedSignal("RunState"):Connect(function()
	lastRunState = player:GetAttribute("RunState")
	last = player:GetAttribute("CurrentOil") or 0
end)

-- GUTTER: the regular loss sound above (CurrentOil drops) PLUS a hollow
-- metal clang and a low glass crack, so a gutter is clearly different.
task.spawn(function()
	local gutter = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("GutterPenalty")
	gutter.OnClientEvent:Connect(function()
		play(METAL, 0.6, 0.5)
		play(GLASS, 0.35, 0.5, 0.08)
		play(THUMP, 0.5, 0.5, 0.12)
	end)
end)
