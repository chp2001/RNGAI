--[[
    File    :   /lua/AI/AIBaseTemplates/EconomyBuildConditions.lua
    Author  :   relentless
    Summary :
        Economy Build Conditions
]]
WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset EconomyBuildConditions.lua' )
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

function GreaterThanEconStorageRatioRNG(aiBrain, mStorageRatio, eStorageRatio, mult)

    if aiBrain.EnemyIntel.ChokeFlag then
        if mult == 'LAND' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.20 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif mult == 'FACTORY' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.10 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif mult == 'DEFENSE' then
            if GetEconomyStoredRatio(aiBrain, 'MASS') >= 0.20 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= 0.80 then
                return true
            end
        elseif GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif aiBrain.UpgradeMode == 'Aggressive' then
        if GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio * 1.5 and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif mult == true then
        if GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio * aiBrain.EcoManager.EcoMultiplier and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
            return true
        end
    elseif GetEconomyStoredRatio(aiBrain, 'MASS') >= mStorageRatio and GetEconomyStoredRatio(aiBrain, 'ENERGY') >= eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEconTrendRNG(aiBrain, MassTrend, EnergyTrend)

    if GetEconomyTrend(aiBrain, 'MASS') >= MassTrend and GetEconomyTrend(aiBrain, 'ENERGY') >= EnergyTrend then
        return true
    end
    return false
end

function GreaterThanEnergyTrendRNG(aiBrain, eTrend)

    if GetEconomyTrend(aiBrain, 'ENERGY') > eTrend then
        --LOG('Greater than Energy Trend Returning True : '..econ.EnergyTrend)
        return true
    else
        --LOG('Greater than Energy Trend Returning False : '..econ.EnergyTrend)
        return false
    end
end

function GreaterThanMassTrendRNG(aiBrain, mTrend)

    if GetEconomyTrend(aiBrain, 'MASS') > mTrend then
        return true
    else
        return false
    end
end

function LessThanMassTrendRNG(aiBrain, mTrend)

    if GetEconomyTrend(aiBrain, 'MASS') < mTrend then
        return true
    else
        return false
    end
end

--            { EBC, 'LessThanEnergyTrendRNG', { 50.0 } },
function LessThanEnergyTrendRNG(aiBrain, eTrend)

    if GetEconomyTrend(aiBrain, 'ENERGY') < eTrend then
        return true
    else
        return false
    end
end
-- not used yet
function GreaterThanEconEfficiencyOverTimeRNG(aiBrain, MassEfficiency, EnergyEfficiency)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    --LOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= MassEfficiency and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --LOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --LOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function LessThanEnergyEfficiencyOverTimeRNG(aiBrain, EnergyEfficiency)

    if aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime <= EnergyEfficiency then
        return true
    end
    return false
end

function GreaterThanEconTrendOverTimeRNG(aiBrain, MassTrend, EnergyTrend)
    -- Using eco over time values from the EconomyOverTimeRNG thread.
    --LOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (aiBrain.EconomyOverTimeCurrent.MassTrendOverTime >= MassTrend and aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime >= EnergyTrend) then
        --LOG('GreaterThanEconTrendOverTime Returned True')
        return true
    end
    --LOG('GreaterThanEconTrendOverTime Returned False')
    return false
end

function GreaterThanEconEfficiencyRNG(aiBrain, MassEfficiency, EnergyEfficiency)

    local EnergyEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyRequested(aiBrain,'ENERGY'), 2)
    local MassEfficiencyOverTime = math.min(GetEconomyIncome(aiBrain,'MASS') / GetEconomyRequested(aiBrain,'MASS'), 2)
    --LOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --LOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --LOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function GreaterThanEconStorageCurrentRNG(aiBrain, mStorage, eStorage)

    if (GetEconomyStored(aiBrain, 'MASS') >= mStorage and GetEconomyStored(aiBrain, 'ENERGY') >= eStorage) then
        return true
    end
    return false
end

-- { UCBC, 'EnergyToMassRatioIncomeRNG', { 10.0, '>=',true } },  -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
function EnergyToMassRatioIncomeRNG(aiBrain, ratio, compareType)

    return CompareBody(GetEconomyIncome(aiBrain,'ENERGY') / GetEconomyIncome(aiBrain,'MASS'), ratio, compareType)
end

function GreaterThanEconIncomeRNG(aiBrain, mIncome, eIncome)

    if (GetEconomyIncome(aiBrain,'MASS') >= mIncome and GetEconomyIncome(aiBrain,'ENERGY') >= eIncome) then
        return true
    end
    return false
end

function GreaterThanMassIncomeToFactoryRNG(aiBrain, t1Drain, t2Drain, t3Drain)

    # T1 Test
    local testCat = categories.TECH1 * categories.FACTORY
    local unitCount = aiBrain:GetCurrentUnits(testCat)
    # Find units of this type being built or about to be built
    unitCount = unitCount + aiBrain:GetEngineerManagerUnitsBeingBuilt(testCat)

    local massTotal = unitCount * t1Drain

    # T2 Test
    testCat = categories.TECH2 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits(testCat)

    massTotal = massTotal + (unitCount * t2Drain)

    # T3 Test
    testCat = categories.TECH3 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits(testCat)

    massTotal = massTotal + (unitCount * t3Drain)

    if not CompareBody((aiBrain.EconomyOverTimeCurrent.MassIncome * 10), massTotal, '>') then
        --LOG('MassToFactoryRatio false')
        --LOG('aiBrain.EconomyOverTimeCurrent.MassIncome * 10 : '..(aiBrain.EconomyOverTimeCurrent.MassIncome * 10))
        --LOG('Factory massTotal : '..massTotal)
        return false
    end
    --LOG('MassToFactoryRatio true')
    --LOG('aiBrain.EconomyOverTimeCurrent.MassIncome * 10 : '..(aiBrain.EconomyOverTimeCurrent.MassIncome * 10))
    --LOG('Factory massTotal : '..massTotal)
    return true
end

function MassToFactoryRatioBaseCheckRNG(aiBrain, locationType)
    local factoryManager = aiBrain.BuilderManagers[locationType].FactoryManager
    if not factoryManager then
        WARN('*AI WARNING: FactoryCapCheck - Invalid location - ' .. locationType)
        return false
    end

    local t1
    local t2
    local t3
    if aiBrain.CheatEnabled then
        t1 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T1Value or 8) * tonumber(ScenarioInfo.Options.BuildMult)
        t2 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T2Value or 20) * tonumber(ScenarioInfo.Options.BuildMult)
        t3 = (aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T3Value or 30) * tonumber(ScenarioInfo.Options.BuildMult)
    else
        t1 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T1Value or 8
        t2 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T2Value or 20
        t3 = aiBrain.BuilderManagers[locationType].BaseSettings.MassToFactoryValues.T3Value or 30
    end

    return GreaterThanMassIncomeToFactoryRNG(aiBrain, t1, t2, t3)
end

--[[function FactorySpendRatioRNG(aiBrain,uType,ratio,greater)
    if not greater or greater~='greater' then
        if aiBrain.cmanager.categoryspend.fac[uType]/aiBrain.cmanager.income.r.m+math.random(-15,15)/200<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.cmanager.categoryspend.fac[uType]/aiBrain.cmanager.income.r.m>ratio then
            return true
        else
            return false
        end
    end
end]]
function FutureProofEspendRNG(aiBrain,ratio,greater)
    if not aiBrain.cmanager.income.neede then return false end
    if not greater or greater~='greater' then
        if aiBrain.cmanager.income.r.e/aiBrain.cmanager.income.neede<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.cmanager.income.r.e/aiBrain.cmanager.income.neede>ratio then
            return true
        else
            return false
        end
    end
end
function MexesToBeClaimedRNG(aiBrain,num)
    if aiBrain.cmanager.unclaimedmexcount>num then
        return true
    end
    return false
end
function CoinFlipRNG(aiBrain,ratio)
    if math.random()<ratio then
        return true
    end
    return false
end
function FactoryTypeRatioRNG(aiBrain,uType,ratio,greater)
    if not aiBrain.fmanager.buildpower then return false end
    if not greater or greater~='greater' then
        if aiBrain.fmanager.buildpower[uType]/aiBrain.fmanager.buildpower.total<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.fmanager.buildpower[uType]/aiBrain.fmanager.buildpower.total>ratio then
            return true
        else
            return false
        end
    end
end
function FactorySpendRatioRNG(aiBrain,uType,ratio,greater)
    if not aiBrain.fmanager.buildpower then return false end
    if not greater or greater~='greater' then
        if aiBrain.fmanager.buildpower[uType]/aiBrain.cmanager.income.r.m<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.fmanager.buildpower[uType]/aiBrain.cmanager.income.r.m>ratio then
            return true
        else
            return false
        end
    end
end
function FutureProofFactorySpendRatioRNG(aiBrain,uType,ratio,greater)
    if not aiBrain.fmanager.buildpower then return false end
    if not greater or greater~='greater' then
        if aiBrain.fmanager.buildpower[uType]/(aiBrain.cmanager.income.r.m+2*aiBrain.cmanager.unclaimedmexcount)<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.fmanager.buildpower[uType]/(aiBrain.cmanager.income.r.m+2*aiBrain.cmanager.unclaimedmexcount)>ratio then
            return true
        else
            return false
        end
    end
end
function FactorySpendRatioUnitRNG(aiBrain,uType,ratio,greater)
    if not aiBrain.fmanager.buildpower[uType] or not aiBrain.cmanager.income.r.m then return false end
    if not greater or greater~='greater' then
        if math.random()<ratio/(aiBrain.fmanager.buildpower[uType]/aiBrain.cmanager.income.r.m) then
            return true
        else
            return false
        end
    else
        if aiBrain.fmanager.buildpower[uType]/aiBrain.cmanager.income.r.m>ratio then
            return true
        else
            return false
        end
    end
end
function FutureProofFactoryUpgradeSpendRatioRNG(aiBrain,uType,ratio,greater)
    if not aiBrain.fmanager.uspend[uType] or not aiBrain.cmanager.unclaimedmexcount then return false end
    if not greater or greater~='greater' then
        if aiBrain.fmanager.uspend[uType]/(aiBrain.cmanager.income.r.m+2*aiBrain.cmanager.unclaimedmexcount)<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.fmanager.uspend[uType]/(aiBrain.cmanager.income.r.m+2*aiBrain.cmanager.unclaimedmexcount)>ratio then
            return true
        else
            return false
        end
    end
end
function AvgFuelRatioRNG(aiBrain,ratio,greater)
    if not aiBrain.cmanager.needfuel or aiBrain.cmanager.needfuel.total<1 then return false end
    if not greater or greater~='greater' then
        if aiBrain.cmanager.needfuel.fuelratiosum/aiBrain.cmanager.needfuel.total<ratio then
            return true
        else
            return false
        end
    else
        if aiBrain.cmanager.needfuel.fuelratiosum/aiBrain.cmanager.needfuel.total>ratio then
            return true
        else
            return false
        end
    end
end