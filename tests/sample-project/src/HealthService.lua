local HealthService = {}

function HealthService.AddHealth(player, amount)
    player:SetAttribute("MaxHealthBonus", amount)
end

return HealthService
