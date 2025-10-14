-- Módulo de Web Slinger
local WebSlingerModule = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findNearestPlayer(lp, character)
    local nearestPlayer = nil
    local nearestDistance = math.huge
    
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local localPosition = character.HumanoidRootPart.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= lp and player.Character and player.Character:FindFirstChild("UpperTorso") then
            local distance = (player.Character.UpperTorso.Position - localPosition).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
            end
        end
    end
    
    return nearestPlayer
end

local function unequipCurrentTool(character, backpack)
    if not character then return end
    
    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            tool.Parent = backpack
        end
    end
end

local function equipWebSlinger(character, backpack)
    if not character or not backpack then return false end
    
    unequipCurrentTool(character, backpack)
    
    wait(0.1)
    
    local webSlinger = nil
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool.Name == "Web Slinger" and tool:IsA("Tool") then
            webSlinger = tool
            break
        end
    end
    
    if not webSlinger and character then
        webSlinger = character:FindFirstChild("Web Slinger")
    end
    
    if webSlinger then
        if webSlinger.Parent == backpack then
            webSlinger.Parent = character
        end
        return true
    else
        return false
    end
end

function WebSlingerModule.use(lp, character, backpack)
    if not equipWebSlinger(character, backpack) then
        return
    end
    
    wait(0.1)
    
    local nearestPlayer = findNearestPlayer(lp, character)
    
    if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character:FindFirstChild("UpperTorso") then
        local args = {
            vector.create(-467.7173156738281, -6.074514389038086, 108.23033142089844),
            nearestPlayer.Character.UpperTorso
        }
        
        ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Net"):WaitForChild("RE/UseItem"):FireServer(unpack(args))
    end
end

return WebSlingerModule