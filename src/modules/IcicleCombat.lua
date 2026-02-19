IcicleCombat = IcicleCombat or {}

local bit_band = bit.band
local strmatch = string.match
local COMBATLOG_OBJECT_TYPE_PET_MASK = COMBATLOG_OBJECT_TYPE_PET or 0
local petTooltip = CreateFrame("GameTooltip", "IciclePetOwnerTooltip", nil, "GameTooltipTemplate")
local petOwnerByGUID = {}
local petOwnerCacheTTL = 10

local function ShortName(name)
    if not name then return nil end
    return strmatch(name, "([^%-]+)") or name
end

local function PetOwnerNameFromSource(sourceName)
    if not sourceName then return nil end
    local owner = strmatch(sourceName, "<([^>]+)>")
    if owner and owner ~= "" then
        return ShortName(owner)
    end
    return nil
end

local function PetOwnerNameFromGUID(sourceGUID)
    -- Performance mode: avoid tooltip scanning in combat path.
    -- Keep only cache lookup if already known.
    if not sourceGUID then return nil end
    local now = GetTime()
    local cached = petOwnerByGUID[sourceGUID]
    if cached and (now - (cached.seenAt or 0)) <= petOwnerCacheTTL then
        return cached.name
    end
    return nil
end

function IcicleCombat.IsHostileEnemyCaster(flags)
    if type(flags) ~= "number" then return false end
    local isHostile = bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE
    if not isHostile then
        return false
    end
    local isPlayer = bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER
    local isPet = COMBATLOG_OBJECT_TYPE_PET_MASK ~= 0 and bit_band(flags, COMBATLOG_OBJECT_TYPE_PET_MASK) == COMBATLOG_OBJECT_TYPE_PET_MASK
    return isPlayer or isPet
end

function IcicleCombat.GetReactionFromFlags(flags)
    if type(flags) ~= "number" then return nil end
    if bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE then
        return "hostile"
    end
    if bit_band(flags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == COMBATLOG_OBJECT_REACTION_FRIENDLY then
        return "friendly"
    end
    if bit_band(flags, COMBATLOG_OBJECT_REACTION_NEUTRAL) == COMBATLOG_OBJECT_REACTION_NEUTRAL then
        return "neutral"
    end
    return nil
end

function IcicleCombat.ParseCombatLog(...)
    local arg3 = select(3, ...)
    local sourceGUID, sourceName, sourceFlags, spellID, spellName

    if type(arg3) == "boolean" then
        sourceGUID, sourceName, sourceFlags = select(4, ...), select(5, ...), select(6, ...)
        spellID, spellName = select(12, ...), select(13, ...)
    else
        sourceGUID, sourceName, sourceFlags = select(3, ...), select(4, ...), select(5, ...)
        spellID, spellName = select(9, ...), select(10, ...)
    end

    local normalizedSourceName = ShortName(sourceName)
    local normalizedSourceGUID = sourceGUID
    local sourceIsPet = false
    if type(sourceFlags) == "number" and COMBATLOG_OBJECT_TYPE_PET_MASK ~= 0 and bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET_MASK) == COMBATLOG_OBJECT_TYPE_PET_MASK then
        sourceIsPet = true
        local owner = PetOwnerNameFromSource(sourceName)
        if not owner then
            owner = PetOwnerNameFromGUID(sourceGUID)
        end
        if owner then
            normalizedSourceName = owner
            normalizedSourceGUID = nil
        end
    end

    return {
        eventType = select(2, ...),
        sourceGUID = normalizedSourceGUID,
        sourceName = normalizedSourceName,
        sourceFlags = sourceFlags,
        sourceReaction = IcicleCombat.GetReactionFromFlags(sourceFlags),
        spellID = spellID,
        spellName = spellName,
        sourceIsPet = sourceIsPet,
    }
end
