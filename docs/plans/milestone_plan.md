# Milestone Plan - Cuticle Capital

## Milestone 0 - Foundation Setup
- Create Godot project scaffold and baseline scene flow.
- Define economy constants/data tables for bedroom tier.
- Implement save/load skeleton and basic settings.

## Milestone 1 - Core Bedroom Loop (Prototype)
- Service interaction loop with time-to-complete feedback.
- Currency accrual and debt tracking.
- First upgrade branch: tools, polish quality, booking speed.
- Basic UI panels: cash, debt, upgrades, service queue.

## Milestone 2 - First Expansion Tier (Rented Suite)
- Unlock condition from bedroom tier.
- Add extra station logic and throughput increase.
- Introduce simple staff hire system.

## Milestone 3 - Midgame Retention Systems
- Daily login reward.
- Missions/objectives.
- Lightweight minigame events tied to bonus rewards.

## Milestone 4 - Endgame + Infinite Play
- Owned salon unlock.
- Prestige/infinite scaling systems (renown, franchise level, etc.).
- Late-game sinks to preserve meaningful decisions.

## Immediate Next Steps
1. Add a second service type (pedicure) with unlock progression.
2. Implement queue/capacity simulation tied to station upgrades.
3. Add missions/objectives panel with milestone cash rewards.
4. Introduce first staff hire and automation behavior.
5. Perform first full Web export build and browser smoke test.

## Completed In Current Build
- Initialized Godot project scaffold in `godot/`.
- Implemented single-service state machine and clickable interaction loop.
- Added JSON economy config load on startup.
- Added upgrade purchase system and applied effects.
- Added autosave plus save/load with offline passive income catch-up.
