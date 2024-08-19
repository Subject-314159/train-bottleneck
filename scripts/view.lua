local model = require("scripts.model")

local view = {}

local hsv_to_rgb = function(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return r, g, b
end

local draw_test_render = function(surface_index)
    for i = 1, 255, 1 do
        local fac = i / 255
        local r, g, b
        if fac > 0.5 then
            r = 1
            g = (1 - fac) * 2
        else
            r = fac * 2
            g = 1
        end
        local prop = {
            color = {r, g, 0},
            radius = 0.25,
            filled = true,
            target = {i / 10, -6},
            surface = surface_index,
            time_to_live = 10 * 60
        }
        rendering.draw_circle(prop)

        prop.color = {fac, 1 - fac, 0}
        prop.target = {i / 10, -5.1}
        rendering.draw_circle(prop)

        r, g, b = hsv_to_rgb((120 / 360) - fac * (120 / 360), 1, 1)

        prop.color = {r, g, b}
        prop.target = {i / 10, -5.55}
        rendering.draw_circle(prop)

        for s = 1, 255, 1 do
            r, g, b = hsv_to_rgb(fac, 1, s / 255)

            prop.color = {r, g, b}
            prop.target = {i / 10, -7 - (s / 20)}
            rendering.draw_circle(prop)
        end
    end
end

local render_throughput = function(player_index, surface_index, data)

    -- Get some variables to work with
    local gs = global.surfaces[surface_index]
    local srf = game.get_surface(surface_index)
    if not srf then
        return
    end

    -- Loop through data
    for id, entry in pairs(data.entries) do

        -- Calculate red and green fraction
        -- TODO: Convert to HSL->RGB for better color gradient?
        local fac = entry.total / data.max
        local r = math.min(fac * 2, 1)
        local g = math.min((1 - fac) * 2, 1)

        -- Get all rails on this position
        local str = srf.find_entities_filtered({
            position = entry.pos,
            name = "straight-rail"
        })
        for _, rail in pairs(str) do
            if rail.unit_number == id then
                local prop = {
                    tint = {r, g, 0},
                    target = entry.pos,
                    surface = srf.index,
                    time_to_live = 10 * 60
                }
                if rail.direction == defines.direction.north or rail.direction == defines.direction.south then
                    -- Set correct sprite
                    prop.sprite = "tb_overlay-straight"
                    -- Rotate by 90 degree
                    prop.orientation = 0.25
                elseif rail.direction == defines.direction.east or rail.direction == defines.direction.west then
                    -- Set correct sprite
                    prop.sprite = "tb_overlay-straight"
                else
                    -- Set correct sprite
                    prop.sprite = "tb_overlay-diagonal"
                    -- Rotate by the orientation
                    prop.orientation = ((rail.direction - 1) / 8) + 0.25
                end
                -- Draw the sprite
                rendering.draw_sprite(prop)
            end
        end

        local cur = srf.find_entities_filtered({
            position = entry.pos,
            name = "curved-rail"
        })
        for _, rail in pairs(cur) do
            if rail.unit_number == id then
                -- Set baseline prop
                local prop = {
                    tint = {r, g, 0},
                    target = entry.pos,
                    surface = srf.index,
                    time_to_live = 10 * 60
                }

                -- Correct orientation
                if (rail.direction % 2) == 0 then
                    prop.sprite = "tb_overlay-curved-right"
                    prop.orientation = ((rail.direction) / 8) - 0.25

                else
                    prop.sprite = "tb_overlay-curved-left"
                    prop.orientation = ((rail.direction - 1) / 8) + 0.25
                end

                -- Draw segment
                rendering.draw_sprite(prop)
            end
        end
    end
end

local render_waiting = function(player_index, surface_index, data)
end

view.render = function(player_index, surface_index, history_minutes, type)
    -- TMP
    -- draw_test_render(surface_index)

    -- Check if the render is requested for an existing global surface
    if not global.surfaces or not global.surfaces[surface_index] then
        return
    end

    -- Get some variables to work with
    local minute = math.floor(game.tick / 3600)
    local first_minute = math.max(minute - history_minutes, 0)

    local data = model.get_averages(type, surface_index, first_minute)

    if type == "throughput" then
        render_throughput(player_index, surface_index, data)
    elseif type == "waiting" then
        render_waiting(player_index, surface_index, data)
    end
end

return view
