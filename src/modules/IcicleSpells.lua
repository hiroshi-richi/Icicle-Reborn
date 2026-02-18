IcicleSpells = IcicleSpells or {}

local tinsert = table.insert

function IcicleSpells.BuildSpellRowsData(ctx)
    local rows, seen = {}, {}
    local db = ctx.db or {}

    if db.customSpells then
        for spellID, data in pairs(db.customSpells) do
            if not seen[spellID] then
                local customIsItem = ctx.IsItemSpell(spellID)
                local name, icon = ctx.GetSpellOrItemInfo(spellID, customIsItem)
                local ov = db.spellOverrides and db.spellOverrides[spellID]
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
                    enabled = not (db.disabledSpells and db.disabledSpells[spellID]),
                    description = ctx.GetSpellDescSafe(spellID, customIsItem),
                })
                seen[spellID] = true
            end
        end
    end

    if db.spellOverrides then
        for spellID, ov in pairs(db.spellOverrides) do
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
                    enabled = not (db.disabledSpells and db.disabledSpells[spellID]),
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
                local ov = db.spellOverrides and db.spellOverrides[spellID]
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
                    enabled = not (db.disabledSpells and db.disabledSpells[spellID]),
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
