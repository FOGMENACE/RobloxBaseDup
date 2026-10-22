--------------------------------------------------
-- FEEDBACK MAILBOX (SERVER)
--
-- Builds a cartoon mailbox in the lobby, decorated with bowling pins (your
-- StandPin1 model, with a drawn fallback), and owns the feedback flow:
--
--   client (FeedbackUI) -> RemoteFunction FeedbackSubmit(text)
--   server: validates type / length / rate limit, runs Roblox's text
--   filter, saves the message in DataStore "Feedback_v1" (one array per
--   UTC day), and only then answers true.
--
-- The player is told "sent" ONLY when the save succeeded. Read the
-- messages in the Creator Hub's Data Stores explorer (key = the date).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local FLOOR_Y = 63.5
local POSITION = Vector3.new(-30.5, FLOOR_Y, -261) -- east wall, back end: open floor past the ball rack, before the generators
local MIN_LENGTH, MAX_LENGTH = 5, 400
local COOLDOWN = 45 -- seconds between messages per player
local MAX_PER_SESSION = 6
local MAX_PER_DAY_STORE = 150

local store = DataStoreService:GetDataStore("Feedback_v1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local submit = remotes:FindFirstChild("FeedbackSubmit")
if not submit then
	submit = Instance.new("RemoteFunction")
	submit.Name = "FeedbackSubmit"
	submit.Parent = remotes
end

--------------------------------------------------
-- BUILD THE MAILBOX
--------------------------------------------------

local old = Workspace:FindFirstChild("FeedbackMailbox")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "FeedbackMailbox"
model.Parent = Workspace

local function part(name, shape, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local BLOCK, CYL, BALL = Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball
local upright = CFrame.Angles(0, 0, math.pi / 2)
local RED = Color3.fromRGB(226, 60, 62)
local BLUE = Color3.fromRGB(70, 130, 230)
local CREAM = Color3.fromRGB(255, 247, 232)

-- round bowling-lane base plate
local base = part("Base", CYL, Vector3.new(0.6, 9, 9), CFrame.new(POSITION + Vector3.new(0, 0.3, 0)) * upright, Color3.fromRGB(214, 170, 110), Enum.Material.WoodPlanks)
base.CanCollide = true

-- post + body (cartoon mailbox: a barrel-shaped body with a rounded top)
part("Post", BLOCK, Vector3.new(0.9, 5, 0.9), CFrame.new(POSITION + Vector3.new(0, 3.1, 0)), RED)
part("Body", BLOCK, Vector3.new(3.6, 2.2, 5), CFrame.new(POSITION + Vector3.new(0, 6.2, 0)), BLUE)
part("Roof", CYL, Vector3.new(5, 3.6, 3.6), CFrame.new(POSITION + Vector3.new(0, 7.3, 0)) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), BLUE)
part("Door", BLOCK, Vector3.new(3.3, 3, 0.2), CFrame.new(POSITION + Vector3.new(0, 6.6, -2.55)), CREAM)
part("DoorStripe", BLOCK, Vector3.new(3.3, 0.35, 0.22), CFrame.new(POSITION + Vector3.new(0, 7.8, -2.56)), RED)
part("Slot", BLOCK, Vector3.new(2.2, 0.35, 0.24), CFrame.new(POSITION + Vector3.new(0, 6.3, -2.58)), Color3.fromRGB(40, 36, 60))
part("Knob", BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(POSITION + Vector3.new(0, 5.5, -2.7)), Color3.fromRGB(255, 205, 70), Enum.Material.Metal)

-- red flag
part("FlagPole", BLOCK, Vector3.new(0.25, 2.6, 0.25), CFrame.new(POSITION + Vector3.new(2.1, 7.2, 0.6)), Color3.fromRGB(210, 210, 220))
part("Flag", BLOCK, Vector3.new(0.2, 1.2, 1.7), CFrame.new(POSITION + Vector3.new(2.1, 8.2, -0.2)), RED)

-- bowling pins around the base (StandPin1 from the shop model)
local shop = Workspace:FindFirstChild("BowlingShop")
local pinTemplate = shop and shop:FindFirstChild("StandPin1")

for index = 0, 4 do
	local angle = index * (2 * math.pi / 5) + 0.3
	local position = POSITION + Vector3.new(math.cos(angle) * 5.2, 0, math.sin(angle) * 5.2)

	if pinTemplate and pinTemplate:IsA("MeshPart") then
		local pin = pinTemplate:Clone()
		pin.Anchored = true
		pin.CanCollide = false
		pin.CanTouch = false
		pin.CanQuery = false
		pin.CastShadow = false
		pin.Size = pinTemplate.Size * 2.0
		local rotation = pinTemplate.CFrame - pinTemplate.CFrame.Position
		pin.CFrame = CFrame.new(position.X, FLOOR_Y + 0.6 + pin.Size.Y / 2, position.Z) * rotation
		pin.Parent = model
	else
		part("Pin", CYL, Vector3.new(2.6, 1.3, 1.3), CFrame.new(position + Vector3.new(0, 2, 0)) * upright, CREAM)
		part("PinHead", BALL, Vector3.new(0.9, 0.9, 0.9), CFrame.new(position + Vector3.new(0, 3.5, 0)), CREAM)
	end
end

-- a mini bowling ball on top of the post's base as decoration
part("MiniBall", BALL, Vector3.new(1.6, 1.6, 1.6), CFrame.new(POSITION + Vector3.new(-1.6, 1.4, 1.2)), Color3.fromRGB(40, 36, 70), Enum.Material.Glass)

-- floating title: "FEEDBACKS / LEAVE YOUR FEEDBACK!"
local anchor = part("TitleAnchor", BLOCK, Vector3.new(1, 1, 1), CFrame.new(POSITION + Vector3.new(0, 11.5, 0)), CREAM)
anchor.Transparency = 1

local gui = Instance.new("BillboardGui")
gui.Name = "Title"
gui.Size = UDim2.fromOffset(230, 62)
gui.LightInfluence = 0
gui.MaxDistance = 70
gui.Parent = anchor

local function titleLabel(text, y, h, size, c1, c2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, h)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = size
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(c1, c2)
	gradient.Rotation = 90
	gradient.Parent = label
end

titleLabel("FEEDBACKS", 0, 0.6, 2.5, Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 120, 20))
titleLabel("LEAVE YOUR FEEDBACK!", 0.62, 0.34, 2, Color3.new(1, 1, 1), Color3.fromRGB(235, 235, 245))

-- the prompt players use ("E" / tap)
local promptHolder = part("PromptHolder", BLOCK, Vector3.new(1, 1, 1), CFrame.new(POSITION + Vector3.new(0, 5, -3)), CREAM)
promptHolder.Transparency = 1

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "FeedbackPrompt"
prompt.ActionText = "FEEDBACK"
prompt.ObjectText = ""
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 11
prompt.RequiresLineOfSight = false
prompt.Parent = promptHolder

-- Make the whole mailbox a compact prop, standing on the floor.
do
	model:PivotTo(CFrame.new(POSITION) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-POSITION) * model:GetPivot()) -- door faces the room (-X)
	model:ScaleTo(0.62)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, FLOOR_Y - bottom, 0))
end

--------------------------------------------------
-- SUBMIT (validated, filtered, saved)
--------------------------------------------------

local lastSent = {} -- [player] = os.clock()
local sentCount = {} -- [player] = number
local busy = {}

submit.OnServerInvoke = function(player, text)
	if typeof(text) ~= "string" then
		return false, "INVALID"
	end

	if busy[player] then
		return false, "BUSY"
	end

	-- normalise whitespace, strip control characters
	text = text:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")

	if #text < MIN_LENGTH then
		return false, "TOO_SHORT"
	end
	if #text > MAX_LENGTH then
		return false, "TOO_LONG"
	end

	local now = os.clock()
	if lastSent[player] and now - lastSent[player] < COOLDOWN then
		return false, "COOLDOWN"
	end
	if (sentCount[player] or 0) >= MAX_PER_SESSION then
		return false, "LIMIT"
	end

	busy[player] = true

	-- Roblox text filter (required for any user text that is stored)
	local okFilter, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)

	if not okFilter or typeof(filtered) ~= "string" then
		busy[player] = nil
		return false, "FILTER_FAILED"
	end

	local day = os.date("!%Y-%m-%d", os.time())
	local entry = {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Time = os.time(),
		Rebirths = player:GetAttribute("Rebirths") or 0,
		Level = player:GetAttribute("GlobalLevel") or 0,
		PlaceVersion = game.PlaceVersion,
		Text = filtered,
	}

	local saved = pcall(function()
		store:UpdateAsync(day, function(list)
			list = typeof(list) == "table" and list or {}
			if #list >= MAX_PER_DAY_STORE then
				table.remove(list, 1)
			end
			table.insert(list, entry)
			return list
		end)
	end)

	busy[player] = nil

	if not saved then
		return false, "SAVE_FAILED"
	end

	lastSent[player] = now
	sentCount[player] = (sentCount[player] or 0) + 1
	return true, "OK"
end

Players.PlayerRemoving:Connect(function(player)
	lastSent[player] = nil
	sentCount[player] = nil
	busy[player] = nil
end)

print("[FeedbackMailbox] READY at", POSITION)
