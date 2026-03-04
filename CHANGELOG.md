# Changelog

## 1.0.3-Beta - 2026-03-04

### Added
- Added duel refresh handling in `src/modules/IcicleEvents.lua` for `DUEL_REQUESTED`, `DUEL_INBOUNDS`, and `DUEL_FINISHED`.
- Added castbar anchor source debug traces via centralized `Print` in `src/core/Icicle.lua`.
- Added a Position-tab toggle for castbar-aware anchoring in `src/ui/IcicleUIOptionTabs.lua`.

### Changed
- Improved castbar-relative icon anchoring logic in `src/core/Icicle.lua` to better follow real nameplate castbar composites.
- Updated the default `anchorBelowCastbarWhenCasting` setting to `true` in `src/config/settings.lua`, with schema fallback in `src/core/IcicleConfig.lua`.
- Updated inspect queue internals in `src/modules/IcicleInspect.lua` and `src/core/IcicleState.lua` with GUID index bookkeeping for faster queue updates.
- Updated resolver group-target scanning in `src/modules/IcicleResolver.lua` to skip group-target passes when not grouped.
- Updated options refresh behavior in `src/ui/IcicleUIOptions.lua` with debounced non-critical full plate refreshes.
- Updated cooldown tracking internals in `src/modules/IcicleTracking.lua` and expiry/prune paths in `src/core/Icicle.lua` to use cached spell-map counts.
- Improved nameplate/castbar refresh handling in `src/modules/IcicleNameplates.lua` with cast text region caching, safer discovery heuristics, and castbar rebinding when plate internals change.

### Fixed
- Fixed cooldown icon anchor refresh for castbar show/hide transitions in render updates (`src/modules/IcicleRender.lua`).
- Fixed profile reset UX noise by ensuring chat output is gated by centralized debug-aware `Print`.

## 1.0.2-Beta - 2026-02-26

### Added
- Added `src/core/IcicleContexts.lua` to centralize context construction for tracking, test mode, spells, and event routing.
- Added `src/modules/IcicleEventParser.lua` for combat log and `UNIT_SPELLCAST_SUCCEEDED` parsing helpers.
- Added `src/ui/IcicleUIOptionTabs.lua` to split General/Style/Position option tab definitions from panel assembly.
- Added maintainer architecture documentation in `docs/ARCHITECTURE.md`.

### Changed
- Refactored `src/core/Icicle.lua` to consume context builders instead of large inline context tables.
- Refactored `src/modules/IcicleEvents.lua` to use parser helpers for clearer and safer event payload handling.
- Refactored `src/core/IcicleConfig.lua` to use profile migration/schema steps before normalization.
- Improved resolver heuristics in `src/modules/IcicleResolver.lua` with centralized tuning constants and stricter cast tie-break behavior.
- Updated README with resolver tuning guidance for maintainers.

### Fixed
- Removed unused legacy combat parser path and related dead code from `src/modules/IcicleCombat.lua`.

## 1.0.1-Beta - 2026-02-20

- Improved nameplate responsiveness in crowded fights with event-driven fast-scan bursts.
- Added reappear fallback logic so known cooldowns show faster when enemy nameplates return to view.
- Added periodic plate discovery while pending binds exist, improving reused-frame detection.
- Cleaned up release text across UI descriptions and README wording.

## 1.0.0-Beta - 2026-02-19

- Finalized release metadata in `Icicle.toc` (flavor, release date, category, default state).
- Updated README structure and release-facing documentation for clarity and consistency.
- Focused this beta release on packaging, docs, and presentation polish.
