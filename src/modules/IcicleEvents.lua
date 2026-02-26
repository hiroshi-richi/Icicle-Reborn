IcicleEvents = IcicleEvents or {}

local EventParser = _G.IcicleEventParser

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
        if ctx.UpdateAdvancedSpecEvents then
            ctx.UpdateAdvancedSpecEvents()
        end

        ctx.addon:SetScript("OnUpdate", ctx.OnUpdate)
        if ctx.CommitRefs then
            ctx.CommitRefs()
        end
        ctx.BuildOptionsPanel()

        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if ctx.ResetRuntimeState then
            ctx.ResetRuntimeState()
        end
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
        if not ctx.IsEnabledInCurrentZone() then
            return
        end
        local db = ctx.dbRef and ctx.dbRef.value or nil
        if not (db and db.specDetectEnabled) then
            return
        end
        local unit = ...
        if not unit or unit == "" then return end
        if unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" and not string.match(unit, "^arena%d+$") then
            return
        end
        if not UnitExists(unit) or not UnitCanAttack("player", unit) then
            return
        end
        if ctx.HandleFeignDeathAura then
            ctx.HandleFeignDeathAura(unit)
        end
        local guid = UnitGUID(unit)
        local now = GetTime()
        if guid then
            local last = ctx.STATE.lastSpecAuraCheckByGUID and ctx.STATE.lastSpecAuraCheckByGUID[guid]
            if last and (now - last) < 0.35 then
                return
            end
            ctx.STATE.lastSpecAuraCheckByGUID = ctx.STATE.lastSpecAuraCheckByGUID or {}
            ctx.STATE.lastSpecAuraCheckByGUID[guid] = now
        end
        ctx.SyncSpecContext()
        local changed = ctx.SpecModule.UpdateFromUnitAura(ctx.SPEC_CONTEXT, unit)
        if changed then
            ctx.RefreshAllVisiblePlates()
        end
        return
    end

    if event == "ARENA_OPPONENT_UPDATE" then
        if not ctx.IsEnabledInCurrentZone() then
            return
        end
        local db = ctx.dbRef and ctx.dbRef.value or nil
        if not (db and db.specDetectEnabled) then
            return
        end
        local unit, updateReason = ...
        if not unit or updateReason == "cleared" then
            return
        end
        if not UnitExists(unit) then
            return
        end
        local guid = UnitGUID(unit)
        if guid and ctx.STATE.specByGUID and ctx.STATE.specByGUID[guid] then
            return
        end
        ctx.QueueInspectForUnit(unit)
        return
    end

    if event == "INSPECT_TALENT_READY" then
        if not ctx.IsEnabledInCurrentZone() then
            return
        end
        local db = ctx.dbRef and ctx.dbRef.value or nil
        if not (db and db.specDetectEnabled) then
            return
        end
        local guid = ...
        ctx.HandleInspectTalentReady(guid)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not ctx.IsEnabledInCurrentZone() then return end
        local parsed = EventParser and EventParser.ParseCombatLog and EventParser.ParseCombatLog(...)
        if not parsed or not ALLOWED_COMBATLOG_SUBEVENTS[parsed.subEvent] then
            return
        end

        local sourceGUID = parsed.sourceGUID
        local sourceName = parsed.sourceName
        local sourceFlags = parsed.sourceFlags
        local spellID = parsed.spellID
        local spellName = parsed.spellName
        if not ctx.CombatModule.IsHostileEnemyCaster(sourceFlags) then return end

        local reaction = ctx.CombatModule.GetReactionFromFlags and ctx.CombatModule.GetReactionFromFlags(sourceFlags) or nil
        local normalizedSourceName = ctx.ShortName(sourceName)
        local normalizedSourceGUID = sourceGUID
        if not normalizedSourceName then return end
        if ctx.RequestFastNameplateScan then
            ctx.RequestFastNameplateScan(0.45)
        end

        if ctx.RecordCombatReaction and reaction then
            ctx.RecordCombatReaction(normalizedSourceGUID, normalizedSourceName, reaction)
        end

        ctx.SyncSpecContext()
        local specChanged = ctx.SpecModule.UpdateFromCombatEvent(ctx.SPEC_CONTEXT, spellID, normalizedSourceGUID, normalizedSourceName)
        if specChanged then
            ctx.RefreshAllVisiblePlates()
        end

        ctx.StartCooldown(normalizedSourceGUID, normalizedSourceName, spellID, spellName, parsed.subEvent)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not ctx.IsEnabledInCurrentZone() then return end

        local parsed = EventParser and EventParser.ParseUnitSpellcastSucceeded and EventParser.ParseUnitSpellcastSucceeded(...)
        if not parsed then return end

        local unit = parsed.unit
        local spellName = parsed.spellName
        local spellRank = parsed.spellRank
        local spellID = parsed.spellID
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

        if ctx.RequestFastNameplateScan then
            ctx.RequestFastNameplateScan(0.45)
        end
        ctx.ResolveUnit(unit, 0.97, "unit-cast")
        ctx.StartCooldown(sourceGUID, sourceName, spellID, spellName, "SPELL_CAST_SUCCESS")
    end
end
