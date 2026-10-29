--------------------------------------------------
-- WORLD SERVICE (SERVER)
--
-- Builds the higher worlds as full, re-themed copies of the lobby (see
-- WorldConfig), places portals, and owns which world each player is in
-- (attribute "World", saved in DataStore "WorldPref_v1"). Entering a world
-- is validated here against the player's rebirths; the client only asks.
-- The copies are scenery: gameplay stations map a copied position back onto
-- the original (WorldConfig offsets), so every existing system keeps working.
--------------------------------------------------

local Players = game:GetService("Players")
local DataRetry = require(game:GetService("ServerScriptService"):WaitForChild("DataRetry"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local SKIP = {
	Terrain = true, Camera = true, PlayerBalls = true, Course = true, FinishWall = true,
	WinCourse = true, Worlds = true, SkyDecor = true,
}
local PORTAL_RADIUS = 5

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function remote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end
local worldTeleport = remote("WorldTeleport") -- client -> server: (worldId)
local worldNotice = remote("WorldNotice") -- server -> client: (kind, data)

local store = DataStoreService:GetDataStore("WorldPref_v1")

local spawnPart = Workspace:WaitForChild("BallSpawn")
local startWall = Workspace:WaitForChild("StartWall")

--------------------------------------------------
-- PORTALS (positions are in world-1 coordinates; each world adds its offset)
--------------------------------------------------

-- the WORLDS portal (world-1 coordinates; each copy adds its offset)
-- WALL-mounted on the west wall (centre of the disc), between the ROLL. WIN. REBIRTH!
-- screen and the ball rack that was cut in half (LobbyDecor). The disc faces the room (+X);
-- the ball rolls onto the glowing pad on the floor in front of it to open the menu.
local NEXT_PORTAL = Vector3.new(-104.2, 72, -245.5)
local FLOOR_PAD_Y = 63.55
local PAD_OFFSET_X = 3.5 -- the floor pad sits this far in front of the wall disc

local worldsFolder = Instance.new("Folder")
worldsFolder.Name = "Worlds"
worldsFolder.Parent = Workspace

local portals = {} -- { Position, From, To }

-- The WORLDS portal in every lobby: rolling into it opens the WORLDS menu.
local machines = {} -- portal centre positions

-- Simple wall portal: a dark stone-look ring around a swirling disc (a SurfaceGui whose
-- gradient layers turn on the client, see PortalAnimator), and a floor pad with chevrons
-- pointing at it. About a dozen parts and no per-part animation.
local function makePortal(parent, position, toWorld, label, color)
	local model = Instance.new("Model")
	model.Name = "Portal_To_" .. toWorld

	local hue = color:ToHSV()
	local accent = Color3.fromHSV((hue + 0.16) % 1, 0.75, 1)

	local function disc(name, diameter, thickness, dx, material, c, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder -- axis along X: a vertical disc on the wall
		p.Size = Vector3.new(thickness, diameter, diameter)
		p.CFrame = CFrame.new(position + Vector3.new(dx, 0, 0))
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material = material
		p.Color = c
		p.Transparency = transparency or 0
		p.Parent = model
		return p
	end
	local function slab(name, size, cframe, material, c, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
		p.Material = material
		p.Color = c
		p.Transparency = transparency or 0
		p.Parent = model
		return p
	end

	-- ring + glowing rim
	disc("Frame", 13.4, 0.7, -0.35, Enum.Material.Slate, Color3.fromRGB(44, 46, 84))
	disc("Rim", 11.4, 0.25, 0, Enum.Material.Neon, color)

	-- the swirl: layered gradient circles, turned by the client
	local core = disc("Core", 10.4, 0.2, 0.05, Enum.Material.SmoothPlastic, Color3.fromRGB(14, 18, 44))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(400, 400)
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = core
	local layers = {
		{ size = 1.0, speed = 35, from = color, to = color:Lerp(Color3.fromRGB(20, 24, 80), 0.7), transparency = 0 },
		{ size = 0.82, speed = -60, from = accent, to = accent:Lerp(Color3.fromRGB(30, 20, 90), 0.6), transparency = 0.1 },
		{ size = 0.6, speed = 95, from = Color3.new(1, 1, 1), to = color, transparency = 0.2 },
		{ size = 0.34, speed = -140, from = Color3.new(1, 1, 1), to = accent, transparency = 0.05 },
	}
	for _, layer in ipairs(layers) do
		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(0.5, 0.5)
		circle.Size = UDim2.fromScale(layer.size, layer.size)
		circle.BackgroundColor3 = Color3.new(1, 1, 1)
		circle.BackgroundTransparency = layer.transparency
		circle.BorderSizePixel = 0
		circle.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local gradient = Instance.new("UIGradient")
		-- hard stripes read as swirling arms once the gradient turns
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, layer.from),
			ColorSequenceKeypoint.new(0.2, layer.to),
			ColorSequenceKeypoint.new(0.33, layer.from),
			ColorSequenceKeypoint.new(0.53, layer.to),
			ColorSequenceKeypoint.new(0.66, layer.from),
			ColorSequenceKeypoint.new(0.86, layer.to),
			ColorSequenceKeypoint.new(1, layer.from),
		})
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(0.33, 0),
			NumberSequenceKeypoint.new(0.53, 0.45),
			NumberSequenceKeypoint.new(0.66, 0),
			NumberSequenceKeypoint.new(0.86, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		gradient:SetAttribute("SpinSpeed", layer.speed)
		CollectionService:AddTag(gradient, "PortalSwirl")
		gradient.Parent = circle
	end

	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	mist.Rate = 10
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Speed = NumberRange.new(2, 4)
	mist.EmissionDirection = Enum.NormalId.Right
	mist.SpreadAngle = Vector2.new(25, 25)
	mist.Color = ColorSequence.new(color)
	mist.Size = NumberSequence.new(0.5, 0)
	mist.LightEmission = 1
	mist.Parent = core
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 2
	light.Parent = core

	-- floor pad with chevrons pointing at the wall disc (roll onto it to open the menu)
	local padCenter = Vector3.new(position.X + PAD_OFFSET_X, FLOOR_PAD_Y + 0.06, position.Z)
	slab("FloorPad", Vector3.new(8.4, 0.12, 7.6), CFrame.new(padCenter), Enum.Material.Slate, Color3.fromRGB(44, 46, 84))
	for _, side in ipairs({ -1, 1 }) do
		slab("PadEdge", Vector3.new(8.4, 0.14, 0.35), CFrame.new(padCenter + Vector3.new(0, 0.02, side * 3.6)), Enum.Material.Neon, color)
	end
	for index = 1, 3 do
		local tip = padCenter + Vector3.new((index - 2) * 2.3 - 1.2, 0.08, 0) -- tip points toward the wall (-X)
		for _, side in ipairs({ -1, 1 }) do
			local center = tip + Vector3.new(1.0, 0, side * 1.0)
			local bar = slab("Chevron" .. index, Vector3.new(0.5, 0.1, 2.0), CFrame.lookAt(center, tip), Enum.Material.Neon, accent)
			bar:SetAttribute("ChevronIndex", index)
			CollectionService:AddTag(bar, "PortalChevron")
		end
	end
	local sign = Instance.new("Part")
	sign.Name = "SignAnchor"
	sign.Size = Vector3.new(1, 1, 1)
	sign.Transparency = 1
	sign.Anchored, sign.CanCollide, sign.CanTouch, sign.CanQuery = true, false, false, false
	sign.CFrame = CFrame.new(position + Vector3.new(1.5, 8.6, 0)) -- above the frame, in front of the wall
	sign.Parent = model
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(14, 3.4)
	bb.Adornee = sign
	bb.AlwaysOnTop = true -- never hidden behind the wall or the screens
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = sign
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = label
	text.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(24, 22, 34)
	stroke.Parent = text
	text.Parent = bb

	model:SetAttribute("ToWorld", toWorld)
	model.Parent = parent
	return model
end

--------------------------------------------------
-- LOBBY COPIES
--------------------------------------------------

-- A cloned SurfaceGui/BillboardGui keeps its Adornee pointing at the ORIGINAL
-- part, so the copy shows nothing. Re-point it at the copied part it sits in.
local function fixAdornees(root)
	for _, d in ipairs(root:GetDescendants()) do
		if (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) and d.Adornee and not d.Adornee:IsDescendantOf(root) then
			local host = d:FindFirstAncestorWhichIsA("BasePart")
			d.Adornee = host
		end
	end
end

local WorldSkinStyle = require(ReplicatedStorage:WaitForChild("WorldSkinStyle"))
local BALL_MESH = "rbxassetid://108970038238376"

local function theme(copy, t)
	fixAdornees(copy)
	-- display balls (shop shelves, racks) are coated in the world's evolved skin
	local displayBalls = {}
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("MeshPart") and d.MeshId == BALL_MESH then
			table.insert(displayBalls, d)
		end
	end
	task.defer(function()
		for _, ball in ipairs(displayBalls) do
			if ball.Parent then
				WorldSkinStyle.Apply(ball, t, true)
			end
		end
	end)
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size
			local flat = s.Y < 1 and s.X > 20 and s.Z > 20
			local wall = math.max(s.X, s.Z) > 25 and s.Y > 20
			if flat then
				d.Color = t.Floor
				d.Reflectance = math.max(d.Reflectance, t.Shine * 0.5)
			elseif wall then
				d.Color = t.Primary
			elseif d.Material == Enum.Material.Neon then
				d.Color = t.Glow
			else
				d.Color = d.Color:Lerp(t.Tint, 0.35)
				d.Reflectance = math.max(d.Reflectance, t.Shine * 0.3)
			end
		elseif d:IsA("SpawnLocation") then
			d.Enabled = false
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Color = t.Glow
		elseif (d:IsA("Script") or d:IsA("LocalScript")) and d.Name ~= "BowlingShopInteraction" then
			-- the shop's own touch script is kept: it works on whichever shop it sits in
			d:Destroy()
		end
	end
end

local function buildWorld(world)
	-- a persistent Model is always streamed to every client, so a ball moved
	-- here never lands before the floor has loaded
	local folder = Instance.new("Model")
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Name = "World" .. world.Id
	folder:SetAttribute("WorldId", world.Id)
	for _, child in ipairs(Workspace:GetChildren()) do
		if not SKIP[child.Name] and not child.Name:find("^PlayerCourse") and not child.Name:find("Preview")
			and (child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder")) then
			local ok, copy = pcall(function()
				return child:Clone()
			end)
			if ok and copy then
				if copy:IsA("SpawnLocation") then
					copy.Enabled = false
				end
				copy.Parent = folder
				if copy:IsA("BasePart") then
					copy.CFrame += world.Offset
				elseif copy:IsA("Model") then
					copy:PivotTo(copy:GetPivot() + world.Offset)
				else
					for _, d in ipairs(copy:GetDescendants()) do
						if d:IsA("BasePart") then
							d.CFrame += world.Offset
						end
					end
				end
			end
		end
	end
	theme(folder, world.Theme)

	-- the course lane behind this lobby's start wall: a copy of the real lane,
	-- dressed as a polished, themed maple bowling lane with metal gutters (the
	-- run itself happens on the shared course after the start wall hand-off)
	local course = Workspace:FindFirstChild("Course")
	if course then
		local lane = Instance.new("Model")
		lane.Name = "ThemedLane"
		for _, name in ipairs({ "Floor", "LeftBoundary", "RightBoundary" }) do
			local source = course:FindFirstChild(name)
			if source then
				local copy = source:Clone()
				copy:ClearAllChildren()
				copy.CFrame += world.Offset
				if name == "Floor" then
					copy.Material = Enum.Material.WoodPlanks
					copy.Color = Color3.fromRGB(226, 186, 138):Lerp(world.Theme.Floor, 0.3)
					copy.Reflectance = 0.18 + world.Theme.Shine * 0.3
					copy.Transparency = 0
				else
					copy.Color = world.Theme.Glow
				end
				copy.Parent = lane
			end
		end
		local floorPart = lane:FindFirstChild("Floor")
		if floorPart then
			local top = floorPart.Position.Y + floorPart.Size.Y / 2
			local length = math.max(floorPart.Size.X, floorPart.Size.Z)
			for _, wall in ipairs({ lane:FindFirstChild("LeftBoundary"), lane:FindFirstChild("RightBoundary") }) do
				if wall then
					local inward = (floorPart.Position.X - wall.Position.X) > 0 and 1 or -1
					local x = wall.Position.X + inward * 1.45
					local trough = Instance.new("Part")
					trough.Name = "Gutter"
					trough.Shape = Enum.PartType.Cylinder
					trough.Size = Vector3.new(length, 2.6, 2.6)
					trough.CFrame = CFrame.new(x, top - 0.95, floorPart.Position.Z) * CFrame.Angles(0, math.pi / 2, 0)
					trough.Material = Enum.Material.Metal
					trough.Color = world.Theme.Primary
					trough.Reflectance = world.Theme.Shine
					trough.Anchored, trough.CanCollide, trough.CanTouch, trough.CanQuery = true, false, false, false
					trough.Parent = lane
					local lip = Instance.new("Part")
					lip.Name = "GutterLip"
					lip.Size = Vector3.new(0.25, 0.12, length)
					lip.CFrame = CFrame.new(x - inward * 1.35, top + 0.04, floorPart.Position.Z)
					lip.Material = Enum.Material.Neon
					lip.Color = world.Theme.Accent
					lip.Anchored, lip.CanCollide, lip.CanTouch, lip.CanQuery = true, false, false, false
					lip.Parent = lane
				end
			end
		end
		lane.Parent = folder
	end

	-- the lobby previews of the oil course and win course (same as world 1)
	task.spawn(function()
		local courseRootForPreview = Workspace:FindFirstChild("Course")
		if not courseRootForPreview then
			return
		end
		for _, name in ipairs({ "LobbyCourse", "WinCoursePreview" }) do
			local source = courseRootForPreview:WaitForChild(name, 30)
			if source then
				task.wait(0.5) -- let the preview builders finish
				local ok, copy = pcall(function()
					return source:Clone()
				end)
				if ok and copy then
					for _, d in ipairs(copy:GetDescendants()) do
						if d:IsA("Script") or d:IsA("LocalScript") then
							d:Destroy()
						elseif d:IsA("TextLabel") and d.Name == "OilAmount" and d.Text == "" then
							d.Text = "???" -- hidden until the run, like world 1's preview
						elseif d:IsA("BasePart") then
							d.CFrame += world.Offset
							d.Color = d.Color:Lerp(world.Theme.Tint, 0.25)
							d.CanCollide, d.CanTouch, d.CanQuery = false, false, false -- scenery only
						end
					end
					fixAdornees(copy)
					copy.Parent = folder
				end
			end
		end
	end)

	-- this world's own finish wall (RunController checks every world's wall)
	local finish = Workspace:FindFirstChild("FinishWall")
	if finish then
		local wallCopy = finish:Clone()
		wallCopy:ClearAllChildren()
		wallCopy.Name = "FinishWall"
		wallCopy.CFrame += world.Offset
		wallCopy.Parent = folder
	end

	-- this world's own win course: a live, themed mirror of the generated
	-- tiles (tiles are added as runs need them, so new ones are mirrored too)
	local courseRoot = Workspace:FindFirstChild("Course")
	local function hookWinCourse(source)
		local mirror = Instance.new("Model")
		mirror.Name = "WinCourseMirror"
		mirror.Parent = folder
		local copies = {}
		local function mirrorChild(child)
			if copies[child] or not (child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder")) then
				return
			end
			task.wait(0.1) -- let the generator finish building the tile
			if not child.Parent then
				return
			end
			local ok, copy = pcall(function()
				return child:Clone()
			end)
			if not ok or not copy then
				return
			end
			for _, d in ipairs(copy:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Color = d.Color:Lerp(world.Theme.Tint, 0.25)
				end
			end
			if copy:IsA("BasePart") then
				copy.CFrame += world.Offset
				copy.Color = copy.Color:Lerp(world.Theme.Tint, 0.25)
			elseif copy:IsA("Model") then
				copy:PivotTo(copy:GetPivot() + world.Offset)
			else
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CFrame += world.Offset
					end
				end
			end
			fixAdornees(copy)
			copies[child] = copy
			copy.Parent = mirror
		end
		for _, child in ipairs(source:GetChildren()) do
			task.spawn(mirrorChild, child)
		end
		source.ChildAdded:Connect(function(child)
			task.spawn(mirrorChild, child)
		end)
		source.ChildRemoved:Connect(function(child)
			if copies[child] then
				copies[child]:Destroy()
				copies[child] = nil
			end
		end)
		source.Destroying:Once(function()
			mirror:Destroy()
		end)
	end
	-- the win course is generated after startup and may be rebuilt: follow it
	if courseRoot then
		local existing = courseRoot:FindFirstChild("WinCourse")
		if existing then
			hookWinCourse(existing)
		end
		courseRoot.ChildAdded:Connect(function(child)
			if child.Name == "WinCourse" then
				task.defer(hookWinCourse, child)
			end
		end)
	end

	makePortal(folder, NEXT_PORTAL + world.Offset, 0, "WORLDS", world.Theme.Glow)
	folder.Parent = worldsFolder
end

task.spawn(function()
	-- build as soon as the scripted lobby decor exists (was a fixed 8 s wait)
	local started = os.clock()
	for _, name in ipairs({ "Podium", "LobbyDecor", "LobbyFurniture" }) do
		Workspace:WaitForChild(name, math.max(0.1, 8 - (os.clock() - started)))
	end
	-- the wall racks build their balls one by one (accessories can take a few
	-- seconds): copying earlier left the copied shelves mostly empty
	local decor = Workspace:FindFirstChild("LobbyDecor")
	local waited = 0
	while decor and not decor:GetAttribute("Built") and waited < 30 do
		task.wait(0.25)
		waited += 0.25
	end
	task.wait(0.5)
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Id > 1 then
			buildWorld(world)
		end
	end
	makePortal(worldsFolder, NEXT_PORTAL, 0, "WORLDS", Color3.fromRGB(80, 200, 255))
	for _, p in ipairs(worldsFolder:GetDescendants()) do
		if p:IsA("Model") and p:GetAttribute("ToWorld") then
			local core = p:FindFirstChild("Core")
			-- rolling onto the floor pad in front of the wall disc opens the WORLDS menu
			table.insert(machines, Vector3.new(core.Position.X + PAD_OFFSET_X, FLOOR_PAD_Y + 0.5, core.Position.Z))
		end
	end
	Workspace:SetAttribute("WorldsReady", true)
	print("[WorldService] built", #WorldConfig.Worlds - 1, "world copies and", #portals, "portals")
end)

--------------------------------------------------
-- MOVING BETWEEN WORLDS
--------------------------------------------------

local lastMove = {}

local function getBall(player)
	local folder = Workspace:FindFirstChild("PlayerBalls")
	return folder and folder:FindFirstChild("PlayerBall_" .. player.UserId)
end

local function save(player, id)
	task.spawn(function()
		pcall(function()
			store:SetAsync(tostring(player.UserId), id)
		end)
	end)
end

local function moveTo(player, id, reason)
	local world = WorldConfig.Worlds[id]
	if not world then
		return false
	end
	-- the copies are built a few seconds after the server starts; never move a
	-- ball to a world whose floor does not exist yet
	if id > 1 and not Workspace:GetAttribute("WorldsReady") then
		return false
	end
	local rebirths = player:GetAttribute("Rebirths") or 0
	if not WorldConfig.Unlocked(rebirths, id) then
		worldNotice:FireClient(player, "Locked", { World = id, Need = world.Rebirths, Have = rebirths })
		return false
	end
	local state = player:GetAttribute("RunState")
	if state and state ~= "" and state ~= "Waiting" then
		return false -- never mid-run
	end
	if lastMove[player] and os.clock() - lastMove[player] < 2 then
		return false
	end
	lastMove[player] = os.clock()

	player:SetAttribute("World", id)
	save(player, id)
	worldNotice:FireClient(player, "Entered", { World = id, Reason = reason })
	local ball = getBall(player)
	if ball then
		-- hold the ball still on the new spawn while the transition screen is up
		ball:SetAttribute("WorldMoveAt", os.clock())
		ball.Anchored = true
		ball.AssemblyLinearVelocity = Vector3.zero
		ball.AssemblyAngularVelocity = Vector3.zero
		ball.CFrame = CFrame.new(spawnPart.Position + world.Offset + Vector3.new(0, ball.Size.Y / 2 + 0.3, 0))
		task.delay(0.5, function()
			if ball.Parent then
				ball.Anchored = false
			end
		end)
	end
	return true
end

worldTeleport.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 then
		return
	end
	moveTo(player, id, "Menu")
end)

-- World Machine: opens the menu once each time the ball rolls onto the pad
local onMachine = {}
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local ball = getBall(player)
			local inside = false
			if ball then
				for _, pad in ipairs(machines) do
					local flat = Vector3.new(ball.Position.X - pad.X, 0, ball.Position.Z - pad.Z)
					if flat.Magnitude < 4.5 and math.abs(ball.Position.Y - pad.Y) < 6 then
						inside = true
						break
					end
				end
			end
			if inside and not onMachine[player] then
				worldNotice:FireClient(player, "OpenMenu")
			end
			onMachine[player] = inside
		end
	end
end)

-- portals: a ball resting inside a portal circle moves the player
task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local ball = getBall(player)
			if ball then
				for _, portal in ipairs(portals) do
					local flat = Vector3.new(ball.Position.X - portal.Position.X, 0, ball.Position.Z - portal.Position.Z)
					if flat.Magnitude < PORTAL_RADIUS and math.abs(ball.Position.Y - portal.Position.Y) < 8 then
						if not moveTo(player, portal.To, "Portal") then
							-- locked: push the ball back out of the circle
							local away = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
							ball.AssemblyLinearVelocity = away * 40 + Vector3.new(0, 10, 0)
						end
						break
					end
				end
			end
		end
	end
end)

--------------------------------------------------
-- JOIN / LEAVE
--------------------------------------------------

local function onJoin(player)
	player:SetAttribute("World", 1)
	player:SetAttribute("WorldReady", false)
	-- the loading screen stays up until this is true (see LoadingBoot)
	local function ready()
		if player.Parent then
			player:SetAttribute("WorldReady", true)
		end
	end
	local ok, saved = DataRetry.Get(store, tostring(player.UserId), 3)
	if not ok or typeof(saved) ~= "number" or saved <= 1 then
		ready()
		return
	end
	-- wait for the saved rebirths, then go back to the saved world if still unlocked
	local waited = 0
	while player.Parent and player:GetAttribute("Rebirths") == nil and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	while player.Parent and not getBall(player) and waited < 40 do
		task.wait(0.5)
		waited += 0.5
	end
	-- never send a ball to a world before its copy exists (it would fall forever)
	while player.Parent and not Workspace:GetAttribute("WorldsReady") and waited < 60 do
		task.wait(0.25)
		waited += 0.25
	end
	if player.Parent then
		lastMove[player] = nil
		moveTo(player, saved, "Join")
	end
	task.wait(0.6) -- let the ball settle on the new floor
	ready()
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(onJoin, p)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end
Players.PlayerRemoving:Connect(function(p)
	lastMove[p] = nil
	onMachine[p] = nil
end)

local _ = startWall