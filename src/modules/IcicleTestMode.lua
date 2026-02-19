IcicleTestMode = IcicleTestMode or {}

local tinsert = table.insert

local INTERRUPT_SPELLS = {
    [72] = true,
    [6552] = true,
    [1766] = true,
    [2139] = true,
    [19647] = true,
    [47528] = true,
    [57994] = true,
    [47476] = true,
    [34490] = true,
}

local function IsInterruptSpell(spellID)
    return INTERRUPT_SPELLS[spellID] and true or false
end

local function IsSharedSpell(ctx, spellID)
    if not ctx.GetSharedCooldownTargets then
        return false
    end
    local targets = ctx.GetSharedCooldownTargets(spellID)
    return type(targets) == "table" and next(targets) ~= nil
end

local function IsSpecialModifierSpell(ctx, spellID)
    if not ctx.GetCooldownRule then
        return false
    end
    local rule = ctx.GetCooldownRule(spellID, nil, nil)
    return rule and type(rule.modifiers) == "table" and next(rule.modifiers) ~= nil
end

local function BuildTestPool(ctx)
    ctx.WipeTable(ctx.STATE.testPool)
    ctx.STATE.testPoolByType = { interrupt = {}, shared = {}, item = {}, special = {}, normal = {} }

    if type(ctx.BuildSpellRowsData) == "function" then
        local rows = ctx.BuildSpellRowsData() or {}
        for i = 1, #rows do
            local row = rows[i]
            local spellID = row and row.id
            local cd = row and tonumber(row.cd) or 0
            local rule = nil
            if spellID and type(ctx.GetCooldownRule) == "function" then
                rule = ctx.GetCooldownRule(spellID, nil, nil)
            end
            if spellID and row.enabled and rule and cd and cd > 0 then
                local entry = {
                    spellID = spellID,
                    cd = cd,
                    isInterrupt = IsInterruptSpell(spellID),
                    isShared = IsSharedSpell(ctx, spellID),
                    isItem = row.isItem and true or false,
                    isSpecial = IsSpecialModifierSpell(ctx, spellID),
                }
                tinsert(ctx.STATE.testPool, entry)
                if entry.isInterrupt then tinsert(ctx.STATE.testPoolByType.interrupt, entry) end
                if entry.isShared then tinsert(ctx.STATE.testPoolByType.shared, entry) end
                if entry.isItem then tinsert(ctx.STATE.testPoolByType.item, entry) end
                if entry.isSpecial then tinsert(ctx.STATE.testPoolByType.special, entry) end
                if (not entry.isInterrupt) and (not entry.isShared) and (not entry.isItem) and (not entry.isSpecial) then
                    tinsert(ctx.STATE.testPoolByType.normal, entry)
                end
            end
        end
        return
    end

    if not ctx.baseCooldowns then
        return
    end

    for spellID, cfg in pairs(ctx.baseCooldowns) do
        local rule = nil
        if type(ctx.GetCooldownRule) == "function" then
            rule = ctx.GetCooldownRule(spellID, nil, nil)
        end
        if rule then
            local cd
            if type(cfg) == "number" then
                cd = cfg
            elseif type(cfg) == "table" then
                cd = cfg.cd or cfg.duration
            end
            if cd and cd > 0 then
                local entry = {
                    spellID = spellID,
                    cd = cd,
                    isInterrupt = IsInterruptSpell(spellID),
                    isShared = IsSharedSpell(ctx, spellID),
                    isItem = ctx.IsItemSpell and (ctx.IsItemSpell(spellID) and true or false) or false,
                    isSpecial = IsSpecialModifierSpell(ctx, spellID),
                }
                tinsert(ctx.STATE.testPool, entry)
                if entry.isInterrupt then tinsert(ctx.STATE.testPoolByType.interrupt, entry) end
                if entry.isShared then tinsert(ctx.STATE.testPoolByType.shared, entry) end
                if entry.isItem then tinsert(ctx.STATE.testPoolByType.item, entry) end
                if entry.isSpecial then tinsert(ctx.STATE.testPoolByType.special, entry) end
                if (not entry.isInterrupt) and (not entry.isShared) and (not entry.isItem) and (not entry.isSpecial) then
                    tinsert(ctx.STATE.testPoolByType.normal, entry)
                end
            end
        end
    end
end

local function EnsurePools(ctx)
    -- Rebuild every time so test mode always reflects current enabled/disabled tracking state.
    BuildTestPool(ctx)
end

local function RandomFromList(list)
    if not list or #list == 0 then
        return nil
    end
    return list[math.random(1, #list)]
end

local function RandomSpellEntry(ctx)
    return RandomFromList(ctx.STATE.testPool)
end

local function AddPick(ctx, records, used, now, pick)
    if not pick or used[pick.spellID] then
        return false
    end
    local spellName, tex
    if ctx and ctx.GetSpellOrItemInfo then
        spellName, tex = ctx.GetSpellOrItemInfo(pick.spellID, pick.isItem and true or false)
    else
        spellName, _, tex = GetSpellInfo(pick.spellID)
    end
    local duration = math.max(4, math.floor(pick.cd * (0.3 + math.random())))
    records[#records + 1] = {
        spellID = pick.spellID,
        spellName = spellName or ("Spell " .. tostring(pick.spellID)),
        texture = tex or "Interface\\Icons\\INV_Misc_QuestionMark",
        startAt = now,
        expiresAt = now + duration,
        duration = duration,
        isInterrupt = pick.isInterrupt or false,
        isShared = pick.isShared or false,
        isItem = pick.isItem or false,
        isSpecial = pick.isSpecial or false,
        __ambiguous = false,
    }
    used[pick.spellID] = true
    return true
end

local function FillSmartRecords(ctx, records, now, totalCount)
    local used = {}
    local pools = ctx.STATE.testPoolByType or {}

    -- Ensure key visual scenarios are present whenever possible.
    AddPick(ctx, records, used, now, RandomFromList(pools.interrupt))
    AddPick(ctx, records, used, now, RandomFromList(pools.shared))
    AddPick(ctx, records, used, now, RandomFromList(pools.special))
    AddPick(ctx, records, used, now, RandomFromList(pools.item))

    while #records < totalCount do
        local pick = RandomSpellEntry(ctx)
        if not pick then
            break
        end
        AddPick(ctx, records, used, now, pick)
        if #records > #ctx.STATE.testPool then
            break
        end
    end
end

function IcicleTestMode.PopulateRandomPlateTests(ctx)
    local now = GetTime()
    ctx.WipeTable(ctx.STATE.testByPlate)
    EnsurePools(ctx)

    for plate in pairs(ctx.STATE.knownPlates) do
        if plate:IsShown() and plate:GetAlpha() > 0 then
            local records = {}
            local count = math.random(3, 5)
            FillSmartRecords(ctx, records, now, count)
            if #records > 0 then
                ctx.STATE.testByPlate[plate] = records
            end
        end
    end
end

function IcicleTestMode.RandomizeTestMode(ctx)
    if not ctx.STATE.testModeActive then return end
    IcicleTestMode.PopulateRandomPlateTests(ctx)
    ctx.RefreshAllVisiblePlates()
end

function IcicleTestMode.StopTestMode(ctx)
    ctx.STATE.testModeActive = false
    ctx.WipeTable(ctx.STATE.testByPlate)
    if ctx.STATE.ui and ctx.STATE.ui.status then
        ctx.STATE.ui.status:SetText("Test: OFF")
        ctx.STATE.ui.status:SetTextColor(1, 0.2, 0.2)
    end
    ctx.RefreshAllVisiblePlates()
end

function IcicleTestMode.StartTestMode(ctx)
    if randomseed then
        randomseed(time())
    elseif math.randomseed then
        math.randomseed(time())
    end
    BuildTestPool(ctx)
    ctx.STATE.testModeActive = true
    IcicleTestMode.PopulateRandomPlateTests(ctx)
    if ctx.STATE.ui and ctx.STATE.ui.status then
        ctx.STATE.ui.status:SetText("Test: ON")
        ctx.STATE.ui.status:SetTextColor(0.2, 1, 0.2)
    end
    ctx.RefreshAllVisiblePlates()
end

function IcicleTestMode.ToggleTestMode(ctx)
    if ctx.STATE.testModeActive then
        IcicleTestMode.StopTestMode(ctx)
        ctx.Print("test mode disabled")
    else
        IcicleTestMode.StartTestMode(ctx)
        ctx.Print("test mode enabled")
    end
end
