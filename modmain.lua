local require, unpack, select, Vector3 = GLOBAL.require, table.unpack or GLOBAL.unpack, GLOBAL.select, GLOBAL.Vector3

local DST = GLOBAL.TheSim.GetGameID ~= nil and GLOBAL.TheSim:GetGameID() == "DST"

local function IsDLCEnabled(dlc)
    -- if the constant doesn't even exist, then they can't have the DLC
    if not GLOBAL.rawget(GLOBAL, dlc) then return false end
    GLOBAL.assert(GLOBAL.rawget(GLOBAL, "IsDLCEnabled"), "Old version of game, please update (IsDLCEnabled function missing)")
    return GLOBAL.IsDLCEnabled(GLOBAL[dlc])
end

local controller = require("controller")

local PlacerUpdate = require(DST and "placer/together" or (
        IsDLCEnabled("CAPY_DLC") and "placer/capy" or "placer/vanilla"
    ))

local SEARCH_RADIUS, SNAP, ALIGN, EPSILON = 10, 0.5, 0.1, 0.001

local function AlignTo(...)
    local set = {}
    for i = 1, select('#', ...) do
        set[select(i, ...)] = true
    end
    return function(inst)
        return set[inst.prefab] == true
    end
end

local SNAP_INFO = {
    -- Check function, placer, deployable/recipe
    -- Plants
    {AlignTo('berrybush'), 'dug_berrybush_placer', 'dug_berrybush'},
    {AlignTo('berrybush2'), 'dug_berrybush2_placer', 'dug_berrybush2'},
    {AlignTo('berrybush_juicy'), 'dug_berrybush_juicy_placer', 'dug_berrybush_juicy'},
    {AlignTo('grass'), 'dug_grass_placer', 'dug_grass'},
    {AlignTo('bambootree'), 'dug_bambootree_placer', 'dug_bambootree'},
    {AlignTo('vine'), 'dug_bush_vine_placer', 'dug_bush_vine'},
    {AlignTo('flower'), 'butterfly_placer', 'butterfly'},
    {AlignTo('rock_avocado_bush'), 'dug_rock_avocado_bush_placer', 'dug_rock_avocado_bush'},
    {AlignTo('sapling'), 'dug_sapling_placer', 'dug_sapling'},
    {AlignTo('sapling_moon'), 'dug_sapling_moon_placer', 'dug_sapling_moon'},
    {AlignTo('pottedfern'), 'pottedfern_placer', 'pottedfern'},
    {AlignTo('marsh_bush'), 'dug_marsh_bush_placer', 'dug_marsh_bush'},

    -- Trees
    {AlignTo('pinecone_sapling', 'evergreen'), 'pinecone_placer', 'pinecone'},
    {AlignTo('acorn_sapling', 'deciduoustree'), 'acorn_placer', 'acorn'},
    {AlignTo('twiggy_nut_sapling', 'twiggytree'), 'twiggy_nut_placer', 'twiggy_nut'},
    {AlignTo('marblebean_sapling', 'marbleshrub'), 'marblebean_placer', 'marblebean'},
    {AlignTo('moonbutterfly_sapling', 'moon_tree'), 'moonbutterfly_placer', 'moonbutterfly'},

    -- Fires
    {AlignTo('campfire'), 'campfire_placer', 'campfire'},
    {AlignTo('coldfire'), 'coldfire_placer', 'coldfire'},
    {AlignTo('firepit'), 'firepit_placer', 'firepit'},
    {AlignTo('coldfirepit'), 'coldfirepit_placer', 'coldfirepit'},

    -- Farms
    {AlignTo('slow_farmplot'), 'slow_farmplot_placer', 'slow_farmplot'},
    {AlignTo('fast_farmplot'), 'fast_farmplot_placer', 'fast_farmplot'},
    {AlignTo('mushroom_farm'), 'mushroom_farm_placer', 'mushroom_farm'},

    --Structure
    {AlignTo('birdcage'), 'birdcage_placer', 'birdcage'},
    {AlignTo('beebox'), 'beebox_placer', 'beebox'},
    {AlignTo('icebox'), 'icebox_placer', 'icebox'},
    {AlignTo('lightning_rod'), 'lightning_rod_placer', 'lightning_rod'},
    {AlignTo('cookpot'), 'cookpot_placer', 'cookpot'},
    {AlignTo('treasurechest'), 'treasurechest_placer', 'treasurechest'},
    {AlignTo('meatrack'), 'meatrack_placer', 'meatrack'},
    {AlignTo('firesuppressor'), 'firesuppressor_placer', 'firesuppressor'},
    {AlignTo('dragonflychest'), 'dragonflychest_placer', 'dragonflychest'},
    {AlignTo('dragoonden'), 'dragoonden_placer', 'dragoonden'}, -- Shipwrecked
    {AlignTo('saltbox'), 'saltbox_placer', 'saltbox'},
    {AlignTo('scarecrow'), 'scarecrow_placer', 'scarecrow'},
    {AlignTo('resurrectionstatue'), 'resurrectionstatue_placer', 'resurrectionstatue'},
    {AlignTo('cellar'), 'cellar_placer', 'cellar'}, -- MOD: DST Storm Cellar

    -- Houses
    {AlignTo('spiderden'), 'spidereggsack_placer', 'spidereggsack'},
    {AlignTo('pighouse'), 'pighouse_placer', 'pighouse'},
    {AlignTo('rabbithouse'), 'rabbithouse_placer', 'rabbithouse'},
    {AlignTo('primeapebarrel'), 'primeapebarrel_placer', 'primeapebarrel'}, -- Shipwrecked
    {AlignTo('wildborehouse'), 'wildborehouse_placer', 'wildborehouse'}, -- Shipwrecked

    -- Traps
    {AlignTo('trap_teeth'), 'trap_teeth_placer', 'trap_teeth'},
    {AlignTo('trap_bramble'), 'trap_bramble_placer', 'trap_bramble'},
    {AlignTo('beemine'), 'beemine_placer', 'beemine'},
    {AlignTo('eyeturret'), 'eyeturret_item_placer', 'eyeturret_item'},
}

local function GenerateEnitiyFilterTable(infos)
    local placers = {}
    local deployables_or_recipes = {}
    for _, v in ipairs(infos) do
        local checker, placer, deployable = unpack(v)
        placers[placer] = checker
        if deployable then deployables_or_recipes[deployable] = checker end
    end
    return placers, deployables_or_recipes
end


local PLACER_FILTERS, DEPLOYABLE_RECIPE_FILTERS = GenerateEnitiyFilterTable(SNAP_INFO)

local function Align(v, step)
    return (v + step/2) - (v % step)
end

local function DistanceAxis(axis, a, b)
    return math.abs(a[axis] - b[axis])
end

local OtherAxis = {x = 'z', z = 'x'}

local function NearestAtAxis(axis, entities, base)
    local target, d = nil, math.huge
    local oaxis = OtherAxis[axis]
    for _, e in ipairs(entities) do
        if DistanceAxis(axis, e:GetPosition(), base) < SNAP then
            local newd = DistanceAxis(oaxis, e:GetPosition(), base)
            if not target or d > newd then
                target, d = e, newd
            end
        end
    end
    return target
end

local function SnapAxis(axis, entities, position)
    local t = NearestAtAxis(axis, entities, position)
    if not t then
        return Align(position[axis], ALIGN), nil
    end
    return t:GetPosition()[axis], t
end

local TAERGET_COLOR, ZERO = {.75,.75,.75, 0}, {0,0,0,0}

local function SetAddColor(inst,color)
    if inst and inst.AnimState then
        inst.AnimState:SetAddColour(unpack(color))
    end
end

local function RemoveHilightColors(inst)
    if inst.hilights then
        for _, e in pairs(inst.hilights) do SetAddColor(e, ZERO) end
    end
end

local function UpdateHilightColors(inst, targets)
    RemoveHilightColors(inst)
    if targets then
        for _, e in pairs(targets) do
            SetAddColor(e, TAERGET_COLOR)
        end
    end
    inst.hilights = targets
end

local function FindEntities(position, radius, fn)
    local entities = {}
    local x, y, z = position:Get()
    local nears = GLOBAL.TheSim:FindEntities(x, y, z, radius, nil, {'INLIMBO', 'wall'})
    for _, v in ipairs(nears) do
        if fn(v) then
            entities[#entities+1] = v
        end
    end
    return entities
end

local function DifferentSign(a, b)
    return (a < 0 and b > 0) or (a > 0 and b < 0)
end

--TODO: Should support place in the middle
local function EqualSpaceAlignAxis(axis, entities, position, middle)
    local oaxis = OtherAxis[axis]
    local diff = position[axis] - middle[axis]
    if math.abs(diff) < EPSILON then
        return Align(position[axis], ALIGN), nil
    end

    local t, lastd = nil, math.huge
    for _, v in ipairs(entities) do
        local vpos = v:GetPosition()
        if math.abs(vpos[oaxis] - middle[oaxis]) < EPSILON then
            local d = vpos[axis] - middle[axis]
            local distdiff = math.abs(diff + d)
            if distdiff < lastd
            and DifferentSign(diff, d)
            and distdiff < SNAP then
                t, lastd = v, distdiff
            end
        end
    end
    if not t then
        return Align(position[axis], ALIGN), nil
    end
    return 2*middle[axis] - t:GetPosition()[axis], t
end

local function SnapToEntities(position, snapFilter)
    if not position or not snapFilter then
        return position
    end
    local entities = FindEntities(position, SEARCH_RADIUS, snapFilter)
    local x, xt = SnapAxis('x', entities, position)
    local z, zt = SnapAxis('z', entities, position)

    if xt == nil or zt == nil then
        if xt ~= nil then
            z, zt = EqualSpaceAlignAxis('z', entities, position, xt:GetPosition())
        elseif zt ~= nil then
            x, xt = EqualSpaceAlignAxis('x', entities, position, zt:GetPosition())
        end
    end

    return Vector3(x, position.y, z), {xt, zt}
end

local function Snap(placer, position)
    local snapFilter = PLACER_FILTERS[placer.inst.prefab]
    if not snapFilter then
        return position
    end

    local to, targets = SnapToEntities(position, snapFilter)
    UpdateHilightColors(placer, targets)
    return to or position
end

-- AddComponentPostInit("playercontroller", controller.PostInit)

AddComponentPostInit("placer", function(placer)
    controller.SetupFollower(placer)
    placer.OnUpdate = function(self, dt)
        PlacerUpdate(self, dt, Snap, controller)
    end

    placer.inst:ListenForEvent("onremove", function()
        RemoveHilightColors(placer)
    end)
end)

AddComponentPostInit("builder", function(builder)
    local CanBuildAtPoint, MakeRecipe = builder.CanBuildAtPoint, builder.MakeRecipe

    function builder:CanBuildAtPoint(pt, recipe, ...)
        local filter = DEPLOYABLE_RECIPE_FILTERS[recipe.name]
        local aligned = SnapToEntities(pt, filter)
        return CanBuildAtPoint(self, aligned, recipe, ...)
    end

    function builder:MakeRecipe(recipe, pt, ...)
        local filter = DEPLOYABLE_RECIPE_FILTERS[recipe.name]
        local aligned = SnapToEntities(pt, filter)
        return MakeRecipe(self, recipe, aligned, ...)
    end
end)

AddComponentPostInit("deployable", function(deployable)
    local CanDeploy, Deploy = deployable.CanDeploy, deployable.Deploy
    function deployable:CanDeploy(pt, ...)
        local filter = DEPLOYABLE_RECIPE_FILTERS[self.inst.prefab]
        local aligned = SnapToEntities(pt, filter)
        return CanDeploy(self, aligned, ...)
    end

    function deployable:Deploy(pt, deployer, ...)
        local filter = DEPLOYABLE_RECIPE_FILTERS[self.inst.prefab]
        local aligned = SnapToEntities(pt, filter)
        return Deploy(self, aligned, deployer, ...)
    end
end)

