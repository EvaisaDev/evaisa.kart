local w = 8
local h = 8

BiomeMapSetSize( w, h )


for x = 0, w - 1 do
	for y = 0, h - 1 do
        BiomeMapSetPixel( x, y, 0xffebaaaa )
	end
end
