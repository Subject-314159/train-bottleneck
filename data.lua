data:extend({{
    type = "shortcut",
    name = "tb_shortcut",
    action = "lua",
    icon = {
        filename = "__base__/graphics/icons/rail.png",
        size = 64
    }
}})

data:extend({{
    type = "sprite",
    name = "tb_overlay-straight",
    filename = "__train-bottleneck__/graphics/sprites/straight-rail-horizontal-segment-visualisation-middle.png",
    width = 64,
    height = 128,
    shift = {0, -0.031250}
}, {
    type = "sprite",
    name = "tb_overlay-diagonal",
    filename = "__train-bottleneck__/graphics/sprites/straight-rail-diagonal-left-top-segment-visualisation-middle.png",
    width = 96,
    height = 96,
    shift = {0.5, 0.5}
}, {
    type = "sprite",
    name = "tb_overlay-curved-right",
    filename = "__train-bottleneck__/graphics/sprites/curved-rail-horizontal-left-top-segment-visualisation-middle.png",
    width = 288,
    height = 192,
    shift = {0.4375, 0.406250}
}, {
    type = "sprite",
    name = "tb_overlay-curved-left",
    filename = "__train-bottleneck__/graphics/sprites/curved-rail-horizontal-right-top-segment-visualisation-middle.png",
    width = 288,
    height = 192,
    shift = {-0.4375, 0.406250}
}})

-- data:extend({{
--     type = "sprite",
--     name = "tb_overlay-straight",
--     filename = "__base__/graphics/entity/straight-rail/straight-rail-horizontal-segment-visualisation-middle.png",
--     width = 64,
--     height = 128
-- }, {
--     type = "sprite",
--     name = "tb_overlay-diagonal",
--     filename = "__base__/graphics/entity/straight-rail/straight-rail-diagonal-left-top-segment-visualisation-middle.png",
--     width = 96,
--     height = 96
-- }, {
--     type = "sprite",
--     name = "tb_overlay-curved-right",
--     filename = "__base__/graphics/entity/curved-rail/curved-rail-horizontal-left-top-segment-visualisation-middle.png",
--     width = 288,
--     height = 192
-- }, {
--     type = "sprite",
--     name = "tb_overlay-curved-left",
--     filename = "__base__/graphics/entity/curved-rail/curved-rail-horizontal-right-top-segment-visualisation-middle.png",
--     width = 288,
--     height = 192
-- }})
