local model = {}

local get_minute = function()
    return math.floor(game.tick / 3600)
end

local get_indexed_array = function(array)
    if array then
        local data = {}
        for _, id in pairs(array) do
            data[id] = true
        end
        return data
    else
        return nil
    end
end

local get_indexed_filter = function(filter)
    -- Process filter if any
    if filter then
        return {
            trains = get_indexed_array(filter.trains or nil),
            signals = get_indexed_array(filter.signals or nil),
            stations = get_indexed_array(filter.signals or nil),
            rails = get_indexed_array(filter.rails or nil)
        }
    end

    -- Fallback
    return {}

    -- Backup
    -- -- Init array
    -- local fltr = {}

    -- -- Only if a filter argument is passed
    -- if filter then
    --     -- Trains filter
    --     if filter.trains then
    --         fltr.trains = get_indexed_array(filter.trains)
    --     end

    --     -- Signals filter
    --     if filter.signals then
    --         fltr.signals = get_indexed_array(filter.signals)
    --     end

    --     -- Stations filter
    --     if filter.stations then
    --         fltr.stations = get_indexed_array(filter.signals)
    --     end

    --     -- Rails filter
    --     if filter.rails then
    --         fltr.rails = get_indexed_array(filter.rails)
    --     end
    -- end

    -- -- Return the array
    -- return fltr
end

local update_throughput = function(gt, data, filter)
    -- Early exit if this train does not have any rail data yet
    if not gt or not gt.rails then
        return
    end

    -- Loop through rails for throughput
    for id, prop in pairs(gt.rails) do
        -- Make sure the rail entity is included in the filter (or no rail filter is given)
        if not filter.rails or filter.rails[id] then
            -- Get data measurement rail id entry
            if not data.measurements.rails[id] then
                data.measurements.rails[id] = {
                    pos = prop.pos,
                    throughput = 0,
                    traveling = 0,
                    error = 0,
                    waiting_signal = 0,
                    waiting_station = 0
                }
            end
            local dmr = data.measurements.rails[id]

            -- Sum throughput for this rail entity
            if prop.throughput then
                for min, count in pairs(prop.throughput) do
                    dmr.throughput = (dmr.throughput or 0) + (count or 0)
                end
            end

            -- Sum traveling for this rail entry
            if prop.traveling then
                for min, tick in pairs(prop.traveling) do
                    dmr.traveling = (dmr.traveling or 0) + (tick or 0)
                end
            end

            -- Sum error for this rail entity
            if prop.error then
                for min, tick in pairs(prop.error) do
                    dmr.error = (dmr.error or 0) + (tick or 0)
                end
            end
        end
    end
end
local update_waiting_signal = function(gtm, data, filter)
end
local update_waiting_station = function(gtm, data, filter)
end

model.get_averages = function(surface_index, history_minutes, filter)
    -- Get surface
    local gs = global.surfaces[surface_index]
    if not gs then
        return
    end

    -- Get current minute and earliest minute
    local current_minute = get_minute()
    local first_minute = math.max(current_minute - history_minutes, 0) -- Do not start before game minute 0

    local fltr = get_indexed_filter(filter)

    -- Construct return data
    local data = {
        measurements = {
            rails = {},
            signals = {},
            stations = {}
        },
        max = {
            throughput = 0,
            traveling = 0,
            waiting_signal = 0,
            waiting_station = 0
        }
    }

    -- Loop through global trains
    for id, gt in pairs(gs.trains) do
        -- Only if the train is filtered (or no train filter passed)
        if not fltr.trains or fltr.trains[id] then
            update_throughput(gt, data, fltr)
        end
    end

    -- Calculate max
    for id, prop in pairs(data.measurements.rails) do
        data.max.throughput = math.max(data.max.throughput or 0, prop.throughput or 0)
        data.max.traveling = math.max(data.max.traveling or 0, prop.traveling or 0)
        data.max.waiting_signal = math.max(data.max.waiting_signal or 0, prop.waiting_signal or 0)
        data.max.waiting_station = math.max(data.max.waiting_station or 0, prop.waiting_station or 0)
    end

    return data

end

-- returns {
--     measurements = {
--         rails = {
--             [rail_id] = {
--                 throughput = count,
--                 traveling = ticks,
--                 waiting_signal = ticks,
--                 waiting_station = ticks,
--                 pos = {x,y},
--             },
--             [rail_id .. n] = {...}
--         },
--         signals = {
--             [signal_id] = ticks,
--             [signal_id .. n] = ticks
--         },
--         stations = {
--             [station_id] = ticks,
--             [station_id .. n] = ticks
--         }
--     },
--     max = {
--         throughput = count,
--         traveling = ticks,
--         waiting_signal = ticks,
--         waiting_station = ticks
--     }
-- }

----------------------------------------------------------------------------------------------------
-- Update train global data
----------------------------------------------------------------------------------------------------

local warn_invalid = function(train)
    -- Save
    game.auto_save()

    -- Log
    log('Include all data between DEBUG START and DEBUG END in the bug report')
    log('===== DEBUG START =====')
    log('Error on train id: ' .. train.id)
    -- log('global')
    -- log(serpent.block(global))
    log(debug.traceback())
    log('===== DEBUG END =====')

    -- Inform user
    game.print("Weird... We ran into an issue while processing train " .. train.id .. " which should not have happened")
    game.print("An auto save has been generated and detailed information is available in the log")
    game.print("please report to mod author and include all relevant data for further analysis")

end

local get_rail = function(train, gt)

    local rail = train.front_rail
    if not rail then
        warn_invalid(train)
        return
    end

    -- Get rail entry
    if not gt.rails then
        gt.rails = {}
    end
    if not gt.rails[rail.unit_number] then
        gt.rails[rail.unit_number] = {
            pos = rail.position,
            entity = rail
        }
    end
    local gtr = gt.rails[rail.unit_number]

    return rail, gtr
end

local process_train_throughput = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local rail, gtr = get_rail(train, gt)
    if not rail or not gtr then
        return
    end

    -- Update throughput count if on new rail
    if not gt.last_rail or (gt.last_rail ~= rail.unit_number) then
        -- Update count in global train
        if not gtr.throughput then
            gtr.throughput = {}
        end
        gtr.throughput[minute] = (gtr.throughput[minute] or 0) + 1

        -- Update last rail
        gt.last_rail = rail.unit_number
    end
end

local process_train_traveling = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local rail, gtr = get_rail(train, gt)
    if not rail or not gtr then
        return
    end

    -- Update traveling ticks
    if not gtr.traveling then
        gtr.traveling = {}
    end
    gtr.traveling[minute] = (gtr.traveling[minute] or 0) + 1
end

local process_train_waiting_signal = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local signal = train.signal
    if not signal then
        warn_invalid(train)
        return
    end

    -- Get signal entry
    if not gt.signals then
        gt.signals = {}
    end
    if not gt.signals[signal.unit_number] then
        gt.signals[signal.unit_number] = {
            pos = signal.position,
            entity = signal,
            waiting = {}
        }
    end

    -- Update waiting at signal
    local gts = gt.signals[signal.unit_number]
    gts.waiting[minute] = (gts.waiting[minute] or 0) + 1
end

local process_train_waiting_station = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local station = train.station
    if not station then
        warn_invalid(train)
        return
    end

    -- Get station entry
    if not gt.stations then
        gt.stations = {}
    end
    if not gt.stations[station.unit_number] then
        gt.stations[station.unit_number] = {
            pos = station.position,
            entity = station,
            waiting = {}
        }
    end

    -- Update waiting at station
    local gts = gt.stations[station.unit_number]
    gts.waiting[minute] = (gts.waiting[minute] or 0) + 1
end

local process_train_waiting_other = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local rail, gtr = get_rail(train, gt)
    if not rail or not gtr then
        return
    end

    -- Update waiting in error state (any)
    if not gtr.error then
        gtr.error = {}
    end
    gtr.error[minute] = (gtr.error[minute] or 0) + 1

end

local update_trains_on_surface = function(surface_index)
    -- Get global surface
    local gs = global.surfaces[surface_index]

    -- Loop through trains on surface
    for _, train in pairs(game.surfaces[surface_index].get_trains()) do
        if train then
            -- Get global train
            if not gs.trains[train.id] then
                gs.trains[train.id] = {}
            end
            local gt = gs.trains[train.id]

            -- Always update unique count throughput based on previous track id
            process_train_throughput(train, gt)

            -- CONTAINMENT: Always measure train traveling time (even if it means it is stopped)
            -- Because we don't have a proper translation from signal/station waiting to rail entity_id
            -- To determine; Should we always do this here and add rails.waiting_signal and rails.waiting_station
            process_train_traveling(train, gt)

            -- Update data based on train state
            if train.state == defines.train_state.on_the_path or train.state == defines.train_state.arrive_station then
                -- Train is traveling
                -- process_train_traveling(train, gt)
                -- TO DETERMINE:
                -- When arriving at station (breaking) there is no train.station yet, so we can't measure duration at that station entity
                -- Therefore we process this breaking as 'on route', should we do the same for breaking for a signal? For now: No
            elseif train.state == defines.train_state.arrive_signal or train.state == defines.train_state.wait_signal then
                -- Train is waiting at signal
                process_train_waiting_signal(train, gt)
            elseif train.state == defines.train_state.wait_station then
                -- Train is waiting at station
                process_train_waiting_station(train, gt)
            elseif train.state == defines.train_state.path_lost or train.state == defines.train_state.no_schedule or
                train.state == defines.train_state.no_path or train.state == defines.train_state.destination_full then
                -- Train is waiting for some other reason
                process_train_waiting_other(train, gt)
            end
        end
    end
end

model.tick_update = function()
    -- Loop through global surfaces
    for id, gs in pairs(global.surfaces) do
        local srf = game.get_surface(id)
        if srf then
            -- Process the surface
            update_trains_on_surface(id)
        else
            -- Surface no longer exists, we can remove it
            global.surfaces[id] = nil
        end
    end
end

model.init = function()
    -- Init global surfaces
    if not global.surfaces then
        global.surfaces = {}
    end

    -- Init each surface in global surfaces
    for _, s in pairs(game.surfaces) do
        if not global.surfaces[s.index] then
            global.surfaces[s.index] = {}
        end
        local gs = global.surfaces[s.index]
        if not gs.trains then
            gs.trains = {}
        end

        -- TO BE IMPLEMENTED
        -- if not gs.overlay then
        --     gs.overlay = {}
        -- end
    end
end

-- Global data model
-- global = {
--     surfaces = {
--         [surface_id] = {
--             trains = {
--                 [train_id] = {
--                     last_rail = entity_id, -- Unit number of the track this train was in previous tick
--                     rails = {
--                         [rail_entity_id] = {
--                             position = {x, y},
--                             entity = entity,
--                             throughput = {
--                                 [minute] = count,
--                                 [minute .. n] = count
--                             },
--                             traveling = {
--                                 [minute] = tick,
--                                 [minute .. n] = tick
--                             },
--                             error = {
--                                 [minute] = tick,
--                                 [minute .. n] = tick
--                             }
--                         },
--                         [rail_entity_id .. n] = {...}
--                     },
--                     signals = {
--                         [signal_entity_id] = {
--                             position = {x, y},
--                             entity = entity,
--                             waiting = {
--                                 [minute] = tick,
--                                 [minute .. n] = tick
--                             }
--                         },
--                         [signal_entity_id .. n] = {...}
--                     },
--                     stations = {
--                         [station_entity_id] = {
--                             position = {x, y},
--                             entity = entity,
--                             waiting = {
--                                 [minute] = tick,
--                                 [minute .. n] = tick
--                             }
--                         },
--                         [station_entity_id .. n] = {...}
--                     }
--                 },
--                 [train_id .. n] = {...}
--             },
--             overlay = { -- TO BE IMPLEMENTED
--                 [entity_id] = render_id
--             }
--         },
--         [surface_id .. n] = {...}
--     }
-- }

return model
