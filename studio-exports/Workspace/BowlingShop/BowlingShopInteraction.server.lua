--------------------------------------------------
-- BOWLING SHOP INTERACTION
--
-- SERVER ONLY
--
-- Location:
-- Workspace
--     > BowlingShop
--         > BallShopInteractionPoint
--             > BowlingShopInteraction
--------------------------------------------------

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


--------------------------------------------------
-- SHOP
--------------------------------------------------

local shop =
	script.Parent


local interactionPoint =
	shop:WaitForChild(
		"BallShopInteractionPoint"
	)


if not interactionPoint:IsA("BasePart")
	and not interactionPoint:IsA("Attachment")
	and not interactionPoint:IsA("Model") then

	error(
		"[BowlingShop] BallShopInteractionPoint must be a BasePart, Attachment, or Model"
	)

end


--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


--------------------------------------------------
-- OPEN SHOP REMOTE
--
-- This RemoteEvent tells ONLY the player who
-- interacted with the shop to open their UI.
--------------------------------------------------

local openShopRemote =
	remotes:FindFirstChild(
		"OpenBowlingShop"
	)


if not openShopRemote then

	openShopRemote =
		Instance.new(
			"RemoteEvent"
		)

	openShopRemote.Name =
		"OpenBowlingShop"

	openShopRemote.Parent =
		remotes

	print(
		"[BowlingShop]",
		"Created OpenBowlingShop RemoteEvent"
	)

end


if not openShopRemote:IsA("RemoteEvent") then

	error(
		"[BowlingShop] OpenBowlingShop must be a RemoteEvent"
	)

end


--------------------------------------------------
-- PROXIMITY PROMPT
--------------------------------------------------

local prompt =
	interactionPoint:FindFirstChildOfClass(
		"ProximityPrompt"
	)


if not prompt then

	prompt =
		Instance.new(
			"ProximityPrompt"
		)

	prompt.Name =
		"BallShopPrompt"

	prompt.Parent =
		interactionPoint

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

prompt.ActionText =
	"Open Ball Shop"

prompt.ObjectText =
	"Bowling Balls"

prompt.KeyboardKeyCode =
	Enum.KeyCode.E

prompt.HoldDuration =
	0

prompt.MaxActivationDistance =
	10

prompt.RequiresLineOfSight =
	false

prompt.Style =
	Enum.ProximityPromptStyle.Default


--------------------------------------------------
-- INTERACTION
--------------------------------------------------

prompt.Triggered:Connect(
	function(player)

		--------------------------------------------------
		-- SAFETY
		--------------------------------------------------

		if not player
			or not player:IsA("Player") then

			return

		end


		--------------------------------------------------
		-- DEBUG
		--------------------------------------------------

		print(
			"[BowlingShop]",
			player.Name,
			"opened the Ball Shop"
		)


		--------------------------------------------------
		-- OPEN ONLY THIS PLAYER'S SHOP
		--------------------------------------------------

		openShopRemote:FireClient(
			player
		)

	end
)


--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"=========================================="
)

print(
	"[BowlingShop] INTERACTION READY"
)

print(
	"[BowlingShop] Prompt:",
	prompt.Name
)

print(
	"[BowlingShop] Action:",
	prompt.ActionText
)

print(
	"[BowlingShop] Key:",
	prompt.KeyboardKeyCode.Name
)

print(
	"[BowlingShop] OpenBowlingShop RemoteEvent connected"
)

print(
	"=========================================="
)

--------------------------------------------------
-- ROLL-OVER TRIGGER
--
-- Rolling the player's ball onto the pad opens the shop for
-- that player only. The E prompt is disabled; the pad is the
-- interaction point now. Server decides who triggered it from
-- the ball's OwnerUserId attribute (never from client data).
-- A player must leave the pad before it can trigger again.
--------------------------------------------------

prompt.Enabled = false

local Players = game:GetService("Players")

local padInside = {}      -- [player] = true while their ball is on the pad
local padLeaveToken = {}  -- [player] = counter for debounced exit

local function getBallOwner(part)
	local ball = part
	while ball and not ball:GetAttribute("OwnerUserId") do
		ball = ball.Parent
		if ball == workspace then return nil end
	end
	if not ball then return nil end

	local ownerId = ball:GetAttribute("OwnerUserId")
	if typeof(ownerId) ~= "number" then return nil end

	return Players:GetPlayerByUserId(ownerId)
end

interactionPoint.Touched:Connect(function(hit)
	local player = getBallOwner(hit)
	if not player or padInside[player] then
		return
	end

	padInside[player] = true
	padLeaveToken[player] = (padLeaveToken[player] or 0) + 1
	openShopRemote:FireClient(player)
end)

-- Release the latch once the player's ball has left the pad.
task.spawn(function()
	while true do
		task.wait(0.25)
		for player in pairs(padInside) do
			local stillOn = false
			if player.Parent then
				for _, part in ipairs(workspace:GetPartsInPart(interactionPoint)) do
					if getBallOwner(part) == player then
						stillOn = true
						break
					end
				end
			end
			if not stillOn then
				padInside[player] = nil
				padLeaveToken[player] = nil
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	padInside[player] = nil
	padLeaveToken[player] = nil
end)
