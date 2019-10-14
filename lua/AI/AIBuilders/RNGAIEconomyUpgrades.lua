local EBC = '/lua/editor/EconomyBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI ExtractorUpgrades',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNG T1 Mass Extractor Upgrade Close',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 400,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 2.2, 20}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNG T1 Mass Extractor Upgrade Close',
        PlatoonTemplate = 'T1MassExtractorUpgrade',
        InstanceCount = 1,
        Priority = 400,
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconIncome',  { 2.2, 20}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
            { MIBC, 'GreaterThanGameTime', { 960 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'MASSEXTRACTION TECH2', 'MASSEXTRACTION' } },
        },
        FormRadius = 10000,
        BuilderType = 'Any',
    },
}