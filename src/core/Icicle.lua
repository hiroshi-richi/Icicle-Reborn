local ADDON_NAME = "Icicle"

local floor, ceil = math.floor, math.ceil
local max, min = math.max, math.min
local pow = math.pow
local tinsert, tremove = table.insert, table.remove
local strmatch = string.match
local strlower, strupper = string.lower, string.upper
local format = string.format

local addon = CreateFrame("Frame")
local db
local aceDB
local optionsBuilt = false
local profileCallbacks = {}
local GetSpellDescSafe

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBLib = LibStub("AceDB-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local function RequireTable(name, value)
    if type(value) ~= "table" then
        error("Icicle: Reborn: required module missing: " .. tostring(name))
    end
    return value
end

local function RequireFunction(moduleName, moduleTable, functionName)
    if type(moduleTable[functionName]) ~= "function" then
        error("Icicle: Reborn: required function missing: " .. tostring(moduleName) .. "." .. tostring(functionName))
    end
    return moduleTable[functionName]
end

local OptionsModule = RequireTable("IcicleOptions", IcicleOptions)
local ConstantsModule = RequireTable("IcicleConstants", IcicleConstants)
local TooltipModule = RequireTable("IcicleTooltip", IcicleTooltip)
local CombatModule = RequireTable("IcicleCombat", IcicleCombat)
local TrackingModule = RequireTable("IcicleTracking", IcicleTracking)
local NameplatesModule = RequireTable("IcicleNameplates", IcicleNameplates)
local ResolverModule = RequireTable("IcicleResolver", IcicleResolver)
local RenderModule = RequireTable("IcicleRender", IcicleRender)
local ConfigModule = RequireTable("IcicleConfig", IcicleConfig)
local CooldownRulesModule = RequireTable("IcicleCooldownRules", IcicleCooldownRules)
local TestModeModule = RequireTable("IcicleTestMode", IcicleTestMode)
local SpellsModule = RequireTable("IcicleSpells", IcicleSpells)
local SpecModule = RequireTable("IcicleSpec", IcicleSpec)
local StateModule = RequireTable("IcicleState", IcicleState)
local EventsModule = RequireTable("IcicleEvents", IcicleEvents)
local UIOptionsModule = RequireTable("IcicleUIOptions", IcicleUIOptions)
local BootstrapModule = RequireTable("IcicleBootstrap", IcicleBootstrap)
local DataModule = RequireTable("IcicleData", IcicleData)

RequireFunction("IcicleOptions", OptionsModule, "RegisterPanels")
RequireFunction("IcicleTooltip", TooltipModule, "GetSpellOrItemInfo")
RequireFunction("IcicleTooltip", TooltipModule, "BuildSpellTooltipText")
RequireFunction("IcicleTooltip", TooltipModule, "BuildSpellPanelDesc")
RequireFunction("IcicleTooltip", TooltipModule, "GetSpellDescSafe")
RequireFunction("IcicleTooltip", TooltipModule, "PreloadEnabledItemDisplayInfo")
RequireFunction("IcicleTracking", TrackingModule, "StartCooldown")
RequireFunction("IcicleNameplates", NameplatesModule, "FindBars")
RequireFunction("IcicleNameplates", NameplatesModule, "FindFontStringNameRegion")
RequireFunction("IcicleNameplates", NameplatesModule, "ScanNameplates")
RequireFunction("IcicleResolver", ResolverModule, "RemovePlateBinding")
RequireFunction("IcicleResolver", ResolverModule, "DecayAndPurgeMappings")
RequireFunction("IcicleResolver", ResolverModule, "MigrateNameCooldownsToGUID")
RequireFunction("IcicleResolver", ResolverModule, "TryBindByName")
RequireFunction("IcicleResolver", ResolverModule, "RegisterPendingBind")
RequireFunction("IcicleResolver", ResolverModule, "TryResolvePendingBinds")
RequireFunction("IcicleResolver", ResolverModule, "ResolveUnit")
RequireFunction("IcicleResolver", ResolverModule, "ResolveGroupTargets")
RequireFunction("IcicleRender", RenderModule, "RefreshAllVisiblePlates")
RequireFunction("IcicleRender", RenderModule, "OnUpdate")
RequireFunction("IcicleConfig", ConfigModule, "CopyDefaults")
RequireFunction("IcicleConfig", ConfigModule, "NormalizeProfile")
RequireFunction("IcicleCooldownRules", CooldownRulesModule, "GetSpellConfig")
RequireFunction("IcicleTestMode", TestModeModule, "PopulateRandomPlateTests")
RequireFunction("IcicleTestMode", TestModeModule, "RandomizeTestMode")
RequireFunction("IcicleTestMode", TestModeModule, "StopTestMode")
RequireFunction("IcicleTestMode", TestModeModule, "StartTestMode")
RequireFunction("IcicleTestMode", TestModeModule, "ToggleTestMode")
RequireFunction("IcicleSpells", SpellsModule, "BuildSpellRowsData")
RequireFunction("IcicleSpec", SpecModule, "PruneExpiredHints")
RequireFunction("IcicleSpec", SpecModule, "UpdateFromInspectTalents")
RequireFunction("IcicleState", StateModule, "BuildInitialState")
RequireFunction("IcicleEvents", EventsModule, "HandleEvent")
RequireFunction("IcicleUIOptions", UIOptionsModule, "BuildOptionsPanel")
RequireFunction("IcicleBootstrap", BootstrapModule, "BuildInternalAPI")

local GetSpellOrItemInfo = TooltipModule.GetSpellOrItemInfo
local BuildSpellTooltipText = TooltipModule.BuildSpellTooltipText
local BuildSpellPanelDesc = TooltipModule.BuildSpellPanelDesc
GetSpellDescSafe = TooltipModule.GetSpellDescSafe
local PreloadEnabledItemDisplayInfo = TooltipModule.PreloadEnabledItemDisplayInfo

if type(DataModule.SPELL_CATEGORY_ORDER) ~= "table" then
    error("Icicle: Reborn: IcicleData.SPELL_CATEGORY_ORDER is required")
end
if type(DataModule.SPELL_CATEGORY_LABELS) ~= "table" then
    error("Icicle: Reborn: IcicleData.SPELL_CATEGORY_LABELS is required")
end
if type(DataModule.DEFAULT_SPELLS_BY_CATEGORY) ~= "table" then
    error("Icicle: Reborn: IcicleData.DEFAULT_SPELLS_BY_CATEGORY is required")
end
if type(DataModule.DEFAULT_ITEM_IDS) ~= "table" then
    error("Icicle: Reborn: IcicleData.DEFAULT_ITEM_IDS is required")
end

if type(DataModule.DEFAULT_SPELL_DATA) ~= "table" then
    error("Icicle: Reborn: IcicleData.DEFAULT_SPELL_DATA is required")
end
if type(DataModule.BASE_COOLDOWNS) ~= "table" then
    error("Icicle: Reborn: IcicleData.BASE_COOLDOWNS is required")
end
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A[" .. ADDON_NAME .. "]|r: " .. tostring(msg))
end

local function ShortName(name)
    if not name then return nil end
    return strmatch(name, "([^%-]+)") or name
end

local function CopyDefaults(target, defaults)
    return ConfigModule.CopyDefaults(target, defaults)
end

local function WipeTable(tbl)
    for k in pairs(tbl) do tbl[k] = nil end
end

local STATE = StateModule.BuildInitialState()

local VALID_POINTS = ConstantsModule.VALID_POINTS
local VALID_GROW = ConstantsModule.VALID_GROW
local POINT_VALUES = ConstantsModule.POINT_VALUES
local GROW_VALUES = ConstantsModule.GROW_VALUES

local SPELL_CATEGORY_ORDER = DataModule.SPELL_CATEGORY_ORDER
local SPELL_CATEGORY_LABELS = DataModule.SPELL_CATEGORY_LABELS
local DEFAULT_SPELLS_BY_CATEGORY = DataModule.DEFAULT_SPELLS_BY_CATEGORY
local DEFAULT_SPELL_DATA = DataModule.DEFAULT_SPELL_DATA
local DEFAULT_ITEM_IDS = DataModule.DEFAULT_ITEM_IDS
local DEFAULT_ENABLED_SPELL_IDS = DataModule.DEFAULT_ENABLED_SPELL_IDS or {}
local BASE_COOLDOWNS = DataModule.BASE_COOLDOWNS or {}

local function NormalizeCategory(category)
    category = strupper(category or "GENERAL")
    if not SPELL_CATEGORY_LABELS[category] then
        return "GENERAL"
    end
    return category
end

local function SpellCategory(spellID)
    if db and db.spellCategories and db.spellCategories[spellID] then
        return NormalizeCategory(db.spellCategories[spellID])
    end
    local base = DEFAULT_SPELL_DATA[spellID]
    if base and base.category then
        return NormalizeCategory(base.category)
    end
    return "GENERAL"
end

local function EnsureDefaultSpellProfile(profile)
    if not profile then return end
    profile.customSpells = profile.customSpells or {}
    profile.spellOverrides = profile.spellOverrides or {}
    profile.removedBaseSpells = profile.removedBaseSpells or {}
    profile.disabledSpells = profile.disabledSpells or {}
    profile.spellCategories = profile.spellCategories or {}
    for spellID, data in pairs(DEFAULT_SPELL_DATA or {}) do
        if not profile.spellCategories[spellID] then
            profile.spellCategories[spellID] = NormalizeCategory(data.category)
        end
    end
end

local function IsItemSpell(spellID)
    if DEFAULT_ITEM_IDS[spellID] then
        return true
    end
    return db and db.customSpells and db.customSpells[spellID] and db.customSpells[spellID].isItem
end

local SPELL_IDS_BY_NAME = nil
local CLASS_TO_CATEGORY = {
    WARRIOR = "WARRIOR",
    PALADIN = "PALADIN",
    HUNTER = "HUNTER",
    ROGUE = "ROGUE",
    PRIEST = "PRIEST",
    DEATHKNIGHT = "DEATH_KNIGHT",
    DEATH_KNIGHT = "DEATH_KNIGHT",
    SHAMAN = "SHAMAN",
    MAGE = "MAGE",
    WARLOCK = "WARLOCK",
    DRUID = "DRUID",
}
local SPEC_TO_CATEGORY = {
    balance = "DRUID",
    feral = "DRUID",
    restoDruid = "DRUID",
    bm = "HUNTER",
    mm = "HUNTER",
    survival = "HUNTER",
    arcane = "MAGE",
    fire = "MAGE",
    frost = "MAGE",
    holy = "PALADIN",
    protPala = "PALADIN",
    retri = "PALADIN",
    disc = "PRIEST",
    holyPriest = "PRIEST",
    shadow = "PRIEST",
    assa = "ROGUE",
    combat = "ROGUE",
    sub = "ROGUE",
    ele = "SHAMAN",
    enhancement = "SHAMAN",
    restoSham = "SHAMAN",
    affli = "WARLOCK",
    demo = "WARLOCK",
    destro = "WARLOCK",
    arms = "WARRIOR",
    fury = "WARRIOR",
    protWar = "WARRIOR",
    blood = "DEATH_KNIGHT",
    frostDk = "DEATH_KNIGHT",
    unholy = "DEATH_KNIGHT",
}
local COOLDOWN_RULES_CONTEXT

local function ClassTokenToCategory(classToken)
    if not classToken then
        return nil
    end
    return CLASS_TO_CATEGORY[strupper(classToken)]
end

local function GetSourceClassCategory(sourceGUID, sourceName)
    local category = nil
    if sourceGUID and STATE.classByGUID then
        category = STATE.classByGUID[sourceGUID]
    end
    if (not category) and sourceName and STATE.classByName then
        category = STATE.classByName[sourceName]
    end
    if category then
        return NormalizeCategory(category)
    end

    if COOLDOWN_RULES_CONTEXT and COOLDOWN_RULES_CONTEXT.GetUnitSpec then
        local spec = COOLDOWN_RULES_CONTEXT.GetUnitSpec(sourceGUID, sourceName)
        if spec and SPEC_TO_CATEGORY[spec] then
            return SPEC_TO_CATEGORY[spec]
        end
    end
    return nil
end

local function NormalizeRankText(rankText)
    if not rankText then
        return nil
    end
    local text = strlower(tostring(rankText)):gsub("%s+", "")
    if text == "" then
        return nil
    end
    return text
end

local function BuildSpellNameIndex()
    SPELL_IDS_BY_NAME = {}
    local function addSpellID(spellID)
        local spellName, spellRank = GetSpellInfo(spellID)
        if not spellName or spellName == "" then
            return
        end
        SPELL_IDS_BY_NAME[spellName] = SPELL_IDS_BY_NAME[spellName] or {}
        local list = SPELL_IDS_BY_NAME[spellName]
        for i = 1, #list do
            if list[i].id == spellID then
                return
            end
        end
        tinsert(list, {
            id = spellID,
            rank = NormalizeRankText(spellRank),
            category = SpellCategory(spellID),
        })
    end

    if BASE_COOLDOWNS then
        for spellID in pairs(BASE_COOLDOWNS) do
            addSpellID(spellID)
        end
    end
    if DEFAULT_SPELL_DATA then
        for spellID in pairs(DEFAULT_SPELL_DATA) do
            addSpellID(spellID)
        end
    end
    if db and db.customSpells then
        for spellID in pairs(db.customSpells) do
            addSpellID(spellID)
        end
    end
    if db and db.spellOverrides then
        for spellID in pairs(db.spellOverrides) do
            addSpellID(spellID)
        end
    end
end

local function ResolveSpellIDByName(spellName, spellRank, classToken)
    if not spellName or spellName == "" then
        return nil
    end
    if not SPELL_IDS_BY_NAME then
        BuildSpellNameIndex()
    end
    local list = SPELL_IDS_BY_NAME and SPELL_IDS_BY_NAME[spellName]
    if not list or #list == 0 then
        return nil
    end
    local rankNorm = NormalizeRankText(spellRank)
    if spellName == "Death Coil" and rankNorm and rankNorm ~= "rank6" then
        return nil
    end
    if #list == 1 then
        return list[1].id
    end

    local candidates = list
    if rankNorm then
        local ranked = {}
        for i = 1, #candidates do
            if candidates[i].rank == rankNorm then
                tinsert(ranked, candidates[i])
            end
        end
        if #ranked > 0 then
            candidates = ranked
        end
    end

    local preferredCategory = CLASS_TO_CATEGORY[classToken]
    if preferredCategory then
        local classMatches = {}
        for i = 1, #candidates do
            local cat = NormalizeCategory(candidates[i].category)
            if cat == preferredCategory then
                tinsert(classMatches, candidates[i])
            end
        end
        if #classMatches > 0 then
            candidates = classMatches
        end
    end

    if #candidates == 1 then
        return candidates[1].id
    end

    local best = candidates[1]
    for i = 2, #candidates do
        if candidates[i].id > best.id then
            best = candidates[i]
        end
    end
    return best and best.id or nil
end

local function IsEnabledInCurrentZone()
    if not db then return false end
    local _, zoneType = IsInInstance()

    if db.all then return true end
    if zoneType == "arena" then return db.arena end
    if zoneType == "pvp" then return db.battleground end
    if zoneType == "party" then return db.party end
    if zoneType == "raid" then return db.raid end
    return db.field
end

COOLDOWN_RULES_CONTEXT = {
    db = nil,
    baseCooldowns = BASE_COOLDOWNS,
    defaultSpellData = DEFAULT_SPELL_DATA,
    STATE = STATE,
    IsItemSpell = IsItemSpell,
    GetUnitSpec = function(sourceGUID, sourceName)
        local entry
        if sourceGUID and STATE.specByGUID[sourceGUID] then
            entry = STATE.specByGUID[sourceGUID]
            if type(entry) == "table" then
                return entry.spec
            end
            return entry
        end
        if sourceName and STATE.specByName[sourceName] then
            entry = STATE.specByName[sourceName]
            if type(entry) == "table" then
                return entry.spec
            end
            return entry
        end
        return nil
    end,
}

local function SyncCooldownRulesContext()
    COOLDOWN_RULES_CONTEXT.db = db
    COOLDOWN_RULES_CONTEXT.baseCooldowns = BASE_COOLDOWNS
end

local function GetSpellConfig(spellID, sourceGUID, sourceName)
    SyncCooldownRulesContext()
    return CooldownRulesModule.GetSpellConfig(COOLDOWN_RULES_CONTEXT, spellID, sourceGUID, sourceName)
end

local function EventMatchesTrigger(eventType, trigger)
    if trigger == "SUCCESS" then
        return eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_MISSED"
    elseif trigger == "AURA_APPLIED" then
        return eventType == "SPELL_AURA_APPLIED"
    elseif trigger == "START" then
        return eventType == "SPELL_CAST_START"
    elseif trigger == "ANY" then
        return eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_CAST_START" or eventType == "SPELL_MISSED"
    end
    return eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_MISSED"
end

local function EnsureContainer(meta)
    if meta.container and meta.container:IsObjectType("Frame") then return meta.container end

    local parent = meta.healthBar or meta.plate
    local container = CreateFrame("Frame", nil, parent)
    container:SetFrameStrata(db.frameStrata)
    container:SetFrameLevel((parent:GetFrameLevel() or meta.plate:GetFrameLevel() or 1) + 1)
    container:EnableMouse(false)
    container:SetWidth(1)
    container:SetHeight(1)

    meta.container = container
    meta.plate.IcicleContainer = container
    return container
end

local function GetIconTextColor(remain)
    if remain <= 3 then return 1, 0, 0 end
    if remain <= 10 then return 1, 0.7, 0 end
    return 0.7, 1, 0
end

local function FormatRemaining(remain)
    if remain >= 60 then return ceil(remain / 60) .. "m" end
    if remain > 0 then return tostring(ceil(remain)) end
    return ""
end

local function CreateIcon(container)
    local function SafeSetFont(fontString, fontPath, size, flags)
        if fontString:SetFont(fontPath, size, flags) then
            return
        end
        fontString:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
    end

    local icon = CreateFrame("Button", nil, container)
    icon:SetFrameStrata(container:GetFrameStrata())
    icon:SetFrameLevel(container:GetFrameLevel() + 1)

    icon.texture = icon:CreateTexture(nil, "BORDER")
    icon.texture:SetAllPoints(icon)

    icon.borderFrame = CreateFrame("Frame", nil, icon)
    icon.borderFrame:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon.borderFrame:SetFrameLevel(icon:GetFrameLevel() + 2)
    icon.borderSkin = icon.borderFrame:CreateTexture(nil, "OVERLAY")
    icon.borderSkin:SetAllPoints(icon.borderFrame)
    icon.borderSkin:SetTexture("Interface\\AddOns\\Icicle\\media\\DefaultBorder.blp")
    icon.borderSkin:SetBlendMode("ADD")
    icon.borderFrame:Hide()

    icon.cooldown = icon:CreateFontString(nil, "OVERLAY")
    icon.cooldown:SetAllPoints(icon)
    icon.cooldown:SetJustifyH("CENTER")
    icon.cooldown:SetJustifyV("MIDDLE")
    SafeSetFont(icon.cooldown, db.textfont, db.fontSize, "OUTLINE")

    icon.ambiguousMark = icon:CreateFontString(nil, "OVERLAY")
    icon.ambiguousMark:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
    SafeSetFont(icon.ambiguousMark, db.textfont, max(8, db.fontSize - 2), "OUTLINE")
    icon.ambiguousMark:SetText("?")
    icon.ambiguousMark:Hide()

    icon:SetScript("OnEnter", function(self)
        if not db.showTooltips or not self.record then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local spellID = self.record.spellID
        local spellName = self.record.spellName or ("Spell " .. tostring(spellID))
        local iconTex = self.record.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        local remain = max(0, self.record.expiresAt - GetTime())
        local isItem = IsItemSpell(spellID)
        local header, body = BuildSpellTooltipText(spellID, spellName, iconTex, remain, isItem)

        GameTooltip:ClearLines()
        GameTooltip:AddLine(header)
        GameTooltip:AddLine(body, 1, 1, 1, true)
        GameTooltip:Show()
    end)

    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return icon
end

local function ApplyIconBorderLayout(icon)
    if not icon or not icon.borderFrame then
        return
    end
    local borderSize = max(1, min(6, tonumber(db.priorityBorderSize) or 1))
    local inset = max(-2, min(4, tonumber(db.priorityBorderInset) or 0))
    local baseRatio = 42 / 36
    local scale = baseRatio + ((borderSize - 2) * 0.09) - (inset * 0.05)
    if scale < 0.85 then scale = 0.85 end
    local w = max(1, icon:GetWidth() * scale)
    local h = max(1, icon:GetHeight() * scale)
    icon.borderFrame:SetSize(w, h)
end

local function AcquireIcon(meta)
    if #meta.iconPool > 0 then
        local icon = tremove(meta.iconPool)
        ApplyIconBorderLayout(icon)
        return icon
    end
    local icon = CreateIcon(meta.container)
    ApplyIconBorderLayout(icon)
    return icon
end

local function ReleaseIcons(meta)
    for i = #meta.activeIcons, 1, -1 do
        local icon = meta.activeIcons[i]
        icon:Hide()
        icon.record = nil
        icon.isOverflow = nil
        icon.ambiguousMark:Hide()
        if icon.border then icon.border:Hide() end
        if icon.borderFrame then icon.borderFrame:Hide() end
        tinsert(meta.iconPool, icon)
        tremove(meta.activeIcons, i)
    end
end

local function ApplyContainerAnchor(meta)
    local container = EnsureContainer(meta)
    local parent = meta.healthBar or meta.plate
    container:SetFrameStrata(db.frameStrata)
    container:SetFrameLevel((parent:GetFrameLevel() or meta.plate:GetFrameLevel() or 1) + 1)
    container:ClearAllPoints()
    container:SetPoint(db.anchorPoint, parent, db.anchorTo, db.xOffset, db.yOffset)
end
local function LayoutIcons(meta)
    local function SafeSetFont(fontString, fontPath, size, flags)
        if fontString:SetFont(fontPath, size, flags) then
            return
        end
        fontString:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
    end

    local size = db.iconSize
    local spacing = db.iconSpacing
    local maxPerRow = max(1, db.maxIconsPerRow)

    for i = 1, #meta.activeIcons do
        local icon = meta.activeIcons[i]
        local row = floor((i - 1) / maxPerRow)
        local col = (i - 1) % maxPerRow
        local x, y = 0, 0

        if db.growthDirection == "RIGHT" then
            x, y = col * (size + spacing), -row * (size + spacing)
        elseif db.growthDirection == "LEFT" then
            x, y = -col * (size + spacing), -row * (size + spacing)
        elseif db.growthDirection == "UP" then
            x, y = col * (size + spacing), row * (size + spacing)
        else
            x, y = col * (size + spacing), -row * (size + spacing)
        end

        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", meta.container, "TOPLEFT", x, y)
        icon:SetWidth(size)
        icon:SetHeight(size)
        SafeSetFont(icon.cooldown, db.textfont, db.fontSize, "OUTLINE")
        SafeSetFont(icon.ambiguousMark, db.textfont, max(8, db.fontSize - 2), "OUTLINE")
        ApplyIconBorderLayout(icon)
    end
end

local function PruneExpiredStore(tbl, now)
    local changed = false
    for k, spellMap in pairs(tbl) do
        for spellID, rec in pairs(spellMap) do
            if rec.expiresAt <= now then
                spellMap[spellID] = nil
                changed = true
            end
        end
        if next(spellMap) == nil then
            tbl[k] = nil
        end
    end
    return changed
end

local function DecayedConfidence(entry, now)
    local dt = now - (entry.lastSeen or now)
    return (entry.conf or 0) * pow(0.5, dt / max(1, db.confHalfLife))
end

local RESOLVER_CONTEXT = {
    STATE = STATE,
    db = nil,
    DecayedConfidence = DecayedConfidence,
    ShortName = ShortName,
    ClassTokenToCategory = ClassTokenToCategory,
}

local function SyncResolverContext()
    RESOLVER_CONTEXT.db = db
end

local function RemovePlateBinding(plate)
    SyncResolverContext()
    return ResolverModule.RemovePlateBinding(RESOLVER_CONTEXT, plate)
end

local function DecayAndPurgeMappings()
    SyncResolverContext()
    return ResolverModule.DecayAndPurgeMappings(RESOLVER_CONTEXT)
end

local function MigrateNameCooldownsToGUID(name, guid)
    SyncResolverContext()
    return ResolverModule.MigrateNameCooldownsToGUID(RESOLVER_CONTEXT, name, guid)
end

local function TryBindByName(guid, name, baseConf, reason, spellName, eventTime)
    SyncResolverContext()
    return ResolverModule.TryBindByName(RESOLVER_CONTEXT, guid, name, baseConf, reason, spellName, eventTime)
end

local function RegisterPendingBind(guid, name, spellName, eventTime)
    SyncResolverContext()
    return ResolverModule.RegisterPendingBind(RESOLVER_CONTEXT, guid, name, spellName, eventTime)
end

local function TryResolvePendingBinds()
    SyncResolverContext()
    return ResolverModule.TryResolvePendingBinds(RESOLVER_CONTEXT)
end

local RENDER_CONTEXT = {
    STATE = STATE,
    db = nil,
    DecayedConfidence = DecayedConfidence,
    ApplyContainerAnchor = ApplyContainerAnchor,
    ReleaseIcons = ReleaseIcons,
    AcquireIcon = AcquireIcon,
    GetIconTextColor = GetIconTextColor,
    FormatRemaining = FormatRemaining,
    LayoutIcons = LayoutIcons,
    PruneExpiredStore = PruneExpiredStore,
    ScanNameplates = nil,
    ResolveGroupTargets = nil,
    PopulateRandomPlateTests = nil,
    SpellCategory = SpellCategory,
}

local function SyncRenderContext()
    RENDER_CONTEXT.db = db
end

local function RefreshAllVisiblePlates()
    SyncRenderContext()
    return RenderModule.RefreshAllVisiblePlates(RENDER_CONTEXT)
end

local function OnPlateHide(self)
    local meta = STATE.plateMeta[self]
    if not meta then return end
    RemovePlateBinding(self)
    if meta.container then meta.container:Hide() end
    ReleaseIcons(meta)
end

local function RegisterPlate(frame)
    if STATE.knownPlates[frame] then return end

    local healthBar, castBar = NameplatesModule.FindBars(frame)
    local meta = {
        plate = frame,
        healthBar = healthBar,
        castBar = castBar,
        nameText = NameplatesModule.FindFontStringNameRegion(frame),
        name = nil,
        lastCastSpell = nil,
        lastCastAt = 0,
        iconPool = {},
        activeIcons = {},
    }

    STATE.knownPlates[frame] = true
    STATE.plateMeta[frame] = meta

    EnsureContainer(meta)
    ApplyContainerAnchor(meta)

    if not frame.IcicleHooked then
        frame:HookScript("OnHide", OnPlateHide)
        frame.IcicleHooked = true
    end
end

local NAMEPLATES_CONTEXT = {
    STATE = STATE,
    db = nil,
    RegisterPlate = RegisterPlate,
    WipeTable = WipeTable,
    RemovePlateBinding = RemovePlateBinding,
    DecayAndPurgeMappings = DecayAndPurgeMappings,
    TryResolvePendingBinds = TryResolvePendingBinds,
    ShortName = ShortName,
    GetTime = GetTime,
    WorldFrame = WorldFrame,
}

local function ScanNameplates()
    NAMEPLATES_CONTEXT.db = db
    NameplatesModule.ScanNameplates(NAMEPLATES_CONTEXT)
end

local function ResolveUnit(unit, confidence, reason)
    SyncResolverContext()
    return ResolverModule.ResolveUnit(RESOLVER_CONTEXT, unit, confidence, reason)
end

local function ResolveGroupTargets()
    SyncResolverContext()
    return ResolverModule.ResolveGroupTargets(RESOLVER_CONTEXT)
end

local TRACKING_CONTEXT = {
    STATE = STATE,
    db = nil,
    spellDedupeWindow = ConstantsModule.SPELL_DEDUPE_WINDOW,
    GetCooldownRule = GetSpellConfig,
    GetSharedCooldownTargets = function(spellID)
        SyncCooldownRulesContext()
        if CooldownRulesModule.GetSharedTargetsForSpell then
            return CooldownRulesModule.GetSharedTargetsForSpell(COOLDOWN_RULES_CONTEXT, spellID)
        end
    end,
    GetSpellConfig = GetSpellConfig,
    EventMatchesTrigger = EventMatchesTrigger,
    TryBindByName = TryBindByName,
    RegisterPendingBind = RegisterPendingBind,
    MigrateNameCooldownsToGUID = MigrateNameCooldownsToGUID,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    IsItemSpell = IsItemSpell,
    GetSpellOrItemInfo = GetSpellOrItemInfo,
    SpellCategory = SpellCategory,
    GetSourceClassCategory = GetSourceClassCategory,
}

local function StartCooldown(sourceGUID, sourceName, spellID, spellName, eventType)
    TRACKING_CONTEXT.db = db
    TrackingModule.StartCooldown(TRACKING_CONTEXT, sourceGUID, sourceName, spellID, spellName, eventType)
end
local function ResetAllCooldowns(silent)
    WipeTable(STATE.cooldownsByGUID)
    WipeTable(STATE.cooldownsByName)
    WipeTable(STATE.recentEventByUnit)
    RefreshAllVisiblePlates()
    if not silent then
        Print("all cooldown timers reset")
    end
end

local function NormalizeTrigger(trigger)
    if not trigger then return "SUCCESS" end
    trigger = strupper(trigger)
    if trigger == "SUCCESS" or trigger == "AURA_APPLIED" or trigger == "START" or trigger == "ANY" then
        return trigger
    end
    return "SUCCESS"
end

local SPEC_CONTEXT = {
    STATE = STATE,
    db = nil,
}

local function SyncSpecContext()
    SPEC_CONTEXT.db = db
end

local function SyncSpecHintsFromDB()
    WipeTable(STATE.specByGUID)
    WipeTable(STATE.specByName)
    if not db or not db.persistSpecHints then
        return
    end
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    for k, v in pairs(db.specHintsByGUID) do
        if type(v) == "table" then
            STATE.specByGUID[k] = {
                spec = v.spec,
                confidence = tonumber(v.confidence) or 0.9,
                lastSeen = tonumber(v.lastSeen) or GetTime(),
                source = v.source or "saved",
            }
        end
    end
    for k, v in pairs(db.specHintsByName) do
        if type(v) == "table" then
            STATE.specByName[k] = {
                spec = v.spec,
                confidence = tonumber(v.confidence) or 0.9,
                lastSeen = tonumber(v.lastSeen) or GetTime(),
                source = v.source or "saved",
            }
        end
    end
end

local ToggleTestMode
local BuildOptionsPanel
local NotifySpellsChanged
local GetBaseSpellEntry
local ProcessInspectQueue
local PrimeEnabledItemDisplayInfo
local TESTMODE_CONTEXT = {
    STATE = STATE,
    baseCooldowns = BASE_COOLDOWNS,
    WipeTable = WipeTable,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    Print = Print,
    IsItemSpell = IsItemSpell,
    GetSpellOrItemInfo = GetSpellOrItemInfo,
    GetSharedCooldownTargets = function(spellID)
        SyncCooldownRulesContext()
        if CooldownRulesModule.GetSharedTargetsForSpell then
            return CooldownRulesModule.GetSharedTargetsForSpell(COOLDOWN_RULES_CONTEXT, spellID)
        end
        return nil
    end,
    GetCooldownRule = function(spellID, sourceGUID, sourceName)
        return GetSpellConfig(spellID, sourceGUID, sourceName)
    end,
}

local function PopulateRandomPlateTests()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    TESTMODE_CONTEXT.db = db
    TESTMODE_CONTEXT.BuildSpellRowsData = BuildSpellRowsData
    return TestModeModule.PopulateRandomPlateTests(TESTMODE_CONTEXT)
end

local function RandomizeTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    TESTMODE_CONTEXT.db = db
    TESTMODE_CONTEXT.BuildSpellRowsData = BuildSpellRowsData
    return TestModeModule.RandomizeTestMode(TESTMODE_CONTEXT)
end

local function StopTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    TESTMODE_CONTEXT.db = db
    TESTMODE_CONTEXT.BuildSpellRowsData = BuildSpellRowsData
    return TestModeModule.StopTestMode(TESTMODE_CONTEXT)
end

local function StartTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    TESTMODE_CONTEXT.db = db
    TESTMODE_CONTEXT.BuildSpellRowsData = BuildSpellRowsData
    PrimeEnabledItemDisplayInfo()
    return TestModeModule.StartTestMode(TESTMODE_CONTEXT)
end

ToggleTestMode = function()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    TESTMODE_CONTEXT.db = db
    TESTMODE_CONTEXT.BuildSpellRowsData = BuildSpellRowsData
    PrimeEnabledItemDisplayInfo()
    return TestModeModule.ToggleTestMode(TESTMODE_CONTEXT)
end

local SPELLS_CONTEXT = {
    db = nil,
    baseCooldowns = BASE_COOLDOWNS,
    DEFAULT_SPELLS_BY_CATEGORY = DEFAULT_SPELLS_BY_CATEGORY,
    DEFAULT_SPELL_DATA = DEFAULT_SPELL_DATA,
    DEFAULT_ITEM_IDS = DEFAULT_ITEM_IDS,
    GetBaseSpellEntry = function(spellID) return GetBaseSpellEntry(spellID) end,
    GetSpellOrItemInfo = GetSpellOrItemInfo,
    GetSpellDescSafe = GetSpellDescSafe,
    NormalizeTrigger = NormalizeTrigger,
    SpellCategory = SpellCategory,
    IsItemSpell = IsItemSpell,
}

local function BuildSpellRowsData()
    SPELLS_CONTEXT.db = db
    SPELLS_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    return SpellsModule.BuildSpellRowsData(SPELLS_CONTEXT)
end

PrimeEnabledItemDisplayInfo = function()
    if not db then
        return
    end
    PreloadEnabledItemDisplayInfo(db, DEFAULT_ITEM_IDS, IsItemSpell)
end

NotifySpellsChanged = function()
    SPELL_IDS_BY_NAME = nil
    PrimeEnabledItemDisplayInfo()
    if STATE.rebuildSpellArgs then
        STATE.rebuildSpellArgs()
    end
    if AceConfigRegistry then
        AceConfigRegistry:NotifyChange("IcicleSpells")
    end
end

local INTERNAL_API

local function RebuildInternalAPI()
    INTERNAL_API = BootstrapModule.BuildInternalAPI({
        STATE = STATE,
        GetDB = function() return db end,
        StartCooldown = StartCooldown,
        ResetAllCooldowns = ResetAllCooldowns,
        RefreshAllVisiblePlates = RefreshAllVisiblePlates,
        ResolveUnit = ResolveUnit,
        ResolveGroupTargets = ResolveGroupTargets,
        ScanNameplates = ScanNameplates,
        GetCooldownRule = GetSpellConfig,
        GetSpellConfig = GetSpellConfig,
        BuildSpellRowsData = BuildSpellRowsData,
        NotifySpellsChanged = NotifySpellsChanged,
    })
    STATE.api = INTERNAL_API
    _G.IcicleInternalAPI = INTERNAL_API
end

GetBaseSpellEntry = function(spellID)
    local base = DEFAULT_SPELL_DATA and DEFAULT_SPELL_DATA[spellID]
    if not base then return nil end
    return { cd = base.cd, trigger = "SUCCESS" }
end

local function BuildSpellRowName(row)
    local name = row.name or ("Spell " .. tostring(row.id))
    local tex = row.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local iconTag = "|T" .. tex .. ":14:14:0:0|t"
    return format("%s %s", iconTag, name)
end

local function BuildSpellTooltipBody(row)
    local spellName = row.name or ("Spell " .. tostring(row.id))
    local iconTex = row.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local _, body = BuildSpellTooltipText(row.id, spellName, iconTex, row.cd or 0, row.isItem)
    return body
end

local function ProfilesChanged()
    db = aceDB.profile
    SPELL_IDS_BY_NAME = nil
    ConfigModule.NormalizeProfile(db, BASE_COOLDOWNS)
    EnsureDefaultSpellProfile(db)
    PrimeEnabledItemDisplayInfo()
    SyncSpecHintsFromDB()
    RebuildInternalAPI()
    RefreshAllVisiblePlates()
    NotifySpellsChanged()
end

BuildOptionsPanel = function()
    return UIOptionsModule.BuildOptionsPanel({
        STATE = STATE,
        AceConfig = AceConfig,
        AceConfigDialog = AceConfigDialog,
        AceDBOptions = AceDBOptions,
        OptionsModule = OptionsModule,
        POINT_VALUES = POINT_VALUES,
        GROW_VALUES = GROW_VALUES,
        SPELL_CATEGORY_ORDER = SPELL_CATEGORY_ORDER,
        SPELL_CATEGORY_LABELS = SPELL_CATEGORY_LABELS,
        DEFAULT_SPELLS_BY_CATEGORY = DEFAULT_SPELLS_BY_CATEGORY,
        DEFAULT_SPELL_DATA = DEFAULT_SPELL_DATA,
        DEFAULT_ENABLED_SPELL_IDS = DEFAULT_ENABLED_SPELL_IDS,
        IsBuilt = function() return optionsBuilt end,
        SetBuilt = function(v) optionsBuilt = v and true or false end,
        GetDB = function() return db end,
        GetAceDB = function() return aceDB end,
        Print = Print,
        StartCooldown = StartCooldown,
        ToggleTestMode = ToggleTestMode,
        RandomizeTestMode = RandomizeTestMode,
        RefreshAllVisiblePlates = RefreshAllVisiblePlates,
        NormalizeCategory = NormalizeCategory,
        NormalizeTrigger = NormalizeTrigger,
        BuildSpellRowsData = BuildSpellRowsData,
        BuildSpellRowName = BuildSpellRowName,
        BuildSpellTooltipBody = BuildSpellTooltipBody,
        BuildSpellPanelDesc = BuildSpellPanelDesc,
        NotifySpellsChanged = NotifySpellsChanged,
        GetBaseSpellEntry = GetBaseSpellEntry,
        ResetAllCooldowns = ResetAllCooldowns,
    })
end

local function OnUpdate(_, elapsed)
    if db then
        SyncSpecContext()
        STATE.specAccum = (STATE.specAccum or 0) + elapsed
        if STATE.specAccum >= 1.0 then
            STATE.specAccum = 0
            if SpecModule.PruneExpiredHints(SPEC_CONTEXT) then
                RefreshAllVisiblePlates()
            end
        end
        STATE.inspectAccum = (STATE.inspectAccum or 0) + elapsed
        if STATE.inspectAccum >= (tonumber(db.inspectRetryInterval) or 1.0) then
            STATE.inspectAccum = 0
            ProcessInspectQueue()
        end
    end
    SyncRenderContext()
    RENDER_CONTEXT.ScanNameplates = ScanNameplates
    RENDER_CONTEXT.ResolveGroupTargets = ResolveGroupTargets
    RENDER_CONTEXT.PopulateRandomPlateTests = PopulateRandomPlateTests
    return RenderModule.OnUpdate(RENDER_CONTEXT, elapsed)
end

local function HandleUnitSignal(unit, confidence, reason)
    ResolveUnit(unit, confidence, reason)
    RefreshAllVisiblePlates()
end

local FEIGN_DEATH_SPELL_ID = 5384
local FEIGN_DEATH_SPELL_NAME = GetSpellInfo(FEIGN_DEATH_SPELL_ID)

local function HasActiveCooldownForUnit(unitGUID, unitName, spellID)
    local now = GetTime()
    if unitGUID and STATE.cooldownsByGUID[unitGUID] and STATE.cooldownsByGUID[unitGUID][spellID] then
        local rec = STATE.cooldownsByGUID[unitGUID][spellID]
        if rec and rec.expiresAt and rec.expiresAt > now then
            return true
        end
    end
    if unitName and STATE.cooldownsByName[unitName] and STATE.cooldownsByName[unitName][spellID] then
        local rec = STATE.cooldownsByName[unitName][spellID]
        if rec and rec.expiresAt and rec.expiresAt > now then
            return true
        end
    end
    return false
end

local function IsFeignDeathAuraActive(unit)
    if not unit or unit == "" or not UnitExists(unit) then
        return false
    end
    for i = 1, 40 do
        local auraName, _, _, _, _, _, _, _, _, _, auraSpellID = UnitAura(unit, i, "HELPFUL")
        if not auraName then
            break
        end
        if auraSpellID == FEIGN_DEATH_SPELL_ID or (FEIGN_DEATH_SPELL_NAME and auraName == FEIGN_DEATH_SPELL_NAME) then
            return true
        end
    end
    return false
end

local function HandleFeignDeathAura(unit)
    if not db or not IsEnabledInCurrentZone() then
        return
    end
    if not unit or unit == "" or not UnitExists(unit) then
        return
    end
    if not UnitCanAttack("player", unit) then
        return
    end

    local unitGUID = UnitGUID(unit)
    local unitName = ShortName(UnitName(unit))
    if not unitGUID or not unitName then
        return
    end

    local isActive = IsFeignDeathAuraActive(unit)
    local wasActive = STATE.feignDeathAuraByGUID[unitGUID] and true or false

    if isActive then
        STATE.feignDeathAuraByGUID[unitGUID] = true
        return
    end

    if not wasActive then
        return
    end

    STATE.feignDeathAuraByGUID[unitGUID] = nil
    if HasActiveCooldownForUnit(unitGUID, unitName, FEIGN_DEATH_SPELL_ID) then
        return
    end

    local sourceKey = unitGUID or unitName
    local window = ConstantsModule.SPELL_DEDUPE_WINDOW and ConstantsModule.SPELL_DEDUPE_WINDOW[FEIGN_DEATH_SPELL_ID]
    if window and window > 0 and sourceKey then
        STATE.recentUnitSucceededByUnit[sourceKey] = STATE.recentUnitSucceededByUnit[sourceKey] or {}
        local now = GetTime()
        local prev = STATE.recentUnitSucceededByUnit[sourceKey][FEIGN_DEATH_SPELL_ID]
        if prev and (now - prev) < window then
            return
        end
        STATE.recentUnitSucceededByUnit[sourceKey][FEIGN_DEATH_SPELL_ID] = now
    end

    ResolveUnit(unit, 0.97, "unit-aura-feign")
    StartCooldown(unitGUID, unitName, FEIGN_DEATH_SPELL_ID, FEIGN_DEATH_SPELL_NAME, "SPELL_CAST_SUCCESS")
end

local function ShouldSuppressUnitCast(unitKey, spellID)
    if not unitKey or not spellID then
        return false
    end
    local window = ConstantsModule.SPELL_DEDUPE_WINDOW and ConstantsModule.SPELL_DEDUPE_WINDOW[spellID]
    if not window or window <= 0 then
        return false
    end
    STATE.recentUnitSucceededByUnit[unitKey] = STATE.recentUnitSucceededByUnit[unitKey] or {}
    local now = GetTime()
    local prev = STATE.recentUnitSucceededByUnit[unitKey][spellID]
    if prev and (now - prev) < window then
        return true
    end
    STATE.recentUnitSucceededByUnit[unitKey][spellID] = now
    return false
end

local function RemoveInspectQueueEntryAt(index)
    local entry = STATE.inspectQueue[index]
    if not entry then
        return
    end
    STATE.inspectQueuedByGUID[entry.guid] = nil
    tremove(STATE.inspectQueue, index)
end

local function RemoveInspectQueueByGUID(guid)
    if not guid then
        return
    end
    for i = #STATE.inspectQueue, 1, -1 do
        local entry = STATE.inspectQueue[i]
        if entry and entry.guid == guid then
            RemoveInspectQueueEntryAt(i)
        end
    end
    STATE.inspectQueuedByGUID[guid] = nil
end

local function QueueInspectForUnit(unit)
    if not unit or unit == "" or not UnitExists(unit) or not NotifyInspect then
        return
    end
    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    if STATE.inspectQueuedByGUID[guid] then
        for i = 1, #STATE.inspectQueue do
            local entry = STATE.inspectQueue[i]
            if entry and entry.guid == guid then
                entry.unit = unit
                entry.lastSeen = GetTime()
                break
            end
        end
        return
    end

    local now = GetTime()
    STATE.inspectQueue[#STATE.inspectQueue + 1] = {
        guid = guid,
        unit = unit,
        enqueuedAt = now,
        lastTryAt = 0,
        lastSeen = now,
    }
    STATE.inspectQueuedByGUID[guid] = true
end

local function IsInspectUnitInRange(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    if CheckInteractDistance then
        local inRange = CheckInteractDistance(unit, 1)
        if inRange == 1 then
            return true
        end
        if inRange == 0 then
            return false
        end
    end
    if CanInspect then
        return CanInspect(unit, true) and true or false
    end
    return true
end

local function RecordInspectOutOfRangeUnit(guid, unit)
    if not guid then
        return
    end
    STATE.inspectOutOfRangeUnits[guid] = tostring(UnitName(unit) or guid)
end

local function FlushInspectOutOfRangeMessage()
    if not db or not db.showOutOfRangeInspectMessages then
        WipeTable(STATE.inspectOutOfRangeUnits)
        return
    end

    local names = {}
    for _, unitName in pairs(STATE.inspectOutOfRangeUnits) do
        names[#names + 1] = tostring(unitName)
    end
    WipeTable(STATE.inspectOutOfRangeUnits)

    if #names == 0 then
        return
    end

    table.sort(names)
    Print("Inspect skipped (out of range): " .. table.concat(names, ", "))
end

ProcessInspectQueue = function()
    if not db or not NotifyInspect or #STATE.inspectQueue == 0 then
        return
    end

    if STATE.inspectCurrent then
        local active = STATE.inspectCurrent
        local maxRetry = tonumber(db.inspectMaxRetryTime) or 30
        if (GetTime() - (active.requestedAt or 0)) > maxRetry then
            if ClearInspectPlayer then
                ClearInspectPlayer()
            end
            STATE.inspectCurrent = nil
            STATE.inspectUnitByGUID[active.guid] = nil
            RemoveInspectQueueByGUID(active.guid)
            STATE.inspectOutOfRangeSince[active.guid] = nil
        end
        return
    end

    local now = GetTime()
    local retryInterval = tonumber(db.inspectRetryInterval) or 1.0
    local maxRetry = tonumber(db.inspectMaxRetryTime) or 30
    local selectedIndex = nil

    for i = 1, #STATE.inspectQueue do
        local entry = STATE.inspectQueue[i]
        if entry then
            local unit = entry.unit
            local guid = entry.guid
            local tooOld = (now - (entry.enqueuedAt or now)) > maxRetry
            if tooOld then
                if STATE.inspectOutOfRangeSince[guid] then
                    RecordInspectOutOfRangeUnit(guid, unit)
                end
                RemoveInspectQueueEntryAt(i)
                break
            end

            if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
                RemoveInspectQueueEntryAt(i)
                break
            end

            if not IsInspectUnitInRange(unit) then
                if not STATE.inspectOutOfRangeSince[guid] then
                    STATE.inspectOutOfRangeSince[guid] = now
                end
                if (now - STATE.inspectOutOfRangeSince[guid]) >= maxRetry then
                    RecordInspectOutOfRangeUnit(guid, unit)
                    RemoveInspectQueueEntryAt(i)
                    STATE.inspectOutOfRangeSince[guid] = nil
                    break
                end
            else
                STATE.inspectOutOfRangeSince[guid] = nil
                if not selectedIndex and (now - (entry.lastTryAt or 0)) >= retryInterval then
                    selectedIndex = i
                end
            end
        end
    end

    if next(STATE.inspectOutOfRangeUnits) then
        FlushInspectOutOfRangeMessage()
    end

    if not selectedIndex then
        return
    end

    local entry = STATE.inspectQueue[selectedIndex]
    if not entry then
        return
    end
    entry.lastTryAt = now
    STATE.inspectRequestAtByGUID[entry.guid] = now
    STATE.inspectUnitByGUID[entry.guid] = entry.unit
    STATE.inspectCurrent = { guid = entry.guid, unit = entry.unit, requestedAt = now }
    NotifyInspect(entry.unit)
end

local function HandleInspectTalentReady(guid)
    if not guid or guid == "" then
        STATE.inspectCurrent = nil
        return
    end
    local unit = STATE.inspectUnitByGUID[guid]
    if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
        STATE.inspectUnitByGUID[guid] = nil
        STATE.inspectCurrent = nil
        RemoveInspectQueueByGUID(guid)
        STATE.inspectOutOfRangeSince[guid] = nil
        return
    end
    local name, classToken = UnitClass(unit)
    if not classToken then
        STATE.inspectUnitByGUID[guid] = nil
        STATE.inspectCurrent = nil
        RemoveInspectQueueByGUID(guid)
        STATE.inspectOutOfRangeSince[guid] = nil
        return
    end
    local bestTab, bestPoints = nil, -1
    for tabIndex = 1, 3 do
        local _, _, pointsSpent = GetTalentTabInfo(tabIndex, true, false, 1)
        pointsSpent = tonumber(pointsSpent) or 0
        if pointsSpent > bestPoints then
            bestPoints = pointsSpent
            bestTab = tabIndex
        end
    end
    if bestTab and bestPoints >= 0 then
        SyncSpecContext()
        local changed = SpecModule.UpdateFromInspectTalents(SPEC_CONTEXT, guid, ShortName(name), classToken, bestTab)
        if changed then
            RefreshAllVisiblePlates()
        end
    end
    STATE.inspectUnitByGUID[guid] = nil
    STATE.inspectCurrent = nil
    STATE.inspectOutOfRangeSince[guid] = nil
    STATE.inspectOutOfRangeUnits[guid] = nil
    RemoveInspectQueueByGUID(guid)
    if ClearInspectPlayer then
        ClearInspectPlayer()
    end
end

local function RecordCombatReaction(sourceGUID, sourceName, reaction)
    if not reaction then
        return
    end
    STATE.reactionByGUID = STATE.reactionByGUID or {}
    STATE.reactionByName = STATE.reactionByName or {}
    STATE.reactionSourceByGUID = STATE.reactionSourceByGUID or {}
    STATE.reactionSourceByName = STATE.reactionSourceByName or {}
    if sourceGUID and sourceGUID ~= "" then
        STATE.reactionByGUID[sourceGUID] = reaction
        STATE.reactionSourceByGUID[sourceGUID] = "combat"
    end
    if sourceName and sourceName ~= "" then
        STATE.reactionByName[sourceName] = reaction
        STATE.reactionSourceByName[sourceName] = "combat"
    end
end

local EVENTS_CONTEXT = {
    addon = addon,
    baseCooldowns = BASE_COOLDOWNS,
    ConfigModule = ConfigModule,
    SpecModule = SpecModule,
    CombatModule = CombatModule,
    AceDBLib = AceDBLib,
    CopyDefaults = CopyDefaults,
    profileCallbacks = profileCallbacks,
    ProfilesChanged = ProfilesChanged,
    EnsureDefaultSpellProfile = EnsureDefaultSpellProfile,
    SyncSpecHintsFromDB = SyncSpecHintsFromDB,
    RebuildInternalAPI = RebuildInternalAPI,
    STATE = STATE,
    WipeTable = WipeTable,
    ScanNameplates = ScanNameplates,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    HandleUnitSignal = HandleUnitSignal,
    HandleFeignDeathAura = HandleFeignDeathAura,
    ShouldSuppressUnitCast = ShouldSuppressUnitCast,
    QueueInspectForUnit = QueueInspectForUnit,
    HandleInspectTalentReady = HandleInspectTalentReady,
    ShortName = ShortName,
    ResolveSpellIDByName = ResolveSpellIDByName,
    ResolveUnit = ResolveUnit,
    IsEnabledInCurrentZone = IsEnabledInCurrentZone,
    SyncSpecContext = SyncSpecContext,
    SPEC_CONTEXT = SPEC_CONTEXT,
    COOLDOWN_RULES_CONTEXT = COOLDOWN_RULES_CONTEXT,
    RecordCombatReaction = RecordCombatReaction,
    StartCooldown = StartCooldown,
    OnUpdate = OnUpdate,
    BuildOptionsPanel = BuildOptionsPanel,
    Print = Print,
    aceDBRef = { value = nil },
    dbRef = { value = nil },
}

local function HandleEvent(_, event, ...)
    EVENTS_CONTEXT.aceDBRef.value = aceDB
    EVENTS_CONTEXT.dbRef.value = db
    EVENTS_CONTEXT.CommitRefs = function()
        aceDB = EVENTS_CONTEXT.aceDBRef.value
        db = EVENTS_CONTEXT.dbRef.value
    end
    EventsModule.HandleEvent(EVENTS_CONTEXT, event, ...)
    aceDB = EVENTS_CONTEXT.aceDBRef.value
    db = EVENTS_CONTEXT.dbRef.value
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", HandleEvent)



