-- Módulo de FPS Devour
local FPSDevourModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DevourLoop = false
local equipLoop = false
local conn = nil
local equipConnection = nil

local function showCompletionLabel()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local parentGui = playerGui

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "slaaaa"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.IgnoreGuiInset = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parentGui

    if not screenGui.Parent or not screenGui:IsDescendantOf(game) then
        parentGui = game:GetService("CoreGui")
        screenGui.Parent = parentGui
    end

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(0, 300, 0, 50)
    textLabel.Position = UDim2.new(0.5, -150, 0.1, 0)
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.TextSize = 24
    textLabel.Font = Enum.Font.FredokaOne
    textLabel.Text = "FPS Devour concluido!"
    textLabel.BorderSizePixel = 0
    textLabel.BackgroundTransparency = 1
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.ZIndex = 100
    textLabel.Parent = screenGui

    task.spawn(function()
        local colors = {
            Color3.fromRGB(255, 0, 0),
            Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 150, 255),
            Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(0, 0, 0),
            Color3.fromRGB(255, 255, 255)
        }
        local colorIndex = 1
        while textLabel and textLabel.Parent do
            textLabel.TextColor3 = colors[colorIndex]
            colorIndex = colorIndex % #colors + 1
            task.wait(0.1)
        end
    end)

    task.delay(5, function()
        if textLabel and textLabel.Parent then
            textLabel:Destroy()
        end
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
end

local function stopEverything(settings)
    DevourLoop = false
    equipLoop = false
    if conn then
        conn:Disconnect()
        conn = nil
    end
    if equipConnection then
        equipConnection:Disconnect()
        equipConnection = nil
    end
    
    if settings and settings.fpsDevour then
        settings.fpsDevourCooldown = 10
        
        task.spawn(function()
            while settings.fpsDevourCooldown > 0 do
                task.wait(1)
                settings.fpsDevourCooldown = settings.fpsDevourCooldown - 1
            end
        end)
    end
end

-- Método Aura (Clone)
function FPSDevourModule.startAura(character, backpack, settings, getRequiredRemotesFn, updateCharacterRefsFn)
    if DevourLoop then return end
    
    DevourLoop = true
    
    updateCharacterRefsFn()

    if conn then conn:Disconnect() end
    
    if settings.desync then
        task.spawn(function()
            task.wait(1)
            -- Desync será chamado externamente se necessário
        end)
    end
    
    task.spawn(function()
        local success, error = pcall(function()
            local remotes, errorMsg = getRequiredRemotesFn()
            if not remotes then
                return false
            end
            
            local equipped = {}
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA('Tool') then
                    table.insert(equipped, tool)
                end
            end

            local quantum = backpack:FindFirstChild('Quantum Cloner')
            if quantum and not table.find(equipped, quantum) then
                pcall(function()
                    quantum.Parent = character
                end)
            end

            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA('Tool') and tool.Name:lower():find("slap") then
                    if not table.find(equipped, tool) then
                        pcall(function()
                            tool.Parent = character
                        end)
                    end
                end
            end
            
            task.wait(0.5)

            if setfflag then setfflag("WorldStepMax", "-9999999999") end
            task.wait(0.2)
            remotes[1]:FireServer()
            task.wait(1)
            remotes[2]:FireServer()
            task.wait(2)
            if setfflag then setfflag("WorldStepMax", "-1") end
            
            return true
        end)
        
        stopEverything(settings)
        settings.fpsDevour = false
        if success then
            showCompletionLabel()
        end
    end)
end

-- Método Equip (Slaps)
function FPSDevourModule.startEquip(character, backpack, useItemRemote, updateCharacterRefsFn, settings)
    if equipLoop then return end
    
    if settings.fpsDevourCooldown > 0 then
        return
    end
    
    equipLoop = true
    settings.fpsDevour = true
    
    updateCharacterRefsFn()
    
    equipConnection = RunService.RenderStepped:Connect(function()
        if not equipLoop then
            if equipConnection then
                equipConnection:Disconnect()
                equipConnection = nil
            end
            return
        end
        
        if not character or not character.Parent or not backpack or not backpack.Parent then
            updateCharacterRefsFn()
            return
        end
        
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA('Tool') and tool.Name:lower():find("slap") then
                pcall(function()
                    tool.Parent = character
                end)
            end
        end
        
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA('Tool') and tool.Name:lower():find("slap") then
                pcall(function()
                    tool.Parent = backpack
                end)
            end
        end
        
        if useItemRemote and useItemRemote.Parent then
            pcall(function()
                useItemRemote:FireServer()
            end)
        end
    end)
end

function FPSDevourModule.stop(settings)
    DevourLoop = false
    equipLoop = false
    settings.fpsDevour = false
    
    if conn then
        conn:Disconnect()
        conn = nil
    end
    
    if equipConnection then
        equipConnection:Disconnect()
        equipConnection = nil
    end
end

function FPSDevourModule.stopEquip(settings)
    equipLoop = false
    settings.fpsDevour = false
    
    if equipConnection then
        equipConnection:Disconnect()
        equipConnection = nil
    end
end

return FPSDevourModule