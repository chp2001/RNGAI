local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

local LandMode = function(self, aiBrain, builderManager, builderData)
    --LOG('Setting T1 Queue to Eng')
    if builderData.TechLevel == 1 then
        return 745
    elseif builderData.TechLevel == 2 then
        return 750
    elseif builderData.TechLevel == 3 then
        return 755
    end
    return 0
end

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 744, -- After second engie group
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 745,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'tank'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 743,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'arty'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 AA',
        PlatoonTemplate = 'T1LandAA',
        Priority = 742,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'aa'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Mex Engineer',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 746,
        BuilderConditions = {
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.4, 'greater'} },
            { EBC, 'MexesToBeClaimedRNG', { 3 } },
            { UCBC, 'LessThanIdleEngineersRNG', { 1 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            { EBC, 'CoinFlipRNG', { 0.6 }},
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Excess Engineer',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 747,
        BuilderConditions = {
            { UCBC, 'LessThanIdleEngineersRNG', { 1 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            { EBC, 'CoinFlipRNG', { 0.2 }},
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 First Engineers',
        PlatoonTemplate = 'T1BuildEngineer',
        Priority = 748,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.ENGINEER }},
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Tank',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 750,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'tank'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Bot',
        PlatoonTemplate = 'RNGAIT2AttackBot',
        Priority = 749,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'bot'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 AA',
        PlatoonTemplate = 'T2LandAA',
        Priority = 746,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'aa'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield',
        PlatoonTemplate = 'T2MobileShields',
        Priority = 747,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'shield'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 748,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'mml'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile Stealth',
        PlatoonTemplate = 'RNGAIT2MobileStealth',
        Priority = 746,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'stealth'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T3',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Tank',
        PlatoonTemplate = 'T3LandBot',
        Priority = 755,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'tank'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Armoured',
        PlatoonTemplate = 'T3ArmoredAssault',
        Priority = 755,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'armoured'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 AA',
        PlatoonTemplate = 'T3LandAA',
        Priority = 752,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'aa'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 753,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'arty'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Shields',
        PlatoonTemplate = 'T3MobileShields',
        Priority = 751,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'shield'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Sniper',
        PlatoonTemplate = 'T3SniperBots',
        Priority = 754,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'sniper'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Missile',
        PlatoonTemplate = 'T3MobileMissile',
        Priority = 754,
        --PriorityFunction = LandMode,
        BuilderConditions = {
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'mml'} },
            { EBC, 'FactorySpendRatioUnitRNG', {'Land', 0.8} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

