-- Módulo de ESP (Players e Best Brainrot)
local ESPModule = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- ESP Players
local playerBillboards = {}
local playerHighlights = {}
local scriptUsers = {}
local espOnPlayer = false

local espOnBrainrot = false

local function parseMoneyPerSec(text)
    if not text then return 0 end
    local mult = 1
    local numberStr = text:match('[%d%.]+')
    if not numberStr then return 0 end
    if text:find('K') then
        mult = 1000
    elseif text:find('M') then
        mult = 1000000
    elseif text:find('B') then
        mult = 1000000000
    elseif text:find('T') then
        mult = 1000000000000
    elseif text:find('Q') then
        mult = 1000000000000000
    end
    local number = tonumber(numberStr)
    return number and number * mult or 0
end

local function clearAllBest()
    local plotsFolder = Workspace:FindFirstChild('Plots')
    if not plotsFolder then return end
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        for _, inst in ipairs(plot:GetDescendants()) do
            if inst:IsA('BillboardGui') and inst.Name == 'Best_ESP' then
                pcall(function() inst:Destroy() end)
            end
        end
    end
end

local function updateBest(lp)
    local plotsFolder = Workspace:FindFirstChild('Plots')
    if not plotsFolder then
        clearAllBest()
        return
    end
    if not espOnBrainrot then
        clearAllBest()
        return
    end
    
    local myPlotName
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local plotSign = plot:FindFirstChild('PlotSign')
        if plotSign and plotSign:FindFirstChild('YourBase') and plotSign.YourBase.Enabled then
            myPlotName = plot.Name
            break
        end
    end
    
    local bestPetInfo
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if plot.Name ~= myPlotName then
            for _, desc in ipairs(plot:GetDescendants()) do
                if desc:IsA('TextLabel') and desc.Name == 'Rarity' and desc.Parent and desc.Parent:FindFirstChild('DisplayName') then
                    local parentModel = desc.Parent.Parent
                    local displayName = desc.Parent.DisplayName.Text
                    local genLabel = desc.Parent:FindFirstChild('Generation')
                    if genLabel and genLabel:IsA('TextLabel') then
                        local mps = parseMoneyPerSec(genLabel.Text)
                        if not bestPetInfo or mps > bestPetInfo.mps then
                            bestPetInfo = {
                                petName = displayName,
                                genText = genLabel.Text,
                                mps = mps,
                                model = parentModel,
                            }
                        end
                    end
                end
            end
        end
    end
    
    clearAllBest()
    
    if bestPetInfo and bestPetInfo.mps > 0 and bestPetInfo.model then
        local billboard = Instance.new('BillboardGui')
        billboard.Name = 'Best_ESP'
        billboard.Size = UDim2.new(0, 350, 0, 90)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = bestPetInfo.model
        
        local nameLabel = Instance.new('TextLabel')
        nameLabel.Size = UDim2.new(1, 0, 0, 42)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = bestPetInfo.petName
        nameLabel.TextColor3 = Color3.fromRGB(255, 50, 100)
        nameLabel.Font = Enum.Font.FredokaOne
        nameLabel.TextScaled = false
        nameLabel.TextSize = 32
        nameLabel.LineHeight = 1
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        nameLabel.Parent = billboard
        
        local nameGradient = Instance.new('UIGradient')
        nameGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 100)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 150)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 60))
        }
        nameGradient.Rotation = 90
        nameGradient.Parent = nameLabel
        
        local moneyLabel = Instance.new('TextLabel')
        moneyLabel.Size = UDim2.new(1, 0, 0, 36)
        moneyLabel.Position = UDim2.new(0, 0, 0, 42)
        moneyLabel.BackgroundTransparency = 1
        moneyLabel.Text = bestPetInfo.genText
        moneyLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
        moneyLabel.Font = Enum.Font.FredokaOne
        moneyLabel.TextScaled = false
        moneyLabel.TextSize = 28
        moneyLabel.LineHeight = 1
        moneyLabel.TextStrokeTransparency = 0
        moneyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        moneyLabel.Parent = billboard
        
        local moneyGradient = Instance.new('UIGradient')
        moneyGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 150)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50, 255, 200)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 100))
        }
        moneyGradient.Rotation = 90
        moneyGradient.Parent = moneyLabel
    end
end

-- Funções ESP Players
local function updateESPColors()
    -- Atualizar cores dos billboards
    for player, billboard in pairs(playerBillboards) do
        if billboard and billboard.Parent then
            local label = billboard:FindFirstChild("TextLabel")
            if label then
                local oldGradient = label:FindFirstChild("UIGradient")
                if oldGradient then oldGradient:Destroy() end
                
                if scriptUsers[player.Name] then
                    label.TextColor3 = Color3.fromRGB(255, 165, 0)
                    
                    local gradient = Instance.new('UIGradient')
                    gradient.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 165, 0)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0))
                    }
                    gradient.Rotation = 90
                    gradient.Parent = label
                else
                    label.TextColor3 = Color3.fromRGB(0, 255, 255)
                    
                    local gradient = Instance.new('UIGradient')
                    gradient.Color = ColorSequence.new{
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 255)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
                    }
                    gradient.Rotation = 90
                    gradient.Parent = label
                end
            end
        end
    end
    
    -- Atualizar cores do ESP
    for player, espData in pairs(playerHighlights) do
        if espData and type(espData) == "table" and espData.parts then
            local color
            if scriptUsers[player.Name] then
                color = Color3.fromRGB(255, 165, 0)
            else
                color = Color3.fromRGB(0, 255, 255)
            end
            
            for _, partData in ipairs(espData.parts) do
                if partData.visual and partData.visual.Parent then
                    partData.visual.Color = color
                end
            end
        end
    end
end

function ESPModule.updateScriptUsersFromWebSocket(usersData)
    if not usersData or not usersData.users then return end
    
    scriptUsers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            for _, user in ipairs(usersData.users) do
                if user.username == player.Name and tostring(user.userid) == tostring(player.UserId) then
                    scriptUsers[player.Name] = true
                    break
                end
            end
        end
    end
    
    updateESPColors()
end

local function createPlayerBillboard(player, playerGui)
    if not player.Character then return end

    local rootPart = player.Character:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then return end

    if playerBillboards[player] then
        pcall(function() playerBillboards[player]:Destroy() end)
        playerBillboards[player] = nil
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 220, 0, 55)
    billboard.Adornee = rootPart
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.Parent = playerGui

    local label = Instance.new("TextLabel", billboard)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name
    label.TextScaled = false
    label.TextSize = 24
    label.Font = Enum.Font.FredokaOne
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    
    if scriptUsers[player.Name] then
        label.TextColor3 = Color3.fromRGB(255, 165, 0)
        
        local gradient = Instance.new('UIGradient')
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 165, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0))
        }
        gradient.Rotation = 90
        gradient.Parent = label
    else
        label.TextColor3 = Color3.fromRGB(0, 255, 255)
        
        local gradient = Instance.new('UIGradient')
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
        }
        gradient.Rotation = 90
        gradient.Parent = label
    end

    playerBillboards[player] = billboard
end

local function createPlayerHighlight(player)
    if not player.Character then return end

    local character = player.Character

    if playerHighlights[player] then
        pcall(function() 
            if type(playerHighlights[player]) == "table" and playerHighlights[player].model then
                playerHighlights[player].model:Destroy()
            end
        end)
        playerHighlights[player] = nil
    end
    
    local color
    if scriptUsers[player.Name] then
        color = Color3.fromRGB(255, 165, 0)
    else
        color = Color3.fromRGB(0, 255, 255)
    end
    
    -- Criar Model no Workspace
    local espModel = Instance.new("Model")
    espModel.Name = "ESP_" .. player.Name
    espModel.Parent = Workspace
    
    local partsToTrack = {
        "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
        "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", 
        "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg",
        "RightUpperLeg", "RightLowerLeg", "LeftHand", "RightHand",
        "LeftFoot", "RightFoot"
    }
    
    local espParts = {}
    
    for _, partName in ipairs(partsToTrack) do
        local originalPart = character:FindFirstChild(partName)
        if originalPart and originalPart:IsA("BasePart") then
            -- Criar parte visual
            local visualPart = Instance.new("Part")
            visualPart.Name = partName
            visualPart.Size = originalPart.Size
            visualPart.CFrame = originalPart.CFrame
            visualPart.Transparency = 0.7
            visualPart.Color = color
            visualPart.Material = Enum.Material.Neon
            visualPart.CanCollide = false
            visualPart.Anchored = true
            visualPart.CastShadow = false
            visualPart.Parent = espModel
            
            table.insert(espParts, {visual = visualPart, original = originalPart})
        end
    end
    
    if #espParts > 0 then
        playerHighlights[player] = {
            model = espModel,
            parts = espParts
        }
    else
        espModel:Destroy()
    end
end

-- Funções públicas
function ESPModule.toggleESPBest(state, lp)
    espOnBrainrot = state
    if not espOnBrainrot then
        clearAllBest()
    else
        updateBest(lp)
    end
end

function ESPModule.toggleESPPlayer(state, lp, playerGui)
    espOnPlayer = state
    if not espOnPlayer then
        for _, billboard in pairs(playerBillboards) do 
            pcall(function() billboard:Destroy() end) 
        end
        
        for _, espData in pairs(playerHighlights) do
            pcall(function()
                if type(espData) == "table" and espData.model then
                    espData.model:Destroy()
                end
            end)
        end
        
        playerBillboards = {}
        playerHighlights = {}
    else
        task.spawn(function()
            task.wait(2)
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= lp then
                    if player.Character then
                        local humanoid = player.Character:FindFirstChild("Humanoid")
                        local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                        
                        if humanoid and rootPart then
                            if playerBillboards[player] then
                                pcall(function() playerBillboards[player]:Destroy() end)
                                playerBillboards[player] = nil
                            end
                            
                            if playerHighlights[player] then
                                pcall(function()
                                    if type(playerHighlights[player]) == "table" and playerHighlights[player].model then
                                        playerHighlights[player].model:Destroy()
                                    end
                                end)
                                playerHighlights[player] = nil
                            end
                            
                            createPlayerBillboard(player, playerGui)
                            createPlayerHighlight(player)
                        end
                    end
                end
            end
            
        end)
    end
end

function ESPModule.setupLoop(lp)
    -- Loop ESP Best
    task.spawn(function()
        while true do
            if espOnBrainrot then 
                updateBest(lp)
            else
                clearAllBest()
            end
            task.wait(1)
        end
    end)
    
    -- Loop ESP Player
    RunService.Heartbeat:Connect(function()
        if not espOnPlayer then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= lp then
                local character = player.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")

                if character and rootPart then
                    if not playerBillboards[player] or not playerBillboards[player].Parent then
                        createPlayerBillboard(player, lp:WaitForChild("PlayerGui"))
                    else
                        playerBillboards[player].Adornee = rootPart
                    end

                    -- Verificar e atualizar ESP
                    if not playerHighlights[player] or not playerHighlights[player].model or not playerHighlights[player].model.Parent then
                        createPlayerHighlight(player)
                    else
                        -- Sincronizar partes visuais
                        local espData = playerHighlights[player]
                        for _, partData in ipairs(espData.parts) do
                            if partData.visual and partData.original and partData.original.Parent then
                                partData.visual.CFrame = partData.original.CFrame
                                partData.visual.Size = partData.original.Size
                            end
                        end
                    end
                end
            end
        end
    end)
end

function ESPModule.setupPlayerEvents(lp)
    Players.PlayerRemoving:Connect(function(player)
        if playerBillboards[player] then 
            pcall(function() playerBillboards[player]:Destroy() end)
        end
        
        if playerHighlights[player] then
            pcall(function()
                if type(playerHighlights[player]) == "table" and playerHighlights[player].model then
                    playerHighlights[player].model:Destroy()
                end
            end)
        end
    end)
    
    local function connectPlayerCharacterAdded(player)
        player.CharacterAdded:Connect(function(character)
            if espOnPlayer then
                task.spawn(function()
                    if playerBillboards[player] then
                        pcall(function() playerBillboards[player]:Destroy() end)
                        playerBillboards[player] = nil
                    end
                    
                    if playerHighlights[player] then
                        pcall(function()
                            if type(playerHighlights[player]) == "table" and playerHighlights[player].model then
                                playerHighlights[player].model:Destroy()
                            end
                        end)
                        playerHighlights[player] = nil
                    end

                    local humanoid = character:WaitForChild("Humanoid", 10)
                    local rootPart = character:WaitForChild("HumanoidRootPart", 10)

                    if humanoid and rootPart then
                        task.wait(1)
                        createPlayerBillboard(player, lp:WaitForChild("PlayerGui"))
                        createPlayerHighlight(player)
                    end
                end)
            end
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        connectPlayerCharacterAdded(player)
    end)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= lp then
            connectPlayerCharacterAdded(player)
        end
    end
end

return ESPModule
