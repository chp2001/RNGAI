--[[
    File    :   /lua/AI/AIBaseTemplates/TechAI MainBase Standard.lua
    Author  :   relentless
    Summary :
        Main Base template
]]

BaseBuilderTemplate {
    BaseTemplateName = 'RNGStandardMainBaseTemplate Small Tech',
    Builders = {

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
        if personality == 'TechAI' or personality == 'TechAIcheat' then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'TechAI'
        end
        return -1
    end,
    FirstBaseFunction = function(aiBrain)
        local personality = ScenarioInfo.ArmySetup[aiBrain.Name].AIPersonality
        local mapSizeX, mapSizeZ = GetMapSize()
        if personality == 'TechAI' or personality == 'TechAIcheat' then
            --LOG('* AI-RNG: ### M-FirstBaseFunction '..personality)
            --LOG('* AI-RNG: Map size is small', mapSizeX, mapSizeZ)
            return 1000, 'TechAI'
        end
        return -1
    end,
}