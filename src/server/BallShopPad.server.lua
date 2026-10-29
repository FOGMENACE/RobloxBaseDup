--------------------------------------------------
-- BALL SHOP PAD (server)
--
-- Rolling onto the shop pad opens the Ball Shop for that player. It used to re-open
-- right after a player closed it: the old place script (Workspace.BowlingShop.
-- BowlingShopInteraction) re-armed as soon as the ball was not seen INSIDE the pad for
-- one check, so a ball resting on or rolling along the edge triggered it again.
--
-- Now a player's pad is re-armed only after their ball has been clearly AWAY from it
-- (a few studs past its edge) for a moment, and there is a short cooldown after every
-- open. Each player is checked against their own ball (PlayerBall_<UserId>), never client data.
-- This script replaces the old one, which it switches off.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shop = workspace:WaitForChild("BowlingShop")
local pad = shop:WaitForChild("BallShopInteractionPoint")

local oldScript = shop:FindFirstChild("BowlingShopInteraction")
if oldScript and oldScript:IsA("Script") then
	oldScript.Disabled = true
end

if not pad:IsA("BasePart") then
	warn("[BallShopPad] BallShopInteractionPoint is not a part; shop pad disabled")
	return
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openShop = remotes:WaitForChild("OpenBowlingShop")

-- the old script's E prompt stays off: the pad is the interaction
local oldPrompt = pad:FindFirstChildOfClass("ProximityPrompt")
if oldPrompt then
	oldPrompt.Enabled = false
end

local EXIT_MARGIN = 4 -- studs past the pad's edge before it can trigger again
local AWAY_SECONDS = 0.8 -- ...and for this long
local COOLDOWN = 2.5 -- seconds between two opens for the same player

local state = {} -- [player] = { Armed, AwaySince, LastOpen }

local function stateOf(player)
	local s = state[player]
	if not s then
		s = { Armed = true, AwaySince = nil, LastOpen = 0 }
		state[player] = s
	end
	return s
end

local function padRadius()
	return math.max(pad.Size.X, pad.Size.Z) / 2
end

local function flatDistance(position)
	local offset = position - pad.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

local function onPad(ball)
	return flatDistance(ball.Position) <= padRadius() + 0.5
		and math.abs(ball.Position.Y - pad.Position.Y) < ball.Size.Y + 4
end

-- Position checks (not Touched, which misses balls that are moved or barely graze the
-- pad): open when an armed player's ball is on the pad; re-arm once it has been well
-- away from it for a moment.
task.spawn(function()
	local balls = workspace:WaitForChild("PlayerBalls")
	while true do
		task.wait(0.2)
		for _, player in ipairs(Players:GetPlayers()) do
			local s = stateOf(player)
			local ball = balls:FindFirstChild("PlayerBall_" .. player.UserId)
			local runState = player:GetAttribute("RunState")
			local inLobby = runState == nil or runState == "" or runState == "Waiting"
			if ball and inLobby and s.Armed and os.clock() - s.LastOpen >= COOLDOWN and onPad(ball) then
				s.Armed = false
				s.AwaySince = nil
				s.LastOpen = os.clock()
				openShop:FireClient(player)
			elseif not s.Armed then
				local away = not ball or flatDistance(ball.Position) > padRadius() + EXIT_MARGIN
				if away then
					s.AwaySince = s.AwaySince or os.clock()
					if os.clock() - s.AwaySince >= AWAY_SECONDS then
						s.Armed = true
						s.AwaySince = nil
					end
				else
					s.AwaySince = nil
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
end)

print("[BallShopPad] READY")
