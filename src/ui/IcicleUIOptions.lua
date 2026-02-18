IcicleUIOptions = IcicleUIOptions or {}

local strfind, strlower = string.find, string.lower
local tinsert = table.insert

function IcicleUIOptions.BuildOptionsPanel(ctx)
    if ctx.IsBuilt() or not (ctx.AceConfig and ctx.AceConfigDialog) then
        return
    end

    local function DB()
        return ctx.GetDB()
    end

    local function L(key, fallback)
        if type(IcicleLocale) == "table" and IcicleLocale.Get then
            return IcicleLocale.Get(key, fallback)
        end
        return fallback
    end

    local root = {
        type = "group",
        name = "Icicle Reborn",
        args = {
            introOverview = {
                type = "description",
                order = 1,
                name = "Icicle Reborn tracks enemy cooldown usage and shows active cooldown timers directly on nameplates. " ..
                    "It is designed to give fast combat awareness without needing to move your eyes away from enemy units.\n\n" ..
                    "The addon listens to combat events, identifies who casted what, maps that information to visible nameplates, " ..
                    "and renders countdown icons with category-aware visuals.",
            },
            introSpacer1 = {
                type = "description",
                order = 2,
                name = " ",
                width = "full",
            },
            howItWorksHeader = {
                type = "header",
                order = 3,
                name = "How It Works",
            },
            howItWorksBody = {
                type = "description",
                order = 4,
                name = "1. Detection: Icicle Reborn reads combat log events and unit cast signals.\n" ..
                    "2. Rule Resolution: It applies cooldown rules (base cooldowns, shared cooldown links, reset effects, and spec modifiers).\n" ..
                    "3. Identity Mapping: It resolves caster GUID/name to the correct visible nameplate.\n" ..
                    "4. Rendering: It draws cooldown icons, countdown text, and border cues on each nameplate.\n" ..
                    "5. Filtering: Optional class/category filtering prevents impossible spell-to-class assignments.",
            },
            introSpacer2 = {
                type = "description",
                order = 5,
                name = " ",
                width = "full",
            },
            setupHeader = {
                type = "header",
                order = 6,
                name = "Recommended Setup Flow",
            },
            setupBody = {
                type = "description",
                order = 7,
                name = "1. General: Choose where Icicle Reborn runs (arena, battleground, world, party, raid).\n" ..
                    "2. Style settings: Adjust icon size, text, and border thickness/inset.\n" ..
                    "3. Position settings: Anchor and offset the icon container around nameplates.\n" ..
                    "4. Tracked Spells: Review categories, enable/disable entries, and customize category border colors.\n" ..
                    "5. Profiles: Save or copy presets for different characters/specs.",
            },
            introSpacer3 = {
                type = "description",
                order = 8,
                name = " ",
                width = "full",
            },
            notesHeader = {
                type = "header",
                order = 9,
                name = "Notes",
            },
            notesBody = {
                type = "description",
                order = 10,
                name = "- Interrupt highlighting pulses the border and uses the spell/category border color.\n" ..
                    "- Category border visibility can be toggled per category in Tracked Spells.\n" ..
                    "- On first install or profile reset, default tracked spells/categories are loaded from the addon dataset.\n" ..
                    "- Default enabled set is curated: interrupt, stun, incapacitate, damage-reduction, and movement-impair-removal spells are enabled; other default spells remain disabled until manually enabled.\n" ..
                    "- If mapping is ambiguous (multiple same-name enemies), targeting/focus/mouseover helps resolve ownership faster.",
            },
            introSpacer4 = {
                type = "description",
                order = 11,
                name = " ",
                width = "full",
            },
            quickNavHeader = {
                type = "header",
                order = 12,
                name = "Panels",
            },
            quickNavBody = {
                type = "description",
                order = 13,
                name = "General, Style settings, Position settings, Tracked Spells, Testing, Profiles",
            },
        },
    }

    local function OptionsSet(info, value)
        local db = DB()
        db[info[#info]] = value
        ctx.RefreshAllVisiblePlates()
    end

    local function OptionsGet(info)
        local db = DB()
        return db[info[#info]]
    end

    local general = {
        type = "group",
        name = "General",
        get = OptionsGet,
        set = OptionsSet,
        args = {
            desc = { type = "description", order = 1, name = "Display conditions and runtime behavior." },

            zonesHeader = { type = "header", order = 2, name = "Zones" },
            all = { type = "toggle", order = 2.1, name = "Enable everywhere", desc = "Ignores zone filters and enables Icicle Reborn in all zones." },
            arena = { type = "toggle", order = 2.2, name = "Arena", desc = "Enable Icicle Reborn while in arena instances." },
            battleground = { type = "toggle", order = 2.3, name = "Battleground", desc = "Enable Icicle Reborn while in battleground instances." },
            field = { type = "toggle", order = 2.4, name = "World", desc = "Enable Icicle Reborn in open world/non-instance zones." },
            party = { type = "toggle", order = 2.5, name = L("general.party", "Party"), desc = "Enable Icicle Reborn in 5-player dungeon instances." },
            raid = { type = "toggle", order = 2.6, name = L("general.raid", "Raid"), desc = "Enable Icicle Reborn in raid instances." },
            sep1 = { type = "description", order = 2.7, name = " ", width = "full" },

            behaviorHeader = { type = "header", order = 3, name = "Behavior" },
            showTooltips = { type = "toggle", order = 3.1, name = "Show tooltips", desc = "Shows tooltip details when hovering nameplate icons." },
            showInterruptWhenCapped = { type = "toggle", order = 3.2, name = L("general.show_interrupt_when_capped", "Prioritize interrupt cooldowns when capped"), desc = "When icon cap is reached, prefer showing interrupt cooldowns first." },
            highlightInterrupts = { type = "toggle", order = 3.3, name = L("style.highlight_interrupts", "Highlight interrupts"), desc = "Do border pulses of interrupt cooldowns." },
            classCategoryFilterEnabled = { type = "toggle", order = 3.4, name = L("general.class_filter", "Filter by spell class/category"), desc = "Prevents class-category spells (Warrior, Druid, etc.) from being assigned to units with a conflicting detected class." },
            showOutOfRangeInspectMessages = { type = "toggle", order = 3.5, name = L("general.show_out_of_range_inspect", "Show out-of-range inspect warnings"), desc = "Prints a message when inspect-based spec detection cannot complete due to range." },
            showAmbiguousFallback = { type = "toggle", order = 3.6, name = "Show ambiguous icon", desc = "Show '?' icon for ambiguity unit (target/focus/mouseover the unit to detect cooldowns)" },
            debug = { type = "toggle", order = 3.7, name = "Debug mode", desc = "Enables additional debug output for troubleshooting." },
            testMode = {
                type = "toggle",
                order = 3.8,
                name = "Test mode",
                desc = "Enable or disable synthetic cooldown icons on visible nameplates for UI testing.",
                get = function()
                    return ctx.STATE and ctx.STATE.testModeActive and true or false
                end,
                set = function(_, value)
                    local active = ctx.STATE and ctx.STATE.testModeActive and true or false
                    if (value and not active) or ((not value) and active) then
                        ctx.ToggleTestMode()
                    end
                end,
            },
            sep2 = { type = "description", order = 3.9, name = " ", width = "full" },

            performanceHeader = { type = "header", order = 4, name = "Performance" },
            scanInterval = { type = "range", order = 4.1, name = "Scan interval", desc = "How often nameplates are scanned for updates.", min = 0.10, max = 0.50, step = 0.01 },
            iconUpdateInterval = { type = "range", order = 4.2, name = "Icon update interval", desc = "How often cooldown texts/colors are refreshed.", min = 0.05, max = 0.30, step = 0.01 },
            groupScanInterval = { type = "range", order = 4.3, name = "Group signal scan", desc = "How often group targets are used to resolve GUID/nameplate mapping.", min = 0.10, max = 1.00, step = 0.05 },
            sep3 = { type = "description", order = 4.4, name = " ", width = "full" },

            filtersHeader = { type = "header", order = 5, name = "Filters" },
            minTrackedCooldown = { type = "range", order = 5.1, name = L("general.min_cd_filter", "Min tracked cooldown (sec)"), desc = "Ignore spells with cooldown below this value.", min = 0, max = 600, step = 1 },
            maxTrackedCooldown = { type = "range", order = 5.2, name = L("general.max_cd_filter", "Max tracked cooldown (sec, 0=off)"), desc = "Ignore spells with cooldown above this value (0 disables max filter).", min = 0, max = 1800, step = 5 },
            sep4 = { type = "description", order = 5.3, name = " ", width = "full" },

            inspectHeader = { type = "header", order = 6, name = "Inspect" },
            inspectRetryInterval = { type = "range", order = 6.1, name = L("general.inspect_retry_interval", "Inspect retry interval"), desc = "Delay between inspect retries while waiting for spec data.", min = 0.2, max = 5.0, step = 0.1 },
            inspectMaxRetryTime = { type = "range", order = 6.2, name = L("general.inspect_max_retry", "Inspect max retry time"), desc = "Maximum time to keep retrying inspect before giving up.", min = 5, max = 120, step = 1 },
        },
    }

    local fontChoices = {
        ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata TT",
        ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
        ["Fonts\\MORPHEUS.TT"] = "Morpheus",
        ["Fonts\\SKURRI.TTF"] = "Skurri",
    }

    local style = {
        type = "group",
        name = "Style settings",
        get = OptionsGet,
        set = OptionsSet,
        args = {
            desc = { type = "description", order = 1, name = "Icon/text appearance." },
            iconSize = { type = "range", order = 2, name = "Icon size", desc = "Sets the width/height of each cooldown icon.", min = 10, max = 64, step = 1 },
            fontSize = { type = "range", order = 3, name = "Font size", desc = "Controls the cooldown text size inside icons.", min = 6, max = 30, step = 1 },
            textfont = { type = "select", order = 4, name = "Font face", desc = "Selects the font used for cooldown text and markers.", values = fontChoices },
            iconSpacing = { type = "range", order = 5, name = "Icon spacing", desc = "Horizontal/vertical gap between icons.", min = 0, max = 20, step = 1 },
            maxIconsPerRow = { type = "range", order = 6, name = "Max icons per row", desc = "Maximum number of icons shown in each row.", min = 1, max = 20, step = 1 },
            maxIcons = { type = "range", order = 7, name = "Max icons", desc = "Total icon cap per nameplate.", min = 1, max = 40, step = 1 },
            spacer1 = { type = "description", order = 8, name = " ", width = "full" },
            bordersHeader = { type = "header", order = 9, name = "Borders" },
            priorityBorderSize = {
                type = "range",
                order = 9.1,
                name = L("style.border_size", "Border thickness"),
                desc = "Thickness of highlight borders.",
                min = 1, max = 6, step = 1,
            },
            priorityBorderInset = {
                type = "range",
                order = 9.2,
                name = L("style.border_inset", "Border inset"),
                desc = "Moves border inward/outward relative to icon edges.",
                min = -2, max = 4, step = 1,
            },
            spacer2 = { type = "description", order = 9.3, name = "\n", width = "full" },
        },
    }

    local position = {
        type = "group",
        name = "Position settings",
        get = OptionsGet,
        set = OptionsSet,
        args = {
            desc = { type = "description", order = 1, name = "Container anchor and growth configuration." },
            spacer1 = { type = "description", order = 1.5, name = "", width = "full" },
            anchorPoint = { type = "select", order = 2, name = "Frame anchor", desc = "Anchor point used by Icicle Reborn icon container.", values = ctx.POINT_VALUES },
            anchorTo = { type = "select", order = 3, name = "Nameplate anchor", desc = "Nameplate point that the Icicle Reborn container attaches to.", values = ctx.POINT_VALUES },
            spacer2 = { type = "description", order = 3.5, name = "", width = "full" },
            xOffset = { type = "range", order = 4, name = "X offset", desc = "Horizontal offset from the selected anchor point.", min = -200, max = 200, step = 1 },
            yOffset = { type = "range", order = 5, name = "Y offset", desc = "Vertical offset from the selected anchor point.", min = -200, max = 200, step = 1 },
            spacer3 = { type = "description", order = 5.5, name = "", width = "full" },
            growthDirection = { type = "select", order = 6, name = "Growth direction", desc = "Direction used when adding more icons in the grid.", values = ctx.GROW_VALUES },
            frameStrata = {
                type = "select",
                order = 7,
                name = "Layer priority",
                desc = "Rendering layer priority of Icicle Reborn icons relative to other UI elements.",
                values = { LOW = "LOW", MEDIUM = "MEDIUM", HIGH = "HIGH" }
            },
        },
    }

    local tmpAddSpellIDByCategory = {}
    local spellSearchText = ""
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

        ctx.editState.spellID = tostring(sid)
        ctx.SyncEditStateFromSpellID(sid)
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
                    spellSearchText = val or ""
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
            local passesEnabledFilter = true
            if matchesSearch and passesEnabledFilter then
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
                    ctx.Print("All spells in category " .. tostring(categoryLabel) .. " were Enabled.")
                else
                    ctx.Print("All spells in category " .. tostring(categoryLabel) .. " were Disabled.")
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
                    -- Restore default spell state for this category:
                    -- removed/override/category reset; enabled state follows default enabled preset.
                    db.spellOverrides[sid] = nil
                    if (not hasDefaultEnabledMap) or defaultEnabledMap[sid] then
                        db.disabledSpells[sid] = nil
                    else
                        db.disabledSpells[sid] = true
                    end
                    db.removedBaseSpells[sid] = nil
                    db.spellCategories[sid] = categoryKey
                end
            else
                -- Fallback safety: preserve old behavior if category map is unavailable.
                local rowsInCategory = allRowsByCategory[categoryKey] or {}
                for i = 1, #rowsInCategory do
                    if rowsInCategory[i].fromBase then
                        local sid = rowsInCategory[i].id
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
                ctx.Print("Category " .. tostring(categoryLabel) .. " was restored.")
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
                        name = " " .. tostring(categoryLabel) .. " color",
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
                        name = "Add Spell to " .. categoryLabel,
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
                                    ctx.editState.spellID = tostring(newSid)
                                    ctx.SyncEditStateFromSpellID(newSid)
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
                    desc = "Category controls and tracked spells for " .. tostring(categoryLabel) .. ".",
                    order = 100 + order,
                    childGroups = "tree",
                    args = categoryArgs,
                }
            end
        end
    end

    local testState = {
        specUnit = "",
        specValue = "survival",
        ruleSpellID = "",
        simSpellID = "",
        simEvent = "SPELL_CAST_SUCCESS",
        simSourceName = "TestEnemy",
        matrixSummary = "",
        matrixOutput = "No test executed.",
        configPayload = "",
        shareCode = "",
    }

    local testing = {
        type = "group",
        name = "Testing",
        args = {
            testingDesc = {
                type = "description",
                order = 1,
                width = "full",
                name = "Tools to validate Icicle Reborn behavior in one place. These controls are intended for development/testing only.",
            },
            spacer1 = { type = "description", order = 1.5, width = "full", name = " " },
            toggleTestMode = {
                type = "execute",
                order = 2,
                width = "normal",
                name = "Test Mode",
                desc = "Enables or disables synthetic cooldown icons on visible nameplates for UI testing.",
                func = function()
                    ctx.ToggleTestMode()
                end,
            },
            spacer2 = { type = "description", order = 3, width = "full", name = " " },
            ruleHeader = {
                type = "header",
                order = 4,
                name = "Cooldown Rule Inspector",
            },
            ruleSpellID = {
                type = "input",
                order = 5,
                width = "normal",
                name = "Spell ID",
                desc = "Spell ID used by the rule inspector.",
                get = function() return testState.ruleSpellID end,
                set = function(_, v) testState.ruleSpellID = v or "" end,
            },
            ruleInspect = {
                type = "execute",
                order = 6,
                width = "normal",
                name = "Inspect Rule",
                desc = "Shows resolved cooldown rule details for the entered Spell ID.",
                func = function()
                    local sid = tonumber(testState.ruleSpellID or "")
                    if not sid then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "Invalid spell ID for rule inspection."
                        return
                    end
                    local line = nil
                    if ctx.DescribeSpellRule then
                        line = ctx.DescribeSpellRule(sid)
                    elseif ctx.DebugSpellRule then
                        line = "Rule printed in chat (fallback mode)."
                        ctx.DebugSpellRule(testState.ruleSpellID)
                    end
                    testState.matrixOutput = line or "Rule inspector unavailable."
                end,
            },
            spacer3 = { type = "description", order = 6.5, width = "full", name = " " },
            specHeader = {
                type = "header",
                order = 8,
                name = "Spec Hint (for modifier testing)",
            },
            specDetectEnabled = {
                type = "toggle",
                order = 8.1,
                width = "normal",
                name = "Auto Spec Detection",
                desc = "When enabled, Icicle Reborn infers enemy spec from observed spells.",
                get = function()
                    local db = DB()
                    return db.specDetectEnabled and true or false
                end,
                set = function(_, v)
                    local db = DB()
                    db.specDetectEnabled = v and true or false
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Auto Spec Detection: " .. (db.specDetectEnabled and "ON" or "OFF")
                end,
            },
            specHintTTL = {
                type = "range",
                order = 8.2,
                width = "full",
                name = "Spec Hint TTL (seconds)",
                desc = "How long inferred spec hints are kept before expiring.",
                min = 30,
                max = 3600,
                step = 10,
                get = function()
                    local db = DB()
                    return tonumber(db.specHintTTL) or 300
                end,
                set = function(_, v)
                    local db = DB()
                    db.specHintTTL = math.max(30, math.min(3600, tonumber(v) or 300))
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Spec Hint TTL: " .. tostring(db.specHintTTL) .. "s"
                end,
            },
            specUnit = {
                type = "input",
                order = 9,
                width = "normal",
                name = "Unit Key (name or GUID)",
                desc = "Target unit for manual spec hint operations.",
                get = function() return testState.specUnit end,
                set = function(_, v) testState.specUnit = v or "" end,
            },
            specValue = {
                type = "select",
                order = 10,
                width = "normal",
                name = "Spec Key",
                desc = "Manual spec value to assign to the unit key.",
                values = {
                    survival = "survival",
                    arcane = "arcane",
                    retri = "retri",
                    protPala = "protPala",
                    shadow = "shadow",
                    combat = "combat",
                    sub = "sub",
                    ele = "ele",
                    demo = "demo",
                    fury = "fury",
                    protWar = "protWar",
                    feral = "feral",
                },
                get = function() return testState.specValue end,
                set = function(_, v) testState.specValue = v or "survival" end,
            },
            specSet = {
                type = "execute",
                order = 11,
                width = "normal",
                name = "Set Spec Hint",
                desc = "Stores a manual spec hint for the selected unit key.",
                func = function()
                    if not ctx.SetUnitSpecHint then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "SetUnitSpecHint unavailable."
                        return
                    end
                    local ok, err = ctx.SetUnitSpecHint(testState.specUnit, testState.specValue)
                    testState.matrixOutput = ok and ("Spec hint set: " .. tostring(testState.specUnit) .. " -> " .. tostring(testState.specValue)) or ("Spec hint error: " .. tostring(err))
                end,
            },
            persistSpecHints = {
                type = "toggle",
                order = 11.2,
                width = "normal",
                name = "Persist Spec Hints",
                desc = "Saves runtime spec hints to profile data between sessions/reloads.",
                get = function()
                    local db = DB()
                    return db.persistSpecHints and true or false
                end,
                set = function(_, v)
                    local db = DB()
                    db.persistSpecHints = v and true or false
                    if ctx.SetPersistSpecHints then
                        ctx.SetPersistSpecHints(db.persistSpecHints)
                    end
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Persist Spec Hints: " .. (db.persistSpecHints and "ON" or "OFF")
                end,
            },
            specClear = {
                type = "execute",
                order = 12,
                width = "normal",
                name = "Clear Spec Hint",
                desc = "Removes manual/runtime spec hint for the selected unit key.",
                func = function()
                    if not ctx.SetUnitSpecHint then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "SetUnitSpecHint unavailable."
                        return
                    end
                    local ok, err = ctx.SetUnitSpecHint(testState.specUnit, "")
                    testState.matrixOutput = ok and ("Spec hint cleared for: " .. tostring(testState.specUnit)) or ("Spec clear error: " .. tostring(err))
                end,
            },
            spacer4 = { type = "description", order = 12.5, width = "full", name = " " },
            simHeader = {
                type = "header",
                order = 13,
                name = "Simulate Cooldown Event",
            },
            simSourceName = {
                type = "input",
                order = 14,
                width = "normal",
                name = "Source Name",
                desc = "Source unit name used by event simulation.",
                get = function() return testState.simSourceName end,
                set = function(_, v) testState.simSourceName = v or "TestEnemy" end,
            },
            simSpellID = {
                type = "input",
                order = 15,
                width = "normal",
                name = "Spell ID",
                desc = "Spell ID used by event simulation.",
                get = function() return testState.simSpellID end,
                set = function(_, v) testState.simSpellID = v or "" end,
            },
            simEvent = {
                type = "select",
                order = 16,
                width = "normal",
                name = "Combat Event",
                desc = "Combat log event type used by simulation.",
                values = {
                    SPELL_CAST_SUCCESS = "SPELL_CAST_SUCCESS",
                    SPELL_AURA_APPLIED = "SPELL_AURA_APPLIED",
                    SPELL_CAST_START = "SPELL_CAST_START",
                },
                get = function() return testState.simEvent end,
                set = function(_, v) testState.simEvent = v or "SPELL_CAST_SUCCESS" end,
            },
            simulateButton = {
                type = "execute",
                order = 17,
                width = "normal",
                name = "Simulate Event",
                desc = "Injects a synthetic cooldown event using the fields above.",
                func = function()
                    local sid = tonumber(testState.simSpellID or "")
                    if not sid then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "Invalid spell ID for simulation."
                        return
                    end
                    if not ctx.StartCooldown then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "StartCooldown unavailable."
                        return
                    end
                    ctx.StartCooldown(nil, testState.simSourceName, sid, GetSpellInfo(sid), testState.simEvent)
                    testState.matrixOutput = "Simulated " .. tostring(testState.simEvent) .. " for spell " .. tostring(sid) .. " from " .. tostring(testState.simSourceName)
                end,
            },
            spacer5 = { type = "description", order = 17.5, width = "full", name = " " },
            matrixHeader = {
                type = "header",
                order = 18,
                name = "Matrix Self Tests",
            },
            matrixStrictMode = {
                type = "toggle",
                order = 18.2,
                width = "normal",
                name = "Strict Mode",
                desc = "Enables stricter matrix validation checks.",
                get = function()
                    local db = DB()
                    return db.matrixStrictSelfTests and true or false
                end,
                set = function(_, v)
                    local db = DB()
                    db.matrixStrictSelfTests = v and true or false
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Matrix strict mode: " .. (db.matrixStrictSelfTests and "ON" or "OFF")
                end,
            },
            matrixLogEnabled = {
                type = "toggle",
                order = 18.3,
                width = "normal",
                name = "Matrix Action Log",
                desc = "Records detailed shared/reset matrix actions for debugging.",
                get = function()
                    local db = DB()
                    return db.matrixLogEnabled and true or false
                end,
                set = function(_, v)
                    local db = DB()
                    db.matrixLogEnabled = v and true or false
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Matrix action log: " .. (db.matrixLogEnabled and "ON" or "OFF")
                end,
            },
            runMatrixTests = {
                type = "execute",
                order = 19,
                width = "normal",
                name = "Run Matrix Self Tests",
                desc = "Runs focused matrix sanity checks (shared, reset, modifiers, coverage).",
                func = function()
                    if not ctx.RunMatrixSelfTests then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunMatrixSelfTests unavailable."
                        return
                    end
                    local results = ctx.RunMatrixSelfTests()
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No self-test results."
                        return
                    end
                    local pass, fail = 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Summary: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runMatrixParity = {
                type = "execute",
                order = 19.05,
                width = "normal",
                name = "Run Default Dataset Integrity",
                desc = "Compares current matrix status against Icicle Reborn default dataset baseline and lists unresolved references.",
                func = function()
                    if not ctx.RunMatrixParityReport then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunMatrixParityReport unavailable."
                        return
                    end
                    local results = ctx.RunMatrixParityReport()
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No dataset integrity results."
                        return
                    end
                    local pass, fail, skip = 0, 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        elseif string.find(line, "=SKIP", 1, true) then
                            skip = skip + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Dataset Integrity: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. " | SKIP " .. tostring(skip) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runTriggerParity = {
                type = "execute",
                order = 19.08,
                width = "normal",
                name = "Run Default Trigger Integrity",
                desc = "Checks effective spell triggers against Icicle Reborn default trigger baseline.",
                func = function()
                    if not ctx.RunTriggerParityReport then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunTriggerParityReport unavailable."
                        return
                    end
                    local results = ctx.RunTriggerParityReport()
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No trigger integrity results."
                        return
                    end
                    local pass, fail = 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Trigger Integrity: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runSnapshotFixtures = {
                type = "execute",
                order = 19.09,
                width = "normal",
                name = "Run Snapshot Fixture Check",
                desc = "Validates key expected validation lines to detect behavioral drift.",
                func = function()
                    if not ctx.RunSnapshotFixtureCheck then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunSnapshotFixtureCheck unavailable."
                        return
                    end
                    local full = ctx.RunFullValidation and ctx.RunFullValidation() or nil
                    if type(full) ~= "table" or #full == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No validation output for snapshot check."
                        return
                    end
                    local results = ctx.RunSnapshotFixtureCheck(full)
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No snapshot results."
                        return
                    end
                    local pass, fail = 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Snapshot Fixtures: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runRegression = {
                type = "execute",
                order = 19.1,
                width = "normal",
                name = "Run Regression Scenario",
                desc = "Runs a fixed scenario and compares actual cooldown snapshot to expected output.",
                func = function()
                    if not ctx.RunRegressionHarness then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunRegressionHarness unavailable."
                        return
                    end
                    local results = ctx.RunRegressionHarness()
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No regression results."
                        return
                    end
                    local pass, fail = 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Regression: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runFullValidation = {
                type = "execute",
                order = 19.15,
                width = "normal",
                name = "Run Full Validation",
                desc = "Runs basic matrix tests, regression harness, and strict matrix checks in one action.",
                func = function()
                    if not ctx.RunFullValidation then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunFullValidation unavailable."
                        return
                    end
                    local results = ctx.RunFullValidation()
                    if type(results) ~= "table" or #results == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No full validation results."
                        return
                    end
                    local pass, fail = 0, 0
                    for i = 1, #results do
                        local line = tostring(results[i] or "")
                        if string.find(line, "=PASS", 1, true) then
                            pass = pass + 1
                        elseif string.find(line, "=FAIL", 1, true) then
                            fail = fail + 1
                        end
                    end
                    local statusColor = fail > 0 and "|cffff4040" or "|cff40ff40"
                    testState.matrixSummary = statusColor .. "Full Validation: PASS " .. tostring(pass) .. " | FAIL " .. tostring(fail) .. "|r"
                    testState.matrixOutput = table.concat(results, "\n")
                end,
            },
            runDiagnostic = {
                type = "execute",
                order = 19.17,
                width = "normal",
                name = "Copy Diagnostic Report",
                desc = "Builds a full diagnostic bundle (settings + health + validations) into the output field for copy/paste.",
                func = function()
                    if not ctx.RunDiagnosticReport then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunDiagnosticReport unavailable."
                        return
                    end
                    local lines = ctx.RunDiagnosticReport()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No diagnostic output."
                        return
                    end
                    testState.matrixSummary = "|cff40b0ffDiagnostic Report Ready|r"
                    testState.matrixOutput = table.concat(lines, "\n")
                end,
            },
            runPerformance = {
                type = "execute",
                order = 19.18,
                width = "normal",
                name = "Performance Report",
                desc = "Shows scan/update timings plus resolver and pending-bind metrics.",
                func = function()
                    if not ctx.RunPerformanceReport then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunPerformanceReport unavailable."
                        return
                    end
                    local lines = ctx.RunPerformanceReport()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No performance output."
                        return
                    end
                    testState.matrixSummary = "|cff40b0ffPerformance Report|r"
                    testState.matrixOutput = table.concat(lines, "\n")
                end,
            },
            runReactionMap = {
                type = "execute",
                order = 19.185,
                width = "normal",
                name = "Reaction Mapping Report",
                desc = "Shows mapped plates with reaction values by source (unit/combat/color).",
                func = function()
                    if not ctx.RunReactionMappingReport then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunReactionMappingReport unavailable."
                        return
                    end
                    local lines = ctx.RunReactionMappingReport()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No reaction mapping output."
                        return
                    end
                    testState.matrixSummary = "|cff40b0ffReaction Mapping Report|r"
                    testState.matrixOutput = table.concat(lines, "\n")
                end,
            },
            startupHealth = {
                type = "execute",
                order = 19.2,
                width = "normal",
                name = "Startup Health Check",
                desc = "Prints schema/version/module health and key runtime/profile flags.",
                func = function()
                    if not ctx.RunStartupHealthCheck then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunStartupHealthCheck unavailable."
                        return
                    end
                    local lines = ctx.RunStartupHealthCheck()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No startup health output."
                        return
                    end
                    testState.matrixSummary = "|cff40b0ffStartup Health|r"
                    testState.matrixOutput = table.concat(lines, "\n")
                end,
            },
            showMatrixLog = {
                type = "execute",
                order = 19.3,
                width = "normal",
                name = "Show Recent Matrix Actions",
                desc = "Displays recent shared/reset matrix actions captured in the runtime log.",
                func = function()
                    if not ctx.GetMatrixActionLog then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "GetMatrixActionLog unavailable."
                        return
                    end
                    local lines = ctx.GetMatrixActionLog()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No matrix actions logged."
                        return
                    end
                    testState.matrixSummary = "|cff40b0ffRecent Matrix Actions|r"
                    testState.matrixOutput = table.concat(lines, "\n")
                end,
            },
            clearMatrixLog = {
                type = "execute",
                order = 19.4,
                width = "normal",
                name = "Clear Matrix Actions",
                desc = "Clears the stored matrix action log buffer.",
                func = function()
                    if not ctx.ClearMatrixActionLog then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "ClearMatrixActionLog unavailable."
                        return
                    end
                    ctx.ClearMatrixActionLog()
                    testState.matrixSummary = ""
                    testState.matrixOutput = "Matrix action log cleared."
                end,
            },
            exportConfig = {
                type = "execute",
                order = 19.42,
                width = "normal",
                name = "Build Config Export Payload",
                desc = "Builds a copy/paste payload of options and spell customizations.",
                func = function()
                    if not ctx.RunExportConfigPayload then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunExportConfigPayload unavailable."
                        return
                    end
                    local lines = ctx.RunExportConfigPayload()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No export payload generated."
                        return
                    end
                    testState.configPayload = table.concat(lines, "\n")
                    testState.matrixSummary = "|cff40b0ffConfig Export Ready|r"
                    testState.matrixOutput = testState.configPayload
                end,
            },
            exportDefaultDataset = {
                type = "execute",
                order = 19.425,
                width = "normal",
                name = "Build Default Dataset (ID + Name)",
                desc = "Builds DEFAULT_SPELLS_BY_CATEGORY lines with inline spell-name comments from current client.",
                func = function()
                    if not ctx.RunExportDefaultDatasetWithNames then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunExportDefaultDatasetWithNames unavailable."
                        return
                    end
                    local lines = ctx.RunExportDefaultDatasetWithNames()
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No default dataset export generated."
                        return
                    end
                    testState.configPayload = table.concat(lines, "\n")
                    testState.matrixSummary = "|cff40b0ffDefault Dataset Export Ready|r"
                    testState.matrixOutput = testState.configPayload
                end,
            },
            importConfig = {
                type = "execute",
                order = 19.43,
                width = "normal",
                name = "Import Config Payload",
                desc = "Imports options and spell customizations from the payload field below.",
                func = function()
                    if not ctx.RunImportConfigPayload then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "RunImportConfigPayload unavailable."
                        return
                    end
                    local lines = ctx.RunImportConfigPayload(testState.configPayload or "")
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No import result."
                        return
                    end
                    local text = table.concat(lines, "\n")
                    local hasFail = string.find(text, "=FAIL", 1, true) ~= nil
                    testState.matrixSummary = hasFail and "|cffff4040Config Import Failed|r" or "|cff40ff40Config Import Applied|r"
                    testState.matrixOutput = text
                end,
            },
            configPayload = {
                type = "input",
                order = 19.44,
                width = "full",
                name = "Config Payload (export/import)",
                desc = "Paste payload here then click Import Config Payload.",
                multiline = true,
                get = function()
                    return testState.configPayload or ""
                end,
                set = function(_, v)
                    testState.configPayload = v or ""
                end,
            },
            exportShareCode = {
                type = "execute",
                order = 19.45,
                width = "normal",
                name = L("testing.export_share", "Build Share Code"),
                desc = "Builds a compressed/importable profile code.",
                func = function()
                    if not ctx.RunExportShareCode then
                        testState.matrixSummary = ""
                        testState.matrixOutput = L("testing.share_unavailable", "Share-code libraries unavailable (AceSerializer/LibDeflate).")
                        return
                    end
                    local text = ctx.RunExportShareCode()
                    if not text or text == "" then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "Failed to build share code."
                        return
                    end
                    testState.shareCode = text
                    testState.matrixSummary = "|cff40b0ffShare Code Ready|r"
                    testState.matrixOutput = text
                end,
            },
            importShareCode = {
                type = "execute",
                order = 19.46,
                width = "normal",
                name = L("testing.import_share", "Import Share Code"),
                desc = "Imports a compressed profile code into current profile.",
                func = function()
                    if not ctx.RunImportShareCode then
                        testState.matrixSummary = ""
                        testState.matrixOutput = L("testing.share_unavailable", "Share-code libraries unavailable (AceSerializer/LibDeflate).")
                        return
                    end
                    local lines = ctx.RunImportShareCode(testState.shareCode or "")
                    if type(lines) ~= "table" or #lines == 0 then
                        testState.matrixSummary = ""
                        testState.matrixOutput = "No import-share result."
                        return
                    end
                    local text = table.concat(lines, "\n")
                    local hasFail = string.find(text, "=FAIL", 1, true) ~= nil
                    testState.matrixSummary = hasFail and "|cffff4040Share Import Failed|r" or "|cff40ff40Share Import Applied|r"
                    testState.matrixOutput = text
                end,
            },
            shareCode = {
                type = "input",
                order = 19.47,
                width = "full",
                name = L("testing.share_code", "Share Code (compressed)"),
                desc = "Paste share code here then click Import Share Code.",
                multiline = true,
                get = function() return testState.shareCode or "" end,
                set = function(_, v) testState.shareCode = v or "" end,
            },
            outputSummary = {
                type = "description",
                order = 19.6,
                width = "full",
                name = function()
                    return testState.matrixSummary ~= "" and testState.matrixSummary or " "
                end,
            },
            output = {
                type = "input",
                order = 20.1,
                width = "full",
                name = "Output (click, Ctrl+A, Ctrl+C)",
                desc = "Copyable output for test and validation results.",
                multiline = true,
                get = function()
                    return testState.matrixOutput or "No output."
                end,
                set = function() end,
            },
        },
    }

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
        testing = testing,
    })

    ctx.SetBuilt(true)
end
