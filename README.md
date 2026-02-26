# Icicle: Reborn

Icicle: Reborn tracks enemy cooldowns on WotLK (3.3.5a) nameplates and renders active cooldown timers directly on each enemy plate.

![Interface: 30300](https://img.shields.io/badge/Interface-30300-blue) ![Wrath 3.3.5a](https://img.shields.io/badge/Wrath-3.3.5a-yellow)

## Release metadata

- AddOn: `Icicle: Reborn`
- Interface: `30300`
- Version: `1.0.1-Beta`
- SavedVariables: `Icicledb`
- Compatible client: `Wrath of the Lich King 3.3.5a`

## What it does

- Reads combat events and cast signals to detect cooldown usage.
- Resolves caster identity (GUID/name) to visible nameplates.
- Stores cooldowns by GUID, with controlled name-based storage when GUID is not yet resolved.
- Uses a short reappear fallback so known cooldowns can return faster when nameplates come back into view.
- Applies cooldown rules (base cooldowns, shared links, reset effects, spec modifiers).
- Supports class/category filtering to prevent class-spell mismatches.
- Shows category border colors and interrupt pulse highlight behavior.

## Configuration

All configuration is available in Blizzard Interface Options:

`Game Menu -> Interface -> AddOns -> Icicle: Reborn`

Panels:
- `General`
- `Style settings`
- `Position settings`
- `Tracked Spells`
- `Profiles`

## Defaults and data

- Base settings: `src/config/settings.lua` (`IcicleDefaults`)
- Default tracked categories/spells: `src/data/IcicleData.lua`
- Cooldown interaction matrix: `src/modules/IcicleCooldownRules.lua`
- Default enabled preset is curated: interrupt, stun, incapacitate, damage-reduction, and movement-impair-removal.
- Other default dataset spells remain available but disabled until manually enabled.

## Performance notes

- Nameplate scanning is throttled (`scanInterval`).
- Event-driven fast-scan bursts temporarily increase scan cadence during combat/nameplate transitions.
- Icon text refresh is throttled (`iconUpdateInterval`).
- Group target resolution is throttled (`groupScanInterval`).
- Rendering uses pooled icon frames with periodic updates (no per-icon `OnUpdate` handlers).

## Known limits (3.3.5a)

- Blizzard 3.3.5 nameplates do not expose GUID directly.
- Same-name units (most commonly pets/guardians) can remain ambiguous until stronger mapping signals appear.
- Castbar correlation depends on cast text visibility and event timing.

## Resolver tuning quick guide

Resolver heuristics are implemented in `src/modules/IcicleResolver.lua` (`RESOLVER_TUNING` and `TunedNumber`).

Most important knobs:
- `castMatchUniqueConfidence`: confidence for strict single cast-match bind.
- `castMatchNearestConfidence`: confidence when nearest cast match clearly wins.
- `castMatchLatestConfidence`: confidence for latest-cast fallback bind.
- `castNearestMinGap`: minimum timing gap required to accept nearest tie-break.
- `candidateTTLMultiplier`: how long candidate GUIDs are retained per name.
- `pendingBindMinTTL`: minimum pending bind lifetime.

Safe tuning order:
1. Adjust `castNearestMinGap` first (reduces wrong binds in same-name scenarios).
2. Tune confidence values (`castMatch*Confidence`) second.
3. Tune retention values (`candidateTTLMultiplier`, `pendingBindMinTTL`) last.

## Quick release checklist

1. Enter combat and confirm enemy cooldown icons appear when casts happen.
2. Verify category border colors match Tracked Spells category settings.
3. Confirm interrupt highlight pulses appear as expected for both Border and Icon modes.
4. Test duplicate-name situations with target/focus/mouseover to stabilize mapping.
5. Use `General -> Test mode` for quick UI simulation checks.
