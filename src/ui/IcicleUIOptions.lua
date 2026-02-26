IcicleUIOptions = IcicleUIOptions or {}

local strfind, strlower = string.find, string.lower
local format = string.format
local tinsert = table.insert
local OptionTabsModule = _G.IcicleUIOptionTabs

function IcicleUIOptions.BuildOptionsPanel(ctx)
    if ctx.IsBuilt() or not (ctx.AceConfig and ctx.AceConfigDialog) then
        return
    end
    if type(OptionTabsModule) ~= "table" then
        error("Icicle: Reborn: required module missing: IcicleUIOptionTabs")
    end
    local addonVersion = (GetAddOnMetadata and GetAddOnMetadata("Icicle", "Version")) or "dev"

    local function DB()
        return ctx.GetDB()
    end

    local function BuildRootGroup(addonVersion)
        return {
            type = "group",
            name = "Icicle: Reborn",
            args = {
            discussionsLink = {
                type = "input",
                order = 1,
                width = "full",
                name = "Report a bug, discussions or idea at: ",
                get = function()
                    return "https://github.com/hiroshi-richi/Icicle-Reborn/discussions"
                end,
                set = function() end,
            },
            introOverview = {
                type = "description",
                order = 2,
                name = format("\nVersion: %s (WotLK 3.3.5a)\n\nIcicle: Reborn tracks enemy cooldown usage and shows active cooldown timers directly on nameplates. It is designed to give fast combat awareness without needing to move your eyes away from enemy units.\n\nThe addon listens to combat events, identifies who cast what, maps that information to visible nameplates, and renders countdown icons with class-aware visuals.", tostring(addonVersion)),
            },
            introSpacer1 = {
                type = "description",
                order = 3,
                name = " ",
                width = "full",
            },
            howItWorksHeader = {
                type = "header",
                order = 4,
                name = "How It Works",
            },
            howItWorksBody = {
                type = "description",
                order = 5,
                name = "1. Detection: Icicle: Reborn reads combat log events and unit cast signals.\n2. Rule Resolution: It applies cooldown rules (base cooldowns, shared cooldown links, reset effects, and spec modifiers).\n3. Identity Mapping: It resolves caster GUID/name to the correct visible nameplate.\n4. Rendering: It draws cooldown icons, countdown text, and border cues on each nameplate.\n5. Filtering: Optional spell-class filtering prevents spell-class mismatches.",
            },
            introSpacer2 = {
                type = "description",
                order = 6,
                name = " ",
                width = "full",
            },
            setupHeader = {
                type = "header",
                order = 7,
                name = "Recommended Setup Flow",
            },
            setupBody = {
                type = "description",
                order = 8,
                name = "1. General: Choose where Icicle: Reborn runs (arena, battleground, world, party, raid).\n2. Style settings: Adjust icon size, text, and border thickness/inset.\n3. Position settings: Anchor and offset the icon container around nameplates.\n4. Tracked Spells: Review categories, enable/disable entries, and customize category/class border colors.\n5. Profiles: Save or copy presets for different characters/specs.",
            },
            introSpacer3 = {
                type = "description",
                order = 9,
                name = " ",
                width = "full",
            },
            notesHeader = {
                type = "header",
                order = 10,
                name = "Notes",
            },
            notesBody = {
                type = "description",
                order = 11,
                name = "- Interrupt highlighting can pulse border or icon based on Interrupt settings.\n- Category/class border visibility can be toggled per category in Tracked Spells.\n- On first install or profile reset, default tracked spells/categories are loaded from the addon dataset.\n- Default enabled set is curated: interrupt, stun, incapacitate, damage-reduction, and movement-impair-removal spells are enabled; other default spells remain disabled until manually enabled.\n- If mapping is ambiguous (multiple same-name enemies), targeting/focus/mouseover helps resolve ownership faster.",
            },
            introSpacer4 = {
                type = "description",
                order = 12,
                name = " ",
                width = "full",
            },
            quickNavHeader = {
                type = "header",
                order = 13,
                name = "Panels",
            },
            quickNavBody = {
                type = "description",
                order = 14,
                name = "General, Style settings, Position settings, Tracked Spells, Profiles",
            },
            },
        }
    end

    local root = BuildRootGroup(addonVersion)

    local function OptionsSet(info, value)
        local db = DB()
        local key = info[#info]
        db[key] = value
        if key == "performanceMode" and ctx.ConfigModule and ctx.ConfigModule.ApplyPerformanceMode then
            ctx.ConfigModule.ApplyPerformanceMode(db, value)
        end
        if key == "specDetectEnabled" and ctx.UpdateAdvancedSpecEvents then
            ctx.UpdateAdvancedSpecEvents()
        end
        ctx.RefreshAllVisiblePlates()
    end

    local function OptionsGet(info)
        local db = DB()
        return db[info[#info]]
    end

    local general = OptionTabsModule.BuildGeneralGroup({
        STATE = ctx.STATE,
        ConfigModule = ctx.ConfigModule,
        OptionsGet = OptionsGet,
        OptionsSet = OptionsSet,
        ToggleTestMode = ctx.ToggleTestMode,
    })

    local style = OptionTabsModule.BuildStyleGroup({
        OptionsGet = OptionsGet,
        OptionsSet = OptionsSet,
    })

    local position = OptionTabsModule.BuildPositionGroup({
        OptionsGet = OptionsGet,
        OptionsSet = OptionsSet,
        POINT_VALUES = ctx.POINT_VALUES,
        GROW_VALUES = ctx.GROW_VALUES,
    })

    local tmpAddSpellIDByCategory = {}
    local spellSearchText = ""
    local categoryBorderDefaults = ctx.CATEGORY_BORDER_DEFAULTS or {
        GENERAL = { r = 0.502, g = 0.502, b = 0.502, a = 1.00 },
    }
    local spells = {
        type = "group",
        name = "Tracked Spells",
        desc = "Manage tracked cooldown spells by class/category, including custom additions and per-spell overrides.",
        childGroups = "tree",
        args = {},
    }

    local function EnsureEntry(sid)
        local base = ctx.GetBaseSpellEntry(sid)
        if base then
            return { cd = base.cd, trigger = base.trigger, fromBase = true }
        end
        local db = DB()
        db.customSpells = db.customSpells or {}
        db.customSpells[sid] = db.customSpells[sid] or { name = (GetSpellInfo(sid) or tostring(sid)), trigger = "SUCCESS" }
        return { cd = db.customSpells[sid].cd, trigger = db.customSpells[sid].trigger or "SUCCESS", fromBase = false }
    end

    local function RemoveEntry(sid, fromBase)
        local db = DB()
        db.spellOverrides = db.spellOverrides or {}
        db.customSpells = db.customSpells or {}
        db.removedBaseSpells = db.removedBaseSpells or {}
        db.spellCategories = db.spellCategories or {}
        db.disabledSpells = db.disabledSpells or {}

        db.spellOverrides[sid] = nil
        db.spellCategories[sid] = nil
        if fromBase then
            db.removedBaseSpells[sid] = nil
            db.disabledSpells[sid] = true
        else
            db.customSpells[sid] = nil
            db.disabledSpells[sid] = nil
        end
    end

    local function AddSpellToCategory(categoryKey)
        categoryKey = ctx.NormalizeCategory(categoryKey)
        local sid = tonumber(tmpAddSpellIDByCategory[categoryKey])
        if not sid then
            ctx.Print("Invalid Spell ID")
            return
        end
        local sName = GetSpellInfo(sid)
        local db = DB()
        db.customSpells = db.customSpells or {}
        db.removedBaseSpells = db.removedBaseSpells or {}
        db.spellCategories = db.spellCategories or {}
        db.disabledSpells = db.disabledSpells or {}

        db.removedBaseSpells[sid] = nil
        db.spellCategories[sid] = categoryKey
        db.disabledSpells[sid] = nil

        if not ctx.GetBaseSpellEntry(sid) then
            if not db.customSpells[sid] then
                db.customSpells[sid] = { name = sName or tostring(sid), trigger = "SUCCESS" }
            else
                db.customSpells[sid].name = db.customSpells[sid].name or sName or tostring(sid)
                db.customSpells[sid].trigger = db.customSpells[sid].trigger or "SUCCESS"
            end
        end

        ctx.NotifySpellsChanged()
        if ctx.AceConfigDialog then
            ctx.AceConfigDialog:SelectGroup("IcicleSpells", categoryKey, "spell_" .. tostring(sid))
        end
    end

    local function RebuildSpellArgs()
        spells.args = {
            search = {
                type = "input",
                order = 1,
                width = "full",
                name = "Search by spell name",
                desc = "Filters visible spells in the left tree by spell name.",
                get = function() return spellSearchText or "" end,
                set = function(_, val)
                    local prevSearch = strlower(spellSearchText or "")
                    spellSearchText = val or ""
                    local nextSearch = strlower(spellSearchText or "")
                    if prevSearch ~= "" and nextSearch == "" and ctx.AceConfigDialog and ctx.AceConfigDialog.GetStatusTable then
                        local status = ctx.AceConfigDialog:GetStatusTable("IcicleSpells")
                        if type(status) == "table" then
                            status.groups = status.groups or {}
                            status.groups.groups = {}
                            local firstCategoryKey = ctx.SPELL_CATEGORY_ORDER and ctx.SPELL_CATEGORY_ORDER[1]
                            if firstCategoryKey then
                                status.groups.selected = firstCategoryKey
                            else
                                status.groups.selected = nil
                            end
                        end
                    end
                    ctx.NotifySpellsChanged()
                end,
            },
        }

        local rows = ctx.BuildSpellRowsData()
        local rowsByCategory = {}
        local allRowsByCategory = {}
        local globalSearch = strlower(spellSearchText or "")

        for _, categoryKey in ipairs(ctx.SPELL_CATEGORY_ORDER) do
            rowsByCategory[categoryKey] = {}
            allRowsByCategory[categoryKey] = {}
        end

        for _, row in ipairs(rows) do
            local categoryKey = ctx.NormalizeCategory(row.categoryKey)
            local rowName = strlower(row.name or tostring(row.id))
            tinsert(allRowsByCategory[categoryKey], row)
            local matchesSearch = (globalSearch == "" or strfind(rowName, globalSearch, 1, true))
            if matchesSearch then
                tinsert(rowsByCategory[categoryKey], row)
            end
        end

        if globalSearch ~= "" and ctx.AceConfigDialog and ctx.AceConfigDialog.GetStatusTable then
            local status = ctx.AceConfigDialog:GetStatusTable("IcicleSpells")
            if type(status) == "table" then
                status.groups = status.groups or {}
                status.groups.groups = status.groups.groups or {}
                for _, categoryKey in ipairs(ctx.SPELL_CATEGORY_ORDER) do
                    if rowsByCategory[categoryKey] and #rowsByCategory[categoryKey] > 0 then
                        status.groups.groups[categoryKey] = true
                    end
                end
            end
        end

        local function SetCategoryEnabled(categoryKey, enabled)
            local db = DB()
            db.disabledSpells = db.disabledSpells or {}
            local rowsInCategory = allRowsByCategory[categoryKey] or {}
            local categoryLabel = ctx.SPELL_CATEGORY_LABELS[categoryKey] or categoryKey
            for i = 1, #rowsInCategory do
                local sid = rowsInCategory[i].id
                if enabled then
                    db.disabledSpells[sid] = nil
                else
                    db.disabledSpells[sid] = true
                end
            end
            ctx.ResetAllCooldowns(true)
            ctx.NotifySpellsChanged()
            if ctx.Print then
                if enabled then
                    ctx.Print(format("All spells in category %s were Enabled.", tostring(categoryLabel)))
                else
                    ctx.Print(format("All spells in category %s were Disabled.", tostring(categoryLabel)))
                end
            end
        end

        local function ResetCategoryOverrides(categoryKey)
            local db = DB()
            db.spellOverrides = db.spellOverrides or {}
            db.disabledSpells = db.disabledSpells or {}
            db.removedBaseSpells = db.removedBaseSpells or {}
            db.spellCategories = db.spellCategories or {}
            db.categoryBorderEnabled = db.categoryBorderEnabled or {}
            db.categoryBorderColors = db.categoryBorderColors or {}
            local defaultEnabledMap = ctx.DEFAULT_ENABLED_SPELL_IDS or {}
            local hasDefaultEnabledMap = next(defaultEnabledMap) ~= nil
            local categoryLabel = ctx.SPELL_CATEGORY_LABELS[categoryKey] or categoryKey

            local defaultsInCategory = ctx.DEFAULT_SPELLS_BY_CATEGORY and ctx.DEFAULT_SPELLS_BY_CATEGORY[categoryKey]
            if type(defaultsInCategory) == "table" then
                for sid in pairs(defaultsInCategory) do
                    db.spellOverrides[sid] = nil
                    if (not hasDefaultEnabledMap) or defaultEnabledMap[sid] then
                        db.disabledSpells[sid] = nil
                    else
                        db.disabledSpells[sid] = true
                    end
                    db.removedBaseSpells[sid] = nil
                    db.spellCategories[sid] = categoryKey
                end
            end

            local borderDefault = categoryBorderDefaults[categoryKey] or categoryBorderDefaults.GENERAL
            db.categoryBorderEnabled[categoryKey] = true
            db.categoryBorderColors[categoryKey] = {
                r = borderDefault.r,
                g = borderDefault.g,
                b = borderDefault.b,
                a = borderDefault.a,
            }
            ctx.ResetAllCooldowns(true)
            ctx.NotifySpellsChanged()
            ctx.RefreshAllVisiblePlates()
            if ctx.Print then
                ctx.Print(format("Category %s was restored.", tostring(categoryLabel)))
            end
        end

        for order, categoryKey in ipairs(ctx.SPELL_CATEGORY_ORDER) do
            local categoryLabel = ctx.SPELL_CATEGORY_LABELS[categoryKey] or categoryKey
            local categoryRows = rowsByCategory[categoryKey] or {}
            local showCategory = (#categoryRows > 0) or (globalSearch == "")

            if showCategory then
                local categoryArgs = {
                    categoryHeader = {
                        type = "header",
                        order = 1.0,
                        width = "full",
                        name = tostring(categoryLabel),
                    },
                    spacer1 = {
                        type = "description",
                        order = 1.1,
                        width = "full",
                        name = "\n",
                    },
                    showCategoryBorder = {
                        type = "toggle",
                        order = 2.1,
                        width = "normal",
                        name = "Show border color",
                        desc = "Show this category border color on tracked spell icons.",
                        get = function()
                            local db = DB()
                            db.categoryBorderEnabled = db.categoryBorderEnabled or {}
                            if db.categoryBorderEnabled[categoryKey] == nil then
                                db.categoryBorderEnabled[categoryKey] = true
                            end
                            return db.categoryBorderEnabled[categoryKey] and true or false
                        end,
                        set = function(_, val)
                            local db = DB()
                            db.categoryBorderEnabled = db.categoryBorderEnabled or {}
                            db.categoryBorderEnabled[categoryKey] = val and true or false
                            ctx.RefreshAllVisiblePlates()
                        end,
                    },
                    categoryBorderColor = {
                        type = "color",
                        order = 2.2,
                        width = "normal",
                        name = " " .. format("%s color", tostring(categoryLabel)),
                        desc = "Border color used for this category on tracked spell icons.",
                        hasAlpha = true,
                        get = function()
                            local db = DB()
                            db.categoryBorderColors = db.categoryBorderColors or {}
                            local def = categoryBorderDefaults[categoryKey] or categoryBorderDefaults.GENERAL
                            if type(db.categoryBorderColors[categoryKey]) ~= "table" then
                                db.categoryBorderColors[categoryKey] = { r = def.r, g = def.g, b = def.b, a = def.a }
                            end
                            local c = db.categoryBorderColors[categoryKey]
                            return c.r or def.r, c.g or def.g, c.b or def.b, c.a or def.a
                        end,
                        set = function(_, r, g, b, a)
                            local db = DB()
                            db.categoryBorderColors = db.categoryBorderColors or {}
                            db.categoryBorderColors[categoryKey] = { r = r, g = g, b = b, a = a }
                            ctx.RefreshAllVisiblePlates()
                        end,
                    },
                    spacer2 = {
                        type = "description",
                        order = 2.3,
                        width = "full",
                        name = "\n",
                    },
                    inputSpellID = {
                        type = "input",
                        order = 3.1,
                        width = "normal",
                        name = "Spell ID",
                        desc = "Enter a numeric Spell ID to add to this category.",
                        get = function() return tmpAddSpellIDByCategory[categoryKey] or "" end,
                        set = function(_, val) tmpAddSpellIDByCategory[categoryKey] = val end,
                    },
                    addSpell = {
                        type = "execute",
                        order = 3.2,
                        width = "normal",
                        name = format("Add Spell to %s", categoryLabel),
                        desc = "Adds the entered Spell ID to this category as a tracked spell.",
                        func = function() AddSpellToCategory(categoryKey) end,
                    },
                    spacer3 = {
                        type = "description",
                        order = 3.3,
                        width = "full",
                        name = "",
                    },
                    enableAll = {
                        type = "execute",
                        order = 4.1,
                        width = "normal",
                        name = "Enable All",
                        desc = "Enable tracking for every spell in this category.",
                        func = function() SetCategoryEnabled(categoryKey, true) end,
                    },
                    disableAll = {
                        type = "execute",
                        order = 4.2,
                        width = "normal",
                        name = "Disable All",
                        desc = "Disable tracking for every spell in this category.",
                        func = function() SetCategoryEnabled(categoryKey, false) end,
                    },
                    resetCategory = {
                        type = "execute",
                        order = 4.3,
                        width = "normal",
                        name = "Reset All",
                        desc = "Restores default spells in this category (enabled + default values). Custom spells are not deleted.",
                        func = function() ResetCategoryOverrides(categoryKey) end,
                    }
                }

                for i, row in ipairs(categoryRows) do
                    local sid = row.id
                    local spellName = row.name or tostring(sid)
                    local groupName = ctx.BuildSpellRowName(row)
                    if not row.enabled then
                        groupName = "|cff7f7f7f" .. groupName .. "|r"
                    end
                    local texture = row.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                    local tooltipText = ctx.BuildSpellTooltipBody(row)
                    local panelText = ctx.BuildSpellPanelDesc(row)
                    local spellTreeKey = "spell_" .. tostring(sid)

                    categoryArgs[spellTreeKey] = {
                        type = "group",
                        name = groupName,
                        desc = tooltipText,
                        order = 100 + i,
                        args = {
                            spellTitle = { type = "header", order = 1, name = spellName },
                            spellDesc = {
                                type = "description",
                                order = 2,
                                width = "full",
                                name = panelText,
                                image = texture,
                                imageWidth = 32,
                                imageHeight = 32,
                            },
                            spacer1 = { type = "description", order = 2.5, name = "\n", width = "full" },
                            enable = {
                                type = "toggle",
                                name = "Enable",
                                order = 3,
                                width = "normal",
                                desc = "Enable or disable tracking for this spell.",
                                get = function()
                                    local db = DB()
                                    db.disabledSpells = db.disabledSpells or {}
                                    return not db.disabledSpells[sid]
                                end,
                                set = function(_, value)
                                    local db = DB()
                                    db.disabledSpells = db.disabledSpells or {}
                                    if value then
                                        db.disabledSpells[sid] = nil
                                    else
                                        db.disabledSpells[sid] = true
                                    end
                                    ctx.ResetAllCooldowns(true)
                                    ctx.NotifySpellsChanged()
                                end,
                            },
                            spacer2 = { type = "description", order = 3.5, name = "", width = "full" },
                            spellID = {
                                type = "input",
                                name = "Spell ID",
                                order = 4,
                                width = "normal",
                                desc = "Change this tracked entry to a different Spell ID.",
                                get = function() return tostring(sid) end,
                                set = function(_, val)
                                    local newSid = tonumber(val)
                                    if not newSid then return end
                                    local prev = EnsureEntry(sid)
                                    local curr = EnsureEntry(newSid)
                                    local db = DB()
                                    db.spellOverrides = db.spellOverrides or {}
                                    db.spellCategories = db.spellCategories or {}
                                    db.spellOverrides[newSid] = db.spellOverrides[newSid] or {}
                                    db.spellOverrides[newSid].cd = db.spellOverrides[newSid].cd or prev.cd
                                    db.spellOverrides[newSid].trigger = db.spellOverrides[newSid].trigger or prev.trigger or curr.trigger or "SUCCESS"
                                    db.spellCategories[newSid] = row.categoryKey
                                    RemoveEntry(sid, row.fromBase)
                                    ctx.NotifySpellsChanged()
                                    if ctx.AceConfigDialog then
                                        ctx.AceConfigDialog:SelectGroup("IcicleSpells", row.categoryKey, "spell_" .. tostring(newSid))
                                    end
                                end,
                            },
                            cooldown = {
                                type = "input",
                                name = "Cooldown seconds",
                                order = 5,
                                width = "normal",
                                desc = "Set the cooldown duration (in seconds) used for this tracked spell.",
                                get = function()
                                    local db = DB()
                                    local entry = EnsureEntry(sid)
                                    local ov = db.spellOverrides and db.spellOverrides[sid]
                                    local cd = ov and ov.cd or entry.cd
                                    return cd and tostring(cd) or ""
                                end,
                                set = function(_, val)
                                    local cd = tonumber(val)
                                    if not cd or cd <= 0 then return end
                                    local db = DB()
                                    local entry = EnsureEntry(sid)
                                    db.spellOverrides[sid] = db.spellOverrides[sid] or {}
                                    db.spellOverrides[sid].cd = cd
                                    db.spellOverrides[sid].trigger = ctx.NormalizeTrigger((db.spellOverrides[sid].trigger or entry.trigger or "SUCCESS"))
                                    ctx.RefreshAllVisiblePlates()
                                    ctx.NotifySpellsChanged()
                                end,
                            },
                            trigger = {
                                type = "select",
                                name = "Trigger",
                                order = 6,
                                width = "normal",
                                desc = "Choose which combat-log event starts this cooldown.",
                                values = { SUCCESS = "SUCCESS", AURA_APPLIED = "AURA_APPLIED", START = "START" },
                                get = function()
                                    local db = DB()
                                    local entry = EnsureEntry(sid)
                                    local ov = db.spellOverrides and db.spellOverrides[sid]
                                    return ctx.NormalizeTrigger((ov and ov.trigger) or entry.trigger or "SUCCESS")
                                end,
                                set = function(_, val)
                                    local db = DB()
                                    local entry = EnsureEntry(sid)
                                    db.spellOverrides[sid] = db.spellOverrides[sid] or {}
                                    db.spellOverrides[sid].cd = db.spellOverrides[sid].cd or entry.cd
                                    db.spellOverrides[sid].trigger = ctx.NormalizeTrigger(val)
                                    ctx.RefreshAllVisiblePlates()
                                    ctx.NotifySpellsChanged()
                                end,
                            },
                            spacer3 = { type = "description", order = 6.5, name = "\n\n", width = "full" },
                            removeSpell = {
                                type = "execute",
                                order = 7,
                                width = "normal",
                                name = "Remove Spell",
                                desc = "Removes this spell from tracking (base spells become disabled).",
                                func = function()
                                    RemoveEntry(sid, row.fromBase)
                                    ctx.RefreshAllVisiblePlates()
                                    ctx.NotifySpellsChanged()
                                end,
                            },
                        },
                    }
                end

                spells.args[categoryKey] = {
                    type = "group",
                    name = categoryLabel,
                    desc = format("Category controls and tracked spells for %s.", tostring(categoryLabel)),
                    order = 100 + order,
                    childGroups = "tree",
                    args = categoryArgs,
                }
            end
        end
    end

    RebuildSpellArgs()
    ctx.STATE.rebuildSpellArgs = RebuildSpellArgs

    ctx.OptionsModule.RegisterPanels({
        AceConfig = ctx.AceConfig,
        AceConfigDialog = ctx.AceConfigDialog,
        AceDBOptions = ctx.AceDBOptions,
        aceDB = ctx.GetAceDB(),
        root = root,
        general = general,
        style = style,
        position = position,
        spells = spells,
    })

    ctx.SetBuilt(true)
end
