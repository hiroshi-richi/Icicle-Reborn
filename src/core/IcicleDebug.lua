IcicleDebug = IcicleDebug or {}

function IcicleDebug.DebugLog(ctx, msg)
    if ctx.db and ctx.db.debug then
        ctx.Print("[debug] " .. tostring(msg))
    end
end

function IcicleDebug.ShowStats(ctx)
    local now = GetTime()
    local uptime = math.max(1, now - ctx.STATE.stats.startTime)
    local scansPerSec = ctx.STATE.stats.scanCount / uptime
    local avgScanMs = ctx.STATE.stats.scanCount > 0 and (ctx.STATE.stats.scanTotalMs / ctx.STATE.stats.scanCount) or 0

    local known = 0
    for _ in pairs(ctx.STATE.knownPlates) do
        known = known + 1
    end

    local mapped = 0
    for _ in pairs(ctx.STATE.plateByGUID) do
        mapped = mapped + 1
    end

    ctx.Print(string.format("scans/s=%.2f avgScanMs=%.3f knownPlates=%d visiblePlates=%d mappings=%d refreshes=%d", scansPerSec, avgScanMs, known, ctx.STATE.visibleCount, mapped, ctx.STATE.stats.refreshCount))
end

function IcicleDebug.PrintConfig(ctx)
    local db = ctx.db
    ctx.Print(string.format("anchor=%s anchorTo=%s x=%d y=%d size=%d font=%d maxRow=%d maxIcons=%d grow=%s spacing=%d scan=%.2f", db.anchorPoint, db.anchorTo, db.xOffset, db.yOffset, db.iconSize, db.fontSize, db.maxIconsPerRow, db.maxIcons, db.growthDirection, db.iconSpacing, db.scanInterval))
end
