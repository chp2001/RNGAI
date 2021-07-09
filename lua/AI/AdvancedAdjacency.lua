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
function DoAdvancedAdjacency(aiBrain, baseManager, intelManager, blueprint, location, radius, locationBias, job)
    local self=aiBrain
    local function combintoid(set)
        local tab=set
        local tabid={}
        for k,v in tab do
            local n=v
            tabid[k]=tostring(v)
        end
        local output=''
        for k,v in tabid do
            if k>1 then
                output=output..'X'
            end
            output=output..v
        end
        return output
    end
    local function PullReference(blueprint,region)
        local reftable=nil
        local factory=false
        local land=false
        local air=false
        local energyproduction=false
        local massfabrication=false
        local radar=false
        local massstorage=false
        local energystorage=false
        local tech1=false
        local tech2=false
        local tech3=false
        local supportfactory=false
        local airstagingplatform=false
        local shield =false
        local defense=false
        local directfire=false
        local antimissile=false
        local artillery=false
        local omni=false
        if blueprint.CategoriesHash then
            factory=blueprint.CategoriesHash.FACTORY
            land=blueprint.CategoriesHash.LAND
            air=blueprint.CategoriesHash.AIR
            energyproduction=blueprint.CategoriesHash.ENERGYPRODUCTION
            massfabrication=blueprint.CategoriesHash.MASSFABRICATION
            radar=blueprint.CategoriesHash.RADAR
            omni=blueprint.CategoriesHash.OMNI
            massstorage=blueprint.CategoriesHash.MASSSTORAGE
            energystorage=blueprint.CategoriesHash.ENERGYSTORAGE
            tech1=blueprint.CategoriesHash.TECH1
            tech2=blueprint.CategoriesHash.TECH2
            tech3=blueprint.CategoriesHash.TECH3
            supportfactory=blueprint.CategoriesHash.SUPPORTFACTORY
            airstagingplatform=blueprint.CategoriesHash.AIRSTAGINGPLATFORM
            shield=blueprint.CategoriesHash.SHIELD
            defense=blueprint.CategoriesHash.DEFENSE
            directfire=blueprint.CategoriesHash.DIRECTFIRE
            antimissile=blueprint.CategoriesHash.ANTIMISSILE
            artillery=blueprint.CategoriesHash.ARTILLERY
        end
        local bias=false
        if factory and land then
            if tech1 or supportfactory then
                reftable={
                    categories.MASSEXTRACTION * categories.TECH1,
                    --categories.ENERGYPRODUCTION * categories.STRUCTURE - categories.TECH1 - categories.HYDROCARBON,
                    categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.SUPPORTFACTORY,
                    categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.TECH1,
                }
                bias='ForwardClose'
            else
                reftable={
                    categories.MASSEXTRACTION * categories.TECH3,
                    categories.ENERGYPRODUCTION * categories.TECH3,
                    categories.ENERGYPRODUCTION * categories.TECH2,
                    categories.MASSEXTRACTION * categories.TECH2,
                    categories.MASSEXTRACTION * categories.TECH1,
                    categories.HYDROCARBON,
                    --categories.ENERGYPRODUCTION * categories.STRUCTURE - categories.TECH1 - categories.HYDROCARBON,
                    categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.SUPPORTFACTORY,
                    categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.TECH1,
                }
            end
        elseif factory and air then
            reftable={
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH3,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH2,
                categories.HYDROCARBON,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
                categories.FACTORY * categories.AIR,
            }
            bias='BackClose'
        elseif airstagingplatform then
            reftable = {
                categories.STRUCTURE * categories.AIRSTAGINGPLATFORM,
                categories.FACTORY * categories.AIR,
            }
        elseif massstorage then
            reftable = {
                categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3,
                categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH2,
                categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH3,
                categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH2,
                categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1,
            }
        elseif energystorage then
            reftable = {
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
                categories.HYDROCARBON,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
            }
        elseif massfabrication and tech2 then
            reftable = {
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
                categories.HYDROCARBON,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
            }
        elseif massfabrication and tech3 then
            reftable = {
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                categories.STRUCTURE * categories.SHIELD,
                categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
                categories.HYDROCARBON,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
            }
        elseif energyproduction and tech1 then
            reftable = {
                categories.FACTORY * categories.AIR,
                categories.RADAR * categories.STRUCTURE,
                categories.MASSEXTRACTION * categories.TECH1,
                categories.FACTORY * categories.LAND,
                categories.ENERGYSTORAGE,   
                categories.INDIRECTFIRE * categories.DEFENSE,
                categories.SHIELD * categories.STRUCTURE,
                categories.ENERGYPRODUCTION * categories.STRUCTURE,
            }
            bias='BackClose'
        elseif energyproduction and tech2 then
            reftable = {
                categories.EXPERIMENTAL * categories.STRUCTURE * categories.INDIRECTFIRE,
                categories.STRATEGIC * categories.STRUCTURE - categories.AIRSTAGINGPLATFORM,
                categories.FACTORY * categories.AIR,
                categories.SHIELD * categories.STRUCTURE * categories.TECH3,
                categories.MASSFABRICATION * categories.TECH3,
                categories.GATE * categories.STRUCTURE,
                categories.FACTORY * categories.LAND,
                categories.SHIELD * categories.STRUCTURE * categories.TECH2,
                categories.INDIRECTFIRE * categories.DEFENSE,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYPRODUCTION * categories.STRUCTURE,
            }
            bias='BackClose'
        elseif energyproduction and tech3 then
            reftable = {
                categories.EXPERIMENTAL * categories.STRUCTURE * categories.INDIRECTFIRE,
                categories.STRATEGIC * categories.STRUCTURE - categories.AIRSTAGINGPLATFORM,
                categories.FACTORY * categories.AIR,
                categories.SHIELD * categories.STRUCTURE * categories.TECH3,
                categories.MASSFABRICATION * categories.TECH3,
                categories.GATE * categories.STRUCTURE,
                categories.FACTORY * categories.LAND,
                categories.SHIELD * categories.STRUCTURE * categories.TECH2,
                categories.INDIRECTFIRE * categories.DEFENSE,
                categories.RADAR * categories.STRUCTURE,
                categories.ENERGYPRODUCTION * categories.STRUCTURE,
            }
            bias='BackClose'
        elseif shield then
            reftable = {
                categories.STRUCTURE * categories.EXPERIMENTAL,
                categories.STRUCTURE * categories.STRATEGIC,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH3,
                categories.FACTORY * categories.STRUCTURE * categories.TECH3 - categories.SUPPORTFACTORY,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH2,
                categories.FACTORY * categories.STRUCTURE * categories.TECH2 - categories.SUPPORTFACTORY,
                categories.FACTORY * categories.STRUCTURE * categories.TECH3,
                categories.FACTORY * categories.STRUCTURE * categories.TECH2,
                categories.DEFENSE * categories.DIRECTFIRE,
                categories.HYDROCARBON,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
                categories.FACTORY * categories.AIR,
            }
        elseif radar or omni then
            reftable = {
                categories.STRUCTURE * categories.ENERGYPRODUCTION,
            }
            bias='ForwardClose'
        elseif artillery then
            reftable = {
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH3,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH2,
                categories.STRUCTURE * categories.SHIELD,
                categories.ENERGYPRODUCTION * categories.STRUCTURE * categories.TECH1,
            }
            bias='Forward'
        elseif antimissile and tech2 then
            reftable = {
                categories.FACTORY * categories.STRUCTURE * categories.LAND - categories.TECH1 - categories.SUPPORTFACTORY,
                categories.ENERGYPRODUCTION * (categories.TECH3 + categories.TECH2),
                categories.MASSEXTRACTION - categories.TECH1,
            }
            bias='Forward'
        elseif defense and directfire then 
            reftable = {
                categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.SUPPORTFACTORY + categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.TECH1,
                categories.STRUCTURE * categories.SHIELD,
            }
            bias='Forward'
        elseif defense then
            reftable = {
                categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.SUPPORTFACTORY,
                categories.STRUCTURE * categories.SHIELD,
                categories.FACTORY * categories.STRUCTURE * categories.LAND * categories.TECH1,
            }
            bias='Forward'
        else
            reftable={
                categories.STRUCTURE,
            }
        end
        if not bias then bias='Close' end
        local reference={}
        if job.job.area=='Base' then
            bias='BackClose'
        end
        for _,v in reftable do
            LOG('input into reftable is '..repr(v)..' pos is '..repr(region))
            local refunits=AIUtils.GetOwnUnitsAroundPoint(self, v, region, 80, nil,nil, nil)
            table.insert(reference,refunits)
        end
        return reference, bias
    end
    local function normalposition(vec)
        return {vec[1],GetSurfaceHeight(vec[1],vec[2]),vec[2]}
    end
    local function PrebuildToBuild(blueprint)
        local blueprintID=blueprint.BlueprintId
        local factionIndex = self:GetFactionIndex()
        local buildingTmpl = import('/lua/BuildingTemplates.lua')['BuildingTemplates'][factionIndex]
        for _,v in buildingTmpl do
            if v[2]==blueprintID then
                return v[1]
            end
        end
    end
    local function BuildPrebuildUnit(blueprint,region)
        if blueprint then
            local reference,bias=PullReference(blueprint,region)
            local Centered=false
            local whatToBuild=blueprint.BlueprintId
            local buildtype=PrebuildToBuild(blueprint)
            local unitSize = blueprint.Physics
            for _,x in reference do
                local spots={}
                local adjcombos={}
                if bias then
                    if bias=='Forward' and self.PrimaryEnemy.Position then
                            table.sort(x,function(a,b)  return VDist3Sq(a:GetPosition(),self.PrimaryEnemy.Position)<VDist3Sq(b:GetPosition(),self.PrimaryEnemy.Position) end)
                    elseif bias=='Back' and self.PrimaryEnemy.Position then
                            table.sort(x,function(a,b)  return VDist3Sq(a:GetPosition(),self.PrimaryEnemy.Position)>VDist3Sq(b:GetPosition(),self.PrimaryEnemy.Position) end)
                    elseif bias=='BackClose' and self.PrimaryEnemy.Position then
                            table.sort(x,function(a,b)  return VDist3Sq(a:GetPosition(),self.PrimaryEnemy.Position)/math.max(10,VDist3Sq(a:GetPosition(),region))>VDist3Sq(b:GetPosition(),self.PrimaryEnemy.Position)/math.max(10,VDist3Sq(b:GetPosition(),region)) end)
                    elseif bias=='ForwardClose' and self.PrimaryEnemy.Position then
                            table.sort(x,function(a,b)  return VDist3Sq(a:GetPosition(),self.PrimaryEnemy.Position)*math.max(10,VDist3Sq(a:GetPosition(),region))<VDist3Sq(b:GetPosition(),self.PrimaryEnemy.Position)*math.max(10,VDist3Sq(b:GetPosition(),region)) end)
                    elseif bias=='Close' or not self.PrimaryEnemy.Position then
                            table.sort(x,function(a,b)  return math.max(10,VDist3Sq(a:GetPosition(),region))<math.max(10,VDist3Sq(b:GetPosition(),region)) end)
                    end
                end
                for k,v in x do
                    local instantreturn=(table.getn(x)==1)
                    if not Centered then
                        if not v.Dead then
                            local targetSize = v:GetBlueprint().Physics
                            local targetPos = v:GetPosition()
                            local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
                            local offsetX=math.floor(differenceX/2)
                            local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
                            local offsetZ=math.floor(differenceZ/2)
                            local offsetfactory=0
                            if EntityCategoryContains(categories.FACTORY, v) and ((buildtype=='T1LandFactory' or buildtype=='T2LandFactory' or buildtype=='T3LandFactory' or buildtype=='T2SupportLandFactory' or buildtype=='T3SupportLandFactory') or (buildtype=='T1AirFactory' or buildtype=='T2AirFactory' or buildtype=='T3AirFactory' or buildtype=='T2SupportAirFactory' or buildtype=='T3SupportAirFactory')) then
                                offsetfactory=2
                            end
                            -- Top/bottom of unit
                            for i=-offsetX,offsetX do
                                local testPos = { targetPos[1] + (i * 1), targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2)-offsetfactory, 0 }
                                local testPos2 = { targetPos[1] + (i * 1), targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2)+offsetfactory, 0 }
                                -- check if the buildplace is to close to the border or inside buildable area
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if instantreturn and self:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then return normalposition(testPos) end
                                    if not adjcombos[combintoid(normalposition(testPos))] then
                                        adjcombos[combintoid(normalposition(testPos))]=1
                                    else
                                        adjcombos[combintoid(normalposition(testPos))]=adjcombos[combintoid(normalposition(testPos))]+1
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if instantreturn and self:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then return normalposition(testPos2) end
                                    if not adjcombos[combintoid(normalposition(testPos2))] then
                                        adjcombos[combintoid(normalposition(testPos2))]=1
                                    else
                                        adjcombos[combintoid(normalposition(testPos2))]=adjcombos[combintoid(normalposition(testPos2))]+1
                                    end
                                end
                            end
                            -- Sides of unit
                            for i=-offsetZ,offsetZ do
                                local testPos = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2)-offsetfactory, targetPos[3] + (i * 1), 0 }
                                local testPos2 = { targetPos[1]+targetSize.SkirtSizeX/2+(unitSize.SkirtSizeX/2)+offsetfactory, targetPos[3] + (i * 1), 0 }
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if instantreturn and self:CanBuildStructureAt(whatToBuild, normalposition(testPos)) then return normalposition(testPos) end
                                    if not adjcombos[combintoid(normalposition(testPos))] then
                                        adjcombos[combintoid(normalposition(testPos))]=1
                                    else
                                        adjcombos[combintoid(normalposition(testPos))]=adjcombos[combintoid(normalposition(testPos))]+1
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if instantreturn and self:CanBuildStructureAt(whatToBuild, normalposition(testPos2)) then return normalposition(testPos2) end
                                    if not adjcombos[combintoid(normalposition(testPos2))] then
                                        adjcombos[combintoid(normalposition(testPos2))]=1
                                    else
                                        adjcombos[combintoid(normalposition(testPos2))]=adjcombos[combintoid(normalposition(testPos2))]+1
                                    end
                                end
                            end
                        end
                    end
                end
                local sets={}
                for k,v in adjcombos do
                    if not sets[v] then sets[v]={} end
                    local enter={}
                    for a,b in STR_GetTokens(k or '', 'X') do
                        enter[a+1]=tonumber(b)
                    end
                    table.insert(sets[v],enter)
                end
                for k,v in region do
                    if not (type(v)=='number') then
                        table.remove(region,k)
                    end
                end
                for v=table.getn(sets),1,-1 do
                    for _,coord in sets[v] do
                        if self:CanBuildStructureAt(whatToBuild, coord) then
                            return coord
                        end
                    end
                end
            end
        end
        return false
    end
    if not self.PrimaryEnemy then
        local enemies={}
        for i,v in ArmyBrains do
            if ArmyIsCivilian(v:GetArmyIndex()) or not IsEnemy(self:GetArmyIndex(),v:GetArmyIndex()) or v.Result=="defeat" then continue end
            local index = v:GetArmyIndex()
            local astartX, astartZ = v:GetArmyStartPos()
            local aiBrainstart = {Position={astartX, GetTerrainHeight(astartX, astartZ), astartZ},army=i,brain=v}
            table.insert(enemies,aiBrainstart)
        end
        local startX, startZ = self:GetArmyStartPos()
        table.sort(enemies,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX,startZ)<VDist2Sq(b.Position[1],b.Position[3],startX,startZ) end)
        self.PrimaryEnemy=enemies[1]
    end
    return BuildPrebuildUnit(blueprint,location)
end
