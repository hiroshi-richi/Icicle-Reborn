IcicleUIOptionTabs = IcicleUIOptionTabs or {}

function IcicleUIOptionTabs.BuildGeneralGroup(ctx)
    local performanceModeValues = (ctx.ConfigModule and ctx.ConfigModule.GetPerformanceModeOptions and ctx.ConfigModule.GetPerformanceModeOptions()) or {
        BATTERY = "1. Battery Saver (Slowest)",
        LOW_END = "2. Low-End PC",
        BALANCED = "3. Balanced",
        HIGH_END = "4. High-End PC",
        ARENA = "5. Arena (Fastest)",
    }
    local performanceModeSorting = (ctx.ConfigModule and ctx.ConfigModule.GetPerformanceModeOrder and ctx.ConfigModule.GetPerformanceModeOrder()) or {
        "BATTERY",
        "LOW_END",
        "BALANCED",
        "HIGH_END",
        "ARENA",
    }

    return {
        type = "group",
        name = "General",
        get = ctx.OptionsGet,
        set = ctx.OptionsSet,
        args = {
            desc = { type = "description", order = 1, name = "Display conditions and runtime behavior." },

            zonesHeader = { type = "header", order = 2, name = "Zones" },
            arena = { type = "toggle", order = 2.1, name = "Arena", desc = "Enable Icicle: Reborn while in arena instances. Zone enable/disable applies after a 2-second safety delay." },
            battleground = { type = "toggle", order = 2.2, name = "Battleground", desc = "Enable Icicle: Reborn while in battleground instances. Zone enable/disable applies after a 2-second safety delay." },
            field = { type = "toggle", order = 2.3, name = "World", desc = "Enable Icicle: Reborn in open world/non-instance zones. Zone enable/disable applies after a 2-second safety delay." },
            party = { type = "toggle", order = 2.4, name = "Party", desc = "Enable Icicle: Reborn in 5-player dungeon instances. Zone enable/disable applies after a 2-second safety delay." },
            raid = { type = "toggle", order = 2.5, name = "Raid", desc = "Enable Icicle: Reborn in raid instances. Zone enable/disable applies after a 2-second safety delay." },
            sep1 = { type = "description", order = 2.6, name = " ", width = "full" },

            behaviorHeader = { type = "header", order = 3, name = "Behavior" },
            showTooltips = { type = "toggle", order = 3.1, name = "Show tooltips", desc = "Shows tooltip details when hovering nameplate icons. Higher CPU cost." },
            specDetectEnabled = { type = "toggle", order = 3.2, name = "Enable Advanced Spec Detection", desc = "Uses aura/inspect detection for modifier-aware cooldowns. Higher CPU cost." },
            classCategoryFilterEnabled = { type = "toggle", order = 3.3, name = "Filter by spell-class", desc = "Supports filtering to prevent spell-class mismatches." },
            showOutOfRangeInspectMessages = { type = "toggle", order = 3.4, name = "Show out-of-range inspect warnings", desc = "Prints a message when aura/inspect detection cannot complete due to range." },
            showAmbiguousByName = { type = "toggle", order = 3.5, name = "Show ambiguous icon", desc = "Shows a '?' icon when ownership is ambiguous (target/focus/mouseover helps resolve faster)." },
            testMode = {
                type = "toggle",
                order = 3.6,
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
            debugMode = {
                type = "toggle",
                order = 3.7,
                name = "Debug mode",
                desc = "Prints chat messages when Icicle is enabled or disabled at runtime (zone changes, test mode, and similar transitions).",
            },
            sep2 = { type = "description", order = 3.8, name = " ", width = "full" },

            interruptHeader = { type = "header", order = 4, name = "Interrupt" },
            showInterruptWhenCapped = { type = "toggle", order = 4.1, name = "Prioritize interrupt cooldowns when capped", desc = "When icon cap is reached, prefer showing interrupt cooldowns first." },
            highlightInterrupts = { type = "toggle", order = 4.2, name = "Highlight interrupts", desc = "Enable interrupt pulse highlighting." },
            interruptHighlightMode = {
                type = "select",
                order = 4.3,
                name = "How to highlight interrupts?",
                desc = "Choose whether interrupt pulses animate the border or the icon.",
                values = {
                    BORDER = "Border pulses",
                    ICON = "Icon pulses",
                },
            },
            sep3 = { type = "description", order = 4.4, name = " ", width = "full" },

            filtersHeader = { type = "header", order = 5, name = "Filters" },
            minTrackedCooldown = { type = "range", order = 5.1, name = "Min tracked cooldown (sec)", desc = "Ignore spells with cooldown below this value.", min = 0, max = 600, step = 1 },
            maxTrackedCooldown = { type = "range", order = 5.2, name = "Max tracked cooldown (sec, 0=off)", desc = "Ignore spells with cooldown above this value (0 disables max filter).", min = 0, max = 1800, step = 5 },
            sep4 = { type = "description", order = 5.3, name = " ", width = "full" },

            performanceHeader = { type = "header", order = 6, name = "Performance" },
            performanceMode = {
                type = "select",
                order = 6.1,
                name = "Performance mode",
                desc = "Runtime modes for defining the refresh rate and inspection retry parameters.",
                values = performanceModeValues,
                sorting = performanceModeSorting,
            },
            sep5 = { type = "description", order = 6.2, name = " ", width = "full" },
        },
    }
end

function IcicleUIOptionTabs.BuildStyleGroup(ctx)
    local fontChoices = {
        ["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata TT",
        ["Fonts\\ARIALN.TTF"] = "Arial Narrow",
        ["Fonts\\MORPHEUS.TT"] = "Morpheus",
        ["Fonts\\SKURRI.TTF"] = "Skurri",
    }

    return {
        type = "group",
        name = "Style settings",
        get = ctx.OptionsGet,
        set = ctx.OptionsSet,
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
                name = "Border thickness",
                desc = "Thickness of highlight borders.",
                min = 1, max = 6, step = 1,
            },
            priorityBorderInset = {
                type = "range",
                order = 9.2,
                name = "Border inset",
                desc = "Moves border inward/outward relative to icon edges.",
                min = -2, max = 4, step = 1,
            },
            showBorders = {
                type = "toggle",
                order = 9.3,
                name = "Show borders",
                desc = "Show category color borders.",
            }
        },
    }
end

function IcicleUIOptionTabs.BuildPositionGroup(ctx)
    return {
        type = "group",
        name = "Position settings",
        get = ctx.OptionsGet,
        set = ctx.OptionsSet,
        args = {
            desc = { type = "description", order = 1, name = "Container anchor and growth configuration." },
            spacer1 = { type = "description", order = 1.5, name = "", width = "full" },
            anchorPoint = { type = "select", order = 2, name = "Frame anchor", desc = "Anchor point used by Icicle: Reborn icon container.", values = ctx.POINT_VALUES },
            anchorTo = { type = "select", order = 3, name = "Nameplate anchor", desc = "Nameplate point that the Icicle: Reborn container attaches to.", values = ctx.POINT_VALUES },
            spacer2 = { type = "description", order = 3.5, name = "", width = "full" },
            xOffset = { type = "range", order = 4, name = "X offset", desc = "Horizontal offset from the selected anchor point.", min = -200, max = 200, step = 1 },
            yOffset = { type = "range", order = 5, name = "Y offset", desc = "Vertical offset from the selected anchor point.", min = -200, max = 200, step = 1 },
            spacer3 = { type = "description", order = 5.5, name = "", width = "full" },
            growthDirection = { type = "select", order = 6, name = "Growth direction", desc = "Direction used when adding more icons in the grid.", values = ctx.GROW_VALUES },
            frameStrata = {
                type = "select",
                order = 7,
                name = "Layer priority",
                desc = "Rendering layer priority of Icicle: Reborn icons relative to other UI elements.",
                values = { LOW = "LOW", MEDIUM = "MEDIUM", HIGH = "HIGH" }
            },
        },
    }
end
