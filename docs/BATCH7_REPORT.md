# Batch 7: release audit, admin system, all-ages review

**How to read this:** "TESTED" = I ran it in a Studio play session (one player, your account). "STATIC" = I read the code, did not execute that path. Nothing here was published, and no player data was reset.

## 1. Findings (severity ranked)

| # | Sev | Finding | Basis | Status |
|---|---|---|---|---|
| 1 | High | `AdminConfig.Admins` holds `50333721` and `4467315` (both confirmed by the owner). Anyone on this list can run admin commands. | STATIC | Keep this list short |
| 2 | High | No DataStore session lock: if one account is in two servers at once (quick rejoin, or an exploit-forced duplicate), the last save wins and can overwrite newer progress. | STATIC | Open. Mitigation for admin resets only (MessagingService). A proper fix is a session-lock field in `PlayerData_v1`; a schema change, so not done without your OK. |
| 3 | High | Studio play sessions read and write the **same production DataStores** as the live game. My tests during this project changed your test account (Starter Pack grant, quest claims, auto-rebirth toggle, a feedback entry). | TESTED | Use a separate test place, or reset that account (the new admin reset exists for this). |
| 4 | Medium | Lobby movement is client-owned (smoothness). An exploiter can teleport / speed up the lobby ball. Rewards never read lobby position, and the new `LobbyBallGuard` undoes teleports and speeds over 110 studs/s. | TESTED (40 stud teleport undone) | Residual: small lobby cheating, no reward impact. |
| 5 | Medium | The Like requirement for the Community reward (+500 wins once) trusts the client's "favorite prompt completed" signal. | STATIC | Low value; accept or drop the Like requirement. |
| 6 | Medium | Tier platforms (upgrade/downgrade) froze the ball for about 0.25 s: the old code destroyed and re-created the ball. Now the same ball part is changed in place. Root cause found by measuring the client: writing Size, calling ApplyMesh, or welding new accessory parts onto the live ball each froze it on the client for ~0.2 s. Fixed by skipping Size/ApplyMesh when unchanged (all 19 tier balls share one mesh and 4-stud size) and adding accessories anchored/un-welded (clients already place them every frame). Re-measured in Studio: 0 s freeze on every swap. | TESTED server-side (same instance, speed and position continuous). Client-side smoothness after the fix not separately measured. | Fixed |
| 7 | Medium | Badge awards log "could not award Welcome". Badges only work for badges owned by this experience and awarded in a published place. | TESTED (Studio) | Verify after publishing |
| 8 | Low | Music and sound-effect ids were chosen without listening; third-party audio licensing not verified. | STATIC | You: audition and confirm rights |
| 9 | Low | Camera could leave the lobby walls; fixed (clamped inside, above the floor, below the ceiling). | Camera floor TESTED; wall clamp STATIC | Fixed |

No critical (data-loss or free-currency) issue was found in what I exercised.

### What was tested for malformed / abusive requests (all TESTED, one player)
- Ball shop: unknown ball, 300-character id, nil / table / number / NaN arguments, exclusive ball (`EXCLUSIVE`), unaffordable or rebirth-gated balls (`REBIRTH_REQUIREMENT`), already-owned, starting ball, 8 rapid duplicate requests (rate-limited), equip of an unowned ball (`NOT_OWNED`). Wins stayed 185,889 throughout.
- 8 other remotes (gifts, X6, kits, boosts, store, quest skip, auto-rebirth, prompt flags) sent NaN, infinity, negative numbers, tables, booleans, 2,000-character strings; quest / weekly / community / leaderboard functions likewise; rebirth with a table. **No server errors**; no state changed.
- Feedback: too short rejected, valid saved, repeat rejected as cooldown.
- Not tested: disconnect mid-purchase, receipt replay, 2+ players, Robux purchases of any kind (STATIC review only).

## 2. Admin system

Files: `src/server/AdminConfig.luau`, `AdminService.server.lua`, `PlayerDataLoader/PlayerDataService.luau` (admin API), `src/client/AdminConsole.client.lua`.

- **Who is admin:** only numeric UserIds in `AdminConfig.Admins`, checked on the server for every command. The client's `IsAdmin` attribute only decides whether the console UI appears.
- **Using it:** press the backtick key (`` ` ``) in-game, type `help`.
- **Admins:** UserIds 50333721 and 4467315.
- **Quick reference (backtick opens the console):**

| Command | What it does |
|---|---|
| `help` / `whoami` | list commands / show your id and admin status |
| `find <text>` | search players by name |
| `inspect <name\|id>` | show a player's stats |
| `kick <name> [reason]` | remove a player from this server (they can rejoin) |
| `ban <name\|id> [reason]` | permanent ban, stored in `AdminBans_v1`; kicked now and on every future join. Admins cannot be banned |
| `unban <id>` | remove a ban |
| `banlist` | list banned ids |
| `goto <name>` / `bring <name>` | teleport (lobby only) |
| `reset <id> [dry]` then `confirm <code>` | progression reset with backup (see below); `cancel` aborts |

  Ban / unban / banlist were built but NOT yet run live (needs a second account).
- **Commands:** `help`, `whoami`, `find`, `inspect <name|id>`, `kick <name> [reason]`, `ban`, `unban`, `banlist`, `goto`, `bring` (lobby only), `reset <userid> [dry]`, `confirm <code>`, `cancel`. A fixed command table: no eval, no free-form execution; input length, characters and rate are limited; an unauthorized caller gets only "not allowed".
- **Reset (one explicit UserId, progression only):**
  1. `reset 123 dry` shows what would change. `reset 123` shows the current values and a one-time 4-digit code (valid 60 s).
  2. `confirm <code>` backs up the old record to DataStore `PlayerDataBackup_v1` (key `<id>_<time>`); **if the backup fails, nothing is changed**.
  3. Resets XP, level, global level, wins, rebirths, rebirth requirement, current oil, owned balls (StraightBall only), equipped ball to valid defaults.
  4. Online target: in-memory data replaced and saved through the normal save path. Offline target: the stored record is replaced atomically (`UpdateAsync`).
  5. All other servers are told through MessagingService to drop that player's session **without saving** and kick them, so stale data cannot restore progress.
  6. Receipt / idempotency records (`ProcessedReceipts_v1`) are in a different DataStore and are never touched; quests, calendar, boosts, tutorial and leaderboards are also not reset (separate stores; say if you want them included).
  7. Every command except read-only ones is logged to the Output and to DataStore `AdminLog_v1`.
- **Safe testing:** use `AdminConfig.ResetAllowList = { [testUserId] = true }` so only test accounts can be reset, and use `dry` first.
- **TESTED:** whoami, find, inspect, `reset … dry` (online and offline id), wrong code, expired / cancelled confirm, bad usage, unknown command, over-long input, kick of an unknown player.
- **NOT TESTED (on purpose):** an actual reset (I did not reset your account or any player), kick of a real second player, goto / bring (needs 2 players), the cross-server MessagingService path, and a non-admin caller (needs a second account). Manual test plan: create a throwaway account, add its id to `ResetAllowList`, join it, run `reset <id>` then `confirm`, check the player is back to level 1 and that a backup key exists in `PlayerDataBackup_v1`.

## 3. Other fixes in this pass (all in `src/`, Rojo-synced)
- Robux icon (`utf8.char(0xE002)`) replaces "R$" on every price in the game; Store buy buttons now show the cost (passes read their price from Roblox).
- Tier swap in place (`BallSpawner.server.lua`); lobby camera kept inside the walls (`BallCamera.client.lua`) and the far zoom level is closer (21 / FOV 74); "BUY BOWLING GEAR!" slightly bigger; two wall screens at each end of both ball racks (`LobbyDecor.server.lua`).
- Earlier in this session (already summarised): shop / podium swap, cashier pin, mailbox + feedback, name tags, lobby guard.

## 4. All-ages readiness (policy review, not a rating)
I can't assign or promise a rating; Roblox calculates it from your questionnaire answers.

**Content review:**
- Visuals and text: cartoon bowling, no violence, blood, weapons, alcohol, romance or gambling imagery. The dragon, spider-like "lessons" pass names and "Most Wanted" are fantasy / wordplay; confirm you are comfortable with "Most Wanted" and "Spider" wording.
- Audio: three third-party music tracks and several sound ids were picked by title only. Listen to all of them, and check that each asset is allowed in your experience.
- Random rewards: **none are paid-random.** Quests, calendar, X6 and wheel-style offers are deterministic or free; there are no loot boxes. Keep it that way, because paid random items are restricted by Roblox policy and change which questionnaire answers apply.
- Monetization to review for clarity: high-price items (R$2,799 Captain pack) need an unambiguous description in Creator Hub; prices and results are shown in-game; purchases are confirmed only after the server grants them.
- Reward-for-actions: the Community panel gives wins for liking and joining the group. **Check current Roblox Creator rules on incentivizing likes / favorites and group membership**; if unsure, make it a thank-you with no reward, or remove the Like step.
- AFK: `PromptManager` answers Roblox's idle event so players are not removed at 20 minutes. **Confirm that this is acceptable under current platform rules**, and do not describe it as "earning while away"; a real Auto Roll feature (see CORE_LOOP_PROPOSAL.md) would be the sanctioned approach.
- Feedback box: text goes through Roblox's text filter before it is stored; it stores the player's UserId, names and a bit of game state (rebirths, level). Mention feedback collection in your privacy notes if you keep a policy.
- No player-to-player chat, trading or user-generated content was added by this work.

**What you must complete (manual):**
1. Creator Hub > your experience > **Settings > Maturity & Compliance** (the maturity questionnaire). Answer honestly for violence, fear, language, social features, paid items, and "paid random items" (answer based on the real game: none). Do not pick a rating yourself; let the result stand.
2. **Experience Guidelines / age recommendation** and, if shown, the **Social and Communication** settings (voice, chat options). Keep defaults unless you change the game.
3. Verify the **Developer Product** and **Game Pass** names / descriptions / prices / icons in Creator Hub match the in-game text (all passes and products listed in `server/StoreConfig.luau`, `shared/ShopConfig.luau`).
4. Badges: confirm all five badges belong to this experience and are enabled.
5. Set the **Group** (42308423) / privacy / monetization settings as you want them; I changed none of these.
6. Review third-party audio and any imported models for licensing.

## 5. Multiplayer release checklist
- [ ] Two clients: lobby movement, name tags, podium, shop, mailbox; leaderboard updates; Captain announcement; friend XP bonus.
- [ ] Join / leave / rejoin: data saved, boosts and quests persist, no stale resets.
- [ ] Purchase tests with a test account: ball, XP kit, boosts, Captain, Starter Pack, Oil Barrel pass, quest skip, rebirth skip; rejoin after each to check no double grant.
- [ ] Mobile: thumbstick area, panels, camera zoom button.
- [ ] 10+ players: server FPS / memory, ball replication, lobby part count (about 1,900).
- [ ] Admin: throwaway-account reset test (section 2), then clear the test account.
- [ ] Remove or replace test data in the test account; consider a separate test place with its own DataStores.
- [ ] Save the Studio place (lane, FinishWall, shop model edits live only there; see `studio-exports/README.md`).
- [ ] Publish only after the above; I have not published or changed any release setting.

## 6. Remaining risks
Session locking (finding 2), lobby client ownership (4), audio licensing (8), unverified platform-policy items (reward-for-like, AFK), and everything marked NOT TESTED above.

## Course variety (rarity pass)

- Upgrade / downgrade rows (`BallTierGates`): each course picks 0-3 of rows 3, 6, 9 (weights 32/40/20/8 %). Most courses have 0 or 1.
- Gutters (`GutterService`): each course gets 0-3 (weights 35/38/20/7 %), no longer always 3.
- Oil digits (`OilCourseGenerator`): scale = clamp(0.3 + 0.07 x rebirths, 0.3, 1.6) x a per-course luck roll (0.6 / 0.85 / 1.15 / 1.5, 25/35/30/10 %). Rebirth 0 sees roughly 40-300 per platform. Stored on the course as attribute `OilScale`. The server-side rebirth OIL multiplier at collection is unchanged.
- TESTED in Studio (one account, rebirth 0): scales 0.18 / 0.26 / 0.18, amounts 38-300, tier rows 2 / 1 / 0, gutters 1 / 2 / 1. Small sample; the distribution weights themselves were not statistically tested.

## Fixes from the generator / platform review

- XP: the silent pass multiplier now STACKS with the generator (it was `max(generator, pass)`, so for pass owners every generator paid the same). XP = base x rebirth XP x generator x pass x XP boost. NOT measured live (the lobby ball is client-driven, so a scripted test could not stand on a generator); verified by reading the code only.
- X2 / X4 / dividers: tested in Studio (600 oil on an X4 platform -> 2,400). Two real bugs fixed: (1) special platforms were also being multiplied by the rebirth / boost oil bonus, (2) fast balls could skip the 0.3-stud-thick platforms so Touched never fired ("on and off"). New `SweptTouch` module plus a swept check in `OilPlatformCollectionHandler` now test the ball's path each frame; tier gates and gutters use it too. Verified in Studio by teleporting the ball across a platform in one frame.
- Oil Barrel (exclusive) on a downgrade platform: now counts as one step above the best normal ball, so a downgrade drops it to the best normal ball (upgrade = "best ball"). NOT tested live.
- Win course: the ball now eases down over its last ~0.2 s (speed limited to remaining travel / 0.22 s) before it is frozen, so it no longer coasts onto the next tile on clients and snaps back. The credited tile is unchanged (the tile under the ball). NOT measured live.
- Sounds: new `PlatformSounds` (oil gain = snap + ping, big gain = double ping, loss = thump + whoosh); upgrade = ping, downgrade = low "swoop" (replaces the oof). Built-in Roblox sounds, not auditioned by me.
- Quests: red "!" dot on the DAILY and WEEKLY tabs when something is claimable (hidden when all claimed), plus the hub badge filled at join.
- "Don't leave" popup: larger, dimmed backdrop, pulsing claim button, small "no thanks" far from it.

## Progression + tutorial rework

- Reach-level schedule (`RebirthBonuses.RequiredLevel`, also used by `PlayerDataService`): 2 (free tutorial rebirth), 9, 17, 30, 45, 55, 70, 80, 95, 110, 125, 145, 165, 190, 215, 245, 275, 310, 345, 385, then +45 growing by 5 each rebirth. Base is no longer 65. NOTE: "2" means the first level-up (Level 1 is the starting level).
- Multipliers: oil = 1 + rebirths (x2 after the free rebirth); wins start at the rebirth that reaches x3 oil (rebirth 2 -> wins x2, then +1 each). XP rule unchanged.
- Tutorial (TutorialService, 12 steps): roll -> X1 generator level-up -> FREE rebirth (REBIRTH button appears here) -> roll again -> buy Aftershock -> equip -> roll again -> daily calendar appears and opens, claim day 1 (no "come back tomorrow" text) -> done. Everything but the target is dimmed (spotlight). Admin `reset` restarts the tutorial.
- HUD: at the reach level the level box says MAX LEVEL and the bar says REBIRTH REQUIRED, which shakes on every XP hit.
- Hub: REBIRTH button, DAILY calendar and the bottom-left multiplier panel are hidden for new players until their tutorial step. Badges ("!") lift their button above neighbours and pop in.
- TESTED in Studio: tutorial reset to step 1 (rebirth/calendar hidden), step 4 spotlight on the REBIRTH hub button and on REBIRTH NOW, MAX LEVEL display. NOT tested: a full run through all 12 steps, the shop/equip spotlight, the calendar step, a real tutorial rebirth (it would change the owner's live data), existing-player migration of saved levels.

## X2 / X4 / divider root cause + tile colours
- ROOT CAUSE of X2/X4/dividers never working: `OilPlatformCollectionHandler` rejected any platform whose `OilAmount` is 0, and special platforms are 0 BY DESIGN. Fixed (special platforms are exempt). TESTED in Studio from 600 oil: X4 -> 2,400, /2 -> 275 (rounding of an earlier value included), /4 -> 150; X2 test read 5,780 because the ball kept rolling after the teleport and hit the next row (X4) before I read it, so X2 itself should be re-checked in isolation.
- Win tiles: 41-109 use the same floor material with a cycling colour per amount; 110+ use a soft translucent rainbow over a light base. Visual check of the new rainbow was not possible (the tile was not streamed to the client in my test).
- Tutorial: arrows are now world arrows on the floor pointing along the way; the spotlight seam is fixed (checked in Studio).

## Mixed difficulty + win-course speed
- Oil course: every course rolls how many X2/X4 helpers (0-2) and /2 /4 hurters (0-2) it may contain; `MultiplierPlatforms` / `DividerPlatforms` are published on the course. Upgrade platforms are capped to 1 on a course with 2 helpers and 2 on a course with 1. Only a single generated course was inspected (1 helper, cap 2); the distribution across many courses was NOT sampled.
- Win course: top speed now scales with the travel budget (budget / 45 s, between 240 and 700 studs/s) and the acceleration reaches it in ~10 s, so a big-oil run no longer takes minutes. NOT run end to end; tile credit still follows the ball's real position, but very high speeds on very large budgets are untested.

## Core-loop review (simulated, not player-tested)
Numbers from a Studio simulation of the generator + speed model (rebirth 0 wins x1; no boosts):

| Travel budget (studs) | Tiles passed | Wins (base) | Roll time (before this pass) |
|---|---|---|---|
| 1,000 | 19 | 501 | 6 s |
| 8,000 | 97 | 7,248 | 35 s |
| 20,000 | 190 | 23,244 | 48 s |
| 150,000 | 1,190 | 741,744 | 218 s |
| 500,000 | 3,882 | 7.6 M | 600 s |

- Wins grow with the square of the distance, so oil matters a lot (good). The problem was TIME at deep rebirths: fixed. Travel is now 1 oil = 1 stud up to 20,000, then grows with the 0.8 power, and top speed scales up to 900 studs/s, so 150k oil is about 45 s and 500k about 60 s. Wins for those players are lower than the table shows (less distance); check the economy before launch.
- Skill competition (best choice of two platforms each row vs random choice, 3,000 simulated courses): average oil 990 vs 295 at rebirth 0 (x3.3), x2.2 at rebirth 2, x1.9 at 5, x1.7 at 20. Choosing well clearly pays, and less so deep in the game because the rebirth oil multiplier dominates; consider more gutters / dividers at high rebirths if you want skill to stay important.
- Possibly missing rewards (not implemented): no reward for a perfect oil run (all positive platforms), no streak / daily-first-win bonus, no leaderboard rewards, no reward for reaching WinCourse tile milestones (e.g. every 100th tile), no badge besides the Strike badge. These are suggestions, not defects.
- UI sizes: not audited screen by screen. Skybox: the default Roblox sky is still used with a pastel atmosphere; the Creator Store skyboxes I found came with scripts / unreviewed content, so I did not use them.

## Start-wall hardening, win-course oil, UI audit
- START WALL: a run now starts only when the ball ROLLS into the wall: it must have been seen on the lobby side within 14 studs for 3+ frames, at least 2.5 s after it was created/respawned, not anchored, under 160 studs/s, inside the lane and near the floor, and not have moved more than 14 studs in one frame. TESTED in Studio: teleporting a ball onto the wall no longer starts a run (it did before); rolling in with the W key starts it normally. The exact "spawned inside the floor" glitch was not reproduced, only blocked by the same rules (spawn grace, near-floor check).
- WIN-COURSE OIL: the lower amount was my travel compression (oil above a limit counts for less distance). Limit raised: 1 oil = 1 stud up to 60,000, then power 0.9. Everything below 60,000 oil is exactly 1:1. Wins still follow the real distance travelled; the oil meter shows remaining oil.
- UI AUDIT (1922x856 only, scripted + screenshots): no text under 11 px (except a badge mid-animation), nothing off screen, no clipped text in Calendar, Store, Quests, Ball Shop panels; Store list now fills its panel and the Captain text is larger; hidden popups no longer peek in at the top. NOT done: phone / tablet sizes, console/gamepad.
- Skybox: kept the default sky with the pastel atmosphere; it reads fine in screenshots and the free skyboxes I found were unreviewed.

## Oil as fuel (economy)
- Win-course distance = 1.1 x oil^0.84 x ball factor (0.7 starter .. 1.3 fastest ball, from ForwardSpeed) x rebirth factor (1 + 2 %/rebirth, max +50 %). Replaces the old 1 oil = 1 stud (and my short-lived compression). TESTED once in Studio: 50,000 oil at rebirth 6 with a mid ball -> 14,158 studs, 14,424 base wins (was ~100k), run ~50 s including countdown. Small oil: 1,000 oil is ~330 studs (~7 tiles at factor 1).
- Better balls, more rebirths (and wins multipliers / boosts, which still apply to the credited wins) are now what pushes deeper. This lowers wins for everyone, so retune tile amounts, quest targets and shop prices before launch; none of those were changed.
- Oil meter is wider (600 px). Top speed floor is 260 studs/s and scales with the budget; the meter drains in roughly 30 s.

## Faster oil burn, finish-wall oil, start-wall safety net, retune
- BURN: win-course start speed 110 (+oil boost up to +100), acceleration 40/s, top speed ceiling >= 420 studs/s (budget / 18 s above that, max 900). TESTED: 50,000 oil at rebirth 6 -> top speed 420, the rolling part lasted ~10 s, base wins 2,299 (x wins multiplier, boosts on top), no errors.
- FINISH WALL OIL: the meter during the countdown no longer shows "oil divided by the multipliers" (that was the "less than collected" you saw; the multipliers are already inside the oil). It now shows the real collected oil (verified: attribute 50,000 and meter 50.0K) and the multiplier chips only pulse / shake it. The server never reduced oil at the wall.
- START WALL: besides the roll-in rules, an approach is remembered for 2.5 s (a fast or laggy ball already inside the wall on its first frame still counts) and there is a safety net: a ball found PAST the wall while the player is in the lobby either starts the run (if it rolled in within the last 4 s) or is returned to the spawn. TESTED in Studio: ball teleported past the wall -> back at spawn; keyboard roll-in -> Running. The intermittent "no game" case could not be reproduced here, so the safety net, not a verified root cause, is what covers it.
- RETUNE: not changed in code, checked against the new economy. Ball prices (24 / 160 / 470 ... 250,000 wins, gated by rebirths 0-13), quest targets (daily WinCourse 150 / 400 / 900 wins, weekly 3,000) and gifts (2,000 / 8,000 wins) were reasoned through at rebirth 0, 2, 5, 10, 13: one run pays about 25-60 wins at rebirth 0 (Aftershock is 24: one good run), ~1-14k at rebirth 5, and roughly a ball price per 1-3 runs deeper in. Late balls look slightly cheap; first-day quests look fine. A real playtest should confirm the pacing.

## Level / XP curve retune
- ROOT CAUSE: XP per level was geometric (x1.35 per level). With the reach levels 2, 9, 17, 30, 45... the XP needed past rebirth ~3 outgrew any income (a simulation put rebirth 4 at ~14 hours and rebirth 6 at tens of thousands of years). That is why x10 wins was unreachable.
- NEW: total XP to reach level L = 85 x (L^2.43 - 1) (`PlayerDataService`). Fitted to the XP income model (12 XP/s base x rebirth XP (1+10r) x generator x ball speed): about 0.5 min for the tutorial rebirth, ~2 min rebirth 2, 3-5 min mid game, 5-8 min deep; x10 wins (rebirth 10) in roughly an hour of play, if players use the best generator they have unlocked. These times come from a model, not from watching a player: they assume standing on the best generator.
- Existing saves keep their stored XP, which now maps to a higher level than before (the owner test account jumped to level 80). XP kits scale with the level's XP so they still work.
- Rebirth UI: header pills, the OIL BARREL row on top with its multiplier on the right, the trophy row under it.

## Rebirth stuck on "REBIRTHING..."
- Cause NOT reproduced (it needs a real rebirth, which would change the owner's saved data). Hardened every way the client could wait forever: the server now always answers (rate-limited requests get TOO_FAST, errors get SERVER_ERROR via pcall and are logged as `[RebirthServer] RebirthPlayer error`), and the client unlocks the button after 6 s ("REBIRTH COMPLETE!" if the rebirth count went up, otherwise "No answer - try again."). If it happens again, check the Output for that warning: it names the real cause.
- XP curve made slightly harder: 95 x (L^2.46 - 1) (was 85 x (L^2.43 - 1)); about +20 % XP per early level and +30 % at level 125.


## Pre-launch hardening (data safety, claims, prompts, daily hook)

Verified in the BACKUP place (Studio play), not production:
- **Session lock + load retry** (`PlayerData_v1`, `SessionLock={JobId,Time}`, 150 s stale timeout, 5 load attempts with 1/2/4/8 s backoff). A player whose load fails is kicked and never saved. Lock is released on leave/shutdown (checked: record lock empty after stop). Cross-server behaviour was only simulated, not tested with two live servers.
- **Atomic one-time claims** (leave reward, community reward, starter pack) via UpdateAsync. 40 concurrent `LeaveRewardClaim` calls on a fresh key produced exactly 1 success. Community and starter-pack claims use the same pattern but were not re-run under a storm.
- **Remote fuzz**: 32 remotes, 1,776 junk calls, no server errors or hangs. This is not proof of exploit-proofing; only argument-shape fuzzing from one client.
- **Finish-wall oil multiplier**: platforms add raw oil only; rebirth x boost multiplier is applied once at the finish wall (`ApplyFinishOilMultiplier`). Tested: 1,000 raw -> 36,000 at 35 rebirths; a second invoke does not multiply again. The drag-in animation was not re-watched this pass.
- **Audit logging**: `[AUDIT]` lines for purchase grant success/failure (ReceiptLedger), rebirth success/refusal/save failure, load/save lock events.
- **Favorite prompt bug**: `PromptSetFavoriteCompleted` passes an `Enum.AvatarPromptResult` (always truthy), so pressing No counted as favorited. Now only `Success` counts, and the stored flag was renamed `FavoriteVerified` so old wrongly-set flags are ignored. Favoriting cannot be verified server-side by Roblox; the server only trusts the client's Success report. Group membership IS checked server-side (`IsInGroupAsync`).
- Prompts repeat every 420 s (first at 180 s) until both group and favorite are done; anti-AFK (`VirtualUser` on `Idled`) already lives in `PromptManager.client.lua`.
- **Daily hook**: calendar title shows the current streak; opening the Roblox menu with an unclaimed daily opens the calendar with a "claim before you leave" toast (leave-reward card takes priority when ready). Not yet visually checked in play.

## Win-course retune + stability
- Travel = 1.0*oil^0.80 (was 1.1*oil^0.84): 100k oil now ~10.0k base studs vs ~17.4k (-43%); 1k oil -31%. Modelled, not play-tested for tile landing.
- Camera and name tag now dead-reckon the ball (velocity extrapolation + soft pull) to remove replication jitter at high speed; tag cannot sink below the ball top. Not verified in a live win-course run.

## Oil spill icon + platform amount on the drag
- Uploaded the three spill PNGs (black/yellow/green) to Roblox via Studio MCP; ids in shared/UiAssets.luau (Black 97000428428004, Yellow 87174949328054, Green 75803779771688). Used as the oil icon in the oil meter, HUD oil chip (right of the level bar), rebirth panel, calendar oil slot, multiplier chips and level-up FX.
- Oil meter: the flying oil is now the spill plus '+amount' of the platform just hit (skipped for the finish-wall multiplier jump, which has its own animation). Not yet viewed in play.

## Meter redesign, multiplier FX, win-course arrows, cross-server gate
- Oil meter: wider (74% of screen, max 1000px), taller, plate-backed breathing spill icon, bigger outlined number, gliding shine, bar turns green/amber/red as win-course oil burns down, swell + flare while the multiplier counts. Viewed in play (oil course state forced via attributes).
- MultiplierFly: rainbow number for x10+, per-tick punch, shake, shockwave rings + sparkle bursts, glitter trail while dragged into the meter. Ran Fly() in play without errors; sparks clean up. Sound/feel needs a human pass.
- Win course: 4 white flow chevrons per tile (WinCourseGenerator.addFlowArrows). 48 arrows created for 12 tiles; preview tiles (WinCoursePreviewService) do not get them. Size increased after the first look; the larger version was not re-screenshotted.
- Cross-server: new SessionGate (per-player stores wait until PlayerData_v1 loaded = lock acquired) applied to Quest, Boost, Gift/calendar, Tutorial, AutoRebirth and LimitedGenerator loads; ReleasePlayer waits 2 s before dropping the lock so those services' leave-saves land first. Static/behavioural check only in one Studio server; NOT tested with two live servers. PromptFlags/Leaderboard/receipts already use UpdateAsync or derived values.

## Win-course burn, pass 2 + lobby review
- Travel = 0.9*oil^0.77 (was 1.0*oil^0.80), rebirth stretch +1%/rebirth capped +35% (was +2% / +50%). Example 100k oil at 35 rebirths: ~15,000 -> ~8,600 base studs. Modelled only, not run through the win course.
- Lobby snapshot review (Studio play, 4 camera angles): see chat; nothing built yet.

## Lobby furniture (LobbyFurniture.server.lua)
- Center rug (non-colliding, 'ROLL. WIN. REBIRTH!'), two lounge benches, four poufs, four plants, arcade corner (3 cabinets + stools + neon ARCADE sign above the existing wall screen). Decor only, anchored, in Workspace.LobbyFurniture. Viewed in Studio play from three angles; the rug text orientation and sign overlap were fixed after the first look. Not tested on phone, and I did not play-test the lobby ball against the solid seating.

- Lobby furniture revised on feedback (too busy/claustrophobic): rug, benches and plants removed. Kept the four poufs and the arcade corner.

- Hold-to-jump (BallController): holding Space / gamepad A / the touch button re-jumps on landing via the existing requestJump gate (lobby only, grounded, cooldown). Studio test: 8 jumps in a 4 s hold, 1 for a tap. Poufs reduced to three small ones tucked under the right-wall ball rack.

- Podium (CommunityUI) LIKE button had the same always-truthy PromptSetFavoriteCompleted bug as PromptManager; fixed (only AvatarPromptResult.Success counts, otherwise a hint is shown). The server claim requires group membership (IsInGroupAsync) AND the FavoriteVerified flag. Limits: Roblox gives servers no way to verify a favorite, so the flag is the client's Success report; a modified client could fake it. Not tested with a real favorite prompt (Studio cannot complete it).

## Thumbnails E-H (+1 Oil Bowling)
- assets/thumbnails/thumb_E_man_throw, F_woman_throw, G_man_closeup, H_woman_closeup (1920x1080). In-engine scenes staged in a Studio play session only (nothing saved to the place): R6 character with Pal (bacon) hair + drawn manly face / pink double-bun hair + drawn female face, ball in a throw pose, platforms relabelled +1, floating plain-text +1. Faces uploaded as images 135930452561333 (man) and 119757106290229 (woman); sources in assets/thumbnails/source/. Captured at 1652x797 and upscaled, so close-ups are soft; retake at higher resolution if needed.

## Start-wall feel, win-course camera, name tag
- Start wall: detection was already fast (~50 ms in Studio). The delay was the ball dropping from the 24 lobby speed to COURSE_START_SPEED 10 and crawling up at 12/s^2 (~3.5 s). Now 26 start / 34 accel: 24 -> 50 studs/s in ~0.6 s (measured in Studio).
- Win course camera: tighter chase (distance 14, height 8, look-ahead 28, FOV 56 + up to 10 with speed), and the camera aims velocity/CAMERA_SMOOTHNESS studs ahead so smoothing no longer leaves it ~75 studs behind at 900 studs/s. Measured at ~420 studs/s: camera ~19 studs from the ball, FOV 66.
- Name tag + camera: the dead-reckoning snap threshold was a fixed 40 studs, so at win-course speeds it re-snapped every frame (tag all over the place). It now grows with speed. Measured at ~420 studs/s: tag stays ~40 px above the ball and varies about 10 px. Not tested at the 900 studs/s ceiling or with multiple players.

## Win course: camera, tag, multiplier once
- Wins multipliers were applied PER TILE (floor(tile x mult) for every tile). Now each tile is credited raw and the rebirth x boost multipliers apply once to the whole tile total in finalizeWinnings (it credits total x mult minus what was already paid). Studio run: base 1,143 x35 = 40,005 credited; wins climbed raw per tile then jumped once at the end. Boost-only/expiring-boost cases not tested.
- Camera (WinCourse): distance 19, height 11, FOV 64 (+9 with speed), aimed at the ball: steady-state ball stays at screen Y 376-449 (centre 398) and the dash streaks converge on it; ball-camera distance ~25 studs. The first ~0.5 s after launch still settles.
- Name tag: in the WinCourse the local tag is pinned to the camera just above the centred ball; tag stays ~30-45 px above the ball centre (screenshot checked). Other players' tags and the oil course are unchanged.

- Removed the per-tile flow arrows from the win course (WinCourseGenerator). Added bowling lane markings before the oil-course FinishWall (LaneMarkings.server.lua): darker approach band, 7 spots, 7 arrows in the same V as the start. Seen in Studio play.

## Win course: stop behaviour + dash
- Camera overshoot at the end: the camera/tag dead-reckoning velocity decayed slowly (6/s) after the ball stopped, so the target ran ~tens of studs past the ball. Slowing is now followed instantly, the tracked point is clamped to never pass the ball, and a 'settle' ease (closer, lower, narrower FOV 73->61) plays as the ball stops. Studio run: 848 frames, 0 outside the frame; ball stayed at the screen centre line while slowing from 420 to ~10 studs/s.
- Dash (SpeedFX): four thin tapered air ribbons + stretched wind streaks replace the two fat bars; in the WinCourse the dash (ribbons, wind, screen lines) switches on at each tile hit and fades before the next (88 trail on/off toggles in one run). Oil course dash unchanged. Looks only checked in 2 screenshots.

## Platform rarity rebalance, platform timing, start wall
- Rarity: the old bands overlapped (Common 200-500, Uncommon 450-800, Rare 700-1,200) and the per-course scale (x0.3..x2.4) pushed Common up to ~1,160 at rebirth 35. New disjoint bands (before scale): Common 120-320 w46, Uncommon 380-650 w25, Rare 800-1,100 w12, Epic 1,500-2,200 w5 (gold label, either polarity), Legendary 3,000-4,500 w2 (pink label, positive/green only). Weighted mean stays ~520 per normal platform, so the economy is unchanged on average but has real jackpots. 60 generated courses at rebirth 35: Common 49%, Uncommon 29%, Rare 12%, Epic 5%, Legendary ~0.6-1%; no band overlap; no negative Legendary. Needs a human feel pass (no long-term economy simulation).
- Platforms 'calculated before touching': measured in Studio, the number/sounds/pop arrived when the ball the player SEES was still ~10 studs (~0.2 s) short of the gate, because the server ball reaches the client late. Presentation only: new shared/RunTiming waits until the visible ball reaches the gate (oil meter, HUD oil, platform sounds, gate pop). Studio: effects now play at gap -0.7..+1.2 studs. The server's authoritative collection is unchanged, and the server count is still 0.2 s ahead on a real network by roughly your ping as well (RunTiming adapts to what it sees). All 12 rows collected in a straight run (centre line collects both gates of a row).
- Start wall: no longer needs several approach frames; any continuous touch from the lobby side starts the run (wall check box grown by ~0.75 studs for a near-touch; grace after ball creation 2.5 -> 0.6 s; lane edge tolerance = ball radius). Studio: a tap that stops ~2.5 studs short does not start; a tap that ends ~1 stud from the wall starts it. Angled/edge/laggy approaches not tested; teleport blocking (previous frame on lobby side, <=14 stud step) unchanged.

## Finish wall -> win course start: glide instead of teleport
- Cause: WinCourseService froze the ball dead at the FinishWall (anchored, zero velocity) and teleported it to the official start; WinCourseProgressService placed it again. Now WinCourseService no longer freezes or moves it; WinCourseProgressService.beginGlideToStart keeps 40% of the arriving speed and eases the ball to the start with a critically damped spring (omega 5), driven through physics so the client interpolates it, then locks onto the exact start (<=2.2 s) before the 5 s countdown. Studio, finishing 15.7 studs off-centre: 49 -> 0 studs/s over ~1.2 s, peak lateral ~32 studs/s, no jump; the full win course then ran and credited 13,401 x 35 = 469,035. Start position, tile distances and anti-exploit logic unchanged. Visual smoothness on a real connection not checked.

- Wins fly-in (HubUI flyWins, shown per win tile): enlarged from 120x40 / 26 px text to 200x64 / 44 px text with a 56 px trophy and a thicker outline, pops in bigger, shrinks as it is dragged into the counter, wins pill bumps 1.2 (was 1.1), wider scatter so quick tiles do not stack. Checked in Studio with a simulated Wins change (one frame mid-flight); not seen during a real win course.

- Return-to-spawn sound: the plain built-in 'get up' clip is replaced by a client chime (WinCelebration playReturnChime) on ReturnedToLobby: airy whoosh + rising pentatonic ping arpeggio (6 notes + bright final note) on a light reverb, ~0.6 s, built only from sounds the game already uses. Studio: a full run fired exactly once, 8 notes, when the ball was back in the lobby. I cannot hear audio here, so how it sounds is untested; tuning (volumes, notes, new assets) is a by-ear job.

- Free-wins podium: thin gold neon ring on the floor (96 flat segments, a cylinder cannot be hollow) with a fainter outer glow ring, centred between the podium and its gold prompt circle so both sit inside it (PodiumService). Seen in Studio play.

- Thumbnails I/J (+1 Oil Bowling, rainbow oil barrel): drawn with a small code renderer (assets/thumbnails/source/Thumb.cs, run via PowerShell Add-Type), NOT built in Studio or the game: flat-shaded blocky Roblox-style guy, rainbow lane, rainbow barrel with OIL label, +999 / -67 end boards, clean flat +1 text with no stickers. Stylised/flat, not a render; I judged it by eye only.
