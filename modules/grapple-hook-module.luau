-- Grapple Hook Module
local GrappleHookModule = {}

-- Services
local uis = game:GetService("UserInputService")
local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local lp = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera

-- Module State
local config = {
    Speed = 200,
    Keybind = Enum.KeyCode.Y,
}

local active = false
local character
local hrp
local tool
local remote
local humanoid
local connections = {}
local keybindConnection

-- Private Functions
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

local function speedon()
    if active then return end
    active = true
    
    charsetup()
    
    connections.velocity = runService.Heartbeat:Connect(function()
        if not active or not hrp then return end
        
        local direction = getdir()
        
        if direction.Magnitude > 0 then
            local randomFactor = math.random(95, 105) / 100
            hrp.AssemblyLinearVelocity = direction * (config.Speed * randomFactor)
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

local function speedoff()
    if not active then return end
    active = false
    cleanup()
end

-- Public Functions
function GrappleHookModule:Enable()
    speedon()
end

function GrappleHookModule:Disable()
    speedoff()
end

function GrappleHookModule:Toggle()
    if active then
        self:Disable()
    else
        self:Enable()
    end
end

function GrappleHookModule:IsActive()
    return active
end

function GrappleHookModule:SetSpeed(speed)
    config.Speed = speed or 200
end

function GrappleHookModule:GetSpeed()
    return config.Speed
end

function GrappleHookModule:SetKeybind(keybind)
    config.Keybind = keybind or Enum.KeyCode.Y
end

function GrappleHookModule:GetKeybind()
    return config.Keybind
end

function GrappleHookModule:Init(customConfig)
    -- Apply custom config if provided
    if customConfig then
        if customConfig.Speed then config.Speed = customConfig.Speed end
        if customConfig.Keybind then config.Keybind = customConfig.Keybind end
    end
    
    -- Setup keybind listener
    if keybindConnection then
        keybindConnection:Disconnect()
    end
    
    keybindConnection = uis.InputBegan:Connect(function(input, processed)
        if input.KeyCode == config.Keybind then
            if processed then return end
            self:Toggle()
        end
    end)
end

function GrappleHookModule:Destroy()
    if keybindConnection then
        keybindConnection:Disconnect()
        keybindConnection = nil
    end
    
    self:Disable()
end

return GrappleHookModule
