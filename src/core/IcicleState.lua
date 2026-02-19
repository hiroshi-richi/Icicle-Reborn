IcicleState = IcicleState or {}

function IcicleState.BuildInitialState()
    return {
        knownPlates = {},
        plateMeta = {},
        visiblePlatesByName = {},
        visibleCount = 0,

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

