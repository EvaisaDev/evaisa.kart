local ffi = require("ffi")
-- cdef memcmp
ffi.cdef[[
    int memcmp(const void *s1, const void *s2, size_t n);
]]
local memcmp = ffi.C.memcmp

ffi.cdef([[
#pragma pack(push, 1)
typedef struct A {
    float x;
    float y;
	float z;
	float r;
} Transform;
#pragma pack(pop)
]])

ffi.cdef[[
#pragma pack(push, 1)
typedef struct B {
	float x;
	float y;
	float z;
} Velocity;
#pragma pack(pop)
]]

--[[
			is_npc = false,
			player_id = 0,
			current_node = nil,   
			next_checkpoint = 1,     
			last_checkpoint = nil,
			last_rotation = 0,
			wrongway_delay = 50,
			wrongway_timer = 0,
			was_wrongway = false,
]]

ffi.cdef[[
#pragma pack(push, 1)
typedef struct C {
	bool is_npc;
	int player_id;
	int next_checkpoint;
	int last_checkpoint;
	float last_rotation;
	int wrongway_delay;
	int wrongway_timer;
	bool was_wrongway;
} Kart;
#pragma pack(pop)
]]

local Structs = {}
Structs.Transform = ffi.typeof("Transform")
Structs.Velocity = ffi.typeof("Velocity")
Structs.Kart = ffi.typeof("Kart")

return Structs