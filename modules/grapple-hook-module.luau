-- Módulo de Grapple Hook Speed/Fly (EXATAMENTE igual ao arise.luau)
local GrappleHookModule = {}

local uis = game:GetService("UserInputService")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local lp = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera

local active = false
local character
local hrp
local humanoid
local tool
local remote
local connections = {}
local speed = 200

function GrappleHookModule.setSpeed(newSpeed)
    speed = newSpeed
end

function GrappleHookModule.getSpeed()
    return speed
end

local function charsetup()
    character = lp.Character or lp.CharacterAdded:Wait()
    hrp = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    
    local packages = rs:WaitForChild("Packages")
    local net = packages:FindFirstChild("Net")
    if net then
        remote = net:WaitForChild("RE/UseItem")
    end
    
    tool = lp.Backpack:FindFirstChild("Grapple Hook")
    if tool then
        tool.Parent = character
    end
end

local function cleanup()
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}
    
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    
    tool = character and character:FindFirstChild("Grapple Hook")
    if tool then
        tool.Parent = lp.Backpack
    end
end

local function getdir()
    local moveDir = Vector3.zero
    local camCF = camera.CFrame
    
    if uis:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
    if uis:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
    if uis:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
    if uis:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
    
    return moveDir.Magnitude > 0 and moveDir.Unit or Vector3.zero
end

function GrappleHookModule.enable()
    if active then return end
    active = true
    
    charsetup()
    
    connections.velocity = runService.Heartbeat:Connect(function()
        if not active or not hrp then return end
        
        local direction = getdir()
        
        if direction.Magnitude > 0 then
            local randomFactor = math.random(95, 105) / 100
            local finalVel = direction * (speed * randomFactor)
            hrp.AssemblyLinearVelocity = finalVel
        else
            local currentVel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
        end
        
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    
    task.spawn(function()
        while active do
            if remote then
                pcall(function()
                    local variance = math.random(80, 87) / 100
                    remote:FireServer(variance)
                end)
            end
            task.wait(1 + math.random(-10, 10) / 100)
        end
    end)
end

function GrappleHookModule.disable()
    if not active then return end
    active = false
    cleanup()
end

function GrappleHookModule.toggle()
    if active then
        GrappleHookModule.disable()
    else
        GrappleHookModule.enable()
    end
    return active
end

function GrappleHookModule.isActive()
    return active
end

function GrappleHookModule.updateCharacterRefs()
    if lp.Character then
        character = lp.Character
        hrp = character:FindFirstChild("HumanoidRootPart")
        humanoid = character:FindFirstChild("Humanoid")
    end
end

function GrappleHookModule.reset()
    if active then
        active = false
        cleanup()
    end
end

return GrappleHookModule
