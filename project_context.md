# Project Context - Cuticle Capital

## Project Summary
Browser-first idle/tycoon nail salon game built in Godot. Player starts with school debt and minimal equipment, then scales operations through upgrades, staffing, and location expansion.

## Recent Progress
- Initialized repository and documentation scaffold.
- Created dedicated game concept document for gameplay vision and reward design.
- Established milestone plan with immediate implementation tasks.

## Immediate Next Steps
1. Create base Godot 4 project in `godot/` with a minimal playable scene.
2. Implement first loop: tap/click to complete basic manicure service and gain cash.
3. Add starter economy config (service payout, service duration, first two upgrades).
4. Add save/load using local storage-compatible persistence for web.
5. Prepare first web export profile and verify local browser build.

## Long-Term Strategy
- Ship vertical slices: core loop -> upgrades -> expansion tiers -> retention systems.
- Keep balance values data-driven (JSON/resource files) so economy tuning is fast.
- Build with mobile UX constraints in mind even during web-first development.

## Blockers/Risks
- Idle game balance can drift quickly without telemetry and controlled tuning passes.
- Web performance and save persistence need early validation to avoid late rework.
- Scope creep risk from adding too many side systems before core loop is compelling.

## Key Files Changed
- `README.md`
- `project_context.md`
- `docs/plans/milestone_plan.md`
- `game-concept.md`

## Environment Notes
- GitHub auth verified for account `TinyRocketLaunch`.
- Repo intended as canonical source of truth across machines.