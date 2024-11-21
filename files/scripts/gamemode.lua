dofile("mods/evaisa.kart/files/scripts/game.lua")
Game.Init()

gamemodes[#gamemodes+1] = {
	id = "noita_kart",
    name = "Super Noita Kart",
    version = 0.02,
    version_flavor_text = "Demo",
    allow_in_progress_joining = true,
	enable_spectator = false,
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
	binding_register = function(bindings)
        -- Keyboard Bindings
        bindings:RegisterBinding("kart_gameplay_gas", "Gameplay [keyboard]", "Gas", "Key_w", "key", false, true, false, false)
        bindings:RegisterBinding("kart_gameplay_reverse", "Gameplay [keyboard]", "Reverse", "Key_s", "key", false, true, false, false)
        bindings:RegisterBinding("kart_gameplay_left", "Gameplay [keyboard]", "Steer Left", "Key_a", "key", false, true, false, false)
        bindings:RegisterBinding("kart_gameplay_right", "Gameplay [keyboard]", "Steer Right", "Key_d", "key", false, true, false, false)
		bindings:RegisterBinding("kart_gameplay_jump", "Gameplay [keyboard]", "Hop", "Key_SPACE", "key", false, true, false, false)

		bindings:RegisterBinding("kart_spectator_switch_left", "Spectator [keyboard]", "Previous Player", "Key_q", "key", false, true, false, false)
        bindings:RegisterBinding("kart_spectator_switch_right", "Spectator [keyboard]", "Next Player", "Key_e", "key", false, true, false, false)


		-- Controller Bindings
		bindings:RegisterBinding("kart_gameplay_steer_joy", "Gameplay [gamepad]", "Steering (Stick)", "gamepad_left_stick", "axis", false, false, false, true)
		bindings:RegisterBinding("kart_gameplay_gas_joy", "Gameplay [gamepad]", "Gas (Trigger)", "gamepad_left_trigger", "axis", false, false, false, true)
		bindings:RegisterBinding("kart_gameplay_reverse_joy", "Gameplay [gamepad]", "Reverse (Trigger)", "gamepad_right_trigger", "axis", false, false, false, true)
		bindings:RegisterBinding("kart_gameplay_jump_joy", "Gameplay [gamepad]", "Hop (Button)", "gamepad_a", "button", false, false, false, true)

		bindings:RegisterBinding("kart_spectator_switch_left_joy", "Spectator [gamepad]", "Previous Player", "JOY_BUTTON_LEFT_SHOULDER", "button", false, false, false, true)
		bindings:RegisterBinding("kart_spectator_switch_right_joy", "Spectator [gamepad]", "Next Player", "JOY_BUTTON_RIGHT_SHOULDER", "button", false, false, false, true)

    end,
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
	start = function(lobby, was_in_progress)
		Game.LoadMap(lobby, "map0")
		if(was_in_progress)then
			Networking.send.request_entities()
		end
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
		Game.Disconnected(lobby, player)
	end,
	received = function(lobby, event, message, user)
		if Networking.receive[event] == nil then
			return
		end
		Networking.receive[event](lobby, message, user)
	end,
}