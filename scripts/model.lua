local model = {}

local get_minute = function()
    return math.floor(game.tick / 3600)
end

model.get_global_player = function(player_index)
    if not global.players then
        global.players = {}
    end
    if not global.players[player_index] then
        global.players[player_index] = {}
    end
    local gp = global.players[player_index]
    return gp
end

local set_global_entity = function(unit_number, entity)
    if not global.entities then
        global.entities = {}
    end
    if not entity or not entity.valid then
        return
    end
    if not global.entities[unit_number] then
        global.entities[unit_number] = entity
    end
end

model.get_global_entity = function(unit_number)
    if not global.entities then
        return
    end
    local entity = global.entities[unit_number]
    if entity and entity.valid then
        return entity
    else
        global.entities[unit_number] = nil
    end
end

model.set_player_overlay_rendering = function(player_index, render_id, unit_number)
    local gp = model.get_global_player(player_index)
    if not gp then
        return
    end
    if not gp.rendering then
        gp.rendering = {}
    end
    gp.rendering[render_id] = unit_number
end

model.get_player_is_rendered = function(player_index)
    if not global.players or not global.players[player_index] then
        -- If global player is not set up then return false
        return false
    end
    local gp = global.players[player_index]
    for k, v in pairs(gp.rendering) do
        -- We get here if there is at least one entry
        return true
    end

    -- Fallback return fale
    return false
end

model.get_player_all_renders = function(player_index)
    if not global.players or not global.players[player_index] then
        -- If global player is not set up then return false
        return {}
    end
    local gp = global.players[player_index]
    return gp.rendering or {}
end

local get_indexed_array = function(array)
    if array then
        lodata = {}
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
    for rid, prop in pairs(gt.rails) do
        -- Make sure the rail entity is included in the filter (or no rail filter is given)
        if not filter.rails or filter.rails[rid] then
            -- Get data measurement rail id entry
            if not data.measurements.rails[rid] then
                data.measurements.rails[rid] = {
                    pos = prop.pos,
                    throughput = 0,
                    traveling = 0,
                    error = 0,
                    waiting_signal = 0,
                    waiting_station = 0
                }
            end
            local dmr = data.measurements.rails[rid]

            -- Sum throughput for this rail entity
            if prop.throughput then
                for min, count in pairs(prop.throughput) do
                    if min >= filter.first_minute and min <= filter.last_minute then
                        dmr.throughput = (dmr.throughput or 0) + (count or 0)
                    end
                end
            end

            -- Sum traveling for this rail entry
            if prop.traveling then
                for min, tick in pairs(prop.traveling) do
                    if min >= filter.first_minute and min <= filter.last_minute then
                        dmr.traveling = (dmr.traveling or 0) + (tick or 0)
                    end
                end
            end

            -- Sum error for this rail entity
            if prop.error then
                for min, tick in pairs(prop.error) do
                    if min >= filter.first_minute and min <= filter.last_minute then
                        dmr.error = (dmr.error or 0) + (tick or 0)
                    end
                end
            end
        end
    end
end
local get_rail_in_block_recursive
get_rail_in_block_recursive = function(rail, rib)
    -- Early exit if rail is not rail
    -- local prot = game.entity_prototypes[rail.name]
    -- if prot and prot.type and (prot.type ~= "straight-rail" and prot.type ~= "curved-rail") then
    --     return
    -- end

    -- Get rail segment ends
    local rse = {}
    for _, dir in pairs {defines.rail_direction.front, defines.rail_direction.back} do

        -- Get the segment end
        local seg = rail.get_rail_segment_end(dir)

        if seg then
            rse[seg.unit_number] = seg
        end
    end

    for id, r in pairs(rse) do
        -- Check front/back for station
        local has_station = false
        for _, dir in pairs {defines.rail_direction.front, defines.rail_direction.back} do

            local grse = r.get_rail_segment_entity(dir, true)
            if grse and game.entity_prototypes[grse.name].type == "train-stop" and grse.connected_rail and
                grse.connected_rail == r then
                has_station = true
            end
        end

        -- Check if segment is interrupted by a station
        if not has_station then
            -- Look further
            for _, dir in pairs {defines.rail_direction.front, defines.rail_direction.back} do

                for _, condir in pairs({defines.rail_connection_direction.left,
                                        defines.rail_connection_direction.straight,
                                        defines.rail_connection_direction.right}) do
                    -- Get connected rail
                    local gcr = r.get_connected_rail {
                        rail_direction = dir,
                        rail_connection_direction = condir
                    }

                    if gcr then

                        -- Check if connected rail has station that is not in our segment
                        local segment_valid = true
                        for _, cdir in pairs {defines.rail_direction.front, defines.rail_direction.back} do
                            -- Check if we have a station at the connected rail
                            local grse = gcr.get_rail_segment_entity(cdir, true)
                            if grse and game.entity_prototypes[grse.name].type == "train-stop" and
                                not grse.connected_rail.is_rail_in_same_rail_segment_as(r) then
                                segment_valid = false
                            end
                        end

                        -- Check if the connected rail is in the same block and in a valid segment (i.e. not interrupted by station)
                        if gcr.is_rail_in_same_rail_block_as(r) and segment_valid then
                            -- Check if this rail has a station

                            -- Check if this rail is already in our array
                            if not rib[gcr.unit_number] then
                                -- e this rail
                                rib[gcr.unit_number] = gcr
                                set_global_entity(gcr.unit_number, gcr)
                                -- Dig deeper
                                get_rail_in_block_recursive(gcr, rib)
                            end

                        end
                    end
                end

                -- Get & store all rails in current segment
                for _, seg in pairs(rail.get_rail_segment_rails(dir)) do
                    -- Safe add to our array
                    if not rib[seg.unit_number] then
                        rib[seg.unit_number] = seg
                        set_global_entity(seg.unit_number, seg)
                    end
                end
            end

        end
    end

end

local get_signal_rails_in_block = function(signal)
    -- Make array of rails in block
    local ris = {}

    -- Loop through all connected rails (orphan signals will return nil)
    for _, r in pairs(signal.get_connected_rails()) do
        if r and r.valid then
            -- First check if we have an inbound or outbound signal
            local is_outbound = false
            for _, s in pairs(r.get_outbound_signals()) do
                -- If we found our signal in the outbound signals of this rail then the rail is in the correct block
                if s.unit_number == signal.unit_number then
                    is_outbound = true
                end
            end

            -- Get correct rail piece
            local rails_corrected = {}
            if is_outbound then
                -- Safe add to our array because it can be that we meet this rail multiple times
                if not ris[r.unit_number] then
                    ris[r.unit_number] = r
                end
            else
                -- The signal is connected to the wrong side of the rail block
                -- Loop through directions required for get_connected_rail
                for _, dir in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
                    for _, condir in pairs({defines.rail_connection_direction.left,
                                            defines.rail_connection_direction.straight,
                                            defines.rail_connection_direction.right}) do
                        -- Get the connected rail
                        local gcr = r.get_connected_rail {
                            rail_direction = dir,
                            rail_connection_direction = condir
                        }
                        if gcr then
                            -- Check for this new connected rail if this block contains our signal as outbound signal
                            local is_outbound_chain = false
                            for _, s in pairs(gcr.get_outbound_signals()) do
                                -- If we found our signal in the outbound signals of this rail then the rail is in the correct block
                                if s.unit_number == signal.unit_number then
                                    is_outbound_chain = true
                                end
                            end

                            if is_outbound_chain then
                                -- Ladies and gentlemen, we've got 'em!
                                -- Safe add to our array because it can be that we meet this rail multiple times
                                if not ris[gcr.unit_number] then
                                    ris[gcr.unit_number] = gcr
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- At this point our rail in segment array contains all the rails we are interested in
    -- Now we need to get all segments connected to these rails and check if they are in the same block
    local rib = {}
    for _, r in pairs(ris) do
        get_rail_in_block_recursive(r, rib)
    end

    return rib

    -- -- Next we need to all the rails in that segment and add it to our array
    -- local roi = {}
    -- for id, entity in pairs(rib) do
    --     for _, dir in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
    --         for _, r in pairs(entity.get_rail_segment_rails(dir)) do
    --             -- TODO near future: we need to recursively find segments because a block consists of multiple segments
    --             -- Safe add to our array
    --             if not roi[r.unit_number] then
    --                 roi[r.unit_number] = r
    --             end
    --         end
    --     end
    -- end

    -- -- Finally we have all rails in the blocks leading to our signal, return the array
    -- return roi
end
local update_waiting_signal = function(gt, data, filter)
    -- Early exit if this train does not have any signal data yet
    if not gt or not gt.signals then
        return
    end

    -- Loop through signals
    for sid, prop in pairs(gt.signals) do
        local entity = model.get_global_entity(sid)
        if entity then
            -- Get all rails in this signal's block
            local roi = get_signal_rails_in_block(entity)

            -- Add the measurements to the array
            for id, entity in pairs(roi) do
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

                -- Sum waiting signal for this rail entity
                if prop.waiting then
                    for min, tick in pairs(prop.waiting) do
                        if min >= filter.first_minute and min <= filter.last_minute then
                            dmr.waiting_signal = (dmr.waiting_signal or 0) + (tick or 0)
                        end
                    end
                end

            end

            -- Add signal data to data.signal[id]
            if prop.waiting then
                -- Init the array
                if not data.measurements.signals[sid] then
                    data.measurements.signals[sid] = {
                        waiting = 0,
                        pos = prop.pos
                    }
                end
                local dms = data.measurements.signals[sid]
                -- Add the waiting time of this signal
                for min, tick in pairs(prop.waiting) do
                    if min >= filter.first_minute and min <= filter.last_minute then
                        dms.waiting_signal = (dms.waiting_signal or 0) + (tick or 0)
                    end
                end
            end
        end
    end
end
local update_waiting_station = function(gt, data, filter)
    -- Early exit if this train does not have any station data yet
    if not gt or not gt.stations then
        return
    end

    -- Loop through stations
    for sid, prop in pairs(gt.stations) do
        local entity = model.get_global_entity(sid)
        if entity then
            -- Get all rails in this station's block
            -- First get the rail that belongs to this station
            local rail = entity.connected_rail
            if rail then
                -- Make array of rails in block
                local rib = {}
                get_rail_in_block_recursive(rail, rib)

                -- At this point we have all the rails in our segment (block)
                -- Now we can add it to the data array
                for id, entity in pairs(rib) do

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

                    -- Sum waiting signal for this rail entity
                    if prop.waiting then
                        for min, tick in pairs(prop.waiting) do
                            if min >= filter.first_minute and min <= filter.last_minute then
                                dmr.waiting_station = (dmr.waiting_station or 0) + (tick or 0)
                            end
                        end
                    end

                    -- TODO: Add station data to data.signal[id].waiting
                end
            end

            -- Add station data to data.signal[id]
            if prop.waiting then
                -- Init the array
                if not data.measurements.stations[sid] then
                    data.measurements.stations[sid] = {
                        waiting_station = 0,
                        pos = prop.pos
                    }
                end
                local dms = data.measurements.stations[sid]
                -- Add the waiting time of this station
                for min, tick in pairs(prop.waiting) do
                    if min >= filter.first_minute and min <= filter.last_minute then
                        dms.waiting_station = (dms.waiting_station or 0) + (tick or 0)
                    end
                end
            end
        end
    end
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
    fltr.last_minute = current_minute
    fltr.first_minute = first_minute

    -- Construct return data
    local data = {
        measurements = {
            rails = {},
            signals = {},
            stations = {}
        },
        ordered = {
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
            update_waiting_signal(gt, data, fltr)
            update_waiting_station(gt, data, fltr)
        end
    end

    -- Make tables for ordering
    for id, prop in pairs(data.measurements.rails) do
        local p = {
            id = id,
            throughput = prop.throughput
        }
        table.insert(data.ordered.rails, prop)
    end

    -- Sort rails by throughput
    table.sort(data.ordered.rails, function(left, right)
        return left.throughput > right.throughput
    end)

    -- Sort signals & stations by waiting
    for _, type in pairs({"signal", "station"}) do
        local tbl = data.measurements[type .. "s"]
        local ord = data.ordered[type .. "s"]
        local arr = {}
        for id, prop in pairs(tbl) do
            -- if prop["waiting_" .. type] and prop["waiting_" .. type] > 0 then
            local p = {
                id = id,
                waiting = prop["waiting_" .. type] or 0
            }
            -- prop.id = id
            table.insert(ord, p)
            -- end
        end
        table.sort(ord, function(left, right)
            return left.waiting > right.waiting
        end)
        ord = arr
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
--                 pos = {x, y},
--             },
--             [rail_id .. n] = {...}
--         },
--         signals = {
--             [signal_id] = {
--                 waiting = ticks,
--                 pos = {x, y},
--             },
--             [signal_id .. n] = {...}
--         },
--         stations = {
--             [station_id] = {
--                 waiting = ticks,
--                 pos = {x, y},
--             },
--             [station_id .. n] = {...}
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

local get_rail = function(train, gt)

    local rail = train.front_rail
    -- if not rail then
    --     warn_invalid(train)
    --     return
    -- end

    -- Get rail entry
    if not gt.rails then
        gt.rails = {}
    end
    if not gt.rails[rail.unit_number] then
        gt.rails[rail.unit_number] = {
            pos = rail.position
        }
    end
    set_global_entity(rail.unit_number, rail)
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

local process_train_waiting_signal = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local signal = train.signal

    if signal then

        -- Get signal entry
        if not gt.signals then
            gt.signals = {}
        end
        if not gt.signals[signal.unit_number] then
            gt.signals[signal.unit_number] = {
                pos = signal.position,
                waiting = {}
            }
        end
        set_global_entity(signal.unit_number, signal)

        -- Update waiting at signal
        local gts = gt.signals[signal.unit_number]
        gts.waiting[minute] = (gts.waiting[minute] or 0) + 1
    else
        process_train_waiting_other(train, gt)
    end
end

local process_train_waiting_station = function(train, gt)
    -- Get variables
    local minute = get_minute()
    local station = train.station

    if station then

        -- Get station entry
        if not gt.stations then
            gt.stations = {}
        end
        if not gt.stations[station.unit_number] then
            gt.stations[station.unit_number] = {
                pos = station.position,
                waiting = {}
            }
        end
        set_global_entity(station.unit_number, station)

        -- Update waiting at station
        local gts = gt.stations[station.unit_number]
        gts.waiting[minute] = (gts.waiting[minute] or 0) + 1
    else
        process_train_waiting_other(train, gt)
    end
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

    -- Init global entities
    if not global.entities then
        global.entities = {}
    end
end

-- Global data model
-- global = {
--     surfaces = {
--         [surface_id] = {        trains = {
--                 [train_id] = {
--                     last_rail = entity_id, -- Unit number of the track this train was in previous tick
--                     rails = {
--                         [rail_entity_id] = {
--                             position = {x, y},
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
--     },
--     entities = {
--         [unit_number] = LuaEntity,
--         [unit_number .. n] = LuaEntity
--     }
-- }

return model
