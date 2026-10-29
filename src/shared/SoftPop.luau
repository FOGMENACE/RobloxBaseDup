--------------------------------------------------
-- SOFT POP (client, sound only)
--
-- The smooth little "pop" when a dragged number lands (XP into the level bar, oil into
-- the meter, a multiplier into its total). Quiet, with a slightly different pitch each
-- time, and never more often than MIN_GAP, so a stream of pickups stays pleasant.
--------------------------------------------------

local SoundService = game:GetService("SoundService")

local SoftPop = {}

local POP_SOUND = "rbxassetid://72264591133889" -- "ui-pop-sound" (Creator Store, free)
local MIN_GAP = 0.18

local sound = Instance.new("Sound")
sound.Name = "SoftPop"
sound.SoundId = POP_SOUND
sound.Volume = 0.35
sound.Parent = SoundService

local rng = Random.new()
local last = 0

-- strength 0..1: bigger landings are a touch louder and lower
function SoftPop.Play(strength)
	local now = os.clock()
	if now - last < MIN_GAP then
		return
	end
	last = now
	strength = math.clamp(tonumber(strength) or 0.5, 0, 1)
	sound.Volume = 0.22 + 0.25 * strength
	sound.PlaybackSpeed = (1.12 - 0.22 * strength) * rng:NextNumber(0.95, 1.06)
	sound.TimePosition = 0
	sound:Play()
end

return SoftPop
