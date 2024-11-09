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

local Structs = {}
Structs.Transform = ffi.typeof("Transform")
Structs.Velocity = ffi.typeof("Velocity")

return Structs