IcicleOptions = IcicleOptions or {}

function IcicleOptions.RegisterPanels(ctx)
    local AceConfig = ctx.AceConfig
    local AceConfigDialog = ctx.AceConfigDialog
    local AceDBOptions = ctx.AceDBOptions
    local aceDB = ctx.aceDB

    AceConfig:RegisterOptionsTable("Icicle", ctx.root)
    AceConfigDialog:AddToBlizOptions("Icicle", "Icicle: Reborn")

    AceConfig:RegisterOptionsTable("IcicleGeneral", ctx.general)
    AceConfigDialog:AddToBlizOptions("IcicleGeneral", "General", "Icicle: Reborn")

    AceConfig:RegisterOptionsTable("IcicleStyle", ctx.style)
    AceConfigDialog:AddToBlizOptions("IcicleStyle", "Style settings", "Icicle: Reborn")

    AceConfig:RegisterOptionsTable("IciclePosition", ctx.position)
    AceConfigDialog:AddToBlizOptions("IciclePosition", "Position settings", "Icicle: Reborn")

    AceConfig:RegisterOptionsTable("IcicleSpells", ctx.spells)
    AceConfigDialog:AddToBlizOptions("IcicleSpells", "Tracked Spells", "Icicle: Reborn")

    if AceDBOptions and aceDB then
        local profileOptions = AceDBOptions:GetOptionsTable(aceDB)
        AceConfig:RegisterOptionsTable("IcicleProfiles", profileOptions)
        AceConfigDialog:AddToBlizOptions("IcicleProfiles", "Profiles", "Icicle: Reborn")
    end

end

function IcicleOptions.OpenPanel(panelName)
    InterfaceOptionsFrame_OpenToCategory(panelName)
    InterfaceOptionsFrame_OpenToCategory(panelName)
end
