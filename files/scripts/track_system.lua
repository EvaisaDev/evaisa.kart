dofile("mods/evaisa.kart/files/scripts/defs/tracks.lua")
dofile("mods/evaisa.kart/files/scripts/utilities.lua")
TrackSystem = {
    current_track = nil,
    track_map = {},
}

MaterialTypes = {
    default = 0,
    slow = 1,
    solid = 2,
    out_of_bounds = 3,
}

function TrackSystem.CheckMaterial(x, y)
    if (TrackSystem.current_track == nil) then
        return false
    end
    local map = TrackSystem.track_map[TrackSystem.current_track]
    -- Check if the position (x, y) is within the material map
    local collision_row = map.material_map[math.floor(y / map.material_map_scale.y)]
    if collision_row then
        return collision_row[math.floor(x / map.material_map_scale.x)]
    end
    return false
end

function TrackSystem.CastRay(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    local steps = math.ceil(distance)

    for i = 0, steps do
        local x = x1 + dx * i / steps
        local y = y1 + dy * i / steps

        if TrackSystem.IsSolid(x, y) then
            return x, y, true
        end
    end

    return x2, y2, false
end

-- Function to check if a given (x, y) position is solid
function TrackSystem.IsSolid(x, y)
    return TrackSystem.CheckMaterial(x, y) == MaterialTypes.solid or TrackSystem.CheckMaterial(x, y) == MaterialTypes.out_of_bounds
end

function TrackSystem.Init()
    -- Load all tracks
    for _, trackData in ipairs(track_definitions) do
        local track = Utilities.deepCopy(trackData)

        track.flow_map = {}
        track.spawn_points = {}
        track.material_map = {}
        track.entity_map = {}

        -- Calculate scale
        local track_img_id, track_tex_w, track_tex_h = ModImageMakeEditable(track.texture, 0, 0)

        -- Ensure color channels are correctly set up
        ModImageMakeEditable(track.oob_texture, 0, 0)
        ModImageMakeEditable(track.parallax_1_texture, 0, 0)
        ModImageMakeEditable(track.parallax_2_texture, 0, 0)
        ModImageMakeEditable(track.parallax_3_texture, 0, 0)

        -- Create materials
        local material_texture = track.materials_texture
        local id, w, h = ModImageMakeEditable(material_texture, 0, 0)
        local texture_scale_x = track_tex_w / w
        local texture_scale_y = track_tex_h / h

        print("Material Texture Scale X: " .. texture_scale_x)
        print("Material Texture Scale Y: " .. texture_scale_y)

        -- Create an empty table for the material map
        track.material_map = {}
        track.material_map_scale = { x = texture_scale_x, y = texture_scale_y }

        -- Scan the texture for material types and spawn points
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
                local scaled_x = (x)
                local scaled_y = (h - y) - 1

                -- Initialize the row if it doesn't exist
                track.material_map[scaled_y] = track.material_map[scaled_y] or {}

                if r == 255 and g == 255 and b == 0 and a == 255 then
                    -- Solid material
                    track.material_map[scaled_y][scaled_x] = MaterialTypes.solid
                elseif r == 255 and g == 128 and b == 0 and a == 255 then
                    -- Slow material
                    track.material_map[scaled_y][scaled_x] = MaterialTypes.slow
                elseif r == 255 and g == 0 and b == 0 and a == 255 then
                    -- Out of bounds material
                    track.material_map[scaled_y][scaled_x] = MaterialTypes.out_of_bounds
                elseif r == 0 and g == 255 and b == 0 and a == 255 then
                    -- Spawn point
                    table.insert(track.spawn_points, Vector3.new(scaled_x * texture_scale_x, scaled_y * texture_scale_y, 0))
                    track.material_map[scaled_y][scaled_x] = MaterialTypes.default
				elseif r == 56 and g == 103 and b == 103 and a == 255 then
					-- AI Border
					track.material_map[scaled_y][scaled_x] = MaterialTypes.ai_border
				elseif r == 207 and g == 54 and b == 241 and a == 255 then
					track.start_point = Vector3.new(scaled_x, scaled_y, 0)
					track.material_map[scaled_y][scaled_x] = MaterialTypes.default
				elseif r == 241 and g == 54 and b == 145 and a == 255 then
					track.end_point = Vector3.new(scaled_x, scaled_y, 0)
					track.material_map[scaled_y][scaled_x] = MaterialTypes.default
                else
                    -- Default material (track road)
                    track.material_map[scaled_y][scaled_x] = MaterialTypes.default
                end
            end
        end

        -- Load entity map
        local entity_texture = track.entity_texture
        local id, w, h = ModImageMakeEditable(entity_texture, 0, 0)
        local texture_scale_x = track_tex_w / w
        local texture_scale_y = track_tex_h / h

        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
                local scaled_x = (x)
                local scaled_y = (h - y) - 1

                for _, entity_def in ipairs(entity_definitions) do
                    if entity_def.spawn_color and r == entity_def.spawn_color[1] and g == entity_def.spawn_color[2] and b == entity_def.spawn_color[3] and a == 255 then
                        table.insert(track.entity_map, { x = scaled_x * texture_scale_x, y = scaled_y * texture_scale_y, entity = entity_def.uid })
                    end
                end
            end
        end

        -- Generate the flow map
        TrackSystem.GenerateFlowMap(track)

        -- Add debug overlay to the track texture
        TrackSystem.DebugOverlayFlowMap(track, track_img_id, track_tex_w, track_tex_h)

        TrackSystem.track_map[trackData.uid] = track
    end
end

function TrackSystem.GenerateFlowMap(track)
    local width = #track.material_map[1]
    local height = #track.material_map

    -- Initialize the potential map with high values
    local potential_map = {}
    for y = 0, height - 1 do
        potential_map[y] = {}
        for x = 0, width - 1 do
            potential_map[y][x] = math.huge  -- Start with a high potential everywhere
        end
    end


end


function TrackSystem.GetNextDirection(x, y)
    local track = TrackSystem.track_map[TrackSystem.current_track]
    local map_x = math.floor(x / track.material_map_scale.x)
    local map_y = math.floor(y / track.material_map_scale.y)
    local flow = track.flow_map[map_y] and track.flow_map[map_y][map_x]
    if flow then
        return flow.x, flow.y
    else
        return 0, 0
    end
end

function TrackSystem.DebugOverlayFlowMap(track, track_img_id, track_tex_w, track_tex_h)
    -- Overlay the flow map onto the track texture for debugging
    local width = #track.material_map[1]
    local height = #track.material_map

    -- Scale factor to map flow map coordinates to texture coordinates
    local scale_x = track.material_map_scale.x
    local scale_y = track.material_map_scale.y

    -- Loop through the flow map and draw arrows representing the flow direction
    for y = 0, height - 1 do
        for x = 0, width - 1 do
			
   
        end
    end
end

-- Function to draw a line on the texture between two points
function TrackSystem.DrawLineOnTexture(img_id, x0, y0, x1, y1, color_abgr)
    local dx = math.abs(x1 - x0)
    local dy = -math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy

    while true do
        ModImageSetPixel(img_id, x0, y0, color_abgr)

        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then
            err = err + dy
            x0 = x0 + sx
        end
        if e2 <= dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function TrackSystem.GetActiveTrackID()
    return TrackSystem.current_track
end

function TrackSystem.GetActiveTrack()
    return TrackSystem.track_map[TrackSystem.current_track]
end

function TrackSystem.LoadTrack(track_uid)
    TrackSystem.current_track = track_uid
    -- Kill all entities
    EntitySystem.KillAll()
    -- Load track entities
    local track = TrackSystem.track_map[track_uid]
    for _, entitySpawnDef in ipairs(track.entity_map) do
        local entity = EntitySystem.FromType(entitySpawnDef.entity)
        if (entity) then
            entity.transform:SetPosition(entitySpawnDef.x, entitySpawnDef.y)
        end
    end

    GameSetPostFxTextureParameter("map_tex", track.texture, 2, 3, false)
    GameSetPostFxTextureParameter("oob_tex", track.oob_texture, 2, 3, false)

    GameSetPostFxTextureParameter("parallax1_tex", track.parallax_1_texture, 2, 3, false)
    GameSetPostFxTextureParameter("parallax2_tex", track.parallax_2_texture, 2, 3, false)
    GameSetPostFxTextureParameter("parallax3_tex", track.parallax_3_texture, 2, 3, false)
end

local function take_subset(t, i, j)
    local subset = {}
    for k = i, j do
        if (k > #t) then
            break
        end
        table.insert(subset, t[k])
    end
    return subset
end

function TrackSystem.GetSpawnPoints(count)
    local track = TrackSystem.track_map[TrackSystem.current_track]
    local spawn_points = take_subset(track.spawn_points, 1, count)
    for i = #spawn_points, 2, -1 do
        local j = Random(1, i)
        spawn_points[i], spawn_points[j] = spawn_points[j], spawn_points[i]
    end
    return spawn_points
end
