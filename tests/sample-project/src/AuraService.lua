local AuraService = {}

function AuraService.ApplyAura(player, aura)
    local clickBonus = aura.ClickMultiplier or 1
    player:SetAttribute("ClickMultiplier", clickBonus)
end

return AuraService
