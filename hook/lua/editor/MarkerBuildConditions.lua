local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local LastGetMassMarker = 0
local LastCheckMassMarker = {}
local MassMarker = {}
local LastMassBOOL = false

--[[function CanBuildOnMassDistanceRNG(aiBrain, locationType, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
    if not engineerManager then
        --WARN('*AI WARNING: Invalid location - ' .. locationType)
        return false
    end
    local position = engineerManager.Location
    
    local markerTable = AIUtils.AIGetSortedMassLocations(aiBrain, maxNum, threatMin, threatMax, threatRings, threatType, position)
    return VDist2Sq( markerTable[1][1], markerTable[1][3], position[1], position[3] ) < distance * distance
end]]

function CanBuildOnMassEng2(aiBrain, engPos, distance)
    local MassMarker = {}
    for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Mass' then
            if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                -- mass marker is too close to border, skip it.
                continue
            end 
            local mexDistance = VDist3( v.position, engPos )
            if mexDistance < distance and CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                --LOG('mexDistance '..mexDistance)
                table.insert(MassMarker, {Position = v.position, Distance = mexDistance , MassSpot = v})
            end
        end
    end
    table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    if table.getn(MassMarker) > 0 then
        return true, MassMarker
    else
        return false
    end
end

function CanBuildOnMassEng(aiBrain, engPos, distance, threatMin, threatMax, threatRings, threatType, maxNum )
    if LastGetMassMarker < GetGameTimeSeconds() then
        LastGetMassMarker = GetGameTimeSeconds()+10
        MassMarker = {}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                table.insert(MassMarker, {Position = v.position, Distance = VDist3( v.position, engPos ) })
            end
        end
        table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarker[distance] or LastCheckMassMarker[distance] < GetGameTimeSeconds() then
        LastCheckMassMarker[distance] = GetGameTimeSeconds()
        local threatCheck = false
        if threatMin and threatMax and threatRings then
            threatCheck = true
        end
        LastMassBOOL = false
        for _, v in MassMarker do
            if v.Distance > distance then
                break
            end
            --LOG(_..'Checking marker with max distance ['..distance..']. Actual marker has distance: ('..(v.Distance)..').')
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                if threatCheck then
                    threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                    if threat <= threatMin or threat >= threatMax then
                        continue
                    end
                end
                LastMassBOOL = true
                break
            end
        end
    end
    return LastMassBOOL
end

function CanBuildOnMassDistanceRNG(aiBrain, locationType, minDistance, maxDistance, threatMin, threatMax, threatRings, threatType, maxNum )
    if LastGetMassMarker < GetGameTimeSeconds() then
        LastGetMassMarker = GetGameTimeSeconds()+5
        local engineerManager = aiBrain.BuilderManagers[locationType].EngineerManager
        if not engineerManager then
            --WARN('*AI WARNING: CanBuildOnMass: Invalid location - ' .. locationType)
            return false
        end
        local position = engineerManager.Location
        MassMarker = {}
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                table.insert(MassMarker, {Position = v.position, Distance = VDist3( v.position, position ) })
            end
        end
        table.sort(MassMarker, function(a,b) return a.Distance < b.Distance end)
    end
    if not LastCheckMassMarker[maxDistance] or LastCheckMassMarker[maxDistance] < GetGameTimeSeconds() then
        LastCheckMassMarker[maxDistance] = GetGameTimeSeconds()
        local threatCheck = false
        if threatMin and threatMax and threatRings then
            threatCheck = true
        end
        LastMassBOOL = false
        for _, v in MassMarker do
            if v.Distance < minDistance then
                continue
            elseif v.Distance > maxDistance then
                break
            end
            --LOG(_..'Checking marker with max maxDistance ['..maxDistance..'] minDistance ['..minDistance..'] . Actual marker has distance: ('..(v.Distance)..').')
            if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
                if threatCheck then
                    threat = aiBrain:GetThreatAtPosition(v.Position, threatRings, true, threatType or 'Overall')
                    if threat <= threatMin or threat >= threatMax then
                        continue
                    end
                end
                --LOG('Returning MassMarkerDistance True')
                LastMassBOOL = true
                break
            end
        end
    end
    return LastMassBOOL
end

function MassMarkerLessThanDistanceRNG(aiBrain, distance)

    local startX, startZ = aiBrain:GetArmyStartPos()
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Mass' then
            if VDist2Sq(startX, startZ, v.position[1], v.position[3]) < distance * distance then
                --LOG('Mass marker less than '..distance)
                return true
            end
        end
    end
    return false
end


