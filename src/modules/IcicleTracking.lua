IcicleTracking = IcicleTracking or {}

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo

local function EventDedupe(state, spellDedupeWindow, unitKey, spellID)
    local now = GetTime()
    state.recentEventByUnit[unitKey] = state.recentEventByUnit[unitKey] or {}
    local prev = state.recentEventByUnit[unitKey][spellID]
    local window = (spellDedupeWindow and spellDedupeWindow[spellID]) or 0.25
    if prev and (now - prev) < window then
        return true
    end
    state.recentEventByUnit[unitKey][spellID] = now
    return false
end

local INTERRUPT_SPELLS = {
    [72] = true,     -- Shield Bash
    [6552] = true,   -- Pummel
    [1766] = true,   -- Kick
    [2139] = true,   -- Counterspell
    [19647] = true,  -- Spell Lock
    [47528] = true,  -- Mind Freeze
    [57994] = true,  -- Wind Shear
    [47476] = true,  -- Strangulate
    [34490] = true,  -- Silencing Shot
}

local function IsInterruptSpell(spellID)
    return INTERRUPT_SPELLS[spellID] and true or false
end

local function ShouldTrackDuration(ctx, duration)
    if not duration or duration <= 0 then
        return false
    end
    local db = ctx and ctx.db
    if not db then
        return true
    end
    local minCd = tonumber(db.minTrackedCooldown) or 0
    local maxCd = tonumber(db.maxTrackedCooldown) or 0
    if minCd > 0 and duration < minCd then
        return false
    end
    if maxCd > 0 and duration > maxCd then
        return false
    end
    return true
end

local function BuildRecord(ctx, spellID, duration, spellNameOverride, meta, now, spellInfoCache)
    if not ShouldTrackDuration(ctx, duration) then
        return nil
    end
    local info = spellInfoCache and spellInfoCache[spellID]
    if not info then
        local spellName, _, texture = GetSpellInfo(spellID)
        info = {
            name = spellName,
            texture = texture,
        }
        if spellInfoCache then
            spellInfoCache[spellID] = info
        end
    end
    local texture = info.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
    now = now or GetTime()
    local isItem = false
    if ctx and ctx.IsItemSpell then
        isItem = ctx.IsItemSpell(spellID) and true or false
    end
    return {
        spellID = spellID,
        spellName = spellNameOverride or info.name or ("Spell " .. tostring(spellID)),
        texture = texture,
        startAt = now,
        expiresAt = now + duration,
        duration = duration,
        isShared = meta and meta.isShared or false,
        isItem = isItem,
        isInterrupt = IsInterruptSpell(spellID),
    }
end

local function UpsertRecord(mapByUnit, unitKey, record)
    mapByUnit[unitKey] = mapByUnit[unitKey] or {}
    local current = mapByUnit[unitKey][record.spellID]
    if (not current) or current.expiresAt < record.expiresAt then
        mapByUnit[unitKey][record.spellID] = record
    end
end

local function ApplyResets(stateStore, unitKey, resetSpells)
    local bySpell = stateStore[unitKey]
    if not bySpell then
        return false
    end

    local changed = false
    for resetSpellID in pairs(resetSpells) do
        if bySpell[resetSpellID] then
            bySpell[resetSpellID] = nil
            changed = true
        end
    end

    if next(bySpell) == nil then
        stateStore[unitKey] = nil
    end
    return changed
end

local function BuildTriggeredRecords(ctx, sourceSpellID, sourceSpellName, sourceRule, now, spellInfoCache)
    local list = {}

    local sourceRecord = BuildRecord(ctx, sourceRule.spellID or sourceSpellID, sourceRule.cd, sourceSpellName, { isShared = false }, now, spellInfoCache)
    if sourceRecord then
        list[#list + 1] = sourceRecord
    end

    local sharedTargets = sourceRule.sharedTargets
    if not sharedTargets then
        return list
    end

    for targetSpellID, sharedCfg in pairs(sharedTargets) do
        local targetRule
        if ctx.GetCooldownRule then
            targetRule = ctx.GetCooldownRule(targetSpellID, sourceRule.sourceGUID, sourceRule.sourceName)
        else
            targetRule = ctx.GetSpellConfig(targetSpellID, sourceRule.sourceGUID, sourceRule.sourceName)
        end
        if targetRule then
            local sharedDuration = sharedCfg and sharedCfg.sharedDuration
            local duration = sharedDuration or targetRule.cd
            if duration and duration > 0 then
                local rec = BuildRecord(ctx, targetRule.spellID or targetSpellID, duration, nil, { isShared = true }, now, spellInfoCache)
                if rec then
                    list[#list + 1] = rec
                end
            end
        end
    end

    return list
end

local function BuildSharedOnlyRecords(ctx, sourceGUID, sourceName, sourceSpellID, sharedTargets, now, spellInfoCache)
    local list = {}
    if not sharedTargets then
        return list
    end
    for targetSpellID, sharedCfg in pairs(sharedTargets) do
        local targetRule
        if ctx.GetCooldownRule then
            targetRule = ctx.GetCooldownRule(targetSpellID, sourceGUID, sourceName)
        else
            targetRule = ctx.GetSpellConfig(targetSpellID, sourceGUID, sourceName)
        end
        if targetRule then
            local duration = (sharedCfg and sharedCfg.sharedDuration) or targetRule.cd
            if duration and duration > 0 then
                local rec = BuildRecord(ctx, targetRule.spellID or targetSpellID, duration, nil, { isShared = true }, now, spellInfoCache)
                if rec then
                    list[#list + 1] = rec
                end
            end
        end
    end
    return list
end

local CLASS_CATEGORIES = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    DEATH_KNIGHT = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    DRUID = true,
}

local function IsClassMismatch(ctx, sourceGUID, sourceName, spellID)
    if not ctx or not ctx.db or not ctx.db.classCategoryFilterEnabled then
        return false
    end
    if not ctx or not ctx.SpellCategory then
        return false
    end
    local spellCategory = ctx.SpellCategory(spellID)
    if not spellCategory or not CLASS_CATEGORIES[spellCategory] then
        return false
    end
    if not ctx.GetSourceClassCategory then
        return false
    end
    local sourceCategory = ctx.GetSourceClassCategory(sourceGUID, sourceName)
    if not sourceCategory then
        return false
    end
    return sourceCategory ~= spellCategory
end

function IcicleTracking.StartCooldown(ctx, sourceGUID, sourceName, spellID, spellName, eventType)
    local sourceRule
    if ctx.GetCooldownRule then
        sourceRule = ctx.GetCooldownRule(spellID, sourceGUID, sourceName)
    else
        sourceRule = ctx.GetSpellConfig(spellID, sourceGUID, sourceName)
    end
    local now = GetTime()
    local sourceKey = sourceGUID or sourceName
    if not sourceKey then
        return
    end
    local sourceSpellID = sourceRule and (sourceRule.spellID or spellID) or spellID
    if IsClassMismatch(ctx, sourceGUID, sourceName, sourceSpellID) then
        return
    end

    local records
    local isSharedOnly = false
    local spellInfoCache = {}
    local dedupeSpellID = sourceSpellID
    if EventDedupe(ctx.STATE, ctx.spellDedupeWindow, sourceKey, dedupeSpellID) then
        return
    end

    if sourceRule and ctx.EventMatchesTrigger(eventType, sourceRule.trigger) then
        sourceRule.sourceGUID = sourceGUID
        sourceRule.sourceName = sourceName
        records = BuildTriggeredRecords(ctx, spellID, spellName, sourceRule, now, spellInfoCache)
    else
        local sharedTargets = ctx.GetSharedCooldownTargets and ctx.GetSharedCooldownTargets(spellID)
        if not sharedTargets or eventType ~= "SPELL_CAST_SUCCESS" then
            return
        end
        records = BuildSharedOnlyRecords(ctx, sourceGUID, sourceName, spellID, sharedTargets, now, spellInfoCache)
        isSharedOnly = true
    end

    if #records == 0 then
        return
    end

    local hasChanges = false

    if sourceGUID then
        for i = 1, #records do
            UpsertRecord(ctx.STATE.cooldownsByGUID, sourceGUID, records[i])
        end
        hasChanges = true
    end

    local bound = false
    if sourceGUID and sourceName then
        bound = ctx.TryBindByName(sourceGUID, sourceName, 0.9, "combatlog", spellName, now)
        if bound then
            ctx.MigrateNameCooldownsToGUID(sourceName, sourceGUID)
        elseif ctx.RegisterPendingBind then
            ctx.RegisterPendingBind(sourceGUID, sourceName, spellName, now)
        end
    end

    if sourceName and (not sourceGUID or not bound) then
        for i = 1, #records do
            UpsertRecord(ctx.STATE.cooldownsByName, sourceName, records[i])
        end
        hasChanges = true
    end

    local resetSpells = sourceRule and sourceRule.resetSpells or nil
    if resetSpells then
        if sourceGUID then
            local changed = ApplyResets(ctx.STATE.cooldownsByGUID, sourceGUID, resetSpells)
            hasChanges = changed or hasChanges
        end
        if sourceName then
            local changed = ApplyResets(ctx.STATE.cooldownsByName, sourceName, resetSpells)
            hasChanges = changed or hasChanges
        end
    end

    if hasChanges then
        ctx.RefreshAllVisiblePlates()
    end
end

