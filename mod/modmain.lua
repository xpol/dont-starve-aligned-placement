local require, unpack = GLOBAL.require, table.unpack or GLOBAL.unpack
local assert, rawget = GLOBAL.assert, GLOBAL.rawget

local DST = GLOBAL.TheSim.GetGameID ~= nil and GLOBAL.TheSim:GetGameID() == "DST"

local function IsDLCEnabled(dlc)
    -- if the constant doesn't even exist, then they can't have the DLC
    if not rawget(GLOBAL, dlc) then return false end
    assert(rawget(GLOBAL, "IsDLCEnabled"), "Old version of game, please update (IsDLCEnabled function missing)")
    return GLOBAL.IsDLCEnabled(GLOBAL[dlc])
end

local controller = require("controller")
local align = require("align")

local PlacerUpdate = require(DST and "placer/together" or (
        IsDLCEnabled("CAPY_DLC") and "placer/capy" or "placer/vanilla"
    ))

local SEARCH_RADIUS = 10

local SupportedPrefabs = {
    -- deployable/recipe, placer, algin to prefabs...
    -- Plants
    {'dug_berrybush', 'dug_berrybush_placer', {'berrybush'}},
    {'dug_berrybush2', 'dug_berrybush2_placer', {'berrybush2'}},
    {'dug_berrybush_juicy', 'dug_berrybush_juicy_placer', {'berrybush_juicy'}},
    {'dug_grass', 'dug_grass_placer', {'grass'}},
    {'dug_bambootree', 'dug_bambootree_placer', {'bambootree'}},
    {'dug_bush_vine', 'dug_bush_vine_placer', {'vine'}},
    {'butterfly', 'butterfly_placer', {'flower'}},
    {'dug_rock_avocado_bush', 'dug_rock_avocado_bush_placer', {'rock_avocado_bush'}},
    {'dug_sapling', 'dug_sapling_placer', {'sapling'}},
    {'dug_sapling_moon', 'dug_sapling_moon_placer', {'sapling_moon'}},
    {'pottedfern', 'pottedfern_placer', {'pottedfern'}},
    {'succulent_potted', 'succulent_potted_placer', {'succulent_potted'}},
    {'dug_marsh_bush', 'dug_marsh_bush_placer', {'marsh_bush'}},
    {'dug_trap_starfish', 'dug_trap_starfish_placer', {'trap_starfish'}},
    {'bullkelp_root', 'bullkelp_root_placer', {'bullkelp_plant'}},

    -- Trees
    {'pinecone', 'pinecone_placer', {'pinecone_sapling', 'evergreen'}},
    {'acorn', 'acorn_placer', {'acorn_sapling', 'deciduoustree'}},
    {'twiggy_nut', 'twiggy_nut_placer', {'twiggy_nut_sapling', 'twiggytree'}},
    {'marblebean', 'marblebean_placer', {'marblebean_sapling', 'marbleshrub'}},
    {'moonbutterfly', 'moonbutterfly_placer', {'moonbutterfly_sapling', 'moon_tree'}},

    --Structures (Search `_placer` in scripts/recipes.lua)
    {'birdcage', 'birdcage_placer', {'birdcage'}},
    {'beebox', 'beebox_placer', {'beebox'}},
    {'icebox', 'icebox_placer', {'icebox'}},
    {'lightning_rod', 'lightning_rod_placer', {'lightning_rod'}},
    {'cookpot', 'cookpot_placer', {'cookpot'}},
    {'treasurechest', 'treasurechest_placer', {'treasurechest'}},
    {'homesign', 'homesign_placer', {'homesign'}},
    {'meatrack', 'meatrack_placer', {'meatrack'}},
    {'firesuppressor', 'firesuppressor_placer', {'firesuppressor'}},
    {'dragonflychest', 'dragonflychest_placer', {'dragonflychest'}},
    {'dragoonden', 'dragoonden_placer', {'dragoonden'}}, -- Shipwrecked
    {'saltbox', 'saltbox_placer', {'saltbox'}},
    {'scarecrow', 'scarecrow_placer', {'scarecrow'}},
    {'resurrectionstatue', 'resurrectionstatue_placer', {'resurrectionstatue'}},
    {'sculptingtable', 'sculptingtable_placer', {'sculptingtable'}},
    {'dragonflyfurnace', 'dragonflyfurnace_placer', {'dragonflyfurnace'}},
    {'wardrobe', 'wardrobe_placer', {'wardrobe'}},
    {'researchlab', 'researchlab_placer', {'researchlab'}},
    {'researchlab2', 'researchlab2_placer', {'researchlab2'}},
    {'researchlab3', 'researchlab3_placer', {'researchlab3'}},
    {'researchlab4', 'researchlab4_placer', {'researchlab4'}},
    {'townportal', 'townportal_placer', {'townportal'}},
    {'winterometer', 'winterometer_placer', {'winterometer'}},
    {'rainometer', 'rainometer_placer', {'rainometer'}},
    {'telebase', 'telebase_placer', {'telebase'}},
    {'cartographydesk', 'cartographydesk_placer', {'cartographydesk'}},
    {'perdshrine', 'perdshrine_placer', {'perdshrine'}},
    {'wargshrine', 'wargshrine_placer', {'wargshrine'}},
    {'pigshrine', 'pigshrine_placer', {'pigshrine'}},
    {'yotc_carratshrine', 'yotc_carratshrine_placer', {'yotc_carratshrine'}},
    {'endtable', 'endtable_placer', {'endtable'}},
    {'seafaring_prototyper', 'seafaring_prototyper_placer', {'seafaring_prototyper'}},
    {'moondial', 'moondial_placer', {'moondial'}},
    {'sentryward', 'sentryward_placer', {'sentryward'}},
    {'tent', 'tent_placer', {'tent'}},
    {'siestahut', 'siestahut_placer', {'siestahut'}},
    {'fish_box', 'fish_box_placer', {'fish_box'}},
    {'tacklestation', 'tacklestation_placer', {'tacklestation'}},
    {'trophyscale_fish', 'trophyscale_fish_placer', {'trophyscale_fish'}},
    {'mushroom_light', 'mushroom_light_placer', {'mushroom_light'}},
    {'mushroom_light2', 'mushroom_light2_placer', {'mushroom_light2'}},
    {'saltlick', 'saltlick_placer', {'saltlick'}},
    {'cellar', 'cellar_placer', {'cellar'}}, -- MOD: DST Storm Cellar
    {'arrowsign_post', 'arrowsign_post_placer', {'arrowsign_post'}},
    {'beefalo_groomer_item', 'beefalo_groomer_item_placer', {'beefalo_groomer_item'}},
    {'compostingbin', 'compostingbin_placer', {'compostingbin'}},
    {'madscience_lab', 'madscience_lab_placer', {'madscience_lab'}},
    {'meatrack', 'meatrack_placer', {'meatrack'}},
    {'mermhouse_crafted', 'mermhouse_crafted_placer', {'mermhouse_crafted'}},
    {'mermthrone_construction', 'mermthrone_construction_placer', {'mermthrone_construction'}},
    {'mermwatchtower', 'mermwatchtower_placer', {'mermwatchtower'}},
    {'mighty_gym', 'mighty_gym_placer', {'mighty_gym'}},
    {'moon_device_construction1', 'moon_device_construction1_placer', {'moon_device_construction1'}},
    {'nightlight', 'nightlight_placer', {'nightlight'}},
    {'ruinsrelic_bowl', 'ruinsrelic_bowl_placer', {'ruinsrelic_bowl'}},
    {'ruinsrelic_chair', 'ruinsrelic_chair_placer', {'ruinsrelic_chair'}},
    {'ruinsrelic_chipbowl', 'ruinsrelic_chipbowl_placer', {'ruinsrelic_chipbowl'}},
    {'ruinsrelic_plate', 'ruinsrelic_plate_placer', {'ruinsrelic_plate'}},
    {'ruinsrelic_table', 'ruinsrelic_table_placer', {'ruinsrelic_table'}},
    {'ruinsrelic_vase', 'ruinsrelic_vase_placer', {'ruinsrelic_vase'}},
    {'sisturn', 'sisturn_placer', {'sisturn'}},
    {'table_winters_feast', 'table_winters_feast_placer', {'table_winters_feast'}},
    {'trophyscale_oversizedveggies', 'trophyscale_oversizedveggies_placer', {'trophyscale_oversizedveggies'}},
    {'turfcraftingstation', 'turfcraftingstation_placer', {'turfcraftingstation'}},
    {'waterpump', 'waterpump_placer', {'waterpump'}},
    {'winch', 'winch_placer', {'winch'}},
    {'winona_battery_high', 'winona_battery_high_placer', {'winona_battery_high'}},
    {'winona_battery_low', 'winona_battery_low_placer', {'winona_battery_low'}},
    {'winona_catapult', 'winona_catapult_placer', {'winona_catapult'}},
    {'winona_spotlight', 'winona_spotlight_placer', {'winona_spotlight'}},
    {'winter_treestand', 'winter_treestand_placer', {'winter_treestand'}},
    {'wintersfeastoven', 'wintersfeastoven_placer', {'wintersfeastoven'}},
    {'yot_catcoonshrine', 'yot_catcoonshrine_placer', {'yot_catcoonshrine'}},
    {'yotb_beefaloshrine', 'yotb_beefaloshrine_placer', {'yotb_beefaloshrine'}},

    -- Fires
    {'campfire', 'campfire_placer', {'campfire'}},
    {'coldfire', 'coldfire_placer', {'coldfire'}},
    {'firepit', 'firepit_placer', {'firepit'}},
    {'coldfirepit', 'coldfirepit_placer', {'coldfirepit'}},

    -- Farms
    {'slow_farmplot', 'slow_farmplot_placer', {'slow_farmplot'}},
    {'fast_farmplot', 'fast_farmplot_placer', {'fast_farmplot'}},
    {'mushroom_farm', 'mushroom_farm_placer', {'mushroom_farm'}},

    -- Houses
    {'spidereggsack', 'spidereggsack_placer', {'spiderden'}},
    {'pighouse', 'pighouse_placer', {'pighouse'}},
    {'rabbithouse', 'rabbithouse_placer', {'rabbithouse'}},
    {'primeapebarrel', 'primeapebarrel_placer', {'primeapebarrel'}}, -- Shipwrecked
    {'wildborehouse', 'wildborehouse_placer', {'wildborehouse'}}, -- Shipwrecked

    -- Traps
    {'trap_teeth', 'trap_teeth_placer', {'trap_teeth'}},
    {'trap_bramble', 'trap_bramble_placer', {'trap_bramble'}},
    {'beemine', 'beemine_placer', {'beemine'}},
    {'eyeturret_item', 'eyeturret_item_placer', {'eyeturret'}},
}


local function AlignTo(list)
    local set = {}
    for _, v in ipairs(list) do
        set[v] = true
    end
    return function(inst)
        return set[inst.prefab] == true
    end
end

local function CreateAllFilter(categoryItems)
    local allPrefabs = {}
    for _, v in ipairs(categoryItems) do
        for _, prefab in ipairs(v[3]) do
            allPrefabs[#allPrefabs+1] = prefab
        end
    end

    return AlignTo(allPrefabs)
end

local function GenerateFilters(conf, alignAll)
    local filters = {}
    local allFilter = alignAll and CreateAllFilter(conf) or nil

    for _, v in ipairs(conf) do
        local deployable, placer, prefabs = unpack(v)
        local filter = allFilter or AlignTo(prefabs)
        filters[placer] = filter
        filters[deployable] = filter
    end
    return filters
end

local FILTERS = GenerateFilters(SupportedPrefabs, GetModConfigData('ALIGN_DIFFERENT_OBJECTS'))

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
    print(("Found %d candidates to align"):format(#entities))
    return entities
end

local function SnapToEntities(position, snapFilter)
    if not position or not snapFilter then
        return position
    end
    local entities = FindEntities(position, SEARCH_RADIUS, snapFilter)

    return align.AlignPlacerToEntities(position, entities)
end

local function Snap(placer, position)
    local snapFilter = FILTERS[placer.inst.prefab]
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
        local filter = FILTERS[recipe.name]
        local aligned = SnapToEntities(pt, filter)
        return CanBuildAtPoint(self, aligned, recipe, ...)
    end

    function builder:MakeRecipe(recipe, pt, ...)
        local filter = FILTERS[recipe.name]
        local aligned = SnapToEntities(pt, filter)
        return MakeRecipe(self, recipe, aligned, ...)
    end
end)

AddComponentPostInit("deployable", function(deployable)
    local CanDeploy, Deploy = deployable.CanDeploy, deployable.Deploy
    function deployable:CanDeploy(pt, ...)
        local filter = FILTERS[self.inst.prefab]
        local aligned = SnapToEntities(pt, filter)
        return CanDeploy(self, aligned, ...)
    end

    function deployable:Deploy(pt, deployer, ...)
        local filter = FILTERS[self.inst.prefab]
        local aligned = SnapToEntities(pt, filter)
        return Deploy(self, aligned, deployer, ...)
    end
end)

