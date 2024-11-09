dofile("mods/evaisa.kart/files/scripts/game.lua")
Game.Init()

gamemodes[#gamemodes+1] = {
	id = "noita_kart",
    name = "Super Noita Kart",
    version = 0.01,
    version_flavor_text = "Demo",
    allow_in_progress_joining = false,
	settings = {
		{
            id = "npcs",
            name = "NPC Drivers",
            description = "Fill empty player slots with NPCs",
            type = "bool",
            default = true
        },  
		{
            id = "kart_collisions",
            name = "Kart Collisions",
            description = "Players can collide with each other",
            type = "bool",
            default = true
        },  
	},
	refresh = function(lobby)

		local npcs = steam.matchmaking.getLobbyData(lobby, "setting_npcs")
		if (npcs == nil) then
			npcs = "true"
		end
		if(npcs == "true")then
			GameAddFlagRun("npcs")
		else
			GameRemoveFlagRun("npcs")
		end

		local kart_collisions = steam.matchmaking.getLobbyData(lobby, "setting_kart_collisions")
        if (kart_collisions == nil) then
            kart_collisions = "true"
        end
        if(kart_collisions == "true")then
            GameAddFlagRun("kart_collisions")
        else
            GameRemoveFlagRun("kart_collisions")
        end
	end,
	enter = function(lobby)
	end,
	start = function(lobby)
		Game.LoadMap(lobby, "map0")



	end,
	update = function(lobby)
		Game.Update()
	end,
	lobby_update = function(lobby)
    end,
	late_update = function(lobby)
	end,
	leave = function(lobby)
    end,
	disconnected = function(lobby, player)
	end,
	received = function(lobby, event, message, user)
		Networking.receive[event](lobby, message, user)
	end,
}