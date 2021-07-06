

-- Former Templates --

PlatoonTemplate {
    Name = 'TechAI AntiAirHunt',
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 100, 'Attack', 'none' },
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 0, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'TechAI AntiAirLockdown',
    Plan = 'AirHuntAI',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.GROUNDATTACK - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 100, 'Attack', 'none' },
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 0, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'TechAI AirScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 4, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'TechAI AirScoutSingle',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * (categories.TECH1 + categories.TECH3), 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'TechAI ResponseAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR *(categories.BOMBER + categories.GROUNDATTACK) - categories.daa0206 - categories.EXPERIMENTAL - categories.TRANSPORTFOCUS, 1, 100, 'Attack', 'NoFormation' },
    }
}

PlatoonTemplate {
    Name = 'TechAI BomberAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'TechAI GunShipAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.GROUNDATTACK - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'TechAI BomberEnergyAttack',
    Plan = 'StrikeForceAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY - categories.daa0206, 1, 5, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'TechAI MercyAttack',
    Plan = 'MercyAIRNG',
    GlobalSquads = {
        { categories.daa0206 , 2, 3, 'Attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'TechAI TorpBomberAttack',
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.ANTINAVY - categories.EXPERIMENTAL, 1, 50, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'T4ExperimentalAirRNG',
    Plan = 'ExperimentalAIHubRNG',
    GlobalSquads = {
        { categories.AIR * categories.EXPERIMENTAL * categories.MOBILE - categories.SATELLITE, 1, 1, 'attack', 'none' },
    },
}

PlatoonTemplate {
    Name = 'T2AirMissile',
    FactionSquads = {
        Aeon = {
            { 'daa0206', 1, 4, 'Attack', 'none' },
        },
    }
}
PlatoonTemplate {
    Name = 'TechAIFighterGroup',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 3, 'Attack', 'None' },
            { 'uea0101', 1, 1, 'scout', 'None' }
        },
        Aeon = {
            { 'uaa0102', 1, 3, 'Attack', 'None' },
            { 'uaa0101', 1, 1, 'scout', 'None' }
        },
        Cybran = {
            { 'ura0102', 1, 3, 'Attack', 'None' },
            { 'ura0101', 1, 1, 'scout', 'None' }
        },
        Seraphim = {
            { 'xsa0102', 1, 3, 'Attack', 'None' },
            { 'xsa0101', 1, 1, 'scout', 'None' }
        },
    }
}

PlatoonTemplate {
    Name = 'TechAIFighterGroupT2',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 3, 'Attack', 'None' }, -- T1 Fighter
            { 'dea0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
        Aeon = {
            { 'xaa0202', 1, 4, 'Attack', 'None' }, -- T2 Fighter
        },
        Cybran = {
            { 'ura0102', 1, 3, 'Attack', 'None' }, -- T1 Fighter
            { 'dra0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
        Seraphim = {
            { 'xsa0102', 1, 3, 'Attack', 'None' }, -- T1 Fighter
            { 'xsa0202', 1, 1, 'Attack', 'None' } -- T2 FighterBomber
        },
    }
}

PlatoonTemplate {
    Name = 'TechAIT1AirQueue',
    FactionSquads = {
        UEF = {
            { 'uea0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uea0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Aeon = {
            { 'uaa0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'uaa0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
        Cybran = {
            { 'ura0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'ura0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
            { 'xra0105', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Gunship
            
        },
        Seraphim = {
            { 'xsa0102', 1, 1, 'Attack', 'GrowthFormation' }, -- T1 Fighter
            { 'xsa0103', 1, 2, 'Attack', 'GrowthFormation' }, -- T1 Bomber
        },
    }
}

PlatoonTemplate {
    Name = 'TechAIT2AirQueue',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 2, 'Attack', 'None' }, -- FighterBomber
            { 'uea0203', 1, 2, 'Attack', 'None' }, -- Gunship
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'Attack', 'None' },-- Fighter
            { 'uaa0203', 1, 2, 'Attack', 'None' },-- Gunship
        },
        Cybran = {
            { 'dra0202', 1, 2, 'Attack', 'None' },-- FighterBomber
            { 'ura0203', 1, 2, 'Attack', 'None' },-- Gunship
        },
        Seraphim = {
            { 'xsa0202', 1, 2, 'Attack', 'None' },-- FighterBomber
            { 'xsa0203', 1, 2, 'Attack', 'None' }, -- Gunship
        },
    },
}

PlatoonTemplate {
    Name = 'TechAIT2FighterAeon',
    FactionSquads = {
        UEF = {
            { 'dea0202', 1, 1, 'Attack', 'None' },
        },
        Aeon = {
            { 'xaa0202', 1, 1, 'Attack', 'None' },
        },
        Cybran = {
            { 'dra0202', 1, 1, 'Attack', 'None' },
        },
        Seraphim = {
            { 'xsa0202', 1, 1, 'Attack', 'None' },
        },
    },
}

PlatoonTemplate { Name = 'TechAIT3AirResponse',
    FactionSquads = {
        UEF = {
            { 'uea0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
         },
        Aeon = {
            { 'uaa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
        Cybran = {
            { 'ura0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
        Seraphim = {
            { 'xsa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
        },
    }
}

PlatoonTemplate { 
    Name = 'TechAIT3AirQueue',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 1, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 2, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 4, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 1, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 3, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 1, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 3, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}

PlatoonTemplate { 
    Name = 'TechAIT3AirAttackQueue',
    FactionSquads = {
        UEF = {
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uea0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uea0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'uea0305', 1, 2, 'Guard', 'none' },   -- Gunship
         },
        Aeon = {
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'uaa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'uaa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xaa0305', 1, 2, 'Guard', 'none' },   -- Gunship
        },
        Cybran = {
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0304', 1, 1, 'Artillery', 'none' },      -- Strategic Bomber
            { 'ura0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'ura0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
            { 'xra0305', 1, 2, 'Guard', 'none' },   -- Gunship
        },
        Seraphim = {
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0303', 1, 1, 'Attack', 'none' },      -- Air Superiority Fighter
            { 'xsa0302', 1, 1, 'Attack', 'none' },      -- Scout
            { 'xsa0304', 1, 2, 'Artillery', 'none' },       -- Strategic Bomber
            { 'xsa0303', 1, 1, 'Attack', 'none' },   -- Air Superiority Fighter
        },
    }
}