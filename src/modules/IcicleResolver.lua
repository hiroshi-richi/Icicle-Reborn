IcicleResolver = IcicleResolver or {}

local GetTime = GetTime

local function UnitReactionCategory(unit)
    if not unit or unit == "" or not UnitExists(unit) then
        return nil
    end
    if UnitCanAttack("player", unit) then
        return "hostile"
    end
    if UnitIsFriend("player", unit) then
        return "friendly"
    end
    local r = UnitReaction(unit, "player")
    if type(r) == "number" then
        if r <= 4 then
            return "neutral"
        end
        return "friendly"
    end
    return nil
end

local function RememberReaction(ctx, guid, name, plate, reaction, source)
    if not reaction then return end
    ctx.STATE.reactionByGUID = ctx.STATE.reactionByGUID or {}
    ctx.STATE.reactionByName = ctx.STATE.reactionByName or {}
    ctx.STATE.reactionByPlate = ctx.STATE.reactionByPlate or {}
    ctx.STATE.reactionSourceByGUID = ctx.STATE.reactionSourceByGUID or {}
    ctx.STATE.reactionSourceByName = ctx.STATE.reactionSourceByName or {}
    ctx.STATE.reactionSourceByPlate = ctx.STATE.reactionSourceByPlate or {}
    if guid then ctx.STATE.reactionByGUID[guid] = reaction end
    if name then ctx.STATE.reactionByName[name] = reaction end
    if plate then ctx.STATE.reactionByPlate[plate] = reaction end
    if source then
        if guid then ctx.STATE.reactionSourceByGUID[guid] = source end
        if name then ctx.STATE.reactionSourceByName[name] = source end
        if plate then ctx.STATE.reactionSourceByPlate[plate] = source end
    end
end

local function PlateReaction(ctx, plate)
    return ctx.STATE.reactionByPlate and ctx.STATE.reactionByPlate[plate] or nil
end

local function PruneCandidateGuids(ctx)
    local now = GetTime()
    local ttl = (ctx.db and ctx.db.mappingTTL or 8) * 2
    for name, guids in pairs(ctx.STATE.candidatesByName) do
        for guid, seenAt in pairs(guids) do
            if (now - (seenAt or 0)) > ttl then
                guids[guid] = nil
            end
        end
        if next(guids) == nil then
            ctx.STATE.candidatesByName[name] = nil
        end
    end
end

function IcicleResolver.RemovePlateBinding(ctx, plate)
    local mapped = ctx.STATE.guidByPlate[plate]
    if not mapped then return end
    local guid = mapped.guid
    if guid and ctx.STATE.plateByGUID[guid] and ctx.STATE.plateByGUID[guid].plate == plate then
        ctx.STATE.plateByGUID[guid] = nil
    end
    ctx.STATE.guidByPlate[plate] = nil
    if ctx.STATE.reactionByPlate then
        ctx.STATE.reactionByPlate[plate] = nil
    end
    if ctx.STATE.reactionSourceByPlate then
        ctx.STATE.reactionSourceByPlate[plate] = nil
    end
end

function IcicleResolver.RemoveGUIDBinding(ctx, guid)
    local mapped = ctx.STATE.plateByGUID[guid]
    if not mapped then return end
    local plate = mapped.plate
    if plate and ctx.STATE.guidByPlate[plate] and ctx.STATE.guidByPlate[plate].guid == guid then
        ctx.STATE.guidByPlate[plate] = nil
    end
    ctx.STATE.plateByGUID[guid] = nil
end

function IcicleResolver.SetBinding(ctx, guid, plate, conf, reason, sourceName)
    if not guid or not plate then return false end

    local now = GetTime()
    IcicleResolver.RemoveGUIDBinding(ctx, guid)
    IcicleResolver.RemovePlateBinding(ctx, plate)

    ctx.STATE.plateByGUID[guid] = { plate = plate, conf = conf, lastSeen = now, sourceName = sourceName, reason = reason }
    ctx.STATE.guidByPlate[plate] = { guid = guid, conf = conf, lastSeen = now, sourceName = sourceName, reason = reason }
    return true
end

function IcicleResolver.DecayAndPurgeMappings(ctx)
    local now = GetTime()
    for guid, entry in pairs(ctx.STATE.plateByGUID) do
        if (not entry.plate) or (not entry.plate:IsShown()) then
            IcicleResolver.RemoveGUIDBinding(ctx, guid)
        else
            local conf = ctx.DecayedConfidence(entry, now)
            if conf < ctx.db.minConfidence or (now - entry.lastSeen) > ctx.db.mappingTTL then
                IcicleResolver.RemoveGUIDBinding(ctx, guid)
            end
        end
    end
    PruneCandidateGuids(ctx)
end

function IcicleResolver.RegisterPendingBind(ctx, guid, name, spellName, eventTime)
    if not guid or not name then
        return
    end
    ctx.STATE.pendingBindByGUID = ctx.STATE.pendingBindByGUID or {}
    local now = GetTime()
    ctx.STATE.pendingBindByGUID[guid] = {
        name = name,
        spellName = spellName,
        eventTime = eventTime or now,
        createdAt = now,
        expiresAt = now + math.max(2, (ctx.db and ctx.db.mappingTTL or 8)),
    }
end

function IcicleResolver.MigrateNameCooldownsToGUID(ctx, name, guid)
    local byName = ctx.STATE.cooldownsByName[name]
    if not byName then return end

    ctx.STATE.cooldownsByGUID[guid] = ctx.STATE.cooldownsByGUID[guid] or { __dirty = true, __list = {}, __listCount = 0 }
    local byGUID = ctx.STATE.cooldownsByGUID[guid]
    for spellID, rec in pairs(byName) do
        if type(spellID) == "number" and type(rec) == "table" then
            local current = byGUID[spellID]
            if (not current) or current.expiresAt < rec.expiresAt then
                byGUID[spellID] = rec
                byGUID.__dirty = true
                if ctx.RegisterExpiryRecord then
                    ctx.RegisterExpiryRecord("guid", guid, rec)
                end
            end
        end
    end
    ctx.STATE.cooldownsByName[name] = nil
end

function IcicleResolver.RegisterCandidate(ctx, name, guid)
    if not name or not guid then return end
    ctx.STATE.candidatesByName[name] = ctx.STATE.candidatesByName[name] or {}
    ctx.STATE.candidatesByName[name][guid] = GetTime()
end

function IcicleResolver.TryBindByName(ctx, guid, name, baseConf, reason, spellName, eventTime)
    if not guid or not name then return false end
    IcicleResolver.RegisterCandidate(ctx, name, guid)

    local plates = ctx.STATE.visiblePlatesByName[name]
    if not plates or plates.count == 0 then return false end
    if plates.count == 1 then
        local onlyReaction = PlateReaction(ctx, plates.first)
        if onlyReaction == "friendly" then
            return false
        end
        return IcicleResolver.SetBinding(ctx, guid, plates.first, baseConf, reason, name)
    end

    if spellName then
        local candidatePlate, candidateCount = nil, 0
        local latestPlate, latestCount, latestAt = nil, 0, 0
        for plate in pairs(plates.map) do
            local reaction = PlateReaction(ctx, plate)
            local reactionAllowed = reaction ~= "friendly"
            if reactionAllowed then
                local meta = ctx.STATE.plateMeta[plate]
                if meta and meta.lastCastAt and math.abs(meta.lastCastAt - eventTime) <= ctx.db.castMatchWindow and meta.lastCastSpell == spellName then
                    candidateCount = candidateCount + 1
                    candidatePlate = plate
                end
                if meta and meta.lastCastSpell == spellName and meta.lastCastAt and meta.lastCastAt > latestAt then
                    latestAt = meta.lastCastAt
                    latestPlate = plate
                    latestCount = 1
                elseif meta and meta.lastCastSpell == spellName and meta.lastCastAt and meta.lastCastAt == latestAt and latestAt > 0 then
                    latestCount = latestCount + 1
                end
            end
        end
        if candidateCount == 1 then
            return IcicleResolver.SetBinding(ctx, guid, candidatePlate, 0.98, "castbar", name)
        end
        if candidateCount == 0 and latestPlate and latestCount == 1 and (GetTime() - latestAt) <= math.max(0.15, (ctx.db.castMatchWindow or 0.25) * 2) then
            return IcicleResolver.SetBinding(ctx, guid, latestPlate, 0.92, "castbar-latest", name)
        end
    end

    return false
end

function IcicleResolver.TryResolvePendingBinds(ctx)
    ctx.STATE.pendingBindByGUID = ctx.STATE.pendingBindByGUID or {}
    local now = GetTime()
    for guid, pending in pairs(ctx.STATE.pendingBindByGUID) do
        if not pending or not pending.name or now > (pending.expiresAt or 0) then
            ctx.STATE.pendingBindByGUID[guid] = nil
        else
            local ok = IcicleResolver.TryBindByName(
                ctx,
                guid,
                pending.name,
                0.88,
                "pending",
                pending.spellName,
                pending.eventTime or now
            )
            if ok then
                IcicleResolver.MigrateNameCooldownsToGUID(ctx, pending.name, guid)
                ctx.STATE.pendingBindByGUID[guid] = nil
            end
        end
    end
end

function IcicleResolver.ResolveUnit(ctx, unit, confidence, reason)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    local name = ctx.ShortName(UnitName(unit))
    if not guid or not name then return end
    local reaction = UnitReactionCategory(unit)
    local _, classToken = UnitClass(unit)
    local classCategory = ctx.ClassTokenToCategory and ctx.ClassTokenToCategory(classToken) or nil
    if classCategory then
        ctx.STATE.classByGUID = ctx.STATE.classByGUID or {}
        ctx.STATE.classByName = ctx.STATE.classByName or {}
        ctx.STATE.classByGUID[guid] = classCategory
        ctx.STATE.classByName[name] = classCategory
    end
    RememberReaction(ctx, guid, name, nil, reaction, "unit")

    IcicleResolver.RegisterCandidate(ctx, name, guid)
    local plates = ctx.STATE.visiblePlatesByName[name]
    if plates and plates.count == 1 and IcicleResolver.SetBinding(ctx, guid, plates.first, confidence, reason, name) then
        RememberReaction(ctx, guid, name, plates.first, reaction, "unit")
        IcicleResolver.MigrateNameCooldownsToGUID(ctx, name, guid)
    end
end

function IcicleResolver.ResolveGroupTargets(ctx)
    if UnitExists("target") then IcicleResolver.ResolveUnit(ctx, "target", 0.95, "target") end
    if UnitExists("focus") then IcicleResolver.ResolveUnit(ctx, "focus", 0.95, "focus") end
    if UnitExists("mouseover") then IcicleResolver.ResolveUnit(ctx, "mouseover", 0.95, "mouseover") end

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i = 1, 40 do
            local unit = "raid" .. i .. "target"
            if UnitExists(unit) then IcicleResolver.ResolveUnit(ctx, unit, 0.8, "raid-target") end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i .. "target"
            if UnitExists(unit) then IcicleResolver.ResolveUnit(ctx, unit, 0.75, "party-target") end
        end
    end
end

