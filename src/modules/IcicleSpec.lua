IcicleSpec = IcicleSpec or {}

local SPEC_BY_SPELL_ID = {
    -- Druid
    [50334] = "feral",
    [16979] = "feral",
    [49376] = "feral",

    -- Hunter
    [63672] = "survival",
    [49012] = "survival",
    [19503] = "survival",
    [34490] = "mm",
    [53209] = "mm",
    [19574] = "bm",

    -- Mage
    [12042] = "arcane",
    [12472] = "frost",
    [29977] = "fire",
    [44572] = "frost",
    [42950] = "fire",
    [31687] = "frost",

    -- Paladin
    [53385] = "retri",
    [31789] = "protPala",
    [53595] = "protPala",
    [31821] = "holy",

    -- Priest
    [15487] = "shadow",
    [64044] = "shadow",
    [53007] = "disc",
    [33206] = "disc",
    [10060] = "disc",
    [47788] = "holyPriest",

    -- Rogue
    [51690] = "combat",
    [51713] = "sub",
    [36554] = "sub",
    [14185] = "sub",
    [13877] = "combat",
    [14177] = "assa",

    -- Shaman
    [59159] = "ele",
    [51533] = "enhancement",
    [55198] = "restoSham",
    [16190] = "restoSham",
    [16188] = "restoSham",
    [16166] = "ele",

    -- Warlock
    [47241] = "demo",
    [59172] = "destro",
    [47847] = "destro",
    [59164] = "affli",
    [18708] = "demo",

    -- Warrior
    [12809] = "protWar",
    [46924] = "arms",
    [12292] = "fury",
    [12975] = "protWar",
}

local SPEC_BY_AURA_NAME = {
    ["Ice Barrier"] = "frost",
    ["Icy Veins"] = "frost",
    ["Arcane Power"] = "arcane",
    ["Combustion"] = "fire",
    ["Avenging Wrath"] = "retri",
    ["Shadowform"] = "shadow",
    ["Dispersion"] = "shadow",
    ["Power Infusion"] = "disc",
    ["Pain Suppression"] = "disc",
    ["Divine Spirit"] = "holyPriest",
    ["Adrenaline Rush"] = "combat",
    ["Shadow Dance"] = "sub",
    ["Metamorphosis"] = "demo",
    ["Backdraft"] = "destro",
    ["Haunt"] = "affli",
    ["Elemental Mastery"] = "ele",
    ["Tidal Force"] = "restoSham",
    ["Shamanistic Rage"] = "enhancement",
    ["Blade Flurry"] = "combat",
    ["Recklessness"] = "fury",
    ["Shield Wall"] = "protWar",
    ["Berserk"] = "feral",
}

local INSPECT_SPEC_BY_CLASS_TAB = {
    WARRIOR = { "arms", "fury", "protWar" },
    PALADIN = { "holy", "protPala", "retri" },
    HUNTER = { "bm", "mm", "survival" },
    ROGUE = { "assa", "combat", "sub" },
    PRIEST = { "disc", "holyPriest", "shadow" },
    SHAMAN = { "ele", "enhancement", "restoSham" },
    MAGE = { "arcane", "fire", "frost" },
    WARLOCK = { "affli", "demo", "destro" },
    DRUID = { "balance", "feral", "restoDruid" },
    DEATHKNIGHT = { "blood", "frostDk", "unholy" },
}

local function CopyEntry(spec, confidence, now, source)
    return {
        spec = spec,
        confidence = confidence,
        lastSeen = now,
        source = source,
    }
end

local function UpdateEntry(existing, spec, now, source, ttl)
    if not existing or type(existing) ~= "table" then
        return CopyEntry(spec, 0.65, now, source), true
    end

    local lastSeen = existing.lastSeen or now
    local conf = tonumber(existing.confidence) or 0.6
    local isStale = (now - lastSeen) > ttl

    if existing.spec == spec then
        local nextConf = math.min(1.0, conf + 0.10)
        local changed = (nextConf ~= conf) or ((existing.source or "") ~= (source or ""))
        return {
            spec = spec,
            confidence = nextConf,
            lastSeen = now,
            source = source,
        }, changed
    end

    if isStale or conf <= 0.50 then
        return CopyEntry(spec, 0.55, now, source), true
    end

    return {
        spec = existing.spec,
        confidence = math.max(0.30, conf - 0.20),
        lastSeen = now,
        source = existing.source or source,
    }, true
end

function IcicleSpec.GetSpecFromSpellID(spellID)
    return SPEC_BY_SPELL_ID[spellID]
end

function IcicleSpec.GetSpecFromAuraName(auraName)
    return SPEC_BY_AURA_NAME[auraName]
end

function IcicleSpec.UpdateFromCombatEvent(ctx, spellID, sourceGUID, sourceName)
    if not ctx or not ctx.db or not ctx.db.specDetectEnabled then
        return false
    end
    local spec = IcicleSpec.GetSpecFromSpellID(spellID)
    if not spec then
        return false
    end

    local ttl = tonumber(ctx.db.specHintTTL) or 300
    ttl = math.max(30, math.min(3600, ttl))
    local now = GetTime()
    local changed = false
    local source = "spell:" .. tostring(spellID)

    if sourceGUID and sourceGUID ~= "" then
        local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByGUID[sourceGUID], spec, now, source, ttl)
        ctx.STATE.specByGUID[sourceGUID] = nextEntry
        changed = changed or entryChanged
    end

    if sourceName and sourceName ~= "" then
        local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByName[sourceName], spec, now, source, ttl)
        ctx.STATE.specByName[sourceName] = nextEntry
        changed = changed or entryChanged
    end

    if changed and ctx.db.persistSpecHints then
        ctx.db.specHintsByGUID = ctx.db.specHintsByGUID or {}
        ctx.db.specHintsByName = ctx.db.specHintsByName or {}
        if sourceGUID and sourceGUID ~= "" then
            ctx.db.specHintsByGUID[sourceGUID] = ctx.STATE.specByGUID[sourceGUID]
        end
        if sourceName and sourceName ~= "" then
            ctx.db.specHintsByName[sourceName] = ctx.STATE.specByName[sourceName]
        end
    end

    return changed
end

function IcicleSpec.PruneExpiredHints(ctx)
    if not ctx or not ctx.db then
        return false
    end
    local ttl = tonumber(ctx.db.specHintTTL) or 300
    ttl = math.max(30, math.min(3600, ttl))
    local now = GetTime()
    local changed = false

    local function pruneTable(tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                local lastSeen = tonumber(v.lastSeen) or now
                if (now - lastSeen) > ttl then
                    tbl[k] = nil
                    changed = true
                end
            end
        end
    end

    pruneTable(ctx.STATE.specByGUID)
    pruneTable(ctx.STATE.specByName)

    if changed and ctx.db.persistSpecHints then
        ctx.db.specHintsByGUID = ctx.db.specHintsByGUID or {}
        ctx.db.specHintsByName = ctx.db.specHintsByName or {}
        for k in pairs(ctx.db.specHintsByGUID) do
            if not ctx.STATE.specByGUID[k] then
                ctx.db.specHintsByGUID[k] = nil
            end
        end
        for k in pairs(ctx.db.specHintsByName) do
            if not ctx.STATE.specByName[k] then
                ctx.db.specHintsByName[k] = nil
            end
        end
    end

    return changed
end

function IcicleSpec.UpdateFromUnitAura(ctx, unit)
    if not ctx or not ctx.db or not ctx.db.specDetectEnabled then
        return false
    end
    if not unit or unit == "" or not UnitExists(unit) or not UnitCanAttack("player", unit) then
        return false
    end
    local sourceGUID = UnitGUID(unit)
    local sourceName = UnitName(unit)
    if sourceName then
        sourceName = string.match(sourceName, "([^%-]+)") or sourceName
    end
    if not sourceGUID and not sourceName then
        return false
    end

    local changed = false
    local ttl = tonumber(ctx.db.specHintTTL) or 300
    ttl = math.max(30, math.min(3600, ttl))
    local now = GetTime()
    for i = 1, 40 do
        local auraName, _, _, _, _, _, _, _, _, _, auraSpellID = UnitAura(unit, i, "HELPFUL")
        if not auraName then
            break
        end
        local spec = nil
        if auraSpellID then
            spec = SPEC_BY_SPELL_ID[auraSpellID]
        end
        if not spec then
            spec = SPEC_BY_AURA_NAME[auraName]
        end
        if spec then
            local source = auraSpellID and ("auraSpell:" .. tostring(auraSpellID)) or ("aura:" .. tostring(auraName))
            if sourceGUID and sourceGUID ~= "" then
                local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByGUID[sourceGUID], spec, now, source, ttl)
                ctx.STATE.specByGUID[sourceGUID] = nextEntry
                changed = changed or entryChanged
            end
            if sourceName and sourceName ~= "" then
                local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByName[sourceName], spec, now, source, ttl)
                ctx.STATE.specByName[sourceName] = nextEntry
                changed = changed or entryChanged
            end
            if changed and ctx.db.persistSpecHints then
                ctx.db.specHintsByGUID = ctx.db.specHintsByGUID or {}
                ctx.db.specHintsByName = ctx.db.specHintsByName or {}
                if sourceGUID and sourceGUID ~= "" then
                    ctx.db.specHintsByGUID[sourceGUID] = ctx.STATE.specByGUID[sourceGUID]
                end
                if sourceName and sourceName ~= "" then
                    ctx.db.specHintsByName[sourceName] = ctx.STATE.specByName[sourceName]
                end
            end
            return changed
        end
    end
    return false
end

function IcicleSpec.UpdateFromInspectTalents(ctx, guid, sourceName, classToken, bestTabIndex)
    if not ctx or not ctx.db or not ctx.db.specDetectEnabled then
        return false
    end
    local tabs = INSPECT_SPEC_BY_CLASS_TAB[classToken]
    if not tabs then return false end
    local spec = tabs[bestTabIndex]
    if not spec then return false end
    local ttl = tonumber(ctx.db.specHintTTL) or 300
    ttl = math.max(30, math.min(3600, ttl))
    local now = GetTime()
    local source = "inspect:" .. tostring(classToken) .. ":" .. tostring(bestTabIndex)
    local changed = false

    if guid and guid ~= "" then
        local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByGUID[guid], spec, now, source, ttl)
        ctx.STATE.specByGUID[guid] = nextEntry
        changed = changed or entryChanged
    end
    if sourceName and sourceName ~= "" then
        local nextEntry, entryChanged = UpdateEntry(ctx.STATE.specByName[sourceName], spec, now, source, ttl)
        ctx.STATE.specByName[sourceName] = nextEntry
        changed = changed or entryChanged
    end
    if changed and ctx.db.persistSpecHints then
        ctx.db.specHintsByGUID = ctx.db.specHintsByGUID or {}
        ctx.db.specHintsByName = ctx.db.specHintsByName or {}
        if guid and guid ~= "" then
            ctx.db.specHintsByGUID[guid] = ctx.STATE.specByGUID[guid]
        end
        if sourceName and sourceName ~= "" then
            ctx.db.specHintsByName[sourceName] = ctx.STATE.specByName[sourceName]
        end
    end
    return changed
end
