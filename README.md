RobloxBase — Roblox Bowling Game
Overview

RobloxBase is an existing Roblox bowling-ball game developed using Luau, Roblox Studio, and Rojo.

The project includes ball gameplay, oil courses, player progression, ball ownership, purchases, rebirth-related systems, UI controllers, and custom 3D assets.

The goal is to improve and complete the existing game for its first public release while preserving valuable working systems and reusing existing assets.

This project is not intended to be rebuilt from scratch.
Project Goals

    Create responsive, satisfying bowling-ball movement and physics.
    Improve camera behavior and support jumping in designated lobby areas.
    Build a structured, welcoming, visually polished lobby.
    Improve the ball shop and gameplay UI.
    Add cohesive UI animations, background music, and gameplay audio feedback.
    Implement appropriately timed group and like invitations and a functional feedback interface.
    Maintain secure server-authoritative progression and purchases.
    Verify persistence, multiplayer behavior, and performance.
    Prepare a stable first release, targeting a 24–48 hour development window if testing supports it.

Technology

    Roblox Studio
    Luau
    Rojo
    Blender and existing 3D assets
    MCP-based development tools where configured

Verify the installed versions, tool capabilities, and actual configuration before making environment changes.
Existing Project Structure

The repository contains client-side controllers, server-side services, shared modules and assets, and a Rojo project configuration.

Important existing systems include:

    Player data and progression
    Ball definitions, spawning, physics, and synchronization
    Oil collection and course generation
    Win-course progression
    Purchases and ball ownership
    Rebirth-related logic
    XP, HUD, floating XP, and rebirth UI
    Ball camera and visual controllers

See docs/SYSTEMS_INVENTORY.md for the implementation inventory and docs/ARCHITECTURE.md for verified system relationships.

These descriptions are initial context, not proof that every system is complete or working.
Architecture Principles

The intended architecture is server-authoritative.

The server owns player progression, rewards, currency, purchases, ball ownership, rebirth decisions, and persistent data.

The client handles input, presentation, animations, camera behavior, and visual effects. Client requests that affect gameplay must be validated by the server.

Avoid duplicate sources of truth, duplicate services, unnecessary remotes, and undocumented changes to persistent data or public attributes.

Inspect the actual implementation before relying on these assumptions.
Development Workflow

    Inspect existing code and documentation before making changes.
    Identify the root cause of a problem before changing its implementation.
    Reuse working systems and existing assets where appropriate.
    Refactor or replace defective systems when necessary.
    Make focused changes with clear responsibilities.
    Run available validation and test the game in Roblox Studio.
    Document changes, test results, known issues, and outstanding risks.

Use source control or a separate working copy before making substantial changes.
Release Priorities

    Movement, physics, camera, and input reliability.
    Data persistence, progression, purchases, and security.
    Lobby layout and navigation.
    Ball shop and UI polish.
    Audio, animations, and player feedback.
    Performance, multiplayer, mobile compatibility, and release testing.

Documentation

    CLAUDE.md — Instructions for AI-assisted development.
    docs/ARCHITECTURE.md — Verified architecture and data flow.
    docs/SYSTEMS_INVENTORY.md — Existing systems, files, and responsibilities.
    docs/GAME_DESIGN.md — Intended gameplay and player experience.
    docs/ROADMAP.md — Priorities, implementation status, and release checklist.

Current Status

The repository contains substantial existing development work. The precise implementation status of individual systems, known defects, and remaining release requirements must be established through source inspection and testing.

Do not mark features as verified merely because a script or module exists.
Release Philosophy

Prioritize a cohesive, reliable, and enjoyable core experience over unnecessary features.

The first release should be stable enough for real players, while remaining easy to improve through subsequent updates and player feedback.