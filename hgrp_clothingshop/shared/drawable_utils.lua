local WEAR_COMPONENT = {
    face = 0, mask = 1, hands = 3, jacket = 11, undershirt = 8, pants = 4, shoes = 6, bag = 5, armor = 9, chains = 7,
}

local PROP_SLOT = {
    hat = 0, glasses = 1,
}

DrawableUtils = DrawableUtils or {}

function DrawableUtils.wearComponentId(category)
    return WEAR_COMPONENT[category] or PROP_SLOT[category]
end

function DrawableUtils.isPropCategory(category)
    return PROP_SLOT[category] ~= nil
end

return DrawableUtils
