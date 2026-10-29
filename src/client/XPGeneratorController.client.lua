--------------------------------------------------
-- XP GENERATOR CONTROLLER
--
-- CLIENT ONLY, display only. Each generator pad gets:
--   * a slim label (multiplier + what it needs) that lives in the WORLD,
--     so neighbouring labels can never overlap at any distance
--   * a floating oil icon above it: bigger and more colourful for higher
--     multipliers (x1 smallest ... x1000 largest), with sparkles and a
--     colour-cycling glow on the two admin generators
-- The GenX6 label also shows the limited-time claim state (waiting /
-- ready / active / back tomorrow) published by the server.
--
-- The server (BallPhysicsController) decides what a generator pays;
-- nothing here awards XP.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))

local generatorsFolder = Workspace:WaitForChild("XPGenerators")

assert(
	generatorsFolder:IsA("Model"),
	"[XPGeneratorController] XPGenerators must be a Model."
)

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local FONT = Enum.Font.FredokaOne

-- Display only. The server (BallPhysicsController) is the authority.
local DISPLAY_REBIRTH_REQUIREMENT = {
	GenX2 = 2,
	GenX4 = 4,
	GenX8 = 8,
	GenX10 = 10,
}

local addFade -- defined below (the icon builder needs it first)
local GUI_NAME = "GeneratorFloatingUI"
local ICON_NAME = "GeneratorIcon"

-- World sizes, in studs
local LABEL_WIDTH = 9.0
local LABEL_HEIGHT = 2.7
local LABEL_LIFT = 6.6 -- label centre above the pad's top surface (raised so it is not in the camera's face)

--------------------------------------------------
-- GENERATOR CONFIGURATION
--------------------------------------------------

local generatorInfo = {
	GenX1 = { Top = "NO REBIRTH", Bottom = "X1", Color = Color3.fromRGB(90, 255, 155) },
	GenX2 = { Top = "REBIRTH 2 REQUIRED", Bottom = "X2", Color = Color3.fromRGB(90, 210, 255) },
	GenX4 = { Top = "REBIRTH 4 REQUIRED", Bottom = "X4", Color = Color3.fromRGB(155, 115, 255) },
	GenX6 = { Top = "LIMITED-TIME GIFT", Bottom = "X6", Color = Color3.fromRGB(255, 205, 75) },
	GenX8 = { Top = "REBIRTH 8 REQUIRED", Bottom = "X8", Color = Color3.fromRGB(255, 125, 190) },
	GenX10 = { Top = "REBIRTH 10 REQUIRED", Bottom = "X10", Color = Color3.fromRGB(255, 100, 100) },
	["GenX100 Admin XP"] = { Top = "ADMIN PASS", Bottom = "X100", Color = Color3.fromRGB(255, 190, 65) },
	["GenX1000 Admin XP"] = { Top = "ADMIN PASS", Bottom = "X1000", Color = Color3.fromRGB(255, 90, 90) },
}

local ADMIN_NAMES = {
	["GenX100 Admin XP"] = true,
	["GenX1000 Admin XP"] = true,
}

-- Which uploaded oil image (and tint) each tier uses once UiAssets has ids.
local ICON_STYLE = {
	GenX1 = { Variant = "Green", Tint = Color3.new(1, 1, 1) },
	GenX2 = { Variant = "Green", Tint = Color3.fromRGB(130, 255, 220) },
	GenX4 = { Variant = "Yellow", Tint = Color3.new(1, 1, 1) },
	GenX6 = { Variant = "Yellow", Tint = Color3.fromRGB(255, 230, 120) },
	GenX8 = { Variant = "Black", Tint = Color3.new(1, 1, 1) },
	GenX10 = { Variant = "Black", Tint = Color3.new(1, 1, 1) },
}

local function multiplierOf(part)
	return tonumber(part.Name:match("GenX(%d+)")) or 1
end

local function formatClock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

--------------------------------------------------
-- X6 STATE (published by the server as player attributes)
--------------------------------------------------

local function x6Text()
	local mode = player:GetAttribute("X6Mode")
	local untilTime = player:GetAttribute("X6Until")
	local remaining = typeof(untilTime) == "number"
		and (untilTime - Workspace:GetServerTimeNow())
		or 0

	if mode == "Waiting" then
		return "FREE IN " .. formatClock(remaining)
	elseif mode == "Ready" then
		return "FREE NOW! CLAIM"
	elseif mode == "Active" then
		return "ACTIVE " .. formatClock(remaining)
	end

	return "LIMITED-TIME GIFT"
end

--------------------------------------------------
-- ICONS (shared animation loop)
--------------------------------------------------

local icons = {} -- list of { Root, Glow, Admin, Phase, Sparks, Parent }

local function createGeneratorIcon(part, info)
	local old = part:FindFirstChild(ICON_NAME)
	if old then
		old:Destroy()
	end

	local multiplier = multiplierOf(part)
	local isAdmin = ADMIN_NAMES[part.Name] == true

	-- Diameter in studs: x1 = 2.4 ... x1000 = 6.0
	local diameter = 2.4 + 1.2 * math.log10(math.max(multiplier, 1))
	local labelTop = part.Size.Y / 2 + LABEL_LIFT + LABEL_HEIGHT / 2

	local billboard = Instance.new("BillboardGui")
	billboard.Name = ICON_NAME
	billboard.Adornee = part
	billboard.Size = UDim2.fromScale(diameter * 1.9, diameter * 1.9)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, labelTop + 0.5 + diameter / 2 + 0.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.Parent = part

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(0.53, 0.53)
	root.Parent = billboard

	-- Tier-coloured glow behind the icon
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.35, 1.35)
	glow.BackgroundColor3 = info.Color
	glow.BackgroundTransparency = 0.6
	glow.Parent = root
	Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

	-- The oil icon (image if uploaded, otherwise a drawn droplet)
	local style = ICON_STYLE[part.Name] or { Variant = "Black", Tint = Color3.new(1, 1, 1) }
	local imageId = UiAssets.OilImages[style.Variant]

	if imageId ~= nil and imageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = imageId
		image.ImageColor3 = style.Tint
		image.ScaleType = Enum.ScaleType.Fit
		image.Parent = root
	else
		local drop = Instance.new("Frame")
		drop.Size = UDim2.fromScale(1, 1)
		drop.BackgroundColor3 = Color3.fromRGB(38, 34, 52)
		drop.Parent = root
		Instance.new("UICorner", drop).CornerRadius = UDim.new(1, 0)

		local rim = Instance.new("UIStroke")
		rim.Color = info.Color
		rim.Thickness = 3
		rim.Parent = drop

		local shine = Instance.new("Frame")
		shine.BackgroundColor3 = CREAM
		shine.BackgroundTransparency = 0.25
		shine.Position = UDim2.fromScale(0.2, 0.18)
		shine.Size = UDim2.fromScale(0.24, 0.16)
		shine.Parent = drop
		Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)
	end

	-- Admin generators: orbiting sparkles
	local sparks = {}
	if isAdmin then
		for index = 1, 6 do
			local spark = Instance.new("TextLabel")
			spark.BackgroundTransparency = 1
			spark.AnchorPoint = Vector2.new(0.5, 0.5)
			spark.Size = UDim2.fromScale(0.22, 0.22)
			spark.Font = FONT
			spark.Text = "*"
			spark.TextScaled = true
			spark.TextColor3 = Color3.fromRGB(255, 240, 160)
			spark.Parent = root
			sparks[index] = spark
		end
	end

	table.insert(icons, {
		Root = root,
		Glow = glow,
		Admin = isAdmin,
		Phase = math.random() * math.pi * 2,
		Sparks = sparks,
		Parent = billboard,
	})
	addFade(billboard, part)
end

-- The labels and icons fade out when the camera is close (they used to sit right
-- in the player's face on the platforms) and are fully readable from a distance.
-- Their height is unchanged so they do not cover the leaderboards on the back wall.
local fadeList = {} -- { Billboard, Group, Part }
local FADE_NEAR, FADE_FAR = 16, 50
local NEAR_TRANSPARENCY, FAR_TRANSPARENCY = 0.85, 0.06 -- nearly see-through right next to it
local NEAR_SCALE = 0.55 -- and smaller, so it never fills the screen

addFade = function(billboard, part)
	local group = Instance.new("CanvasGroup")
	group.Name = "Fade"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	for _, child in ipairs(billboard:GetChildren()) do
		child.Parent = group
	end
	group.Parent = billboard
	table.insert(fadeList, { Billboard = billboard, Group = group, Part = part, Base = billboard.Size })
end

RunService.Heartbeat:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for index = #fadeList, 1, -1 do
		local entry = fadeList[index]
		if not entry.Billboard.Parent or not entry.Part.Parent then
			table.remove(fadeList, index)
		else
			local distance = (entry.Part.Position + Vector3.new(0, 5, 0) - cameraPosition).Magnitude
			local k = math.clamp((distance - FADE_NEAR) / (FADE_FAR - FADE_NEAR), 0, 1)
			entry.Group.GroupTransparency = NEAR_TRANSPARENCY + (FAR_TRANSPARENCY - NEAR_TRANSPARENCY) * k
			local scale = NEAR_SCALE + (1 - NEAR_SCALE) * k
			entry.Billboard.Size = UDim2.fromScale(entry.Base.X.Scale * scale, entry.Base.Y.Scale * scale)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for index = #icons, 1, -1 do
		local icon = icons[index]

		if not icon.Parent.Parent then
			table.remove(icons, index)
		else
			-- Smooth idle float (fractions of the icon, so it scales with it)
			icon.Root.Position = UDim2.fromScale(0.5, 0.5 + math.sin(now * 1.8 + icon.Phase) * 0.035)
			icon.Root.Rotation = math.sin(now * 1.1 + icon.Phase) * 4

			icon.Glow.BackgroundTransparency = 0.6 + math.sin(now * 2.4 + icon.Phase) * 0.12

			if icon.Admin then
				-- Colour-cycling glow + orbiting sparkles
				icon.Glow.BackgroundColor3 = Color3.fromHSV((now * 0.25 + icon.Phase) % 1, 0.7, 1)
				icon.Glow.BackgroundTransparency = 0.45 + math.sin(now * 4 + icon.Phase) * 0.15

				for sparkIndex, spark in ipairs(icon.Sparks) do
					local angle = now * 1.6 + (sparkIndex / #icon.Sparks) * math.pi * 2
					spark.Position = UDim2.fromScale(
						0.5 + math.cos(angle) * 0.78,
						0.5 + math.sin(angle) * 0.55
					)
					spark.TextTransparency = 0.2 + (math.sin(now * 5 + sparkIndex) * 0.5 + 0.5) * 0.5
				end
			end
		end
	end
end)

--------------------------------------------------
-- LABEL
--------------------------------------------------

local WorldConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig"))

local function createGeneratorUI(part, world)
	if not part:IsA("BasePart") then
		return
	end

	local info = generatorInfo[part.Name]

	if not info then
		warn("[XPGeneratorController] No configuration for:", part:GetFullName())
		return
	end

	-- copies in the higher worlds show that world's (bigger) numbers; the
	-- server applies the same WorldConfig rules
	local worldRequirement = nil
	if world and world.Id > 1 then
		local base = tonumber(string.match(info.Bottom, "%d+")) or 1
		local adjusted = table.clone(info)
		if world.Admin[part.Name] then
			adjusted.Bottom = "X" .. world.Admin[part.Name]
		elseif world.Generators and world.Generators[part.Name] then
			local value = world.Generators[part.Name]
			adjusted.Bottom = "X" .. value
			if part.Name ~= "GenX6" then
				worldRequirement = value
				-- the lowest one is open to everyone who reached this world
				adjusted.Top = part.Name == "GenX1" and "STARTER" or ("REBIRTH " .. value .. " REQUIRED")
			end
		end
		local _ = base
		info = adjusted
	end

	-- Avoid duplicate interfaces.
	local existing = part:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = GUI_NAME
	billboard.Adornee = part
	billboard.Size = UDim2.fromScale(LABEL_WIDTH, LABEL_HEIGHT)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + LABEL_LIFT, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.Parent = part

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = CREAM
	background.BorderSizePixel = 0
	background.Parent = billboard

	Instance.new("UICorner", background).CornerRadius = UDim.new(0.5, 0)

	local outline = Instance.new("UIStroke")
	outline.Color = info.Color
	outline.Thickness = 3
	outline.Parent = background

	local multiplier = Instance.new("TextLabel")
	multiplier.Name = "Multiplier"
	multiplier.BackgroundTransparency = 1
	multiplier.Position = UDim2.fromScale(0.04, 0.06)
	multiplier.Size = UDim2.fromScale(0.42, 0.88)
	multiplier.Font = FONT
	multiplier.Text = info.Bottom
	multiplier.TextColor3 = info.Color
	multiplier.TextScaled = true
	multiplier.Parent = background

	local textOutline = Instance.new("UIStroke")
	textOutline.Color = INK
	textOutline.Thickness = 2
	textOutline.Parent = multiplier

	-- the powerful generators (X10 and the admin ones) get a rich gold gradient
	if info.Bottom == "X10" or ADMIN_NAMES[part.Name] then
		background.BackgroundColor3 = Color3.new(1, 1, 1)
		local rich = Instance.new("UIGradient")
		rich.Rotation = 90
		rich.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 196)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 214, 110)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 160, 60)),
		})
		rich.Parent = background
		outline.Thickness = 5
		outline.Color = Color3.fromRGB(120, 60, 10)
	end

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.BackgroundTransparency = 1
	requirement.Position = UDim2.fromScale(0.47, 0.12)
	requirement.Size = UDim2.fromScale(0.5, 0.76)
	requirement.Font = FONT
	requirement.Text = info.Top
	requirement.TextColor3 = INK
	requirement.TextScaled = true
	requirement.TextWrapped = true
	requirement.Parent = background

	--------------------------------------------------
	-- LIVE STATE (display only; server decides real access)
	--
	-- Locked    -> dimmed
	-- Earning   -> "EARNING XP" while the server reports this generator
	--              as the player's ActiveXPGenerator
	-- GenX6     -> shows the claim timer
	--------------------------------------------------

	local requiredRebirths = worldRequirement or DISPLAY_REBIRTH_REQUIREMENT[part.Name]
	local isX6 = part.Name == "GenX6"
	if isX6 then
		-- timer on top (big), the XP amount below it (a bit smaller)
		requirement.Position = UDim2.fromScale(0.08, 0.04)
		requirement.Size = UDim2.fromScale(0.84, 0.55)
		multiplier.Position = UDim2.fromScale(0.2, 0.58)
		multiplier.Size = UDim2.fromScale(0.6, 0.38)
		multiplier.Text = info.Bottom .. " XP"
	end

	local function refreshState()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local earning = player:GetAttribute("ActiveXPGenerator") == part.Name
		local locked = requiredRebirths ~= nil and rebirths < requiredRebirths

		if isX6 then
			locked = player:GetAttribute("X6Mode") ~= "Active"
		end

		if earning then
			requirement.Text = "EARNING XP"
			requirement.TextColor3 = Color3.fromRGB(190, 105, 10)
		else
			requirement.Text = isX6 and x6Text() or info.Top
			requirement.TextColor3 = INK
		end

		background.BackgroundTransparency = locked and 0.3 or 0
		multiplier.TextTransparency = locked and 0.4 or 0
	end

	local connections = {
		player:GetAttributeChangedSignal("Rebirths"):Connect(refreshState),
		player:GetAttributeChangedSignal("ActiveXPGenerator"):Connect(refreshState),
		player:GetAttributeChangedSignal("X6Mode"):Connect(refreshState),
		player:GetAttributeChangedSignal("X6Until"):Connect(refreshState),
	}

	-- The X6 countdown ticks once a second.
	local ticking = isX6
	if isX6 then
		task.spawn(function()
			while ticking and billboard.Parent do
				refreshState()
				task.wait(0.5)
			end
		end)
	end

	billboard.Destroying:Once(function()
		ticking = false
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)

	addFade(billboard, part)
	refreshState()
	createGeneratorIcon(part, info)
end

--------------------------------------------------
-- INITIAL GENERATORS
--------------------------------------------------

for _, instance in ipairs(generatorsFolder:GetDescendants()) do
	createGeneratorUI(instance)
end

generatorsFolder.DescendantAdded:Connect(function(instance)
	task.defer(function()
		if instance:IsDescendantOf(generatorsFolder) then
			createGeneratorUI(instance)
		end
	end)
end)

-- rolling onto a higher world's admin generator without its pass opens the
-- Roblox purchase prompt for that world's pass (the server re-checks ownership)
task.spawn(function()
	local MarketplaceService = game:GetService("MarketplaceService")
	local owned, lastPrompt = {}, 0
	-- a finished purchase must not leave a stale "not owned" answer (it would prompt again)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, passId, purchased)
		if who == player then
			owned[passId] = purchased and true or nil
		end
	end)
	while true do
		task.wait(0.3)
		local world = WorldConfig.Of(player)
		-- world 1 is the original lobby (Workspace.XPGenerators); the other worlds are copies
		local worldModel = Workspace:FindFirstChild("Worlds") and Workspace.Worlds:FindFirstChild("World" .. world.Id)
		local gens = world.Id == 1 and Workspace:FindFirstChild("XPGenerators")
			or (worldModel and worldModel:FindFirstChild("XPGenerators"))
		local balls = Workspace:FindFirstChild("PlayerBalls")
		local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
		if world.AdminPass and gens and ball and os.clock() - lastPrompt > 6 then
			for name, passId in pairs(world.AdminPass) do
				local part = gens:FindFirstChild(name, true)
				if part and part:IsA("BasePart") then
					local here = part.CFrame:PointToObjectSpace(ball.Position)
					if math.abs(here.X) < part.Size.X / 2 + 1.5 and math.abs(here.Z) < part.Size.Z / 2 + 1.5 then
						if owned[passId] == nil then
							local ok, has = pcall(function()
								return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
							end)
							owned[passId] = ok and has or nil
						end
						if owned[passId] == false then
							lastPrompt = os.clock()
							MarketplaceService:PromptGamePassPurchase(player, passId)
						end
					end
				end
			end
		end
	end
end)

-- generator copies in the higher worlds
task.spawn(function()
	local worlds = Workspace:WaitForChild("Worlds", 60)
	if not worlds then
		return
	end
	local function scan(folder)
		local id = folder:GetAttribute("WorldId")
		local gens = folder:FindFirstChild("XPGenerators")
		if id and gens and not folder:GetAttribute("GenUIBuilt") then
			folder:SetAttribute("GenUIBuilt", true)
			for _, instance in ipairs(gens:GetDescendants()) do
				task.spawn(createGeneratorUI, instance, WorldConfig.Get(id)) -- one slow icon must not block the rest
			end
			-- instance streaming brings far-away copies in later
			gens.DescendantAdded:Connect(function(instance)
				task.defer(createGeneratorUI, instance, WorldConfig.Get(id))
			end)
		end
	end
	for _, folder in ipairs(worlds:GetChildren()) do
		scan(folder)
	end
	worlds.ChildAdded:Connect(function(folder)
		task.defer(scan, folder)
	end)
end)

print("[XPGeneratorController] Floating generator UI ready.")
