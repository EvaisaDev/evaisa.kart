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