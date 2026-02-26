IcicleCombat = IcicleCombat or {}

local bit_band = bit.band
local COMBATLOG_OBJECT_TYPE_PET_MASK = COMBATLOG_OBJECT_TYPE_PET or 0

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
