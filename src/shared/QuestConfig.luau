--------------------------------------------------
-- QUEST CONFIG (shared, display + definitions)
--
-- Each day a player gets QUESTS_PER_DAY different quests picked at random from
-- Pool by the server (10 quest types x 1-3 difficulty picks, so the daily mix
-- changes a lot from day to day). Rewards are decided on the server (QuestService); the client
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
	{ Id = "Levels", Title = "Gain %d levels", Targets = { 15, 25, 40 }, Reward = 200 }, -- levels are 5x finer now
	{ Id = "WinCourse", Title = "Win %d wins on the WinCourse", Targets = { 150, 400, 900 }, Reward = 250 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Targets = { 6, 12, 20 }, Reward = 150 },
	{ Id = "Rebirths", Title = "Rebirth %d times", TitleOne = "Rebirth once", Targets = { 1, 2, 3 }, Reward = 300 },
	{ Id = "GenMinutes", Title = "Earn XP on generators for %d minutes", Targets = { 3, 6, 10 }, Reward = 150 },
	{ Id = "Gates", Title = "Roll through %d ball upgrade or downgrade gates", TitleOne = "Roll through a ball upgrade or downgrade gate", Targets = { 1, 2, 4 }, Reward = 200 },
	{ Id = "Gift", Title = "Claim the free XP gift %d times", TitleOne = "Claim the free XP gift", Targets = { 1, 2 }, Reward = 250 },
	{ Id = "Multipliers", Title = "Hit %d x2 or x4 oil panels", TitleOne = "Hit an x2 or x4 oil panel", Targets = { 1, 2, 3 }, Reward = 250 },
	-- only offered once the player can reach a themed world (MinRebirths)
	{ Id = "WorldRuns", Title = "Finish %d runs in a new world", Targets = { 2, 4, 6 }, Reward = 300, MinRebirths = 15 },
}

-- Weekly milestones (counters reset every Monday 00:00 UTC). Seven rungs,
-- free to everyone. Reward = wins (scaled by rebirths like daily quests);
-- Boost = optional x4 XP seconds.
QuestConfig.Weekly = {
	{ Id = "Runs", Title = "Finish %d runs", Target = 10, Reward = 400 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Target = 40, Reward = 500 },
	{ Id = "Levels", Title = "Gain %d levels", Target = 50, Reward = 700 },
	{ Id = "Runs", Title = "Finish %d runs", Target = 30, Reward = 1200 },
	{ Id = "WinCourse", Title = "Win %d wins on the WinCourse", Target = 3000, Reward = 1500 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Target = 150, Reward = 2500 },
	{ Id = "Runs", Title = "Finish %d runs", Target = 70, Reward = 5000, Boost = 15 * 60 },
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
