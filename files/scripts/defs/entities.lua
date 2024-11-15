entity_definitions = {
	{
		uid = "racer",
		name = "Racer",
		tags = {
			player = true
		},
		components = {
			{
				type = "Sprite",
				data = {
					texture = "rotta_kart"
				}
			},
			{
				type = "Kart",
			},
			{
				type = "Velocity"
			},
			{
				type = "Collider",
				data = {
					tags = {
						player = true
					},
					is_sphere = true,
					radius = 5,
				}
			},
			{
				type = "Text",
				data = {
					tags = {
						nametag = true
					},
					text = "",
					offset_z = 35,
					Update_hook = function(orig, self, entity, lobby)
						if(GameGetFrameNum() % 20 == 0 and not entity:GetComponentOfType("Kart").is_npc)then
							self.text = steam_utils.getTranslatedPersonaName(entity._owner)
						end
						orig(self, entity, lobby)
						
					end
				}
			}
		}
	},
	{
		uid = "tree",
		name = "Tree",
		spawn_color = {112, 238, 22}, -- if this is defined the entity is instantiated from the track entity texture
		components = {
			{	
				type = "Sprite",
				data = {
					texture = "tree1"
				}
			},
			{
				type = "Collider",
				data = {
					is_sphere = true,
					radius = 5,
				}
			}
		}
	}
}