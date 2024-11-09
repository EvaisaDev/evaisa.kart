local vecs = dofile("mods/evaisa.kart/lib/vector.lua")
Vector3 = vecs.Vector3
Vector = vecs.Vector

Structs = dofile("mods/evaisa.kart/files/scripts/defs/structs.lua")

dofile("mods/evaisa.kart/files/scripts/network_events.lua")
dofile("mods/evaisa.kart/files/scripts/entity_system.lua")
dofile("mods/evaisa.kart/files/scripts/rendering_system.lua")
dofile("mods/evaisa.kart/files/scripts/track_system.lua")

Game = {}

Game.Init = function()
	RenderingSystem.GenerateTextures()
	ComponentSystem.Init()
	EntitySystem.Init()
	TrackSystem.Init()
end

Game.Update = function(lobby)
	RenderingSystem.Update()
	for _, entity in ipairs(EntitySystem.entities) do
		entity:Update(lobby)
	end
	CameraSystem.Update()
end

Game.LoadMap = function(lobby, map)
	TrackSystem.LoadTrack(map)
	if(steamutils.IsOwner())then
		Game.SpawnPlayers(lobby)
	end
end

Game.SpawnPlayers = function(lobby)
    local player_ids = {}
	for i = 1, steam.matchmaking.getNumLobbyMembers(lobby) do
		local h = steam.matchmaking.getLobbyMemberByIndex(lobby, i - 1)
        table.insert(player_ids, h)
    end

	local max_players = steam.matchmaking.getLobbyMemberLimit(lobby)
	local fill_with_npcs = GameHasFlagRun("npcs")

	-- New way of spawning players
	local players = {}

	if(fill_with_npcs)then
		local spawn_points = TrackSystem.GetSpawnPoints(max_players)
		for i = 1, max_players do
			-- get spawn point and wrap around if we have more players than spawn points
			local spawn_point = spawn_points[(i % #spawn_points) + 1]
			if(spawn_point)then
				local player = EntitySystem.FromType("racer")
				if(player)then
					player.transform:SetPosition(spawn_point.x, spawn_point.y)
					table.insert(players, player)
				end
			end
		end
	else
		local spawn_points = TrackSystem.GetSpawnPoints(#player_ids)
		for i = 1, #player_ids do
			local spawn_point = spawn_points[(i % #spawn_points) + 1]
			if(spawn_point)then
				local player = EntitySystem.FromType("racer")
				if(player)then
					player.transform:SetPosition(spawn_point.x, spawn_point.y)
					table.insert(players, player)
				end
			end
		end
	end

	print("Player count: " .. #player_ids)

	-- set up the players
	for i, player in ipairs(players) do
		local member = player_ids[i]
		if(member)then
			print("Setting up player: " .. steam_utils.getTranslatedPersonaName(member))	
			-- set ownership
			player:SetOwner(member)
			--player:GetComponentOfType("Kart").player_id = member
			-- check if this is the local player
			--[[if(member._id == c)then
				player:GetComponentOfType("Kart").is_owner = true
				CameraSystem.target_entity = player
			end]]
		else
			player:GetComponentOfType("Kart").is_npc = true
		end
		player:NetworkSpawn(member)
	end

	

end