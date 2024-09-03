local model = require("scripts.model")
local view = require("scripts.view")

local init = function()
    model.init()

    -- Add debug command
    local name = "train_bottleneck_stats"
    if not commands.commands[name] then
        commands.add_command(name, "Prints stats for debugging", function(e)
            -- Get variables
            local player = game.get_player(e.player_index)
            local arr = {}

            -- Loop through surfaces and gather train/rail info
            for _, s in pairs(game.surfaces) do
                local ids = 0
                local first_min
                local last_min
                for id, prop in pairs(global.surfaces[s.index].throughput) do
                    ids = ids + 1
                    for min, _ in pairs(prop.measurements) do
                        first_min = math.min((first_min or min), min)
                        last_min = math.max((last_min or min), min)
                    end
                end
                local prop = {
                    as_identifier = s.name,
                    num_rails = #s.find_entities_filtered({
                        name = {"straight-rail", "curved-rail"}
                    }),
                    num_trains = #s.get_trains(),
                    num_ids = ids,
                    first_min = first_min,
                    last_min = last_min
                }
                table.insert(arr, prop)
            end

            -- Gather global surface data
            game.print(serpent.block(arr))
            log(serpent.block(arr))
        end)
    end
end

script.on_configuration_changed(function()
    init()
end)

script.on_init(function()
    init()
end)

script.on_event({defines.events.on_surface_created, defines.events.on_surface_imported}, function(e)
    -- Call model init to add surface
    model.init()
end)

script.on_event(defines.events.on_tick, function(e)
    model.tick_update()
end)

script.on_event(defines.events.on_lua_shortcut, function(e)
    local player = game.get_player(e.player_index)
    if not player then
        return
    end
    if e.prototype_name == "tb_shortcut-throughput" or e.prototype_name == "tb_shortcut" then
        view.toggle_gui(e.player_index)
    end
end)

script.on_event(defines.events.on_gui_click, function(e)
    -- Get the player
    local player = game.get_player(e.player_index)
    if not player then
        return
    end
    local el = e.element

    -- Check for our button
    local name = el.name
    if name == "tb_show-overlay" then
        if el.toggled then
            view.remove_render(e.player_index)
        else
            view.render(e.player_index, player.surface.index, 10, "bottleneck")
        end
    elseif name == "btn_signal" then
        if el.tags and el.tags.id then
            local ent = model.get_global_entity(el.tags.id)
            player.zoom_to_world(ent.position, 1)
        else
            game.print("Signal with ID " .. el.name .. " not found")
        end
    end

end)
