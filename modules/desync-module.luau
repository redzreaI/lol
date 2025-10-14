-- Módulo de Desync
local DesyncModule = {}
local desyncActive = false

function DesyncModule.findTool(backpack, character)
    local toolNames = {"Quantum Cloner", "Brainrot", "brainrot"}
    
    for _, toolName in ipairs(toolNames) do
        local tool = backpack:FindFirstChild(toolName) or character:FindFirstChild(toolName)
        if tool then return tool end
    end
    
    -- Fallback: pegar qualquer tool
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then return item end
    end
    
    return nil
end

function DesyncModule.getRequiredRemotes()
    local packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages", 5)
    if not packages then return nil, "Packages não encontrado" end
    
    local netFolder = packages:WaitForChild("Net", 5)
    if not netFolder then return nil, "Net folder não encontrado" end
    
    local useItemRemote = netFolder:WaitForChild("RE/UseItem", 5)
    local teleportRemote = netFolder:WaitForChild("RE/QuantumCloner/OnTeleport", 5)
    
    if not useItemRemote or not teleportRemote then 
        return nil, "Remotos não encontrados" 
    end
    
    return {useItemRemote, teleportRemote}, nil
end

function DesyncModule.enable()
    local success, error = pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        
        local remotes, errorMsg = DesyncModule.getRequiredRemotes()
        if not remotes then
            return false
        end
        
        local tool = DesyncModule.findTool(backpack, character)
        if tool and tool.Parent == backpack then
            humanoid:EquipTool(tool)
            task.wait(0.5)
        end

        -- Executar desync
        if setfflag then setfflag("WorldStepMax", "-9999999999") end
        task.wait(0.2)
        remotes[1]:FireServer()
        task.wait(1)
        remotes[2]:FireServer()
        task.wait(2)
        if setfflag then setfflag("WorldStepMax", "-1") end
        
        return true
    end)
    
    return success
end

function DesyncModule.disable()
    pcall(function()
        if setfflag then setfflag("WorldStepMax", "-1") end
    end)
end

function DesyncModule.toggle()
    desyncActive = not desyncActive
    
    if desyncActive then
        local success = DesyncModule.enable()
        if not success then
            desyncActive = false
        end
        return success
    else
        DesyncModule.disable()
        return false
    end
end

function DesyncModule.reset()
    desyncActive = false
    DesyncModule.disable()
end

return DesyncModule