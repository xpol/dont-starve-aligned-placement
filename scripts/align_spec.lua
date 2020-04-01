-- class.lua
-- Compatible with Lua 5.1 (not 5.0).

local TrackClassInstances = false

ClassRegistry = {}

if TrackClassInstances == true then
    global("ClassTrackingTable")
    global("ClassTrackingInterval")

    ClassTrackingInterval = 100
end

local function __index(t, k)
    local p = rawget(t, "_")[k]
    if p ~= nil then
        return p[1]
    end
    return getmetatable(t)[k]
end

local function __newindex(t, k, v)
    local p = rawget(t, "_")[k]
    if p == nil then
        rawset(t, k, v)
    else
        local old = p[1]
        p[1] = v
        p[2](t, v, old)
    end
end

local function __dummy()
end

local function onreadonly(t, v, old)
    assert(v == old, "Cannot change read only property")
end

function makereadonly(t, k)
    local _ = rawget(t, "_")
    assert(_ ~= nil, "Class does not support read only properties")
    local p = _[k]
    if p == nil then
        _[k] = { t[k], onreadonly }
        rawset(t, k, nil)
    else
        p[2] = onreadonly
    end
end

function addsetter(t, k, fn)
    local _ = rawget(t, "_")
    assert(_ ~= nil, "Class does not support property setters")
    local p = _[k]
    if p == nil then
        _[k] = { t[k], fn }
        rawset(t, k, nil)
    else
        p[2] = fn
    end
end

function removesetter(t, k)
    local _ = rawget(t, "_")
    if _ ~= nil and _[k] ~= nil then
        rawset(t, k, _[k][1])
        _[k] = nil
    end
end

function Class(base, _ctor, props)
    local c = {}    -- a new class instance
    local c_inherited = {}
	if not _ctor and type(base) == 'function' then
        _ctor = base
        base = nil
    elseif type(base) == 'table' then
        -- our new class is a shallow copy of the base class!
		-- while at it also store our inherited members so we can get rid of them 
		-- while monkey patching for the hot reload
		-- if our class redefined a function peronally the function pointed to by our member is not the in in our inherited
		-- table
        for i,v in pairs(base) do
            c[i] = v
            c_inherited[i] = v
        end
        c._base = base
    end
    
    -- the class will be the metatable for all its objects,
    -- and they will look up their methods in it.
    if props ~= nil then
        c.__index = __index
        c.__newindex = __newindex
    else
        c.__index = c
    end

    -- expose a constructor which can be called by <classname>(<args>)
    local mt = {}
    
    if TrackClassInstances == true and CWD~=nil then
        if ClassTrackingTable == nil then
            ClassTrackingTable = {}
        end
        ClassTrackingTable[mt] = {}
		local dataroot = "@"..CWD.."\\"
        local tablemt = {}
        setmetatable(ClassTrackingTable[mt], tablemt)
        tablemt.__mode = "k"         -- now the instancetracker has weak keys
    
        local source = "**unknown**"
        if _ctor then
  			-- what is the file this ctor was created in?

			local info = debug.getinfo(_ctor, "S")
			-- strip the drive letter
			-- convert / to \\
			source = info.source
			source = string.gsub(source, "/", "\\")
			source = string.gsub(source, dataroot, "")
			local path = source

			local file = io.open(path, "r")
			if file ~= nil then
				local count = 1
   				for i in file:lines() do
					if count == info.linedefined then
						source = i
						-- okay, this line is a class definition
						-- so it's [local] name = Class etc
						-- take everything before the =
						local equalsPos = string.find(source,"=")
						if equalsPos then
							source = string.sub(source,1,equalsPos-1)
						end	
						-- remove trailing and leading whitespace
						source = source:gsub("^%s*(.-)%s*$", "%1")
						-- do we start with local? if so, strip it
						if string.find(source,"local ") ~= nil then
							source = string.sub(source,7)
						end
						-- trim again, because there may be multiple spaces
						source = source:gsub("^%s*(.-)%s*$", "%1")
						break
					end
					count = count + 1
				end
				file:close()
			end
		end

		mt.__call = function(class_tbl, ...)
			local obj = {}
			if props ~= nil then
				obj._ = { _ = { nil, __dummy } }
				for k, v in pairs(props) do
					obj._[k] = { nil, v }
				end
			end
			setmetatable(obj, c)
			ClassTrackingTable[mt][obj] = source
			if c._ctor then
				c._ctor(obj, ...)
			end
			return obj
		end    
	else
		mt.__call = function(class_tbl, ...)
			local obj = {}
			if props ~= nil then
				obj._ = { _ = { nil, __dummy } }
				for k, v in pairs(props) do
					obj._[k] = { nil, v }
				end
			end
			setmetatable(obj, c)
			if c._ctor then
			   c._ctor(obj, ...)
			end
			return obj
		end    
	end
	
    c._ctor = _ctor
    c.is_a = function(self, klass)
        local m = getmetatable(self)
        while m do 
            if m == klass then return true end
            m = m._base
        end
        return false
    end
    setmetatable(c, mt)
    ClassRegistry[c] = c_inherited
--    local count = 0
--    for i,v in pairs(ClassRegistry) do
--        count = count + 1
--    end
--    if string.split then	
--        print("ClassRegistry size : "..tostring(count))
--    end
    return c
end

function ReloadedClass(mt)
	ClassRegistry[mt] = nil
end

local lastClassTrackingDumpTick = 0

function HandleClassInstanceTracking()
    if TrackClassInstances and CWD~=nil then
        lastClassTrackingDumpTick = lastClassTrackingDumpTick + 1

        if lastClassTrackingDumpTick >= ClassTrackingInterval then
            collectgarbage()
            print("------------------------------------------------------------------------------------------------------------")
            lastClassTrackingDumpTick = 0
            if ClassTrackingTable then
                local sorted = {}
                local index = 1
                for i,v in pairs(ClassTrackingTable) do
                    local count = 0
                    local first = nil
                    for j,k in pairs(v) do
                        if count == 1 then
                            first = k
                        end
                        count = count + 1
                    end
                    if count>1 then
                        sorted[#sorted+1] = {first, count-1}
                    end
                    index = index + 1
                end
                -- get the top 10
                table.sort(sorted, function(a,b) return a[2] > b[2] end )
                for i=1,10 do
                    local entry = sorted[i]
                    if entry then
                        print(tostring(i).." : "..tostring(sorted[i][1]).." - "..tostring(sorted[i][2]))
                    end 
                end
                print("------------------------------------------------------------------------------------------------------------")
            end
        end
    end
end


local Vector3 = Class(function(self, x, y, z)
    self.x, self.y, self.z = x or 0, y or 0, z or 0
end)

local Point = Vector3

function Vector3:__add( rhs )
    return Vector3( self.x + rhs.x, self.y + rhs.y, self.z + rhs.z)
end

function Vector3:__sub( rhs )
    return Vector3( self.x - rhs.x, self.y - rhs.y, self.z - rhs.z)
end

function Vector3:__mul( rhs )
    return Vector3( self.x * rhs, self.y * rhs, self.z * rhs)
end

function Vector3:__div( rhs )
    return Vector3( self.x / rhs, self.y / rhs, self.z / rhs)
end

function Vector3:Dot( rhs )
    return self.x * rhs.x + self.y * rhs.y + self.z * rhs.z
end

function Vector3:Cross( rhs )
    return Vector3( self.y * rhs.z - self.z * rhs.y,
                    self.z * rhs.x - self.x * rhs.z,
                    self.x * rhs.y - self.y * rhs.x)
end

function Vector3:__tostring()
    return string.format("(%2.2f, %2.2f, %2.2f)", self.x, self.y, self.z) 
end

function Vector3:__eq( rhs )
    return self.x == rhs.x and self.y == rhs.y and self.z == rhs.z
end

function Vector3:DistSq(other)
    return (self.x - other.x)*(self.x - other.x) + (self.y - other.y)*(self.y - other.y) + (self.z - other.z)*(self.z - other.z)
end

function Vector3:Dist(other)
    return math.sqrt(self:DistSq(other))
end

function Vector3:LengthSq()
    return self.x*self.x + self.y*self.y + self.z*self.z
end

function Vector3:Length()
    return math.sqrt(self:LengthSq())
end

function Vector3:Normalize()
    local len = self:Length()
    if len > 0 then
        self.x = self.x / len
        self.y = self.y / len
        self.z = self.z / len
    end
    return self
end

function Vector3:GetNormalized()
    return self / self:Length()
end

function Vector3:GetNormalizedAndLength()
    local len = self:Length()
    return (len > 0 and self / len) or self, len
end

function Vector3:Get()
    return self.x, self.y, self.z
end

function Vector3:IsVector3()
    return true
end

function ToVector3(obj,y,z)
    if not obj then
        return
    end
    if obj.IsVector3 then  -- note: specifically not a function call! 
        return obj
    end
    if type(obj) == "table" then
        return Vector3(tonumber(obj[1]),tonumber(obj[2]),tonumber(obj[3]))
    else
        return Vector3(tonumber(obj),tonumber(y),tonumber(z))
    end
end

local Entity = Class(function(self, name, x, y, z)
    self.prefab, self.position = name, Vector3(x, y, z)
end)

function Entity:GetPosition()
    return Vector3(self.position:Get())
end

local EPSILON = 0.0000000001

describe("align", function()
    local align

    setup(function()
        _G._TEST = true
        _G.Vector3 = Vector3
        align = require('scripts.align')
    end)

    teardown(function()
        _G._TEST = nil
    end)

    describe('BestAxis()', function()
        local cases = {
            [1] = {x=1, z=0, angle=math.pi*0/4, off=0.0},
            [2] = {x=1, z=1, angle=math.pi*1/4, off=0.0},
            [3] = {x=0, z=1, angle=math.pi*2/4, off=0.0},
            [4] = {x=-1,z=1, angle=math.pi*3/4, off=0.0},
            [5] = {x=-1,z=0, angle=math.pi*4/4, off=0.0},
            [6] = {x=-1,z=-1, angle=math.pi*5/4, off=0.0},
            [7] = {x=0, z=-1, angle=math.pi*6/4, off=0.0},
            [8] = {x=1, z=-1, angle=math.pi*7/4, off=0.0},
            [9] = {x=1, z=-1.01, angle=math.pi*7/4, off=0.0070710678118655065708},
            [10] = {x=1, z=-0.99, angle=math.pi*7/4, off=0.0070710678118655065708},
            [11] = {x=100, z=-101, angle=nil, off=math.huge},
            [12] = {x=100, z=-99, angle=nil, off=math.huge},
            [13] = {x=1, z=-101, angle=nil, off=math.huge},
            [14] = {x=1, z=-99, angle=nil, off=math.huge},
          }
          for i, case in ipairs(cases) do
            local angle, off = align.BestAxis(case)
            it("case "..i, function()
                if case.angle == nil then
                    assert.is_nil(angle)
                else
                    assert.are.near(case.angle, angle, EPSILON)
                end
                assert.are.near(case.off, off, EPSILON)
            end)
          end
    end)

    describe('SnapOffsetOnline()', function()
        local cases = {
            {{x=1, z=0}, {x=-1.2, z=0}, -0.1},
            {{x=1, z=0}, {x=-0.8, z=0}, 0.1},

            {{x=-2.1, z=0}, {x=-1, z=0}, 0.1},
            {{x=-1.9, z=0}, {x=-1, z=0}, -0.1},
            {{x=-1.1, z=0}, {x=-2, z=0}, -0.2},
            {{x=-0.9, z=0}, {x=-2, z=0},  0.2},
          }
          for i, case in ipairs(cases) do
            local point, axisPoint, expected = table.unpack(case)
            local got = align.SnapOffsetOnline(point, axisPoint)
            it("case "..i, function()
                assert.are.near(expected, got, EPSILON)
            end)
          end
    end)

    describe('MakeTransformer()', function()
        it('to 1,1 and then rotate 90', function()
            local transform = align.MakeTransformer(Vector3(1, 0, 1), math.pi/2)
            local got = transform(Vector3(0, 0, 0))
            assert.are.near(-1.0, got.x, EPSILON)
            assert.are.near(1.0, got.z, EPSILON)
        end)

        it('to 1,1 and then rotate 45', function()
            local transform = align.MakeTransformer(Vector3(1, 0, 1), math.pi/4)
            local got = transform(Vector3(0, 0, 0))
            assert.are.near(-math.sqrt(2), got.x, EPSILON)
            assert.are.near(0.0, got.z, EPSILON)
        end)
    end)

    describe('SnapOffsetOffline()', function()
        it('should snap if x is near enough', function()
            local got = align.SnapOffsetOffline(Vector3(0.0001, 0, 100000))
            assert.are.equals(0.0001, got)

            got = align.SnapOffsetOffline(Vector3(-0.002, 0, 100000))
            assert.are.equals(-0.002, got)
        end)
        it('should snap if v is near enough', function()
            local off, score = align.SnapOffsetOffline(Vector3(1, 0, 1))
            assert.are.equals(0, off)
            assert.are.equals(0, score)

            off, score = align.SnapOffsetOffline(Vector3(1.1, 0, 1))
            assert.are.near(0.1, off, EPSILON)
            assert.are.near(0.07071067811866, score, EPSILON)

            off, score = align.SnapOffsetOffline(Vector3(0.9, 0, 1))
            assert.are.near(-0.1, off, EPSILON)
            assert.are.near(0.07071067811866, score, EPSILON)
        end)

        it('should snap if u is near enough', function()
            local off, score = align.SnapOffsetOffline(Vector3(-1, 0, 1))
            assert.are.equals(0, off)
            assert.are.equals(0, score)

            off, score = align.SnapOffsetOffline(Vector3(-1.1, 0, 1))
            assert.are.near(-0.1, off, EPSILON)
            assert.are.near(0.07071067811866, score, EPSILON)

            off, score = align.SnapOffsetOffline(Vector3(-0.9, 0, 1))
            assert.are.near(0.1, off, EPSILON)
            assert.are.near(0.07071067811866, score, EPSILON)
        end)
    end)

    describe('RoundPoint()', function()
        it('should rund to 0.1', function()
            local got = align.RoundPoint(Vector3(0.11, 0, 2.02))
            assert.are.same(Vector3(0.1, 0, 2.0), got)
        end)
    end)


    describe('AlignPlacerToEntities()', function()
        it('should handle when there is no entities', function()
            local got, targets = align.AlignPlacerToEntities(Vector3(1, 0, 1), {})
            assert.are.same(Vector3(1, 0, 1), got)
            assert.are.same(nil, targets)
        end)

        describe('when there is only entity', function()
            it('should align to one entity in x axis', function()
                local target = Entity('a', 1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(2, 0, 1.1), {target})
                assert.are.same(Vector3(2, 0, 1), got)
                assert.are.equals(1, #targets)
                assert.are.same(target, targets[1])
            end)

            it('should not align x axis when its far', function()
                local target = Entity('a', 1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(2, 0, 1.3), {target})
                assert.are.same(Vector3(2, 0, 1.3), got)
                assert.are.equals(nil, targets)
            end)
    
            it('should align to one entity in u axis', function()
                local target = Entity('a', 1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(1.99, 0, 2.01), {target})
                assert.are.near(2, got.x, EPSILON)
                assert.are.near(2, got.z, EPSILON)
                assert.are.equals(1, #targets)
                assert.are.same(target, targets[1])
            end)

            it('should not alig u axis when its fare', function()
                local target = Entity('a', 1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(2, 0, 2.4), {target})
                assert.are.same(Vector3(2, 0, 2.4), got)
                assert.are.same(nil, targets)
            end)
    
            it('should align to one entity in z axis', function()
                local target = Entity('a', 1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(1.01, 0, 2), {target})
                assert.are.same(Vector3(1, 0, 2), got)
                assert.are.equals(1, #targets)
                assert.are.same(target, targets[1])
            end)
    
            it('should align to one entity in v axis', function()
                local target = Entity('a', -1, 0, 1)
                local got, targets = align.AlignPlacerToEntities(Vector3(-1.99, 0, 2.01), {target})
                assert.are.near(-2, got.x, EPSILON)
                assert.are.near(2, got.z, EPSILON)
                assert.are.equals(1, #targets)
                assert.are.same(target, targets[1])
            end)
        end)

        describe('when there is 2 entities', function()
            it('will not align if they are far', function()
                local entities = {Entity('a', 10, 0, 11), Entity('a', 10, 0, -11)}
                local got, targets = align.AlignPlacerToEntities(Vector3(3, 0, 5), entities)
                assert.are.same(Vector3(3, 0, 5), got)
                assert.is_nil(targets)
            end)

            it('will align only one item', function()
                local entities = {Entity('a', 10, 0, 11), Entity('a', 10, 0, -11)}
                local got, targets = align.AlignPlacerToEntities(Vector3(10.25, 0, 5), entities)
                assert.are.near(10, got.x, EPSILON)
                assert.are.near(5, got.z, EPSILON)
                assert.are.equals(1, #targets)
                assert.are.same(entities[1], targets[1])
            end)

            it('will align both item when x is near', function()
                local entities = {Entity('a', 10, 0, 10), Entity('b', 10, 0, -10)}
                local got, targets = align.AlignPlacerToEntities(Vector3(0.1, 0, 0.1), entities)
                assert.are.near(0, got.x, EPSILON)
                assert.are.near(0, got.z, EPSILON)
                assert.are.equals(2, #targets)
                assert.are.same(entities, targets)
            end)

            it('will align both item when order is placer base eitity', function()
                local entities = {Entity('a', 5, 0, 5), Entity('b', 10, 0, 10)}
                local got, targets = align.AlignPlacerToEntities(Vector3(0.1, 0, 0.1), entities)
                assert.are.near(0, got.x, EPSILON)
                assert.are.near(0, got.z, EPSILON)
                assert.are.equals(2, #targets)
                assert.are.same(entities, targets)
            end)

            it('will align both item when order is placer eitity base', function()
                local entities = {Entity('b', 10, 0, 10), Entity('a', 5, 0, 5)}
                local got, targets = align.AlignPlacerToEntities(Vector3(0.1, 0, 0.1), entities)
                assert.are.near(0, got.x, EPSILON)
                assert.are.near(0, got.z, EPSILON)
                assert.are.equals(2, #targets)
                assert.are.same(entities, targets)
            end)

            it('will align both item when order is eitity placer base', function()
                local entities = {Entity('a', 10, 0, 10), Entity('b', 0, 0, 0)}
                local got, targets = align.AlignPlacerToEntities(Vector3(5.1, 0, 5.1), entities)
                assert.are.near(5, got.x, EPSILON)
                assert.are.near(5, got.z, EPSILON)
                assert.are.equals(2, #targets)
                assert.are.same(entities, targets)
            end)

            it('will align both item when in a 45 dgree angle', function()
                local entities = {Entity('a', 0, 0, 0), Entity('b', 5, 0, 5)}
                local got, targets = align.AlignPlacerToEntities(Vector3(10.01, 0, 0), entities)
                assert.are.near(10, got.x, EPSILON)
                assert.are.near(0, got.z, EPSILON)
                assert.are.equals(2, #targets)
                assert.are.same(entities, targets)
            end)
        end)
    end)
end)
