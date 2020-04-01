
local SnapDistanceEpsilon = 0.25
local SameLineTolerance = 0.01
local ROUND = 0.1

-- Distance = (| a*x1 + b*y1 + c |) / (sqrt( a*a + b*b))
--[[
         z^
    v \   |   / u
        \ | /
  --------+-------->x
        / | \
      /   |   \
]]
local AXES = {
  {
    name = 'x',
    Angle = function(p) return p.x > 0 and 0 or math.pi end,
    Distance = function(p) return math.abs(p.z) end
  },
  {
    name = 'u',
    Angle = function(p) return (math.pi / 4) * (p.z > 0 and 1 or 5) end,
    Distance = function(p) return math.abs(p.z - p.x) * 0.70710678118655 end
  },
  {
    name = 'z',
    Angle = function(p) return (math.pi / 4) * (p.z > 0 and 2 or 6) end,
    Distance = function(p) return math.abs(p.x) end
  },
  {
    name = 'v',
    Angle = function(p) return (math.pi / 4) * (p.x > 0 and 7 or 3) end,
    Distance = function(p) return math.abs(p.x + p.z) * 0.70710678118655 end
  }
}
local function BestAxis(v)
  local min, axis = math.huge, nil
  for _, a in ipairs(AXES) do
    local d = a.Distance(v)
    if d < min then
      min, axis = d, a
    end
  end
  if min > SnapDistanceEpsilon then
    return nil, math.huge
  end
  return axis.Angle(v), min
end

local function FirstAxisEntity(entities, placerPoint)
  for _, e in ipairs(entities) do
    local angle, off = BestAxis(placerPoint - e:GetPosition())
    if off < SnapDistanceEpsilon then
      return e, angle
    end
  end
  return nil, nil
end

local function MakeTransformer(origin, angle)
  local SIN, COS = math.sin(angle), math.cos(angle)
  local o = Vector3(origin:Get())
  return function(point)
    local p = point - o
    local newX = p.x * COS + p.z * SIN
    local newZ = p.z * COS - p.x * SIN
    p.x, p.z = newX, newZ
    return p
  end
end

local OFFSETS = {
    function(p)
        return p.x, math.abs(p.x)
    end,
    function(p)
        local d = (p.z - p.x)
        return -d, math.abs(d* 0.70710678118655)
    end,
    function(p)
        local d = (p.x + p.z)
        return d, math.abs(d* 0.70710678118655)
    end,
}

-- Snap when placer base and current point are not in a line
local function SnapOffsetOffline(point, _)
    local offset, abs = 0, math.huge
    for _, fn in ipairs(OFFSETS) do
        local newOff, newAbs = fn(point)
        if newAbs < abs then
            offset, abs = newOff, newAbs
        end
    end

    return offset, abs
end

-- Snap when placer base and current point are in a line
local function SnapOffsetOnline(point, axisPoint)
  if math.abs(point.z - axisPoint.z) > SameLineTolerance then
    print(point, axisPoint, "are not in same line.")
    return 0, math.huge
  end

  if point.x > 0 then -- base -> placer -> entity
    local off = 0.5*point.x + 0.5*axisPoint.x
    return off, math.abs(off)
  end

  if point.x < axisPoint.x then -- entity -> base -> placer
    local off = 2*axisPoint.x - point.x
    return off, math.abs(off)
  end

  -- base -> entity -> placer
  local off = 2*point.x - axisPoint.x
  return off, math.abs(off)
end

local SNAPS = {
  SnapOffsetOffline,
  SnapOffsetOnline,
}

local function BsetSnap(point, basePosition)
  local off, abs = 0, math.huge
  for _, fn in ipairs(SNAPS) do
    local newOff, newAbs = fn(point, basePosition)
    if newAbs < abs then
      off, abs = newOff, newAbs
    end
  end

  return off, abs
end

local function FirstDistanceEntity(entities, placerPoint, baseEntity, angle)
  local transform = MakeTransformer(placerPoint, angle)
  local basePosition = transform(baseEntity:GetPosition())
  assert(basePosition.x <= 0, "base entity should at left side of placer!")

  for _, e in ipairs(entities) do
    local point = transform(e:GetPosition())
    local off, abs = BsetSnap(point, basePosition)
    if abs < SnapDistanceEpsilon then
      return e, math.abs(basePosition.x) + off
    end
  end

  return nil, math.abs(basePosition.x)
end


local function FinalAlignedPoint(originEntity, angle, distance)
  local x, z = distance*math.cos(angle), distance*math.sin(angle)
  return originEntity:GetPosition() + Vector3(x, 0, z)
end

local _M = {}

local function RoundPoint(p)
    p.x = math.floor((p.x + ROUND*.5)/ROUND)*ROUND
    p.z = math.floor((p.z + ROUND*.5)/ROUND)*ROUND
    return p
end

function _M.AlignPlacerToEntities(placerPoint, entities)
    print("### Align", #entities, "entities")
  local axisEntity, angle = FirstAxisEntity(entities, placerPoint)
  if not angle then return RoundPoint(placerPoint) end
  local distanceEntity, distance = FirstDistanceEntity(entities, placerPoint, axisEntity, angle)

  local placerAlignedTo = FinalAlignedPoint(axisEntity, angle, distance)
  return placerAlignedTo, {axisEntity, distanceEntity}
end

if _TEST then
    _M.BestAxis = BestAxis
    _M.FirstAxisEntity = FirstAxisEntity
    _M.MakeTransformer = MakeTransformer
    _M.SnapOffsetOffline = SnapOffsetOffline
    _M.SnapOffsetOnline = SnapOffsetOnline
    _M.BsetSnap = BsetSnap
    _M.FirstDistanceEntity = FirstDistanceEntity
    _M.FinalAlignedPoint = FinalAlignedPoint
    _M.RoundPoint = RoundPoint
end

return _M
