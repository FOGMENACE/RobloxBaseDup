--------------------------------------------------
-- SHINE (shared UI helper)
--
-- A soft diagonal glare that sweeps across a button for a moment every
-- few seconds (default: 0.9 s sweep every 5 s). One shared loop drives
-- every shine, so attaching it to many buttons is cheap.
--
--   Shine.Attach(button, { Offset = 0.7, Interval = 5, Strength = 0.5 })
--
-- Offset staggers neighbouring buttons so they do not all flash at once.
-- Purely visual; the shine never intercepts clicks.
--------------------------------------------------

local RunService = game:GetService("RunService")

local Shine = {}

local SWEEP_TIME = 0.9
local entries = {}
local connection = nil

local function ensureLoop()
	if connection then
		return
	end

	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()

		for index = #entries, 1, -1 do
			local entry = entries[index]

			if not entry.Frame.Parent then
				table.remove(entries, index)
			else
				local t = (now + entry.Offset) % entry.Interval

				if t < SWEEP_TIME then
					entry.Frame.Visible = true
					entry.Frame.Position = UDim2.fromScale(-0.3 + (t / SWEEP_TIME) * 1.6, 0.5)
				else
					entry.Frame.Visible = false
				end
			end
		end
	end)
end

function Shine.Attach(button, options)
	options = options or {}

	button.ClipsDescendants = true

	local frame = Instance.new("Frame")
	frame.Name = "Shine"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.new(0.22, 0, 2.4, 0)
	frame.Position = UDim2.fromScale(-0.3, 0.5)
	frame.Rotation = 20
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Visible = false
	frame.ZIndex = (button.ZIndex or 1) + 20

	-- Soft edges: fully clear at the sides, bright in the middle.
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 1 - (options.Strength or 0.55)),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame

	frame.Parent = button

	table.insert(entries, {
		Frame = frame,
		Offset = options.Offset or 0,
		Interval = options.Interval or 5,
	})

	ensureLoop()
	return frame
end

return Shine
