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
						if(GameGetFrameNum() % 20 == 0 and not entity:GetComponentOfType("Kart").is_npc and not self._entity:IsOwner())then
							self.text = steam_utils.getTranslatedPersonaName(entity._owner)
						end
						orig(self, entity, lobby)
						
					end
				}
			},
			{
				type = "ParticleEmitter",
				data = {
					tags = {
						tire_smoke = true
					},
					emitter_data = {
						["velocity_min_y"] = -0.5,
						["rotation"] = 0,
						["velocity_max_x"] = 0.5,
						["sprite_random_rotation"] = true,
						["rotation_speed"] = 0,
						["count_min"] = 1,
						["lifetime_max"] = 30,
						["velocity_min_z"] = 0.30000001192093,
						["lifetime_min"] = 20,
						["alpha_over_lifetime"] = true,
						["max_offset_x"] = 1,
						["scale_min"] = 0.20000000298023,
						["emitting"] = false,
						["spawn_in_sphere"] = false,
						["texture"] = "smoke",
						["min_offset_z"] = 0,
						["max_offset_y"] = 1,
						["count_max"] = 1,
						["min_offset_x"] = -1,
						["interval_min_frames"] = 0,
						["velocity_min_x"] = -0.5,
						["velocity_max_z"] = 0.20000000298023,
						["scale_max"] = 1,
						["use_velocity_as_rotation"] = true,
						["sphere_min_radius"] = 0,
						["interval_max_frames"] = 0,
						["sphere_max_radius"] = 10,
						["velocity_max_y"] = 0.5,
						["min_offset_y"] = -1,
						["max_offset_z"] = 0,
					},
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
	},
	{
		uid = "lakitu",
		name = "Lakitu",
		components = {
			{	
				type = "Sprite",
				data = {
					texture = "lakitu"
				}
			},
			{
				type = "Lakitu",
				data = {
					spawn_offset = Vector3(200, 20, 145),
					offset = Vector3(0, 20, 45),
					lerp = 0.1,
					wave_speed = 0.03,
					wave_amplitude = 2,
				}
			}
		}
	}
}