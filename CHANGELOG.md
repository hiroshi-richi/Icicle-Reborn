# Changelog

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
- Performed release text cleanup across UI descriptions and README wording.

## 1.0.0-Beta - 2026-02-19

- Finalized release metadata in `Icicle.toc` (flavor, release date, category, default state).
- Updated README structure and release-facing documentation for clarity and consistency.
- This release focuses on beta release, packaging, docs, and presentation polish.
