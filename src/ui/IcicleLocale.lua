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
}

function IcicleLocale.Get(key, defaultValue)
    if ENUS[key] then
        return ENUS[key]
    end
    return defaultValue or key
end
