# Evolved skin products (Worlds 2-4)

Evolved balls are sold with Wins (server-validated) or Robux (Developer Products).
Pricing lives in `src/shared/WorldConfig.luau`. The original lobby (World 1) shop is unchanged.

## Wins price
`max(original WinsCost, 300) * world multiplier` (World 2 x3, World 3 x8, World 4 x20), two significant figures.
The Oil Barrel uses fixed prices. Wins need the Rookie Lanes original first (the shop offers a popup to buy it).

## Robux price
Original lobby Robux price + an extra that grows from the slowest to the fastest ball and is
larger in each later world: World 2 +10 -> +100, World 3 +40 -> +275, World 4 +85 -> +450
(prices end in 9). Paying Robux skips the original-ball requirement and also gives the original.
After any skin purchase the ball is auto-equipped (the server validates the equip).

## Developer Products (60, one per evolved ball per world)
Each product is named after its ball and world ("Pro Alley Voltage", "Master Arena Meteor",
"GrandMaster Oil Barrel") so the Robux prompt shows the right item. Their ids live in
`src/server/SkinProducts.luau` as `[ballId] = { [2] = ..., [3] = ..., [4] = ... }`
(World 2 = Pro Alley, 3 = Master Arena, 4 = GrandMaster). All 60 pasted prices were checked
against `WorldConfig`'s planned prices (0 mismatches). The server only grants a purchase when the
product bought is the one for the ball and world in its own pending record.

## Status
Wins route and shop UI built and tested in Studio. The Robux route is wired to the real
product ids but no live purchase has been made, so it is untested end to end.
