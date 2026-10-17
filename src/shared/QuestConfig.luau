--------------------------------------------------
-- QUEST CONFIG (shared, display + definitions)
--
-- Each day a player gets QUESTS_PER_DAY quests picked from Pool by the
-- server. Rewards are decided on the server (QuestService); the client
-- only shows what the server sends.
--
-- Pool entry: Id (the event the server tracks), Title (%d = target),
-- Targets (easy / medium / hard picks), Reward (wins for the easy pick;
-- the others scale up with their target).
--------------------------------------------------

local QuestConfig = {}

QuestConfig.QUESTS_PER_DAY = 3

QuestConfig.Pool = {
	{ Id = "Runs", Title = "Finish %d runs", Targets = { 2, 3, 4 }, Reward = 150 },
	{ Id = "Levels", Title = "Gain %d levels", Targets = { 3, 5, 8 }, Reward = 200 },
	{ Id = "WinCourse", Title = "Win %d wins on the WinCourse", Targets = { 150, 400, 900 }, Reward = 250 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Targets = { 6, 12, 20 }, Reward = 150 },
}

-- Bonus for claiming all of today's quests.
QuestConfig.BonusWins = 500
QuestConfig.BonusBoostSeconds = 5 * 60 -- x4 XP

function QuestConfig.Find(id)
	for _, entry in ipairs(QuestConfig.Pool) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

return QuestConfig
