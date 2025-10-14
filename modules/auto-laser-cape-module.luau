-- Módulo de Auto Laser Cape
local AutoLaserModule = {}

local AutoLaserLoop = false
local autoLaserConnection = nil
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function equipTool(character, backpack, toolName)
    if not character or not character.Parent then
        return nil
    end
    local tool = character:FindFirstChild(toolName)
        or (backpack and backpack:FindFirstChild(toolName))
    if tool and character:FindFirstChild('Humanoid') then
        tool.Parent = character
        character.Humanoid:EquipTool(tool)
        task.wait(0.05)
        return tool
    end
    return nil
end

local function getClosestPlayerHRP(player, character)
    if not character or not character:FindFirstChild('HumanoidRootPart') then
        return nil
    end
    local hrp = character.HumanoidRootPart
    local closest, distance = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if
            plr ~= player
            and plr.Character
            and plr.Character:FindFirstChild('HumanoidRootPart')
        then
            local targetHRP = plr.Character.HumanoidRootPart
            local mag = (hrp.Position - targetHRP.Position).Magnitude
            if mag < distance then
                closest, distance = targetHRP, mag
            end
        end
    end
    return closest
end

function AutoLaserModule.start(player, character, backpack, useItemRemote)
    if AutoLaserLoop then
        return
    end
    AutoLaserLoop = true

    if not character or not character.Parent then
        return
    end

    autoLaserConnection = RunService.RenderStepped:Connect(function()
        if not AutoLaserLoop then
            if autoLaserConnection then
                autoLaserConnection:Disconnect()
                autoLaserConnection = nil
            end
            return
        end

        if not character or not character.Parent then
            return
        end

        if not AutoLaserLoop then
            return
        end

        local tool = equipTool(character, backpack, 'Laser Cape')
        local closestHRP = getClosestPlayerHRP(player, character)
        if tool and closestHRP and useItemRemote and AutoLaserLoop then
            pcall(function()
                useItemRemote:FireServer(closestHRP.Position, closestHRP)
            end)
        end
    end)
end

function AutoLaserModule.stop()
    AutoLaserLoop = false
    if autoLaserConnection then
        autoLaserConnection:Disconnect()
        autoLaserConnection = nil
    end
end

function AutoLaserModule.isActive()
    return AutoLaserLoop
end

return AutoLaserModule