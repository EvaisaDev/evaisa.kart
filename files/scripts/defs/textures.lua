TextureTypes = {
	billboard = 1,
	directional_billboard = 2,
	floor = 3,
}

texture_definitions = {
	{
		uid = "rotta_kart",
		type = TextureTypes.directional_billboard,
		path = "mods/evaisa.kart/files/textures/racers/rotta.png", -- this is used to generate the sprite sheet
		rotations = 12,
		sprite_width = 32,
		sprite_height = 32,
		shrink_by_one_pixel = "0",
		offset_x = 16,
		offset_y = 32,
		side_index = 8
	},
	{
		uid = "tree1",
		type = TextureTypes.billboard,
		defs = {
			{
				path = "mods/evaisa.kart/files/textures/objects/vegetation/tree_spruce_1.png",
				offset_x = 36,
				offset_y = 135,
			},
			{
				path = "mods/evaisa.kart/files/textures/objects/vegetation/tree_spruce_2.png",
				offset_x = 43,
				offset_y = 129,
			},
			{
				path = "mods/evaisa.kart/files/textures/objects/vegetation/tree_spruce_3.png",
				offset_x = 43,
				offset_y = 118,
			},
			{
				path = "mods/evaisa.kart/files/textures/objects/vegetation/tree_spruce_4.png",
				offset_x = 51,
				offset_y = 132,
			},
		}
	}
}