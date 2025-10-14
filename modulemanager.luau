-- Módulo Gerenciador - Coordena todos os módulos do script
-- Carregado via loadstring do GitHub
local ModulesManager = {}

-- URLs dos módulos no GitHub (CONFIGURADO PARA: redzreaI/lol)
local GITHUB_BASE = "https://raw.githubusercontent.com/redzreaI/lol/refs/heads/main/modules/"

-- Funcao para carregar modulo externo
local function loadModule(moduleName)
    local url = GITHUB_BASE .. moduleName .. ".luau"
    print("[Labs Hub] Loading module: " .. moduleName)
    
    local success, result = pcall(function()
        local code = game:HttpGet(url)
        return loadstring(code)()
    end)
    
    if not success then
        warn("[Labs Hub] Failed to load module: " .. moduleName .. " | Error: " .. tostring(result))
        return nil
    end
    
    print("[Labs Hub] Loaded module: " .. moduleName)
    return result
end

-- ===== CARREGAR MODULOS EM PARALELO (MUITO MAIS RAPIDO!) =====
print("[Labs Hub] Starting parallel module loading...")

local modules = {}
local modulesToLoad = {
    "desync-module",
    "x-ray-module",
    "auto-laser-cape-module",
    "web-slinger",
    "ESP-module",
    "auto-joiner-module",
    "fps-devour-module",
    "float-module",
    "roof-steal-module",
    "open-base-buttons-module"
}

-- Carregar todos em paralelo usando task.spawn
for _, moduleName in ipairs(modulesToLoad) do
    task.spawn(function()
        modules[moduleName] = loadModule(moduleName)
    end)
end

-- Aguardar TODOS carregarem (com timeout)
local timeout = 15 -- 15 segundos maximo
local startTime = tick()
local loadedCount = 0

while tick() - startTime < timeout do
    loadedCount = 0
    for _, moduleName in ipairs(modulesToLoad) do
        if modules[moduleName] then
            loadedCount = loadedCount + 1
        end
    end
    
    if loadedCount == #modulesToLoad then
        print("[Labs Hub] All modules loaded! (" .. loadedCount .. "/" .. #modulesToLoad .. ")")
        break
    end
    
    task.wait(0.1)
end

-- Mostrar progresso
if loadedCount < #modulesToLoad then
    warn("[Labs Hub] Only " .. loadedCount .. "/" .. #modulesToLoad .. " modules loaded after timeout")
    
    -- Mostrar quais falharam
    for _, moduleName in ipairs(modulesToLoad) do
        if not modules[moduleName] then
            warn("[Labs Hub] Missing: " .. moduleName)
        end
    end
end

-- Atribuir modulos carregados
local DesyncModule = modules["desync-module"]
local XRayModule = modules["x-ray-module"]
local AutoLaserModule = modules["auto-laser-cape-module"]
local WebSlingerModule = modules["web-slinger"]
local ESPModule = modules["ESP-module"]
local AutoJoinerModule = modules["auto-joiner-module"]
local FPSDevourModule = modules["fps-devour-module"]
local FloatModule = modules["float-module"]
local RoofStealModule = modules["roof-steal-module"]
local OpenBaseButtonsModule = modules["open-base-buttons-module"]

-- CONTINUAR MESMO COM MODULOS FALTANDO (evitar crash completo)
local failedModules = {}
if not DesyncModule then table.insert(failedModules, "desync-module") end
if not XRayModule then table.insert(failedModules, "x-ray-module") end
if not AutoLaserModule then table.insert(failedModules, "auto-laser-cape-module") end
if not WebSlingerModule then table.insert(failedModules, "web-slinger") end
if not ESPModule then table.insert(failedModules, "ESP-module") end
if not AutoJoinerModule then table.insert(failedModules, "auto-joiner-module") end
if not FPSDevourModule then table.insert(failedModules, "fps-devour-module") end
if not FloatModule then table.insert(failedModules, "float-module") end
if not RoofStealModule then table.insert(failedModules, "roof-steal-module") end
if not OpenBaseButtonsModule then table.insert(failedModules, "open-base-buttons-module") end

if #failedModules > 0 then
    warn("[Labs Hub] Failed modules: " .. table.concat(failedModules, ", "))
    warn("[Labs Hub] Some features may not work!")
end

-- Referências globais
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local character = nil
local backpack = nil
local humanoid = nil
local rootPart = nil

-- Função para atualizar referências de character
function ModulesManager.updateCharacterRefs()
    if lp and lp.Character then
        character = lp.Character
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
    elseif lp then
        character = lp.CharacterAdded:Wait()
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
    end
    
    if lp then
        backpack = lp:WaitForChild('Backpack')
    end
end

-- Inicializar módulos
function ModulesManager.init()
    -- Inicializar X-Ray
    local playerGui = lp:WaitForChild("PlayerGui")
    XRayModule.init(playerGui)
    
    -- Configurar loops do ESP
    ESPModule.setupLoop(lp)
    ESPModule.setupPlayerEvents(lp)
    
    -- Atualizar referências de character
    ModulesManager.updateCharacterRefs()
end

-- Exportar funções dos módulos
ModulesManager.Desync = DesyncModule
ModulesManager.XRay = XRayModule
ModulesManager.AutoLaser = AutoLaserModule
ModulesManager.WebSlinger = WebSlingerModule
ModulesManager.ESP = ESPModule
ModulesManager.AutoJoiner = AutoJoinerModule
ModulesManager.FPSDevour = FPSDevourModule
ModulesManager.Float = FloatModule
ModulesManager.RoofSteal = RoofStealModule
ModulesManager.OpenBaseButtons = OpenBaseButtonsModule

-- Funções auxiliares para acessar referências
function ModulesManager.getCharacter()
    return character
end

function ModulesManager.getBackpack()
    return backpack
end

function ModulesManager.getHumanoid()
    return humanoid
end

function ModulesManager.getRootPart()
    return rootPart
end

function ModulesManager.getLocalPlayer()
    return lp
end

-- Função para usar Auto Laser (wrapper)
function ModulesManager.startAutoLaser(useItemRemote)
    ModulesManager.updateCharacterRefs()
    AutoLaserModule.start(lp, character, backpack, useItemRemote)
end

function ModulesManager.stopAutoLaser()
    AutoLaserModule.stop()
end

-- Função para usar Web Slinger (wrapper)
function ModulesManager.useWebSlinger()
    ModulesManager.updateCharacterRefs()
    WebSlingerModule.use(lp, character, backpack)
end

-- Função para toggle ESP Best (wrapper)
function ModulesManager.toggleESPBest(state)
    ESPModule.toggleESPBest(state, lp)
end

-- Função para toggle ESP Player (wrapper)
function ModulesManager.toggleESPPlayer(state)
    local playerGui = lp:WaitForChild("PlayerGui")
    ESPModule.toggleESPPlayer(state, lp, playerGui)
end

-- Função para X-Ray (wrapper)
function ModulesManager.setBaseInvisible(state)
    XRayModule.setBaseInvisible(state)
end

-- Função para conectar WebSocket (wrapper)
function ModulesManager.connectWebSocket(wsUrl, methods, key)
    return AutoJoinerModule.connectWebSocket(wsUrl, lp, methods, key)
end

-- Função para desconectar WebSocket (wrapper)
function ModulesManager.disconnectWebSocket(methods, key)
    AutoJoinerModule.disconnectWebSocket(lp, methods, key)
end

-- Função para processar job do WebSocket (wrapper)
function ModulesManager.processWebSocketJob(jobData, methods, specificBrainrots, avaiblemethods, showBrainrots)
    AutoJoinerModule.processWebSocketJob(jobData, methods, specificBrainrots, avaiblemethods, showBrainrots, lp)
end

-- Função para rodar Auto Joiner (wrapper)
function ModulesManager.runAutoJoiner(config)
    config.lp = lp
    AutoJoinerModule.run(config)
end

-- Funções para FPS Devour (wrapper)
function ModulesManager.startFPSDevourAura(settings)
    ModulesManager.updateCharacterRefs()
    FPSDevourModule.startAura(character, backpack, settings, DesyncModule.getRequiredRemotes, ModulesManager.updateCharacterRefs)
end

function ModulesManager.startFPSDevourEquip(useItemRemote, settings)
    ModulesManager.updateCharacterRefs()
    FPSDevourModule.startEquip(character, backpack, useItemRemote, ModulesManager.updateCharacterRefs, settings)
end

function ModulesManager.stopFPSDevour(settings)
    FPSDevourModule.stop(settings)
end

function ModulesManager.stopFPSDevourEquip(settings)
    FPSDevourModule.stopEquip(settings)
end

-- Funções para Float (wrapper)
function ModulesManager.enableFloat(Labs, activetheme)
    local playerGui = lp:WaitForChild("PlayerGui")
    ModulesManager.updateCharacterRefs()
    FloatModule.enable(playerGui, Labs, activetheme, rootPart, ModulesManager.updateCharacterRefs)
end

function ModulesManager.disableFloat()
    ModulesManager.updateCharacterRefs()
    FloatModule.disable(rootPart)
end

function ModulesManager.isFloatEnabled()
    return FloatModule.isEnabled()
end

-- Funções para Roof Steal (wrapper)
function ModulesManager.enableRoofSteal(Labs)
    local playerGui = lp:WaitForChild("PlayerGui")
    RoofStealModule.enable(Labs, playerGui)
end

function ModulesManager.disableRoofSteal()
    local playerGui = lp:WaitForChild("PlayerGui")
    RoofStealModule.disable(playerGui)
end

function ModulesManager.isRoofStealEnabled()
    return RoofStealModule.isEnabled()
end

-- Funções para Open Base Buttons (wrapper)
function ModulesManager.createOpenBaseButtons(Labs, activetheme)
    local playerGui = lp:WaitForChild("PlayerGui")
    OpenBaseButtonsModule.create(playerGui, Labs, activetheme, lp)
end

function ModulesManager.removeOpenBaseButtons()
    OpenBaseButtonsModule.remove()
end

function ModulesManager.isOpenBaseButtonsEnabled()
    return OpenBaseButtonsModule.isEnabled()
end

return ModulesManager
