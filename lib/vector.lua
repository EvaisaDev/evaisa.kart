-- Rewrite table.concat to allow for any type by implicitly converting using tostring
table.concat = function(t, sep, i, j)
    sep = sep or ""
    i = i or 1
    j = j or #t
    local s = ""
    for k = i, j do
        s = s .. t[k] .. sep  -- Lua automatically calls tostring on non-string types
    end
    -- Remove the trailing separator
    if sep ~= "" and #s >= #sep then
        s = s:sub(1, -#sep-1)
    end
    return s
end

-- 2D Vector Class
Vector = {}
Vector.__index = Vector

function Vector.new(x, y)
	if type(x) == "table" then
		return setmetatable({ x = x.x or 0, y = x.y or 0 }, Vector)
	end

    return setmetatable({ x = x or 0, y = y or 0 }, Vector)
end

-- Metamethods for Vector
function Vector.__add(a, b)
    if type(a) == "number" then
        return Vector.new(b.x + a, b.y + a)
    elseif type(b) == "number" then
        return Vector.new(a.x + b, a.y + b)
    elseif getmetatable(b) == Vector3 then
        return Vector.new(a.x + b.x, a.y + b.y)
    else
        return Vector.new(a.x + b.x, a.y + b.y)
    end
end

function Vector.__sub(a, b)
    if type(a) == "number" then
        return Vector.new(a - b.x, a - b.y)
    elseif type(b) == "number" then
        return Vector.new(a.x - b, a.y - b)
    elseif getmetatable(b) == Vector3 then
        return Vector.new(a.x - b.x, a.y - b.y)
    else
        return Vector.new(a.x - b.x, a.y - b.y)
    end
end

function Vector.__mul(a, b)
    if type(a) == "number" then
        return Vector.new(b.x * a, b.y * a)
    elseif type(b) == "number" then
        return Vector.new(a.x * b, a.y * b)
    elseif getmetatable(b) == Vector3 then
        return Vector.new(a.x * b.x, a.y * b.y)
    else
        return Vector.new(a.x * b.x, a.y * b.y)
    end
end

function Vector.__div(a, b)
    if type(a) == "number" then
        return Vector.new(a / b.x, a / b.y)
    elseif type(b) == "number" then
        return Vector.new(a.x / b, a.y / b)
    elseif getmetatable(b) == Vector3 then
        return Vector.new(a.x / b.x, a.y / b.y)
    else
        return Vector.new(a.x / b.x, a.y / b.y)
    end
end

function Vector.__eq(a, b)
    if getmetatable(b) == Vector3 then
        return a.x == b.x and a.y == b.y
    end
    return a.x == b.x and a.y == b.y
end

function Vector.__lt(a, b)
    if getmetatable(b) == Vector3 then
        return a.x < b.x or (a.x == b.x and a.y < b.y)
    end
    return a.x < b.x or (a.x == b.x and a.y < b.y)
end

function Vector.__le(a, b)
    if getmetatable(b) == Vector3 then
        return a.x <= b.x and a.y <= b.y
    end
    return a.x <= b.x and a.y <= b.y
end

function Vector.__tostring(a)
    return "(" .. a.x .. ", " .. a.y .. ")"
end

function Vector.__concat(a, b)
    return tostring(a) .. tostring(b)
end

-- Vector Methods
function Vector:clone()
    return Vector.new(self.x, self.y)
end

function Vector:unpack()
    return self.x, self.y
end

function Vector:len()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vector:lenSq()
    return self.x * self.x + self.y * self.y
end

function Vector:floor()
    return Vector.new(math.floor(self.x), math.floor(self.y))
end

function Vector:ceil()
    return Vector.new(math.ceil(self.x), math.ceil(self.y))
end

function Vector:round()
    return Vector.new(math.floor(self.x + 0.5), math.floor(self.y + 0.5))
end

function Vector:random()
    return Vector.new(Random(), Random())  -- Ensure Random() is defined elsewhere
end

function Vector:min(other)
    return Vector.new(math.min(self.x, other.x), math.min(self.y, other.y))
end

function Vector:max(other)
    return Vector.new(math.max(self.x, other.x), math.max(self.y, other.y))
end

function Vector:normalize()
    local len = self:len()
    if len == 0 then return self end
    self.x = self.x / len
    self.y = self.y / len
    return self
end

function Vector:normalized()
    local len = self:len()
    if len == 0 then return Vector.new(0, 0) end
    return Vector.new(self.x / len, self.y / len)
end

function Vector:dot(other)
    return self.x * other.x + self.y * other.y
end

function Vector:direction(other)
    return (other - self):normalized()
end

function Vector:lerp(other, t)
    return self + ((other - self) * t)
end

function Vector:rotate(phi)
    local c = math.cos(phi)
    local s = math.sin(phi)
    local newX = c * self.x - s * self.y
    local newY = s * self.x + c * self.y
    self.x = newX
    self.y = newY
    return self
end

function Vector:rotated(phi)
    return self:clone():rotate(phi)
end

function Vector:perpendicular()
    return Vector.new(-self.y, self.x)
end

function Vector:projectOn(other)
    local scalar = self:dot(other) / other:lenSq()
    return other * scalar
end

function Vector:cross(other)
    return self.x * other.y - self.y * other.x
end

function Vector:distance(other)
    return (other - self):len()
end

function Vector:print(name)
    if name then
        print("[" .. name .. "] " .. tostring(self))
    else
        print(tostring(self))
    end
end

function Vector:radian()
    return math.atan2(self.y, self.x)
end

function Vector:GamePrint(name)
    if name then
        print("[" .. name .. "] " .. tostring(self))
    else
        print(tostring(self))
    end
end

setmetatable(Vector, { __call = function(_, ...) return Vector.new(...) end })

-- 3D Vector Class
Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)

	if(type(x) == "table") then
		return setmetatable({ x = x.x or 0, y = x.y or 0, z = x.z or 0, xy = Vector.new(x.x, x.y) }, Vector3)
	end

    return setmetatable({ x = x or 0, y = y or 0, z = z or 0, xy = Vector.new(x, y) }, Vector3)
end

-- Metamethods for Vector3
function Vector3.__add(a, b)
    if type(a) == "number" then
        return Vector3.new(b.x + a, b.y + a, b.z + a)
    elseif type(b) == "number" then
        return Vector3.new(a.x + b, a.y + b, a.z + b)
    elseif getmetatable(b) == Vector then
        return Vector3.new(a.x + b.x, a.y + b.y, a.z)
    else
        return Vector3.new(a.x + b.x, a.y + b.y, a.z + b.z)
    end
end

function Vector3.__sub(a, b)
    if type(a) == "number" then
        return Vector3.new(a - b.x, a - b.y, a - b.z)
    elseif type(b) == "number" then
        return Vector3.new(a.x - b, a.y - b, a.z - b)
    elseif getmetatable(b) == Vector then
        return Vector3.new(a.x - b.x, a.y - b.y, a.z)
    else
        return Vector3.new(a.x - b.x, a.y - b.y, a.z - b.z)
    end
end

function Vector3.__mul(a, b)
    if type(a) == "number" then
        return Vector3.new(b.x * a, b.y * a, b.z * a)
    elseif type(b) == "number" then
        return Vector3.new(a.x * b, a.y * b, a.z * b)
    elseif getmetatable(b) == Vector then
        return Vector3.new(a.x * b.x, a.y * b.y, a.z)
    else
        return Vector3.new(a.x * b.x, a.y * b.y, a.z * b.z)
    end
end

function Vector3.__div(a, b)
    if type(a) == "number" then
        return Vector3.new(a / b.x, a / b.y, a / b.z)
    elseif type(b) == "number" then
        return Vector3.new(a.x / b, a.y / b, a.z / b)
    elseif getmetatable(b) == Vector then
        return Vector3.new(a.x / b.x, a.y / b.y, a.z)
    else
        return Vector3.new(a.x / b.x, a.y / b.y, a.z / b.z)
    end
end

function Vector3.__eq(a, b)
    if getmetatable(b) == Vector then
        return a.x == b.x and a.y == b.y
    end
    return a.x == b.x and a.y == b.y and a.z == b.z
end

function Vector3.__lt(a, b)
    if getmetatable(b) == Vector then
        return (a.x < b.x) or (a.x == b.x and a.y < b.y)
    end
    return (a.x < b.x) or (a.x == b.x and a.y < b.y) or (a.x == b.x and a.y == b.y and a.z < b.z)
end

function Vector3.__le(a, b)
    if getmetatable(b) == Vector then
        return a.x <= b.x and a.y <= b.y
    end
    return a.x <= b.x and a.y <= b.y and a.z <= b.z
end

function Vector3.__tostring(a)
    return "(" .. a.x .. ", " .. a.y .. ", " .. a.z .. ")"
end

function Vector3.__concat(a, b)
    return tostring(a) .. tostring(b)
end

-- Vector3 Methods
function Vector3:clone()
    return Vector3.new(self.x, self.y, self.z)
end

function Vector3:unpack()
    return self.x, self.y, self.z
end

function Vector3:len()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector3:lenSq()
    return self.x * self.x + self.y * self.y + self.z * self.z
end

function Vector3:floor()
    return Vector3.new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function Vector3:ceil()
    return Vector3.new(math.ceil(self.x), math.ceil(self.y), math.ceil(self.z))
end

function Vector3:round()
    return Vector3.new(math.floor(self.x + 0.5), math.floor(self.y + 0.5), math.floor(self.z + 0.5))
end

function Vector3:random()
    return Vector3.new(Random(), Random(), Random())  -- Ensure Random() is defined elsewhere
end

function Vector3:min(other)
    return Vector3.new(math.min(self.x, other.x), math.min(self.y, other.y), math.min(self.z, other.z))
end

function Vector3:max(other)
    return Vector3.new(math.max(self.x, other.x), math.max(self.y, other.y), math.max(self.z, other.z))
end

function Vector3:normalize()
    local len = self:len()
    if len == 0 then return self end
    self.x = self.x / len
    self.y = self.y / len
    self.z = self.z / len
    return self
end

function Vector3:normalized()
    local len = self:len()
    if len == 0 then return Vector3.new(0, 0, 0) end
    return Vector3.new(self.x / len, self.y / len, self.z / len)
end

function Vector3:dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function Vector3:cross(other)
    return Vector3.new(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x
    )
end

function Vector3:direction(other)
    return (other - self):normalized()
end

function Vector3:lerp(other, t)
    return self + ((other - self) * t)
end

-- Rotate around Z-axis (common for 3D vectors)
function Vector3:rotateZ(phi)
    local c = math.cos(phi)
    local s = math.sin(phi)
    local newX = c * self.x - s * self.y
    local newY = s * self.x + c * self.y
    -- Z remains the same
    self.x = newX
    self.y = newY
    return self
end

function Vector3:rotatedZ(phi)
    return self:clone():rotateZ(phi)
end

function Vector3:projectOn(other)
    local scalar = self:dot(other) / other:lenSq()
    return other * scalar
end

function Vector3:distance(other)
    return (other - self):len()
end

function Vector3:print(name)
    if name then
        print("[" .. name .. "] " .. tostring(self))
    else
        print(tostring(self))
    end
end

function Vector3:GamePrint(name)
    if name then
        print("[" .. name .. "] " .. tostring(self))
    else
        print(tostring(self))
    end
end

setmetatable(Vector3, { __call = function(_, ...) return Vector3.new(...) end })

-- Example Usage
--[[

local v2 = Vector(1, 2)
local v3 = Vector3(1, 2, 3)

print(v2 + Vector(3, 4))       -- Output: (4, 6)
print(v3 + Vector3(4, 5, 6))   -- Output: (5, 7, 9)
print(v2 + v3)                 -- Output: (2, 4)

print(v2:dot(Vector(3, 4)))    -- Output: 11
print(v3:dot(Vector3(4, 5, 6)))-- Output: 32

print(v2:cross(Vector(3, 4)))  -- Output: -2
print(v3:cross(Vector3(4, 5, 6)))-- Output: (-3, 6, -3)

]]
return {Vector = Vector, Vector3 = Vector3}
