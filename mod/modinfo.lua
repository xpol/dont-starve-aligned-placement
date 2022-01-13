name = 'Aligned Placement 对齐建造'
description = 'Help align to already planted/built/deployed same items. 帮助对齐到已经种植、建造、部署的相同物品。支持手柄和鼠标！'
author = 'xpolife'
version = '2.3.2'

icon_atlas = 'AlignedPlacement.xml'
icon = 'AlignedPlacement.tex'

forumthread = ''

api_version = 6

dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true

dst_compatible = true
api_version_dst = 10
client_only_mod = true
all_clients_require_mod = false

configuration_options = {
    {
        name = 'ALIGN_DIFFERENT_OBJECTS',
        label = 'Align different object 对齐不同的物品',
        hover = 'Allow align to a different kind of object 允许对齐到不同的物品',
        options = {
            {description = 'No', data = false},
            {description = 'Yes', data = true},
        },
        default = false,
    },
}
