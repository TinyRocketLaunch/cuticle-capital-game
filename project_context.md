# Project Context - Cuticle Capital

## Project Summary
Browser-first idle/tycoon nail salon game built in Godot. Player starts with school debt and minimal equipment, then scales operations through upgrades, staffing, and location expansion.

## Recent Progress
- Implemented a runnable Godot 4.6 project in `godot/` with main scene `res://scenes/Main.tscn`.
- Built playable core loop: start service -> progress bar -> payout -> repeat.
- Added economy systems from JSON config (`godot/data/economy.json`):
  - cash, debt, reputation
  - 5 upgrades with scaling costs/effects
  - location unlock flow (bedroom -> small suite)
- Added retention and persistence foundations:
  - daily login reward streak logic
  - save/load on `user://savegame.json`
  - autosave timer and offline passive income catch-up
- Added Web export preset config in `godot/export_presets.cfg`.
- Added repeatable QA script `tools/qa/economy_sanity.ps1`.
- Verified project via headless Godot startup and QA script.

## Immediate Next Steps
1. Add a second service type (pedicure) with unlock condition and separate pacing values.
2. Introduce queue/capacity mechanics so upgrades affect throughput, not just multipliers.
3. Add first mission/objective panel with milestone rewards.
4. Implement simple staff system (one hireable assistant) for semi-automation.
5. Perform first Web export build to `build/web/` and run local browser smoke test.

## Long-Term Strategy
- Continue modular vertical slices with strict playable checkpoints.
- Keep economy, locations, and upgrades fully data-driven to speed balancing.
- Add lightweight balancing telemetry hooks early (session income, upgrade purchase timing, churn points).

## Blockers/Risks
- No visual polish/art pipeline yet; current prototype is functional UI-only.
- Web export profile exists, but full browser packaging/export still needs a first pass.
- Balance is pre-telemetry and likely to require several tuning iterations.

## Key Files Changed
- `.gitignore`
- `README.md`
- `project_context.md`
- `godot/project.godot`
- `godot/scenes/Main.tscn`
- `godot/scripts/main.gd`
- `godot/data/economy.json`
- `godot/export_presets.cfg`
- `godot/README.md`
- `tools/qa/economy_sanity.ps1`

## Environment Notes
- GitHub auth verified for account `TinyRocketLaunch`.
- Headless validation command succeeded with Godot 4.6 console binary.
- Repo remains canonical source of truth across machines.

## Session Handoff (2026-02-16)
- User confirmed next session should begin with:
  1. Pedicure service unlock + balancing
  2. Queue/capacity simulation
  3. Missions/objectives panel
  4. First hireable assistant automation
- Current branch is expected to remain `main` unless feature-branch workflow is requested later.
