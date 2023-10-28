function onInit()
    global.schedule = {}
end

function supertrim(surface, tick_distance, batch_size)
    local schedule = global.schedule[surface] or {}

    local n = 1
    for chunk in surface.get_chunks() do
        local tick = game.tick + (tick_distance * n)
        schedule[tick] = schedule[tick] or {}
        table.insert(schedule[tick], {
            position = {
                x = chunk.x,
                y = chunk.y
            },
            area = chunk.area
        })
        if #schedule[tick] >= batch_size then
            n = n + 1
        end
    end
    
    global.schedule[surface] = schedule
end

function onTick(tickNumber)
    local preserved = preserveForces()
    for surface, schedule in pairs(global.schedule) do
        if not surface.valid then
            global.schedule[surface] = nil
        else
            if schedule[tickNumber] then
                for _, chunk in ipairs(schedule[tickNumber] or {}) do
                    trimChunk(surface, chunk, preserved)
                end
                if schedule[tickNumber].delete_on_empty and isEmpty(surface) then
                    game.delete_surface(surface)
                end
                schedule[tickNumber] = nil
            end
            if isScheduleEmpty(schedule) then
                global.schedule[surface] = nil
            end
            if isEmpty(surface) then
                game.delete_surface(surface)
            end
        end
    end
end

function isScheduleEmpty(schedule)
    for k, v in pairs(schedule) do
        return false
    end
    return true
end

function isEmpty(surface)
    return not surface.is_chunk_generated(surface.get_random_chunk())
end

function preserveForces()
    local forces = {}
    for k, force in pairs(game.forces) do
        if #force.players > 0 then
            table.insert(forces, force)
        end
    end
    return forces
end

function trimChunk(surface, chunk, preserveForces)
    if not surface.is_chunk_generated(chunk.position) then return end
    local entities = surface.find_entities_filtered({
        area = chunk.area,
        force = preserveForces
    })
    if #entities ~= 0 then return end
    surface.delete_chunk(chunk.position)
end

return { onInit = onInit, onTick = onTick, supertrim = supertrim }