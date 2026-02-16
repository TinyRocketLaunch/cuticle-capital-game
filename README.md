# Cuticle Capital

A browser-first idle/tycoon game about building a nail salon empire from a debt-heavy bedroom setup to owning a full shop.

## Current Scope
- Core prototype in Godot targeting Web export first.
- Economy loop: perform services -> earn cash slowly -> buy upgrades -> improve throughput and value.
- Progression path: bedroom setup -> rented suite(s) -> owned salon endgame + infinite progression.

## Project Structure
- `project_context.md`: implementation continuity and engineering state.
- `game-concept.md`: game design intent, loop design, balancing goals, and feature ideas.
- `docs/plans/milestone_plan.md`: execution milestones and immediate next steps.
- `godot/`: Godot project files.
- `tools/qa/`: repeatable terminal QA checks.

## Tooling
- Engine: Godot 4.x
- Target: HTML5/Web first; mobile testing after web loop is stable.

## Quick Start
1. Install Godot 4.x.
2. Open the `godot/` folder in Godot and run scene `res://scenes/Main.tscn`.

## Terminal Validation
1. Headless boot check:
   - `& 'C:\Users\Rocket\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6-stable_win64_console.exe' --headless --path godot --quit`
2. Economy sanity QA:
   - `powershell -ExecutionPolicy Bypass -File tools/qa/economy_sanity.ps1`

## Notes
This repo is initialized with planning docs first so we can keep design and implementation synchronized from day one.
