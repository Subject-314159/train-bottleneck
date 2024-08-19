local model = {}

local init_global_surface = function(surface)
    -- Get global surface
    if not global.surfaces then
        global.surfaces = {}
    end
    if not global.surfaces[surface.index] then
        global.surfaces[surface.index] = {}
    end
    local gs = global.surfaces[surface.index]
    if not gs.trains then
        gs.trains = {}
    end
    if not gs.throughput then
        gs.throughput = {}
    end
    if not gs.waiting then
        gs.waiting = {}
    end
end

local get_average = function(glob, threshold_minute)
    -- Get variables
    local arr = {
        max = 0,
        entries = {}
    }

    -- Loop through positions
    for id, prop in pairs(glob) do
        -- Get total over measurements within threshold
        local tot = 0
        for min, cnt in pairs(prop.measurements) do
            if min >= threshold_minute then
                tot = tot + cnt
            end
        end

        -- Add result to array
        arr.entries[id] = {
            pos = prop.pos,
            total = tot
        }

        -- Update max
        arr.max = math.max(arr.max, tot)
    end

    -- Return the array and max
    return arr
end

model.get_averages = function(type, surface_index, threshold_minute)
    -- Get global pointer
    local glob
    if type == "throughput" then
        glob = global.surfaces[surface_index].throughput
    elseif type == "waiting" then
        glob = global.surfaces[surface_index].waiting
    end

    -- Return the average of that pointer
    if glob then
        return get_average(glob, threshold_minute)
    end
end

model.tick_update = function()
    -- Get current minute
    local minute = math.floor(game.tick / 3600)

    for _, srf in pairs(game.surfaces) do
        -- Get global surface
        init_global_surface(srf)
        local gs = global.surfaces[srf.index]

        -- Get trains on this surface
        local trains = srf.get_trains()
        for _, t in pairs(trains) do

            -- Throughput measurement
            local r = t.front_rail
            if r then
                -- Get global train
                if not gs.trains[t.id] then
                    gs.trains[t.id] = {}
                end
                local gt = gs.trains[t.id]

                -- Only if the train is on a new rail entity
                if not gt.last_rail or (gt.last_rail and gt.last_rail ~= r.unit_number) then
                    -- Create global entry
                    -- local id = "x" .. r.position.x .. "_y" .. r.position.y
                    local id = r.unit_number or 0
                    if not gs.throughput[id] then
                        gs.throughput[id] = {}
                    end
                    local tpt = gs.throughput[id]

                    if not tpt.measurements then
                        tpt.measurements = {}
                    end

                    -- Increase counter
                    tpt.measurements[minute] = (tpt.measurements[minute] or 0) + 1

                    -- Store position
                    if not tpt.pos then
                        tpt.pos = r.position
                    end

                    -- Store the rail entity the train is currently at
                    gt.last_rail = r.unit_number
                end
            end

            -- Waiting measurement
            if t.state == defines.train_state.wait_signal and t.signal then
                -- Get global waiting
                local id = t.signal.unit_number or 0
                if not gs.waiting[id] then
                    gs.waiting[id] = {}
                end
                local wait = gs.waiting[id]
                if not wait.measurements then
                    wait.measurements = {}
                end

                -- Increase counter
                wait.measurements[minute] = (wait.measurements[minute] or 0) + 1

                -- Store position
                if not wait.pos then
                    wait.pos = t.signal.position
                end
            end
        end
    end
end

model.init = function()
    -- global.surfaces[index] = {
    --     trains = {
    --         [id] = {previous_position}
    --     },
    --     throughput = {
    --         [id] = {
    --             position = {x, y},
    --             measurements = {
    --                 [minute] = 1
    --             }
    --         }
    --     },
    --     waiting = {
    --         [id] = {
    --             position = {x, y},
    --             measurements = {
    --                 [minute] = 1
    --             }
    --         }
    --     }
    -- }
end

return model
