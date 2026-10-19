--------------------------------------------------
-- BALL NAME TAGS (client, visual)
--
-- A tag above every player's ball:  [REBIRTHS] DisplayName  (no "x").
-- The bracketed number is coloured by the player's rebirth zone.
--
-- The tag lives on its own invisible anchored part that follows only the
-- ball's POSITION every frame (smoothed, always upright), so it never
-- rolls, spins or bounces with the ball. Text comes from replicated
-- server data (Rebirths attribute, Player.DisplayName).
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local playerBalls = workspace:WaitForChild("PlayerBalls")

local ZONES = {
	{ From = 0, Color = Color3.fromRGB(150, 235, 90) }, -- lime
	{ From = 5, Color = Color3.fromRGB(80, 220, 230) }, -- aqua
	{ From = 10, Color = Color3.fromRGB(100, 150, 255) }, -- blue
	{ From = 20, Color = Color3.fromRGB(190, 120, 255) },
	{ From = 40, Color = Color3.fromRGB(255, 200, 70) },
	{ From = 75, Color = Color3.fromRGB(255, 90, 130) },
}

local function zoneColor(rebirths)
	local color = ZONES[1].Color
	for _, zone in ipairs(ZONES) do
		if rebirths >= zone.From then
			color = zone.Color
		end
	end
	return color
end

local function hex(color)
	return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local folder = workspace:FindFirstChild("BallNameTags")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "BallNameTags"
folder.Parent = workspace

local tags = {} -- [ball] = { Anchor, Label, Player, Height, Smoothed }

local function setText(entry)
	local player = entry.Player
	local rebirths = math.floor(player:GetAttribute("Rebirths") or 0)
	local name = player.DisplayName:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

	entry.Label.RichText = true
	entry.Label.Text = string.format('<font color="%s">[%d]</font> %s', hex(zoneColor(rebirths)), rebirths, name)
end

local function remove(ball)
	local entry = tags[ball]
	if entry then
		entry.Anchor:Destroy()
		tags[ball] = nil
	end
end

local function add(ball)
	if not ball:IsA("BasePart") or tags[ball] then
		return
	end

	local userId = tonumber(ball.Name:match("^PlayerBall_(%d+)$"))
	local player = userId and Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "Tag_" .. userId
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 36)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 18, 30)
	stroke.Parent = label

	local entry = {
		Anchor = anchor,
		Label = label,
		Player = player,
		Height = ball.Size.Y / 2 + 2.6,
		Smoothed = ball.Position.Y,
	}
	tags[ball] = entry

	setText(entry)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		if tags[ball] == entry then
			setText(entry)
		end
	end)

	ball.AncestryChanged:Connect(function(_, parent)
		if not parent then
			remove(ball)
		end
	end)
end

playerBalls.ChildAdded:Connect(function(ball)
	task.defer(add, ball)
end)
for _, ball in ipairs(playerBalls:GetChildren()) do
	add(ball)
end

-- Follow the ball's position only. Height is smoothed so little bounces on
-- the lane do not make the tag jitter.
RunService.RenderStepped:Connect(function(deltaTime)
	local alpha = 1 - math.exp(-14 * deltaTime)

	for ball, entry in pairs(tags) do
		if ball.Parent then
			local position = ball.Position
			local velocity = ball.AssemblyLinearVelocity

			-- dead-reckon so a fast-moving ball (win course) does not leave
			-- the tag behind/under it between replication steps
			if not entry.Track or (entry.Track - position).Magnitude > 40 + velocity.Magnitude * 0.45 then
				entry.Track = position
				entry.Velocity = velocity
			end
			-- slowing down is followed at once so the tag never overshoots a stopped ball
			if velocity.Magnitude < entry.Velocity.Magnitude then
				entry.Velocity = velocity
			else
				entry.Velocity = entry.Velocity:Lerp(velocity, 1 - math.exp(-6 * deltaTime))
			end
			entry.Track = (entry.Track + entry.Velocity * deltaTime):Lerp(position, 1 - math.exp(-5 * deltaTime))
			local tracked = entry.Track

			entry.Smoothed += (tracked.Y - entry.Smoothed) * alpha
			-- never let the tag sink below the top of the ball
			entry.Smoothed = math.max(entry.Smoothed, tracked.Y - 0.5)

			local camera = workspace.CurrentCamera
			if entry.Player == Players.LocalPlayer and ball:GetAttribute("WinCourseActive") == true and camera then
				-- WinCourse: the chase camera keeps the ball in the middle of the
				-- frame, so the tag is pinned to the CAMERA (right above that
				-- spot) instead of chasing a ball that moves hundreds of studs
				-- per second. It cannot jitter, drift or end up under the ball.
				local cf = camera.CFrame
				local depth = math.max((tracked - cf.Position):Dot(cf.LookVector), 4)
				entry.Anchor.CFrame = CFrame.new(cf.Position + cf.LookVector * depth + cf.UpVector * (entry.Height * 0.85))
			else
				entry.Anchor.CFrame = CFrame.new(tracked.X, entry.Smoothed + entry.Height, tracked.Z)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for ball, entry in pairs(tags) do
		if entry.Player == player then
			remove(ball)
		end
	end
end)
