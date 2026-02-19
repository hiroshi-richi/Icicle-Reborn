IcicleRender = IcicleRender or {}

local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local min, sin = math.min, math.sin
local GetTime = GetTime

local function SortByExpire(a, b)
    return a.expiresAt < b.expiresAt
end

local function WipeArray(arr)
    for i = #arr, 1, -1 do
        arr[i] = nil
    end
end

local function BuildDisplaySlice(records, cap, preferInterrupt, out, interrupt, regular)
    out = out or {}
    if cap <= 0 then
        WipeArray(out)
        return out
    end

    if (not preferInterrupt) or #records <= cap then
        local count = min(#records, cap)
        for i = 1, count do
            out[i] = records[i]
        end
        for i = #out, count + 1, -1 do
            out[i] = nil
        end
        return out
    end

    interrupt = interrupt or {}
    regular = regular or {}
    WipeArray(interrupt)
    WipeArray(regular)

    for i = 1, #records do
        local rec = records[i]
        if rec.isInterrupt then
            interrupt[#interrupt + 1] = rec
        else
            regular[#regular + 1] = rec
        end
    end

    local outCount = 0
    for i = 1, #interrupt do
        if outCount >= cap then break end
        outCount = outCount + 1
        out[outCount] = interrupt[i]
    end
    for i = 1, #regular do
        if outCount >= cap then break end
        outCount = outCount + 1
        out[outCount] = regular[i]
    end
    for i = #out, outCount + 1, -1 do
        out[i] = nil
    end

    if outCount > 1 then
        tsort(out, SortByExpire)
    end
    return out
end

local CATEGORY_BORDER_DEFAULT_COLORS = {
    GENERAL = { r = 0.62, g = 0.62, b = 0.62, a = 1.00 },
    WARRIOR = { r = 0.780, g = 0.612, b = 0.431, a = 1.00 },
    PALADIN = { r = 0.961, g = 0.549, b = 0.729, a = 1.00 },
    HUNTER = { r = 0.671, g = 0.831, b = 0.451, a = 1.00 },
    ROGUE = { r = 1.000, g = 0.961, b = 0.412, a = 1.00 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    DEATH_KNIGHT = { r = 0.769, g = 0.122, b = 0.231, a = 1.00 },
    SHAMAN = { r = 0.000, g = 0.439, b = 0.871, a = 1.00 },
    MAGE = { r = 0.247, g = 0.780, b = 0.922, a = 1.00 },
    WARLOCK = { r = 0.529, g = 0.533, b = 0.933, a = 1.00 },
    DRUID = { r = 1.000, g = 0.490, b = 0.039, a = 1.00 },
}

local function ApplyPriorityBorder(ctx, icon, rec, now)
    if not icon then
        return
    end
    local hasSingleBorder = icon.border ~= nil
    local hasEdgeBorder = icon.borderEdges ~= nil
    local hasFrameBorder = icon.borderFrame ~= nil
    if not hasSingleBorder and not hasEdgeBorder and not hasFrameBorder then
        return
    end

    local function HideBorder()
        if hasSingleBorder and icon.border then
            icon.border:Hide()
        end
        if hasFrameBorder and icon.borderFrame then
            icon.borderFrame:Hide()
        end
        if hasEdgeBorder then
            icon.borderEdges.top:Hide()
            icon.borderEdges.bottom:Hide()
            icon.borderEdges.left:Hide()
            icon.borderEdges.right:Hide()
        end
    end

    local c = nil
    local pulseEnabled = false
    local bordersEnabled = ctx.db.showBorders ~= false
    if ctx.SpellCategory and rec.spellID then
        local category = ctx.SpellCategory(rec.spellID)
        if category then
            local colorsMap = ctx.db.categoryBorderColors or {}
            local categoryColor = colorsMap[category] or CATEGORY_BORDER_DEFAULT_COLORS[category]
            if ctx.db.highlightInterrupts and rec.isInterrupt then
                c = categoryColor
            elseif bordersEnabled then
                local enabledMap = ctx.db.categoryBorderEnabled or {}
                local enabled = enabledMap[category]
                if enabled == nil then enabled = true end
                if enabled then
                    c = categoryColor
                end
            end
        end
    end
    if c and ctx.db.highlightInterrupts and rec.isInterrupt then
        pulseEnabled = true
    end

    if c then
        local pulse = pulseEnabled and 1 or 0
        local baseA = c.a or 1
        local a = baseA
        if pulse > 0 then
            local wave = 0.5 + 0.5 * sin((now or GetTime()) * 7.0)
            local floorA = 1 - pulse
            a = baseA * (floorA + (pulse * wave))
        end
        if hasSingleBorder and icon.border then
            icon.border:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, a)
            icon.border:Show()
        end
        if hasFrameBorder and icon.borderFrame then
            if icon.borderSkin then
                icon.borderSkin:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, a)
            end
            icon.borderFrame:Show()
        end
        if hasEdgeBorder then
            local r, g, b = c.r or 1, c.g or 1, c.b or 1
            icon.borderEdges.top:SetVertexColor(r, g, b, a)
            icon.borderEdges.bottom:SetVertexColor(r, g, b, a)
            icon.borderEdges.left:SetVertexColor(r, g, b, a)
            icon.borderEdges.right:SetVertexColor(r, g, b, a)
            icon.borderEdges.top:Show()
            icon.borderEdges.bottom:Show()
            icon.borderEdges.left:Show()
            icon.borderEdges.right:Show()
        end
    else
        HideBorder()
    end
end

function IcicleRender.CollectDisplayRecords(ctx, meta)
    local out = meta._renderRecords or {}
    WipeArray(out)
    meta._renderRecords = out
    local now = GetTime()

    if ctx.STATE.testModeActive and ctx.STATE.testByPlate[meta.plate] then
        local testRecords = ctx.STATE.testByPlate[meta.plate]
        local outIndex = 0
        for i = 1, #testRecords do
            local rec = testRecords[i]
            if rec and rec.expiresAt and rec.expiresAt > now then
                outIndex = outIndex + 1
                out[outIndex] = rec
            end
        end
        return out
    end

    local plateReaction = ctx.STATE.reactionByPlate and ctx.STATE.reactionByPlate[meta.plate]
    if plateReaction and plateReaction ~= "hostile" then
        return out
    end

    local guidEntry = ctx.STATE.guidByPlate[meta.plate]

    if guidEntry then
        local conf = ctx.DecayedConfidence(guidEntry, now)
        if conf >= ctx.db.minConfidence then
            local byGUID = ctx.STATE.cooldownsByGUID[guidEntry.guid]
            if byGUID then
                for _, rec in pairs(byGUID) do
                    if rec.expiresAt > now then
                        rec.__ambiguous = false
                        tinsert(out, rec)
                    end
                end
                guidEntry.lastSeen = now
                return out
            end
        end
    end

    if meta.name then
        local byName = ctx.STATE.cooldownsByName[meta.name]
        if byName then
            local visible = ctx.STATE.visiblePlatesByName[meta.name]
            local visibleCount = visible and visible.count or 0
            if visibleCount == 1 or ctx.db.showAmbiguousByName then
                for _, rec in pairs(byName) do
                    if rec.expiresAt > now then
                        rec.__ambiguous = (visibleCount > 1)
                        tinsert(out, rec)
                    end
                end
            end
        end
    end

    return out
end

function IcicleRender.RenderPlate(ctx, meta)
    ctx.ApplyContainerAnchor(meta)

    local now = GetTime()
    local records = IcicleRender.CollectDisplayRecords(ctx, meta)
    if #records > 1 then
        tsort(records, SortByExpire)
    end

    local cap = min(#records, ctx.db.maxIcons)
    local displayRecords = BuildDisplaySlice(records, cap, ctx.db.showInterruptWhenCapped, meta._displayRecords, meta._interruptRecords, meta._regularRecords)
    meta._displayRecords = displayRecords
    meta.activeIcons = meta.activeIcons or {}
    for i = 1, #displayRecords do
        local rec = displayRecords[i]
        local icon = meta.activeIcons[i]
        if not icon then
            icon = ctx.AcquireIcon(meta)
            meta.activeIcons[i] = icon
        end
        local remain = rec.expiresAt - now
        local r, g, b = ctx.GetIconTextColor(remain)

        icon.texture:SetTexture(rec.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon.cooldown:SetTextColor(r, g, b)
        icon.cooldown:SetText(ctx.FormatRemaining(remain))
        icon.record = rec
        icon.isOverflow = nil
        icon:SetAlpha(rec.__ambiguous and 0.45 or 1)
        if rec.__ambiguous then icon.ambiguousMark:Show() else icon.ambiguousMark:Hide() end
        ApplyPriorityBorder(ctx, icon, rec, now)
        icon:Show()
    end

    if #records > cap and cap > 0 then
        local last = meta.activeIcons[#meta.activeIcons]
        if last then
            last.texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            last.cooldown:SetText("+" .. tostring(#records - cap + 1))
            last.record = { spellID = 0, spellName = "Overflow", expiresAt = now + 9999 }
            last.isOverflow = true
            last:SetAlpha(1)
            last.ambiguousMark:Hide()
            if last.border then last.border:Hide() end
            if last.borderFrame then last.borderFrame:Hide() end
            if last.borderEdges then
                last.borderEdges.top:Hide()
                last.borderEdges.bottom:Hide()
                last.borderEdges.left:Hide()
                last.borderEdges.right:Hide()
            end
        end
    end

    for i = #meta.activeIcons, cap + 1, -1 do
        local icon = meta.activeIcons[i]
        if icon then
            icon:Hide()
            icon.record = nil
            icon.isOverflow = nil
            icon.ambiguousMark:Hide()
            if icon.border then icon.border:Hide() end
            if icon.borderFrame then icon.borderFrame:Hide() end
            if icon.borderEdges then
                icon.borderEdges.top:Hide()
                icon.borderEdges.bottom:Hide()
                icon.borderEdges.left:Hide()
                icon.borderEdges.right:Hide()
            end
            tremove(meta.activeIcons, i)
            tinsert(meta.iconPool, icon)
        end
    end

    ctx.LayoutIcons(meta)
end

function IcicleRender.RefreshAllVisiblePlates(ctx)
    for _, plates in pairs(ctx.STATE.visiblePlatesByName) do
        for plate in pairs(plates.map) do
            local meta = ctx.STATE.plateMeta[plate]
            if meta then IcicleRender.RenderPlate(ctx, meta) end
        end
    end
end

function IcicleRender.OnUpdate(ctx, elapsed)
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

    if ctx.STATE.testModeActive and ctx.STATE.testAccum >= (tonumber(ctx.db.testRefreshInterval) or 10.0) then
        ctx.STATE.testAccum = 0
        if ctx.PopulateRandomPlateTests then
            ctx.PopulateRandomPlateTests()
            IcicleRender.RefreshAllVisiblePlates(ctx)
        end
    end

    if ctx.STATE.iconAccum >= ctx.db.iconUpdateInterval then
        ctx.STATE.iconAccum = 0
        local now = GetTime()
        local changed = false

        changed = ctx.PruneExpiredStore(ctx.STATE.cooldownsByGUID, now) or changed
        changed = ctx.PruneExpiredStore(ctx.STATE.cooldownsByName, now) or changed

        if changed then
            IcicleRender.RefreshAllVisiblePlates(ctx)
        elseif ctx.STATE.testModeActive then
            -- Test records are filtered during render; force re-render so expired test icons disappear on time.
            IcicleRender.RefreshAllVisiblePlates(ctx)
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
                                if rec.isInterrupt and ctx.db.highlightInterrupts then
                                    ApplyPriorityBorder(ctx, icon, rec, now)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

