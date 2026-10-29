--------------------------------------------------
-- BADGE OVERLAY (client, shared module)
--
-- A "!" badge that hangs over the corner of a button must be drawn ABOVE
-- the neighbouring buttons. Parented inside its own button, later siblings
-- paint over it, so a VISUAL COPY of the badge is drawn in one overlay layer
-- per ScreenGui (very high ZIndex) and follows its button every frame.
--
-- The original badge stays where it is (callers keep finding it by name and
-- keep setting Visible / Text / its UIScale); it is shrunk to nothing and
-- the copy mirrors its Visible, Text and scale.
--
--   BadgeOverlay.Attach(badge, button, { Dx = 4, Dy = 2 })
--------------------------------------------------

local RunService = game:GetService("RunService")

local BadgeOverlay = {}

local layers = {} -- [ScreenGui] = { Frame, Items = { [original] = item } }
local connected = false

local function isButtonShown(button)
	local current = button
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") then
			return current.Enabled
		end
		current = current.Parent
	end
	return true
end

local function step()
	for gui, layer in pairs(layers) do
		if not gui.Parent then
			layers[gui] = nil
		else
			for original, item in pairs(layer.Items) do
				if not original.Parent or not item.Button.Parent then
					item.Visual:Destroy()
					layer.Items[original] = nil
				else
					local button = item.Button
					local shown = original.Visible and isButtonShown(button)

					if shown then
						local origin = layer.Frame.AbsolutePosition
						local position = button.AbsolutePosition
						local size = button.AbsoluteSize
						item.Visual.Position = UDim2.fromOffset(
							position.X - origin.X + size.X + item.Dx,
							position.Y - origin.Y + item.Dy
						)

						if item.Visual.Text ~= original.Text then
							item.Visual.Text = original.Text
						end
						if item.Visual.TextColor3 ~= original.TextColor3 then
							item.Visual.TextColor3 = original.TextColor3
						end

						if item.OriginalScale and item.VisualScale then
							item.VisualScale.Scale = item.OriginalScale.Scale
						end
					end

					item.Visual.Visible = shown
				end
			end
		end
	end
end

local function layerFor(gui)
	local layer = layers[gui]
	if layer then
		return layer
	end

	local frame = Instance.new("Frame")
	frame.Name = "BadgeLayer"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 500
	frame.Active = false
	frame.Parent = gui

	layer = { Frame = frame, Items = {} }
	layers[gui] = layer

	if not connected then
		connected = true
		RunService.RenderStepped:Connect(step)
	end

	return layer
end

function BadgeOverlay.Attach(original, button, options)
	options = options or {}
	local gui = button:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui then
		return
	end

	local layer = layerFor(gui)

	local visual = original:Clone()
	visual.Name = "BadgeVisual"
	visual.AnchorPoint = Vector2.new(1, 0)
	visual.ZIndex = 500
	visual.Visible = false
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = 501
		end
	end
	visual.Parent = layer.Frame

	-- hide the original without touching the properties callers use
	original.Size = UDim2.new()
	original.BackgroundTransparency = 1
	original.TextTransparency = 1
	for _, descendant in ipairs(original:GetDescendants()) do
		if descendant:IsA("UIStroke") then
			descendant.Enabled = false
		end
	end

	layer.Items[original] = {
		Button = button,
		Visual = visual,
		VisualScale = visual:FindFirstChildOfClass("UIScale"),
		OriginalScale = original:FindFirstChildOfClass("UIScale"),
		Dx = options.Dx or 4,
		Dy = options.Dy or 2,
	}
end

return BadgeOverlay
