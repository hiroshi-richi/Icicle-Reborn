IcicleTooltip = IcicleTooltip or {}

local floor = math.floor
local format = string.format
local tinsert = table.insert
local UnitFactionGroup = UnitFactionGroup

local spellTooltip = CreateFrame("GameTooltip", "IcicleSpellTooltipScanner", UIParent, "GameTooltipTemplate")
local spellTooltipCache = {}
local PVP_TRINKET_CANONICAL_ID = 42122
local PVP_TRINKET_HORDE_DISPLAY_ID = 42123

local function IsEmptyString(s)
    if not s then return true end
    return (s:gsub("^%s*(.-)%s*$", "%1")) == ""
end

local function FormatCooldownText(seconds)
    if not seconds then return "Unknown" end
    if SecondsToTime then
        return SecondsToTime(seconds)
    end
    if seconds >= 60 then
        return format("%dm %ds", floor(seconds / 60), seconds % 60)
    end
    return format("%.1fs", seconds)
end

local function ScanTooltipDescriptionRaw(spellID, isItem)
    local cacheKey = (isItem and "item:" or "spell:") .. tostring(spellID)
    if spellTooltipCache[cacheKey] then return spellTooltipCache[cacheKey] end

    local link = (isItem and "item:" or "spell:") .. tostring(spellID)
    spellTooltip:ClearLines()
    spellTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = pcall(spellTooltip.SetHyperlink, spellTooltip, link)
    if not ok then
        spellTooltip:Hide()
        spellTooltipCache[cacheKey] = "No description available."
        return spellTooltipCache[cacheKey]
    end

    local lines = spellTooltip:NumLines()
    if lines < 1 then
        spellTooltip:Hide()
        spellTooltipCache[cacheKey] = "No description available."
        return spellTooltipCache[cacheKey]
    end

    local desc = nil
    local last = _G["IcicleSpellTooltipScannerTextLeft" .. lines]
    if last then
        desc = last:GetText()
    end
    if IsEmptyString(desc) and lines > 1 then
        local prev = _G["IcicleSpellTooltipScannerTextLeft" .. (lines - 1)]
        if prev then
            desc = prev:GetText()
        end
    end

    if IsEmptyString(desc) then
        local collect = {}
        for i = 2, lines do
            local left = _G["IcicleSpellTooltipScannerTextLeft" .. i]
            if left then
                local txt = left:GetText()
                if not IsEmptyString(txt) then
                    tinsert(collect, txt)
                end
            end
        end
        desc = table.concat(collect, "\n")
    end

    if IsEmptyString(desc) then
        desc = "No description available."
    end
    spellTooltip:Hide()
    spellTooltipCache[cacheKey] = desc
    return desc
end

function IcicleTooltip.ResolveDisplaySpellOrItemID(spellID, isItem)
    if not spellID then
        return spellID
    end
    if isItem and spellID == PVP_TRINKET_CANONICAL_ID then
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        if faction == "Horde" then
            return PVP_TRINKET_HORDE_DISPLAY_ID
        end
    end
    return spellID
end

function IcicleTooltip.GetSpellOrItemInfo(spellID, isItem)
    spellID = IcicleTooltip.ResolveDisplaySpellOrItemID(spellID, isItem)

    if isItem then
        local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(spellID)
        return itemName, itemTexture or GetItemIcon(spellID)
    end
    local spellName, _, spellTexture = GetSpellInfo(spellID)
    return spellName, spellTexture
end

function IcicleTooltip.GetSpellDescSafe(spellID, isItem)
    if not spellID then return "No description available." end
    spellID = IcicleTooltip.ResolveDisplaySpellOrItemID(spellID, isItem)
    return ScanTooltipDescriptionRaw(spellID, isItem)
end

function IcicleTooltip.PreloadEnabledItemDisplayInfo(db, defaultItemIDs, isItemSpellFn)
    if type(db) ~= "table" then
        return
    end

    local queued = {}
    local function QueueItem(spellID)
        local displayID = IcicleTooltip.ResolveDisplaySpellOrItemID(spellID, true)
        if not displayID or queued[displayID] then
            return
        end
        queued[displayID] = true
        GetItemInfo(displayID)
        GetItemIcon(displayID)
        ScanTooltipDescriptionRaw(displayID, true)
    end

    if type(defaultItemIDs) == "table" then
        for spellID in pairs(defaultItemIDs) do
            if not (db.removedBaseSpells and db.removedBaseSpells[spellID]) and not (db.disabledSpells and db.disabledSpells[spellID]) then
                QueueItem(spellID)
            end
        end
    end

    if type(db.customSpells) == "table" then
        for spellID, entry in pairs(db.customSpells) do
            if not (db.disabledSpells and db.disabledSpells[spellID]) then
                local isItem = false
                if type(isItemSpellFn) == "function" then
                    isItem = isItemSpellFn(spellID) and true or false
                elseif type(entry) == "table" and entry.isItem then
                    isItem = true
                end
                if isItem then
                    QueueItem(spellID)
                end
            end
        end
    end
end

function IcicleTooltip.BuildSpellTooltipText(spellID, spellName, iconTex, cooldownSeconds, isItem)
    spellName = spellName or ("Spell " .. tostring(spellID))
    iconTex = iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
    local desc = IcicleTooltip.GetSpellDescSafe(spellID, isItem)
    local header = "|T" .. iconTex .. ":16:16:0:0|t " .. spellName
    local body = format(
        "\n|cffffd700Cooldown:|r %s\n\n%s\n\n|cffffd700Spell ID:|r %d",
        FormatCooldownText(cooldownSeconds or 0),
        desc,
        spellID
    )
    return header, body
end

function IcicleTooltip.BuildSpellPanelDesc(row)
    local d = row.description or IcicleTooltip.GetSpellDescSafe(row.id, row.isItem) or "No description available."
    return "|cffffffff" .. d .. "|r"
end
