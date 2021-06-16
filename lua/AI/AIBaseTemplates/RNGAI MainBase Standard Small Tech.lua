--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Tech',
    Builders = {
        -- ACU MainBase Initial Builder --
        'RNG Tech Initial ACU Builder Small',

        -- ACU Other Builders --
        'RNG Tech ACU Build Assist',
        'RNG Tech ACU Structure Builders',
        --'RNGAI Test PD',
        --'RNGAI ACU Enhancements Gun',
        --'RNGAI ACU Enhancements Tier',

        -- Intel Builders --
        'RNGAI RadarBuilders',
        'RNGAI RadarUpgrade',

        -- Economy Builders --
        'RNG Tech Energy Builder',
        'RNGAI Energy Storage Builder',
        'RNGAI Mass Builder',
        'RNGAI Mass Storage Builder',
        'RNGAI Hydro Builder',
        --'RNGAI ExtractorUpgrades',
        'RNGAI Mass Fab',

        -- Engineer Builders --
        'RNGAI Engineer Builder',
        'RNGAI Engineering Support Builder',
        'RNGAI T1 Reclaim Builders',
        --'RNGAI Assist Builders',
        --'RNGAIR Hard Assist Builders',
        'RNGAI Energy Production Reclaim',
        'RNGAI Engineer Transfer To Active Expansion',
        --'RNGAI Assist Manager BuilderGroup',
        'RNG Tech Energy Assist',

        -- Land Unit Builders T1 --
        'RNGAI ScoutLandBuilder',
        --'RNGAI LabLandBuilder', -- Remove to use queue
        'RNGAI TankLandBuilder Small',
        --'RNGAI Land AA 2',
        --'RNGAI Reaction Tanks',
        'RNGAI T3 AttackLandBuilder Small',
        --'RNG Tech InitialBuilder Small',
        --'RNG Tech T3 Land Builder Small',
        

        -- Land Unit Formers T1 --
        'RNGAI ScoutLandFormer',
        'RNGAI Land Mass Raid',
        'RNGAI Land FormBuilders',
        'RNGAI Mass Hunter Labs FormBuilders',
        --'RNGAI Land Response Formers',
        'RNG Tech Hero FormBuilders',

        -- Land Factory Builders --
        'RNG Tech Factory Builder Land',   
        --'RNG Tech Factory Builder Land',
        'RNG Tech Support Factory Builder Land',
        'RNG Tech Land Factory Reclaimer',
        'RNGAI LandBuilder T1',
        'RNGAI LandBuilder T2',
        'RNGAI LandBuilder T3',

        -- Land Factory Formers --
        'RNG Tech Land Upgrade Builders',
        'RNGAI Land Upgrade Builders',
        'RNG Tech Land Support Upgrade Builders',

        -- Air Factory Builders --
        'RNGAI Factory Builder Air',
        'RNG Tech Air Staging Platform',
        
        -- Sea Factory Builders
        --'RNGAI Factory Builder Sea',

        -- Air Factory Formers --
        'RNGAI Air Upgrade Builders',

        -- Air Unit Builders --
        'RNGAI ScoutAirBuilder',
        'RNGAI Air Builder T1 Ratio',
        'RNGAI Air Builder T2 Ratio',
        'RNGAI Air Builder T3 Ratio',
        'RNGAI TransportFactoryBuilders Small',
        'RNGAI Air Builder T3',

        -- Air Unit Formers --
        'RNGAI ScoutAirFormer',
        'RNGAI Air Platoon Builder',
        'RNGAI Air Response Formers',

        -- Sea Unit Builders
        --'RNGAI Sea Builders T1',
        
        -- Sea Unit Formers
        --'RNGAI Sea Formers',
        --'RNGAI Mass Hunter Sea Formers',
        
        -- Defence Builders --
        'RNGAI Base Defenses',
        'RNGAI Perimeter Defenses Small',
        'RNGAI T2 Defense FormBuilders',
        'RNGAI Shield Builder',
        'RNGAI Shields Upgrader',
        'RNGAI SMD Builders',
        'RNGAI Perimeter Defenses Expansions',

        -- Expansions --
        'RNGAI Engineer Expansion Builders Small',

        -- SACU Builders --
        'RNGAI Gate Builders',
        'RNGAI SACU Builder',

        --Strategic Builders
        'RNGAI SML Builders',
        'RNGAI Strategic Artillery Builders Small',
        'RNGAI Strategic Formers',

        --Experimentals --
        'RNGAI Experimental Builders',
        'RNGAI Experimental Formers',
    },
    NonCheatBuilders = {
    },
    BaseSettings = {
        EngineerCount = {
            Tech1 = 20,
            Tech2 = 12,
            Tech3 = 8,
            SCU = 6,
        },
        FactoryCount = {
            Land = 15,
            Air = 5,
            Sea = 1,
            Gate = 1,
        },
        MassToFactoryValues = {
            T1Value = 4.4,
            T2Value = 11,
            T3Value = 19,
        },

    },
    ExpansionFunction = function(aiBrain, location, markerType)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGTech' or personality == 'RNGTechcheat' then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGTech'
        end
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'RNGTech' or personality == 'RNGTechcheat' then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'RNGTech'
        end
        return -1
    end,
}