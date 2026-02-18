IcicleData = IcicleData or {}

IcicleData.CATEGORY_DEFS = {
    { key = "GENERAL", label = "General" },
    { key = "WARRIOR", label = "Warrior" },
    { key = "PALADIN", label = "Paladin" },
    { key = "HUNTER", label = "Hunter" },
    { key = "ROGUE", label = "Rogue" },
    { key = "PRIEST", label = "Priest" },
    { key = "DEATH_KNIGHT", label = "Death Knight" },
    { key = "SHAMAN", label = "Shaman" },
    { key = "MAGE", label = "Mage" },
    { key = "WARLOCK", label = "Warlock" },
    { key = "DRUID", label = "Druid" },
}

IcicleData.SPELL_CATEGORY_ORDER = {}
IcicleData.SPELL_CATEGORY_LABELS = {}
for i = 1, #IcicleData.CATEGORY_DEFS do
    local def = IcicleData.CATEGORY_DEFS[i]
    if def and def.key then
        IcicleData.SPELL_CATEGORY_ORDER[#IcicleData.SPELL_CATEGORY_ORDER + 1] = def.key
        IcicleData.SPELL_CATEGORY_LABELS[def.key] = def.label or def.key
    end
end

-- Format: [spellID] = { cd = seconds, enabledDefault = bool, types = { class/shared/item/racial/spell = true } }
IcicleData.DEFAULT_SPELLS_BY_CATEGORY = {
    GENERAL = {
        [7744] = { cd = 120, enabledDefault = false, types = { shared = true, racial = true } }, -- Will of the Forsaken
        [20549] = { cd = 120, enabledDefault = true, types = { racial = true } }, -- War Stomp
        [20572] = { cd = 120, enabledDefault = false, types = { racial = true } }, -- Blood Fury
        [20589] = { cd = 60, enabledDefault = true, types = { racial = true } }, -- Escape Artist
        [20594] = { cd = 120, enabledDefault = false, types = { racial = true } }, -- Stoneform
        [26297] = { cd = 180, enabledDefault = false, types = { racial = true } }, -- Berserking
        [28730] = { cd = 120, enabledDefault = true, types = { racial = true } }, -- Arcane Torrent
        [28880] = { cd = 180, enabledDefault = false, types = { racial = true } }, -- Gift of the Naaru
        [47088] = { cd = 180, enabledDefault = false, types = { item = true } }, -- No Man's Land -> Borean Tundra, Warsong Hold
        [50356] = { cd = 120, enabledDefault = false, types = { item = true } }, -- Inject Plague
        [50364] = { cd = 60, enabledDefault = false, types = { item = true } }, -- Rock Shield
        [50726] = { cd = 120, enabledDefault = false, types = { item = true } }, -- Sparktouched Oracle State
        [51377] = { cd = 120, enabledDefault = true, types = { shared = true, item = true } }, -- Unknown
        [58984] = { cd = 120, enabledDefault = false, types = { racial = true } }, -- Shadowmeld
        [59752] = { cd = 120, enabledDefault = true, types = { shared = true, racial = true } }, -- Every Man for Himself
    },
    WARRIOR = {
        [72] = { cd = 12, enabledDefault = true, types = { class = true } }, -- Shield Bash
        [676] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Disarm
        [871] = { cd = 300, enabledDefault = true, types = { class = true } }, -- Shield Wall
        [1680] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Whirlwind
        [1719] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Recklessness
        [2565] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Shield Block
        [3411] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Intervene
        [5246] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Intimidating Shout
        [6552] = { cd = 10, enabledDefault = true, types = { class = true } }, -- Pummel
        [11578] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Charge
        [12292] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Death Wish
        [12328] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Sweeping Strikes
        [12809] = { cd = 30, enabledDefault = true, types = { class = true } }, -- Concussion Blow
        [12975] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Last Stand
        [18499] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Berserker Rage
        [20252] = { cd = 25, enabledDefault = true, types = { class = true } }, -- Intercept
        [23920] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Spell Reflection
        [30335] = { cd = 4, enabledDefault = false, types = { class = true } }, -- Bloodthirst
        [46924] = { cd = 90, enabledDefault = false, types = { class = true } }, -- Bladestorm
        [46968] = { cd = 17, enabledDefault = false, types = { class = true } }, -- Shockwave
        [47486] = { cd = 5, enabledDefault = false, types = { class = true } }, -- Mortal Strike
        [55694] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Enraged Regeneration
        [57755] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Heroic Throw
        [60970] = { cd = 45, enabledDefault = false, types = { class = true } }, -- Heroic Fury
        [64382] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Shattering Throw
        [65932] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Retaliation
    },
    PALADIN = {
        [498] = { cd = 180, enabledDefault = true, types = { class = true } }, -- Divine Protection
        [642] = { cd = 300, enabledDefault = true, types = { class = true } }, -- Divine Shield
        [1038] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Hand of Salvation
        [1044] = { cd = 25, enabledDefault = true, types = { class = true } }, -- Hand of Freedom
        [6940] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Hand of Sacrifice
        [10278] = { cd = 180, enabledDefault = true, types = { class = true } }, -- Hand of Protection
        [10308] = { cd = 40, enabledDefault = true, types = { class = true } }, -- Hammer of Justice
        [20066] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Repentance
        [20216] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Divine Favor
        [31789] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Righteous Defense
        [31821] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Aura Mastery
        [31842] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Divine Illumination
        [31884] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Avenging Wrath
        [35395] = { cd = 4, enabledDefault = false, types = { class = true } }, -- Crusader Strike
        [48788] = { cd = 1200, enabledDefault = false, types = { class = true } }, -- Lay on Hands
        [48817] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Holy Wrath
        [48819] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Consecration
        [48825] = { cd = 5, enabledDefault = false, types = { class = true } }, -- Holy Shock
        [48827] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Avenger's Shield
        [48952] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Holy Shield
        [53385] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Divine Storm
        [53595] = { cd = 6, enabledDefault = false, types = { class = true } }, -- Hammer of the Righteous
        [54428] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Divine Plea
        [62124] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Hand of Reckoning
        [64205] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Divine Sacrifice
    },
    HUNTER = {
        [3045] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Rapid Fire
        [5384] = { cd = 25, enabledDefault = false, types = { class = true } }, -- Feign Death
        [13809] = { cd = 28, enabledDefault = false, types = { class = true } }, -- Frost Trap
        [14311] = { cd = 28, enabledDefault = true, types = { class = true } }, -- Freezing Trap
        [19263] = { cd = 90, enabledDefault = true, types = { class = true } }, -- Deterrence
        [19503] = { cd = 30, enabledDefault = true, types = { class = true } }, -- Scatter Shot
        [19574] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Bestial Wrath
        [19577] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Intimidation
        [23989] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Readiness
        [34490] = { cd = 20, enabledDefault = true, types = { class = true } }, -- Silencing Shot
        [34600] = { cd = 28, enabledDefault = false, types = { class = true } }, -- Snake Trap
        [49012] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Wyvern Sting
        [49050] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Aimed Shot
        [49055] = { cd = 28, enabledDefault = false, types = { class = true } }, -- Immolation Trap
        [49067] = { cd = 28, enabledDefault = false, types = { class = true } }, -- Explosive Trap
        [53209] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Chimera Shot
        [53271] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Master's Call
        [53476] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Intervene
        [53480] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Roar of Sacrifice
        [60192] = { cd = 28, enabledDefault = true, types = { class = true } }, -- Freezing Arrow
        [63672] = { cd = 22, enabledDefault = false, types = { class = true } }, -- Black Arrow
    },
    ROGUE = {
        [1766] = { cd = 10, enabledDefault = true, types = { class = true } }, -- Kick
        [1776] = { cd = 10, enabledDefault = true, types = { class = true } }, -- Gouge
        [1856] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Vanish
        [2094] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Blind
        [5277] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Evasion
        [8643] = { cd = 20, enabledDefault = true, types = { class = true } }, -- Kidney Shot
        [11305] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Sprint
        [13750] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Adrenaline Rush
        [13877] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Blade Flurry
        [14177] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Cold Blood
        [14185] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Preparation
        [14278] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Ghostly Strike
        [31224] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Cloak of Shadows
        [36554] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Shadowstep
        [48659] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Feint
        [51690] = { cd = 75, enabledDefault = false, types = { class = true } }, -- Killing Spree
        [51713] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Shadow Dance
        [51722] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Dismantle
        [57934] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Tricks of the Trade
    },
    PRIEST = {
        [586] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Fade
        [6346] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Fear Ward
        [10060] = { cd = 96, enabledDefault = false, types = { class = true } }, -- Power Infusion
        [10890] = { cd = 27, enabledDefault = true, types = { class = true } }, -- Psychic Scream
        [14751] = { cd = 144, enabledDefault = false, types = { class = true } }, -- Inner Focus
        [15487] = { cd = 45, enabledDefault = true, types = { class = true } }, -- Silence
        [33206] = { cd = 144, enabledDefault = true, types = { class = true } }, -- Pain Suppression
        [34433] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Shadowfiend
        [47585] = { cd = 75, enabledDefault = true, types = { class = true } }, -- Dispersion
        [47788] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Guardian Spirit
        [48086] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Lightwell
        [48158] = { cd = 12, enabledDefault = false, types = { class = true } }, -- Shadow Word: Death
        [48173] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Desperate Prayer
        [53007] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Penance
        [64044] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Psychic Horror
        [64843] = { cd = 480, enabledDefault = false, types = { class = true } }, -- Divine Hymn
        [64901] = { cd = 360, enabledDefault = false, types = { class = true } }, -- Hymn of Hope
    },
    DEATH_KNIGHT = {
        [42650] = { cd = 360, enabledDefault = false, types = { class = true } }, -- Army of the Dead
        [45529] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Blood Tap
        [46584] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Raise Dead
        [47481] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Gnaw
        [47482] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Leap
        [47528] = { cd = 10, enabledDefault = true, types = { class = true } }, -- Mind Freeze
        [47568] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Empower Rune Weapon
        [48707] = { cd = 45, enabledDefault = true, types = { class = true } }, -- Anti-Magic Shell
        [48743] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Death Pact
        [48792] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Icebound Fortitude
        [48982] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Rune Tap
        [49005] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Mark of Blood
        [49016] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Hysteria
        [49028] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Dancing Rune Weapon
        [49039] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Lichborne
        [49203] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Hungering Cold
        [49206] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Summon Gargoyle
        [49222] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Bone Shield
        [49576] = { cd = 25, enabledDefault = false, types = { class = true } }, -- Death Grip
        [49796] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Deathchill
        [49916] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Strangulate
        [51052] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Anti-Magic Zone
        [51271] = { cd = 60, enabledDefault = true, types = { class = true } }, -- Unbreakable Armor
        [51411] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Howling Blast
        [55233] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Vampiric Blood
    },
    SHAMAN = {
        [2484] = { cd = 10.5, enabledDefault = false, types = { class = true } }, -- Earthbind Totem
        [2825] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Bloodlust
        [8177] = { cd = 13.5, enabledDefault = false, types = { class = true } }, -- Grounding Totem
        [16166] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Elemental Mastery
        [16188] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Nature's Swiftness
        [16190] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Mana Tide Totem
        [17364] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Stormstrike
        [20608] = { cd = 1800, enabledDefault = false, types = { class = true } }, -- Reincarnation
        [30823] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Shamanistic Rage
        [32182] = { cd = 300, enabledDefault = false, types = { class = true } }, -- Heroism
        [49271] = { cd = 6, enabledDefault = false, types = { class = true } }, -- Chain Lightning
        [51514] = { cd = 45, enabledDefault = true, types = { class = true } }, -- Hex
        [51533] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Feral Spirit
        [55198] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Tidal Force
        [57994] = { cd = 5, enabledDefault = true, types = { class = true } }, -- Wind Shear
        [58582] = { cd = 21, enabledDefault = false, types = { class = true } }, -- Stoneclaw Totem
        [59159] = { cd = 35, enabledDefault = false, types = { class = true } }, -- Thunderstorm
        [60043] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Lava Burst
        [60103] = { cd = 6, enabledDefault = false, types = { class = true } }, -- Lava Lash
        [61301] = { cd = 6, enabledDefault = false, types = { class = true } }, -- Riptide
        [61657] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Fire Nova
    },
    MAGE = {
        [66] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Invisibility
        [1953] = { cd = 15, enabledDefault = false, types = { class = true } }, -- Blink
        [2139] = { cd = 24, enabledDefault = true, types = { class = true } }, -- Counterspell
        [11958] = { cd = 384, enabledDefault = false, types = { class = true } }, -- Cold Snap
        [12042] = { cd = 84, enabledDefault = false, types = { class = true } }, -- Arcane Power
        [12043] = { cd = 84, enabledDefault = false, types = { class = true } }, -- Presence of Mind
        [12051] = { cd = 240, enabledDefault = false, types = { class = true } }, -- Evocation
        [12472] = { cd = 144, enabledDefault = false, types = { class = true } }, -- Icy Veins
        [29977] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Combustion
        [31687] = { cd = 144, enabledDefault = false, types = { class = true } }, -- Summon Water Elemental
        [33395] = { cd = 25, enabledDefault = false, types = { class = true } }, -- Freeze
        [42917] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Frost Nova
        [42945] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Blast Wave
        [42950] = { cd = 20, enabledDefault = true, types = { class = true } }, -- Dragon's Breath
        [42987] = { cd = 120, enabledDefault = false, types = { class = true } }, -- Replenish Mana
        [43010] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Fire Ward
        [43012] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Frost Ward
        [43039] = { cd = 24, enabledDefault = true, types = { class = true } }, -- Ice Barrier
        [44572] = { cd = 30, enabledDefault = true, types = { class = true } }, -- Deep Freeze
        [45438] = { cd = 240, enabledDefault = true, types = { class = true } }, -- Ice Block
        [55342] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Mirror Image
    },
    WARLOCK = {
        [17928] = { cd = 32, enabledDefault = true, types = { class = true } }, -- Howl of Terror
        [17962] = { cd = 10, enabledDefault = false, types = { class = true } }, -- Conflagrate
        [18708] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Fel Domination
        [19647] = { cd = 24, enabledDefault = true, types = { class = true } }, -- Spell Lock
        [47193] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Demonic Empowerment
        [47241] = { cd = 126, enabledDefault = false, types = { class = true } }, -- Metamorphosis
        [47827] = { cd = 15, enabledDefault = false, types = { class = true } }, -- Shadowburn
        [47847] = { cd = 20, enabledDefault = true, types = { class = true } }, -- Shadowfury
        [47860] = { cd = 120, enabledDefault = true, types = { class = true } }, -- Death Coil
        [47891] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Shadow Ward
        [48011] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Devour Magic
        [48020] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Demonic Circle: Teleport
        [59164] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Haunt
        [59172] = { cd = 12, enabledDefault = false, types = { class = true } }, -- Chaos Bolt
        [61290] = { cd = 15, enabledDefault = false, types = { class = true } }, -- Shadowflame
    },
    DRUID = {
        [5209] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Challenging Roar
        [5229] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Enrage
        [6795] = { cd = 8, enabledDefault = false, types = { class = true } }, -- Growl
        [8983] = { cd = 30, enabledDefault = true, types = { class = true } }, -- Bash
        [16979] = { cd = 15, enabledDefault = false, types = { class = true } }, -- Feral Charge - Bear
        [17116] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Nature's Swiftness
        [18562] = { cd = 13, enabledDefault = false, types = { class = true } }, -- Swiftmend
        [22812] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Barkskin
        [22842] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Frenzied Regeneration
        [29166] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Innervate
        [33357] = { cd = 144, enabledDefault = false, types = { class = true } }, -- Dash
        [33831] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Force of Nature
        [48447] = { cd = 480, enabledDefault = false, types = { class = true } }, -- Tranquility
        [48477] = { cd = 600, enabledDefault = false, types = { class = true } }, -- Rebirth
        [49376] = { cd = 15, enabledDefault = false, types = { class = true } }, -- Feral Charge - Cat
        [49802] = { cd = 10, enabledDefault = true, types = { class = true } }, -- Maim
        [50213] = { cd = 30, enabledDefault = false, types = { class = true } }, -- Tiger's Fury
        [50334] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Berserk
        [53201] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Starfall
        [53312] = { cd = 60, enabledDefault = false, types = { class = true } }, -- Nature's Grasp
        [61336] = { cd = 180, enabledDefault = false, types = { class = true } }, -- Survival Instincts
        [61384] = { cd = 20, enabledDefault = false, types = { class = true } }, -- Typhoon
    },
}
IcicleData.DEFAULT_SPELL_DATA = {}
IcicleData.BASE_COOLDOWNS = {}
IcicleData.DEFAULT_ITEM_IDS = {}
IcicleData.DEFAULT_ENABLED_SPELL_IDS = {}
IcicleData.DEFAULT_SPELL_TYPES = {}

for categoryKey, spellMap in pairs(IcicleData.DEFAULT_SPELLS_BY_CATEGORY) do
    for spellID, entry in pairs(spellMap) do
        local cd = nil
        local enabledDefault = false
        local types = nil

        if type(entry) == "number" then
            cd = tonumber(entry)
            if categoryKey ~= "GENERAL" then
                types = { class = true }
            else
                types = { spell = true }
            end
        elseif type(entry) == "table" then
            cd = tonumber(entry.cd or entry.duration)
            enabledDefault = entry.enabledDefault and true or false
            if type(entry.types) == "table" then
                types = {}
                for key, value in pairs(entry.types) do
                    if value then
                        types[key] = true
                    end
                end
            end
            if not types then
                if categoryKey ~= "GENERAL" then
                    types = { class = true }
                else
                    types = { spell = true }
                end
            end
        end

        if cd then
            IcicleData.DEFAULT_SPELL_DATA[spellID] = { cd = cd, category = categoryKey, types = types, enabledDefault = enabledDefault }
            IcicleData.BASE_COOLDOWNS[spellID] = cd
            IcicleData.DEFAULT_SPELL_TYPES[spellID] = types
            if enabledDefault then
                IcicleData.DEFAULT_ENABLED_SPELL_IDS[spellID] = true
            end
            if types and types.item then
                IcicleData.DEFAULT_ITEM_IDS[spellID] = true
            end
        end
    end
end

-- Readable helper for development/debug: builds name hints from client spell data when available.
IcicleData.DEFAULT_SPELLS_READABLE = {}
for spellID, data in pairs(IcicleData.DEFAULT_SPELL_DATA) do
    local spellName = GetSpellInfo(spellID)
    IcicleData.DEFAULT_SPELLS_READABLE[#IcicleData.DEFAULT_SPELLS_READABLE + 1] = {
        id = spellID,
        name = spellName or ("Spell " .. tostring(spellID)),
        category = data.category,
        cd = data.cd,
        enabledDefault = data.enabledDefault and true or false,
        types = data.types,
    }
end
table.sort(IcicleData.DEFAULT_SPELLS_READABLE, function(a, b)
    if a.category == b.category then
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end
    return a.category < b.category
end)

