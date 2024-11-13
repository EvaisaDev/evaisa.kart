-- This is the old prototype code for the kart proof of concept.
-- It is a fucking mess but does work.

local vecs = dofile("mods/evaisa.kart/lib/vector.lua")
local Vector3 = vecs.Vector3
local Vector = vecs.Vector

-- Set the track, OOB, and parallax textures as before
GameSetPostFxTextureParameter("map_tex", "mods/evaisa.kart/files/textures/map-noita-2.png", 2, 3, false)
GameSetPostFxTextureParameter("oob_tex", "mods/evaisa.kart/files/textures/oob-noita.png", 2, 3, false)
GameSetPostFxTextureParameter("parallax1_tex", "mods/evaisa.kart/files/textures/parallax/1.png", 2, 3, false)
GameSetPostFxTextureParameter("parallax2_tex", "mods/evaisa.kart/files/textures/parallax/2.png", 2, 3, false)
GameSetPostFxTextureParameter("parallax3_tex", "mods/evaisa.kart/files/textures/parallax/3.png", 2, 3, false)


local function generate_directional_texture(uid, image_path, rotations, sprite_width, sprite_height, shrink_by_one_pixel)
	local file_template = [[
	<Sprite filename="[image_path]" >
		[animations]
	</Sprite>
	]]
	local animation_template = [[
		<RectAnimation 
			name="[anim_name]" 
			pos_x="[pos_x]" 
			pos_y="[pos_y]" 
			frame_width="[frame_width]" 
			frame_height="[frame_height]" 
			frame_count="1"  	
			frame_wait="0.2" 
			frames_per_row="1" 
			shrink_by_one_pixel="[shrink_by_one_pixel]"
			loop="1"  >
		</RectAnimation>
	]]
	
	local animations = ""
	for i = 0, rotations - 1 do
		local anim_name = "anim_"..tostring(i)
		local pos_x = (i) * sprite_width
		local pos_y = 0
		animations = animations .. animation_template:gsub("%[anim_name%]", anim_name):gsub("%[pos_x%]", pos_x):gsub("%[pos_y%]", pos_y):gsub("%[frame_width%]", sprite_width):gsub("%[frame_height%]", sprite_height):gsub("%[shrink_by_one_pixel%]", shrink_by_one_pixel)
	end

	local file_contents = file_template:gsub("%[image_path%]", image_path):gsub("%[animations%]", animations)

	local path = "data/entities/sprites/"..uid..".xml"

	ModTextFileSetContent(path, file_contents)

	-- print
	print("Generated directional texture: "..path)
	print(file_contents)

	return path
end

local texture_types = {
	billboard = 1,
	directional_billboard = 2,
	floor = 3,
}

local textures = {
	{
		uid = "rotta_kart",
		type = texture_types.directional_billboard,
		image_path = "mods/evaisa.kart/files/textures/racers/rotta.png", -- this is used to generate the sprite sheet
		rotations = 12,
		sprite_width = 32,
		sprite_height = 32,
		shrink_by_one_pixel = "0",
		offset_x = 16,
		offset_y = 32,
		side_index = 8
	},
	{
		uid = "tree1",
		type = texture_types.billboard,
		path = "data/vegetation/tree_spruce_1.png",
		offset_x = 36,
		offset_y = 134,
	}
}

local entity_defs = {
	{
		uid = "tree",
		spawn_color = {112, 238, 22},
		collision = true,
		is_trigger = false, -- don't collide but trigger collision events
		radius = 8,
		texture = "tree1",
		position = Vector3.new(0, 0, 0),
		rotation = 0,
		on_update = function(this)
			-- do something
		end,
		on_spawn = function(this)
			-- do something
		end,

	}
}

local texture_map = {}


local camera_mode = {
	orbit = 1,
	freecam = 2,
	follow = 3,
}

local game_data = {
    camera_mode = camera_mode.follow,
    camera = {
		position = Vector3.new(0, 0, 25),
        rotation = 0,
        target = 1,
        follow_distance = 10,
        follow_speed = 0.1,
    },
    kart_config = {
        acceleration = 0.1,
        deceleration = 0.03,
        max_speed = 1.6,
		slow_mult = 0.9,
        turn_speed = 0.03,
        jump_power = 0.1,
    },
	ai_config = {
		node_random_offset = 20,
		node_reach_threshold = 70,
	},
    racers = {},
	entities = {},
    maps = {
        {
            name = "Map1",
            texture = "mods/evaisa.kart/files/textures/map-noita-2.png",
            oob_texture = "mods/evaisa.kart/files/textures/oob-noita.png",
            ai_node_texture = "mods/evaisa.kart/files/textures/map-noita-ai-nodes-2.png",
            materials_texture = "mods/evaisa.kart/files/textures/map-noita-materials-2.png",
			entity_texture = "mods/evaisa.kart/files/textures/map-noita-entities-2.png",
			parallax_1_texture = "mods/evaisa.kart/files/textures/parallax/1.png",
			parallax_2_texture = "mods/evaisa.kart/files/textures/parallax/2.png",
			parallax_3_texture = "mods/evaisa.kart/files/textures/parallax/3.png",
            ai_nodes = {}, -- generated AI nodes
            material_map = {}, -- generated materials
			spawn_points = {},
			entities = {},
        },
    },
    current_map = 1,
}

local racer_template = {
	name = "Player1",
	texture = "rotta_kart",
	position = Vector3.new(920, 440, 0),
	rotation = 0,
	speed = 0,
	is_owner = false,
	use_ai = false,
	current_node_index = 1,
	laps = 0,
	has_crossed = false,
}


local material_types = {
	default = 0,
	slow = 1,
	solid = 2,
	out_of_bounds = 3,
}

local camera_handlers = {
	[camera_mode.orbit] = function()

		local first_racer = game_data.racers[game_data.camera.target]

		-- Orbit camera around the player
		local orbit_radius = 40       -- Distance from the camera to the player
		local angular_speed = 0.5      -- How fast the camera orbits (radians per second)

		-- Get the elapsed time in seconds
		local frame_num = GameGetFrameNum()
		local time = frame_num / 60.0   -- Assuming the game runs at 60 FPS

		-- Update the rotation angle based on time and angular speed
		local rotation_angle = time * angular_speed

		-- Calculate camera position around the player
		local x = first_racer.position.x + orbit_radius * math.cos(rotation_angle)
		local y = first_racer.position.y + orbit_radius * math.sin(rotation_angle)

		-- Set the camera transformation parameters
		game_data.camera.position.x = x
		game_data.camera.position.y = y
		game_data.camera.rotation = rotation_angle + math.pi / 2

	end,
	[camera_mode.freecam] = function()
		local forwardPressed = InputIsKeyDown(26)
		local backwardPressed = InputIsKeyDown(22)
		local rotateLeftPressed = InputIsKeyDown(4)
		local rotateRightPressed = InputIsKeyDown(7)
		local shiftPressed = InputIsKeyDown(42)
	

		if rotateLeftPressed then
			game_data.camera.rotation = game_data.camera.rotation + 0.03
		end
		if rotateRightPressed then
			game_data.camera.rotation = game_data.camera.rotation - 0.03
		end

		local cos_theta = math.cos(game_data.camera.rotation)
		local sin_theta = math.sin(game_data.camera.rotation)

		local speed = 1;
		if shiftPressed then
			speed = 4;
		end
		-- handle forward and backward in relation to the rotation
		if forwardPressed then
			game_data.camera.position.x = game_data.camera.position.x - sin_theta * speed
			game_data.camera.position.y = game_data.camera.position.y + cos_theta * speed
		end
	
		if backwardPressed then
			game_data.camera.position.x = game_data.camera.position.x + sin_theta * speed
			game_data.camera.position.y = game_data.camera.position.y - cos_theta * speed
		end
	end,
	[camera_mode.follow] = function()

		local first_racer = game_data.racers[game_data.camera.target]

		-- Lerp the camera position to follow the player smoothly
		local target_x = first_racer.position.x - game_data.camera.follow_distance * math.cos(first_racer.rotation + math.pi / 2)
		local target_y = first_racer.position.y - game_data.camera.follow_distance * math.sin(first_racer.rotation + math.pi / 2)

		game_data.camera.position.x = game_data.camera.position.x + (target_x - game_data.camera.position.x) * game_data.camera.follow_speed
		game_data.camera.position.y = game_data.camera.position.y + (target_y - game_data.camera.position.y) * game_data.camera.follow_speed

		-- look at the player always
		-- calculate the angle between the camera and the player
		local dx = first_racer.position.x - game_data.camera.position.x
		local dy = first_racer.position.y - game_data.camera.position.y

		local target_r = math.atan2(dy, dx) - math.pi / 2
		-- Normalize the angle difference to prevent the camera from rotating unnecessarily
		local angle_diff = target_r - game_data.camera.rotation
		angle_diff = (angle_diff + math.pi) % (2 * math.pi) - math.pi  -- Normalize to [-π, π]

		-- Now interpolate the camera rotation using the normalized angle difference
		game_data.camera.rotation = game_data.camera.rotation + angle_diff * game_data.camera.follow_speed
	end
}

local horizonOffset = 0.5;

function worldToScreenUV(worldPos, cameraTransform)

	local camera_x, camera_y, camera_w, camera_h = GameGetCameraBounds()

    -- Compute sine and cosine of the camera's rotation angle (cameraTransform.w)
    local cos_theta = math.cos(cameraTransform[4])
    local sin_theta = math.sin(cameraTransform[4])

    -- Small value to avoid division by zero
    local epsilon = 0.0001

    -- Calculate the horizon position and offset in screen space
    local horizon = camera_h - (camera_h * horizonOffset)
    
    -- The camera height plus epsilon to avoid precision issues
    local C = cameraTransform[3] + epsilon
    local windowHeight = camera_h

    -- Compute the difference between the world position and the camera position
    local dx = worldPos[1] - cameraTransform[1]
    local dy = worldPos[2] - cameraTransform[2]

    -- A and B are factors used for perspective projection
    local A = horizon * 224.0
    local B = C * 224 + (-sin_theta * dx + cos_theta * dy) * windowHeight

    -- Check if B is too small (to avoid division by zero); if so, return default UV coordinates (0, 0)
    if math.abs(B) < 1e-6 then
        return {0.0, 0.0, 0.0}
    end

    -- Compute perspective factor P
    local P = A / B

    -- Compute texture coordinates based on the perspective factor and camera position
    local tex_coord_y = (horizon - P * C) / windowHeight
    local tex_coord_x = (128.0 + P * (cos_theta * dx + sin_theta * dy)) / 256.0

    -- Return the calculated UV coordinates
    return {tex_coord_x, tex_coord_y, P}
end

local renderedSprites = {}

local gui = GuiCreate()

function DrawLine3D(gui, id, point1, point2, width, r, g, b, a)
    r = r or 1
    g = g or 1
    b = b or 1
    a = a or 1

	-- convert to screen space
	local screen_width, screen_height = GuiGetScreenDimensions(gui)
	local uv1 = worldToScreenUV({point1.x, point1.y, point1.z}, {game_data.camera.position.x, game_data.camera.position.y, game_data.camera.position.z, game_data.camera.rotation})
	local uv2 = worldToScreenUV({point2.x, point2.y, point2.z}, {game_data.camera.position.x, game_data.camera.position.y, game_data.camera.position.z, game_data.camera.rotation})

	local vec1 = Vector.new(uv1[1] * screen_width, uv1[2] * screen_height)
	local vec2 = Vector.new(uv2[1] * screen_width, uv2[2] * screen_height)

	
    local length = vec1:distance(vec2)
    local angle = (vec1:direction(vec2)):radian()
    
    GuiColorSetForNextWidget(gui, r, g, b, a)
    local offsetX = math.sin(angle) * (width / 2)
    local offsetY = math.cos(angle) * -(width / 2)
    GuiImage(gui, id, vec1.x + offsetX, vec1.y + offsetY, "mods/evaisa.kart/files/textures/1pixel.png", a, length, width, angle)
end

local round = function(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function RenderDirectionalBillboard(id, texture, x, y, z, r, sprite_scale)
    -- Check if texture exists
    if(texture_map[texture] == nil or texture_map[texture].path == nil) then
        print("Texture is missing or invalid for texture ID:", texture)
        return
    end

    -- Convert world position to screen UV coordinates
    local uv = worldToScreenUV(
        {x, y, z},
        {
            game_data.camera.position.x,
            game_data.camera.position.y,
            game_data.camera.position.z,
            game_data.camera.rotation
        }
    )

    local camera_x, camera_y, camera_w, camera_h = GameGetCameraBounds()

    -- Flip the Y-coordinate to account for Lua's top-left origin screen space
    local render_x = camera_x + (uv[1] * camera_w)
    local render_y = camera_y + ((1.0 - uv[2]) * camera_h)  -- Y-axis flip applied here

    local tex = texture_map[texture]

    -- Create the sprite entity if it doesn't exist
    if(renderedSprites[id] == nil) then
        renderedSprites[id] = EntityCreateNew("billboard_"..tostring(id))
        local sprite_comp = EntityAddComponent2(renderedSprites[id], "SpriteComponent", {
            image_file = tex.path,
            rect_animation = "anim_0",
            smooth_filtering = false,
			offset_x = tex.offset_x or 0,
			offset_y = tex.offset_y or 0,
        })
        EntityAddComponent2(renderedSprites[id], "SpriteAnimatorComponent")
		
    end

    local sprite_comp = EntityGetFirstComponentIncludingDisabled(renderedSprites[id], "SpriteComponent")
    if(sprite_comp ~= nil) then
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if(image_file ~= tex.path) then
            ComponentSetValue2(sprite_comp, "image_file", tex.path)
        end


		local camera_forward = Vector.new(-math.sin(game_data.camera.rotation), math.cos(game_data.camera.rotation) )

		local actual_camera_pos = game_data.camera.position - (camera_forward * game_data.camera.position.z)
        -- Calculate the direction from sprite to camera
        local direction_to_camera = Vector.new(actual_camera_pos.x - x, actual_camera_pos.y - y)

		local relative_to_camera_forward = direction_to_camera - camera_forward
		local to_camera_angle = math.atan2(relative_to_camera_forward.y, relative_to_camera_forward.x)

        -- Adjust for the sprite's own rotation
        local relative_angle = to_camera_angle - r
		relative_angle = relative_angle + math.pi / 2
		relative_angle = relative_angle % (2 * math.pi)
		
		local to_sprite = (Vector.new(x, y) - actual_camera_pos):normalized()

		local dot = to_sprite:dot(camera_forward)
		if dot < 0 then
			-- behind camera
			-- disable sprite component
			EntitySetComponentIsEnabled(renderedSprites[id], sprite_comp, false)
			return
		else
			EntitySetComponentIsEnabled(renderedSprites[id], sprite_comp, true)
		end

		local distance = Vector.new(x, y):distance(actual_camera_pos)


        -- Handle half rotation sprite sheet (180 degrees / π radians)
        local total_rotations = tex.rotations or 8 -- Number of frames for half a rotation
		local side_index = tex.side_index or 4
        local mirror = 1

        if relative_angle > math.pi then
            -- Mirror the sprite for angles beyond half rotation
            relative_angle = 2 * math.pi - relative_angle
            mirror = -1
        end


        -- Determine the correct sprite index based on the relative angle
		local anglePerSpriteBackwards = (math.pi / 2) / side_index
		local anglePerSpriteForwards = (math.pi / 2) / (total_rotations - (side_index - 1))
		local sprite_index = math.floor(relative_angle / anglePerSpriteBackwards) % total_rotations

		if relative_angle > (math.pi / 2) then
			sprite_index = math.floor((relative_angle - (math.pi / 2)) / anglePerSpriteForwards) % (total_rotations - (side_index - 1))
			sprite_index = sprite_index + (side_index - 1)

		end

		--GamePrint("sprite_index: "..sprite_index)


        -- Set the animation based on the calculated sprite index
        local anim_name = "anim_"..tostring(sprite_index)
        ComponentSetValue2(sprite_comp, "rect_animation", anim_name)
        GamePlayAnimation(renderedSprites[id], anim_name, 0)

		-- set Z index of sprite component based on distance
		ComponentSetValue2(sprite_comp, "z_index", math.floor(distance))

		EntityRefreshSprite(renderedSprites[id], sprite_comp)

        -- Calculate scale based on perspective factor and sprite scale
        local P = uv[3]
        local drawScale = Vector.new(P, P) * sprite_scale

        -- Adjust render_y to account for z height and perspective factor (P)
        render_y = render_y - (z * P)
		
        -- Apply transformation and mirror if necessary
        EntitySetTransform(renderedSprites[id], render_x, render_y, 0, drawScale.x * mirror, drawScale.y)
    else
        print("SpriteComponent not found for sprite ID:", renderedSprites[id])
    end
end

-- billboard without rotation
function RenderBillboard(id, texture, x, y, z, sprite_scale)
    -- Check if texture exists
    if(texture_map[texture] == nil or texture_map[texture].path == nil) then
        print("Texture is missing or invalid for texture ID:", texture)
        return
    end

    -- Convert world position to screen UV coordinates
    local uv = worldToScreenUV(
        {x, y, z},
        {
            game_data.camera.position.x,
            game_data.camera.position.y,
            game_data.camera.position.z,
            game_data.camera.rotation
        }
    )

    local camera_x, camera_y, camera_w, camera_h = GameGetCameraBounds()

    -- Flip the Y-coordinate to account for Lua's top-left origin screen space
    local render_x = camera_x + (uv[1] * camera_w)
    local render_y = camera_y + ((1.0 - uv[2]) * camera_h)  -- Y-axis flip applied here

    local tex = texture_map[texture]

    -- Create the sprite entity if it doesn't exist
    if(renderedSprites[id] == nil) then
        renderedSprites[id] = EntityCreateNew("billboard_"..tostring(id))
        local sprite_comp = EntityAddComponent2(renderedSprites[id], "SpriteComponent", {
            image_file = tex.path,
            rect_animation = "anim_0",
            smooth_filtering = false,
			offset_x = tex.offset_x or 0,
			offset_y = tex.offset_y or 0,
        })
        EntityAddComponent2(renderedSprites[id], "SpriteAnimatorComponent")
		
    end

    local sprite_comp = EntityGetFirstComponentIncludingDisabled(renderedSprites[id], "SpriteComponent")
    if(sprite_comp ~= nil) then
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if(image_file ~= tex.path) then
            ComponentSetValue2(sprite_comp, "image_file", tex.path)
        end


		local camera_forward = Vector.new(-math.sin(game_data.camera.rotation), math.cos(game_data.camera.rotation) )

		local actual_camera_pos = game_data.camera.position - (camera_forward * game_data.camera.position.z)

		local to_sprite = (Vector.new(x, y) - actual_camera_pos):normalized()

		local dot = to_sprite:dot(camera_forward)
		if dot < 0 then
			-- behind camera
			-- disable sprite component
			EntitySetComponentIsEnabled(renderedSprites[id], sprite_comp, false)
			return
		else
			EntitySetComponentIsEnabled(renderedSprites[id], sprite_comp, true)
		end

		local distance = Vector.new(x, y):distance(actual_camera_pos)


		--GamePrint("sprite_index: "..sprite_index)


		-- set Z index of sprite component based on distance
		ComponentSetValue2(sprite_comp, "z_index", math.floor(distance))

		EntityRefreshSprite(renderedSprites[id], sprite_comp)

        -- Calculate scale based on perspective factor and sprite scale
        local P = uv[3]
        local drawScale = Vector.new(P, P) * sprite_scale

        -- Adjust render_y to account for z height and perspective factor (P)
        render_y = render_y - (z * P)
		
        -- Apply transformation and mirror if necessary
        EntitySetTransform(renderedSprites[id], render_x, render_y, 0, drawScale.x, drawScale.y)
    else
        print("SpriteComponent not found for sprite ID:", renderedSprites[id])
    end
end






function check_material(x, y, map)
    -- Check if the position (x, y) is within a solid area
    local collision_row = map.material_map[math.floor(y / map.material_map_scale.y)]
    if collision_row then
        return collision_row[math.floor(x / map.material_map_scale.x)]
    end
    return false
end

local copy_table = function(t)
	local new_table = {}
	for k, v in pairs(t) do
		new_table[k] = v
	end
	return new_table
end


function init_material_map(map)
    local material_texture = map.materials_texture
    local id, w, h = ModImageMakeEditable(material_texture, 0, 0)
	local track_tex_id, track_tex_w, track_tex_h = ModImageMakeEditable(map.texture, 0, 0)
	local texture_scale_x = track_tex_w / w
	local texture_scale_y = track_tex_h / h

	print("Material Texture Scale X: "..texture_scale_x)
	print("Material Texture Scale Y: "..texture_scale_y)

    -- Create an empty table for the collision map
    map.material_map = {}
	map.material_map_scale = {x = texture_scale_x, y = texture_scale_y}

    -- Scan the texture for solid pixels (255, 255, 0) and scale up
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = abgrToRgba(ModImageGetPixel(id, x, y))
			local scaled_x = (x)
			local scaled_y = (h - y) - 1

            -- Check for the solid color (255, 255, 0)
            if r == 255 and g == 255 and b == 0 and a == 255 then
     
				map.material_map[scaled_y] = map.material_map[scaled_y] or {}
				map.material_map[scaled_y][scaled_x] = material_types.solid

			-- check for slow color (255, 128, 0)
			elseif r == 255 and g == 128 and b == 0 and a == 255 then
				map.material_map[scaled_y] = map.material_map[scaled_y] or {}
				map.material_map[scaled_y][scaled_x] = material_types.slow
			
			elseif r == 255 and g == 0 and b == 0 and a == 255 then
				map.material_map[scaled_y] = map.material_map[scaled_y] or {}
				map.material_map[scaled_y][scaled_x] = material_types.out_of_bounds
			elseif r == 0 and g == 255 and b == 0 and a == 255 then
				table.insert(map.spawn_points, Vector3.new(scaled_x * texture_scale_x, scaled_y * texture_scale_y, 0))
			else
				map.material_map[scaled_y] = map.material_map[scaled_y] or {}
				map.material_map[scaled_y][scaled_x] = material_types.default
			end
		end
	end
end

function load_entities(map)
	local entity_texture = map.entity_texture
	
	local id, w, h = ModImageMakeEditable(entity_texture, nil, nil)
	local track_tex_id, track_tex_w, track_tex_h = ModImageMakeEditable(map.texture, nil, nil)
	local texture_scale_x = track_tex_w / w
	local texture_scale_y = track_tex_h / h

	print("Entity Texture Scale X: "..texture_scale_x)
	print("Entity Texture Scale Y: "..texture_scale_y)

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local r, g, b, a = abgrToRgba(ModImageGetPixel(id, x, y))
			local scaled_x = (x)
			local scaled_y = (h - y) - 1

			for i, entity_def in ipairs(entity_defs) do
				--print("Checking entity def: "..entity_def.uid)
				--print("Color: "..r.." == "..entity_def.spawn_color[1].." and "..g.." == "..entity_def.spawn_color[2].." and "..b.." == "..entity_def.spawn_color[3])
				if r == entity_def.spawn_color[1] and g == entity_def.spawn_color[2] and b == entity_def.spawn_color[3] and a == 255 then
					local entity = copy_table(entity_def)
					entity.position = Vector3.new(scaled_x * texture_scale_x, scaled_y * texture_scale_y, 0)
					table.insert(map.entities, entity)
					print("Spawned entity at: "..entity.position.x..", "..entity.position.y)
				end
			end
		end
	end

end


function update_ai_movement(racer)
    local map = game_data.maps[game_data.current_map]
    local ai_nodes = map.ai_nodes

    if not ai_nodes or #ai_nodes == 0 then
        return  -- No AI nodes to follow
    end

    -- Get the current target node
    local target_index = racer.current_node_index
    if target_index > #ai_nodes then
        racer.current_node_index = 1  -- Loop back to the first node
        target_index = 1
    end
	if(racer.target_node == nil) then
     	racer.target_node = {x = ai_nodes[racer.current_node_index].x + Random(-game_data.ai_config.node_random_offset, game_data.ai_config.node_random_offset), y = ai_nodes[racer.current_node_index].y + Random(-game_data.ai_config.node_random_offset, game_data.ai_config.node_random_offset)}
	end

    -- Calculate the direction vector towards the target node
    local dx = racer.target_node.x - racer.position.x
    local dy = racer.target_node.y - racer.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Threshold to consider the node as reached
    local threshold = game_data.ai_config.node_reach_threshold

    if distance < threshold then
        -- Node reached, target the next node
        racer.current_node_index = racer.current_node_index + 1
        if racer.current_node_index > #ai_nodes then
            racer.current_node_index = 1  -- Loop back to the first node
        end
        racer.target_node = {x = ai_nodes[racer.current_node_index].x + Random(-game_data.ai_config.node_random_offset, game_data.ai_config.node_random_offset), y = ai_nodes[racer.current_node_index].y + Random(-game_data.ai_config.node_random_offset, game_data.ai_config.node_random_offset)}
        dx = racer.target_node.x - racer.position.x
        dy = racer.target_node.y - racer.position.y
        distance = math.sqrt(dx * dx + dy * dy)
    end

    -- Calculate the desired rotation towards the target node
    local desired_r = math.atan2(dy, dx) - math.pi / 2

    -- Calculate angle difference
    local angle_diff = desired_r - racer.rotation
    angle_diff = (angle_diff + math.pi) % (2 * math.pi) - math.pi  -- Normalize to [-π, π]

    -- Smoothly adjust rotation
    local rotation_speed = game_data.kart_config.turn_speed  -- Adjust multiplier as needed
    if math.abs(angle_diff) < rotation_speed then
        racer.rotation = desired_r
    else
        if angle_diff > 0 then
            racer.rotation = racer.rotation + rotation_speed
        else
            racer.rotation = racer.rotation - rotation_speed
        end
    end

    -- Ensure rotation stays within [0, 2π]
    racer.rotation = (racer.rotation + 2 * math.pi) % (2 * math.pi)

    local max_speed = game_data.kart_config.max_speed


    -- Accelerate towards max_speed
    if racer.speed < max_speed then
        racer.speed = racer.speed + game_data.kart_config.acceleration
        if racer.speed > max_speed then
            racer.speed = max_speed
        end
    elseif racer.speed > max_speed then
        racer.speed = racer.speed - game_data.kart_config.deceleration
        if racer.speed < max_speed then
            racer.speed = max_speed
        end
    end


	
end

function update_player_movement(racer)

	local map = game_data.maps[game_data.current_map]

	-- Get the input keys
	local forwardPressed = InputIsKeyDown(26)
	local backwardPressed = InputIsKeyDown(22)
	local leftPressed = InputIsKeyDown(4)
	local rightPressed = InputIsKeyDown(7)
	local jumpPressed = InputIsKeyDown(44)

	-- Get the kart configuration
	local acceleration = game_data.kart_config.acceleration
	local deceleration = game_data.kart_config.deceleration
	local max_speed = game_data.kart_config.max_speed
	local turn_speed = game_data.kart_config.turn_speed
	local jump_power = game_data.kart_config.jump_power

	-- Accelerate or decelerate based on input
	if forwardPressed then
		racer.speed = racer.speed + acceleration
		if racer.speed > max_speed then
			racer.speed = max_speed
		end
	elseif backwardPressed then
		racer.speed = racer.speed - acceleration
		if racer.speed < -(max_speed / 2) then
			racer.speed = -(max_speed / 2)
		end
	else
		-- Decelerate when no input
		if racer.speed > 0 then
			racer.speed = racer.speed - deceleration
			if racer.speed < 0 then
				racer.speed = 0
			end
		end
	end

	-- Turn left or right based on input
	if leftPressed then
		racer.rotation = racer.rotation + turn_speed
	end
	if rightPressed then
		racer.rotation = racer.rotation - turn_speed
	end

	-- Jump when the jump key is pressed
	if jumpPressed then
		racer.position.z = racer.position.z + jump_power
	else
		-- Apply gravity when not jumping
		racer.position.z = racer.position.z - 0.01
	end

	-- Clamp the rotation angle to [0, 2π]
	racer.rotation = (racer.rotation + 2 * math.pi) % (2 * math.pi)

	-- Clamp the z position to prevent falling through the floor
	if racer.position.z < 0 then
		racer.position.z = 0
	end

end



function update_kart_movement(racer)
    local map = game_data.maps[game_data.current_map]

    if racer.is_owner then
        update_player_movement(racer)
    elseif racer.use_ai then
        update_ai_movement(racer)
    end

	
	-- slow down when on slow material
	if check_material(racer.position.x, racer.position.y, map) == material_types.slow or check_material(racer.position.x, racer.position.y, map) == material_types.solid then
		racer.speed = racer.speed * game_data.kart_config.slow_mult
	end

    -- Calculate the intended direction of movement
    local velocity_x = math.cos(racer.rotation + math.pi / 2) * racer.speed
    local velocity_y = math.sin(racer.rotation + math.pi / 2) * racer.speed

    -- First, check for collisions along the x-axis
    local target_x = racer.position.x + velocity_x
    local new_x, _, collision_x = cast_ray(racer.position.x, racer.position.y, target_x, racer.position.y, map)

    -- If no collision in x, move kart horizontally
    if not collision_x then
        racer.position.x = new_x
    end

    -- Now check for collisions along the y-axis
    local target_y = racer.position.y + velocity_y
    local _, new_y, collision_y = cast_ray(racer.position.x, racer.position.y, racer.position.x, target_y, map)

    -- If no collision in y, move kart vertically
    if not collision_y then
        racer.position.y = new_y
    end

	-- if out of bounds, reset to the nearest node
	if check_material(racer.position.x, racer.position.y, map) == material_types.out_of_bounds then
		local nearest_node = nil
		local nearest_distance = 999999
		for i, node in ipairs(map.ai_nodes) do
			local dx = racer.position.x - node.x
			local dy = racer.position.y - node.y
			local distance = math.sqrt(dx * dx + dy * dy)
			if distance < nearest_distance then
				nearest_distance = distance
				nearest_node = node
			end
		end
		if(nearest_node ~= nil)then
			racer.position.x = nearest_node.x
			racer.position.y = nearest_node.y
		end
	end
end

function cast_ray(x1, y1, x2, y2, map)
	local dx = x2 - x1
	local dy = y2 - y1
	local distance = math.sqrt(dx * dx + dy * dy)
	local steps = math.ceil(distance) 

	for i = 0, steps do
		local x = x1 + dx * i / steps
		local y = y1 + dy * i / steps

		if is_solid(x, y, map) then
			return x, y,  true
		end
	end

	return x2, y2, false
end



-- Function to check if a given (x, y) position is solid
function is_solid(x, y, map)
    return check_material(x, y, map) == material_types.solid or check_material(x, y, map) == material_types.out_of_bounds
end


function OnWorldPostUpdate()

	-- Keybind to switch camera mode
	if InputIsKeyJustDown(6) then
		game_data.camera_mode = (game_data.camera_mode % 3) + 1	
	end

	camera_handlers[game_data.camera_mode]()


	-- Set camera and player transformations
	GameSetPostFxParameter("cameraTransform", game_data.camera.position.x, game_data.camera.position.y, game_data.camera.position.z, game_data.camera.rotation)
	for i, racer in ipairs(game_data.racers) do
		update_kart_movement(racer)
		--GameSetPostFxParameter("player"..tostring(i).."Transform", racer.position.x, racer.position.y, racer.position.z, racer.rotation - math.pi / 2)
	end
end

function init_racers()
	--[[for i, racer in ipairs(game_data.racers) do
		GameSetPostFxTextureParameter("player"..tostring(i).."_tex", racer.texture, 2, 0, false)
		GameSetPostFxParameter("player"..tostring(i).."TexCoords", 0, 0, 32, 32)
		GameSetPostFxParameter("player"..tostring(i).."Active", 1, 1, 1, 1)
	end]]
end

function abgrToRgba(abgr)
    local r = bit.band(abgr, 0x000000FF)
    local g = bit.band(abgr, 0x0000FF00)
    local b = bit.band(abgr, 0x00FF0000)
    local a = bit.band(abgr, 0xFF000000)

    g = bit.rshift(g, 8)
    b = bit.rshift(b, 16)
    a = bit.rshift(a, 24)

    return r,g,b,a
end

function init_maps()
	for i, map in ipairs(game_data.maps) do
		-- generate AI nodes
		local ai_node_texture = map.ai_node_texture
		-- generate AI nodes using the texture, scaled up by 8
		-- blue channel is used to define the order of the nodes
		-- use the coordinates of the nodes to generate the AI nodes
		
		local id, w, h = ModImageMakeEditable(ai_node_texture, 0, 0)
		-- calculate scale
		local track_tex_id, track_tex_w, track_tex_h = ModImageMakeEditable(map.texture, 0, 0)
		local texture_scale_x = track_tex_w / w
		local texture_scale_y = track_tex_h / h

		-- little bit of color channel tomfoolery
		local _, _, _ = ModImageMakeEditable(map.oob_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(map.parallax_1_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(map.parallax_2_texture, 0, 0)
		local _, _, _ = ModImageMakeEditable(map.parallax_3_texture, 0, 0)


		print("AI Node Texture Scale X: "..texture_scale_x)
		print("AI Node Texture Scale Y: "..texture_scale_y)

		-- find the first AI node
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				local r, g, b, a = abgrToRgba(ModImageGetPixel(id, x, y))
				if r == 0 and g == 0 and b == 0 and a ~= 0 then
					-- found a blue pixel
					table.insert(map.ai_nodes, {x = (x * texture_scale_x), y = ((h - y) * texture_scale_y)})
				end
			end
		end

		-- create the AI spline, by repeatedly finding the next node based on the amount of blue, so we always take the one with the least blue that also has more blue than the current node.
		local finished = false
		local last_blue_value = 0
		while not finished do
			local best_node = nil
			local best_blue_val = 999999
			-- loop through all pixels on the image and find the best one for the previous node
			for y = 0, h - 1 do
				for x = 0, w - 1 do
					local r, g, b, a = abgrToRgba(ModImageGetPixel(id, x, y))
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
				table.insert(map.ai_nodes, best_node)
			else
				finished = true
			end
		end

		init_material_map(map)
		load_entities(map)

	end
end

function LoadMap(index)
	local map = game_data.maps[index]
	GameSetPostFxTextureParameter("map_tex", map.texture, 2, 3, false)
	GameSetPostFxTextureParameter("oob_tex", map.oob_texture, 2, 3, false)
	-- spawn players from spawn points
	-- shuffle spawn points
	local spawn_points = map.spawn_points
	for i = #spawn_points, 2, -1 do
		local j = Random(1, i)
		spawn_points[i], spawn_points[j] = spawn_points[j], spawn_points[i]
	end
	local player_spawned = false

	for _ = 1, 10 do
		for i = 1, #spawn_points do
			local racer = copy_table(racer_template)
			racer.position = Vector3.new(spawn_points[i] + Vector3.new(Random(-5, 5), Random(-5, 5), 0))
			if(player_spawned) then
				racer.use_ai = true
				racer.is_owner = false
			else
				racer.is_owner = true
				player_spawned = true
				racer.use_ai = false
			end
			table.insert(game_data.racers, racer)
			print("Spawned "..(#game_data.racers).." racers")
		end
	end
	-- load map entities
	for i, entity in ipairs(map.entities) do
		table.insert(game_data.entities, copy_table(entity))
		print("Spawned "..(#game_data.entities).." entities")
	end
end

function OnMagicNumbersAndWorldSeedInitialized()
	SetRandomSeed(1, 1)
	-- generate textures
	for i, texture in ipairs(textures) do
		if texture.type == texture_types.directional_billboard and texture.image_path then
			texture.path = generate_directional_texture(texture.uid, texture.image_path, texture.rotations, texture.sprite_width, texture.sprite_height, texture.shrink_by_one_pixel)
		end
		texture_map[texture.uid] = texture
	end
	init_maps()
end

function OnWorldPreUpdate()
	GuiStartFrame(gui)
	local render_id = 0
	local new_id = function ()
		render_id = render_id + 1
		return render_id
	end
	for i, racer in ipairs(game_data.racers) do
		RenderDirectionalBillboard(new_id(), racer.texture, racer.position.x, racer.position.y, racer.position.z, racer.rotation, 0.8)
	end
	-- draw entities

	for j, entity in ipairs(game_data.entities) do
		if(texture_map[entity.texture])then
			-- check texture type
			if(texture_map[entity.texture].type == texture_types.billboard) then
				RenderBillboard(new_id(), entity.texture, entity.position.x, entity.position.y, entity.position.z, 0.8)
			elseif(texture_map[entity.texture].type == texture_types.directional_billboard) then
				RenderDirectionalBillboard(new_id(), entity.texture, entity.position.x, entity.position.y, entity.position.z, entity.rotation, 0.8)
			end
		end
	end

end

function OnPlayerSpawned(player_entity)
	LoadMap(game_data.current_map)
    EntityKill(player_entity)  -- Remove the player entity (optional)
	init_racers()
end

ModMagicNumbersFileAdd("mods/evaisa.kart/files/magic.xml")
