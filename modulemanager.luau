-- Módulo Gerenciador - Coordena todos os módulos do script
-- Carregado via loadstring do GitHub
local ModulesManager = {}

-- URLs dos módulos no GitHub (ATUALIZE COM SEU REPOSITÓRIO)
local GITHUB_BASE = "https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/SCRIPT-MODULES/modules/"

-- Função para carregar módulo externo
local function loadModule(moduleName)
    local url = GITHUB_BASE .. moduleName .. ".luau"
    local success, result = pcall(function()
        local code = game:HttpGet(url)
        return loadstring(code)()
    end)
    
    if not success then
        warn("[Labs Hub] Failed to load module: " .. moduleName, result)
        return nil
    end
    
    return result
end

-- Carregar todos os módulos
local DesyncModule = loadModule("desync-module")
local XRayModule = loadModule("x-ray-module")
local AutoLaserModule = loadModule("auto-laser-cape-module")
local WebSlingerModule = loadModule("web-slinger")
local ESPModule = loadModule("ESP-module")
local AutoJoinerModule = loadModule("auto-joiner-module")
local FPSDevourModule = loadModule("fps-devour-module")
local FloatModule = loadModule("float-module")
local RoofStealModule = loadModule("roof-steal-module")
local OpenBaseButtonsModule = loadModule("open-base-buttons-module")

-- Verificar se todos os módulos foram carregados
if not DesyncModule or not XRayModule or not AutoLaserModule or not WebSlingerModule or not ESPModule or not AutoJoinerModule or not FPSDevourModule or not FloatModule or not RoofStealModule or not OpenBaseButtonsModule then
    error("[Labs Hub] Failed to load one or more modules. Please check GitHub URLs.")
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
