-- entity_system.lua
dofile("mods/evaisa.kart/files/scripts/utilities.lua")
dofile("mods/evaisa.kart/files/scripts/component_system.lua")

-- Entity system table
EntitySystem = {}
EntitySystem.entities = {}
EntitySystem.entitiesByNetworkId = {}
EntitySystem.nextId = 1
EntitySystem.nextNetworkId = 1
EntitySystem.uidMap = {}
EntitySystem.networkLoadQueue = {}

-- Entity creation function
function EntitySystem.Create(name)
    local entity = {
		is_entity = true,
        _id = EntitySystem.nextId,
		_owner = steamutils.getSteamID(),
        _components = {
			ComponentSystem.CreateComponent("Transform")
		},
		_name = name or ("Entity" .. EntitySystem.nextId),
		_parent = nil,
		_children = {},

		Update = function(self, lobby)
			-- update all components
			for index, component in ipairs(self._components) do
				if component.Update and component._enabled then
					component:Update(self, lobby)
				end
				if(self:IsOwner() and component.NetworkSerialize and self.network_id and GameGetFrameNum() % (component.update_rate or 1) == 0)then
					local network_data = component:NetworkSerialize(self, lobby)
					-- implement networking stuff here
					Networking.send.component_update(self.network_id, index, network_data)
				end
			end
			if(steamutils.IsOwner() and self.network_id)then
				Networking.send.entity_check(self.network_id)
			end
		end,
		ComponentSync = function(self, componentId, data)
			local component = self._components[componentId]
			if component then
				if(component.NetworkDeserialize)then
					component:NetworkDeserialize(self, data)
				end
			end
		end,

		-- Add a component to the entity
		AddComponent = function(self, componentType, data)
			if ComponentSystem[componentType] then
				local component = ComponentSystem.CreateComponent(componentType)
				for key, value in pairs(data or {}) do
					component[key] = value
				end
				component._entity = self
				table.insert(self._components, component)
			else
				error("Component type " .. componentType .. " not found.")
			end
		end,

		-- Remove a component from the entity
		RemoveComponent = function(self, componentRef)
			for i, component in ipairs(self._components) do
				if component == componentRef then
					table.remove(self._components, i)
					return
				end
			end
		end,

		-- Remove all components of type
		RemoveComponentsOfType = function(self, componentType)
			for i = #self._components, 1, -1 do
				if self._components[i]._type == componentType then
					table.remove(self._components, i)
				end
			end
		end,

		-- Get a components of type
		GetComponentsOfType = function(self, componentType)
			local components = {}
			for _, component in ipairs(self._components) do
				if component._type == componentType then
					table.insert(components, component)
				end
			end
			return components
		end,

		-- Get first component of type
		GetComponentOfType = function(self, componentType)
			for _, component in ipairs(self._components) do
				if component._type == componentType then
					return component
				end
			end
			return nil
		end,

		-- Set name
		SetName = function(self, name)
			self._name = name
		end,

		-- Get name
		GetName = function(self)
			return self._name
		end,

		-- Get Transform
		GetTransform = function(self)
			return self:GetComponentOfType("Transform")
		end,

        -- Destroy the entity
        Destroy = function(self)
			-- destroy all components
			for _, component in ipairs(self._components) do
				if component.Destroy then
					component:Destroy(self)
				end
			end
			if(self.network_id)then
				EntitySystem.entitiesByNetworkId[self.network_id] = nil
				Networking.send.entity_destroy(self.network_id)
			end
			
            EntitySystem.entities[self._id] = nil
			
        end,
		NetworkSpawn = function(self, target)
			-- check if we have a network id
			if(not self.network_id)then
				-- generate network id
				self.network_id = EntitySystem.nextNetworkId
				
				EntitySystem.entitiesByNetworkId[self.network_id] = self
				EntitySystem.nextNetworkId = EntitySystem.nextNetworkId + 1
			end
			print("Spawning entity with id: " .. self.network_id)
			Networking.send.entity_spawn(self._type, self.network_id, target, self._owner)
		end,
		IsOwner = function(self)
			if(self._owner == steamutils.getSteamID())then
				return true
			end
			return false
		end,
		GetOwner = function(self)
			return self._owner
		end,
		SetOwner = function(self, owner)
			self._owner = owner
			Networking.send.update_owner(self.network_id, owner)
		end,
		SetParent = function(self, parent)
			self._parent = parent
			table.insert(parent._children, self)
		end,
		GetParent = function(self)
			return self._parent
		end,
		GetChildren = function(self)
			return self._children
		end,
		RemoveFromParent = function(self)
			if(self._parent)then
				for i, child in ipairs(self._parent._children) do
					if(child == self)then
						table.remove(self._parent._children, i)
						self._parent = nil
						return
					end
				end
			end
		end,
		GetComponents = function(self)
			return self._components
		end

    }

	entity.transform = entity:GetComponentOfType("Transform")

    EntitySystem.entities[EntitySystem.nextId] = entity
    EntitySystem.nextId = EntitySystem.nextId + 1
    return entity
end

function EntitySystem.Load(entityData)
	local entity = EntitySystem.Create(entityData.name)
	for _, componentData in ipairs(entityData.components) do
		entity:AddComponent(componentData.type, componentData.data)
	end
	return entity
end

dofile("mods/evaisa.kart/files/scripts/defs/entities.lua")

function EntitySystem.Init()
	for _, data in ipairs(entity_definitions) do
		EntitySystem.uidMap[data.uid] = data
	end
end

function EntitySystem.FromType(entityType)
	local data = EntitySystem.uidMap[entityType]
	if data then
		local entity = EntitySystem.Load(data)
		entity._type = entityType
		return entity
	end

	return nil
end

-- Define the grid size based on your game's scale and entity distribution
local GRID_SIZE = 50  -- Adjust as needed for optimal performance

-- Persistent spatial grid
local spatialGrid = {}  -- Key: cell coordinates, Value: table of entities in that cell

-- Initialize entities in the grid (run once at the start or when entities are created)
function InitializeSpatialGrid(entities)
    for _, entity in pairs(entities) do
        AddEntityToGrid(entity)
    end
end

-- Function to add an entity to the grid
function AddEntityToGrid(entity)
    local collider = entity:GetComponentOfType("Collider")
    if collider then
        local position = entity.transform.position
        local cell_x = math.floor(position.x / GRID_SIZE)
        local cell_y = math.floor(position.y / GRID_SIZE)
        local cell_key = cell_x .. "_" .. cell_y
        if not spatialGrid[cell_key] then
            spatialGrid[cell_key] = {}
        end
        spatialGrid[cell_key][entity._id] = entity
        entity._gridCell = cell_key  -- Store cell key in entity for quick reference
    end
end

-- Function to remove an entity from the grid
function RemoveEntityFromGrid(entity)
    local cell_key = entity._gridCell
    if cell_key and spatialGrid[cell_key] then
        spatialGrid[cell_key][entity._id] = nil
        if next(spatialGrid[cell_key]) == nil then
            spatialGrid[cell_key] = nil  -- Remove empty cell
        end
    end
    entity._gridCell = nil
end

-- Function to update an entity's position in the grid
function UpdateEntityInGrid(entity)
    local collider = entity:GetComponentOfType("Collider")
    if collider then
        local old_cell_key = entity._gridCell
        local position = entity.transform.position
        local cell_x = math.floor(position.x / GRID_SIZE)
        local cell_y = math.floor(position.y / GRID_SIZE)
        local new_cell_key = cell_x .. "_" .. cell_y

        if old_cell_key ~= new_cell_key then
            -- Entity has moved to a new cell
            RemoveEntityFromGrid(entity)
            AddEntityToGrid(entity)
        end
    end
end

-- Update function called once per frame
function EntitySystem.UpdateCollisions()
    -- Assuming 'EntitySystem.entities' is a table of entities
    local all_entities = EntitySystem.entities

    -- Update grid positions for all entities (you can optimize this by only updating moving entities)
    for _, entity in pairs(all_entities) do
        UpdateEntityInGrid(entity)
    end

    -- Keep track of already checked pairs to avoid duplicates
    local checked_pairs = {}

    -- Perform collision checks
    for _, entity in pairs(all_entities) do
        local collider = entity:GetComponentOfType("Collider")
        if collider then
            local position = entity.transform.position
            local cell_x = math.floor(position.x / GRID_SIZE)
            local cell_y = math.floor(position.y / GRID_SIZE)

            -- Check neighboring cells (-1 to 1 in both x and y directions)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local neighbor_cell_x = cell_x + dx
                    local neighbor_cell_y = cell_y + dy
                    local cell_key = neighbor_cell_x .. "_" .. neighbor_cell_y
                    local cell_entities = spatialGrid[cell_key]
                    if cell_entities then
                        for _, other_entity in pairs(cell_entities) do
                            if other_entity ~= entity then
                                local pair_id = math.min(entity._id, other_entity._id) .. "_" .. math.max(entity._id, other_entity._id)
                                if not checked_pairs[pair_id] then
                                    checked_pairs[pair_id] = true
                                    local other_collider = other_entity:GetComponentOfType("Collider")
                                    if other_collider and collider:Intersects(other_collider) then
									-- Collision response code
										if not other_collider.is_trigger and not collider.is_trigger then
											local other_velocity = other_entity:GetComponentOfType("Velocity")
											local self_velocity = entity:GetComponentOfType("Velocity")

											-- Compute normal and relative velocity
											local normal = (entity.transform.position - other_entity.transform.position):normalize()
											local relative_velocity = (self_velocity and self_velocity.velocity or Vector.Zero())
											if other_velocity then
												relative_velocity = relative_velocity - other_velocity.velocity
											end

											local separating_velocity = relative_velocity:dot(normal)
											if separating_velocity < 0 then
												local restitution = math.min(collider.restitution, other_collider.restitution)
												local new_sep_velocity = -separating_velocity * restitution
												local delta_velocity = new_sep_velocity - separating_velocity

												-- Handle infinite mass (mass == 0)
												local total_inverse_mass = 0
												if collider.mass > 0 then
													total_inverse_mass = total_inverse_mass + 1 / collider.mass
												end
												if other_collider.mass > 0 then
													total_inverse_mass = total_inverse_mass + 1 / other_collider.mass
												end

												-- Avoid division by zero
												if total_inverse_mass > 0 then
													local impulse = delta_velocity / total_inverse_mass
													local impulse_per_mass = normal * impulse

													if self_velocity and collider.mass > 0 then
														self_velocity.velocity = self_velocity.velocity + impulse_per_mass / collider.mass
													end
													if other_velocity and other_collider.mass > 0 then
														other_velocity.velocity = other_velocity.velocity - impulse_per_mass / other_collider.mass
													end
												end
											end

										end


                                        -- Trigger OnCollision event
                                        if collider.OnCollision then
                                            collider:OnCollision(other_collider)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end



function EntitySystem.NetworkLoad(entityType, networkId, owner)
	print("Network load entity: " .. entityType .. " with id: " .. networkId)
	local entity = EntitySystem.FromType(entityType)
	if entity then
		entity.network_id = networkId
		entity._owner = owner
		EntitySystem.entitiesByNetworkId[networkId] = entity
		return entity
	end

	return nil
end


function EntitySystem.NetworkSpawn(entityType, owner)
	local entity = EntitySystem.NetworkLoad(entityType, EntitySystem.nextNetworkId, owner)
	if entity then

		Networking.send.entity_spawn(entityType, EntitySystem.nextNetworkId, entity._owner)

		EntitySystem.nextNetworkId = EntitySystem.nextNetworkId + 1

		return entity
	end
	return nil
end


function EntitySystem.GetEntityByNetworkId(networkId)
	return EntitySystem.entitiesByNetworkId[networkId]
end

function EntitySystem.GetEntityByNetworkIdOrRequestSpawn(networkId)
	local entity = EntitySystem.GetEntityByNetworkId(networkId)
	if not entity then
		Networking.send.entity_request_spawn(networkId)
	end
	return entity
end

function EntitySystem.FromColor(color)
	for _, data in ipairs(entity_definitions) do
		if data.spawn_color then
			if data.spawn_color[1] == color[1] and data.spawn_color[2] == color[2] and data.spawn_color[3] == color[3] then
				return EntitySystem.Load(data)
			end
		end
	end
	return nil
end


-- Get all entities
function EntitySystem.GetAllEntities()
    return EntitySystem.entities
end

function EntitySystem.KillAll()
	local entities = EntityGetInRadius(0, 0, math.huge)
	for _, entity in ipairs(entities) do
		local name = EntityGetName(entity)
		-- if name starts with billboard, kill
		if string.sub(name, 1, 9) == "billboard" then
			EntityKill(entity)
		end
	end

	for _, entity in pairs(EntitySystem.entities) do
		entity:Destroy()
	end
end