--------------------------------------------------
-- SKY ANIMATOR (CLIENT, visual only)
--
-- Slowly turns / bobs the sky decoration that SkyDecor tags "SkyDecorSpin":
-- the bowling-ball planet rotates, the giant pins tumble, the oil drop bobs.
-- Each part keeps its base CFrame (attribute SkyBase); nothing collides.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local parts = {}
local function add(part)
	if part:IsA("BasePart") then
		parts[part] = true
	end
end
for _, part in ipairs(CollectionService:GetTagged("SkyDecorSpin")) do
	add(part)
end
CollectionService:GetInstanceAddedSignal("SkyDecorSpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SkyDecorSpin"):Connect(function(part)
	parts[part] = nil
end)

local last = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - last < 1 / 30 then
		return -- 30 updates a second is plenty this far away
	end
	last = now
	for part in pairs(parts) do
		if not part.Parent then
			parts[part] = nil
		else
			local base = part:GetAttribute("SkyBase")
			local spin = part:GetAttribute("SkySpin")
			local bob = part:GetAttribute("SkyBob") or 0
			if typeof(base) == "CFrame" and typeof(spin) == "Vector3" then
				local offset = Vector3.new(0, math.sin(now * 0.6 + base.Position.X * 0.01) * bob, 0)
				part.CFrame = (base + offset) * CFrame.Angles(now * spin.X, now * spin.Y, now * spin.Z)
			end
		end
	end
end)