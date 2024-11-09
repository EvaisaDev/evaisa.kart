Networking = {
	receive = {
		entity_spawn = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				EntitySystem.NetworkLoad(message[1], message[2], message[3] and steam.utils.decompressSteamID(message[3]) or nil)
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
				local entity = EntitySystem.GetEntityByNetworkId(message)
				if entity then
					entity:Destroy()
				end
			end
		end,
		entity_request_spawn = function(lobby, message, user)
			if not steamutils.IsOwner(user) then
				-- get entity by network id 
				local entity = EntitySystem.GetEntityByNetworkId(message)
				if entity then
					entity:NetworkSpawn(user)
				end
			end
		end,
		update_owner = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				local entity = EntitySystem.GetEntityByNetworkIdOrRequestSpawn(message[1])
				if entity then
					entity._owner = steam.utils.decompressSteamID(message[2])
				end
			end
		end
	},
	send = {
		entity_spawn = function(entityType, networkId, target, owner)
			if(not target)then
				steamutils.send("entity_spawn", {entityType, networkId, steam.utils.compressSteamID(owner)}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
			else
				steamutils.sendToPlayer("entity_spawn", {entityType, networkId, steam.utils.compressSteamID(owner)}, target, true, true)
			end
		end,
		component_update = function(networkId, componentId, data)
			steamutils.send("component_update", {networkId, componentId, data}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		entity_destroy = function(networkId)
			steamutils.send("entity_destroy", networkId, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end,
		entity_request_spawn = function(networkId)
			steamutils.send("entity_request_spawn", networkId, steamutils.messageTypes.Owner, lobby_code, true, true)
		end,
		update_owner = function(networkId, owner)
			steamutils.send("update_owner", {networkId, steam.utils.compressSteamID(owner)}, steamutils.messageTypes.OtherPlayers, lobby_code, true, true)
		end
	}
}