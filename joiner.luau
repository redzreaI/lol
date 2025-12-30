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
-- TEMA (estética do loader)
-- ============================================================================

local THEME = {
    DarkBg = Color3.fromRGB(10, 14, 24),
    CardBg = Color3.fromRGB(20, 25, 35),
    AccentRed = Color3.fromRGB(255, 200, 220),
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

-- ============================================================================
-- GUI HELPERS (estética do loader)
-- ============================================================================

local function smoothTween(object, properties, duration, easingStyle)
    duration = duration or 0.25
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    local tween = TweenService:Create(object, TweenInfo.new(duration, easingStyle, Enum.EasingDirection.Out), properties)
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

local function createFrame(parent, size, position, bgColor, bgTransparency)
    local frame = Instance.new("Frame")
    frame.Size = size
    frame.Position = position
    frame.BackgroundColor3 = bgColor or THEME.CardBg
    frame.BackgroundTransparency = bgTransparency or 0
    frame.BorderSizePixel = 0
    frame.Parent = parent
    addCorners(frame, 8)
    return frame
end

local function createTextLabel(parent, size, position, text, textSize, textColor)
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

local function createTextButton(parent, size, position, text, bgColor, textSize)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = bgColor or THEME.ButtonBg
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = textSize or 11
    button.TextColor3 = THEME.TextPrimary
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.Parent = parent
    addCorners(button, 8)
    return button
end

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
    
    -- Pesquisa
    SearchQuery = "", -- Query de pesquisa atual
}

-- ============================================================================
-- DADOS
-- ============================================================================

local petsData = {} -- {jobId, petName, generation, timestamp, ...}
local isRefreshing = false
local petRarities = {} -- Cache de raridades dos pets {petName = "Secret"/"OG"/etc}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Sistema de rastreamento de loops ativos (global, não é perdido quando lista é atualizada)
local activeLoops = {} -- {[jobId] = {isLooping = true/false, tries = 0, maxTries = 100, loopThread = thread}}

-- Debounce para atualizações de lista (reduz ping)
local updateDebounce = false
local pendingUpdate = false

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
            return
        else
            warn("[Pet Finder] Erro ao salvar em arquivo:", err)
        end
    end
    
    -- Fallback: salva no getgenv
    if getgenv then
        getgenv().PetFinderConfig = configToSave
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

-- Verifica se pet passa na pesquisa
local function passesSearch(petData, searchQuery)
    if not searchQuery or searchQuery == "" then return true end
    
    local query = searchQuery:lower()
    local petName = (petData.PetName or petData.Name or ""):lower()
    local genStr = tostring(petData.Generation or petData.G or "0"):lower()
    local plotName = (petData.PlotName or ""):lower()
    
    return petName:find(query) ~= nil or genStr:find(query) ~= nil or plotName:find(query) ~= nil
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
            
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
            end)
            
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
    
    -- Atualiza interface (com debounce para evitar ping alto)
    task.spawn(function()
        updatePetsList()
    end)
    
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
-- INTERFACE GUI (estética do loader)
-- ============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetFinderGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- Frame principal (altura reduzida)
local mainFrame = createFrame(screenGui, UDim2.new(0, 500, 0, 580), UDim2.new(0.5, -250, 0.5, -290), THEME.DarkBg, 0.15)
mainFrame.Name = "MainFrame"
addStroke(mainFrame, THEME.AccentRed, 1, 0.3)

-- Header
local header = createFrame(mainFrame, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 0), THEME.CardBg, 0)
header.Name = "Header"

-- Título
local title = createTextLabel(header, UDim2.new(1, -100, 1, 0), UDim2.new(0, 15, 0, 0), "🍓 Moranguete Finder", 20, THEME.AccentRed)
title.Name = "Title"
title.Font = Enum.Font.GothamBold

-- Contador de pets
local petCountLabel = createTextLabel(header, UDim2.new(0, 80, 1, 0), UDim2.new(1, -95, 0, 0), "0 pets", 14, THEME.TextSecondary)
petCountLabel.Name = "PetCount"
petCountLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Botão fechar (melhorado)
local closeBtn = createTextButton(header, UDim2.new(0, 35, 0, 35), UDim2.new(1, -40, 0, 7.5), "×", Color3.fromRGB(255, 60, 60), 24)
closeBtn.Name = "CloseBtn"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextStrokeTransparency = 0
closeBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
addStroke(closeBtn, Color3.fromRGB(0, 0, 0), 2, 0)

closeBtn.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
end)

-- Efeito hover no botão fechar
closeBtn.MouseEnter:Connect(function()
    smoothTween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 100, 100)})
end)
closeBtn.MouseLeave:Connect(function()
    smoothTween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 60, 60)})
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
local controls = createFrame(mainFrame, UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 60), nil, 1)
controls.Name = "Controls"

-- Botão limpar
local clearBtn = createTextButton(controls, UDim2.new(0, 70, 0, 28), UDim2.new(0, 0, 0, 0), "Limpar", THEME.ButtonBg, 10)
clearBtn.Name = "ClearBtn"
addStroke(clearBtn, THEME.Border, 1, 0.5)

clearBtn.MouseEnter:Connect(function()
    smoothTween(clearBtn, {BackgroundColor3 = Color3.fromRGB(40, 45, 55)})
end)
clearBtn.MouseLeave:Connect(function()
    smoothTween(clearBtn, {BackgroundColor3 = THEME.ButtonBg})
end)

-- Dropdown de ordenação
local sortLabel = createTextLabel(controls, UDim2.new(0, 50, 0, 28), UDim2.new(0, 80, 0, 0), "Ordenar:", 10, THEME.TextSecondary)
sortLabel.Name = "SortLabel"
sortLabel.TextYAlignment = Enum.TextYAlignment.Center

local sortDropdown = createTextButton(controls, UDim2.new(0, 80, 0, 28), UDim2.new(0, 135, 0, 0), "Tempo ▼", THEME.ButtonBg, 10)
sortDropdown.Name = "SortDropdown"
sortDropdown.Font = Enum.Font.Gotham
addStroke(sortDropdown, THEME.Border, 1, 0.5)

sortDropdown.MouseEnter:Connect(function()
    smoothTween(sortDropdown, {BackgroundColor3 = Color3.fromRGB(40, 45, 55)})
end)
sortDropdown.MouseLeave:Connect(function()
    smoothTween(sortDropdown, {BackgroundColor3 = THEME.ButtonBg})
end)

-- Barra de controles (linha 2 - configurações)
local controls2 = createFrame(mainFrame, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 95), nil, 1)
controls2.Name = "Controls2"
controls2.ZIndex = 10

-- Botão auto joiner
local autoJoinerBtn = createTextButton(controls2, UDim2.new(0, 80, 0, 28), UDim2.new(0, 0, 0, 0), CONFIG.AutoJoiner and "Auto: On" or "Auto: Off", CONFIG.AutoJoiner and THEME.AccentOrange or THEME.ButtonBg, 10)
autoJoinerBtn.Name = "AutoJoinerBtn"
autoJoinerBtn.ZIndex = 11
addStroke(autoJoinerBtn, CONFIG.AutoJoiner and THEME.AccentOrange or THEME.Border, 1, CONFIG.AutoJoiner and 0.3 or 0.5)

autoJoinerBtn.MouseButton1Click:Connect(function()
    CONFIG.AutoJoiner = not CONFIG.AutoJoiner
    autoJoinerBtn.BackgroundColor3 = CONFIG.AutoJoiner and THEME.AccentOrange or THEME.ButtonBg
    autoJoinerBtn.Text = CONFIG.AutoJoiner and "Auto: On" or "Auto: Off"
    addStroke(autoJoinerBtn, CONFIG.AutoJoiner and THEME.AccentOrange or THEME.Border, 1, CONFIG.AutoJoiner and 0.3 or 0.5)
end)

-- Botão filtro de raridade (com borda preta quando ativo)
local filterRarityBtn = createTextButton(controls2, UDim2.new(0, 80, 0, 28), UDim2.new(0, 90, 0, 0), CONFIG.FilterRarity and "Filtro: On" or "Filtro: Off", CONFIG.FilterRarity and THEME.AccentGreen or THEME.ButtonBg, 10)
filterRarityBtn.Name = "FilterRarityBtn"
filterRarityBtn.ZIndex = 11
addStroke(filterRarityBtn, CONFIG.FilterRarity and Color3.fromRGB(0, 0, 0) or THEME.Border, 1.5, CONFIG.FilterRarity and 0 or 0.5) -- Borda preta quando ativo

filterRarityBtn.MouseButton1Click:Connect(function()
    CONFIG.FilterRarity = not CONFIG.FilterRarity
    filterRarityBtn.BackgroundColor3 = CONFIG.FilterRarity and THEME.AccentGreen or THEME.ButtonBg
    filterRarityBtn.Text = CONFIG.FilterRarity and "Filtro: On" or "Filtro: Off"
    addStroke(filterRarityBtn, CONFIG.FilterRarity and Color3.fromRGB(0, 0, 0) or THEME.Border, 1.5, CONFIG.FilterRarity and 0 or 0.5) -- Borda preta quando ativo
    saveConfig()
    updatePetsList()
end)

-- Botão de configuração
local configBtn = createTextButton(controls2, UDim2.new(0, 70, 0, 28), UDim2.new(0, 180, 0, 0), "Retries", THEME.ButtonBg, 10)
configBtn.Name = "ConfigBtn"
configBtn.ZIndex = 11
addStroke(configBtn, THEME.Border, 1, 0.5)

configBtn.MouseEnter:Connect(function()
    smoothTween(configBtn, {BackgroundColor3 = Color3.fromRGB(40, 45, 55)})
end)
configBtn.MouseLeave:Connect(function()
    smoothTween(configBtn, {BackgroundColor3 = THEME.ButtonBg})
end)

-- Botão de seleção de brainrots (com borda preta)
local selectPetsBtn = createTextButton(controls2, UDim2.new(0, 80, 0, 28), UDim2.new(0, 260, 0, 0), "Brainrots", THEME.AccentOrange, 10)
selectPetsBtn.Name = "SelectPetsBtn"
selectPetsBtn.ZIndex = 11
addStroke(selectPetsBtn, Color3.fromRGB(0, 0, 0), 1.5, 0) -- Borda preta fina

selectPetsBtn.MouseEnter:Connect(function()
    smoothTween(selectPetsBtn, {BackgroundColor3 = Color3.fromRGB(255, 190, 100)})
end)
selectPetsBtn.MouseLeave:Connect(function()
    smoothTween(selectPetsBtn, {BackgroundColor3 = THEME.AccentOrange})
end)

-- Scroll frame para lista de pets (ajustado para altura menor)
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "PetsList"
scrollFrame.Size = UDim2.new(1, -20, 1, -155)
scrollFrame.Position = UDim2.new(0, 10, 0, 130)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = THEME.Border
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
    local overlay = createFrame(screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 0.5)
    overlay.Name = "ConfigOverlay"
    overlay.ZIndex = 20
    
    -- Janela principal
    local configWindow = createFrame(screenGui, UDim2.new(0, 400, 0, 300), UDim2.new(0.5, -200, 0.5, -150), THEME.CardBg, 0)
    configWindow.Name = "ConfigWindow"
    configWindow.ZIndex = 21
    addStroke(configWindow, THEME.AccentRed, 1, 0.3)
    
    -- Título
    local title = createFrame(configWindow, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), THEME.ButtonBg, 0)
    title.Name = "Title"
    local titleText = createTextLabel(title, UDim2.new(1, -50, 1, 0), UDim2.new(0, 15, 0, 0), "Configuração de Retries", 18, THEME.AccentRed)
    titleText.Font = Enum.Font.GothamBold
    
    -- Botão fechar
    local closeBtn = createTextButton(configWindow, UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), "×", Color3.fromRGB(255, 60, 60), 20)
    closeBtn.Name = "CloseBtn"
    closeBtn.ZIndex = 22
    closeBtn.Font = Enum.Font.GothamBold
    
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
        local labelText = createTextLabel(configWindow, UDim2.new(0, 180, 0, 30), UDim2.new(0, 20, 0, yPos), label, 14, THEME.TextSecondary)
        labelText.TextYAlignment = Enum.TextYAlignment.Center
        
        -- TextBox
        local textBox = Instance.new("TextBox")
        textBox.Name = key .. "Retry"
        textBox.Size = UDim2.new(0, 150, 0, 35)
        textBox.Position = UDim2.new(1, -170, 0, yPos)
        textBox.BackgroundColor3 = THEME.ButtonBg
        textBox.BorderSizePixel = 0
        textBox.Text = tostring(CONFIG.RetryConfig[key] or 0)
        textBox.TextColor3 = THEME.TextPrimary
        textBox.Font = Enum.Font.Gotham
        textBox.TextSize = 14
        textBox.ClearTextOnFocus = false
        textBox.Parent = configWindow
        addCorners(textBox, 8)
        
        retryFields[key] = textBox
        yPos = yPos + 50
    end
    
    -- Botão salvar
    local saveBtn = createTextButton(configWindow, UDim2.new(0, 200, 0, 40), UDim2.new(0.5, -100, 1, -50), "Salvar", THEME.AccentGreen, 16)
    addStroke(saveBtn, THEME.AccentGreen, 1, 0.3)
    saveBtn.Name = "SaveBtn"
    
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
    local overlay = createFrame(screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 0.5)
    overlay.Name = "PetsSelectionOverlay"
    overlay.ZIndex = 20
    
    -- Janela principal
    local petsWindow = createFrame(screenGui, UDim2.new(0, 500, 0, 600), UDim2.new(0.5, -250, 0.5, -300), THEME.CardBg, 0)
    petsWindow.Name = "PetsSelectionWindow"
    petsWindow.ZIndex = 21
    addStroke(petsWindow, THEME.AccentRed, 1, 0.3)
    
    -- Título
    local title = createFrame(petsWindow, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0), THEME.ButtonBg, 0)
    title.Name = "Title"
    local titleText = createTextLabel(title, UDim2.new(1, -50, 1, 0), UDim2.new(0, 15, 0, 0), "Selecionar Brainrots", 18, THEME.AccentRed)
    titleText.Font = Enum.Font.GothamBold
    
    -- Botão fechar
    local closeBtn = createTextButton(petsWindow, UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), "×", Color3.fromRGB(255, 60, 60), 20)
    closeBtn.Name = "CloseBtn"
    closeBtn.ZIndex = 22
    closeBtn.Font = Enum.Font.GothamBold
    
    -- Campo de pesquisa
    local searchFrame = createFrame(petsWindow, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 50), THEME.ButtonBg, 0)
    searchFrame.Name = "SearchFrame"
    addStroke(searchFrame, THEME.Border, 1, 0.5)
    
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -10, 1, 0)
    searchBox.Position = UDim2.new(0, 10, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Pesquisar..."
    searchBox.PlaceholderColor3 = THEME.TextMuted
    searchBox.TextColor3 = THEME.TextPrimary
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 12
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = searchFrame
    
    -- Scroll frame para lista de pets
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "PetsScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -140)
    scrollFrame.Position = UDim2.new(0, 10, 0, 90)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = THEME.Border
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
    
    local searchQuery = ""
    local function updatePetsListInWindow()
        -- Limpa lista atual
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") and child.Name == "PetEntry" then
                child:Destroy()
            end
        end
        
        -- Filtra pets pela pesquisa
        local filteredPets = {}
        for _, petName in ipairs(petNames) do
            if searchQuery == "" or string.find(petName:lower(), searchQuery:lower()) then
                table.insert(filteredPets, petName)
            end
        end
        
        -- Recria entries filtrados
        for i, petName in ipairs(filteredPets) do
            -- Cria entry (mesmo código de antes, mas com índice filtrado)
            local entry = createFrame(scrollFrame, UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0, 0), THEME.ButtonBg, 0)
            entry.Name = "PetEntry"
            entry.LayoutOrder = i
            
            -- Checkbox
            local checkbox = createTextButton(entry, UDim2.new(0, 30, 0, 30), UDim2.new(0, 10, 0, 5), CONFIG.MarkedPets[petName] and "✓" or "", CONFIG.MarkedPets[petName] and THEME.AccentGreen or THEME.ButtonBg, 18)
            checkbox.Name = "Checkbox"
            checkbox.Font = Enum.Font.GothamBold
            
            -- Nome do pet (primeira linha)
            local nameLabel = createTextLabel(entry, UDim2.new(1, -160, 0, 30), UDim2.new(0, 50, 0, 5), petName, 14, THEME.TextPrimary)
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Raridade (primeira linha)
            local rarityLabel = createTextLabel(entry, UDim2.new(0, 100, 0, 30), UDim2.new(1, -110, 0, 5), petRarities[petName] or "?", 12, THEME.AccentCyan)
            rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
            
            -- Label "Min:" (segunda linha)
            local minLabel = createTextLabel(entry, UDim2.new(0, 50, 0, 25), UDim2.new(0, 50, 0, 38), "Min:", 12, THEME.TextSecondary)
            minLabel.TextYAlignment = Enum.TextYAlignment.Center
            
            -- Campo de valor mínimo (segunda linha)
            local minTextBox = Instance.new("TextBox")
            minTextBox.Name = "MinGen"
            minTextBox.Size = UDim2.new(0, 150, 0, 25)
            minTextBox.Position = UDim2.new(0, 105, 0, 38)
            minTextBox.BackgroundColor3 = THEME.ButtonBg
            minTextBox.BorderSizePixel = 0
            local currentMin = CONFIG.MinGeneration[petName]
            minTextBox.PlaceholderText = "Ex: 200M"
            minTextBox.PlaceholderColor3 = THEME.TextMuted
            minTextBox.Text = currentMin and formatGenForInput(currentMin) or ""
            minTextBox.TextColor3 = THEME.TextPrimary
            minTextBox.Font = Enum.Font.Gotham
            minTextBox.TextSize = 12
            minTextBox.ClearTextOnFocus = false
            minTextBox.Parent = entry
            addCorners(minTextBox, 6)
            
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
                    checkbox.BackgroundColor3 = THEME.ButtonBg
                    checkbox.Text = ""
                else
                    CONFIG.MarkedPets[petName] = true
                    checkbox.BackgroundColor3 = THEME.AccentGreen
                    checkbox.Text = "✓"
                end
            end)
        end
        
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 10)
    end
    
    scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 10)
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = searchBox.Text
        updatePetsListInWindow()
    end)
    
    -- Inicializa lista
    updatePetsListInWindow()
    
    -- Botão salvar
    local saveBtn = createTextButton(petsWindow, UDim2.new(0, 200, 0, 40), UDim2.new(0.5, -100, 1, -50), "Salvar", THEME.AccentGreen, 16)
    saveBtn.Name = "SaveBtn"
    
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
    -- Verifica geração para cores especiais
    local genStr = tostring(petData.Generation or petData.G or "0")
    local genValue = parseGeneration(genStr)
    local is1BPlus = genValue >= 1000000000 -- 1B+
    local is500MPlus = genValue >= 500000000 -- 500M+
    local is100MPlus = genValue >= 100000000 -- 100M
    
    -- Cores baseadas na geração
    local entryBgColor = THEME.CardBg
    local entryHoverColor = THEME.ButtonBg
    if is1BPlus then
        entryBgColor = Color3.fromRGB(30, 10, 40) -- Roxo escuro para 1B+
        entryHoverColor = Color3.fromRGB(50, 20, 60)
    elseif is500MPlus then
        entryBgColor = Color3.fromRGB(40, 20, 10) -- Marrom escuro para 500M+
        entryHoverColor = Color3.fromRGB(60, 30, 15)
    elseif is100MPlus then
        entryBgColor = Color3.fromRGB(60, 20, 20) -- Vermelho escuro para 100M+
        entryHoverColor = Color3.fromRGB(80, 30, 30)
    end
    
    local entry = createFrame(scrollFrame, UDim2.new(1, 0, 0, 95), UDim2.new(0, 0, 0, 0), entryBgColor, 0)
    entry.Name = "PetEntry_" .. index
    
    -- Hover effect
    entry.MouseEnter:Connect(function()
        smoothTween(entry, {BackgroundColor3 = entryHoverColor})
    end)
    entry.MouseLeave:Connect(function()
        smoothTween(entry, {BackgroundColor3 = entryBgColor})
    end)
    
    -- Linha 1: Nome Brainrot - Geração brainrot
    local nameAndGen = createTextLabel(entry, UDim2.new(1, -150, 0, 22), UDim2.new(0, 12, 0, 6), "", 15, THEME.TextPrimary)
    nameAndGen.Name = "NameAndGen"
    nameAndGen.Font = Enum.Font.GothamBold
    nameAndGen.TextTruncate = Enum.TextTruncate.AtEnd
    
    local petNameStr = petData.PetName or petData.Name or "Unknown Pet"
    local genFormatted = formatGeneration(petData.Generation or petData.G or 0)
    nameAndGen.Text = petNameStr .. " (" .. genFormatted .. ")"
    
    -- Linha 2: Players
    local playersInfo = createTextLabel(entry, UDim2.new(1, -150, 0, 18), UDim2.new(0, 12, 0, 28), "", 11, THEME.TextSecondary)
    playersInfo.Name = "PlayersInfo"
    playersInfo.TextYAlignment = Enum.TextYAlignment.Center
    
    if petData.Players then
        playersInfo.Text = "Players: " .. tostring(petData.Players)
    elseif petData.PlayerCount then
        playersInfo.Text = "Players: " .. tostring(petData.PlayerCount)
    else
        playersInfo.Text = "Players: N/A"
    end
    
    -- Linha 3: Há quanto tempo notificou
    local timeInfo = createTextLabel(entry, UDim2.new(1, -150, 0, 18), UDim2.new(0, 12, 0, 46), "", 11, THEME.TextMuted)
    timeInfo.Name = "TimeInfo"
    timeInfo.TextYAlignment = Enum.TextYAlignment.Center
    
    if petData.timestamp then
        timeInfo.Text = getTimeAgo(petData.timestamp) .. " ago"
    else
        timeInfo.Text = "Agora"
    end
    
    -- Botão entrar (rosinha claro, com borda preta fina)
    local joinBtnColor = Color3.fromRGB(255, 220, 240) -- Rosinha claro
    local joinBtn = createTextButton(entry, UDim2.new(0, 70, 0, 32), UDim2.new(1, -160, 0, 28), "Entrar", joinBtnColor, 12)
    joinBtn.Name = "JoinBtn"
    joinBtn.Font = Enum.Font.GothamBold
    joinBtn.TextStrokeTransparency = 0
    joinBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    addStroke(joinBtn, Color3.fromRGB(0, 0, 0), 1.5, 0) -- Borda preta fina
    
    -- Efeito hover no botão entrar
    joinBtn.MouseEnter:Connect(function()
        smoothTween(joinBtn, {BackgroundColor3 = Color3.fromRGB(255, 240, 250)})
    end)
    joinBtn.MouseLeave:Connect(function()
        smoothTween(joinBtn, {BackgroundColor3 = joinBtnColor})
    end)
    
    -- Botão loop (rosinha mais escuro, com borda preta fina, distanciado)
    local loopBtnColor = Color3.fromRGB(255, 150, 180) -- Rosinha mais escuro
    local loopBtn = createTextButton(entry, UDim2.new(0, 60, 0, 32), UDim2.new(1, -80, 0, 28), "Loop", loopBtnColor, 12)
    loopBtn.Name = "LoopBtn"
    loopBtn.Font = Enum.Font.GothamBold
    loopBtn.TextStrokeTransparency = 0
    loopBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    addStroke(loopBtn, Color3.fromRGB(0, 0, 0), 1.5, 0) -- Borda preta fina
    
    -- Efeito hover no botão loop
    loopBtn.MouseEnter:Connect(function()
        smoothTween(loopBtn, {BackgroundColor3 = Color3.fromRGB(255, 180, 200)})
    end)
    loopBtn.MouseLeave:Connect(function()
        smoothTween(loopBtn, {BackgroundColor3 = loopBtnColor})
    end)
    
    -- Ação de entrar
    joinBtn.MouseButton1Click:Connect(function()
        local jobId = petData.JobId
        if not jobId then
            warn("[Pet Finder] JobId não encontrado")
            return
        end
        
        joinBtn.Text = "Entrando..."
        joinBtn.BackgroundColor3 = THEME.TextMuted
        
        task.spawn(function()
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
            end)
            
            if not success then
                warn("[Pet Finder] Erro ao entrar:", err)
                joinBtn.Text = "Erro"
                task.wait(1)
                joinBtn.Text = "Entrar"
                joinBtn.BackgroundColor3 = joinBtnColor
            end
        end)
    end)
    
    -- Ação de loop (configurável por geração) - usa sistema global
    local jobId = petData.JobId
    
    -- Função para atualizar botão do loop (sempre consulta activeLoops diretamente)
    local function updateLoopButton()
        local currentLoopData = activeLoops[jobId]
        if currentLoopData and currentLoopData.isLooping then
            loopBtn.Text = string.format("%d/%d", currentLoopData.tries or 0, currentLoopData.maxTries or 0)
            loopBtn.BackgroundColor3 = THEME.TextMuted
        else
            loopBtn.Text = "Loop"
            loopBtn.BackgroundColor3 = loopBtnColor
        end
        addStroke(loopBtn, Color3.fromRGB(0, 0, 0), 1.5, 0)
    end
    
    -- Atualiza botão inicialmente
    updateLoopButton()
    
    -- Atualiza botão periodicamente (sempre consulta activeLoops) - otimizado
    task.spawn(function()
        while entry.Parent do
            local currentLoopData = activeLoops[jobId]
            if currentLoopData and currentLoopData.isLooping then
                updateLoopButton()
                task.wait(0.2) -- Reduzido para 0.2s (menos frequente)
            else
                task.wait(0.5) -- Se não está em loop, verifica menos frequentemente
            end
        end
    end)
    
    loopBtn.MouseButton1Click:Connect(function()
        if not jobId then
            warn("[Pet Finder] JobId não encontrado")
            return
        end
        
        local currentLoopData = activeLoops[jobId]
        
        -- Se já está em loop, para
        if currentLoopData and currentLoopData.isLooping then
            currentLoopData.isLooping = false
            activeLoops[jobId] = nil
            updateLoopButton()
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
        
        -- Cria/atualiza loop data
        local newLoopData = {
            isLooping = true,
            tries = 0,
            maxTries = maxTries,
            jobId = jobId
        }
        activeLoops[jobId] = newLoopData
        
        updateLoopButton()
        
        -- Inicia loop em thread separada
        task.spawn(function()
            while newLoopData and newLoopData.isLooping and newLoopData.tries < maxTries do
                newLoopData.tries = newLoopData.tries + 1
                
                pcall(function()
                    TeleportService:TeleportToPlaceInstance(PlaceId, jobId, LocalPlayer)
                end)
                
                task.wait(CONFIG.RetryInterval)
            end
            
            -- Loop terminou
            if newLoopData then
                newLoopData.isLooping = false
                if newLoopData.tries >= maxTries then
                    -- Marca como concluído temporariamente
                    task.wait(1)
                end
                -- Só remove se ainda for o mesmo loop (pode ter sido substituído)
                if activeLoops[jobId] == newLoopData then
                    activeLoops[jobId] = nil
                end
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
    -- Debounce: se já está atualizando, marca como pendente e retorna
    if isRefreshing then
        pendingUpdate = true
        return
    end
    
    -- Se está em debounce, marca como pendente e retorna
    if updateDebounce then
        pendingUpdate = true
        return
    end
    
    -- Ativa debounce (evita atualizações muito frequentes)
    updateDebounce = true
    task.spawn(function()
        task.wait(0.1) -- Espera 0.1s antes de permitir próxima atualização
        updateDebounce = false
        if pendingUpdate then
            pendingUpdate = false
            updatePetsList() -- Processa atualização pendente
        end
    end)
    
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
        local petName = petData.PetName or petData.Name or ""
        -- Aplica filtro de raridade e pesquisa
        if passesFilter(petName, petData) and passesSearch(petData, CONFIG.SearchQuery) then
            table.insert(petsArray, petData)
        end
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
    
    -- Atualiza scroll (só se necessário)
    task.spawn(function()
        task.wait() -- Aguarda um frame
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    
    isRefreshing = false
end

-- ============================================================================
-- EVENTOS
-- ============================================================================

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
    
    sortDropdown.Text = labels[CONFIG.SortBy] or "Tempo ▼"
    updatePetsList()
end)

-- Atualização automática (reduzida para evitar ping alto)
task.spawn(function()
    while true do
        task.wait(CONFIG.UpdateInterval * 2) -- Dobra o intervalo (4s ao invés de 2s)
        if CONFIG.AutoRefresh and screenGui.Enabled then
            updatePetsList()
        end
    end
end)

-- Atualiza scroll quando lista muda (com debounce para evitar ping alto)
local scrollUpdateDebounce = false
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if scrollUpdateDebounce then return end
    scrollUpdateDebounce = true
    
    task.spawn(function()
        task.wait(0.05) -- Debounce de 0.05s
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
        scrollUpdateDebounce = false
    end)
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
-- SISTEMA DE AUTENTICAÇÃO KEY
-- ============================================================================

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

-- ============================================================================
-- CLIENTE WEBSOCKET PARA BRAINROT MONITOR
-- ============================================================================

-- Configuração do WebSocket (suporta Cloudflared ou localhost)
local customWsUrl = getgenv().PetFinder and getgenv().PetFinder["WS URL"] or ""
local WS_CONFIG = {
    wsUrl = (customWsUrl ~= "" and customWsUrl) or "ws://127.0.0.1:8080",
    authApiUrl = "http://127.0.0.1:8081/api/auth",
    reconnectInterval = 5,
}

local wsClient = nil
local isConnected = false
local authKey = nil
local isAuthenticated = false

-- Função para tocar som de notificação
local function playNotificationSound()
    local soundId = 17504881745
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. soundId
    sound.Volume = 0.5
    sound.Parent = game:GetService("SoundService")
    
    sound:Play()
    
    -- Para o som após 3 segundos
    task.spawn(function()
        task.wait(3)
        if sound and sound.Parent then
            sound:Stop()
            sound:Destroy()
        end
    end)
    
    -- Limpa automaticamente quando terminar
    sound.Ended:Connect(function()
        if sound and sound.Parent then
            sound:Destroy()
        end
    end)
end

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
                Players = brainrot.Players or brainrot.PlayerCount or brainrot.players,
                timestamp = tick()
            }
            
            -- Adiciona ao Pet Finder
            if PetFinderAPI and PetFinderAPI.AddPet(petData) then
                added = added + 1
                -- Toca som quando um novo pet é adicionado
                playNotificationSound()
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
            processBrainrots(data.data)
        end
    end
end

-- Função para conectar ao WebSocket (com autenticação)
local function connect()
    if isConnected and wsClient and isAuthenticated then return end
    
    -- Obtém key
    authKey = getAuthKey()
    if not authKey then
        warn("[WebSocket Client] Key não encontrada! Autenticação falhou.")
        return
    end
    
    -- Verifica se WebSocket está disponível (Volt/KCT)
    if not WebSocket then
        warn("[WebSocket Client] WebSocket não está disponível! Certifique-se de estar usando Volt/KCT")
        return
    end
    
    -- Conecta ao WebSocket
    local success, ws = pcall(function()
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
    task.wait(0.1)
    if wsClient then
        local authMessage = HttpService:JSONEncode({
            type = "auth",
            key = authKey
        })
        wsClient:Send(authMessage)
    end
    
    -- Handler de desconexão
    ws.OnClose:Connect(function()
        isConnected = false
        isAuthenticated = false
        wsClient = nil
        
        -- Tenta reconectar
        task.wait(WS_CONFIG.reconnectInterval)
        connect()
    end)
end

-- Inicia conexão
task.spawn(function()
    task.wait(1)
    connect()
end)

-- ============================================================================
-- INICIALIZAÇÃO
-- ============================================================================

-- Atualiza lista inicial
updatePetsList()

task.spawn(function()
    while true do
        game:GetService('GuiService'):ClearError()
        task.wait()
    end
end)
