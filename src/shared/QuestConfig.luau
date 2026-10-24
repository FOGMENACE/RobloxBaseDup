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
	{ Id = "Runs", Title = "Finish %d runs", Targets = { 6, 10, 15 }, Reward = 150 },
	{ Id = "Levels", Title = "Gain %d levels", Targets = { 40, 80, 140 }, Reward = 200 }, -- levels are 5x finer now; the server also scales this with rebirths
	{ Id = "WinCourse", Title = "Win %d wins on the WinCourse", Targets = { 2000, 6000, 15000 }, Reward = 250 }, -- scaled up with rebirths by the server (wins per run grow fast),
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Targets = { 20, 35, 50 }, Reward = 150 },
	{ Id = "Rebirths", Title = "Rebirth %d times", TitleOne = "Rebirth once", Targets = { 2, 3, 5 }, Reward = 300 },
	{ Id = "GenMinutes", Title = "Earn XP on generators for %d minutes", Targets = { 8, 15, 25 }, Reward = 150 },
	{ Id = "Gates", Title = "Roll through %d ball upgrade or downgrade gates", TitleOne = "Roll through a ball upgrade or downgrade gate", Targets = { 3, 5, 8 }, Reward = 200 },
	{ Id = "Gift", Title = "Claim the free XP gift %d times", TitleOne = "Claim the free XP gift", Targets = { 2, 3 }, Reward = 250 },
	{ Id = "Multipliers", Title = "Hit %d x2 or x4 oil panels", TitleOne = "Hit an x2 or x4 oil panel", Targets = { 2, 4, 6 }, Reward = 250 },
	-- only offered once the player can reach a themed world (MinRebirths)
	{ Id = "WorldRuns", Title = "Finish %d runs in a new world", Targets = { 4, 8, 12 }, Reward = 300, MinRebirths = 15 },
}

-- Weekly milestones (counters reset every Monday 00:00 UTC). Seven rungs, all TIME based (runs and
-- platforms), so high-rebirth players cannot clear them with a couple of big runs,
-- free to everyone. Reward = wins (scaled by rebirths like daily quests);
-- Boost = optional x4 XP seconds.
QuestConfig.Weekly = {
	{ Id = "Runs", Title = "Finish %d runs", Target = 20, Reward = 500 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Target = 80, Reward = 650 },
	{ Id = "Runs", Title = "Finish %d runs", Target = 50, Reward = 1200 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Target = 200, Reward = 1800 },
	{ Id = "Runs", Title = "Finish %d runs", Target = 100, Reward = 3000 },
	{ Id = "Platforms", Title = "Roll through %d oil platforms", Target = 400, Reward = 4500 },
	{ Id = "Runs", Title = "Finish %d runs", Target = 200, Reward = 8000, Boost = 15 * 60 },
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
