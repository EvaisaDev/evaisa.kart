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
		uid = "tablet_kart",
		type = TextureTypes.directional_billboard,
		path = "mods/evaisa.kart/files/textures/racers/tablet.png", -- this is used to generate the sprite sheet
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
	},
	{
		uid = "smoke",
		type = TextureTypes.billboard,
		defs = {
			{
				path = "data/particles/smoke_cloud_tiny_grey_1.xml",
			},
			{
				path = "data/particles/smoke_cloud_tiny_grey_2.xml",
			},			
		},
	},
	{
		uid = "glyphs",
		type = TextureTypes.billboard,
		path = "mods/evaisa.kart/files/textures/misc/glyphs.png",
		animations = {
			default = {
				pos_x=0,
				pos_y=0,
				frame_count=26,
				frame_width=7,
				frame_height=9,
				frame_wait=0.04,
				frames_per_row=26,
				loop=true,
			},
		},
		default_animation = "default",
	},
	{
		uid = "lakitu",
		type = TextureTypes.billboard,
		path = "mods/evaisa.kart/files/textures/misc/lakitu.png",
		animations = {
			flag = {
				pos_x=0,
				pos_y=0,
				frame_count=3,
				frame_width=42,
				frame_height=34,
				frame_wait=1,
				frames_per_row=3,
				loop=true,
			},
			wrong_way = {
				pos_x=0,
				pos_y=34,
				frame_count=2,
				frame_width=42,
				frame_height=34,
				frame_wait=1,
				frames_per_row=2,
				loop=true,
			}
		},
		default_animation = "flag",
	},
}