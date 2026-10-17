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

## Engagement rating: about 7 / 10

**Hooks:** short runs with a visible payoff, several progress layers (XP/level, wins, rebirth multipliers, balls, leaderboards), variance (multiplier/divider/tier platforms), reasons to return (calendar, timed gift, X6, leave reward), friend bonus, effects and music.

**Holding it back:** no short-term goals beyond bigger numbers (no daily quests), mid-game surprises thin out, limited social play.

**Added this pass:** friend XP bonus; purchase confirmation toast. Nothing else added; the next items below are optional, so I did not build them unasked.

**Best next, in order:** (1) 3 daily quests with a wins reward; (2) first-time milestone rewards (first rebirth, first premium ball); (3) a weekly leaderboard reset with a small prize.

## Release checklist
1. Set every Developer Product price and description in Creator Hub; match `ShopConfig.RobuxPrices`.
2. Upload the oil PNGs and audition the audio.
3. Test purchases with a test account and rejoin; test with a second client.
4. Save the Studio place with the lane edits; confirm `studio-exports/README.md` items are in it.
5. Only then publish (this repo never publishes).
