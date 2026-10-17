# Release audit, monetization review and engagement rating

Status key: **Verified** = seen in a Studio play test. **Built** = written and loads without errors, behaviour not exercised. **Open** = needs you or a live test.

## Verified in Studio
- Lobby ball physics, camera, gutter penalty, zero-oil return, XP generators.
- XP kit buttons (amounts follow the level and drop after a rebirth), rebirth panel, boost buttons, Store panel entries.
- Preview labels show `???` / `---` until the run starts.
- Community panel, leave popup, FREE x6 card, podium render.
- Tier platforms: rows 3, 6, 9 of the normal 12-row course convert to green (upgrade) / red (downgrade).
- Dragon ball: parts are now placed straight from the ball position (no spin-induced jitter), longer body, shoulder-mounted wings.
- Oil course: spacing 39, FinishWall / WinCourse start moved back, original centre stand kept.
- Dribble: the ball hopped about 0.8 stud vertically on the oil lane; after cancelling upward velocity the range is about 0.12 stud.

## Built, not exercised
- **Every Robux flow** (balls, XP kits, x2 oil, x2 wins). Test with a test purchase and a rejoin. A green "PURCHASED" toast now appears only after the server has granted, saved and recorded the receipt.
- Leave reward, 25-minute cooldown, 360 wins + x4 XP (8 min). Community claim. Win countdown banner, result count-up and confetti. Level-up burst. Ball tier swap and revert. Friend XP bonus (needs two friends in one server).
- Anti-AFK (`Idled` + `VirtualUser`) is present; only a 20+ minute idle session proves it.

## Known limits
- Roblox gives no hook into the real "Close Roblox" dialog; the leave popup appears when the player opens the Esc menu.
- No API verifies a Like. The reward relies on the favorite prompt completing, reported by the client; an exploiter could fake it once per account (+500 wins). Group membership is verified on the server.
- Sound ids (tick, fanfare, notification) and the music tracks were chosen without listening. Audition them.
- The three oil PNGs in `assets/textures/` are not uploaded yet, so the UI still draws droplets (`shared/UiAssets.luau`).
- Not tested with 14 players. Some premium balls were only reviewed in part.
- The lane floor, boundaries and FinishWall edits live in the Studio place (see `studio-exports/README.md`); save/publish that place.
- Mesh balls (BallModels) roll with default collision; the upward-velocity cancel hides hopping rather than changing the mesh. A true sphere collider would be the cleaner long-term fix.

## Microtransaction review

| Offer | Where | Notes |
|---|---|---|
| 17 Robux balls (R$17-419) | Ball shop | Also buyable with wins, so there is a free path. Robux skips the rebirth requirement. |
| XP kits 1/2/3 | Under the level badges | Size follows level, so it stays relevant. Price is set in Creator Hub. |
| x2 oil / x2 wins, 30 min, R$4 | Right edge + Store | Low price, impulse-friendly, time-limited, saved across rejoins. |
| Admin x100 / x1000 passes | Store | Permanent; silent multiplier passes are server-only. |

**Good:** receipts are durable (grant, save, record, then confirm), the server picks product ids and amounts, boosts cannot be extended by rejoining, price is shown next to every button, a confirmation appears only after the server confirms.

**Watch before launch**
- Roblox expects clear price and "what you get" on every prompt. Boost and kit buttons do this; check the Creator Hub product names and descriptions match.
- Many buy buttons are visible at once (kits, two boosts, FREE x6, popup). If testers call it noisy, hide the kit row after level ~10 or when a free reward is showing.
- The leave popup fires on the Esc menu. Keep it to free rewards only (it is), and do not add a paid offer there.
- Players under 13 cannot get some paid-random-item mechanics; nothing here is random-paid, keep it that way (no loot boxes).

## Ratings after the quests update

**Engagement: about 8 / 10** (was 7). New: 3 daily quests per player (server-tracked, reset at UTC midnight, wins scale with rebirths) plus an all-done bonus of 500 wins and 5 min of x4 XP. That adds a reason to return every day and short goals inside a run. Built and loads (state, hub button and bonus pill verified); a full claim cycle is not exercised yet.

**Monetization: about 7 / 10.** Honest note: it cannot reach 8+ with the products that exist today. The strongest additions need new Developer Products that only you can create in Creator Hub:
1. *Starter pack* (one-time, shown for the first sessions): e.g. a ball + 30 min x2 oil + x2 wins.
2. *Quest refresh / skip* (small R$): replaces one quest.
3. *Boost bundle* (x2 oil + x2 wins together at a small discount).
Send me the product ids and I will wire them with the same durable receipt path (`ProductService`). Until then I did not add placeholder buy buttons.

**Passes:** the six passes are now `X100 / X1000` (admin generators) and `X240 / X360 / X1900 / X2200` (everywhere), only the two generator passes are listed in the Store; the four multiplier passes are not listed anywhere in the UI. The HUD shows a small "REBIRTH XP / PASS XP" pill (0% with no pass). It shows the best owned multiplier only; the admin x100 / x1000 passes work on their generators and are not in that percentage.

**Other:** the XP multiplier no longer appears in the rebirth panel or the rebirth window (still applied by the server).

**Best next, in order:** milestone rewards (first rebirth, first premium ball), a weekly leaderboard reset with a small prize, then the paid items above.

## Release checklist
1. Set every Developer Product price and description in Creator Hub; match `ShopConfig.RobuxPrices`.
2. Upload the oil PNGs and audition the audio.
3. Test purchases with a test account and rejoin; test with a second client.
4. Save the Studio place with the lane edits; confirm `studio-exports/README.md` items are in it.
5. Only then publish (this repo never publishes).
