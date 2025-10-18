-- Módulo de Grapple Hook Speed/Fly
local GrappleHookModule = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera

local active = false
local character = nil
local hrp = nil
local humanoid = nil
local tool = nil
local remote = nil
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
    
    local packages = ReplicatedStorage:WaitForChild("Packages")
    local net = packages:FindFirstChild("Net")
    if net then
        remote = net:WaitForChild("RE/UseItem")
    end
    
    local backpack = lp:WaitForChild("Backpack")
    tool = backpack:FindFirstChild("Grapple Hook")
    if tool then
        tool.Parent = character
        print("[Grapple Hook] Tool equipped! Speed:", speed)
    else
        print("[Grapple Hook] Tool NOT found in backpack!")
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
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camCF.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camCF.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camCF.RightVector end
    
    return moveDir.Magnitude > 0 and moveDir.Unit or Vector3.zero
end

function GrappleHookModule.enable()
    print("[Grapple Hook] Enable called!")
    if active then 
        print("[Grapple Hook] Already active!")
        return 
    end
    active = true
    
    print("[Grapple Hook] Starting charsetup...")
    charsetup()
    print("[Grapple Hook] Charsetup done! HRP:", hrp, "Remote:", remote)
    
    connections.velocity = RunService.Heartbeat:Connect(function()
        if not active or not hrp then return end
        
        local direction = getdir()
        
        if direction.Magnitude > 0 then
            local randomFactor = math.random(95, 105) / 100
            local finalSpeed = speed * randomFactor
            print("[Grapple Hook] Moving! Direction:", direction, "Speed:", finalSpeed)
            hrp.AssemblyLinearVelocity = direction * finalSpeed
        else
            local currentVel = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(0, currentVel.Y, 0)
        end
        
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    
    print("[Grapple Hook] Velocity connection created!")
    
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

return GrappleHookModule
