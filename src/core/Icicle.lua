local ADDON_NAME = "Icicle"
local VERSION = "v2.0.0-wotlk"

local floor, ceil = math.floor, math.ceil
local max, min = math.max, math.min
local abs, pow = math.abs, math.pow
local tinsert, tremove = table.insert, table.remove
local bit_band = bit.band
local strmatch, strfind = string.match, string.find
local strlower, strupper = string.lower, string.upper
local format = string.format

local addon = CreateFrame("Frame")
local db
local aceDB
local optionsBuilt = false
local profileCallbacks = {}
local editState = { spellID = "", cooldown = "", trigger = "SUCCESS" }
local GetSpellDescSafe

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBLib = LibStub("AceDB-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local OptionsModule = type(IcicleOptions) == "table" and IcicleOptions or nil
local ConstantsModule = type(IcicleConstants) == "table" and IcicleConstants or nil
local TooltipModule = type(IcicleTooltip) == "table" and IcicleTooltip or nil
local CombatModule = type(IcicleCombat) == "table" and IcicleCombat or nil
local TrackingModule = type(IcicleTracking) == "table" and IcicleTracking or nil
local NameplatesModule = type(IcicleNameplates) == "table" and IcicleNameplates or nil
local ResolverModule = type(IcicleResolver) == "table" and IcicleResolver or nil
local RenderModule = type(IcicleRender) == "table" and IcicleRender or nil
local ConfigModule = type(IcicleConfig) == "table" and IcicleConfig or nil
local CooldownRulesModule = type(IcicleCooldownRules) == "table" and IcicleCooldownRules or nil
local TestModeModule = type(IcicleTestMode) == "table" and IcicleTestMode or nil
local SpellsModule = type(IcicleSpells) == "table" and IcicleSpells or nil
local DebugModule = type(IcicleDebug) == "table" and IcicleDebug or nil
local SpecModule = type(IcicleSpec) == "table" and IcicleSpec or nil
local StateModule = type(IcicleState) == "table" and IcicleState or nil
local EventsModule = type(IcicleEvents) == "table" and IcicleEvents or nil
local MigrationModule = type(IcicleMigration) == "table" and IcicleMigration or nil
local UIOptionsModule = type(IcicleUIOptions) == "table" and IcicleUIOptions or nil
local BootstrapModule = type(IcicleBootstrap) == "table" and IcicleBootstrap or nil

if not OptionsModule then
    local fallback = {}
    function fallback.RegisterPanels(ctx)
        local AC = ctx.AceConfig
        local ACD = ctx.AceConfigDialog
        local ADO = ctx.AceDBOptions
        local adb = ctx.aceDB
        AC:RegisterOptionsTable("Icicle", ctx.root)
        ACD:AddToBlizOptions("Icicle", "Icicle Reborn")
        AC:RegisterOptionsTable("IcicleGeneral", ctx.general)
        ACD:AddToBlizOptions("IcicleGeneral", "General", "Icicle Reborn")
        AC:RegisterOptionsTable("IcicleStyle", ctx.style)
        ACD:AddToBlizOptions("IcicleStyle", "Style settings", "Icicle Reborn")
        AC:RegisterOptionsTable("IciclePosition", ctx.position)
        ACD:AddToBlizOptions("IciclePosition", "Position settings", "Icicle Reborn")
        AC:RegisterOptionsTable("IcicleSpells", ctx.spells)
        ACD:AddToBlizOptions("IcicleSpells", "Tracked Spells", "Icicle Reborn")
        if ctx.testing then
            AC:RegisterOptionsTable("IcicleTesting", ctx.testing)
            ACD:AddToBlizOptions("IcicleTesting", "Testing", "Icicle Reborn")
        end
        if ADO and adb then
            local profileOptions = ADO:GetOptionsTable(adb)
            AC:RegisterOptionsTable("IcicleProfiles", profileOptions)
            ACD:AddToBlizOptions("IcicleProfiles", "Profiles", "Icicle Reborn")
        end
    end
    function fallback.OpenPanel(panelName)
        InterfaceOptionsFrame_OpenToCategory(panelName)
        InterfaceOptionsFrame_OpenToCategory(panelName)
    end
    OptionsModule = fallback
end

if not ConstantsModule then
    ConstantsModule = {
        VALID_POINTS = {
            TOPLEFT = true, TOP = true, TOPRIGHT = true,
            LEFT = true, CENTER = true, RIGHT = true,
            BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
        },
        VALID_GROW = { RIGHT = true, LEFT = true, UP = true, DOWN = true },
        POINT_VALUES = {
            TOPLEFT = "TOPLEFT", TOP = "TOP", TOPRIGHT = "TOPRIGHT",
            LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT",
            BOTTOMLEFT = "BOTTOMLEFT", BOTTOM = "BOTTOM", BOTTOMRIGHT = "BOTTOMRIGHT",
        },
        GROW_VALUES = { RIGHT = "RIGHT", LEFT = "LEFT", UP = "UP", DOWN = "DOWN" },
        SPELL_DEDUPE_WINDOW = {
            [53007] = 2.2,
            [61384] = 2.2,
        },
    }
end

if not TooltipModule then
    local fallbackTooltip = CreateFrame("GameTooltip", "IcicleFallbackSpellTooltipScanner", UIParent, "GameTooltipTemplate")
    local fallbackTooltipCache = {}
    local function FallbackIsEmptyString(s)
        if not s then return true end
        return (s:gsub("^%s*(.-)%s*$", "%1")) == ""
    end
    local function FallbackFormatCooldownText(seconds)
        if not seconds then return "Unknown" end
        if SecondsToTime then
            return SecondsToTime(seconds)
        end
        if seconds >= 60 then
            return format("%dm %ds", floor(seconds / 60), seconds % 60)
        end
        return format("%.1fs", seconds)
    end
    local function FallbackGetSpellOrItemInfo(spellID, isItem)
        if isItem then
            local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(spellID)
            return itemName, itemTexture or GetItemIcon(spellID)
        end
        local spellName, _, spellTexture = GetSpellInfo(spellID)
        return spellName, spellTexture
    end
    local function FallbackGetSpellDescSafe(spellID, isItem)
        if not spellID then return "No description available." end
        local cacheKey = (isItem and "item:" or "spell:") .. tostring(spellID)
        if fallbackTooltipCache[cacheKey] then return fallbackTooltipCache[cacheKey] end
        fallbackTooltip:ClearLines()
        fallbackTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        local link = (isItem and "item:" or "spell:") .. tostring(spellID)
        local ok = pcall(fallbackTooltip.SetHyperlink, fallbackTooltip, link)
        if not ok then
            fallbackTooltip:Hide()
            fallbackTooltipCache[cacheKey] = "No description available."
            return fallbackTooltipCache[cacheKey]
        end
        local lines = fallbackTooltip:NumLines()
        if lines < 1 then
            fallbackTooltip:Hide()
            fallbackTooltipCache[cacheKey] = "No description available."
            return fallbackTooltipCache[cacheKey]
        end
        local txt = nil
        local last = _G["IcicleFallbackSpellTooltipScannerTextLeft" .. lines]
        if last then
            txt = last:GetText()
        end
        if FallbackIsEmptyString(txt) and lines > 1 then
            local prev = _G["IcicleFallbackSpellTooltipScannerTextLeft" .. (lines - 1)]
            if prev then
                txt = prev:GetText()
            end
        end
        if FallbackIsEmptyString(txt) then
            local collect = {}
            for i = 2, lines do
                local left = _G["IcicleFallbackSpellTooltipScannerTextLeft" .. i]
                if left then
                    local lineTxt = left:GetText()
                    if not FallbackIsEmptyString(lineTxt) then
                        tinsert(collect, lineTxt)
                    end
                end
            end
            txt = table.concat(collect, "\n")
        end
        fallbackTooltip:Hide()
        if FallbackIsEmptyString(txt) then
            txt = "No description available."
        end
        fallbackTooltipCache[cacheKey] = txt
        return fallbackTooltipCache[cacheKey]
    end
    local function FallbackBuildSpellTooltipText(spellID, spellName, iconTex, cooldownSeconds, isItem)
        spellName = spellName or ("Spell " .. tostring(spellID))
        iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
        local desc = FallbackGetSpellDescSafe(spellID, isItem)
        local header = "|T" .. iconTex .. ":16:16:0:0|t " .. spellName
        local body = format(
            "\n|cffffd700Cooldown:|r %s\n\n%s\n\n|cffffd700Spell ID:|r %d",
            FallbackFormatCooldownText(cooldownSeconds or 0),
            desc,
            spellID
        )
        return header, body
    end
    local function FallbackBuildSpellPanelDesc(row)
        return "|cffffffff" .. FallbackGetSpellDescSafe(row.id, row.isItem) .. "|r"
    end
    TooltipModule = {
        GetSpellOrItemInfo = FallbackGetSpellOrItemInfo,
        BuildSpellTooltipText = FallbackBuildSpellTooltipText,
        BuildSpellPanelDesc = FallbackBuildSpellPanelDesc,
        GetSpellDescSafe = FallbackGetSpellDescSafe,
    }
end

if not CombatModule then
    local COMBATLOG_OBJECT_TYPE_PET_MASK = COMBATLOG_OBJECT_TYPE_PET or 0
    local function FallbackReactionFromFlags(flags)
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
    local function FallbackPetOwnerNameFromSource(sourceName)
        if not sourceName then return nil end
        local owner = strmatch(sourceName, "<([^>]+)>")
        if owner and owner ~= "" then
            return strmatch(owner, "([^%-]+)") or owner
        end
        return nil
    end
    local function FallbackParseCombatLog(...)
        local arg3 = select(3, ...)
        local sourceGUID, sourceName, sourceFlags, spellID, spellName
        if type(arg3) == "boolean" then
            sourceGUID, sourceName, sourceFlags = select(4, ...), select(5, ...), select(6, ...)
            spellID, spellName = select(12, ...), select(13, ...)
        else
            sourceGUID, sourceName, sourceFlags = select(3, ...), select(4, ...), select(5, ...)
            spellID, spellName = select(9, ...), select(10, ...)
        end
        local normalizedSourceName = sourceName and (strmatch(sourceName, "([^%-]+)") or sourceName) or nil
        local normalizedSourceGUID = sourceGUID
        local sourceIsPet = false
        if type(sourceFlags) == "number" and COMBATLOG_OBJECT_TYPE_PET_MASK ~= 0 and bit_band(sourceFlags, COMBATLOG_OBJECT_TYPE_PET_MASK) == COMBATLOG_OBJECT_TYPE_PET_MASK then
            sourceIsPet = true
            local owner = FallbackPetOwnerNameFromSource(sourceName)
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
            sourceReaction = FallbackReactionFromFlags(sourceFlags),
            spellID = spellID,
            spellName = spellName,
            sourceIsPet = sourceIsPet,
        }
    end
    local function FallbackIsHostileEnemyCaster(flags)
        if type(flags) ~= "number" then return false end
        local isHostile = bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE
        if not isHostile then
            return false
        end
        local isPlayer = bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER
        local isPet = COMBATLOG_OBJECT_TYPE_PET_MASK ~= 0 and bit_band(flags, COMBATLOG_OBJECT_TYPE_PET_MASK) == COMBATLOG_OBJECT_TYPE_PET_MASK
        return isPlayer or isPet
    end
    CombatModule = {
        ParseCombatLog = FallbackParseCombatLog,
        IsHostileEnemyCaster = FallbackIsHostileEnemyCaster,
        GetReactionFromFlags = FallbackReactionFromFlags,
    }
end

if not TrackingModule then
    local fallback = {}
    local function FallbackEventDedupe(state, spellDedupeWindow, unitKey, spellID)
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
    function fallback.StartCooldown(ctx, sourceGUID, sourceName, spellID, spellName, eventType)
        local spellCfg
        if ctx.GetCooldownRule then
            spellCfg = ctx.GetCooldownRule(spellID, sourceGUID, sourceName)
        else
            spellCfg = ctx.GetSpellConfig(spellID, sourceGUID, sourceName)
        end
        if not spellCfg and ctx.GetSharedCooldownTargets and eventType == "SPELL_CAST_SUCCESS" then
            local sharedTargets = ctx.GetSharedCooldownTargets(spellID)
            if sharedTargets then
                local sourceKey = sourceGUID or sourceName
                if sourceKey and not FallbackEventDedupe(ctx.STATE, ctx.spellDedupeWindow, sourceKey, spellID) then
                    local applied = 0
                    if sourceGUID then
                        ctx.STATE.cooldownsByGUID[sourceGUID] = ctx.STATE.cooldownsByGUID[sourceGUID] or {}
                    end
                    if sourceName then
                        ctx.STATE.fallbackCooldownsByName[sourceName] = ctx.STATE.fallbackCooldownsByName[sourceName] or {}
                    end
                    for targetSpellID, sharedCfg in pairs(sharedTargets) do
                        local targetRule = (ctx.GetCooldownRule and ctx.GetCooldownRule(targetSpellID, sourceGUID, sourceName)) or (ctx.GetSpellConfig and ctx.GetSpellConfig(targetSpellID, sourceGUID, sourceName))
                        if targetRule and targetRule.cd and targetRule.cd > 0 then
                            local duration = (sharedCfg and sharedCfg.sharedDuration) or targetRule.cd
                            local rec = {
                                spellID = targetRule.spellID or targetSpellID,
                                spellName = GetSpellInfo(targetRule.spellID or targetSpellID) or ("Spell " .. tostring(targetSpellID)),
                                texture = select(3, GetSpellInfo(targetRule.spellID or targetSpellID)) or "Interface\\Icons\\INV_Misc_QuestionMark",
                                startAt = GetTime(),
                                expiresAt = GetTime() + duration,
                                duration = duration,
                            }
                            if sourceGUID then
                                ctx.STATE.cooldownsByGUID[sourceGUID][rec.spellID] = rec
                            end
                            if sourceName then
                                ctx.STATE.fallbackCooldownsByName[sourceName][rec.spellID] = rec
                            end
                            applied = applied + 1
                        end
                    end
                    if applied > 0 then
                        ctx.RefreshAllVisiblePlates()
                    end
                end
            end
            return
        end
        if not spellCfg or not ctx.EventMatchesTrigger(eventType, spellCfg.trigger) then
            return
        end
        local now = GetTime()
        local sourceKey = sourceGUID or sourceName
        if not sourceKey or FallbackEventDedupe(ctx.STATE, ctx.spellDedupeWindow, sourceKey, spellID) then
            return
        end
        local texture = select(3, GetSpellInfo(spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        local record = {
            spellID = spellID,
            spellName = spellName or (GetSpellInfo(spellID) or ("Spell " .. tostring(spellID))),
            texture = texture,
            startAt = now,
            expiresAt = now + spellCfg.cd,
            duration = spellCfg.cd,
        }
        if sourceGUID then
            ctx.STATE.cooldownsByGUID[sourceGUID] = ctx.STATE.cooldownsByGUID[sourceGUID] or {}
            ctx.STATE.cooldownsByGUID[sourceGUID][spellID] = record
            if sourceName then
                local bound = ctx.TryBindByName(sourceGUID, sourceName, 0.9, "combatlog", spellName, now)
                if bound then
                    ctx.MigrateNameFallbackToGUID(sourceName, sourceGUID)
                else
                    if ctx.RegisterPendingBind then
                        ctx.RegisterPendingBind(sourceGUID, sourceName, spellName, now)
                    end
                    ctx.STATE.fallbackCooldownsByName[sourceName] = ctx.STATE.fallbackCooldownsByName[sourceName] or {}
                    ctx.STATE.fallbackCooldownsByName[sourceName][spellID] = record
                end
            end
        elseif sourceName then
            ctx.STATE.fallbackCooldownsByName[sourceName] = ctx.STATE.fallbackCooldownsByName[sourceName] or {}
            ctx.STATE.fallbackCooldownsByName[sourceName][spellID] = record
        end
        ctx.RefreshAllVisiblePlates()
    end
    TrackingModule = fallback
end

if not NameplatesModule then
    local fallback = {}
    function fallback.FindFontStringNameRegion(plate)
        if plate.oldname and plate.oldname.GetText then return plate.oldname end
        if plate.name and plate.name.GetText then return plate.name end
        if plate.UnitFrame and plate.UnitFrame.oldName and plate.UnitFrame.oldName.GetText then return plate.UnitFrame.oldName end

        local best
        local regions = { plate:GetRegions() }
        for i = 1, #regions do
            local reg = regions[i]
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                local txt = reg:GetText()
                if txt and txt ~= "" then
                    if not best then best = reg end
                    if not strmatch(txt, "^%d+$") then return reg end
                end
            end
        end
        return best
    end
    function fallback.FindBars(plate)
        local healthBar, castBar
        if plate.healthBar and plate.healthBar.GetObjectType and plate.healthBar:GetObjectType() == "StatusBar" then
            healthBar = plate.healthBar
        end
        local children = { plate:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
                if not healthBar then
                    healthBar = child
                elseif child ~= healthBar and not castBar then
                    castBar = child
                end
            end
        end
        return healthBar, castBar
    end
    function fallback.GetCastSpellFromBar(castBar)
        if not castBar then return nil end
        if castBar.Text and castBar.Text.GetText then
            local txt = castBar.Text:GetText()
            if txt and txt ~= "" then return txt end
        end
        local regions = { castBar:GetRegions() }
        for i = 1, #regions do
            local reg = regions[i]
            if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
                local txt = reg:GetText()
                if txt and txt ~= "" then return txt end
            end
        end
        return nil
    end
    function fallback.PlateName(meta, shortNameFn)
        if meta.nameText and meta.nameText.GetText then
            local n = meta.nameText:GetText()
            if n and n ~= "" then return shortNameFn(n) end
        end
        if meta.plate.aloftData and meta.plate.aloftData.name then
            return shortNameFn(meta.plate.aloftData.name)
        end
        return nil
    end
    function fallback.IsLikelyNamePlate(frame)
        if frame.IcicleIsPlate ~= nil then return frame.IcicleIsPlate end
        local name = frame:GetName()
        if name and strfind(name, "NamePlate") then
            frame.IcicleIsPlate = true
            return true
        end
        if frame:GetNumRegions() < 2 or frame:GetNumChildren() < 1 then
            frame.IcicleIsPlate = false
            return false
        end
        if frame:GetNumRegions() > 2 and frame:GetNumChildren() >= 1 then
            frame.IcicleIsPlate = true
            return true
        end
        local hasStatusBar = false
        local children = { frame:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
                hasStatusBar = true
                break
            end
        end
        frame.IcicleIsPlate = hasStatusBar
        return hasStatusBar
    end
    function fallback.AddVisibleNamePlate(visiblePlatesByName, name, plate)
        local entry = visiblePlatesByName[name]
        if not entry then
            entry = { count = 0, first = nil, map = {} }
            visiblePlatesByName[name] = entry
        end
        if not entry.map[plate] then
            entry.map[plate] = true
            entry.count = entry.count + 1
            if not entry.first then entry.first = plate end
        end
    end
    function fallback.ScanNameplates(ctx)
        local startMs = debugprofilestop and debugprofilestop() or 0
        local num = WorldFrame:GetNumChildren()
        ctx.STATE.stats.lastScanChildren = num
        for i = 1, num do
            local frame = select(i, WorldFrame:GetChildren())
            if frame and not ctx.STATE.knownPlates[frame] and fallback.IsLikelyNamePlate(frame) then
                ctx.RegisterPlate(frame)
            end
        end
        ctx.WipeTable(ctx.STATE.visiblePlatesByName)
        ctx.STATE.visibleCount = 0
        for plate in pairs(ctx.STATE.knownPlates) do
            if plate:IsShown() and plate:GetAlpha() > 0 then
                local meta = ctx.STATE.plateMeta[plate]
                if meta then
                    meta.name = fallback.PlateName(meta, ctx.ShortName)
                    if meta.name then
                        fallback.AddVisibleNamePlate(ctx.STATE.visiblePlatesByName, meta.name, plate)
                        ctx.STATE.visibleCount = ctx.STATE.visibleCount + 1
                    end
                    if meta.castBar and meta.castBar:IsShown() then
                        local castSpell = fallback.GetCastSpellFromBar(meta.castBar)
                        if castSpell and castSpell ~= "" then
                            if castSpell ~= meta.lastCastSpell or (GetTime() - meta.lastCastAt) > ctx.db.castMatchWindow then
                                meta.lastCastSpell = castSpell
                                meta.lastCastAt = GetTime()
                            end
                        end
                    end
                    if meta.container then meta.container:Show() end
                end
            else
                local meta = ctx.STATE.plateMeta[plate]
                if meta and meta.container then meta.container:Hide() end
                ctx.RemovePlateBinding(plate)
            end
        end
        ctx.DecayAndPurgeMappings()
        ctx.STATE.stats.scanCount = ctx.STATE.stats.scanCount + 1
        if debugprofilestop then
            ctx.STATE.stats.scanTotalMs = ctx.STATE.stats.scanTotalMs + (debugprofilestop() - startMs)
        end
    end
    NameplatesModule = fallback
end

if not ResolverModule then
    local fallback = {}
    function fallback.RemovePlateBinding(ctx, plate)
        local mapped = ctx.STATE.guidByPlate[plate]
        if not mapped then return end
        local guid = mapped.guid
        if guid and ctx.STATE.plateByGUID[guid] and ctx.STATE.plateByGUID[guid].plate == plate then
            ctx.STATE.plateByGUID[guid] = nil
        end
        ctx.STATE.guidByPlate[plate] = nil
    end
    function fallback.RemoveGUIDBinding(ctx, guid)
        local mapped = ctx.STATE.plateByGUID[guid]
        if not mapped then return end
        local plate = mapped.plate
        if plate and ctx.STATE.guidByPlate[plate] and ctx.STATE.guidByPlate[plate].guid == guid then
            ctx.STATE.guidByPlate[plate] = nil
        end
        ctx.STATE.plateByGUID[guid] = nil
    end
    function fallback.SetBinding(ctx, guid, plate, conf, reason, sourceName)
        if not guid or not plate then return false end
        local now = GetTime()
        fallback.RemoveGUIDBinding(ctx, guid)
        fallback.RemovePlateBinding(ctx, plate)
        ctx.STATE.plateByGUID[guid] = { plate = plate, conf = conf, lastSeen = now, sourceName = sourceName, reason = reason }
        ctx.STATE.guidByPlate[plate] = { guid = guid, conf = conf, lastSeen = now, sourceName = sourceName, reason = reason }
        ctx.DebugLog(format("bind guid=%s conf=%.2f reason=%s", tostring(guid), conf, tostring(reason)))
        return true
    end
    function fallback.DecayAndPurgeMappings(ctx)
        local now = GetTime()
        for guid, entry in pairs(ctx.STATE.plateByGUID) do
            if (not entry.plate) or (not entry.plate:IsShown()) then
                fallback.RemoveGUIDBinding(ctx, guid)
            else
                local conf = ctx.DecayedConfidence(entry, now)
                if conf < ctx.db.minConfidence or (now - entry.lastSeen) > ctx.db.mappingTTL then
                    fallback.RemoveGUIDBinding(ctx, guid)
                end
            end
        end
    end
    function fallback.MigrateNameFallbackToGUID(ctx, name, guid)
        local byName = ctx.STATE.fallbackCooldownsByName[name]
        if not byName then return end
        ctx.STATE.cooldownsByGUID[guid] = ctx.STATE.cooldownsByGUID[guid] or {}
        for spellID, rec in pairs(byName) do
            local current = ctx.STATE.cooldownsByGUID[guid][spellID]
            if (not current) or current.expiresAt < rec.expiresAt then
                ctx.STATE.cooldownsByGUID[guid][spellID] = rec
            end
        end
        ctx.STATE.fallbackCooldownsByName[name] = nil
    end
    function fallback.RegisterCandidate(ctx, name, guid)
        if not name or not guid then return end
        ctx.STATE.candidatesByName[name] = ctx.STATE.candidatesByName[name] or {}
        ctx.STATE.candidatesByName[name][guid] = GetTime()
    end
    function fallback.TryBindByName(ctx, guid, name, baseConf, reason, spellName, eventTime)
        if not guid or not name then return false end
        fallback.RegisterCandidate(ctx, name, guid)
        local plates = ctx.STATE.visiblePlatesByName[name]
        if not plates or plates.count == 0 then return false end
        if plates.count == 1 then return fallback.SetBinding(ctx, guid, plates.first, baseConf, reason, name) end
        if spellName then
            local candidatePlate, candidateCount = nil, 0
            for plate in pairs(plates.map) do
                local meta = ctx.STATE.plateMeta[plate]
                if meta and meta.lastCastAt and abs(meta.lastCastAt - eventTime) <= ctx.db.castMatchWindow and meta.lastCastSpell == spellName then
                    candidateCount = candidateCount + 1
                    candidatePlate = plate
                end
            end
            if candidateCount == 1 then return fallback.SetBinding(ctx, guid, candidatePlate, 0.98, "castbar", name) end
        end
        return false
    end
    function fallback.ResolveUnit(ctx, unit, confidence, reason)
        if not UnitExists(unit) then return end
        local guid = UnitGUID(unit)
        local name = ctx.ShortName(UnitName(unit))
        if not guid or not name then return end
        fallback.RegisterCandidate(ctx, name, guid)
        local plates = ctx.STATE.visiblePlatesByName[name]
        if plates and plates.count == 1 and fallback.SetBinding(ctx, guid, plates.first, confidence, reason, name) then
            fallback.MigrateNameFallbackToGUID(ctx, name, guid)
        end
    end
    function fallback.ResolveGroupTargets(ctx)
        if UnitExists("target") then fallback.ResolveUnit(ctx, "target", 0.95, "target") end
        if UnitExists("focus") then fallback.ResolveUnit(ctx, "focus", 0.95, "focus") end
        if UnitExists("mouseover") then fallback.ResolveUnit(ctx, "mouseover", 0.95, "mouseover") end
        if GetNumRaidMembers and GetNumRaidMembers() > 0 then
            for i = 1, 40 do
                local unit = "raid" .. i .. "target"
                if UnitExists(unit) then fallback.ResolveUnit(ctx, unit, 0.8, "raid-target") end
            end
        else
            for i = 1, 4 do
                local unit = "party" .. i .. "target"
                if UnitExists(unit) then fallback.ResolveUnit(ctx, unit, 0.75, "party-target") end
            end
        end
    end
    ResolverModule = fallback
end

if not RenderModule then
    local fallback = {}
    function fallback.CollectDisplayRecords(ctx, meta)
        if ctx.STATE.testModeActive and ctx.STATE.testByPlate[meta.plate] then
            return ctx.STATE.testByPlate[meta.plate]
        end
        local records = {}
        local now = GetTime()
        local guidEntry = ctx.STATE.guidByPlate[meta.plate]
        if guidEntry then
            local conf = ctx.DecayedConfidence(guidEntry, now)
            if conf >= ctx.db.minConfidence then
                local byGUID = ctx.STATE.cooldownsByGUID[guidEntry.guid]
                if byGUID then
                    for _, rec in pairs(byGUID) do
                        if rec.expiresAt > now then
                            rec.__ambiguous = false
                            tinsert(records, rec)
                        end
                    end
                    guidEntry.lastSeen = now
                    return records
                end
            end
        end
        if meta.name then
            local fallbackStore = ctx.STATE.fallbackCooldownsByName[meta.name]
            if fallbackStore then
                local visible = ctx.STATE.visiblePlatesByName[meta.name]
                local visibleCount = visible and visible.count or 0
                if visibleCount == 1 or ctx.db.showAmbiguousFallback then
                    for _, rec in pairs(fallbackStore) do
                        if rec.expiresAt > now then
                            rec.__ambiguous = (visibleCount > 1)
                            tinsert(records, rec)
                        end
                    end
                end
            end
        end
        return records
    end
    function fallback.RenderPlate(ctx, meta)
        ctx.ApplyContainerAnchor(meta)
        local records = fallback.CollectDisplayRecords(ctx, meta)
        table.sort(records, function(a, b) return a.expiresAt < b.expiresAt end)
        ctx.ReleaseIcons(meta)
        local cap = min(#records, ctx.db.maxIcons)
        for i = 1, cap do
            local rec = records[i]
            local icon = ctx.AcquireIcon(meta)
            local r, g, b = ctx.GetIconTextColor(rec.expiresAt - GetTime())
            icon.texture:SetTexture(rec.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon.cooldown:SetTextColor(r, g, b)
            icon.cooldown:SetText(ctx.FormatRemaining(rec.expiresAt - GetTime()))
            icon.record = rec
            icon.isOverflow = nil
            icon:SetAlpha(rec.__ambiguous and 0.45 or 1)
            if rec.__ambiguous then icon.ambiguousMark:Show() else icon.ambiguousMark:Hide() end
            icon:Show()
            tinsert(meta.activeIcons, icon)
        end
        if #records > cap and cap > 0 then
            local last = meta.activeIcons[#meta.activeIcons]
            if last then
                last.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                last.cooldown:SetText("+" .. tostring(#records - cap + 1))
                last.record = { spellID = 0, spellName = "Overflow", expiresAt = GetTime() + 9999 }
                last.isOverflow = true
                last.ambiguousMark:Hide()
            end
        end
        ctx.LayoutIcons(meta)
    end
    function fallback.RefreshAllVisiblePlates(ctx)
        for _, plates in pairs(ctx.STATE.visiblePlatesByName) do
            for plate in pairs(plates.map) do
                local meta = ctx.STATE.plateMeta[plate]
                if meta then fallback.RenderPlate(ctx, meta) end
            end
        end
        ctx.STATE.stats.refreshCount = ctx.STATE.stats.refreshCount + 1
    end
    function fallback.OnUpdate(ctx, elapsed)
        if not ctx.db then return end
        ctx.STATE.scanAccum = ctx.STATE.scanAccum + elapsed
        ctx.STATE.iconAccum = ctx.STATE.iconAccum + elapsed
        ctx.STATE.groupAccum = ctx.STATE.groupAccum + elapsed
        ctx.STATE.testAccum = ctx.STATE.testAccum + elapsed
        if ctx.STATE.scanAccum >= ctx.db.scanInterval then
            ctx.STATE.scanAccum = 0
            ctx.ScanNameplates()
        end
        if ctx.STATE.groupAccum >= ctx.db.groupScanInterval then
            ctx.STATE.groupAccum = 0
            ctx.ResolveGroupTargets()
        end
        if ctx.STATE.iconAccum >= ctx.db.iconUpdateInterval then
            ctx.STATE.iconAccum = 0
            local now = GetTime()
            local changed = false
            changed = ctx.PruneExpiredStore(ctx.STATE.cooldownsByGUID, now) or changed
            changed = ctx.PruneExpiredStore(ctx.STATE.fallbackCooldownsByName, now) or changed
            if changed then
                fallback.RefreshAllVisiblePlates(ctx)
            else
                for _, plates in pairs(ctx.STATE.visiblePlatesByName) do
                    for plate in pairs(plates.map) do
                        local meta = ctx.STATE.plateMeta[plate]
                        if meta then
                            for i = 1, #meta.activeIcons do
                                local icon = meta.activeIcons[i]
                                local rec = icon.record
                                if rec and not icon.isOverflow then
                                    local remain = rec.expiresAt - now
                                    icon.cooldown:SetText(ctx.FormatRemaining(remain))
                                    local r, g, b = ctx.GetIconTextColor(remain)
                                    icon.cooldown:SetTextColor(r, g, b)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    RenderModule = fallback
end

if not ConfigModule then
    local fallback = {}
    function fallback.CopyDefaults(target, defaults)
        for k, v in pairs(defaults) do
            if type(v) == "table" then
                if type(target[k]) ~= "table" then target[k] = {} end
                fallback.CopyDefaults(target[k], v)
            elseif target[k] == nil then
                target[k] = v
            end
        end
    end
    function fallback.EnsureProfileRoot(saved)
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
    function fallback.ApplyLoginMigrations(dbRef, baseCooldowns)
        local function defaultCategoryForSpell(spellID)
            local dataModule = _G.IcicleData
            if type(dataModule) == "table" and type(dataModule.DEFAULT_SPELL_DATA) == "table" then
                local entry = dataModule.DEFAULT_SPELL_DATA[spellID]
                if entry and type(entry.category) == "string" and entry.category ~= "" then
                    return strupper(entry.category)
                end
            end
            return "GENERAL"
        end
        local function isDefaultEnabledSpell(spellID)
            local dataModule = _G.IcicleData
            if type(dataModule) == "table" and type(dataModule.DEFAULT_ENABLED_SPELL_IDS) == "table" then
                return dataModule.DEFAULT_ENABLED_SPELL_IDS[spellID] and true or false
            end
            return true
        end
        local function applyDefaultEnabledPreset()
            dbRef.disabledSpells = dbRef.disabledSpells or {}
            local dataModule = _G.IcicleData
            local defaultSpellData = type(dataModule) == "table" and dataModule.DEFAULT_SPELL_DATA or nil
            if type(defaultSpellData) == "table" then
                for spellID in pairs(defaultSpellData) do
                    if isDefaultEnabledSpell(spellID) then
                        dbRef.disabledSpells[spellID] = nil
                    else
                        dbRef.disabledSpells[spellID] = true
                    end
                end
            elseif baseCooldowns then
                for spellID in pairs(baseCooldowns) do
                    if isDefaultEnabledSpell(spellID) then
                        dbRef.disabledSpells[spellID] = nil
                    else
                        dbRef.disabledSpells[spellID] = true
                    end
                end
            end
            dbRef.defaultEnabledPresetVersion = 1
        end
        if not dbRef.autoLoweredFrameStrata then
            if dbRef.frameStrata == "HIGH" or dbRef.frameStrata == "DIALOG" then
                dbRef.frameStrata = "LOW"
            end
            dbRef.autoLoweredFrameStrata = true
        end
        dbRef.spellCategories = dbRef.spellCategories or {}
        dbRef.disabledSpells = dbRef.disabledSpells or {}
        dbRef.specHintsByGUID = dbRef.specHintsByGUID or {}
        dbRef.specHintsByName = dbRef.specHintsByName or {}
        if dbRef.persistSpecHints == nil then dbRef.persistSpecHints = false end
        if dbRef.specDetectEnabled == nil then dbRef.specDetectEnabled = true end
        if dbRef.classCategoryFilterEnabled == nil then dbRef.classCategoryFilterEnabled = true end
        dbRef.specHintTTL = max(30, min(3600, tonumber(dbRef.specHintTTL) or 300))
        dbRef.categoryBorderEnabled = dbRef.categoryBorderEnabled or {}
        dbRef.categoryBorderColors = dbRef.categoryBorderColors or {}
        local categoryBorderDefaults = {
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
        for category, color in pairs(categoryBorderDefaults) do
            if dbRef.categoryBorderEnabled[category] == nil then
                dbRef.categoryBorderEnabled[category] = true
            end
            if type(dbRef.categoryBorderColors[category]) ~= "table" then
                dbRef.categoryBorderColors[category] = { r = color.r, g = color.g, b = color.b, a = color.a }
            end
        end
        if dbRef.matrixLogEnabled == nil then dbRef.matrixLogEnabled = true end
        if dbRef.matrixStrictSelfTests == nil then dbRef.matrixStrictSelfTests = false end
        dbRef.matrixLogMaxEntries = max(5, min(200, tonumber(dbRef.matrixLogMaxEntries) or 30))
        dbRef.profileSchemaVersion = tonumber(dbRef.profileSchemaVersion) or 0
        dbRef.defaultEnabledPresetVersion = tonumber(dbRef.defaultEnabledPresetVersion) or 0
        if baseCooldowns then
            for spellID in pairs(baseCooldowns) do
                if dbRef.spellCategories[spellID] == nil then
                    dbRef.spellCategories[spellID] = defaultCategoryForSpell(spellID)
                end
            end
        end
        if dbRef.customSpells then
            for spellID in pairs(dbRef.customSpells) do
                if dbRef.spellCategories[spellID] == nil then
                    dbRef.spellCategories[spellID] = "GENERAL"
                end
            end
        end
        if dbRef.defaultEnabledPresetVersion < 1 then
            applyDefaultEnabledPreset()
        end
    end
    function fallback.SetConfigValue(dbRef, key, value, validPoints, validGrow)
        key = strlower(key)
        if key == "anchor" then
            value = strupper(value)
            if not validPoints[value] then return false, "invalid anchor point" end
            dbRef.anchorPoint = value
        elseif key == "anchorto" then
            value = strupper(value)
            if not validPoints[value] then return false, "invalid anchor target point" end
            dbRef.anchorTo = value
        elseif key == "x" then
            dbRef.xOffset = tonumber(value) or dbRef.xOffset
        elseif key == "y" then
            dbRef.yOffset = tonumber(value) or dbRef.yOffset
        elseif key == "size" then
            dbRef.iconSize = max(10, min(64, tonumber(value) or dbRef.iconSize))
        elseif key == "font" then
            dbRef.fontSize = max(6, min(30, tonumber(value) or dbRef.fontSize))
        elseif key == "maxrow" then
            dbRef.maxIconsPerRow = max(1, min(20, tonumber(value) or dbRef.maxIconsPerRow))
        elseif key == "maxicons" then
            dbRef.maxIcons = max(1, min(40, tonumber(value) or dbRef.maxIcons))
        elseif key == "grow" then
            value = strupper(value)
            if not validGrow[value] then return false, "invalid growth direction" end
            dbRef.growthDirection = value
        elseif key == "spacing" then
            dbRef.iconSpacing = max(0, min(20, tonumber(value) or dbRef.iconSpacing))
        elseif key == "scan" then
            dbRef.scanInterval = max(0.1, min(0.5, tonumber(value) or dbRef.scanInterval))
        else
            return false, "unknown key"
        end
        return true
    end
    ConfigModule = fallback
end

if not CooldownRulesModule then
    local fallback = {}
    local function normalizeTrigger(trigger)
        if not trigger then return "SUCCESS" end
        trigger = strupper(trigger)
        if trigger == "SUCCESS" or trigger == "AURA_APPLIED" or trigger == "START" or trigger == "ANY" then
            return trigger
        end
        return "SUCCESS"
    end
    local function resolve(ctx, spellID)
        local dbRef = ctx.db
        if dbRef and dbRef.disabledSpells and dbRef.disabledSpells[spellID] then
            return nil, "disabled"
        end

        local source = "none"
        local cfg
        if not (dbRef and dbRef.removedBaseSpells and dbRef.removedBaseSpells[spellID]) then
            cfg = ctx.baseCooldowns and ctx.baseCooldowns[spellID]
            if cfg then
                source = "base"
            else
                local base = ctx.defaultSpellData and ctx.defaultSpellData[spellID]
                if base then
                    cfg = { cd = base.cd, trigger = "SUCCESS" }
                    source = "default"
                end
            end
        end
        if not cfg and dbRef and dbRef.customSpells then
            cfg = dbRef.customSpells[spellID]
            if cfg then
                source = "custom"
            end
        end

        local cd, trigger
        if type(cfg) == "number" then
            cd, trigger = cfg, "SUCCESS"
        elseif type(cfg) == "table" then
            cd, trigger = cfg.cd or cfg.duration, cfg.trigger or "SUCCESS"
        end

        local overrideApplied = false
        if dbRef and dbRef.spellOverrides and dbRef.spellOverrides[spellID] then
            local ov = dbRef.spellOverrides[spellID]
            if type(ov) == "number" then
                cd = ov
                overrideApplied = true
            elseif type(ov) == "table" then
                cd = ov.cd or cd
                trigger = ov.trigger or trigger
                overrideApplied = true
            end
        end

        if not cd or cd <= 0 then
            return nil, "missing"
        end

        return {
            spellID = spellID,
            cd = cd,
            trigger = normalizeTrigger(trigger),
            source = source,
            overrideApplied = overrideApplied,
            isItem = ctx.IsItemSpell and (ctx.IsItemSpell(spellID) and true or false) or false,
            sharedGroup = nil,
            resets = nil,
            modifiers = nil,
        }
    end
    function fallback.GetSpellConfig(ctx, spellID)
        return resolve(ctx, spellID)
    end
    function fallback.DescribeSpellRule(ctx, spellID)
        local rule, status = resolve(ctx, spellID)
        if not rule then
            return format("spell=%d status=%s", spellID, status or "missing")
        end
        local shared = rule.sharedGroup or "none"
        local resets = (type(rule.resets) == "table") and tostring(#rule.resets) or "0"
        local modifiers = (type(rule.modifiers) == "table") and tostring(#rule.modifiers) or "0"
        return format("spell=%d cd=%.1f trigger=%s source=%s override=%s item=%s shared=%s resets=%s modifiers=%s",
            rule.spellID, rule.cd, rule.trigger, rule.source or "none",
            rule.overrideApplied and "yes" or "no",
            rule.isItem and "yes" or "no",
            shared, resets, modifiers
        )
    end
    function fallback.ValidateMatrix(_, strictMode)
        if strictMode then
            return { "strict_matrix_checks=FAIL" }
        end
        return { "strict_matrix_checks=SKIP" }
    end
    function fallback.BuildParityReport(ctx)
        local checks = fallback.ValidateMatrix(ctx, true)
        return {
            "parity_source=fallback",
            "parity_status=PASS",
            checks[1] or "strict_matrix_checks=SKIP",
        }
    end
    CooldownRulesModule = fallback
end

if not TestModeModule then
    local fallback = {}
    local function BuildTestPool(ctx)
        ctx.WipeTable(ctx.STATE.testPool)
        if not ctx.baseCooldowns then
            return
        end
        for spellID, cfg in pairs(ctx.baseCooldowns) do
            local cd
            if type(cfg) == "number" then
                cd = cfg
            elseif type(cfg) == "table" then
                cd = cfg.cd or cfg.duration
            end
            if cd and cd > 0 then
                tinsert(ctx.STATE.testPool, { spellID = spellID, cd = cd })
            end
        end
    end
    local function RandomSpellEntry(ctx)
        if #ctx.STATE.testPool == 0 then
            BuildTestPool(ctx)
        end
        if #ctx.STATE.testPool == 0 then
            return nil
        end
        return ctx.STATE.testPool[math.random(1, #ctx.STATE.testPool)]
    end
    function fallback.PopulateRandomPlateTests(ctx)
        local now = GetTime()
        ctx.WipeTable(ctx.STATE.testByPlate)
        for plate in pairs(ctx.STATE.knownPlates) do
            if plate:IsShown() and plate:GetAlpha() > 0 then
                local records = {}
                local count = math.random(1, 4)
                for i = 1, count do
                    local pick = RandomSpellEntry(ctx)
                    if pick then
                        local spellName, _, tex = GetSpellInfo(pick.spellID)
                        local duration = math.max(4, math.floor(pick.cd * (0.3 + math.random())))
                        tinsert(records, {
                            spellID = pick.spellID,
                            spellName = spellName or ("Spell " .. tostring(pick.spellID)),
                            texture = tex or "Interface\\Icons\\INV_Misc_QuestionMark",
                            startAt = now,
                            expiresAt = now + duration,
                            duration = duration,
                            __ambiguous = false,
                        })
                    end
                end
                if #records > 0 then
                    ctx.STATE.testByPlate[plate] = records
                end
            end
        end
    end
    function fallback.RandomizeTestMode(ctx)
        if not ctx.STATE.testModeActive then return end
        fallback.PopulateRandomPlateTests(ctx)
        ctx.RefreshAllVisiblePlates()
    end
    function fallback.StopTestMode(ctx)
        ctx.STATE.testModeActive = false
        ctx.WipeTable(ctx.STATE.testByPlate)
        if ctx.STATE.ui and ctx.STATE.ui.status then
            ctx.STATE.ui.status:SetText("Test: OFF")
            ctx.STATE.ui.status:SetTextColor(1, 0.2, 0.2)
        end
        ctx.RefreshAllVisiblePlates()
    end
    function fallback.StartTestMode(ctx)
        if randomseed then
            randomseed(time())
        elseif math.randomseed then
            math.randomseed(time())
        end
        BuildTestPool(ctx)
        ctx.STATE.testModeActive = true
        fallback.PopulateRandomPlateTests(ctx)
        if ctx.STATE.ui and ctx.STATE.ui.status then
            ctx.STATE.ui.status:SetText("Test: ON")
            ctx.STATE.ui.status:SetTextColor(0.2, 1, 0.2)
        end
        ctx.RefreshAllVisiblePlates()
    end
    function fallback.ToggleTestMode(ctx)
        if ctx.STATE.testModeActive then
            fallback.StopTestMode(ctx)
            ctx.Print("test mode disabled")
        else
            fallback.StartTestMode(ctx)
            ctx.Print("test mode enabled")
        end
    end
    TestModeModule = fallback
end

if not SpellsModule then
    local fallback = {}
    function fallback.BuildSpellRowsData(ctx)
        local rows, seen = {}, {}
        local dbCtx = ctx.db or {}
        if ctx.baseCooldowns then
            for spellID in pairs(ctx.baseCooldowns) do
                local base = ctx.GetBaseSpellEntry(spellID)
                if base then
                    local name, icon = ctx.GetSpellOrItemInfo(spellID, false)
                    local ov = dbCtx.spellOverrides and dbCtx.spellOverrides[spellID]
                    local cd = base.cd
                    local trigger = base.trigger
                    if ov then
                        cd = ov.cd or cd
                        trigger = ctx.NormalizeTrigger(ov.trigger or trigger)
                    end
                    tinsert(rows, {
                        id = spellID,
                        name = name or tostring(spellID),
                        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                        cd = cd,
                        trigger = ctx.NormalizeTrigger(trigger),
                        overridden = ov and true or false,
                        fromBase = true,
                        categoryKey = "GENERAL",
                        isItem = false,
                        enabled = not (dbCtx.disabledSpells and dbCtx.disabledSpells[spellID]),
                        description = ctx.GetSpellDescSafe(spellID, false),
                    })
                    seen[spellID] = true
                end
            end
        end
        if dbCtx.customSpells then
            for spellID, data in pairs(dbCtx.customSpells) do
                if not seen[spellID] then
                    local customIsItem = ctx.IsItemSpell(spellID)
                    local name, icon = ctx.GetSpellOrItemInfo(spellID, customIsItem)
                    local ov = dbCtx.spellOverrides and dbCtx.spellOverrides[spellID]
                    local trigger = data.trigger or "SUCCESS"
                    local cd = data.cd
                    if ov then
                        cd = ov.cd or cd
                        trigger = ctx.NormalizeTrigger(ov.trigger or trigger)
                    end
                    tinsert(rows, {
                        id = spellID,
                        name = name or data.name or tostring(spellID),
                        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                        cd = cd,
                        trigger = ctx.NormalizeTrigger(trigger),
                        overridden = ov and true or false,
                        fromBase = false,
                        categoryKey = ctx.SpellCategory(spellID),
                        isItem = customIsItem,
                        enabled = not (dbCtx.disabledSpells and dbCtx.disabledSpells[spellID]),
                        description = ctx.GetSpellDescSafe(spellID, customIsItem),
                    })
                    seen[spellID] = true
                end
            end
        end
        if dbCtx.spellOverrides then
            for spellID, ov in pairs(dbCtx.spellOverrides) do
                if not seen[spellID] then
                    local ovIsItem = ctx.IsItemSpell(spellID)
                    local name, icon = ctx.GetSpellOrItemInfo(spellID, ovIsItem)
                    tinsert(rows, {
                        id = spellID,
                        name = name or tostring(spellID),
                        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                        cd = ov.cd,
                        trigger = ctx.NormalizeTrigger(ov.trigger),
                        overridden = true,
                        fromBase = false,
                        categoryKey = ctx.SpellCategory(spellID),
                        isItem = ovIsItem,
                        enabled = not (dbCtx.disabledSpells and dbCtx.disabledSpells[spellID]),
                        description = ctx.GetSpellDescSafe(spellID, ovIsItem),
                    })
                    seen[spellID] = true
                end
            end
        end
        for categoryKey, spellMap in pairs(ctx.DEFAULT_SPELLS_BY_CATEGORY) do
            for spellID, entry in pairs(spellMap) do
                if not seen[spellID] then
                    local cd = type(entry) == "table" and (entry.cd or entry.duration) or entry
                    local ov = dbCtx.spellOverrides and dbCtx.spellOverrides[spellID]
                    local trigger = "SUCCESS"
                    local isItem = ctx.DEFAULT_ITEM_IDS[spellID] and true or false
                    local name, icon = ctx.GetSpellOrItemInfo(spellID, isItem)
                    if ov and ov.trigger then
                        trigger = ctx.NormalizeTrigger(ov.trigger)
                    end
                    tinsert(rows, {
                        id = spellID,
                        name = name or tostring(spellID),
                        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                        cd = (ov and ov.cd) or cd,
                        trigger = trigger,
                        overridden = ov and true or false,
                        fromBase = true,
                        categoryKey = ctx.SpellCategory(spellID) or categoryKey,
                        isItem = isItem,
                        enabled = not (dbCtx.disabledSpells and dbCtx.disabledSpells[spellID]),
                        description = ctx.GetSpellDescSafe(spellID, isItem),
                    })
                    seen[spellID] = true
                end
            end
        end
        table.sort(rows, function(a, b)
            local an = string.lower(a.name or tostring(a.id))
            local bn = string.lower(b.name or tostring(b.id))
            if an == bn then
                return a.id < b.id
            end
            return an < bn
        end)
        return rows
    end
    SpellsModule = fallback
end

if not DebugModule then
    local fallback = {}
    function fallback.DebugLog(ctx, msg)
        if ctx.db and ctx.db.debug then
            ctx.Print("[debug] " .. tostring(msg))
        end
    end
    function fallback.ShowStats(ctx)
        local now = GetTime()
        local uptime = max(1, now - ctx.STATE.stats.startTime)
        local scansPerSec = ctx.STATE.stats.scanCount / uptime
        local avgScanMs = ctx.STATE.stats.scanCount > 0 and (ctx.STATE.stats.scanTotalMs / ctx.STATE.stats.scanCount) or 0
        local known = 0
        for _ in pairs(ctx.STATE.knownPlates) do known = known + 1 end
        local mapped = 0
        for _ in pairs(ctx.STATE.plateByGUID) do mapped = mapped + 1 end
        ctx.Print(format("scans/s=%.2f avgScanMs=%.3f knownPlates=%d visiblePlates=%d mappings=%d refreshes=%d", scansPerSec, avgScanMs, known, ctx.STATE.visibleCount, mapped, ctx.STATE.stats.refreshCount))
    end
    function fallback.PrintConfig(ctx)
        local d = ctx.db
        ctx.Print(format("anchor=%s anchorTo=%s x=%d y=%d size=%d font=%d maxRow=%d maxIcons=%d grow=%s spacing=%d scan=%.2f", d.anchorPoint, d.anchorTo, d.xOffset, d.yOffset, d.iconSize, d.fontSize, d.maxIconsPerRow, d.maxIcons, d.growthDirection, d.iconSpacing, d.scanInterval))
    end
    DebugModule = fallback
end

if not SpecModule then
    local fallback = {}
    function fallback.GetSpecFromSpellID()
        return nil
    end
    function fallback.UpdateFromCombatEvent()
        return false
    end
    function fallback.PruneExpiredHints()
        return false
    end
    function fallback.UpdateFromUnitAura()
        return false
    end
    function fallback.UpdateFromInspectTalents()
        return false
    end
    SpecModule = fallback
end

if not StateModule then
    StateModule = {
        BuildInitialState = function()
            return {
                knownPlates = {},
                plateMeta = {},
                visiblePlatesByName = {},
                visibleCount = 0,
                plateByGUID = {},
                guidByPlate = {},
                candidatesByName = {},
                pendingBindByGUID = {},
                cooldownsByGUID = {},
                fallbackCooldownsByName = {},
                recentEventByUnit = {},
                recentUnitSucceededByUnit = {},
                specByGUID = {},
                specByName = {},
                classByGUID = {},
                classByName = {},
                reactionByGUID = {},
                reactionByName = {},
                reactionByPlate = {},
                reactionSourceByGUID = {},
                reactionSourceByName = {},
                reactionSourceByPlate = {},
                inspectUnitByGUID = {},
                inspectRequestAtByGUID = {},
                inspectQueue = {},
                inspectQueuedByGUID = {},
                inspectCurrent = nil,
                inspectOutOfRangeSince = {},
                matrixLog = {},
                stats = {
                    scanCount = 0,
                    scanTotalMs = 0,
                    refreshCount = 0,
                    lastScanChildren = 0,
                    startTime = 0,
                    resolverBindAttempts = 0,
                    resolverBindSuccess = 0,
                    pendingBindQueued = 0,
                    pendingBindResolved = 0,
                    pendingBindExpired = 0,
                    pendingBindPeak = 0,
                    onUpdateCount = 0,
                    onUpdateTotalMs = 0,
                },
                scanAccum = 0,
                iconAccum = 0,
                groupAccum = 0,
                testAccum = 0,
                specAccum = 0,
                inspectAccum = 0,
                testModeActive = false,
                testPool = {},
                testPoolByType = {},
                testByPlate = {},
                ui = {},
            }
        end,
    }
end

if not EventsModule then
    EventsModule = {
        HandleEvent = function(ctx, event, ...)
            if ctx and ctx.LegacyHandleEvent then
                return ctx.LegacyHandleEvent(event, ...)
            end
        end,
    }
end

if not MigrationModule then
    MigrationModule = {
        GetCurrentSchemaVersion = function() return 0 end,
        ApplyProfileMigrations = function() return 0 end,
    }
end

if not UIOptionsModule then
    UIOptionsModule = {
        BuildOptionsPanel = function()
        end,
    }
end

if not BootstrapModule then
    BootstrapModule = {
        BuildInternalAPI = function(ctx)
            return {
                GetDB = ctx.GetDB,
                GetState = function() return ctx.STATE end,
                StartCooldown = ctx.StartCooldown,
                ResetAllCooldowns = ctx.ResetAllCooldowns,
                RefreshAllVisiblePlates = ctx.RefreshAllVisiblePlates,
                ResolveUnit = ctx.ResolveUnit,
                ResolveGroupTargets = ctx.ResolveGroupTargets,
                ScanNameplates = ctx.ScanNameplates,
                GetCooldownRule = ctx.GetCooldownRule or ctx.GetSpellConfig,
                GetSpellConfig = ctx.GetSpellConfig,
                DebugSpellRule = ctx.DebugSpellRule,
                SetUnitSpecHint = ctx.SetUnitSpecHint,
                SetPersistSpecHints = ctx.SetPersistSpecHints,
                RunMatrixSelfTests = ctx.RunMatrixSelfTests,
                RunMatrixParityReport = ctx.RunMatrixParityReport,
                RunTriggerParityReport = ctx.RunTriggerParityReport,
                RunRegressionHarness = ctx.RunRegressionHarness,
                RunFullValidation = ctx.RunFullValidation,
                RunDiagnosticReport = ctx.RunDiagnosticReport,
                RunPerformanceReport = ctx.RunPerformanceReport,
                RunReactionMappingReport = ctx.RunReactionMappingReport,
                RunSnapshotFixtureCheck = ctx.RunSnapshotFixtureCheck,
                RunExportConfigPayload = ctx.RunExportConfigPayload,
                RunImportConfigPayload = ctx.RunImportConfigPayload,
                RunExportDefaultDatasetWithNames = ctx.RunExportDefaultDatasetWithNames,
                RunExportShareCode = ctx.RunExportShareCode,
                RunImportShareCode = ctx.RunImportShareCode,
                RunStartupHealthCheck = ctx.RunStartupHealthCheck,
                GetMatrixActionLog = ctx.GetMatrixActionLog,
                ClearMatrixActionLog = ctx.ClearMatrixActionLog,
                BuildSpellRowsData = ctx.BuildSpellRowsData,
                NotifySpellsChanged = ctx.NotifySpellsChanged,
            }
        end,
    }
end

local GetSpellOrItemInfo = TooltipModule.GetSpellOrItemInfo
local BuildSpellTooltipText = TooltipModule.BuildSpellTooltipText
local BuildSpellPanelDesc = TooltipModule.BuildSpellPanelDesc
GetSpellDescSafe = TooltipModule.GetSpellDescSafe
local DataModule = type(IcicleData) == "table" and IcicleData or nil

if not DataModule then
    DataModule = {
        SPELL_CATEGORY_ORDER = {
            "GENERAL", "WARRIOR", "PALADIN", "HUNTER", "ROGUE",
            "PRIEST", "DEATH_KNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
        },
        SPELL_CATEGORY_LABELS = {
            GENERAL = "General",
            WARRIOR = "Warrior",
            PALADIN = "Paladin",
            HUNTER = "Hunter",
            ROGUE = "Rogue",
            PRIEST = "Priest",
            DEATH_KNIGHT = "Death Knight",
            SHAMAN = "Shaman",
            MAGE = "Mage",
            WARLOCK = "Warlock",
            DRUID = "Druid",
        },
        DEFAULT_SPELLS_BY_CATEGORY = {
            GENERAL = {
                [7744] = 120, [20549] = 120, [20572] = 120, [20589] = 60, [20594] = 120,
                [26297] = 180, [28730] = 120, [28880] = 180, [47088] = 180, [50356] = 120,
                [50364] = 60, [50726] = 120, [51377] = 120, [58984] = 120, [59752] = 120,
            },
            WARRIOR = {
                [72] = 12, [676] = 60, [871] = 300, [1680] = 10, [1719] = 300, [2565] = 60,
                [3411] = 30, [5246] = 120, [6552] = 10, [11578] = 20, [12292] = 120, [12328] = 30,
                [12809] = 30, [12975] = 180, [18499] = 30, [20252] = 25, [23920] = 10, [30335] = 4,
                [46924] = 90, [46968] = 17, [47486] = 5, [55694] = 180, [57755] = 60, [60970] = 45,
                [64382] = 300, [65932] = 300,
            },
            PALADIN = {
                [498] = 180, [642] = 300, [1038] = 120, [1044] = 25, [6940] = 120, [10278] = 180,
                [10308] = 40, [20066] = 60, [20216] = 120, [31789] = 8, [31821] = 120, [31842] = 180,
                [31884] = 180, [35395] = 4, [48788] = 1200, [48817] = 30, [48819] = 8, [48825] = 5,
                [48827] = 30, [48952] = 8, [53385] = 10, [53595] = 6, [54428] = 60, [62124] = 8,
                [64205] = 120,
            },
            HUNTER = {
                [3045] = 300, [5384] = 25, [13809] = 28, [14311] = 28, [19263] = 90, [19503] = 30,
                [19574] = 120, [19577] = 60, [23989] = 180, [34490] = 20, [34600] = 28, [49012] = 60,
                [49050] = 8, [49055] = 28, [49067] = 28, [53209] = 10, [53271] = 60, [53476] = 30,
                [53480] = 60, [60192] = 28, [63672] = 22,
            },
            ROGUE = {
                [1766] = 10, [1776] = 10, [1856] = 120, [2094] = 120, [5277] = 180, [8643] = 20,
                [11305] = 180, [13750] = 180, [13877] = 120, [14177] = 180, [14185] = 300, [14278] = 20,
                [31224] = 60, [36554] = 20, [48659] = 10, [51690] = 75, [51713] = 60, [51722] = 60,
                [57934] = 30,
            },
            PRIEST = {
                [586] = 30, [6346] = 180, [10060] = 96, [10890] = 27, [14751] = 144, [15487] = 45,
                [33206] = 144, [34433] = 300, [47585] = 75, [47788] = 180, [48086] = 180, [48158] = 12,
                [48173] = 120, [53007] = 8, [64044] = 120, [64843] = 480, [64901] = 360,
            },
            DEATH_KNIGHT = {
                [42650] = 360, [45529] = 60, [46584] = 30, [47481] = 60, [47482] = 20, [47528] = 10,
                [47568] = 300, [48707] = 45, [48743] = 120, [48792] = 120, [48982] = 30, [49005] = 180,
                [49016] = 180, [49028] = 60, [49039] = 120, [49203] = 60, [49206] = 180, [49222] = 60,
                [49576] = 25, [49796] = 120, [49916] = 120, [51052] = 120, [51271] = 60, [51411] = 8,
                [55233] = 60,
            },
            SHAMAN = {
                [2484] = 10.5, [2825] = 300, [8177] = 13.5, [16166] = 180, [16188] = 120, [16190] = 300,
                [17364] = 8, [20608] = 1800, [30823] = 60, [32182] = 300, [49271] = 6, [51514] = 45,
                [51533] = 180, [55198] = 180, [57994] = 5, [58582] = 21, [59159] = 35, [60043] = 8,
                [60103] = 6, [61301] = 6, [61657] = 10,
            },
            MAGE = {
                [66] = 180, [1953] = 15, [2139] = 24, [11958] = 384, [12042] = 84, [12043] = 84,
                [12051] = 240, [12472] = 144, [29977] = 120, [31687] = 144, [33395] = 25, [42917] = 20,
                [42945] = 30, [42950] = 20, [42987] = 120, [43010] = 30, [43012] = 30, [43039] = 24,
                [44572] = 30, [45438] = 240, [55342] = 180,
            },
            WARLOCK = {
                [17928] = 32, [17962] = 10, [18708] = 180, [19647] = 24, [47193] = 60, [47241] = 126,
                [47827] = 15, [47847] = 20, [47860] = 120, [47891] = 30, [48011] = 8, [48020] = 30,
                [59164] = 8, [59172] = 12, [61290] = 15,
            },
            DRUID = {
                [5209] = 180, [5229] = 60, [6795] = 8, [8983] = 30, [16979] = 15, [17116] = 180,
                [18562] = 13, [22812] = 60, [22842] = 180, [29166] = 180, [33357] = 144, [33831] = 180,
                [48447] = 480, [48477] = 600, [49376] = 15, [49802] = 10, [50213] = 30, [50334] = 180,
                [53201] = 60, [53312] = 60, [61336] = 180, [61384] = 20,
            },
        },
        DEFAULT_ITEM_IDS = {
            [47088] = true,
            [50356] = true,
            [50364] = true,
            [50726] = true,
            [51377] = true,
        },
    }
    DataModule.DEFAULT_SPELL_DATA = {}
    DataModule.BASE_COOLDOWNS = {}
    for categoryKey, spellMap in pairs(DataModule.DEFAULT_SPELLS_BY_CATEGORY) do
        for spellID, entry in pairs(spellMap) do
            local cd = type(entry) == "table" and (entry.cd or entry.duration) or entry
            if not DataModule.DEFAULT_SPELL_DATA[spellID] then
                DataModule.DEFAULT_SPELL_DATA[spellID] = { cd = cd, category = categoryKey }
            end
            if DataModule.BASE_COOLDOWNS[spellID] == nil then
                DataModule.BASE_COOLDOWNS[spellID] = cd
            end
        end
    end
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

local DEBUG_CONTEXT = {
    STATE = STATE,
    db = nil,
    Print = Print,
}

local function SyncDebugContext()
    DEBUG_CONTEXT.db = db
end

local function DebugLog(msg)
    SyncDebugContext()
    return DebugModule.DebugLog(DEBUG_CONTEXT, msg)
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

local function AddMatrixActionLog(line)
    if not db or not db.matrixLogEnabled then return end
    local maxEntries = max(5, min(200, tonumber(db.matrixLogMaxEntries) or 30))
    local stamp = date and date("%H:%M:%S") or tostring(floor(GetTime()))
    tinsert(STATE.matrixLog, "[" .. stamp .. "] " .. tostring(line))
    while #STATE.matrixLog > maxEntries do
        tremove(STATE.matrixLog, 1)
    end
end

local function ClearMatrixActionLog()
    WipeTable(STATE.matrixLog)
end

local function GetMatrixActionLog()
    local out = {}
    for i = 1, #STATE.matrixLog do
        out[i] = STATE.matrixLog[i]
    end
    return out
end

local function EventMatchesTrigger(eventType, trigger)
    if trigger == "SUCCESS" then
        return eventType == "SPELL_CAST_SUCCESS"
    elseif trigger == "AURA_APPLIED" then
        return eventType == "SPELL_AURA_APPLIED"
    elseif trigger == "START" then
        return eventType == "SPELL_CAST_START"
    elseif trigger == "ANY" then
        return eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_CAST_START"
    end
    return eventType == "SPELL_CAST_SUCCESS"
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
    DebugLog = DebugLog,
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

local function RemoveGUIDBinding(guid)
    SyncResolverContext()
    return ResolverModule.RemoveGUIDBinding(RESOLVER_CONTEXT, guid)
end

local function SetBinding(guid, plate, conf, reason, sourceName)
    SyncResolverContext()
    return ResolverModule.SetBinding(RESOLVER_CONTEXT, guid, plate, conf, reason, sourceName)
end

local function DecayAndPurgeMappings()
    SyncResolverContext()
    return ResolverModule.DecayAndPurgeMappings(RESOLVER_CONTEXT)
end

local function MigrateNameFallbackToGUID(name, guid)
    SyncResolverContext()
    return ResolverModule.MigrateNameFallbackToGUID(RESOLVER_CONTEXT, name, guid)
end

local function RegisterCandidate(name, guid)
    SyncResolverContext()
    return ResolverModule.RegisterCandidate(RESOLVER_CONTEXT, name, guid)
end

local function TryBindByName(guid, name, baseConf, reason, spellName, eventTime)
    SyncResolverContext()
    return ResolverModule.TryBindByName(RESOLVER_CONTEXT, guid, name, baseConf, reason, spellName, eventTime)
end

local function RegisterPendingBind(guid, name, spellName, eventTime)
    SyncResolverContext()
    if ResolverModule.RegisterPendingBind then
        return ResolverModule.RegisterPendingBind(RESOLVER_CONTEXT, guid, name, spellName, eventTime)
    end
end

local function TryResolvePendingBinds()
    SyncResolverContext()
    if ResolverModule.TryResolvePendingBinds then
        return ResolverModule.TryResolvePendingBinds(RESOLVER_CONTEXT)
    end
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

local function CollectDisplayRecords(meta)
    SyncRenderContext()
    return RenderModule.CollectDisplayRecords(RENDER_CONTEXT, meta)
end

local function RenderPlate(meta)
    SyncRenderContext()
    return RenderModule.RenderPlate(RENDER_CONTEXT, meta)
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
    debugprofilestop = debugprofilestop,
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
    MigrateNameFallbackToGUID = MigrateNameFallbackToGUID,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    DebugLog = DebugLog,
    LogMatrixAction = AddMatrixActionLog,
    IsItemSpell = IsItemSpell,
    SpellCategory = SpellCategory,
    GetSourceClassCategory = GetSourceClassCategory,
}

local function StartCooldown(sourceGUID, sourceName, spellID, spellName, eventType)
    TRACKING_CONTEXT.db = db
    TrackingModule.StartCooldown(TRACKING_CONTEXT, sourceGUID, sourceName, spellID, spellName, eventType)
end
local function ResetAllCooldowns(silent)
    WipeTable(STATE.cooldownsByGUID)
    WipeTable(STATE.fallbackCooldownsByName)
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

local function DebugSpellRule(idText)
    local sid = tonumber(idText)
    if not sid then
        Print("usage: rule <spellID>")
        return
    end
    SyncCooldownRulesContext()
    Print(CooldownRulesModule.DescribeSpellRule(COOLDOWN_RULES_CONTEXT, sid))
end

local function DescribeSpellRuleByID(spellID, sourceGUID, sourceName)
    SyncCooldownRulesContext()
    return CooldownRulesModule.DescribeSpellRule(COOLDOWN_RULES_CONTEXT, spellID, sourceGUID, sourceName)
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
        elseif type(v) == "string" then
            STATE.specByGUID[k] = {
                spec = v,
                confidence = 0.9,
                lastSeen = GetTime(),
                source = "saved-legacy",
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
        elseif type(v) == "string" then
            STATE.specByName[k] = {
                spec = v,
                confidence = 0.9,
                lastSeen = GetTime(),
                source = "saved-legacy",
            }
        end
    end
end

local function SetPersistSpecHints(enabled)
    if not db then return end
    db.persistSpecHints = enabled and true or false
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    if db.persistSpecHints then
        WipeTable(db.specHintsByGUID)
        WipeTable(db.specHintsByName)
        for k, v in pairs(STATE.specByGUID) do
            db.specHintsByGUID[k] = v
        end
        for k, v in pairs(STATE.specByName) do
            db.specHintsByName[k] = v
        end
    else
        WipeTable(db.specHintsByGUID)
        WipeTable(db.specHintsByName)
    end
end

local function SetUnitSpecHint(unitKey, specKey)
    if not unitKey or unitKey == "" then
        return false, "unit key required"
    end
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    if not specKey or specKey == "" then
        STATE.specByGUID[unitKey] = nil
        STATE.specByName[unitKey] = nil
        db.specHintsByGUID[unitKey] = nil
        db.specHintsByName[unitKey] = nil
        return true
    end
    local normalized = strlower(tostring(specKey))
    local entry = {
        spec = normalized,
        confidence = 1.0,
        lastSeen = GetTime(),
        source = "manual",
    }
    STATE.specByGUID[unitKey] = entry
    STATE.specByName[unitKey] = entry
    if db and db.persistSpecHints then
        db.specHintsByGUID[unitKey] = normalized
        db.specHintsByName[unitKey] = normalized
    else
        db.specHintsByGUID[unitKey] = nil
        db.specHintsByName[unitKey] = nil
    end
    return true
end

local RunFullValidation
local RunStartupHealthCheck
local RunPerformanceReport
local RunReactionMappingReport
local RunSnapshotFixtureCheck
local RunExportConfigPayload
local RunImportConfigPayload
local RunExportDefaultDatasetWithNames
local RunExportShareCode
local RunImportShareCode
local NotifySpellsChanged
local GetBaseSpellEntry
local ProcessInspectQueue

local SNAPSHOT_EXPECTATIONS = {
    { id = "matrix_shared_edges", prefix = "matrix_basic:coverage_shared_edges=", contains = "=PASS" },
    { id = "matrix_reset_entries", prefix = "matrix_basic:coverage_reset_entries=", contains = "=PASS" },
    { id = "matrix_alias_chain", prefix = "matrix_basic:alias_chain=PASS", contains = nil },
    { id = "regression_snapshot", prefix = "regression:regression_snapshot=PASS", contains = nil },
    { id = "trigger_parity", prefix = "trigger_parity:trigger_parity_status=PASS", contains = nil },
}

local function BuildUnitSpecResolver(stateRef)
    return function(sourceGUID, sourceName)
        local e
        if sourceGUID then e = stateRef.specByGUID[sourceGUID] end
        if not e and sourceName then e = stateRef.specByName[sourceName] end
        if type(e) == "table" then return e.spec end
        return e
    end
end

local function BuildTestRuleContext(fakeDB, stateRef)
    return {
        db = fakeDB,
        baseCooldowns = BASE_COOLDOWNS,
        defaultSpellData = DEFAULT_SPELL_DATA,
        STATE = stateRef,
        IsItemSpell = IsItemSpell,
        GetUnitSpec = BuildUnitSpecResolver(stateRef),
    }
end

local function BuildTestTrackingContext(stateRef, testRuleContext, matrixLogCollector)
    return {
        STATE = stateRef,
        spellDedupeWindow = ConstantsModule.SPELL_DEDUPE_WINDOW,
        GetCooldownRule = function(spellID, sourceGUID, sourceName)
            return CooldownRulesModule.GetSpellConfig(testRuleContext, spellID, sourceGUID, sourceName)
        end,
        GetSharedCooldownTargets = function(spellID)
            if CooldownRulesModule.GetSharedTargetsForSpell then
                return CooldownRulesModule.GetSharedTargetsForSpell(testRuleContext, spellID)
            end
        end,
        EventMatchesTrigger = EventMatchesTrigger,
        TryBindByName = function() return false end,
        RegisterPendingBind = function() end,
        MigrateNameFallbackToGUID = function() end,
        RefreshAllVisiblePlates = function() end,
        DebugLog = function() end,
        LogMatrixAction = matrixLogCollector,
    }
end

local function RunMatrixSelfTests()
    local testState = {
        cooldownsByGUID = {},
        fallbackCooldownsByName = {},
        recentEventByUnit = {},
        specByGUID = {},
        specByName = {},
    }
    local fakeDB = {
        disabledSpells = {},
        removedBaseSpells = {},
        spellOverrides = {},
        customSpells = {},
    }
    local testRuleContext = BuildTestRuleContext(fakeDB, testState)
    local testTrackingContext = BuildTestTrackingContext(testState, testRuleContext, nil)

    local function hasSpell(store, unitKey, spellID)
        return store[unitKey] and store[unitKey][spellID] and true or false
    end

    local strictMode = db and db.matrixStrictSelfTests and true or false
    local results = {}

    TrackingModule.StartCooldown(testTrackingContext, "GUID-A", "Tester", 51377, "PvP Trinket", "SPELL_CAST_SUCCESS")
    local trinketOK = hasSpell(testState.cooldownsByGUID, "GUID-A", 51377)
        and hasSpell(testState.cooldownsByGUID, "GUID-A", 7744)
        and hasSpell(testState.cooldownsByGUID, "GUID-A", 59752)
    tinsert(results, "shared_trinket=" .. (trinketOK and "PASS" or "FAIL"))

    TrackingModule.StartCooldown(testTrackingContext, "GUID-B", "HunterX", 3045, "Rapid Fire", "SPELL_CAST_SUCCESS")
    local beforeReset = hasSpell(testState.cooldownsByGUID, "GUID-B", 3045)
    TrackingModule.StartCooldown(testTrackingContext, "GUID-B", "HunterX", 23989, "Readiness", "SPELL_CAST_SUCCESS")
    local afterReset = hasSpell(testState.cooldownsByGUID, "GUID-B", 3045)
    local readinessOK = beforeReset and (not afterReset) and hasSpell(testState.cooldownsByGUID, "GUID-B", 23989)
    tinsert(results, "reset_readiness=" .. (readinessOK and "PASS" or "FAIL"))

    testState.specByName["HunterSpec"] = "survival"
    local rule60192 = CooldownRulesModule.GetSpellConfig(testRuleContext, 60192, nil, "HunterSpec")
    local modifierOK = rule60192 and abs((rule60192.cd or 0) - 22) < 0.001
    tinsert(results, "modifier_survival=" .. (modifierOK and "PASS" or "FAIL"))

    if CooldownRulesModule.ValidateMatrix then
        local matrixChecks = CooldownRulesModule.ValidateMatrix(testRuleContext, strictMode)
        if type(matrixChecks) == "table" then
            for i = 1, #matrixChecks do
                tinsert(results, matrixChecks[i])
            end
        end
    end

    return results
end

local function RunMatrixParityReport()
    local testState = {
        cooldownsByGUID = {},
        fallbackCooldownsByName = {},
        recentEventByUnit = {},
        specByGUID = {},
        specByName = {},
    }
    local fakeDB = {
        disabledSpells = {},
        removedBaseSpells = {},
        spellOverrides = {},
        customSpells = {},
    }
    local testRuleContext = BuildTestRuleContext(fakeDB, testState)
    if not CooldownRulesModule.BuildParityReport then
        return { "parity_status=FAIL", "parity_error=build_parity_report_unavailable" }
    end
    return CooldownRulesModule.BuildParityReport(testRuleContext)
end

local function RunTriggerParityReport()
    local testState = {
        cooldownsByGUID = {},
        fallbackCooldownsByName = {},
        recentEventByUnit = {},
        specByGUID = {},
        specByName = {},
    }
    local fakeDB = {
        disabledSpells = {},
        removedBaseSpells = {},
        spellOverrides = {},
        customSpells = {},
    }
    local testRuleContext = BuildTestRuleContext(fakeDB, testState)
    if not CooldownRulesModule.BuildTriggerParityReport then
        return { "trigger_parity_status=FAIL", "trigger_parity_error=build_trigger_parity_report_unavailable" }
    end
    return CooldownRulesModule.BuildTriggerParityReport(testRuleContext)
end

local function RunDiagnosticReport()
    local out = {}
    local total, disabledCount = 0, 0
    local seen = {}
    if DEFAULT_SPELL_DATA then
        for spellID in pairs(DEFAULT_SPELL_DATA) do
            seen[spellID] = true
            total = total + 1
        end
    end
    if db and db.customSpells then
        for spellID in pairs(db.customSpells) do
            if not seen[spellID] then
                seen[spellID] = true
                total = total + 1
            end
        end
    end
    if db and db.spellOverrides then
        for spellID in pairs(db.spellOverrides) do
            if not seen[spellID] then
                seen[spellID] = true
                total = total + 1
            end
        end
    end
    if db and db.removedBaseSpells then
        for spellID in pairs(db.removedBaseSpells) do
            if seen[spellID] then
                total = total - 1
                seen[spellID] = nil
            end
        end
    end
    if db and db.disabledSpells then
        for spellID in pairs(db.disabledSpells) do
            if seen[spellID] then
                disabledCount = disabledCount + 1
            end
        end
    end
    local enabledCount = max(0, total - disabledCount)

    tinsert(out, "diagnostic_version=" .. tostring(VERSION))
    tinsert(out, "diagnostic_time=" .. date("%Y-%m-%d %H:%M:%S"))
    tinsert(out, "diagnostic_zone=enabled:" .. (IsEnabledInCurrentZone() and "yes" or "no"))
    tinsert(out, "diagnostic_spells=total:" .. tostring(total) .. ",enabled:" .. tostring(enabledCount) .. ",disabled:" .. tostring(disabledCount))
    tinsert(out, "diagnostic_settings=arena:" .. (db and db.arena and "on" or "off")
        .. ",bg:" .. (db and db.battleground and "on" or "off")
        .. ",world:" .. (db and db.field and "on" or "off")
        .. ",showTooltips:" .. (db and db.showTooltips and "on" or "off")
        .. ",strict:" .. (db and db.matrixStrictSelfTests and "on" or "off"))
    tinsert(out, "diagnostic_mapping=castWindow:" .. tostring(db and db.castMatchWindow or 0)
        .. ",minConf:" .. tostring(db and db.minConfidence or 0)
        .. ",ttl:" .. tostring(db and db.mappingTTL or 0))

    local startup = RunStartupHealthCheck()
    if type(startup) == "table" then
        tinsert(out, "diagnostic_section=startup_health")
        for i = 1, #startup do
            tinsert(out, "startup:" .. tostring(startup[i]))
        end
    end

    local full = RunFullValidation()
    if type(full) == "table" then
        tinsert(out, "diagnostic_section=full_validation")
        for i = 1, #full do
            tinsert(out, "validation:" .. tostring(full[i]))
        end
    end

    local perf = RunPerformanceReport()
    if type(perf) == "table" then
        tinsert(out, "diagnostic_section=performance")
        for i = 1, #perf do
            tinsert(out, "performance:" .. tostring(perf[i]))
        end
    end

    return out
end

local function RunRegressionHarness()
    local testState = {
        cooldownsByGUID = {},
        fallbackCooldownsByName = {},
        recentEventByUnit = {},
        specByGUID = {},
        specByName = {},
        matrixLog = {},
    }
    local fakeDB = {
        disabledSpells = {},
        removedBaseSpells = {},
        spellOverrides = {},
        customSpells = {},
        specDetectEnabled = true,
        specHintTTL = 300,
        persistSpecHints = false,
        matrixStrictSelfTests = false,
    }
    local testRuleContext = BuildTestRuleContext(fakeDB, testState)
    local testSpecContext = {
        STATE = testState,
        db = fakeDB,
    }
    local testTrackingContext = BuildTestTrackingContext(testState, testRuleContext, function(line)
        tinsert(testState.matrixLog, tostring(line))
    end)

    local sequence = {
        { guid = "R1", name = "HunterOne", spell = 3045, ev = "SPELL_CAST_SUCCESS" }, -- Rapid Fire
        { guid = "R1", name = "HunterOne", spell = 23989, ev = "SPELL_CAST_SUCCESS" }, -- Readiness reset
        { guid = "R2", name = "UndeadTwo", spell = 51377, ev = "SPELL_CAST_SUCCESS" }, -- Trinket shared
        { guid = "R3", name = "MageThree", spell = 45438, ev = "SPELL_CAST_SUCCESS" }, -- Ice Block
        { guid = "R3", name = "MageThree", spell = 11958, ev = "SPELL_CAST_SUCCESS" }, -- reset Ice Block
    }

    for i = 1, #sequence do
        local s = sequence[i]
        SpecModule.UpdateFromCombatEvent(testSpecContext, s.spell, s.guid, s.name)
        TrackingModule.StartCooldown(testTrackingContext, s.guid, s.name, s.spell, GetSpellInfo(s.spell), s.ev)
    end

    local function collectSnapshotForGUID(guid)
        local bySpell = testState.cooldownsByGUID[guid] or {}
        local ids = {}
        for spellID in pairs(bySpell) do
            tinsert(ids, spellID)
        end
        table.sort(ids)
        local out = {}
        for i = 1, #ids do out[i] = tostring(ids[i]) end
        return table.concat(out, ",")
    end

    local snapR1 = collectSnapshotForGUID("R1")
    local snapR2 = collectSnapshotForGUID("R2")
    local snapR3 = collectSnapshotForGUID("R3")
    local snapshot = "R1=" .. snapR1 .. ";R2=" .. snapR2 .. ";R3=" .. snapR3
    local expected = "R1=23989;R2=7744,51377,59752;R3=11958"
    local ok = snapshot == expected

    return {
        "regression_snapshot=" .. (ok and "PASS" or "FAIL"),
        "regression_expected=" .. expected,
        "regression_actual=" .. snapshot,
        "regression_log_entries=" .. tostring(#testState.matrixLog),
    }
end

local function SummarizeValidation(lines)
    local pass, fail = 0, 0
    if type(lines) ~= "table" then
        return 0, 0
    end
    for i = 1, #lines do
        local line = tostring(lines[i] or "")
        if strfind(line, "=PASS", 1, true) then
            pass = pass + 1
        elseif strfind(line, "=FAIL", 1, true) then
            fail = fail + 1
        end
    end
    return pass, fail
end

RunSnapshotFixtureCheck = function(fullValidationLines)
    local out = {}
    local lines = fullValidationLines or {}
    local fail = 0
    for i = 1, #SNAPSHOT_EXPECTATIONS do
        local expected = SNAPSHOT_EXPECTATIONS[i]
        local ok = false
        for j = 1, #lines do
            local line = tostring(lines[j] or "")
            if strfind(line, expected.prefix, 1, true) == 1 then
                if (not expected.contains) or strfind(line, expected.contains, 1, true) then
                    ok = true
                    break
                end
            end
        end
        if not ok then
            fail = fail + 1
        end
        tinsert(out, "snapshot_" .. tostring(expected.id) .. "=" .. (ok and "PASS" or "FAIL"))
    end
    tinsert(out, "snapshot_status=" .. (fail == 0 and "PASS" or "FAIL"))
    return out
end

RunPerformanceReport = function()
    local out = {}
    local stats = STATE and STATE.stats or {}
    local updates = tonumber(stats.onUpdateCount) or 0
    local avgUpdateMs = updates > 0 and ((tonumber(stats.onUpdateTotalMs) or 0) / updates) or 0
    local binds = tonumber(stats.resolverBindAttempts) or 0
    local bindSuccess = tonumber(stats.resolverBindSuccess) or 0
    local bindRate = binds > 0 and (bindSuccess / binds * 100) or 0
    local pendingNow = 0
    if STATE and STATE.pendingBindByGUID then
        for _ in pairs(STATE.pendingBindByGUID) do pendingNow = pendingNow + 1 end
    end

    tinsert(out, "perf_scan_count=" .. tostring(stats.scanCount or 0))
    tinsert(out, "perf_scan_avg_ms=" .. format("%.3f", (stats.scanCount or 0) > 0 and ((stats.scanTotalMs or 0) / stats.scanCount) or 0))
    tinsert(out, "perf_onupdate_count=" .. tostring(updates))
    tinsert(out, "perf_onupdate_avg_ms=" .. format("%.3f", avgUpdateMs))
    tinsert(out, "perf_resolver_bind_attempts=" .. tostring(binds))
    tinsert(out, "perf_resolver_bind_success=" .. tostring(bindSuccess))
    tinsert(out, "perf_resolver_bind_rate=" .. format("%.1f%%", bindRate))
    tinsert(out, "perf_pending_now=" .. tostring(pendingNow))
    tinsert(out, "perf_pending_peak=" .. tostring(stats.pendingBindPeak or 0))
    tinsert(out, "perf_pending_queued=" .. tostring(stats.pendingBindQueued or 0))
    tinsert(out, "perf_pending_resolved=" .. tostring(stats.pendingBindResolved or 0))
    tinsert(out, "perf_pending_expired=" .. tostring(stats.pendingBindExpired or 0))
    return out
end

RunReactionMappingReport = function()
    local out = {}
    local mapped = STATE and STATE.guidByPlate or nil
    if type(mapped) ~= "table" then
        tinsert(out, "reaction_map_status=FAIL")
        tinsert(out, "reaction_map_error=no_state")
        return out
    end

    local rows = {}
    for plate, bind in pairs(mapped) do
        if plate and bind and bind.guid then
            local meta = STATE.plateMeta and STATE.plateMeta[plate] or nil
            local name = (meta and meta.name) or bind.sourceName or "?"
            local guid = bind.guid
            local guidReaction = STATE.reactionByGUID and STATE.reactionByGUID[guid] or nil
            local guidSource = STATE.reactionSourceByGUID and STATE.reactionSourceByGUID[guid] or nil
            local nameReaction = STATE.reactionByName and STATE.reactionByName[name] or nil
            local nameSource = STATE.reactionSourceByName and STATE.reactionSourceByName[name] or nil
            local plateReaction = STATE.reactionByPlate and STATE.reactionByPlate[plate] or nil
            local plateSource = STATE.reactionSourceByPlate and STATE.reactionSourceByPlate[plate] or nil

            local effectiveReaction = guidReaction or nameReaction or plateReaction or "unknown"
            local effectiveSource = guidSource or nameSource or plateSource or "unknown"
            rows[#rows + 1] = {
                name = tostring(name),
                guid = tostring(guid),
                conf = tonumber(bind.conf) or 0,
                reason = tostring(bind.reason or "?"),
                effectiveReaction = tostring(effectiveReaction),
                effectiveSource = tostring(effectiveSource),
                guidReaction = guidReaction,
                guidSource = guidSource,
                nameReaction = nameReaction,
                nameSource = nameSource,
                plateReaction = plateReaction,
                plateSource = plateSource,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.name == b.name then
            return a.guid < b.guid
        end
        return a.name < b.name
    end)

    tinsert(out, "reaction_map_count=" .. tostring(#rows))
    for i = 1, #rows do
        local row = rows[i]
        tinsert(out, string.format(
            "reaction_map[%d]=name=%s guid=%s bind=%.2f/%s effective=%s(%s) guid=%s(%s) name=%s(%s) plate=%s(%s)",
            i,
            row.name,
            row.guid,
            row.conf,
            row.reason,
            row.effectiveReaction,
            row.effectiveSource,
            tostring(row.guidReaction or "-"),
            tostring(row.guidSource or "-"),
            tostring(row.nameReaction or "-"),
            tostring(row.nameSource or "-"),
            tostring(row.plateReaction or "-"),
            tostring(row.plateSource or "-")
        ))
    end
    tinsert(out, "reaction_map_status=PASS")
    return out
end

local function BoolToFlag(v)
    return v and "1" or "0"
end

local function FlagToBool(v)
    return tostring(v) == "1" or tostring(v) == "true"
end

local EXPORTED_OPTION_KEYS = {
    "all", "arena", "battleground", "field", "showTooltips", "showAmbiguousFallback",
    "anchorPoint", "anchorTo", "xOffset", "yOffset",
    "iconSize", "iconSpacing", "maxIconsPerRow", "maxIcons",
    "growthDirection", "frameStrata", "fontSize", "textfont",
    "scanInterval", "iconUpdateInterval", "groupScanInterval", "testRefreshInterval",
    "castMatchWindow", "confHalfLife", "minConfidence", "mappingTTL",
    "matrixLogEnabled", "matrixLogMaxEntries", "matrixStrictSelfTests",
    "persistSpecHints", "specDetectEnabled", "specHintTTL",
    "classCategoryFilterEnabled",
}

local EXPORTED_OPTION_TYPES = {
    all = "bool", arena = "bool", battleground = "bool", field = "bool",
    showTooltips = "bool", showAmbiguousFallback = "bool",
    xOffset = "number", yOffset = "number", iconSize = "number", iconSpacing = "number",
    maxIconsPerRow = "number", maxIcons = "number", fontSize = "number",
    scanInterval = "number", iconUpdateInterval = "number", groupScanInterval = "number",
    testRefreshInterval = "number", castMatchWindow = "number", confHalfLife = "number",
    minConfidence = "number", mappingTTL = "number", matrixLogEnabled = "bool",
    matrixLogMaxEntries = "number", matrixStrictSelfTests = "bool",
    persistSpecHints = "bool", specDetectEnabled = "bool", specHintTTL = "number",
    classCategoryFilterEnabled = "bool",
}

local function SortedNumericKeys(tbl)
    local ids = {}
    for k in pairs(tbl or {}) do
        if tonumber(k) then
            tinsert(ids, tonumber(k))
        end
    end
    table.sort(ids)
    return ids
end

local function DeepCloneTable(src)
    if type(src) ~= "table" then
        return src
    end
    local out = {}
    for k, v in pairs(src) do
        out[k] = DeepCloneTable(v)
    end
    return out
end

RunExportConfigPayload = function()
    if not db then
        return { "config_export_status=FAIL", "config_export_error=no_db" }
    end

    local out = { "icicle_config_export=v1" }
    for i = 1, #EXPORTED_OPTION_KEYS do
        local key = EXPORTED_OPTION_KEYS[i]
        local v = db[key]
        if v ~= nil then
            local vStr = EXPORTED_OPTION_TYPES[key] == "bool" and BoolToFlag(v) or tostring(v)
            tinsert(out, "opt=" .. tostring(key) .. "," .. vStr)
        end
    end

    local ids = SortedNumericKeys(db.spellOverrides)
    for i = 1, #ids do
        local sid = ids[i]
        local entry = db.spellOverrides[sid]
        if type(entry) == "table" then
            local cd = entry.cd ~= nil and tostring(entry.cd) or ""
            local trigger = NormalizeTrigger(entry.trigger)
            tinsert(out, "spell_override=" .. sid .. "," .. cd .. "," .. trigger)
        end
    end

    ids = SortedNumericKeys(db.customSpells)
    for i = 1, #ids do
        local sid = ids[i]
        local entry = db.customSpells[sid]
        if type(entry) == "table" then
            local cd = entry.cd ~= nil and tostring(entry.cd) or ""
            local trigger = NormalizeTrigger(entry.trigger)
            local category = NormalizeCategory((db.spellCategories and db.spellCategories[sid]) or "GENERAL")
            local isItem = entry.isItem and "1" or "0"
            tinsert(out, "custom_spell=" .. sid .. "," .. cd .. "," .. trigger .. "," .. category .. "," .. isItem)
        end
    end

    ids = SortedNumericKeys(db.disabledSpells)
    for i = 1, #ids do
        tinsert(out, "disabled_spell=" .. tostring(ids[i]))
    end

    ids = SortedNumericKeys(db.removedBaseSpells)
    for i = 1, #ids do
        tinsert(out, "removed_base_spell=" .. tostring(ids[i]))
    end

    ids = SortedNumericKeys(db.spellCategories)
    for i = 1, #ids do
        local sid = ids[i]
        tinsert(out, "spell_category=" .. sid .. "," .. NormalizeCategory(db.spellCategories[sid]))
    end

    tinsert(out, "config_export_summary=PASS:lines=" .. tostring(#out))
    return out
end

RunImportConfigPayload = function(payloadText)
    if not db then
        return { "config_import_status=FAIL", "config_import_error=no_db" }
    end
    if type(payloadText) ~= "string" or payloadText == "" then
        return { "config_import_status=FAIL", "config_import_error=empty_payload" }
    end

    local seenHeader = false
    local importedOptions = 0
    local importedOverrides = 0
    local importedCustom = 0
    local importedDisabled = 0
    local importedRemoved = 0
    local importedCategories = 0

    local newOverrides = {}
    local newCustom = {}
    local newDisabled = {}
    local newRemoved = {}
    local newCategories = {}

    for rawLine in string.gmatch(payloadText, "([^\r\n]+)") do
        local line = tostring(rawLine or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            local key, value = string.match(line, "^([^=]+)=(.*)$")
            if key == "icicle_config_export" then
                if value ~= "v1" then
                    return { "config_import_status=FAIL", "config_import_error=unsupported_version:" .. tostring(value) }
                end
                seenHeader = true
            elseif key == "opt" then
                local optKey, optVal = string.match(value or "", "^([^,]+),(.+)$")
                if optKey and optVal then
                    local optType = EXPORTED_OPTION_TYPES[optKey]
                    if optType == "bool" then
                        db[optKey] = FlagToBool(optVal)
                        importedOptions = importedOptions + 1
                    elseif optType == "number" then
                        local n = tonumber(optVal)
                        if n then
                            db[optKey] = n
                            importedOptions = importedOptions + 1
                        end
                    elseif optType == "string" or optType == nil then
                        db[optKey] = optVal
                        importedOptions = importedOptions + 1
                    end
                end
            elseif key == "spell_override" then
                local sid, cd, trigger = string.match(value or "", "^(%d+),([^,]*),([^,]+)$")
                sid = tonumber(sid)
                if sid then
                    newOverrides[sid] = { trigger = NormalizeTrigger(trigger) }
                    if cd and cd ~= "" then
                        newOverrides[sid].cd = tonumber(cd)
                    end
                    importedOverrides = importedOverrides + 1
                end
            elseif key == "custom_spell" then
                local sid, cd, trigger, category, isItem = string.match(value or "", "^(%d+),([^,]*),([^,]+),([^,]+),([^,]+)$")
                sid = tonumber(sid)
                if sid then
                    local spellName = GetSpellInfo(sid) or tostring(sid)
                    newCustom[sid] = {
                        name = spellName,
                        trigger = NormalizeTrigger(trigger),
                        isItem = FlagToBool(isItem),
                    }
                    if cd and cd ~= "" then
                        newCustom[sid].cd = tonumber(cd)
                    end
                    newCategories[sid] = NormalizeCategory(category)
                    importedCustom = importedCustom + 1
                end
            elseif key == "disabled_spell" then
                local sid = tonumber(value)
                if sid then
                    newDisabled[sid] = true
                    importedDisabled = importedDisabled + 1
                end
            elseif key == "removed_base_spell" then
                local sid = tonumber(value)
                if sid then
                    newRemoved[sid] = true
                    importedRemoved = importedRemoved + 1
                end
            elseif key == "spell_category" then
                local sid, category = string.match(value or "", "^(%d+),([^,]+)$")
                sid = tonumber(sid)
                if sid then
                    newCategories[sid] = NormalizeCategory(category)
                    importedCategories = importedCategories + 1
                end
            end
        end
    end

    if not seenHeader then
        return { "config_import_status=FAIL", "config_import_error=missing_header" }
    end

    db.spellOverrides = newOverrides
    db.customSpells = newCustom
    db.disabledSpells = newDisabled
    db.removedBaseSpells = newRemoved
    db.spellCategories = newCategories

    EnsureDefaultSpellProfile(db)
    NotifySpellsChanged()
    RefreshAllVisiblePlates()

    return {
        "config_import_status=PASS",
        "config_import_options=" .. tostring(importedOptions),
        "config_import_spell_overrides=" .. tostring(importedOverrides),
        "config_import_custom_spells=" .. tostring(importedCustom),
        "config_import_disabled_spells=" .. tostring(importedDisabled),
        "config_import_removed_base_spells=" .. tostring(importedRemoved),
        "config_import_categories=" .. tostring(importedCategories),
    }
end

RunExportDefaultDatasetWithNames = function()
    local out = {}
    tinsert(out, "IcicleData.DEFAULT_SPELLS_BY_CATEGORY = {")
    for i = 1, #SPELL_CATEGORY_ORDER do
        local category = SPELL_CATEGORY_ORDER[i]
        local spells = DEFAULT_SPELLS_BY_CATEGORY and DEFAULT_SPELLS_BY_CATEGORY[category]
        tinsert(out, "    " .. tostring(category) .. " = {")
        if type(spells) == "table" then
            local ids = {}
            for spellID in pairs(spells) do
                ids[#ids + 1] = tonumber(spellID)
            end
            table.sort(ids)
            for j = 1, #ids do
                local spellID = ids[j]
                local entry = spells[spellID]
                local cd = type(entry) == "table" and (entry.cd or entry.duration) or entry
                local enabledDefault = type(entry) == "table" and (entry.enabledDefault and true or false) or false
                local types = type(entry) == "table" and entry.types or nil
                local typeParts = {}
                if type(types) == "table" then
                    if types.class then tinsert(typeParts, "class = true") end
                    if types.shared then tinsert(typeParts, "shared = true") end
                    if types.item then tinsert(typeParts, "item = true") end
                    if types.racial then tinsert(typeParts, "racial = true") end
                    if types.spell then tinsert(typeParts, "spell = true") end
                end
                if #typeParts == 0 then
                    tinsert(typeParts, "spell = true")
                end
                local typeText = "{ " .. table.concat(typeParts, ", ") .. " }"
                local spellName = GetSpellInfo(spellID) or "Unknown"
                spellName = tostring(spellName):gsub("[\r\n]", " ")
                tinsert(out, string.format(
                    "        [%d] = { cd = %s, enabledDefault = %s, types = %s }, -- %s",
                    spellID,
                    tostring(cd),
                    tostring(enabledDefault),
                    typeText,
                    spellName
                ))
            end
        end
        tinsert(out, "    },")
    end
    tinsert(out, "}")
    return out
end

RunExportShareCode = function()
    if not db then
        return nil
    end
    local serializer = LibStub and LibStub("AceSerializer-3.0", true)
    local deflate = LibStub and LibStub("LibDeflate", true)
    if not serializer or not deflate then
        return nil
    end

    local packet = {
        addon = "Icicle",
        version = 1,
        datasetVersion = DataModule.DEFAULT_DATASET_VERSION or 1,
        profile = DeepCloneTable(db),
    }
    local serialized = serializer:Serialize(packet)
    if not serialized then return nil end
    local compressed = deflate:CompressZlib(serialized)
    if not compressed then return nil end
    return deflate:EncodeForPrint(compressed)
end

RunImportShareCode = function(shareCode)
    if type(shareCode) ~= "string" or shareCode == "" then
        return { "share_import_status=FAIL", "share_import_error=empty_code" }
    end
    local serializer = LibStub and LibStub("AceSerializer-3.0", true)
    local deflate = LibStub and LibStub("LibDeflate", true)
    if not serializer or not deflate then
        return { "share_import_status=FAIL", "share_import_error=missing_libraries" }
    end

    local decoded = deflate:DecodeForPrint(shareCode)
    if not decoded then
        return { "share_import_status=FAIL", "share_import_error=decode_failed" }
    end
    local decompressed = deflate:DecompressZlib(decoded)
    if not decompressed then
        return { "share_import_status=FAIL", "share_import_error=decompress_failed" }
    end
    local ok, packet = serializer:Deserialize(decompressed)
    if not ok or type(packet) ~= "table" then
        return { "share_import_status=FAIL", "share_import_error=deserialize_failed" }
    end
    if packet.addon ~= "Icicle" then
        return { "share_import_status=FAIL", "share_import_error=wrong_addon" }
    end
    if tonumber(packet.version) ~= 1 then
        return { "share_import_status=FAIL", "share_import_error=unsupported_version" }
    end
    if type(packet.profile) ~= "table" then
        return { "share_import_status=FAIL", "share_import_error=missing_profile" }
    end

    for k in pairs(db) do
        db[k] = nil
    end
    local imported = DeepCloneTable(packet.profile)
    for k, v in pairs(imported) do
        db[k] = v
    end

    CopyDefaults(db, _G.IcicleDefaults or {})
    ConfigModule.ApplyLoginMigrations(db, BASE_COOLDOWNS)
    MigrationModule.ApplyProfileMigrations(db)
    EnsureDefaultSpellProfile(db)
    SyncSpecHintsFromDB()
    NotifySpellsChanged()
    RefreshAllVisiblePlates()

    return {
        "share_import_status=PASS",
        "share_import_dataset=" .. tostring(packet.datasetVersion or 1),
    }
end

RunFullValidation = function()
    local out = {}

    tinsert(out, "full_validation_start=PASS")

    local prevStrict = db and db.matrixStrictSelfTests or false
    if db then db.matrixStrictSelfTests = false end
    local basic = RunMatrixSelfTests()
    if db then db.matrixStrictSelfTests = prevStrict end
    tinsert(out, "section_matrix_basic=PASS")
    if type(basic) == "table" then
        for i = 1, #basic do tinsert(out, "matrix_basic:" .. tostring(basic[i])) end
    else
        tinsert(out, "matrix_basic=FAIL")
    end

    local reg = RunRegressionHarness()
    tinsert(out, "section_regression=PASS")
    if type(reg) == "table" then
        for i = 1, #reg do tinsert(out, "regression:" .. tostring(reg[i])) end
    else
        tinsert(out, "regression=FAIL")
    end

    if db then db.matrixStrictSelfTests = true end
    local strict = RunMatrixSelfTests()
    if db then db.matrixStrictSelfTests = prevStrict end
    tinsert(out, "section_matrix_strict=PASS")
    if type(strict) == "table" then
        for i = 1, #strict do tinsert(out, "matrix_strict:" .. tostring(strict[i])) end
    else
        tinsert(out, "matrix_strict=FAIL")
    end

    local parity = RunMatrixParityReport()
    tinsert(out, "section_matrix_parity=PASS")
    if type(parity) == "table" then
        for i = 1, #parity do tinsert(out, "matrix_parity:" .. tostring(parity[i])) end
    else
        tinsert(out, "matrix_parity=FAIL")
    end

    local triggerParity = RunTriggerParityReport()
    tinsert(out, "section_trigger_parity=PASS")
    if type(triggerParity) == "table" then
        for i = 1, #triggerParity do tinsert(out, "trigger_parity:" .. tostring(triggerParity[i])) end
    else
        tinsert(out, "trigger_parity=FAIL")
    end

    local snapshots = RunSnapshotFixtureCheck(out)
    tinsert(out, "section_snapshot_fixtures=PASS")
    if type(snapshots) == "table" then
        for i = 1, #snapshots do tinsert(out, "snapshot:" .. tostring(snapshots[i])) end
    else
        tinsert(out, "snapshot=FAIL")
    end

    local pass, fail = SummarizeValidation(out)
    tinsert(out, "full_validation_summary=PASS:" .. tostring(pass) .. ",FAIL:" .. tostring(fail))
    return out
end

RunStartupHealthCheck = function()
    local lines = {}
    local function yn(v) return v and "yes" or "no" end
    local profileVer = db and (tonumber(db.profileSchemaVersion) or 0) or 0
    local targetVer = MigrationModule.GetCurrentSchemaVersion and MigrationModule.GetCurrentSchemaVersion() or 0
    local specGuidCount, specNameCount = 0, 0
    local pendingCount = 0
    for _ in pairs(STATE.specByGUID) do specGuidCount = specGuidCount + 1 end
    for _ in pairs(STATE.specByName) do specNameCount = specNameCount + 1 end
    for _ in pairs(STATE.pendingBindByGUID or {}) do pendingCount = pendingCount + 1 end

    tinsert(lines, "health_schema=profile:" .. tostring(profileVer) .. ",target:" .. tostring(targetVer))
    tinsert(lines, "health_module_state=" .. yn(type(StateModule) == "table"))
    tinsert(lines, "health_module_events=" .. yn(type(EventsModule) == "table"))
    tinsert(lines, "health_module_migration=" .. yn(type(MigrationModule) == "table"))
    tinsert(lines, "health_module_spec=" .. yn(type(SpecModule) == "table"))
    tinsert(lines, "health_module_rules=" .. yn(type(CooldownRulesModule) == "table"))
    tinsert(lines, "health_module_tracking=" .. yn(type(TrackingModule) == "table"))
    tinsert(lines, "health_module_uioptions=" .. yn(type(UIOptionsModule) == "table"))
    tinsert(lines, "health_spec_hints_runtime=guid:" .. tostring(specGuidCount) .. ",name:" .. tostring(specNameCount))
    tinsert(lines, "health_pending_binds=" .. tostring(pendingCount))
    if db then
        local dbGuid, dbName = 0, 0
        db.specHintsByGUID = db.specHintsByGUID or {}
        db.specHintsByName = db.specHintsByName or {}
        for _ in pairs(db.specHintsByGUID) do dbGuid = dbGuid + 1 end
        for _ in pairs(db.specHintsByName) do dbName = dbName + 1 end
        tinsert(lines, "health_spec_hints_profile=guid:" .. tostring(dbGuid) .. ",name:" .. tostring(dbName))
        tinsert(lines, "health_flags=persistHints:" .. yn(db.persistSpecHints) .. ",specDetect:" .. yn(db.specDetectEnabled) .. ",strict:" .. yn(db.matrixStrictSelfTests))
        tinsert(lines, "health_dataset=default_plus_custom")
    else
        tinsert(lines, "health_profile=missing")
    end
    return lines
end

local ToggleTestMode
local BuildOptionsPanel
local OpenOptionsPanel
local TESTMODE_CONTEXT = {
    STATE = STATE,
    baseCooldowns = BASE_COOLDOWNS,
    WipeTable = WipeTable,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    Print = Print,
    IsItemSpell = IsItemSpell,
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
    return TestModeModule.PopulateRandomPlateTests(TESTMODE_CONTEXT)
end

local function RandomizeTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    return TestModeModule.RandomizeTestMode(TESTMODE_CONTEXT)
end

local function StopTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    return TestModeModule.StopTestMode(TESTMODE_CONTEXT)
end

local function StartTestMode()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
    return TestModeModule.StartTestMode(TESTMODE_CONTEXT)
end

ToggleTestMode = function()
    TESTMODE_CONTEXT.baseCooldowns = BASE_COOLDOWNS
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

NotifySpellsChanged = function()
    SPELL_IDS_BY_NAME = nil
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
        DebugSpellRule = DebugSpellRule,
        SetUnitSpecHint = SetUnitSpecHint,
        SetPersistSpecHints = SetPersistSpecHints,
        RunMatrixSelfTests = RunMatrixSelfTests,
        RunMatrixParityReport = RunMatrixParityReport,
        RunTriggerParityReport = RunTriggerParityReport,
        RunRegressionHarness = RunRegressionHarness,
        RunFullValidation = RunFullValidation,
        RunDiagnosticReport = RunDiagnosticReport,
        RunPerformanceReport = RunPerformanceReport,
        RunReactionMappingReport = RunReactionMappingReport,
        RunSnapshotFixtureCheck = RunSnapshotFixtureCheck,
        RunExportConfigPayload = RunExportConfigPayload,
        RunImportConfigPayload = RunImportConfigPayload,
        RunExportDefaultDatasetWithNames = RunExportDefaultDatasetWithNames,
        RunExportShareCode = RunExportShareCode,
        RunImportShareCode = RunImportShareCode,
        RunStartupHealthCheck = RunStartupHealthCheck,
        GetMatrixActionLog = GetMatrixActionLog,
        ClearMatrixActionLog = ClearMatrixActionLog,
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

local function SyncEditStateFromSpellID(spellID)
    if not spellID then
        editState.name = nil
        editState.icon = nil
        editState.baseKnown = nil
        return
    end

    local name, _, icon = GetSpellInfo(spellID)
    editState.name = name or ("Unknown Spell (" .. tostring(spellID) .. ")")
    editState.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

    local base = GetBaseSpellEntry(spellID)
    if base then
        editState.baseKnown = true
        editState.cooldown = tostring(base.cd)
        editState.trigger = NormalizeTrigger(base.trigger)
    else
        editState.baseKnown = false
        editState.cooldown = ""
        if not editState.trigger or editState.trigger == "" then
            editState.trigger = "SUCCESS"
        end
    end
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
    ConfigModule.ApplyLoginMigrations(db, BASE_COOLDOWNS)
    MigrationModule.ApplyProfileMigrations(db)
    EnsureDefaultSpellProfile(db)
    SyncSpecHintsFromDB()
    RebuildInternalAPI()
    RefreshAllVisiblePlates()
    NotifySpellsChanged()
end

BuildOptionsPanel = function()
    return UIOptionsModule.BuildOptionsPanel({
        STATE = STATE,
        editState = editState,
        AceConfig = AceConfig,
        AceConfigDialog = AceConfigDialog,
        AceDBOptions = AceDBOptions,
        OptionsModule = OptionsModule,
        POINT_VALUES = POINT_VALUES,
        GROW_VALUES = GROW_VALUES,
        SPELL_CATEGORY_ORDER = SPELL_CATEGORY_ORDER,
        SPELL_CATEGORY_LABELS = SPELL_CATEGORY_LABELS,
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
        SyncEditStateFromSpellID = SyncEditStateFromSpellID,
        ResetAllCooldowns = ResetAllCooldowns,
        DescribeSpellRule = DescribeSpellRuleByID,
        SetUnitSpecHint = SetUnitSpecHint,
        SetPersistSpecHints = SetPersistSpecHints,
        RunMatrixSelfTests = RunMatrixSelfTests,
        RunMatrixParityReport = RunMatrixParityReport,
        RunTriggerParityReport = RunTriggerParityReport,
        RunRegressionHarness = RunRegressionHarness,
        RunFullValidation = RunFullValidation,
        RunDiagnosticReport = RunDiagnosticReport,
        RunPerformanceReport = RunPerformanceReport,
        RunReactionMappingReport = RunReactionMappingReport,
        RunSnapshotFixtureCheck = RunSnapshotFixtureCheck,
        RunExportConfigPayload = RunExportConfigPayload,
        RunImportConfigPayload = RunImportConfigPayload,
        RunExportDefaultDatasetWithNames = RunExportDefaultDatasetWithNames,
        RunExportShareCode = RunExportShareCode,
        RunImportShareCode = RunImportShareCode,
        RunStartupHealthCheck = RunStartupHealthCheck,
        GetMatrixActionLog = GetMatrixActionLog,
        ClearMatrixActionLog = ClearMatrixActionLog,
    })
end

OpenOptionsPanel = function()
    OptionsModule.OpenPanel("Icicle")
end

local function OnUpdate(_, elapsed)
    local startedMs = debugprofilestop and debugprofilestop() or nil
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
    local result = RenderModule.OnUpdate(RENDER_CONTEXT, elapsed)
    if STATE and STATE.stats then
        STATE.stats.onUpdateCount = (STATE.stats.onUpdateCount or 0) + 1
        if startedMs and debugprofilestop then
            STATE.stats.onUpdateTotalMs = (STATE.stats.onUpdateTotalMs or 0) + (debugprofilestop() - startedMs)
        end
    end
    return result
end

local function HandleUnitSignal(unit, confidence, reason)
    ResolveUnit(unit, confidence, reason)
    RefreshAllVisiblePlates()
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

    for i = 1, #STATE.inspectQueue do
        local entry = STATE.inspectQueue[i]
        if entry then
            local unit = entry.unit
            local guid = entry.guid
            local tooOld = (now - (entry.enqueuedAt or now)) > maxRetry
            if tooOld then
                RemoveInspectQueueEntryAt(i)
                return
            end

            if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
                RemoveInspectQueueEntryAt(i)
                return
            end

            if CanInspect and not CanInspect(unit, true) then
                if not STATE.inspectOutOfRangeSince[guid] then
                    STATE.inspectOutOfRangeSince[guid] = now
                end
                if (now - STATE.inspectOutOfRangeSince[guid]) >= maxRetry then
                    if db.showOutOfRangeInspectMessages then
                        Print("Inspect skipped (out of range): " .. tostring(UnitName(unit) or guid))
                    end
                    RemoveInspectQueueEntryAt(i)
                    STATE.inspectOutOfRangeSince[guid] = nil
                end
                return
            end

            STATE.inspectOutOfRangeSince[guid] = nil
            if (now - (entry.lastTryAt or 0)) < retryInterval then
                return
            end

            entry.lastTryAt = now
            STATE.inspectRequestAtByGUID[guid] = now
            STATE.inspectUnitByGUID[guid] = unit
            STATE.inspectCurrent = { guid = guid, unit = unit, requestedAt = now }
            NotifyInspect(unit)
            return
        end
    end
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
            AddMatrixActionLog(string.format("spec inspect caster=%s class=%s tab=%d", tostring(guid), tostring(classToken), bestTab))
            RefreshAllVisiblePlates()
        end
    end
    STATE.inspectUnitByGUID[guid] = nil
    STATE.inspectCurrent = nil
    STATE.inspectOutOfRangeSince[guid] = nil
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
    MigrationModule = MigrationModule,
    SpecModule = SpecModule,
    CombatModule = CombatModule,
    AceDBLib = AceDBLib,
    CopyDefaults = CopyDefaults,
    profileCallbacks = profileCallbacks,
    ProfilesChanged = ProfilesChanged,
    ApplyProfileMigrations = function(profile)
        return MigrationModule.ApplyProfileMigrations(profile)
    end,
    EnsureDefaultSpellProfile = EnsureDefaultSpellProfile,
    SyncSpecHintsFromDB = SyncSpecHintsFromDB,
    RebuildInternalAPI = RebuildInternalAPI,
    STATE = STATE,
    WipeTable = WipeTable,
    ScanNameplates = ScanNameplates,
    RefreshAllVisiblePlates = RefreshAllVisiblePlates,
    HandleUnitSignal = HandleUnitSignal,
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
    AddMatrixActionLog = AddMatrixActionLog,
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

