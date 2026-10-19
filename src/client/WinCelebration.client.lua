--------------------------------------------------
-- WIN CELEBRATION
--
-- CLIENT ONLY, visual.
--   * Countdown: a "HOLD ON!" banner, a tightening vignette and a tick
--     sound each second, so the 5 seconds before the WinCourse feel busy.
--   * Result: when the server finishes a course (WinRunId attribute) the
--     tile total appears, multipliers (rebirth, boost) are dragged into it
--     and the credited total lands with a fanfare and confetti.
-- The numbers come from server attributes; nothing here awards anything.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RebirthBonuses = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))
local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))
local MultiplierFly = require(ReplicatedStorage:WaitForChild("MultiplierFly"))

local TICK_SOUND = "rbxassetid://9120386436"
local FANFARE_SOUND = "rbxassetid://9125402735"

local INK = Color3.fromRGB(24, 22, 34)
local FONT = Enum.Font.FredokaOne
local RNG = Random.new()

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function play(id, volume, speed)
	local sound = create("Sound", { SoundId = id, Volume = volume or 0.6, PlaybackSpeed = speed or 1 }, SoundService)
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)
end

-- A soft, airy "welcome back" chime for when the ball returns to the spawn
-- after the WinCourse: a gentle whoosh, then a rising pentatonic sparkle on a
-- light reverb. Built from the sounds the game already uses.
local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function playReturnChime()
	local function note(id, volume, speed, delay)
		task.delay(delay, function()
			local sound = create("Sound", { SoundId = id, Volume = volume, PlaybackSpeed = speed }, SoundService)
			create("ReverbSoundEffect", {
				DecayTime = 1.9,
				Density = 0.85,
				Diffusion = 0.9,
				DryLevel = -2,
				WetLevel = -5,
			}, sound)
			sound:Play()
			task.delay(5, function()
				sound:Destroy()
			end)
		end)
	end

	note(FANFARE_SOUND, 0.32, 1.35, 0) -- airy whoosh
	local scale = { 1, 1.122, 1.335, 1.498, 1.682, 2 } -- major pentatonic climb
	for index, speed in ipairs(scale) do
		note(PING_SOUND, 0.16 + index * 0.02, speed, 0.12 + (index - 1) * 0.075)
	end
	note(PING_SOUND, 0.3, 2, 0.12 + #scale * 0.075 + 0.04) -- bright final note
end

local old = playerGui:FindFirstChild("WinCelebration")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "WinCelebration",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 40,
}, playerGui)

--------------------------------------------------
-- COUNTDOWN
--------------------------------------------------

local vignette = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
create("UIStroke", { Color = Color3.fromRGB(255, 200, 60), Thickness = 0, Transparency = 0.4 }, vignette)

local banner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.22),
	Size = UDim2.fromOffset(520, 70),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "WIN RUSH INCOMING!",
	TextColor3 = Color3.fromRGB(255, 225, 80),
	TextSize = 46,
	Visible = false,
}, gui)
create("UIStroke", { Color = INK, Thickness = 4 }, banner)
local bannerScale = create("UIScale", { Scale = 1 }, banner)

local showOilChips -- assigned below (needs the chip builder)

local function countdown(seconds)
	seconds = tonumber(seconds) or 5

	banner.Visible = true
	if showOilChips then
		task.spawn(showOilChips)
	end
	vignette.Visible = true
	local stroke = vignette:FindFirstChildOfClass("UIStroke")
	stroke.Thickness = 0
	TweenService:Create(stroke, TweenInfo.new(seconds, Enum.EasingStyle.Quad), { Thickness = 70 }):Play()

	local messages = { "WIN RUSH INCOMING!", "HOLD ON TIGHT!", "GET READY!", "ALMOST...", "GO GO GO!" }
	for step = 1, math.floor(seconds) do
		banner.Text = messages[math.min(step, #messages)]
		bannerScale.Scale = 1.3
		TweenService:Create(bannerScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		banner.Rotation = (step % 2 == 0) and 3 or -3
		play(TICK_SOUND, 0.4, 0.9 + step * 0.08)
		task.wait(seconds / math.floor(seconds))
	end

	banner.Visible = false
	banner.Rotation = 0
	vignette.Visible = false
end

--------------------------------------------------
-- RESULT
--------------------------------------------------

local function confetti()
	local colors = {
		Color3.fromRGB(255, 80, 120), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 150),
		Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 110, 255),
	}

	for _ = 1, 90 do
		local size = RNG:NextInteger(8, 16)
		local piece = create("Frame", {
			Position = UDim2.fromScale(RNG:NextNumber(0.05, 0.95), -0.05),
			Size = UDim2.fromOffset(size, size * RNG:NextNumber(0.5, 1.6)),
			BackgroundColor3 = colors[RNG:NextInteger(1, #colors)],
			Rotation = RNG:NextInteger(0, 360),
			BorderSizePixel = 0,
			ZIndex = 60,
		}, gui)

		local fall = RNG:NextNumber(1.8, 3.2)
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine), {
			Position = UDim2.fromScale(piece.Position.X.Scale + RNG:NextNumber(-0.12, 0.12), 1.1),
			Rotation = piece.Rotation + RNG:NextInteger(-540, 540),
			BackgroundTransparency = 0.3,
		}):Play()
		task.delay(fall + 0.1, function()
			piece:Destroy()
		end)
	end
end

-- Plain number with thousands separators.
local function commas(value)
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function addStroke(inst, thickness)
	create("UIStroke", { Color = INK, Thickness = thickness }, inst)
end

-- During the countdown (oil course over): the oil multipliers fly out of the
-- bottom-left barrel tile (or slide in, for boosts), count up with ticking
-- sounds and are dragged into the oil meter, which counts up as each lands.
-- The server already included them in CurrentOil; the meter just shows the
-- oil BEFORE them first (CurrentOil / product) so the multiplication is seen.
showOilChips = function()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local serverNow = workspace:GetServerTimeNow()

	local list = {}
	local rebirthOil = RebirthBonuses.OilMultiplier(rebirths)
	if rebirthOil > 1 then
		table.insert(list, { Mult = rebirthOil, Color = Color3.fromRGB(150, 90, 235), Hud = true })
	end
	if (player:GetAttribute("BoostOilUntil") or 0) > serverNow then
		table.insert(list, { Mult = 2, Color = Color3.fromRGB(255, 150, 40), Label = "OIL BOOST" })
	end
	if (player:GetAttribute("BoostCaptainUntil") or 0) > serverNow then
		table.insert(list, { Mult = 3, Color = Color3.fromRGB(235, 190, 40), Label = "CAPTAIN" })
	end

	if #list == 0 then
		return
	end

	local meterGui = playerGui:FindFirstChild("OilMeterUI")
	local anim = meterGui and meterGui:FindFirstChild("OilMeterAnim")
	local panel = meterGui and meterGui:FindFirstChild("Panel")

	local product = 1
	for _, entry in ipairs(list) do
		product *= entry.Mult
	end

	if anim then
		-- Platforms gave RAW oil; the multipliers were applied once at the finish
		-- wall. Show the raw total first, then count up as each multiplier lands.
		local raw = player:GetAttribute("OilRawCollected")
		if typeof(raw) ~= "number" then
			raw = (player:GetAttribute("CurrentOil") or 0) / product
		end
		anim:Fire("Begin", raw)
	end

	local target = panel and (panel.AbsolutePosition + Vector2.new(panel.AbsoluteSize.X / 2, 26))
		or (gui.AbsoluteSize * Vector2.new(0.5, 0.08))

	for index, entry in ipairs(list) do
		MultiplierFly.Fly({
			Gui = gui,
			Source = entry.Hud and MultiplierFly.FindTile(playerGui, "Oil") or nil,
			Target = target,
			Multiplier = entry.Mult,
			Kind = "Oil",
			Color = entry.Color,
			Label = entry.Label,
			FromLeft = index % 2 == 1,
			Sound = play,
		})
		if anim then
			anim:Fire("Multiply", entry.Mult)
		end
		task.wait(0.1)
	end

	task.wait(1.2)
	if anim then
		anim:Fire("End")
	end
end


-- LIVE TOTAL: while the WinCourse runs, ONE number at the top of the screen
-- keeps adding up the tiles passed (instead of announcing every tile).
local liveTotal = 0

local liveLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.fromOffset(620, 90),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(255, 232, 90),
	TextSize = 70,
	Visible = false,
	ZIndex = 65,
}, gui)
addStroke(liveLabel, 6)
local liveScale = create("UIScale", { Scale = 1 }, liveLabel)

local function addLive(amount)
	liveTotal += amount
	liveLabel.Visible = true
	liveLabel.Text = "+" .. commas(liveTotal)
	liveScale.Scale = 1.18
	TweenService:Create(liveScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function resetLive()
	liveTotal = 0
	liveLabel.Visible = false
end
local lastRunId = player:GetAttribute("WinRunId") or 0
local celebrating = false

-- Whole result sequence. Every number comes from server attributes:
--   WinRunBase     wins from the tiles passed (before multipliers)
--   WinRunFinalTile amount of the last tile reached
--   WinRunRebirthMult / WinRunBoostMult multipliers that were applied
--   WinRunCredited what was actually added to the player's wins
local function showResult()
	local base = player:GetAttribute("WinRunBase") or 0
	local credited = player:GetAttribute("WinRunCredited") or 0
	local rebirthMult = player:GetAttribute("WinRunRebirthMult") or 1
	local boostMult = player:GetAttribute("WinRunBoostMult") or 1

	if credited <= 0 and base <= 0 then
		return
	end

	-- 1) banner
	local banner = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.29),
		Size = UDim2.fromOffset(640, 70),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "COURSE COMPLETE!",
		TextColor3 = Color3.fromRGB(255, 232, 90),
		TextSize = 54,
		ZIndex = 70,
	}, gui)
	addStroke(banner, 6)
	local bannerScale = create("UIScale", { Scale = 0 }, banner)
	TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	play(FANFARE_SOUND, 0.6)


	-- 3) big total, counting up from the tile sum
	local total = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(800, 140),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "+" .. commas(base),
		TextColor3 = Color3.fromRGB(255, 232, 90),
		TextSize = 110,
		ZIndex = 71,
	}, gui)
	addStroke(total, 8)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 170), Color3.fromRGB(255, 160, 30)),
		Rotation = 90,
	}, total)
	local totalScale = create("UIScale", { Scale = 0.3 }, total)
	TweenService:Create(totalScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	confetti()
	task.wait(1.0)

	-- 4) multipliers are DRAGGED into the total, one after another
	local shown = base
	local function dragIn(multiplier, color, fromLeft, label, fromHud)
		-- the chip lifts out of the bottom-left trophy tile, counts up to its
		-- multiplier and is dragged into the total
		MultiplierFly.Fly({
			Gui = gui,
			Source = fromHud and MultiplierFly.FindTile(playerGui, "Wins") or nil,
			Target = total.AbsolutePosition + total.AbsoluteSize / 2,
			Multiplier = multiplier,
			Kind = "Wins",
			Color = color,
			Label = label,
			FromLeft = fromLeft,
			Sound = play,
		})

		-- the number multiplies with a punch
		local from = shown
		shown = shown * multiplier
		totalScale.Scale = 1.35
		TweenService:Create(totalScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		play(FANFARE_SOUND, 0.45, 1 + multiplier * 0.05)
		-- count up: longer for bigger jumps, and it speeds up as it goes
		local jump = math.max(shown - from, 1)
		local duration = math.clamp(0.7 + math.log10(jump) * 0.28, 0.7, 2.4)
		local start = os.clock()
		local nextTick = 0
		local ticks = 0
		while os.clock() - start < duration do
			local t = (os.clock() - start) / duration
			local alpha = t * t * (1.6 - 0.6 * t) -- accelerating curve
			total.Text = "+" .. commas(from + (shown - from) * alpha)
			if t >= nextTick then
				ticks += 1
				nextTick = t + math.max(0.015, (0.11 / (1 + math.log10(jump) * 0.35)) * (1 - t))
				play(TICK_SOUND, 0.3, 0.9 + math.min(ticks, 24) * 0.05)
			end
			task.wait()
		end
		total.Text = "+" .. commas(shown)
		task.wait(0.25)
	end

	local left = true
	local serverNow = workspace:GetServerTimeNow()
	local captainOn = (player:GetAttribute("BoostCaptainUntil") or 0) > serverNow
	local boostOn = (player:GetAttribute("BoostWinsUntil") or 0) > serverNow

	local chips = {}
	if rebirthMult > 1 then
		table.insert(chips, { rebirthMult, Color3.fromRGB(150, 90, 235), nil, true })
	end

	-- split the boost multiplier into its parts when they add up exactly
	local parts = {}
	if boostOn then
		table.insert(parts, 2)
	end
	if captainOn then
		table.insert(parts, 3)
	end
	local product = 1
	for _, v in ipairs(parts) do
		product *= v
	end

	if boostMult > 1 and product == boostMult then
		for _, v in ipairs(parts) do
			table.insert(chips, { v, v == 3 and Color3.fromRGB(235, 190, 40) or Color3.fromRGB(255, 150, 40), v == 3 and "CAPTAIN" or "WINS BOOST" })
		end
	elseif boostMult > 1 then
		table.insert(chips, { boostMult, Color3.fromRGB(255, 150, 40), "WINS BOOST" })
	end

	for _, entry in ipairs(chips) do
		dragIn(entry[1], entry[2], left, entry[3], entry[4])
		left = not left
	end


	-- 5) final: the exact amount the server credited
	total.Text = "+" .. commas(credited) .. " WINS!"
	-- the final total GROWS and stays bigger while it is on screen
	totalScale.Scale = 1.0
	TweenService:Create(totalScale, TweenInfo.new(0.55, Enum.EasingStyle.Back), { Scale = 1.45 }):Play()
	confetti()
	play(FANFARE_SOUND, 0.7)
	task.wait(0.5)
	confetti()

	task.wait(2.4)
	TweenService:Create(totalScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.4)
	banner:Destroy()
	total:Destroy()
end

-- Triggered once per finished course (the server bumps WinRunId).
player:GetAttributeChangedSignal("WinRunId"):Connect(function()
	local id = player:GetAttribute("WinRunId") or 0
	if id == lastRunId or celebrating then
		lastRunId = id
		return
	end

	lastRunId = id
	celebrating = true
	task.spawn(function()
		pcall(showResult)
		celebrating = false
	end)
end)

--------------------------------------------------
--------------------------------------------------
-- SERVER EVENTS
--------------------------------------------------

local winCourse = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WinCourse")

winCourse.OnClientEvent:Connect(function(eventName, value)
	if eventName == "CountdownStart" then
		resetLive()
		task.spawn(countdown, value)
	elseif eventName == "WinCourseTileCollected" and typeof(value) == "table" then
		local amount = tonumber(value.TileWin)
		if amount and amount > 0 then
			addLive(amount)
		end
	elseif eventName == "ReturnedToLobby" then
		liveLabel.Visible = false
		playReturnChime()
	elseif eventName == "WinCourseFinished" then
		-- the result sequence (or the lobby) takes over from here
		liveLabel.Visible = false
	end
end)
