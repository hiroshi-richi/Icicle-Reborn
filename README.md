# Icicle: Reborn

Icicle: Reborn tracks enemy cooldowns on WotLK (3.3.5a) nameplates and renders active cooldown timers directly on each enemy plate.

![Interface: 30300](https://img.shields.io/badge/Interface-30300-blue) ![WotLK Retail](https://img.shields.io/badge/WotLK-Retail-yellow)

## Release metadata

- AddOn: `Icicle: Reborn`
- Interface: `30300`
- Version: `1.0.0-Beta`
- SavedVariables: `Icicledb`
- Compatible client: `Wrath of the Lich King 3.3.5a`

## What it does

- Reads combat events and cast signals to detect cooldown usage.
- Resolves caster identity (GUID/name) to visible nameplates.
- Stores cooldowns by GUID, with controlled name-based storage when GUID is not yet resolved.
- Applies cooldown rules (base cooldowns, shared links, reset effects, spec modifiers).
- Supports class/category filtering to prevent class-spell miss matches.
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
- Icon text refresh is throttled (`iconUpdateInterval`).
- Group target resolution is throttled (`groupScanInterval`).
- Rendering uses pooled icon frames with periodic updates (no per-icon `OnUpdate` handlers).

## Known limits (3.3.5a)

- Blizzard 3.3.5 nameplates do not expose GUID directly.
- Duplicate enemy names can remain ambiguous until stronger mapping signals appear.
- Castbar correlation depends on cast text visibility and event timing.

## Quick release checklist

1. Enter combat and confirm enemy cooldown icons appear when casts happen.
2. Verify category border colors match Tracked Spells category settings.
3. Confirm interrupt highlight pulse appears when enabled.
4. Test duplicate-name situations with target/focus/mouseover to stabilize mapping.
5. Use `General -> Test mode` for quick UI simulation checks.
