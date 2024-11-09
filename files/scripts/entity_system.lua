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

-- Entity creation function
function EntitySystem.Create(name)
    local entity = {
        _id = EntitySystem.nextId,
        _components = {
			ComponentSystem.CreateComponent("Transform")
		},
		_name = name or ("Entity" .. EntitySystem.nextId),

		Update = function(self, lobby)
			-- update all components
			for index, component in ipairs(self._components) do
				if component.Update and component._enabled then
					component:Update(self, lobby)
					if(component.is_owner and component.NetworkSerialize and self.network_id and GameGetFrameNum() % (self.update_rate or 1) == 0)then
						local network_data = component:NetworkSerialize(self, lobby)
						
						-- implement networking stuff here
						Networking.send.entity_update(self.network_id, index, network_data)
					end
				end
			end
		end,
		NetworkSync = function(self, componentId, data)
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

            EntitySystem.entities[self.id] = nil
        end,
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
		return EntitySystem.Load(data)
	end

	return nil
end

function EntitySystem.NetworkLoad(entityType, networkId)
	local entity = EntitySystem.FromType(entityType)
	if entity then
		entity.network_id = networkId
		EntitySystem.entitiesByNetworkId[networkId] = entity
		return entity
	end

	return nil
end


function EntitySystem.NetworkSpawn(lobby, entityType)
	local entity = EntitySystem.NetworkLoad(entityType, EntitySystem.nextNetworkId)
	if entity then

		Networking.send.entity_spawn(entityType, EntitySystem.nextNetworkId)

		EntitySystem.nextNetworkId = EntitySystem.nextNetworkId + 1

		return entity
	end
	return nil
end


function EntitySystem.GetEntityByNetworkId(networkId)
	return EntitySystem.entitiesByNetworkId[networkId]
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
	for _, entity in pairs(EntitySystem.entities) do
		entity:Destroy()
	end
end