--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 30',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 1000,
        InstanceCount = 2,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 30,
                ThreatMin = -500,
                ThreatMax = 5,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 60',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 60, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 60,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 120',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 850,
        InstanceCount = 4,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 120, -500, 0, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 120,
                ThreatMin = -500,
                ThreatMax = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 240',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 6,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 240, -500, 2, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 120,
                Type = 'Mass',
                MaxDistance = 240,
                ThreatMin = -500,
                ThreatMax = 5,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 480',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 700,
        InstanceCount = 6,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 180 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 480, -500, 2, 30, 'AntiSurface', 1}},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = true,
                Distance = 120,
                Type = 'Mass',
                MaxDistance = 480,
                ThreatMin = -500,
                ThreatMax = 5,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },

    Builder {
        BuilderName = 'RNGAI T1Engineer Mass 2000',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 300,
        InstanceCount = 7,
        BuilderConditions = { 
            { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
            { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 2000, -500, 10, 0, 'AntiSurface', 1}},
            
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 1000,
                ThreatMin = -500,
                ThreatMax = 10,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
}


BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Fab',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI Mass Fab',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 500,
        DelayEqualBuildPlattons = {'MassFab', 7},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassFab' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveUnitRatioRNG', { 0.3, categories.STRUCTURE * categories.MASSFABRICATION, '<=',categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'LessThanEconStorageRatio', { 0.10, 2 } },
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.MASSFABRICATION } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCapRNG', { 0.10 , '<', categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSFABRICATION) } },
    
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 4,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyDistance = 80,
                AvoidCategory = categories.MASSFABRICATION,
                maxUnits = 1,
                maxRadius = 15,
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI Mass Fab Adja',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 400,
        DelayEqualBuildPlattons = {'MassFab', 7},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassFab' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            -- Do we need additional conditions to build it ?
            { UCBC, 'HaveUnitRatioRNG', { 0.5, categories.STRUCTURE * categories.MASSFABRICATION, '<=',categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 } },
            --{ UCBC, 'HasNotParagon', {} },
            -- Have we the eco to build it ?
            { EBC, 'LessThanMassTrendRNG', { 5.0 } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.95}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } }, -- relative income
            -- Don't build it if...
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 1, categories.STRUCTURE * categories.MASSFABRICATION } },
            -- Respect UnitCap
            { UCBC, 'HaveUnitRatioVersusCapRNG', { 0.10 , '<', categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSFABRICATION) } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 5,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyDistance = 80,
                AvoidCategory = categories.MASSFABRICATION,
                maxUnits = 1,
                maxRadius = 15,
                BuildClose = true,
                BuildStructures = {
                    'T3MassCreation',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Builder Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 30 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 850,
        InstanceCount = 2,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 30, -500, 1, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 30,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 150 Expansion',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 150, -500, 1, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 150,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1ResourceEngineer 1000 Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 550,
        InstanceCount = 2,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 420 } },
                { MABC, 'CanBuildOnMassLessThanDistance', { 'LocationType', 2000, -500, 50, 0, 'AntiSurface', 1 }},
            },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                MaxDistance = 2000,
                ThreatMin = -500,
                ThreatMax = 30,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Mass Storage Builder',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 150, -3, 0, 0}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyCheck', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 100, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                AdjacencyDistance = 100,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'MassStorage',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNG T1 Mass Adjacency Engineer Distant',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 400,
        DelayEqualBuildPlattons = {'MassStorage', 5},
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'MassStorage' }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 3, categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3)}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 500, -3, 0, 0}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyCheck', { 'LocationType', categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3), 500, 'ueb1106' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.MASSEXTRACTION * (categories.TECH2 + categories.TECH3),
                AdjacencyDistance = 500,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'MassStorage',
                }
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAIR Crazyrush Builder',                               -- BuilderGroupName, initalized from AIBaseTemplates in "\lua\AI\AIBaseTemplates\"
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAIR T1 Mex Adjacency Engineer',
        PlatoonTemplate = 'EngineerBuilderT123RNG',
        Priority = 900,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 150, -3, 5, 0}},
            { EBC, 'GreaterThanEconStorageRatio', { -0.1, 0.1 }},
            { EBC, 'LessThanEconStorageRatio', { 1, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 200, categories.MASSEXTRACTION}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyCheck', { 'LocationType', categories.MASSEXTRACTION, 100, 'ueb1103' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.MASSEXTRACTION,
                AdjacencyDistance = 100,
                BuildClose = false,
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
    Builder {
        BuilderName = 'RNGAIR T1 Mex Adjacency Engineer Distant',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 400,
        InstanceCount = 12,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.MASSEXTRACTION}},
            { MABC, 'MarkerLessThanDistance',  { 'Mass', 500, -3, 0, 0}},
            { EBC, 'LessThanEconStorageRatio', { 0.2, 1.1 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 200, categories.MASSEXTRACTION}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
            { UCBC, 'AdjacencyCheck', { 'LocationType', categories.MASSEXTRACTION, 500, 'ueb1103' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                AdjacencyCategory = categories.MASSEXTRACTION,
                AdjacencyDistance = 500,
                BuildClose = false,
                ThreatMin = -3,
                ThreatMax = 0,
                ThreatRings = 0,
                BuildStructures = {
                    'T1Resource',
                }
            }
        }
    },
}
