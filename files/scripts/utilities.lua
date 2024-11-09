-- utilities.lua

Utilities = {}

-- Deep copy function to clone tables
function Utilities.deepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[Utilities.deepCopy(orig_key, copies)] = Utilities.deepCopy(orig_value, copies)
            end
            setmetatable(copy, Utilities.deepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

Utilities.round = function(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function Utilities.abgrToRgba(abgr)
    local r = bit.band(abgr, 0x000000FF)
    local g = bit.band(abgr, 0x0000FF00)
    local b = bit.band(abgr, 0x00FF0000)
    local a = bit.band(abgr, 0xFF000000)

    g = bit.rshift(g, 8)
    b = bit.rshift(b, 16)
    a = bit.rshift(a, 24)

    return r,g,b,a
end