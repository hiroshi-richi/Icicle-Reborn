IcicleRender = IcicleRender or {}

local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local min, sin = math.min, math.sin
local GetTime = GetTime

local function GetPlateBuffBlinkFactor(rec, now)
    if not rec or not rec.expiresAt then
        return 1
    end
    now = now or GetTime()
    local remain = rec.expiresAt - now
    if remain < 0 then
        remain = 0
    end
    local bth = remain % 1
    if bth > 0.5 then
        bth = 1 - bth
    end
    bth = bth * 3
    if bth < 0 then bth = 0 end
    if bth > 1 then bth = 1 end
    return bth
end

local function ApplyInterruptIconPulse(ctx, icon, rec, now)
    if not icon or not icon.texture then
        return
    end
    local mode = (ctx.db and ctx.db.interruptHighlightMode) or "BORDER"
    local baseAlpha = (rec and rec.__ambiguous) and 0.45 or 1
    local isInterruptPulseTarget = rec and rec.isInterrupt and ctx.db and ctx.db.highlightInterrupts and mode == "ICON"
    local pulseFactor = isInterruptPulseTarget and GetPlateBuffBlinkFactor(rec, now) or 1

    local alpha = baseAlpha
    if isInterruptPulseTarget then
        alpha = baseAlpha * pulseFactor
    end
    if alpha < 0 then alpha = 0 end
    if alpha > 1 then alpha = 1 end

    if icon._lastIconAlpha ~= alpha then
        icon:SetAlpha(alpha)
        icon._lastIconAlpha = alpha
    end

    if icon._lastIconTexR ~= 1 or icon._lastIconTexG ~= 1 or icon._lastIconTexB ~= 1 then
        icon.texture:SetVertexColor(1, 1, 1, 1)
        icon._lastIconTexR, icon._lastIconTexG, icon._lastIconTexB = 1, 1, 1
    end
end

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

    local c = nil
    local mode = (ctx.db and ctx.db.interruptHighlightMode) or "BORDER"
    local interruptBorderPulse = (mode == "BORDER") and ctx.db.highlightInterrupts and rec.isInterrupt
    local bordersEnabled = ctx.db.showBorders ~= false
    if ctx.SpellCategory and rec.spellID then
        local category = ctx.SpellCategory(rec.spellID)
        if category then
            local colorsMap = ctx.db.categoryBorderColors or {}
            local defaultColors = ctx.CATEGORY_BORDER_DEFAULTS or {}
            local categoryColor = colorsMap[category] or defaultColors[category] or defaultColors.GENERAL
            if interruptBorderPulse then
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
    if c then
        local baseA = c.a or 1
        local a = baseA
        now = now or GetTime()
        local pulseActive = false
        if interruptBorderPulse then
            local wave = 0.5 + 0.5 * sin(now * 7.0)
            a = baseA * wave
            pulseActive = true
        end
        local r, g, b = c.r or 1, c.g or 1, c.b or 1
        local colorChanged = (icon._lastBorderR ~= r) or (icon._lastBorderG ~= g) or (icon._lastBorderB ~= b) or (icon._lastBorderA ~= a)
        if pulseActive or colorChanged or not icon._borderVisible then
            if hasSingleBorder and icon.border then
                if colorChanged or pulseActive then
                    icon.border:SetVertexColor(r, g, b, a)
                end
                icon.border:Show()
            end
            if hasFrameBorder and icon.borderFrame then
                if icon.borderSkin and (colorChanged or pulseActive) then
                    icon.borderSkin:SetVertexColor(r, g, b, a)
                end
                icon.borderFrame:Show()
            end
            if hasEdgeBorder then
                if colorChanged or pulseActive then
                    icon.borderEdges.top:SetVertexColor(r, g, b, a)
                    icon.borderEdges.bottom:SetVertexColor(r, g, b, a)
                    icon.borderEdges.left:SetVertexColor(r, g, b, a)
                    icon.borderEdges.right:SetVertexColor(r, g, b, a)
                end
                icon.borderEdges.top:Show()
                icon.borderEdges.bottom:Show()
                icon.borderEdges.left:Show()
                icon.borderEdges.right:Show()
            end
            icon._lastBorderR, icon._lastBorderG, icon._lastBorderB, icon._lastBorderA = r, g, b, a
            icon._borderVisible = true
        end
    else
        if icon._borderVisible then
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
            icon._borderVisible = false
        end
    end
end

function IcicleRender.CollectDisplayRecords(ctx, meta)
    local out = meta._renderRecords or {}
    WipeArray(out)
    meta._renderRecords = out
    local now = GetTime()
    local outIndex = 0

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
                local list, count = ctx.GetRecordList(byGUID, now)
                for i = 1, count do
                    local rec = list[i]
                    rec.__ambiguous = false
                    outIndex = outIndex + 1
                    out[outIndex] = rec
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
                local list, count = ctx.GetRecordList(byName, now)
                for i = 1, count do
                    local rec = list[i]
                    rec.__ambiguous = (visibleCount > 1)
                    outIndex = outIndex + 1
                    out[outIndex] = rec
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

        local texturePath = rec.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
        if icon._lastTexture ~= texturePath then
            icon.texture:SetTexture(texturePath)
            icon._lastTexture = texturePath
        end
        if icon._lastR ~= r or icon._lastG ~= g or icon._lastB ~= b then
            icon.cooldown:SetTextColor(r, g, b)
            icon._lastR, icon._lastG, icon._lastB = r, g, b
        end
        local cooldownText = ctx.FormatRemaining(remain)
        if icon._lastCooldownText ~= cooldownText then
            icon.cooldown:SetText(cooldownText)
            icon._lastCooldownText = cooldownText
        end
        icon.record = rec
        icon.isOverflow = nil
        ApplyInterruptIconPulse(ctx, icon, rec, now)
        if rec.__ambiguous then icon.ambiguousMark:Show() else icon.ambiguousMark:Hide() end
        ApplyPriorityBorder(ctx, icon, rec, now)
        icon:Show()
    end

    if #records > cap and cap > 0 then
        local last = meta.activeIcons[#meta.activeIcons]
        if last then
            local overflowTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
            if last._lastTexture ~= overflowTexture then
                last.texture:SetTexture(overflowTexture)
                last._lastTexture = overflowTexture
            end
            local overflowText = "+" .. tostring(#records - cap + 1)
            if last._lastCooldownText ~= overflowText then
                last.cooldown:SetText(overflowText)
                last._lastCooldownText = overflowText
            end
            last.record = { spellID = 0, spellName = "Overflow", expiresAt = now + 9999 }
            last.isOverflow = true
            last:SetAlpha(1)
            last._lastIconAlpha = 1
            last.texture:SetVertexColor(1, 1, 1, 1)
            last._lastIconTexR, last._lastIconTexG, last._lastIconTexB = 1, 1, 1
            last._interruptPulseSecond = nil
            last._interruptPulseUntil = nil
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
            icon._lastTexture = nil
            icon._lastCooldownText = nil
            icon._lastR, icon._lastG, icon._lastB = nil, nil, nil
            icon.texture:SetVertexColor(1, 1, 1, 1)
            icon._lastIconTexR, icon._lastIconTexG, icon._lastIconTexB = 1, 1, 1
            icon._lastIconAlpha = nil
            icon._lastBorderR, icon._lastBorderG, icon._lastBorderB, icon._lastBorderA = nil, nil, nil, nil
            icon._interruptPulseSecond = nil
            icon._interruptPulseUntil = nil
            icon._interruptPulseWindow = nil
            icon._borderVisible = false
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
    local list = ctx.STATE.visiblePlateList
    local count = ctx.STATE.visiblePlateCount or (list and #list) or 0
    if not list or count <= 0 then
        return
    end
    for i = 1, count do
        local plate = list[i]
        local meta = plate and plate.IsShown and plate:IsShown() and plate:GetAlpha() > 0 and ctx.STATE.plateMeta[plate]
        if meta then
            IcicleRender.RenderPlate(ctx, meta)
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
        local shouldScan = false
        if (ctx.STATE.dirtyPlateCount or 0) > 0 then
            shouldScan = true
        elseif ctx.STATE.pendingBindByGUID and next(ctx.STATE.pendingBindByGUID) then
            shouldScan = true
        elseif ctx.GetWorldChildrenCount then
            local worldCount = ctx.GetWorldChildrenCount()
            if worldCount ~= (ctx.STATE.lastWorldChildrenCount or 0) then
                shouldScan = true
            end
        else
            shouldScan = true
        end
        if shouldScan then
            ctx.ScanNameplates()
        end
    end

    if ctx.STATE.groupAccum >= ctx.db.groupScanInterval then
        ctx.STATE.groupAccum = 0
        if ctx.ResolveGroupTargets then
            ctx.ResolveGroupTargets()
        end
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

        if ctx.ProcessExpiryQueue then
            changed = ctx.ProcessExpiryQueue(now) or changed
        else
            changed = ctx.PruneExpiredStore(ctx.STATE.cooldownsByGUID, now) or changed
            changed = ctx.PruneExpiredStore(ctx.STATE.cooldownsByName, now) or changed
        end

        if changed then
            if ctx.RefreshDirtyPlates then
                ctx.RefreshDirtyPlates()
            else
                IcicleRender.RefreshAllVisiblePlates(ctx)
            end
        elseif ctx.STATE.testModeActive then
            -- Test records are filtered during render; force re-render so expired test icons disappear on time.
            IcicleRender.RefreshAllVisiblePlates(ctx)
        else
            local list = ctx.STATE.visiblePlateList
            local count = ctx.STATE.visiblePlateCount or (list and #list) or 0
            if list and count > 0 then
                for p = 1, count do
                    local plate = list[p]
                    local meta = plate and plate.IsShown and plate:IsShown() and plate:GetAlpha() > 0 and ctx.STATE.plateMeta[plate]
                    if meta then
                        for i = 1, #meta.activeIcons do
                            local icon = meta.activeIcons[i]
                            local rec = icon.record
                            if rec and not icon.isOverflow then
                                if now < (icon._nextTextUpdateAt or 0) then
                                    ApplyInterruptIconPulse(ctx, icon, rec, now)
                                    ApplyPriorityBorder(ctx, icon, rec, now)
                                else
                                local remain = rec.expiresAt - now
                                local cooldownText = ctx.FormatRemaining(remain)
                                if icon._lastCooldownText ~= cooldownText then
                                    icon.cooldown:SetText(cooldownText)
                                    icon._lastCooldownText = cooldownText
                                end
                                local r, g, b = ctx.GetIconTextColor(remain)
                                if icon._lastR ~= r or icon._lastG ~= g or icon._lastB ~= b then
                                    icon.cooldown:SetTextColor(r, g, b)
                                    icon._lastR, icon._lastG, icon._lastB = r, g, b
                                end
                                if remain > 10 then
                                    icon._nextTextUpdateAt = now + 0.35
                                else
                                    icon._nextTextUpdateAt = now + 0.10
                                end
                                ApplyInterruptIconPulse(ctx, icon, rec, now)
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

