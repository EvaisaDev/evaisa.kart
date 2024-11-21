Networking = {
	receive = {
		entity_spawn = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				--print("Received entity spawn message for type: " .. tostring(message[1]) .. " with network id: " .. tostring(message[2]))
				-- make sure the entity doesn't already exist
				local entity = EntitySystem.GetEntityByNetworkId(message[2])
				if not entity then
					entity = EntitySystem.NetworkLoad(message[1], message[2], message[3] and steam.utils.decompressSteamID(message[3]) or nil)
				end
				if entity then
					for i = 1, #message[4] do
						entity:ComponentSync(message[4][i][1], message[4][i][2])
					end

					for i = 1, #message[5] do
						for key, value in pairs(message[5][i]) do
							entity:SetNetworkVar(i, key, value)
						end
						
					end
				end
			end
		end,
		component_update = function(lobby, message, user)

			local entity = EntitySystem.GetEntityByNetworkIdOrRequestSpawn(message[1])
			if entity and entity:GetOwner() == user then
				entity:ComponentSync(message[2], message[3])
			end

		end,
		entity_destroy = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				local entity = EntitySystem.GetEntityByNetworkId(message[1])
				if entity then
					entity:Destroy()
				end
			end
		end,
		entity_request_spawn = function(lobby, message, user)
			--print("Received entity spawn request for id: " .. message[1])
			local entity = EntitySystem.GetEntityByNetworkId(message[1])
			if entity then
				--print("Entity already exists, spawning for user: " .. tostring(user))
				entity:NetworkSpawn(lobby, user)
			end
		end,
		update_owner = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				local entity = EntitySystem.GetEntityByNetworkIdOrRequestSpawn(message[1])
				if entity then
					entity._owner = steam.utils.decompressSteamID(message[2])
				end
			end
		end,
		entity_check = function(lobby, message, user)
			if(not steamutils.IsOwner(user))then
				return
			end
			EntitySystem.GetEntityByNetworkIdOrRequestSpawn(message[1])
		end,
		set_network_var = function(lobby, message, user)
			local entity = EntitySystem.GetEntityByNetworkIdOrRequestSpawn(message[1])
			--print("Received set network var message for entity: " .. tostring(entity) .. " with network id: " .. tostring(message[1]) .. " and key: " .. tostring(message[3]) .. " and value: " .. tostring(message[4]))
			
			if entity and entity:GetOwner() == user then
				entity:SetNetworkVar(message[2], message[3], message[4])
			end
		end,
		request_entities = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				for _, entity in pairs(EntitySystem.entitiesByNetworkId) do
					entity:NetworkSpawn(lobby, user)
				end
			end
		end
	},
	send = {
		entity_spawn = function(entityType, networkId, target, owner, component_updates, network_vars)
			--print("Sending entity spawn message for type: " .. tostring(entityType) .. " with network id: " .. tostring(networkId) .. " and owner: " .. tostring(owner))
			if(not target)then
				steamutils.send("entity_spawn", {entityType, networkId, steam.utils.compressSteamID(owner), component_updates, network_vars}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
			else
				steamutils.sendToPlayer("entity_spawn", {entityType, networkId, steam.utils.compressSteamID(owner), component_updates, network_vars}, target, true, true)
			end
		end,
		component_update = function(networkId, componentId, data)
			steamutils.send("component_update", {networkId, componentId, data}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		entity_destroy = function(networkId)
			steamutils.send("entity_destroy", {networkId}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		entity_request_spawn = function(networkId)
			steamutils.send("entity_request_spawn", {networkId}, steamutils.messageTypes.Host, lobby_code, true, true)
		end,
		update_owner = function(networkId, owner)
			steamutils.send("update_owner", {networkId, steam.utils.compressSteamID(owner)}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		entity_check = function(networkId)
			steamutils.send("entity_check", {networkId}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		set_network_var = function(networkId, componentId, key, value)
			steamutils.send("set_network_var", {networkId, componentId, key, value}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		request_entities = function()
			steamutils.send("request_entities", {}, steamutils.messageTypes.Host, lobby_code, true, true)
		end
	}
}