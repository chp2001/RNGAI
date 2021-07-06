local DilliDalliBeginSession = import('/mods/TechAI/lua/AI/DilliDalli/Mapping.lua').BeginSession
local DilliDalliYeOldeBeginSession = BeginSession
function BeginSession()
    DilliDalliYeOldeBeginSession()
    DilliDalliBeginSession()
end