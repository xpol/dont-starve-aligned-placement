std = 'max'
globals = {
  'GLOBAL',
  'AddAction',
  'AddBrainPostInit',
  'AddClassPostConstruct',
  'AddComponentPostInit',
  'AddCookerRecipe',
  'AddGamePostInit',
  'AddGlobalClassPostConstruct',
  'AddIngredientValues',
  'AddLevel',
  'AddLevelPreInit',
  'AddLevelPreInitAny',
  'AddMinimapAtlas',
  'AddModCharacter',
  'AddPlayerPostInit',
  'AddPrefabPostInit',
  'AddPrefabPostInitAny',
  'AddRoom',
  'AddRoomPreInit',
  'AddSimPostInit',
  'AddStategraphActionHandler',
  'AddStategraphEvent',
  'AddStategraphPostInit',
  'AddStategraphState',
  'AddTask',
  'AddTaskPreInit',
  'AddTreasure',
  'AddTreasureLoot',
  'AddTreasureLootPreInit',
  'AddTreasurePreInit',
  'Asset',
  'Assets',
  'GetModConfigData',
  'LoadPOFile',
  'Recipe',
  'RemapSoundEvent',
  'Vector3',
}

files['mod/modinfo.lua'].globals = {
  'name',
  'version',
  'description',
  'author',
  'forumthread',
  'api_version',
  'icon_atlas',
  'icon',
  'dont_starve_compatible',
  'reign_of_giants_compatible',
  'shipwrecked_compatible',
  'dst_compatible',
  'configuration_options',
}

files["spec/**/*_spec.lua"].globals = {
  "assert",
  "describe",
  "it",
}
