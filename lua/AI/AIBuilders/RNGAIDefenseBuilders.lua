--[[
    File    :   /lua/AI/AIBuilders/RNGAIDefenceBuilders.lua
    Author  :   relentless
    Summary :
        Defence Builders, for thos pesky units that slip past. Like bombers.
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'


BuilderGroup {
    BuilderGroupName = 'RNGAI Base Defenses',
    BuildersType = 'EngineerBuilder',
    --[[Builder {
        BuilderName = 'RNGAI T1 Defence Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 875,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.30}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER } },
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
            DesiresAssist = true,
            NumAssistees = 5,
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
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * (categories.TECH2 + categories.TECH3)} },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, 'DEFENSE'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 2, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * (categories.TECH2 + categories.TECH3)} },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, 'DEFENSE TECH2 ANTIAIR'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 2, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER * (categories.TECH3)} },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, 'DEFENSE ANTIAIR TECH3'}},
            { MIBC, 'GreaterThanGameTime', { 300 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.6, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 2, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 825,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 0, categories.ENGINEER } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, 'DEFENSE TECH2'}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.30}},
            { MIBC, 'GreaterThanGameTime', { 480 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Base D Engineer AA',
        PlatoonTemplate = 'T3EngineerBuilder',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, 'DEFENSE TECH3 ANTIAIR STRUCTURE'}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3 } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.8, 1.1 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE TECH3 ANTIAIR STRUCTURE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                AvoidCategory = 'TECH3 ANTIAIR STRUCTURE',
                maxUnits = 1,
                maxRadius = 10,
                AdjacencyCategory = 'SHIELD STUCTURE, FACTORY TECH3, FACTORY TECH2, FACTORY',
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Expansion TML',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer',
        PlatoonTemplate = 'T2EngineerBuilder',
        Priority = 825,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTime', { 720 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiency', { 1.0, 1.0}},
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.30}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { UCBC, 'CheckUnitRange', { 'LocationType', 'T2StrategicMissile', categories.STRUCTURE + (categories.LAND * (categories.TECH2 + categories.TECH3)) } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
}


-- Defenses surrounding the base in patrol points

BuilderGroup {
    BuilderGroupName = 'RNGAI T1 Perimeter Defenses',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence - Perimeter',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { MIBC, 'GreaterThanGameTime', { 360 } },
            { EBC, 'GreaterThanEconStorageRatio', { 0.15, 0.30}},
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                NearBasePatrolPoints = true,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Defense FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T2 TML Silo',
        PlatoonTemplate = 'T2TacticalLauncher',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 10000,
        BuilderType = 'Any',
    },
    Builder {
        BuilderName = 'RNGAI T2 Artillery',
        PlatoonTemplate = 'T2ArtilleryStructure',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 10000,
        BuilderType = 'Any',
    },
}