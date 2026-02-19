IcicleEvents = IcicleEvents or {}

local ALLOWED_COMBATLOG_SUBEVENTS = {
    SPELL_CAST_SUCCESS = true,
    SPELL_AURA_APPLIED = true,
    SPELL_CAST_START = true,
    SPELL_MISSED = true,
}

function IcicleEvents.HandleEvent(ctx, event, ...)
    if event == "PLAYER_LOGIN" then
        _G.Icicledb = type(_G.Icicledb) == "table" and _G.Icicledb or {}

        if ctx.AceDBLib then
            ctx.aceDBRef.value = ctx.AceDBLib:New("Icicledb", { profile = _G.IcicleDefaults or {} }, "Default")
            ctx.dbRef.value = ctx.aceDBRef.value.profile
            ctx.CopyDefaults(ctx.dbRef.value, _G.IcicleDefaults or {})

            function ctx.profileCallbacks:OnProfileChanged()
                ctx.ProfilesChanged()
            end
            function ctx.profileCallbacks:OnProfileReset()
                ctx.ProfilesChanged()
                if ctx.Print then
                    ctx.Print("Profile was restored.")
                end
            end
            ctx.aceDBRef.value.RegisterCallback(ctx.profileCallbacks, "OnProfileChanged", "OnProfileChanged")
            ctx.aceDBRef.value.RegisterCallback(ctx.profileCallbacks, "OnProfileCopied", "OnProfileChanged")
            ctx.aceDBRef.value.RegisterCallback(ctx.profileCallbacks, "OnProfileReset", "OnProfileReset")
        else
            _G.Icicledb.profile = _G.Icicledb.profile or {}
            ctx.CopyDefaults(_G.Icicledb.profile, _G.IcicleDefaults or {})
            ctx.dbRef.value = _G.Icicledb.profile
        end

        ctx.ConfigModule.NormalizeProfile(ctx.dbRef.value, ctx.baseCooldowns)
        if ctx.EnsureDefaultSpellProfile then
            ctx.EnsureDefaultSpellProfile(ctx.dbRef.value)
        end
        ctx.SyncSpecHintsFromDB()
        ctx.RebuildInternalAPI()

        ctx.addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        ctx.addon:RegisterEvent("PLAYER_ENTERING_WORLD")
        ctx.addon:RegisterEvent("PLAYER_TARGET_CHANGED")
        ctx.addon:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        ctx.addon:RegisterEvent("PLAYER_FOCUS_CHANGED")
        ctx.addon:RegisterEvent("UNIT_TARGET")
        ctx.addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        ctx.addon:RegisterEvent("UNIT_AURA")
        ctx.addon:RegisterEvent("ARENA_OPPONENT_UPDATE")
        ctx.addon:RegisterEvent("INSPECT_TALENT_READY")

        ctx.addon:SetScript("OnUpdate", ctx.OnUpdate)
        if ctx.CommitRefs then
            ctx.CommitRefs()
        end
        ctx.BuildOptionsPanel()

        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        ctx.WipeTable(ctx.STATE.plateByGUID)
        ctx.WipeTable(ctx.STATE.guidByPlate)
        ctx.WipeTable(ctx.STATE.candidatesByName)
        ctx.STATE.pendingBindByGUID = ctx.STATE.pendingBindByGUID or {}
        ctx.WipeTable(ctx.STATE.pendingBindByGUID)
        ctx.WipeTable(ctx.STATE.recentEventByUnit)
        ctx.WipeTable(ctx.STATE.recentUnitSucceededByUnit)
        ctx.WipeTable(ctx.STATE.classByGUID)
        ctx.WipeTable(ctx.STATE.classByName)
        ctx.WipeTable(ctx.STATE.reactionByGUID)
        ctx.WipeTable(ctx.STATE.reactionByName)
        ctx.WipeTable(ctx.STATE.reactionByPlate)
        ctx.WipeTable(ctx.STATE.reactionSourceByGUID)
        ctx.WipeTable(ctx.STATE.reactionSourceByName)
        ctx.WipeTable(ctx.STATE.reactionSourceByPlate)
        ctx.WipeTable(ctx.STATE.inspectUnitByGUID)
        ctx.WipeTable(ctx.STATE.inspectRequestAtByGUID)
        ctx.WipeTable(ctx.STATE.inspectQueue)
        ctx.WipeTable(ctx.STATE.inspectQueuedByGUID)
        ctx.WipeTable(ctx.STATE.inspectOutOfRangeSince)
        ctx.WipeTable(ctx.STATE.inspectOutOfRangeUnits)
        ctx.WipeTable(ctx.STATE.feignDeathAuraByGUID)
        ctx.STATE.inspectCurrent = nil
        ctx.ScanNameplates()
        ctx.RefreshAllVisiblePlates()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        ctx.HandleUnitSignal("target", 0.95, "target")
        return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
        ctx.HandleUnitSignal("mouseover", 0.95, "mouseover")
        return
    end

    if event == "PLAYER_FOCUS_CHANGED" then
        ctx.HandleUnitSignal("focus", 0.95, "focus")
        return
    end

    if event == "UNIT_TARGET" then
        local unitID = ...
        if unitID == "target" or unitID == "focus" or unitID == "mouseover" then
            ctx.HandleUnitSignal(unitID, 0.9, "unit-target")
        else
            local targetUnit = unitID .. "target"
            if UnitExists(targetUnit) then
                ctx.ResolveUnit(targetUnit, 0.8, "group-target")
            end
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if not unit or unit == "" then return end
        if ctx.HandleFeignDeathAura then
            ctx.HandleFeignDeathAura(unit)
        end
        ctx.SyncSpecContext()
        local changed = ctx.SpecModule.UpdateFromUnitAura(ctx.SPEC_CONTEXT, unit)
        if changed then
            ctx.RefreshAllVisiblePlates()
        end
        return
    end

    if event == "ARENA_OPPONENT_UPDATE" then
        local unit, updateReason = ...
        if unit and updateReason ~= "cleared" then
            ctx.QueueInspectForUnit(unit)
        end
        return
    end

    if event == "INSPECT_TALENT_READY" then
        local guid = ...
        ctx.HandleInspectTalentReady(guid)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not ctx.IsEnabledInCurrentZone() then return end
        local subEvent = select(2, ...)
        if not ALLOWED_COMBATLOG_SUBEVENTS[subEvent] then
            return
        end

        local info = ctx.CombatModule.ParseCombatLog(...)
        if not info.spellID or not info.sourceName then return end
        if ctx.RecordCombatReaction and info.sourceReaction then
            ctx.RecordCombatReaction(info.sourceGUID, info.sourceName, info.sourceReaction)
        end
        if not ctx.CombatModule.IsHostileEnemyCaster(info.sourceFlags) then return end

        ctx.SyncSpecContext()
        local specChanged = ctx.SpecModule.UpdateFromCombatEvent(ctx.SPEC_CONTEXT, info.spellID, info.sourceGUID, info.sourceName)
        if specChanged then
            ctx.RefreshAllVisiblePlates()
        end

        ctx.StartCooldown(info.sourceGUID, info.sourceName, info.spellID, info.spellName, info.eventType)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not ctx.IsEnabledInCurrentZone() then return end

        local unit = select(1, ...)
        local a2, a3, a4, a5 = select(2, ...), select(3, ...), select(4, ...), select(5, ...)
        local spellName, spellRank, spellID
        if type(a2) == "string" then
            spellName = a2
            spellRank = type(a3) == "string" and a3 or nil
            if type(a4) == "number" then spellID = a4 end
            if not spellID and type(a5) == "number" then spellID = a5 end
        elseif type(a3) == "string" then
            spellName = a3
            spellRank = type(a4) == "string" and a4 or nil
            if type(a5) == "number" then spellID = a5 end
        end
        if not unit or not spellName or spellName == "" then return end
        if not UnitExists(unit) then return end
        if not UnitCanAttack("player", unit) then return end

        local sourceGUID = UnitGUID(unit)
        local sourceName = ctx.ShortName(UnitName(unit))
        local _, classToken = UnitClass(unit)
        if not sourceGUID or not sourceName then return end

        if not spellID and ctx.ResolveSpellIDByName then
            spellID = ctx.ResolveSpellIDByName(spellName, spellRank, classToken)
        end
        if not spellID then return end
        if ctx.ShouldSuppressUnitCast and ctx.ShouldSuppressUnitCast(sourceGUID or sourceName, spellID) then
            return
        end

        ctx.ResolveUnit(unit, 0.97, "unit-cast")
        ctx.StartCooldown(sourceGUID, sourceName, spellID, spellName, "SPELL_CAST_SUCCESS")
    end
end

