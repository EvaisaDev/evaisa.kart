-- Add this at the top if not already included
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

local DEBUG = true

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

        track.checkpoint_zones = {}
        track.spawn_points = {}
        track.material_map = {}
        track.entity_map = {}
        track.cached_paths = {}
        track.nodes = {}  -- Initialize nodes table

        -- Calculate scale
        local track_img_id, track_tex_w, track_tex_h = ModImageMakeEditable(track.texture, 0, 0)

		track.width, track.height = track_tex_w, track_tex_h

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
                local scaled_x = x
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
                local scaled_x = x
                local scaled_y = (h - y) - 1

                for _, entity_def in ipairs(entity_definitions) do
                    if entity_def.spawn_color and r == entity_def.spawn_color[1] and g == entity_def.spawn_color[2] and b == entity_def.spawn_color[3] and a == 255 then
                        table.insert(track.entity_map, { x = scaled_x * texture_scale_x, y = scaled_y * texture_scale_y, entity = entity_def.uid })
                    end
                end
            end
        end

        -- Load checkpoint zones
        local zones_texture = track.zones_texture
        local id, w, h = ModImageMakeEditable(zones_texture, 0, 0)
        local texture_scale_x = track_tex_w / w
        local texture_scale_y = track_tex_h / h

        -- Collect all unique red values present in the image
        local red_values = {}

        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
                if a == 255 and r > 0 then
                    red_values[r] = true
                end
            end
        end

        -- Convert red values to a sorted list in decreasing order
        local red_values_list = {}
        for red_value, _ in pairs(red_values) do
            table.insert(red_values_list, red_value)
        end
        table.sort(red_values_list, function(a, b) return a > b end)

        track.checkpoint_zones = {}

        for index, red_value in ipairs(red_values_list) do
            local zone_pixel_map = {}
            local pixel_count = 0

            for y = 0, h - 1 do
                for x = 0, w - 1 do
                    local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
                    if a == 255 and r == red_value then
                        local map_x = x
                        local map_y = h - y - 1

                        -- Initialize row if necessary
                        zone_pixel_map[map_y] = zone_pixel_map[map_y] or {}

                        -- Mark the pixel as part of the zone
                        zone_pixel_map[map_y][map_x] = true
                        pixel_count = pixel_count + 1
                    end
                end
            end

            if pixel_count > 0 then
                local zone = {
                    index = index,
                    red_value = red_value,
                    pixel_map = zone_pixel_map
                }

                table.insert(track.checkpoint_zones, zone)
            end
        end

        -- Generate AI nodes while accounting for split paths
        track.nodes = {}
        local nodes_texture = track.nodes_texture
        local id, w, h = ModImageMakeEditable(nodes_texture, 0, 0)
        local texture_scale_x = track_tex_w / w
        local texture_scale_y = track_tex_h / h

        -- Node colors as per your specifications
        local START_COLOR = { r = 0, g = 0, b = 0 }
        local FORWARD_DIRECTION_COLOR = { r = 150, g = 0, b = 0 }
        local REGULAR_PATH_COLOR = { r = 255, g = 0, b = 0 }
		local ALTERNATIVE_PATH_START_COLOR = { r = 0, g = 150, b = 0 } -- Changed to green {0, 255, 0}
        local ALTERNATIVE_PATH_COLOR = { r = 0, g = 255, b = 0 } -- Changed to green {0, 255, 0}

        -- First, collect all nodes from the image
        local node_pixels = {}
        for y = 0, h - 1 do
            for x = 0, w - 1 do 
                local abgr = ModImageGetPixel(id, x, y)
                local r, g, b, a = Utilities.abgrToRgba(abgr)
                local scaled_x = x * texture_scale_x
                local scaled_y = (h - y - 1) * texture_scale_y

                if a == 255 then
                    local color_key = r .. "_" .. g .. "_" .. b
                    if (r == REGULAR_PATH_COLOR.r and g == REGULAR_PATH_COLOR.g and b == REGULAR_PATH_COLOR.b) or
                       (r == ALTERNATIVE_PATH_COLOR.r and g == ALTERNATIVE_PATH_COLOR.g and b == ALTERNATIVE_PATH_COLOR.b) or
                       (r == START_COLOR.r and g == START_COLOR.g and b == START_COLOR.b) or
                       (r == FORWARD_DIRECTION_COLOR.r and g == FORWARD_DIRECTION_COLOR.g and b == FORWARD_DIRECTION_COLOR.b) or
					   (r == ALTERNATIVE_PATH_START_COLOR.r and g == ALTERNATIVE_PATH_START_COLOR.g and b == ALTERNATIVE_PATH_START_COLOR.b)  
					   then
                        table.insert(node_pixels, {
                            x = scaled_x,
                            y = scaled_y,
                            r = r,
                            g = g,
                            b = b,
                            visited = false,
                            neighbors = {},
							is_regular = (r == REGULAR_PATH_COLOR.r and g == REGULAR_PATH_COLOR.g and b == REGULAR_PATH_COLOR.b),
                            is_start = (r == START_COLOR.r and g == START_COLOR.g and b == START_COLOR.b),
                            is_forward = (r == FORWARD_DIRECTION_COLOR.r and g == FORWARD_DIRECTION_COLOR.g and b == FORWARD_DIRECTION_COLOR.b),
                            is_alternative = (r == ALTERNATIVE_PATH_COLOR.r and g == ALTERNATIVE_PATH_COLOR.g and b == ALTERNATIVE_PATH_COLOR.b),
							is_alternative_start = (r == ALTERNATIVE_PATH_START_COLOR.r and g == ALTERNATIVE_PATH_START_COLOR.g and b == ALTERNATIVE_PATH_START_COLOR.b)
                        })
                    end
                end
            end
        end

        -- Function to find the closest unvisited node of a specific color
        local function findClosestNode(current_node, nodes_list, color_match)
            local closest_node = nil
            local min_distance = math.huge
            for _, node in ipairs(nodes_list) do
                if not node.visited and color_match(node) then
                    local dx = node.x - current_node.x
                    local dy = node.y - current_node.y
                    local distance = dx * dx + dy * dy
                    if distance < min_distance then
                        min_distance = distance
                        closest_node = node
                    end
                end
            end
            return closest_node
        end

		local current_color = {0, 255, 0}
        -- Build paths starting from the start node
        local function buildPaths(start_node, alternative)
            local current_node = start_node
            current_node.visited = true
            local path = { current_node }
            while true do
				--[[current_node.color = {current_color[1], current_color[2], current_color[3]}
				if(current_color[1] < 255)then
					current_color[1] = current_color[1] + 5
				elseif(current_color[2] < 255)then
					current_color[2] = current_color[2] + 5
				elseif(current_color[3] < 255)then
					current_color[3] = current_color[3] + 5
				else
					current_color = {0, 0, 0}
				end]]

				current_node.color = {current_color[1], current_color[2], current_color[3]}

                -- Determine the color to search for next
                local function color_match(node)
                    if current_node.is_start then
                        return node.is_forward
                    elseif current_node.is_forward then
                        return node.is_regular
                    elseif current_node.is_alternative then
                        return node.is_alternative or (node.r == REGULAR_PATH_COLOR.r and node.g == REGULAR_PATH_COLOR.g and node.b == REGULAR_PATH_COLOR.b)
					elseif current_node.is_alternative_start then
						return node.is_alternative
					else
                        return node.r == current_node.r and node.g == current_node.g and node.b == current_node.b
                    end
                end

                local next_node = findClosestNode(current_node, node_pixels, color_match)
                if next_node then
                    -- Link the nodes
                    current_node.neighbors[next_node] = true
                    next_node.visited = true
                    table.insert(path, next_node)
                    current_node = next_node

					if(alternative and next_node.is_regular)then
						break
					end
                else
                    -- No more nodes to visit
                    break
                end
            end
            return path
        end

        -- Find the start node
        local start_node = nil
        for _, node in ipairs(node_pixels) do
            if node.is_start then
                start_node = node
                break
            end
        end

        if start_node then
            -- Build the main path
            local main_path = buildPaths(start_node)
			-- set all nodes to not visited
			for _, node in ipairs(node_pixels) do
				node.visited = false
			end

            for _, node in ipairs(node_pixels) do
                if node.is_alternative_start then

					-- find closest regular node
					local closest_regular_node = findClosestNode(node, node_pixels, function(node) return node.is_regular end)
					if closest_regular_node then
						-- add self as neighbor
						closest_regular_node.neighbors[node] = true
					end

                    local alt_path = buildPaths(node, true)

					print("Alternative path found")
					
					for _, node in ipairs(alt_path) do
						table.insert(main_path, node)
					end
                end
            end

			track.nodes = main_path
        else
            print("Start node not found in nodes_texture")
        end

        -- Store the processed track
        TrackSystem.track_map[trackData.uid] = track
    end
end

-- Function to get the next node(s) from the current node
function TrackSystem.GetNextNodes(current_node)
    if current_node and current_node.neighbors then
        local next_nodes = {}
        for neighbor_node, _ in pairs(current_node.neighbors) do
            table.insert(next_nodes, neighbor_node)
        end
        return next_nodes
    end
    return {}
end

-- Function to find the closest node to a given position
function TrackSystem.FindClosestNode(x, y, track_uid)
    local track = TrackSystem.track_map[track_uid]
    if not track then return nil end
    local min_distance = math.huge
    local closest_node = nil
    for _, node in ipairs(track.nodes) do
        local dx = node.x - x
        local dy = node.y - y
        local distance = dx * dx + dy * dy
        if distance < min_distance then
            min_distance = distance
            closest_node = node
        end
    end
    return closest_node
end

-- Pathfinding function to get a path from current position to a target node
function TrackSystem.FindPath(x, y, target_node, track_uid)
    local track = TrackSystem.track_map[track_uid]
    if not track then return nil end
    local start_node = TrackSystem.FindClosestNode(x, y, track_uid)
    if not start_node or not target_node then return nil end

    -- Simple BFS for pathfinding
    local queue = { start_node }
    local came_from = {}
    came_from[start_node] = nil

    while #queue > 0 do
        local current = table.remove(queue, 1)
        if current == target_node then
            -- Reconstruct path
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = came_from[current]
            end
            return path
        end
        for neighbor_node, _ in pairs(current.neighbors) do
            if not came_from[neighbor_node] then
                came_from[neighbor_node] = current
                table.insert(queue, neighbor_node)
            end
        end
    end

    return nil -- Path not found
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

function TrackSystem.CheckCheckpoint(x, y, checkpoint_index)
	local track = TrackSystem.track_map[TrackSystem.current_track]
	if (track == nil) then
		return false
	end

	-- convert x, y to map scale
	x = math.floor(x / track.material_map_scale.x)
	y = math.floor(y / track.material_map_scale.y)

	for _, zone in ipairs(track.checkpoint_zones) do
		if zone.index == checkpoint_index then
			if zone.pixel_map[y] and zone.pixel_map[y][x] then
				return true
			end
		end
	end

	return false
end

function TrackSystem.GetNearestCheckpoint(x, y, next_checkpoint)
	local track = TrackSystem.track_map[TrackSystem.current_track]
	if (track == nil) then
		return nil
	end

	-- get nearest pixel in next checkpoint zone
	local nearest_checkpoint = nil
	local nearest_distance = math.huge
	for _, zone in ipairs(track.checkpoint_zones) do
		if zone.index == next_checkpoint then
			for y2, row in pairs(zone.pixel_map) do
				for x2, _ in pairs(row) do
					local dx = x2 - x
					local dy = y2 - y
					local distance = dx * dx + dy * dy
					if distance < nearest_distance then
						nearest_distance = distance
						nearest_checkpoint = { x = x2 * track.material_map_scale.x, y = y2 * track.material_map_scale.y }
					end
				end
			end
		end
	end
	

	return nearest_checkpoint
end



function TrackSystem.Update()
	if DEBUG then
		-- draw path entirely
		local track = TrackSystem.track_map[TrackSystem.current_track]
		if (track) then
			local first_node = track.nodes[1]
			local draw_node_connections;
			local drawn = {}
			draw_node_connections = function (node)
				if(not node.color)then
					node.color = {0, 0, 0}
				end
				for neighbor, _ in pairs(node.neighbors) do
					RenderingSystem.DrawLine(Vector3(node.x, node.y, 0), Vector3(neighbor.x, neighbor.y, 0), 0.5, node.color[1] / 255, node.color[2] / 255, node.color[3] / 255, 1)
					if(not drawn[neighbor]) then
						drawn[neighbor] = true
						draw_node_connections(neighbor)
					end
				end
			end
			draw_node_connections(first_node)
		end
		
	end
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
