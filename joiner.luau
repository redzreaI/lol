repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local HttpService = game:GetService("HttpService")

-- ============================================================================
-- CONFIGURAÇÕES
-- ============================================================================

local CONFIG = {
    UpdateInterval = 2, -- Segundos entre atualizações automáticas
    MaxPetsDisplay = 50, -- Máximo de pets na lista
    AutoRefresh = true, -- Atualização automática
    SortBy = "Time", -- "Generation", "Name", "Time"
    
    -- Configuração de retries baseado em geração
    RetryConfig = {
        ["100M-"] = 40,    -- Menos de 100M: 40 retries
        ["100M+"] = 100,   -- 100M ou mais: 100 retries
        ["500M+"] = 1000,  -- 500M ou mais: 1000 retries
    },
    RetryInterval = 0.30, -- Intervalo entre retries (segundos)
    
    -- Filtro de pets
    FilterRarity = true, -- Ativar filtro (só mostra pets marcados no JSON)
    MarkedPets = {}, -- Pets marcados para aparecer (definido no menu de seleção)
    MinGeneration = {}, -- Valor mínimo de geração por pet {["Pet Name"] = 200000000}
    
    -- Auto Joiner
    AutoJoiner = false, -- Ativar auto joiner (entra automaticamente nos pets que chegarem)
}

-- ============================================================================
-- DADOS
-- ============================================================================

local petsData = {} -- {jobId, petName, generation, timestamp, ...}
local isRefreshing = false
local petRarities = {} -- Cache de raridades dos pets {petName = "Secret"/"OG"/etc}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- FUNÇÕES DE INTERFACE (declaradas antes de serem usadas)
-- ============================================================================

local updatePetsList -- Forward declaration

-- ============================================================================
-- PERSISTÊNCIA DE CONFIGURAÇÕES (JSON)
-- ============================================================================

local CONFIG_FILE = "petfinder_config.json"

-- Carrega configurações salvas do JSON
local function loadConfig()
    -- Tenta carregar do arquivo primeiro
    if readfile and isfile then
        local success, configData = pcall(function()
            if isfile(CONFIG_FILE) then
                local fileContent = readfile(CONFIG_FILE)
                if fileContent and fileContent ~= "" then
                    return HttpService:JSONDecode(fileContent)
                end
            end
            return nil
        end)
        
        if success and configData then
            if configData.RetryConfig then
                for k, v in pairs(configData.RetryConfig) do
                    CONFIG.RetryConfig[k] = v
                end
            end
            if configData.MarkedPets then
                CONFIG.MarkedPets = {}
                for k, v in pairs(configData.MarkedPets) do
                    CONFIG.MarkedPets[k] = v
                end
            end
            if configData.MinGeneration then
                CONFIG.MinGeneration = {}
                for k, v in pairs(configData.MinGeneration) do
                    CONFIG.MinGeneration[k] = v
                end
            end
            if configData.FilterRarity ~= nil then
                CONFIG.FilterRarity = configData.FilterRarity
            end
            -- AutoJoiner NÃO é carregado do JSON (sempre inicia desativado)
            print("[Pet Finder] Configurações carregadas do arquivo")
            return
        end
    end
    
    -- Fallback: tenta carregar do getgenv
    if getgenv and getgenv().PetFinderConfig then
        local saved = getgenv().PetFinderConfig
        if saved.RetryConfig then
            for k, v in pairs(saved.RetryConfig) do
                CONFIG.RetryConfig[k] = v
            end
        end
        if saved.MarkedPets then
            for k, v in pairs(saved.MarkedPets) do
                CONFIG.MarkedPets[k] = v
            end
        end
        if saved.MinGeneration then
            for k, v in pairs(saved.MinGeneration) do
                CONFIG.MinGeneration[k] = v
            end
        end
        if saved.FilterRarity ~= nil then
            CONFIG.FilterRarity = saved.FilterRarity
        end
        -- AutoJoiner NÃO é carregado do getgenv (sempre inicia desativado)
        print("[Pet Finder] Configurações carregadas do getgenv")
    end
end

-- Salva configurações em JSON
local function saveConfig()
    local configToSave = {
        RetryConfig = CONFIG.RetryConfig,
        MarkedPets = CONFIG.MarkedPets,
        MinGeneration = CONFIG.MinGeneration,
        FilterRarity = CONFIG.FilterRarity
        -- AutoJoiner NÃO é salvo (sempre inicia desativado após reiniciar)
    }
    
    -- Tenta salvar no arquivo primeiro
    if writefile then
        local success, err = pcall(function()
            local jsonData = HttpService:JSONEncode(configToSave)
            writefile(CONFIG_FILE, jsonData)
            return true
        end)
        
        if success then
            print("[Pet Finder] Configurações salvas em", CONFIG_FILE)
            return
        else
            warn("[Pet Finder] Erro ao salvar em arquivo:", err)
        end
    end
    
    -- Fallback: salva no getgenv
    if getgenv then
        getgenv().PetFinderConfig = configToSave
        print("[Pet Finder] Configurações salvas no getgenv")
    end
end

-- Carrega configurações ao iniciar
loadConfig()

-- ============================================================================
-- SISTEMA DE RARIDADE
-- ============================================================================

-- Carrega raridades dos pets do módulo Animals
local function loadPetRarities()
    local success, animalsModule = pcall(function()
        local datas = ReplicatedStorage:WaitForChild("Datas", 10)
        local animals = datas:WaitForChild("Animals", 10)
        return require(animals)
    end)
    
    if not success or not animalsModule then
        warn("[Pet Finder] Não foi possível carregar módulo Animals")
        return
    end
    
    -- Processa o módulo Animals (formato: {["Nome"] = {DisplayName = "...", Rarity = "...", ...}})
    local count = 0
    for key, value in pairs(animalsModule) do
        if type(value) == "table" and value.Rarity then
            -- Usa DisplayName como nome do pet (ou a chave como fallback)
            local petName = value.DisplayName or tostring(key)
            local rarity = value.Rarity
            
            if petName and rarity then
                petRarities[tostring(petName)] = tostring(rarity)
                count = count + 1
            end
        end
    end
    
    print("[Pet Finder] Raridades carregadas:", count, "pets")
end

-- Obtém raridade de um pet
local function getPetRarity(petName)
    if not petName then return nil end
    return petRarities[petName] or petRarities[tostring(petName)]
end

-- Função auxiliar para parse de geração (mesma lógica)
local function parseGenValue(generation)
    if type(generation) == "number" then
        return generation
    end
    local genStr = tostring(generation)
    genStr = genStr:gsub(",", ""):gsub("%s+", ""):upper()
    local number = genStr:match("[%d%.]+")
    if not number then return 0 end
    local multiplier = 1
    if genStr:find("K") then
        multiplier = 1e3
    elseif genStr:find("M") then
        multiplier = 1e6
    elseif genStr:find("B") then
        multiplier = 1e9
    elseif genStr:find("T") then
        multiplier = 1e12
    elseif genStr:find("Q") then
        multiplier = 1e15
    end
    return (tonumber(number) or 0) * multiplier
end

-- Verifica se pet passa no filtro
local function passesFilter(petName, petData)
    -- Se o filtro não está ativo, permite tudo
    if not CONFIG.FilterRarity then return true end
    
    -- Se está marcado no JSON, verifica valor mínimo
    if CONFIG.MarkedPets[petName] then
        -- Se tem valor mínimo configurado, verifica
        if CONFIG.MinGeneration[petName] then
            local minGen = CONFIG.MinGeneration[petName]
            local petGen = 0
            
            if petData then
                local genStr = tostring(petData.Generation or petData.G or "0")
                petGen = parseGenValue(genStr)
            end
            
            -- Só passa se a geração do pet for >= valor mínimo
            if petGen < minGen then
                return false
            end
        end
        return true
    end
    
    -- Se não está marcado e o filtro está ativo, bloqueia
    return false
end

-- Inicia carregamento de raridades
task.spawn(function()
    task.wait(3) -- Aguarda jogo carregar
    loadPetRarities()
end)

-- ============================================================================
-- SISTEMA DE RECEBIMENTO DE DADOS
-- ============================================================================

local PetFinderAPI = {}

-- Função para fazer auto join com retry
local function autoJoinWithRetry(petData)
    if not CONFIG.AutoJoiner then return end
    
    local petName = petData.PetName or petData.Name or ""
    -- Só faz auto join se o pet estiver marcado
    if not CONFIG.MarkedPets[petName] then return end
    
    local jobId = petData.JobId
    if not jobId then return end
    
    print(string.format("[Auto Joiner] Pet detectado: %s, iniciando auto join...", petName))
    
    -- Função auxiliar local para parse de geração (mesma lógica da função principal)
    local function parseGen(generation)
        if type(generation) == "number" then
            return generation
        end
        local genStr = tostring(generation)
        genStr = genStr:gsub(",", ""):gsub("%s+", ""):upper()
        local number = genStr:match("[%d%.]+")
        if not number then return 0 end
        local multiplier = 1
        if genStr:find("K") then
            multiplier = 1e3
        elseif genStr:find("M") then
            multiplier = 1e6
        elseif genStr:find("B") then
            multiplier = 1e9
        elseif genStr:find("T") then
            multiplier = 1e12
        elseif genStr:find("Q") then
            multiplier = 1e15
        end
        return (tonumber(number) or 0) * multiplier
    end
    
    -- Calcula maxTries baseado na geração
    local genStr = tostring(petData.Generation or petData.G or "0")
    local genValue = parseGen(genStr)
    local maxTries = CONFIG.RetryConfig["100M-"]
    
    if genValue >= 500000000 then -- 500M+
        maxTries = CONFIG.RetryConfig["500M+"]
    elseif genValue >= 100000000 then -- 100M+
        maxTries = CONFIG.RetryConfig["100M+"]
    end
    
    -- Executa retry em uma thread separada
    task.spawn(function()
        local tries = 0
        
        while tries < maxTries and CONFIG.AutoJoiner do
            tries = tries + 1
            print(string.format("[Auto Joiner] Tentativa %d/%d para %s", tries, maxTries, petName))
            
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
            end)
            
            if not success then
                warn(string.format("[Auto Joiner] Tentativa %d/%d falhou: %s", tries, maxTries, err))
            else
                print(string.format("[Auto Joiner] ✅ Teleport iniciado para %s (tentativa %d/%d)", petName, tries, maxTries))
            end
            
            -- Sempre espera o intervalo antes da próxima tentativa (ou fim)
            task.wait(CONFIG.RetryInterval)
        end
        
        if tries >= maxTries then
            print(string.format("[Auto Joiner] ⚠️ Limite de tentativas atingido para %s (%d tentativas)", petName, maxTries))
        end
    end)
end

-- Função para receber pets externamente
function PetFinderAPI.AddPet(petData)
    if not petData or not petData.JobId then
        return false
    end
    
    local petName = petData.PetName or petData.Name or ""
    
    -- Verifica filtro (se ativado, só mostra pets marcados no JSON e respeita valor mínimo)
    if not passesFilter(petName, petData) then
        return false
    end
    
    local jobId = tostring(petData.JobId)
    petData.timestamp = tick()
    -- Usa JobId + timestamp para garantir ID único mesmo se chegar múltiplos ao mesmo tempo
    petData.id = jobId .. "_" .. tostring(petData.timestamp) .. "_" .. (petData.PodiumID or petData.AnimalIndex or math.random(1000, 9999))
    
    -- Adiciona ou atualiza pet
    petsData[petData.id] = petData
    
    -- Atualiza interface
    updatePetsList()
    
    -- Auto joiner: se estiver ativo, tenta entrar automaticamente
    if CONFIG.AutoJoiner then
        autoJoinWithRetry(petData)
    end
    
    return true
end

-- Função para adicionar múltiplos pets
function PetFinderAPI.AddPets(petsArray)
    if not petsArray or type(petsArray) ~= "table" then
        warn("[Pet Finder] Array de pets inválido")
        return false
    end
    
    local added = 0
    for _, petData in ipairs(petsArray) do
        if PetFinderAPI.AddPet(petData) then
            added = added + 1
        end
    end
    
    return added
end

-- Função para limpar pets
function PetFinderAPI.Clear()
    petsData = {}
    updatePetsList()
end

-- Função para obter pets atuais
function PetFinderAPI.GetPets()
    return petsData
end

-- Exporta API globalmente para acesso do cliente HTTP
_G.PetFinderAPI = PetFinderAPI

-- ============================================================================
-- INTERFACE GUI
-- ============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetFinderGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- Frame principal
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 500, 0, 640) -- Aumentado para acomodar segunda linha de controles
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -320)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Corner radius
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Sombra (irmã do mainFrame para se mover junto)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(0, 510, 0, 610)
shadow.Position = UDim2.new(0.5, -250, 0.5, -300)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.7
shadow.ZIndex = mainFrame.ZIndex - 1
shadow.Parent = screenGui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 12)
shadowCorner.Parent = shadow

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

-- Título
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "🐾 Pet Finder"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Contador de pets
local petCountLabel = Instance.new("TextLabel")
petCountLabel.Name = "PetCount"
petCountLabel.Size = UDim2.new(0, 80, 1, 0)
petCountLabel.Position = UDim2.new(1, -95, 0, 0)
petCountLabel.BackgroundTransparency = 1
petCountLabel.Text = "0 pets"
petCountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
petCountLabel.Font = Enum.Font.Gotham
petCountLabel.TextSize = 14
petCountLabel.TextXAlignment = Enum.TextXAlignment.Right
petCountLabel.Parent = header

-- Botão fechar
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
end)

-- ============================================================================
-- SISTEMA DE ARRASTAR GUI
-- ============================================================================

local dragging = false
local dragStart = nil
local startPos = nil

local function updateDrag(input)
    if not dragging then return end
    
    local delta = input.Position - dragStart
    local newX = startPos.X.Offset + delta.X
    local newY = startPos.Y.Offset + delta.Y
    
    mainFrame.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    -- Move a sombra junto (offset de -5 pixels)
    shadow.Position = UDim2.new(startPos.X.Scale, newX - 5, startPos.Y.Scale, newY - 5)
end

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        local connection
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                connection:Disconnect()
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateDrag(input)
    end
end)

-- Barra de controles (linha 1)
local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.Size = UDim2.new(1, -20, 0, 40)
controls.Position = UDim2.new(0, 10, 0, 60)
controls.BackgroundTransparency = 1
controls.Parent = mainFrame

-- Barra de controles (linha 2 - configurações)
local controls2 = Instance.new("Frame")
controls2.Name = "Controls2"
controls2.Size = UDim2.new(1, -20, 0, 35)
controls2.Position = UDim2.new(0, 10, 0, 105)
controls2.BackgroundTransparency = 1
controls2.Visible = true
controls2.ZIndex = 10 -- Garante que fica acima de outros elementos
controls2.Parent = mainFrame

-- Botão refresh
local refreshBtn = Instance.new("TextButton")
refreshBtn.Name = "RefreshBtn"
refreshBtn.Size = UDim2.new(0, 100, 0, 35)
refreshBtn.Position = UDim2.new(0, 0, 0, 0)
refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "🔄 Refresh"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 14
refreshBtn.Parent = controls

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 8)
refreshCorner.Parent = refreshBtn

-- Botão limpar
local clearBtn = Instance.new("TextButton")
clearBtn.Name = "ClearBtn"
clearBtn.Size = UDim2.new(0, 100, 0, 35)
clearBtn.Position = UDim2.new(0, 110, 0, 0)
clearBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
clearBtn.BorderSizePixel = 0
clearBtn.Text = "🗑️ Limpar"
clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
clearBtn.Font = Enum.Font.Gotham
clearBtn.TextSize = 14
clearBtn.Parent = controls

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 8)
clearCorner.Parent = clearBtn

-- Dropdown de ordenação
local sortLabel = Instance.new("TextLabel")
sortLabel.Name = "SortLabel"
sortLabel.Size = UDim2.new(0, 60, 0, 35)
sortLabel.Position = UDim2.new(0, 220, 0, 0)
sortLabel.BackgroundTransparency = 1
sortLabel.Text = "Ordenar:"
sortLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
sortLabel.Font = Enum.Font.Gotham
sortLabel.TextSize = 12
sortLabel.TextXAlignment = Enum.TextXAlignment.Left
sortLabel.Parent = controls

local sortDropdown = Instance.new("TextButton")
sortDropdown.Name = "SortDropdown"
sortDropdown.Size = UDim2.new(0, 150, 0, 35)
sortDropdown.Position = UDim2.new(0, 285, 0, 0)
sortDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
sortDropdown.BorderSizePixel = 0
sortDropdown.Text = "Tempo ▼"
sortDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
sortDropdown.Font = Enum.Font.Gotham
sortDropdown.TextSize = 12
sortDropdown.Parent = controls

local sortCorner = Instance.new("UICorner")
sortCorner.CornerRadius = UDim.new(0, 8)
sortCorner.Parent = sortDropdown

-- Botão auto joiner (linha 2)
local autoJoinerBtn = Instance.new("TextButton")
autoJoinerBtn.Name = "AutoJoinerBtn"
autoJoinerBtn.Size = UDim2.new(0, 115, 0, 35)
autoJoinerBtn.Position = UDim2.new(0, 0, 0, 0)
autoJoinerBtn.BackgroundColor3 = CONFIG.AutoJoiner and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 100, 100)
autoJoinerBtn.BorderSizePixel = 0
autoJoinerBtn.Text = CONFIG.AutoJoiner and "🤖 Auto: On" or "🤖 Auto: Off"
autoJoinerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoJoinerBtn.Font = Enum.Font.Gotham
autoJoinerBtn.TextSize = 11
autoJoinerBtn.Visible = true
autoJoinerBtn.ZIndex = 11
autoJoinerBtn.Parent = controls2

local autoJoinerCorner = Instance.new("UICorner")
autoJoinerCorner.CornerRadius = UDim.new(0, 8)
autoJoinerCorner.Parent = autoJoinerBtn

autoJoinerBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoJoiner = not CONFIG.AutoJoiner
    autoJoinerBtn.BackgroundColor3 = CONFIG.AutoJoiner and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 100, 100)
    autoJoinerBtn.Text = CONFIG.AutoJoiner and "🤖 Auto: On" or "🤖 Auto: Off"
    -- AutoJoiner NÃO é salvo (sempre inicia desativado após reiniciar)
    if CONFIG.AutoJoiner then
        print("[Auto Joiner] ✅ Auto joiner ativado!")
    else
        print("[Auto Joiner] ❌ Auto joiner desativado!")
    end
end)

-- Botão filtro de raridade (linha 2)
local filterRarityBtn = Instance.new("TextButton")
filterRarityBtn.Name = "FilterRarityBtn"
filterRarityBtn.Size = UDim2.new(0, 115, 0, 35)
filterRarityBtn.Position = UDim2.new(0, 125, 0, 0)
filterRarityBtn.BackgroundColor3 = CONFIG.FilterRarity and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(100, 100, 100)
filterRarityBtn.BorderSizePixel = 0
filterRarityBtn.Text = CONFIG.FilterRarity and "✓ Filtro: On" or "✗ Filtro: Off"
filterRarityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
filterRarityBtn.Font = Enum.Font.Gotham
filterRarityBtn.TextSize = 11
filterRarityBtn.Visible = true
filterRarityBtn.ZIndex = 11
filterRarityBtn.Parent = controls2

local filterRarityCorner = Instance.new("UICorner")
filterRarityCorner.CornerRadius = UDim.new(0, 8)
filterRarityCorner.Parent = filterRarityBtn

filterRarityBtn.MouseButton1Click:Connect(function()
    CONFIG.FilterRarity = not CONFIG.FilterRarity
    filterRarityBtn.BackgroundColor3 = CONFIG.FilterRarity and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(100, 100, 100)
    filterRarityBtn.Text = CONFIG.FilterRarity and "✓ Filtro: On" or "✗ Filtro: Off"
    saveConfig()
    updatePetsList()
end)

-- Botão de configuração (linha 2)
local configBtn = Instance.new("TextButton")
configBtn.Name = "ConfigBtn"
configBtn.Size = UDim2.new(0, 105, 0, 35)
configBtn.Position = UDim2.new(0, 250, 0, 0)
configBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 200)
configBtn.BorderSizePixel = 0
configBtn.Text = "⚙️ Retries"
configBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
configBtn.Font = Enum.Font.Gotham
configBtn.TextSize = 11
configBtn.Visible = true
configBtn.ZIndex = 11
configBtn.Parent = controls2

local configCorner = Instance.new("UICorner")
configCorner.CornerRadius = UDim.new(0, 8)
configCorner.Parent = configBtn

-- Botão de seleção de pets (linha 2)
local selectPetsBtn = Instance.new("TextButton")
selectPetsBtn.Name = "SelectPetsBtn"
selectPetsBtn.Size = UDim2.new(0, 115, 0, 35)
selectPetsBtn.Position = UDim2.new(0, 365, 0, 0)
selectPetsBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 80)
selectPetsBtn.BorderSizePixel = 0
selectPetsBtn.Text = "📋 Pets"
selectPetsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
selectPetsBtn.Font = Enum.Font.Gotham
selectPetsBtn.TextSize = 11
selectPetsBtn.Visible = true
selectPetsBtn.ZIndex = 11
selectPetsBtn.Parent = controls2

local selectPetsCorner = Instance.new("UICorner")
selectPetsCorner.CornerRadius = UDim.new(0, 8)
selectPetsCorner.Parent = selectPetsBtn

-- Scroll frame para lista de pets
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PetsList"
scrollFrame.Size = UDim2.new(1, -20, 1, -155)
scrollFrame.Position = UDim2.new(0, 10, 0, 145)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- ============================================================================
-- MENUS DE CONFIGURAÇÃO
-- ============================================================================

-- Cria janela de configuração de retries
local function createConfigWindow()
    -- Overlay escuro
    local overlay = Instance.new("Frame")
    overlay.Name = "ConfigOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 20
    overlay.Parent = screenGui
    
    -- Janela principal
    local configWindow = Instance.new("Frame")
    configWindow.Name = "ConfigWindow"
    configWindow.Size = UDim2.new(0, 400, 0, 300)
    configWindow.Position = UDim2.new(0.5, -200, 0.5, -150)
    configWindow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    configWindow.BorderSizePixel = 0
    configWindow.ZIndex = 21
    configWindow.Parent = screenGui
    
    local windowCorner = Instance.new("UICorner")
    windowCorner.CornerRadius = UDim.new(0, 12)
    windowCorner.Parent = configWindow
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.BorderSizePixel = 0
    title.Text = "⚙️ Configuração de Retries"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = configWindow
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = title
    
    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.ZIndex = 22
    closeBtn.Parent = configWindow
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    -- Campos de retry
    local retryFields = {}
    local yPos = 60
    
    local retryLabels = {
        ["100M-"] = "Retries para < 100M:",
        ["100M+"] = "Retries para ≥ 100M:",
        ["500M+"] = "Retries para ≥ 500M:"
    }
    
    for key, label in pairs(retryLabels) do
        -- Label
        local labelText = Instance.new("TextLabel")
        labelText.Size = UDim2.new(0, 180, 0, 30)
        labelText.Position = UDim2.new(0, 20, 0, yPos)
        labelText.BackgroundTransparency = 1
        labelText.Text = label
        labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
        labelText.Font = Enum.Font.Gotham
        labelText.TextSize = 14
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        labelText.Parent = configWindow
        
        -- TextBox
        local textBox = Instance.new("TextBox")
        textBox.Name = key .. "Retry"
        textBox.Size = UDim2.new(0, 150, 0, 35)
        textBox.Position = UDim2.new(1, -170, 0, yPos)
        textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        textBox.BorderSizePixel = 0
        textBox.Text = tostring(CONFIG.RetryConfig[key] or 0)
        textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        textBox.Font = Enum.Font.Gotham
        textBox.TextSize = 14
        textBox.ClearTextOnFocus = false
        textBox.Parent = configWindow
        
        local textBoxCorner = Instance.new("UICorner")
        textBoxCorner.CornerRadius = UDim.new(0, 8)
        textBoxCorner.Parent = textBox
        
        retryFields[key] = textBox
        yPos = yPos + 50
    end
    
    -- Botão salvar
    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Size = UDim2.new(0, 200, 0, 40)
    saveBtn.Position = UDim2.new(0.5, -100, 1, -50)
    saveBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾 Salvar"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 16
    saveBtn.Parent = configWindow
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = saveBtn
    
    -- Eventos
    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        configWindow:Destroy()
    end)
    
    saveBtn.MouseButton1Click:Connect(function()
        for key, textBox in pairs(retryFields) do
            local value = tonumber(textBox.Text)
            if value and value >= 0 then
                CONFIG.RetryConfig[key] = value
            end
        end
        saveConfig()
        overlay:Destroy()
        configWindow:Destroy()
        print("[Pet Finder] Configurações de retry salvas!")
    end)
    
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            overlay:Destroy()
            configWindow:Destroy()
        end
    end)
end

-- Cria janela de seleção de pets
local function createPetsSelectionWindow()
    -- Overlay escuro
    local overlay = Instance.new("Frame")
    overlay.Name = "PetsSelectionOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 20
    overlay.Parent = screenGui
    
    -- Janela principal
    local petsWindow = Instance.new("Frame")
    petsWindow.Name = "PetsSelectionWindow"
    petsWindow.Size = UDim2.new(0, 500, 0, 600)
    petsWindow.Position = UDim2.new(0.5, -250, 0.5, -300)
    petsWindow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    petsWindow.BorderSizePixel = 0
    petsWindow.ZIndex = 21
    petsWindow.Parent = screenGui
    
    local windowCorner = Instance.new("UICorner")
    windowCorner.CornerRadius = UDim.new(0, 12)
    windowCorner.Parent = petsWindow
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.BorderSizePixel = 0
    title.Text = "📋 Selecionar Pets para Mostrar"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = petsWindow
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = title
    
    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.ZIndex = 22
    closeBtn.Parent = petsWindow
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    -- Scroll frame para lista de pets
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "PetsScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -100)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.Parent = petsWindow
    
    local scrollLayout = Instance.new("UIListLayout")
    scrollLayout.Padding = UDim.new(0, 5)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scrollLayout.Parent = scrollFrame
    
    -- Preenche lista de pets (apenas Secret e OG)
    local petNames = {}
    for petName, rarity in pairs(petRarities) do
        local rarityLower = string.lower(tostring(rarity))
        if rarityLower == "secret" or rarityLower == "og" then
            table.insert(petNames, petName)
        end
    end
    table.sort(petNames)
    
    local minGenFields = {} -- Armazena referências aos campos de valor mínimo
    
    -- Função para formatar geração (definida antes de ser usada)
    local function formatGenForInput(value)
        if not value or value == 0 then return "" end
        local gen = tonumber(value) or 0
        if gen >= 1e15 then
            return string.format("%.2fQ", gen / 1e15)
        elseif gen >= 1e12 then
            return string.format("%.2fT", gen / 1e12)
        elseif gen >= 1e9 then
            return string.format("%.2fB", gen / 1e9)
        elseif gen >= 1e6 then
            return string.format("%.2fM", gen / 1e6)
        elseif gen >= 1e3 then
            return string.format("%.2fK", gen / 1e3)
        else
            return string.format("%.0f", gen)
        end
    end
    
    for i, petName in ipairs(petNames) do
        local entry = Instance.new("Frame")
        entry.Name = "PetEntry"
        entry.Size = UDim2.new(1, 0, 0, 70) -- Aumentado para 70px para acomodar campo de valor mínimo
        entry.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        entry.BorderSizePixel = 0
        entry.LayoutOrder = i
        entry.Parent = scrollFrame
        
        local entryCorner = Instance.new("UICorner")
        entryCorner.CornerRadius = UDim.new(0, 8)
        entryCorner.Parent = entry
        
        -- Checkbox
        local checkbox = Instance.new("TextButton")
        checkbox.Name = "Checkbox"
        checkbox.Size = UDim2.new(0, 30, 0, 30)
        checkbox.Position = UDim2.new(0, 10, 0, 5)
        checkbox.BackgroundColor3 = CONFIG.MarkedPets[petName] and Color3.fromRGB(60, 200, 100) or Color3.fromRGB(80, 80, 80)
        checkbox.BorderSizePixel = 0
        checkbox.Text = CONFIG.MarkedPets[petName] and "✓" or ""
        checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 18
        checkbox.Parent = entry
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 6)
        checkboxCorner.Parent = checkbox
        
        -- Nome do pet (primeira linha)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -160, 0, 30)
        nameLabel.Position = UDim2.new(0, 50, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = petName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextSize = 14
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = entry
        
        -- Raridade (primeira linha)
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(0, 100, 0, 30)
        rarityLabel.Position = UDim2.new(1, -110, 0, 5)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = petRarities[petName] or "?"
        rarityLabel.TextColor3 = Color3.fromRGB(150, 150, 255)
        rarityLabel.Font = Enum.Font.Gotham
        rarityLabel.TextSize = 12
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
        rarityLabel.Parent = entry
        
        -- Label "Min:" (segunda linha)
        local minLabel = Instance.new("TextLabel")
        minLabel.Size = UDim2.new(0, 50, 0, 25)
        minLabel.Position = UDim2.new(0, 50, 0, 38)
        minLabel.BackgroundTransparency = 1
        minLabel.Text = "Min:"
        minLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        minLabel.Font = Enum.Font.Gotham
        minLabel.TextSize = 12
        minLabel.TextXAlignment = Enum.TextXAlignment.Left
        minLabel.Parent = entry
        
        -- Campo de valor mínimo (segunda linha)
        local minTextBox = Instance.new("TextBox")
        minTextBox.Name = "MinGen"
        minTextBox.Size = UDim2.new(0, 150, 0, 25)
        minTextBox.Position = UDim2.new(0, 105, 0, 38)
        minTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        minTextBox.BorderSizePixel = 0
        local currentMin = CONFIG.MinGeneration[petName]
        minTextBox.PlaceholderText = "Ex: 200M"
        minTextBox.Text = currentMin and formatGenForInput(currentMin) or ""
        minTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        minTextBox.Font = Enum.Font.Gotham
        minTextBox.TextSize = 12
        minTextBox.ClearTextOnFocus = false
        minTextBox.Parent = entry
        
        local minTextBoxCorner = Instance.new("UICorner")
        minTextBoxCorner.CornerRadius = UDim.new(0, 6)
        minTextBoxCorner.Parent = minTextBox
        
        minGenFields[petName] = minTextBox
        
        -- Função para converter texto para número
        local function parseGenFromInput(text)
            if not text or text == "" then return 0 end
            local genStr = text:gsub(",", ""):gsub("%s+", ""):upper()
            local number = genStr:match("[%d%.]+")
            if not number then return 0 end
            local multiplier = 1
            if genStr:find("K") then
                multiplier = 1e3
            elseif genStr:find("M") then
                multiplier = 1e6
            elseif genStr:find("B") then
                multiplier = 1e9
            elseif genStr:find("T") then
                multiplier = 1e12
            elseif genStr:find("Q") then
                multiplier = 1e15
            end
            return (tonumber(number) or 0) * multiplier
        end
        
        -- Atualiza formato ao perder foco
        minTextBox.FocusLost:Connect(function()
            local value = parseGenFromInput(minTextBox.Text)
            if value > 0 then
                minTextBox.Text = formatGenForInput(value)
                CONFIG.MinGeneration[petName] = value
            else
                minTextBox.Text = ""
                CONFIG.MinGeneration[petName] = nil
            end
        end)
        
        -- Toggle checkbox
        checkbox.MouseButton1Click:Connect(function()
            if CONFIG.MarkedPets[petName] then
                CONFIG.MarkedPets[petName] = nil
                checkbox.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                checkbox.Text = ""
            else
                CONFIG.MarkedPets[petName] = true
                checkbox.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
                checkbox.Text = "✓"
            end
        end)
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 10)
    scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 10)
    end)
    
    -- Botão salvar
    local saveBtn = Instance.new("TextButton")
    saveBtn.Name = "SaveBtn"
    saveBtn.Size = UDim2.new(0, 200, 0, 40)
    saveBtn.Position = UDim2.new(0.5, -100, 1, -50)
    saveBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
    saveBtn.BorderSizePixel = 0
    saveBtn.Text = "💾 Salvar"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 16
    saveBtn.Parent = petsWindow
    
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 8)
    saveCorner.Parent = saveBtn
    
    -- Eventos
    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        petsWindow:Destroy()
    end)
    
    saveBtn.MouseButton1Click:Connect(function()
        -- Processa todos os campos de valor mínimo antes de salvar
        for petName, textBox in pairs(minGenFields) do
            local text = textBox.Text
            if text and text ~= "" then
                -- Função auxiliar para parse
                local genStr = text:gsub(",", ""):gsub("%s+", ""):upper()
                local number = genStr:match("[%d%.]+")
                if number then
                    local multiplier = 1
                    if genStr:find("K") then
                        multiplier = 1e3
                    elseif genStr:find("M") then
                        multiplier = 1e6
                    elseif genStr:find("B") then
                        multiplier = 1e9
                    elseif genStr:find("T") then
                        multiplier = 1e12
                    elseif genStr:find("Q") then
                        multiplier = 1e15
                    end
                    CONFIG.MinGeneration[petName] = (tonumber(number) or 0) * multiplier
                else
                    CONFIG.MinGeneration[petName] = nil
                end
            else
                CONFIG.MinGeneration[petName] = nil
            end
        end
        
        saveConfig()
        overlay:Destroy()
        petsWindow:Destroy()
        updatePetsList()
        print("[Pet Finder] Seleção de pets e valores mínimos salvos!")
    end)
    
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            overlay:Destroy()
            petsWindow:Destroy()
        end
    end)
end

-- Eventos dos botões
configBtn.MouseButton1Click:Connect(createConfigWindow)
selectPetsBtn.MouseButton1Click:Connect(createPetsSelectionWindow)

-- ============================================================================
-- FUNÇÕES DE INTERFACE
-- ============================================================================

local function parseGeneration(generation)
    if type(generation) == "number" then
        return generation
    end
    
    local genStr = tostring(generation)
    genStr = genStr:gsub(",", ""):gsub("%s+", ""):upper() -- Remove espaços e converte para maiúsculo
    
    local number = genStr:match("[%d%.]+")
    if not number then return 0 end
    
    local multiplier = 1
    if genStr:find("K") then
        multiplier = 1e3
    elseif genStr:find("M") then
        multiplier = 1e6
    elseif genStr:find("B") then
        multiplier = 1e9
    elseif genStr:find("T") then
        multiplier = 1e12
    elseif genStr:find("Q") then
        multiplier = 1e15
    end
    
    local result = tonumber(number) * multiplier
    return result or 0
end

local function formatGeneration(generation)
    if type(generation) == "string" then
        return generation
    end
    
    local gen = tonumber(generation) or 0
    
    if gen >= 1e15 then
        return string.format("%.2fQ", gen / 1e15)
    elseif gen >= 1e12 then
        return string.format("%.2fT", gen / 1e12)
    elseif gen >= 1e9 then
        return string.format("%.2fB", gen / 1e9)
    elseif gen >= 1e6 then
        return string.format("%.2fM", gen / 1e6)
    elseif gen >= 1e3 then
        return string.format("%.2fK", gen / 1e3)
    else
        return string.format("%.0f", gen)
    end
end

local function getTimeAgo(timestamp)
    local diff = tick() - timestamp
    if diff < 60 then
        return string.format("%.0fs", diff)
    elseif diff < 3600 then
        return string.format("%.0fm", diff / 60)
    else
        return string.format("%.1fh", diff / 3600)
    end
end

local function createPetEntry(petData, index)
    -- Verifica se é 100M+ para cor vermelha
    local genStr = tostring(petData.Generation or petData.G or "0")
    local genValue = parseGeneration(genStr)
    local isHighValue = genValue >= 100000000 -- 100M
    
    local entry = Instance.new("Frame")
    entry.Name = "PetEntry_" .. index
    entry.Size = UDim2.new(1, 0, 0, 80)
    
    -- Cor de fundo do entry para 100M+
    if isHighValue then
        entry.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    else
        entry.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end
    
    entry.BorderSizePixel = 0
    entry.Parent = scrollFrame
    
    local entryCorner = Instance.new("UICorner")
    entryCorner.CornerRadius = UDim.new(0, 8)
    entryCorner.Parent = entry
    
    -- Hover effect
    entry.MouseEnter:Connect(function()
        if isHighValue then
            TweenService:Create(entry, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 30, 30)}):Play()
        else
            TweenService:Create(entry, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play()
        end
    end)
    entry.MouseLeave:Connect(function()
        if isHighValue then
            TweenService:Create(entry, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 20, 20)}):Play()
        else
            TweenService:Create(entry, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
        end
    end)
    
    -- Nome do pet
    local petName = Instance.new("TextLabel")
    petName.Name = "PetName"
    petName.Size = UDim2.new(1, -200, 0, 25)
    petName.Position = UDim2.new(0, 15, 0, 8)
    petName.BackgroundTransparency = 1
    petName.Text = petData.PetName or petData.Name or "Unknown Pet"
    petName.TextColor3 = Color3.fromRGB(255, 255, 255)
    petName.Font = Enum.Font.GothamBold
    petName.TextSize = 16
    petName.TextXAlignment = Enum.TextXAlignment.Left
    petName.TextTruncate = Enum.TextTruncate.AtEnd
    petName.Parent = entry
    
    -- Geração
    local generation = Instance.new("TextLabel")
    generation.Name = "Generation"
    generation.Size = UDim2.new(0, 150, 0, 20)
    generation.Position = UDim2.new(0, 15, 0, 30)
    generation.BackgroundTransparency = 1
    generation.Text = "Gen: " .. (formatGeneration(petData.Generation or petData.G or 0))
    generation.TextColor3 = Color3.fromRGB(100, 200, 255)
    generation.Font = Enum.Font.Gotham
    generation.TextSize = 13
    generation.TextXAlignment = Enum.TextXAlignment.Left
    generation.Parent = entry
    
    -- Info adicional
    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.Size = UDim2.new(1, -200, 0, 20)
    info.Position = UDim2.new(0, 15, 0, 50)
    info.BackgroundTransparency = 1
    
    local infoText = {}
    if petData.PlotName then
        table.insert(infoText, "Plot: " .. petData.PlotName)
    end
    if petData.timestamp then
        table.insert(infoText, getTimeAgo(petData.timestamp) .. " ago")
    end
    
    info.Text = table.concat(infoText, " • ")
    info.TextColor3 = Color3.fromRGB(150, 150, 150)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = entry
    
    -- Botão entrar
    local joinBtn = Instance.new("TextButton")
    joinBtn.Name = "JoinBtn"
    joinBtn.Size = UDim2.new(0, 80, 0, 35)
    joinBtn.Position = UDim2.new(1, -180, 0, 22.5)
    joinBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
    joinBtn.BorderSizePixel = 0
    joinBtn.Text = "▶ Entrar"
    joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    joinBtn.Font = Enum.Font.GothamBold
    joinBtn.TextSize = 13
    joinBtn.Parent = entry
    
    local joinCorner = Instance.new("UICorner")
    joinCorner.CornerRadius = UDim.new(0, 6)
    joinCorner.Parent = joinBtn
    
    -- Efeito hover no botão
    joinBtn.MouseEnter:Connect(function()
        TweenService:Create(joinBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 220, 120)}):Play()
    end)
    joinBtn.MouseLeave:Connect(function()
        TweenService:Create(joinBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 200, 100)}):Play()
    end)
    
    -- Botão loop (para todos os pets, posição muda baseado em 100M+)
    local loopBtn = Instance.new("TextButton")
    loopBtn.Name = "LoopBtn"
    if isHighValue then
        loopBtn.Size = UDim2.new(0, 60, 0, 35)
        loopBtn.Position = UDim2.new(1, -110, 0, 22.5)
    else
        loopBtn.Size = UDim2.new(0, 60, 0, 35)
        loopBtn.Position = UDim2.new(1, -90, 0, 22.5)
        joinBtn.Position = UDim2.new(1, -160, 0, 22.5)
    end
    loopBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    loopBtn.BorderSizePixel = 0
    loopBtn.Text = "🔄 Loop"
    loopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loopBtn.Font = Enum.Font.GothamBold
    loopBtn.TextSize = 12
    loopBtn.Parent = entry
    
    local loopCorner = Instance.new("UICorner")
    loopCorner.CornerRadius = UDim.new(0, 6)
    loopCorner.Parent = loopBtn
    
    -- Efeito hover no botão loop
    loopBtn.MouseEnter:Connect(function()
        TweenService:Create(loopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 120, 120)}):Play()
    end)
    loopBtn.MouseLeave:Connect(function()
        TweenService:Create(loopBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
    end)
    
    -- Botão marcar/desmarcar filtro
    local filterBtn = Instance.new("TextButton")
    filterBtn.Name = "FilterBtn"
    filterBtn.Size = UDim2.new(0, 30, 0, 30)
    filterBtn.Position = UDim2.new(1, -35, 0, 8)
    filterBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    filterBtn.BorderSizePixel = 0
    filterBtn.Text = "★"
    filterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    filterBtn.Font = Enum.Font.GothamBold
    filterBtn.TextSize = 14
    filterBtn.Parent = entry
    
    local filterCorner = Instance.new("UICorner")
    filterCorner.CornerRadius = UDim.new(0, 6)
    filterCorner.Parent = filterBtn
    
    -- Atualiza estado do botão filtro
    local function updateFilterButton()
        local petName = petData.PetName or petData.Name or ""
        if CONFIG.MarkedPets[petName] then
            filterBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
            filterBtn.Text = "★"
        else
            filterBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            filterBtn.Text = "☆"
        end
    end
    
    updateFilterButton()
    
    -- Ação de marcar/desmarcar filtro
    filterBtn.MouseButton1Click:Connect(function()
        local petName = petData.PetName or petData.Name or ""
        if CONFIG.MarkedPets[petName] then
            CONFIG.MarkedPets[petName] = nil
        else
            CONFIG.MarkedPets[petName] = true
        end
        saveConfig()
        updateFilterButton()
        -- Recarrega lista para aplicar filtro
        updatePetsList()
    end)
    
    -- Ação de entrar
    joinBtn.MouseButton1Click:Connect(function()
        local jobId = petData.JobId
        if not jobId then
            warn("[Pet Finder] JobId não encontrado")
            return
        end
        
        joinBtn.Text = "⏳ Entrando..."
        joinBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        joinBtn.AutoButtonColor = false
        
        task.spawn(function()
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
            end)
            
            if not success then
                warn("[Pet Finder] Erro ao entrar:", err)
                joinBtn.Text = "❌ Erro"
                task.wait(1)
                joinBtn.Text = "▶ Entrar"
                joinBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
            end
        end)
    end)
    
    -- Ação de loop (configurável por geração)
    local isLooping = false
    loopBtn.MouseButton1Click:Connect(function()
        if isLooping then
            isLooping = false
            loopBtn.Text = "🔄 Loop"
            loopBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
            return
        end
        
        local jobId = petData.JobId
        if not jobId then
            warn("[Pet Finder] JobId não encontrado")
            return
        end
        
        -- Calcula maxTries baseado na geração
        local genStr = tostring(petData.Generation or petData.G or "0")
        local genValue = parseGeneration(genStr)
        local maxTries = CONFIG.RetryConfig["100M-"]
        
        if genValue >= 500000000 then -- 500M+
            maxTries = CONFIG.RetryConfig["500M+"]
        elseif genValue >= 100000000 then -- 100M+
            maxTries = CONFIG.RetryConfig["100M+"]
        end
        
        isLooping = true
        loopBtn.Text = "⏸ Parar"
        loopBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        
        task.spawn(function()
            local tries = 0
            
            while isLooping and tries < maxTries do
                tries = tries + 1
                loopBtn.Text = string.format("🔄 %d/%d", tries, maxTries)
                
                local success, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
                end)
                
                if not success then
                    warn(string.format("[Pet Finder] Tentativa %d/%d falhou: %s", tries, maxTries, err))
                end
                
                task.wait(CONFIG.RetryInterval)
            end
            
            isLooping = false
            loopBtn.Text = "🔄 Loop"
            loopBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
            
            if tries >= maxTries then
                loopBtn.Text = "✓ Concluído"
                task.wait(1)
                loopBtn.Text = "🔄 Loop"
            end
        end)
    end)
    
    return entry
end

local function sortPets(petsArray)
    local sortBy = CONFIG.SortBy
    
    table.sort(petsArray, function(a, b)
        if sortBy == "Generation" then
            local genA = parseGeneration(a.Generation or a.G or 0)
            local genB = parseGeneration(b.Generation or b.G or 0)
            return genA > genB
        elseif sortBy == "Name" then
            local nameA = (a.PetName or a.Name or ""):lower()
            local nameB = (b.PetName or b.Name or ""):lower()
            return nameA < nameB
        elseif sortBy == "Time" then
            local timeA = a.timestamp or 0
            local timeB = b.timestamp or 0
            return timeA > timeB
        end
        return false
    end)
end

updatePetsList = function()
    if isRefreshing then return end
    isRefreshing = true
    
    -- Limpa lista atual
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("PetEntry_") then
            child:Destroy()
        end
    end
    
    -- Converte petsData para array
    local petsArray = {}
    for _, petData in pairs(petsData) do
        table.insert(petsArray, petData)
    end
    
    -- Ordena
    sortPets(petsArray)
    
    -- Limita quantidade
    local displayCount = math.min(#petsArray, CONFIG.MaxPetsDisplay)
    
    -- Atualiza contador
    petCountLabel.Text = string.format("%d pets", #petsArray)
    if #petsArray > CONFIG.MaxPetsDisplay then
        petCountLabel.Text = petCountLabel.Text .. " (mostrando " .. CONFIG.MaxPetsDisplay .. ")"
    end
    
    -- Cria entries
    for i = 1, displayCount do
        local entry = createPetEntry(petsArray[i], i)
        entry.LayoutOrder = i
    end
    
    -- Atualiza scroll
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    
    isRefreshing = false
end

-- ============================================================================
-- EVENTOS
-- ============================================================================

refreshBtn.MouseButton1Click:Connect(function()
    updatePetsList()
end)

clearBtn.MouseButton1Click:Connect(function()
    petsData = {}
    updatePetsList()
end)

sortDropdown.MouseButton1Click:Connect(function()
    local options = {"Generation", "Name", "Time"}
    local currentIndex = 1
    for i, opt in ipairs(options) do
        if CONFIG.SortBy == opt then
            currentIndex = i
            break
        end
    end
    
    currentIndex = (currentIndex % #options) + 1
    CONFIG.SortBy = options[currentIndex]
    
    local labels = {
        Generation = "Geração ▼",
        Name = "Nome ▼",
        Time = "Tempo ▼"
    }
    
    sortDropdown.Text = labels[CONFIG.SortBy] or "Ordenar ▼"
    updatePetsList()
end)

-- Atualização automática
task.spawn(function()
    while true do
        task.wait(CONFIG.UpdateInterval)
        if CONFIG.AutoRefresh and screenGui.Enabled then
            updatePetsList()
        end
    end
end)

-- Atualiza scroll quando lista muda
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end)

-- ============================================================================
-- TECLA DE ATALHO
-- ============================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- ============================================================================
-- SISTEMA DE AUTENTICAÇÃO KEY + HWID
-- ============================================================================

-- Obtém HWID único do sistema (usa função padrão do executor)
local function getHWID()
    -- Tenta usar função padrão do executor
    if gethwid then
        local success, hwid = pcall(function()
            return gethwid()
        end)
        if success and hwid then
            return tostring(hwid)
        end
    end
    
    -- Fallback se gethwid não estiver disponível
    warn("[Auth] gethwid() não está disponível! Usando fallback.")
    local fallback_id = ""
    if LocalPlayer then
        fallback_id = tostring(LocalPlayer.UserId)
    end
    return fallback_id .. "_fallback"
end

-- Obtém a key (vem de getgenv().PetFinder["Key"])
local function getAuthKey()
    -- Tenta obter do getgenv().PetFinder
    if getgenv and getgenv().PetFinder and getgenv().PetFinder["Key"] and getgenv().PetFinder["Key"] ~= "" then
        return getgenv().PetFinder["Key"]
    end
    
    -- Tenta obter de variável global (fallback)
    if _G.PetFinder and _G.PetFinder["Key"] and _G.PetFinder["Key"] ~= "" then
        return _G.PetFinder["Key"]
    end
    
    -- Retorna nil se não encontrar (vai falhar na autenticação)
    warn("[Auth] Key não encontrada! Configure getgenv().PetFinder[\"Key\"] com sua key de autenticação")
    return nil
end

-- Função removida - validação agora é feita diretamente no WebSocket via headers

-- ============================================================================
-- CLIENTE WEBSOCKET PARA BRAINROT MONITOR
-- Conecta ao servidor WebSocket do selfbot e atualiza o pet finder
-- Requer Volt/KCT executor com suporte a WebSocket
-- ============================================================================

-- WebSocket é fornecido pelo Volt/KCT executor (não é uma variável padrão do Roblox)

-- Configuração do WebSocket (suporta Cloudflared ou localhost)
local customWsUrl = getgenv().PetFinder and getgenv().PetFinder["WS URL"] or ""
local WS_CONFIG = {
    -- URL do servidor WebSocket (usa configuração customizada ou padrão localhost)
    wsUrl = (customWsUrl ~= "" and customWsUrl) or "ws://127.0.0.1:8080",
    
    -- URL da API de autenticação (não usado mais, mas mantido para compatibilidade)
    authApiUrl = "http://127.0.0.1:8081/api/auth",
    
    -- Intervalo de reconexão (segundos)
    reconnectInterval = 5,
}

print("[WebSocket Client] URL configurada:", WS_CONFIG.wsUrl)

local wsClient = nil
local isConnected = false
local authKey = nil
local authHWID = nil
local isAuthenticated = false

-- Função para processar brainrots recebidos
local function processBrainrots(brainrots)
    if not brainrots or type(brainrots) ~= "table" then 
        return 
    end
    
    local added = 0
    
    -- Processa cada brainrot individualmente
    for _, brainrot in ipairs(brainrots) do
        -- Verifica se tem JobId (obrigatório)
        if brainrot.JobId then
            -- Converte para formato do Pet Finder
            local petData = {
                JobId = tostring(brainrot.JobId),
                PetName = brainrot.PetName or brainrot.name or "Unknown",
                Generation = brainrot.Generation or brainrot.gen or "0",
                PlotName = brainrot.PlotName,
                PodiumID = brainrot.PodiumID,
                AnimalIndex = brainrot.AnimalIndex,
                timestamp = tick() -- Sempre usa timestamp atual para garantir unicidade
            }
            
            -- Adiciona ao Pet Finder
            if PetFinderAPI and PetFinderAPI.AddPet(petData) then
                added = added + 1
            end
        end
    end
end

-- Função para processar mensagens recebidas via WebSocket
local function handleMessage(message)
    local success, data = pcall(function()
        return HttpService:JSONDecode(message)
    end)
    
    if not success then
        warn("[WebSocket Client] Erro ao decodificar mensagem:", data)
        return
    end
    
    if not data or not data.type then
        return
    end
    
    if data.type == "new_brainrot" or data.type == "brainrot" then
        -- Processa um único brainrot
        local brainrots = {data.data}
        processBrainrots(brainrots)
        
    elseif data.type == "all_brainrots" or data.type == "init" then
        -- Recebe todos os brainrots ao conectar
        if data.data and type(data.data) == "table" then
            print(string.format("[WebSocket Client] Carregando %d brainrots...", #data.data))
            processBrainrots(data.data)
            print("[WebSocket Client] Todos os brainrots carregados!")
        end
    end
end

-- Função para conectar ao WebSocket (com autenticação)
local function connect()
    if isConnected and wsClient and isAuthenticated then return end
    
    -- Obtém credenciais
    authKey = getAuthKey()
    if not authKey then
        warn("[WebSocket Client] Key não encontrada! Autenticação falhou.")
        return
    end
    
    authHWID = getHWID()
    if not authHWID then
        warn("[WebSocket Client] Erro ao obter HWID! Autenticação falhou.")
        return
    end
    
    print("[WebSocket Client] Conectando ao WebSocket com autenticação...")
    print("[WebSocket Client] HWID:", authHWID)
    
    -- Verifica se WebSocket está disponível (Volt/KCT)
    -- @ts-ignore - WebSocket é fornecido pelo executor Volt/KCT
    if not WebSocket then
        warn("[WebSocket Client] WebSocket não está disponível! Certifique-se de estar usando Volt/KCT")
        return
    end
    
    -- Conecta ao WebSocket (sem query params - tudo via mensagem)
    print("[WebSocket Client] Conectando ao WebSocket...")
    
    local success, ws = pcall(function()
        -- @ts-ignore - WebSocket é fornecido pelo executor Volt/KCT
        return WebSocket.connect(WS_CONFIG.wsUrl)
    end)
    
    if not success or not ws then
        warn("[WebSocket Client] Erro ao conectar:", ws)
        return
    end
    
    wsClient = ws
    isConnected = true
    isAuthenticated = false
    
    -- Handler de mensagens
    ws.OnMessage:Connect(function(message)
        local msgSuccess, msgData = pcall(function()
            return HttpService:JSONDecode(message)
        end)
        
        if not msgSuccess then
            if isAuthenticated then
                handleMessage(message)
            end
            return
        end
        
        -- Verifica resposta de autenticação
        if msgData.type == "auth_success" then
            isAuthenticated = true
            print("[WebSocket Client] Autenticado! Conectado ao servidor!")
        elseif msgData.type == "auth_failed" then
            warn("[WebSocket Client] Autenticação falhou:", msgData.reason or "Razão desconhecida")
            ws:Close()
            return
        elseif msgData.type == "auth_required" then
            -- Ignora, já vamos enviar
        else
            -- Mensagens normais só se autenticado
            if isAuthenticated then
                handleMessage(message)
            end
        end
    end)
    
    -- Envia autenticação imediatamente após conectar
    task.wait(0.1) -- Pequeno delay para conexão estabelecer
    if wsClient then
        local authMessage = HttpService:JSONEncode({
            type = "auth",
            key = authKey,
            hwid = authHWID
        })
        wsClient:Send(authMessage)
        print("[WebSocket Client] Credenciais enviadas, aguardando validação...")
    end
    
    -- Handler de desconexão
    ws.OnClose:Connect(function()
        print("[WebSocket Client] Desconectado do servidor")
        isConnected = false
        isAuthenticated = false
        wsClient = nil
        
        -- Tenta reconectar
        task.wait(WS_CONFIG.reconnectInterval)
        connect()
    end)
    
    -- Handler de erro (OnError não existe no WebSocket do executor)
    -- Erros são tratados via OnClose e pcall
end

-- Inicia conexão
task.spawn(function()
    task.wait(1) -- Aguarda pet finder carregar
    connect()
end)

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

print("[Pet Finder] Interface carregada!")
print("[Pet Finder] API disponível via PetFinderAPI")
print("[Pet Finder] Pressione P para abrir/fechar a interface")
print("[WebSocket Client] Cliente iniciado! Conectando a", WS_CONFIG.wsUrl)

-- Atualiza lista inicial
updatePetsList()
