# Launch review: loop rating, security, ideas, forecast

Honest status: everything below that says "tested" was seen in a Studio play test on one account. Nothing was tested with 2+ real players, real Robux, or on mobile hardware.

## 1. What changed in this pass
- **Strike badge** now shows the rebirth requirement (`RebirthLevelRequirement`, 65 for you), the same number as "Reach level N" in the Rebirth window.
- **Name tag** above every ball: `[rebirths] DisplayName` (no "x", display-name casing kept). Bracket colour by zone: 0-4 lime, 5-9 aqua, 10-19 blue, 20-39 purple, 40-74 gold, 75+ pink. Built on the server from server data (`BallNameTags.server.lua`). Tested: shows `[0] EPlCS0NNYD`.
- **Character / forcefield:** the character was already invisible; the spawn ForceField shell is now deleted on spawn and SpawnLocations get Duration 0 (tested: 0 forcefields).
- **Mailbox** (`FeedbackMailbox.server.lua`, `FeedbackUI.client.lua`): cartoon mailbox with bowling pins at the right side of the lobby, floating "FEEDBACKS / LEAVE YOUR FEEDBACK!", prompt opens a text panel. Server checks length (5-400), 45 s cooldown, 6 per session, runs Roblox's text filter, saves to DataStore `Feedback_v1` (key = `<UTC date>/<server>`, an array of messages with name, rebirths, level; the admin `feedback` command merges a day) and only then says "sent". Tested: too-short rejected, valid saved, immediate second rejected as cooldown. Read messages in Creator Hub > Data Stores > `Feedback_v1`.
- **Shop call-to-action:** floating "BUY BOWLING EQUIPMENT!" / "BECOME THE BEST DRIVER" above the existing Ball Shop sign (the sign stays).
- **Lobby ball guard** (`LobbyBallGuard.server.lua`): teleport / speed-hack in the lobby is undone (tested with a 40-stud teleport).

## 2. Exploit review
Principle held: clients only *ask*; the server decides amounts, prices, ids, cooldowns, ownership.

| Area | State |
|---|---|
| Wins, XP, oil, rebirths, balls, boosts, quests, calendar, X6 | Server-only; remotes carry an index/key at most. Verified by reading every `OnServerEvent/OnServerInvoke` (21). |
| Purchases | One `ProcessReceipt` owner; grant -> save -> record -> confirm; product ids and amounts resolved on the server; client "purchased" flags never trusted (they only trigger a server re-check). |
| Game passes | Ownership read from Roblox on the server. Multiplier totals are cached server-side; only a display attribute is replicated. |
| Lobby movement | Client-owned for smoothness (the one real surface). Guard above limits teleport/speed; nothing rewards depends on lobby position except XP generators, which the server validates per pass. |
| Remotes | Rate limits on purchase prompts, feedback, rebirth, gifts. Argument types checked. |
| Leaderboard remote | Key looked up in a fixed table; unknown keys return nil. |

**Known gaps (cannot be fully closed on Roblox):**
- The "Like" requirement is reported by the client (`PromptDone`): worth 500 wins once per account. Group membership is server-verified. Treat as low risk, or drop the like requirement.
- Studio-only objects (StarterGui, Workspace models, the old Xocoatl LevelUp) are visible to the client by nature; none grant anything.
- Nothing is "exploit-proof". A player can always read what the client has and can fire remotes with garbage; the design makes that harmless, but a second review after real traffic (look for DataStore anomalies, impossible win totals) is wise.
- Add before launch: DataStore ban list / kick on impossible values (e.g. Wins jump > X per minute) and keep an eye on `Feedback_v1` size.

## 3. Ratings (as built, before real players)
| | Score | Why |
|---|---|---|
| Core loop engagement | **7.5 / 10** | Short run, instant payoff, several progress layers (level, wins, rebirth multipliers, balls), variance (multipliers/dividers/tier/gutter platforms), daily + weekly goals, X6 and leave offers, friend bonus. Missing: an AFK/auto mode, social hooks, cosmetic flex, mid-game surprise events. |
| Monetization | **7 / 10** | Strong, varied price ladder (R$4 boosts to R$2,799 pack, R$499 exclusive ball, passes, skips). Weak points: no cosmetic tier, no subscription-style pass, big offers appear before the player has a reason to want them. |
| Release readiness | **Beta-ready, not launch-proven** | Needs the checks in section 5. |

## 4. Ideas, in order of value (ask me to build any)
1. **Auto Roll** (free 10 min after each manual run; unlimited as a pass). Biggest engagement and revenue lever; real "keep playing while away" feature.
2. **Cosmetics**: trails, dash colours, name-tag frames per rebirth zone, finish confetti styles (wins/Robux).
3. **First-session guidance**: a 30-second arrow from spawn to StartWall and to the Ball Shop (the shop was easy to miss; the new floating call-out helps).
4. **Server goal bar** and **weekly leaderboard reset** with a small prize.
5. **Limited-time events** every weekend (x2 wins window) with a banner; reuse `BoostService`.
6. **Value tweaks to test**: shorten the first rebirth (65 levels is long for a new player: consider 40 for rebirth 1), make the first premium ball affordable in the first session, show "next goal" under the HUD ("12,000 wins to Voltage").
7. **UI**: the bottom HUD is clear now during runs; consider collapsing the three XP kit buttons into one "XP" button after level ~15 to reduce noise.

## 5. Before you publish
1. Test every Robux item with a test account and a rejoin (balls, kits, boosts, Captain, Starter, Oil Barrel pass, skips).
2. Two-client session: name tags, leaderboards, Captain announcement, friend bonus.
3. Mobile test (thumbstick, panels, zoom button).
4. Check all sound ids and music by ear.
5. Save the Studio place (lane edits live there) and set Developer Product prices/descriptions in Creator Hub.
6. Turn on Creator Hub analytics events or at least check the retention charts after day 1.

## 6. First-month player forecast (rough, with a few small ad campaigns)
These are planning ranges from typical small-studio Roblox launches, not measurements. Roblox discovery is dominated by early retention and ad spend.

| Scenario | Month-1 unique players | Typical peak concurrent | What has to be true |
|---|---|---|---|
| Quiet | 1,500 - 6,000 | 10 - 40 | Little/no ad spend, day-1 retention < 20% |
| **Realistic with a few campaigns** | **8,000 - 40,000** | **40 - 200** | Roughly 150-400 USD of ads spread over 3-4 campaigns, day-1 retention 25-35%, a fun first 3 minutes |
| Breakout | 100,000+ | 1,000+ | The algorithm picks it up (strong retention + play time) or a social/influencer push |

Your stated goal of 500+ active users every hour is the "breakout" end. It needs: day-1 retention above ~30%, average session over ~15 minutes, and sustained ads or social traffic. Plan for the middle row, and treat the first two weeks as a tuning period (watch where players quit in the first 3 minutes). Revenue scales with engaged players: expect roughly 1-4% of players to spend, so 20,000 players is on the order of 200-800 buyers in a good month; the Captain pack and the Oil Barrel are your high-ticket items.
