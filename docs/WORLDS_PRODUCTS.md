# Worlds: products to create

Create these in Creator Hub (your experience > Monetization), then send me the IDs. Prices are my recommendations; each world costs more than the one before.

## 1. Admin XP generator Game Passes (Monetization > Passes)

| World | Pass | Multiplier | Price |
|---|---|---|---|
| Pro Alley (2) | Admin XP II | x200 | R$ 1,499 |
| Pro Alley (2) | Admin XP II MAX | x1300 | R$ 4,999 |
| Master Arena (3) | Admin XP III | x400 | R$ 2,999 |
| Master Arena (3) | Admin XP III MAX | x2600 | R$ 9,999 |
| Grandmaster Palace (4) | Admin XP IV | x800 | R$ 5,999 |
| Grandmaster Palace (4) | Admin XP IV MAX | x5200 | R$ 19,999 |

These go into `GamePassConfig.WorldAdminGenerators` in `src/server/GamePassConfig.luau`.

## 2. Re-themed ball Developer Products (Monetization > Developer Products)

The server uses one product per price point and records which ball you clicked, so you don't need one product per ball. Slower balls are cheaper and faster balls cost more. Each world uses a higher band.

| Product name | Price |
|---|---|
| Ball Tier 1 | R$ 49 |
| Ball Tier 2 | R$ 99 |
| Ball Tier 3 | R$ 149 |
| Ball Tier 4 | R$ 249 |
| Ball Tier 5 | R$ 399 |
| Ball Tier 6 | R$ 599 |
| Ball Tier 7 | R$ 899 |
| Ball Tier 8 | R$ 1,299 |
| Ball Tier 9 | R$ 1,799 |
| Ball Tier 10 | R$ 2,499 |

Which balls use which tier:
- **Pro Alley:** slowest uses Tier 1, fastest uses Tier 6.
- **Master Arena:** Tier 3 to Tier 8.
- **Grandmaster Palace:** Tier 5 to Tier 10.

## 3. Rainbow Oil Barrel world skins (Developer Products)

These can only be bought by players who own the original Oil Barrel pass. Each is the fastest ball in its world (+5 speed over that world's fastest).

| Skin | Price |
|---|---|
| Barrel: Pro Alley | R$ 3,499 |
| Barrel: Master Arena | R$ 6,999 |
| Barrel: Grandmaster Palace | R$ 12,999 |

## What to send me

Send the IDs in this format:

```
AdminXP-II: <id>, AdminXP-II-MAX: <id>, ... (6 pass ids)
BallTier1: <id> ... BallTier10: <id>
Barrel2: <id>, Barrel3: <id>, Barrel4: <id>
```