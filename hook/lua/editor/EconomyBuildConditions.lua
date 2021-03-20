--[[
    File    :   /lua/AI/AIBaseTemplates/EconomyBuildConditions.lua
    Author  :   relentless
    Summary :
        Economy Build Conditions
]]

local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored

function GreaterThanEconStorageRatioRNG(aiBrain, mStorageRatio, eStorageRatio, mult)
    local econ = {}
    econ.MassStorageRatio = GetEconomyStoredRatio(aiBrain, 'MASS')
    econ.EnergyStorageRatio = GetEconomyStoredRatio(aiBrain, 'ENERGY')
    -- If a paragon is present and we not stall mass or energy, return true
    --LOG('Mass Storage Ratio :'..econ.MassStorageRatio..' Energy Storage Ratio :'..econ.EnergyStorageRatio)
    if aiBrain.HasParagon and econ.MassStorageRatio >= 0.01 and econ.EnergyStorageRatio >= 0.01 then
        return true
    elseif aiBrain.EnemyIntel.ChokeFlag then
        if mult == 'LAND' then
            if econ.MassStorageRatio >= 0.20 and econ.EnergyStorageRatio >= 0.80 then
                return true
            end
        elseif mult == 'FACTORY' then
            if econ.MassStorageRatio >= 0.10 and econ.EnergyStorageRatio >= 0.80 then
                return true
            end
        elseif mult == 'DEFENSE' then
            if econ.MassStorageRatio >= 0.20 and econ.EnergyStorageRatio >= 0.80 then
                return true
            end
        elseif econ.MassStorageRatio >= mStorageRatio and econ.EnergyStorageRatio >= eStorageRatio then
            return true
        end
    elseif aiBrain.UpgradeMode == 'Aggressive' then
        if econ.MassStorageRatio >= mStorageRatio * 1.5 and econ.EnergyStorageRatio >= eStorageRatio then
            return true
        end
    elseif mult == true then
        if econ.MassStorageRatio >= mStorageRatio * aiBrain.EcoManager.EcoMultiplier and econ.EnergyStorageRatio >= eStorageRatio then
            return true
        end
    elseif econ.MassStorageRatio >= mStorageRatio and econ.EnergyStorageRatio >= eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEconTrendRNG(aiBrain, MassTrend, EnergyTrend)
    local econ = {}
    econ.MassTrend = GetEconomyTrend(aiBrain, 'MASS')
    econ.EnergyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
    -- If a paragon is present and we have at least a neutral m+e trend, return true
    --LOG('Current Econ Trends M E: ', econ.MassTrend, econ.EnergyTrend)
    if aiBrain.HasParagon and econ.MassTrend >= 0 and econ.EnergyTrend >= 0 then
        return true
    elseif econ.MassTrend >= MassTrend and econ.EnergyTrend >= EnergyTrend then
        return true
    end
    return false
end

function GreaterThanEnergyTrendRNG(aiBrain, eTrend, DEBUG)
    local EnergyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
    if DEBUG then
        --LOG('Current Energy Trend is : ', econ.EnergyTrend)
    end
    if EnergyTrend > eTrend then
        --LOG('Greater than Energy Trend Returning True : '..econ.EnergyTrend)
        return true
    else
        --LOG('Greater than Energy Trend Returning False : '..econ.EnergyTrend)
        return false
    end
end

function GreaterThanMassTrendRNG(aiBrain, mTrend, DEBUG)
    local MassTrend = GetEconomyTrend(aiBrain, 'MASS')
    if DEBUG then
        --LOG('Current Energy Trend is : ', econ.MassTrend)
    end
    if MassTrend > mTrend then
        return true
    else
        return false
    end
end

function LessThanMassTrendRNG(aiBrain, mTrend)
    local MassTrend = GetEconomyTrend(aiBrain, 'MASS')
    --LOG('Mass Trend is'..MassTrend)
    if MassTrend < mTrend then
        return true
    else
        return false
    end
end

--            { EBC, 'LessThanEnergyTrendRNG', { 50.0 } },
function LessThanEnergyTrendRNG(aiBrain, eTrend, DEBUG)
    local EnergyTrend = GetEconomyTrend(aiBrain, 'ENERGY')
    --LOG('Energy Trend is'..EnergyTrend)
    if EnergyTrend < eTrend then
        return true
    else
        return false
    end
end

function GreaterThanEconEfficiencyOverTimeRNG(aiBrain, MassEfficiency, EnergyEfficiency)
    local EnergyIncome = GetEconomyIncome(aiBrain,'ENERGY')
    local MassIncome = GetEconomyIncome(aiBrain,'MASS')
    local EnergyRequested = GetEconomyRequested(aiBrain,'ENERGY')
    local MassRequested = GetEconomyRequested(aiBrain,'MASS')
    local EnergyEfficiencyOverTime = math.min(EnergyIncome / EnergyRequested, 2)
    local MassEfficiencyOverTime = math.min(MassIncome / MassRequested, 2)
    --LOG('Mass Wanted :'..MassEfficiency..'Actual :'..MassEfficiencyOverTime..'Energy Wanted :'..EnergyEfficiency..'Actual :'..EnergyEfficiencyOverTime)
    if (MassEfficiencyOverTime >= MassEfficiency and EnergyEfficiencyOverTime >= EnergyEfficiency) then
        --LOG('GreaterThanEconEfficiencyOverTime Returned True')
        return true
    end
    --LOG('GreaterThanEconEfficiencyOverTime Returned False')
    return false
end

function GreaterThanMassIncomeToFactory(aiBrain, t1Drain, t2Drain, t3Drain)
    local econTime = aiBrain:GetEconomyOverTime()
    
    -- T1 Test
    local testCat = categories.TECH1 * categories.FACTORY
    local unitCount = aiBrain:GetCurrentUnits( testCat )
    -- Find units of this type being built or about to be built
    unitCount = unitCount + aiBrain:GetEngineerManagerUnitsBeingBuilt(testCat)
    
    local massTotal = unitCount * t1Drain
    -- T2 Test
    testCat = categories.TECH2 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits( testCat )
    
    massTotal = massTotal + ( unitCount * t2Drain )
    
    -- T3 Test
    testCat = categories.TECH3 * categories.FACTORY
    unitCount = aiBrain:GetCurrentUnits( testCat )

    massTotal = massTotal + ( unitCount * t3Drain )    
    
    if not CompareBody( (econTime.MassIncome * 10), massTotal, '>' ) then
        return false
    end
    return true
end

function GreaterThanEconStorageCurrentRNG(aiBrain, mStorage, eStorage)
    local MassStorage = GetEconomyStored(aiBrain, 'MASS')
    local EnergyStorage = GetEconomyStored(aiBrain, 'ENERGY')

    if (MassStorage >= mStorage and EnergyStorage >= eStorage) then
        return true
    end
    return false
end

-- { UCBC, 'EnergyToMassRatioIncomeRNG', { 10.0, '>=',true } },  -- True if we have 10 times more Energy then Mass income ( 100 >= 10 = true )
function EnergyToMassRatioIncomeRNG(aiBrain, ratio, compareType, DEBUG)
    local EnergyIncome = GetEconomyIncome(aiBrain,'ENERGY')
    local MassIncome = GetEconomyIncome(aiBrain,'MASS')
    if DEBUG then
        --LOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( E:'..(econ.EnergyIncome*10)..' '..compareType..' M:'..(econ.MassIncome*10)..' ) -- R['..ratio..'] -- return '..repr(CompareBody(econ.EnergyIncome / econ.MassIncome, ratio, compareType)))
    end
    return CompareBody(EnergyIncome / MassIncome, ratio, compareType)
end
