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

## Developer Products to create (49 price points, one product per price)
19, 25, 29, 39, 49, 59, 69, 89, 99, 109, 119, 129, 139, 149, 159, 169, 189, 199, 209, 229, 239, 249, 259, 279, 299, 309, 319, 349, 359, 369, 389, 399, 409, 439, 449, 469, 479, 509, 549, 559, 599, 609, 659, 679, 699, 759, 779, 849, 949

Name each product after its price, then paste its id into `src/server/SkinProducts.luau`
(`[price] = productId`). A price left at `0` shows "SOON" and cannot be bought; the server warns
about prices missing from that file. The server decides which skin a purchase grants from its own
pending record, never from the client.

## Status
Wins route and shop UI built; the Robux route has not been exercised with live product ids.
