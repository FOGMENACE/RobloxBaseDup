--------------------------------------------------
-- PORTAL ANIMATOR
--
-- CLIENT ONLY, visual. The WORLDS portal (built by WorldService) tags the
-- gradients of its swirl "PortalSwirl" and its floor chevrons "PortalChevron".
-- A single loop turns the gradients and ripples the chevrons toward the wall,
-- locally, so there is no per-part physics or server traffic.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local swirls = {}
local chevrons = {}

local function track(set)
	return function(instance)
		set[instance] = true
	end
end

local function untrack(set)
	return function(instance)
		set[instance] = nil
	end
end

for _, instance in ipairs(CollectionService:GetTagged("PortalSwirl")) do
	swirls[instance] = true
end
for _, instance in ipairs(CollectionService:GetTagged("PortalChevron")) do
	chevrons[instance] = true
end
CollectionService:GetInstanceAddedSignal("PortalSwirl"):Connect(track(swirls))
CollectionService:GetInstanceAddedSignal("PortalChevron"):Connect(track(chevrons))
CollectionService:GetInstanceRemovedSignal("PortalSwirl"):Connect(untrack(swirls))
CollectionService:GetInstanceRemovedSignal("PortalChevron"):Connect(untrack(chevrons))

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for gradient in pairs(swirls) do
		if not gradient.Parent then
			swirls[gradient] = nil
		else
			gradient.Rotation = (now * (gradient:GetAttribute("SpinSpeed") or 60)) % 360
		end
	end

	-- a pulse runs along the three chevrons toward the portal
	for bar in pairs(chevrons) do
		if not bar.Parent then
			chevrons[bar] = nil
		else
			local index = bar:GetAttribute("ChevronIndex") or 1
			local wave = (math.sin(now * 4 + index * 1.4) + 1) / 2
			bar.Transparency = 0.7 - wave * 0.65
		end
	end
end)