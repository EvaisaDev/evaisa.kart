-- component_system.lua

dofile("mods/evaisa.kart/files/scripts/utilities.lua")

-- Component system table
ComponentSystem = {}

-- Define a new component type
function ComponentSystem.DefineComponent(componentType, defaultData)
    if not ComponentSystem[componentType] then
        ComponentSystem[componentType] = Utilities.deepCopy(defaultData)
		ComponentSystem[componentType]._type = componentType
		ComponentSystem[componentType].SetValue = function(self, key, value)
			self[key] = value
		end
		ComponentSystem[componentType].GetValue = function(self, key)
			return self[key]
		end
		ComponentSystem[componentType].SetActive = function(self, active)
			self._enabled = active
		end
		if(defaultData._enabled ~= nil) then
			ComponentSystem[componentType]._enabled = defaultData._enabled
		else
			ComponentSystem[componentType]._enabled = true
		end
    else
        error("Component type " .. componentType .. " already exists.")
    end
end

-- Get a deep copy of the component data
function ComponentSystem.CreateComponent(componentType)
    if ComponentSystem[componentType] then
        local comp = Utilities.deepCopy(ComponentSystem[componentType])

		return comp
    else
        error("Component type " .. componentType .. " not found.")
    end
end

dofile("mods/evaisa.kart/files/scripts/defs/components.lua")

function ComponentSystem.Init()
	for _, componentData in ipairs(component_definitions) do
		ComponentSystem.DefineComponent(componentData.name, componentData.default_data)
	end
end