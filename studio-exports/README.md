# studio-exports

Scripts that live **only in the Studio place** (their parents, `StarterGui` and
`Workspace`, are not mapped by `default.project.json`, so Rojo does not manage
them). These are reference copies recovered from Studio; Rojo does not sync
this folder.

| File | Studio path | Type |
|---|---|---|
| `StarterGui/MainUI/HUDController.client.lua` | `StarterGui.MainUI.HUDController` | LocalScript |
| `Workspace/BowlingShop/BowlingShopInteraction.server.lua` | `Workspace.BowlingShop.BowlingShopInteraction` | Script |

Edits made directly in Studio via MCP that are **not scripts** (instance
properties; not captured by these files):

- `Workspace.BowlingShop.BallShopInteractionPoint.CanCollide = false`
- `Workspace.XPGenerators["GenX100 ADMIN XP"]` renamed to `GenX100 Admin XP`

Other Studio-only scripts not exported here (unmodified): `StarterGui.MainUI.XPBarController`,
`LevelUpController`, `StarterGui.BowlingShopGui.BowlingShopUI`,
`StarterGui.WinCourseUI.WinCourseUIController`, `StarterPlayerScripts.Xocoatl.*`.

Mapping StarterGui/Workspace into Rojo would let Rojo overwrite the Studio-built
frames, so it has been left unmapped until that is done deliberately.

## Studio-only changes (not captured by script files)

- `StarterGui.BowlingShopGui` is **disabled** (`Enabled = false`, its `BowlingShopUI`
  script `Disabled = true`). It is replaced by `src/client/BallShopUI.client.lua`,
  which builds its own UI in code. The old GUI is kept in the place for reference.
- `StarterGui.MainUI` is **disabled** (`Enabled = false`). The old top-right Wins/Oil/Level
  panel is replaced by `src/client/HudUI.client.lua` (bottom-center HUD + bottom-left rebirth
  panel). Its scripts (`HUDController`, `XPBarController`, `LevelUpController`) still exist but
  render nothing; delete the GUI once you are happy with the new HUD.

## Lobby room widened (Studio-only geometry change)

The generator row (x = -98 .. -29) did not fit inside the original room (walls x = -92.7 .. -37.3,
floor ending at x = -32.1), so GenX1 and both admin generators were partly or fully outside it.
The room was widened to fit. World X extents, before -> after:

| Part (all `Workspace.Part`, rotated 90 deg about Y) | Before | After |
|---|---|---|
| Wood floor (size 51.9 x 0.2 x 65.7) | -97.8 .. -32.1 | -111.3 .. -18.6 |
| Glass strip under the generators (11.9 x 0.4 x 65.7) | -97.8 .. -32.1 | -111.3 .. -18.6 |
| Back wall | -92.7 .. -37.3 | -106.7 .. -23.3 |
| West wall (47.2 x 31.7 x 0.8) | -92.7 .. -91.9 | -106.7 .. -105.9 |
| East wall (47.2 x 31.7 x 0.6) | -37.9 .. -37.3 | -23.9 .. -23.3 |
| Front wall, west piece | -92.7 .. -76.5 | -106.7 .. -76.5 |
| Front wall, east piece | -53.5 .. -37.3 | -53.5 .. -23.3 |

The lane opening (-76.5 .. -53.5) is unchanged. `LobbyDecor` and `LeaderboardService` use the new width.

## XP generators rearranged (Studio-only geometry change)

The eight `Workspace.XPGenerators` pads were packed in one row 10 studs apart. They are now 80% size
(6.7 x 0.6 x 6.8) and staggered in two rows (odd pads at z = -238.6, even pads at z = -229.8), keeping the
left-to-right order x1 -> x1000 (x unchanged).

## Lobby deepened (Studio-only geometry change)

For 14 players the room was deepened from 46 to 83 studs. Z extents, before -> after:

| Part | Before | After |
|---|---|---|
| Back wall (z centre) | -242.8 | -279.0 |
| West / east walls | -243.3 .. -196.1 | -279.5 .. -196.1 |
| Wood floor | -247.7 .. -195.9 | -283.5 .. -195.9 |
| Glass strip under the generators | z centre -241.8 | z centre -272.0 |
| `XPGenerators` (all eight, now one straight row) | z -238.6 / -229.8 (staggered) | z -272.0 |

`LobbyDecor` (Z_MIN = -278.4), `LeaderboardService` (board Z = -278.0) and the rack placement use the new depth.

## Oil course extended (Studio-only geometry change)

`OilCourseGenerator` / `OilCoursePreview` `ROW_SPACING` went 27 -> 39. Rows 1..12 span z -174.6 .. 254.4, with 55 studs of clear room before the FinishWall for the countdown camera. The original shared `OilPlatformStand` (centre post + top rail) is unchanged.

| Part | Before | After |
|---|---|---|
| `Course.Floor`, `LeftBoundary`, `RightBoundary` | end at z ~146.9 | end at z 311.55 (size X lengthened, centre moved) |
| `FinishWall` (z) | 144.75 | 309.4 |
| `WinCourseGenerator` START_POSITION z (code) | 135.584 | 300.244 |

`GutterService` sizes its strips from the floor / FinishWall, so it follows automatically. If you change `ROW_SPACING` again, move `FinishWall`, extend the three lane parts and shift the WinCourse start by the same amount (11 x change).
