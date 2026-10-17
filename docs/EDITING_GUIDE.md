# Editing guide (for you)

Edit files in `src/` in your code editor, with `rojo serve` running and the Rojo plugin connected in Studio. Changes sync live. Stop and restart Play to reload ModuleScripts. Studio-only objects (StarterGui, Workspace models) are listed in `studio-exports/README.md`.

## Where things live

| Folder | Becomes | Put here |
|---|---|---|
| `src/server` | ServerScriptService | anything that grants, saves, charges |
| `src/client` | StarterPlayerScripts | UI, effects, input |
| `src/shared` | ReplicatedStorage | config both sides read (never secrets) |

**Rule:** the client may only *ask*. Prices, amounts, cooldowns and "is this allowed" are decided on the server.

## Change a number (safe, one-line edits)

| Want to change | File | What to edit |
|---|---|---|
| Leave popup reward / cooldown | `server/RewardService.server.lua` | `LEAVE_WINS`, `LEAVE_COOLDOWN`, `LEAVE_BOOST_SECONDS` |
| Community reward (+500) | `server/RewardService.server.lua` | `COMMUNITY_WINS` (also update the "+500 WINS!" text in `client/CommunityUI.client.lua`) |
| X6 timing | `server/LimitedGenerator.luau` | `CHANCES` |
| XP kit sizes | `shared/XPKits.luau` | `FRACTIONS` (1 = one level's XP) |
| x2 oil / x2 wins length, price label | `shared/BoostConfig.luau` | `Duration`, `PriceRobux` (the real price is set in Creator Hub) |
| Rebirth multipliers | `shared/RebirthBonuses.luau` | the three formulas |
| Daily quests (targets, wins, bonus) | `shared/QuestConfig.luau` | `Pool`, `BonusWins`, `BonusBoostSeconds` |
| Game pass ids and multipliers | `server/GamePassConfig.luau` (grants) and `shared/ShopConfig.luau` (Store list) | change the id in both |
| Friend XP bonus | `server/BoostService.luau` | `FRIEND_BONUS_PER`, `FRIEND_BONUS_MAX` |
| Which rows are upgrade/downgrade | `server/BallTierGates.server.lua` | `TIER_ROWS`, and the percentages in `rollPattern` |
| Space between oil rows | `server/OilCourseGenerator.luau` and `server/OilCoursePreview.server.lua` (same number in both) | `ROW_SPACING`; then follow the steps in `studio-exports/README.md` (lane length, FinishWall, `WinCourseGenerator` start) |
| Music tracks | `shared/AudioConfig.luau` | `SoundId` for `Lobby` and `Course` |
| Group id | `server/PromptService.server.lua`, `server/RewardService.server.lua`, `client/CommunityUI.client.lua` | `GROUP_ID` (change all three) |

## Add something to the STORE panel (left hub button)

The Store panel is built in `src/client/HubUI.client.lua`, in the section `GAME PASS SHOP PANEL`.

- **A game pass:** add an entry to `ShopConfig.GamePasses` in `src/shared/ShopConfig.luau`:
  ```lua
  { Name = "My Pass", Description = "What it does.", PassId = 123456789 },
  ```
  It appears automatically with a BUY button (`PassId = 0` shows SOON). The effect must be granted by a server script that checks `MarketplaceService:UserOwnsGamePassAsync`; see `server/GamePassService.luau` for the pattern.
- **A timed boost (developer product):** add an entry to `BoostConfig.Boosts` in `src/shared/BoostConfig.luau` with `ProductId`, `Duration`, `PriceRobux`, then add its key to the list `{ "Wins2x", "Oil2x" }` in the boost loop of `HubUI.client.lua`. If it needs a new effect, read `BoostService.XPMultiplier` and copy that.
- **A one-off developer product** (like XP kits): register it in `server/ProductService.server.lua` using `PurchaseService.RegisterProduct(productId, handler)` and the `consume()` helper. Never grant from a client message.

## Add a ball to the BOWLING SHOP

1. Create the product in Creator Hub (Robux balls only) and copy the id.
2. `src/server/BallDefinitions.luau`: copy an existing block and set `DisplayName`, `ForwardSpeed`, `HorizontalSpeed`, `WinsCost`, `RequiredRebirths`, and `DisplayOrder` (the order in the shop and in the upgrade/downgrade chain).
3. Robux ball: add `YourBall = <productId>,` in `src/server/BallProductDefinitions.luau`, and the display price in `src/shared/ShopConfig.luau` (`RobuxPrices`, display only).
4. Add the model to `BallModels` (Studio `.rbxm`; the colour/size comes from the template named exactly like the ball id).
5. Optional extras (orbiting/attached parts): add `designs.YourBall = function(ball) ... end` in `src/shared/BallAccessories.luau`, copying a small design such as `Venom`.
6. Check the Output window on Play: `[BallService] Definitions validated` must list the new count with no warnings.

## Change the lobby look

`src/server/LobbyDecor.server.lua` builds walls, racks, lamps and signs (constants at the top). The shop sign text is near `"BallShopSign"`.

## Test checklist after any change

1. Play in Studio, open Output, look for red errors.
2. Roll through StartWall, finish a run, confirm wins and XP update.
3. Rejoin and confirm saved data (wins, balls, boosts).
4. For purchases use a Studio test account only; never claim a purchase worked without the Output / receipt confirmation.

## Don't

- Don't rename DataStore keys or player attributes (`CurrentOil`, `Wins`, `Level`, ...) without tracing every user of them (`grep` the name first).
- Don't put prices, amounts or ids that grant things into client scripts.
- Don't publish from here without testing in Studio first.

## Adding a new big panel

Register it with `PanelManager` (`src/shared/PanelManager.luau`) instead of toggling `Visible` yourself:
`PanelManager.Register("Name", frame)`, then `PanelManager.Toggle("Name")`. That gives the slide in/out transition,
closes whichever panel is open, and makes the camera ignore zoom/FOV input while it is open.
