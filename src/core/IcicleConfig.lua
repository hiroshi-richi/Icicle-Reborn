IcicleConfig = IcicleConfig or {}

local max, min = math.max, math.min
local strlower, strupper = string.lower, string.upper

local CATEGORY_BORDER_DEFAULTS = {
    GENERAL = { r = 0.62, g = 0.62, b = 0.62, a = 1.00 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43, a = 1.00 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73, a = 1.00 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45, a = 1.00 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41, a = 1.00 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    DEATH_KNIGHT = { r = 0.77, g = 0.12, b = 0.23, a = 1.00 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87, a = 1.00 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94, a = 1.00 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79, a = 1.00 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04, a = 1.00 },
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

function IcicleConfig.EnsureProfileRoot(saved)
    if type(saved) ~= "table" then
        saved = {}
    end

    if not saved.profile then
        local legacy = saved
        saved = { profile = {}, profiles = {} }
        for k, v in pairs(legacy) do
            saved.profile[k] = v
        end
    end

    return saved
end

function IcicleConfig.ApplyLoginMigrations(db, baseCooldowns)
    if not db.autoLoweredFrameStrata then
        if db.frameStrata == "HIGH" or db.frameStrata == "DIALOG" then
            db.frameStrata = "LOW"
        end
        db.autoLoweredFrameStrata = true
    end

    db.spellCategories = db.spellCategories or {}
    db.disabledSpells = db.disabledSpells or {}
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    if db.textfont == "Interface\\AddOns\\Icicle\\FreeUniversal-Regular.ttf"
        or db.textfont == "Interface\\AddOns\\Icicle\\Hooge0655.ttf" then
        db.textfont = "Fonts\\FRIZQT__.TTF"
    end
    if db.persistSpecHints == nil then db.persistSpecHints = false end
    if db.specDetectEnabled == nil then db.specDetectEnabled = true end
    db.specHintTTL = math.max(30, math.min(3600, tonumber(db.specHintTTL) or 300))
    if db.party == nil then db.party = db.field ~= false end
    if db.raid == nil then db.raid = db.field ~= false end
    if db.showInterruptWhenCapped == nil then db.showInterruptWhenCapped = true end
    if db.classCategoryFilterEnabled == nil then db.classCategoryFilterEnabled = true end
    if db.showOutOfRangeInspectMessages == nil then db.showOutOfRangeInspectMessages = true end
    db.minTrackedCooldown = math.max(0, tonumber(db.minTrackedCooldown) or 0)
    db.maxTrackedCooldown = math.max(0, tonumber(db.maxTrackedCooldown) or 0)
    db.inspectRetryInterval = math.max(0.2, math.min(5, tonumber(db.inspectRetryInterval) or 1.0))
    db.inspectMaxRetryTime = math.max(5, math.min(120, tonumber(db.inspectMaxRetryTime) or 30.0))
    if db.defaultDatasetVersion == nil then db.defaultDatasetVersion = 1 end
    if db.highlightInterrupts == nil then db.highlightInterrupts = true end
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
    if db.matrixLogEnabled == nil then db.matrixLogEnabled = true end
    if db.matrixStrictSelfTests == nil then db.matrixStrictSelfTests = false end
    db.matrixLogMaxEntries = math.max(5, math.min(200, tonumber(db.matrixLogMaxEntries) or 30))
    db.profileSchemaVersion = tonumber(db.profileSchemaVersion) or 0
    db.defaultEnabledPresetVersion = tonumber(db.defaultEnabledPresetVersion) or 0

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

function IcicleConfig.SetConfigValue(db, key, value, validPoints, validGrow)
    key = strlower(key)
    if key == "anchor" then
        value = strupper(value)
        if not validPoints[value] then return false, "invalid anchor point" end
        db.anchorPoint = value
    elseif key == "anchorto" then
        value = strupper(value)
        if not validPoints[value] then return false, "invalid anchor target point" end
        db.anchorTo = value
    elseif key == "x" then
        db.xOffset = tonumber(value) or db.xOffset
    elseif key == "y" then
        db.yOffset = tonumber(value) or db.yOffset
    elseif key == "size" then
        db.iconSize = max(10, min(64, tonumber(value) or db.iconSize))
    elseif key == "font" then
        db.fontSize = max(6, min(30, tonumber(value) or db.fontSize))
    elseif key == "maxrow" then
        db.maxIconsPerRow = max(1, min(20, tonumber(value) or db.maxIconsPerRow))
    elseif key == "maxicons" then
        db.maxIcons = max(1, min(40, tonumber(value) or db.maxIcons))
    elseif key == "grow" then
        value = strupper(value)
        if not validGrow[value] then return false, "invalid growth direction" end
        db.growthDirection = value
    elseif key == "spacing" then
        db.iconSpacing = max(0, min(20, tonumber(value) or db.iconSpacing))
    elseif key == "scan" then
        db.scanInterval = max(0.1, min(0.5, tonumber(value) or db.scanInterval))
    else
        return false, "unknown key"
    end

    return true
end
