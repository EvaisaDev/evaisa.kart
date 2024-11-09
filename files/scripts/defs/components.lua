component_definitions = {
    {
        name = "Transform",
        default_data = {
            position = Vector3(0, 0, 0),
            rotation = 0,
            scale = Vector(1, 1),
			update_rate = 1, -- 1 = every frame, 2 = every other frame, etc.
            GetPosition = function(self)
                return self.position
            end,
            SetPosition = function(self, x, y)
                if(type(x) == "table")then
                    self.position = x
                else
                    if(x)then
                        self.position.x = x
                    end
                    if(y)then
                        self.position.y = y
                    end
                end
            end,
            GetRotation = function(self)
                return self.rotation
            end,
            SetRotation = function(self, rotation)
                self.rotation = rotation or 0
            end,
            GetScale = function(self)
                return self.scale or Vector(1, 1)
            end,
            SetScale = function(self, x, y)
                if(type(x) == "table")then
                    self.scale = x
                else
                    if(x)then
                        self.scale.x = x
                    end
                    if(y)then
                        self.scale.y = y
                    end
                end
            end,
			NetworkSerialize = function(self, lobby)

				print("Transform NetworkSerialize: \nx:" .. self.position.x .. ", y: " .. self.position.y .. ", z: " .. self.position.z .. ", r: " .. self.rotation)

				return Structs.Transform{
					x = self.position.x,
					y = self.position.y,
					z = self.position.z,
					r = self.rotation
				}
			end,
			NetworkDeserialize = function(self, lobby, data)

				print("Transform NetworkDeserialize: \nx:" .. data.x .. ", y: " .. data.y .. ", z: " .. data.z .. ", r: " .. data.r)

				-- apply data
				self.position.x = data.x
				self.position.y = data.y
				self.position.z = data.z
				self.rotation = data.r
			end,
        }
    },
    {
        name = "Velocity",
        default_data = {
            velocity = Vector3(0, 0, 0),
			last_speed = 0,
            gravity = -0.2,
            drag = 0.95,
            collide_with_map = true,
            debug = false,
			update_rate = 1,
            Update = function(self, entity, lobby)
                -- Apply gravity
                self.velocity.z = self.velocity.z + self.gravity

                -- print velocity for debugging
                if self.debug then
                    GamePrint("Velocity: " .. self.velocity.x .. ", " .. self.velocity.y .. ", " .. self.velocity.z)
                end
                
                -- keep in bounds of map
                if self.collide_with_map then
                    local map = TrackSystem.GetActiveTrack()
                    entity.transform.position.z = entity.transform.position.z + self.velocity.z

                    local target_x = entity.transform.position.x + self.velocity.x
                    local new_x, _, collision_x = TrackSystem.CastRay(entity.transform.position.x, entity.transform.position.y, target_x, entity.transform.position.y)
                    if not collision_x then
                        entity.transform.position.x = new_x
                    end

                    local target_y = entity.transform.position.y + self.velocity.y
                    local _, new_y, collision_y = TrackSystem.CastRay(entity.transform.position.x, entity.transform.position.y, entity.transform.position.x, target_y)
                    if not collision_y then
                        entity.transform.position.y = new_y
                    end
                else
                    -- Update position based on velocity
                    entity.transform.position.x = entity.transform.position.x + self.velocity.x
                    entity.transform.position.y = entity.transform.position.y + self.velocity.y
                    entity.transform.position.z = entity.transform.position.z + self.velocity.z
                end

				-- Apply drag
				self.velocity.x = self.velocity.x * self.drag
				self.velocity.y = self.velocity.y * self.drag
				self.velocity.z = self.velocity.z * self.drag

                -- Clamp the z position to prevent falling through the floor
                if entity.transform.position.z < 0 then
                    entity.transform.position.z = 0
                    self.velocity.z = 0
                end

                -- Handle collisions with other entities
                local all_entities = EntitySystem.GetAllEntities()
                for _, other_entity in ipairs(all_entities) do
                    if other_entity ~= entity then
                        local collider = entity:GetComponentOfType("Collider")
                        local other_collider = other_entity:GetComponentOfType("Collider")
                        if collider and other_collider and collider:Intersects(other_collider) then
							if(not other_collider.is_trigger and not collider.is_trigger) then
								local other_velocity = other_entity:GetComponentOfType("Velocity")
								if other_velocity then

									-- Simple elastic collision response
									local normal = (entity.transform.position - other_entity.transform.position):normalize()
									local relative_velocity = self.velocity - other_velocity.velocity
									local separating_velocity = relative_velocity:dot(normal)
									if separating_velocity < 0 then
										local new_sep_velocity = -separating_velocity * math.min(collider.restitution, other_collider.restitution)
										local delta_velocity = new_sep_velocity - separating_velocity
										local total_inverse_mass = 1 / collider.mass + 1 / other_collider.mass
										local impulse = delta_velocity / total_inverse_mass
										local impulse_per_mass = normal * impulse

										self.velocity = self.velocity + impulse_per_mass / collider.mass
										other_velocity.velocity = other_velocity.velocity - impulse_per_mass / other_collider.mass
									end
								else
									-- Collision with a static entity (no velocity component)
									local normal = (entity.transform.position - other_entity.transform.position):normalize()
									local separating_velocity = self.velocity:dot(normal)
									if separating_velocity < 0 then
										local new_sep_velocity = -separating_velocity * collider.restitution
										self.velocity = self.velocity + normal * (new_sep_velocity - separating_velocity)
									end
								end
							end
							-- Trigger OnCollision event
							collider:OnCollision(other_collider)
                        end
                    end
                end
            end,
            GetVelocity = function(self)
                return self.velocity
            end,
            SetVelocity = function(self, x, y, z)
                if(type(x) == "table")then
                    self.velocity = x
                else
                    if(x)then
                        self.velocity.x = x
                    end
                    if(y)then
                        self.velocity.y = y
                    end
                    if(z)then
                        self.velocity.z = z
                    end
                end
            end,
			--[[NetworkSerialize = function(self, lobby)
				return Structs.Velocity{
					x = self.velocity.x,
					y = self.velocity.y,
					z = self.velocity.z
				}
			end,
			NetworkDeserialize = function(self, lobby, data)
				-- apply data
				self.velocity.x = data.x
				self.velocity.y = data.y
				self.velocity.z = data.z
			end,]]
        }
    },
    {
        name = "Collider",
        default_data = {
			tags = {},
            is_sphere = false,
            radius = 0,
            AAA = Vector3(0, 0, 0),
            BBB = Vector3(0, 0, 0),
            mass = 1,
            restitution = 0.8,
			is_trigger = false,
            -- Check if the collider intersects with another collider
            Intersects = function(self, other)
				if((self.tags and self.tags.player and other.tags and other.tags.player) and not GameHasFlagRun("kart_collisions")) then
					return false
				end
				
                if self.is_sphere and other.is_sphere then
                    -- Sphere against Sphere
                    local distance = self._entity.transform.position:distance(other._entity.transform.position)
                    return distance < (self.radius + other.radius)
                elseif self.is_sphere and not other.is_sphere then
                    -- Sphere against Box
                    local closest_point = other.AAA:clone()
                    if self._entity.transform.position.x > other.BBB.x then
                        closest_point.x = other.BBB.x
                    elseif self._entity.transform.position.x < other.AAA.x then
                        closest_point.x = other.AAA.x
                    end
                    if self._entity.transform.position.y > other.BBB.y then
                        closest_point.y = other.BBB.y
                    elseif self._entity.transform.position.y < other.AAA.y then
                        closest_point.y = other.AAA.y
                    end
                    if self._entity.transform.position.z > other.BBB.z then
                        closest_point.z = other.BBB.z
                    elseif self._entity.transform.position.z < other.AAA.z then
                        closest_point.z = other.AAA.z
                    end
                    return self._entity.transform.position:distance(closest_point) < self.radius
                elseif not self.is_sphere and not other.is_sphere then
                    -- Box against Box
                    return (self.AAA.x <= other.BBB.x and self.BBB.x >= other.AAA.x) and
                           (self.AAA.y <= other.BBB.y and self.BBB.y >= other.AAA.y) and
                           (self.AAA.z <= other.BBB.z and self.BBB.z >= other.AAA.z)
                end
                return false
            end,
			OnCollision = function(self, other)

			end,
			
        },
    },
    {
        name = "Sprite",
        default_data = {
            texture = nil,
            GetTexture = function(self)
                return self.texture
            end,
            SetTexture = function(self, texture)
                self.texture = texture
            end,
            Update = function(self, entity, lobby)
                if(RenderingSystem.texture_map[self.texture])then
                    -- check texture type
                    if(RenderingSystem.texture_map[self.texture].type == TextureTypes.billboard) then
                        RenderingSystem.RenderBillboard(RenderingSystem.new_id(), self.texture, entity.transform.position.x, entity.transform.position.y, entity.transform.position.z, 0.8)
                    elseif(RenderingSystem.texture_map[self.texture].type == TextureTypes.directional_billboard) then
                        RenderingSystem.RenderDirectionalBillboard(RenderingSystem.new_id(), self.texture, entity.transform.position.x, entity.transform.position.y, entity.transform.position.z, entity.transform.rotation, 0.8)
                    end
                end
            end,
        }
    },
    {
        name = "Kart",
        default_data = {
            config = {
                acceleration = 0.2,
                slow_mult = 0.9,
                turn_speed = 0.03,
                jump_power = 3,
            },
            ai_config = {
                node_random_offset = 20,
                node_reach_threshold = 70,
            },
            is_npc = false,
			player_id = 0,
            PlayerMovement = function(self, entity)
                -- Get the input keys
                local forwardPressed = InputIsKeyDown(26)
                local backwardPressed = InputIsKeyDown(22)
                local leftPressed = InputIsKeyDown(4)
                local rightPressed = InputIsKeyDown(7)
                local jumpPressed = InputIsKeyJustDown(44)

                -- Get the kart configuration
                local acceleration = self.config.acceleration
                local turn_speed = self.config.turn_speed
                local jump_power = self.config.jump_power

				

                -- Turn left or right based on input
                if leftPressed then
                    entity.transform.rotation = entity.transform.rotation + turn_speed
                end
                if rightPressed then
                    entity.transform.rotation = entity.transform.rotation - turn_speed
                end

                -- Get the Velocity component
                local velocityComponent = entity:GetComponentOfType("Velocity")
                if not velocityComponent then return end

				local old_speed = velocityComponent.velocity:len()

				if forwardPressed then
					velocityComponent.velocity.x = velocityComponent.velocity.x + math.cos(entity.transform.rotation + math.pi / 2) * acceleration
					velocityComponent.velocity.y = velocityComponent.velocity.y + math.sin(entity.transform.rotation + math.pi / 2) * acceleration
				elseif backwardPressed then
					velocityComponent.velocity.x = velocityComponent.velocity.x - math.cos(entity.transform.rotation + math.pi / 2) * acceleration
					velocityComponent.velocity.y = velocityComponent.velocity.y - math.sin(entity.transform.rotation + math.pi / 2) * acceleration
				end

                -- Jump when the jump key is pressed
                if jumpPressed and entity.transform.position.z == 0 then
                    velocityComponent.velocity.z = jump_power
                end
            end,

            UpdateAIMovement = function(self, entity)
                local map = TrackSystem.GetActiveTrack()
                local ai_nodes = map.ai_nodes
                
                if not ai_nodes or #ai_nodes == 0 then
                    return
                end

                self.current_node_index = self.current_node_index or 1
                
                -- Get the current target node
                local target_index = self.current_node_index
                if target_index > #ai_nodes then
                    self.current_node_index = 1  -- Loop back to the first node
                    target_index = 1
                end
                if(self.target_node == nil) then
                    self.target_node = {x = ai_nodes[self.current_node_index].x + Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset), y = ai_nodes[self.current_node_index].y + Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)}
                end

                -- Calculate the direction vector towards the target node
                local dx = self.target_node.x - entity.transform.position.x
                local dy = self.target_node.y - entity.transform.position.y
                local distance = math.sqrt(dx * dx + dy * dy)

                -- Threshold to consider the node as reached
                local threshold = self.ai_config.node_reach_threshold

                if distance < threshold then
                    -- Node reached, target the next node
                    self.current_node_index = self.current_node_index + 1
                    if self.current_node_index > #ai_nodes then
                        self.current_node_index = 1  -- Loop back to the first node
                    end
                    self.target_node = {x = ai_nodes[self.current_node_index].x + Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset), y = ai_nodes[self.current_node_index].y + Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)}
                    dx = self.target_node.x - entity.transform.position.x
                    dy = self.target_node.y - entity.transform.position.y
                    distance = math.sqrt(dx * dx + dy * dy)
                end

                -- Calculate the desired rotation towards the target node
                local desired_r = math.atan2(dy, dx) - math.pi / 2

                -- Calculate angle difference
                local angle_diff = desired_r - entity.transform.rotation
                angle_diff = (angle_diff + math.pi) % (2 * math.pi) - math.pi  -- Normalize to [-π, π]

                -- Smoothly adjust rotation
                local rotation_speed = self.config.turn_speed  -- Adjust multiplier as needed
                if math.abs(angle_diff) < rotation_speed then
                    entity.transform.rotation = desired_r
                else
                    if angle_diff > 0 then
                        entity.transform.rotation = entity.transform.rotation + rotation_speed
                    else
                        entity.transform.rotation = entity.transform.rotation - rotation_speed
                    end
                end

                -- Ensure rotation stays within [0, 2π]
                entity.transform.rotation = (entity.transform.rotation + 2 * math.pi) % (2 * math.pi)

                -- Get the Velocity component
                local velocityComponent = entity:GetComponentOfType("Velocity")
                if not velocityComponent then return end

				-- Accelerate towards the target node
				velocityComponent.velocity.x = velocityComponent.velocity.x + math.cos(entity.transform.rotation + math.pi / 2) * self.config.acceleration
				velocityComponent.velocity.y = velocityComponent.velocity.y + math.sin(entity.transform.rotation + math.pi / 2) * self.config.acceleration
            end,

            Update = function(self, entity, lobby)
                local map = TrackSystem.GetActiveTrack()

				if self.is_npc then
					self:UpdateAIMovement(entity)
                elseif self._entity:IsOwner() then
                    self:PlayerMovement(entity)
					-- follow camera
					CameraSystem.target_entity = entity
                end

                -- slow down when on slow material
                local x = entity.transform.position.x
                local y = entity.transform.position.y
                local material = TrackSystem.CheckMaterial(x, y)
				local velocityComponent = entity:GetComponentOfType("Velocity")
                if material == MaterialTypes.slow or material == MaterialTypes.out_of_bounds or material == MaterialTypes.solid then
					if velocityComponent then
						velocityComponent.velocity.x = velocityComponent.velocity.x * self.config.slow_mult
						velocityComponent.velocity.y = velocityComponent.velocity.y * self.config.slow_mult
					end
                end

                -- if out of bounds, reset position to the nearest AI node
                if material == MaterialTypes.out_of_bounds then
                    local ai_nodes = map.ai_nodes
                    local nearest_node = ai_nodes[1]
                    local min_distance = math.huge
                    for _, node in ipairs(ai_nodes) do
                        local dx = node.x - entity.transform.position.x
                        local dy = node.y - entity.transform.position.y
                        local distance = math.sqrt(dx * dx + dy * dy)
                        if distance < min_distance then
                            min_distance = distance
                            nearest_node = node
                        end
                    end
                    entity.transform.position.x = nearest_node.x
                    entity.transform.position.y = nearest_node.y
                end
            end,
        }
    }
}