component_definitions = {
    {
        name = "Transform",
        default_data = {
            position = Vector3(0, 0, 0),
            rotation = 0,
            scale = Vector(1, 1),
			update_rate = 1, -- 1 = every frame, 2 = every other frame, etc.
			inherit_transform = false,
            GetPosition = function(self)
                return self.position
            end,
            SetPosition = function(self, x, y, z)
                if(type(x) == "table")then
                    self.position = x
                else
                    if(x)then
                        self.position.x = x
                    end
                    if(y)then
                        self.position.y = y
                    end
					if(z)then
						self.position.z = z
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
				return Structs.Transform{
					x = self.position.x,
					y = self.position.y,
					z = self.position.z,
					r = self.rotation
				}
			end,
			NetworkDeserialize = function(self, lobby, data)
				-- apply data
				self.position.x = data.x
				self.position.y = data.y
				self.position.z = data.z
				self.rotation = data.r
			end,
			Update = function(self, entity, lobby)
				if(self.inherit_transform)then
					local parent = entity:GetParent()
					if(parent)then
						local parent_transform = parent:GetComponentOfType("Transform")
						if(parent_transform)then
							self.position = parent_transform.position:clone()
							self.rotation = parent_transform.rotation
							self.scale = parent_transform.scale:clone()
						end
					end
				end
			end
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
				--[[
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
				]]
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
			NetworkSerialize = function(self, lobby)
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
			end,
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
			debug = false,
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

				-- draw debug cross for sprite
				if(RenderingSystem.debug_gizmos or self.debug)then
					RenderingSystem.DrawLine(Vector3(entity.transform.position.x - 5, entity.transform.position.y, 0), Vector3(entity.transform.position.x + 5, entity.transform.position.y, 0), 0.5, 255, 0, 0)
					RenderingSystem.DrawLine(Vector3(entity.transform.position.x, entity.transform.position.y - 5, 0), Vector3(entity.transform.position.x, entity.transform.position.y + 5, 0), 0.5, 255, 0, 0)
				end
            end,
        }
    },
	{
		name = "Text",
		default_data = {
			offset_x = 0,
			offset_y = 0,
			offset_z = 0,
			text = "",
			font = nil,
			is_pixel_font = nil,
			size = 1,
			color = {255, 255, 255, 255},
			centered_x = true,
			centered_y = true,
			Update = function(self, entity, lobby)
				local position = entity.transform.position:clone()
				position.x = position.x + self.offset_x
				position.y = position.y + self.offset_y
				position.z = position.z + self.offset_z

				local r = self.color[1] / 255
				local g = self.color[2] / 255
				local b = self.color[3] / 255
				local a = self.color[4] / 255

				RenderingSystem.DrawText(self.text, position, self.size, self.centered_x, self.centered_y, r, g, b, a, self.font, self.is_pixel_font)
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
				deceleration = 0.1,  -- Rate at which the kart should decelerate
			},
			ai_config = {
				node_reach_threshold = 60,
				node_random_offset = 15,
				max_turn_speed = 0.8,
			},
			is_npc = false,
			player_id = 0,
			current_node = nil,         -- The current node the AI is moving towards
			next_checkpoint = 1,     
	
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
				local track = TrackSystem.GetActiveTrack()
				if not track then return end
			
				local x = entity.transform.position.x
				local y = entity.transform.position.y
			
				SetRandomSeed(x + GameGetFrameNum(), y)
			
				-- If the AI doesn't have a current node, find the closest node to its position
				if not self.current_node then
					self.current_node = TrackSystem.FindClosestNode(x, y, TrackSystem.current_track)
					self.current_offset_x = Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)
					self.current_offset_y = Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)
				end
			
				local current_node = self.current_node
				if not current_node then return end
			
				-- Calculate direction to the current node
				local dx = (current_node.x + self.current_offset_x) - x
				local dy = (current_node.y + self.current_offset_y) - y
				local distance_sq = dx * dx + dy * dy
			
				-- Check if the AI has reached the current node
				local reach_threshold_sq = self.ai_config.node_reach_threshold * self.ai_config.node_reach_threshold
				if distance_sq < reach_threshold_sq then
					-- Choose the next node(s)
					local next_nodes = TrackSystem.GetNextNodes(current_node)
					if #next_nodes > 0 then
						-- Randomly select one of the next nodes
						local random_index = Random(1, #next_nodes)
						self.current_node = next_nodes[random_index]
						self.current_offset_x = Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)
						self.current_offset_y = Random(-self.ai_config.node_random_offset, self.ai_config.node_random_offset)
					else
						-- If no next nodes (end of path), loop back to the first node
						self.current_node = track.nodes[1]
					end
					-- Update direction to new current node
					dx = (self.current_node.x + self.current_offset_x) - x
					dy = (self.current_node.y + self.current_offset_y) - y
				end
			
				-- Calculate the desired rotation towards the current node
				local desired_r = math.atan2(dy, dx) - math.pi / 2
			
				-- Calculate angle difference
				local angle_diff = desired_r - entity.transform.rotation
				angle_diff = (angle_diff + math.pi) % (2 * math.pi) - math.pi  -- Normalize to [-π, π]
			
				-- Smoothly adjust rotation
				local rotation_speed = self.config.turn_speed
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
			
				-- Determine velocity adjustment based on sharpness of turn and current speed
				local velocityComponent = entity:GetComponentOfType("Velocity")
				if not velocityComponent then return end
			
				local next_nodes = TrackSystem.GetNextNodes(current_node)
				local adjusted_acceleration = self.config.acceleration
			
				if #next_nodes > 0 then
					local next_node = next_nodes[1]
					local future_dx = next_node.x - current_node.x
					local future_dy = next_node.y - current_node.y
					local future_angle = math.atan2(future_dy, future_dx) - math.pi / 2
					local future_angle_diff = (future_angle - desired_r + math.pi) % (2 * math.pi) - math.pi
			
					-- Only slow down for sharp turns based on current speed and sharpness
					local turn_sharpness = math.abs(future_angle_diff)
					local max_sharpness = math.pi / 2  -- Define what is considered a "sharp turn"
					local current_speed_sq = velocityComponent.velocity.x * velocityComponent.velocity.x + velocityComponent.velocity.y * velocityComponent.velocity.y
					local max_speed_for_turn = self.ai_config.max_turn_speed
			
					if turn_sharpness > 0.3 and current_speed_sq > max_speed_for_turn * max_speed_for_turn then
						local slow_down_factor = math.min(1, turn_sharpness / max_sharpness)
						adjusted_acceleration = adjusted_acceleration * (1 - slow_down_factor)
					end
				end
			
				-- Apply adjusted velocity
				velocityComponent.velocity.x = velocityComponent.velocity.x + math.cos(entity.transform.rotation + math.pi / 2) * adjusted_acceleration
				velocityComponent.velocity.y = velocityComponent.velocity.y + math.sin(entity.transform.rotation + math.pi / 2) * adjusted_acceleration
			end,
			
	
			Update = function(self, entity, lobby)
				local map = TrackSystem.GetActiveTrack()
				if not map then return end
	
				local x = entity.transform.position.x
				local y = entity.transform.position.y
	
				if self.is_npc then
					self:UpdateAIMovement(entity)
				elseif self._entity:IsOwner() then
					self:PlayerMovement(entity)
	
					-- Follow camera
					CameraSystem.target_entity = entity
					if(RenderingSystem.debug_gizmos)then
						-- track checkpoints
						TrackSystem.DrawCheckpoint(self.next_checkpoint)
					end
				end
	
				

				-- Check if the kart has passed a checkpoint
				if(TrackSystem.CheckCheckpoint(x, y, self.next_checkpoint))then
					self.next_checkpoint = self.next_checkpoint + 1
					if self.next_checkpoint > #map.checkpoint_zones then
						self.next_checkpoint = 1
					end
				end

				
	
				local material = TrackSystem.CheckMaterial(x, y)
				local velocityComponent = entity:GetComponentOfType("Velocity")
				if material == MaterialTypes.slow or material == MaterialTypes.out_of_bounds or material == MaterialTypes.solid then
					if velocityComponent then
						velocityComponent.velocity.x = velocityComponent.velocity.x * self.config.slow_mult
						velocityComponent.velocity.y = velocityComponent.velocity.y * self.config.slow_mult
					end
				end
			end,
		}
	}

}