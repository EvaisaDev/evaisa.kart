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
	if(TrackSystem.current_track == nil)then
		return false
	end
	local map = TrackSystem.track_map[TrackSystem.current_track]
    -- Check if the position (x, y) is within a solid area
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
			return x, y,  true
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

		track.ai_nodes = {}
		track.spawn_points = {}
		track.material_map = {}
		track.entity_map = {}

		local ai_node_texture = track.ai_node_texture

		local id, w, h = ModImageMakeEditable(ai_node_texture, 0, 0)
		-- calculate scale
		local _, track_tex_w, track_tex_h = ModImageMakeEditable(track.texture, 0, 0)
		local texture_scale_x = track_tex_w / w
		local texture_scale_y = track_tex_h / h

		-- little bit of color channel tomfoolery
		-- We need to do this in order for the shader to get the correct color channels.. for some reason!!! :D
		local _, _, _ = ModImageMakeEditable(track.oob_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(track.parallax_1_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(track.parallax_2_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(track.parallax_3_texture, 0, 0)

		-- create AI node spline
		local finished = false
		local last_blue_value = -10
		while not finished do
			local best_node = nil
			local best_blue_val = 999999
			-- loop through all pixels on the image and find the best one for the previous node
			for y = 0, h - 1 do
				for x = 0, w - 1 do
					local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
					if r == 0 and g == 0 and a ~= 0 then
						-- found a blue pixel
						if b > last_blue_value and b < best_blue_val then
							best_blue_val = b
							best_node = {x = (x * texture_scale_x), y = ((h - y) * texture_scale_y)}
						end
					end
				end
			end
			if best_node then
				last_blue_value = best_blue_val
				table.insert(track.ai_nodes, best_node)
			else
				finished = true
			end
		end


		-- create materials
		local material_texture = track.materials_texture
		local id, w, h = ModImageMakeEditable(material_texture, 0, 0)
		local texture_scale_x = track_tex_w / w
		local texture_scale_y = track_tex_h / h
	
		print("Material Texture Scale X: "..texture_scale_x)
		print("Material Texture Scale Y: "..texture_scale_y)
	
		-- Create an empty table for the collision track
		track.material_map = {}
		track.material_map_scale = {x = texture_scale_x, y = texture_scale_y}
	
		-- Scan the texture for solid pixels (255, 255, 0) and scale up
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
				local scaled_x = (x)
				local scaled_y = (h - y) - 1
	
				-- Check for the solid color (255, 255, 0)
				if r == 255 and g == 255 and b == 0 and a == 255 then
		 
					track.material_map[scaled_y] = track.material_map[scaled_y] or {}
					track.material_map[scaled_y][scaled_x] = MaterialTypes.solid
	
				-- check for slow color (255, 128, 0)
				elseif r == 255 and g == 128 and b == 0 and a == 255 then
					track.material_map[scaled_y] = track.material_map[scaled_y] or {}
					track.material_map[scaled_y][scaled_x] = MaterialTypes.slow
				
				elseif r == 255 and g == 0 and b == 0 and a == 255 then
					track.material_map[scaled_y] = track.material_map[scaled_y] or {}
					track.material_map[scaled_y][scaled_x] = MaterialTypes.out_of_bounds
				elseif r == 0 and g == 255 and b == 0 and a == 255 then
					table.insert(track.spawn_points, Vector3.new(scaled_x * texture_scale_x, scaled_y * texture_scale_y, 0))
				else
					track.material_map[scaled_y] = track.material_map[scaled_y] or {}
					track.material_map[scaled_y][scaled_x] = MaterialTypes.default
				end
			end
		end

		local entity_texture = track.entity_texture
		local id, w, h = ModImageMakeEditable(entity_texture, 0, 0)
		local texture_scale_x = track_tex_w / w
		local texture_scale_y = track_tex_h / h

		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local r, g, b, a = Utilities.abgrToRgba(ModImageGetPixel(id, x, y))
				local scaled_x = (x)
				local scaled_y = (h - y) - 1
	
				for i, entity_def in ipairs(entity_definitions) do
					--print("Checking entity def: "..entity_def.uid)
					--print("Color: "..r.." == "..entity_def.spawn_color[1].." and "..g.." == "..entity_def.spawn_color[2].." and "..b.." == "..entity_def.spawn_color[3])
					if entity_def.spawn_color and r == entity_def.spawn_color[1] and g == entity_def.spawn_color[2] and b == entity_def.spawn_color[3] and a == 255 then
						table.insert(track.entity_map, {x = scaled_x * texture_scale_x, y = scaled_y * texture_scale_y, entity = entity_def.uid})
					end
				end
			end
		end


		TrackSystem.track_map[trackData.uid] = track
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
	-- kill all entities
	EntitySystem.KillAll()
	-- load track entities
	local track = TrackSystem.track_map[track_uid]
	for _, entitySpawnDef in ipairs(track.entity_map) do
		local entity = EntitySystem.FromType(entitySpawnDef.entity)
		if(entity)then
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
		if(k > #t)then
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