IcicleCooldownRules = IcicleCooldownRules or {}

-- Cooldown interaction data (shared and reset relationships).

local SHARED_COOLDOWNS = {
    -- PvP trinkets/racials
    [51378] = {
        [7744] = { sharedDuration = 45 },   -- Will of the Forsaken
        [59752] = { sharedDuration = 120 }, -- Every Man for Himself
    },
    [59752] = {
        [51378] = { sharedDuration = 120 },
    },
    [7744] = {
        [51378] = { sharedDuration = 45 },
    },

    -- Druid
    [16979] = { [49376] = {} }, -- Feral Charge Bear -> Cat
    [49376] = { [16979] = {} }, -- Feral Charge Cat -> Bear

    -- Hunter trap families
    [60192] = { [14311] = {}, [13809] = {} }, -- Freezing Arrow
    [14311] = { [60192] = {}, [13809] = {} }, -- Freezing Trap
    [13809] = { [60192] = {}, [14311] = {} }, -- Frost Trap
    [49055] = { [49067] = {} },               -- Immolation Trap -> Explosive Trap
    [49067] = { [49055] = {} },               -- Explosive Trap -> Immolation Trap

    -- Paladin
    [31884] = { -- Avenging Wrath
        [498] = { sharedDuration = 30 },   -- Divine Protection
        [642] = { sharedDuration = 30 },   -- Divine Shield
        [48788] = { sharedDuration = 30 }, -- Lay on Hands
        [10278] = { sharedDuration = 30 }, -- Hand of Protection
    },
    [498] = { [31884] = { sharedDuration = 30 } },
    [642] = { [31884] = { sharedDuration = 30 } },
    [48788] = { [31884] = { sharedDuration = 30 } },

    -- Warrior
    [72] = { [6552] = { sharedDuration = 12 } },  -- Shield Bash -> Pummel
    [6552] = { [72] = { sharedDuration = 10 } },  -- Pummel -> Shield Bash
    [1719] = { [871] = { sharedDuration = 12 }, [20230] = { sharedDuration = 12 } }, -- Recklessness
    [871] = { [1719] = { sharedDuration = 12 }, [20230] = { sharedDuration = 12 } }, -- Shield Wall
    [20230] = { [871] = { sharedDuration = 12 }, [1719] = { sharedDuration = 12 } }, -- Retaliation
}

local RESET_COOLDOWNS = {
    -- Hunter: Readiness
    [23989] = {
        [53209] = true, -- Chimera Shot
        [49050] = true, -- Aimed Shot
        [13809] = true, -- Frost Trap
        [14311] = true, -- Freezing Trap
        [60192] = true, -- Freezing Arrow
        [5116] = true,  -- Concussive Shot
        [34026] = true, -- Kill Command
        [53271] = true, -- Master's Call
        [1513] = true,  -- Scare Beast
        [49045] = true, -- Arcane Shot
        [20736] = true, -- Distracting Shot
        [1543] = true,  -- Flare
        [61006] = true, -- Kill Shot
        [49048] = true, -- Multi-Shot
        [3045] = true,  -- Rapid Fire
        [19801] = true, -- Tranquilizing Shot
        [3034] = true,  -- Viper Sting
        [19263] = true, -- Deterrence
        [781] = true,   -- Disengage
        [49067] = true, -- Explosive Trap
        [5384] = true,  -- Feign Death
        [49055] = true, -- Immolation Trap
        [34477] = true, -- Misdirection
        [53339] = true, -- Mongoose Bite
        [48996] = true, -- Raptor Strike
        [34600] = true, -- Snake Trap
        [34490] = true, -- Silencing Shot
        [19503] = true, -- Scatter Shot
    },

    -- Rogue: Preparation
    [14185] = {
        [5277] = true,  -- Evasion
        [11305] = true, -- Sprint
        [1856] = true,  -- Vanish
        [14177] = true, -- Cold Blood
        [36554] = true, -- Shadowstep
        [13877] = true, -- Blade Flurry
        [1766] = true,  -- Kick
        [51722] = true, -- Dismantle
    },

    -- Warlock: Summon Felhunter
    [691] = {
        [19647] = true, -- Spell Lock
    },

    -- Mage: Cold Snap
    [11958] = {
        [43039] = true, -- Ice Barrier
        [43012] = true, -- Frost Ward
        [42917] = true, -- Frost Nova
        [45438] = true, -- Ice Block
        [12472] = true, -- Icy Veins
        [31687] = true, -- Summon Water Elemental
        [44572] = true, -- Deep Freeze
        [42931] = true, -- Cone of Cold
    },
}

local ID_ALIASES = {
    -- PvP trinket canonicalization (Alliance/Horde item IDs).
    [18853] = 51378, -- Medallion of the Alliance (vanilla version)
    [18863] = 51378, -- Medallion of the Horde (vanilla version)
    [37864] = 51378, -- Medallion of the Alliance (tbc version)
    [37865] = 51378, -- Medallion of the Horde (tbc version)
    [42122] = 51378, -- Medallion of the Alliance (wotlk version - phase 1)
    [42123] = 51378, -- Medallion of the Horde (wotlk version - phase 1)
    [42124] = 51378, -- Medallion of the Alliance (wotlk version - phase 2)
    [42126] = 51378, -- Medallion of the Horde (wotlk version - phase 2)
    [51377] = 51378, -- Medallion of the Alliance (wotlk version - phase 4)
    [51378] = 51378, -- Medallion of the Horde (wotlk version - phase 4)

    -- Spell ranks / equivalent IDs used by Icicle custom list
    [6554] = 6552, -- Pummel rank alias
    [2983] = 11305, -- Sprint rank alias
    [26889] = 1856, -- Vanish rank alias
    [26669] = 5277, -- Evasion rank alias
    [1020] = 642, -- Divine Shield rank alias
    [1022] = 10278, -- Hand of Protection rank alias
    [5599] = 10278, -- Hand of Protection rank alias
    [853] = 10308, -- Hammer of Justice ranks
    [5588] = 10308,
    [5589] = 10308,
    [8122] = 10890, -- Psychic Scream ranks
    [30283] = 47847, -- Shadowfury ranks
    [30413] = 47847,
    [30414] = 47847,
    [6789] = 47860, -- Death Coil ranks
    [17925] = 47860,
    [17926] = 47860,
    [27223] = 47860,
    [33041] = 42950, -- Dragon's Breath ranks
    [33042] = 42950,
    [33043] = 42950,
    [11129] = 29977, -- Combustion rank alias
    [24132] = 49012, -- Wyvern Sting ranks
    [24133] = 49012,
    [27068] = 49012,
    [16689] = 53312, -- Nature's Grasp ranks
    [27009] = 53312,
    [27148] = 6940, -- Hand of Sacrifice rank alias
    [8042] = 25454, -- Earth Shock ranks
}

local MODIFIER_COOLDOWNS = {
    [8983] = { feral = 30 },
    [49067] = { survival = 22 },
    [60192] = { survival = 22 },
    [14311] = { survival = 22 },
    [13809] = { survival = 22 },
    [49055] = { survival = 22 },
    [34600] = { survival = 22 },
    [12051] = { arcane = 120 },
    [66] = { arcane = 126 },
    [31884] = { retri = 120 },
    [498] = { protPala = 120 },
    [642] = { protPala = 240 },
    [10308] = { protPala = 30 },
    [586] = { shadow = 15 },
    [10890] = { shadow = 23 },
    [34433] = { shadow = 180 },
    [5277] = { combat = 120 },
    [11305] = { combat = 120 },
    [57934] = { sub = 20 },
    [49271] = { ele = 3.5 },
    [18708] = { demo = 126 },
    [18499] = { fury = 20 },
    [11578] = { protWar = 15 },
    [676] = { protWar = 40 },
    [1719] = { protWar = 240, fury = 201 },
    [65932] = { protWar = 240 },
    [2565] = { protWar = 40 },
    [871] = { protWar = 240 },
}

-- Default trigger behavior: tracked cooldowns are success-driven by default.
-- Only add entries here when a specific spell should use a non-success trigger.
local TRIGGER_OVERRIDES = {
}

local function NormalizeSpellID(spellID)
    return ID_ALIASES[spellID] or spellID
end

local function NormalizeTrigger(trigger)
    if not trigger then return "SUCCESS" end
    trigger = string.upper(trigger)
    if trigger == "SUCCESS" or trigger == "AURA_APPLIED" or trigger == "START" or trigger == "ANY" then
        return trigger
    end
    return "SUCCESS"
end

local function ResolveRawConfig(ctx, spellID, sourceGUID, sourceName)
    local rawSpellID = spellID
    spellID = NormalizeSpellID(spellID)
    local db = ctx.db

    if db and db.disabledSpells and (db.disabledSpells[spellID] or db.disabledSpells[rawSpellID]) then
        return nil, "disabled"
    end

    local source = "none"
    local cfg
    local base = ctx.defaultSpellData and ctx.defaultSpellData[spellID]
    if base then
        source = "default"
        cfg = { cd = base.cd, trigger = "SUCCESS" }
    end
    if db and db.customSpells then
        local custom = db.customSpells[spellID] or db.customSpells[rawSpellID]
        if custom then
            cfg = custom
            source = "custom"
        end
    end

    local cd, trigger
    if type(cfg) == "number" then
        cd, trigger = cfg, "SUCCESS"
    elseif type(cfg) == "table" then
        cd, trigger = cfg.cd or cfg.duration, cfg.trigger or "SUCCESS"
    end

    local modifierSpec
    local modifiers = MODIFIER_COOLDOWNS[spellID]
    if modifiers and ctx.GetUnitSpec then
        modifierSpec = ctx.GetUnitSpec(sourceGUID, sourceName)
        if modifierSpec and modifiers[modifierSpec] then
            cd = modifiers[modifierSpec]
        end
    end

    local overrideApplied = false
    if db and db.spellOverrides then
        local ov = db.spellOverrides[spellID] or db.spellOverrides[rawSpellID]
        if ov then
            if type(ov) == "number" then
                cd = ov
                overrideApplied = true
            elseif type(ov) == "table" then
                cd = ov.cd or cd
                trigger = ov.trigger or trigger
                overrideApplied = true
            end
        end
    end

    local expectedTrigger = nil
    if TRIGGER_OVERRIDES[spellID] then
        expectedTrigger = NormalizeTrigger(TRIGGER_OVERRIDES[spellID])
    elseif ctx.defaultSpellData and ctx.defaultSpellData[spellID] then
        expectedTrigger = "SUCCESS"
    end
    if expectedTrigger and not overrideApplied then
        trigger = expectedTrigger
    end

    if not cd or cd <= 0 then
        return nil, "missing"
    end

    local shared = SHARED_COOLDOWNS[spellID]
    local resets = RESET_COOLDOWNS[spellID]

    return {
        spellID = spellID,
        originalSpellID = rawSpellID,
        cd = cd,
        trigger = NormalizeTrigger(trigger),
        source = source,
        overrideApplied = overrideApplied,
        isItem = ctx.IsItemSpell and (ctx.IsItemSpell(spellID) and true or false) or false,
        sharedTargets = shared,
        resetSpells = resets,
        sharedGroup = nil,
        resets = resets,
        modifiers = modifiers,
        appliedSpec = modifierSpec,
    }
end

function IcicleCooldownRules.GetSpellConfig(ctx, spellID, sourceGUID, sourceName)
    return ResolveRawConfig(ctx, spellID, sourceGUID, sourceName)
end

function IcicleCooldownRules.GetSharedTargetsForSpell(_, spellID)
    spellID = NormalizeSpellID(spellID)
    return SHARED_COOLDOWNS[spellID]
end
