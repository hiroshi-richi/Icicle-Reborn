IcicleInspect = IcicleInspect or {}

local tremove = table.remove
local sort = table.sort

local function RemoveInspectQueueEntryAt(state, index)
    local entry = state.inspectQueue[index]
    if not entry then
        return
    end
    state.inspectQueuedByGUID[entry.guid] = nil
    tremove(state.inspectQueue, index)
end

local function RemoveInspectQueueByGUID(state, guid)
    if not guid then
        return
    end
    for i = #state.inspectQueue, 1, -1 do
        local entry = state.inspectQueue[i]
        if entry and entry.guid == guid then
            RemoveInspectQueueEntryAt(state, i)
        end
    end
    state.inspectQueuedByGUID[guid] = nil
end

function IcicleInspect.QueueInspectForUnit(ctx, unit)
    if not unit or unit == "" or not UnitExists(unit) or not NotifyInspect then
        return
    end
    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    local state = ctx.STATE
    if state.inspectQueuedByGUID[guid] then
        for i = 1, #state.inspectQueue do
            local entry = state.inspectQueue[i]
            if entry and entry.guid == guid then
                entry.unit = unit
                entry.lastSeen = GetTime()
                break
            end
        end
        return
    end

    local now = GetTime()
    state.inspectQueue[#state.inspectQueue + 1] = {
        guid = guid,
        unit = unit,
        enqueuedAt = now,
        lastTryAt = 0,
        lastSeen = now,
    }
    state.inspectQueuedByGUID[guid] = true
end

local function IsInspectUnitInRange(unit)
    if not unit or not UnitExists(unit) then
        return false
    end
    if CheckInteractDistance then
        local inRange = CheckInteractDistance(unit, 1)
        if inRange == 1 then
            return true
        end
        if inRange == 0 then
            return false
        end
    end
    if CanInspect then
        return CanInspect(unit, true) and true or false
    end
    return true
end

local function RecordInspectOutOfRangeUnit(state, guid, unit)
    if not guid then
        return
    end
    state.inspectOutOfRangeUnits[guid] = tostring(UnitName(unit) or guid)
end

local function FlushInspectOutOfRangeMessage(ctx)
    local state = ctx.STATE
    local db = ctx.db
    if not db or not db.showOutOfRangeInspectMessages then
        ctx.WipeTable(state.inspectOutOfRangeUnits)
        return
    end

    local names = {}
    for _, unitName in pairs(state.inspectOutOfRangeUnits) do
        names[#names + 1] = tostring(unitName)
    end
    ctx.WipeTable(state.inspectOutOfRangeUnits)

    if #names == 0 then
        return
    end

    sort(names)
    ctx.Print("Inspect skipped (out of range): " .. table.concat(names, ", "))
end

function IcicleInspect.ProcessInspectQueue(ctx)
    local state = ctx.STATE
    local db = ctx.db
    if not db or not NotifyInspect or #state.inspectQueue == 0 then
        return
    end

    if state.inspectCurrent then
        local active = state.inspectCurrent
        local maxRetry = tonumber(db.inspectMaxRetryTime) or 30
        if (GetTime() - (active.requestedAt or 0)) > maxRetry then
            if ClearInspectPlayer then
                ClearInspectPlayer()
            end
            state.inspectCurrent = nil
            state.inspectUnitByGUID[active.guid] = nil
            RemoveInspectQueueByGUID(state, active.guid)
            state.inspectOutOfRangeSince[active.guid] = nil
        end
        return
    end

    local now = GetTime()
    local retryInterval = tonumber(db.inspectRetryInterval) or 1.0
    local maxRetry = tonumber(db.inspectMaxRetryTime) or 30
    local selectedIndex = nil

    for i = 1, #state.inspectQueue do
        local entry = state.inspectQueue[i]
        if entry then
            local unit = entry.unit
            local guid = entry.guid
            local tooOld = (now - (entry.enqueuedAt or now)) > maxRetry
            if tooOld then
                if state.inspectOutOfRangeSince[guid] then
                    RecordInspectOutOfRangeUnit(state, guid, unit)
                end
                RemoveInspectQueueEntryAt(state, i)
                break
            end

            if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
                RemoveInspectQueueEntryAt(state, i)
                break
            end

            if not IsInspectUnitInRange(unit) then
                if not state.inspectOutOfRangeSince[guid] then
                    state.inspectOutOfRangeSince[guid] = now
                end
                if (now - state.inspectOutOfRangeSince[guid]) >= maxRetry then
                    RecordInspectOutOfRangeUnit(state, guid, unit)
                    RemoveInspectQueueEntryAt(state, i)
                    state.inspectOutOfRangeSince[guid] = nil
                    break
                end
            else
                state.inspectOutOfRangeSince[guid] = nil
                if not selectedIndex and (now - (entry.lastTryAt or 0)) >= retryInterval then
                    selectedIndex = i
                end
            end
        end
    end

    if next(state.inspectOutOfRangeUnits) then
        FlushInspectOutOfRangeMessage(ctx)
    end

    if not selectedIndex then
        return
    end

    local entry = state.inspectQueue[selectedIndex]
    if not entry then
        return
    end
    entry.lastTryAt = now
    state.inspectRequestAtByGUID[entry.guid] = now
    state.inspectUnitByGUID[entry.guid] = entry.unit
    state.inspectCurrent = { guid = entry.guid, unit = entry.unit, requestedAt = now }
    NotifyInspect(entry.unit)
end

function IcicleInspect.HandleInspectTalentReady(ctx, guid)
    local state = ctx.STATE
    if not guid or guid == "" then
        state.inspectCurrent = nil
        return
    end
    local unit = state.inspectUnitByGUID[guid]
    if not unit or not UnitExists(unit) or UnitGUID(unit) ~= guid then
        state.inspectUnitByGUID[guid] = nil
        state.inspectCurrent = nil
        RemoveInspectQueueByGUID(state, guid)
        state.inspectOutOfRangeSince[guid] = nil
        return
    end
    local name, classToken = UnitClass(unit)
    if not classToken then
        state.inspectUnitByGUID[guid] = nil
        state.inspectCurrent = nil
        RemoveInspectQueueByGUID(state, guid)
        state.inspectOutOfRangeSince[guid] = nil
        return
    end
    local bestTab, bestPoints = nil, -1
    for tabIndex = 1, 3 do
        local _, _, pointsSpent = GetTalentTabInfo(tabIndex, true, false, 1)
        pointsSpent = tonumber(pointsSpent) or 0
        if pointsSpent > bestPoints then
            bestPoints = pointsSpent
            bestTab = tabIndex
        end
    end
    if bestTab and bestPoints >= 0 then
        ctx.SyncSpecContext()
        local changed = ctx.SpecModule.UpdateFromInspectTalents(ctx.SPEC_CONTEXT, guid, ctx.ShortName(name), classToken, bestTab)
        if changed then
            ctx.RefreshAllVisiblePlates()
        end
    end
    state.inspectUnitByGUID[guid] = nil
    state.inspectCurrent = nil
    state.inspectOutOfRangeSince[guid] = nil
    state.inspectOutOfRangeUnits[guid] = nil
    RemoveInspectQueueByGUID(state, guid)
    if ClearInspectPlayer then
        ClearInspectPlayer()
    end
end
