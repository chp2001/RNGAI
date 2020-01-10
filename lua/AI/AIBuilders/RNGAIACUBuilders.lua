--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local SAI = '/lua/ScenarioPlatoonAI.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small Close',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small Distant',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Distant',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }

    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG','ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1000,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BuildStructures = {
                    'T1LandFactory',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                    'T1AirFactory',
                    'T1EnergyProduction',
                }
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncome',  { 0.5, 5.0}},
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.10}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.7 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 2, 'FACTORY LAND TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.10, 0.15}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { EBC, 'GreaterThanEconIncome',  { 0.7, 8.0}},
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.05, 0.30}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 1, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        BuilderConditions = {
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.70}},
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8 }},
            { UCBC, 'GreaterThanEnergyTrend', { 0.0 } },
            { UCBC, 'FactoryLessAtLocation', { 'LocationType', 3, 'FACTORY AIR TECH1' }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'FACTORY AIR TECH1' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 20',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = {            
            { MIBC, 'GreaterThanGameTime', { 70 } },
            { UCBC, 'LessThanEnergyTrend', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Trend'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Storage',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = {            
            { EBC, 'LessThanEconStorageRatio', { 0.0, 0.50}}, -- Ratio from 0 to 1. (1=100%) -- If our energy is trending into negatives
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.5, 0.2 }},
            { EBC, 'LessThanEconEfficiencyOverTime', { 2.0, 1.6 }},
            { UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Storage'}},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, 'ENERGYPRODUCTION TECH2' }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.4, 0.4}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Engineer',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.7, 0.8}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Factory',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ALLUNITS'},
                Time = 30,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Structure',
        PlatoonTemplate = 'CommanderAssist',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.6} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = 'Structure',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {'ENERGYPRODUCTION', 'FACTORY', 'STRUCTURE DEFENSE'},
                Time = 30,
            },
        }
    },
}

BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Gun',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'UEF CDR Enhancement HeavyAntiMatter',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 0.5, 50.0}},
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
                { UCBC, 'CmdrHasUpgrade', { 'HeavyAntiMatterCannon', false }},
                { MIBC, 'FactionIndex', {1}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeavyAntiMatterCannon' },
        },

    },
    Builder {
        BuilderName = 'Aeon CDR Enhancement Crysalis',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 0.5, 50.0}},
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
                { UCBC, 'CmdrHasUpgrade', { 'CrysalisBeam', false }},
                { MIBC, 'FactionIndex', {2}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            TimeBetweenEnhancements = 20,
            Enhancement = { 'HeatSink', 'CrysalisBeam'},
        },
    },
    Builder {
        BuilderName = 'Cybran CDR Enhancement CoolingUpgrade',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 0.5, 50.0}},
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
                { UCBC, 'CmdrHasUpgrade', { 'CoolingUpgrade', false }},
                { MIBC, 'FactionIndex', {3}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'CoolingUpgrade'},
        },

    },
    Builder {
        BuilderName = 'Seraphim CDR Enhancement RateOfFire',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncome',  { 0.5, 50.0}},
                { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.2 }},
                { UCBC, 'CmdrHasUpgrade', { 'RateOfFire', false }},
                { MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'RateOfFire' },
        },

    },
}