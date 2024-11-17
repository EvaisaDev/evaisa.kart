dofile("mods/evaisa.kart/files/scripts/camera_system.lua")
dofile("mods/evaisa.kart/files/scripts/defs/textures.lua")
dofile("mods/evaisa.kart/files/scripts/utilities.lua")

local gui = GuiCreate()

RenderingSystem = {
	texture_types = {
		billboard = 1,
		directional_billboard = 2,
		floor = 3,
	},
	texture_map = {},
	camera = CameraSystem,
	horizonOffset = 0.5,
	last_id = 4,
	last_debug_id = 1352551,
	render_offset_y = 0,
	debug_gizmos = false,
}

RenderingSystem.new_id = function()
	RenderingSystem.last_id = RenderingSystem.last_id + 1
	return RenderingSystem.last_id
end

RenderingSystem.new_debug_id = function()
	RenderingSystem.last_debug_id = RenderingSystem.last_debug_id + 1
	return RenderingSystem.last_debug_id
end

local texture_types = {
	billboard = 1,
	directional_billboard = 2,
	floor = 3,
}



function RenderingSystem.GenerateDirectionalTexture(uid, image_path, rotations, sprite_width, sprite_height, shrink_by_one_pixel)
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

-- Need to calculate world position to screen position based on the following shader code:
--[[
float horizon = window_size.y - (window_size.y * horizonOffset);
// Camera Transform w = rotation
float cos_theta = cos(cameraTransform.w);
float sin_theta = sin(cameraTransform.w);
float epsilon = 0.0001;

// Resolution is 256x224
uv.x *= 256.0;
uv.y *= 224.0;
uv.x -= 128.0;

vec2 rotatedCoord;
rotatedCoord.x = uv.x * cos_theta - uv.y * sin_theta;
rotatedCoord.y = uv.x * sin_theta + uv.y * cos_theta;

float perspectiveFactor = (horizon - gl_FragCoord.y) / (cameraTransform.z + epsilon);
rotatedCoord /= perspectiveFactor;

rotatedCoord.x += cameraTransform.x;
rotatedCoord.y += cameraTransform.y;

vec2 mapUV = rotatedCoord;
mapUV.y = 1.0 - mapUV.y;
]]
local ffi = require("ffi")
ffi.cdef([[
typedef struct SDL_Window SDL_Window;
SDL_Window* SDL_GL_GetCurrentWindow();
int SDL_GetWindowSize(SDL_Window* window, int* w, int* h);
]])

SDL2 = ffi.load('SDL2.dll')

local window = SDL2.SDL_GL_GetCurrentWindow()

function GetWindowSize()
	local w = ffi.new("int[1]")
	local h = ffi.new("int[1]")
	SDL2.SDL_GetWindowSize(window, w, h)
	return w[0], h[0]
end


function RenderingSystem.worldToScreenUV(worldPos, cameraTransform)

    local window_width, window_height = GetWindowSize()

	window_width = window_width * 0.25
	window_height = window_height * 0.25

    -- Compute sine and cosine of the camera's rotation angle (cameraTransform.w)
    local cos_theta = math.cos(cameraTransform[4])
    local sin_theta = math.sin(cameraTransform[4])

    -- Small value to avoid division by zero
    local epsilon = 0.0001

    -- Calculate the horizon position and offset in screen space
    local horizon = window_height - (window_height * RenderingSystem.horizonOffset)
    
    -- The camera height plus epsilon to avoid precision issues
    local C = cameraTransform[3] + epsilon


    -- Compute the difference between the world position and the camera position
    local dx = worldPos[1] - cameraTransform[1]
    local dy = worldPos[2] - cameraTransform[2]

    -- A and B are factors used for perspective projection
    local A = horizon * 224.0
    local B = C * 224 + (-sin_theta * dx + cos_theta * dy) * window_height

    -- Check if B is too small (to avoid division by zero); if so, return default UV coordinates (0, 0)
    if math.abs(B) < 1e-6 then
        return {0.0, 0.0, 0.0}
    end

    -- Compute perspective factor P
    local P = A / B

    -- Compute texture coordinates based on the perspective factor and camera position
    local tex_coord_y = (horizon - P * C) / window_height
    local tex_coord_x = (128.0 + P * (cos_theta * dx + sin_theta * dy)) / 256.0

	tex_coord_y = tex_coord_y - (RenderingSystem.render_offset_y * P)

    -- Return the calculated UV coordinates
    return {tex_coord_x, tex_coord_y, P}
end

function RenderingSystem.screenUVToWorld(x, y, cameraTransform)
    local window_width, window_height = GetWindowSize()

    window_width = window_width * 0.25
    window_height = window_height * 0.25

    -- Compute sine and cosine of the camera's rotation angle (cameraTransform.w)
    local cos_theta = math.cos(cameraTransform[4])
    local sin_theta = math.sin(cameraTransform[4])

    -- Small value to avoid division by zero
    local epsilon = 0.0001

    -- Calculate the horizon position in screen space
    local horizon = window_height - (window_height * RenderingSystem.horizonOffset)

    -- The camera height plus epsilon to avoid precision issues
    local C = cameraTransform[3] + epsilon

    -- Recompute the perspective factor P from the screen UV y-coordinate
    local P = (horizon - y * window_height) / C

    -- Compute the world-space X and Y positions based on screen UV and perspective
    local screen_x = (x * 256.0 - 128.0) / P
    local screen_y = (horizon - y * window_height + RenderingSystem.render_offset_y * P) / P

    -- Reverse the camera's rotation to map back to world coordinates
    local dx = cos_theta * screen_x - sin_theta * screen_y
    local dy = sin_theta * screen_x + cos_theta * screen_y

    -- Add the camera's position to get the final world position
    local world_x = cameraTransform[1] + dx
    local world_y = cameraTransform[2] + dy

    -- Return the calculated world position
    return {world_x, world_y}
end

local renderedSprites = {}


function RenderingSystem.RenderDirectionalBillboard(id, texture, x, y, z, r, sprite_scale)
    -- Check if texture exists
    if(RenderingSystem.texture_map[texture] == nil or (RenderingSystem.texture_map[texture].path == nil and RenderingSystem.texture_map[texture].defs == nil)) then
        print("Texture is missing or invalid for texture ID:", texture)
        return
    end

    -- Convert world position to screen UV coordinates
    local uv = RenderingSystem.worldToScreenUV(
        {x, y, z},
        {
            RenderingSystem.camera.position.x,
            RenderingSystem.camera.position.y,
            RenderingSystem.camera.position.z,
            RenderingSystem.camera.rotation
        }
    )

    local camera_x, camera_y, camera_w, camera_h = GameGetCameraBounds()

    -- Flip the Y-coordinate to account for Lua's top-left origin screen space
    local render_x = camera_x + (uv[1] * camera_w)
    local render_y = camera_y + ((1.0 - uv[2]) * camera_h)  -- Y-axis flip applied here

    local tex = RenderingSystem.texture_map[texture]

    -- Create the sprite entity if it doesn't exist
    if(renderedSprites[id] == nil) then
		renderedSprites[id] = {}
        renderedSprites[id].entity = EntityCreateNew("billboard_"..tostring(id))
        local sprite_comp = EntityAddComponent2(renderedSprites[id].entity, "SpriteComponent", {
            image_file = tex.path,
            rect_animation = "anim_0",
            smooth_filtering = false,
			offset_x = tex.offset_x or 0,
			offset_y = tex.offset_y or 0,
        })
        EntityAddComponent2(renderedSprites[id].entity, "SpriteAnimatorComponent")
		
    end

	renderedSprites[id].last_frame_rendered = GameGetFrameNum()

    local sprite_comp = EntityGetFirstComponentIncludingDisabled(renderedSprites[id].entity, "SpriteComponent")
    if(sprite_comp ~= nil) then
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if(image_file ~= tex.path) then
            ComponentSetValue2(sprite_comp, "image_file", tex.path)
        end

		local tex = RenderingSystem.texture_map[texture]
		SetRandomSeed(id, id + 1)
		if tex.defs then
			local def = tex.defs[Random(1, #tex.defs)]
			-- copy def contents to tex
			for k, v in pairs(def) do
				tex[k] = v
			end
		end
	

		local camera_forward = Vector.new(-math.sin(RenderingSystem.camera.rotation), math.cos(RenderingSystem.camera.rotation) )

		local actual_camera_pos = RenderingSystem.camera.position - (camera_forward * RenderingSystem.camera.position.z)
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
			EntitySetComponentIsEnabled(renderedSprites[id].entity, sprite_comp, false)
			return
		else
			EntitySetComponentIsEnabled(renderedSprites[id].entity, sprite_comp, true)
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
        GamePlayAnimation(renderedSprites[id].entity, anim_name, 0)

		-- set Z index of sprite component based on distance
		ComponentSetValue2(sprite_comp, "z_index", math.floor(distance))

		EntityRefreshSprite(renderedSprites[id].entity, sprite_comp)

        -- Calculate scale based on perspective factor and sprite scale
        local P = uv[3]
        local drawScale = Vector.new(P, P) * sprite_scale

        -- Adjust render_y to account for z height and perspective factor (P)
        render_y = render_y - (z * P)
		
        -- Apply transformation and mirror if necessary
        EntitySetTransform(renderedSprites[id].entity, render_x, render_y, 0, drawScale.x * mirror, drawScale.y)
    else
        print("SpriteComponent not found for sprite ID:", renderedSprites[id].entity)
    end
end

-- billboard without rotation
function RenderingSystem.RenderBillboard(id, texture, x, y, z, sprite_scale)
    -- Check if texture exists
    if(RenderingSystem.texture_map[texture] == nil or (RenderingSystem.texture_map[texture].path == nil and RenderingSystem.texture_map[texture].defs == nil)) then
        print("Texture is missing or invalid for texture ID:", texture)
        return
    end

	local tex = RenderingSystem.texture_map[texture]
	SetRandomSeed(id, id + 1)
	if tex.defs then
		local def = tex.defs[Random(1, #tex.defs)]
		-- copy def contents to tex
		for k, v in pairs(def) do
			tex[k] = v
		end
	end

    -- Convert world position to screen UV coordinates
    local uv = RenderingSystem.worldToScreenUV(
        {x, y, z},
        {
            RenderingSystem.camera.position.x,
            RenderingSystem.camera.position.y,
            RenderingSystem.camera.position.z,
            RenderingSystem.camera.rotation
        }
    )

    local camera_x, camera_y, camera_w, camera_h = GameGetCameraBounds()

    -- Flip the Y-coordinate to account for Lua's top-left origin screen space
    local render_x = camera_x + (uv[1] * camera_w)
    local render_y = camera_y + ((1.0 - uv[2]) * camera_h)  -- Y-axis flip applied here

    local tex = RenderingSystem.texture_map[texture]

    -- Create the sprite entity if it doesn't exist
    if(renderedSprites[id] == nil) then
		renderedSprites[id] = {last_frame_rendered = GameGetFrameNum()}
        renderedSprites[id].entity = EntityCreateNew("billboard_"..tostring(id))
        local sprite_comp = EntityAddComponent2(renderedSprites[id].entity, "SpriteComponent", {
            image_file = tex.path,
            rect_animation = "anim_0",
            smooth_filtering = false,
			offset_x = tex.offset_x or 0,
			offset_y = tex.offset_y or 0,
        })
        EntityAddComponent2(renderedSprites[id].entity, "SpriteAnimatorComponent")
		
    end

	renderedSprites[id].last_frame_rendered = GameGetFrameNum()

    local sprite_comp = EntityGetFirstComponentIncludingDisabled(renderedSprites[id].entity, "SpriteComponent")
    if(sprite_comp ~= nil) then
        local image_file = ComponentGetValue2(sprite_comp, "image_file")
        if(image_file ~= tex.path) then
            ComponentSetValue2(sprite_comp, "image_file", tex.path)
        end


		local camera_forward = Vector.new(-math.sin(RenderingSystem.camera.rotation), math.cos(RenderingSystem.camera.rotation) )

		local actual_camera_pos = RenderingSystem.camera.position - (camera_forward * RenderingSystem.camera.position.z)

		local to_sprite = (Vector.new(x, y) - actual_camera_pos):normalized()

		local dot = to_sprite:dot(camera_forward)
		if dot < 0 then
			-- behind camera
			-- disable sprite component
			EntitySetComponentIsEnabled(renderedSprites[id].entity, sprite_comp, false)
			return
		else
			EntitySetComponentIsEnabled(renderedSprites[id].entity, sprite_comp, true)
		end

		local distance = Vector.new(x, y):distance(actual_camera_pos)


		--GamePrint("sprite_index: "..sprite_index)


		-- set Z index of sprite component based on distance
		ComponentSetValue2(sprite_comp, "z_index", math.floor(distance))

		EntityRefreshSprite(renderedSprites[id].entity, sprite_comp)

        -- Calculate scale based on perspective factor and sprite scale
        local P = uv[3]
        local drawScale = Vector.new(P, P) * sprite_scale

        -- Adjust render_y to account for z height and perspective factor (P)
        render_y = render_y - (z * P)
		
        -- Apply transformation and mirror if necessary
        EntitySetTransform(renderedSprites[id].entity, render_x, render_y, 0, drawScale.x, drawScale.y)
    else
        print("SpriteComponent not found for sprite ID:", renderedSprites[id].entity)
    end
end

dofile("data/scripts/lib/utilities.lua")


function RenderingSystem.DrawLine(point1, point2, width, r, g, b, a)
    r = r or 1
    g = g or 1
    b = b or 1
    a = a or 1

	local uv1 = RenderingSystem.worldToScreenUV({point1.x, point1.y, point1.z}, {
		RenderingSystem.camera.position.x,
		RenderingSystem.camera.position.y,
		RenderingSystem.camera.position.z,
		RenderingSystem.camera.rotation
	})
	local uv2 = RenderingSystem.worldToScreenUV({point2.x, point2.y, point2.z}, {
		RenderingSystem.camera.position.x,
		RenderingSystem.camera.position.y,
		RenderingSystem.camera.position.z,
		RenderingSystem.camera.rotation
	})

    local screen_width, screen_height = GuiGetScreenDimensions(gui)

    local render_x = screen_width * uv1[1]
	local render_y = screen_height * (1.0 - uv1[2])
	local render_x2 = screen_width * uv2[1]
	local render_y2 = screen_height * (1.0 - uv2[2])

	-- frustum culling based on uv1[3]
	if uv1[3] < 0 or uv2[3] < 0 then
		return
	end
	

	local vec1 = Vector.new(render_x, render_y)
	local vec2 = Vector.new(render_x2, render_y2)
	
    local length = vec1:distance(vec2)
    local angle = (vec1:direction(vec2)):radian()

    GuiColorSetForNextWidget(gui, r, g, b, a)
    local offsetX = math.sin(angle) * (width / 2)
    local offsetY = math.cos(angle) * -(width / 2)
    GuiImage(gui, RenderingSystem.new_debug_id(), vec1.x + offsetX, vec1.y + offsetY, "mods/evaisa.kart/files/textures/1pixel.png", a, length, width, angle)
end

function RenderingSystem.DrawText(text, point, scale, center_horizontal, center_vertical, r, g, b, a, font, is_pixel_font)
	r = r or 1
	g = g or 1
	b = b or 1
	a = a or 1
	scale = scale or 1

	local uv = RenderingSystem.worldToScreenUV(
		{point.x, point.y, point.z},
		{
			RenderingSystem.camera.position.x,
			RenderingSystem.camera.position.y,
			RenderingSystem.camera.position.z,
			RenderingSystem.camera.rotation
		}
	)

	local screen_width, screen_height = GuiGetScreenDimensions(gui)

	local render_x = screen_width * uv[1]
	local render_y = screen_height * (1.0 - uv[2])

	-- scale text based on perspective factor
	scale = scale * uv[3]

	if(is_pixel_font == nil)then
		is_pixel_font = true
	end

	local text_width, text_height

	if font then
		text_width, text_height = GuiGetTextDimensions(gui, tostring(text), scale, 2, font, is_pixel_font)
	else
		text_width, text_height = GuiGetTextDimensions(gui, tostring(text), scale, 2)
	end

	if center_horizontal then
		render_x = render_x - (text_width / 2)
	end

	if center_vertical then
		render_y = render_y - (text_height / 2)
	end

	-- offset Y based on Z position
	render_y = render_y - (point.z * uv[3])

	-- print out all the arguments for debugging
	--print("text: "..text..", point: "..point.x..", "..point.y..", "..point.z..", scale: "..scale..", center_horizontal: "..tostring(center_horizontal)..", center_vertical: "..tostring(center_vertical)..", r: "..r..", g: "..g..", b: "..b..", a: "..a..", font: "..font..", is_pixel_font: "..tostring(is_pixel_font))


	GuiColorSetForNextWidget(gui, r, g, b, a)

	if font then
		GuiText(gui, render_x, render_y, tostring(text), scale, font, is_pixel_font)
	else
		GuiText(gui, render_x, render_y, tostring(text), scale)
	end

end

function RenderingSystem.GenerateTextures()
	for i, texture in ipairs(texture_definitions) do
		if(texture.defs)then
			for _, def in ipairs(texture.defs) do
				if texture.type == texture_types.directional_billboard and def.path then
					def.path = RenderingSystem.GenerateDirectionalTexture(texture.uid, def.path, def.rotations, def.sprite_width, def.sprite_height, def.shrink_by_one_pixel)
				end
			end
		else
			if texture.type == texture_types.directional_billboard and texture.path then
				texture.path = RenderingSystem.GenerateDirectionalTexture(texture.uid, texture.path, texture.rotations, texture.sprite_width, texture.sprite_height, texture.shrink_by_one_pixel)
			end
		end
		RenderingSystem.texture_map[texture.uid] = texture
	end
end

function RenderingSystem.Update()
	-- reset id to 4
	RenderingSystem.last_id = 4
	RenderingSystem.last_debug_id = 1352551
	GuiStartFrame(gui)

	-- garbage collection
	for id, entity in pairs(renderedSprites) do
		if entity.last_frame_rendered and entity.last_frame_rendered < GameGetFrameNum() - 5 then
			EntityKill(entity.entity)
			renderedSprites[id] = nil
		end
	end
end

function RenderingSystem.Reset()
	-- kill all rendered sprites
	for id, entity in pairs(renderedSprites) do
		if(EntityGetIsAlive(entity))then
			EntityKill(entity)
		end
	end
	renderedSprites = {}
	print("Reset rendering system")
end