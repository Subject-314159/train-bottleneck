-- Get all connected rails from this signal
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

        -- Get corrected array of rail pieces
        local rails_corrected = {}
        if is_outbound then
            -- We already have the correct rail, no need to do anything else
            table.insert(rails_corrected, r)
        else
            -- The signal is connected to the wrong side of the rail block
            -- Loop through directions required for get_connected_rail
            for _, dir in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
                for _, condir in pairs({defines.rail_connection_direction.left,
                                        defines.rail_connection_direction.straight,
                                        defines.rail_connection_direction.right --  defines.rail_connection_direction.none
                }) do
                    -- Get the connected rail in that direction
                    local gcr = r.get_connected_rail {
                        rail_direction = dir,
                        rail_connection_direction = condir
                    }

                    -- Check if there is actually a rail in this direction
                    if gcr then
                        -- Check for this connected rail if this rail's block contains our original signal as outbound signal
                        local is_outbound_chain = false
                        for _, s in pairs(gcr.get_outbound_signals()) do
                            -- If we found our signal in the outbound signals of this rail then the rail is in the correct block
                            if s.unit_number == signal.unit_number then
                                is_outbound_chain = true
                            end
                        end

                        if is_outbound_chain then
                            -- Ladies and gentlemen, we've got 'em!
                            table.insert(rails_corrected, r)
                        end

                    end
                end
            end
        end
    end
end
