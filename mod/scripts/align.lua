
local SnapDistanceEpsilon = 0.25
local SameLineTolerance = 0.001
local ROUND = 0.1

local OtherAxis = {x = 'z', z = 'x'}

local function FindFirstAxisSnapTarget(refs)
    local r, axis, best = nil, nil, SnapDistanceEpsilon
    for _, ref in ipairs(refs) do
        local dx, dz = math.abs(ref.x), math.abs(ref.z)
        local off = math.min(dx, dz)
        if off < best then
            r, best, axis = ref, off, dx <= dz and 'x' or 'z'
        end
    end
    return r, axis, axis and OtherAxis[axis]
end

-- Snap when placer base and current point are not in a line
local function GetSecondAxisOfflineSnapOffset(point, axis, _)
    local offset = point[axis]
    return offset, math.abs(offset)
end

local function DifferentSign(a, b)
    return (a < 0 and b > 0) or (a > 0 and b < 0)
end

local function GetSecondAxisSnapOnlineOffsetForValues(pointValue, firstValue)
    if DifferentSign(pointValue, firstValue) then -- first <-> origin <-> point
        return 0.5*pointValue + 0.5*firstValue
    end

    if math.abs(pointValue) >= math.abs(firstValue) then -- point <-> first <-> origin
        return 2*firstValue - pointValue
    end

    return 2*pointValue - firstValue -- first <-> point <-> origin
end

-- Snap when placer base and current point are in a line
local function GetSecondAxisOnlineSnapOffset(point, axis, first)
    local oaxis = OtherAxis[axis]
    if math.abs(point[oaxis] - first[oaxis]) >= SameLineTolerance then
        return 0, math.huge
    end

    local off = GetSecondAxisSnapOnlineOffsetForValues(point[axis], first[axis])
    return off, math.abs(off)
end

local SNAPS = {
    GetSecondAxisOfflineSnapOffset,
    GetSecondAxisOnlineSnapOffset,
}

local function GetBsetSecondAxisSnapOffsetForPoint(point, axis, first)
    local off, abs = 0, math.huge
    for _, fn in ipairs(SNAPS) do
        local newOff, newAbs = fn(point, axis, first)
        if newAbs < abs then
        off, abs = newOff, newAbs
        end
    end

    return off, abs
end

local function FindSecondAxisSnapTarget(refs, axis, first)
    local entity, offset, best = nil, 0, SnapDistanceEpsilon
    for _, ref in ipairs(refs) do
        if not rawequal(ref, first) then -- Skip first entity.
            local off, abs = GetBsetSecondAxisSnapOffsetForPoint(ref, axis, first)
            if abs < best then
                entity, offset, best = ref, off, abs
            end
        end
    end
    return entity, offset
end


local _M = {}

local function RoundPoint(p)
    p.x = math.floor((p.x + ROUND*.5)/ROUND)*ROUND
    p.z = math.floor((p.z + ROUND*.5)/ROUND)*ROUND
    return p
end

local function Transform(entities, origin)
    local refs = {}
    for _, entity in ipairs(entities) do
        local d = entity:GetPosition() - origin
        d.entity = entity
        refs[#refs+1] = d
    end
    return refs
end

local function FinalAlignedPoint(placerPoint, axis, ref, oaxis, off)
    local r = Vector3(placerPoint:Get())
    r[axis] = ref.entity:GetPosition()[axis]
    r[oaxis] = r[oaxis] + off
    return r
  end

function _M.AlignPlacerToEntities(placerPoint, entities)
    local refs = Transform(entities, placerPoint)
    local first, axis, nextAxis = FindFirstAxisSnapTarget(refs)

    if not first then return RoundPoint(placerPoint) end

    local second, off = FindSecondAxisSnapTarget(refs, nextAxis, first)

    local aligned = FinalAlignedPoint(placerPoint, axis, first, nextAxis, off)
    return aligned, {first.entity, second and second.entity}
end

local private = {
    FindFirstAxisSnapTarget = FindFirstAxisSnapTarget,
    GetSecondAxisOfflineSnapOffset = GetSecondAxisOfflineSnapOffset,
    GetSecondAxisOnlineSnapOffset = GetSecondAxisOnlineSnapOffset,
    FindSecondAxisSnapTarget = FindSecondAxisSnapTarget,
    FinalAlignedPoint = FinalAlignedPoint,
    RoundPoint = RoundPoint,
}

_M.private = private

return _M
