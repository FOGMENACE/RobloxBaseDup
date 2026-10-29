--------------------------------------------------
-- UI SOUNDS (client, audio only)
--
-- HOVER: a soft, short tick when the mouse moves onto any button of the game's own
-- UI (mouse only: touch screens have no hover). Throttled, and skipped for hidden or
-- screen-sized buttons (steering zones etc.), so sweeping the mouse never rattles.
--
-- CLICK on the wins hub buttons: a crisp switch click plus the arcade power-up blip
-- (the level-up sound), each button on its own note of a major pentatonic scale, so
-- every button sounds different but they all belong together:
--   STORE C  QUESTS D  REBIRTH E  GIFT G  DAILY A  X6 high C
--
-- Samples (measured in Studio; heard level = sample loudness x Volume, music ~160):
--   click  "Switch Click On Or Off Toggle Button 2 (SFX)", ProSoundEffects, peak ~157
--   blip   "retro coin pickup sound effect powerup" (from LilMati on freesound), peak ~250
-- The SFX setting mutes these like every other sound (SettingsUI).
--------------------------------------------------

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CLICK = "rbxassetid://9119717523"
local BLIP = "rbxassetid://93529351909119"

local HOVER_VOLUME = 0.25
local HOVER_SPEED = 1.6
local HOVER_GAP = 0.06
local CLICK_VOLUME = 0.6
local BLIP_VOLUME = 0.35

-- semitones above the blip's natural pitch
local HUB_NOTES = {
	ShopButton = 0,
	QuestsButton = 2,
	RebirthButton = 4,
	GiftButton = 7,
	DailyButton = 9,
	X6Button = 12,
}

local holder = Instance.new("ScreenGui")
holder.Name = "UiSounds"
holder.ResetOnSpawn = false
holder.Parent = playerGui

local function voice(id)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0
	sound.Parent = holder
	return sound
end

local hoverVoice = voice(CLICK)
local clickVoice = voice(CLICK)
local blipVoice = voice(BLIP)

local function play(sound, volume, speed)
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.TimePosition = 0
	sound:Play()
end

--------------------------------------------------
-- HOVER
--------------------------------------------------

local lastHover = 0

local function usingMouse()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.MouseMovement
		or last == Enum.UserInputType.MouseButton1
		or last == Enum.UserInputType.MouseButton2
		or last == Enum.UserInputType.MouseWheel
end

local function hoverable(button)
	if not button.Visible then
		return false
	end
	local size = button.AbsoluteSize
	local screen = holder.AbsoluteSize
	-- hidden originals (BadgeOverlay shrinks them to 0) and screen-sized input zones
	return size.X >= 8 and size.Y >= 8 and size.X * size.Y < screen.X * screen.Y * 0.25
end

local hooked = setmetatable({}, { __mode = "k" })

local function hook(button)
	if hooked[button] or button:IsDescendantOf(holder) then
		return
	end
	hooked[button] = true
	button.MouseEnter:Connect(function()
		local now = os.clock()
		if now - lastHover < HOVER_GAP or not usingMouse() or not hoverable(button) then
			return
		end
		lastHover = now
		play(hoverVoice, HOVER_VOLUME, HOVER_SPEED)
	end)
end

local function scan(instance)
	if instance:IsA("GuiButton") then
		hook(instance)
	end
end

for _, descendant in ipairs(playerGui:GetDescendants()) do
	scan(descendant)
end
playerGui.DescendantAdded:Connect(scan)

--------------------------------------------------
-- HUB CLICKS
--------------------------------------------------

local function hubClick(note)
	play(clickVoice, CLICK_VOLUME, 1)
	blipVoice:Stop() -- one voice: never two notes ringing on top of each other
	play(blipVoice, BLIP_VOLUME, 2 ^ (note / 12))
end

task.spawn(function()
	local hub = playerGui:WaitForChild("HubUI", 30)
	if not hub then
		return
	end
	local function hookHub(instance)
		local note = HUB_NOTES[instance.Name]
		if note and instance:IsA("GuiButton") and not instance:GetAttribute("UiClickHooked") then
			instance:SetAttribute("UiClickHooked", true)
			instance.Activated:Connect(function()
				hubClick(note)
			end)
		end
	end
	for _, descendant in ipairs(hub:GetDescendants()) do
		hookHub(descendant)
	end
	hub.DescendantAdded:Connect(hookHub)
end)
