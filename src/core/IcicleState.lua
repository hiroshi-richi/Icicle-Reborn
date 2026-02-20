IcicleState = IcicleState or {}

local RESET_TABLE_FIELDS = {
    "plateByGUID",
    "guidByPlate",
    "candidatesByName",
    "pendingBindByGUID",
    "recentEventByUnit",
    "recentUnitSucceededByUnit",
    "lastSpecAuraCheckByGUID",
    "spellCategoryCache",
    "classByGUID",
    "classByName",
    "reactionByGUID",
    "reactionByName",
    "reactionByPlate",
    "reactionSourceByGUID",
    "reactionSourceByName",
    "reactionSourceByPlate",
    "inspectUnitByGUID",
    "inspectRequestAtByGUID",
    "inspectQueue",
    "inspectQueuedByGUID",
    "inspectOutOfRangeSince",
    "inspectOutOfRangeUnits",
    "feignDeathAuraByGUID",
    "dirtyPlates",
    "dirtyPlateList",
    "visiblePlateList",
    "visiblePlateIndexByRef",
    "expiryHeap",
}

function IcicleState.BuildInitialState()
    return {
        knownPlates = {},
        plateMeta = {},
        visiblePlatesByName = {},
        visiblePlateList = {},
        visiblePlateCount = 0,
        visiblePlateIndexByRef = {},
        visibleCount = 0,
        dirtyPlates = {},
        dirtyPlateList = {},
        dirtyPlateCount = 0,

        plateByGUID = {},
        guidByPlate = {},
        candidatesByName = {},
        pendingBindByGUID = {},

        cooldownsByGUID = {},
        cooldownsByName = {},
        recentEventByUnit = {},
        recentUnitSucceededByUnit = {},
        specByGUID = {},
        specByName = {},
        lastSpecAuraCheckByGUID = {},
        classByGUID = {},
        classByName = {},
        reactionByGUID = {},
        reactionByName = {},
        reactionByPlate = {},
        reactionSourceByGUID = {},
        reactionSourceByName = {},
        reactionSourceByPlate = {},
        inspectUnitByGUID = {},
        inspectRequestAtByGUID = {},
        inspectQueue = {},
        inspectQueuedByGUID = {},
        inspectCurrent = nil,
        inspectOutOfRangeSince = {},
        inspectOutOfRangeUnits = {},
        feignDeathAuraByGUID = {},
        lastWorldChildrenCount = 0,
        spellCategoryCache = {},
        expiryHeap = {},
        expiryCount = 0,
        expirySeq = 0,
        scratchRecords = {},
        scratchSpellInfo = {},

        scanAccum = 0,
        iconAccum = 0,
        groupAccum = 0,
        testAccum = 0,
        specAccum = 0,
        inspectAccum = 0,

        testModeActive = false,
        testPool = {},
        testPoolByType = {},
        testByPlate = {},
        ui = {},
    }
end

function IcicleState.ResetRuntimeState(state, wipeTable)
    if type(state) ~= "table" then
        return
    end
    local wipe = wipeTable
    if type(wipe) ~= "function" then
        wipe = function(tbl)
            if type(tbl) ~= "table" then
                return
            end
            for k in pairs(tbl) do
                tbl[k] = nil
            end
        end
    end

    for i = 1, #RESET_TABLE_FIELDS do
        local field = RESET_TABLE_FIELDS[i]
        wipe(state[field])
    end

    state.dirtyPlateCount = 0
    state.visiblePlateCount = 0
    state.visibleCount = 0
    state.expiryCount = 0
    state.expirySeq = 0
    state.lastWorldChildrenCount = 0
    state.inspectCurrent = nil
end

