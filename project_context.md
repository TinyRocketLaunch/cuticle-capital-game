# Project Context - Cuticle Capital

## Project Summary
Browser-first idle/tycoon nail salon game built in Godot. Player starts with school debt and minimal equipment, then scales operations through upgrades, staffing, and location expansion.

## Recent Progress
- Expanded economy schema to data-drive multiple service types via `services[]`.
- Added pedicure as unlockable second service with distinct duration/payout/reputation values.
- Implemented queue/capacity simulation:
  - demand generates queued clients over time
  - queue cap scales with upgrades and location bonuses
  - service consumption drains queue and throughput becomes a pacing constraint
- Added first objectives panel with claimable mission rewards.
- Implemented first staff automation loop:
  - hireable assistant with cost + wage drain
  - assistant auto-processes queued clients using value-per-second prioritization
- Refactored `godot/scripts/main.gd` for save-compatible state evolution (legacy saves still merge).
- Updated QA checks in `tools/qa/economy_sanity.ps1` to validate new schema fields (`services`, `queue`, `staff`, missions).
- Re-validated via headless Godot startup and QA script.

## Immediate Next Steps
1. Add lightweight telemetry logging (`session income`, `services/min`, `upgrade purchase timestamps`) to support balancing.
2. Do first balancing pass now that queue + assistant loops exist (target debt payoff and location unlock timing).
3. Import first cohesive CC0 visual asset baseline (UI panels/icons + basic environment sprites).
4. Execute first Web export build to `build/web/` and run browser smoke test.
5. Add one more location tier and at least 2 new missions to prevent mid-loop plateau.

## Long-Term Strategy
- Continue modular vertical slices with strict playable checkpoints.
- Keep economy, locations, and upgrades fully data-driven to speed balancing.
- Add lightweight balancing telemetry hooks early (session income, upgrade purchase timing, churn points).

## Blockers/Risks
- No visual polish/art pipeline yet; current prototype is functional UI-only.
- Web export profile exists, but full browser packaging/export still needs a first pass.
- Current tuning is still manual/pre-telemetry; assistant + queue loops can drift into runaway or stall states without measured pacing targets.
- Assistant completion currently updates the shared message area frequently, which can reduce UX clarity during fast loops.

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

## Session Handoff (2026-02-27)
- Newly completed this session:
  1. Pedicure unlock path
  2. Queue/capacity simulation tied to upgrades/locations
  3. Objectives panel with claimable rewards
  4. Hireable assistant automation
- Next session priority order:
  1. Telemetry hooks + balancing pass
  2. Web export and browser smoke
  3. First cohesive CC0 art integration
- Current branch remains `main`.
