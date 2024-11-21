local camera_mode = {
	orbit = 1,
	freecam = 2,
	follow = 3,
}

CameraModes = camera_mode

CameraSystem = {
	mode = camera_mode.follow,
	position = Vector3.new(0, 0, 25),
	rotation = 0,
	height = 25,
	target_entity = nil,
	follow_distance = 10,
	follow_speed = 0.1,
}

CameraSystem.camera_handlers = {
	[camera_mode.orbit] = function()

		if(CameraSystem.target_entity == nil) then
			return
		end

		-- Orbit camera around the player
		local orbit_radius = 40       -- Distance from the camera to the player
		local angular_speed = 0.5      -- How fast the camera orbits (radians per second)

		-- Get the elapsed time in seconds
		local frame_num = GameGetFrameNum()
		local time = frame_num / 60.0   -- Assuming the game runs at 60 FPS

		-- Update the rotation angle based on time and angular speed
		local rotation_angle = time * angular_speed

		-- Calculate camera position around the player
		local x = CameraSystem.target_entity.transform.position.x + orbit_radius * math.cos(rotation_angle)
		local y = CameraSystem.target_entity.transform.position.y + orbit_radius * math.sin(rotation_angle)

		-- Set the camera transformation parameters
		CameraSystem.position.x = x
		CameraSystem.position.y = y
		CameraSystem.position.z = CameraSystem.target_entity.transform.position.z + CameraSystem.height
		CameraSystem.rotation = rotation_angle + math.pi / 2

	end,
	[camera_mode.freecam] = function()
		local forwardPressed = InputIsKeyDown(26)
		local backwardPressed = InputIsKeyDown(22)
		local rotateLeftPressed = InputIsKeyDown(4)
		local rotateRightPressed = InputIsKeyDown(7)
		local shiftPressed = InputIsKeyDown(42)
	

		if rotateLeftPressed then
			CameraSystem.rotation = CameraSystem.rotation + 0.03
		end
		if rotateRightPressed then
			CameraSystem.rotation = CameraSystem.rotation - 0.03
		end

		local cos_theta = math.cos(CameraSystem.rotation)
		local sin_theta = math.sin(CameraSystem.rotation)

		local speed = 1;
		if shiftPressed then
			speed = 4;
		end
		-- handle forward and backward in relation to the rotation
		if forwardPressed then
			CameraSystem.position.x = CameraSystem.position.x - sin_theta * speed
			CameraSystem.position.y = CameraSystem.position.y + cos_theta * speed
		end
	
		if backwardPressed then
			CameraSystem.position.x = CameraSystem.position.x + sin_theta * speed
			CameraSystem.position.y = CameraSystem.position.y - cos_theta * speed
		end
	end,
	[camera_mode.follow] = function()

		if(CameraSystem.target_entity == nil) then
			return
		end

		-- Lerp the camera position to follow the player smoothly
		local target_x = CameraSystem.target_entity.transform.position.x - CameraSystem.follow_distance * math.cos(CameraSystem.target_entity.transform.rotation + math.pi / 2)
		local target_y = CameraSystem.target_entity.transform.position.y - CameraSystem.follow_distance * math.sin(CameraSystem.target_entity.transform.rotation + math.pi / 2)
		local target_z = (CameraSystem.target_entity.transform.position.z + CameraSystem.follow_distance) + CameraSystem.height

		CameraSystem.position.x = CameraSystem.position.x + (target_x - CameraSystem.position.x) * CameraSystem.follow_speed
		CameraSystem.position.y = CameraSystem.position.y + (target_y - CameraSystem.position.y) * CameraSystem.follow_speed
		CameraSystem.position.z = CameraSystem.position.z + (target_z - CameraSystem.position.z) * CameraSystem.follow_speed

		-- look at the player always
		-- calculate the angle between the camera and the player
		local dx = CameraSystem.target_entity.transform.position.x - CameraSystem.position.x
		local dy = CameraSystem.target_entity.transform.position.y - CameraSystem.position.y

		local target_r = math.atan2(dy, dx) - math.pi / 2
		-- Normalize the angle difference to prevent the camera from rotating unnecessarily
		local angle_diff = target_r - CameraSystem.rotation
		angle_diff = (angle_diff + math.pi) % (2 * math.pi) - math.pi  -- Normalize to [-π, π]

		-- Now interpolate the camera rotation using the normalized angle difference
		CameraSystem.rotation = CameraSystem.rotation + angle_diff * CameraSystem.follow_speed
	end
}

function CameraSystem.Update()
	CameraSystem.camera_handlers[CameraSystem.mode]()

	if(InputIsKeyJustDown(19))then
		CameraSystem.mode = CameraSystem.mode == camera_mode.follow and camera_mode.freecam or camera_mode.follow
		print("Camera mode: " .. CameraSystem.mode)
	end

	GameSetPostFxParameter("cameraTransform", CameraSystem.position.x, CameraSystem.position.y, CameraSystem.position.z, CameraSystem.rotation)
end