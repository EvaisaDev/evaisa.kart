function OnPlayerSpawned(player)
	EntityKill(player)
end

ModMagicNumbersFileAdd("mods/evaisa.kart/files/magic.xml")

if(ModIsEnabled("evaisa.mp"))then
	ModLuaFileAppend("mods/evaisa.mp/data/gamemodes.lua", "mods/evaisa.kart/files/scripts/gamemode.lua")
end

function OnWorldPreUpdate()
    if(not ModIsEnabled("evaisa.mp"))then
        GamePrint("This gamemode requires the mod 'evaisa.mp' (Noita Online) to be enabled.")
    end
	GameSetCameraPos(0, 0)
end

function OnWorldPostUpdate()
	GameSetCameraPos(0, 0)
end