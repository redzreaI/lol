-- ============================================================================
-- ADMIN PANEL MODULE
-- Este mÃ³dulo contÃ©m toda a lÃ³gica do Admin Panel
-- Deve ser executado via loadstring apÃ³s as variÃ¡veis globais estarem definidas
-- ============================================================================

-- Verifica se as variÃ¡veis globais necessÃ¡rias estÃ£o disponÃ­veis
if not _G.variaveis then
    warn("[Admin Panel] VariÃ¡veis globais nÃ£o encontradas. Tentando criar fallback...")
end

-- Acessa variÃ¡veis globais necessÃ¡rias
local variaveis = _G.variaveis or (function()
    local v = {}
    v.Workspace = game:GetService("Workspace")
    v.ReplicatedStorage = game:GetService("ReplicatedStorage")
    v.Players = game:GetService("Players")
    v.TeleportService = game:GetService("TeleportService")
    v.UserInputService = game:GetService("UserInputService")
    v.RunService = game:GetService("RunService")
    v.TweenService = game:GetService("TweenService")
    v.HttpService = game:GetService("HttpService")
    v.JobId = game.JobId
    v.PlaceId = game.PlaceId
    v.LocalPlayer = v.Players.LocalPlayer
    return v
end)()

-- Acessa outras variÃ¡veis globais necessÃ¡rias
local utils = _G.utils or (function()
    local ok, genv = pcall(function() return getgenv() end)
    if ok and genv and genv.oNine and genv.oNine["Utils"] then
        return genv.oNine["Utils"]
    end
    return {}
end)()
local stealConfig = _G.stealConfig or (function()
    local ok, genv = pcall(function() return getgenv() end)
    if ok and genv and genv.oNine and genv.oNine["Steal Nearest"] then
        return genv.oNine["Steal Nearest"]
    end
    return {Enabled = true, ["Follow Index"] = false}
end)()
local folder = _G.folder or "_oNine"
local savedConfig = _G.savedConfig or {}
local savedPositions = _G.savedPositions or {}
local isMyPlot = _G.isMyPlot
local generateRandomGuiName = _G.generateRandomGuiName or function(prefix)
    return prefix .. "_" .. variaveis.HttpService:GenerateGUID(false):sub(1, 8)
end
local generateUUID = _G.generateUUID or function()
    return variaveis.HttpService:GenerateGUID(false):gsub("-", "")
end
local saveConfig = (type(_G.saveConfig) == "function" and _G.saveConfig) or function() end
local savePositions = (type(_G.savePositions) == "function" and _G.savePositions) or function() end
local PlaceId = variaveis.PlaceId
local Players = variaveis.Players
local Workspace = variaveis.Workspace
local ReplicatedStorage = variaveis.ReplicatedStorage

-- Carrega AnimalsData para uso no painel de prioridade
local AnimalsData = _G.AnimalsData or (function()
    local ok, data = pcall(function() return require(variaveis.ReplicatedStorage.Datas.Animals) end)
    return ok and data or {}
end)()
_G.AnimalsData = AnimalsData

-- Aguarda jogo carregar antes de continuar
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(0.3) -- Reduzido de 2 para 0.3

-- Inicializa _G.oNineShared se não existir
if not _G.oNineShared then
    _G.oNineShared = {}
end

-- Theme (rosa claro) - movido para global para reduzir variÃ¡veis locais
if not _G.oNineShared.THEME then
        _G.oNineShared.THEME = {
            DarkBg = Color3.fromRGB(10, 14, 24),
            CardBg = Color3.fromRGB(20, 25, 35),
            AccentRed = Color3.fromRGB(255, 20, 147),
            AccentWhite = Color3.fromRGB(255, 255, 255),
            AccentGreen = Color3.fromRGB(100, 255, 100),
            AccentOrange = Color3.fromRGB(240, 173, 78),
            AccentCyan = Color3.fromRGB(0, 220, 255),
            TextPrimary = Color3.fromRGB(255, 255, 255),
            TextSecondary = Color3.fromRGB(185, 193, 199),
            TextMuted = Color3.fromRGB(128, 139, 150),
            Border = Color3.fromRGB(52, 58, 64),
            Divider = Color3.fromRGB(73, 80, 87),
            ButtonBg = Color3.fromRGB(30, 35, 45),
        }
end
local THEME = _G.oNineShared.THEME

-- GUI Helpers
local function smoothTween(object, properties, duration, easingStyle)
    duration = duration or 0.25
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    local tween = variaveis.TweenService:Create(object, TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out), properties)
    tween:Play()
    return tween
end

local function addCorners(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function addStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.Border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.3
    stroke.Parent = parent
    return stroke
end

local function addPinkGradient(parent)
    -- Removido gradiente, usa apenas rosa choque
    if parent:IsA("TextLabel") or parent:IsA("TextButton") then
        parent.TextColor3 = THEME.AccentRed
    end
end

local function createFrame(parent, size, position, bgColor, bgTransparency)
    if not parent then
        warn("[Admin Panel] createFrame: parent é nil")
        return nil
    end
    local frame = Instance.new("Frame")
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = bgColor or THEME.CardBg
    frame.BackgroundTransparency = bgTransparency or 0
    frame.Parent = parent
    return frame
end

local function createTextLabel(parent, size, position, text, textSize, textColor)
    if not parent then
        warn("[Admin Panel] createTextLabel: parent é nil")
        return nil
    end
    local label = Instance.new("TextLabel")
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = textSize or 12
    label.TextColor3 = textColor or THEME.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = parent
    return label
end

local function createTitleWithIcon(parent, size, position, text, textSize, textColor, iconSize)
    if not parent then
        warn("[Admin Panel] createTitleWithIcon: parent é nil")
        return nil, nil, nil
    end
    
    iconSize = iconSize or 20
    local container = Instance.new("Frame")
    container.Size = size
    container.Position = position
    container.BackgroundTransparency = 1
    container.Parent = parent
    
    -- Reutiliza tabela para reduzir variÃ¡veis
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, iconSize, 0, iconSize)
    icon.Position = UDim2.new(0, 0, 0.5, -iconSize/2)
    icon.BackgroundTransparency = 1
    icon.Text = "ðŸ"
    icon.Font = Enum.Font.Gotham
    icon.TextSize = iconSize - 2
    icon.TextColor3 = THEME.AccentRed
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.TextYAlignment = Enum.TextYAlignment.Center
    icon.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -iconSize - 5, 1, 0)
    label.Position = UDim2.new(0, iconSize + 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = textSize or 12
    label.TextColor3 = textColor or THEME.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = container
    
    return container, label, icon
end

local function createTextButton(parent, size, position, text, bgColor, textSize)
    if not parent then
        warn("[Admin Panel] createTextButton: parent é nil")
        return nil
    end
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = bgColor or THEME.ButtonBg
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = textSize or 11
    button.TextColor3 = THEME.TextPrimary
    button.AutoButtonColor = false
    button.Parent = parent
    return button
end

local playerGui = variaveis.LocalPlayer:WaitForChild("PlayerGui", 15)
    if not playerGui then return end
    
    -- Main GUI
    local mainGui = Instance.new("ScreenGui")
    mainGui.Name = generateRandomGuiName("AdminPanel") .. "_" .. generateUUID()
    mainGui.Parent = playerGui
    mainGui.ResetOnSpawn = false
    mainGui.IgnoreGuiInset = true
    mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- ========================================================================
    -- OPEN BASE BUTTONS (LOCAL)
    -- ========================================================================
    
    local nearestPrompts = {[1]={prompt=nil, dist=math.huge}, [2]={prompt=nil, dist=math.huge}, [3]={prompt=nil, dist=math.huge}}
    
    -- ExpÃµe globalmente para acesso do sistema de detecÃ§Ã£o de roubo
    _G.oNineNearestPrompts = nearestPrompts
    
    local openBasePanel = createFrame(mainGui, UDim2.new(0, 200, 0, 60), UDim2.new(0.5, -100, 0, 100), THEME.DarkBg, 0.1)
    addCorners(openBasePanel, 12)
    addStroke(openBasePanel, THEME.AccentRed, 2, 0.3)
    
    local buttonsFrame = createFrame(openBasePanel, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), nil, 1)
    local buttonsLayout = Instance.new("UIListLayout")
    buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
    buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    buttonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    buttonsLayout.Padding = UDim.new(0, 8)
    buttonsLayout.Parent = buttonsFrame
    
    local function createFloorButton(floorNum)
        local btn = createTextButton(buttonsFrame, UDim2.new(0, 50, 0, 50), UDim2.new(0, 0, 0, 0), tostring(floorNum), THEME.CardBg, 32)
        btn.Font = Enum.Font.GothamBold
        btn.TextColor3 = Color3.fromRGB(255, 255, 255) -- Branco brilhante
        btn.TextStrokeTransparency = 0.2 -- Stroke sutil mas visÃ­vel
        btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        btn.ZIndex = 10
        addCorners(btn, 10)
        
        -- Imagem do morango como fundo (sem quadrado preto)
        local obj = Instance.new("ImageLabel")
        obj.Name = "BackgroundImage"
        obj.Size = UDim2.new(1, 0, 1, 0)
        obj.Position = UDim2.new(0, 0, 0, 0)
        obj.BackgroundTransparency = 1
        obj.Image = "rbxassetid://103548565633794"
        obj.ImageTransparency = 0.6 -- Transparente o suficiente para o texto aparecer
        obj.ScaleType = Enum.ScaleType.Crop
        obj.ZIndex = 1
        obj.Parent = btn
        
        local stroke = addStroke(btn, THEME.AccentRed, 2, 0.5)
        stroke.ZIndex = 3
        return btn, stroke
    end
    
    local floorButtons = {}
    for i = 1, 3 do
        local btn, stroke = createFloorButton(i)
        floorButtons[i] = {btn = btn, stroke = stroke}
    end
    
    local function findNearestPrompts()
        local hrp = (variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        if not hrp then return end
        
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return end
        
        local temp = {[1]={prompt=nil, dist=math.huge}, [2]={prompt=nil, dist=math.huge}, [3]={prompt=nil, dist=math.huge}}
        
        for _, plot in ipairs(plots:GetChildren()) do
            local unlock = plot:FindFirstChild("Unlock")
            if unlock then
                for _, main in ipairs(unlock:GetChildren()) do
                    if main.Name == "Main" then
                        local unlockBase = main:FindFirstChild("UnlockBase")
                        if unlockBase and unlockBase:IsA("ProximityPrompt") then
                            local floorNum = tonumber(unlockBase:GetAttribute("Floor"))
                            if floorNum and floorNum >= 1 and floorNum <= 3 then
                                local pos = main:IsA("BasePart") and main.Position or (main.PrimaryPart and main.PrimaryPart.Position)
                                if pos then
                                    local dist = (hrp.Position - pos).Magnitude
                                    if dist < temp[floorNum].dist then
                                        temp[floorNum] = {prompt=unlockBase, dist=dist}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        nearestPrompts = temp
    end
    
    local function firePrompt(prompt)
        if not prompt then return end
        
        if typeof(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt)
            return
        end
        
        local hrp = (variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        if not hrp then return end
        
        local promptParent = prompt.Parent
        local promptPos = promptParent:IsA("BasePart") and promptParent.Position or (promptParent.PrimaryPart and promptParent.PrimaryPart.Position)
        
        if promptPos then
            local originalPos = hrp.CFrame
            hrp.CFrame = CFrame.new(promptPos + Vector3.new(0, 5, 0))
            task.wait(0.2)
            pcall(function()
                if typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(prompt)
                end
            end)
            task.wait(0.2)
            hrp.CFrame = originalPos
        end
    end
    
    -- ExpÃµe globalmente para acesso do sistema de detecÃ§Ã£o de roubo
    _G.oNineFirePrompt = firePrompt
    
    -- Atualiza visual dos botÃµes baseado na disponibilidade
    task.spawn(function()
        while openBasePanel and openBasePanel.Parent do
            pcall(findNearestPrompts)
            
            for i = 1, 3 do
                local btnData = floorButtons[i]
                if btnData and btnData.btn and btnData.stroke then
                    if nearestPrompts[i].prompt then
                        btnData.stroke.Color = THEME.AccentRed
                        btnData.stroke.Transparency = 0.2
                        btnData.btn.BackgroundColor3 = Color3.fromRGB(
                            math.min(255, THEME.CardBg.R * 255 + 20),
                            math.min(255, THEME.CardBg.G * 255 + 20),
                            math.min(255, THEME.CardBg.B * 255 + 20)
                        )
                    else
                        btnData.stroke.Color = THEME.AccentRed
                        btnData.stroke.Transparency = 0.5
                        btnData.btn.BackgroundColor3 = THEME.CardBg
                    end
                end
            end
            
            task.wait(0.3)
        end
    end)
    
    -- Conecta cliques dos botÃµes
    floorButtons[1].btn.MouseButton1Click:Connect(function() firePrompt(nearestPrompts[1].prompt) end)
    floorButtons[2].btn.MouseButton1Click:Connect(function() firePrompt(nearestPrompts[2].prompt) end)
    floorButtons[3].btn.MouseButton1Click:Connect(function() firePrompt(nearestPrompts[3].prompt) end)
    
    -- ========================================================================
    -- END OPEN BASE BUTTONS
    -- ========================================================================
    
    -- Command system
    local commandCooldowns = {
        rocket = 120,
        ragdoll = 30,
        balloon = 30,
        inverse = 60,
        nightvision = 60,
        jail = 60,
        tiny = 60,
        jumpscare = 60,
        morph = 60
    }
    
    local lastCommandUse = {}
    local commands = {"balloon","jumpscare","morph","inverse","nightvision","tiny"}
    
    local function findRemote()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            local n = d.Name:lower()
            if n:find("executecommand") and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                return d
            end
        end
    end
    local remote = findRemote()
    
    local proximityEnabled, playerCommandPools, lastHit = false, {}, {}
    local globalCommandsLeft = #commands
    
    local function isCommandOnCooldown(command)
        local lastUse = lastCommandUse[command]
        if not lastUse then return false end
        local cooldownTime = commandCooldowns[command] or 0
        return (tick() - lastUse) < cooldownTime
    end
    
    local function getRemainingCooldown(command)
        local lastUse = lastCommandUse[command]
        if not lastUse then return 0 end
        local cooldownTime = commandCooldowns[command] or 0
        local remaining = cooldownTime - (tick() - lastUse)
        return math.max(0, remaining)
    end
    
    -- ========================================================================
    -- ANTI-DESYNC SYSTEM
    -- ========================================================================
    
    local Camera = variaveis.Workspace.CurrentCamera
    local EQUIP_DELAY = 0.5
    local CAMERA_TRANSITION_DELAY = 0.3
    local MOVEMENT_DELAY = 0.3
    local ROTATION_DELAY = 0.2
    local RESTORE_DELAY = 0.1
    local UNEQUIP_DELAY = 0.2
    local TARGET_DISTANCE = 1
    
    local function loadAntiDesyncModule(path)
        local success, module = pcall(function()
            local parts = {}
            for part in path:gmatch("[^/]+") do
                table.insert(parts, part)
            end
            
            local current = ReplicatedStorage
            for _, part in ipairs(parts) do
                current = current:WaitForChild(part, 5)
                if not current then return nil end
            end
            
            return require(current)
        end)
        return success and module or nil
    end
    
    -- Usa a funÃ§Ã£o isMyPlot global definida anteriormente
    
    local function getPlayerStealingBestBrainrotForAntiDesync()
        local Synchronizer = require(variaveis.ReplicatedStorage.Packages.Synchronizer)
        local Animals = require(variaveis.ReplicatedStorage.Shared.Animals)
        local AnimalsData = require(variaveis.ReplicatedStorage.Datas.Animals)
        
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return nil end
        
        local bestSortValue = -math.huge
        local bestStealerUserId = nil
        local followIndex = stealConfig["Follow Index"] or false
        
        for _, plot in plots:GetChildren() do
            if not plot:IsA("Model") then continue end
            if not plot:GetAttribute("Tier") then continue end
            if isMyPlot(plot) then continue end
            
            local success, channel = pcall(function()
                return Synchronizer:Wait(plot.Name)
            end)
            
            if not success or not channel then continue end
            
            local animalList = channel:Get("AnimalList") or {}
            
            for _, entry in pairs(animalList) do
                if type(entry) ~= "table" then continue end
                if not entry.Index or entry == "Empty" then continue end
                
                local isFusing = entry.Fusing == true
                local isMachineActive = entry.Machine and entry.Machine.Active == true
                
                if isFusing or isMachineActive then continue end
                
                local generation = Animals:GetGeneration(entry.Index, entry.Mutation, entry.Traits, nil)
                local animalData = AnimalsData[entry.Index]
                
                local sortValue = generation
                if followIndex and animalData and animalData.Generation then
                    sortValue = animalData.Generation
                end
                
                if entry.Steal and type(entry.Steal) == "number" and sortValue > bestSortValue then
                    bestSortValue = sortValue
                    bestStealerUserId = entry.Steal
                end
            end
        end
        
        if not bestStealerUserId then return nil end
        
        for _, player in Players:GetPlayers() do
            if player.UserId == bestStealerUserId and player ~= variaveis.LocalPlayer then
                local character = player.Character
                if character and character:FindFirstChild("HumanoidRootPart") then
                    return player
                end
            end
        end
        
        return nil
    end
    
    local function getRandomPlayerForAntiDesync()
        local stealer = getPlayerStealingBestBrainrotForAntiDesync()
        if stealer then return stealer end
        
        local validPlayers = {}
        
        for _, player in Players:GetPlayers() do
            if player == variaveis.LocalPlayer then continue end
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                table.insert(validPlayers, player)
            end
        end
        
        if #validPlayers == 0 then return nil end
        return validPlayers[math.random(1, #validPlayers)]
    end
    
    local function equipLaserGun()
        local backpack = variaveis.LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return false end
        local laserGun = backpack:FindFirstChild("Laser Gun")
        if not laserGun then return false end
        laserGun.Parent = variaveis.LocalPlayer.Character
        return true
    end
    
    local function unequipLaserGun()
        local character = variaveis.LocalPlayer.Character
        if not character then return false end
        local laserGun = character:FindFirstChild("Laser Gun")
        if not laserGun then return false end
        local backpack = variaveis.LocalPlayer:FindFirstChild("Backpack")
        if not backpack then return false end
        laserGun.Parent = backpack
        return true
    end
    
    local function moveCharacterToFront(targetCharacter, distance)
        local character = variaveis.LocalPlayer.Character
        if not character then return end
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
        if not targetHRP then return end
        local cframe = humanoidRootPart.CFrame
        local frontPosition = cframe.Position + cframe.LookVector * distance
        targetHRP.Anchored = true
        targetHRP.CFrame = CFrame.new(frontPosition, cframe.Position)
    end
    
    local function rotateToTarget(targetHRP, myHRP)
        if not myHRP or not targetHRP then return end
        local currentPosition = myHRP.Position
        local targetPosition = targetHRP.Position
        myHRP.CFrame = CFrame.lookAt(
            currentPosition,
            Vector3.new(targetPosition.X, currentPosition.Y, targetPosition.Z)
        )
    end
    
    local function antiDesyncShoot(targetPlayer)
        pcall(function()
            local LaserGunsShared = loadAntiDesyncModule("Shared/LaserGunsShared")
            if not LaserGunsShared then 
                warn("[Anti-Desync] Failed to load LaserGunsShared module")
                return 
            end
            
            local character = variaveis.LocalPlayer.Character
            if not character then 
                warn("[Anti-Desync] No character found")
                return 
            end
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then 
                warn("[Anti-Desync] No HumanoidRootPart found")
                return 
            end
            
            if not targetPlayer then
                targetPlayer = getRandomPlayerForAntiDesync()
            end
            
            if not targetPlayer then 
                warn("[Anti-Desync] No target player found")
                return 
            end
            
            local targetCharacter = targetPlayer.Character
            if not targetCharacter then 
                warn("[Anti-Desync] Target player has no character")
                return 
            end
            local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
            if not targetHRP then 
                warn("[Anti-Desync] Target player has no HumanoidRootPart")
                return 
            end
            
            local originalTargetAnchored = targetHRP.Anchored
            
            if not equipLaserGun() then 
                warn("[Anti-Desync] Failed to equip Laser Gun")
                return 
            end
            task.wait(EQUIP_DELAY)
            
            if not character:FindFirstChild("Laser Gun") then 
                warn("[Anti-Desync] Laser Gun not found after equip")
                return 
            end
            
            local originalCameraMode = variaveis.LocalPlayer.CameraMode
            local originalHRPCFrame = humanoidRootPart.CFrame
            
            variaveis.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            Camera.CameraType = Enum.CameraType.Custom
            task.wait(CAMERA_TRANSITION_DELAY)
            
            moveCharacterToFront(targetCharacter, TARGET_DISTANCE)
            task.wait(MOVEMENT_DELAY)
            
            rotateToTarget(targetHRP, humanoidRootPart)
            task.wait(ROTATION_DELAY)
            
            if LaserGunsShared and LaserGunsShared.ShootLocal then
                LaserGunsShared.ShootLocal()
            else
                warn("[Anti-Desync] ShootLocal function not found")
            end
            task.wait(RESTORE_DELAY)
            
            if originalHRPCFrame then
                humanoidRootPart.CFrame = originalHRPCFrame
                task.wait(RESTORE_DELAY)
            end
            
            variaveis.LocalPlayer.CameraMode = originalCameraMode
            Camera.CameraType = Enum.CameraType.Custom
            
            task.wait(UNEQUIP_DELAY)
            unequipLaserGun()
            
            if targetHRP and targetHRP.Parent then
                targetHRP.Anchored = originalTargetAnchored
            end
        end)
    end
    
    -- ========================================================================
    -- END ANTI-DESYNC SYSTEM
    -- ========================================================================
    
    local function executeCommand(player, command, source)
        if command == "hit" then
            task.spawn(function()
                antiDesyncShoot(player)
            end)
            return
        end
        
        if not remote then remote = findRemote() if not remote then return end end
        
        if isCommandOnCooldown(command) then
            return
        end
        
        local ok = pcall(function() remote:FireServer(player, command) end)
        if ok then
            lastCommandUse[command] = tick()
            if source=="proximity" and globalCommandsLeft>0 then
                globalCommandsLeft -= 1
                if globalCommandsLeft < 0 then globalCommandsLeft=0 end
            end
            
            if source == "manual" then
                local cooldownTime = commandCooldowns[command] or 0
                if cooldownTime > 0 then
                    task.spawn(function()
                        task.wait(cooldownTime)
                        local pool = playerCommandPools[player]
                        if pool and not table.find(pool, command) then
                            table.insert(pool, command)
                            for i = #pool, 2, -1 do 
                                local j = math.random(i) 
                                pool[i], pool[j] = pool[j], pool[i] 
                            end
                        end
                    end)
                end
            end
        end
    end
    
    -- Steal Detection System
    local PlayerStealing = {} -- [userId] = {pet = "PetName", gen = "$90M/s"}
    local PlayerStealingChanged = Instance.new("BindableEvent") -- Evento para atualizaÃ§Ã£o instantÃ¢nea
    local Synchronizer = require(variaveis.ReplicatedStorage.Packages.Synchronizer)
    local Plots = Workspace:WaitForChild("Plots")
    local AnimalsData = require(variaveis.ReplicatedStorage.Datas.Animals)
    local AnimalsShared = require(variaveis.ReplicatedStorage.Shared.Animals)
    local NumberUtils = require(variaveis.ReplicatedStorage.Utils.NumberUtils)
    local plotConnections = {} -- Para evitar conexÃµes duplicadas
    
    local function getGenerationString(index, mutation, traits)
        if index == "Coffin Tung Tung Tung Sahur" then return "N/A" end
        local gen = AnimalsShared:GetGeneration(index, mutation, traits, nil)
        -- FormataÃ§Ã£o consistente (evita 1000K em vez de 1M)
        if not gen or gen == 0 then return "$0/s" end
        if gen >= 1e15 then return string.format("$%.1fQ/s", gen / 1e15)
        elseif gen >= 1e12 then return string.format("$%.1fT/s", gen / 1e12)
        elseif gen >= 1e9 then return string.format("$%.1fB/s", gen / 1e9)
        elseif gen >= 1e6 then return string.format("$%.1fM/s", gen / 1e6)
        elseif gen >= 1e3 then return string.format("$%.1fK/s", gen / 1e3)
        else return string.format("$%d/s", math.floor(gen)) end
    end
    
    local function getPetDisplayName(index)
        local data = AnimalsData[index]
        return data and data.DisplayName or index
    end
    
    local function setupPlotMonitoring(plot)
        if not plot:IsA("Model") or not plot:GetAttribute("Tier") then return end
        if plotConnections[plot] then return end -- JÃ¡ estÃ¡ sendo monitorado
        
        plotConnections[plot] = true
        local channel = Synchronizer:Wait(plot.Name)
        local lastSteal = {}
        
        local function scan(animalList)
            if not animalList then return end
            
            for slot, entry in pairs(animalList) do
                if type(entry) == "table" and entry.Index then
                local prev = lastSteal[slot]
                    local now = (type(entry.Steal) == "number") and entry.Steal or nil
                
                    -- Detecta quando alguÃ©m comeÃ§a a roubar
                if not prev and now and type(now) == "number" then
                    local petName = getPetDisplayName(entry.Index)
                    local gen = getGenerationString(entry.Index, entry.Mutation, entry.Traits)
                    PlayerStealing[now] = {
                        pet = petName,
                        gen = gen
                    }
                        PlayerStealingChanged:Fire(now, PlayerStealing[now]) -- Notifica mudanÃ§a instantÃ¢nea
                end
                
                    -- Detecta quando alguÃ©m para de roubar
                if prev and not now then
                    PlayerStealing[prev] = nil
                        PlayerStealingChanged:Fire(prev, nil) -- Notifica remoÃ§Ã£o instantÃ¢nea
                    end
                    
                    -- Detecta mudanÃ§a de roubo (outro player roubando o mesmo slot)
                    if prev and now and prev ~= now then
                        -- Remove o anterior
                        PlayerStealing[prev] = nil
                        PlayerStealingChanged:Fire(prev, nil)
                        
                        -- Adiciona o novo
                        local petName = getPetDisplayName(entry.Index)
                        local gen = getGenerationString(entry.Index, entry.Mutation, entry.Traits)
                        PlayerStealing[now] = {
                            pet = petName,
                            gen = gen
                        }
                        PlayerStealingChanged:Fire(now, PlayerStealing[now])
                end
                
                lastSteal[slot] = now
                end
            end
        end
        
        -- Scan inicial
        scan(channel:Get("AnimalList") or {})
        
        -- Monitora mudanÃ§as (instantÃ¢neo via OnChanged)
        channel:OnChanged("AnimalList", function(newList)
            scan(newList or {})
        end, true)
        
        -- Scan periÃ³dico como backup (reduzido para evitar overhead de rede)
        task.spawn(function()
            while plot.Parent do
                task.wait(1) -- Aumentado de 0.2 para 1 segundo para reduzir overhead de rede
                local currentList = channel:Get("AnimalList")
                if currentList then
                    scan(currentList)
                end
            end
        end)
    end
    
    -- Monitora plots existentes
    for _, plot in Plots:GetChildren() do
        setupPlotMonitoring(plot)
    end
    
    -- Monitora novos plots (instantÃ¢neo)
    Plots.ChildAdded:Connect(function(plot)
        task.defer(function()
        setupPlotMonitoring(plot)
        end)
    end)
    
    -- Auto fire no andar atual quando comeÃ§ar a roubar (usando o mesmo sistema do admin panel)
    local localUserId = variaveis.LocalPlayer.UserId
    local wasStealing = false
    local lastFireTime = 0
    
    local function checkAndFireFloor()
        if not _G.oNineNearestPrompts or not _G.oNineFirePrompt then return end
        
        local hrp = (variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        if not hrp then return end
        
        -- Determina o andar baseado na posiÃ§Ã£o Y (consolidado)
        local floorNum = (hrp.Position.Y >= 31 and 3) or (hrp.Position.Y >= 14 and 2) or (hrp.Position.Y >= 0 and 1) or nil
        
        -- Faz fire no prompt do andar atual
        if floorNum and _G.oNineNearestPrompts[floorNum] and _G.oNineNearestPrompts[floorNum].prompt then
            local currentTime = tick()
            if currentTime - lastFireTime > 1 then
                lastFireTime = currentTime
                task.wait(0.1)
                _G.oNineFirePrompt(_G.oNineNearestPrompts[floorNum].prompt)
            end
        end
    end
    
    -- Sistema 1: Evento do PlayerStealingChanged
    PlayerStealingChanged.Event:Connect(function(userId, data)
        if userId == localUserId then
            local isStealing = data ~= nil
            if isStealing and not wasStealing then
                -- Acabou de comeÃ§ar a roubar
                wasStealing = true
                checkAndFireFloor()
            elseif not isStealing then
                -- Parou de roubar
                wasStealing = false
            end
        end
    end)
    
    -- Sistema 2: VerificaÃ§Ã£o periÃ³dica direta usando o mesmo mÃ©todo do monitoramento
    task.spawn(function()
        while true do
            task.wait(0.2) -- Verifica mais frequentemente
            local plots = Workspace:FindFirstChild("Plots")
            if plots then
                local foundStealing = false
                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:IsA("Model") and plot:GetAttribute("Tier") then
                        local ok, channel = pcall(function() return Synchronizer:Wait(plot.Name) end)
                        if ok and channel then
                            local animalList = channel:Get("AnimalList") or {}
                            for _, entry in pairs(animalList) do
                                if type(entry) == "table" and type(entry.Steal) == "number" and entry.Steal == localUserId then
                                    foundStealing = true
                                    break
                                end
                            end
                            if foundStealing then break end
                        end
                    end
                end
                
                if foundStealing and not wasStealing then
                    wasStealing = true
                    checkAndFireFloor()
                elseif not foundStealing and wasStealing then
                    wasStealing = false
                end
            end
        end
    end)
    
    -- Limpeza periÃ³dica de dados obsoletos e atualizaÃ§Ã£o ativa (otimizado para evitar ping alto)
    task.spawn(function()
        while true do
            task.wait(2) -- Aumentado de 1 para 2 segundos para reduzir ainda mais o overhead
            local activeStealers = {}
            
            -- Limita nÃºmero de plots processados por vez (evita sobrecarga)
            local plots = Plots:GetChildren()
            local maxPlotsPerCycle = 10 -- Processa no mÃ¡ximo 10 plots por ciclo
            local plotsProcessed = 0
            
            for _, plot in ipairs(plots) do
                if plotsProcessed >= maxPlotsPerCycle then break end
                
                if plot:IsA("Model") and plot:GetAttribute("Tier") then
                    local channel = Synchronizer:Get(plot.Name)
                    if channel then
                        local animalList = channel:Get("AnimalList") or {}
                        local animalsProcessed = 0
                        local maxAnimalsPerPlot = 20 -- Limita animais por plot
                        
                        for slot, entry in pairs(animalList) do
                            if animalsProcessed >= maxAnimalsPerPlot then break end
                            
                            if type(entry) == "table" and entry.Steal and type(entry.Steal) == "number" then
                                local userId = entry.Steal
                                activeStealers[userId] = true
                                
                                -- Atualiza se nÃ£o existe ou mudou
                                if not PlayerStealing[userId] then
                                    local petName = getPetDisplayName(entry.Index)
                                    local gen = getGenerationString(entry.Index, entry.Mutation, entry.Traits)
                                    PlayerStealing[userId] = {
                                        pet = petName,
                                        gen = gen
                                    }
                                    PlayerStealingChanged:Fire(userId, PlayerStealing[userId])
                                end
                                animalsProcessed = animalsProcessed + 1
                            end
                        end
                    end
                    plotsProcessed = plotsProcessed + 1
                end
            end
            
            -- Remove players que nÃ£o estÃ£o mais roubando
            for userId in pairs(PlayerStealing) do
                if not activeStealers[userId] then
                    PlayerStealing[userId] = nil
                    PlayerStealingChanged:Fire(userId, nil)
                end
            end
        end
    end)
    
    -- ========================================================================
    -- STEAL NEAREST FILTER PANEL
    -- ========================================================================
    
    local stealFilterPanel = createFrame(mainGui, UDim2.new(0, 240, 0, 220), UDim2.new(0, 20, 0.5, -330), THEME.DarkBg, 0.1)
    addCorners(stealFilterPanel, 12)
    addStroke(stealFilterPanel, THEME.AccentRed, 2, 0.3)
    
    local sfHeader = createFrame(stealFilterPanel, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), nil, 1)
    local sfTitleContainer, sfTitle, sfIcon = createTitleWithIcon(sfHeader, UDim2.new(1, -20, 1, 0), UDim2.new(0, 12, 0, 0), "Steal Target", 12, THEME.AccentWhite, 18)
    sfTitle.Font = Enum.Font.GothamBold
    addPinkGradient(sfTitle)
    
    -- Container para os brainrots (altura aumentada para caber 5 brainrots)
    local brainrotListFrame = createFrame(stealFilterPanel, UDim2.new(1, -20, 1, -40), UDim2.new(0, 10, 0, 35), nil, 1)
    
    local brainrotListLayout = Instance.new("UIListLayout")
    brainrotListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    brainrotListLayout.Padding = UDim.new(0, 4)
    brainrotListLayout.Parent = brainrotListFrame
    
    -- Estado do filtro
    local selectedTargetIndex = 1 -- Por padrÃ£o, foca no melhor (Ã­ndice 1)
    local currentBrainrotButtons = {}
    local currentBrainrotConnections = {} -- NOVO: Guardar conexÃµes para limpar
    local topBrainrots = {}
    local lastBrainrotHash = "" -- NOVO: Para evitar updates desnecessÃ¡rios
    
    -- FunÃ§Ã£o para formatar geraÃ§Ã£o curta
    local function formatGenShort(gen)
        if gen >= 1e15 then return string.format("%.1fQ", gen / 1e15)
        elseif gen >= 1e12 then return string.format("%.1fT", gen / 1e12)
        elseif gen >= 1e9 then return string.format("%.1fB", gen / 1e9)
        elseif gen >= 1e6 then return string.format("%.1fM", gen / 1e6)
        elseif gen >= 1e3 then return string.format("%.1fK", gen / 1e3)
        else return tostring(math.floor(gen))
        end
    end
    
    -- FunÃ§Ã£o para obter o dono do plot
    local function getPlotOwner(plot)
        if not plot then return "Unknown" end
        local sign = plot:FindFirstChild("PlotSign")
        if not sign then return "Unknown" end
        local surfaceGui = sign:FindFirstChildWhichIsA("SurfaceGui", true)
        if not surfaceGui then return "Unknown" end
        
        -- Tenta encontrar o nome do dono em qualquer TextLabel dentro do SurfaceGui
        for _, label in ipairs(surfaceGui:GetDescendants()) do
            if label:IsA("TextLabel") or label:IsA("TextBox") then
                local text = label.Text
                if text and text ~= "" then
                    -- Remove tags HTML/RichText se houver
                    text = text:gsub("<[^>]+>", "")
                    -- Tenta extrair o nome (pode estar em vÃ¡rios formatos)
                    local ownerName = text:match("Owner:?%s*(.+)") 
                        or text:match("(.+)'s Plot") 
                        or text:match("Plot of (.+)")
                        or text:match("(.+)'s")
                        or text
                    -- Limpa espaÃ§os extras
                    ownerName = ownerName:match("^%s*(.-)%s*$")
                    if ownerName and ownerName ~= "" and #ownerName > 0 then
                        return ownerName
                    end
                end
            end
        end
        
        -- Se nÃ£o encontrou, tenta pelo nome do plot (pode conter o nome do player)
        for _, player in Players:GetPlayers() do
            if plot.Name:find(player.Name) or plot.Name:find(player.DisplayName) then
                return player.DisplayName
            end
        end
        
        return "Unknown"
    end
    
    -- FunÃ§Ã£o para criar botÃ£o de brainrot
    local function createBrainrotButton(brainrot, index)
        local isSelected = index == selectedTargetIndex
        local btnColor = isSelected and THEME.AccentGreen or THEME.CardBg
        
        local btn = createFrame(brainrotListFrame, UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 0, 0), btnColor)
        btn.LayoutOrder = index
        addCorners(btn, 6)
        
        if isSelected then
            addStroke(btn, THEME.AccentGreen, 2, 0)
        else
            addStroke(btn, THEME.Border, 1, 0.5)
        end
        
        -- NÃºmero do ranking
        local rankLabel = createTextLabel(btn, UDim2.new(0, 18, 0, 15), UDim2.new(0, 5, 0, 2), "#" .. index, 9, isSelected and THEME.DarkBg or THEME.TextMuted)
        rankLabel.Font = Enum.Font.GothamBold
        rankLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        -- Nome do brainrot (linha 1)
        local nameLabel = createTextLabel(btn, UDim2.new(0.55, 0, 0, 15), UDim2.new(0, 23, 0, 2), brainrot.name, 10, isSelected and THEME.DarkBg or THEME.TextPrimary)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- GeraÃ§Ã£o (linha 1, direita)
        local genLabel = createTextLabel(btn, UDim2.new(0, 50, 0, 15), UDim2.new(1, -55, 0, 2), formatGenShort(brainrot.gen), 9, isSelected and THEME.DarkBg or THEME.AccentGreen)
        genLabel.Font = Enum.Font.GothamBold
        genLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        -- Dono do brainrot (linha 2) - maior e mais forte, igual ao nome
        local ownerLabel = createTextLabel(btn, UDim2.new(1, -10, 0, 15), UDim2.new(0, 23, 0, 17), "Owner: " .. (brainrot.owner or "Unknown"), 10, isSelected and THEME.DarkBg or THEME.TextPrimary)
        ownerLabel.Font = Enum.Font.GothamBold
        ownerLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- BotÃ£o invisÃ­vel para clique
        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.Parent = btn
        
        -- Guarda conexÃµes para limpeza
        local connections = {}
        
        connections[1] = clickBtn.MouseButton1Click:Connect(function()
            selectedTargetIndex = index
            
            -- Atualiza o target no Steal Nearest
            if _G.oNineStealNearest and topBrainrots[index] then
                local target = topBrainrots[index]
                _G.oNineStealNearest.currentBestPet = {
                    PlotName = target.plotName,
                    AnimalIndex = target.animalIndex,
                    PodiumID = target.podiumId,
                    G = target.gen
                }
                _G.oNineStealNearest.currentTargetName = target.name
                _G.oNineStealNearest.isHoldingVirtual = false
                _G.oNineStealNearest.manualTarget = true -- Flag para indicar seleÃ§Ã£o manual
            end
            
            -- ForÃ§a atualizaÃ§Ã£o do ESP imediatamente
            if _G.oNineForceESPUpdate then
                _G.oNineForceESPUpdate()
            end
            
            -- Refresh visual
            updateBrainrotList()
        end)
        
        -- Hover effect
        connections[2] = clickBtn.MouseEnter:Connect(function()
            if not isSelected then
                btn.BackgroundColor3 = Color3.fromRGB(35, 40, 50)
            end
        end)
        
        connections[3] = clickBtn.MouseLeave:Connect(function()
            if not isSelected then
                btn.BackgroundColor3 = THEME.CardBg
            end
        end)
        
        return btn, connections
    end
    
    -- FunÃ§Ã£o para atualizar lista de brainrots
    function updateBrainrotList()
        -- Coleta top 5 brainrots PRIMEIRO (antes de limpar)
        local newBrainrots = {}
        local followIndex = stealConfig["Follow Index"]
        
        for _, plot in Plots:GetChildren() do
            -- IGNORA PLOT DO PLAYER LOCAL
            if plot:IsA("Model") and plot:GetAttribute("Tier") and not isMyPlot(plot) then
                local channel = Synchronizer:Get(plot.Name)
                if channel then
                    local animalList = channel:Get("AnimalList") or {}
                    for podiumId, entry in pairs(animalList) do
                        if type(entry) == "table" and entry.Index then
                            local isFusing = entry.Fusing == true
                            local isMachineActive = entry.Machine and entry.Machine.Active == true
                            
                            if not isFusing and not isMachineActive then
                                local gen = AnimalsShared:GetGeneration(entry.Index, entry.Mutation, entry.Traits, nil)
                                local data = AnimalsData[entry.Index]
                                local displayName = data and data.DisplayName or entry.Index
                                
                                -- Usa geraÃ§Ã£o base do index se Follow Index estiver ativo
                                local sortValue = gen
                                if followIndex and data and data.Generation then
                                    sortValue = data.Generation
                                end
                                
                                -- ObtÃ©m o dono do plot
                                local plotOwner = getPlotOwner(plot)
                                
                                -- ObtÃ©m prioridade (se configurada)
                                local priority = _G.oNineGetBrainrotPriority and _G.oNineGetBrainrotPriority(entry.Index) or 999999
                                
                                table.insert(newBrainrots, {
                                    name = displayName,
                                    gen = gen,
                                    baseGen = (data and data.Generation) or 0,
                                    sortValue = sortValue,
                                    priority = priority,
                                    plotName = plot.Name,
                                    animalIndex = entry.Index,
                                    podiumId = podiumId,
                                    owner = plotOwner,
                                    uniqueId = plot.Name .. "_" .. tostring(podiumId) -- Identificador Ãºnico
                                })
                            end
                        end
                    end
                end
            end
        end
        
        -- Ordena usando prioridade primeiro, depois geraÃ§Ã£o, depois uniqueId
        table.sort(newBrainrots, function(a, b)
            -- Primeiro por prioridade (menor nÃºmero = maior prioridade)
            if a.priority ~= b.priority then
                return a.priority < b.priority
            end
            -- Se tÃªm a mesma prioridade, ordena por geraÃ§Ã£o
            if a.sortValue == b.sortValue then
                -- Se tÃªm a mesma geraÃ§Ã£o, usa uniqueId para garantir ordem consistente
                return a.uniqueId < b.uniqueId
            end
            return a.sortValue > b.sortValue
        end)
        
        -- Limita a 5
        while #newBrainrots > 5 do
            table.remove(newBrainrots)
        end
        
        -- Cria hash para verificar se mudou (evita updates desnecessÃ¡rios)
        local newHash = ""
        for _, b in ipairs(newBrainrots) do
            newHash = newHash .. b.uniqueId .. tostring(math.floor(b.gen))
        end
        newHash = newHash .. tostring(selectedTargetIndex)
        
        -- Se nÃ£o mudou, nÃ£o recria os botÃµes (evita memory leak)
        if newHash == lastBrainrotHash and #currentBrainrotButtons > 0 then
            return
        end
        lastBrainrotHash = newHash
        topBrainrots = newBrainrots
        
        -- AGORA limpa conexÃµes antigas (previne memory leak)
        for _, conn in pairs(currentBrainrotConnections) do
            if conn and conn.Disconnect then
                conn:Disconnect()
            end
        end
        currentBrainrotConnections = {}
        
        -- Limpa botÃµes antigos
        for _, btn in pairs(currentBrainrotButtons) do
            if btn and btn.Parent then
                btn:Destroy()
            end
        end
        currentBrainrotButtons = {}
        
        -- Valida selectedTargetIndex
        if selectedTargetIndex > #topBrainrots then
            selectedTargetIndex = 1
        end
        
        -- Cria botÃµes
        for i, brainrot in ipairs(topBrainrots) do
            local btn, connections = createBrainrotButton(brainrot, i)
            table.insert(currentBrainrotButtons, btn)
            -- Guarda todas as conexÃµes para limpeza futura
            for _, conn in pairs(connections) do
                table.insert(currentBrainrotConnections, conn)
            end
        end
        
        -- Se nÃ£o hÃ¡ brainrots
        if #topBrainrots == 0 then
            local emptyLabel = createTextLabel(brainrotListFrame, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), "No brainrots found", 11, THEME.TextMuted)
            emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
            table.insert(currentBrainrotButtons, emptyLabel)
        end
    end
    
    -- Inicializa e atualiza periodicamente (menos frequente para evitar memory leak)
    task.spawn(function()
        task.wait(1) -- Reduzido de 3 para 1
        updateBrainrotList()
        
        while true do
            task.wait(5) -- Aumentado para 5 segundos (era 2)
            -- SÃ³ atualiza se nÃ£o tiver seleÃ§Ã£o manual ativa
            if not (_G.oNineStealNearest and _G.oNineStealNearest.manualTarget) then
                selectedTargetIndex = 1
            end
            updateBrainrotList()
        end
    end)
    
    -- BotÃ£o para resetar para automÃ¡tico
    local autoBtn = createTextButton(stealFilterPanel, UDim2.new(0, 60, 0, 22), UDim2.new(1, -140, 0, 8), "AUTO", THEME.ButtonBg, 9)
    addCorners(autoBtn, 4)
    
    autoBtn.MouseButton1Click:Connect(function()
        selectedTargetIndex = 1
        if _G.oNineStealNearest then
            _G.oNineStealNearest.manualTarget = false
            _G.oNineStealNearest.isHoldingVirtual = false
        end
        
        -- ForÃ§a atualizaÃ§Ã£o do ESP imediatamente
        if _G.oNineForceESPUpdate then
            _G.oNineForceESPUpdate()
        end
        
        updateBrainrotList()
    end)
    
    -- BotÃ£o para desativar/ativar steal nearest (toggle)
    local stopBtn = createTextButton(stealFilterPanel, UDim2.new(0, 60, 0, 22), UDim2.new(1, -70, 0, 8), "OFF", THEME.ButtonBg, 9)
    addCorners(stopBtn, 4)
    addStroke(stopBtn, THEME.AccentRed, 1, 0.3)
    
    stopBtn.MouseButton1Click:Connect(function()
        if _G.oNineStealNearest then
            if _G.oNineStealNearest.active then
                -- Desativa
                _G.oNineStealNearest:Stop()
                stopBtn.Text = "OFF"
                stopBtn.BackgroundColor3 = THEME.ButtonBg
            else
                -- Reativa
                _G.oNineStealNearest:Start()
                stopBtn.Text = "ON"
                stopBtn.BackgroundColor3 = THEME.AccentGreen
            end
        end
    end)
    
    -- Monitora o estado do steal nearest para atualizar o botÃ£o
    task.spawn(function()
        while stealFilterPanel and stealFilterPanel.Parent do
            if _G.oNineStealNearest then
                if _G.oNineStealNearest.active then
                    stopBtn.Text = "ON"
                    stopBtn.BackgroundColor3 = THEME.AccentGreen
                else
                    stopBtn.Text = "OFF"
                    stopBtn.BackgroundColor3 = THEME.ButtonBg
                end
            end
            task.wait(0.5)
        end
    end)
    
    -- Quick Commands Panel (menor altura, maior largura)
    local quickCommandsPanel = createFrame(mainGui, UDim2.new(0, 320, 0, 240), UDim2.new(0, 20, 0.5, -120), THEME.DarkBg, 0.1)
    addCorners(quickCommandsPanel, 12)
    addStroke(quickCommandsPanel, THEME.AccentRed, 2, 0.3)
    
    local qcHeader = createFrame(quickCommandsPanel, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), nil, 1)
    local qcTitleContainer, qcTitle, qcIcon = createTitleWithIcon(qcHeader, UDim2.new(1, -50, 1, 0), UDim2.new(0, 15, 0, 0), "Moranguete Hub Proximity", 16, THEME.AccentWhite, 22)
    qcTitle.Font = Enum.Font.GothamBold
    addPinkGradient(qcTitle)
    
    local proximityFrame = createFrame(quickCommandsPanel, UDim2.new(1, -30, 0, 45), UDim2.new(0, 15, 0, 45), THEME.CardBg)
    addCorners(proximityFrame, 8)
    local proxTitleContainer, proxTitle, proxIcon = createTitleWithIcon(proximityFrame, UDim2.new(1, 0, 0, 20), UDim2.new(0, 10, 0, 5), "Proximity Commands", 13, THEME.TextPrimary, 16)
    proxTitle.Font = Enum.Font.GothamSemibold
    local proximityStatus = createTextLabel(proximityFrame, UDim2.new(1, -20, 0, 15), UDim2.new(0, 10, 0, 22), "", 10, THEME.TextMuted)
    local proximityToggle = createTextButton(proximityFrame, UDim2.new(0, 80, 0, 26), UDim2.new(1, -90, 0.5, -13), "DISABLED", THEME.ButtonBg, 11)
    addCorners(proximityToggle, 6)
    
    local rangeFrame = createFrame(quickCommandsPanel, UDim2.new(1, -30, 0, 50), UDim2.new(0, 15, 0, 95), THEME.CardBg)
    addCorners(rangeFrame, 8)
    local rangeText = createTextLabel(rangeFrame, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 5), "Proximity Range: 60 studs", 13, THEME.TextMuted)
    
    local sliderTrack = createFrame(rangeFrame, UDim2.new(1, -20, 0, 4), UDim2.new(0, 10, 0, 30), THEME.Border)
    addCorners(sliderTrack, 2)
    local sliderFill = createFrame(sliderTrack, UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 0, 0, 0), THEME.ButtonBg)
    addCorners(sliderFill, 2)
    local sliderHandle = createTextButton(sliderTrack, UDim2.new(0, 14, 0, 14), UDim2.new(0.5, -7, 0.5, -7), "", THEME.ButtonBg)
    addCorners(sliderHandle, 7)
    
    -- Carrega range salvo ou usa padrÃ£o
    local proximityRange = savedConfig.proximityRange or 60
    local draggingSlider = false
    
    -- Atualiza slider com valor carregado
    local function updateSliderFromRange()
        local normalizedRange = math.clamp((proximityRange - 20) / 180, 0, 1)
        rangeText.Text = "Proximity Range: " .. proximityRange .. " studs"
        sliderFill.Size = UDim2.new(normalizedRange, 0, 1, 0)
        sliderHandle.Position = UDim2.new(normalizedRange, -7, 0.5, -7)
    end
    updateSliderFromRange()
    
    -- CÃ­rculo visual do proximity range usando Beams (apenas borda, nÃ£o preenchido)
    local proximityCircle = nil
    local proximityCircleConnection = nil
    local proximityAttachments = {}
    
    -- ExpÃµe globalmente para o FPS Boost nÃ£o deletar (inicializa como nil)
    _G.oNineProximityCircle = nil
    
    local function createProximityCircle()
        if proximityCircle then
            if proximityCircleConnection then
                proximityCircleConnection:Disconnect()
                proximityCircleConnection = nil
            end
            proximityCircle:Destroy()
            proximityAttachments = {}
        end
        
        local hrp = variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then 
            warn("[Proximity Circle] HRP nÃ£o encontrado")
            return 
        end
        
        -- Cria folder para o cÃ­rculo
        local folder = Instance.new("Folder")
        folder.Name = "ProximityCircle_" .. generateUUID()
        folder.Parent = Workspace
        
        local points = 60 -- Quantidade de pontos
        local heightOffset = -3 -- Altura acima do chÃ£o
        
        -- Criar Attachments invisÃ­veis
        for i = 1, points do
            local part = Instance.new("Part")
            part.Name = "Point_" .. i .. "_" .. generateUUID()
            part.Size = Vector3.new(0.2, 0.2, 0.2)
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 1
            part.Parent = folder

            local attachment = Instance.new("Attachment")
            attachment.Name = "Attachment_" .. generateUUID()
            attachment.Parent = part
            table.insert(proximityAttachments, attachment)
        end
        
        -- Conectar os Beams
        for i = 1, points do
            local nextIndex = i % points + 1
            local beam = Instance.new("Beam")
            beam.Name = "Beam_" .. i .. "_" .. generateUUID()
            beam.Attachment0 = proximityAttachments[i]
            beam.Attachment1 = proximityAttachments[nextIndex]
            beam.FaceCamera = true
            beam.Width0 = 0.6
            beam.Width1 = 0.6
            beam.LightEmission = 1
            beam.Transparency = NumberSequence.new(0)
            beam.Color = ColorSequence.new(THEME.AccentRed)
            beam.Parent = folder
        end
        
        proximityCircle = folder
        _G.oNineProximityCircle = proximityCircle -- Atualiza referÃªncia global
        
        -- Posiciona os pontos inicialmente
        local hrp = variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local rootPos = hrp.Position + Vector3.new(0, -3, 0)
            local numPoints = #proximityAttachments
            for i, attachment in ipairs(proximityAttachments) do
                if attachment and attachment.Parent then
                    local angle = (i / numPoints) * math.pi * 2
                    local x = math.cos(angle) * proximityRange
                    local z = math.sin(angle) * proximityRange
                    attachment.Parent.Position = rootPos + Vector3.new(x, 0, z)
                end
            end
        end
        
        -- Atualizar posiÃ§Ã£o do cÃ­rculo
        proximityCircleConnection = variaveis.RunService.RenderStepped:Connect(function()
            if not proximityEnabled or not proximityCircle or not proximityCircle.Parent then
                return
            end
            
            local hrp = variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local rootPos = hrp.Position + Vector3.new(0, -3, 0) -- heightOffset fixo
            local numPoints = #proximityAttachments
            if numPoints > 0 then
                for i, attachment in ipairs(proximityAttachments) do
                    if attachment and attachment.Parent then
                        local angle = (i / numPoints) * math.pi * 2
                        local x = math.cos(angle) * proximityRange
                        local z = math.sin(angle) * proximityRange
                        attachment.Parent.Position = rootPos + Vector3.new(x, 0, z)
                    end
                end
            end
        end)
    end
    
    local function updateProximityCircle()
        -- O cÃ­rculo Ã© atualizado automaticamente pelo RenderStepped connection
        -- NÃ£o precisa de funÃ§Ã£o separada, mas mantemos para compatibilidade
    end
    
    local function updateSlider(mouseX)
        local trackPos = sliderTrack.AbsolutePosition.X
        local trackSize = sliderTrack.AbsoluteSize.X
        local relativeX = math.clamp((mouseX - trackPos) / trackSize, 0, 1)
        
        proximityRange = math.floor(20 + (relativeX * 180))
        rangeText.Text = "Proximity Range: " .. proximityRange .. " studs"
        
        sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderHandle.Position = UDim2.new(relativeX, -7, 0.5, -7)
        
        -- Salva range no config
        savedConfig.proximityRange = proximityRange
        saveConfig()
        
        -- Recria cÃ­rculo para atualizar tamanho
        if proximityEnabled then
            createProximityCircle()
        end
    end
    
    sliderHandle.MouseButton1Down:Connect(function()
        draggingSlider = true
    end)
    
    variaveis.UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)
    
    variaveis.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = false
        end
    end)
    
    local autoTurretFrame = createFrame(quickCommandsPanel, UDim2.new(1, -30, 0, 45), UDim2.new(0, 15, 0, 150), THEME.CardBg)
    addCorners(autoTurretFrame, 8)
    local turretTitleContainer, turretTitle, turretIcon = createTitleWithIcon(autoTurretFrame, UDim2.new(1, 0, 0, 20), UDim2.new(0, 10, 0, 5), "Auto Destroy Turret", 13, THEME.TextPrimary, 16)
    turretTitle.Font = Enum.Font.GothamSemibold
    local autoTurretToggle = createTextButton(autoTurretFrame, UDim2.new(0, 80, 0, 26), UDim2.new(1, -90, 0.5, -13), "OFF", THEME.ButtonBg, 11)
    addCorners(autoTurretToggle, 6)
    
    autoTurretToggle.MouseButton1Click:Connect(function()
        if _G.oNineAutoTurret then
            if _G.oNineAutoTurret.IsEnabled() then
                _G.oNineAutoTurret.Disable()
                autoTurretToggle.Text = "OFF"
                autoTurretToggle.BackgroundColor3 = THEME.ButtonBg
            else
                _G.oNineAutoTurret.Enable()
                autoTurretToggle.Text = "ON"
                autoTurretToggle.BackgroundColor3 = THEME.ButtonBg
            end
        end
    end)
    
    -- Troll Panel (maior largura, menor altura)
    local trollPanel = createFrame(mainGui, UDim2.new(0, 380, 0, 480), UDim2.new(1, -400, 0.5, -240), THEME.DarkBg, 0.1)
    addCorners(trollPanel, 12)
    addStroke(trollPanel, THEME.AccentRed, 2, 0.3)
    
    local trollHeader = createFrame(trollPanel, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), nil, 1)
    local trollTitleContainer, trollTitle, trollIcon = createTitleWithIcon(trollHeader, UDim2.new(1, -50, 1, 0), UDim2.new(0, 15, 0, 0), "Moranguete Hub Command Center", 16, THEME.AccentWhite, 22)
    trollTitle.Font = Enum.Font.GothamBold
    addPinkGradient(trollTitle)
    
    local allButtonFrame = createFrame(trollPanel, UDim2.new(1, -30, 0, 35), UDim2.new(0, 15, 0, 45), THEME.CardBg)
    addCorners(allButtonFrame, 8)
    local allTitleContainer, allTitle, allIcon = createTitleWithIcon(allButtonFrame, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 10, 0, 0), "Execute All", 12, THEME.TextPrimary, 14)
    allTitle.Font = Enum.Font.GothamSemibold
    local allButton = createTextButton(allButtonFrame, UDim2.new(0, 60, 0, 22), UDim2.new(1, -65, 0.5, -11), "ON", THEME.ButtonBg, 10)
    addCorners(allButton, 6)
    
    local allModeEnabled = true
    allButton.MouseButton1Click:Connect(function()
        allModeEnabled = not allModeEnabled
        allButton.Text = allModeEnabled and "ON" or "OFF"
        allButton.BackgroundColor3 = THEME.ButtonBg
    end)
    
    local ragdollSelfFrame = createFrame(trollPanel, UDim2.new(1, -30, 0, 35), UDim2.new(0, 15, 0, 85), THEME.CardBg)
    addCorners(ragdollSelfFrame, 8)
    local ragdollTitleContainer, ragdollTitle, ragdollIcon = createTitleWithIcon(ragdollSelfFrame, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 10, 0, 0), "Ragdoll Self", 12, THEME.TextPrimary, 14)
    ragdollTitle.Font = Enum.Font.GothamSemibold
    local ragdollSelfButton = createTextButton(ragdollSelfFrame, UDim2.new(0, 80, 0, 26), UDim2.new(1, -90, 0.5, -13), "RAGDOLL", THEME.ButtonBg, 10)
    addCorners(ragdollSelfButton, 6)
    
    ragdollSelfButton.MouseButton1Click:Connect(function()
        if not isCommandOnCooldown("ragdoll") then
            executeCommand(variaveis.LocalPlayer, "ragdoll", "manual")
        end
    end)
    
    local playerListFrame = Instance.new("ScrollingFrame")
    playerListFrame.Size = UDim2.new(1, -30, 1, -130)
    playerListFrame.Position = UDim2.new(0, 15, 0, 125)
    playerListFrame.BackgroundTransparency = 1
    playerListFrame.BorderSizePixel = 0
    playerListFrame.ScrollBarThickness = 4
    playerListFrame.ScrollBarImageColor3 = THEME.AccentRed
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
    playerListFrame.Parent = trollPanel
    
    local playerListLayout = Instance.new("UIListLayout")
    playerListLayout.SortOrder = Enum.SortOrder.Name
    playerListLayout.Padding = UDim.new(0, 4)
    playerListLayout.Parent = playerListFrame
    
    -- Atualiza o canvas size dinamicamente (7 players mÃ¡ximo)
    playerListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local contentSize = playerListLayout.AbsoluteContentSize
        -- Calcula altura necessÃ¡ria: 7 players * 45px + 6 padding * 4px = 315 + 24 = 339
        local calculatedHeight = contentSize.Y
        playerListFrame.CanvasSize = UDim2.new(0, 0, 0, calculatedHeight)
    end)
    
    -- Cooldowns Panel
    local cooldownsPanel = createFrame(mainGui, UDim2.new(0, 200, 0, 220), UDim2.new(1, -220, 1, -240), THEME.DarkBg, 0.1)
    addCorners(cooldownsPanel, 12)
    addStroke(cooldownsPanel, THEME.AccentRed, 2, 0.3)
    
    local cooldownHeader = createTextLabel(cooldownsPanel, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 10), "Admin Panel Cooldowns", 14, THEME.AccentWhite)
    cooldownHeader.Font = Enum.Font.GothamBold
    addPinkGradient(cooldownHeader)
    
    local cooldownLabels = {}
    local cooldownCommandsList = {
        {name = "Rocket", cmd = "rocket", color = THEME.AccentOrange},
        {name = "Ragdoll", cmd = "ragdoll", color = THEME.AccentRed}, 
        {name = "Balloon", cmd = "balloon", color = Color3.fromRGB(50, 200, 50)},
        {name = "Inverse", cmd = "inverse", color = THEME.AccentCyan},
        {name = "Jail", cmd = "jail", color = THEME.AccentRed},
        {name = "NightVision", cmd = "nightvision", color = THEME.AccentRed},
        {name = "Tiny", cmd = "tiny", color = THEME.AccentGreen},
        {name = "Morph", cmd = "morph", color = THEME.AccentRed}
    }
    
    for i, cmd in ipairs(cooldownCommandsList) do
        local cooldownItem = createFrame(cooldownsPanel, UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 40 + (i-1) * 18), nil, 1)
        createTextLabel(cooldownItem, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 0, 0, 0), cmd.name .. ":", 11, THEME.TextSecondary)
        local statusLabel = createTextLabel(cooldownItem, UDim2.new(0.4, 0, 1, 0), UDim2.new(0.6, 0, 0, 0), "Ready", 11, THEME.AccentGreen)
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.Font = Enum.Font.GothamBold
        cooldownLabels[cmd.cmd] = statusLabel
    end
    
    -- Player List Functions
    local function resetPlayerPool(plr)
        playerCommandPools[plr] = table.clone(commands)
        for i = #playerCommandPools[plr], 2, -1 do 
            local j = math.random(i) 
            playerCommandPools[plr][i], playerCommandPools[plr][j] = playerCommandPools[plr][j], playerCommandPools[plr][i] 
        end
    end
    
    local playerFrames = {}
    
    local function createPlayerButton(player)
        local playerFrame = createFrame(playerListFrame, UDim2.new(1, -5, 0, 45), UDim2.new(0, 0, 0, 0), THEME.CardBg)
        playerFrame.Name = "Player_" .. player.Name
        playerFrame.ClipsDescendants = true
        addCorners(playerFrame, 6)
        playerFrames[player] = playerFrame
        
        -- Nome do player (linha de cima)
        local nameLabel = createTextLabel(playerFrame, UDim2.new(1, -130, 0, 20), UDim2.new(0, 8, 0, 3), player.DisplayName, 12, THEME.TextPrimary)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Info do roubo (linha de baixo)
        local stealLabel = createTextLabel(playerFrame, UDim2.new(1, -130, 0, 18), UDim2.new(0, 8, 0, 22), "", 11, THEME.TextMuted)
        stealLabel.Font = Enum.Font.Gotham
        stealLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        local function updateStealInfo()
            local stealData = PlayerStealing[player.UserId]
            if stealData then
                stealLabel.Text = stealData.pet .. " " .. stealData.gen
                stealLabel.TextColor3 = Color3.fromRGB(255, 105, 180)
                nameLabel.TextColor3 = Color3.fromRGB(255, 20, 147)
            else
                stealLabel.Text = ""
                nameLabel.TextColor3 = THEME.TextPrimary
            end
        end
        
        updateStealInfo()
        
        -- AtualizaÃ§Ã£o instantÃ¢nea via evento
        local connection = PlayerStealingChanged.Event:Connect(function(userId, data)
            if userId == player.UserId then
                updateStealInfo()
            end
        end)
        
        -- Cleanup quando o frame for destruÃ­do
        playerFrame.AncestryChanged:Connect(function()
            if not playerFrame.Parent then
                connection:Disconnect()
            end
        end)
        
        -- Backup periÃ³dico (menos frequente, apenas para garantir)
        task.spawn(function()
            while playerFrame.Parent do
                task.wait(5) -- Reduzido para 5 segundos, apenas backup
                updateStealInfo()
            end
        end)
        
        -- BotÃµes compactos (alinhados Ã  direita, dentro do frame)
        local buttons = {}
        
        if utils["Anti Desync"] then
            table.insert(buttons, {text = "HIT", color = THEME.ButtonBg, command = "hit"})
        end
        
        table.insert(buttons, {text = "BLN", color = THEME.ButtonBg, command = "balloon"})
        table.insert(buttons, {text = "RKT", color = THEME.ButtonBg, command = "rocket"})
        table.insert(buttons, {text = "RAG", color = THEME.ButtonBg, command = "ragdoll"})
        table.insert(buttons, {text = "JAIL", color = THEME.ButtonBg, command = "jail"})
        
        -- Posiciona botÃµes da direita para esquerda (28px cada + 2px gap)
        local btnWidth = 28
        local btnGap = 2
        local rightPadding = 4
        
        for i, btn in ipairs(buttons) do
            local xOffset = rightPadding + (i - 1) * (btnWidth + btnGap)
            local button = createTextButton(playerFrame, UDim2.new(0, btnWidth, 0, 26), UDim2.new(1, -(xOffset + btnWidth), 0.5, -13), btn.text, btn.color, 8)
            button.Font = Enum.Font.GothamBold
            addCorners(button, 4)
            
            button.MouseButton1Click:Connect(function()
                if not isCommandOnCooldown(btn.command) then
                    executeCommand(player, btn.command, "manual")
                end
            end)
            
            task.spawn(function()
                while button.Parent do
                    if isCommandOnCooldown(btn.command) then
                        button.BackgroundTransparency = 0.6
                        button.TextTransparency = 0.5
                    else
                        button.BackgroundTransparency = 0
                        button.TextTransparency = 0
                    end
                    task.wait(1)
                end
            end)
        end
        
        playerFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and allModeEnabled then
                for cmdName, _ in pairs(commandCooldowns) do
                    if not isCommandOnCooldown(cmdName) then
                        executeCommand(player, cmdName, "manual")
                        task.wait(0.1)
                    end
                end
            end
        end)
        
        return playerFrame
    end
    
    local function refreshPlayerList()
        if not playerListFrame or not playerListFrame.Parent then return end
        
        pcall(function()
            for _, child in ipairs(playerListFrame:GetChildren()) do
                if child:IsA("Frame") and child.Name:find("Player_") then
                    child:Destroy()
                end
            end
            
            playerFrames = {}
            
            if Players and Players.GetPlayers then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= variaveis.LocalPlayer then
                        if not playerCommandPools[player] then
                            resetPlayerPool(player)
                        end
                        createPlayerButton(player)
                    end
                end
            end
        end)
    end
    
    variaveis.Players.PlayerAdded:Connect(function()
        task.defer(function()
            refreshPlayerList()
        end)
    end)
    variaveis.Players.PlayerRemoving:Connect(function(player)
        playerFrames[player] = nil
        task.defer(function()
        refreshPlayerList()
        end)
    end)
    
    -- Atualiza steal target quando players entram/saem
    variaveis.Players.PlayerAdded:Connect(function()
        task.defer(function()
            updateBrainrotList()
        end)
    end)
    variaveis.Players.PlayerRemoving:Connect(function()
        task.defer(function()
            updateBrainrotList()
        end)
    end)
    
    -- Proximity Toggle
    local function toggleProximity()
        proximityEnabled = not proximityEnabled
        proximityToggle.Text = proximityEnabled and "ENABLED" or "DISABLED"
        proximityToggle.BackgroundColor3 = THEME.ButtonBg
        
        -- Atualiza cÃ­rculo visual
        if proximityEnabled then
            -- Reseta contador de comandos e cria pools para todos os players
            globalCommandsLeft = #commands
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= variaveis.LocalPlayer then
                    if not playerCommandPools[plr] then
                        resetPlayerPool(plr)
                    end
                end
            end
            createProximityCircle()
        else
            if proximityCircleConnection then
                proximityCircleConnection:Disconnect()
                proximityCircleConnection = nil
            end
            if proximityCircle then
                proximityCircle:Destroy()
                proximityCircle = nil
                _G.oNineProximityCircle = nil
                proximityAttachments = {}
            end
        end
    end
    
    proximityToggle.MouseButton1Click:Connect(toggleProximity)
    
    -- ExpÃµe funÃ§Ã£o globalmente para keybind
    _G.oNineToggleProximity = toggleProximity
    
    -- Cooldown update loop
    task.spawn(function()
        while true do
            for command, label in pairs(cooldownLabels) do
                if isCommandOnCooldown(command) then
                    local remaining = math.ceil(getRemainingCooldown(command))
                    label.Text = remaining .. "s"
                    label.TextColor3 = THEME.AccentRed
                else
                    label.Text = "Ready"
                    label.TextColor3 = THEME.AccentGreen
                end
            end
            task.wait(1)
        end
    end)
    
    -- Cria cÃ­rculo inicial se proximity estiver habilitado
    task.spawn(function()
        task.wait(1)
        if proximityEnabled then
            createProximityCircle()
        end
    end)
    
    -- Atualiza cÃ­rculo quando personagem muda
    variaveis.LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if proximityEnabled then
            createProximityCircle()
        end
    end)
    
    -- Proximity loop (otimizado com throttling para evitar ping alto)
    local lastProximityCheck = 0
    local proximityCheckInterval = 0.2 -- Verifica a cada 0.2s ao invÃ©s de a cada frame
    variaveis.RunService.Heartbeat:Connect(function()
        if not proximityEnabled then return end
        
        -- Throttling: sÃ³ verifica a cada X segundos
        local now = tick()
        if now - lastProximityCheck < proximityCheckInterval then return end
        lastProximityCheck = now
        
        local hrp = variaveis.LocalPlayer.Character and variaveis.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") 
        if not hrp then return end
        local myPos = hrp.Position
        
        -- Atualiza posiÃ§Ã£o do cÃ­rculo
        if proximityCircle then
            updateProximityCircle()
        end
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= variaveis.LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if (plr.Character.HumanoidRootPart.Position - myPos).Magnitude <= proximityRange then
                    if (not lastHit[plr]) or (tick() - lastHit[plr]) >= 1.5 then
                        local pool = playerCommandPools[plr]
                        if pool and #pool > 0 then
                            -- Se globalCommandsLeft chegou a zero, reseta todos os pools e o contador
                            if globalCommandsLeft <= 0 then
                                globalCommandsLeft = #commands
                                for _, p in ipairs(Players:GetPlayers()) do
                                    if p ~= variaveis.LocalPlayer and playerCommandPools[p] then
                                        resetPlayerPool(p)
                                    end
                                end
                            end
                            
                            if globalCommandsLeft > 0 then
                                local cmd = table.remove(pool, 1)
                                executeCommand(plr, cmd, "proximity")
                                lastHit[plr] = tick()
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Draggable panels com save automÃ¡tico
    local function makeDraggable(frame, panelName)
        local dragging, dragStart, startPos
        local saveDebounce = nil
        
        -- Carrega posiÃ§Ã£o salva se existir
        if savedPositions[panelName] then
            local pos = savedPositions[panelName]
            frame.Position = UDim2.new(pos.XScale, pos.XOffset, pos.YScale, pos.YOffset)
        end
        
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        
                        -- Salva posiÃ§Ã£o quando para de arrastar (com debounce)
                        if saveDebounce then
                            task.cancel(saveDebounce)
                        end
                        saveDebounce = task.delay(0.5, function()
                            savedPositions[panelName] = {
                                XScale = frame.Position.X.Scale,
                                XOffset = frame.Position.X.Offset,
                                YScale = frame.Position.Y.Scale,
                                YOffset = frame.Position.Y.Offset
                            }
                            if type(savePositions) == "function" then
                                savePositions()
                            end
                        end)
                    end
                end)
            end
        end)
        
        variaveis.UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end
    
    makeDraggable(stealFilterPanel, "stealFilterPanel")
    makeDraggable(quickCommandsPanel, "quickCommandsPanel")
    makeDraggable(trollPanel, "trollPanel")
    makeDraggable(cooldownsPanel, "cooldownsPanel")
    
    -- ========================================================================
    -- JOB ID JOINER (Centro baixo da tela)
    -- ========================================================================
    
    local jobIdPanel = createFrame(mainGui, UDim2.new(0, 320, 0, 120), UDim2.new(0.5, -160, 1, -300), THEME.DarkBg, 0.1)
    addCorners(jobIdPanel, 12)
    addStroke(jobIdPanel, THEME.AccentRed, 2, 0.3)
    
    local jobIdHeader = createFrame(jobIdPanel, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), nil, 1)
    local jobIdTitle = createTextLabel(jobIdHeader, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 12, 0, 0), "Job ID Joiner", 13, THEME.AccentWhite)
    jobIdTitle.Font = Enum.Font.GothamBold
    addPinkGradient(jobIdTitle)
    
    -- Loop toggle
    local loopEnabled = false
    local loopToggle = createTextButton(jobIdPanel, UDim2.new(0, 60, 0, 22), UDim2.new(1, -70, 0, 4), "LOOP", THEME.ButtonBg, 9)
    addCorners(loopToggle, 6)
    addStroke(loopToggle, THEME.Border, 1, 0.5)
    
    -- Input box
    local jobIdInputFrame = createFrame(jobIdPanel, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 30), THEME.CardBg)
    addCorners(jobIdInputFrame, 8)
    addStroke(jobIdInputFrame, THEME.Border, 1, 0.3)
    
    local jobIdInput = Instance.new("TextBox")
    jobIdInput.Size = UDim2.new(1, -16, 1, 0)
    jobIdInput.Position = UDim2.new(0, 8, 0, 0)
    jobIdInput.BackgroundTransparency = 1
    jobIdInput.Text = ""
    jobIdInput.PlaceholderText = "Paste Job ID here..."
    jobIdInput.PlaceholderColor3 = THEME.TextMuted
    jobIdInput.Font = Enum.Font.GothamMedium
    jobIdInput.TextSize = 12
    jobIdInput.TextColor3 = THEME.TextPrimary
    jobIdInput.TextXAlignment = Enum.TextXAlignment.Left
    jobIdInput.ClearTextOnFocus = false
    jobIdInput.Parent = jobIdInputFrame
    
    -- Status label
    local jobIdStatus = createTextLabel(jobIdPanel, UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 66), "Paste a Job ID to join instantly", 10, THEME.TextMuted)
    jobIdStatus.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Loop status
    local loopStatus = createTextLabel(jobIdPanel, UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 82), "", 9, THEME.TextMuted)
    loopStatus.TextXAlignment = Enum.TextXAlignment.Center
    
    -- VariÃ¡veis de controle - movidas para global para reduzir variÃ¡veis locais
    if not _G.oNineShared.JobIdControls then
        _G.oNineShared.JobIdControls = {
            lastJobId = "",
            isJoining = false,
            loopThread = nil,
            attemptCount = 0
        }
    end
    local controls = _G.oNineShared.JobIdControls
    
    -- FunÃ§Ã£o para validar Job ID (formato UUID)
    local function isValidJobId(text)
        if not text or #text < 30 then return false end
        return text:match("^[%w%-]+$") ~= nil and #text >= 30
    end
    
    -- FunÃ§Ã£o para tentar entrar no servidor
    local function tryJoinServer(jobId, isLoopAttempt)
        if not isValidJobId(jobId) then
            if not isLoopAttempt then
                jobIdStatus.Text = "âŒ Invalid Job ID format"
                jobIdStatus.TextColor3 = THEME.AccentRed
            end
            return false
        end
        
        if not isLoopAttempt then
            controls.isJoining = true
            jobIdStatus.Text = "â³ Joining server..."
            jobIdStatus.TextColor3 = THEME.AccentOrange
        end
        
        controls.attemptCount = controls.attemptCount + 1
        
        if loopEnabled then
            loopStatus.Text = "Loop ON | Attempt #" .. controls.attemptCount
            loopStatus.TextColor3 = THEME.AccentCyan
        end
        
        -- Tenta teleportar
        local success, err = pcall(function()
            variaveis.TeleportService:TeleportToPlaceInstance(PlaceId, jobId, variaveis.LocalPlayer)
        end)
        
        if success then
            jobIdStatus.Text = "Teleporting..."
            jobIdStatus.TextColor3 = THEME.AccentGreen
            loopStatus.Text = ""
            return true
        else
            if not loopEnabled then
                controls.isJoining = false
                jobIdStatus.Text = "Failed - try again"
                jobIdStatus.TextColor3 = THEME.AccentRed
            else
                jobIdStatus.Text = "Retrying..."
                jobIdStatus.TextColor3 = THEME.AccentOrange
            end
            return false
        end
    end
    
    -- Loop de tentativas
    local function startLoop(jobId)
        if controls.loopThread then
            task.cancel(controls.loopThread)
        end
        
        controls.attemptCount = 0
        
        controls.loopThread = task.spawn(function()
            while loopEnabled do
                tryJoinServer(jobId, true)
                task.wait(0.2)
            end
            loopStatus.Text = ""
        end)
    end
    
    local function stopLoop()
        if controls.loopThread then
            task.cancel(controls.loopThread)
            controls.loopThread = nil
        end
        loopStatus.Text = ""
        controls.attemptCount = 0
    end
    
    -- Toggle loop
    loopToggle.MouseButton1Click:Connect(function()
        loopEnabled = not loopEnabled
        
        if loopEnabled then
            loopToggle.BackgroundColor3 = THEME.ButtonBg
            loopToggle.Text = "LOOP"
            addStroke(loopToggle, THEME.ButtonBg, 1, 0)
            
            -- Se jÃ¡ tem um Job ID, comeÃ§a o loop
            local text = jobIdInput.Text:gsub("%s+", "")
            if isValidJobId(text) then
                startLoop(text)
            end
        else
            loopToggle.BackgroundColor3 = THEME.ButtonBg
            loopToggle.Text = "LOOP"
            addStroke(loopToggle, THEME.Border, 1, 0.5)
            stopLoop()
        end
    end)
    
    -- Detecta mudanÃ§a no texto (quando cola)
    jobIdInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = jobIdInput.Text:gsub("%s+", "")
        
        if text ~= controls.lastJobId and #text > 20 then
            controls.lastJobId = text
            
            task.delay(0.1, function()
                if jobIdInput.Text:gsub("%s+", "") == text then
                    if loopEnabled then
                        stopLoop()
                        startLoop(text)
                    else
                        tryJoinServer(text, false)
                    end
                end
            end)
        end
    end)
    
    -- TambÃ©m funciona com Enter (backup)
    jobIdInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local text = jobIdInput.Text:gsub("%s+", "")
            if #text > 20 then
                if loopEnabled then
                    stopLoop()
                    startLoop(text)
                else
                    tryJoinServer(text, false)
                end
            end
        end
    end)
    
    -- Hover effect no input
    jobIdInput.Focused:Connect(function()
        smoothTween(jobIdInputFrame, {BackgroundColor3 = Color3.fromRGB(30, 35, 45)}, 0.2)
    end)
    
    jobIdInput.FocusLost:Connect(function()
        smoothTween(jobIdInputFrame, {BackgroundColor3 = THEME.CardBg}, 0.2)
    end)
    
    makeDraggable(jobIdPanel, "jobIdPanel")
    
    -- ========================================================================
    -- STEAL PRIORITY CONFIGURATION
    -- ========================================================================
    
    if not _G.oNineShared then _G.oNineShared = {} end
    _G.oNineShared.priorityFile = folder .. "/steal-priority.json"
    _G.oNineShared.stealPriority = _G.oNineShared.stealPriority or {}
    _G.oNineShared.priorityEnabled = _G.oNineShared.priorityEnabled ~= false
    
    local function loadPriorities()
        pcall(function()
            if isfile and readfile and isfile(_G.oNineShared.priorityFile) then
                local data = readfile(_G.oNineShared.priorityFile)
                _G.oNineShared.stealPriority = variaveis.HttpService:JSONDecode(data) or {}
            end
        end)
    end
    
    local function savePriorities()
        pcall(function()
            if writefile then
                local data = variaveis.HttpService:JSONEncode(_G.oNineShared.stealPriority)
                writefile(_G.oNineShared.priorityFile, data)
            end
        end)
    end
    
    loadPriorities()
    
    local function getBrainrotPriority(animalIndex)
        if not _G.oNineShared.priorityEnabled then return 999999 end
        return _G.oNineShared.stealPriority[animalIndex] or 999999
    end
    
    -- ExpÃµe funÃ§Ã£o globalmente para uso no steal nearest e ESP
    _G.oNineGetBrainrotPriority = getBrainrotPriority
    
    -- BotÃ£o no canto inferior esquerdo
    local priorityBtn = createTextButton(mainGui, UDim2.new(0, 50, 0, 50), UDim2.new(0, 20, 1, -70), "âš™", THEME.ButtonBg, 20)
    addCorners(priorityBtn, 8)
    addStroke(priorityBtn, THEME.AccentRed, 2, 0.3)
    priorityBtn.TextColor3 = THEME.AccentRed
    
    -- Interface de configuraÃ§Ã£o (inicialmente oculta)
    local priorityConfigGui = createFrame(mainGui, UDim2.new(0, 500, 0, 600), UDim2.new(0.5, -250, 0.5, -300), THEME.DarkBg, 0.1)
    addCorners(priorityConfigGui, 12)
    addStroke(priorityConfigGui, THEME.AccentRed, 2, 0.3)
    priorityConfigGui.Visible = false
    
    local priorityHeader = createFrame(priorityConfigGui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), nil, 1)
    local priorityTitle = createTextLabel(priorityHeader, UDim2.new(1, -90, 1, 0), UDim2.new(0, 15, 0, 0), "ðŸ“ Steal Priority Config", 16, THEME.AccentWhite)
    priorityTitle.Font = Enum.Font.GothamBold
    addPinkGradient(priorityTitle)
    
    local toggleBtn = createTextButton(priorityHeader, UDim2.new(0, 50, 0, 25), UDim2.new(1, -50, 0.5, -12.5), "ON", THEME.ButtonBg, 10)
    addCorners(toggleBtn, 6)
    toggleBtn.TextColor3 = THEME.AccentGreen
    
    local function updateToggleBtn()
        if _G.oNineShared.priorityEnabled then
            toggleBtn.Text = "ON"
            toggleBtn.TextColor3 = THEME.AccentGreen
        else
            toggleBtn.Text = "OFF"
            toggleBtn.TextColor3 = THEME.AccentRed
        end
    end
    updateToggleBtn()
    
    toggleBtn.MouseButton1Click:Connect(function()
        _G.oNineShared.priorityEnabled = not _G.oNineShared.priorityEnabled
        updateToggleBtn()
    end)
    
    local closeBtn = createTextButton(priorityHeader, UDim2.new(0, 30, 0, 30), UDim2.new(1, -10, 0.5, -15), "Ã—", THEME.ButtonBg, 20)
    addCorners(closeBtn, 6)
    closeBtn.TextColor3 = THEME.AccentRed
    
    local priorityGUI = {}
    priorityGUI.listFrame = createFrame(priorityConfigGui, UDim2.new(1, -30, 1, -100), UDim2.new(0, 15, 0, 50), nil, 1)
    priorityGUI.listLayout = Instance.new("UIListLayout")
    priorityGUI.listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    priorityGUI.listLayout.Padding = UDim.new(0, 4)
    priorityGUI.listLayout.Parent = priorityGUI.listFrame
    
    priorityGUI.listScroll = Instance.new("ScrollingFrame")
    priorityGUI.listScroll.Size = UDim2.new(1, 0, 1, 0)
    priorityGUI.listScroll.Position = UDim2.new(0, 0, 0, 0)
    priorityGUI.listScroll.BackgroundTransparency = 1
    priorityGUI.listScroll.BorderSizePixel = 0
    priorityGUI.listScroll.ScrollBarThickness = 4
    priorityGUI.listScroll.ScrollBarImageColor3 = THEME.AccentRed
    priorityGUI.listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    priorityGUI.listScroll.Parent = priorityGUI.listFrame
    
    priorityGUI.listLayout2 = Instance.new("UIListLayout")
    priorityGUI.listLayout2.SortOrder = Enum.SortOrder.LayoutOrder
    priorityGUI.listLayout2.Padding = UDim.new(0, 4)
    priorityGUI.listLayout2.Parent = priorityGUI.listScroll
    
    priorityGUI.listLayout2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        priorityGUI.listScroll.CanvasSize = UDim2.new(0, 0, 0, priorityGUI.listLayout2.AbsoluteContentSize.Y)
    end)
    
    priorityGUI.addBtn = createTextButton(priorityConfigGui, UDim2.new(0, 120, 0, 35), UDim2.new(1, -145, 1, -50), "+ Add Brainrot", THEME.ButtonBg, 12)
    addCorners(priorityGUI.addBtn, 8)
    addStroke(priorityGUI.addBtn, THEME.AccentGreen, 2, 0.3)
    priorityGUI.addBtn.TextColor3 = THEME.AccentGreen
    
    local function updatePriorityList()
        for _, child in ipairs(priorityGUI.listScroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Converte para array e ordena por prioridade
        local priorityArray = {}
        for index, priority in pairs(_G.oNineShared.stealPriority) do
            table.insert(priorityArray, {index = index, priority = priority})
        end
        table.sort(priorityArray, function(a, b) return a.priority < b.priority end)
        
        if #priorityArray == 0 then
            local emptyLabel = createTextLabel(priorityGUI.listScroll, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 0), "-- VocÃª chegou ao final da plantaÃ§Ã£o de morangos --", 12, THEME.TextMuted)
            emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
            return
        end
        
        for i, item in ipairs(priorityArray) do
            local itemFrame = createFrame(priorityGUI.listScroll, UDim2.new(1, 0, 0, 35), UDim2.new(0, 0, 0, 0), THEME.CardBg)
            itemFrame.LayoutOrder = i
            addCorners(itemFrame, 6)
            addStroke(itemFrame, THEME.Border, 1, 0.5)
            
            -- Nome do brainrot
            local data = AnimalsData[item.index]
            local displayName = (data and data.DisplayName) or item.index
            local nameLabel = createTextLabel(itemFrame, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 10, 0, 0), displayName, 12, THEME.TextPrimary)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Prioridade
            local priorityLabel = createTextLabel(itemFrame, UDim2.new(0, 60, 1, 0), UDim2.new(0.65, 0, 0, 0), "Priority: " .. item.priority, 11, THEME.AccentGreen)
            priorityLabel.Font = Enum.Font.GothamBold
            
            -- BotÃ£o remover
            local removeBtn = createTextButton(itemFrame, UDim2.new(0, 60, 0, 25), UDim2.new(1, -10, 0.5, -12.5), "Remove", THEME.ButtonBg, 10)
            addCorners(removeBtn, 4)
            removeBtn.TextColor3 = THEME.AccentRed
            
            removeBtn.MouseButton1Click:Connect(function()
                _G.oNineShared.stealPriority[item.index] = nil
                savePriorities()
                updatePriorityList()
            end)
        end
    end
    
    priorityGUI.selectGui = createFrame(priorityConfigGui, UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), THEME.DarkBg, 0.1)
    addCorners(priorityGUI.selectGui, 12)
    addStroke(priorityGUI.selectGui, THEME.AccentRed, 2, 0.3)
    priorityGUI.selectGui.Visible = false
    priorityGUI.selectGui.ZIndex = 10
    
    priorityGUI.selectHeader = createFrame(priorityGUI.selectGui, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), nil, 1)
    priorityGUI.selectTitle = createTextLabel(priorityGUI.selectHeader, UDim2.new(1, -50, 1, 0), UDim2.new(0, 15, 0, 0), "Select Brainrot", 16, THEME.AccentWhite)
    priorityGUI.selectTitle.Font = Enum.Font.GothamBold
    addPinkGradient(priorityGUI.selectTitle)
    
    priorityGUI.selectClose = createTextButton(priorityGUI.selectHeader, UDim2.new(0, 30, 0, 30), UDim2.new(1, -10, 0.5, -15), "Ã—", THEME.ButtonBg, 20)
    addCorners(priorityGUI.selectClose, 6)
    priorityGUI.selectClose.TextColor3 = THEME.AccentRed
    
    priorityGUI.searchFrame = createFrame(priorityGUI.selectGui, UDim2.new(1, -30, 0, 35), UDim2.new(0, 15, 0, 45), THEME.CardBg)
    addCorners(priorityGUI.searchFrame, 8)
    addStroke(priorityGUI.searchFrame, THEME.Border, 1, 0.3)
    
    priorityGUI.searchInput = Instance.new("TextBox")
    priorityGUI.searchInput.Size = UDim2.new(1, -16, 1, 0)
    priorityGUI.searchInput.Position = UDim2.new(0, 8, 0, 0)
    priorityGUI.searchInput.BackgroundTransparency = 1
    priorityGUI.searchInput.Text = ""
    priorityGUI.searchInput.PlaceholderText = "Search brainrots..."
    priorityGUI.searchInput.PlaceholderColor3 = THEME.TextMuted
    priorityGUI.searchInput.Font = Enum.Font.GothamMedium
    priorityGUI.searchInput.TextSize = 12
    priorityGUI.searchInput.TextColor3 = THEME.TextPrimary
    priorityGUI.searchInput.TextXAlignment = Enum.TextXAlignment.Left
    priorityGUI.searchInput.ClearTextOnFocus = false
    priorityGUI.searchInput.Parent = priorityGUI.searchFrame
    
    priorityGUI.selectScroll = Instance.new("ScrollingFrame")
    priorityGUI.selectScroll.Size = UDim2.new(1, -30, 1, -90)
    priorityGUI.selectScroll.Position = UDim2.new(0, 15, 0, 85)
    priorityGUI.selectScroll.BackgroundTransparency = 1
    priorityGUI.selectScroll.BorderSizePixel = 0
    priorityGUI.selectScroll.ScrollBarThickness = 4
    priorityGUI.selectScroll.ScrollBarImageColor3 = THEME.AccentRed
    priorityGUI.selectScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    priorityGUI.selectScroll.Parent = priorityGUI.selectGui
    
    priorityGUI.selectLayout = Instance.new("UIListLayout")
    priorityGUI.selectLayout.SortOrder = Enum.SortOrder.LayoutOrder
    priorityGUI.selectLayout.Padding = UDim.new(0, 4)
    priorityGUI.selectLayout.Parent = priorityGUI.selectScroll
    
    priorityGUI.selectLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        priorityGUI.selectScroll.CanvasSize = UDim2.new(0, 0, 0, priorityGUI.selectLayout.AbsoluteContentSize.Y)
    end)
    
    local function loadBrainrotsList(searchText)
        for _, child in ipairs(priorityGUI.selectScroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        searchText = searchText and searchText:lower() or ""
        local brainrotsList = {}
        
        for index, data in pairs(AnimalsData) do
            if data and (data.Rarity == "OG" or data.Rarity == "Secret") then
                local displayName = data.DisplayName or index
                if searchText == "" or displayName:lower():find(searchText) or index:lower():find(searchText) then
                    table.insert(brainrotsList, {index = index, data = data, displayName = displayName})
                end
            end
        end
        
        -- Ordena por nome
        table.sort(brainrotsList, function(a, b) return a.displayName < b.displayName end)
        
        for i, brainrot in ipairs(brainrotsList) do
            local brainrotBtn = createFrame(priorityGUI.selectScroll, UDim2.new(1, 0, 0, 35), UDim2.new(0, 0, 0, 0), THEME.CardBg)
            brainrotBtn.LayoutOrder = i
            addCorners(brainrotBtn, 6)
            addStroke(brainrotBtn, THEME.Border, 1, 0.5)
            
            local nameLabel = createTextLabel(brainrotBtn, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 10, 0, 0), brainrot.displayName, 12, THEME.TextPrimary)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            local rarityLabel = createTextLabel(brainrotBtn, UDim2.new(0, 60, 1, 0), UDim2.new(0.72, 0, 0, 0), brainrot.data.Rarity, 10, brainrot.data.Rarity == "Secret" and THEME.AccentRed or THEME.AccentGreen)
            rarityLabel.Font = Enum.Font.GothamBold
            
            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.Parent = brainrotBtn
            
            clickBtn.MouseButton1Click:Connect(function()
                local priorityInputFrame = createFrame(priorityGUI.selectGui, UDim2.new(0, 300, 0, 120), UDim2.new(0.5, -150, 0.5, -60), THEME.DarkBg, 0.1)
                priorityInputFrame.ZIndex = 20
                addCorners(priorityInputFrame, 12)
                addStroke(priorityInputFrame, THEME.AccentRed, 2, 0.3)
                
                local inputTitle = createTextLabel(priorityInputFrame, UDim2.new(1, -20, 0, 25), UDim2.new(0, 10, 0, 10), "Priority for " .. brainrot.displayName, 13, THEME.TextPrimary)
                inputTitle.Font = Enum.Font.GothamBold
                
                local priorityInput = Instance.new("TextBox")
                priorityInput.Size = UDim2.new(1, -20, 0, 30)
                priorityInput.Position = UDim2.new(0, 10, 0, 40)
                priorityInput.BackgroundColor3 = THEME.CardBg
                priorityInput.BorderSizePixel = 0
                priorityInput.Text = ""
                priorityInput.PlaceholderText = "Enter priority number (1 = highest)"
                priorityInput.PlaceholderColor3 = THEME.TextMuted
                priorityInput.Font = Enum.Font.GothamMedium
                priorityInput.TextSize = 12
                priorityInput.TextColor3 = THEME.TextPrimary
                priorityInput.TextXAlignment = Enum.TextXAlignment.Center
                priorityInput.ClearTextOnFocus = false
                addCorners(priorityInput, 6)
                priorityInput.Parent = priorityInputFrame
                
                local confirmBtn = createTextButton(priorityInputFrame, UDim2.new(0, 100, 0, 30), UDim2.new(0.5, -110, 1, -40), "Confirm", THEME.ButtonBg, 11)
                addCorners(confirmBtn, 6)
                confirmBtn.TextColor3 = THEME.AccentGreen
                
                local cancelBtn = createTextButton(priorityInputFrame, UDim2.new(0, 100, 0, 30), UDim2.new(0.5, 10, 1, -40), "Cancel", THEME.ButtonBg, 11)
                addCorners(cancelBtn, 6)
                cancelBtn.TextColor3 = THEME.AccentRed
                
                confirmBtn.MouseButton1Click:Connect(function()
                    local priority = tonumber(priorityInput.Text)
                    if priority and priority > 0 then
                        _G.oNineShared.stealPriority[brainrot.index] = priority
                        savePriorities()
                        priorityInputFrame:Destroy()
                        priorityGUI.selectGui.Visible = false
                        updatePriorityList()
                    end
                end)
                
                cancelBtn.MouseButton1Click:Connect(function()
                    priorityInputFrame:Destroy()
                end)
                
                priorityInput.Focused:Connect(function()
                    priorityInput:CaptureFocus()
                end)
            end)
        end
    end
    
    -- Eventos
    priorityBtn.MouseButton1Click:Connect(function()
        priorityConfigGui.Visible = not priorityConfigGui.Visible
        if priorityConfigGui.Visible then
            updatePriorityList()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        priorityConfigGui.Visible = false
    end)
    
    priorityGUI.addBtn.MouseButton1Click:Connect(function()
        priorityGUI.selectGui.Visible = true
        priorityGUI.searchInput.Text = ""
        loadBrainrotsList("")
    end)
    
    priorityGUI.selectClose.MouseButton1Click:Connect(function()
        priorityGUI.selectGui.Visible = false
    end)
    
    priorityGUI.searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        loadBrainrotsList(priorityGUI.searchInput.Text)
    end)
    
    makeDraggable(priorityConfigGui, "priorityConfigGui")
    
    -- Inicializa lista de players após um pequeno delay para garantir que tudo está carregado
    task.spawn(function()
        task.wait(0.5)
        refreshPlayerList()
    end)
