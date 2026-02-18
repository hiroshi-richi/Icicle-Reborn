IcicleTooltip = IcicleTooltip or {}

local floor = math.floor
local format = string.format
local tinsert = table.insert

local spellTooltip = CreateFrame("GameTooltip", "IcicleSpellTooltipScanner", UIParent, "GameTooltipTemplate")
local spellTooltipCache = {}

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

function IcicleTooltip.GetSpellOrItemInfo(spellID, isItem)
    if isItem then
        local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(spellID)
        return itemName, itemTexture or GetItemIcon(spellID)
    end
    local spellName, _, spellTexture = GetSpellInfo(spellID)
    return spellName, spellTexture
end

function IcicleTooltip.GetSpellDescSafe(spellID, isItem)
    if not spellID then return "No description available." end
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
