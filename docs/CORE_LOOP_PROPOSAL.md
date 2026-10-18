# Core loop audit and proposal (decisions needed from you)

Nothing in the "Proposed" sections is built yet. Each one is a yes/no for you.

## 1. The loop as it works today

1. **Lobby**: stand on an XP generator or roll around, shop for balls, claim free things (quests, calendar, timed gift, X6, community reward).
2. **OilCourse**: 12 rows, pick a platform per row (oil, x2/x4, /2 /4, upgrade/downgrade ball on rows 3/6/9, gutter on 3 random rows). Oil is the run's score.
3. **FinishWall -> WinCourse**: oil becomes distance; tiles along the way pay wins; a result screen (tile total, multipliers dragged in, confetti).
4. **Spend**: wins buy balls (faster = more oil and wins), XP -> level -> rebirth (permanent oil/wins multipliers).
5. **Return reasons**: daily quests, 7-day calendar, X6 offers, timed gift, leaderboards, friend XP bonus.

**What works:** a run is short and always pays something; there are three timescales of progress (run, session, rebirth); free rewards are frequent.

**Gaps found in this audit**
| Gap | Why it matters |
|---|---|
| No auto/AFK loop | Players who step away stop earning; AFK-friendly games hold concurrent users and sell the strongest pass in this genre |
| Few spend sinks after the last ball | Wins pile up with nothing to buy |
| Cosmetic layer is missing (trails, auras, ball skins) | Safest, highest-margin Robux items; also a flex for leaderboards |
| No server-wide goal | Nothing gives 14 players a reason to cheer each other on |
| No weekly layer | Daily quests reset every 24 h; nothing to chase for 7 days |
| Robux items are mostly boosts | Players who never buy still get nothing to look at |

## 2. What I verified / fixed in this pass
- WinCourse "ball tps back to start": generation now looks ~25 tiles ahead (was 10), and if the ball ever drops below the course the run ends gracefully with what was already earned instead of the ball being destroyed and respawned. (Under test I could not reproduce a fall at 240 studs/s.)
- Preview numbers no longer leak from the previous run's leftover rows.
- Gutter is now a negative platform in the 12 rows, not an edge strip.
- X6: endless random 7-14 min offers with a 2-minute claim window and a countdown card at a random spot.

## 3. Anti-AFK (be clear about the limit)
`PromptManager` answers Roblox's idle event, so a client that is still running will not be kicked at 20 minutes. It cannot keep anyone in if they close Roblox, lose their connection or the computer sleeps. The only honest way to keep a player earning while away is an **Auto Roll** mode (below), which is an explicit feature, not a trick.

## 4. Proposed additions (ask me which to build)

**A. Auto Roll (recommended, biggest lever)**
Server-driven loop: it picks the best platform each row and re-enters the course. Free version: 10 minutes after each manual run; Pass version (Robux): unlimited. Wins/oil are computed on the server exactly as now, with a safe efficiency (for example 70% of a manual run) so skill still matters. Needs one new Game Pass id.

**B. Cosmetics: trails and auras (Robux and wins)**
Ball trail colors, dash trail styles, finish-line confetti colors. Pure visuals, no balance risk.

**C. Weekly event + milestone track**
7 milestones per week (for example "finish 40 runs") with a free track and an optional paid track. Resets on Monday UTC. Gives the "come back every day this week" reason.

**D. Server goal bar**
A shared meter all players in a server fill by finishing runs; at 100% everyone gets x2 oil for 5 minutes. Builds the social feeling cheaply.

**E. Lucky wheel**
One free spin per hour; extra spins as a Robux item. Prizes: wins, boosts, a trail. (No random paid item with real value to avoid loot-box rules; extra spins only buy the same free prizes.)

**F. Starter pack / bundles**
First-session offer (ball + boosts), boost bundle, quest skip. Needs new product ids from you.

**G. More win sinks**
Rebirth-gated shop tier (balls that cost very large wins), ball "mastery" levels (spend wins to add a small speed bonus).

Suggested order: **A, B, C**, then D, E, F, G.

## 5. Release readiness (honest)
Ready to test publicly after you (1) create and wire the new Robux items you pick, (2) test every purchase with a test account and a rejoin, (3) run a 2-client session. Not proven yet: 14-player load, any real Robux purchase, the Roblox-side group/favorite prompts, and the sounds (ids chosen unheard).
