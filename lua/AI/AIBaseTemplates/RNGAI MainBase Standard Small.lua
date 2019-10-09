--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Small',

        -- Intel Builders --
        'RNGAI RadarBuilders',

        -- Economy Builders --
        'RNGAI Energy Builder',
        'RNGAI Mass Builder',
        'RNGAI Hydro Builder',
        'RNGAI ExtractorUpgrades',

        -- Land Unit Builders T1 --
        'RNGAI Engineer Builder',
        'RNGAI ScoutLandBuilder',
        'RNGAI LabLandBuilder',
        'RNGAI TankLandBuilder',
        'RNGAI Land AA',
        'RNGAI T1 Reaction Tanks',

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',

        -- Air Unit Builders T1 --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder',

        -- Air Unit Formers T1 --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',

        -- Defence Builders --
        'RNGAI T1 Base Defenses',
        'RNGAI T1 Perimeter Defenses',

    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 9,
            Tech2 = 3,
            Tech3 = 3,
            SCU = 2,
        },
        FactoryCount = {
            Land = 6,
            Air = 3,
            Sea = 0,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1Value = 6,
            T2Value = 15,
            T3Value = 22.5,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGStandard' and mapSizeX < 1000 and mapSizeZ < 1000 or personality == 'RNGStandardCheat' and mapSizeX < 1000 and mapSizeZ < 1000 then
            --LOG('### M-FirstBaseFunction '..personality)
            LOG('Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandardMainBaseTemplate Small'
        end
        return -1
    end,
}