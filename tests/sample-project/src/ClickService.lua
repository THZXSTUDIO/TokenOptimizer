local ClickService = {}

function ClickService.AddClick(player, baseClick)
    local multiplier = player:GetAttribute("ClickMultiplier") or 1
    local total = baseClick * multiplier
    player.leaderstats.Click.Value += total
end

return ClickService
