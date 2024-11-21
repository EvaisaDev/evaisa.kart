local Module = {}

local original_pairs = pairs

-- Override the global pairs function
function pairs(t)
    local mt = getmetatable(t)
    if mt and mt.__pairs then
        return mt.__pairs(t)
    else
        return original_pairs(t)
    end
end

function Module.new(init_vars, component)
    local self = {}
    local internal = {
		component = component,
		entity = component._entity,
	}
    local data_store = init_vars or {}

    -- Assign a metatable with metamethods to the instance
    setmetatable(self, {
        __index = function(table, key)

			return data_store[key]
	
        end,
        __newindex = function(table, key, value)
            local entity = internal.entity
			data_store[key] = value
            if entity and entity.IsOwner and entity:IsOwner() then
                Networking.send.set_network_var(
                    entity.network_id,
                    internal.component._id,
                    key,
                    value
                )
            else
                -- Handle the case where entity is nil or not the owner
            end
        end,
        __pairs = function(table)
            -- Loop over data_store
            return next, data_store, nil
        end,
    })

    return self
end

function Module.get_instance_function(init_vars)
	return function(component)
		if(init_vars and type(init_vars) == "table")then
			return Module.new(Utilities.deepCopy(init_vars), component)
		elseif init_vars and type(init_vars) == "function" then
			return Module.new(init_vars(component), component)
		else
			return Module.new({}, component)
		end
	end
end

-- Allow initialization by calling Module directly
setmetatable(Module, {
    __call = function(cls, init_vars)
        return cls.get_instance_function(init_vars)
    end,
})

return Module
