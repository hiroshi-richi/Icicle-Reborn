IcicleLocale = IcicleLocale or {}

local ENUS = {
    ["general.party"] = "Party",
    ["general.raid"] = "Raid",
    ["general.show_interrupt_when_capped"] = "Prioritize interrupt cooldowns when capped",
    ["general.class_filter"] = "Filter by spell class/category",
    ["general.show_out_of_range_inspect"] = "Show out-of-range inspect warnings",
    ["general.min_cd_filter"] = "Min tracked cooldown (sec)",
    ["general.max_cd_filter"] = "Max tracked cooldown (sec, 0=off)",
    ["general.inspect_retry_interval"] = "Inspect retry interval",
    ["general.inspect_max_retry"] = "Inspect max retry time",
    ["style.highlight_interrupts"] = "Highlight interrupts",
    ["style.border_size"] = "Border thickness",
    ["style.border_inset"] = "Border inset",
    ["testing.export_share"] = "Build Share Code",
    ["testing.import_share"] = "Import Share Code",
    ["testing.share_code"] = "Share Code (compressed)",
    ["testing.share_unavailable"] = "Share-code libraries unavailable (AceSerializer/LibDeflate).",
}

function IcicleLocale.Get(key, fallback)
    if ENUS[key] then
        return ENUS[key]
    end
    return fallback or key
end
