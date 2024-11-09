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
		end
	},
	send = {
		entity_spawn = function(entityType, networkId)
			steamutils.send("entity_spawn", {entityType, networkId}, steamutils.messageTypes.OtherPlayers, nil, true, true)
		end,
		component_update = function(networkId, componentId, data)
			steamutils.send("entity_update", {networkId, componentId, data}, steamutils.messageTypes.OtherPlayers, nil, true, true)
		end
	}
}