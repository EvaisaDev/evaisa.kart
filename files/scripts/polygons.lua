local PolygonExtractor = {}

local function floodFill(pointsMap, visited, x, y, shape)
    if visited[x] and visited[x][y] then return end
    visited[x] = visited[x] or {}
    visited[x][y] = true

    table.insert(shape, {x = x, y = y})

    local neighbors = {
        {x = x + 1, y = y}, {x = x - 1, y = y},
        {x = x, y = y + 1}, {x = x, y = y - 1},
        {x = x + 1, y = y + 1}, {x = x - 1, y = y - 1},
        {x = x + 1, y = y - 1}, {x = x - 1, y = y + 1},
    }
    for _, neighbor in ipairs(neighbors) do
        if pointsMap[neighbor.x] and pointsMap[neighbor.x][neighbor.y] then
            floodFill(pointsMap, visited, neighbor.x, neighbor.y, shape)
        end
    end
end

local function findShapes(points)
    local pointsMap = {}
    local visited = {}
    local shapes = {}

    for _, point in ipairs(points) do
        pointsMap[point.x] = pointsMap[point.x] or {}
        pointsMap[point.x][point.y] = true
    end

    for _, point in ipairs(points) do
        if not (visited[point.x] and visited[point.x][point.y]) then
            local shape = {}
            floodFill(pointsMap, visited, point.x, point.y, shape)
            table.insert(shapes, shape)
        end
    end

    return shapes
end

-- Convex Hull (Graham's scan)
local function convexHull(points)
    table.sort(points, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)

    local function cross(o, a, b)
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    end

    local lower = {}
    for _, p in ipairs(points) do
        while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do
            table.remove(lower)
        end
        table.insert(lower, p)
    end

    local upper = {}
    for i = #points, 1, -1 do
        local p = points[i]
        while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do
            table.remove(upper)
        end
        table.insert(upper, p)
    end

    table.remove(upper)
    table.remove(lower)

    for _, p in ipairs(upper) do
        table.insert(lower, p)
    end

    return lower
end

-- Resample points to a fixed number
local function resamplePoints(points, targetCount)
    local totalLength = 0
    local lengths = {}

    for i = 1, #points do
        local nextIndex = (i % #points) + 1
        local dx = points[nextIndex].x - points[i].x
        local dy = points[nextIndex].y - points[i].y
        local segmentLength = math.sqrt(dx * dx + dy * dy)
        table.insert(lengths, segmentLength)
        totalLength = totalLength + segmentLength
    end

    local targetSegmentLength = totalLength / targetCount
    local resampled = {points[1]}
    local accumulatedLength = 0

    for i = 1, #points do
        local nextIndex = (i % #points) + 1
        local dx = points[nextIndex].x - points[i].x
        local dy = points[nextIndex].y - points[i].y
        local segmentLength = lengths[i]

        while accumulatedLength + segmentLength >= targetSegmentLength do
            local t = (targetSegmentLength - accumulatedLength) / segmentLength
            table.insert(resampled, {
                x = points[i].x + t * dx,
                y = points[i].y + t * dy,
            })
            accumulatedLength = accumulatedLength - targetSegmentLength
        end

        accumulatedLength = accumulatedLength + segmentLength
    end

    return resampled
end

-- Main extraction function
function PolygonExtractor.extractPolygons(points)
    local shapes = findShapes(points)
    local polygons = {}

    for _, shape in ipairs(shapes) do
        local hull = convexHull(shape)
        local resampledPolygon = resamplePoints(hull, 32)
        table.insert(polygons, resampledPolygon)
    end

    return polygons
end

return PolygonExtractor
