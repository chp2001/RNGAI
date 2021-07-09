local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local PROFILER = import('/mods/TechAI/lua/AI/DilliDalli/Profiler.lua').GetProfiler()
local MAP = import('/mods/TechAI/lua/AI/DilliDalli/Mapping.lua').GetMap()
local ADJ = import('/mods/TechAI/lua/AI/AdvancedAdjacency.lua')
function WaitingOnCommands(cmds)
    for _, cmd in cmds do
        if not IsCommandDone(cmd) then
            return true
        end
    end
    return false
end

function FindLocation(aiBrain, baseManager, intelManager, blueprint, location, radius, locationBias, job)
    -- Fuck having this as a dependency: aiBrain:FindPlaceToBuild
    -- It is so miserably complex to call that I'm going to roll my own version right here. Fight me.

    local startTime = PROFILER:Now()
    local chplocation=ADJ.DoAdvancedAdjacency(aiBrain, baseManager, intelManager, blueprint, location, radius, locationBias, job)
    if chplocation then
        return chplocation
    end
    -- Step 1: Identify starting location
    local targetLocation
    -- TODO: detect this dynamically
    local buildRadius = 10
    if locationBias == "enemy" then
        -- Bias location towards nearby enemy structures
    elseif locationBias == "centre" then
        -- Bias location towards the centre of the map
        local dx = intelManager.centre[1] - location[1]
        local dz = intelManager.centre[3] - location[3]
        local norm = math.sqrt(dx*dx+dz*dz)
        local x = math.floor(location[1]+(dx*buildRadius)/(norm*2)+Random(-1,1))+0.5
        local z = math.floor(location[3]+(dz*buildRadius)/(norm*2)+Random(-1,1))+0.5
        targetLocation = {x,GetSurfaceHeight(x,z),z}
    elseif locationBias == "defence" then
        -- Bias location defensively, taking into account similar units
    else
        local x = math.floor(location[1]+Random(-5,5))+0.5
        local z = math.floor(location[3]+Random(-5,5))+0.5
        targetLocation = {x,GetSurfaceHeight(x,z),z}
    end
    -- Step 2: Iterate through candidate locations in order
    local start = table.copy(targetLocation)
    local ring = 0
    local ringSize = 0
    local ringIndex = 0
    local iterations = 0
    local result
    local maxIterations = 100000 -- 300x300 square
    while iterations < maxIterations do
        iterations = iterations + 1
        if aiBrain:CanBuildStructureAt(blueprint.BlueprintId,targetLocation) and MAP:CanPathTo2(location,targetLocation,"surf")
                                                                             and baseManager:LocationIsClear(targetLocation,blueprint) then
            -- TODO add adjacency check support
            PROFILER:Add("FindLocation",PROFILER:Now()-startTime)
            return targetLocation
        end
        -- Update targetLocation
        if ringIndex == ringSize then
            ring = ring+1
            ringIndex = 0
            ringSize = 8*ring
            local x = start[1]+ring
            local z = start[3]+ring
            targetLocation = {x,GetSurfaceHeight(x,z),z}
        else
            local x = targetLocation[1]
            local z = targetLocation[3]
            if ringIndex < 2*ring then
                -- Move up
                z = z-1
            elseif ringIndex < ring*4 then
                -- Move left
                x = x-1
            elseif ringIndex < ring*6 then
                -- Move down
                z = z+1
            else
                -- Move right
                x = x+1
            end
            ringIndex = ringIndex + 1
            targetLocation = {x,GetSurfaceHeight(x,z),z}
        end
    end
    PROFILER:Add("FindLocation",PROFILER:Now()-startTime)
    return result
end

function EngineerBuildStructure(brain,engie,structure,location,radius,job)
    local aiBrain = engie:GetAIBrain()
    local bp = aiBrain:GetUnitBlueprint(structure)
    if not location then
        location = engie:GetPosition()
        radius = 40
    end
    -- This gets profiled separately
    local pos = FindLocation(aiBrain,brain.base,brain.intel,bp,location,radius,"centre",job)
    if pos then
        local start = PROFILER:Now()
        -- Clear any existing commands
        IssueClearCommands({engie})
        -- Now issue build command
        -- I need a unique token.  This is unique with high probability (0,2^30 - 1).
        local constructionID = Random(0,1073741823)
        brain.base:BaseIssueBuildMobile({engie},pos,bp,constructionID,structure)
        PROFILER:Add("EngineerBuildStructure",PROFILER:Now()-start)
        WaitTicks(2)
        start = PROFILER:Now()
        while engie and (not engie.Dead) and table.getn(engie:GetCommandQueue()) > 0 do
            PROFILER:Add("EngineerBuildStructure",PROFILER:Now()-start)
            WaitTicks(2)
            start = PROFILER:Now()
        end
        brain.base:BaseCompleteBuildMobile(constructionID,engie)
        PROFILER:Add("EngineerBuildStructure",PROFILER:Now()-start)
        return true
    else
        WARN("Failed to find position to build: "..tostring(structure))
        IssueMove({engie},{brain.intel.centre[1],GetSurfaceHeight(brain.intel.centre[1],brain.intel.centre[2]),brain.intel.centre[2]})
        WaitTicks(10)
        return false
    end
end

function EngineerFinishStructure(brain,engie,job)
    local aiBrain = engie:GetAIBrain()
    -- This gets profiled separately
    local unfinishedUnits = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, engie:GetPosition(), 30, 'Ally')
    local target=nil
    for k,v in unfinishedUnits do
        local FractionComplete = v:GetFractionComplete()
        if FractionComplete < 1 and table.getn(v:GetGuards()) < 1 then
            if not v.Dead and not v:BeenDestroyed() then
                target=v
                break
            end
        end
    end
    if target then
        local start = PROFILER:Now()
        -- Clear any existing commands
        IssueClearCommands({engie})
        -- Now issue build command
        -- I need a unique token.  This is unique with high probability (0,2^30 - 1).
        IssueRepair({engie},target)
        PROFILER:Add("EngineerFinishStructure",PROFILER:Now()-start)
        WaitTicks(2)
        start = PROFILER:Now()
        while engie and (not engie.Dead) and table.getn(engie:GetCommandQueue()) > 0 do
            PROFILER:Add("EngineerFinishStructure",PROFILER:Now()-start)
            WaitTicks(2)
            start = PROFILER:Now()
        end
        PROFILER:Add("EngineerFinishStructure",PROFILER:Now()-start)
        return true
    else
        --WARN("Failed to find position to build: "..tostring(structure))
        IssueMove({engie},{brain.intel.centre[1],GetSurfaceHeight(brain.intel.centre[1],brain.intel.centre[2]),brain.intel.centre[2]})
        WaitTicks(10)
        return false
    end
end

function EngineerBuildMarkedStructure(brain,engie,structure,markerType)
    local aiBrain = engie:GetAIBrain()
    local bp = aiBrain:GetUnitBlueprint(structure)
    -- This thing gets profiled separately
    local pos = brain.intel:FindNearestEmptyMarker(engie:GetPosition(),markerType).position
    if pos then
        local start = PROFILER:Now()
        IssueClearCommands({engie})
        -- I need a unique token.  This is unique with high probability (0,2^30 - 1).
        local constructionID = Random(0,1073741823)
        brain.base:BaseIssueBuildMobile({engie},pos,bp,constructionID,structure)
        PROFILER:Add("EngineerBuildMarkedStructure",PROFILER:Now()-start)
        WaitTicks(2)
        start = PROFILER:Now()
        while engie and (not engie.Dead) and table.getn(engie:GetCommandQueue()) > 0 do
            PROFILER:Add("EngineerBuildMarkedStructure",PROFILER:Now()-start)
            WaitTicks(2)
            start = PROFILER:Now()
        end
        brain.base:BaseCompleteBuildMobile(constructionID,engie)
        if (not engie) or engie.Dead then
            PROFILER:Add("EngineerBuildMarkedStructure",PROFILER:Now()-start)
            return true
        end
        local target = brain.intel:GetEnemyStructure(pos)
        if target then
            IssueReclaim({engie},target)
            brain.base:BaseIssueBuildMobile({engie},pos,bp,constructionID,structure)
            while engie and (not engie.Dead) and table.getn(engie:GetCommandQueue()) > 0 do
                PROFILER:Add("EngineerBuildMarkedStructure",PROFILER:Now()-start)
                WaitTicks(2)
                start = PROFILER:Now()
            end
            brain.base:BaseCompleteBuildMobile(constructionID,engie)
        end
        PROFILER:Add("EngineerBuildMarkedStructure",PROFILER:Now()-start)
        return true
    else
        -- TODO: debug why this sometimes happens
        WARN("Failed to find position for markerType: "..tostring(markerType))
        WaitTicks(2)
        return false
    end
end

function EngineerAssist(engie,target)
    local start = PROFILER:Now()
    IssueClearCommands({engie})
    IssueGuard({engie},target)
    PROFILER:Add("EngineerAssist",PROFILER:Now()-start)
    WaitTicks(2)
    start = PROFILER:Now()
    while target and (not target.Dead) and engie and (not engie.Dead) and (not engie.CustomData.assistComplete) do
        PROFILER:Add("EngineerAssist",PROFILER:Now()-start)
        WaitTicks(2)
        start = PROFILER:Now()
    end
    if engie and (not engie.Dead) then
        -- Reset this engie
        IssueClearCommands({engie})
        engie.CustomData.assistComplete = nil
    end
    PROFILER:Add("EngineerAssist",PROFILER:Now()-start)
end

function FactoryBuildUnit(fac,unit)
    local start = PROFILER:Now()
    IssueClearCommands({fac})
    IssueBuildFactory({fac},unit,1)
    PROFILER:Add("FactoryBuildUnit",PROFILER:Now()-start)
    WaitTicks(1)
    start = PROFILER:Now()
    while fac and not fac.Dead and not fac:IsIdleState() do
        -- Like, I know this is hammering something but you can't afford to wait on facs.
        -- In the future I want to queue up stuff properly, but for now just deal with it.
        PROFILER:Add("FactoryBuildUnit",PROFILER:Now()-start)
        WaitTicks(1)
        start = PROFILER:Now()
    end
    PROFILER:Add("FactoryBuildUnit",PROFILER:Now()-start)
end