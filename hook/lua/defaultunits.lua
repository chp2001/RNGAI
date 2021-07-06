
local TechAIMobileUnit = MobileUnit
MobileUnit = Class(TechAIMobileUnit) {

    OnCreate = function(self)
        local aiBrain = self:GetAIBrain()
        if not aiBrain.TechAI then
            return TechAIMobileUnit.OnCreate(self)
        end
        Unit.OnCreate(self)
        self:updateBuildRestrictions()
        self:SetFireState(FireState.RETURN_FIRE)
    end,

}