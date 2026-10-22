# Roadmap ideas (not built yet)

Notes from design discussions, to come back to after release. Nothing here is implemented.

## Lanes and the bowling-alley feel

Decision: keep the single shared start lane. One door keeps friends together, makes ghost runs
visible to everyone, and fills a small server. Build the alley feel *around* it:

1. **Background lanes with NPC bowlers** (best value). 3-4 decorative lanes each side of the real
   lane, behind glass / a low rail. NPCs in bowling shirts loop a throw animation, pins fall with
   real pin-crash sounds, little scoreboards flash "STRIKE!". Client-side only (one script drives
   animations + sounds for everyone), no physics, so it is cheap and never laggy.
2. **Strike celebrations**: when a real player gets a big win, all background lanes flash and
   their pins fall together.
3. **Timed race events** instead of permanent separate lanes: every ~10 min open 4 race lanes for
   30 s; the winner gets a boost. Multiplayer moment without splitting friends all the time.
4. **Per-world lane looks**: Pro Alley neon league lanes, Master Arena stadium with a crowd,
   GrandMaster floating lanes in space.
5. **Cosmetic lane trails / celebration sounds** sold for Robux, visible to others on the ghost view.

## How to build these in high quality (not choppy)

- **Models**: Blender (already set up with the Blender MCP) for pins, lanes, NPC props; export FBX,
  keep each mesh under ~10k triangles, bake textures to one 1024 px image per prop.
- **NPC bowlers**: Roblox R15 rigs + animations made in the Roblox Animation Editor (or Moon
  Animator); play them with an Animator on the client. Use the Creator Store's free R15 animation
  packs as a base.
- **Smoothness rules**: everything decorative is anchored and animated on the client
  (TweenService / RenderStepped CFrame), never physics or server-driven movement; stream it in with
  `ModelStreamingMode = Persistent` only when it must be seen from far away.
- **Sound**: Roblox's licensed audio library (Creator Store > Audio) has bowling pin crash / alley
  ambience sounds that are safe to use; play them as 3D sounds with a short RollOffMaxDistance so the
  lobby is not noisy.
- **Testing**: Studio "Start Server" with 2-4 players + the MicroProfiler (Ctrl+F6) to spot frame
  spikes before publishing.

## Release and growth plan

- **Before ads**: thumbnails (3-5, A/B tested with Roblox's thumbnail test), a 15-30 s gameplay
  video, a clear title + icon, and the first 60 seconds tuned (fast first win, first ball purchase
  within 2-3 minutes, tutorial short).
- **Ads**: start with Roblox Sponsored Experiences at about $20/day for 5-7 days. Watch the
  numbers in Creator Hub analytics: D1 retention (aim 25%+), average session (aim 12+ min), and
  payer conversion. Only scale spend while D1 retention holds; if it drops, fix the game first.
- **Recommendations** come from retention + session length + payer rate, not from ad spend alone.
  The ads only seed the first players; keeping them is what makes Roblox recommend the game.
- **Social**: short TikTok / YouTube Shorts / X clips (big wins, evolved balls, rebirths, the
  hologram leaderboard), a Discord with update pings, and a Roblox group (the group/like prompt is
  already in the game). Post 1 short a day for the first 2 weeks.
- **Updates**: a small update every week (new ball, limited event, new evolved skin) with a
  countdown in-game; big update every 3-4 weeks (new world). Update timing on Friday/Saturday.
- **Events and limited items**: weekend x2 events, limited-time balls, and a gifting system drive
  both spending and return visits.
- **400+ concurrent is a big target**: it usually needs strong retention plus either sustained ad
  spend or one viral clip. Treat it as the goal for after the first 2-3 updates, not week one.
