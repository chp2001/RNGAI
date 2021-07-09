WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * TechAI: offset aibrain.lua' )

local RUtils = import('/mods/TechAI/lua/AI/RNGUtilities.lua')
local DebugArrayRNG = import('/mods/TechAI/lua/AI/RNGUtilities.lua').DebugArrayRNG
local AIUtils = import('/lua/ai/AIUtilities.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local PlatoonGenerateSafePathToRNG = import('/lua/AI/aiattackutilities.lua').PlatoonGenerateSafePathToRNG

local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GiveResource = moho.aibrain_methods.GiveResource
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatsAroundPosition = moho.aibrain_methods.GetThreatsAroundPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local VDist2Sq = VDist2Sq
local WaitTicks = coroutine.yield

local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local CreateDilliDalliBrain = import('/mods/TechAI/lua/AI/DilliDalli/Brain.lua').CreateBrain
local TechAIBrainClass = AIBrain
AIBrain = Class(TechAIBrainClass) {

    OnCreateAI = function(self, planName)
        TechAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        --LOG('Oncreate')
        self:CreateBrainShared(planName)
        if string.find(per, 'TechAI') then
            --LOG('* AI-RNG: This is RNG')
            self.TechAI = true
            self.DilliDalli = true
            self.DilliDalliBrain = CreateDilliDalliBrain(self)
        end
    end,

    --[[OnSpawnPreBuiltUnits = function(self)
        if not self.TechAI then
            return TechAIBrainClass.OnSpawnPreBuiltUnits(self)
        end
        local factionIndex = self:GetFactionIndex()
        local resourceStructures = nil
        local initialUnits = nil
        local posX, posY = self:GetArmyStartPos()

        if factionIndex == 1 then
            resourceStructures = {'UEB1103', 'UEB1103', 'UEB1103', 'UEB1103'}
            initialUnits = {'UEB0101', 'UEB1101', 'UEB1101', 'UEB1101', 'UEB1101'}
        elseif factionIndex == 2 then
            resourceStructures = {'UAB1103', 'UAB1103', 'UAB1103', 'UAB1103'}
            initialUnits = {'UAB0101', 'UAB1101', 'UAB1101', 'UAB1101', 'UAB1101'}
        elseif factionIndex == 3 then
            resourceStructures = {'URB1103', 'URB1103', 'URB1103', 'URB1103'}
            initialUnits = {'URB0101', 'URB1101', 'URB1101', 'URB1101', 'URB1101'}
        elseif factionIndex == 4 then
            resourceStructures = {'XSB1103', 'XSB1103', 'XSB1103', 'XSB1103'}
            initialUnits = {'XSB0101', 'XSB1101', 'XSB1101', 'XSB1101', 'XSB1101'}
        end

        if resourceStructures then
            -- Place resource structures down
            for k, v in resourceStructures do
                local unit = self:CreateResourceBuildingNearest(v, posX, posY)
                local unitBp = unit:GetBlueprint()
                if unit ~= nil and unitBp.Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
                if unit ~= nil then
                    if not self.StructurePool then
                        RUtils.CheckCustomPlatoons(self)
                    end
                    local StructurePool = self.StructurePool
                    self:AssignUnitsToPlatoon(StructurePool, {unit}, 'Support', 'none' )
                    local upgradeID = unitBp.General.UpgradesTo or false
                    --LOG('* AI-RNG: BlueprintID to upgrade to is : '..unitBp.General.UpgradesTo)
                    if upgradeID and __blueprints[upgradeID] then
                        RUtils.StructureUpgradeInitialize(unit, self)
                    end
                    local unitTable = StructurePool:GetPlatoonUnits()
                    --LOG('* AI-RNG: StructurePool now has :'..table.getn(unitTable))
                end
            end
        end

        if initialUnits then
            -- Place initial units down
            for k, v in initialUnits do
                local unit = self:CreateUnitNearSpot(v, posX, posY)
                if unit ~= nil and unit:GetBlueprint().Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
            end
        end

        self.PreBuilt = true
    end,]]

    InitializeSkirmishSystems = function(self)
        self:ForkThread(RUtils.DisplayEconomyRNG)
        if not self.TechAI then
            self.HeavyEco = self:ForkThread(self.HeavyEconomyRNG)
            return TechAIBrainClass.InitializeSkirmishSystems(self)
        end
        
        --if we aren't running team share thread, check if we have teammates
        local selfindex = self:GetArmyIndex()
        local DoMexConstruct=false
        if not self.TeamMexAllocation then
            for _, v in ArmyBrains do
                local testIndex = v:GetArmyIndex()
                if IsEnemy(selfindex, testIndex) or ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" or testIndex==selfindex then continue end
                DoMexConstruct=true
                break
            end
        end
        --if we aren't running team share thread and want to, start it
        if DoMexConstruct and not self.TeamMexAllocation then
            self:ForkThread(RUtils.ThrottledAllocateRNG)
        end
        --LOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon:TurnOffPoolAI()
        end
        --local mapSizeX, mapSizeZ = GetMapSize()
        --LOG('Map X size is : '..mapSizeX..'Map Z size is : '..mapSizeZ)
        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}
        -- this is for chps fav map, when the masspoint are created they are not put in the scenariocache
        self.crazyrush = false

        self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

        -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
        self.EconomyData = {}
        self.EconomyTicksMonitor = 50
        self.EconomyCurrentTick = 1
        self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitorRNG)
        self.EconomyOverTimeCurrent = {}
        self.EconomyOverTimeThread = self:ForkThread(self.EconomyOverTimeRNG)
        self.EngineerAssistManagerActive = false
        self.EngineerAssistManagerEngineerCount = 0
        self.EngineerAssistManagerEngineerCountDesired = 0
        self.EngineerAssistManagerBuildPowerDesired = 5
        self.EngineerAssistManagerBuildPowerRequired = 0
        self.EngineerAssistManagerBuildPower = 0
        self.EngineerAssistManagerPriorityTable = {}
        self.cmanager = {
            income = {
                r  = {
                    m = 0,
                    e = 0,
                },
                t = {
                    m = 0,
                    e = 0,
                },
            },
            spend = {
                m = 0,
                e = 0,
            },
            categoryspend = {
                eng = {T1=0,T2=0,T3=0,com=0},
                fac = {Land=0,Air=0,Naval=0},
                silo = {T2=0,T3=0},
                mex = {T1=0,T2=0,T3=0},
            },
            storage = {
                current = {
                    m = 0,
                    e = 0,
                },
                max = {
                    m = 0,
                    e = 0,
                },
            },
        }
        self.amanager = {
            Current = {
                Land = {
                    T1 = {
                        scout=0,
                        tank=0,
                        arty=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        stealth=0,
                        bot=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        armoured=0
                    }
                },
                Air = {
                    T1 = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0
                    },
                    T2 = {
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                    },
                    T3 = {
                        asf=0,
                        bomber=0,
                        gunship=0,
                    }
                },
                Naval = {
                    T1 = {
                        frigate=0,
                        submarine=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0
                    }
                },
            },
            Total = {
                Land = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Air = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Naval = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                }
            },
            Type = {
                Land = {
                    scout=0,
                    tank=0,
                    sniper=0,
                    arty=0,
                    mml=0,
                    aa=0,
                    shield=0,
                    bot=0,
                    armoured=0
                },
                Air = {
                    scout=0,
                    interceptor=0,
                    bomber=0,
                    gunship=0,
                    fighter=0,
                    mercy=0,
                    torpedo=0,
                    asf=0,
                },
                Naval = {
                    scout=0,
                    tank=0,
                    sniper=0,
                    arty=0,
                    mml=0,
                    aa=0,
                    shield=0
                },
            },
            Ratios = {
                [1] = {
                    Land = {
                        T1 = {
                            scout=11,
                            tank=55,
                            arty=22,
                            aa=12,
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                    Air = {
                        T1 = {
                            scout=11,
                            interceptor=55,
                            bomber=22,
                        },
                        T2 = {
                            bomber=70,
                            gunship=30,
                            torpedo=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                },
                [2] = {
                    Land = {
                        T1 = {
                            scout=11,
                            tank=55,
                            arty=22,
                            aa=12,
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10
                        },
                        T3 = {
                            tank=45,
                            arty=15,
                            aa=10,
                            sniper=30
                        }
                    },
                    Air = {
                        T1 = {
                            scout=11,
                            interceptor=55,
                            bomber=22,
                        },
                        T2 = {
                            fighter=85,
                            gunship=15,
                            torpedo=0,
                            mercy=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                },
                [3] = {
                    Land = {
                        T1 = {
                            scout=11,
                            tank=55,
                            arty=22,
                            aa=12,
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=25,
                            aa=10,
                            stealth=5,
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            arty=15,
                            aa=10,
                        }
                    },
                    Air = {
                        T1 = {
                            scout=11,
                            interceptor=55,
                            bomber=22,
                            gunship=12,
                        },
                        T2 = {
                            bomber=85,
                            gunship=15,
                            torpedo=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                },
                [4] = {
                    Land = {
                        T1 = {
                            scout=11,
                            tank=55,
                            arty=22,
                            aa=12,
                        },
                        T2 = {
                            bot=75,
                            mml=10,
                            aa=15,
                        },
                        T3 = {
                            tank=45,
                            arty=10,
                            aa=10,
                            sniper=30,
                            shield=5,
                        }
                    },
                    Air = {
                        T1 = {
                            scout=11,
                            interceptor=55,
                            bomber=22,
                        },
                        T2 = {
                            bomber=75,
                            gunship=15,
                            torpedo=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                },
                [5] = {
                    Land = {
                        T1 = {
                            scout=11,
                            tank=55,
                            arty=22,
                            aa=12,
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10,
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10,
                        }
                    },
                    Air = {
                        T1 = {
                            scout=11,
                            interceptor=55,
                            bomber=22,
                        },
                        T2 = {
                            bomber=75,
                            gunship=15,
                            torpedo=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10
                        }
                    },
                },
            },
        }
        self.smanager = {
            fac = {
                Land =
                {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0
                },
                Air = {
                    T1=0,
                    T2=0,
                    T3=0
                },
                Naval= {
                    T1=0,
                    T2=0,
                    T3=0
                }
            },
            mex = {
                T1=0,
                T2=0,
                T3=0
            },
            pgen = {
                T1=0,
                T2=0,
                T3=0
            },
            silo = {
                T2=0,
                T3=0
            },
            fabs= {
                T2=0,
                T3=0
            }
        }

        self.LowEnergyMode = false
        self.EcoManager = {
            EcoManagerTime = 30,
            EcoManagerStatus = 'ACTIVE',
            ExtractorUpgradeLimit = {
                TECH1 = 1,
                TECH2 = 1
            },
            ExtractorsUpgrading = {TECH1 = 0, TECH2 = 0},
            EcoMultiplier = 1,
        }
        self.EcoManager.PowerPriorityTable = {
            ENGINEER = 12,
            STATIONPODS = 11,
            TML = 10,
            SHIELD = 8,
            AIR = 9,
            NAVAL = 5,
            LAND = 2,
            RADAR = 4,
            MASSEXTRACTION = 3,
            MASSFABRICATION = 7,
            NUKE = 6,
        }
        self.EcoManager.MassPriorityTable = {
            Advantage = {
                MASSEXTRACTION = 5,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                AIR = 7,
                NAVAL = 8,
                LAND = 6,
                NUKE = 9,
                },
            Disadvantage = {
                MASSEXTRACTION = 8,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                AIR = 6,
                NAVAL = 7,
                NUKE = 9,
            }
        }
        -- ACU Support Data
        self.ACUSupport = {}
        self.ACUMaxSearchRadius = 0
        self.ACUSupport.Supported = false
        self.ACUSupport.PlatoonCount = 0
        self.ACUSupport.Position = {}
        self.ACUSupport.TargetPosition = false
        self.ACUSupport.ReturnHome = true

        -- Misc
        self.ReclaimEnabled = true
        self.ReclaimLastCheck = 0
        
        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)
        
        -- Begin the base monitor process

        self:BaseMonitorInitializationRNG()
        --LOG(repr(Scenario))

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)
        --local perlocations, orient, positionsel = RUtils.GetBasePerimeterPoints(self, 'MAIN', 50, 'FRONT', false, 'Land', true)
        --LOG('Perimeter Points '..repr(perlocations))
        --LOG('Orient is '..orient)
        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitor)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.EcoExtractorUpgradeCheckRNG)
        self:ForkThread(self.EcoPowerManagerRNG)
        self:ForkThread(self.EcoMassManagerRNG)
        self:ForkThread(self.AllyEconomyHelpThread)
        self:ForkThread(self.HeavyEconomyRNG)
        self:ForkThread(RUtils.MexUpgradeManagerRNG)
    end,

    EconomyMonitorRNG = function(self)
        -- build "eco trend over time" table
        for i = 1, self.EconomyTicksMonitor do
            self.EconomyData[i] = { EnergyIncome=0, EnergyRequested=0, MassIncome=0, MassRequested=0 }
        end
        -- make counters local (they are not used anywhere else)
        local EconomyTicksMonitor = self.EconomyTicksMonitor
        local EconomyCurrentTick = self.EconomyCurrentTick
        -- loop until the AI is dead
        while self.Result ~= "defeat" do
            self.EconomyData[EconomyCurrentTick].EnergyIncome = GetEconomyIncome(self, 'ENERGY')
            self.EconomyData[EconomyCurrentTick].MassIncome = GetEconomyIncome(self, 'MASS')
            self.EconomyData[EconomyCurrentTick].EnergyRequested = GetEconomyRequested(self, 'ENERGY')
            self.EconomyData[EconomyCurrentTick].MassRequested = GetEconomyRequested(self, 'MASS')
            self.EconomyData[EconomyCurrentTick].EnergyTrend = GetEconomyTrend(self, 'ENERGY')
            self.EconomyData[EconomyCurrentTick].MassTrend = GetEconomyTrend(self, 'MASS')
            -- store eco trend for the last 50 ticks (5 seconds)
            EconomyCurrentTick = EconomyCurrentTick + 1
            if EconomyCurrentTick > EconomyTicksMonitor then
                EconomyCurrentTick = 1
            end
            WaitTicks(2)
        end
    end,

    EconomyOverTimeRNG = function(self)
        if not self.EconomyMonitorThread then
            WARN('TechAI : Error EconomyMonitorThread not running')
            return
        end
        while self.Result ~= "defeat" do
            local eIncome = 0
            local mIncome = 0
            local eRequested = 0
            local mRequested = 0
            local eTrend = 0
            local mTrend = 0
            local num = 0
            for k, v in self.EconomyData do
                num = k
                eIncome = eIncome + v.EnergyIncome
                mIncome = mIncome + v.MassIncome
                eRequested = eRequested + v.EnergyRequested
                mRequested = mRequested + v.MassRequested
                
                if v.EnergyTrend then
                    eTrend = eTrend + v.EnergyTrend
                end
                if v.EnergyTrend then
                    mTrend = mTrend + v.MassTrend
                end
            end

            self.EconomyOverTimeCurrent.EnergyIncome = eIncome / num
            self.EconomyOverTimeCurrent.MassIncome = mIncome / num
            self.EconomyOverTimeCurrent.EnergyRequested = eRequested / num
            self.EconomyOverTimeCurrent.MassRequested = mRequested / num
            self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime = math.min(eIncome / eRequested, 2)
            self.EconomyOverTimeCurrent.MassEfficiencyOverTime = math.min(mIncome / mRequested, 2)
            self.EconomyOverTimeCurrent.EnergyTrendOverTime = eTrend / num
            self.EconomyOverTimeCurrent.MassTrendOverTime = mTrend / num
            WaitTicks(50)
        end
    end,

    BaseMonitorThreadRNG = function(self)
        while true do
            if self.BaseMonitor.BaseMonitorStatus == 'ACTIVE' then
                self:BaseMonitorCheckRNG()
            end
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorInitializationRNG = function(self, spec)
        self.BaseMonitor = {
            BaseMonitorStatus = 'ACTIVE',
            BaseMonitorPoints = {},
            AlertSounded = false,
            AlertsTable = {},
            AlertLocation = false,
            AlertSoundedThreat = 0,
            ActiveAlerts = 0,

            PoolDistressRange = 75,
            PoolReactionTime = 7,

            -- Variables for checking a radius for enemy units
            UnitRadiusThreshold = spec.UnitRadiusThreshold or 3,
            UnitCategoryCheck = spec.UnitCategoryCheck or (categories.MOBILE - (categories.SCOUT + categories.ENGINEER)),
            UnitCheckRadius = spec.UnitCheckRadius or 40,

            -- Threat level must be greater than this number to sound a base alert
            AlertLevel = spec.AlertLevel or 0,
            -- Delay time for checking base
            BaseMonitorTime = spec.BaseMonitorTime or 11,
            -- Default distance a platoon will travel to help around the base
            DefaultDistressRange = spec.DefaultDistressRange or 75,
            -- Default how often platoons will check if the base is under duress
            PlatoonDefaultReactionTime = spec.PlatoonDefaultReactionTime or 5,
            -- Default duration for an alert to time out
            DefaultAlertTimeout = spec.DefaultAlertTimeout or 10,

            PoolDistressThreshold = 1,

            -- Monitor platoons for help
            PlatoonDistressTable = {},
            PlatoonDistressThread = false,
            PlatoonAlertSounded = false,
        }
        self:ForkThread(self.BaseMonitorThreadRNG)
        self:ForkThread(self.TacticalMonitorInitializationRNG)
        self:ForkThread(self.TacticalAnalysisThreadRNG)
    end,

    GetStructureVectorsRNG = function(self)
        local structures = GetListOfUnits(self, categories.STRUCTURE - categories.WALL - categories.MASSEXTRACTION, false)
        -- Add all points around location
        local tempGridPoints = {}
        local indexChecker = {}

        for k, v in structures do
            if not v.Dead then
                local pos = AIUtils.GetUnitBaseStructureVector(v)
                if pos then
                    if not indexChecker[pos[1]] then
                        indexChecker[pos[1]] = {}
                    end
                    if not indexChecker[pos[1]][pos[3]] then
                        indexChecker[pos[1]][pos[3]] = true
                        table.insert(tempGridPoints, pos)
                    end
                end
            end
        end

        return tempGridPoints
    end,

    BaseMonitorCheckRNG = function(self)
        
        local gameTime = GetGameTimeSeconds()
        if gameTime < 300 then
            -- default monitor spec
        elseif gameTime > 300 then
            self.BaseMonitor.PoolDistressRange = 130
            self.AlertLevel = 5
        end

        local vecs = self:GetStructureVectorsRNG()
        if table.getn(vecs) > 0 then
            -- Find new points to monitor
            for k, v in vecs do
                local found = false
                for subk, subv in self.BaseMonitor.BaseMonitorPoints do
                    if v[1] == subv.Position[1] and v[3] == subv.Position[3] then
                        found = true
                        -- if we found this point already stored, we don't need to continue searching the rest
                        break
                    end
                end
                if not found then
                    table.insert(self.BaseMonitor.BaseMonitorPoints,
                        {
                            Position = v,
                            Threat = GetThreatAtPosition(self, v, 0, true, 'Land'),
                            Alert = false
                        }
                    )
                end
            end
            --LOG('BaseMonitorPoints Threat Data '..repr(self.BaseMonitor.BaseMonitorPoints))
            -- Remove any points that we dont monitor anymore
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                local found = false
                for subk, subv in vecs do
                    if v.Position[1] == subv[1] and v.Position[3] == subv[3] then
                        found = true
                        break
                    end
                end
                -- If point not in list and the num units around the point is small
                if not found and self:GetNumUnitsAroundPoint(categories.STRUCTURE, v.Position, 16, 'Ally') <= 1 then
                    table.remove(self.BaseMonitor.BaseMonitorPoints, k)
                end
            end
            -- Check monitor points for change
            local alertThreat = self.BaseMonitor.AlertLevel
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                if not v.Alert then
                    v.Threat = GetThreatAtPosition(self, v.Position, 0, true, 'Land')
                    if v.Threat > alertThreat then
                        v.Alert = true
                        table.insert(self.BaseMonitor.AlertsTable,
                            {
                                Position = v.Position,
                                Threat = v.Threat,
                            }
                        )
                        self.BaseMonitor.AlertSounded = true
                        self:ForkThread(self.BaseMonitorAlertTimeout, v.Position)
                        self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                    end
                end
            end
        end
    end,

    PickEnemyRNG = function(self)
        while true do
            self:PickEnemyLogicRNG()
            WaitTicks(1200)
        end
    end,

    PickEnemyLogicRNG = function(self)
        local armyStrengthTable = {}
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local allyCount = 0
        local enemyCount = 0
        local MainPos = self.BuilderManagers.MAIN.Position
        for _, v in ArmyBrains do
            local insertTable = {
                Enemy = true,
                Strength = 0,
                Position = false,
                Distance = false,
                EconomicThreat = 0,
                ACUPosition = {},
                ACULastSpotted = 0,
                Brain = v,
            }
            -- Share resources with friends but don't regard their strength
            if ArmyIsCivilian(v:GetArmyIndex()) then
                continue
            elseif IsAlly(selfIndex, v:GetArmyIndex()) then
                self:SetResourceSharing(true)
                allyCount = allyCount + 1
                insertTable.Enemy = false
            elseif not IsEnemy(selfIndex, v:GetArmyIndex()) then
                insertTable.Enemy = false
            end
            if insertTable.Enemy == true then
                enemyCount = enemyCount + 1
                table.insert(enemyBrains, v)
            end
            local acuPos = {}
            -- Gather economy information of army to guage economy value of the target
            local enemyIndex = v:GetArmyIndex()
            local startX, startZ = v:GetArmyStartPos()
            local ecoThreat = 0

            if insertTable.Enemy == false then
                local ecoStructures = GetUnitsAroundPoint(self, categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                local GetBlueprint = moho.entity_methods.GetBlueprint
                for _, v in ecoStructures do
                    local bp = v:GetBlueprint()
                    local ecoStructThreat = bp.Defense.EconomyThreatLevel
                    --LOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
            else
                ecoThreat = 1
            end
            -- Doesn't exist yet!!. Check if the ACU's last position is known.
            --LOG('* AI-RNG: Enemy Index is :'..enemyIndex)
            local acuPos, lastSpotted = RUtils.GetLastACUPosition(self, enemyIndex)
            --LOG('* AI-RNG: ACU Position is has data'..repr(acuPos))
            insertTable.ACUPosition = acuPos
            insertTable.ACULastSpotted = lastSpotted
            
            insertTable.EconomicThreat = ecoThreat
            if insertTable.Enemy then
                local enemyTotalStrength = 0
                local highestEnemyThreat = 0
                local threatPos = {}
                local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', enemyIndex)
                for _, threat in enemyStructureThreat do
                    enemyTotalStrength = enemyTotalStrength + threat[3]
                    if threat[3] > highestEnemyThreat then
                        highestEnemyThreat = threat[3]
                        threatPos = {threat[1],0,threat[2]}
                    end
                end
                if enemyTotalStrength > 0 then
                    insertTable.Strength = enemyTotalStrength
                    insertTable.Position = threatPos
                end

                --LOG('Enemy Index is '..enemyIndex)
                --LOG('Enemy name is '..v.Nickname)
                --LOG('* AI-RNG: First Enemy Pass Strength is :'..insertTable.Strength)
                --LOG('* AI-RNG: First Enemy Pass Position is :'..repr(insertTable.Position))
                if insertTable.Strength == 0 then
                    --LOG('Enemy Strength is zero, using enemy start pos')
                    insertTable.Position = {startX, 0 ,startZ}
                end
            else
                insertTable.Position = {startX, 0 ,startZ}
                insertTable.Strength = ecoThreat
                --LOG('* AI-RNG: First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
            end
            armyStrengthTable[v:GetArmyIndex()] = insertTable
        end
        
        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        
        if allyEnemy  then
            --LOG('* AI-RNG: Ally Enemy is true or ACU is close')
            self:SetCurrentEnemy(allyEnemy)
        else
            local findEnemy = false
            if not self:GetCurrentEnemy() then
                findEnemy = true
            else
                local cIndex = self:GetCurrentEnemy():GetArmyIndex()
                -- If our enemy has been defeated or has less than 20 strength, we need a new enemy
                if self:GetCurrentEnemy():IsDefeated() or armyStrengthTable[cIndex].Strength < 20 then
                    findEnemy = true
                end
            end
            local enemyTable = {}
            if findEnemy then
                local enemyStrength = false
                local enemy = false

                for k, v in armyStrengthTable do
                    -- Dont' target self
                    if k == selfIndex then
                        continue
                    end

                    -- Ignore allies
                    if not v.Enemy then
                        continue
                    end

                    -- If we have a better candidate; ignore really weak enemies
                    if enemy and v.Strength < 20 then
                        continue
                    end

                    if v.Strength == 0 then
                        name = v.Brain.Nickname
                        --LOG('* AI-RNG: Name is'..name)
                        --LOG('* AI-RNG: v.strenth is 0')
                        if name ~= 'civilian' then
                            --LOG('* AI-RNG: Inserted Name is '..name)
                            table.insert(enemyTable, v.Brain)
                        end
                        continue
                    end

                    -- The closer targets are worth more because then we get their mass spots
                    local distanceWeight = 0.1
                    local distance = VDist3(self:GetStartVector3f(), v.Position)
                    local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                    --LOG('* AI-RNG: armyStrengthTable Strength is :'..v.Strength)
                    --LOG('* AI-RNG: Threat Weight is :'..threatWeight)
                    if not enemy or threatWeight > enemyStrength then
                        enemy = v.Brain
                        enemyStrength = threatWeight
                        --LOG('* AI-RNG: Enemy Strength is'..enemyStrength)
                    end
                end

                if enemy then
                    --LOG('* AI-RNG: Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = table.getn(enemyTable)
                    --LOG('* AI-RNG: Table number is'..num)
                    local ran = math.random(num)
                    --LOG('* AI-RNG: Random Number is'..ran)
                    enemy = enemyTable[ran]
                    --LOG('* AI-RNG: Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
                
            end
        end
        local selfEnemy = self:GetCurrentEnemy()
        if selfEnemy then
            local enemyIndex = selfEnemy:GetArmyIndex()
            local closest = 9999999
            local expansionName
            local mainDist = VDist2Sq(self.BuilderManagers['MAIN'].Position[1], self.BuilderManagers['MAIN'].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            --LOG('Main base Position '..repr(self.BuilderManagers['MAIN'].Position))
            --LOG('Enemy base position '..repr(armyStrengthTable[enemyIndex].Position))
            for k, v in self.BuilderManagers do
                --LOG('build k is '..k)
                if (string.find(k, 'Expansion Area')) or (string.find(k, 'ARMY_')) then
                    if v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0 then
                        local exDistance = VDist2Sq(self.BuilderManagers[k].Position[1], self.BuilderManagers[k].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
                        --LOG('Distance to Enemy for '..k..' is '..exDistance)
                        if (exDistance < closest) and (mainDist > exDistance) then
                            expansionName = k
                            closest = exDistance
                        end
                    end
                end
            end
            if closest < 9999999 and expansionName then
                --LOG('Closest Base to Enemy is '..expansionName..' at a distance of '..closest)
                self.BrainIntel.ActiveExpansion = expansionName
                --LOG('Active Expansion is '..self.BrainIntel.ActiveExpansion)
            end
            local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(self, 'Water Path Node', armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            if waterNodePos then
                --LOG('Enemy Closest water node pos is '..repr(waterNodePos))
                self.EnemyIntel.NavalRange.Position = waterNodePos
                --LOG('Enemy Closest water node pos distance is '..waterNodeDist)
                self.EnemyIntel.NavalRange.Range = waterNodeDist
            end
            --LOG('Current Naval Range table is '..repr(self.EnemyIntel.NavalRange))
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local startX, startZ = self:GetArmyStartPos()
        local ACUDist = nil        
        --LOG('* AI-RNG: My Own Strength is'..highStrength)
        for k, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                --LOG('* AI-RNG: ACU Position is :'..repr(v.ACUPosition))
                if v.ACUPosition[1] then
                    ACUDist = VDist2(startX, startZ, v.ACUPosition[1], v.ACUPosition[3])
                    --LOG('* AI-RNG: Enemy ACU Distance in Alliance Check is'..ACUDist)
                    if ACUDist < 230 then
                        --LOG('* AI-RNG: Enemy ACU is close switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    elseif v.Threat < 200 and ACUDist < 200 then
                        --LOG('* AI-RNG: Enemy ACU has low threat switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    end
                end
                continue
            end

            -- Ally too weak
            if v.Strength < highStrength then
                continue
            end

            -- If the brain has an enemy, it's our new enemy
            
            local enemy = v.Brain:GetCurrentEnemy()
            if enemy and not enemy:IsDefeated() and v.Strength > 0 then
                highStrength = v.Strength
                returnEnemy = v.Brain:GetCurrentEnemy()
            end
        end
        if returnEnemy then
            --LOG('* AI-RNG: Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            --LOG('* AI-RNG: returnEnemy is false')
        end
        return returnEnemy
    end,

    EcoMassManagerRNG = function(self)
    -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    WaitTicks(50)
                    continue
                end
                local massStateCaution = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                
                if massStateCaution then
                    --LOG('massStateCaution State Caution is true')
                    local massCycle = 0
                    local unitTypePaused = {}
                    while massStateCaution do
                        local massPriorityTable = {}
                        local priorityNum = 0
                        local priorityUnit = false
                        massCycle = massCycle + 1
                        for k, v in massPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --LOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            --LOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'MASS')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'MASSEXTRACTION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            --LOG('Number of mass extractors'..table.getn(Extractors))
                            self:EcoSelectorManagerRNG(priorityUnit, Extractors, 'pause', 'MASS')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'MASS')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'MASS')
                        end
                        WaitTicks(20)
                        massStateCaution = self:EcoManagerMassStateCheck()
                        if massStateCaution then
                            --LOG('Power State Caution still true after first pass')
                            if massCycle > 8 then
                                --LOG('Power Cycle Threashold met, waiting longer')
                                WaitTicks(100)
                                massCycle = 0
                            end
                        else
                            --LOG('Power State Caution is now false')
                        end
                        WaitTicks(5)
                        --LOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'MASS')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'MASS')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'MASSEXTRACTION' then
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Extractors, 'unpause', 'MASS')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'MASS')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'MASS')
                        end
                    end
                    massStateCaution = false
                end
            end
            WaitTicks(30)
        end
    end,

    EcoManagerPowerStateCheck = function(self)

        local stallTime = GetEconomyStored(self, 'ENERGY') / ((GetEconomyRequested(self, 'ENERGY') * 10) - (GetEconomyIncome(self, 'ENERGY') * 10))
        --LOG('Time to stall for '..stallTime)
        if stallTime >= 0.0 then
            if stallTime < 20 then
                return true
            elseif stallTime > 20 then
                return false
            end
        end
        return false
    end,
    
    EcoPowerManagerRNG = function(self)
        -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 300 then
                    WaitTicks(50)
                    continue
                end
                local powerStateCaution = self:EcoManagerPowerStateCheck()
                local unitTypePaused = false
                
                if powerStateCaution then
                    --LOG('Power State Caution is true')
                    local powerCycle = 0
                    local unitTypePaused = {}
                    while powerStateCaution do
                        local priorityNum = 0
                        local priorityUnit = false
                        powerCycle = powerCycle + 1
                        for k, v in self.EcoManager.PowerPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --LOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        --LOG('Doing anti power stall stuff for :'..priorityUnit)
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            --LOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'ENERGY')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'SHIELD' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Shields, 'pause', 'ENERGY')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'ENERGY')
                        elseif priorityUnit == 'RADAR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local Radars = GetListOfUnits(self, categories.STRUCTURE * (categories.RADAR + categories.SONAR), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Radars, 'pause', 'ENERGY')
                        elseif priorityUnit == 'MASSFABRICATION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, MassFabricators, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                table.insert(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'ENERGY')
                        end
                        WaitTicks(20)
                        powerStateCaution = self:EcoManagerPowerStateCheck()
                        if powerStateCaution then
                            --LOG('Power State Caution still true after first pass')
                            if powerCycle > 11 then
                                --LOG('Power Cycle Threashold met, waiting longer')
                                WaitTicks(100)
                                powerCycle = 0
                            end
                        else
                            --LOG('Power State Caution is now false')
                        end
                        WaitTicks(5)
                        --LOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'ENERGY')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'ENERGY')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'SHIELD' then
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Shields, 'unpause', 'ENERGY')
                        elseif v == 'MASSFABRICATION' then
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(v, MassFabricators, 'unpause', 'ENERGY')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'ENERGY')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'ENERGY')
                        end
                    end
                    powerStateCaution = false
                end
            end
            WaitTicks(30)
        end
    end,

    EcoManagerMassStateCheck = function(self)
        if self.EconomyOverTimeCurrent.MassTrendOverTime <= 0.0 and GetEconomyStored(self, 'MASS') <= 200 then
            return true
        else
            return false
        end
        return false
    end,
    
    EcoSelectorManagerRNG = function(self, priorityUnit, units, action, type)
        --LOG('Eco selector manager for '..priorityUnit..' is '..action..' Type is '..type)
        for _,v in units do
            if v.Dead or not v then continue end
            if v.UnitBeingBuilt or v.UnitBeingAssist then
                local beingbuilt=v.UnitBeingBuilt or v.UnitBeingAssist
                local bp=beingbuilt:GetBlueprint()
                if beingbuilt.Dead then continue end
                local massleft=(1-beingbuilt:GetFractionComplete())*bp.Economy.BuildCostMass
                if type=='ENERGY' then
                    massleft=(1-beingbuilt:GetFractionComplete())*bp.Economy.BuildCostEnergy
                end
                if beingbuilt:GetFractionComplete()<1 then
                    v.EPriority=1/massleft
                else
                    v.EPriority=1
                end
            else
                v.EPriority=1
            end
        end
        table.sort(units,function(a,b) return a.EPriority<b.EPriority end)
        for k, v in units do
            if v.Dead then continue end
            if priorityUnit == 'ENGINEER' then
                --LOG('Priority Unit Is Engineer')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Engineer')
                    v:SetPaused(false)
                    continue
                end
                if EntityCategoryContains( categories.STRUCTURE * (categories.TACTICALMISSILEPLATFORM + categories.MASSSTORAGE + categories.ENERGYSTORAGE + categories.SHIELD + categories.GATE) , v.UnitBeingBuilt) then
                    v:SetPaused(true)
                    continue
                end
                if not v.PlatoonHandle.PlatoonData.Assist.AssisteeType then continue end
                if not v.UnitBeingAssist then continue end
                if v:IsPaused() then continue end
                if type == 'ENERGY' and not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                    --LOG('Pausing Engineer')
                    v:SetPaused(true)
                    continue
                elseif type == 'MASS' then
                    v:SetPaused(true)
                    continue
                end
            elseif priorityUnit == 'STATIONPODS' then
                --LOG('Priority Unit Is STATIONPODS')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing STATIONPODS Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER * categories.TECH1, v.UnitBeingBuilt) then continue end
                if table.getn(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing STATIONPODS')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'AIR' then
                --LOG('Priority Unit Is AIR')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Air Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if table.getn(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing AIR')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'NAVAL' then
                --LOG('Priority Unit Is NAVAL')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Naval Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if table.getn(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing NAVAL')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'LAND' then
                --LOG('Priority Unit Is LAND')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Land Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if table.getn(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing LAND')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSFABRICATION' or priorityUnit == 'SHIELD' or priorityUnit == 'RADAR' then
                --LOG('Priority Unit Is MASSFABRICATION or SHIELD')
                if action == 'unpause' then
                    if v.MaintenanceConsumption then continue end
                    --LOG('Unpausing MASSFABRICATION or SHIELD')
                    v:OnProductionUnpaused()
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if not v.MaintenanceConsumption then continue end
                --LOG('pausing MASSFABRICATION or SHIELD '..v.UnitId)
                v:OnProductionPaused()
            elseif priorityUnit == 'NUKE' then
                --LOG('Priority Unit Is Nuke')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Nuke')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing Nuke')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'TML' then
                --LOG('Priority Unit Is TML')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing TML')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing TML')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSEXTRACTION' and action == 'unpause' then
                if not v:IsPaused() then continue end
                v:SetPaused( false )
                --LOG('Unpausing Extractor')
                continue
            end
            if priorityUnit == 'MASSEXTRACTION' and action == 'pause' then
                local upgradingBuilding = {}
                local upgradingBuildingNum = 0
                --LOG('Mass Extractor pause action, gathering upgrading extractors')
                for k, v in units do
                    if v
                        and not v.Dead
                        and not v:BeenDestroyed()
                        and not v:GetFractionComplete() < 1
                    then
                        if v:IsUnitState('Upgrading') then
                            if not v:IsPaused() then
                                table.insert(upgradingBuilding, v)
                                --LOG('Upgrading Extractor not paused found')
                                upgradingBuildingNum = upgradingBuildingNum + 1
                            end
                        end
                    end
                end
                --LOG('Mass Extractor pause action, checking if more than one is upgrading')
                local upgradingTableSize = table.getn(upgradingBuilding)
                --LOG('Number of upgrading extractors is '..upgradingBuildingNum)
                if upgradingBuildingNum > 1 then
                    --LOG('pausing all but one upgrading extractor')
                    --LOG('UpgradingTableSize is '..upgradingTableSize)
                    for i=1, (upgradingTableSize - 1) do
                        upgradingBuilding[i]:SetPaused( true )
                        --UpgradingBuilding:SetCustomName('Upgrading paused')
                        --LOG('Upgrading paused')
                    end
                end
            end
        end
    end,

    AllyEconomyHelpThread = function(self)
        local selfIndex = self:GetArmyIndex()
        WaitTicks(180)
        while true do
            if GetEconomyStoredRatio(self, 'ENERGY') > 0.95 and GetEconomyTrend(self, 'ENERGY') > 10 then
                for index, brain in ArmyBrains do
                    if index ~= selfIndex then
                        if IsAlly(selfIndex, brain:GetArmyIndex()) then
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.01 then
                                LOG('Transfer Energy to team mate')
                                local amount
                                amount = GetEconomyStored( self, 'ENERGY') / 100 * 10
                                GiveResource(self, 'ENERGY', amount)
                            end
                        end
                    end
                end
            end
            WaitTicks(100)
        end
    end,
    HeavyEconomyRNG = function(self)
        if ArmyIsCivilian(self:GetArmyIndex()) then return end
        WaitTicks(math.random(3,50))
        LOG('Heavy Economy thread starting '..self.Nickname)
        self:ForkThread(RUtils.CountSoonMassSpotsRNG)
        self:ForkThread(RUtils.GetAvgSpendPerFactoryTypeRNG)
        self:ForkThread(RUtils.GetFutureMassRNG)
        -- This section is for debug
        ---[[
            self.cmanager = {
                income = {
                    r  = {
                        m = 0,
                        e = 0,
                    },
                    t = {
                        m = 0,
                        e = 0,
                    },
                    neede=0
                },
                spend = {
                    m = 0,
                    e = 0,
                },
                categoryspend = {
                    eng = {T1=0,T2=0,T3=0,com=0},
                    fac = {Land=0,Air=0,Naval=0},
                    silo = {T2=0,T3=0},
                    mex = {T1=0,T2=0,T3=0},
                },
                storage = {
                    current = {
                        m = 0,
                        e = 0,
                    },
                    max = {
                        m = 0,
                        e = 0,
                    },
                },
            }
            self.amanager = {
                Current = {
                    Land = {
                        T1 = {
                            scout=0,
                            tank=0,
                            arty=0,
                            aa=0
                        },
                        T2 = {
                            tank=0,
                            mml=0,
                            aa=0,
                            shield=0,
                            stealth=0,
                            bot=0
                        },
                        T3 = {
                            tank=0,
                            sniper=0,
                            arty=0,
                            mml=0,
                            aa=0,
                            shield=0,
                            armoured=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=0,
                            interceptor=0,
                            bomber=0,
                            gunship=0
                        },
                        T2 = {
                            bomber=0,
                            gunship=0,
                            fighter=0,
                            mercy=0,
                            torpedo=0,
                        },
                        T3 = {
                            asf=0,
                            bomber=0,
                            gunship=0,
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=0,
                            submarine=0,
                            aa=0
                        },
                        T2 = {
                            tank=0,
                            mml=0,
                            aa=0,
                            shield=0
                        },
                        T3 = {
                            tank=0,
                            sniper=0,
                            arty=0,
                            mml=0,
                            aa=0,
                            shield=0
                        }
                    },
                },
                Total = {
                    Land = {
                        T1 = 0,
                        T2 = 0,
                        T3 = 0,
                    },
                    Air = {
                        T1 = 0,
                        T2 = 0,
                        T3 = 0,
                    },
                    Naval = {
                        T1 = 0,
                        T2 = 0,
                        T3 = 0,
                    }
                },
                Type = {
                    Land = {
                        scout=0,
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        bot=0,
                        armoured=0
                    },
                    Air = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                        asf=0,
                    },
                    Naval = {
                        scout=0,
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0
                    },
                },
                Ratios = {
                    [1] = {
                        Land = {
                            T1 = {
                                scout=11,
                                tank=55,
                                arty=22,
                                aa=12,
                            },
                            T2 = {
                                tank=55,
                                mml=5,
                                bot=45,
                                aa=15,
                                shield=15
                            },
                            T3 = {
                                tank=30,
                                armoured=50,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                        Air = {
                            T1 = {
                                scout=11,
                                interceptor=55,
                                bomber=22,
                            },
                            T2 = {
                                bomber=70,
                                gunship=30,
                                torpedo=0
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                    },
                    [2] = {
                        Land = {
                            T1 = {
                                scout=11,
                                tank=55,
                                arty=22,
                                aa=12,
                            },
                            T2 = {
                                tank=55,
                                mml=5,
                                bot=20,
                                aa=10,
                                shield=10
                            },
                            T3 = {
                                tank=45,
                                arty=15,
                                aa=10,
                                sniper=50
                            }
                        },
                        Air = {
                            T1 = {
                                scout=11,
                                interceptor=55,
                                bomber=22,
                            },
                            T2 = {
                                fighter=85,
                                gunship=15,
                                torpedo=0,
                                mercy=0
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                    },
                    [3] = {
                        Land = {
                            T1 = {
                                scout=11,
                                tank=55,
                                arty=22,
                                aa=12,
                            },
                            T2 = {
                                tank=55,
                                mml=5,
                                bot=45,
                                aa=10,
                                stealth=5,
                            },
                            T3 = {
                                tank=30,
                                armoured=50,
                                arty=15,
                                aa=10,
                            }
                        },
                        Air = {
                            T1 = {
                                scout=11,
                                interceptor=55,
                                bomber=22,
                                gunship=12,
                            },
                            T2 = {
                                bomber=85,
                                gunship=15,
                                torpedo=0
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                    },
                    [4] = {
                        Land = {
                            T1 = {
                                scout=11,
                                tank=55,
                                arty=22,
                                aa=12,
                            },
                            T2 = {
                                bot=75,
                                mml=10,
                                aa=15,
                            },
                            T3 = {
                                tank=45,
                                arty=5,
                                aa=15,
                                sniper=50,
                                shield=10,
                            }
                        },
                        Air = {
                            T1 = {
                                scout=11,
                                interceptor=55,
                                bomber=22,
                            },
                            T2 = {
                                bomber=75,
                                gunship=15,
                                torpedo=0
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                    },
                    [5] = {
                        Land = {
                            T1 = {
                                scout=11,
                                tank=55,
                                arty=22,
                                aa=12,
                            },
                            T2 = {
                                tank=55,
                                mml=5,
                                bot=20,
                                aa=10,
                                shield=10,
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10,
                            }
                        },
                        Air = {
                            T1 = {
                                scout=11,
                                interceptor=55,
                                bomber=22,
                            },
                            T2 = {
                                bomber=75,
                                gunship=15,
                                torpedo=0
                            },
                            T3 = {
                                tank=30,
                                armoured=40,
                                mml=5,
                                arty=15,
                                aa=10
                            }
                        },
                    },
                },
            }
            self.smanager = {
                fac = {
                    Land =
                    {
                        T1 = 0,
                        T2 = 0,
                        T3 = 0
                    },
                    Air = {
                        T1=0,
                        T2=0,
                        T3=0
                    },
                    Naval= {
                        T1=0,
                        T2=0,
                        T3=0
                    }
                },
                mex = {
                    T1=0,
                    T2=0,
                    T3=0
                },
                pgen = {
                    T1=0,
                    T2=0,
                    T3=0
                },
                silo = {
                    T2=0,
                    T3=0
                },
                fabs= {
                    T2=0,
                    T3=0
                }
            }
        --]]
        while not self.defeat do
            --LOG('heavy economy loop started')
            self:HeavyEconomyForkRNG()
            WaitTicks(50)
        end
    end,

    HeavyEconomyForkRNG = function(self)
        local units = GetListOfUnits(self, categories.SELECTABLE, true, true)
        local factionIndex = self:GetFactionIndex()
        --LOG('units grabbed')
        local factories = {Land={T1=0,T2=0,T3=0},Air={T1=0,T2=0,T3=0},Naval={T1=0,T2=0,T3=0}}
        local extractors = {T1=0,T2=0,T3=0}
        local fabs = {T2=0,T3=0}
        local coms = {acu=0,sacu=0}
        local pgens = {T1=0,T2=0,T3=0}
        local silo = {T2=0,T3=0}
        local armyLand={T1={scout=0,tank=0,arty=0,aa=0},T2={tank=0,mml=0,aa=0,shield=0,bot=0},T3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,armoured=0}}
        local armyLandType={scout=0,tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,bot=0,armoured=0}
        local armyLandTiers={T1=0,T2=0,T3=0}
        local armyAir={T1={scout=0,interceptor=0,bomber=0,gunship=0},T2={fighter=0,bomber=0,gunship=0,mercy=0},T3={asf=0,bomber=0,gunship=0}}
        local armyAirType={scout=0,interceptor=0,bomber=0,asf=0,gunship=0,fighter=0}
        local armyAirTiers={T1=0,T2=0,T3=0}
        local launcherspend = {T2=0,T3=0}
        local facspend = {Land=0,Air=0,Naval=0}
        local mexspend = {T1=0,T2=0,T3=0}
        local engspend = {T1=0,T2=0,T3=0,com=0}
        local rincome = {m=0,e=0}
        local airmanager = {total=0,fuelratiosum=0}
        local tincome = {m=GetEconomyIncome(self, 'MASS')*10,e=GetEconomyIncome(self, 'ENERGY')*10}
        local storage = {max = {m=GetEconomyStored(self, 'MASS')/GetEconomyStoredRatio(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')/GetEconomyStoredRatio(self, 'ENERGY')},current={m=GetEconomyStored(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')}}
        local tspend = {m=0,e=0}
        for _,z in self.amanager.Ratios[factionIndex] do
            for _,c in z do
                c.total=0
                for i,v in c do
                    if i=='total' then continue end
                    c.total=c.total+v
                end
            end
        end
        for _,unit in units do
            if unit.Dead then continue end
            if not unit then continue end
            local spendm=0
            local spende=0
            local producem=0
            local producee=0
            if unit:GetFractionComplete()==1 then
                spendm=GetConsumptionPerSecondMass(unit)
                spende=GetConsumptionPerSecondEnergy(unit)
                producem=GetProductionPerSecondMass(unit)
                producee=GetProductionPerSecondEnergy(unit)
                tspend.m=tspend.m+spendm
                tspend.e=tspend.e+spende
                rincome.m=rincome.m+producem
                rincome.e=rincome.e+producee
            end
            if EntityCategoryContains(categories.MASSEXTRACTION,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    extractors.T1=extractors.T1+1
                    mexspend.T1=mexspend.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    extractors.T2=extractors.T2+1
                    mexspend.T2=mexspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    extractors.T3=extractors.T3+1
                    mexspend.T3=mexspend.T3+spendm
                end
            elseif EntityCategoryContains(categories.COMMAND+categories.SUBCOMMANDER,unit) then
                if EntityCategoryContains(categories.COMMAND,unit) then
                    coms.acu=coms.acu+1
                    engspend.com=engspend.com+spendm
                elseif EntityCategoryContains(categories.SUBCOMMANDER,unit) then
                    coms.sacu=coms.sacu+1
                    engspend.com=engspend.com+spendm
                end
            elseif EntityCategoryContains(categories.MASSFABRICATION,unit) then
                if EntityCategoryContains(categories.TECH2,unit) then
                    fabs.T2=fabs.T2+1
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    fabs.T3=fabs.T3+1
                end
            elseif EntityCategoryContains(categories.ENGINEER,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    engspend.T1=engspend.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    engspend.T2=engspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    engspend.T3=engspend.T3+spendm
                end
            elseif EntityCategoryContains(categories.FACTORY,unit) then
                if EntityCategoryContains(categories.LAND,unit) then
                    facspend.Land=facspend.Land+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Land.T1=factories.Land.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Land.T2=factories.Land.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Land.T3=factories.Land.T3+1
                    end
                elseif EntityCategoryContains(categories.AIR,unit) then
                    facspend.Air=facspend.Air+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Air.T1=factories.Air.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Air.T2=factories.Air.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Air.T3=factories.Air.T3+1
                    end
                elseif EntityCategoryContains(categories.NAVAL,unit) then
                    facspend.Naval=facspend.Naval+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Naval.T1=factories.Naval.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Naval.T2=factories.Naval.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Naval.T3=factories.Naval.T3+1
                    end
                end
            elseif EntityCategoryContains(categories.ENERGYPRODUCTION,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    pgens.T1=pgens.T1+1
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    pgens.T2=pgens.T2+1
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    pgens.T3=pgens.T3+1
                end
            elseif EntityCategoryContains(categories.LAND,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    armyLandTiers.T1=armyLandTiers.T1+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyLand.T1.scout=armyLand.T1.scout+1
                        armyLandType.scout=armyLandType.scout+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T1.aa=armyLand.T1.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE - categories.ANTIAIR,unit) then
                        armyLand.T1.tank=armyLand.T1.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.INDIRECTFIRE - categories.ANTIAIR,unit) then
                        armyLand.T1.arty=armyLand.T1.arty+1
                        armyLandType.arty=armyLandType.arty+1
                    end
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    armyLandTiers.T2=armyLandTiers.T2+1
                    if EntityCategoryContains(categories.DIRECTFIRE - categories.BOT - categories.ANTIAIR,unit) then
                        armyLand.T2.tank=armyLand.T2.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE * categories.BOT - categories.ANTIAIR,unit) then
                        armyLand.T2.bot=armyLand.T2.bot+1
                        armyLandType.bot=armyLandType.bot+1
                    elseif EntityCategoryContains(categories.SILO,unit) then
                        armyLand.T2.mml=armyLand.T2.mml+1
                        armyLandType.mml=armyLandType.mml+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T2.aa=armyLand.T2.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    elseif EntityCategoryContains(categories.SHIELD,unit) then
                        armyLand.T2.shield=armyLand.T2.shield+1
                        armyLandType.shield=armyLandType.shield+1
                    end
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    armyLandTiers.T3=armyLandTiers.T3+1
                    if EntityCategoryContains(categories.SNIPER,unit) then
                        armyLand.T3.sniper=armyLand.T3.sniper+1
                        armyLandType.sniper=armyLandType.sniper+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE * (categories.xel0305 + categories.xrl0305),unit) then
                        armyLand.T3.armoured=armyLand.T3.armoured+1
                        armyLandType.armoured=armyLandType.armoured+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE - categories.xel0305 - categories.xrl0305 - categories.ANTIAIR,unit) then
                        armyLand.T3.tank=armyLand.T3.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.SILO,unit) then
                        armyLand.T3.mml=armyLand.T3.mml+1
                        armyLandType.mml=armyLandType.mml+1
                    elseif EntityCategoryContains(categories.INDIRECTFIRE,unit) then
                        armyLand.T3.arty=armyLand.T3.arty+1
                        armyLandType.arty=armyLandType.arty+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T3.aa=armyLand.T3.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    elseif EntityCategoryContains(categories.SHIELD,unit) then
                        armyLand.T3.shield=armyLand.T3.shield+1
                        armyLandType.shield=armyLandType.shield+1
                    end
                end
            elseif EntityCategoryContains(categories.AIR,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    armyAirTiers.T1=armyAirTiers.T1+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyAir.T1.scout=armyAir.T1.scout+1
                        armyAirType.scout=armyAirType.scout+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyAir.T1.interceptor=armyAir.T1.interceptor+1
                        armyAirType.interceptor=armyAirType.interceptor+1
                    elseif EntityCategoryContains(categories.BOMBER,unit) then
                        armyAir.T1.bomber=armyAir.T1.bomber+1
                        armyAirType.bomber=armyAirType.bomber+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyAir.T1.gunship=armyAir.T1.gunship+1
                        armyAirType.gunship=armyAirType.gunship+1
                    end
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    armyAirTiers.T2=armyAirTiers.T2+1
                    if EntityCategoryContains(categories.BOMBER - categories.daa0206,unit) then
                        armyAir.T2.bomber=armyAir.T2.bomber+1
                        armyAirType.bomber=armyAirType.bomber+1
                    elseif EntityCategoryContains(categories.xaa0202 - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.fighter=armyAir.T2.fighter+1
                        armyAirType.fighter=armyAirType.fighter+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.gunship=armyAir.T2.gunship+1
                        armyAirType.gunship=armyAirType.gunship+1
                    elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.torpedo=armyAir.T2.torpedo+1
                        armyAirType.torpedo=armyAirType.torpedo+1
                    elseif EntityCategoryContains(categories.daa0206,unit) then
                        armyAir.T2.mercy=armyAir.T2.mercy+1
                        armyAirType.mercy=armyAirType.mercy+1
                    end
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    armyAirTiers.T3=armyAirTiers.T3+1
                end
                if unit.HasFuel then
                    airmanager.fuelratiosum = airmanager.fuelratiosum + unit:GetFuelRatio()
                    airmanager.total = airmanager.total+1
                end
            elseif EntityCategoryContains(categories.SILO,unit) then
                if EntityCategoryContains(categories.TECH2,unit) then
                    silo.T2=silo.T2+1
                    launcherspend.T2=launcherspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    silo.T3=silo.T3+1
                    launcherspend.T3=launcherspend.T3+spendm
                end
            end
        end
        self.cmanager.income.r.m=rincome.m
        self.cmanager.income.r.e=rincome.e
        self.cmanager.income.t.m=tincome.m
        self.cmanager.income.t.e=tincome.e
        if self.cmanager.unclaimedmexcount and tspend.m>0 then
            self.cmanager.income.neede=(tspend.e/tspend.m*(rincome.m+2*self.cmanager.unclaimedmexcount))
        elseif tspend.m>0 then
            self.cmanager.income.neede=(tspend.e/tspend.m*rincome.m)
        else 
            self.cmanager.income.neede=tspend.e
        end
        self.cmanager.spend.m=tspend.m
        self.cmanager.spend.e=tspend.e
        self.cmanager.categoryspend.eng=engspend
        self.cmanager.categoryspend.fac=facspend
        self.cmanager.categoryspend.silo=launcherspend
        self.cmanager.categoryspend.mex=mexspend
        self.cmanager.storage.current.m=storage.current.m
        self.cmanager.storage.current.e=storage.current.e
        if storage.current.m>0 and storage.current.e>0 then
            self.cmanager.storage.max.m=storage.max.m
            self.cmanager.storage.max.e=storage.max.e
        end
        self.cmanager.needfuel=airmanager
        self.amanager.Current.Land=armyLand
        self.amanager.Total.Land=armyLandTiers
        self.amanager.Type.Land=armyLandType
        self.amanager.Current.Air=armyAir
        self.amanager.Total.Air=armyAirTiers
        self.amanager.Type.Air=armyAirType
        self.smanager={fac=factories,mex=extractors,silo=silo,fabs=fabs,pgen=pgens,}
    end,

}