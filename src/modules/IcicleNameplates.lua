IcicleNameplates = IcicleNameplates or {}

local function ReactionFromBarColor(r, g, b)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    if r >= 0.75 and g <= 0.35 and b <= 0.35 then
        return "hostile"
    end
    if r >= 0.85 and g >= 0.75 and b <= 0.35 then
        return "neutral"
    end
    if g >= 0.65 and r <= 0.45 and b <= 0.45 then
        return "friendly"
    end
    return nil
end

function IcicleNameplates.FindFontStringNameRegion(plate)
    if plate.oldname and plate.oldname.GetText then return plate.oldname end
    if plate.name and plate.name.GetText then return plate.name end
    if plate.UnitFrame and plate.UnitFrame.oldName and plate.UnitFrame.oldName.GetText then return plate.UnitFrame.oldName end

    local best
    local regions = { plate:GetRegions() }
    for i = 1, #regions do
        local reg = regions[i]
        if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
            local txt = reg:GetText()
            if txt and txt ~= "" then
                if not best then best = reg end
                if not string.match(txt, "^%d+$") then return reg end
            end
        end
    end
    return best
end

function IcicleNameplates.FindBars(plate)
    local healthBar, castBar
    if plate.healthBar and plate.healthBar.GetObjectType and plate.healthBar:GetObjectType() == "StatusBar" then
        healthBar = plate.healthBar
    end

    local children = { plate:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            if not healthBar then
                healthBar = child
            elseif child ~= healthBar and not castBar then
                castBar = child
            end
        end
    end

    return healthBar, castBar
end

function IcicleNameplates.GetCastSpellFromBar(castBar)
    if not castBar then return nil end

    if castBar.Text and castBar.Text.GetText then
        local txt = castBar.Text:GetText()
        if txt and txt ~= "" then return txt end
    end

    local regions = { castBar:GetRegions() }
    for i = 1, #regions do
        local reg = regions[i]
        if reg and reg.GetObjectType and reg:GetObjectType() == "FontString" then
            local txt = reg:GetText()
            if txt and txt ~= "" then return txt end
        end
    end

    return nil
end

function IcicleNameplates.PlateName(meta, shortNameFn)
    if meta.nameText and meta.nameText.GetText then
        local n = meta.nameText:GetText()
        if n and n ~= "" then return shortNameFn(n) end
    end
    if meta.plate.aloftData and meta.plate.aloftData.name then
        return shortNameFn(meta.plate.aloftData.name)
    end
    return nil
end

function IcicleNameplates.IsLikelyNamePlate(frame)
    if frame.IcicleIsPlate ~= nil then return frame.IcicleIsPlate end

    local name = frame:GetName()
    if name and string.find(name, "NamePlate") then
        frame.IcicleIsPlate = true
        return true
    end

    if frame:GetNumRegions() < 2 or frame:GetNumChildren() < 1 then
        frame.IcicleIsPlate = false
        return false
    end

    -- Classic/WotLK nameplate heuristic.
    if frame:GetNumRegions() > 2 and frame:GetNumChildren() >= 1 then
        frame.IcicleIsPlate = true
        return true
    end

    local hasStatusBar = false
    local children = { frame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetObjectType and child:GetObjectType() == "StatusBar" then
            hasStatusBar = true
            break
        end
    end

    frame.IcicleIsPlate = hasStatusBar
    return hasStatusBar
end

function IcicleNameplates.AddVisibleNamePlate(visiblePlatesByName, name, plate)
    local entry = visiblePlatesByName[name]
    if not entry then
        entry = { count = 0, first = nil, map = {} }
        visiblePlatesByName[name] = entry
    end
    if not entry.map[plate] then
        entry.map[plate] = true
        entry.count = entry.count + 1
        if not entry.first then entry.first = plate end
    end
end

function IcicleNameplates.ScanNameplates(ctx)
    local now = ctx.GetTime()
    local numChildren = ctx.WorldFrame:GetNumChildren()
    local fullRescan = numChildren ~= (ctx.STATE.lastWorldChildrenCount or 0)
    if fullRescan then
        local children = { ctx.WorldFrame:GetChildren() }
        for i = 1, #children do
            local frame = children[i]
            if frame and not ctx.STATE.knownPlates[frame] and IcicleNameplates.IsLikelyNamePlate(frame) then
                ctx.RegisterPlate(frame)
            end
        end
        ctx.STATE.lastWorldChildrenCount = numChildren
    end

    ctx.WipeTable(ctx.STATE.visiblePlatesByName)
    local visibleList = ctx.STATE.visiblePlateList or {}
    ctx.STATE.visiblePlateList = visibleList
    local previousVisible = nil
    local previousVisibleSet = nil
    if not fullRescan then
        previousVisible = {}
        previousVisibleSet = {}
        for i = 1, #visibleList do
            local plate = visibleList[i]
            previousVisible[i] = plate
            previousVisibleSet[plate] = true
        end
    end
    for i = #visibleList, 1, -1 do
        visibleList[i] = nil
    end
    ctx.STATE.visiblePlateCount = 0
    ctx.STATE.visibleCount = 0

    local function ProcessPlate(plate)
        if plate:IsShown() and plate:GetAlpha() > 0 then
            local meta = ctx.STATE.plateMeta[plate]
            if meta then
                meta.name = IcicleNameplates.PlateName(meta, ctx.ShortName)
                if meta.name then
                    IcicleNameplates.AddVisibleNamePlate(ctx.STATE.visiblePlatesByName, meta.name, plate)
                    ctx.STATE.visiblePlateCount = ctx.STATE.visiblePlateCount + 1
                    visibleList[ctx.STATE.visiblePlateCount] = plate
                    ctx.STATE.visibleCount = ctx.STATE.visibleCount + 1
                end

                if meta.healthBar and meta.healthBar.GetStatusBarColor then
                    local r, g, b = meta.healthBar:GetStatusBarColor()
                    if meta._lastHealthR ~= r or meta._lastHealthG ~= g or meta._lastHealthB ~= b then
                        meta._lastHealthR, meta._lastHealthG, meta._lastHealthB = r, g, b
                        local reaction = ReactionFromBarColor(r, g, b)
                        ctx.STATE.reactionByPlate = ctx.STATE.reactionByPlate or {}
                        ctx.STATE.reactionSourceByPlate = ctx.STATE.reactionSourceByPlate or {}
                        if reaction then
                            meta.reactionHint = reaction
                            ctx.STATE.reactionByPlate[plate] = reaction
                            ctx.STATE.reactionSourceByPlate[plate] = "color"
                        else
                            meta.reactionHint = nil
                            ctx.STATE.reactionByPlate[plate] = nil
                            ctx.STATE.reactionSourceByPlate[plate] = nil
                        end
                    end
                end

                if meta.castBar and meta.castBar:IsShown() then
                    if (not meta._lastCastProbeAt) or (now - meta._lastCastProbeAt) >= 0.08 then
                        meta._lastCastProbeAt = now
                        local castSpell = IcicleNameplates.GetCastSpellFromBar(meta.castBar)
                        if castSpell and castSpell ~= "" then
                            if castSpell ~= meta.lastCastSpell or (now - meta.lastCastAt) > ctx.db.castMatchWindow then
                                meta.lastCastSpell = castSpell
                                meta.lastCastAt = now
                            end
                        end
                    end
                else
                    if meta.lastCastSpell and (now - meta.lastCastAt) > ctx.db.castMatchWindow then
                        meta.lastCastSpell = nil
                    end
                    meta._lastCastProbeAt = now
                end

                if meta.container then meta.container:Show() end
            end
        else
            local meta = ctx.STATE.plateMeta[plate]
            if meta and meta.container then meta.container:Hide() end
            if ctx.STATE.reactionByPlate then
                ctx.STATE.reactionByPlate[plate] = nil
            end
            if ctx.STATE.reactionSourceByPlate then
                ctx.STATE.reactionSourceByPlate[plate] = nil
            end
            ctx.RemovePlateBinding(plate)
        end
    end

    if fullRescan then
        for plate in pairs(ctx.STATE.knownPlates) do
            ProcessPlate(plate)
        end
    else
        local prevCount = previousVisible and #previousVisible or 0
        for i = 1, prevCount do
            local plate = previousVisible[i]
            if plate then
                ProcessPlate(plate)
            end
        end
        local dirtyCount = ctx.STATE.dirtyPlateCount or 0
        for i = 1, dirtyCount do
            local plate = ctx.STATE.dirtyPlateList and ctx.STATE.dirtyPlateList[i]
            if plate and (not previousVisibleSet or not previousVisibleSet[plate]) then
                ProcessPlate(plate)
            end
        end
    end

    if ctx.TryResolvePendingBinds then
        ctx.TryResolvePendingBinds()
    end

    ctx.DecayAndPurgeMappings()
end
