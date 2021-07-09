local PROFILER = import('/mods/TechAI/lua/AI/DilliDalli/Profiler.lua').GetProfiler()
local MAP = import('/mods/TechAI/lua/AI/DilliDalli/Mapping.lua').GetMap()
local CreatePriorityQueue = import('/mods/TechAI/lua/AI/DilliDalli/PriorityQueue.lua').CreatePriorityQueue
local RUtils = import('/mods/TechAI/lua/AI/RNGUtilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

UnitController = Class({
    Initialise = function(self,brain)
        self.brain = brain
        self.land = LandController()
        self.air = AirController()

        self.land:Init(self.brain)
        self.air:Init(self.brain)
    end,

    Run = function(self)
        self.land:Run()
        self.air:Run()
    end,
})

function CreateUnitController(brain)
    local uc = UnitController()
    uc:Initialise(brain)
    return uc
end

LandController = Class({
    Init = function(self,brain)
        self.brain = brain
        self.groups = {}
        self.groupID = 1

        self.rematch = false
    end,

    Run = function(self)
        self:ForkThread(self.LandControlThread)
        self:ForkThread(self.LandTargetingThread)
        --self:ForkThread(self.GroupLoggingThread)
    end,

    CreateGroup = function(self,unit)
        local lg = LandGroup()
        lg:Init(self.brain,self,self.groupID)
        self.groupID = self.groupID + 1
        table.insert(self.groups,lg)
        lg:Add(unit)
        lg:Run()
    end,

    FindGroup = function(self,unit)
        -- Add this unit to a relevant group
        local best
        local bestPriority = 0
        if EntityCategoryContains(categories.SCOUT,unit) then
            for _, v in self.groups do
                if not v.scout then
                    v:Add(unit)
                    return
                end
            end
        end
        for _, v in self.groups do
            if (v.size == 0) or v.stop then
                continue
            end
            local priority = (5+v.size)/(1+v.zoneThreat)
            if (not best) or priority < bestPriority then
                best = v
                bestPriority = priority
            end
        end
        if (not best) then
            -- Huh??
            WARN("UnitController: Failed to find group...  creating a new one.")
            self:CreateGroup(unit)
        else
            best:Add(unit)
        end
    end,

    LandTargetingThread = function(self)
        local counter = 0
        while self.brain:IsAlive() do
            if self.rematch then
                counter = 0
                -- Stable matching time
                -- Zones first
                local zones = {}
                for _, z in self.brain.intel.zones do
                    if (z.intel.class == "enemy") or (z.intel.class == "contested") then
                        local retreatEdge = false
                        for _, e in z.edges do
                            if (e.zone.intel.class == "neutral") or (e.zone.intel.class == "allied") then
                                retreatEdge = true
                            end
                        end
                        if retreatEdge then
                            table.insert(zones,{zone = z, assigned = false})
                        end
                    end
                end
                if table.getn(zones) == 0 then
                    for _, spawn in self.brain.intel.enemies do
                        table.insert(zones,{zone = MAP:FindZone(spawn), assigned = false})
                    end
                end
                -- Now groups
                local groups = {}
                for _, g in self.groups do
                    if g:Size() > 0 then
                        table.insert(groups,{group = g, pos = g:Position(), assigned = false})
                    end
                end
                -- Now insert the scores
                local scoreQueue = CreatePriorityQueue()
                for _, z in zones do
                    for _, g in groups do
                        -- Higher is better
                        local s = VDist3(g.pos,z.zone.pos)/(g.group:Size()*z.zone.weight)
                        scoreQueue:Queue({ zone = z, group = g, priority = s})
                    end
                end
                local m = table.getn(zones)
                local n = table.getn(groups)
                -- Now draw in order of priority and assign stuff
                local k = 0
                while scoreQueue:Size() > 0 and k < n and k < m do
                    local item = scoreQueue:Dequeue()
                    if (not item.group.assigned) and (not item.zone.assigned) then
                        k = k+1
                        -- Assign this group to the zone
                        item.group.assigned = true
                        item.zone.assigned = true
                        item.group.group.targetZone = item.zone.zone
                        -- Find a staging zone
                        local bestStaging
                        local bestDistance = 0
                        for _, e in item.zone.zone.edges do
                            if (e.zone.intel.class == "allied") or (e.zone.intel.class == "neutral") then
                                local d = VDist3(self.brain.intel.spawn,e.zone.pos)
                                if (not bestStaging) or (d < bestDistance) then
                                    bestStaging = e.zone
                                    bestDistance = d
                                end
                            end
                        end
                        if bestStaging then
                            item.group.group.stagingZone = bestStaging
                        else
                            WARN("LandTargetingThread: Unable to identify staging zone!")
                            item.group.group.stagingZone = item.zone.zone
                        end
                    else
                    end
                end
                -- Unassigned groups should be added to the nearest assigned group
                if n > m then
                    for _, g1 in groups do
                        if g1.assigned then
                            continue
                        end
                        local bestGroup
                        local bestDist = 0
                        for _, g2 in groups do
                            if not g2.assigned then
                                continue
                            end
                            local d = VDist3(g1.pos,g2.pos)
                            if (not bestGroup) or (d < bestDist) then
                                bestGroup = g2.group
                                bestDist = d
                            end
                        end
                        g1.group.stop = true
                        bestGroup:Merge(g1.group)
                    end
                end
                -- And breathe out...
                WaitTicks(50)
            else
                counter = counter+1
                if counter > 300 then
                    self.rematch = true
                    counter = 0
                end
                WaitTicks(1)
            end
        end
    end,

    FindNewTarget = function(self,pos,layer)
        local best
        local bestPriority = 0
        local foundYet = false
        -- TODO: use layer info
        for _, v in self.brain.intel.zones do
            if (v.intel.class == "allied") or (v.intel.class == "neutral") or (not MAP:CanPathTo2(pos,v.pos,"surf")) then
                continue
            end
            local retreatFound = false
            for _, e in v.edges do
                if e.zone.intel.class == "neutral" or e.zone.intel.class == "allied" then
                    retreatFound = true
                end
            end
            if not retreatFound then
                continue
            end
            local found = false
            for _, g in self.groups do
                if g.targetZone and (VDist3(g.targetZone.pos,v.pos) < 5) then
                    found = true
                end
            end
            if (not found) or (not foundYet) then
                local priority = 1/v.weight
                if table.getn(self.brain.aiBrain:GetUnitsAroundPoint(categories.STRUCTURE,v.pos,30,'Enemy')) > 0 then
                    priority = priority/5
                end
                priority = priority * (100+VDist3(pos,v.pos))
                if (not foundYet) and (not found) then
                    best = v
                    bestPriority = priority
                    foundYet = true
                elseif (not best) or (priority < bestPriority) then
                    best = v
                end
            end
        end
        if best then
            return best
        else
            return self.brain.intel:FindZone(self.brain.intel.enemies[Random(1,table.getn(self.brain.intel.enemies))])
        end
    end,

    CheckGroups = function(self)
        -- Delete dead groups
        local i = 1
        while i <= table.getn(self.groups) do
            if (self.groups[i]:Size() == 0) or self.groups[i].stop then
                table.remove(self.groups,i)
            else
                i = i+1
            end
        end
    end,

    GroupLoggingThread = function(self)
        while self.brain:IsAlive() do
            --LOG("=========================")
            --for _, v in self.groups do
            --    LOG("Group: "..tostring(v.id)..", size: "..tostring(v.size)..", reinforcing: "..tostring(table.getn(v.reinforcing))..", units: "..tostring(table.getn(v.units)))
            --end
            LOG("Num groups: "..tostring(table.getn(self.groups)))
            local t = 0
            for _, v in self.groups do
                t = t + table.getn(v.units)
                t = t + table.getn(v.reinforcing)
            end
            LOG("Group state size: "..tostring(t))
            WaitTicks(200)
        end
    end,

    LandControlThread = function(self)
        while self.brain:IsAlive() do
            local start = PROFILER:Now()
            self:CheckGroups()
            local units = self.brain.aiBrain:GetListOfUnits(categories.LAND * categories.MOBILE - categories.ENGINEER,false,true)
            local numUnits = table.getn(units)
            local targetNumberOfGroups = math.min(math.sqrt(numUnits) + 1,self.brain.intel:NumLandAssaultZones())
            local numGroups = table.getn(self.groups)
            for _, unit in units do
                if not unit.CustomData then
                    unit.CustomData = {}
                end
                if (not unit.CustomData.landAssigned) and (not unit:IsBeingBuilt()) then
                    unit.CustomData.landAssigned = true
                    if EntityCategoryContains(categories.EXPERIMENTAL,unit) then
                        self:ForkThread(self.ExpThread,unit)
                    elseif numGroups < targetNumberOfGroups then
                        -- Create group
                        self:CreateGroup(unit)
                        numGroups = numGroups + 1
                    else
                        -- Add to group
                        self:FindGroup(unit)
                    end
                end
            end
            -- Multiple coms?  Pretty niche.
            if self.brain.base.isBOComplete then
                local coms = self.brain.aiBrain:GetListOfUnits(categories.COMMAND,false,true)
                for _, v in coms do
                    v.CustomData.excludeAssignment = true
                    if not v.CustomData.landAssigned and not v.CustomData.isAssigned then
                        v.CustomData.landAssigned = true
                        self:ForkThread(self.ACUThread,v)
                        --self:CreateGroup(v)
                    end
                end
            end
            PROFILER:Add("LandControlThread",PROFILER:Now()-start)
            WaitTicks(21)
        end
    end,

    BiasLocation = function(self,pos,target,dist)
        local delta = VDiff(target,pos)
        local norm = VDist2(delta[1],delta[3],0,0)
        local x = pos[1]+dist*delta[1]/norm
        local z = pos[3]+dist*delta[3]/norm
        x = math.min(ScenarioInfo.size[1]-5,math.max(5,x))
        z = math.min(ScenarioInfo.size[2]-5,math.max(5,z))
        return {x,GetSurfaceHeight(x,z),z}
    end,

    ACUThread = function(self,acu)
        local target
        local scared = false
        while self.brain:IsAlive() and acu and (not acu.Dead) do
            if acu:GetHealth() < 6000 and (not scared) then
                target = self:BiasLocation(self.brain.intel.allies[1],self.brain.intel.enemies[1],10)
                scared = true
            elseif scared and acu:GetHealth()/acu:GetBlueprint().Defense.MaxHealth > 0.9 then
                scared = false
                target = nil
            end
            if self.brain.monitor.units.land.mass.total > 2500 then
                target = self:BiasLocation(self.brain.intel.allies[1],self.brain.intel.enemies[1],10)
                scared = true
            end
            if not target then
                local best
                local bestMetric = 0
                for _, v in self.brain.intel.zones do
                    local d0 = VDist3(self.brain.intel.allies[1],v.pos)
                    local d1 = VDist3(self.brain.intel.enemies[1],v.pos)
                    local metric = v.weight/(100+math.abs(d0-1.5*d1))
                    if (not best) or metric > bestMetric and d0<256 then
                        best = v.pos
                        bestMetric = metric
                    end
                end
                -- Bias target towards enemy base
                target = self:BiasLocation(best,self.brain.intel.enemies[1],10)
            end
            if VDist3(acu:GetPosition(),target) > 20 then
                -- If too far away move nearer
                IssueClearCommands({acu})
                IssueMove({acu},target)
            elseif acu:IsIdleState() then
                -- Else if idle move somewhere random nearby
                local newPos = {target[1] + Random(-15,15),target[2],target[3] + Random(-15,15)}
                IssueMove({acu},newPos)
            end
            WaitTicks(20)
        end
    end,

    ExpThread = function(self,unit)
        local target = table.copy(self.brain.intel.enemies[1])
        local hurt = false
        local lastPos
        local stationary = false
        while unit and (not unit.Dead) do
            local start = PROFILER:Now()
            local myPos = unit:GetPosition()
            if hurt then
                if unit:GetHealth()/unit:GetBlueprint().Defense.MaxHealth > 0.9 then
                    hurt = false
                    target = table.copy(self.brain.intel.enemies[1])
                    IssueClearCommands({unit})
                    IssueAggressiveMove({unit},target)
                elseif unit:IsIdleState() then
                    local newPos = {target[1] + Random(-20,20),target[2],target[3] + Random(-20,20)}
                    IssueAggressiveMove({unit},newPos)
                end
            else
                if unit:GetHealth()/unit:GetBlueprint().Defense.MaxHealth < 0.4 then
                    -- Check if we are hurt
                    hurt = true
                    target = table.copy(self.brain.intel.allies[1])
                    IssueClearCommands({unit})
                    IssueMove({unit},target)
                elseif VDist3(myPos, target) < 40 then
                    -- If near the target, move randomly
                    if unit:IsIdleState() then
                        local newPos = {target[1] + Random(-20,20),target[2],target[3] + Random(-20,20)}
                        IssueAggressiveMove({unit},newPos)
                    end
                elseif lastPos and VDist3(lastPos,myPos) < 1 then
                    stationary = true
                    IssueClearCommands({unit})
                    IssueAggressiveMove({unit},target)
                elseif stationary then
                    stationary = false
                    IssueClearCommands({unit})
                    IssueAggressiveMove({unit},target)
                end
            end
            lastPos = myPos
            PROFILER:Add("ExpThread",PROFILER:Now()-start)
            WaitTicks(20)
        end
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
})

LandGroup = Class({
    Init = function(self,brain,controller,id)
        self.brain = brain
        self.controller = controller
        self.id = id
        self.scout = nil
        self.stop = false

        -- Intel stuff
        self.threat = 0
        self.localThreat = 0
        self.localSupport = 0
        self.localThreatPos = nil
        self.zoneThreatAge = 0
        self.zoneThreat = 0
        self.collected = true

        self.units = {}
        self.reinforcing = {}
        self.targetZone = nil
        self.stagingZone = nil
        self.targetingCounter = 0
        self.confidence = 2.0
        self.attacking = true

        self.reinforceCounter = 0
        self.radius = 30

        self.size = 0
    end,

    Merge = function(self,other)
        for _, v in other.units do
            self:Add(v)
        end
        for _, v in other.reinforcing do
            self:Add(v)
        end
    end,

    AssaultDebuggingThread = function(self)
        local start = PROFILER:Now()
        while self.size > 0 and not self.stop do
            local myPos = self:Position()
            DrawCircle(myPos,table.getn(self.units),'aaffffff')
            if self.targetZone then
                DrawCircle(self.targetZone.pos,1+self.targetZone.intel.threat.land.enemy,'aaff4444')
                if self.attacking then
                    DrawLine(self.targetZone.pos,myPos,'aaff4444')
                else
                    DrawLine(self.targetZone.pos,myPos,'66444444')
                end
            end
            if self.stagingZone then
                DrawCircle(self.stagingZone.pos,1+self.localSupport,'aa44ff44')
                if not self.attacking then
                    DrawLine(self.stagingZone.pos,myPos,'aa44ff44')
                else
                    DrawLine(self.stagingZone.pos,myPos,'66444444')
                end
            end
            PROFILER:Add("AssaultDebuggingThread",PROFILER:Now()-start)
            WaitTicks(2)
            start = PROFILER:Now()
        end
    end,

    AssaultControlThread = function(self)
        local function crossp(vec1,vec2,n)
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
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
        local function SpreadIssueMove(unitgroup,location)
            local num=table.getn(unitgroup)
            local sum={0,0,0}
            for i,v in unitgroup do
                if not v or v.Dead then
                    continue
                end
                local pos = v:GetPosition()
                for k,v in sum do
                    sum[k]=sum[k] + pos[k]/num
                end
            end
            num=math.min(num,30)
            local loc1=crossp(sum,location,-num/VDist3(sum,location))
            local loc2=crossp(sum,location,num/VDist3(sum,location))
            for i,v in unitgroup do
                IssueMove({v},midpoint(loc1,loc2,i/num))
            end
        end
        WaitTicks(2)
        local start = PROFILER:Now()
        local clearing = 0
        local prompt = 0
        local oldID = -1
        self:ForkThread(self.OptimalTargetingRNG)
        self:ForkThread(self.ForceKiting)
        while self:Resize() > 0 and not self.stop do
            self:IntelCheck()
            local myPos = self:Reinforce()
            if not self.targetZone then
                self.controller.rematch = true
                self.attacking = false
            elseif (self.targetZone.id ~= oldID) or (prompt > 20) then
                if self.attacking then
                    IssueClearCommands(self.units)
                    SpreadIssueMove(self.units,self.targetZone.pos)
                    self.attacking = true
                else
                    IssueClearCommands(self.units)
                    SpreadIssueMove(self.units,self.stagingZone.pos)
                end
                prompt = 0
                oldID = self.targetZone.id
            else
                prompt = prompt + 1
            end
            -- If the target has higher threat than the whole group, find a new staging zone
            if self.targetZone and self.stagingZone then
                if self.attacking and (self.localSupport < self.targetZone.intel.threat.land.enemy) then
                    self.attacking = false
                    IssueClearCommands(self.units)
                    SpreadIssueMove(self.units,self.stagingZone.pos)
                elseif (not self.attacking) and (self.localSupport*self.confidence > self.targetZone.intel.threat.land.enemy) and self.collected then
                    self.attacking = true
                    IssueClearCommands(self.units)
                    SpreadIssueMove(self.units,self.targetZone.pos)
                end
                
                if VDist3(myPos,self.targetZone.pos) < 10 then
                    if (not self.localThreatPos) then
                        self.controller.rematch = true
                        clearing = 2
                    else
                        clearing = clearing - 1
                        if (clearing <= 0) and self.localThreatPos then
                            IssueClearCommands(self.units)
                            IssueAggressiveMove(self.units,self.localThreatPos)
                            clearing = 5
                        end
                    end
                end
            end
            -- Dodge local enemies
            -- TODO
            PROFILER:Add("AssaultControlThread",PROFILER:Now()-start)
            WaitTicks(10)
            if self.forcekiting then
                WaitTicks(15)
            end
            while self.COMMTARGET do
                WaitTicks(2)
            end
            start = PROFILER:Now()
        end
    end,

    ForceKiting = function(self)
        local function GetWeightedHealthRatio(unit)
            if unit.MyShield then
                return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
            else
                return unit:GetHealthPercent()
            end
        end
        local function GetTrueHealth(unit,total)
            if total then
                if unit.MyShield then
                    return (unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
                else
                    return unit:GetMaxHealth()
                end
            else
                if unit.MyShield then
                    return (unit.MyShield:GetHealth()+unit:GetHealth())
                else
                    return unit:GetHealth()
                end
            end
        end
        local function DistancePredict(target,time)
            local vel={}
            vel[1],vel[2],vel[3]=target:GetVelocity()
            local pos=target:GetPosition()
            local dest={}
            for k,v in vel do
                dest[k]=pos[k]+v*time
            end
            return dest
        end
        local function crossp(vec1,vec2,n)
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
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
        local function SimpleTarget(self,aiBrain)
            local function ViableTargetCheck(unit)
                if unit.Dead or not unit then return false end
                local targetpos=unit:GetPosition()
                if self.MovementLayer=='Amphibious' then
                    for _,v in self.units do
                        if v and not v.Dead then
                            return MAP:CanPathTo2(self:Position(),targetpos,"surf")
                        end
                    end
                else
                    if GetTerrainHeight(targetpos[1],targetpos[3])<GetSurfaceHeight(targetpos[1],targetpos[3]) then
                        return false
                    else
                        for _,v in self.units do
                            if v and not v.Dead then
                                return MAP:CanPathTo2(self:Position(),targetpos,"surf")
                            end
                        end
                    end
                end
            end
            local platoon=self
            local id=platoon.chpdata.id
            local position=self:Position()
            local targets=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, position, self.MaxWeaponRange+10, 'Enemy')
            platoon.targetcandidates={}
            for i,unit in platoon.targetcandidates do
                if ViableTargetCheck(unit) then 
                    table.insert(platoon.targetcandidates,unit) 
                else
                    continue
                end
                if not unit.chppriority then unit.chppriority={} unit.chpdistance={} end
                if not unit.dangerupdate or GetGameTimeSeconds()-unit.dangerupdate>10 then
                    unit.chpdanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unit:GetPosition(),30).enemy)
                    unit.dangerupdate=GetGameTimeSeconds()
                end
                if not unit.chpvalue then unit.chpvalue=unit:GetBlueprint().Economy.BuildCostMass/GetTrueHealth(unit) end
                unit.chpworth=unit.chpvalue/GetTrueHealth(unit)
                unit.chpdistance[id]=VDist3(position,unit:GetPosition())
                unit.chppriority[id]=unit.chpworth/math.max(30,unit.chpdistance[id])/unit.chpdanger
            end
            if table.getn(platoon.targetcandidates)<1 then 
                return false
            else
                return true
            end
        end
        local function VariableKite(self,unit,target)
            local function KiteDist(pos1,pos2,distance,healthmod)
                local vec={}
                local dist=VDist3(pos1,pos2)
                distance=distance*(1-healthmod)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel={}
                vel[1],vel[2],vel[3]=target:GetVelocity()
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            local function GetRoleMod(unit)
                local healthmod=10
                if unit.Role=='Heavy' or unit.Role=='Bruiser' then
                    healthmod=50
                end
                local ratio=GetWeightedHealthRatio(unit)
                healthmod=healthmod*ratio*ratio
                return healthmod/100
            end
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=0
            local healthmod=GetRoleMod(unit)
            local strafemod=3
            if CheckRetreat(pos,tpos,target) then
                mod=5
            end
            if unit.Role=='Heavy' or unit.Role=='Bruiser' or unit.GlassCannon then
                strafemod=7
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            end
            if VDist3Sq(pos,dest)>6 then
                IssueClearCommands({unit})
                IssueMove({unit},dest)
                return
            else
                return
            end
        end
        local function SimpleCombat(self,aiBrain)
            local units=self.units
            for _,v in units do
                if v.Dead or not v then continue end
                table.sort(self.targetcandidates,function(a,b) return VDist3Sq(v:GetPosition(),a:GetPosition())*a.chpworth<VDist3Sq(v:GetPosition(),b:GetPosition())*b.chpworth end)
                local target=self.targetcandidates[1]
                if VDist3Sq(v:GetPosition(),target:GetPosition())>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                    IssueClearCommands({v}) 
                    IssueMove({v},target:GetPosition())
                    continue
                end
                VariableKite(self,v,target)
            end
        end
        if self.ktaken then return end
        self.ktaken=true
        local aiBrain = self.brain.aiBrain
        local platoonUnits = self.units
        while not self.stop do
            local com=aiBrain:GetUnitsAroundPoint(categories.COMMAND,self:Position(),self.MaxWeaponRange*2,'Enemy')
            if table.getn(com)>0 then
                while table.getn(self.units)*100>GetTrueHealth(com[1]) do
                    --ENGAGE DEATH SQUAD
                    self.COMMTARGET=true
                    IssueClearCommands(self.units)
                    IssueMove(self.units,DistancePredict(com[1],5))
                    WaitTicks(5)
                end
                self.COMMTARGET=false
            end
            if self.attacking and SimpleTarget(self,aiBrain) then
                self.forcekiting=true
                SimpleCombat(self,aiBrain)
            elseif SimpleTarget(self,aiBrain) then
                self.forcekiting=false
                SimpleCombat(self,aiBrain)
            else
                self.forcekiting=false
            end
            WaitTicks(20)
        end
    end,

    OptimalTargetingRNG = function(self)
        if self.ttaken then return end
        local function UnitInitialize(self)
            local platoon=self
            local platoonUnits=self.units
            for _,v in platoonUnits do
                if v.Dead then continue end
                if not v.chpinitialized then
                    v.chpinitialized=true
                    if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                        v.Role='Artillery'
                    elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                        v.Role='Experimental'
                    elseif EntityCategoryContains(categories.SILO,v) then
                        v.Role='Silo'
                    elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                        v.Role='Heavy'
                    elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                        v.Role='Sniper'
                        if EntityCategoryContains(categories.ual0201,v) then
                            v.GlassCannon=true
                        end
                    elseif EntityCategoryContains(categories.SCOUT,v) then
                        v.Role='Scout'
                    elseif EntityCategoryContains(categories.ANTIAIR,v) then
                        v.Role='AA'
                    elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                        v.Role='Bruiser'
                    elseif EntityCategoryContains(categories.SHIELD,v) then
                        v.Role='Shield'
                    end
                    for _, weapon in v:GetBlueprint().Weapon or {} do
                        if not (weapon.RangeCategory == 'UWRC_DirectFire') then continue end
                        if not v.MaxWeaponRange or v.MaxRadius > v.MaxWeaponRange then
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                    end
                    if not v.MaxWeaponRange then
                        continue
                    end
                    if not platoon.MaxWeaponRange or v.MaxWeaponRange>platoon.MaxWeaponRange then
                        platoon.MaxWeaponRange=v.MaxWeaponRange
                    end
                end
            end
            if not self.MaxWeaponRange then 
                self.MaxWeaponRange=30
            end
            for _,v in platoonUnits do
                if not v.MaxWeaponRange then
                    v.MaxWeaponRange=self.MaxWeaponRange
                end
            end
        end
        --CREDIT AZROC HOLY SHIT THIS ENTIRE IDEA WAS HIS I JUST MADE THE FUNCTION-CHP2001
        LOG('starting targeting')
        local aiBrain = self.brain.aiBrain
        local platoonUnits = self.units
        local platoon=self
        if not platoon.chpdata then platoon.chpdata={} end
        if not platoon.chpdata.id then platoon.chpdata.id=platoon.units[1].Sync.id end
        platoon.ttaken=true
        local enemyunits=nil
        while not self.stop do
            UnitInitialize(self)
            local com=aiBrain:GetUnitsAroundPoint(categories.COMMAND,self:Position(),self.MaxWeaponRange*2 or 60,'Enemy')
            platoonUnits = self.units
            platoon.Pos=self:Position()
            enemyunits=aiBrain:GetUnitsAroundPoint(categories.SELECTABLE-categories.WALL-categories.MOBILE*categories.AIR,platoon.Pos,platoon.MaxWeaponRange*2,'Enemy')
            for i,v in enemyunits do
                if v.Dead or not v or not v:GetFractionComplete()==1 then 
                    table.remove(enemyunits,i) 
                    continue 
                end
                v.worth=v:GetBlueprint().Economy.BuildCostMass
                v.health=v:GetHealth()
            end
            table.sort(enemyunits,function(a,b) return VDist3Sq(platoon.Pos,a:GetPosition())*math.pow(a:GetHealth(),2)/a.worth<VDist3Sq(platoon.Pos,b:GetPosition())*math.pow(b:GetHealth(),2)/a.worth end)
            if table.getn(enemyunits)>1 then
                for _,v in platoonUnits do
                    if not v or v.Dead then continue end
                    for x = 1, v:GetWeaponCount() do
                        local weapon = v:GetWeapon(x)
                        --LOG('weapon is '..repr(weapon))
                        local bp = weapon:GetBlueprint()
                        local damage=bp.Damage
                        local instakills = {}
                        if bp.WeaponCategory=='Anti Air' or bp.WeaponCategory=='Death' then continue end
                        if self.COMMTARGET then
                            if com[1] and not com[1].Dead then
                                weapon:SetTargetEntity(com[1])
                                self:ForkThread(self.ShowUnitWeaponTargetRNG,v,weapon,com[1])
                                continue
                            end
                        end
                        for i,target in enemyunits do
                            if not target or target.Dead then continue end
                            if VDist3Sq(target:GetPosition(),v:GetPosition())>bp.MaxRadius*bp.MaxRadius then continue end
                            if target.health<=0 then
                                table.remove(enemyunits,i)
                                continue
                            end
                            if target.health<=damage*0.9 then
                                table.insert(instakills,target)
                            end
                        end
                        if table.getn(instakills)>0 then
                            table.sort(instakills,function(a,b) return VDist3Sq(platoon.Pos,a:GetPosition())/math.pow(a:GetHealth()*a.worth,2)<VDist3Sq(platoon.Pos,b:GetPosition())/math.pow(b:GetHealth()*b.worth,2) end)
                            for i,target in instakills do
                                if not target or target.Dead then continue end
                                if VDist3Sq(target:GetPosition(),v:GetPosition())>bp.MaxRadius*bp.MaxRadius then continue end
                                weapon:SetTargetEntity(target)
                                self:ForkThread(self.ShowUnitWeaponTargetRNG,v,weapon,target)
                                target.health=target.health-bp.Damage*0.9
                                break
                            end
                        else
                            for i,target in enemyunits do
                                if not target or target.Dead then continue end
                                if VDist3Sq(target:GetPosition(),v:GetPosition())>bp.MaxRadius*bp.MaxRadius then continue end
                                weapon:SetTargetEntity(target)
                                self:ForkThread(self.ShowUnitWeaponTargetRNG,v,weapon,target)
                                target.health=target.health-bp.Damage*0.9
                                break
                            end
                        end
                    end
                end
            end
            WaitTicks(20)
        end
    end,

    ShowUnitWeaponTargetRNG = function(self, unit, weapon, target)
        -- Show a line to the target from the weapon for a short time
        local display=false
        if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
            display=true
        end
        for _=0,10 do
            if unit.Dead then return end
            if target and not target.Dead then
                weapon:SetTargetEntity(target)
                if display then
                    DrawLinePop(unit:GetPosition(),target:GetPosition(),'ddFF0000')
                end
            end
            WaitTicks(2)
        end
    end,

    DangerAt = function(self,pos,radius)
        local enemyUnits = self.brain.aiBrain:GetUnitsAroundPoint(categories.ALLUNITS-categories.WALL,pos,radius,'Enemy')
        local neutralUnits = self.brain.aiBrain:GetUnitsAroundPoint(categories.ALLUNITS-categories.WALL,pos,radius,'Enemy')
        local dangerEnemy = self.brain.intel:GetLandThreatAndPos(enemyUnits)
        local dangerNeutral = self.brain.intel:GetLandThreatAndPos(neutralUnits)
        if dangerEnemy.pos and dangerNeutral.pos then
            return { threat = dangerEnemy.threat + dangerNeutral.threat, pos = VMult(VAdd(dangerEnemy.pos,dangerNeutral.pos),0.5)}
        elseif dangerNeutral.pos then
            return dangerNeutral
        else
            return dangerEnemy
        end
    end,

    IntelCheck = function(self)
        if self.targetZone then
            local myPos = self:Position()
            local nextPos = self.controller:BiasLocation(myPos,self.targetZone.pos,math.min(20,VDist3(myPos,self.targetZone.pos)))
            local threat = self:DangerAt(nextPos,40)
            self.threat = self.brain.intel:GetLandThreat(self.units)
            self.localThreat = threat.threat
            self.localSupport = math.max(self.brain.intel:GetLandThreat(self.brain.aiBrain:GetUnitsAroundPoint(categories.ALLUNITS-categories.WALL,myPos,40,'Ally')),
                                         self.brain.intel:GetLandThreat(self.brain.aiBrain:GetUnitsAroundPoint(categories.ALLUNITS-categories.WALL,nextPos,60,'Ally'))/1.5)
            self.localThreatPos = threat.pos
            if (self.zoneThreatAge >= 10) or (self.zoneThreat < self.targetZone.control.land.enemy) then
                self.zoneThreatAge = 0
                self.zoneThreat = self.targetZone.control.land.enemy
            else
                self.zoneThreatAge = self.zoneThreatAge + 1
            end
        end
        self.collected = table.getn(self.units) > 2*table.getn(self.reinforcing)
    end,

    Add = function(self,unit)
        -- Add unit, issue initial orders
        if EntityCategoryContains(categories.SCOUT,unit) then
            self.scout = unit
        end
        table.insert(self.reinforcing,unit)
        self.size = self.size + 1
        if self.targetZone then
            IssueClearCommands({unit})
            IssueAggressiveMove({unit}, self.targetZone.pos)
        end
    end,

    Position = function(self)
        local x = 0
        local z = 0
        local n = 0
        for _, v in self.units do
            if v and (not v.Dead) then
                local pos = v:GetPosition()
                x = x + pos[1]
                z = z + pos[3]
                n = n+1
            end
        end
        if n == 0 then
            -- We're in our base maybe?????
            return self.brain.intel.allies[1]
        else
            return {x/n, GetSurfaceHeight(x/n,z/n), z/n}
        end
    end,

    Reinforce = function(self)
        -- Move units from reinforcing into units
        if table.getn(self.units) == 0 then
            self.units = self.reinforcing
            self.reinforcing = {}
            if self.targetZone then
                IssueClearCommands(self.units)
                IssueMove(self.units,self.targetZone.pos)
            end
            return self:Position()
        else
            local currentPos = self:Position()
            local moved = {}
            local i = 1
            while i <= table.getn(self.reinforcing) do
                if VDist3(self.reinforcing[i]:GetPosition(),currentPos) < self.radius then
                    table.insert(moved,self.reinforcing[i])
                    table.insert(self.units,self.reinforcing[i])
                    table.remove(self.reinforcing,i)
                else
                    i = i+1
                end
            end
            if (not self.attacking) and self.stagingZone then
                IssueClearCommands(moved)
                IssueMove(moved,self.stagingZone.pos)
            elseif self.attacking and self.targetZone then
                IssueClearCommands(moved)
                IssueMove(moved,self.targetZone.pos)
            end
            local newPos = self:Position()
            -- IssueMove reinforcing to new position
            if self.reinforceCounter == 0 then
                IssueClearCommands(self.reinforcing)
                IssueAggressiveMove(self.reinforcing,newPos)
                self.reinforceCounter = 5
            else
                self.reinforceCounter = self.reinforceCounter - 1
            end
            -- Return new position
            return newPos
        end
    end,

    Resize = function(self)
        -- Eliminate dead units, return new size
        local i = 1
        while i <= table.getn(self.units) do
            if (not self.units[i]) or self.units[i].Dead then
                table.remove(self.units,i)
            else
                i = i+1
            end
        end
        local j = 1
        while j <= table.getn(self.reinforcing) do
            if (not self.reinforcing[j]) or self.reinforcing[j].Dead then
                table.remove(self.reinforcing,j)
            else
                j = j+1
            end
        end
        self.size = table.getn(self.units) + table.getn(self.reinforcing)
        return self.size
    end,

    Size = function(self)
        -- Return size
        return self.size
    end,

    Run = function(self)
        self:ForkThread(self.AssaultControlThread)
        self:ForkThread(self.AssaultDebuggingThread)
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
})

AirController = Class({
    Init = function(self,brain)
        self.brain = brain
        self.groups = {}
        self.groupID = 1
    end,

    Run = function(self)
        self:ForkThread(self.AirControlThread)
    end,

    CreateGroup = function(self,unit)
        local ag = IntieGroup()
        ag:Init(self.brain,self,self.groupID)
        self.groupID = self.groupID + 1
        self.groups = {}
        table.insert(self.groups,ag)
        ag:Add(unit)
        ag:Run()
    end,

    CheckGroups = function(self)
        -- Delete dead groups
        local i = 1
        while i <= table.getn(self.groups) do
            if self.groups[i]:Size() == 0 then
                table.remove(self.groups,i)
            else
                i = i+1
            end
        end
    end,

    FindGroup = function(self,unit)
        -- Add this unit to a relevant group
        local best
        local bestPriority = 0
        for _, v in self.groups do
            local priority = v.size
            if (not best) or priority < bestPriority then
                best = v
                bestPriority = priority
            end
        end
        if (not best) then
            -- Huh??
            WARN("UnitController: Failed to find group...  creating a new one.")
            self:CreateGroup(unit)
        else
            best:Add(unit)
        end
    end,

    ScoutingThread = function(self,scout)
        local targetZone
        while scout and (not scout.Dead) do
            local myPos = scout:GetPosition()
            if (not targetZone) or (VDist2(myPos[1],myPos[3],targetZone.pos[1],targetZone.pos[3]) < 30) or scout:IsIdleState() then
                targetZone = nil
                local bestScore = 0
                for _, v in self.brain.intel.zones do
                    local dist = VDist2(myPos[1],myPos[3],v.pos[1],v.pos[3])
                    local r = Random(100,1000)
                    if (r > bestScore) and (dist >= 50) then
                        targetZone = v
                        bestScore = r
                    elseif (not targetZone) and (dist < 50) then
                        targetZone = v
                    end
                end
                -- Select new target zone and move there
                IssueClearCommands({scout})
                IssueMove({scout},targetZone.pos)
            end
            WaitTicks(10)
        end
    end,

    AirControlThread = function(self)
        while self.brain:IsAlive() do
            self:CheckGroups()
            local units = self.brain.aiBrain:GetListOfUnits(categories.AIR * categories.MOBILE - categories.ENGINEER,false,true)
            local numUnits = table.getn(units)
            local targetNumberOfGroups = 1 + math.floor((math.sqrt(numUnits/10))+0.1)
            local numGroups = table.getn(self.groups)
            for _, unit in units do
                if not unit.CustomData then
                    unit.CustomData = {}
                end
                if (not unit.CustomData.airAssigned) and (not unit:IsBeingBuilt()) then
                    unit.CustomData.airAssigned = true
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        self:ForkThread(self.ScoutingThread,unit)
                    end
                    if numGroups < targetNumberOfGroups then
                        -- Create group
                        self:CreateGroup(unit)
                        numGroups = numGroups + 1
                    else
                        -- Add to group
                        self:FindGroup(unit)
                    end
                end
            end
            WaitTicks(20)
        end
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
})

IntieGroup = Class({
    Init = function(self,brain,controller,id)
        self.brain = brain
        self.controller = controller
        self.id = id

        self.units = {}
        self.size = 0
    end,

    InterceptionThread = function(self)
        local targetZone = nil
        local waiting = false
        while self:Resize() > 0 do
            if (not targetZone) or (self.units[1]:IsIdleState() and (not waiting)) or (targetZone.intel.threat.land.allied < targetZone.intel.threat.land.enemy) then
                targetZone = nil
                local bestThreat = 0
                local bestSafety = 0
                for _, v in self.brain.intel.zones do
                    local r = Random(1,100)
                    if (v.intel.threat.land.allied > v.intel.threat.land.enemy) and v.control.air.enemy > bestThreat then
                        targetZone = v
                        bestThreat = v.intel.threat.air.enemy
                        waiting = false
                    elseif (bestThreat == 0) and (r > bestSafety) then
                        bestSafety = r
                        targetZone = v
                        waiting = true
                    end
                end
                if targetZone then
                    IssueClearCommands(self.units)
                    IssueAggressiveMove(self.units,targetZone.pos)
                end
            end
            WaitTicks(20)
        end
    end,

    Add = function(self,unit)
        table.insert(self.units,unit)
        self.size = self.size + 1
    end,

    Run = function(self)
        self:ForkThread(self.InterceptionThread)
    end,

    Resize = function(self)
        local i = 1
        while i <= table.getn(self.units) do
            if self.units[i] and (not self.units[i].Dead) then
                i = i+1
            else
                table.remove(self.units,i)
            end
        end
        self.size = table.getn(self.units)
        return self.size
    end,

    Size = function(self)
        return self.size
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
})
