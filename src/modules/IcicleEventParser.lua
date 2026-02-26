IcicleEventParser = IcicleEventParser or {}

local strmatch = string.match
local bit_band = bit.band
local COMBATLOG_OBJECT_TYPE_PET_MASK = COMBATLOG_OBJECT_TYPE_PET or 0

function IcicleEventParser.ParseCombatLog(...)
    local subEvent = select(2, ...)
    local arg3 = select(3, ...)
    local sourceGUID, sourceName, sourceFlags, spellID, spellName

    if type(arg3) == "boolean" then
        sourceGUID, sourceName, sourceFlags = select(4, ...), select(5, ...), select(6, ...)
        spellID, spellName = select(12, ...), select(13, ...)
    else
        sourceGUID, sourceName, sourceFlags = select(3, ...), select(4, ...), select(5, ...)
        spellID, spellName = select(9, ...), select(10, ...)
    end

    if not spellID or not sourceName then
        return nil
    end

    local normalizedSourceName = sourceName
    local normalizedSourceGUID = sourceGUID
    if type(sourceFlags) == "number" and COMBATLOG_OBJECT_TYPE_PET_MASK ~= 0 and bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET_MASK) == COMBATLOG_OBJECT_TYPE_PET_MASK then
        local owner = strmatch(sourceName or "", "<([^>]+)>")
        if owner and owner ~= "" then
            normalizedSourceName = owner
            normalizedSourceGUID = nil
        end
    end

    return {
        subEvent = subEvent,
        sourceGUID = normalizedSourceGUID,
        sourceName = normalizedSourceName,
        sourceFlags = sourceFlags,
        spellID = spellID,
        spellName = spellName,
    }
end

function IcicleEventParser.ParseUnitSpellcastSucceeded(...)
    local unit = select(1, ...)
    local a2, a3, a4, a5 = select(2, ...), select(3, ...), select(4, ...), select(5, ...)
    local spellName, spellRank, spellID

    if type(a2) == "string" then
        spellName = a2
        spellRank = type(a3) == "string" and a3 or nil
        if type(a4) == "number" then spellID = a4 end
        if not spellID and type(a5) == "number" then spellID = a5 end
    elseif type(a3) == "string" then
        spellName = a3
        spellRank = type(a4) == "string" and a4 or nil
        if type(a5) == "number" then spellID = a5 end
    end

    if not unit or not spellName or spellName == "" then
        return nil
    end

    return {
        unit = unit,
        spellName = spellName,
        spellRank = spellRank,
        spellID = spellID,
    }
end
