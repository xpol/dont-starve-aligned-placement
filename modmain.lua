local require, unpack, Vector3 = GLOBAL.require, table.unpack or GLOBAL.unpack, GLOBAL.Vector3

local DST = GLOBAL.TheSim.GetGameID ~= nil and GLOBAL.TheSim:GetGameID() == "DST"

local function IsDLCEnabled(dlc)
    -- if the constant doesn't even exist, then they can't have the DLC
    if not GLOBAL.rawget(GLOBAL, dlc) then return false end
    GLOBAL.assert(GLOBAL.rawget(GLOBAL, "IsDLCEnabled"), "Old version of game, please update (IsDLCEnabled function missing)")
    return GLOBAL.IsDLCEnabled(GLOBAL[dlc])
end

local controller = require("controller")

local function GetGenerateOnUpdate()
    if DST then return
        require("placer/together")
    end
    
    if IsDLCEnabled("CAPY_DLC") then
        return require("placer/capy")
    end

    return require("placer/vanilla")
end

local GenerateOnUpdate = GetGenerateOnUpdate()

--local KEY_CTRL = GLOBAL.KEY_CTRL

local SEARCH_RADIUS, SNAP, ALIGN, EPSILON = 10, 0.5, 0.1, 0.001

local function OnlyPrefab(prefab)
    return function(inst)
        return inst.prefab == prefab
    end
end

local function PrefabMatch(pattern)
    return function(inst)
        return inst.prefab:match(pattern) ~= nil
    end
end

local function PrefabStatus(prefab, status)
    return function(inst)
        local inspectable = inst.components.inspectable
        return inst.prefab == prefab and inspectable and inspectable:GetStatus() == status
    end
end

local function SaplingOrTree(sapling, treeRegx)
    return function(inst)
        local prefab = inst.prefab
        if not prefab then return false end
        if prefab == sapling then return true end

        return prefab:match(treeRegx) ~= nil
    end
end

local SNAP_INFO = {
    -- Check function, placer, deployable/recipe
    -- Plants
    {OnlyPrefab('berrybush'), 'dug_berrybush_placer', 'dug_berrybush'},
    {OnlyPrefab('berrybush2'), 'dug_berrybush2_placer', 'dug_berrybush2'},
    {OnlyPrefab('berrybush_juicy'), 'dug_berrybush_juicy_placer', 'dug_berrybush_juicy'},
    {OnlyPrefab('grass'), 'dug_grass_placer', 'dug_grass'},
    
    {OnlyPrefab('bambootree'), 'dug_bambootree_placer', 'dug_bambootree'},
    {OnlyPrefab('vine'), 'dug_bush_vine_placer', 'dug_bush_vine'},
    {OnlyPrefab('flower'), 'butterfly_placer', 'butterfly'},
    {OnlyPrefab('rock_avocado_bush'), 'dug_rock_avocado_bush_placer', 'dug_rock_avocado_bush'},
    {OnlyPrefab('sapling'), 'dug_sapling_placer', 'dug_sapling'},
    {OnlyPrefab('sapling_moon'), 'dug_sapling_moon_placer', 'dug_sapling_moon'},
    -- Trees
    {SaplingOrTree('pinecone_sapling', '^evergreen'), 'pinecone_placer', 'pinecone'},
    {SaplingOrTree('acorn_sapling', '^deciduoustree'), 'acorn_placer', 'acorn'},
    {SaplingOrTree('marblebean_sapling', '^marbleshrub'), 'marblebean_placer', 'marblebean'},
    {SaplingOrTree('marsh_bush', '^marsh_tree$'), 'dug_marsh_bush_placer', 'dug_marsh_bush'},

    -- Fires
    {OnlyPrefab('campfire'), 'campfire_placer', 'campfire'},
    {OnlyPrefab('coldfire'), 'coldfire_placer', 'coldfire'},
    {OnlyPrefab('firepit'), 'firepit_placer', 'firepit'},
    {OnlyPrefab('coldfirepit'), 'coldfirepit_placer', 'coldfirepit'},

    -- Food
    {OnlyPrefab('slow_farmplot'), 'slow_farmplot_placer', 'slow_farmplot'},
    {OnlyPrefab('fast_farmplot'), 'fast_farmplot_placer', 'fast_farmplot'},
    {OnlyPrefab('ashfarmplot'), 'ashfarmplot_placer', 'ashfarmplot'},
    {OnlyPrefab('mushroom_farm'), 'mushroom_farm_placer', 'mushroom_farm'},

    --Structure
    {OnlyPrefab('birdcage'), 'birdcage_placer', 'birdcage'},
    {OnlyPrefab('beebox'), 'beebox_placer', 'beebox'},
    {OnlyPrefab('icebox'), 'icebox_placer', 'icebox'},
    {OnlyPrefab('lightning_rod'), 'lightning_rod_placer', 'lightning_rod'},
    {OnlyPrefab('pighouse'), 'pighouse_placer', 'pighouse'},
    {OnlyPrefab('rabbithouse'), 'rabbithouse_placer', 'rabbithouse'},
    {OnlyPrefab('cookpot'), 'cookpot_placer', 'cookpot'},
    {OnlyPrefab('treasurechest'), 'treasurechest_placer', 'treasurechest'},
    {OnlyPrefab('meatrack'), 'meatrack_placer', 'meatrack'},
    {OnlyPrefab('firesuppressor'), 'firesuppressor_placer', 'firesuppressor'},
    {OnlyPrefab('pottedfern'), 'pottedfern_placer', 'pottedfern'},
    {OnlyPrefab('dragonflychest'), 'dragonflychest_placer', 'dragonflychest'},
    {OnlyPrefab('wildborehouse'), 'wildborehouse_placer', 'wildborehouse'},
    {OnlyPrefab('primeapebarrel'), 'primeapebarrel_placer', 'primeapebarrel'},
    {OnlyPrefab('dragoonden'), 'dragoonden_placer', 'dragoonden'},
    {OnlyPrefab('saltbox'), 'saltbox_placer', 'saltbox'},
    {OnlyPrefab('scarecrow'), 'scarecrow_placer', 'scarecrow'},
    
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
    if inst then
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
        for i, e in pairs(targets) do
            SetAddColor(e, TAERGET_COLOR)
        end
    end
    inst.hilights = targets
end

local function FindEntities(position, radius, fn)
    local entities = {}
    local x, y, z = position:Get()
    local nears = GLOBAL.TheSim:FindEntities(x, y, z, radius)
    for _, v in ipairs(nears) do
        if fn(v) then entities[#entities+1] = v end
    end
    return entities
end

local function DifferentSign(a, b)
    return (a < 0 and b > 0) or (a > 0 and b < 0)
end

local function EvenSpaceAxis(axis, entities, position, middle)
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
            z, zt = EvenSpaceAxis('z', entities, position, xt:GetPosition())
        elseif zt ~= nil then
            x, xt = EvenSpaceAxis('x', entities, position, zt:GetPosition())
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

AddComponentPostInit("playercontroller", controller.PostInit)

AddComponentPostInit("placer", function(placer)
    placer.OnUpdate = GenerateOnUpdate(Snap, controller.GetPlacerOffset)
    placer.inst:ListenForEvent("onremove", function()
        RemoveHilightColors(placer)
    end)
end)

AddComponentPostInit("builder", function(builder)
    local CanBuildAtPoint, MakeRecipe = builder.CanBuildAtPoint, builder.MakeRecipe

    function builder:CanBuildAtPoint(pt, recipe)
        pt = SnapToEntities(pt, DEPLOYABLE_RECIPE_FILTERS[recipe.name])
        return CanBuildAtPoint(self, pt, recipe)
    end

    function builder:MakeRecipe(recipe, pt, ...)
        local filter = DEPLOYABLE_RECIPE_FILTERS[recipe.name]
        pt = SnapToEntities(pt, filter)
        return MakeRecipe(self, recipe, pt, ...)
    end
end)

AddComponentPostInit("deployable", function(deployable)
    local CanDeploy, Deploy = deployable.CanDeploy, deployable.Deploy
    function deployable:CanDeploy(pt)
        pt = SnapToEntities(pt, DEPLOYABLE_RECIPE_FILTERS[self.inst.prefab])
        return CanDeploy(self, pt)
    end

    function deployable:Deploy(pt, deployer)
        pt = SnapToEntities(pt, DEPLOYABLE_RECIPE_FILTERS[self.inst.prefab])
        return Deploy(self, pt, deployer)
    end
end)
