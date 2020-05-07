--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Large',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNGAI Initial ACU Builder Large',

        -- ACU MainBase Builder --
        'RNGAI ACU Structure Builders Large',
        'RNGAI ACU Enhancements Tier Large',

        -- Expansion Builders --
        'RNGAI Engineer Expansion Builders Large',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        'RNGAI T1 Assist Builders',
        'RNGAI T2 Assist Builders',
        'RNGAI Energy Production Reclaim',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade',
        'RNGAI RadarUpgrade T1 Expansion',
        
        -- Economy Builder --
        'RNGAI Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        'RNGAI Mass Fab',

        -- Scout Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI ScoutLandBuilder',

        -- Scout Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI ScoutLandFormer',
        
        -- Defence Builders --
        'RNGAI Base Defenses',
        'RNGAI T1 Perimeter Defenses',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',

        -- Land Unit Builders --
        'RNGAI TankLandBuilder Large',
        'RNGAI Land AA 2',
        'RNGAI T2 TankLandBuilder Large',
        'RNGAI T3 AttackLandBuilder Large',
        'RNGAI Island Large FormBuilders',


        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',
        'RNGAI Land Response Formers',

        -- Air Unit Builders --
        'RNGAI TransportFactoryBuilders',
        'RNGAI Air Builder T1',
        'RNGAI Air Builder T2',
        'RNGAI Air Builder T3',

        -- Air Unit Formers --
        'RNGAI Air Response Formers',
        'RNGAI Air Platoon Builder',

        -- Land Factory Builders --
        'RNGAI Factory Builder Land Large',

        -- Land Upgrade Builders --
        'RNGAI Land Upgrade Builders',

        -- Air Upgrade Builders --
        'RNGAI Air Upgrade Builders',

        -- RNGAI Air Support Builders --
        'RNGAI Air Staging Platform',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

        -- Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders',
        'RNGAI Strategic Formers',

        -- Experimentals --
        'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',

        -- Sea Builders --
        'RNGAI Factory Builder Sea Large',
        'RNGAI Sea Upgrade Builders',
        'RNGAI Sea Builders T1',
        'RNGAI Sea Builders T23',

        -- Sea Formers --
        'RNGAI Sea Formers',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 15,
            Tech2 = 12,
            Tech3 = 10,
            SCU = 6,
        },
        FactoryCount = {
            Land = 12,
            Air = 6,
            Sea = 6,
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
        if personality == 'RNGStandard' and mapSizeX > 1000 and mapSizeZ > 1000 or personality == 'RNGStandardcheat' and mapSizeX > 1000 and mapSizeZ > 1000 then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is large', mapSizeX, mapSizeZ)
            return 1000, 'RNGStandard'
        end
        return -1
    end,
}