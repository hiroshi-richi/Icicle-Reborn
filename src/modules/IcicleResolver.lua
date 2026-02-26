IcicleResolver = IcicleResolver or {}

local GetTime = GetTime
local abs = math.abs
local max = math.max

-- Resolver-only heuristics (not exposed in UI). Values are conservative defaults
-- tuned for multi-target arena ambiguity without delaying obvious bindings.
local RESOLVER_TUNING = {
    candidateTTLMultiplier = 2.0,
    pendingBindMinTTL = 2.0,
    castMatchUniqueConfidence = 0.98,
    castMatchNearestConfidence = 0.96,
    castMatchLatestConfidence = 0.92,
    castMatchLatestWindowMultiplier = 2.0,
    castMatchLatestWindowMin = 0.15,
    castNearestMinGap = 0.06,
}

local function TunedNumber(ctx, key, fallback, minValue, maxValue)
    local value = fallback
    local db = ctx and ctx.db
    if db and type(db.resolverTuning) == "table" and tonumber(db.resolverTuning[key]) then
        value = tonumber(db.resolverTuning[key])
    end
    value = tonumber(value) or fallback
    if minValue ~= nil and value < minValue then
        value = minValue
    end
    if maxValue ~= nil and value > maxValue then
        value = maxValue
    end
    return value
end

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
    local ttlMultiplier = TunedNumber(ctx, "candidateTTLMultiplier", RESOLVER_TUNING.candidateTTLMultiplier, 1.0, 5.0)
    local ttl = (ctx.db and ctx.db.mappingTTL or 8) * ttlMultiplier
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
    local minTTL = TunedNumber(ctx, "pendingBindMinTTL", RESOLVER_TUNING.pendingBindMinTTL, 0.5, 10.0)
    ctx.STATE.pendingBindByGUID[guid] = {
        name = name,
        spellName = spellName,
        eventTime = eventTime or now,
        createdAt = now,
        expiresAt = now + max(minTTL, (ctx.db and ctx.db.mappingTTL or 8)),
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
        local castWindow = max(0.05, tonumber(ctx.db and ctx.db.castMatchWindow) or 0.25)
        local nearestPlate, nearestDelta, secondNearestDelta, candidateCount = nil, nil, nil, 0
        local latestPlate, latestCount, latestAt = nil, 0, 0
        for plate in pairs(plates.map) do
            local reaction = PlateReaction(ctx, plate)
            local reactionAllowed = reaction ~= "friendly"
            if reactionAllowed then
                local meta = ctx.STATE.plateMeta[plate]
                if meta and meta.lastCastSpell == spellName and meta.lastCastAt and meta.lastCastAt > latestAt then
                    latestAt = meta.lastCastAt
                    latestPlate = plate
                    latestCount = 1
                elseif meta and meta.lastCastSpell == spellName and meta.lastCastAt and meta.lastCastAt == latestAt and latestAt > 0 then
                    latestCount = latestCount + 1
                end
                if meta and meta.lastCastAt and meta.lastCastSpell == spellName then
                    local delta = abs(meta.lastCastAt - eventTime)
                    if delta <= castWindow then
                        candidateCount = candidateCount + 1
                        if nearestDelta == nil or delta < nearestDelta then
                            secondNearestDelta = nearestDelta
                            nearestDelta = delta
                            nearestPlate = plate
                        elseif secondNearestDelta == nil or delta < secondNearestDelta then
                            secondNearestDelta = delta
                        end
                    end
                end
            end
        end
        if candidateCount == 1 then
            local conf = TunedNumber(ctx, "castMatchUniqueConfidence", RESOLVER_TUNING.castMatchUniqueConfidence, 0.80, 1.0)
            return IcicleResolver.SetBinding(ctx, guid, nearestPlate, conf, "castbar", name)
        end
        if candidateCount > 1 and nearestPlate and nearestDelta and secondNearestDelta then
            local minGap = TunedNumber(ctx, "castNearestMinGap", RESOLVER_TUNING.castNearestMinGap, 0.01, 0.20)
            if (secondNearestDelta - nearestDelta) >= minGap then
                local conf = TunedNumber(ctx, "castMatchNearestConfidence", RESOLVER_TUNING.castMatchNearestConfidence, 0.80, 1.0)
                return IcicleResolver.SetBinding(ctx, guid, nearestPlate, conf, "castbar-nearest", name)
            end
        end
        local latestWindowMultiplier = TunedNumber(ctx, "castMatchLatestWindowMultiplier", RESOLVER_TUNING.castMatchLatestWindowMultiplier, 1.0, 4.0)
        local latestWindowMin = TunedNumber(ctx, "castMatchLatestWindowMin", RESOLVER_TUNING.castMatchLatestWindowMin, 0.05, 0.5)
        if candidateCount == 0 and latestPlate and latestCount == 1 and (GetTime() - latestAt) <= max(latestWindowMin, castWindow * latestWindowMultiplier) then
            local conf = TunedNumber(ctx, "castMatchLatestConfidence", RESOLVER_TUNING.castMatchLatestConfidence, 0.75, 1.0)
            return IcicleResolver.SetBinding(ctx, guid, latestPlate, conf, "castbar-latest", name)
        end
    end

    return false
end

function IcicleResolver.TryResolvePendingBinds(ctx)
    ctx.STATE.pendingBindByGUID = ctx.STATE.pendingBindByGUID or {}
    local now = GetTime()
    local changed = false
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
                if ctx.MarkDirtyBySource then
                    ctx.MarkDirtyBySource(guid, pending.name)
                end
                ctx.STATE.pendingBindByGUID[guid] = nil
                changed = true
            end
        end
    end
    if changed then
        if ctx.RefreshDirtyPlates then
            ctx.RefreshDirtyPlates()
        elseif ctx.RefreshAllVisiblePlates then
            ctx.RefreshAllVisiblePlates()
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

    local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raidCount > 0 then
        for i = 1, raidCount do
            local unit = "raid" .. i .. "target"
            if UnitExists(unit) then IcicleResolver.ResolveUnit(ctx, unit, 0.8, "raid-target") end
        end
    else
        local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 4
        if partyCount <= 0 then
            partyCount = 4
        end
        for i = 1, partyCount do
            local unit = "party" .. i .. "target"
            if UnitExists(unit) then IcicleResolver.ResolveUnit(ctx, unit, 0.75, "party-target") end
        end
    end
end
