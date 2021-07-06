local AIUtils = import('/lua/ai/AIUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local Utils = import('/lua/utilities.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GiveUnitToArmy = import('/lua/ScenarioFramework.lua').GiveUnitToArmy
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
-- TEMPORARY LOUD LOCALS
local RNGPOW = math.pow
local RNGSQRT = math.sqrt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort
local RNGFLOOR = math.floor
local RNGCEIL = math.ceil
local RNGPI = math.pi
local RNGCAT = table.cat

--[[
Valid Threat Options:
            Overall
            OverallNotAssigned
            StructuresNotMex
            Structures
            Naval
            Air
            Land
            Experimental
            Commander
            Artillery
            AntiAir
            AntiSurface
            AntiSub
            Economy
            Unknown
    
        self:SetUpAttackVectorsToArmy(categories.STRUCTURE - (categories.MASSEXTRACTION))
        --LOG('Attack Vectors'..repr(self:GetAttackVectors()))

        setfocusarmy -1 = back to observer
]]

local PropBlacklist = {}
-- This uses a mix of Uveso's reclaim logic and my own
function ReclaimTechAIThread(platoon, self, aiBrain)

    --LOG('* AI-RNG: Start Reclaim Function')
    if aiBrain.StartReclaimTaken then
        --LOG('StartReclaimTaken set to true')
        --LOG('Start Reclaim Table has '..table.getn(aiBrain.StartReclaimTable)..' items in it')
    end
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local createTick = GetGameTick()
    local reclaimLoop = 0

    self.BadReclaimables = self.BadReclaimables or {}

    while aiBrain:PlatoonExists(platoon) and self and not self.Dead do
        local engPos = self:GetPosition()
        if not aiBrain.StartReclaimTaken then
            --LOG('Reclaim Function - Starting reclaim is false')
            local sortedReclaimTable = {}
            if table.getn(aiBrain.StartReclaimTable) > 0 then
                
                --WaitTicks(10)
                local reclaimCount = 0
                aiBrain.StartReclaimTaken = true
                for k, r in aiBrain.StartReclaimTable do
                    if r.Reclaim and not IsDestroyed(r.Reclaim) then
                        reclaimCount = reclaimCount + 1
                        --LOG('Reclaim Function - Issuing reclaim')
                        --LOG('Reclaim distance is '..r.Distance)
                        IssueReclaim({self}, r.Reclaim)
                        WaitTicks(20)
                        local reclaimTimeout = 0
                        while aiBrain:PlatoonExists(platoon) and r.Reclaim and (not IsDestroyed(r.Reclaim)) and (reclaimTimeout < 20) do
                            reclaimTimeout = reclaimTimeout + 1
                            --LOG('Waiting for reclaim to no longer exist')
                            if aiBrain:GetEconomyStoredRatio('MASS') > 0.95 then
                                self:SetPaused( true )
                                WaitTicks(50)
                                self:SetPaused( false )
                            end
                            WaitTicks(20)
                        end
                        --LOG('Reclaim Count is '..reclaimCount)
                        if reclaimCount > 10 then
                            break
                        end
                    else
                        --LOG('Reclaim is no longer valid')
                    end
                    --LOG('Set key to nil')
                    aiBrain.StartReclaimTable[k] = nil
                end
                --LOG('Pre Rebuild Reclaim table has '..table.getn(aiBrain.StartReclaimTable)..' reclaim left')
                aiBrain.StartReclaimTable = aiBrain:RebuildTable(aiBrain.StartReclaimTable)
                --LOG('Reclaim table has '..table.getn(aiBrain.StartReclaimTable)..' reclaim left')
                
                if table.getn(aiBrain.StartReclaimTable) == 0 then
                    --LOG('Start Reclaim Taken set to true')
                    aiBrain.StartReclaimTaken = true
                else
                    --LOG('Start Reclaim table not empty, set StartReclaimTaken to false')
                    aiBrain.StartReclaimTaken = false
                end
                for i=1, 10 do
                    --LOG('Waiting Ticks '..i)
                    WaitTicks(20)
                end
            end
        end
        local furtherestReclaim = nil
        local closestReclaim = nil
        local closestDistance = 10000
        local furtherestDistance = 0
        local minRec = platoon.PlatoonData.MinimumReclaim
        local x1 = engPos[1] - initialRange
        local x2 = engPos[1] + initialRange
        local z1 = engPos[3] - initialRange
        local z2 = engPos[3] + initialRange
        local rect = Rect(x1, z1, x2, z2)
        local reclaimRect = {}
        reclaimRect = GetReclaimablesInRect(rect)
        if not engPos then
            WaitTicks(1)
            return
        end

        local reclaim = {}
        local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
        --LOG('* AI-RNG: Going through reclaim table')
        if reclaimRect and table.getn( reclaimRect ) > 0 then
            for k,v in reclaimRect do
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                local rpos = v:GetCachePosition()
                -- Start Blacklisted Props
                local blacklisted = false
                for _, BlackPos in PropBlacklist do
                    if rpos[1] == BlackPos[1] and rpos[3] == BlackPos[3] then
                        blacklisted = true
                        break
                    end
                end
                if blacklisted then continue end
                -- End Blacklisted Props
                if not needEnergy or v.MaxEnergyReclaim then
                    if v.MaxMassReclaim and v.MaxMassReclaim > minRec then
                        if not self.BadReclaimables[v] then
                            local recPos = v:GetCachePosition()
                            local distance = VDist2Sq(engPos[1], engPos[3], recPos[1], recPos[3])
                            if distance < closestDistance then
                                closestReclaim = recPos
                                closestDistance = distance
                            end
                            if distance > furtherestDistance then -- and distance < closestDistance + 20
                                furtherestReclaim = recPos
                                furtherestDistance = distance
                            end
                            if furtherestDistance - closestDistance > 20 then
                                break
                            end
                        end
                    end
                end
            end
        else
            initialRange = initialRange + 100
            --LOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 300 then
                --LOG('* AI-RNG: Reclaim range > 300, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                return
            end
            WaitTicks(2)
            continue
        end
        if closestDistance == 10000 then
            initialRange = initialRange + 100
            --LOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 200 then
                --LOG('* AI-RNG: Reclaim range > 200, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                return
            end
            WaitTicks(2)
            continue
        end
        if self.Dead then 
            return
        end
        --LOG('* AI-RNG: Closest Distance is : '..closestDistance..'Furtherest Distance is :'..furtherestDistance)
        -- Clear Commands first
        IssueClearCommands({self})
        --LOG('* AI-RNG: Attempting move to closest reclaim')
        --LOG('* AI-RNG: Closest reclaim is '..repr(closestReclaim))
        if not closestReclaim then
            WaitTicks(2)
            return
        end
        if self.lastXtarget == closestReclaim[1] and self.lastYtarget == closestReclaim[3] then
            self.blocked = self.blocked + 1
            --LOG('* AI-RNG: Reclaim Blocked + 1 :'..self.blocked)
            if self.blocked > 3 then
                self.blocked = 0
                table.insert (PropBlacklist, closestReclaim)
                --LOG('* AI-RNG: Reclaim Added to blacklist')
            end
        else
            self.blocked = 0
            self.lastXtarget = closestReclaim[1]
            self.lastYtarget = closestReclaim[3]
            StartMoveDestination(self, closestReclaim)
        end

        --LOG('* AI-RNG: Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        local idleCount = 0
        while reclaiming do
            --LOG('* AI-RNG: Engineer is reclaiming')
            WaitSeconds(max_time)
            if self:IsIdleState() then
                idleCount = idleCount + 1
                if (max_time and (GetGameTick() - createTick)*10 > max_time) then
                    --LOG('* AI-RNG: Engineer no longer reclaiming')
                    reclaiming = false
                end
                if idleCount > 5 then
                    reclaiming = false
                end
            end
            if aiBrain:GetEconomyStoredRatio('MASS') > 0.95 then
                self:SetPaused( true )
                WaitTicks(50)
                self:SetPaused( false )
            end
        end
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        local location = AIUtils.RandomLocation(basePosition[1],basePosition[3])
        --LOG('* AI-RNG: basePosition random location :'..repr(location))
        IssueClearCommands({self})
        StartMoveDestination(self, location)
        WaitTicks(50)
        reclaimLoop = reclaimLoop + 1
        if reclaimLoop == 5 then
            --LOG('* AI-RNG: reclaimLopp = 5 returning')
            return
        end
        WaitTicks(5)
    end
end

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        WaitTicks(10)
    end
end
-- Get the military operational areas of the map. Credit to Uveso, this is based on his zones but a little more for small map sizes.
function GetMOARadii(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    local BaseMilitaryArea = math.max( ScenarioInfo.size[1]-50, ScenarioInfo.size[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    -- DMZ is half the map. Mainly used for air formers
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Restricted Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 60, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 120, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( ScenarioInfo.size[1], ScenarioInfo.size[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        --LOG('* TechAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        --LOG('* TechAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        --LOG('* TechAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        --LOG('* TechAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end

function EngineerTryReclaimCaptureArea(aiBrain, eng, pos)
    if not pos then
        return false
    end
    local Reclaiming = false
    --Temporary for troubleshooting
    --local GetBlueprint = moho.entity_methods.GetBlueprint
    -- Check if enemy units are at location
    local checkUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE + categories.MOBILE) - categories.AIR, pos, 15, 'Enemy')
    -- reclaim units near our building place.
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            --temporary for troubleshooting
            --unitdesc = GetBlueprint(unit).Description
            if unit.Dead or unit:BeenDestroyed() then
                continue
            end
            if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                continue
            end
            if unit:IsCapturable() and not EntityCategoryContains(categories.TECH1 * (categories.MOBILE + categories.WALL), unit) then 
                --LOG('* AI-RNG: Unit is capturable and not category t1 mobile'..unitdesc)
                -- if we can capture the unit/building then do so
                unit.CaptureInProgress = true
                IssueCapture({eng}, unit)
            else
                --LOG('* AI-RNG: We are going to reclaim the unit'..unitdesc)
                -- if we can't capture then reclaim
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
            end
        end
        Reclaiming = true
    end
    -- reclaim rocks etc or we can't build mexes or hydros
    local Reclaimables = GetReclaimablesInRect(Rect(pos[1], pos[3], pos[1], pos[3]))
    if Reclaimables and table.getn( Reclaimables ) > 0 then
        for k,v in Reclaimables do
            if v.MaxMassReclaim and v.MaxMassReclaim > 0 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 0 then
                IssueReclaim({eng}, v)
            end
        end
    end
    return Reclaiming
end



function EngineerTryRepair(aiBrain, eng, whatToBuild, pos)
    if not pos then
        return false
    end

    local structureCat = ParseEntityCategory(whatToBuild)
    local checkUnits = GetUnitsAroundPoint(aiBrain, structureCat, pos, 1, 'Ally')
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            IssueRepair({eng}, unit)
        end
        return true
    end

    return false
end

function AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Unmarked Expansion', pos, radius, tMin, tMax, tRings, tType)
    --LOG('Valid Unmarked Expansion Markers '..repr(validPos))

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Large Expansion Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindStartLocationNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = {}

    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Blank Marker', pos, radius, tMin, tMax, tRings, tType)
    local startX, startZ = aiBrain:GetArmyStartPos()
    for _, v in positions do
        if string.sub(v.Name, 1, 5) == 'ARMY_' then
            if startX ~= v.Position[1] and startZ ~= v.Position[3] then
                table.insert(validPos, v)
            end
        end
    end

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindExpansionAreaNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end
    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Expansion Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, positions)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, positions)
    end

    return retPos, retName
end

function AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
    local markerList = {}
        local markers = ScenarioUtils.GetMarkers()
        if markers then
            for k, v in markers do
                if v.type == 'Mass' then
                    if waterOnly then
                        if PositionInWater(v.position) then
                            table.insert(markerList, {Position = v.position, Name = k})
                        end
                    elseif includeWater then
                        table.insert(markerList, {Position = v.position, Name = k})
                    else
                        if not PositionInWater(v.position) then
                            table.insert(markerList, {Position = v.position, Name = k})
                        end
                    end
                end
            end
        end
    return markerList
end

-- This is Sproutos function 
function PositionInWater(pos)
	return GetTerrainHeight(pos[1], pos[3]) < GetSurfaceHeight(pos[1], pos[3])
end

function GetClosestMassMarkerToPos(aiBrain, pos)
    local markerList = {}
    local markers = ScenarioUtils.GetMarkers()
    if markers then
        for k, v in markers do
            if v.type == 'Mass' then
                table.insert(markerList, {Position = v.position, Name = k})
            end
        end
    end

    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(pos[1], pos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            --LOG('Can build at position '..repr(v.Position))
            loc = v.Position
            name = v.Name
            lowest = distance
        else
            --LOG('Cant build at position '..repr(v.Position))
        end
    end

    return loc, name
end

function GetClosestMassMarker(aiBrain, unit)
    local markerList = {}
    local markers = ScenarioUtils.GetMarkers()
    if markers then
        for k, v in markers do
            if v.type == 'Mass' then
                table.insert(markerList, {Position = v.position, Name = k})
            end
        end
    end

    local engPos = unit:GetPosition()
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(engPos[1], engPos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            loc = v.Position
            name = v.Name
            lowest = distance
        end
    end

    return loc, name
end


function GetStartLocationMassMarkers(aiBrain, massLocations)
    local startLocations
    local allyStarts = {}

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position

        if army and startPos then
            if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                allyStarts['ARMY_' .. i] = startPos
            else
                numOpponents = numOpponents + 1
            end
        end
    end

    aiBrain.NumOpponents = numOpponents

    -- If the start location is not ours or an ally's, it is suspicious
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    for _, loc in starts do
        -- If vacant
        if not allyStarts[loc.Name] then
            table.insert(aiBrain.InterestList.LowPriority,
                {
                    Position = loc.Position,
                    LastScouted = 0,
                }
            )
            table.insert(startLocations, startPos)
        end
    end
end

function GetLastACUPosition(aiBrain, enemyIndex)
    local acuPos = {}
    local lastSpotted = 0
    if aiBrain.EnemyIntel.ACU then
        for k, v in aiBrain.EnemyIntel.ACU do
            if k == enemyIndex then
                acuPos = v.Position
                lastSpotted = v.LastSpotted
                --LOG('* AI-RNG: acuPos has data')
            else
                --LOG('* AI-RNG: acuPos is currently false')
            end
        --[[if aiBrain.EnemyIntel.ACU[enemyIndex] == enemyIndex then
            acuPos = aiBrain.EnemyIntel.ACU[enemyIndex].ACUPosition
            lastSpotted = aiBrain.EnemyIntel.ACU[enemyIndex].LastSpotted
            --LOG('* AI-RNG: acuPos has data')
        else
            --LOG('* AI-RNG: acuPos is currently false')
        end]]
        end
    end
    return acuPos, lastSpotted
end


function lerpy(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, distance - weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    local distanceFrac = distance[2] / distance[1]
    local x = vec1[1] * (1 - distanceFrac) + vec2[1] * distanceFrac
    local y = vec1[2] * (1 - distanceFrac) + vec2[2] * distanceFrac
    local z = vec1[3] * (1 - distanceFrac) + vec2[3] * distanceFrac
    return {x,y,z}
end

function LerpyRotate(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    local distanceFrac = distance[2] / distance[1]
    local z = vec2[3] + distanceFrac * (vec2[1] - vec1[1])
    local y = vec2[2] - distanceFrac * (vec2[2] - vec1[2])
    local x = vec2[1] - distanceFrac * (vec2[3] - vec1[3])
    return {x,y,z}
end

function CheckCustomPlatoons(aiBrain)
    if not aiBrain.StructurePool then
        --LOG('* AI-RNG: Creating Structure Pool Platoon')
        local structurepool = aiBrain:MakePlatoon('StructurePool', 'none')
        structurepool:UniquelyNamePlatoon('StructurePool')
        structurepool.BuilderName = 'Structure Pool'
        aiBrain.StructurePool = structurepool
    end
end

function AIFindBrainTargetInRangeOrigRNG(aiBrain, position, platoon, squad, maxRange, atkPri, enemyBrain)
    local position = platoon:GetPlatoonPosition()
    if not aiBrain or not position or not maxRange or not platoon or not enemyBrain then
        return false
    end

    local RangeList = { [1] = maxRange }
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [3] = 384,
            [4] = 512,
            [5] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [4] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    local enemyIndex = enemyBrain:GetArmyIndex()
    for _, range in RangeList do
        local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, position, maxRange, 'Enemy')
        for _, v in atkPri do
            local category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local distance = false
            for num, unit in targetUnits do
                if not unit.Dead and not unit.CaptureInProgress and EntityCategoryContains(category, unit) and unit:GetAIBrain():GetArmyIndex() == enemyIndex and platoon:CanAttackTarget(squad, unit) then
                    local unitPos = unit:GetPosition()
                    if not retUnit or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                        retUnit = unit
                        distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    end
                end
            end
            if retUnit then
                return retUnit
            end
        end
    end

    return false
end

-- 99% of the below was Sprouto's work
function StructureUpgradeInitialize(finishedUnit, aiBrain)
    local StructureUpgradeThread = import('/lua/ai/aibehaviors.lua').StructureUpgradeThread
    local structurePool = aiBrain.StructurePool
    local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
    --LOG('* AI-RNG: Structure Upgrade Initializing')
    if EntityCategoryContains(categories.MASSEXTRACTION, finishedUnit) then
        return
        --[[
        local extractorPlatoon = aiBrain:MakePlatoon('ExtractorPlatoon'..tostring(finishedUnit.Sync.id), 'none')
        extractorPlatoon.BuilderName = 'ExtractorPlatoon'..tostring(finishedUnit.Sync.id)
        extractorPlatoon.MovementLayer = 'Land'
        --LOG('* AI-RNG: Assigning Extractor to new platoon')
        AssignUnitsToPlatoon(aiBrain, extractorPlatoon, {finishedUnit}, 'Support', 'none')
        finishedUnit.PlatoonHandle = extractorPlatoon
        extractorPlatoon:ForkThread( extractorPlatoon.ExtractorCallForHelpAIRNG, aiBrain )

        if not finishedUnit.UpgradeThread then
            --LOG('* AI-RNG: Forking Upgrade Thread')
            upgradeSpec = aiBrain:GetUpgradeSpec(finishedUnit)
            --LOG('* AI-RNG: UpgradeSpec'..repr(upgradeSpec))
            finishedUnit.UpgradeThread = finishedUnit:ForkThread(StructureUpgradeThread, aiBrain, upgradeSpec, false)
        end]]
    end
    if finishedUnit.UpgradeThread then
        finishedUnit.Trash:Add(finishedUnit.UpgradeThread)
    end
end

function InitialMassMarkersInWater(aiBrain)
    if table.getn(AIGetMassMarkerLocations(aiBrain, false, true)) > 0 then
        return true
    else
        return false
    end
end

function PositionOnWater(positionX, positionZ)
    --Check if a position is under water. Used to identify if threat/unit position is over water
    -- Terrain >= Surface = Target is on land
    -- Terrain < Surface = Target is in water

    return GetTerrainHeight( positionX, positionZ ) < GetSurfaceHeight( positionX, positionZ )
end

function ManualBuildStructure(aiBrain, eng, structureType, tech, position)
    -- Usage ManualBuildStructure(aiBrain, engineerunit, 'AntiSurface', 'TECH2', {123:20:123})
    local factionIndex = aiBrain:GetFactionIndex()
    -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    DefenseTable = {
        { 
        AntiAir = {
            TECH1 = 'ueb2104',
            TECH2 = 'ueb2204',
            TECH3 = 'ueb2304'
            },
        AntiSurface = {
            TECH1 = 'ueb2101',
            TECH2 = 'ueb2301',
            TECH3 = 'xeb2306'
            },
        AntiNaval = {
            TECH1 = 'ueb2109',
            TECH2 = 'ueb2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'uab2104',
            TECH2 = 'uab2204',
            TECH3 = 'uab2304'
            },
        AntiSurface = {
            TECH1 = 'uab2101',
            TECH2 = 'uab2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'uab2109',
            TECH2 = 'uab2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'urb2104',
            TECH2 = 'urb2204',
            TECH3 = 'urb2304'
            },
        AntiSurface = {
            TECH1 = 'urb2101',
            TECH2 = 'urb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'urb2109',
            TECH2 = 'urb2205',
            TECH3 = 'xrb2308'
            }
        },
        {
        AntiAir = {
            TECH1 = 'xsb2104',
            TECH2 = 'xsb2204',
            TECH3 = 'xsb2304'
            },
        AntiSurface = {
            TECH1 = 'xsb2101',
            TECH2 = 'xsb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'xsb2109',
            TECH2 = 'xsb2205',
            TECH3 = ''
            }
        }
    }
    local blueprintID = DefenseTable[factionIndex][structureType][tech]
    if CanBuildStructureAt(aiBrain, blueprintID, position) then
        IssueStop({eng})
        IssueClearCommands({eng})
        aiBrain:BuildStructure(eng, blueprintID, position, false)
    end
end

function TacticalMassLocations(aiBrain)
    -- Scans the map and trys to figure out tactical locations with multiple mass markers
    -- markerLocations will be returned in the table full of these tables { Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }

    --LOG('* AI-RNG: * Starting Tactical Mass Location Function')
    local markerGroups = {}
    local markerLocations = AIGetMassMarkerLocations(aiBrain, false, false)
    if markerLocations then
        aiBrain.BrainIntel.MassMarker = table.getn(markerLocations)
    end
    local group = 1
    local duplicateMarker = {}
    -- loop thru all the markers --
    for key_1, marker_1 in markerLocations do
        -- only process a marker that has not already been used
            local groupSet = {MarkerGroup=group, Markers={}}
            -- loop thru all the markers --
            for key_2, marker_2 in markerLocations do
                -- bypass any marker that's already been used
                if VDist2Sq(marker_1.Position[1], marker_1.Position[3], marker_2.Position[1], marker_2.Position[3]) < 1600 then
                    -- insert marker into group --
                    table.insert(groupSet['Markers'], marker_2)
                    markerLocations[key_2] = nil
                end
            end
            markerLocations[key_1] = nil
            if table.getn(groupSet['Markers']) > 2 then
                table.insert(markerGroups, groupSet)
                --LOG('Group Set Markers :'..repr(groupSet))
                group = group + 1
            end
    end
    --LOG('End Marker Groups :'..repr(markerGroups))
    aiBrain.TacticalMonitor.TacticalMassLocations = markerGroups
    --LOG('* AI-RNG: * Marker Groups :'..repr(aiBrain.TacticalMonitor.TacticalMassLocations))
end

function MarkTacticalMassLocations(aiBrain)
--[[ Gets tactical mass locations and sets markers on ones with no existing expansion markers
    'Air Path Node',
    'Amphibious Path Node',
    'Blank Marker',
    'Camera Info',
    'Combat Zone',
    'Defensive Point',
    'Effect',
    'Expansion Area',
    'Hydrocarbon',
    'Island',
    'Land Path Node',
    'Large Expansion Area',
    'Mass',
    'Naval Area',
    'Naval Defensive Point',
    'Naval Exclude',
    'Naval Link',
    'Naval Rally Point',
    'Protected Experimental Construction',
    'Rally Point',
    'Transport Marker',
    'Water Path Node',
    'Weather Definition',
    'Weather Generator',]]

    local massGroups = aiBrain.TacticalMonitor.TacticalMassLocations
    local expansionMarkers = ScenarioUtils.GetMarkers()
    local markerList = {}
    --LOG('Pre Sorted MassGroups'..repr(massGroups))
    if massGroups then
        if expansionMarkers then
            for k, v in expansionMarkers do
                if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' then
                    table.insert(markerList, {Position = v.position})
                end
            end
        end
        for i = 1, 16 do
            if Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i] then
                table.insert(markerList, {Position = Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i].position})
            end
        end
        for key, group in massGroups do
            for key2, marker in markerList do
                if VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]) < 3600 then
                    --LOG('Location :'..repr(group.Markers[1])..' is less than 3600 from :'..repr(marker))
                    massGroups[key] = nil
                else
                    --LOG('Location :'..repr(group.Markers[1])..' is more than 3600 from :'..repr(marker))
                    --LOG('Location distance :'..VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]))
                end
            end
        end
        aiBrain:RebuildTable(massGroups)
    end
    aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups = massGroups
    --LOG('* AI-RNG: * Total Expansion, Large expansion markers'..repr(markerList))
    --LOG('* AI-RNG: * Unmarked Mass Groups'..repr(massGroups))
end

function GenerateMassGroupMarkerLocations(aiBrain)
    -- Will generate locations for markers on the center point for each unmarked mass group
    local markerGroups = aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups
    local newMarkerLocations = {}
    if table.getn(markerGroups) > 0 then
        for key, group in markerGroups do
            local position = MassGroupCenter(group)
            table.insert(newMarkerLocations, position)
            --LOG('Position for new marker is :'..repr(position))
        end
        --LOG('Completed New marker positions :'..repr(newMarkerLocations))
        return newMarkerLocations
    end
    return false
end

function CreateMarkers(markerType, newMarkers)
-- markerType = string e.g "Marker Area"
-- newMarkers = a table of new marker positions e.g {{123,12,123}}
--[[    
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Expansion Area' then
            if string.find(k, 'ExpansionArea') then
                WARN('* AI-RNG: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            elseif not string.find(k, 'Expansion Area') then
                WARN('* AI-RNG: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            end
        end
    end
]]
    --LOG('Marker Dump'..repr(Scenario.MasterChain._MASTERCHAIN_.Markers))
    for index, markerPosition in newMarkers do    
        --LOG('markerType is : '..markerType..' Index is : '..index)
        --local markerName = markerType..' '..index
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index] = { }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].color = 'ff000000'
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].hint = true
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].orientation = { 0, 0, 0 }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].prop = "/env/common/props/markers/M_Expansion_prop.bp"
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].type = markerType
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].position = markerPosition
    end
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Unmarked Expansion' then
            --LOG('Unmarked Expansion Marker at :'..repr(v.position))
        end
    end
end

function GeneratePointsAroundPosition(position,radius,num)
    -- Courtesy of chp2001
    -- position = { 233.5, 25.239820480347, 464.5, type="VECTOR3" }
    -- radius = the size of the circle
    -- num = the number of points around the circle

    local nnn=0
    local coords = {}
    while nnn < num do
        local xxx = 0
        local zzz = 0
        xxx = position[1] + radius * math.cos (nnn/num* (2 * math.pi))
        zzz = position[3] + radius * math.sin (nnn/num* (2 * math.pi))
        table.insert(coords, {xxx, zzz})
        nnn = nnn + 1
        WaitTicks(1)
    end
    return coords
end


function MassGroupCenter(massGroup)
    -- Courtesy of chp2001
    -- takes a group of mass marker positions and will return the center point
    -- Mark Group definition = {MarkerGroup=1,Markers={{ Name="Mass 20", Position={ 159.5, 10.000610351563, 418.5, type="VECTOR3" }}}
    local xx1=0
    local yy1=0
    local zz1=0
    local nn1=0
    for key_1, marker_1 in massGroup.Markers do
        xx1=xx1+marker_1.Position[1]
        yy1=yy1+marker_1.Position[2]
        zz1=zz1+marker_1.Position[3]
        nn1=nn1 + 1
    end
    return {xx1/nn1,yy1/nn1,zz1/nn1}
end

function SetArcPoints(position,enemyPosition,radius,num,arclength)
    -- Courtesy of chp2001
    -- position = engineer position
    -- enemyPosition = base or assault point
    -- radius = distance from the enemyPosition
    -- num = number of points along the arc. Must be greater than 1.
    -- arclength - length of the arc in game units
    -- The radius impacts how large the arclength will be, the arclength has a maximum of around 32
    -- so to increase the width of the arc you also need to increase the radius.
    -- Example set
    -- local arcenemyBase = { 360.5, 10, 365.5, type="VECTOR3" }
    -- local arcengineer = { 233.5, 10, 386.5, type="VECTOR3" }
    -- RUtils.SetArcPoints(arcengineer, arcenemyBase, 80, 3, 30)

    local nnn=0
    local num1 = num-1
    local coords = {}
    local distvec = {position[1]-enemyPosition[1],position[3]-enemyPosition[3]}
    local angoffset = math.atan2(distvec[2],distvec[1])
    local arcangle = arclength/radius
    while nnn <= num1 do
        local xxx = 0
        local zzz = 0
        xxx = enemyPosition[1] + radius * math.cos (nnn/num1* (arcangle)+angoffset-arcangle/2)
        zzz = enemyPosition[3] + radius * math.sin (nnn/num1* (arcangle)+angoffset-arcangle/2)
        table.insert(coords, {xxx,0,zzz})
        nnn = nnn + 1
        WaitTicks(1)
    end
    --LOG('Resulting Table :'..repr(coords))
    return coords
end

function ExtractorsBeingUpgraded(aiBrain)
    -- Returns number of extractors upgrading

    local tech1ExtractorUpgrading = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * categories.TECH1, true)
    local tech2ExtractorUpgrading = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * categories.TECH2, true)
    local tech1ExtNumBuilding = 0
    local tech2ExtNumBuilding = 0
    -- own armyIndex
    local armyIndex = aiBrain:GetArmyIndex()
    -- loop over all units and search for upgrading units
    for t1extKey, t1extrator in tech1ExtractorUpgrading do
        if not t1extrator.Dead and not t1extrator:BeenDestroyed() and t1extrator:IsUnitState('Upgrading') and t1extrator:GetAIBrain():GetArmyIndex() == armyIndex then
            tech1ExtNumBuilding = tech1ExtNumBuilding + 1
        end
    end
    for t2extKey, t2extrator in tech2ExtractorUpgrading do
        if not t2extrator.Dead and not t2extrator:BeenDestroyed() and t2extrator:IsUnitState('Upgrading') and t2extrator:GetAIBrain():GetArmyIndex() == armyIndex then
            tech2ExtNumBuilding = tech2ExtNumBuilding + 1
        end
    end
    return {TECH1 = tech1ExtNumBuilding, TECH2 = tech2ExtNumBuilding}
end

function AIFindBrainTargetInRangeRNG(aiBrain, platoon, squad, maxRange, atkPri, avoidbases, platoonThreat, index)
    local position = platoon:GetPlatoonPosition()
    if platoon.PlatoonData.GetTargetsFromBase then
        --LOG('Looking for targets from position '..platoon.PlatoonData.LocationType)
        position = aiBrain.BuilderManagers[platoon.PlatoonData.LocationType].Position
    end
    local enemyThreat, targetUnits, category
    local RangeList = { [1] = maxRange }
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not avoidbases then
        avoidbases = false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayer(platoon)
    end
    
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [3] = 384,
            [4] = 512,
            [5] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [4] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    for _, range in RangeList do
        targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, position, range, 'Enemy')
        for _, v in atkPri do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local distance = false
            local targetShields = 9999
            for num, unit in targetUnits do
                if index then
                    for k, v in index do
                        if unit:GetAIBrain():GetArmyIndex() == v then
                            if not unit.Dead and not unit.CaptureInProgress and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                                local unitPos = unit:GetPosition()
                                if not retUnit or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                                    retUnit = unit
                                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                                end
                                if platoon.MovementLayer == 'Air' and platoonThreat then
                                    enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                                    --LOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                                    if enemyThreat > platoonThreat then
                                        continue
                                    end
                                end
                                local numShields = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                                if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                                    retUnit = unit
                                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                                    targetShields = numShields
                                end
                            end
                        end
                    end
                else
                    if not unit.Dead and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                        local unitPos = unit:GetPosition()
                        if avoidbases then
                            for _, w in ArmyBrains do
                                if IsEnemy(w:GetArmyIndex(), aiBrain:GetArmyIndex()) or (aiBrain:GetArmyIndex() == w:GetArmyIndex()) then
                                    local estartX, estartZ = w:GetArmyStartPos()
                                    if VDist2Sq(estartX, estartZ, unitPos[1], unitPos[3]) < 22500 then
                                        continue
                                    end
                                end
                            end
                        end
                        if platoon.MovementLayer == 'Air' and platoonThreat then
                            enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                            --LOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                            if enemyThreat > platoonThreat then
                                continue
                            end
                        end
                        local numShields = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                        if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                end
            end
            if retUnit and targetShields > 0 then
                local platoonUnits = platoon:GetPlatoonUnits()
                local punit
                for _, w in platoonUnits do
                    if not w.Dead then
                        punit = w
                        break
                    end
                end
                local closestBlockingShield = AIBehaviors.GetClosestShieldProtectingTargetSorian(punit, retUnit)
                if closestBlockingShield then
                    return closestBlockingShield
                end
            end
            if retUnit then
                return retUnit
            end
        end
    end
    return false
end

function AIFindACUTargetInRangeRNG(aiBrain, platoon, squad, maxRange, platoonThreat, index)
    local position = platoon:GetPlatoonPosition()
    local enemyThreat
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayer(platoon)
    end
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, position, maxRange, 'Enemy')
    local retUnit = false
    local distance = false
    local targetShields = 9999
    for num, unit in targetUnits do
        if index then
            for k, v in index do
                if unit:GetAIBrain():GetArmyIndex() == v then
                    if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) then
                        local unitPos = unit:GetPosition()
                        local unitArmyIndex = unit:GetArmy()
        
                        --[[if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                            continue
                        end]]
                        if platoon.MovementLayer == 'Air' and platoonThreat then
                            enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                            --LOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                            if enemyThreat > platoonThreat then
                                continue
                            end
                        end
                        local numShields = GetNumUnitsAroundPoint(aiBrain, categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                        if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                end
            end
        else
            if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) then
                local unitPos = unit:GetPosition()
                local unitArmyIndex = unit:GetArmy()

                if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                    continue
                end
                if platoon.MovementLayer == 'Air' and platoonThreat then
                    enemyThreat = GetThreatAtPosition( aiBrain, unitPos, 0, true, 'AntiAir')
                    --LOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                    if enemyThreat > platoonThreat then
                        continue
                    end
                end
                local numShields = GetNumUnitsAroundPoint(aiBrain, categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                    retUnit = unit
                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    targetShields = numShields
                end
            end
        end
    end
    if retUnit and targetShields > 0 then
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, w in platoonUnits do
            if not w.Dead then
                unit = w
                break
            end
        end
        local closestBlockingShield = AIBehaviors.GetClosestShieldProtectingTargetSorian(unit, retUnit)
        if closestBlockingShield then
            return closestBlockingShield
        end
    end
    if retUnit then
        return retUnit
    end

    return false
end

function AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, position, squad, maxRange, targetQueryCategory, TargetSearchCategory, enemyBrain)
    if type(TargetSearchCategory) == 'string' then
        TargetSearchCategory = ParseEntityCategory(TargetSearchCategory)
    end
    local enemyIndex = false
    local MyArmyIndex = aiBrain:GetArmyIndex()
    if enemyBrain then
        enemyIndex = enemyBrain:GetArmyIndex()
    end
    local RangeList = {
        [1] = 10,
        [2] = maxRange,
        [3] = maxRange + 30,
    }
    local TargetUnit = false
    local TargetsInRange, EnemyStrength, TargetPosition, category, distance, targetRange, baseTargetRange, canAttack
    for _, range in RangeList do
        if not position then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: position is empty')
            return false
        end
        if not range then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: range is empty')
            return false
        end
        if not TargetSearchCategory then
            WARN('* AI-RNG: AIFindNearestCategoryTargetInCloseRange: TargetSearchCategory is empty')
            return false
        end
        TargetsInRange = GetUnitsAroundPoint(aiBrain, targetQueryCategory, position, range, 'Enemy')
        --DrawCircle(position, range, '0000FF')
        for _, v in TargetSearchCategory do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            distance = maxRange*maxRange
            --LOG('* AIFindNearestCategoryTargetInRange: numTargets '..table.getn(TargetsInRange)..'  ')
            for num, Target in TargetsInRange do
                if Target.Dead or Target:BeenDestroyed() then
                    continue
                end
                TargetPosition = Target:GetPosition()
                EnemyStrength = 0
                -- check if we have a special player as enemy
                if enemyBrain and enemyIndex and enemyBrain ~= enemyIndex then continue end
                -- check if the Target is still alive, matches our target priority and can be attacked from our platoon
                if not Target.Dead and not Target.CaptureInProgress and EntityCategoryContains(category, Target) and platoon:CanAttackTarget(squad, Target) then
                    -- yes... we need to check if we got friendly units with GetUnitsAroundPoint(_, _, _, 'Enemy')
                    if not IsEnemy( MyArmyIndex, Target:GetAIBrain():GetArmyIndex() ) then continue end
                    if Target.ReclaimInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: ReclaimInProgress !!! Ignoring the target.')
                        continue
                    end
                    if Target.CaptureInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: CaptureInProgress !!! Ignoring the target.')
                        continue
                    end
                    targetRange = VDist2Sq(position[1],position[3],TargetPosition[1],TargetPosition[3])
                    -- check if the target is in range of the unit and in range of the base
                    if targetRange < distance then
                        TargetUnit = Target
                        distance = targetRange
                    end
                end
            end
            if TargetUnit then
                --LOG('Target Found in target aquisition function')
                return TargetUnit
            end
           coroutine.yield(10)
        end
        coroutine.yield(1)
    end
    --LOG('NO Target Found in target aquisition function')
    return TargetUnit
end

function GetAssisteesRNG(aiBrain, locationType, assisteeType, buildingCategory, assisteeCategory)
    if assisteeType == categories.FACTORY then
        -- Sift through the factories in the location
        local manager = aiBrain.BuilderManagers[locationType].FactoryManager
        return manager:GetFactoriesWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.ENGINEER then
        local manager = aiBrain.BuilderManagers[locationType].EngineerManager
        return manager:GetEngineersWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.STRUCTURE then
        local manager = aiBrain.BuilderManagers[locationType].PlatoonFormManager
        return manager:GetUnitsBeingBuilt(buildingCategory, assisteeCategory)
    else
        error('*AI ERROR: Invalid assisteeType - ' .. ToString(assisteeType))
    end

    return false
end

function ExpansionSpamBaseLocationCheck(aiBrain, location)
    local validLocation = false
    local enemyStarts = {}

    if table.getn(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
        --LOG('*AI RNG: Enemy Start Locations are present for ExpansionSpamBase')
        --LOG('*AI RNG: SpamBase position is'..repr(location))
        enemyStarts = aiBrain.EnemyIntel.EnemyStartLocations
    else
        return false
    end
    
    for key, startloc in enemyStarts do
        
        local locationDistance = VDist2Sq(startloc[1], startloc[3],location[1], location[3])
        --LOG('*AI RNG: location position distance for ExpansionSpamBase is '..locationDistance)
        if  locationDistance > 25600 and locationDistance < 250000 then
            --LOG('*AI RNG: SpamBase distance is within bounds, position is'..repr(location))
            --LOG('*AI RNG: Enemy Start Position is '..repr(startloc))
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, 'Land', location, startloc, 10)
            --local path, reason = AIAttackUtils.CanGraphToRNG(location, startloc, 'Land')
            
            if reason then
                --LOG('Path position is is '..reason)
            end
            WaitTicks(2)
            if path then
                --LOG('Path reason is '..reason)
                --LOG('*AI RNG: expansion position is within range and pathable to an enemy base for ExpansionSpamBase')
                validLocation = true
                break
            else
                continue
            end
        else
            continue
        end
    end

    if validLocation then
        --LOG('*AI RNG: Spam base is true')
        return true
    else
        --LOG('*AI RNG: Spam base is false')
        return false
    end

    return false
end

function GetNavalPlatoonMaxRangeRNG(aiBrain, platoon)
    local maxRange = 0
    local platoonUnits = platoon:GetPlatoonUnits()
    for _,unit in platoonUnits do
        if unit.Dead then
            continue
        end

        for _,weapon in unit.UnitId.Weapon do
            if not weapon.FireTargetLayerCapsTable or not weapon.FireTargetLayerCapsTable.Water then
                continue
            end

            #Check if the weapon can hit land from water
            local canAttackLand = string.find(weapon.FireTargetLayerCapsTable.Water, 'Land', 1, true)

            if canAttackLand and weapon.MaxRadius > maxRange then
                isTech1 = EntityCategoryContains(categories.TECH1, unit)
                maxRange = weapon.MaxRadius

                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                    selectedWeaponArc = 'low'
                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                    selectedWeaponArc = 'high'
                else
                    selectedWeaponArc = 'none'
                end
            end
        end
    end

    if maxRange == 0 then
        return false
    end

    -- T1 naval units don't hit land targets very well. Bail out!
    if isTech1 then
        return false
    end

    return maxRange, selectedWeaponArc
end

function UnitRatioCheckRNG(aiBrain, ratio, categoryOne, compareType, categoryTwo)
    local numOne = GetCurrentUnits(aiBrain, categoryOne)
    local numTwo = GetCurrentUnits(aiBrain, categoryTwo)
    --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOne..' '..compareType..' '..numTwo..' ) -- ['..ratio..'] -- return '..repr(CompareBody(numOne / numTwo, ratio, compareType)))
    return CompareBodyRNG(numOne / numTwo, ratio, compareType)
end

function CompareBodyRNG(numOne, numTwo, compareType)
    if compareType == '>' then
        if numOne > numTwo then
            return true
        end
    elseif compareType == '<' then
        if numOne < numTwo then
            return true
        end
    elseif compareType == '>=' then
        if numOne >= numTwo then
            return true
        end
    elseif compareType == '<=' then
        if numOne <= numTwo then
            return true
        end
    else
       error('*AI ERROR: Invalid compare type: ' .. compareType)
       return false
    end
    return false
end

function DebugArrayRNG(Table)
    for Index, Array in Table do
        if type(Array) == 'thread' or type(Array) == 'userdata' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        elseif type(Array) == 'table' then
            LOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        else
            LOG('Index['..Index..'] is type('..type(Array)..'). "', repr(Array),'".')
        end
    end
end




--[[
   This is Sproutos work, an early function from the master himself
   Inputs : 
   location, location name string
   radius, radius from location position int
   orientation, return positions based on string 'FRONT', 'REAR', 'ALL'
   positionselection, return all, random, selection int or bool
   layer, movement layer string
   patroltype return sequence bool or nil

   Returns :
   sortedList, position table
   Orient, string NESW
   positionselection, int
   ]]
function GetBasePerimeterPoints( aiBrain, location, radius, orientation, positionselection, layer, patroltype )
    
	local newloc = false
	local Orient = false
	local Basename = false
	
	-- we've been fed a base name rather than 3D co-ordinates
	-- store the Basename and convert location into a 3D position
	if type(location) == 'string' then
		Basename = location
		newloc = aiBrain.BuilderManagers[location].Position or false
		Orient = aiBrain.BuilderManagers[location].Orientation or false
		if newloc then
			location = table.copy(newloc)
		end
	end

	-- we dont have a valid 3D location
	-- likely base is no longer active --
	if not location[3] then
		return {}
	end

	if not layer then
		layer = 'Amphibious'
	end

	if not patroltype then
		patroltype = false
	end

	-- get the map dimension sizes
	local Mx = ScenarioInfo.size[1]
	local Mz = ScenarioInfo.size[2]	
	
	if orientation then
		local Sx = RNGCEIL(location[1])
		local Sz = RNGCEIL(location[3])
	
		if not Orient then
			-- tracks if we used threat to determine Orientation
			local Direction = false
			local threats = aiBrain:GetThreatsAroundPosition( location, 32, true, 'Economy' )
			RNGSORT( threats, function(a,b) return VDist2Sq(a[1],a[2],location[1],location[3]) + a[3] < VDist2Sq(b[1],b[2],location[1],location[3]) + b[3] end )
			for _,v in threats do
				Direction = GetDirectionInDegrees( {v[1],location[2],v[2]}, location )
				break	-- process only the first one
			end
			
			if Direction then
				if Direction < 45 or Direction > 315 then
					Orient = 'S'
				elseif Direction >= 45 and Direction < 135 then
					Orient = 'E'
				elseif Direction >= 135 and Direction < 225 then
					Orient = 'N'
				else
					Orient = 'W'
				end
			else
				-- Use map position to determine orientation
				-- First step is too determine if you're in the top or bottom 25% of the map
				-- if you are then you will orient N or S otherwise E or W
				-- the OrientvalueREAR will be set to value of the REAR positions (either the X or Z value depending upon NSEW Orient value)

				-- check if upper or lower quarter		
				if ( Sz <= (Mz * .25) or Sz >= (Mz * .75) ) then
					Orient = 'NS'
				-- otherwise use East/West orientation
				else
					Orient = 'EW'
				end

				-- orientation will be overridden if we are particularily close to a map edge
				-- check if extremely close to an edge (within 11% of map size)
				if (Sz <= (Mz * .11) or Sz >= (Mz * .89)) then
					Orient = 'NS'
				end

				if (Sx <= (Mx * .11) or Sx >= (Mx * .89)) then
					Orient = 'EW'
				end

				-- Second step is to determine if we are N or S - or - E or W
				
				if Orient == 'NS' then 
					-- if N/S and in the lower half of map
					if (Sz > (Mz* 0.5)) then
						Orient = 'N'
					-- else we must be in upper half
					else	
						Orient = 'S'
					end
				else
					-- if E/W and we are in the right side of the map
					if (Sx > (Mx* 0.5)) then
						Orient = 'W'
					-- else we must on the left side
					else
						Orient = 'E'
					end
				end
			end

			-- store the Orientation for any given base
			if Basename then
				aiBrain.BuilderManagers[Basename].Orientation = Orient		
			end
		end
		
		if Orient == 'S' then
			OrientvalueREAR = Sz - radius
			OrientvalueFRONT = Sz + radius		
		elseif Orient == 'E' then
			OrientvalueREAR = Sx - radius
			OrientvalueFRONT = Sx + radius
		elseif Orient == 'N' then
			OrientvalueREAR = Sz + radius
			OrientvalueFRONT = Sz - radius
		elseif Orient == 'W' then
			OrientvalueREAR = Sx + radius
			OrientvalueFRONT = Sz - radius
		end
	end

	-- If radius is very small just return the centre point and orientation
	-- this is often used by engineers to build structures according to a base template with fixed positions
	-- and still maintain the appropriate rotation -- 
	if radius < 4 then
		return { {location[1],0,location[3]} }, Orient
	end	

	local locList = {}
	local counter = 0

	local lowlimit = (radius * -1)
	local highlimit = radius
	local steplimit = (radius / 2)
	
	-- build an array of points in the shape of a box w 5 points to a side
	-- eliminating the corner positions along the way
	-- the points will be numbered from upper left to lower right
	-- this code will always return the 12 points around whatever position it is fed
	-- even if those points result in some point off of the map
	for x = lowlimit, highlimit, steplimit do
		
		for y = lowlimit, highlimit, steplimit do
			
			-- this code lops off the corners of the box and the interior points leaving us with 3 points to a side
			-- basically it forms a '+' shape
			if not (x == 0 and y == 0)	and	(x == lowlimit or y == lowlimit or x == highlimit or y == highlimit)
			and not ((x == lowlimit and y == lowlimit) or (x == lowlimit and y == highlimit)
			or ( x == highlimit and y == highlimit) or ( x == highlimit and y == lowlimit)) then
				locList[counter+1] = { RNGCEIL(location[1] + x), GetSurfaceHeight(location[1] + x, location[3] + y), RNGCEIL(location[3] + y) }
				counter = counter + 1
			end
		end
	end

	-- if we have an orientation build a list of those points that meet that specification
	-- FRONT will have all points that do not match the OrientvalueREAR (9 points)
	-- REAR will have all point that DO match the OrientvalueREAR (3 points)
	-- otherwise we keep all 12 generated points
	if orientation == 'FRONT' or orientation == 'REAR' then
		
		local filterList = {}
		counter = 0

		for k,v in locList do
			local x = v[1]
			local z = v[3]

			if Orient == 'N' or Orient == 'S' then
				if orientation == 'FRONT' and z != OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and z == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			elseif Orient == 'W' or Orient == 'E' then
				if orientation == 'FRONT' and x != OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and x == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			end
		end
		locList = filterList
	end
	
	-- sort the points from front to rear based upon orientation
	if Orient == 'N' then
		table.sort(locList, function(a,b) return a[3] < b[3] end)
	elseif Orient == 'S' then
		table.sort(locList, function(a,b) return a[3] > b[3] end)
	elseif Orient == 'E' then 
		table.sort(locList, function(a,b) return a[1] > b[1] end)
	elseif Orient == 'W' then
		table.sort(locList, function(a,b) return a[1] < b[1] end)
	end

	local sortedList = {}
	
	if table.getsize(locList) == 0 then
		return {} 
	end
	
	-- Originally I always did this and it worked just fine but I want
	-- to find a way to get the AI to rotate templated builds so I need
	-- to provide a consistent result based upon orientation and NOT 
	-- sorted by proximity to map centre -- as I had been doing -- so 
	-- now I only sort the list if its a patrol or Air request
	-- I have kept the original code contained inside this loop but 
	-- it doesn't run
	if patroltype or layer == 'Air' then
		local lastX = Mx* 0.5
		local lastZ = Mz* 0.5
	
		if patroltype or layer == 'Air' then
			lastX = location[1]
			lastZ = location[3]
		end
		
	
		-- Sort points by distance from (lastX, lastZ) - map centre
		-- or if patrol or 'Air', then from the provided location
		for i = 1, counter do
		
			local lowest
			local czX, czZ, pos, distance, key
		
			for k, v in locList do
				local x = v[1]
				local z = v[3]
				distance = VDist2Sq(lastX, lastZ, x, z)
				if not lowest or distance < lowest then
					pos = v
					lowest = distance
					key = k
				end
			end
		
			if not pos then
				return {} 
			end
		
			sortedList[i] = pos
			
			-- use the last point selected as the start point for the next distance check
			if patroltype or layer == 'Air' then
				lastX = pos[1]
				lastZ = pos[3]
			end
			RNGREMOVE(locList, key)
		end
	else
		sortedList = locList
	end

	-- pick a specific position
	if positionselection then
	
		if type(positionselection) == 'boolean' then
			positionselection = Random( 1, counter )	--table.getn(sortedList))
		end

	end


	return sortedList, Orient, positionselection
end

function GetDistanceBetweenTwoVectors( v1, v2 )
    return VDist3(v1, v2)
end

function XZDistanceTwoVectors( v1, v2 )
    return VDist2( v1[1], v1[3], v2[1], v2[3] )
end

function GetVectorLength( v )
    return RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
end

function NormalizeVector( v )

	if v.x then
		v = {v.x, v.y, v.z}
	end
	
    local length = RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
	
    if length > 0 then
        local invlength = 1 / length
        return Vector( v[1] * invlength, v[2] * invlength, v[3] * invlength )
    else
        return Vector( 0,0,0 )
    end
end

function GetDifferenceVector( v1, v2 )
    return Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3])
end

function GetDirectionVector( v1, v2 )
    return NormalizeVector( Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3]) )
end

function GetDirectionInDegrees( v1, v2 )
    local RNGACOS = math.acos
	local vec = GetDirectionVector( v1, v2)
	
	if vec[1] >= 0 then
		return RNGACOS(vec[3]) * (360/(RNGPI*2))
	end
	
	return 360 - (RNGACOS(vec[3]) * (360/(RNGPI*2)))
end

function ComHealthRNG(cdr)
    local armorPercent = 100 / cdr:GetMaxHealth() * cdr:GetHealth()
    local shieldPercent = armorPercent
    if cdr.MyShield then
        shieldPercent = 100 / cdr.MyShield:GetMaxHealth() * cdr.MyShield:GetHealth()
    end
    return ( armorPercent + shieldPercent ) / 2
end

-- This is Uvesos lead target function 
function LeadTargetRNG(LauncherPos, target, minRadius, maxRadius)
    -- Get launcher and target position
    --local LauncherPos = launcher:GetPosition()
    local TargetPos
    -- Get target position in 1 second intervals.
    -- This allows us to get speed and direction from the target
    local TargetStartPosition=0
    local Target1SecPos=0
    local Target2SecPos=0
    local XmovePerSec=0
    local YmovePerSec=0
    local XmovePerSecCheck=-1
    local YmovePerSecCheck=-1
    -- Check if the target is runing straight or circling
    -- If x/y and xcheck/ycheck are equal, we can be sure the target is moving straight
    -- in one direction. At least for the last 2 seconds.
    local LoopSaveGuard = 0
    while target and (XmovePerSec ~= XmovePerSecCheck or YmovePerSec ~= YmovePerSecCheck) and LoopSaveGuard < 10 do
        -- 1st position of target
        TargetPos = target:GetPosition()
        TargetStartPosition = {TargetPos[1], 0, TargetPos[3]}
        coroutine.yield(10)
        -- 2nd position of target after 1 second
        TargetPos = target:GetPosition()
        Target1SecPos = {TargetPos[1], 0, TargetPos[3]}
        XmovePerSec = (TargetStartPosition[1] - Target1SecPos[1])
        YmovePerSec = (TargetStartPosition[3] - Target1SecPos[3])
        coroutine.yield(10)
        -- 3rd position of target after 2 seconds to verify straight movement
        TargetPos = target:GetPosition()
        Target2SecPos = {TargetPos[1], TargetPos[2], TargetPos[3]}
        XmovePerSecCheck = (Target1SecPos[1] - Target2SecPos[1])
        YmovePerSecCheck = (Target1SecPos[3] - Target2SecPos[3])
        --We leave the while-do check after 10 loops (20 seconds) and try collateral damage
        --This can happen if a player try to fool the targetingsystem by circling a unit.
        LoopSaveGuard = LoopSaveGuard + 1
    end
    -- Get launcher position height
    local fromheight = GetTerrainHeight(LauncherPos[1], LauncherPos[3])
    if GetSurfaceHeight(LauncherPos[1], LauncherPos[3]) > fromheight then
        fromheight = GetSurfaceHeight(LauncherPos[1], LauncherPos[3])
    end
    -- Get target position height
    local toheight = GetTerrainHeight(Target2SecPos[1], Target2SecPos[3])
    if GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3]) > toheight then
        toheight = GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3])
    end
    -- Get height difference between launcher position and target position
    -- Adjust for height difference by dividing the height difference by the missiles max speed
    local HeightDifference = math.abs(fromheight - toheight) / 12
    -- Speed up time is distance the missile will travel while reaching max speed (~22.47 MapUnits)
    -- divided by the missiles max speed (12) which is equal to 1.8725 seconds flight time
    local SpeedUpTime = 22.47 / 12
    --  Missile needs 3 seconds to launch
    local LaunchTime = 3
    -- Get distance from launcher position to targets starting position and position it moved to after 1 second
    local dist1 = VDist2(LauncherPos[1], LauncherPos[3], Target1SecPos[1], Target1SecPos[3])
    local dist2 = VDist2(LauncherPos[1], LauncherPos[3], Target2SecPos[1], Target2SecPos[3])
    -- Missile has a faster turn rate when targeting targets < 50 MU away, so it will level off faster
    local LevelOffTime = 0.25
    local CollisionRangeAdjust = 0
    if dist2 < 50 then
        LevelOffTime = 0.02
        CollisionRangeAdjust = 2
    end
    -- Divide both distances by missiles max speed to get time to impact
    local time1 = (dist1 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    local time2 = (dist2 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Get the missile travel time by extrapolating speed and time from dist1 and dist2
    local MissileTravelTime = (time2 + (time2 - time1)) + ((time2 - time1) * time2)
    -- Now adding all times to get final missile flight time to the position where the target will be
    local MissileImpactTime = MissileTravelTime + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Create missile impact corrdinates based on movePerSec * MissileImpactTime
    local MissileImpactX = Target2SecPos[1] - (XmovePerSec * MissileImpactTime)
    local MissileImpactY = Target2SecPos[3] - (YmovePerSec * MissileImpactTime)
    -- Adjust for targets CollisionOffsetY. If the hitbox of the unit is above the ground
    -- we nedd to fire "behind" the target, so we hit the unit in midair.
    local TargetCollisionBoxAdjust = 0
    local TargetBluePrint = __blueprints[target.UnitId]
    if TargetBluePrint.CollisionOffsetY and TargetBluePrint.CollisionOffsetY > 0 then
        -- if the unit is far away we need to target farther behind the target because of the projectile flight angel
        local DistanceOffset = (100 / 256 * dist2) * 0.06
        TargetCollisionBoxAdjust = TargetBluePrint.CollisionOffsetY * CollisionRangeAdjust + DistanceOffset
    end
    -- To calculate the Adjustment behind the target we use a variation of the Pythagorean theorem. (Percent scale technique)
    -- (a²+b²=c²) If we add x% to c² then also a² and b² are x% larger. (a²)*x% + (b²)*x% = (c²)*x%
    local Hypotenuse = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    local HypotenuseScale = 100 / Hypotenuse * TargetCollisionBoxAdjust
    local aLegScale = (MissileImpactX - LauncherPos[1]) / 100 * HypotenuseScale
    local bLegScale = (MissileImpactY - LauncherPos[3]) / 100 * HypotenuseScale
    -- Add x percent (behind) the target coordinates to get our final missile impact coordinates
    MissileImpactX = MissileImpactX + aLegScale
    MissileImpactY = MissileImpactY + bLegScale
    -- Cancel firing if target is outside map boundries
    if MissileImpactX < 0 or MissileImpactY < 0 or MissileImpactX > ScenarioInfo.size[1] or MissileImpactY > ScenarioInfo.size[2] then
        --LOG('Target outside map boundries')
        return false
    end
    local dist3 = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    if dist3 < minRadius or dist3 > maxRadius then
        --LOG('Target outside max radius')
        return false
    end
    -- return extrapolated target position / missile impact coordinates
    return {MissileImpactX, Target2SecPos[2], MissileImpactY}
end

function AIFindRangedAttackPositionRNG(aiBrain, platoon, MaxPlatoonWeaponRange)
    local startPositions = {}
    local myArmy = ScenarioInfo.ArmySetup[aiBrain.Name]
    local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
    local platoonPosition = platoon:GetPlatoonPosition()

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        local posThreat = 0
        local posDistance = 0
        if startPos then
            if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                posThreat = GetThreatAtPosition(aiBrain, startPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'StructuresNotMex')
                --LOG('Ranged attack loop position is '..repr(startPos)..' with threat of '..posThreat)
                if posThreat > 5 then
                    if GetNumUnitsAroundPoint(aiBrain, categories.STRUCTURE - categories.WALL, startPos, 50, 'Enemy') > 0 then
                        --LOG('Ranged attack position has structures within range')
                        posDistance = VDist2Sq(mainBasePos[1], mainBasePos[3], startPos[1], startPos[2])
                        --LOG('Potential Naval Ranged attack position :'..repr(startPos)..' Threat at Position :'..posThreat..' Distance :'..posDistance)
                        table.insert(startPositions,
                            {
                                Position = startPos,
                                Threat = posThreat,
                                Distance = posDistance,
                            }
                        )
                    else
                        --LOG('Ranged attack position has threat but no structures within range')
                    end
                end
            end
        end
    end
    --LOG('Potential Positions Table '..repr(startPositions))
    -- We sort the positions so the closest are first
    RNGSORT( startPositions, function(a,b) return a.Distance < b.Distance end )
    --LOG('Potential Positions Sorted by distance'..repr(startPositions))
    local attackPosition = false
    local targetStartPosition = false
    --We look for the closest
    for k, v in startPositions do
        local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(aiBrain, 'Water Path Node', v.Position[1], v.Position[3])
        if waterNodeDist and waterNodeDist < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange + 900) then
            --LOG('Start position is '..waterNodeDist..' from water node, weapon range on platoon is '..MaxPlatoonWeaponRange..' we are going to attack from this position')
            if AIAttackUtils.CheckPlatoonPathingEx(platoon, waterNodePos) then
                attackPosition = waterNodePos
                targetStartPosition = v.Position
                break
            end
        end
    end
    if attackPosition then
        --LOG('Valid Attack Position '..repr(attackPosition)..' target Start Position '..repr(targetStartPosition))
    end
    return attackPosition, targetStartPosition
end
-- Another of Sproutos functions
function GetEnemyUnitsInRect( aiBrain, x1, z1, x2, z2 )
    
    local units = GetUnitsInRect(x1, z1, x2, z2)
    
    if units then
	
        local enemyunits = {}
		local counter = 0
		
        local IsEnemy = IsEnemy
		local GetAIBrain = moho.entity_methods.GetAIBrain
		
        for _,v in units do
		
            if not v.Dead and IsEnemy( GetAIBrain(v).ArmyIndex, aiBrain.ArmyIndex) then
                enemyunits[counter+1] =  v
				counter = counter + 1
            end
        end 
		
        if counter > 0 then
            return enemyunits, counter
        end
    end
    
    return {}, 0
end

function GetShieldRadiusAboveGroundSquaredRNG(shield)
    local BP = shield:GetBlueprint().Defense.Shield
    local width = BP.ShieldSize
    local height = BP.ShieldVerticalOffset

    return width * width - height * height
end

function ShieldProtectingTargetRNG(aiBrain, targetUnit)
    if not targetUnit then
        return false
    end

    -- If targetUnit is within the radius of any shields return true
    local tPos = targetUnit:GetPosition()
    local shields = GetUnitsAroundPoint(aiBrain, categories.SHIELD * categories.STRUCTURE, targetUnit:GetPosition(), 50, 'Enemy')
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)
            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                return true
            end
        end
    end
    return false
end

local markerTypeCache = { }
--- Flushes the entire cache
function FlushMarkerTypeCache()
    markerTypeCache = { }
end
--- Flushes a single element from the cache
-- @param markerType The type to flush.
function FlushElementOfMarkerTypeCache(markerType)
    markerTypeCache[markerType] = nil
end
--- Sets the cache for a specific marker type - it is up to you to make 
-- sure the format is correct: {Position = v.position, Name = k}.
-- @param markerType The type to set.
-- @param markers The marker to set.
function SetMarkerTypeCache(markerType, markers)
    markerTypeCache[markerType] = markers
end

function GetMarkersByType(markerType)

    --LOG("Retrieving markers of type: " .. markerType)

    -- check if parameter is set, if not - help us all and return everything
    if not markerType then 
        return Scenario.MasterChain._MASTERCHAIN_.Markers
    end
    -- check if we already looked for these in the past
    if not markerTypeCache[markerType] then
        -- make it easier to read
        local markers = Scenario.MasterChain._MASTERCHAIN_.Markers
        -- prepare a table to keep the markers
        local cache = { }
        -- go over every marker and popualte our table
        if markers then
            for k, v in markers do
                if v.type == markerType then
                    table.insert(cache, {Position = v.position, Name = k})
                end
            end
        end
        -- add the markers of this type to the cache
        markerTypeCache[markerType] = cache
        --LOG("ScenarioUtils: Cached " .. table.getn(cache) .. " markers of type: " .. markerType)
    end
    -- return the cached markers
    return markerTypeCache[markerType]
end

function AIGetSortedMassLocationsThreatRNG(aiBrain, minDist, maxDist, tMin, tMax, tRings, tType, position)

    local threatCheck = false
    local maxDistance = 2000
    local minDistance = 0


    local startX, startZ
    
    if position then
        startX = position[1]
        startZ = position[3]
    else
        startX, startZ = aiBrain:GetArmyStartPos()
    end
    if maxDist and minDist then
        maxDistance = maxDist * maxDist
        minDistance = minDist * minDist
    end

    if tMin and tMax and tType then
        threatCheck = true
    else
        threatCheck = false
    end

    local markerList = GetMarkersByType('Mass')
    RNGSORT(markerList, function(a,b) return VDist2Sq(a.Position[1],a.Position[3], startX,startZ) < VDist2Sq(b.Position[1],b.Position[3], startX,startZ) end)
    --LOG('Sorted Mass Marker List '..repr(markerList))
    local newList = {}
    for _, v in markerList do
        -- check distance to map border. (game engine can't build mass closer then 8 mapunits to the map border.) 
        if v.Position[1] <= 8 or v.Position[1] >= ScenarioInfo.size[1] - 8 or v.Position[3] <= 8 or v.Position[3] >= ScenarioInfo.size[2] - 8 then
            -- mass marker is too close to border, skip it.
            continue
        end
        if VDist2Sq(v.Position[1], v.Position[3], startX, startZ) < minDistance then
            continue
        end
        if VDist2Sq(v.Position[1], v.Position[3], startX, startZ) > maxDistance  then
            LOG('Current Distance of marker..'..VDist2Sq(v.Position[1], v.Position[3], startX, startZ))
            LOG('Max Distance'..maxDistance)
            LOG('mass marker MaxDistance Reached, breaking loop')
            break
        end
        if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            if threatCheck then
                if GetThreatAtPosition(aiBrain, v.Position, 0, true, tType) >= tMax then
                    --LOG('mass marker threatMax Reached, continuing')
                    continue
                end
            end
            table.insert(newList, v)
        end
    end
    LOG('Return marker list has '..table.getn(newList)..' entries')
    return newList
end

function EdgeDistance(x,y,mapwidth)
    local edgeDists = { x, y, math.abs(x-mapwidth), math.abs(y-mapwidth)}
    RNGSORT(edgeDists, function(k1, k2) return k1 < k2 end)
    return edgeDists[1]
end

function GetDirectorTarget(aiBrain, platoon, threatType, platoonThreat)


    
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayer(platoon)
    end

end

ThrottledAllocateRNG = function(aiBrain)
    local aiBrainIndex = aiBrain:GetArmyIndex()
    LOG('aiBrain index (start mex allocation thread)'..aiBrainIndex)
    local startX, startZ = aiBrain:GetArmyStartPos()
    local start={startX,0,startZ}
    while not aiBrain.defeat do
        local brainExtractors = aiBrain:GetListOfUnits(categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1, false, false)
        local extractorCount = table.getn(brainExtractors)
        local givemex = 0
        local allyBrains = {}
        local allycount=0
        for _, v in ArmyBrains do
            local Index = v:GetArmyIndex()
            if IsEnemy(aiBrainIndex, Index) or ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
            if aiBrain.Nickname==v.Nickname then --this is me
            else
                allycount=allycount+1
            end
            local astartX, astartZ = v:GetArmyStartPos()
            local aiBrainstart = {position={astartX, 0, astartZ},abrain=v,index=Index}
            table.insert(allyBrains,aiBrainstart)
        end
        if allycount==0 then break else 
        LOG('allycount '..repr(allycount)) end
        for _, x in brainExtractors do
            if x.Position~=nil then continue end
            x.Position=x:GetPosition()
        end
        table.sort(brainExtractors,function(k1,k2) return VDist2Sq(start[1],start[3],k1.Position[1],k1.Position[3])>VDist2Sq(start[1],start[3],k2.Position[1],k2.Position[3]) end)
        for _, x in brainExtractors do
            if not x or x.Dead then continue end
            if MexAllocateRNG(aiBrain,x,allyBrains) then givemex=givemex+1 end
            if givemex/extractorCount>0.2 then break end
            WaitTicks(5)
        end
        WaitTicks(200)
    end
end

MexAllocateRNG = function(aiBrain,mex,allyBrains)
    LOG('start construct mex')
    if mex:IsUnitState('Upgrading') then return false end
    local starts = {}
    local aiBrainIndex = aiBrain:GetArmyIndex()
    LOG('aiBrain index'..aiBrainIndex)
    local mexnums1 = {}
    for _, v in allyBrains do
        local Index = v.index
        local extractorCount = v.abrain:GetCurrentUnits(categories.STRUCTURE * categories.MASSEXTRACTION)
        table.insert(mexnums1,Index,extractorCount)
        local aiBrainstart = {Index, v.position, mexnums1[Index]}
        table.insert(starts,aiBrainstart)
    end
        table.sort(starts,function(k1,k2) return (k1[3]+10)*VDist2Sq(k1[2][1],k1[2][3],mex.Position[1],mex.Position[3])<(k2[3]+10)*VDist2Sq(k2[2][1],k2[2][3],mex.Position[1],mex.Position[3]) end)
        local chosenstart = starts[1]
            if chosenstart[1]==aiBrainIndex then return false
            elseif chosenstart[1]==nil then return false
            else
                LOG('giving mex to '..repr(chosenstart[1]))
                if mex.PlatoonHandle then
                    mex.PlatoonHandle:PlatoonDisbandNoAssign()
                end
                GiveUnitToArmy(mex,chosenstart[1])
            end
    return true
end

DisplayBaseMexAllocationRNG = function(aiBrain)
    LOG('starting expansion display')
    WaitTicks(50)
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    local Expands = AIUtils.AIGetMarkerLocations(aiBrain, 'Expansion Area')
    local BigExpands = AIUtils.AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
    local players = {}
    LOG('finished grabbing expands and starts')
    for _,v in ArmyBrains do
        if ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
        local astartX, astartZ = v:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, 0, astartZ}}
        table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3])<VDist2Sq(k2.Position[1],k2.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3]) end)
        aiBrainstart.Position[2]=starts[1].Position[2]
        table.insert(players,aiBrainstart)
    end
    local MassMarker = {}
    local expandstart = {}
    for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Mass' then
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                -- mass marker is too close to border, skip it.
                continue
            end 
            table.insert(MassMarker, v)
        end
    end
    for _, v in Expands do
        v.expandtype='expand'
        v.mexnum=0
        table.insert(expandstart,v)
    end
    for _, v in BigExpands do
        v.expandtype='bigexpand'
        v.mexnum=0
        table.insert(expandstart,v)
    end
    for _, v in starts do
        v.expandtype='start'
        v.mexnum=0
        table.insert(expandstart,v)
    end
    while aiBrain.Result ~= "defeat" do
        for _, v in MassMarker do
            local pos1={0,0,0}
            local pos2={0,0,0}
            table.sort(expandstart,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.position[1],v.position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.position[1],v.position[3]) end)
            local chosenstart = expandstart[1]
            expandstart[1].mexnum=expandstart[1].mexnum+1
            pos1=v.position
            pos2=chosenstart.Position
            DrawLinePop(pos1,pos2,'88FF0000')
            if VDist2Sq(expandstart[2].Position[1],expandstart[2].Position[3],v.position[1],v.position[3])-VDist2Sq(expandstart[1].Position[1],expandstart[1].Position[3],v.position[1],v.position[3])<5 then
                pos2=expandstart[2].Position
                expandstart[2].mexnum=expandstart[2].mexnum+1
                DrawLinePop(pos1,pos2,'88FF0000')
            end
        end
        for _, v in expandstart do
            local pos1={0,0,0}
            local pos2={0,0,0}
            table.sort(players,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.Position[1],v.Position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.Position[1],v.Position[3]) end)
            local chosenstart = players[1]
            pos1=v.Position
            pos2=chosenstart.Position
            if v.expandtype=='start' then
                DrawLinePop(pos1,pos2,'ff0000FF')
                DrawCircle(pos1,5*v.mexnum,'ff0000FF')
            elseif v.expandtype=='bigexpand' then
                DrawLinePop(pos1,pos2,'ff00FF00')
                DrawCircle(pos1,5*v.mexnum,'ff00FF00')
            elseif v.expandtype=='expand' then
                DrawLinePop(pos1,pos2,'ffFF00FF')
                DrawCircle(pos1,5*v.mexnum,'ffFF0000')
            end
            if v.expandtype~='start' then
                table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.Position[1],v.Position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.Position[1],v.Position[3]) end)
                if VDist2Sq(chosenstart.Position[1],chosenstart.Position[3],starts[1].Position[1],starts[1].Position[3])>3 then
                    pos2=starts[1].Position
                    if v.expandtype=='bigexpand' then
                        DrawLinePop(pos1,pos2,'5f00FF00')
                    elseif v.expandtype=='expand' then
                        DrawLinePop(pos1,pos2,'5fFF00FF')
                    end
                    if VDist2Sq(starts[2].Position[1],starts[2].Position[3],v.Position[1],v.Position[3])-VDist2Sq(starts[1].Position[1],starts[1].Position[3],v.Position[1],v.Position[3])<5 then
                        pos2=starts[2].Position
                        if v.expandtype=='bigexpand' then
                            DrawLinePop(pos1,pos2,'5f00FF00')
                        elseif v.expandtype=='expand' then
                            DrawLinePop(pos1,pos2,'5fFF00FF')
                        end
                    end
                end
            end
            if VDist2Sq(players[2].Position[1],players[2].Position[3],v.Position[1],v.Position[3])-VDist2Sq(players[1].Position[1],players[1].Position[3],v.Position[1],v.Position[3])<5 then
                pos2=players[2].Position
                if v.expandtype=='start' then
                    DrawLinePop(pos1,pos2,'ff0000FF')
                elseif v.expandtype=='bigexpand' then
                    DrawLinePop(pos1,pos2,'ff00FF00')
                elseif v.expandtype=='expand' then
                    DrawLinePop(pos1,pos2,'ffFF00FF')
                end
            end
            v.mexnum=0
        end
        WaitTicks(2)
    end
end
DisplayExpansionAllegianceSetupRNG = function(aiBrain)
    LOG('starting expansion display')
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    local Expands = AIUtils.AIGetMarkerLocations(aiBrain, 'Expansion Area')
    local BigExpands = AIUtils.AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
    LOG('finished grabbing expands and starts')
    local MassMarker = {}
    local expandstart = {}
    local players = {}
    aiBrain.teamBases={}
    aiBrain.enemyBases={}
    for i,v in ArmyBrains do
        if ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
        local astartX, astartZ = v:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, 0, astartZ},army=i}
        table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3])<VDist2Sq(k2.Position[1],k2.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3]) end)
        aiBrainstart.Position[2]=starts[1].Position[2]
        table.insert(players,i,aiBrainstart)
    end
    for _, v in Expands do
        v.expandtype='expand'
        v.mexnum=0
        v.mextable={}
        v.relevance=0
        v.owner=nil
        table.insert(expandstart,v)
    end
    for _, v in BigExpands do
        v.expandtype='bigexpand'
        v.mexnum=0
        v.mextable={}
        v.relevance=0
        v.owner=nil
        table.insert(expandstart,v)
    end
    for _, v in starts do
        v.expandtype='start'
        v.mexnum=0
        v.mextable={}
        v.relevance=0
        v.owner=nil
        table.insert(expandstart,v)
    end
    for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Mass' then
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                -- mass marker is too close to border, skip it.
                continue
            end 
            table.sort(expandstart,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.position[1],v.position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.position[1],v.position[3]) end)
            expandstart[1].mexnum=expandstart[1].mexnum+1
            table.insert(expandstart[1].mextable, v)
            if VDist2Sq(expandstart[2].Position[1],expandstart[2].Position[3],v.position[1],v.position[3])-VDist2Sq(expandstart[1].Position[1],expandstart[1].Position[3],v.position[1],v.position[3])<5 then
                expandstart[2].mexnum=expandstart[2].mexnum+1
                table.insert(expandstart[2].mextable, v)
            end
            table.insert(MassMarker,v)
        end
    end
    for _, v in expandstart do
        for _,x in MassMarker do
            v.relevance=v.relevance+ScenarioInfo.size[1]/math.pow(math.max(VDist2(v.Position[1],v.Position[3],x.position[1],x.position[3]),25),1.5)
        end
        if not v.expandtype=='start' then
            for _,x in starts do
                v.relevance=v.relevance-ScenarioInfo.size[1]/math.pow(VDist2(v.Position[1],v.Position[3],x.Position[1],x.Position[3]),1.5)
                --LOG('relevance '..repr(v.relevance))
            end
        end
    end
    for i, v in expandstart do
        UpdateExpansionAllegianceRNG(aiBrain,v,i)
    end
    while aiBrain.Result ~= "defeat" do
        for x=0,30,1 do
            for i, v in expandstart do
                DisplayExpansionAllegianceRNG(aiBrain,v,i)
            end
            WaitTicks(2)
        end
        for i, v in expandstart do
            UpdateExpansionAllegianceRNG(aiBrain,v,i)
        end
    end
end
DisplayExpansionAllegianceRNG = function(aiBrain,marker,num)
    local pos1
    local pos2
        for _, v in marker.mextable do
            pos1=v.position
            pos2=marker.Position
            DrawLinePop(pos1,pos2,'88FF0000')
        end
        if marker.expandtype=='start' then
            DrawCircle(pos2,marker.relevance,'5a0000FF')
        elseif marker.expandtype=='bigexpand' then
            DrawCircle(pos2,marker.relevance,'5a00FF00')
        elseif marker.expandtype=='expand' then
            DrawCircle(pos2,marker.relevance,'5aFF0000')
        end
        if marker.owner then
            pos1=marker.Position
            pos2=marker.ownerPos
            if marker.expandtype=='start' then
                DrawLinePop(pos1,pos2,'c00000FF')
            elseif marker.expandtype=='bigexpand' then
                DrawLinePop(pos1,pos2,'c000FF00')
            elseif marker.expandtype=='expand' then
                DrawLinePop(pos1,pos2,'c0FF00FF')
            end
        end
        if marker.allythreat then
            pos1=marker.Position
            local allegiance=marker.allythreat-marker.enemythreat
            if allegiance>0 then
                local radius=math.min(allegiance/20,marker.relevance-1)
                DrawCircle(pos1,radius,'ff0000FF')
            else
                local radius=math.min(-allegiance/20,marker.relevance-1)
                DrawCircle(pos1,radius,'ffFF0000')
            end
        end
        --[[for i,v in players do
            if aiBrain:GetThreatAtPosition(marker.Position, 1, true, 'Overall',i)>0 then
                v.points=v.points+aiBrain:GetThreatAtPosition(marker.Position, 1, true, 'Overall',i)
            else
                v.points=v.points*0.9
            end
        end
        aiBrain:GetThreatAtPosition(marker.Position, 1, true, 'Overall')--]]
end
UpdateExpansionAllegianceRNG = function(aiBrain,marker,num)
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    local aiBrainindex = aiBrain:GetArmyIndex()
    local players = {}
    local maxpoints = 0
    local maxindex
    local brainThreats=aiBrain:GrabMarkerThreatsRNG(marker)
    marker.allythreat=0
    marker.enemythreat=0
    for i,v in ArmyBrains do
        if ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
        local index = v:GetArmyIndex()
        local enemybool = false
        if IsEnemy(aiBrainindex,v:GetArmyIndex()) then
            enemybool=true
        end
        if not v.points then
            v.points={}
            v.points[num]=0
        end
        if not v.points[num] then
            v.points[num]=0
        end
        local astartX, astartZ = v:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, 0, astartZ},army=i}
        table.sort(starts,function(k1,k2) return VDist2(k1.Position[1],k1.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3])<VDist2(k2.Position[1],k2.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3]) end)
        aiBrainstart.Position[2]=starts[1].Position[2]
        table.insert(players,i,aiBrainstart)
        if not v.locationstart then
            v.locationstart=aiBrainstart.Position
        end
        --LOG('threat for army'..repr(i)..' at marker '..repr(marker.Name)..' is '..repr(brainThreats[index])..' points are '..repr(v.points[num]))
                v.points[num]=v.points[num]+brainThreats[index]
                v.points[num]=v.points[num]*0.9
            if v.points[num]>maxpoints then
                maxpoints=v.points[num]
                maxindex=i
            end
            if not enemybool then
                marker.allythreat=marker.allythreat+v.points[num]
            else
                marker.enemythreat=marker.enemythreat+v.points[num]
            end
    end
        if maxpoints>10 then
            marker.owner=maxindex
            marker.ownerPos=players[maxindex].Position
        else
            marker.owner=nil
        end
        --LOG('allegiance for '..repr(marker.Name)..' is '..repr(marker.allythreat-marker.enemythreat))
        if not aiBrain.emptyBases then aiBrain.emptyBases={} end
        if not aiBrain.emptyBase then aiBrain.emptyBase=0 end
        if not aiBrain.teamBase then aiBrain.teamBase=0 end
        if not aiBrain.enemyBase then aiBrain.enemyBase=0 end
        if marker.allythreat-marker.enemythreat>10 then
            if not aiBrain.teamBases[num] then 
                aiBrain.teamBases[num]=marker 
                aiBrain.teamBase=aiBrain.teamBase+1
            end
            if aiBrain.enemyBases[num] then aiBrain.enemyBases[num]=nil 
                aiBrain.enemyBase=aiBrain.enemyBase-1
            end
            if aiBrain.emptyBases[num] then aiBrain.emptyBases[num]=nil 
                aiBrain.emptyBase=aiBrain.emptyBase-1
            end
        elseif math.abs(marker.allythreat-marker.enemythreat)<10 then
            if aiBrain.teamBases[num] then aiBrain.teamBases[num]=nil 
                aiBrain.teamBase=aiBrain.teamBase-1
            end
            if aiBrain.enemyBases[num] then aiBrain.enemyBases[num]=nil 
                aiBrain.enemyBase=aiBrain.enemyBase-1
            end
            if not aiBrain.emptyBases[num] then 
                aiBrain.emptyBases[num]=marker 
                aiBrain.emptyBase=aiBrain.emptyBase+1
            end
        else
            if not aiBrain.enemyBases[num] then 
                aiBrain.enemyBases[num]=marker 
                aiBrain.enemyBase=aiBrain.enemyBase+1
            end
            if aiBrain.teamBases[num] then aiBrain.teamBases[num]=nil 
                aiBrain.teamBase=aiBrain.teamBase-1
            end
            if aiBrain.emptyBases[num] then aiBrain.emptyBases[num]=nil 
                aiBrain.emptyBase=aiBrain.emptyBase-1
            end
        end
end
DisplayEconomyRNG = function(aiBrain)
    WaitTicks(150)
    if ArmyIsCivilian(aiBrain:GetArmyIndex()) then return end
    if ScenarioInfo.Options.AIDebugDisplay ~= 'displayOn' then
        return
    end
    if not aiBrain.locationstart then
        local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
        local astartX, astartZ = aiBrain:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, 0, astartZ}}
        table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3])<VDist2Sq(k2.Position[1],k2.Position[3],aiBrainstart.Position[1],aiBrainstart.Position[3]) end)
        aiBrainstart.Position[2]=starts[1].Position[2]
        aiBrain.locationstart=aiBrainstart.Position
    end
    while aiBrain.Result ~= "defeat" do
        if not aiBrain.cmanager.income.r.m then LOG('no mass?') WaitTicks(20) continue end
        if not aiBrain.cmanager.income.t.e or not aiBrain.cmanager.income.r.e then LOG('no energy?') WaitTicks(20) continue end
        local armycolors={tank='ffFF0000',scout='ffFF00DC',arty='ffFFD800',aa='ff00FFDD',sniper='ff4CFF00',shield='ff0094FF',mml='ffB200FF',bot='ff4CFF00',armoured='ff4CFF00'}
        local fcolors={Land='ffFF0000',Naval='ffFFD800',Air='ff00FFDD'}
        local scolors={Land='ffFF0000',Naval='ffFFD800',Air='ff00FFDD',T1='ff4CFF00',T2='ff267F00',eng='ffB200FF',other='ffFFFFFF'}
        local engsum=0
        for _,v in aiBrain.cmanager.categoryspend.eng do
            engsum=engsum+v
        end
        local spendcategories={Land=aiBrain.cmanager.categoryspend.fac.Land,Air=aiBrain.cmanager.categoryspend.fac.Air,Naval=aiBrain.cmanager.categoryspend.fac.Naval,T1=aiBrain.cmanager.categoryspend.mex.T1,T2=aiBrain.cmanager.categoryspend.mex.T2,eng=engsum,other=0}
        local othersum=aiBrain.cmanager.spend.m
        for _,v in spendcategories do
            othersum=othersum-v
        end
        spendcategories.other=othersum
        local factotal=aiBrain.smanager.fac
        local facnum={Land=0,Air=0,Naval=0}
        local facsum=0
        for x,v in factotal do
            for _,i in factotal[x] do
                facsum=facsum+i
                facnum[x]=facnum[x]+i
            end
        end
        local facspendtotals={Land=0,Air=0,Naval=0}
        local fspendsum=0
        for i,v in aiBrain.fmanager.spend do
            if v.total then
                facspendtotals[i]=v.total*facnum[i]
                fspendsum=fspendsum+v.total*facnum[i]
            end
        end
        local rawm=aiBrain.cmanager.income.r.m
        local totalm=aiBrain.cmanager.income.t.m
        local spendm=aiBrain.cmanager.spend.m
        local storemaxm=aiBrain.cmanager.storage.max.m/10
        local storem=aiBrain.cmanager.storage.current.m/10
        local rawe=aiBrain.cmanager.income.r.e/10
        local totale=aiBrain.cmanager.income.t.e/10
        local neede=aiBrain.cmanager.income.neede/10
        local spende=aiBrain.cmanager.spend.e/10
        local storemaxe=aiBrain.cmanager.storage.max.e/30
        local storee=aiBrain.cmanager.storage.current.e/30
        local home=aiBrain.locationstart
        local army=aiBrain.amanager
        local widthm=math.max(math.sqrt(rawm),4)
        local widthe=math.max(math.sqrt(rawe),4)
        for _=0,25 do
            local voffset=-10
            --[[aiBrain:RenderChartRNG(home,army.t1,6,voffset,armycolors)
            aiBrain:RenderChartRNG(home,army.t2,6,voffset-6,armycolors)
            aiBrain:RenderChartRNG(home,army.t3,6,voffset-12,armycolors)]]
            RenderPieRNG(aiBrain,home,math.sqrt(army.Total.Land.T1),18,-10,army.Current.Land.T1,armycolors)
            RenderPieRNG(aiBrain,home,math.sqrt(army.Total.Land.T2),18+math.sqrt(army.Total.Land.T1)+math.sqrt(army.Total.Land.T2),-10,army.Current.Land.T2,armycolors)
            RenderPieRNG(aiBrain,home,math.sqrt(army.Total.Land.T3),18+2*math.sqrt(army.Total.Land.T2)+math.sqrt(army.Total.Land.T1)+math.sqrt(army.Total.Land.T3),-10,army.Current.Land.T3,armycolors)
            RenderPieRNG(aiBrain,home,math.sqrt(spendm),-10+math.sqrt(spendm)+math.max(spendm/widthm,totalm/widthm,rawm/widthm),9.05+1.5*widthm,spendcategories,scolors)
            RenderPieRNG(aiBrain,home,math.sqrt(facsum)*3,18-math.sqrt(facsum)*3-1.5*math.sqrt(army.Total.Land.T1),-10,facnum,fcolors)
            RenderPieRNG(aiBrain,home,math.sqrt(fspendsum),18-math.sqrt(fspendsum)-math.sqrt(facsum)*6-1.5*math.sqrt(army.Total.Land.T1),-10,facspendtotals,fcolors)
            RenderBarRNG(aiBrain,home,rawm/widthm,widthm,1,'ff4CFF00')
            RenderBarRNG(aiBrain,home,totalm/widthm,widthm,1+widthm,'ff267F00')
            RenderBarRNG(aiBrain,home,spendm/widthm,widthm,1+2*widthm,'ffFF0000')
            RenderBarRNG(aiBrain,home,-storemaxm/3/widthm,3*widthm,1,'ff267F00')
            RenderBarRNG(aiBrain,home,-storem/3/widthm,3*widthm,1,'ff4CFF00')
            RenderBarRNG(aiBrain,home,rawe/widthe,widthe,1.5+3*widthm,'ffFFFF00')
            RenderBarRNG(aiBrain,home,neede/widthe,widthe,1.5+3*widthm+widthe,'ffFFD800')
            RenderBarRNG(aiBrain,home,spende/widthe,widthe,1.5+3*widthm+2*widthe,'ffFF5900')
            RenderBarRNG(aiBrain,home,-storemaxe/3/widthe,3*widthe,1.5+3*widthm,'ffFFD800')
            RenderBarRNG(aiBrain,home,-storee/3/widthe,3*widthe,1.5+3*widthm,'ffFFFF00')
            if aiBrain.cmanager.soonmexes and not true then
                for _,v in aiBrain.cmanager.soonmexes do
                    DrawLinePop(home,v.Position,'a80000FF')
                end
            end
            WaitTicks(2)
        end
    end
end
RenderBarRNG = function(aiBrain,pos,value,width,offset,color)
    local shiftpos={pos[1]-10,pos[2],pos[3]+8.05+offset}
    local blc={shiftpos[1],shiftpos[2],shiftpos[3]+width-0.1}
    local brc={shiftpos[1]+value-0.1,shiftpos[2],shiftpos[3]+width-0.1}
    local trc={shiftpos[1]+value-0.1,shiftpos[2],shiftpos[3]}
    DrawLine(shiftpos,blc,color)
    DrawLine(blc,brc,color)
    DrawLine(brc,trc,color)
    DrawLine(trc,shiftpos,color)
end
RenderChartRNG = function(aiBrain,pos,valuetable,width,offset,colortable)
    local sum=0
    local currentoffset=0
    for _,v in valuetable do
        sum=sum+v
    end
    local color='ffFFFFFF'
    RenderBarRNG(aiBrain,pos,sum,width,offset,color)
    for i,v in valuetable do
        local newpos={pos[1]+currentoffset,pos[2],pos[3]}
        RenderBarRNG(aiBrain,newpos,v,width,offset,colortable[i])
        currentoffset=currentoffset+v
    end
end
RenderSliceRNG = function(aiBrain,center,radius,angle1,anglewidth,color)
    local posi={center[1]+radius*math.cos(angle1),center[2],center[3]+radius*math.sin(angle1)}
    local posf={center[1]+radius*math.cos(angle1+anglewidth),center[2],center[3]+radius*math.sin(angle1+anglewidth)}
    DrawLine(center,posi,color)
    DrawLine(center,posf,color)
    local pos1={center[1]+radius*math.cos(angle1+anglewidth*1/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*1/7)}
    local pos2={center[1]+radius*math.cos(angle1+anglewidth*2/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*2/7)}
    local pos3={center[1]+radius*math.cos(angle1+anglewidth*3/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*3/7)}
    local pos4={center[1]+radius*math.cos(angle1+anglewidth*4/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*4/7)}
    local pos5={center[1]+radius*math.cos(angle1+anglewidth*5/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*5/7)}
    local pos6={center[1]+radius*math.cos(angle1+anglewidth*6/7),center[2],center[3]+radius*math.sin(angle1+anglewidth*6/7)}
    DrawLine(posi,pos1,color)
    DrawLine(pos1,pos2,color)
    DrawLine(pos2,pos3,color)
    DrawLine(pos3,pos4,color)
    DrawLine(pos4,pos5,color)
    DrawLine(pos5,pos6,color)
    DrawLine(pos6,posf,color)
end
RenderPieRNG = function(aiBrain,pos,radius,offsetx,offsetz,valuetable,colortable)
    local sum=0
    local currentoffset=0
    local center={pos[1]+offsetx,pos[2],pos[3]+offsetz}
    for _,v in valuetable do
        sum=sum+v
    end
    for i,v in valuetable do
        local degreeslice=2*math.pi*v/sum
        RenderSliceRNG(aiBrain,center,radius,currentoffset+0.01,degreeslice-0.01,colortable[i])
        currentoffset=currentoffset+degreeslice
    end
end
GrabMarkerThreatsRNG = function(aiBrain,marker)
    local brainThreats = {}
    local allyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,marker.Position,marker.relevance,'Ally')
    local enemyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,marker.Position,marker.relevance,'Enemy')
    for i,v in ArmyBrains do
        brainThreats[i]=0
    end
    for _,v in allyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats[index] = brainThreats[index] + bp.EconomyThreatLevel/20 + bp.SurfaceThreatLevel
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats[index] = brainThreats[index] + bp.EconomyThreatLevel/20 + bp.SurfaceThreatLevel
            end
        end
    end
    return brainThreats
end
GrabMarkerEconRNG = function(aiBrain,marker)
    local brainThreats = {ally=0,enemy=0}
    local allyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,marker.Position,marker.relevance,'Ally')
    local enemyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,marker.Position,marker.relevance,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.EconomyThreatLevel/100
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.EconomyThreatLevel/100
            end
        end
    end
    return brainThreats
end
GrabMarkerDangerRNG = function(aiBrain,marker)
    local brainThreats = {ally=0,enemy=0}
    local allyunits=aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE+categories.INDIRECTFIRE,marker.Position,marker.relevance*2,'Ally')
    local enemyunits=aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE+categories.INDIRECTFIRE,marker.Position,marker.relevance*2,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.SurfaceThreatLevel
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.SurfaceThreatLevel
            end
        end
    end
    return brainThreats
end
GrabPosDangerRNG = function(aiBrain,pos,radius)
    local function GetWeightedHealthRatio(unit)
        if unit.MyShield then
            return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
        else
            return unit:GetHealthPercent()
        end
    end
    local brainThreats = {ally=0,enemy=0}
    local allyunits=aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Ally')
    local enemyunits=aiBrain:GetUnitsAroundPoint(categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    return brainThreats
end
GrabPosEconRNG = function(aiBrain,pos,radius)
    local brainThreats = {ally=0,enemy=0}
    if not aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,pos,radius,'Ally') then return brainThreats end
    local allyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,pos,radius,'Ally')
    local enemyunits=aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.EconomyThreatLevel
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --LOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --LOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --LOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.EconomyThreatLevel
            end
        end
    end
    return brainThreats
end
ExpansionDangerCheckRNG = function(aiBrain)
    WaitTicks(600)
    while aiBrain.Result ~= "defeat" do
        --LOG('expansion danger check cycle')
        if not aiBrain.teamBases or not aiBrain.emptyBases or not aiBrain.enemyBases then
            WaitTicks(20) 
            continue 
        end
        if aiBrain.teamBases and aiBrain.teamBase>0 then
            for _,v in aiBrain.teamBases do
                local danger=aiBrain:GrabMarkerDangerRNG(v)
                v.dangerlevel=danger.enemy
                local econ = aiBrain:GrabMarkerEconRNG(v)
                v.econlevel=econ.ally
            end
        end
        if aiBrain.enemyBases and aiBrain.enemyBase>0 then
            for _,v in aiBrain.enemyBases do
                local danger=aiBrain:GrabMarkerDangerRNG(v)
                v.dangerlevel=danger.enemy-danger.ally/2
                local econ = aiBrain:GrabMarkerEconRNG(v)
                v.econlevel=econ.enemy
            end
        end
        if aiBrain.emptyBases and aiBrain.emptyBase>0 then
            for _,v in aiBrain.emptyBases do
                local danger=aiBrain:GrabMarkerDangerRNG(v)
                v.dangerlevel=danger.enemy-danger.ally/3
                v.econlevel=nil
            end
        end
        for i=0,3 do
            for i=0,10 do
                for _,v in aiBrain.teamBases do
                    if aiBrain.teamBases and aiBrain.teamBase>0 then
                        if v.dangerlevel>0 then
                            DrawCircle(v.Position,v.relevance-2,'ffFF6060')
                            DrawCircle(v.Position,v.relevance+2,'ffFF6060')
                        end
                    end
                end
                if aiBrain.enemyBases and aiBrain.enemyBase>0 then
                    for _,v in aiBrain.enemyBases do
                        if v.dangerlevel<0 then
                            DrawCircle(v.Position,v.relevance-2,'ff00C7FF')
                            DrawCircle(v.Position,v.relevance+2,'ff00C7FF')
                        end
                    end
                end
                if aiBrain.EmptyBases and aiBrain.emptyBase>0 then
                    for _,v in aiBrain.emptyBases do
                        if v.dangerlevel>0 then
                            DrawCircle(v.Position,v.relevance-2,'ffFF9D00')
                            DrawCircle(v.Position,v.relevance+2,'ffFF9D00')
                        end
                    end
                end
                WaitTicks(2)
            end
            WaitTicks(20)
        end
        WaitTicks(10)
    end
end
CountSoonMassSpotsRNG = function(aiBrain)
    local enemies={}
    for i,v in ArmyBrains do
        if ArmyIsCivilian(v:GetArmyIndex()) or not IsEnemy(aiBrain:GetArmyIndex(),v:GetArmyIndex()) or v.Result=="defeat" then continue end
        local index = v:GetArmyIndex()
        local astartX, astartZ = v:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, GetTerrainHeight(astartX, astartZ), astartZ},army=i,brain=v}
        table.insert(enemies,aiBrainstart)
    end
    local startX, startZ = aiBrain:GetArmyStartPos()
    table.sort(enemies,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX,startZ)<VDist2Sq(b.Position[1],b.Position[3],startX,startZ) end)
    while not aiBrain.cmanager do WaitTicks(2) end
    if not aiBrain.expansionMex or not aiBrain.expansionMex[1].priority then
        --initialize expansion priority
        local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
        local Expands = AIUtils.AIGetMarkerLocations(aiBrain, 'Expansion Area')
        local BigExpands = AIUtils.AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
        if not aiBrain.emanager then aiBrain.emanager={} end
        aiBrain.emanager.expands = {}
        aiBrain.emanager.enemies=enemies
        aiBrain.emanager.enemy=enemies[1]
        for _, v in Expands do
            v.expandtype='expand'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        for _, v in BigExpands do
            v.expandtype='bigexpand'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        for _, v in starts do
            v.expandtype='start'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        local markers = ScenarioUtils.GetMarkers()
        aiBrain.expansionMex={}
        local expands={}
        if markers then
            for k, v in markers do
                if v.type == 'Mass' then
                    table.sort(aiBrain.emanager.expands,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],v.position[1],v.position[3])<VDist2Sq(b.Position[1],b.Position[3],v.position[1],v.position[3]) end)
                    if VDist3Sq(aiBrain.emanager.expands[1].Position,v.position)<25*25 then
                        table.insert(aiBrain.emanager.expands[1].mextable,{v,Position = v.position, Name = k})
                        aiBrain.emanager.expands[1].mexnum=aiBrain.emanager.expands[1].mexnum+1
                        table.insert(aiBrain.expansionMex, {v,Position = v.position, Name = k,ExpandMex=true})
                    else
                        table.insert(aiBrain.expansionMex, {v,Position = v.position, Name = k})
                    end
                end
            end
        end
        for _,v in aiBrain.expansionMex do
            table.sort(aiBrain.emanager.expands,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],v.Position[1],v.Position[3])<VDist2Sq(b.Position[1],b.Position[3],v.Position[1],v.Position[3]) end)
            v.distsq=VDist2Sq(aiBrain.emanager.expands[1].Position[1],aiBrain.emanager.expands[1].Position[2],v.Position[1],v.Position[3])
            if v.ExpandMex then
                v.priority=aiBrain.emanager.expands[1].mexnum
                v.expand=aiBrain.emanager.expands[1]
                v.expand.taken=0
                v.expand.takentime=0
            else
                v.priority=1
            end
        end
    end
    aiBrain.cmanager.unclaimedmexcount=0
    local massmarkers={}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                table.insert(massmarkers,v)
            end
        end
    while aiBrain.Result ~= "defeat" do
        local markercache=table.copy(massmarkers)
        local soonmexes={}
        for _=0,10 do
            local unclaimedmexcount=0
            for i,v in markercache do
                if not aiBrain:CanBuildStructureAt('ueb1103', v.position) then 
                    table.remove(markercache,i) 
                    continue 
                end
                if aiBrain:GetNumUnitsAroundPoint(categories.MASSEXTRACTION + categories.ENGINEER, v.position, 50*ScenarioInfo.size[1]/256, 'Ally')>0 then
                    unclaimedmexcount=unclaimedmexcount+1
                    table.insert(soonmexes,{Position = v.position, Name = i})
                end
            end
            aiBrain.cmanager.unclaimedmexcount=(aiBrain.cmanager.unclaimedmexcount+unclaimedmexcount)/2
            aiBrain.emanager.soonmexes=soonmexes
            --LOG(repr(aiBrain.Nickname)..' unclaimedmex='..repr(aiBrain.cmanager.unclaimedmexcount))
            WaitTicks(20)
        end
    end
end
GetAvgSpendPerFactoryTypeRNG = function(aiBrain)
    aiBrain.fmanager={spend={Land={T1=0,T2=0,T3=0,total=0,},Air={T1=0,T2=0,T3=0,total=0},Naval={T1=0,T2=0,T3=0,total=0}},uspend={Land=0,Air=0,Naval=0}}
    while aiBrain.Result ~= "defeat" do
        local fmanager={spend={Land={T1=0,T2=0,T3=0,total=0},Air={T1=0,T2=0,T3=0,total=0},Naval={T1=0,T2=0,T3=0,total=0}},uspend={Land=0,Air=0,Naval=0}}
        local fcount={Land={T1=0,T2=0,T3=0,total=0},Air={T1=0,T2=0,T3=0,total=0},Naval={T1=0,T2=0,T3=0,total=0}}
        local ucount={Land=0,Air=0,Naval=0}
        local factories=aiBrain:GetListOfUnits(categories.FACTORY * categories.STRUCTURE,false,false)
        for _,unit in factories do
            if unit:IsIdleState() then continue end
            local spendm=GetConsumptionPerSecondMass(unit)
            if spendm==0 then continue end
            if EntityCategoryContains(categories.LAND,unit) then
                fmanager.spend.Land.total=fmanager.spend.Land.total+spendm
                fcount.Land.total=fcount.Land.total+1
                if unit:IsUnitState('Upgrading') then
                    fmanager.uspend.Land=fmanager.uspend.Land+spendm
                    ucount.Land=ucount.Land+1
                end
                if EntityCategoryContains(categories.TECH1,unit) then
                    fcount.Land.T1=fcount.Land.T1+1
                    fmanager.spend.Land.T1=fmanager.spend.Land.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    fcount.Land.T1=fcount.Land.T2+1
                    fmanager.spend.Land.T2=fmanager.spend.Land.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    fcount.Land.T1=fcount.Land.T3+1
                    fmanager.spend.Land.T3=fmanager.spend.Land.T3+spendm
                end
            elseif EntityCategoryContains(categories.AIR,unit) then
                fmanager.spend.Air.total=fmanager.spend.Air.total+spendm
                fcount.Air.total=fcount.Air.total+1
                if unit:IsUnitState('Upgrading') then
                    fmanager.uspend.Air=fmanager.uspend.Air+spendm
                    ucount.Air=ucount.Air+1
                end
                if EntityCategoryContains(categories.TECH1,unit) then
                    fcount.Land.T1=fcount.Air.T1+1
                    fmanager.spend.Air.T1=fmanager.spend.Air.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    fcount.Land.T1=fcount.Air.T2+1
                    fmanager.spend.Air.T2=fmanager.spend.Air.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    fcount.Land.T1=fcount.Air.T3+1
                    fmanager.spend.Air.T3=fmanager.spend.Air.T3+spendm
                end
            elseif EntityCategoryContains(categories.NAVAL,unit) then
                fmanager.spend.Naval.total=fmanager.spend.Naval.total+spendm
                fcount.Naval.total=fcount.Naval.total+1
                if unit:IsUnitState('Upgrading') then
                    fmanager.uspend.Naval=fmanager.uspend.Naval+spendm
                    ucount.Naval=ucount.Naval+1
                end
                if EntityCategoryContains(categories.TECH1,unit) then
                    fcount.Land.T1=fcount.Naval.T1+1
                    fmanager.spend.Naval.T1=fmanager.spend.Naval.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    fcount.Land.T1=fcount.Naval.T2+1
                    fmanager.spend.Naval.T2=fmanager.spend.Naval.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    fcount.Land.T1=fcount.Naval.T3+1
                    fmanager.spend.Naval.T3=fmanager.spend.Naval.T3+spendm
                end
            end
        end
        for i,x in fmanager.spend do
            for j,v in x do
                if v>0 then
                    aiBrain.fmanager.spend[i][j]=(v/fcount[i][j]+aiBrain.fmanager.spend[i][j])/2
                end
            end
        end
        for i,v in fmanager.uspend do
            if v>0 then
                aiBrain.fmanager.uspend[i]=(v+aiBrain.fmanager.uspend[i])/2
            end
        end
        local factotal=aiBrain.smanager.fac
        local facnum={Land=0,Air=0,Naval=0}
        local facsum=0
        for x,v in factotal do
            for _,i in factotal[x] do
                facsum=facsum+i
                facnum[x]=facnum[x]+i
            end
        end
        local facspendtotals={Land=0,Air=0,Naval=0}
        local fspendsum=0
        for i,v in aiBrain.fmanager.spend do
            if v.total then
                facspendtotals[i]=v.total*facnum[i]
                fspendsum=fspendsum+v.total*facnum[i]
            end
        end
        aiBrain.fmanager.buildpower=facspendtotals
        aiBrain.fmanager.buildpower.total=fspendsum
        WaitTicks(20)
    end
end
GetFutureMassRNG = function(aiBrain)
    while not aiBrain.smanager do
        WaitSeconds(20)
    end
    aiBrain.smanager.mexupgrade={}
    local mexupgrades={}
    while aiBrain.Result ~= "defeat" do
        local mexes=aiBrain:GetListOfUnits(categories.MASSEXTRACTION * categories.STRUCTURE,false,true)
        for _=0,30,2 do
            for i,v in mexes do
                if not v or v.Dead then table.remove(mexes,i) continue end
                if v:IsUnitState('Upgrading') then
                    DrawCircle(v:GetPosition(),4,'FF00FF00')
                end
            end
            WaitTicks(2)
        end
    end
end
function StructureUpgradeThreadRNG(unit, aiBrain, upgradeSpec, bypasseco) 
    local unitBp = unit:GetBlueprint()
    local upgradeID = unitBp.General.UpgradesTo or false
    local upgradebp = false
    local unitType, unitTech = StructureTypeCheck(aiBrain, unitBp)
    if upgradeID then
        upgradebp = aiBrain:GetUnitBlueprint(upgradeID) or false
    end
    if not (upgradeID and upgradebp) then
        unit.UpgradeThread = nil
        unit.UpgradesComplete = true
        return
    end
    local upgradeable = true
    local upgradeIssued = false
    if not bypasseco then
        bypasseco = false
    end
    -- Eco requirements
    local massNeeded = upgradebp.Economy.BuildCostMass
	local energyNeeded = upgradebp.Economy.BuildCostEnergy
    local buildtime = upgradebp.Economy.BuildTime
    -- build rate
    local buildrate = unitBp.Economy.BuildRate
    -- production while upgrading
    local massProduction = unitBp.Economy.ProductionPerSecondMass or 0
    local energyProduction = unitBp.Economy.ProductionPerSecondEnergy or 0
    local massTrendNeeded = ( math.max( 0,(massNeeded / buildtime) * buildrate)) * .1
    local energyTrendNeeded = ( math.max( 0,(energyNeeded / buildtime) * buildrate)) * .1
    local energyMaintenance = (upgradebp.Economy.MaintenanceConsumptionPerSecondEnergy or 10) * .1
    -- Define Economic Data
    local eco = aiBrain.EcoData.OverTime -- mother of god I'm stupid this is another bit of Sprouto genius.
    local massStorage
    local energyStorage
    local massStorageRatio
    local energyStorageRatio
    local massIncome
    local massRequested
    local energyIncome
    local energyRequested
    local massTrend
    local energyTrend
    local massEfficiency
    local energyEfficiency
    local ecoTimeOut
    local upgradeNumLimit
    local extractorUpgradeLimit = 0
    local extractorClosest = false
    local multiplier
    local initial_delay = 0
    local ecoStartTime = GetGameTimeSeconds()
    if aiBrain.CheatEnabled then
        multiplier = tonumber(ScenarioInfo.Options.BuildMult)
    else
        multiplier = 1
    end
    if unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (320 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Aggressive' then
        ecoTimeOut = (650 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Normal' then
        ecoTimeOut = (880 / multiplier)
    elseif unitTech == 'TECH1' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (420 / multiplier)
    elseif unitTech == 'TECH2' and aiBrain.UpgradeMode == 'Caution' then
        ecoTimeOut = (880 / multiplier)
    end
    --LOG('Multiplier is '..multiplier)
    --LOG('Initial Delay is before any multiplier is '..upgradeSpec.InitialDelay)
    --LOG('Initial Delay is '..(upgradeSpec.InitialDelay / multiplier))
    --LOG('Eco timeout for Tech '..unitTech..' Extractor is '..ecoTimeOut)
    --LOG('* AI-RNG: Initial Variables set')
    while initial_delay < (upgradeSpec.InitialDelay / multiplier) do
		if GetEconomyStored( aiBrain, 'MASS') >= 50 and GetEconomyStored( aiBrain, 'ENERGY') >= 700 and unit:GetFractionComplete() == 1 then
            initial_delay = initial_delay + 10
            unit.InitialDelay = true
            if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
                initial_delay = upgradeSpec.InitialDelay
            end
        end
		WaitTicks(100)
    end
    unit.InitialDelay = false
    -- Main Upgrade Loop
    while ((not unit.Dead) or unit.Sync.id) and upgradeable and not upgradeIssued do
        WaitTicks(upgradeSpec.UpgradeCheckWait * 10)
        upgradeSpec = aiBrain:GetUpgradeSpec(unit)
        if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
            bypasseco = true
        end
        if bypasseco and not (GetEconomyStored( aiBrain, 'MASS') > ( massNeeded * 1.8 ) and GetEconomyStored( aiBrain, 'ENERGY') > energyNeeded ) then
            upgradeNumLimit = StructureUpgradeNumDelay(aiBrain, unitType, unitTech)
            if unitTech == 'TECH1' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH1
            elseif unitTech == 'TECH2' then
                extractorUpgradeLimit = aiBrain.EcoManager.ExtractorUpgradeLimit.TECH2
            end
            if upgradeNumLimit >= extractorUpgradeLimit then
                WaitTicks(10)
                continue
            end
        end
        extractorClosest = ExtractorClosest(aiBrain, unit, unitBp)
        if not extractorClosest then
            WaitTicks(10)
            continue
        end
        if (not unit.MAINBASE) or (unit.MAINBASE and not bypasseco) then
            if UnitRatioCheckRNG( aiBrain, 1.7, categories.MASSEXTRACTION * categories.TECH1, '>=', categories.MASSEXTRACTION * categories.TECH2 ) and unitTech == 'TECH2' then
                --LOG('Too few tech2 extractors to go tech3')
                ecoStartTime = ecoStartTime + upgradeSpec.UpgradeCheckWait
                WaitTicks(10)
                continue
            end
        end
        if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
            massStorage = GetEconomyStored( aiBrain, 'MASS')
            energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            massStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS')
            energyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY')
            massIncome = GetEconomyIncome(aiBrain, 'MASS')
            massRequested = GetEconomyRequested(aiBrain, 'MASS')
            energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
            energyRequested = GetEconomyRequested(aiBrain, 'ENERGY')
            massTrend = aiBrain.EconomyOverTimeCurrent.MassTrendOverTime
            energyTrend = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime
            if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= upgradeSpec.MassLowTrigger and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= upgradeSpec.EnergyLowTrigger)
                or ((massStorageRatio > .60 and energyStorageRatio > .40))
                or (massStorage > (massNeeded * .7) and energyStorage > (energyNeeded * .7 ) ) or bypasseco then
            else
                WaitTicks(10)
                continue
            end
            if ( massTrend >= massTrendNeeded and energyTrend >= energyTrendNeeded and energyTrend >= energyMaintenance )
				or ( massStorage >= (massNeeded * .7) and energyStorage > (energyNeeded * .7) ) or bypasseco then
				-- we need to have 15% of the resources stored -- some things like MEX can bypass this last check
				if (massStorage > ( massNeeded * .15 * upgradeSpec.MassLowTrigger) and energyStorage > ( energyNeeded * .15 * upgradeSpec.EnergyLowTrigger)) or bypasseco then
                    if aiBrain.UpgradeIssued < aiBrain.UpgradeIssuedLimit then
						if not unit.Dead then
                            upgradeIssued = true
                            IssueUpgrade({unit}, upgradeID)
                            -- if upgrade issued and not completely full --
                            if massStorageRatio < 1 or energyStorageRatio < 1 then
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod)  -- delay the next upgrade by the full amount
                            else
                                ForkThread(StructureUpgradeDelay, aiBrain, aiBrain.UpgradeIssuedPeriod * .5)     -- otherwise halve the delay period
                            end
                            repeat
                               WaitTicks(50)
                            until unit.Dead or (unit.UnitBeingBuilt:GetBlueprint().BlueprintId == upgradeID) -- Fix this!
                        end
                        if unit.Dead then
                            upgradeIssued = false
                        end
                        if upgradeIssued then
                            WaitTicks(10)
                            continue
                        end
                    end
                end
            end
        end
    end
    if upgradeIssued then
		--LOG('* AI-RNG: upgradeIssued is true')
		unit.Upgrading = true
        unit.DesiresAssist = true
        local unitbeingbuiltbp = false
		local unitbeingbuilt = unit.UnitBeingBuilt
        unitbeingbuiltbp = unitbeingbuilt:GetBlueprint()
        upgradeID = unitbeingbuiltbp.General.UpgradesTo or false
		-- if the upgrade has a follow on upgrade - start an upgrade thread for it --
        if upgradeID and not unitbeingbuilt.Dead then
			upgradeSpec.InitialDelay = upgradeSpec.InitialDelay + 60			-- increase delay before first check for next upgrade
            unitbeingbuilt.DesiresAssist = true			-- let engineers know they can assist this upgrade
			unitbeingbuilt.UpgradeThread = unitbeingbuilt:ForkThread( StructureUpgradeThread, aiBrain, upgradeSpec, bypasseco )
        end
		-- assign mass extractors to their own platoon 
		if (not unitbeingbuilt.Dead) and EntityCategoryContains( categories.MASSEXTRACTION, unitbeingbuilt) then
			local extractorPlatoon = MakePlatoon( aiBrain,'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id), 'none')
			extractorPlatoon.BuilderName = 'ExtractorPlatoon'..tostring(unitbeingbuilt.Sync.id)
            extractorPlatoon.MovementLayer = 'Land'
            --LOG('* AI-RNG: Extractor Platoon name is '..extractorPlatoon.BuilderName)
			AssignUnitsToPlatoon( aiBrain, extractorPlatoon, {unitbeingbuilt}, 'Support', 'none' )
			extractorPlatoon:ForkThread( extractorPlatoon.ExtractorCallForHelpAIRNG, aiBrain )
		elseif (not unitbeingbuilt.Dead) then
            AssignUnitsToPlatoon( aiBrain, aiBrain.StructurePool, {unitbeingbuilt}, 'Support', 'none' )
		end
        unit.UpgradeThread = nil
	end
end
function MexUpgradeManagerRNG(aiBrain)
    aiBrain:ForkThread(DisplayMarkerAdjacency)
    aiBrain:ForkThread(CommandyBoy)
    local homebasex,homebasey = aiBrain:GetArmyStartPos()
    local homepos = {homebasex,GetTerrainHeight(homebasex,homebasey),homebasey}
    local ratio=0.35
    if true then
        return
    end
    while not aiBrain.cmanager.categoryspend or GetGameTimeSeconds()<250 do
        WaitSeconds(10)
    end
    while not aiBrain.defeat do
        local mexes1 = aiBrain:GetListOfUnits(categories.MASSEXTRACTION - categories.TECH3, true, false)
        local time=GetGameTimeSeconds()
        --[[if aiBrain.EcoManagerPowerStateCheck(aiBrain) then
            WaitSeconds(4)
            continue
        end]]
        local currentupgradecost=0
        local mexes={}
        for i,v in mexes1 do
            --if not v.UCost then
            if v:IsUnitState('Upgrading') and v.UCost then currentupgradecost=currentupgradecost+v.UCost table.remove(mexes,i) continue end
            local spende=GetConsumptionPerSecondEnergy(v)
            local producem=GetProductionPerSecondMass(v)
            local unit=v:GetBlueprint()
            if spende<unit.Economy.MaintenanceConsumptionPerSecondEnergy and spende>0 then
                v.UEmult=spende/unit.Economy.MaintenanceConsumptionPerSecondEnergy
            else
                v.UEmult=1
            end
            if producem>unit.Economy.ProductionPerSecondMass then
                v.UMmult=producem/unit.Economy.ProductionPerSecondMass
            else
                v.UMmult=1
            end
            local uunit=aiBrain:GetUnitBlueprint(unit.General.UpgradesTo)
            local mcost=uunit.Economy.BuildCostMass/uunit.Economy.BuildTime*unit.Economy.BuildRate
            local ecost=uunit.Economy.BuildCostEnergy/uunit.Economy.BuildTime*unit.Economy.BuildRate
            v.UCost=mcost
            v.UECost=ecost
            v.TMCost=uunit.Economy.BuildCostMass
            v.Uupgrade=unit.General.UpgradesTo
        --end
            if not v.UAge then
                v.UAge=time
            end
            v.TAge=1/(1+math.min(120,time-v.UAge)/120)
            table.insert(mexes,v)
        end
        --[[if 10>aiBrain.cmanager.income.r.m*ratio then
            WaitSeconds(3)
            continue
        end]]
        if currentupgradecost<aiBrain.cmanager.income.r.m*ratio then
            table.sort(mexes,function(a,b) return (1+VDist3Sq(a:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,a:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*a.UCost*a.TMCost*a.UECost*a.UEmult*a.TAge/a.UMmult/a.UMmult<(1+VDist3Sq(b:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,b:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*b.UCost*b.TMCost*b.UECost*b.UEmult*b.TAge/b.UMmult/b.UMmult end)
            local startval=aiBrain.cmanager.income.r.m*ratio-currentupgradecost
            --local starte=aiBrain.cmanager.income.r.e*1.3-aiBrain.cmanager.spend.e
            for _,v in mexes do
                if startval>0 then
                    IssueUpgrade({v}, v.Uupgrade)
                    startval=startval-v.UCost
                else
                    break
                end
            end
        end
        WaitSeconds(4)
    end
end
function CommandyBoy(aiBrain)
    local commandyboy=aiBrain:GetListOfUnits(categories.COMMAND, false, false)
    local paused=false
    local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
    while not aiBrain.defeat do
        if GetEconomyStoredRatio(aiBrain, 'ENERGY')<0.2 then
            if not paused then
                for _,v in commandyboy do
                    if v:IsUnitState('Enhancing') then
                        v:SetPaused(true)
                        paused=true
                    end
                end
            end
        elseif paused then
            for _,v in commandyboy do
                v:SetPaused(false)
            end
        end
        WaitSeconds(4)
    end
end
function DisplayMarkerAdjacency(aiBrain)
    aiBrain:ForkThread(LastKnownThread)
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    aiBrain.TechAIAreas={}
    aiBrain.renderlines={}
    aiBrain.armyspots={}
    aiBrain.expandspots={}
    aiBrain.rendercircles={}
    for k,marker in expansionMarkers do
        local node=false
        local expand=false
        --LOG(repr(k)..' marker type is '..repr(marker.type))
        for i, v in STR_GetTokens(marker.type,' ') do
            if v=='Node' then
                node=true
                break
            end
            if v=='Expansion' then
                expand=true
                break
            end
        end
        if node and not marker.TechAIArea then
            aiBrain.TechAIAreas[k]={}
            InfectMarkersRNG(aiBrain,marker,k)
        end
        if expand then
            table.insert(aiBrain.expandspots,{marker,k})
        end
        if not node and not expand then
            for _,v in STR_GetTokens(k,'_') do
                if v=='ARMY' then
                    table.insert(aiBrain.armyspots,{marker,k})
                    table.insert(aiBrain.expandspots,{marker,k})
                end
            end
        end
    end
    aiBrain.analysistablecolors={}
    local tablecolors=GenerateDistinctColorTable(table.getn(aiBrain.expandspots))
    local colors=aiBrain.analysistablecolors
    local colorcomponents={
        r={ToColorRNG(0,256,1),ToColorRNG(0,256,1),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0),ToColorRNG(0,256,0)},
        g={ToColorRNG(0,256,1),ToColorRNG(0,256,1),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0),ToColorRNG(0,256,0)},
        b={ToColorRNG(0,256,1),ToColorRNG(0,256,1),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.75),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.5),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.35),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0.25),ToColorRNG(0,256,0),ToColorRNG(0,256,0)},
    }
    WaitSeconds(10)
    LOG('colortable is'..repr(tablecolors))
    local bases=false
    if bases then
        for _,army in aiBrain.armyspots do
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(army[1].position,25,'Land').name]
            LOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoArmySpotDistanceInfect,aiBrain,closestpath,army[2])
            local randy=math.random(table.getn(tablecolors))
            colors[army[2]]='FF'..tablecolors[randy]
            table.remove(tablecolors,randy)
        end
    else
        for i,v in ArmyBrains do
            if ArmyIsCivilian(v:GetArmyIndex()) or v.Result=="defeat" then continue end
            local astartX, astartZ = v:GetArmyStartPos()
            local army = {position={astartX, GetTerrainHeight(astartX, astartZ), astartZ},army=i,brain=v}
            table.sort(aiBrain.expandspots,function(a,b) return VDist3Sq(a[1].position,army.position)<VDist3Sq(b[1].position,army.position) end)
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(aiBrain.expandspots[1][1].position,25,'Land').name]
            LOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoArmySpotDistanceInfect,aiBrain,closestpath,aiBrain.expandspots[1][2])
            local randy=nil
            if i<9 then
                randy=math.random(table.getn(tablecolors)-7+i,table.getn(tablecolors))
            else
                randy=math.random(table.getn(tablecolors))
            end
            colors[aiBrain.expandspots[1][2]]=tablecolors[randy]
            table.remove(tablecolors,randy)
        end
    end
    local expands=true
    local expandcolors={}
    while aiBrain.renderthreadtracker do
        WaitTicks(2)
    end
    if expands then
        --tablecolors=GenerateDistinctColorTable(table.getn(aiBrain.expandspots))
        for _,expand in aiBrain.expandspots do
            local closestpath=Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(expand[1].position,25,'Land').name]
            --LOG('closestpath is '..repr(closestpath))
            aiBrain.renderthreadtracker=ForkThread(DoExpandSpotDistanceInfect,aiBrain,closestpath,expand[2])
            local randy=math.random(table.getn(tablecolors))
            if colors[expand[2]] then continue end
            colors[expand[2]]=tablecolors[randy]
            table.remove(tablecolors,randy)
        end
    end
    --local markercontinue=true
    --[[while markercontinue do
        markercontinue=false
        for _,marker in expansionMarkers do
            if DoArmySpotStaggeredInfect(aiBrain,marker) then
                markercontinue=true
            end
        end
        for _,v in aiBrain.renderlines do
            if v[3]=='Land Path Node' then
                DrawLine(v[1],v[2],'FFBF9C1E')
            elseif v[3]=='Water Path Node' then
                DrawLine(v[1],v[2],'FF7100FF')
            end
        end
        WaitTicks(2)
    end]]
    --[[for _,marker in expansionMarkers do
        if marker.armydists then
            local bestdist=999999
            local bestarmy=nil
            for k,v in marker.armydists do
                if v<bestdist then
                    bestdist=v
                    bestarmy=k
                end
            end
            if bestarmy then
                marker.closestarmy=bestarmy
                --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[bestarmy].position,marker.type})
            end
        end
    end]]
    while aiBrain.renderthreadtracker do
        WaitTicks(2)
    end
    local bestarmynum=0
    for k,marker in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if marker.bestarmy then
            local first=nil
            local firstd=nil
            local second=nil
            local secondd=nil
            for x,v in marker.armydists do
                if not first or v<firstd then
                    if first then
                        second=first
                        secondd=firstd
                    end
                    first=k
                    firstd=v
                elseif (not second or v<secondd) then
                    second=k
                    secondd=v
                end
            end
            if secondd and math.abs(firstd-secondd)<0.15*(secondd) then
                LOG('border point found- distances are '..repr(firstd)..' and '..repr(secondd))
                table.insert(aiBrain.rendercircles,marker.position)
                --marker.bestarmy=nil
            end
        end
    end
    local iter=0
    for k,marker in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if marker.bestarmy then
            local surround=0
            local border=false
            for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
                local adjnode=nil
                if Scenario.MasterChain._MASTERCHAIN_.Markers[node] then
                    adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
                else
                    continue
                end
                if not adjnode.bestarmy or adjnode.bestarmy~=marker.bestarmy then
                    border=true
                else
                    surround=surround+1
                end
            end
            local function midpoint(vec1,vec2,ratio)
                local vec3={}
                for z,v in vec1 do
                    if type(v)=='number' then 
                        vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                    end
                end
                return vec3
            end
            local function crossp(vec1,vec2,n)
                local z = vec2[3] + n * (vec2[1] - vec1[1])
                local y = vec2[2] - n * (vec2[2] - vec1[2])
                local x = vec2[1] - n * (vec2[3] - vec1[3])
                return {x,y,z}
            end
            bestarmynum=bestarmynum+1
            if not marker.renderlined then marker.renderlined={} end
            local priority=nil
            if border or surround<=3 then
                priority=true
            end
            for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
                local adjnode=nil
                if Scenario.MasterChain._MASTERCHAIN_.Markers[node] then
                    adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
                else
                    continue
                end
                local tempdist=VDist3(marker.position,adjnode.position)
                if adjnode.bestarmy==marker.bestarmy then
                    if not adjnode.renderlined then adjnode.renderlined={} end
                    --surround=surround+1
                    if not adjnode.renderlined[k] and not marker.renderlined[node] then
                        adjnode.renderlined[k]=true
                        marker.renderlined[node]=true
                        local p1={crossp(marker.position,adjnode.position,1/tempdist),crossp(adjnode.position,marker.position,1/tempdist)}
                        local p2={crossp(marker.position,adjnode.position,-1/tempdist),crossp(adjnode.position,marker.position,-1/tempdist)}
                        table.insert(aiBrain.renderlines,{p1[1],p1[2],marker.type,marker.bestarmy,priority})
                        table.insert(aiBrain.renderlines,{p2[1],p2[2],marker.type,marker.bestarmy,priority})
                    end
                end
                if not adjnode.bestarmy or adjnode.bestarmy~=marker.bestarmy then
                    table.insert(aiBrain.renderlines,{crossp(marker.position,midpoint(marker.position,adjnode.position,(tempdist+5)/tempdist/2),10/tempdist),crossp(marker.position,midpoint(marker.position,adjnode.position,(tempdist+5)/tempdist/2),-10/tempdist),marker.type,marker.bestarmy,false})
                    --border=true
                end
            end
            --if border or surround<=3 then
            --table.insert(aiBrain.rendercircles,marker.position)
            --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[marker.closestarmy].position,marker.type})
            iter=iter+1
        end
        if marker.bestexpand then
            local surround=0
            local border=false
            for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
                local adjnode=nil
                if Scenario.MasterChain._MASTERCHAIN_.Markers[node] then
                    adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
                else
                    continue
                end
                if not adjnode.bestexpand or adjnode.bestexpand~=marker.bestexpand then
                    border=true
                else
                    surround=surround+1
                end
            end
            local function midpoint(vec1,vec2,ratio)
                local vec3={}
                for z,v in vec1 do
                    if type(v)=='number' then 
                        vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                    end
                end
                return vec3
            end
            local function crossp(vec1,vec2,n)
                local z = vec2[3] + n * (vec2[1] - vec1[1])
                local y = vec2[2] - n * (vec2[2] - vec1[2])
                local x = vec2[1] - n * (vec2[3] - vec1[3])
                return {x,y,z}
            end
            if not marker.expandrenderlined then marker.expandrenderlined={} end
            local priority=nil
            if border or surround<=3 then
                priority=true
            end
            for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
                local adjnode=nil
                if Scenario.MasterChain._MASTERCHAIN_.Markers[node] then
                    adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
                else
                    continue
                end
                local tempdist=VDist3(marker.position,adjnode.position)
                if adjnode.bestexpand==marker.bestexpand then
                    if not adjnode.expandrenderlined then adjnode.expandrenderlined={} end
                    surround=surround+1
                    if not adjnode.expandrenderlined[k] and not marker.expandrenderlined[node] then
                        adjnode.expandrenderlined[k]=true
                        marker.expandrenderlined[node]=true
                        table.insert(aiBrain.renderlines,{marker.position,adjnode.position,marker.type,marker.bestexpand,priority})
                    end
                end
                if not adjnode.bestexpand or adjnode.bestexpand~=marker.bestexpand then
                    table.insert(aiBrain.renderlines,{crossp(marker.position,midpoint(marker.position,adjnode.position,(tempdist+3)/tempdist/2),10/tempdist),crossp(marker.position,midpoint(marker.position,adjnode.position,(tempdist+3)/tempdist/2),-10/tempdist),marker.type,marker.bestexpand,true})
                    border=true
                end
            end
            iter=iter+2
        end
        if iter>20 then 
            --WaitTicks(1)
            iter=0
        end
    end
    LOG('RNGAreas:')
    for k,v in aiBrain.TechAIAreas do
        LOG(repr(k)..' has '..repr(table.getn(v))..' nodes')
    end
    --[[
    LOG('renderlines has '..table.getn(aiBrain.renderlines))
    LOG('bestarmy has '..repr(bestarmynum))
    --LOG('renderlines are '..repr(aiBrain.renderlines))
    while not aiBrain.defeat do
        for _,v in aiBrain.rendercircles do
            DrawCircle(v,5,'FFBF9C1E')
        end
        for _,v in aiBrain.renderlines do
            if v[4] then
                local prefix='33'
                if v[5] then
                    prefix='aa'
                end
                DrawLine(v[1],v[2],prefix..colors[(v[4])])
            else
                if v[3]=='Land Path Node' then
                    DrawLine(v[1],v[2],'FFBF9C1E')
                elseif v[3]=='Water Path Node' then
                    DrawLine(v[1],v[2],'FF7100FF')
                end
            end
        end
        WaitTicks(2)
    end
    --]]
end
function InfectMarkersRNG(aiBrain,marker,graphname)
    marker.TechAIArea=graphname
    table.insert(aiBrain.TechAIAreas[graphname],marker)
    for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
        if not Scenario.MasterChain._MASTERCHAIN_.Markers[node].TechAIArea then
            InfectMarkersRNG(aiBrain,Scenario.MasterChain._MASTERCHAIN_.Markers[node],graphname)
        end
    end
end
function DoArmySpotDistanceInfect(aiBrain,marker,army)
    aiBrain.renderthreadtracker=CurrentThread()
    WaitTicks(1)
    DrawCircle(marker.position,5,'FF'..aiBrain.analysistablecolors[army])
    if not marker.armydists then
        marker.armydists={}
    end
    if not marker.armydists[army] then
        marker.armydists[army]=0
    end
    local potentialdists={}
    for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
        if node=='' then continue end
        local adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
        local skip=false
        local bestdist=nil
        local adjdist=VDist3(marker.position,adjnode.position)
        if adjnode.armydists then
            for k,v in adjnode.armydists do
                --[[if not bestdist or v<bestdist then
                    bestdist=v
                end
                if k~=army and v<marker.armydists[army] then
                    skip=true
                end]]
                if not potentialdists[k] or potentialdists[k]>v then
                    potentialdists[k]=v+adjdist
                end
            end
        end
        if not adjnode.armydists then adjnode.armydists={} end
        if not adjnode.armydists[army] then
            adjnode.armydists[army]=adjdist+marker.armydists[army]
            
            --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[node].position,marker.type,army})
            ForkThread(DoArmySpotDistanceInfect,aiBrain,adjnode,army)
        elseif adjnode.armydists[army]>adjdist+marker.armydists[army] then
            adjnode.armydists[army]=adjdist+marker.armydists[army]
            adjnode.bestarmy=army
            ForkThread(DoArmySpotDistanceInfect,aiBrain,adjnode,army)
        end
    end
    for k,v in marker.armydists do
        if potentialdists[k]<v then
            v=potentialdists[k]
        end
    end
    for k,v in marker.armydists do
        if not marker.bestarmy or marker.armydists[marker.bestarmy]>v then
            marker.bestarmy=k
        end
    end
    WaitTicks(1)
    if aiBrain.renderthreadtracker==CurrentThread() then
        aiBrain.renderthreadtracker=nil
    end
end
function DoExpandSpotDistanceInfect(aiBrain,marker,expand)
    aiBrain.renderthreadtracker=CurrentThread()
    WaitTicks(1)
    DrawCircle(marker.position,4,'FF'..aiBrain.analysistablecolors[expand])
    if not marker.expanddists then
        marker.expanddists={}
    end
    if not marker.expanddists[expand] then
        marker.expanddists[expand]=0
    end
    local potentialdists={}
    for i, node in STR_GetTokens(marker.adjacentTo or '', ' ') do
        if node=='' then continue end
        local adjnode=Scenario.MasterChain._MASTERCHAIN_.Markers[node]
        local skip=false
        local bestdist=nil
        local adjdist=VDist3(marker.position,adjnode.position)
        if adjnode.expanddists then
            for k,v in adjnode.expanddists do
                --[[if not bestdist or v<bestdist then
                    bestdist=v
                end
                if k~=expand and v<marker.expanddists[expand] then
                    skip=true
                end]]
                if not potentialdists[k] or potentialdists[k]>v then
                    potentialdists[k]=v+adjdist
                end
            end
        end
        if not adjnode.expanddists then adjnode.expanddists={} end
        if not adjnode.expanddists[expand] then
            adjnode.expanddists[expand]=adjdist+marker.expanddists[expand]
            --table.insert(aiBrain.renderlines,{marker.position,Scenario.MasterChain._MASTERCHAIN_.Markers[node].position,marker.type,expand})
            ForkThread(DoExpandSpotDistanceInfect,aiBrain,adjnode,expand)
        elseif adjnode.expanddists[expand]>adjdist+marker.expanddists[expand] then
            adjnode.expanddists[expand]=adjdist+marker.expanddists[expand]
            adjnode.bestexpand=expand
            ForkThread(DoExpandSpotDistanceInfect,aiBrain,adjnode,expand)
        end
    end
    for k,v in marker.expanddists do
        if potentialdists[k]<v then
            v=potentialdists[k]
        end
    end
    for k,v in marker.expanddists do
        if not marker.bestexpand or marker.expanddists[marker.bestexpand]>v then
            marker.bestexpand=k
        end
    end
    WaitTicks(1)
    if aiBrain.renderthreadtracker==CurrentThread() then
        aiBrain.renderthreadtracker=nil
    end
end
function CanGraphToRNGArea(unit, destPos, layer)
    local position = unit:GetPosition()
    local startNode = Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(position,30,layer).name]
    local endNode = false

    if startNode then
        endNode = Scenario.MasterChain._MASTERCHAIN_.Markers[AIAttackUtils.GetClosestPathNodeInRadiusByLayer(destPos,30,layer).name]
    end

    if endNode.TechAIArea==startNode.TechAIArea then
        return true, endNode.position
    end
end
LastKnownThread = function(aiBrain)
    aiBrain.lastknown={}
    aiBrain:ForkThread(ShowLastKnown)
    aiBrain:ForkThread(TruePlatoonPriorityDirector)
    while not aiBrain.emanager.enemies do WaitSeconds(2) end
    while aiBrain.Result ~= "defeat" do
        local time=GetGameTimeSeconds()
        for _=0,10 do
            local eunits=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, {0,0,0}, math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])*1.5, 'Enemy')
            for _,v in eunits do
                if not v or v.Dead then continue end
                local id=v.Sync.id
                if not aiBrain.lastknown[id] or time-aiBrain.lastknown[id].time>10 then
                    if not aiBrain.lastknown[id] then
                        aiBrain.lastknown[id]={}
                        if EntityCategoryContains(categories.MOBILE,v) then
                            if EntityCategoryContains(categories.ENGINEER-categories.COMMAND,v) then
                                aiBrain.lastknown[id].type='eng'
                            elseif EntityCategoryContains(categories.COMMAND,v) then
                                aiBrain.lastknown[id].type='acu'
                            elseif EntityCategoryContains(categories.ANTIAIR,v) then
                                aiBrain.lastknown[id].type='aa'
                            elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                                aiBrain.lastknown[id].type='tank'
                            elseif EntityCategoryContains(categories.INDIRECTFIRE,v) then
                                aiBrain.lastknown[id].type='arty'
                            end
                        elseif EntityCategoryContains(categories.MASSEXTRACTION,v) then
                            aiBrain.lastknown[id].type='mex'
                        elseif EntityCategoryContains(categories.RADAR,v) then
                            aiBrain.lastknown[id].type='radar'
                        end
                    end
                    aiBrain.lastknown[id].object=v
                    aiBrain.lastknown[id].Position=table.copy(v:GetPosition())
                    aiBrain.lastknown[id].time=time
                    aiBrain.lastknown[id].recent=true
                end
            end
            WaitSeconds(2)
            time=GetGameTimeSeconds()
        end
        for i,v in aiBrain.lastknown do
            if (v.object and v.object.Dead) then
                aiBrain.lastknown[i]=nil
            elseif time-v.time>120 or (v.object and v.object.Dead) or (time-v.time>15 and GetNumUnitsAroundPoint(aiBrain,categories.MOBILE,v.Position,20,'Ally')>3) then
                aiBrain.lastknown[i].recent=false
            end
        end
    end
end
ToColorRNG = function(min,max,ratio)
    local ToBase16 = function(num)
        if num<10 then
            return tostring(num)
        elseif num==10 then
            return 'a'
        elseif num==11 then
            return 'b'
        elseif num==12 then
            return 'c'
        elseif num==13 then
            return 'd'
        elseif num==14 then
            return 'e'
        else
            return 'f'
        end
    end
    local baseones=0
    local basetwos=0
    local numinit=math.abs(math.ceil((max-min)*ratio+min))
    basetwos=math.floor(numinit/16)
    baseones=numinit-basetwos*16
    return ToBase16(basetwos)..ToBase16(baseones)
end
GenerateDistinctColorTable = function(num)
    local function factorial(n,min)
        if n>min and n>1 then
            return n*factorial(n-1)
        else
            return n
        end
    end
    local function combintoid(a,b,c)
        local o=tostring(0)
        local tab={a,b,c}
        local tabid={}
        for k,v in tab do
            local n=v
            tabid[k]=tostring(v)
            while n<1000 do
                n=n*10
                tabid[k]=o..tabid[k]
            end
        end
        return tabid[1]..tabid[2]..tabid[3]
    end
    local i=0
    local n=1
    while i<num do
        n=n+1
        i=n*n*n-n
    end
    local ViableValues={}
    for x=0,256,256/(n-1) do
        table.insert(ViableValues,ToColorRNG(0,256,x/256))
    end
    local colortable={}
    local combinations={}
    --[[for k,v in ViableValues do
        table.insert(colortable,v..v..v)
        combinations[combintoid(k,k,k)]=1
    end]]
    local max=ViableValues[table.getn(ViableValues)]
    local min=ViableValues[1]
    local primaries={min..min..min,max..max..min,max..min..max,min..max..max,max..min..min,min..max..min,min..min..max,max..max..max}
    combinations[combintoid(max,max,min)]=1
    combinations[combintoid(max,min,max)]=1
    combinations[combintoid(min,max,max)]=1
    combinations[combintoid(max,min,min)]=1
    combinations[combintoid(min,max,min)]=1
    combinations[combintoid(min,min,max)]=1
    combinations[combintoid(max,max,max)]=1
    combinations[combintoid(min,min,min)]=1
    for a,d in ViableValues do
        for b,e in ViableValues do
            for c,f in ViableValues do
                if not combinations[combintoid(a,b,c)] and not (a==b and b==c) then
                    table.insert(colortable,d..e..f)
                    combinations[combintoid(a,b,c)]=1
                end
            end
        end
    end
    for _,v in primaries do
        table.insert(colortable,v)
    end
    return colortable
end
GrabRandomDistinctColor = function(num)
    local output=GenerateDistinctColorTable(num)
    return output[math.random(table.getn(output))]
end
ShowLastKnown = function(aiBrain)
    if ScenarioInfo.Options.AIDebugDisplay ~= 'displayOn' then
        return
    end
    while not aiBrain.lastknown do
        WaitTicks(2)
    end
    while aiBrain.result ~= "defeat" do
        local time=GetGameTimeSeconds()
        local lastknown=table.copy(aiBrain.lastknown)
        for _,v in lastknown do
            if v.recent then
                local ratio=(1-(time-v.time)/120)*(1-(time-v.time)/120)
                local ratio2=(1-(time-v.time)/120)
                local color=ToColorRNG(10,255,ratio2)
                local color1=ToColorRNG(10,255,ratio)
                local color2=ToColorRNG(10,100,math.random())
                local color3=ToColorRNG(10,100,math.random())
                DrawCircle(v.Position,3,color..color1..color2..color3)
            else
                DrawCircle(v.Position,2,ToColorRNG(120,200,math.random())..ToColorRNG(50,255,math.random())..ToColorRNG(50,255,math.random())..ToColorRNG(50,255,math.random()))
            end
        end
        WaitTicks(2)
    end
end
TruePlatoonPriorityDirector = function(aiBrain)
    aiBrain.prioritypoints={}
    while not aiBrain.lastknown do WaitSeconds(2) end
    while aiBrain.Result ~= "defeat" do
        aiBrain.prioritypoints={}
        for _=0,5 do
            for k,v in aiBrain.lastknown do
                if not v.recent or aiBrain.prioritypoints[k] then continue end
                local priority=0
                if v.type then
                    if v.type=='eng' then
                        priority=30
                    elseif v.type=='mex' then
                        priority=20
                    elseif v.type=='radar' then
                        priority=100
                    else
                        priority=10
                    end
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=GrabPosDangerRNG(aiBrain,v.Position,30).enemy,unit=v.object}
                end
            end
            WaitTicks(10)
        end
    end
end
RenderBrainIntelRNG = function(aiBrain)
    while not aiBrain.BrainIntel.ExpansionWatchTable do WaitSeconds(2) end
    while aiBrain.Result ~= "defeat" do
        for _,expansion in aiBrain.BrainIntel.ExpansionWatchTable do
            if expansion.Position then
                DrawCircle(expansion.Position,expansion.Commander,'FF9999FF')
                DrawCircle(expansion.Position,expansion.Land,'FF99FF99')
                DrawCircle(expansion.Position,expansion.Structure,'FF999999')
            end
        end
        WaitTicks(2)
    end
end
RenderBuildQueue = function(eng)
    LOG('renderbuildqueue starting')
    local function EngineerTemporaryCircleRender(eng,pos,color,rad)
        for _=0,10 do
            for _=0,5 do
                DrawCircle(pos,rad or 5,color)
                WaitTicks(2)
            end
            WaitTicks(5)
        end
    end
    local function EngineerTemporaryLineRender(eng,pos,color,pos2)
        if not pos2 then
            for _=0,25 do
                if not eng or eng.Dead then return end
                DrawLinePop(eng:GetPosition(),pos,color)
                WaitTicks(2)
            end
        else
            for _=0,25 do
                DrawLinePop(pos,pos2,color)
                WaitTicks(2)
            end
        end
    end
    if eng.renderbuildqueue then return end
    aiBrain=eng:GetAIBrain()
    eng.renderbuildqueue=true
    WaitTicks(3)
    local function normalposition(vec)
        return {vec[1],GetSurfaceHeight(vec[1],vec[2]),vec[2]}
    end
    local function RNGtemporaryrenderbuildsquare(pos,x,y)
        local pos1={pos[1]-x/2,pos[3]-y/2}
        local pos2={pos1[1]+x,pos1[2]}
        local pos3={pos2[1],pos2[2]+y}
        local pos4={pos3[1]-x,pos3[2]}
        for _=0,25 do
            DrawLine(normalposition(pos1),normalposition(pos2),'FF4CFF00')
            DrawLine(normalposition(pos2),normalposition(pos3),'FF4CFF00')
            DrawLine(normalposition(pos3),normalposition(pos4),'FF4CFF00')
            DrawLine(normalposition(pos4),normalposition(pos1),'FF4CFF00')
            WaitTicks(2)
        end
    end
    local function positionparse(build)
        if build[4] then
            return build[2]
        else
            return normalposition(build[2])
        end
    end
    while not eng.Dead do
        if not eng or eng.Dead then return end
        if not eng.EngineerBuildQueue or table.getn(eng.EngineerBuildQueue)<1 then
            DrawCircle(eng:GetPosition(),3,'FFFF0000')
            WaitTicks(2)
            continue
        end
        for i,v in eng.EngineerBuildQueue do
            if i==1 then
                ForkThread(EngineerTemporaryLineRender,eng,positionparse(v),'da4CFF00')
            else
                ForkThread(EngineerTemporaryLineRender,eng,positionparse(eng.EngineerBuildQueue[i-1]),'aa4CFF00',positionparse(v))
            end
            ForkThread(RNGtemporaryrenderbuildsquare,positionparse(v),aiBrain:GetUnitBlueprint(v[1]).Physics.SkirtSizeX,aiBrain:GetUnitBlueprint(v[1]).Physics.SkirtSizeZ)
        end
        for _=0,25 do
            WaitTicks(2)
        end
    end
end