--------------------------------------------------
-- HAPTICS (client, feel only)
--
-- Short vibration pulses for the multiplier count-up. Uses Roblox's HapticService on
-- whatever the device reports as supporting vibration (touch screen first, then a
-- connected gamepad). Everything is wrapped in pcall and checked at call time: on a
-- device without vibration support (most PCs, and phones where Roblox does not
-- expose it) every call is a harmless no-op.
--------------------------------------------------

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")

local Haptics = {}

local TARGETS = {
	{ Input = Enum.UserInputType.Touch, Motor = Enum.VibrationMotor.Large },
	{ Input = Enum.UserInputType.Gamepad1, Motor = Enum.VibrationMotor.Large },
	{ Input = Enum.UserInputType.Gamepad1, Motor = Enum.VibrationMotor.Small },
}

local function supported(target)
	local ok, result = pcall(function()
		return HapticService:IsVibrationSupported(target.Input) and HapticService:IsMotorSupported(target.Input, target.Motor)
	end)
	return ok and result == true
end

local token = 0

-- strength 0..1, seconds = how long the pulse lasts (kept short so ticks feel crisp)
function Haptics.Pulse(strength, seconds)
	strength = math.clamp(tonumber(strength) or 0.3, 0, 1)
	seconds = math.clamp(tonumber(seconds) or 0.05, 0.02, 0.4)

	token += 1
	local mine = token
	local used = {}

	for _, target in ipairs(TARGETS) do
		if supported(target) then
			pcall(function()
				HapticService:SetMotor(target.Input, target.Motor, strength)
			end)
			table.insert(used, target)
		end
	end

	if #used > 0 then
		task.delay(seconds, function()
			-- a newer pulse owns the motors now; do not cut it short
			if token ~= mine then
				return
			end
			for _, target in ipairs(used) do
				pcall(function()
					HapticService:SetMotor(target.Input, target.Motor, 0)
				end)
			end
		end)
	end
end

-- a short double-tap "thump" for the moment a multiplier lands
function Haptics.Thump()
	Haptics.Pulse(0.9, 0.09)
	task.delay(0.12, function()
		Haptics.Pulse(0.55, 0.07)
	end)
end

function Haptics.Stop()
	token += 1
	for _, target in ipairs(TARGETS) do
		if supported(target) then
			pcall(function()
				HapticService:SetMotor(target.Input, target.Motor, 0)
			end)
		end
	end
end

-- silences anything still running when the window loses focus
UserInputService.WindowFocusReleased:Connect(Haptics.Stop)

return Haptics
