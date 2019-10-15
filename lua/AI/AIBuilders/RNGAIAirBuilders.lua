--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIFighterAirBuilders.lua
    Author  :   relentless
    Summary :
        Air Builders
]]

local EBC = '/lua/editor/EconomyBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory Bomber',
        PlatoonTemplate = 'T1AirBomber',
        Priority = 850,
        BuilderConditions = {
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { EBC, 'GreaterThanEconTrend', { 0.7, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.AIR * categories.BOMBER } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 850,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Response',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 950,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 10, categories.AIR * categories.ANTIAIR } },
            { TBC, 'EnemyThreatGreaterThanValueAtBase', { 'MAIN', 10, 'Air', 3 , 'RNGAI Factory Intie Response'} },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 500,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 18, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
    Builder {
        BuilderName = 'RNGAI Factory Intie Small',
        PlatoonTemplate = 'T1AirFighter',
        Priority = 950,
        BuilderConditions = { 
            { EBC, 'GreaterThanEconStorageRatio', { 0.0, 0.7}},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.AIR * categories.ANTIAIR } },
        },
        BuilderType = 'Air',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Builder T2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI Factory FighterBomber',
        PlatoonTemplate = 'T2FighterBomber',
        Priority = 500,
        BuilderType = 'Air',
        BuilderConditions = { 
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconTrend', { 0.5, 7.0 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 8, categories.AIR * categories.ANTIAIR } },
        },
    },
    Builder {
        BuilderName = 'TNGAI T2 Air Gunship',
        PlatoonTemplate = 'T2AirGunship',
        Priority = 400,
        BuilderType = 'Air',
        BuilderConditions = {
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.05 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 8, categories.AIR * categories.GROUNDATTACK * categories.TECH2} },
        },
    },
}

    

BuilderGroup {
    BuilderGroupName = 'RNGAI Air Platoon Builder',
    BuildersType = 'PlatoonFormBuilder', -- A PlatoonFormBuilder is for builder groups of units.
    Builder {
        BuilderName = 'RNGAI Air Intercept',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        Priority = 900,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2 + categories.TECH3) * categories.ANTIAIR } },
         },
    },
    Builder {
        BuilderName = 'RNGAI AntiAir Base Guard',
        PlatoonTemplate = 'RNGAI AntiAirBaseGuard',
        Priority = 800,
        InstanceCount = 2,
        BuilderType = 'Any',
        BuilderData = {
            NeverGuardEngineers = true,
            GuardRadius = 200, -- this is in the guardBase function as self.PlatoonData.GuardRadius
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 2, categories.AIR * categories.MOBILE * (categories.TECH1 + categories.TECH2) * categories.ANTIAIR } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Attack',
        PlatoonTemplate = 'RNGAI BomberAttack',
        Priority = 900,
        InstanceCount = 3,
        BuilderType = 'Any',        
        BuilderConditions = { 
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, 'AIR MOBILE TECH2, AIR MOBILE TECH3' } },
        },
        BuilderData = {
            SearchRadius = 100,
            PrioritizedCategories = {
                'MASSEXTRACTION',
                'ENGINEER TECH1',
                'MOBILE ANTIAIR',
                'ALLUNITS',
            },
        },
    },
    Builder {
        BuilderName = 'RNGAI Bomber Attack T2',
        PlatoonTemplate = 'BomberAttack',
        Priority = 800,
        InstanceCount = 3,
        BuilderType = 'Any',
        BuilderData = {
            PrioritizedCategories = {
                'COMMAND',
                'MASSEXTRACTION',
                'ENERGYPRODUCTION',
                'MASSFABRICATION',
                'ANTIAIR STRUCTURE',
                'DEFENSE STRUCTURE',
                'STRUCTURE',
                'MOBILE ANTIAIR',
                'ALLUNITS',
            },
        },
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, 'AIR MOBILE BOMBER' } },
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, 'AIR MOBILE TECH3' } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Gunship Attack T2',
        PlatoonTemplate = 'GunshipAttack',
        Priority = 400,
        InstanceCount = 5,
        BuilderType = 'Any',
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', { 'LocationType', 1, 'AIR MOBILE GROUNDATTACK' } },
            { UCBC, 'PoolLessAtLocation', { 'LocationType', 1, 'AIR MOBILE TECH3' } },
        },
    },
    Builder {
        BuilderName = 'RNGAI Air Intercept Response',
        PlatoonTemplate = 'RNGAI AntiAirHunt',
        Priority = 950,
        InstanceCount = 5,
        BuilderType = 'Any',     
        BuilderConditions = { 
            { TBC, 'EnemyThreatGreaterThanValueAtBase', { 'MAIN', 10, 'Air', 3 , 'RNGAI Factory Intie Response'} },
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI TransportFactoryBuilders',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Air Transport',
        PlatoonTemplate = 'T1AirTransport',
        Priority = 550,
        BuilderConditions = {
            { MIBC, 'ArmyNeedsTransports', {} },
            { UCBC, 'LocationFactoriesBuildingLess', { 'LocationType', 2, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 25, 'TRANSPORTFOCUS' } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuilt', { 1, 'TRANSPORTFOCUS' } },
            { IBC, 'BrainNotLowPowerMode', {} },
            { EBC, 'GreaterThanEconEfficiencyOverTime', { 0.9, 1.05 }},
        },
        BuilderType = 'Air',
    },
}