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
