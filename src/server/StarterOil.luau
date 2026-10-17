--------------------------------------------------
-- STARTER OIL (SERVER ONLY MODULE)
--
-- Run oil (CurrentOil) is reset when a run starts, so oil rewarded
-- from the daily calendar cannot simply be added in the lobby. It is
-- held here until RunController starts a run, then Take() hands it
-- over to be added right after that reset.
--
-- GiftService persists the pending amount (listening to Changed).
--------------------------------------------------

local StarterOil = {}

local pending = {} -- [player] = number

local changed = Instance.new("BindableEvent")
StarterOil.Changed = changed.Event -- (player, amount)

function StarterOil.Get(player)
	return pending[player] or 0
end

-- Load a persisted amount without announcing a change.
function StarterOil.Restore(player, amount)
	pending[player] = math.max(0, math.floor(tonumber(amount) or 0))
end

function StarterOil.Add(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return
	end

	pending[player] = (pending[player] or 0) + amount
	changed:Fire(player, pending[player])
end

-- Returns the pending amount and clears it.
function StarterOil.Take(player)
	local amount = pending[player] or 0
	if amount > 0 then
		pending[player] = 0
		changed:Fire(player, 0)
	end
	return amount
end

function StarterOil.Clear(player)
	pending[player] = nil
end

return StarterOil
