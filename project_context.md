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
- Added telemetry hooks in `godot/scripts/main.gd`:
  - session KPIs in UI (`Session Income`, `Services/Min`, `Queue Pressure`)
  - JSONL event logging to `user://telemetry.jsonl` for upgrade purchases, service completion, mission claims, assistant hire, and location unlocks.
- Completed first balancing pass in `godot/data/economy.json`:
  - slower early demand rate
  - higher debt/location thresholds
  - later pedicure unlock and adjusted mission targets/rewards
  - higher assistant entry cost + wage pressure.
- Updated QA checks in `tools/qa/economy_sanity.ps1` to validate new schema fields (`services`, `queue`, `staff`, missions).
- Added export-template installer workflow scripts under `tools/setup/`.
- Completed first web export build to `godot/build/web/` and validated local HTTP smoke (`index.html` returned 200).
- Added asset pipeline docs and structure:
  - `docs/assets/asset_manifest.md`
  - `docs/assets/ATTRIBUTION.md`
  - `docs/assets/open_asset_sources.md`
  - `godot/assets/` typed subfolders for UI/sprites/tilesets/audio.
- Re-validated via headless Godot startup, QA script, and web export.

## Immediate Next Steps
1. Instrument telemetry analysis tooling (`tools/qa`) to summarize `telemetry.jsonl` into balancing reports.
2. Import first cohesive CC0 visual asset baseline (UI panels/icons + basic environment sprites).
3. Add one more location tier and at least 2 new missions to prevent mid-loop plateau.
4. Add audio cues (service start/complete, purchase, mission claim) with CC0 SFX pack.
5. Reduce message-log spam from assistant completions (queue events into a compact feed).

## Long-Term Strategy
- Continue modular vertical slices with strict playable checkpoints.
- Keep economy, locations, and upgrades fully data-driven to speed balancing.
- Add lightweight balancing telemetry hooks early (session income, upgrade purchase timing, churn points).

## Blockers/Risks
- No visual polish/art pipeline yet; current prototype is functional UI-only.
- Export templates are machine-local; fresh machines must run `tools/setup/install_godot_export_templates.ps1` before web export.
- Current tuning is still first-pass; assistant + queue loops can drift without telemetry-driven tuning scripts.
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
- `tools/setup/install_godot_export_templates.ps1`
- `tools/setup/apply_existing_templates.ps1`
- `docs/assets/asset_manifest.md`
- `docs/assets/ATTRIBUTION.md`
- `docs/assets/open_asset_sources.md`
- `godot/assets/.gitkeep`
- `godot/assets/ui/.gitkeep`
- `godot/assets/sprites/.gitkeep`
- `godot/assets/tilesets/.gitkeep`
- `godot/assets/audio/.gitkeep`

## Environment Notes
- GitHub auth verified for account `TinyRocketLaunch`.
- Headless validation command succeeded with Godot 4.6 console binary.
- Repo remains canonical source of truth across machines.

## Session Handoff (2026-02-27)
- Newly completed this session:
  1. Pedicure unlock path + queue/capacity + objectives + assistant automation
  2. Telemetry/KPI instrumentation in UI and event logs
  3. First balance retune pass
  4. First successful web export + local HTTP smoke
  5. Asset sourcing/attribution workflow scaffolding
- Next session priority order:
  1. Build telemetry summary QA script and use it for second balancing pass
  2. Import first cohesive CC0 art pack set (UI + sprites + tiles)
  3. Add third location tier and expanded mission chain
- Current branch remains `main`.
