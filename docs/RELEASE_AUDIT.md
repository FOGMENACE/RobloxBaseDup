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

## Latest pass (see CORE_LOOP_PROPOSAL.md for the next decisions)
- Verified in Studio: new bottom-left panel (trophy / barrel multipliers), percent badge on the hub REBIRTH button, rebuilt Rebirth window (percent = level progress to the requirement), random-position FREE x6 card with countdown, radial speed lines + side dash trails, gutter platforms in rows 4/5/8 of one run, result celebration (tile total, multipliers dragged in, confetti).
- Built, not exercised: WinCourse fall guard, 25-tile lookahead, the real (non-faked) result attributes at the end of a long WinCourse, leaderboard zoom block, zoom button while a panel is open.
- The old Studio-side WinCourseUIController still draws its own tile pop-ups and countdown; the new celebration plays on top of it.

## Store, badges, weekly milestones, auto rebirth (latest)
Built and loaded in Studio: Store rows (Starter Pack R$18 gamepass, Captain Oil Server Pack R$2,799), Daily + Weekly quest tabs with claims, per-quest SKIP (R$29), Rebirth window with Auto Rebirth toggle (default OFF/red, ON/green) and SKIP REBIRTH (R$46). Verified live: Starter Pack granted once on the test account, a daily quest claim paid +1,029 wins, the auto toggle flipped on the server attribute.

**Assumptions I made (change in `server/StoreConfig.luau` / `shared/QuestConfig.luau`)**
- Captain pack: buyer 150,000 wins + x2 oil / x2 wins / CAPTAIN x3 (oil and wins) for 1 hour and the Captain badge; everyone else in the server 25,000 wins + the same boosts for 30 minutes; a banner tells the whole server who bought it.
- Starter Pack: one-time 10,000 wins + x2 oil and x2 wins for 20 minutes.
- Skip Rebirth does a normal rebirth without the level requirement (XP and level reset).
- Weekly milestones are the free track only (resets Monday 00:00 UTC); no paid track was added.

**Check before launch**
- The Captain product id you sent (371925404) has 9 digits; your other products have 10. Verify it in the Creator Hub, or the buy button will show an error.
- None of the purchase receipts (Captain, Skip Quest, Skip Rebirth) were bought with real or test Robux yet; only the code path loads. Test each with a test account and a rejoin.
- Badges (Welcome, 5/10/20 minutes, Captain) call BadgeService; they only work if those badges belong to this experience.

## Oil Barrel exclusive ball (latest)
- The model is your uploaded barrel mesh (`105517155573112`, loaded at runtime by `BallAccessories` with `AssetService:CreateMeshPartAsync`) with a NEW texture (`rbxassetid://105669825602431`, source `assets/textures/oil_barrel_rainbow_v6.png`). The old texture was lopsided because the mesh UV is split into 116 islands (4 body strips, 2 lids, hoops, overlapping bits); the new texture is generated from the mesh itself: hue follows the barrel axis so the rainbow is even on every strip, the lids get a radial rainbow with a dark rim, and an "OIL" plate sits on each of the four strips. The old parts-built barrel remains as an automatic fallback if the mesh cannot load. Glitter and sparks as before.
- Never sold with wins or a Developer Product (`IsExclusive`). Owned through: the 499 R$ Game Pass (paste the id in `shared/ShopConfig.luau` -> `ExclusiveBalls.OilBarrel.PassId`), the Captain Oil Server Pack (buyer only), or the day-7 calendar reward.
- Ball shop: opaque banner pinned over the bottom edge with the Robux icon and price (disabled "COMING SOON" until the pass id is set); hidden once owned. The Store panel has the same entry.
- Excluded from the upgrade/downgrade chain and from the calendar's "next ball" pick.
- Thumbnail frames: `assets/thumbnails/oil_barrel_closeup.jpg`, `oil_barrel_label.jpg` (1920x913, crop to 512x512 for the pass).
- Not exercised: a real pass purchase / ownership grant, and equipping the barrel from the shop (verified instead: swap onto the run ball, lobby rolling, preview in the shop banner and calendar).

## Notes on test data
Studio runs write to the same DataStores as the published game for your account. During testing the account received the Starter Pack grant (+10,000 wins, boosts), claimed one daily quest, and toggled Auto Rebirth on and off. If you want a clean account, reset those values in the DataStore manager.
