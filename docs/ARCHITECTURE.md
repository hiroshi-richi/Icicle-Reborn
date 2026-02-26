# Icicle: Reborn Architecture

## Runtime Flow
1. `src/core/Icicle.lua` bootstraps modules, validates dependencies, and owns shared runtime state.
2. Event entrypoint (`OnEvent`) delegates to `src/modules/IcicleEvents.lua`.
3. Events resolve units/casters and call tracking (`src/modules/IcicleTracking.lua`).
4. Resolver (`src/modules/IcicleResolver.lua`) binds GUID/name to visible nameplates.
5. Render loop (`src/modules/IcicleRender.lua`) reads state and draws icon containers.
6. UI options (`src/ui/IcicleUIOptions.lua`) configure profile values and notify systems.

## Module Responsibilities
- `src/core/Icicle.lua`: composition root, context wiring, frame scripts, lifecycle control.
- `src/core/IcicleConfig.lua`: profile migration + schema normalization + profile-level data fixes.
- `src/core/IcicleState.lua`: initial runtime state shape and reset behavior.
- `src/core/IcicleContexts.lua`: centralized builders for module context tables.
- `src/modules/IcicleEvents.lua`: event router and high-level event policy.
- `src/modules/IcicleEventParser.lua`: parsing helpers for combat log and spellcast events.
- `src/modules/IcicleTracking.lua`: cooldown record creation, dedupe, reset/shared logic.
- `src/modules/IcicleResolver.lua`: candidate tracking and GUID/nameplate binding heuristics.
- `src/modules/IcicleRender.lua`: icon list selection and frame updates.
- `src/modules/IcicleSpec.lua`: spec inference from aura/combat/inspect.
- `src/modules/IcicleInspect.lua`: inspect queue scheduling and talent callbacks.
- `src/modules/IcicleNameplates.lua`: visible plate discovery and metadata extraction.
- `src/modules/IcicleSpells.lua`: tracked-spell row building for options panel.
- `src/modules/IcicleCooldownRules.lua`: cooldown/shared/reset/modifier rule data and resolution.
- `src/modules/IcicleTestMode.lua`: synthetic cooldown generation for UI checks.
- `src/ui/IcicleUIOptionTabs.lua`: General/Style/Position tab option builders.
- `src/ui/IcicleUIOptions.lua`: options panel assembly and tracked spells tree UI.
- `src/ui/IcicleOptions.lua`: AceConfig panel registration.
- `src/ui/IcicleTooltip.lua`: spell/item tooltip and panel description formatting.

## Context Model
`Icicle.lua` passes explicit context tables into modules instead of letting modules read globals directly.
This keeps modules composable and test-friendly.

Current context builders live in `src/core/IcicleContexts.lua`:
- tracking context
- test mode context
- spells context
- events context

## Resolver Notes
Resolver behavior is controlled by:
- profile values: `mappingTTL`, `minConfidence`, `castMatchWindow`, `confHalfLife`
- internal tuning defaults in `src/modules/IcicleResolver.lua`

Heuristics are intentionally conservative:
- avoid friendly plate binds
- prefer exact/near-exact castbar timing
- use latest unique cast fallback only when strict candidates are unavailable
