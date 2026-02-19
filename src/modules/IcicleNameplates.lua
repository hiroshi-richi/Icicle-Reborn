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
    local num = ctx.WorldFrame:GetNumChildren()

    for i = 1, num do
        local frame = select(i, ctx.WorldFrame:GetChildren())
        if frame and not ctx.STATE.knownPlates[frame] and IcicleNameplates.IsLikelyNamePlate(frame) then
            ctx.RegisterPlate(frame)
        end
    end

    ctx.WipeTable(ctx.STATE.visiblePlatesByName)
    ctx.STATE.visibleCount = 0

    for plate in pairs(ctx.STATE.knownPlates) do
        if plate:IsShown() and plate:GetAlpha() > 0 then
            local meta = ctx.STATE.plateMeta[plate]
            if meta then
                meta.name = IcicleNameplates.PlateName(meta, ctx.ShortName)
                if meta.name then
                    IcicleNameplates.AddVisibleNamePlate(ctx.STATE.visiblePlatesByName, meta.name, plate)
                    ctx.STATE.visibleCount = ctx.STATE.visibleCount + 1
                end

                if meta.healthBar and meta.healthBar.GetStatusBarColor then
                    local r, g, b = meta.healthBar:GetStatusBarColor()
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

                if meta.castBar and meta.castBar:IsShown() then
                    local castSpell = IcicleNameplates.GetCastSpellFromBar(meta.castBar)
                    if castSpell and castSpell ~= "" then
                        if castSpell ~= meta.lastCastSpell or (ctx.GetTime() - meta.lastCastAt) > ctx.db.castMatchWindow then
                            meta.lastCastSpell = castSpell
                            meta.lastCastAt = ctx.GetTime()
                        end
                    end
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

    if ctx.TryResolvePendingBinds then
        ctx.TryResolvePendingBinds()
    end

    ctx.DecayAndPurgeMappings()
end
