# Icicle: Reborn (WotLK 3.3.5a)

Icicle: Reborn tracks enemy cooldowns on WotLK nameplates and renders active cooldown timers directly on each enemy plate.

## Key behavior

- Reads combat events and cast signals to detect cooldown usage.
- Resolves caster identity (GUID/name) to visible nameplates.
- Stores cooldowns by GUID, with controlled name-based storage when GUID is not yet resolved.
- Supports class/category spell filtering to prevent impossible class-spell matches.
- Shows category border colors per spell category, with interrupt pulse highlight behavior.

## How cooldown mapping works

1. Combat event arrives (`COMBAT_LOG_EVENT_UNFILTERED` / unit cast signal).
2. Cooldown rules are resolved (base cooldown, shared links, reset effects, spec modifiers).
3. Source is mapped to a plate using target/focus/mouseover/group target and castbar correlation.
4. Active cooldown icons are rendered and updated on the mapped nameplate.

## Configuration

All configuration is done through Blizzard Interface Options:

`Game Menu -> Interface -> AddOns -> Icicle: Reborn`

Panels:
- `General`
- `Style settings`
- `Position settings`
- `Tracked Spells`
- `Profiles`

## Defaults and data

- Base settings are in `src/config/settings.lua` (`IcicleDefaults`).
- Default tracked categories/spells are in `src/data/IcicleData.lua`.
- Cooldown interaction matrix (shared/reset/alias behavior) is in `src/modules/IcicleCooldownRules.lua`.
- Default enabled spells are a curated control/defensive preset:
  interrupt, stun, incapacitate, damage-reduction, and movement-impair-removal spells.
  Other default dataset spells are present but disabled until manually enabled.

## Performance notes

- Nameplate scanning is throttled (`scanInterval`).
- Icon text refresh is throttled (`iconUpdateInterval`).
- Group target resolution is throttled (`groupScanInterval`).
- Rendering uses pooled icon frames and periodic updates (no per-icon `OnUpdate` handlers).

## Known limits (3.3.5a)

- Blizzard 3.3.5 nameplates do not expose GUID directly.
- Duplicate enemy names can be ambiguous until stronger mapping signals appear.
- Castbar correlation depends on cast text visibility and timing.

## Quick validation checklist

1. Enter combat and confirm enemy cooldown icons appear on casts.
2. Verify category border colors match Tracked Spells category settings.
3. Confirm interrupt highlight pulse appears when enabled.
4. Test duplicate-name situations with target/focus/mouseover to stabilize mapping.
5. Use `General -> Test mode` for quick UI simulation checks.

