IcicleConfig = IcicleConfig or {}

local CATEGORY_BORDER_DEFAULTS = {
    GENERAL = { r = 0.502, g = 0.502, b = 0.502, a = 1.00 },
    WARRIOR = { r = 0.780, g = 0.612, b = 0.431, a = 1.00 },
    PALADIN = { r = 0.961, g = 0.549, b = 0.729, a = 1.00 },
    HUNTER = { r = 0.671, g = 0.831, b = 0.451, a = 1.00 },
    ROGUE = { r = 1.000, g = 0.961, b = 0.412, a = 1.00 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    DEATH_KNIGHT = { r = 0.769, g = 0.122, b = 0.231, a = 1.00 },
    SHAMAN = { r = 0.000, g = 0.439, b = 0.871, a = 1.00 },
    MAGE = { r = 0.247, g = 0.780, b = 0.922, a = 1.00 },
    WARLOCK = { r = 0.529, g = 0.533, b = 0.933, a = 1.00 },
    DRUID = { r = 1.000, g = 0.490, b = 0.039, a = 1.00 },
}

local function GetDefaultCategoryForSpell(spellID)
    local dataModule = _G.IcicleData
    if type(dataModule) == "table" and type(dataModule.DEFAULT_SPELL_DATA) == "table" then
        local entry = dataModule.DEFAULT_SPELL_DATA[spellID]
        if entry and type(entry.category) == "string" and entry.category ~= "" then
            return string.upper(entry.category)
        end
    end
    return "GENERAL"
end

local function IsDefaultEnabledSpell(spellID)
    local dataModule = _G.IcicleData
    if type(dataModule) == "table" and type(dataModule.DEFAULT_ENABLED_SPELL_IDS) == "table" then
        return dataModule.DEFAULT_ENABLED_SPELL_IDS[spellID] and true or false
    end
    return true
end

local function ApplyDefaultEnabledPreset(db, baseCooldowns)
    db.disabledSpells = db.disabledSpells or {}
    local dataModule = _G.IcicleData
    local defaultSpellData = type(dataModule) == "table" and dataModule.DEFAULT_SPELL_DATA or nil

    if type(defaultSpellData) == "table" then
        for spellID in pairs(defaultSpellData) do
            if IsDefaultEnabledSpell(spellID) then
                db.disabledSpells[spellID] = nil
            else
                db.disabledSpells[spellID] = true
            end
        end
    elseif baseCooldowns then
        for spellID in pairs(baseCooldowns) do
            if IsDefaultEnabledSpell(spellID) then
                db.disabledSpells[spellID] = nil
            else
                db.disabledSpells[spellID] = true
            end
        end
    end

    db.defaultEnabledPresetVersion = 1
end

local function RemapSpellKeySimple(tableRef, fromID, toID)
    if type(tableRef) ~= "table" or fromID == toID then
        return
    end
    local fromValue = tableRef[fromID]
    if fromValue == nil then
        return
    end
    if tableRef[toID] == nil then
        tableRef[toID] = fromValue
    end
    tableRef[fromID] = nil
end

local function RemapPvpTrinketCanonicalIDs(db)
    if type(db) ~= "table" then
        return
    end

    local fromID = 51378
    local toID = 42122
    if fromID == toID then
        return
    end

    RemapSpellKeySimple(db.customSpells, fromID, toID)
    RemapSpellKeySimple(db.spellOverrides, fromID, toID)

    if type(db.disabledSpells) == "table" and db.disabledSpells[fromID] ~= nil then
        if db.disabledSpells[toID] == nil then
            db.disabledSpells[toID] = db.disabledSpells[fromID]
        end
        db.disabledSpells[fromID] = nil
    end

    if type(db.removedBaseSpells) == "table" and db.removedBaseSpells[fromID] ~= nil then
        if db.removedBaseSpells[toID] == nil then
            db.removedBaseSpells[toID] = db.removedBaseSpells[fromID]
        end
        db.removedBaseSpells[fromID] = nil
    end

    if type(db.spellCategories) == "table" and db.spellCategories[fromID] ~= nil then
        if db.spellCategories[toID] == nil then
            db.spellCategories[toID] = db.spellCategories[fromID]
        end
        db.spellCategories[fromID] = nil
    end
end

function IcicleConfig.CopyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            IcicleConfig.CopyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function IcicleConfig.NormalizeProfile(db, baseCooldowns)
    db.spellCategories = db.spellCategories or {}
    db.disabledSpells = db.disabledSpells or {}
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    if db.persistSpecHints == nil then db.persistSpecHints = false end
    if db.specDetectEnabled == nil then db.specDetectEnabled = true end
    db.specHintTTL = math.max(30, math.min(3600, tonumber(db.specHintTTL) or 300))
    if db.party == nil then db.party = db.field ~= false end
    if db.raid == nil then db.raid = db.field ~= false end
    if db.showAmbiguousByName == nil then db.showAmbiguousByName = true end
    if db.showInterruptWhenCapped == nil then db.showInterruptWhenCapped = true end
    if db.classCategoryFilterEnabled == nil then db.classCategoryFilterEnabled = true end
    if db.showOutOfRangeInspectMessages == nil then db.showOutOfRangeInspectMessages = true end
    db.minTrackedCooldown = math.max(0, tonumber(db.minTrackedCooldown) or 0)
    db.maxTrackedCooldown = math.max(0, tonumber(db.maxTrackedCooldown) or 0)
    db.inspectRetryInterval = math.max(0.2, math.min(5, tonumber(db.inspectRetryInterval) or 1.0))
    db.inspectMaxRetryTime = math.max(5, math.min(120, tonumber(db.inspectMaxRetryTime) or 30.0))
    if db.highlightInterrupts == nil then db.highlightInterrupts = true end
    if db.showBorders == nil then db.showBorders = false end
    db.priorityBorderSize = math.max(1, math.min(6, tonumber(db.priorityBorderSize) or 1))
    db.priorityBorderInset = math.max(-2, math.min(4, tonumber(db.priorityBorderInset) or 0))
    db.priorityBorderPulseIntensity = math.max(0, math.min(1, tonumber(db.priorityBorderPulseIntensity) or 1))
    db.interruptBorderColor = db.interruptBorderColor or { r = 0.30, g = 0.65, b = 1.00, a = 1.00 }
    db.itemBorderColor = db.itemBorderColor or { r = 1.00, g = 0.82, b = 0.20, a = 1.00 }
    db.categoryBorderEnabled = db.categoryBorderEnabled or {}
    db.categoryBorderColors = db.categoryBorderColors or {}
    for category, color in pairs(CATEGORY_BORDER_DEFAULTS) do
        if db.categoryBorderEnabled[category] == nil then
            db.categoryBorderEnabled[category] = true
        end
        if type(db.categoryBorderColors[category]) ~= "table" then
            db.categoryBorderColors[category] = { r = color.r, g = color.g, b = color.b, a = color.a }
        end
    end
    db.defaultEnabledPresetVersion = tonumber(db.defaultEnabledPresetVersion) or 0
    RemapPvpTrinketCanonicalIDs(db)

    if baseCooldowns then
        for spellID in pairs(baseCooldowns) do
            if db.spellCategories[spellID] == nil then
                db.spellCategories[spellID] = GetDefaultCategoryForSpell(spellID)
            end
        end
    end

    if db.customSpells then
        for spellID in pairs(db.customSpells) do
            if db.spellCategories[spellID] == nil then
                db.spellCategories[spellID] = "GENERAL"
            end
        end
    end

    if db.defaultEnabledPresetVersion < 1 then
        ApplyDefaultEnabledPreset(db, baseCooldowns)
    end
end
