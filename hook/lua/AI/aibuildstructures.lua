WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibuildstructures.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')

RNGAddToBuildQueue = AddToBuildQueue
function AddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    if not aiBrain.RNG then
        return RNGAddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    end
    if not builder.EngineerBuildQueue then
        builder.EngineerBuildQueue = {}
    end
    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
    RUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, BuildToNormalLocation(buildLocation)) 
    aiBrain:BuildStructure(builder, whatToBuild, buildLocation, false)
    local newEntry = {whatToBuild, buildLocation, relative}
    table.insert(builder.EngineerBuildQueue, newEntry)
end

function AIBuildBaseTemplateOrderedRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local factionIndex = aiBrain:GetFactionIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        if IsResource(buildingType) then
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
        else
            for l,bType in baseTemplate do
                for m,bString in bType[1] do
                    if bString == buildingType then
                        for n,position in bType do
                            if n > 1 and aiBrain:CanBuildStructureAt(whatToBuild, BuildToNormalLocation(position)) then
                                 AddToBuildQueue(aiBrain, builder, whatToBuild, position, false)
                                 table.remove(bType,n)
                                 return DoHackyLogic(buildingType, builder)
                            end # if n > 1 and can build structure at
                        end # for loop
                        break
                    end # if bString == builderType
                end # for loop
            end # for loop
        end # end else
    end # if what to build
    return # unsuccessful build
end


local AntiSpamList = {}
function AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local factionIndex = aiBrain:GetFactionIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    -- If the c-engine can't decide what to build, then search the build template manually.
    if not whatToBuild then
        if AntiSpamList[buildingType] then
            return false
        end
        local FactionIndexToName = {[1] = 'UEF', [2] = 'AEON', [3] = 'CYBRAN', [4] = 'SERAPHIM', [5] = 'NOMADS', [6] = 'ARM', [7] = 'CORE' }
        local AIFactionName = FactionIndexToName[factionIndex]
        SPEW('*AIExecuteBuildStructure: We cant decide whatToBuild! AI-faction: '..AIFactionName..', Building Type: '..repr(buildingType)..', engineer-faction: '..repr(builder.factionCategory))
        -- Get the UnitId for the actual buildingType
        local BuildUnitWithID
        for Key, Data in buildingTemplate do
            if Data[1] and Data[2] and Data[1] == buildingType then
                SPEW('*AIExecuteBuildStructure: Found template: '..repr(Data[1])..' - Using UnitID: '..repr(Data[2]))
                BuildUnitWithID = Data[2]
                break
            end
        end
        -- If we can't find a template, then return
        if not BuildUnitWithID then
            AntiSpamList[buildingType] = true
            WARN('*AIExecuteBuildStructure: No '..repr(builder.factionCategory)..' unit found for template: '..repr(buildingType)..'! ')
            return false
        end
        -- get the needed tech level to build buildingType
        local BBC = __blueprints[BuildUnitWithID].CategoriesHash
        local NeedTech
        local HasTech
        if BBC.BUILTBYCOMMANDER or BBC.BUILTBYTIER1COMMANDER or BBC.BUILTBYTIER1ENGINEER then
            NeedTech = 1
        elseif BBC.BUILTBYTIER2COMMANDER or BBC.BUILTBYTIER2ENGINEER then
            NeedTech = 2
        elseif BBC.BUILTBYTIER3COMMANDER or BBC.BUILTBYTIER3ENGINEER then
            NeedTech = 3
        end
        -- If we can't find a techlevel for the building we want to build, then return
        if not NeedTech then
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for BuildUnitWithID: '..repr(BuildUnitWithID))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Need engineer with Techlevel ('..NeedTech..') for BuildUnitWithID: '..repr(BuildUnitWithID))
        end
        -- get the actual tech level from the builder
        local BC = builder:GetBlueprint().CategoriesHash
        if BC.TECH1 or BC.COMMAND then
            HasTech = 1
        elseif BC.TECH2 then
            HasTech = 2
        elseif BC.TECH3 then
            HasTech = 3
        end
        -- If we can't find a techlevel for the building we  want to build, return
        if not HasTech then
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for engineer: '..repr(builder:GetBlueprint().BlueprintId))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer ('..repr(builder:GetBlueprint().BlueprintId)..') has Techlevel ('..HasTech..')')
        end

        if HasTech < NeedTech then
            WARN('*AIExecuteBuildStructure: TECH'..HasTech..' Unit "'..BuildUnitWithID..'" is assigned to build TECH'..NeedTech..' buildplatoon! ('..repr(buildingType)..')')
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer with Techlevel ('..HasTech..') can build TECH'..NeedTech..' BuildUnitWithID: '..repr(BuildUnitWithID))
        end

        local HasFaction = builder.factionCategory
        local NeedFaction = string.upper(__blueprints[string.lower(BuildUnitWithID)].General.FactionName)
        if HasFaction ~= NeedFaction then
            WARN('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', ('..HasFaction..') engineers can\'t build ('..NeedFaction..') structures!')
            return false
        else
            SPEW('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', Engineer with faction ('..HasFaction..') can build faction ('..NeedFaction..') - BuildUnitWithID: '..repr(BuildUnitWithID))
        end

        local IsRestricted = import('/lua/game.lua').IsRestricted
        if IsRestricted(BuildUnitWithID, GetFocusArmy()) then
            WARN('*AIExecuteBuildStructure: Unit is Restricted!!! Building Type: '..repr(buildingType)..', faction: '..repr(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
            AntiSpamList[buildingType] = true
            return false
        end

        WARN('*AIExecuteBuildStructure: DecideWhatToBuild call failed for Building Type: '..repr(buildingType)..', faction: '..repr(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
        return false
    end
    -- find a place to build it (ignore enemy locations if it's a resource)
    -- build near the base the engineer is part of, rather than the engineer location
    local relativeTo
    if closeToBuilder then
        relativeTo = builder:GetPosition()
    elseif builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
    else
        local startPosX, startPosZ = aiBrain:GetArmyStartPos()
        relativeTo = {startPosX, 0, startPosZ}
    end
    local location = false
    if IsResource(buildingType) then
        if buildingType ~= 'T1HydroCarbon' and constructionData.PriorityExpand then
            if not aiBrain.expansionMex or not aiBrain.expansionMex[1].priority then
                --initialize expansion priority
                local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
                local Expands = AIUtils.AIGetMarkerLocations(aiBrain, 'Expansion Area')
                local BigExpands = AIUtils.AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
                if not aiBrain.emanager then aiBrain.emanager={} end
                aiBrain.emanager.expands = {}
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
                            table.insert(aiBrain.expansionMex, {v,Position = v.position, Name = k})
                            table.insert(aiBrain.emanager.expands[1].mextable,{v,Position = v.position, Name = k})
                            aiBrain.emanager.expands[1].mexnum=aiBrain.emanager.expands[1].mexnum+1
                        end
                    end
                end
                for _,v in aiBrain.expansionMex do
                    table.sort(aiBrain.emanager.expands,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],v.Position[1],v.Position[3])<VDist2Sq(b.Position[1],b.Position[3],v.Position[1],v.Position[3]) end)
                    v.distsq=VDist2Sq(aiBrain.emanager.expands[1].Position[1],aiBrain.emanager.expands[1].Position[2],v.Position[1],v.Position[3])
                    v.priority=aiBrain.emanager.expands[1].mexnum/v.distsq
                    v.expand=aiBrain.emanager.expands[1]
                    v.expand.taken=0
                    v.expand.takentime=0
                end
            end
            local markerTable=table.copy(aiBrain.expansionMex)
            relative = false
            if not constructionData.MinDistance then
                constructionData.MinDistance=0
            end
            if not constructionData.MaxDistance then
                constructionData.MaxDistance=9999
            end
            table.sort(markerTable,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],relativeTo[1],relativeTo[3])/a.priority/a.priority*a.distsq<VDist2Sq(b.Position[1],b.Position[3],relativeTo[1],relativeTo[3])/b.priority/b.priority*b.distsq end)
            for i,v in markerTable do
                if not constructionData.ExpandDist then
                    if VDist3Sq( v.Position, relativeTo ) <= constructionData.MaxDistance*constructionData.MaxDistance and VDist3Sq( v.Position, relativeTo ) >= constructionData.MinDistance*constructionData.MinDistance then
                        if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                            if v.expand.taken>0 and v.expand.mexnum/(v.expand.taken+1)<4 then 
                                if v.expand.takentime+40>GetGameTimeSeconds() then
                                    continue
                                elseif v.expand.takentime-60<GetGameTimeSeconds() then
                                    v.expand.taken=v.expand.taken-2
                                    v.expand.takentime=GetGameTimeSeconds()
                                else
                                    v.expand.takentime=GetGameTimeSeconds()
                                end
                            elseif v.expand.taken<1 or v.expand.mexnum/(v.expand.taken+1)>4 then
                                v.expand.takentime=GetGameTimeSeconds()
                                --v.expand.taken=v.expand.taken+1
                            end
                            LOG('MassPoint found for engineer')
                            location = table.copy(markerTable[i])
                            location = {location.Position[1], location.Position[3], location.Position[2]}
                            v.expand.taken=v.expand.taken+1
                            LOG('Location is '..repr(location))
                            break
                        end
                    end
                else
                    if v.distsq <= constructionData.MaxDistance*constructionData.MaxDistance and VDist3Sq( v.Position, relativeTo ) >= constructionData.MinDistance*constructionData.MinDistance then
                        if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                            if v.expand.taken>0 and v.expand.mexnum/(v.expand.taken+1)<4 then 
                                if v.expand.takentime+40>GetGameTimeSeconds() then
                                    continue
                                elseif v.expand.takentime-60<GetGameTimeSeconds() then
                                    v.expand.taken=v.expand.taken-2
                                    v.expand.takentime=GetGameTimeSeconds()
                                else
                                    v.expand.takentime=GetGameTimeSeconds()
                                end
                            elseif v.expand.taken<1 or v.expand.mexnum/(v.expand.taken+1)>4 then
                                v.expand.takentime=GetGameTimeSeconds()
                                --v.expand.taken=v.expand.taken+1
                            end
                            LOG('MassPoint found for engineer')
                            location = table.copy(markerTable[i])
                            location = {location.Position[1], location.Position[3], location.Position[2]}
                            v.expand.taken=v.expand.taken+1
                            LOG('Location is '..repr(location))
                            break
                        end
                    end
                end
            end
            if not location then
                if not constructionData.ExpandDist then
                    for i,v in markerTable do
                        if VDist3Sq( v.Position, relativeTo ) <= constructionData.MaxDistance*constructionData.MaxDistance and VDist3Sq( v.Position, relativeTo ) >= constructionData.MinDistance*constructionData.MinDistance then
                            if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                                LOG('MassPoint found for engineer')
                                location = table.copy(markerTable[i])
                                location = {location.Position[1], location.Position[3], location.Position[2]}
                                v.expand.taken=v.expand.taken+1
                                LOG('Location is '..repr(location))
                                break
                            end
                        end
                    end
                else
                    for i,v in markerTable do
                        if v.distsq <= constructionData.MaxDistance*constructionData.MaxDistance and VDist3Sq( v.Position, relativeTo ) >= constructionData.MinDistance*constructionData.MinDistance then
                            if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                                LOG('MassPoint found for engineer')
                                location = table.copy(markerTable[i])
                                location = {location.Position[1], location.Position[3], location.Position[2]}
                                v.expand.taken=v.expand.taken+1
                                LOG('Location is '..repr(location))
                                break
                            end
                        end
                    end
                end
            end
        elseif buildingType ~= 'T1HydroCarbon' and constructionData.MexThreat then
            LOG('MexThreat Builder Type')
            local threatMin = -9999
            local threatMax = 9999
            local threatRings = 0
            local threatType = 'AntiSurface'
            local markerTable = RUtils.AIGetSortedMassLocationsThreatRNG(aiBrain, constructionData.MinDistance, constructionData.MaxDistance, constructionData.ThreatMin, constructionData.ThreatMax, constructionData.ThreatRings, constructionData.ThreatType, relativeTo)
            relative = false
            for i,v in markerTable do
                if VDist3Sq( v.Position, relativeTo ) <= constructionData.MaxDistance*constructionData.MaxDistance and VDist3Sq( v.Position, relativeTo ) >= constructionData.MinDistance*constructionData.MinDistance then
                    if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                        LOG('MassPoint found for engineer')
                        location = table.copy(markerTable[i])
                        location = {location.Position[1], location.Position[3], location.Position[2]}
                        LOG('Location is '..repr(location))
                        break
                    end
                end
            end
        else
            location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, 'Enemy', relativeTo[1], relativeTo[3], 5)
        end
    else
        location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
    end
    -- if it's a reference, look around with offsets
    if not location and reference then
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                break
            end
        end
    end
    -- if we have no place to build, then maybe we have a modded/new buildingType. Lets try 'T1LandFactory' as dummy and search for a place to build near base
    if not location and not IsResource(buildingType) and builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        --LOG('*AIExecuteBuildStructure: Find no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near base...')
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --LOG('*AIExecuteBuildStructure: Yes! Found a place near base to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we still have no place to build, then maybe we have really no place near the base to build. Lets search near engineer position
    if not location and not IsResource(buildingType) then
        --LOG('*AIExecuteBuildStructure: Find still no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near Engineer...')
        relativeTo = builder:GetPosition()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --LOG('*AIExecuteBuildStructure: Yes! Found a place near engineer to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we have a location, build!
    if location then
        local relativeLoc = BuildToNormalLocation(location)
        if relative then
            relativeLoc = {relativeLoc[1] + relativeTo[1], relativeLoc[2] + relativeTo[2], relativeLoc[3] + relativeTo[3]}
        end
        -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
        AddToBuildQueue(aiBrain, builder, whatToBuild, NormalToBuildLocation(relativeLoc), false)
        return true
    end
    -- At this point we're out of options, so move on to the next thing
    return false
end

function AIBuildAdjacencyRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, cons)
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildingType })
        for k,v in reference do
            if not v.Dead then
                local targetSize = v:GetBlueprint().Physics
                local targetPos = v:GetPosition()
                targetPos[1] = targetPos[1] - (targetSize.SkirtSizeX/2)
                targetPos[3] = targetPos[3] - (targetSize.SkirtSizeZ/2)
                -- Top/bottom of unit
                for i=0,((targetSize.SkirtSizeX/2)-1) do
                    local testPos = { targetPos[1] + 1 + (i * 2), targetPos[3]-(unitSize.SkirtSizeZ/2), 0 }
                    local testPos2 = { targetPos[1] + 1 + (i * 2), targetPos[3]+targetSize.SkirtSizeZ+(unitSize.SkirtSizeZ/2), 0 }
                    -- check if the buildplace is to close to the border or inside buildable area
                    if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                        table.insert(template[1], testPos)
                    end
                    if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                        table.insert(template[1], testPos2)
                    end
                end
                -- Sides of unit
                for i=0,((targetSize.SkirtSizeZ/2)-1) do
                    local testPos = { targetPos[1]+targetSize.SkirtSizeX + (unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i * 2), 0 }
                    local testPos2 = { targetPos[1]-(unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i*2), 0 }
                    if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                        table.insert(template[1], testPos)
                    end
                    if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                        table.insert(template[1], testPos2)
                    end
                end
            end
        end
        -- build near the base the engineer is part of, rather than the engineer location
        local baseLocation = {nil, nil, nil}
        if builder.BuildManagerData and builder.BuildManagerData.EngineerManager then
            baseLocation = builder.BuildManagerdata.EngineerManager.Location
        end
        local location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, template, false, builder, baseLocation[1], baseLocation[3])
        if location then
            if location[1] > 8 and location[1] < ScenarioInfo.size[1] - 8 and location[2] > 8 and location[2] < ScenarioInfo.size[2] - 8 then
                --LOG('Build '..repr(buildingType)..' at adjacency: '..repr(location) )
                AddToBuildQueue(aiBrain, builder, whatToBuild, location, false)
                return true
            end
        end
        -- Build in a regular spot if adjacency not found
        if cons.AdjRequired then
            return false
        else
            return AIExecuteBuildStructure(aiBrain, builder, buildingType, builder, true,  buildingTemplate, baseTemplate)
        end
    end
    return false
end