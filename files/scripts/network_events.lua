Networking = {
	receive = {
		entity_spawn = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				EntitySystem.NetworkLoad(message[1], message[2])
			end
		end,
		component_update = function(lobby, message, user)
			if steamutils.IsOwner(user) then
				local entity = EntitySystem.GetEntityByNetworkId(message[1])
				if entity then
					entity:NetworkSyncComponent(message[2], message[3])
				end
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
		end
	},
	send = {
		entity_spawn = function(entityType, networkId, target)
			if(not target)then
				steamutils.send("entity_spawn", {entityType, networkId}, steamutils.messageTypes.OtherPlayers, nil, true, true)
			else
				steamutils.sendToPlayer("entity_spawn", {entityType, networkId}, target, nil, true, true)
			end
		end,
		component_update = function(networkId, componentId, data)
			steamutils.send("entity_update", {networkId, componentId, data}, steamutils.messageTypes.OtherPlayers, nil, true, true)
		end,
		entity_destroy = function(networkId)
			steamutils.send("entity_destroy", networkId, steamutils.messageTypes.OtherPlayers, nil, true, true)
		end,
		entity_request_spawn = function(networkId)
			steamutils.send("entity_request_spawn", networkId, steamutils.messageTypes.Owner, nil, true, true)
		end
	}
}