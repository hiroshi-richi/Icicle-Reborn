IcicleConstants = IcicleConstants or {}

IcicleConstants.VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

IcicleConstants.VALID_GROW = { RIGHT = true, LEFT = true, UP = true, DOWN = true }

IcicleConstants.POINT_VALUES = {
    TOPLEFT = "TOPLEFT", TOP = "TOP", TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT", CENTER = "CENTER", RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT", BOTTOM = "BOTTOM", BOTTOMRIGHT = "BOTTOMRIGHT",
}

IcicleConstants.GROW_VALUES = { RIGHT = "RIGHT", LEFT = "LEFT", UP = "UP", DOWN = "DOWN" }

IcicleConstants.SPELL_DEDUPE_WINDOW = {
    [53007] = 2.2, -- Penance
    [61384] = 2.2, -- Typhoon
}

IcicleConstants.CATEGORY_BORDER_DEFAULTS = {
    GENERAL = { r = 0.502, g = 0.502, b = 0.502, a = 1.00 },
    WARRIOR = { r = 0.780, g = 0.612, b = 0.431, a = 1.00 },
    PALADIN = { r = 0.961, g = 0.549, b = 0.729, a = 1.00 },
    HUNTER = { r = 0.671, g = 0.831, b = 0.451, a = 1.00 },
    ROGUE = { r = 1.000, g = 0.961, b = 0.412, a = 1.00 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00, a = 1.00 },
    DEATH_KNIGHT = { r = 0.769, g = 0.122, b = 0.231, a = 1.00 },
    SHAMAN = { r = 0.000, g = 0.439, b = 0.871, a = 1.00 },
    MAGE = { r = 0.247, g = 0.780, b = 0.922, a = 1.00 },
    WARLOCK = { r = 0.529, g = 0.533, b = 0.933, a = 1.00 },
    DRUID = { r = 1.000, g = 0.490, b = 0.039, a = 1.00 },
}
