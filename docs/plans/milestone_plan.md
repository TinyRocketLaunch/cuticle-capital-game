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
1. Initialize Godot project in `godot/` and commit generated baseline files.
2. Implement single-service state machine and clickable interaction.
3. Add economy config file and parse on startup.
4. Wire simple upgrade purchase and effects.
5. Add autosave every 10-15 seconds + on important actions.