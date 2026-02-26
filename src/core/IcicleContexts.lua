IcicleContexts = IcicleContexts or {}

function IcicleContexts.BuildTrackingContext(env)
    return {
        STATE = env.STATE,
        db = nil,
        spellDedupeWindow = env.spellDedupeWindow,
        GetCooldownRule = env.GetCooldownRule,
        GetSharedCooldownTargets = env.GetSharedCooldownTargets,
        GetSpellConfig = env.GetSpellConfig,
        EventMatchesTrigger = env.EventMatchesTrigger,
        TryBindByName = env.TryBindByName,
        RegisterPendingBind = env.RegisterPendingBind,
        MigrateNameCooldownsToGUID = env.MigrateNameCooldownsToGUID,
        RefreshAllVisiblePlates = env.RefreshAllVisiblePlates,
        RefreshDirtyPlates = env.RefreshDirtyPlates,
        MarkDirtyBySource = env.MarkDirtyBySource,
        RegisterExpiryRecord = env.RegisterExpiryRecord,
        IsItemSpell = env.IsItemSpell,
        GetSpellOrItemInfo = env.GetSpellOrItemInfo,
        SpellCategory = env.SpellCategory,
        GetSourceClassCategory = env.GetSourceClassCategory,
        RequestFastNameplateScan = env.RequestFastNameplateScan,
        scratchRecords = env.scratchRecords,
        scratchSpellInfo = env.scratchSpellInfo,
    }
end

function IcicleContexts.BuildTestModeContext(env)
    return {
        STATE = env.STATE,
        db = nil,
        baseCooldowns = env.baseCooldowns,
        WipeTable = env.WipeTable,
        RefreshAllVisiblePlates = env.RefreshAllVisiblePlates,
        Print = env.Print,
        IsItemSpell = env.IsItemSpell,
        GetSpellOrItemInfo = env.GetSpellOrItemInfo,
        GetSharedCooldownTargets = env.GetSharedCooldownTargets,
        GetCooldownRule = env.GetCooldownRule,
    }
end

function IcicleContexts.BuildSpellsContext(env)
    return {
        db = nil,
        baseCooldowns = env.baseCooldowns,
        DEFAULT_SPELLS_BY_CATEGORY = env.DEFAULT_SPELLS_BY_CATEGORY,
        DEFAULT_SPELL_DATA = env.DEFAULT_SPELL_DATA,
        DEFAULT_ITEM_IDS = env.DEFAULT_ITEM_IDS,
        GetBaseSpellEntry = env.GetBaseSpellEntry,
        GetSpellOrItemInfo = env.GetSpellOrItemInfo,
        GetSpellDescSafe = env.GetSpellDescSafe,
        NormalizeTrigger = env.NormalizeTrigger,
        SpellCategory = env.SpellCategory,
        IsItemSpell = env.IsItemSpell,
    }
end

function IcicleContexts.BuildEventsContext(env)
    return {
        addon = env.addon,
        baseCooldowns = env.baseCooldowns,
        ConfigModule = env.ConfigModule,
        SpecModule = env.SpecModule,
        CombatModule = env.CombatModule,
        AceDBLib = env.AceDBLib,
        CopyDefaults = env.CopyDefaults,
        profileCallbacks = env.profileCallbacks,
        ProfilesChanged = env.ProfilesChanged,
        EnsureDefaultSpellProfile = env.EnsureDefaultSpellProfile,
        SyncSpecHintsFromDB = env.SyncSpecHintsFromDB,
        RebuildInternalAPI = env.RebuildInternalAPI,
        STATE = env.STATE,
        WipeTable = env.WipeTable,
        ScanNameplates = env.ScanNameplates,
        RefreshAllVisiblePlates = env.RefreshAllVisiblePlates,
        HandleUnitSignal = env.HandleUnitSignal,
        HandleFeignDeathAura = env.HandleFeignDeathAura,
        ShouldSuppressUnitCast = env.ShouldSuppressUnitCast,
        QueueInspectForUnit = env.QueueInspectForUnit,
        HandleInspectTalentReady = env.HandleInspectTalentReady,
        ShortName = env.ShortName,
        ResolveSpellIDByName = env.ResolveSpellIDByName,
        ResolveUnit = env.ResolveUnit,
        IsEnabledInCurrentZone = env.IsEnabledInCurrentZone,
        SyncSpecContext = env.SyncSpecContext,
        SPEC_CONTEXT = env.SPEC_CONTEXT,
        COOLDOWN_RULES_CONTEXT = env.COOLDOWN_RULES_CONTEXT,
        UpdateAdvancedSpecEvents = env.UpdateAdvancedSpecEvents,
        RecordCombatReaction = env.RecordCombatReaction,
        StartCooldown = env.StartCooldown,
        RequestFastNameplateScan = env.RequestFastNameplateScan,
        OnUpdate = env.OnUpdate,
        BuildOptionsPanel = env.BuildOptionsPanel,
        ResetRuntimeState = env.ResetRuntimeState,
        Print = env.Print,
        aceDBRef = { value = nil },
        dbRef = { value = nil },
    }
end
