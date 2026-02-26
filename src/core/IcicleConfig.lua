IcicleConfig = IcicleConfig or {}

local CATEGORY_BORDER_DEFAULTS = (IcicleConstants and IcicleConstants.CATEGORY_BORDER_DEFAULTS) or {
    GENERAL = { r = 0.502, g = 0.502, b = 0.502, a = 1.00 },
}

local PERFORMANCE_MODE_DEFAULT = "BALANCED"
local PROFILE_VERSION_CURRENT = 2
local PROFILE_VERSION_KEY = "configVersion"

local PERFORMANCE_MODE_PRESETS = {
    BATTERY = {
        scanInterval = 0.30,
        iconUpdateInterval = 0.22,
        groupScanInterval = 0.90,
        inspectRetryInterval = 2.00,
        inspectMaxRetryTime = 20.0,
    },
    LOW_END = {
        scanInterval = 0.22,
        iconUpdateInterval = 0.16,
        groupScanInterval = 0.60,
        inspectRetryInterval = 1.50,
        inspectMaxRetryTime = 25.0,
    },
    BALANCED = {
        scanInterval = 0.15,
        iconUpdateInterval = 0.12,
        groupScanInterval = 0.35,
        inspectRetryInterval = 1.00,
        inspectMaxRetryTime = 30.0,
    },
    HIGH_END = {
        scanInterval = 0.11,
        iconUpdateInterval = 0.08,
        groupScanInterval = 0.22,
        inspectRetryInterval = 0.80,
        inspectMaxRetryTime = 35.0,
    },
    ARENA = {
        scanInterval = 0.08,
        iconUpdateInterval = 0.05,
        groupScanInterval = 0.12,
        inspectRetryInterval = 0.60,
        inspectMaxRetryTime = 45.0,
    },
}

local function NormalizePerformanceMode(mode)
    if type(mode) ~= "string" then
        return PERFORMANCE_MODE_DEFAULT
    end
    mode = string.upper(mode)
    if PERFORMANCE_MODE_PRESETS[mode] then
        return mode
    end
    return PERFORMANCE_MODE_DEFAULT
end

local PROFILE_MIGRATIONS = {
    [1] = function(db)
        if type(db.performanceMode) == "string" and string.upper(db.performanceMode) == "TOURNAMENT" then
            db.performanceMode = "ARENA"
        end
    end,
}

local function MigrateProfile(db)
    local version = tonumber(db[PROFILE_VERSION_KEY]) or 0
    if version < 0 then
        version = 0
    end
    if version >= PROFILE_VERSION_CURRENT then
        db[PROFILE_VERSION_KEY] = PROFILE_VERSION_CURRENT
        return
    end
    for nextVersion = version + 1, PROFILE_VERSION_CURRENT do
        local migrate = PROFILE_MIGRATIONS[nextVersion]
        if type(migrate) == "function" then
            migrate(db)
        end
    end
    db[PROFILE_VERSION_KEY] = PROFILE_VERSION_CURRENT
end

local function ApplyProfileSchema(db)
    db.spellCategories = db.spellCategories or {}
    db.disabledSpells = db.disabledSpells or {}
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}

    if db.persistSpecHints == nil then db.persistSpecHints = false end
    if db.specDetectEnabled == nil then db.specDetectEnabled = true end
    if db.showAmbiguousByName == nil then db.showAmbiguousByName = true end
    if db.debugMode == nil then db.debugMode = false end
    if db.showInterruptWhenCapped == nil then db.showInterruptWhenCapped = true end
    if db.classCategoryFilterEnabled == nil then db.classCategoryFilterEnabled = true end
    if db.showOutOfRangeInspectMessages == nil then db.showOutOfRangeInspectMessages = true end
    if db.highlightInterrupts == nil then db.highlightInterrupts = true end
    if db.showBorders == nil then db.showBorders = false end

    db.specHintTTL = math.max(30, math.min(3600, tonumber(db.specHintTTL) or 300))
    db.minTrackedCooldown = math.max(0, tonumber(db.minTrackedCooldown) or 0)
    db.maxTrackedCooldown = math.max(0, tonumber(db.maxTrackedCooldown) or 0)
    db.inspectRetryInterval = math.max(0.2, math.min(5, tonumber(db.inspectRetryInterval) or 1.0))
    db.inspectMaxRetryTime = math.max(5, math.min(120, tonumber(db.inspectMaxRetryTime) or 30.0))
    db.priorityBorderSize = math.max(1, math.min(6, tonumber(db.priorityBorderSize) or 1))
    db.priorityBorderInset = math.max(-2, math.min(4, tonumber(db.priorityBorderInset) or 0))

    if db.party == nil then db.party = db.field ~= false end
    if db.raid == nil then db.raid = db.field ~= false end
    if db.interruptHighlightMode ~= "BORDER" and db.interruptHighlightMode ~= "ICON" then
        db.interruptHighlightMode = "BORDER"
    end
    db.performanceMode = NormalizePerformanceMode(db.performanceMode)

    db.interruptBorderColor = db.interruptBorderColor or { r = 0.30, g = 0.65, b = 1.00, a = 1.00 }
    db.itemBorderColor = db.itemBorderColor or { r = 1.00, g = 0.82, b = 0.20, a = 1.00 }
    db.categoryBorderEnabled = db.categoryBorderEnabled or {}
    db.categoryBorderColors = db.categoryBorderColors or {}
end

function IcicleConfig.ApplyPerformanceMode(db, mode)
    if type(db) ~= "table" then
        return
    end
    local normalizedMode = NormalizePerformanceMode(mode or db.performanceMode)
    local preset = PERFORMANCE_MODE_PRESETS[normalizedMode] or PERFORMANCE_MODE_PRESETS[PERFORMANCE_MODE_DEFAULT]
    db.performanceMode = normalizedMode
    db.scanInterval = preset.scanInterval
    db.iconUpdateInterval = preset.iconUpdateInterval
    db.groupScanInterval = preset.groupScanInterval
    db.inspectRetryInterval = preset.inspectRetryInterval
    db.inspectMaxRetryTime = preset.inspectMaxRetryTime
end

function IcicleConfig.GetPerformanceModeOptions()
    return {
        BATTERY = "1. Battery Saver (Slowest)",
        LOW_END = "2. Low-End PC",
        BALANCED = "3. Balanced",
        HIGH_END = "4. High-End PC",
        ARENA = "5. Arena (Fastest)",
    }
end

function IcicleConfig.GetPerformanceModeOrder()
    return {
        "BATTERY",
        "LOW_END",
        "BALANCED",
        "HIGH_END",
        "ARENA",
    }
end

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
    MigrateProfile(db)
    ApplyProfileSchema(db)
    IcicleConfig.ApplyPerformanceMode(db, db.performanceMode)
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
