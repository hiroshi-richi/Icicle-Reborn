IcicleMigration = IcicleMigration or {}

local PROFILE_SCHEMA_VERSION = 3

local function MigrateTo1(db)
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}
    db.persistSpecHints = db.persistSpecHints and true or false
    db.matrixLogEnabled = db.matrixLogEnabled ~= false
    db.matrixStrictSelfTests = db.matrixStrictSelfTests and true or false
    db.matrixLogMaxEntries = math.max(5, math.min(200, tonumber(db.matrixLogMaxEntries) or 30))
end

local function MigrateTo2(db)
    local now = GetTime and GetTime() or 0
    db.specHintsByGUID = db.specHintsByGUID or {}
    db.specHintsByName = db.specHintsByName or {}

    for k, v in pairs(db.specHintsByGUID) do
        if type(v) == "string" then
            db.specHintsByGUID[k] = { spec = v, confidence = 0.9, lastSeen = now, source = "migrate-v2" }
        elseif type(v) == "table" then
            db.specHintsByGUID[k] = {
                spec = v.spec,
                confidence = tonumber(v.confidence) or 0.9,
                lastSeen = tonumber(v.lastSeen) or now,
                source = v.source or "migrate-v2",
            }
        else
            db.specHintsByGUID[k] = nil
        end
    end

    for k, v in pairs(db.specHintsByName) do
        if type(v) == "string" then
            db.specHintsByName[k] = { spec = v, confidence = 0.9, lastSeen = now, source = "migrate-v2" }
        elseif type(v) == "table" then
            db.specHintsByName[k] = {
                spec = v.spec,
                confidence = tonumber(v.confidence) or 0.9,
                lastSeen = tonumber(v.lastSeen) or now,
                source = v.source or "migrate-v2",
            }
        else
            db.specHintsByName[k] = nil
        end
    end
end

local function MigrateTo3(db)
    if db.defaultDatasetVersion == nil then
        db.defaultDatasetVersion = 1
    end
    if db.minTrackedCooldown == nil then
        db.minTrackedCooldown = 0
    end
    if db.maxTrackedCooldown == nil then
        db.maxTrackedCooldown = 0
    end
end

function IcicleMigration.GetCurrentSchemaVersion()
    return PROFILE_SCHEMA_VERSION
end

function IcicleMigration.ApplyProfileMigrations(db)
    if type(db) ~= "table" then
        return 0
    end

    local startVersion = tonumber(db.profileSchemaVersion) or 0
    local currentVersion = startVersion

    if currentVersion < 1 then
        MigrateTo1(db)
        currentVersion = 1
    end
    if currentVersion < 2 then
        MigrateTo2(db)
        currentVersion = 2
    end
    if currentVersion < 3 then
        MigrateTo3(db)
        currentVersion = 3
    end

    db.profileSchemaVersion = PROFILE_SCHEMA_VERSION
    return startVersion
end
