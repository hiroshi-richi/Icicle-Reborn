IcicleBootstrap = IcicleBootstrap or {}

function IcicleBootstrap.BuildInternalAPI(ctx)
    return {
        GetDB = ctx.GetDB,
        GetState = function() return ctx.STATE end,
        StartCooldown = ctx.StartCooldown,
        ResetAllCooldowns = ctx.ResetAllCooldowns,
        RefreshAllVisiblePlates = ctx.RefreshAllVisiblePlates,
        ResolveUnit = ctx.ResolveUnit,
        ResolveGroupTargets = ctx.ResolveGroupTargets,
        ScanNameplates = ctx.ScanNameplates,
        GetCooldownRule = ctx.GetCooldownRule or ctx.GetSpellConfig,
        GetSpellConfig = ctx.GetSpellConfig,
        DebugSpellRule = ctx.DebugSpellRule,
        BuildSpellRowsData = ctx.BuildSpellRowsData,
        NotifySpellsChanged = ctx.NotifySpellsChanged,
    }
end
