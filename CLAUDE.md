Claude Code Instructions — RobloxBase
Mission

Improve and complete this existing Roblox bowling game for its first public release.

Use the existing project as the reference implementation. Preserve working systems, reuse existing assets, and refactor or replace defective systems when justified.

Do not rebuild the game from scratch or rewrite working code without a clear reason.
Before Making Changes

    Inspect relevant source files and their direct dependencies.
    Read the existing documentation and Rojo configuration.
    Verify actual code behavior rather than trusting comments alone.
    Identify the source of truth for each piece of state.
    Trace important data from server logic through replication to client presentation.
    Identify likely regressions before changing shared systems.

Do not assume a feature is complete because a script exists.
Server Authority and Security

The server owns progression, rewards, XP, levels, wins, rebirths, oil, purchases, ball ownership, and persistent player data.

The client may handle input, UI, animations, camera behavior, and visual effects.

Validate client requests on the server. Never trust client-supplied prices, ownership claims, progression values, or reward amounts.

Preserve appropriate input validation, data sanitization, save safeguards, and failure handling.

Never introduce duplicate sources of truth or duplicate authoritative services.
Existing Player Data

The documented PlayerDataService uses the PlayerData_v1 DataStore and tracks XP, Level, Wins, Rebirths, CurrentOil, OwnedBalls, and EquippedBall.

Verify the actual schema and implementation before changing anything.

The existing notes identify a possible mismatch between the CurrentOil and Oil attributes. Trace every relevant producer and consumer before resolving it.

Do not change DataStore schemas, attribute names, progression formulas, or purchase contracts casually. Explain and test necessary changes.
Movement and Physics

Prioritize investigating the existing ball physics, movement, camera, input, and synchronization systems.

Determine the causes of anchoring, hovering, collision problems, unnatural movement, and controller interference before selecting a solution.

Support responsive movement, natural ground contact, appropriate rolling behavior, and jumping in designated lobby areas.

Do not merely remove anchoring or constraints without understanding their purpose.

Refactor or replace defective controllers when necessary, ensuring that each responsibility has a clear owner.
UI, Audio, and Lobby

Improve the lobby, ball shop, progression UI, animations, and player feedback into a consistent visual experience.

Reuse existing models and assets where appropriate.

The desired style is comfortable, playful, polished, and motivating without excessive visual noise.

Implement background music with suitable volume controls and focus-aware fading where supported.

Use appropriately timed, dismissible group and like invitations and a functional feedback submission flow.

Do not claim that a feedback submission or purchase succeeded without confirmation.
Tooling and Assets

Preserve the existing Rojo configuration unless a verified issue requires a change.

Inspect the actual capabilities of installed Blender MCP and Roblox MCP tools before depending on them.

Do not publish the game, change live production data, or make destructive external changes without explicit authorization.
Efficient Development

    Read only the files needed for the current task and its dependencies.
    Avoid repeatedly summarizing unchanged code.
    Reuse existing modules and assets where appropriate.
    Prefer focused, testable implementation batches.
    Avoid unrelated rewrites and speculative features.
    Keep reports concise and actionable.
    Use source control or a recoverable working copy.
    Do not install unnecessary tools or dependencies.

Validation

Use available static checks, Rojo validation, and Roblox Studio tests.

Test critical gameplay paths, including movement, purchases, progression, saving, rejoining, and multiplayer behavior.

Clearly distinguish verified results from assumptions and tests that still require manual execution.

Never claim that the game is exploit-proof or fully tested without sufficient evidence.
Working Agreement

Start by inspecting and reporting the current state of the project.

Propose a prioritized plan, then implement improvements in manageable batches.

When a root cause is established, fix it rather than repeatedly patching symptoms.

Keep documentation consistent with verified implementation status.

The goal is a reliable, polished first release with minimal unnecessary rework and a maintainable foundation for future updates.