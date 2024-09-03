local model = require("scripts.model")

local view = {}

----------------------------------------------------------------------------------------------------
-- Color helpers
----------------------------------------------------------------------------------------------------

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

---@param factor number Percentage on the scale from 0..1
---@return table {r,g,b}
local get_throughput_color = function(factor)
    -- Factor to hue/saturation
    -- local hue = (160 / 360) * (1 - factor) + (90 / 360) * factor
    local hue = (200 / 360) * (1 - factor) + (100 / 360) * factor
    -- local hue = (120 / 360)
    -- local r, g, b = hsv_to_rgb(hue, (factor / 2) + 0.5, 0.5)

    -- local r, g, b = hsv_to_rgb(hue, (factor / 2) + 0.5, (factor / 2) + 0.5)
    -- local r, g, b = hsv_to_rgb(hue, 1, (factor / 2) + 0.5)
    local r, g, b = hsv_to_rgb(hue, (factor / 2) + 0.5, (factor * 0.25) + 0.75)
    -- return {r, g, b, (factor / 2) + 0.5}
    return {r, g, b}
end

---@param factor integer Percentage on the scale from 0..1
---@return table {r,g,b}
local get_waiting_color = function(factor)
    -- Factor to hue/saturation
    -- local hue = (40 / 360) * (1 - factor)
    local hue = (80 / 360) * (1 - factor)
    local r, g, b = hsv_to_rgb(hue, 1, 1)
    return {r, g, b}
end

local draw_test_render = function(surface_index)
    for i = 1, 255, 1 do
        -- Get some variables
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

        -- Draw saturated scale
        rendering.draw_circle(prop)

        -- Draw old scale
        prop.color = {fac, 1 - fac, 0}
        prop.target = {i / 10, -5.1}
        rendering.draw_circle(prop)

        -- Draw HSV scale
        r, g, b = hsv_to_rgb((120 / 360) - fac * (120 / 360), 1, 1)

        prop.color = {r, g, b}
        prop.target = {i / 10, -5.55}
        rendering.draw_circle(prop)

        -- Draw HSV palette
        for s = 1, 255, 1 do
            r, g, b = hsv_to_rgb(fac, 1, s / 255)

            prop.color = {r, g, b}
            prop.target = {i / 10, -10 - (s / 20)}
            rendering.draw_circle(prop)
        end

        -- Draw new throughput + waiting combined scale
        if fac > 0.5 then
            prop.color = get_waiting_color((fac - 0.5) * 2)
        else
            prop.color = get_throughput_color(fac * 2)
        end
        prop.target = {i / 10, -7}
        rendering.draw_circle(prop)
    end
end

----------------------------------------------------------------------------------------------------
-- Render
----------------------------------------------------------------------------------------------------

local render_throughput = function(player_index, surface_index, data, type)
    -- Early exit if we did not receive proper data
    if not data or not data.measurements or not data.measurements.rails then
        return
    end

    -- Get some variables to work with
    local gs = global.surfaces[surface_index]
    local srf = game.get_surface(surface_index)
    if not srf then
        return
    end

    -- Loop through data
    for id, entry in pairs(data.measurements.rails) do

        -- Calculate throughput and waiting factors
        local fac_tpt = (entry.throughput or 0) / data.max.throughput
        local fac_wtn_sig = (entry.waiting_signal) / (data.max.waiting_signal)
        local fac_wtn_stn = (entry.waiting_station) / (data.max.waiting_station)
        -- fac_wtn_stn = 0

        -- Get the color according to the correct factor
        local color
        if fac_wtn_sig > 0 or fac_wtn_stn > 0 then
            -- Trains have been waiting at this rail
            if fac_wtn_sig > fac_wtn_stn then
                -- We need to get the waiting at signal factor
                color = get_waiting_color(fac_wtn_sig)
            else
                -- We need to get the waiting at station factor
                color = get_waiting_color(fac_wtn_stn)
            end
        else
            -- We need to get the throughput factor
            color = get_throughput_color(fac_tpt)
        end

        -- Loop through all rails in measurement
        local rail = model.get_global_entity(id)
        if rail then
            -- if rail.unit_number == id then
            if rail.prototype.type == "straight-rail" then
                local prop = {
                    tint = color,
                    target = rail.position,
                    surface = srf.index,
                    -- time_to_live = 10 * 60,
                    players = {player_index}
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
                local rid = rendering.draw_sprite(prop)
                model.set_player_overlay_rendering(player_index, rid, id)
            elseif rail.prototype.type == "curved-rail" then
                -- Set baseline prop
                local prop = {
                    tint = color,
                    target = rail.position,
                    surface = srf.index,
                    -- time_to_live = 10 * 60,
                    players = {player_index}
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
                local rid = rendering.draw_sprite(prop)
                model.set_player_overlay_rendering(player_index, rid, id)
            end
        end
    end
end

local render_waiting = function(player_index, surface_index, data)
end

view.render = function(player_index, surface_index, history_minutes, type)
    -- FOR DEBUGGING & TESTING
    -- draw_test_render(surface_index)

    -- Check if the render is requested for an existing global surface
    if not global.surfaces or not global.surfaces[surface_index] then
        return
    end

    local data = model.get_averages(surface_index, history_minutes)

    render_throughput(player_index, surface_index, data, type)

    -- Get player
    local player = game.get_player(player_index)
    if not player then
        return
    end

    -- Toggle the button in the GUI
    local gui = player.gui.left.tb_gui
    if gui then
        gui.header["tb_show-overlay"].toggled = true
    end
end

view.remove_render = function(player_index)
    -- Get global player
    if not global.players or not global.players[player_index] then
        return
    end
    local gp = global.players[player_index]

    -- Remove all renders
    for id, unit_number in pairs(gp.rendering) do
        rendering.destroy(id)
        gp[id] = nil
    end

    -- Get player
    local player = game.get_player(player_index)
    if not player then
        return
    end

    -- Untoggle the button in the GUI
    local gui = player.gui.left.tb_gui
    if gui then
        gui.header["tb_show-overlay"].toggled = false
    end

end

local get_gui = function(player)
    return player.gui.left.tb_gui
end

view.show_gui = function(player)
    -- Main GUI
    local gui = player.gui.left.add({
        type = "frame",
        caption = "Train bottleneck",
        name = 'tb_gui',
        direction = "vertical"
    })

    -- Show overlay button
    local bfl = gui.add({
        type = "flow",
        name = "header"
    })
    bfl.style.vertical_align = "center"
    bfl.add({
        type = "sprite-button",
        name = "tb_show-overlay",
        sprite = "item/locomotive",
        toggled = true
    })
    bfl.add({
        type = "label",
        caption = "Toggle overlay (not auto updating)"
    })

    -- Divider
    gui.add({
        type = "line"
    })
    local lh = gui.add({
        type = "label",
        caption = "Top disturbing signals (experimental)"
    })
    lh.style.font = "heading-2"
    gui.add({
        type = "label",
        caption = "Top 20 signals, ordered by total waiting time in the past 10 minutes"
    })

    -- Signal flow
    local fl = gui.add({
        type = "flow",
        name = "signal-list",
        direction = "vertical"
    })
    if not player.surface then
        game.print("Player not on a surface")
        return
    end
    local data = model.get_averages(player.surface.index, 10)
    local i = 1
    for _, prop in pairs(data.ordered.signals) do
        local entity = model.get_global_entity(prop.id)
        if entity then
            local waiting = prop.waiting_signal or 0
            local sfl = fl.add({
                type = "flow",
                name = "signal-" .. prop.id
            })
            sfl.style.vertical_align = "center"
            local btn = sfl.add({
                type = "sprite-button",
                name = "btn_signal",
                sprite = "item." .. entity.name,
                number = prop.id,
                tags = {
                    id = prop.id,
                    dummy = true
                }
            })
            local pb = sfl.add({
                type = "progressbar",
                name = "bar",
                value = prop.waiting / data.max.waiting_signal
            })
            pb.style.height = 20
            pb.style.bar_width = 20
            local l = sfl.add({
                type = "label",
                name = "duration",
                caption = math.floor(prop.waiting / 60) .. "sec"
            })
            i = i + 1
            if i > 20 then
                break
            end
        end
    end
end

view.close_gui = function(player)
    local gui = get_gui(player)
    if gui then
        gui.destroy()
    end
end

view.toggle_gui = function(player_index)
    local player = game.get_player(player_index)
    if not player then
        return
    end

    if player.gui.left.tb_gui then
        view.close_gui(player)
        view.remove_render(player_index)
    else
        view.show_gui(player)
        view.render(player_index, player.surface.index, 10, "bottleneck")
    end

end
return view
